package core

import (
	"fmt"
	"slices"
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

type mountGate struct {
	external bool
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
			gate := &mountGate{external: true}
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

func gateMountProxies(_ string, _ []map[string]any, _ []constant.Proxy) error {
	return nil
}

func gateMountRuleSet(_ string, _ any, _ []byte, _ cp.RuleBehavior, _ cp.RuleFormat) error {
	return nil
}

func checkMountRuntimeBeforeRunning() error {
	mountGateMu.Lock()
	gate := mountRuntimeCheck
	mountGateMu.Unlock()
	if gate == nil {
		return nil
	}
	proxies := tunnel.Proxies()
	err := mountDialerViolation(proxies, tunnel.Providers())
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

func mountRuntimeViolation(_ map[string]constant.Proxy, _ map[string]string) error {
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
			if isTailscaleExitGroup(member) {
				return false
			}
			return member.Type() == constant.Tailscale || holds(member.Name(), visiting)
		})
	}
	for name, proxy := range proxies {
		if !isTailscaleExitGroup(proxy) && holds(name, map[string]bool{}) {
			holders[name] = true
		}
	}
	return holders
}

// Validate introduced dependencies against actual filtered provider membership.
func mountDialerViolation(proxies map[string]constant.Proxy, providers map[string]cp.ProxyProvider) error {
	all := make(map[string]constant.Proxy, len(proxies))
	for name, proxy := range proxies {
		all[name] = proxy
	}
	var roots []string
	for _, pd := range providers {
		for _, proxy := range pd.Proxies() {
			all[proxy.Name()] = proxy
			if flashguard.IsMountProvider(pd.Name()) {
				roots = append(roots, proxy.Name())
			}
		}
	}
	edges := map[string][]string{}
	for name, proxy := range all {
		if dialer := proxy.ProxyInfo().DialerProxy; dialer != "" {
			edges[name] = append(edges[name], dialer)
		}
		if group, ok := adapterAs[outboundgroup.ProxyGroup](proxy); ok {
			for _, member := range group.Proxies() {
				if member.Name() != name {
					edges[name] = append(edges[name], member.Name())
				}
			}
		}
	}
	return checkMountDependencies(edges, roots, func(name string) bool { return all[name] != nil })
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
