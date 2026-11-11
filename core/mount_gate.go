package core

import (
	"fmt"
	"slices"
	"strings"
	"sync"

	"github.com/metacubex/mihomo/adapter/outboundgroup"
	"github.com/metacubex/mihomo/adapter/provider"
	"github.com/metacubex/mihomo/constant"
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
}

type gateAllowance struct {
	tailscale bool
	relay     bool
}

func newMountGate(base *mountBase, reader *ruleReader, relay *mountRelay, reach map[string]string) *mountGate {
	gate := &mountGate{providers: map[string]gateAllowance{}, ruleSets: map[string]bool{}, relay: relay, reader: reader, reach: reach}
	for name, p := range base.providers {
		if p.gated && !p.unknown {
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

var (
	mountGateMu      sync.Mutex
	activeMountGate  *mountGate
	mountGateRefused []string
	// Set while a mounted config is applied; the executor holds the tunnel
	// back from running until it is checked.
	mountRuntimeCheck *mountGate
	mountRuntimeError error
)

func init() {
	provider.ProxiesGate = gateMountProxies
	rp.RuleSetGate = gateMountRuleSet
	executor.FlashBeforeRunning = checkMountRuntimeBeforeRunning
}

// Installed before the config is applied: its providers load through it.
func installMountGate(report *MountReport) {
	mountGateMu.Lock()
	defer mountGateMu.Unlock()
	activeMountGate, mountGateRefused, mountRuntimeCheck, mountRuntimeError = nil, nil, nil, nil
	if report != nil && len(report.Sources) > 0 {
		activeMountGate, mountRuntimeCheck = report.gate, report.gate
	}
}

func takeMountRuntimeError() error {
	mountGateMu.Lock()
	defer mountGateMu.Unlock()
	err := mountRuntimeError
	mountRuntimeCheck, mountRuntimeError = nil, nil
	return err
}

func refuseMountUpdate(name, what string) error {
	if !slices.Contains(mountGateRefused, name) {
		mountGateRefused = append(mountGateRefused, name)
		slices.Sort(mountGateRefused)
	}
	return fmt.Errorf("%s now %s while subscription nodes are mounted; apply the profile again to take it", name, what)
}

func gateMountProxies(name string, mappings []map[string]any) error {
	mountGateMu.Lock()
	defer mountGateMu.Unlock()
	gate := activeMountGate
	if gate == nil {
		return nil
	}
	allowed, gated := gate.providers[name]
	if !gated {
		return nil
	}
	for _, mapping := range mappings {
		kind, _ := mapping["type"].(string)
		if !allowed.tailscale && strings.EqualFold(kind, "tailscale") {
			return refuseMountUpdate(name, "holds a Tailscale node")
		}
		if !allowed.relay && slices.ContainsFunc(proxyOptionValues(mapping, "dialer-proxy"), gate.relay.reaches) {
			return refuseMountUpdate(name, "relays through Tailscale")
		}
	}
	return nil
}

func gateMountRuleSet(name string, strategy any) error {
	mountGateMu.Lock()
	defer mountGateMu.Unlock()
	gate := activeMountGate
	if gate == nil || !gate.ruleSets[name] {
		return nil
	}
	if gate.reader.strategyReach(strategy) != ruleMisses {
		return refuseMountUpdate(name, "sends Tailscale addresses or names")
	}
	return nil
}

// Every group a Tailscale route may take, as the running config holds them,
// must be free of mounted nodes before the tunnel carries a connection.
func checkMountRuntimeBeforeRunning() error {
	mountGateMu.Lock()
	gate := mountRuntimeCheck
	mountGateMu.Unlock()
	if gate == nil {
		return nil
	}
	err := mountRuntimeViolation(tunnel.Proxies(), gate.reach)
	mountGateMu.Lock()
	mountRuntimeError = err
	mountGateMu.Unlock()
	return err
}

func mountRuntimeViolation(proxies map[string]constant.Proxy, static map[string]string) error {
	_, reach := tailscaleProfileAdapters(proxies)
	delete(reach, globalProxyName)
	guarded := make([]string, 0, len(reach)+len(static))
	for name := range reach {
		guarded = append(guarded, name)
	}
	for name := range static {
		guarded = append(guarded, name)
	}
	slices.Sort(guarded)
	for _, name := range slices.Compact(guarded) {
		if member := mountedMemberOf(proxies, name, map[string]bool{}); member != "" {
			return fmt.Errorf("Tailscale traffic through %s could reach the mounted node %s", name, member)
		}
	}
	return nil
}

func mountedMemberOf(proxies map[string]constant.Proxy, name string, seen map[string]bool) string {
	group, ok := adapterAs[outboundgroup.ProxyGroup](proxies[name])
	if !ok || seen[name] {
		return ""
	}
	seen[name] = true
	for _, member := range group.Proxies() {
		if strings.HasPrefix(member.ProxyInfo().ProviderName, mountProviderPrefix) {
			return member.Name()
		}
		if found := mountedMemberOf(proxies, member.Name(), seen); found != "" {
			return found
		}
	}
	return ""
}

func mountGateState() []string {
	mountGateMu.Lock()
	defer mountGateMu.Unlock()
	return slices.Clone(mountGateRefused)
}
