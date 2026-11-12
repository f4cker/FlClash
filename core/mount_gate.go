package core

import (
	"fmt"
	"slices"
	"strings"
	"sync"

	"github.com/metacubex/mihomo/adapter/outboundgroup"
	"github.com/metacubex/mihomo/adapter/provider"
	"github.com/metacubex/mihomo/component/flashguard"
	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/constant"
	cp "github.com/metacubex/mihomo/constant/provider"
	"github.com/metacubex/mihomo/hub/executor"
	rp "github.com/metacubex/mihomo/rules/provider"
	"github.com/metacubex/mihomo/tunnel"
)

// What the mount check read of the running profile's base. A provider or
// rule set that later loads something the check did not see is refused
// there, before anything can route through it; the profile has to be
// applied again to take it.
type mountGate struct {
	providers map[string]gateAllowance
	ruleSets  map[string]bool
	relay     *mountRelay
	reader    *ruleReader
	reach     map[string]string
	// What a base provider's node may name as its dialer-proxy; nil until
	// the groups taking mounts are known, and then nothing is.
	dialSafe map[string]bool
	// A config applied from elsewhere that holds mounts: nothing was read
	// of it, so whatever it loads may add no Tailscale node, no
	// dialer-proxy and no rule set reaching Tailscale.
	external bool
}

type gateAllowance struct {
	tailscale bool
	relay     bool
}

// A provider whose content could not be read is gated too: the groups using
// it already take no mounts, but its nodes may name any dialer-proxy.
func newMountGate(base *mountBase, reader *ruleReader, relay *mountRelay, reach map[string]string) *mountGate {
	gate := &mountGate{providers: map[string]gateAllowance{}, ruleSets: map[string]bool{}, relay: relay, reader: reader, reach: reach}
	for name, p := range base.providers {
		switch {
		case p.unknown:
			gate.providers[name] = gateAllowance{tailscale: true, relay: true}
		case p.gated:
			gate.providers[name] = gateAllowance{tailscale: p.tailscale, relay: base.providerRelays(name, relay.names)}
		}
	}
	for name := range reader.used {
		if content := base.ruleSets[name]; content.gated && !content.unknown && !content.reaches {
			gate.ruleSets[name] = true
		}
	}
	return gate
}

// Once the groups that take mounts are known, so are the dialer-proxies
// that stay clear of them.
func (g *mountGate) takeGroups(base *mountBase, groups []MountGroupReport) {
	taking := map[string]bool{}
	for _, group := range groups {
		taking[group.Name] = true
	}
	g.dialSafe = base.dialSafe(taking)
}

var (
	mountGateMu      sync.Mutex
	activeMountGate  *mountGate
	mountGateRefused []string
	// Set while a mounted config is applied; the executor holds the tunnel
	// back from running until it is checked.
	mountRuntimeCheck *mountGate
	mountRuntimeError error
	// The config Flash applies next; any other is applied from elsewhere.
	mountApplyExpected *config.Config
)

func init() {
	provider.ProxiesGate = gateMountProxies
	rp.RuleSetGate = gateMountRuleSet
	executor.FlashBeforeApply = beforeMountApply
	executor.FlashBeforeRunning = checkMountRuntimeBeforeRunning
}

// Installed before cfg is applied: its providers load through it.
func installMountGate(report *MountReport, cfg *config.Config) {
	mountGateMu.Lock()
	defer mountGateMu.Unlock()
	activeMountGate, mountGateRefused, mountRuntimeCheck, mountRuntimeError = nil, nil, nil, nil
	if report != nil && len(report.Sources) > 0 {
		activeMountGate, mountRuntimeCheck = report.gate, report.gate
	}
	mountApplyExpected = cfg
}

// A config Flash did not install its gate for, as an external controller's
// reload: the last apply's allowances say nothing of it. One holding mounts
// is gated closed and checked as it runs; one without has nothing to gate.
func beforeMountApply(cfg *config.Config) {
	mountGateMu.Lock()
	defer mountGateMu.Unlock()
	if cfg != nil && cfg == mountApplyExpected {
		mountApplyExpected = nil
		return
	}
	mountApplyExpected = nil
	activeMountGate, mountGateRefused, mountRuntimeCheck, mountRuntimeError = nil, nil, nil, nil
	if cfg == nil {
		return
	}
	for name := range cfg.Providers {
		if flashguard.IsMountProvider(name) {
			gate := &mountGate{external: true, reader: &ruleReader{suffixes: tailnetSuffixes()}}
			activeMountGate, mountRuntimeCheck = gate, gate
			return
		}
	}
}

func takeMountRuntimeError() error {
	mountGateMu.Lock()
	defer mountGateMu.Unlock()
	err := mountRuntimeError
	mountRuntimeCheck, mountRuntimeError = nil, nil
	return err
}

// The gate refuses before the provider swaps its content, so what it held
// stays loaded.
type mountUpdateRefused struct {
	name, what string
}

func (e *mountUpdateRefused) Error() string {
	return fmt.Sprintf("%s now %s while subscription nodes are mounted; apply the profile again to take it", e.name, e.what)
}

func refuseMountUpdate(name, what string) error {
	if !slices.Contains(mountGateRefused, name) {
		mountGateRefused = append(mountGateRefused, name)
		slices.Sort(mountGateRefused)
	}
	return &mountUpdateRefused{name: name, what: what}
}

// Every dialer-proxy the entries name, under any spelling, and the built
// nodes' own, which an override set.
func gatedDialers(mappings []map[string]any, proxies []constant.Proxy) []string {
	var dialers []string
	for _, mapping := range mappings {
		dialers = append(dialers, proxyOptionValues(mapping, "dialer-proxy")...)
	}
	for _, proxy := range proxies {
		if dialer := proxy.ProxyInfo().DialerProxy; dialer != "" {
			dialers = append(dialers, dialer)
		}
	}
	return dialers
}

func gatedTailscale(mappings []map[string]any, proxies []constant.Proxy) bool {
	for _, mapping := range mappings {
		if kind, _ := mapping["type"].(string); strings.EqualFold(kind, "tailscale") {
			return true
		}
	}
	return slices.ContainsFunc(proxies, func(proxy constant.Proxy) bool { return proxy.Type() == constant.Tailscale })
}

// A mount provider's own nodes are dropped and guarded where they load.
func gateMountProxies(name string, mappings []map[string]any, proxies []constant.Proxy) error {
	mountGateMu.Lock()
	defer mountGateMu.Unlock()
	gate := activeMountGate
	if gate == nil || flashguard.IsMountProvider(name) {
		return nil
	}
	dialers := gatedDialers(mappings, proxies)
	tailscale := gatedTailscale(mappings, proxies)
	if gate.external {
		switch {
		case tailscale:
			return refuseMountUpdate(name, "holds a Tailscale node")
		case len(dialers) > 0:
			return refuseMountUpdate(name, "dials through another proxy")
		}
		return nil
	}
	allowed, known := gate.providers[name]
	if tailscale && !allowed.tailscale {
		return refuseMountUpdate(name, "holds a Tailscale node")
	}
	if (!known || !allowed.relay) && slices.ContainsFunc(dialers, gate.relay.reaches) {
		return refuseMountUpdate(name, "relays through Tailscale")
	}
	if slices.ContainsFunc(dialers, func(dialer string) bool { return !gate.dialSafe[dialer] }) {
		return refuseMountUpdate(name, "dials through a group that may take subscription nodes")
	}
	return nil
}

// The set is read again from what was loaded, with every rule recorded as
// written: a classical set's built rules cannot be read back.
func gateMountRuleSet(name string, _ any, raw []byte, behavior cp.RuleBehavior, format cp.RuleFormat) error {
	mountGateMu.Lock()
	defer mountGateMu.Unlock()
	gate := activeMountGate
	if gate == nil || !gate.external && !gate.ruleSets[name] {
		return nil
	}
	strategy, err := rp.ParseRuleSet(raw, behavior, format, recordRule)
	if err != nil || gate.reader.strategyReach(strategy) != ruleMisses {
		return refuseMountUpdate(name, "sends Tailscale addresses or names")
	}
	return nil
}

// Every group a Tailscale route may take, as the running config holds them,
// and every proxy's dialer-proxy, must lead to no mounted node before the
// tunnel carries a connection. A config applied from elsewhere is checked
// alike, from what it built alone, and held if it fails.
func checkMountRuntimeBeforeRunning() error {
	mountGateMu.Lock()
	gate := mountRuntimeCheck
	mountGateMu.Unlock()
	if gate == nil {
		return nil
	}
	proxies := tunnel.Proxies()
	err := mountRuntimeViolation(proxies, gate.reach)
	if err == nil {
		err = mountDialerViolation(proxies, tunnel.Providers())
	}
	mountGateMu.Lock()
	defer mountGateMu.Unlock()
	if gate.external {
		mountRuntimeCheck = nil
		if err != nil {
			logError("a config applied from elsewhere reaches a mounted node, every connection is held: %v", err)
		}
		return err
	}
	mountRuntimeError = err
	return err
}

func mountRuntimeViolation(proxies map[string]constant.Proxy, static map[string]string) error {
	guarded := tailscaleHolders(proxies)
	delete(guarded, globalProxyName)
	for name := range static {
		guarded[name] = true
	}
	for _, name := range sortedKeys(guarded) {
		if member := mountedMemberOf(proxies, name, map[string]bool{}); member != "" {
			return fmt.Errorf("Tailscale traffic through %s could reach the mounted node %s", name, member)
		}
	}
	return nil
}

// The groups holding a Tailscale node, a provider's too, at any depth.
func tailscaleHolders(proxies map[string]constant.Proxy) map[string]bool {
	holders := map[string]bool{}
	var holds func(name string, visiting map[string]bool) bool
	holds = func(name string, visiting map[string]bool) bool {
		group, ok := adapterAs[outboundgroup.ProxyGroup](proxies[name])
		if !ok || visiting[name] {
			return false
		}
		visiting[name] = true
		return slices.ContainsFunc(group.Proxies(), func(member constant.Proxy) bool {
			return member.Type() == constant.Tailscale || holds(member.Name(), visiting)
		})
	}
	for name := range proxies {
		if holds(name, map[string]bool{}) {
			holders[name] = true
		}
	}
	return holders
}

// A proxy that dials through a mounted node may keep a session on it that
// carries later connections, a tailnet one too, without asking it again.
func mountDialerViolation(proxies map[string]constant.Proxy, providers map[string]cp.ProxyProvider) error {
	check := func(proxy constant.Proxy) error {
		info := proxy.ProxyInfo()
		if info.DialerProxy == "" || flashguard.IsMountProvider(info.ProviderName) {
			return nil
		}
		if member := mountedMemberOf(proxies, info.DialerProxy, map[string]bool{}); member != "" {
			return fmt.Errorf("%s dials through %s, which could take the mounted node %s", proxy.Name(), info.DialerProxy, member)
		}
		return nil
	}
	for _, name := range sortedKeys(proxies) {
		if err := check(proxies[name]); err != nil {
			return err
		}
	}
	for _, name := range sortedKeys(providers) {
		if flashguard.IsMountProvider(name) {
			continue
		}
		for _, proxy := range providers[name].Proxies() {
			if err := check(proxy); err != nil {
				return err
			}
		}
	}
	return nil
}

// The first mounted node a connection through name may take: a member, at
// any depth, or one down a member's or name's own dialer-proxy chain. A
// mount provider a group uses counts before its nodes have loaded.
func mountedMemberOf(proxies map[string]constant.Proxy, name string, seen map[string]bool) string {
	proxy, ok := proxies[name]
	if !ok || seen[name] {
		return ""
	}
	seen[name] = true
	group, isGroup := adapterAs[outboundgroup.ProxyGroup](proxy)
	if !isGroup {
		return mountedMemberOf(proxies, proxy.ProxyInfo().DialerProxy, seen)
	}
	for _, member := range group.Proxies() {
		if flashguard.IsMountProvider(member.ProxyInfo().ProviderName) {
			return member.Name()
		}
		next := member.ProxyInfo().DialerProxy
		if _, nested := adapterAs[outboundgroup.ProxyGroup](member); nested {
			next = member.Name()
		}
		if found := mountedMemberOf(proxies, next, seen); found != "" {
			return found
		}
	}
	for _, provider := range group.Providers() {
		if flashguard.IsMountProvider(provider.Name()) {
			return provider.Name()
		}
	}
	return ""
}

// Every name under a tailnet suffix a routing memory keeps, and ts.net, is
// one a mounted node refuses at dial time.
func refreshGuardSuffixes(extra ...string) {
	flashguard.SetSuffixes(append(tailnetSuffixes(), extra...))
}

func mountGateState() []string {
	mountGateMu.Lock()
	defer mountGateMu.Unlock()
	return slices.Clone(mountGateRefused)
}
