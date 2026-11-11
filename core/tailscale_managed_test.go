//go:build with_gvisor && !no_tailscale

package core

import (
	"context"
	"errors"
	"net/netip"
	"os"
	"path/filepath"
	"slices"
	"testing"

	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/adapter/outboundgroup"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
)

// Shaped like a LiteCN-style subscription: include-all groups, a group that
// takes the name the panel would use, and a private-range DIRECT rule ahead
// of everything else.
const managedTestProfile = `mode: rule
proxies:
  - {name: HK 01, type: socks5, server: 127.0.0.1, port: 1}
  - {name: JP 01, type: socks5, server: 127.0.0.1, port: 2}
proxy-groups:
  - {name: Proxy, type: select, include-all: true}
  - {name: Auto, type: url-test, include-all-proxies: true, url: "http://127.0.0.1:1/", interval: 0}
  - {name: Tailscale, type: select, proxies: [DIRECT]}
rule-providers:
  Private:
    type: inline
    behavior: ipcidr
    payload: [10.0.0.0/8, 100.64.0.0/10, 192.168.0.0/16, "fd7a:115c:a1e0::/48"]
rules:
  - RULE-SET,Private,DIRECT,no-resolve
  - DOMAIN-SUFFIX,local,DIRECT
  - MATCH,Proxy
`

func applyManagedProfile(t *testing.T, setup *TailscaleSetup) string {
	t.Helper()
	home := t.TempDir()
	previous := C.Path.HomeDir()
	C.SetHomeDir(home)
	t.Cleanup(func() { C.SetHomeDir(previous) })
	resetTailscaleSetup(t)
	withCurrentConfig(t, nil)
	keepTunnel(t)
	t.Cleanup(func() {
		closeTailscaleUpTo(tailscaleGenerationMark())
		tailscaleActiveTable.Store(nil)
		tailscaleRouting = &tailscaleRouter{}
	})
	if err := os.WriteFile(filepath.Join(home, "config.yaml"), []byte(managedTestProfile), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := applyConfig(&SetupParams{Tailscale: setup}); err != nil {
		t.Fatal(err)
	}
	return home
}

func managedNode(t *testing.T, id string) *outbound.Tailscale {
	t.Helper()
	for _, node := range currentTailscaleNodes() {
		if tailscaleManagedIDOf(node) == id {
			return node
		}
	}
	t.Fatalf("no managed node %q", id)
	return nil
}

func TestTailscaleManagedNodeIsInjectedAfterParse(t *testing.T) {
	exit := "100.64.0.9"
	home := applyManagedProfile(t, &TailscaleSetup{
		ProfileID: 7,
		Managed: []TailscaleManagedSetup{
			{ID: "a1", Attached: true, ExitNode: &exit},
			{ID: "b2"},
		},
	})

	proxies := tunnel.Proxies()
	first, second := managedNode(t, "a1"), managedNode(t, "b2")
	if first.Name() != "Tailscale (FlClash)" || second.Name() != "Tailscale (FlClash 2)" {
		t.Fatalf("names = %q, %q", first.Name(), second.Name())
	}
	if proxies["Tailscale"].Type() != C.Selector {
		t.Fatal("the profile's own Tailscale group was replaced")
	}
	if first.Option().ExitNode != exit {
		t.Fatalf("exit node = %q", first.Option().ExitNode)
	}
	if !first.ExplicitStateDir() || tailscaleManagedKeyOf(first.Option().StateDir) != tailscaleManagedKey(7, "a1", "") {
		t.Fatalf("state dir = %q", first.Option().StateDir)
	}
	for _, group := range []string{"Proxy", "Auto", "GLOBAL"} {
		members := proxies[group].Adapter().(outboundgroup.ProxyGroup).Proxies()
		if slices.ContainsFunc(members, func(p C.Proxy) bool { return p.Name() == first.Name() || p.Name() == second.Name() }) {
			t.Fatalf("group %s holds a panel-added node", group)
		}
	}

	rules := tunnel.Rules()
	if rules[0].Payload() != "tailscale-managed-domains" || rules[1].Payload() != "tailscale-managed-addresses" {
		t.Fatalf("rules start with %s / %s", rules[0].Payload(), rules[1].Payload())
	}
	if rules[2].Payload() != "Private" || rules[2].Adapter() != "DIRECT" {
		t.Fatalf("the profile's first rule moved: %s", rules[2].Payload())
	}
	matched, proxy := rules[1].Match(&C.Metadata{DstIP: netip.MustParseAddr("100.100.1.1")}, C.RuleMatchHelper{})
	if !matched || proxy != tailscaleRejectProxy {
		t.Fatalf("an address no account owns -> %v %q, want REJECT ahead of the DIRECT rule", matched, proxy)
	}
	if matched, _ := rules[1].Match(&C.Metadata{DstIP: netip.MustParseAddr("192.168.1.1")}, C.RuleMatchHelper{}); matched {
		t.Fatal("a private address left the profile's rules")
	}

	written, err := os.ReadFile(filepath.Join(home, "config.yaml"))
	if err != nil || string(written) != managedTestProfile {
		t.Fatal("config.yaml changed")
	}

	var described *TailscaleNode
	for _, node := range handleTailscaleNodes() {
		if node.ManagedID == "a1" {
			described = &node
		}
	}
	if described == nil || described.StateDirMode != "managed" || !described.Attached || described.Settings.ExitNode.Source != tailscaleSourceOverride {
		t.Fatalf("described = %+v", described)
	}

	if got, err := boundTailscale("", "a1", first.Generation()); err != nil || got != first {
		t.Fatalf("bound by managed ID = %v, %v", got, err)
	}
	metadata := &C.Metadata{NetWork: C.TCP, DstIP: netip.MustParseAddr("100.64.0.2"), DstPort: 80}
	if _, err := first.DialContext(context.Background(), metadata); !errors.Is(err, errTailscaleNeedsLogin) {
		t.Fatalf("dial through a managed node with no login = %v", err)
	}
	if first.Started() {
		t.Fatal("traffic started a managed node with no login")
	}

	report, err := handleTailscaleRoutes(TailscaleRoutesParams{ProfileID: 7})
	if err != nil || !report.Active || report.Complete || len(report.Accounts) != 1 {
		t.Fatalf("routes = %+v, %v", report, err)
	}
	if _, err := handleTailscaleRoutes(TailscaleRoutesParams{ProfileID: 8}); !errors.Is(err, errTailscaleProfileNotCurrent) {
		t.Fatalf("routes of another profile = %v", err)
	}
}

func TestTailscaleManagedDraftAddsNoRules(t *testing.T) {
	applyManagedProfile(t, &TailscaleSetup{ProfileID: 7, Managed: []TailscaleManagedSetup{{ID: "a1"}}})
	managedNode(t, "a1")
	if rules := tunnel.Rules(); rules[0].Payload() != "Private" {
		t.Fatalf("a draft added rules: %s", rules[0].Payload())
	}
	if tailscaleActiveTable.Load() != nil {
		t.Fatal("a draft activated the routing")
	}
}

func TestTailscaleManagedSettingsAndGuardFollowTheID(t *testing.T) {
	applyManagedProfile(t, &TailscaleSetup{ProfileID: 7, Managed: []TailscaleManagedSetup{{ID: "a1", Attached: true, LoggedOut: true}}})
	node := managedNode(t, "a1")
	if !tailscaleLoggedOut(tailscaleRefOfNode(node)) {
		t.Fatal("guard not read by managed key")
	}
	if tailscaleLoggedOut(tailscaleRef{name: node.Name()}) {
		t.Fatal("guard leaked to a named node of the same name")
	}
	if _, err := handleTailscaleStart(TailscaleNodeParams{ManagedID: "a1", Generation: node.Generation()}); !errors.Is(err, errTailscaleLoggedOut) {
		t.Fatalf("start of a signed-out managed node = %v", err)
	}
	report, _ := handleTailscaleRoutes(TailscaleRoutesParams{ProfileID: 7})
	if !report.Accounts[0].LoggedOut || report.Complete != true {
		t.Fatalf("a signed-out account counts as loading: %+v", report)
	}
}

func TestTailscaleManagedFailedLoadInjectsNothing(t *testing.T) {
	home := t.TempDir()
	previous := C.Path.HomeDir()
	C.SetHomeDir(home)
	t.Cleanup(func() { C.SetHomeDir(previous) })
	resetTailscaleSetup(t)
	withCurrentConfig(t, nil)
	keepTunnel(t)
	if err := os.WriteFile(filepath.Join(home, "config.yaml"), []byte("proxies: [unterminated\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	_ = applyConfig(&SetupParams{Tailscale: &TailscaleSetup{ProfileID: 7, Managed: []TailscaleManagedSetup{{ID: "a1", Attached: true}}}})
	for _, node := range currentTailscaleNodes() {
		if tailscaleIsManaged(node) {
			t.Fatal("a failed load injected a managed node")
		}
	}
	if tailscaleActiveTable.Load() != nil {
		t.Fatal("a failed load left managed routing on")
	}
}

// End to end on the LiteCN-like profile: two accounts, one with a device list,
// the private rule-set behind the managed rules.
func TestTailscaleManagedRoutesAheadOfThePrivateRuleSet(t *testing.T) {
	applyManagedProfile(t, &TailscaleSetup{ProfileID: 7, Managed: []TailscaleManagedSetup{
		{ID: "a1", Attached: true},
		{ID: "b2", Attached: true},
	}})
	first := managedNode(t, "a1")
	tailscaleManagedMu.Lock()
	tailscaleManagedNodes[first].live = liveAccount("a1", "u1", "tail1.ts.net",
		peer("nas", "nas.tail1.ts.net", "100.101.1.1", "fd7a:115c:a1e0::1")).Live
	tailscaleManagedMu.Unlock()
	refreshTailscaleRoutes()

	rules := tunnel.Rules()
	match := func(metadata *C.Metadata) string {
		for _, rule := range rules {
			if matched, proxy := rule.Match(metadata, C.RuleMatchHelper{}); matched {
				return proxy
			}
		}
		return ""
	}
	// b2 has not reported, so nothing new binds yet.
	if got := match(&C.Metadata{DstIP: netip.MustParseAddr("100.101.1.1")}); got != tailscaleRejectProxy {
		t.Fatalf("before every account reported: %q", got)
	}

	second := managedNode(t, "b2")
	tailscaleManagedMu.Lock()
	tailscaleManagedNodes[second].live = liveAccount("b2", "u2", "tail2.ts.net").Live
	tailscaleManagedMu.Unlock()
	refreshTailscaleRoutes()

	cases := []struct {
		metadata *C.Metadata
		want     string
	}{
		{&C.Metadata{DstIP: netip.MustParseAddr("100.101.1.1")}, first.Name()},
		{&C.Metadata{DstIP: netip.MustParseAddr("fd7a:115c:a1e0::1")}, first.Name()},
		{&C.Metadata{Host: "nas.tail1.ts.net"}, first.Name()},
		{&C.Metadata{DstIP: netip.MustParseAddr("100.101.9.9")}, tailscaleRejectProxy},
		{&C.Metadata{DstIP: netip.MustParseAddr("192.168.1.1")}, "DIRECT"},
		{&C.Metadata{Host: "example.com", DstIP: netip.MustParseAddr("93.184.216.34")}, "Proxy"},
	}
	for _, c := range cases {
		if got := match(c.metadata); got != c.want {
			t.Errorf("%v -> %q, want %q", c.metadata, got, c.want)
		}
	}

	report, err := handleTailscaleRoutes(TailscaleRoutesParams{ProfileID: 7})
	if err != nil || !report.Complete || targetState(report, tailscaleTargetFQDN, "nas.tail1.ts.net") != tailscaleRouteBound {
		t.Fatalf("routes = %+v, %v", report, err)
	}
}
