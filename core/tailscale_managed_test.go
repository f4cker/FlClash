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
	"time"

	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/adapter/outboundgroup"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
	"github.com/metacubex/tailscale/ipn"
	"github.com/metacubex/tailscale/tailcfg"
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
  - {name: Auto, type: select, include-all-proxies: true}
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
	return applyManagedProfileText(t, managedTestProfile, setup)
}

func applyManagedProfileText(t *testing.T, profile string, setup *TailscaleSetup) string {
	t.Helper()
	return applyManagedProfileHome(t, t.TempDir(), profile, setup)
}

func applyManagedProfileHome(t *testing.T, home, profile string, setup *TailscaleSetup) string {
	t.Helper()
	previous := C.Path.HomeDir()
	C.SetHomeDir(home)
	t.Cleanup(func() { C.SetHomeDir(previous) })
	resetTailscaleSetup(t)
	withCurrentConfig(t, nil)
	keepTunnel(t)
	t.Cleanup(func() {
		closeTailscaleUpTo(tailscaleGenerationMark())
		tailscaleManagedMu.Lock()
		tailscaleRunningSlot, tailscaleStagedSlot, tailscaleStaged = nil, nil, false
		tailscaleRunningRun, tailscaleStagedRun = nil, nil
		tailscaleManagedNameClash = map[string]bool{}
		tailscaleManagedMu.Unlock()
		tailscaleRouting = &tailscaleRouter{}
	})
	if err := os.WriteFile(filepath.Join(home, "config.yaml"), []byte(profile), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := applyConfig(&SetupParams{Tailscale: setup}); err != nil {
		t.Fatal(err)
	}
	return home
}

func runningTailscaleTable() *tailscaleRouteTable {
	tailscaleManagedMu.Lock()
	slot := tailscaleRunningSlot
	tailscaleManagedMu.Unlock()
	if slot == nil {
		return nil
	}
	return slot.Load()
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
	if first.Name() != "Tailscale (Flash)" || second.Name() != "Tailscale (Flash 2)" {
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
	if runningTailscaleTable() != nil {
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
	if !report.Accounts[0].LoggedOut || report.Complete {
		t.Fatalf("a signed-out account whose devices were never read counts as loaded: %+v", report)
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
	if runningTailscaleTable() != nil {
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

func matchManagedRules(metadata *C.Metadata) string {
	for _, rule := range tunnel.Rules() {
		if matched, proxy := rule.Match(metadata, C.RuleMatchHelper{}); matched {
			return proxy
		}
	}
	return ""
}

func TestTailscaleManagedFailedBuildStillProtects(t *testing.T) {
	build := buildTailscaleManagedProxy
	buildTailscaleManagedProxy = func(map[string]any) (C.Proxy, error) { return nil, errors.New("no node") }
	t.Cleanup(func() { buildTailscaleManagedProxy = build })
	applyManagedProfile(t, &TailscaleSetup{ProfileID: 7, Managed: []TailscaleManagedSetup{{ID: "a1", Attached: true}}})
	if got := matchManagedRules(&C.Metadata{DstIP: netip.MustParseAddr("100.101.1.1")}); got != tailscaleRejectProxy {
		t.Fatalf("an address while the only account failed to build -> %q, want REJECT", got)
	}
	if got := matchManagedRules(&C.Metadata{Host: "nas.tail1.ts.net"}); got != tailscaleRejectProxy {
		t.Fatalf("a ts.net name -> %q", got)
	}
}

func TestTailscaleManagedUnknownRecordsKeepProtection(t *testing.T) {
	home := t.TempDir()
	previous := C.Path.HomeDir()
	C.SetHomeDir(home)
	t.Cleanup(func() { C.SetHomeDir(previous) })
	kept := newTailscaleRouteMemory()
	kept.Bindings = []tailscaleRouteBinding{{
		Target: TailscaleRouteTarget{Kind: tailscaleTargetIP, Value: "100.101.1.1"},
		Owner:  TailscaleRouteOwner{Kind: tailscaleOwnerManaged, ID: "a1"},
	}}
	if err := saveTailscaleRouteMemory(7, kept); err != nil {
		t.Fatal(err)
	}
	before, _ := os.ReadFile(tailscaleRoutesPath(7))
	applyManagedProfileHome(t, home, managedTestProfile, &TailscaleSetup{ProfileID: 7, ManagedUnknown: true})
	if got := matchManagedRules(&C.Metadata{DstIP: netip.MustParseAddr("100.101.1.1")}); got != tailscaleRejectProxy {
		t.Fatalf("a kept target while the accounts are unknown -> %q", got)
	}
	if got := matchManagedRules(&C.Metadata{DstIP: netip.MustParseAddr("100.64.9.9")}); got != tailscaleRejectProxy {
		t.Fatalf("the range while the accounts are unknown -> %q", got)
	}
	if after, _ := os.ReadFile(tailscaleRoutesPath(7)); string(after) != string(before) {
		t.Fatal("the kept routing was rewritten while the accounts were unknown")
	}
}

func TestTailscaleForgetRoutesOfTheRunningProfileWritesNothing(t *testing.T) {
	applyManagedProfile(t, &TailscaleSetup{ProfileID: 7, Managed: []TailscaleManagedSetup{{ID: "a1", Attached: true}}})
	node := managedNode(t, "a1")
	tailscaleManagedMu.Lock()
	tailscaleManagedNodes[node].live = liveAccount("a1", "u1", "tail1.ts.net", peer("nas", "", "100.101.1.1")).Live
	tailscaleManagedMu.Unlock()
	refreshTailscaleRoutes()
	if _, err := os.Stat(tailscaleRoutesPath(7)); err != nil {
		t.Fatalf("routes not kept: %v", err)
	}
	if result, err := handleTailscaleForgetRoutes(TailscaleRoutesParams{ProfileID: 7}); err != nil || result.Outcome != tailscaleOutcomeConfirmed {
		t.Fatalf("forget = %+v, %v", result, err)
	}
	refreshTailscaleRoutes()
	if _, err := os.Stat(tailscaleRoutesPath(7)); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("the routes of a forgotten profile came back: %v", err)
	}
}

func TestTailscaleManagedNameIsStableAndAvoidsProviderNodes(t *testing.T) {
	profile := managedTestProfile + `proxy-providers:
  Sub:
    type: inline
    payload:
      - {name: "Tailscale (Flash)", type: socks5, server: 127.0.0.1, port: 3}
`
	setup := &TailscaleSetup{ProfileID: 7, Managed: []TailscaleManagedSetup{
		{ID: "a1", Name: "Tailscale (Flash)", Attached: true},
		{ID: "b2", Name: "Tailscale (Flash 2)", Attached: true},
	}}
	applyManagedProfileText(t, profile, setup)
	if err := applyConfig(&SetupParams{Tailscale: setup}); err != nil {
		t.Fatal(err)
	}
	if name := managedNode(t, "b2").Name(); name != "Tailscale (Flash 2)" {
		t.Fatalf("b2 = %q, want the name the host keeps for it", name)
	}
	first := managedNode(t, "a1").Name()
	for _, pd := range tunnel.Providers() {
		for _, proxy := range pd.Proxies() {
			if proxy.Name() == first {
				t.Fatalf("a1 shares %q with a node of %s", first, pd.Name())
			}
		}
	}
}

func TestTailscaleManagedForgetRacesTheWatcher(t *testing.T) {
	applyManagedProfile(t, &TailscaleSetup{ProfileID: 7, Managed: []TailscaleManagedSetup{{ID: "a1", Attached: true}}})
	node := managedNode(t, "a1")
	key := tailscaleManagedKey(7, "a1", "")
	for range 50 {
		tailscaleManagedMu.Lock()
		tailscaleManagedNodes[node] = &tailscaleManagedNode{key: key}
		tailscaleManagedMu.Unlock()
		done := make(chan struct{})
		go func() {
			watchTailscaleManaged(node, ipn.Running.String())
			close(done)
		}()
		forgetTailscaleManaged(node)
		<-done
	}
	tailscaleManagedMu.Lock()
	tailscaleManagedNodes[node] = &tailscaleManagedNode{key: key}
	tailscaleManagedMu.Unlock()
}

func TestTailscaleManagedWatcherExitDropsItsList(t *testing.T) {
	applyManagedProfile(t, &TailscaleSetup{ProfileID: 7, Managed: []TailscaleManagedSetup{{ID: "a1", Attached: true}}})
	node := managedNode(t, "a1")
	tailscaleManagedMu.Lock()
	entry := tailscaleManagedNodes[node]
	entry.live = liveAccount("a1", "u1", "").Live
	tailscaleManagedMu.Unlock()
	watchTailscaleManaged(node, ipn.Running.String())
	deadline := time.Now().Add(5 * time.Second)
	for {
		tailscaleManagedMu.Lock()
		watching, live := entry.watching, entry.live
		tailscaleManagedMu.Unlock()
		if !watching && live == nil {
			break
		}
		if time.Now().After(deadline) {
			t.Fatal("a watcher that stopped left its list counted as loaded")
		}
		time.Sleep(10 * time.Millisecond)
	}
	report, _ := handleTailscaleRoutes(TailscaleRoutesParams{ProfileID: 7})
	if report.Complete {
		t.Fatal("routes complete without a live device list")
	}
}

func TestTailscaleManagedWatchSeesPeersOutsideTheNetmap(t *testing.T) {
	if err := ipn.ValidateNotifyWatchOpt(tailscaleDeviceWatch); err != nil {
		t.Fatal(err)
	}
	if tailscaleDeviceWatch&ipn.NotifyPeerChanges == 0 {
		t.Fatal("the watch does not ask for peer changes")
	}
	addr := netip.MustParseAddr("100.64.0.2")
	peer := &tailcfg.Node{
		Name:      "laptop.tail1.ts.net.",
		Addresses: []netip.Prefix{netip.PrefixFrom(addr, 32)},
		Hostinfo:  (&tailcfg.Hostinfo{Hostname: "laptop"}).View(),
	}
	empty := &tailscaleRouteNetmap{}
	listed := &tailscaleRouteNetmap{Peers: []tailscaleRoutePeer{{Name: "laptop", FQDN: "laptop.tail1.ts.net.", Addrs: []netip.Addr{addr}}}}
	cases := []struct {
		name string
		n    *ipn.Notify
		live *tailscaleRouteNetmap
		want bool
	}{
		{"a peer the list lacks", &ipn.Notify{PeersChanged: []*tailcfg.Node{peer}}, empty, true},
		{"a peer before any list", &ipn.Notify{PeersChanged: []*tailcfg.Node{peer}}, nil, true},
		{"a patch of a listed peer", &ipn.Notify{PeersChanged: []*tailcfg.Node{peer}}, listed, false},
		{"a removed peer", &ipn.Notify{PeersRemoved: []tailcfg.NodeID{1}}, listed, true},
		{"a new netmap", &ipn.Notify{SelfChange: &tailcfg.Node{}}, listed, true},
		{"nothing about peers", &ipn.Notify{}, empty, false},
	}
	for _, c := range cases {
		if got := tailscaleNotifyMovesDevices(c.n, c.live); got != c.want {
			t.Errorf("%s: re-read %v, want %v", c.name, got, c.want)
		}
	}
}

func TestTailscaleManagedTableWaitsForItsConfig(t *testing.T) {
	applyManagedProfile(t, &TailscaleSetup{ProfileID: 7, Managed: []TailscaleManagedSetup{{ID: "a1", Attached: true}}})
	running := runningTailscaleTable()
	if running == nil {
		t.Fatal("no running table")
	}
	setTailscaleSetup(&TailscaleSetup{ProfileID: 7, Managed: []TailscaleManagedSetup{
		{ID: "a1", Attached: true},
		{ID: "b2", Attached: true},
	}})
	cfg, err := loadConfig(runningConfigPath())
	if err != nil {
		t.Fatal(err)
	}
	injectTailscaleManaged(cfg)
	if runningTailscaleTable() != running {
		t.Fatal("the running rules read a table built for a config not applied yet")
	}
	staged, _ := cfg.Rules[1].Match(&C.Metadata{DstIP: netip.MustParseAddr("100.101.1.1")}, C.RuleMatchHelper{})
	if !staged {
		t.Fatal("the new config's rules have no table of their own")
	}
	publishTailscaleManaged()
	if runningTailscaleTable() == running {
		t.Fatal("the table was not handed over once the config ran")
	}
}

func TestTailscaleManagedStateTellsKeptFromForgotten(t *testing.T) {
	applyManagedProfile(t, &TailscaleSetup{ProfileID: 7, Managed: []TailscaleManagedSetup{{ID: "a1", Attached: true}}})
	node := managedNode(t, "a1")
	tailscaleManagedMu.Lock()
	tailscaleManagedNodes[node].live = liveAccount("a1", "u1", "tail1.ts.net", peer("nas", "", "100.101.1.1")).Live
	tailscaleManagedMu.Unlock()
	refreshTailscaleRoutes()
	before, _ := os.ReadFile(tailscaleRoutesPath(7))

	kept, err := handleTailscaleManagedState(TailscaleRoutesParams{ProfileID: 7})
	if err != nil || kept.Routes != tailscaleKeptOnDisk || kept.Digest == "" || !kept.Running ||
		kept.Forgotten || kept.Pending || kept.Protection != tailscaleProtectionActive {
		t.Fatalf("kept = %+v, %v", kept, err)
	}
	again, _ := handleTailscaleManagedState(TailscaleRoutesParams{ProfileID: 7})
	if *again != *kept {
		t.Fatalf("a second read moved: %+v", again)
	}
	if after, _ := os.ReadFile(tailscaleRoutesPath(7)); string(after) != string(before) {
		t.Fatal("reading the state rewrote the routing")
	}

	if _, err := handleTailscaleForgetRoutes(TailscaleRoutesParams{ProfileID: 7}); err != nil {
		t.Fatal(err)
	}
	gone, _ := handleTailscaleManagedState(TailscaleRoutesParams{ProfileID: 7})
	if gone.Routes != tailscaleKeptAbsent || gone.Digest != "" || !gone.Forgotten || gone.Pending ||
		gone.Protection != tailscaleProtectionActive {
		t.Fatalf("forgotten = %+v", gone)
	}
}

func TestTailscaleManagedStateFlagsWhatIsStillMoving(t *testing.T) {
	applyManagedProfile(t, &TailscaleSetup{ProfileID: 7, Managed: []TailscaleManagedSetup{{ID: "a1", Attached: true}}})
	r := tailscaleRouting
	r.mu.Lock()
	r.memory = r.memory.clone()
	r.memory.Accounts["a1"] = TailscaleRouteIdentity{UserID: "u1"}
	r.mu.Unlock()
	if state, _ := handleTailscaleManagedState(TailscaleRoutesParams{ProfileID: 7}); !state.Pending {
		t.Fatalf("an unsaved write = %+v", state)
	}

	refreshTailscaleRoutes()
	cfg, err := loadConfig(runningConfigPath())
	if err != nil {
		t.Fatal(err)
	}
	injectTailscaleManaged(cfg)
	if state, _ := handleTailscaleManagedState(TailscaleRoutesParams{ProfileID: 7}); !state.Pending {
		t.Fatalf("a config not in force yet = %+v", state)
	}
	publishTailscaleManaged()
	if state, _ := handleTailscaleManagedState(TailscaleRoutesParams{ProfileID: 7}); state.Pending {
		t.Fatalf("a settled config = %+v", state)
	}
}

func TestTailscaleManagedStateOfAnotherProfile(t *testing.T) {
	applyManagedProfile(t, &TailscaleSetup{ProfileID: 7})
	if state, _ := handleTailscaleManagedState(TailscaleRoutesParams{ProfileID: 9}); state.Routes != tailscaleKeptAbsent ||
		state.Running || state.Pending || state.Protection != tailscaleProtectionNone {
		t.Fatalf("absent = %+v", state)
	}
	memory := newTailscaleRouteMemory()
	memory.Bindings = []tailscaleRouteBinding{{
		Target:   TailscaleRouteTarget{Kind: tailscaleTargetIP, Value: "100.101.1.1"},
		Owner:    TailscaleRouteOwner{Kind: tailscaleOwnerManaged, ID: "a1"},
		Assigned: true,
	}}
	if err := saveTailscaleRouteMemory(9, memory); err != nil {
		t.Fatal(err)
	}
	kept, _ := handleTailscaleManagedState(TailscaleRoutesParams{ProfileID: 9})
	if kept.Routes != tailscaleKeptOnDisk || kept.Digest != tailscaleOwnershipDigest(memory) {
		t.Fatalf("kept = %+v", kept)
	}
	memory.Lists = map[string]tailscaleRouteList{"a1": {Suffix: "tail1.ts.net"}}
	if tailscaleOwnershipDigest(memory) != kept.Digest {
		t.Fatal("a device list moved the ownership digest")
	}
	memory.Bindings[0].Assigned = false
	if tailscaleOwnershipDigest(memory) == kept.Digest {
		t.Fatal("a dropped pin kept the digest")
	}
	if err := os.WriteFile(tailscaleRoutesPath(9), []byte("{"), 0o600); err != nil {
		t.Fatal(err)
	}
	if state, _ := handleTailscaleManagedState(TailscaleRoutesParams{ProfileID: 9}); state.Routes != tailscaleKeptUnreadable || state.Digest != "" {
		t.Fatalf("unreadable = %+v", state)
	}
}
