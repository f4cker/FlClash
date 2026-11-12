//go:build with_gvisor && !no_tailscale

package core

import (
	"net/netip"
	"os"
	"path/filepath"
	"reflect"
	"slices"
	"testing"

	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/adapter/outboundgroup"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
)

// Shaped like a regional subscription: fixed policy groups over region groups,
// a shared manual group, auto groups, a hidden one and a group already named
// like the exit group. Every name and address is made up.
const exitTestProfile = `mode: rule
proxies:
  - {name: HK 01, type: socks5, server: 127.0.0.1, port: 1}
  - {name: US 01, type: socks5, server: 127.0.0.1, port: 2}
proxy-groups:
  - {name: 国际媒体, type: select, proxies: [香港策略, 美国策略, 全球手动, DIRECT]}
  - {name: 全球手动, type: select, include-all: true}
  - {name: 香港策略, type: url-test, include-all: true, filter: HK}
  - {name: 美国策略, type: fallback, include-all: true, filter: US}
  - {name: 均衡, type: load-balance, proxies: [HK 01, US 01]}
  - {name: 仅香港, type: select, include-all: true, filter: HK, exclude-type: Direct}
  - {name: 仅日本, type: select, include-all: true, filter: JP}
  - {name: 隐藏, type: select, hidden: true, proxies: [DIRECT, REJECT]}
  - {name: Tailscale 出口, type: select, proxies: [DIRECT, HK 01]}
rules:
  - IP-CIDR,100.64.0.0/10,国际媒体,no-resolve
  - DOMAIN-SUFFIX,ts.net,全球手动
  - MATCH,国际媒体
`

func resetTailscaleExit(t *testing.T) {
	t.Helper()
	t.Cleanup(func() {
		tailscaleExitMu.Lock()
		tailscaleExitRunning, tailscaleExitStaged, tailscaleExitPending = nil, nil, false
		tailscaleExitMu.Unlock()
	})
}

func exitSetup(exits map[string]string) *TailscaleSetup {
	setup := &TailscaleSetup{ProfileID: 7}
	for _, id := range []string{"a1", "b2", "c3"} {
		account := TailscaleManagedSetup{ID: id, Attached: id != "c3"}
		if exit, ok := exits[id]; ok {
			account.ExitNode = &exit
			account.ExitLabel = "exit-" + id + " · " + id + "@example.com"
		}
		setup.Managed = append(setup.Managed, account)
	}
	return setup
}

func exitGroupMembers(t *testing.T, name string) []string {
	t.Helper()
	group, ok := adapterAs[outboundgroup.ProxyGroup](tunnel.Proxies()[name])
	if !ok {
		t.Fatalf("no group %s", name)
	}
	var names []string
	for _, member := range group.Proxies() {
		names = append(names, member.Name())
	}
	return names
}

func TestTailscaleExitGroupJoinsEveryManualGroupLast(t *testing.T) {
	resetTailscaleExit(t)
	home := applyManagedProfileText(t, exitTestProfile, exitSetup(map[string]string{"a1": "100.64.0.9", "c3": "100.64.0.8"}))
	const exit = "Tailscale 出口 (Flash)"

	for group, want := range map[string][]string{
		"国际媒体":         {"香港策略", "美国策略", "全球手动", "DIRECT", exit},
		"全球手动":         {"HK 01", "US 01", exit},
		"仅香港":          {"HK 01", exit},
		"仅日本":          {"COMPATIBLE", exit},
		"隐藏":           {"DIRECT", "REJECT", exit},
		"Tailscale 出口": {"DIRECT", "HK 01", exit},
		"香港策略":         {"HK 01"},
		"美国策略":         {"US 01"},
		"均衡":           {"HK 01", "US 01"},
		exit:           {"exit-a1 · a1@example.com"},
	} {
		if got := exitGroupMembers(t, group); !reflect.DeepEqual(got, want) {
			t.Errorf("%s = %q, want %q", group, got, want)
		}
	}
	if slices.Contains(exitGroupMembers(t, "GLOBAL"), exit) {
		t.Error("the built-in GLOBAL offers the exit group")
	}
	for group, now := range map[string]string{"国际媒体": "香港策略", "全球手动": "HK 01", "隐藏": "DIRECT", "Tailscale 出口": "DIRECT"} {
		if got := tunnel.Proxies()[group].Adapter().(outboundgroup.ProxyGroup).Now(); got != now {
			t.Errorf("%s now uses %q, want %q kept", group, got, now)
		}
	}
	if tunnel.Proxies()["Tailscale 出口"].Adapter().(outboundgroup.ProxyGroup).Hidden() {
		t.Error("the profile's own group changed")
	}

	data := handleGetProxies()
	if data.All[len(data.All)-1] != exit {
		t.Fatalf("groups end with %q", data.All[len(data.All)-1])
	}
	if _, ok := data.Proxies["exit-a1 · a1@example.com"]; !ok {
		t.Fatal("the exit node has no view")
	}
	if lookupProxy("exit-a1 · a1@example.com") == nil {
		t.Fatal("the exit node cannot be tested by name")
	}

	report, err := handleTailscaleExit(TailscaleRoutesParams{ProfileID: 7})
	if err != nil || report.State != tailscaleRuntimeConfirmed || report.Group != exit {
		t.Fatalf("report = %+v, %v", report, err)
	}
	var parents []string
	for _, parent := range report.Parents {
		parents = append(parents, parent.Name)
	}
	if want := []string{"国际媒体", "全球手动", "仅香港", "仅日本", "隐藏", "Tailscale 出口"}; !reflect.DeepEqual(parents, want) {
		t.Fatalf("parents = %q, want %q", parents, want)
	}
	if empty := report.Parents[3]; empty.Replacement != "" {
		t.Fatalf("a group left with its empty fallback falls back to %q", empty.Replacement)
	}
	if first := report.Parents[0]; first.Now != "香港策略" || first.Members[len(first.Members)-1] != exit || first.Replacement != "香港策略" {
		t.Fatalf("parent = %+v", first)
	}
	if len(report.Accounts) != 1 || report.Accounts[0].ID != "a1" || report.Accounts[0].State != tailscaleExitUnavailable || report.Accounts[0].Reason != outbound.TailscaleExitNeedsLogin {
		t.Fatalf("accounts = %+v", report.Accounts)
	}
	if report.Selected != "a1" {
		t.Fatalf("selected = %q", report.Selected)
	}

	written, err := os.ReadFile(filepath.Join(home, "config.yaml"))
	if err != nil || string(written) != exitTestProfile {
		t.Fatal("config.yaml changed")
	}
}

func TestTailscaleExitGroupStaysAwayWithoutAnExit(t *testing.T) {
	resetTailscaleExit(t)
	applyManagedProfileText(t, exitTestProfile, exitSetup(nil))
	if got := exitGroupMembers(t, "国际媒体"); !reflect.DeepEqual(got, []string{"香港策略", "美国策略", "全球手动", "DIRECT"}) {
		t.Fatalf("国际媒体 = %q", got)
	}
	if data := handleGetProxies(); slices.Contains(data.All, "Tailscale 出口 (Flash)") {
		t.Fatal("an empty exit group is listed")
	}
	report, _ := handleTailscaleExit(TailscaleRoutesParams{ProfileID: 7})
	if report.Group != "" || len(report.Parents) != 0 {
		t.Fatalf("report = %+v", report)
	}

	node := managedNode(t, "a1")
	exit, label := "100.64.0.9", "exit-a1 · a1@example.com"
	tailscaleExitPrefsChanged(node, &exit, &label, tailscaleOutcomeApplied)
	if got := exitGroupMembers(t, "国际媒体"); got[len(got)-1] != "Tailscale 出口 (Flash)" {
		t.Fatalf("a chosen exit node did not offer the group: %q", got)
	}
	if now := tunnel.Proxies()["国际媒体"].Adapter().(outboundgroup.ProxyGroup).Now(); now != "香港策略" {
		t.Fatalf("offering the group moved the choice to %q", now)
	}
	off := ""
	tailscaleExitPrefsChanged(node, &off, nil, tailscaleOutcomeFailed)
	if got := exitGroupMembers(t, "国际媒体"); got[len(got)-1] != "Tailscale 出口 (Flash)" {
		t.Fatal("a refused change took the exit node away")
	}
	tailscaleExitPrefsChanged(node, &off, nil, tailscaleOutcomeApplied)
	if got := exitGroupMembers(t, "国际媒体"); slices.Contains(got, "Tailscale 出口 (Flash)") {
		t.Fatalf("the group stayed after its last exit node went: %q", got)
	}
}

// A policy group that picked the exit group falls back to its first option
// once the group goes; the choice inside it follows the account.
func TestTailscaleExitSelectionsFollowTheAccount(t *testing.T) {
	resetTailscaleExit(t)
	setup := exitSetup(map[string]string{"a1": "100.64.0.9", "b2": "100.64.0.7"})
	setup.ExitGroup = "Tailscale exit"
	applyManagedProfileText(t, exitTestProfile, setup)
	exit := "Tailscale exit"
	if err := applyConfig(&SetupParams{Tailscale: setup, SelectedMap: map[string]string{
		"国际媒体":                    "Tailscale 出口 (Flash)",
		"全球手动":                    exit,
		tailscaleExitSelectionKey: "b2",
	}}); err != nil {
		t.Fatal(err)
	}
	group := func(name string) outboundgroup.ProxyGroup {
		return tunnel.Proxies()[name].Adapter().(outboundgroup.ProxyGroup)
	}
	if now := group("国际媒体").Now(); now != exit {
		t.Fatalf("国际媒体 now uses %q, want the group under its new name", now)
	}
	if now := group(exit).Now(); now != "exit-b2 · b2@example.com" {
		t.Fatalf("exit group now uses %q, want b2's node", now)
	}

	node := managedNode(t, "b2")
	value, label := "100.64.0.6", "exit-b6 · b2@example.com"
	tailscaleExitPrefsChanged(node, &value, &label, tailscaleOutcomeApplied)
	if now := group(exit).Now(); now != label {
		t.Fatalf("after b2 moved to another exit the group uses %q", now)
	}
	off := ""
	tailscaleExitPrefsChanged(node, &off, nil, tailscaleOutcomeApplied)
	if now := group(exit).Now(); now != "exit-a1 · a1@example.com" {
		t.Fatalf("with b2 off the group uses %q", now)
	}
	tailscaleExitPrefsChanged(managedNode(t, "a1"), &off, nil, tailscaleOutcomeApplied)
	if now := group("国际媒体").Now(); now != "香港策略" {
		t.Fatalf("with the group gone 国际媒体 uses %q, want its first option", now)
	}
}

// Turning an exit off moves only the choices it leaves invalid, each to the
// first option its group has left; an unavailable exit moves nothing.
func TestTailscaleExitTurnedOffFallsBackToTheFirstOption(t *testing.T) {
	resetTailscaleExit(t)
	setup := exitSetup(map[string]string{"a1": "100.64.0.9", "b2": "100.64.0.7"})
	applyManagedProfileText(t, exitTestProfile, setup)
	const exit = "Tailscale 出口 (Flash)"
	if err := applyConfig(&SetupParams{Tailscale: setup, SelectedMap: map[string]string{
		"国际媒体":                    exit,
		"隐藏":                      exit,
		"仅日本":                     exit,
		"全球手动":                    "US 01",
		tailscaleExitSelectionKey: "b2",
	}}); err != nil {
		t.Fatal(err)
	}
	now := func(name string) string {
		return tunnel.Proxies()[name].Adapter().(outboundgroup.ProxyGroup).Now()
	}
	expect := func(step string, want map[string]string) {
		t.Helper()
		for group, choice := range want {
			if got := now(group); got != choice {
				t.Errorf("%s: %s uses %q, want %q", step, group, got, choice)
			}
		}
	}
	onExit := map[string]string{"国际媒体": exit, "隐藏": exit, "仅日本": exit, "全球手动": "US 01"}

	if _, err := handleTailscaleExit(TailscaleRoutesParams{ProfileID: 7}); err != nil {
		t.Fatal(err)
	}
	expect("unavailable", onExit)

	a1, b2 := managedNode(t, "a1"), managedNode(t, "b2")
	off, b2Exit, b2Label := "", "100.64.0.7", "exit-b2 · b2@example.com"
	tailscaleExitPrefsChanged(b2, &off, nil, tailscaleOutcomeApplied)
	expect("b2 off", onExit)
	if got := now(exit); got != "exit-a1 · a1@example.com" {
		t.Fatalf("with b2 off the exit group uses %q", got)
	}
	tailscaleExitPrefsChanged(b2, &b2Exit, &b2Label, tailscaleOutcomeApplied)
	if got := now(exit); got != "exit-a1 · a1@example.com" {
		t.Fatalf("b2 back took the exit group's choice: %q", got)
	}
	tailscaleExitPrefsChanged(b2, &off, nil, tailscaleOutcomeApplied)

	tailscaleExitPrefsChanged(a1, &off, nil, tailscaleOutcomeApplied)
	expect("all off", map[string]string{"国际媒体": "香港策略", "隐藏": "DIRECT", "仅日本": "COMPATIBLE", "全球手动": "US 01"})
	a1Exit, a1Label := "100.64.0.9", "exit-a1 · a1@example.com"
	tailscaleExitPrefsChanged(a1, &a1Exit, &a1Label, tailscaleOutcomeApplied)
	expect("a1 back", map[string]string{"国际媒体": "香港策略", "隐藏": "DIRECT", "全球手动": "US 01"})
}

// The exit group reaches Tailscale nodes, but a rule's group that offers it
// claims no tailnet target and takes no fewer mounts.
func TestTailscaleExitGroupLeavesOwnershipAndMountsAlone(t *testing.T) {
	resetTailscaleExit(t)
	applyManagedProfileText(t, exitTestProfile, exitSetup(map[string]string{"a1": "100.64.0.9"}))
	a1, b2 := managedNode(t, "a1"), managedNode(t, "b2")
	tailscaleManagedMu.Lock()
	routes := len(tailscaleManagedProfile)
	tailscaleManagedNodes[a1].live = liveAccount("a1", "u1", "tail1.ts.net", peer("nas", "nas.tail1.ts.net", "100.101.1.1")).Live
	tailscaleManagedNodes[b2].live = liveAccount("b2", "u2", "tail2.ts.net").Live
	tailscaleManagedMu.Unlock()
	if routes != 0 {
		t.Fatalf("the profile's rules claim %d tailnet routes through the exit group", routes)
	}
	refreshTailscaleRoutes()
	node := a1.Name()
	for _, metadata := range []*C.Metadata{
		{DstIP: netip.MustParseAddr("100.101.1.1")},
		{Host: "nas.tail1.ts.net"},
	} {
		if got := matchManagedRules(metadata); got != node {
			t.Fatalf("%s -> %q, want the account's node", metadata.RemoteAddress(), got)
		}
	}
	if holders := tailscaleHolders(tunnel.Proxies()); len(holders) != 0 {
		t.Fatalf("groups counted as reaching Tailscale: %v", holders)
	}
	if err := mountRuntimeViolation(tunnel.Proxies(), nil); err != nil {
		t.Fatal(err)
	}
	if got := mountRuntimeGroup(tunnel.Proxies()["全球手动"], "全球手动", nil); got.Members != 2 {
		t.Fatalf("mount read of 全球手动 = %+v", got)
	}
}

func TestTailscaleExitGroupBesideMountedNodes(t *testing.T) {
	resetTailscaleExit(t)
	home := withMountHome(t)
	const profile = `proxies:
  - {name: base, type: socks5, server: 127.0.0.9, port: 1080}
proxy-groups:
  - {name: 国际媒体, type: select, proxies: [全球手动, base]}
  - {name: 全球手动, type: select, include-all: true}
rules:
  - MATCH,国际媒体
`
	source := writeMountFile(t, home, "1.yaml", `proxies:
  - {name: Sub 01, type: socks5, server: 192.0.2.1, port: 1}
`)
	mounts := &MountSetup{Target: 7, Revision: "r", Sources: []MountSource{{ID: 1, Label: "S", Path: source}}}
	read := func(exits map[string]string) MountRuntimeState {
		applyMountedTailscale(t, home, profile, "{}", mounts, exitSetup(exits))
		state := handleMountState()
		if state.Blocked {
			t.Fatalf("blocked with exits %v: %+v", exits, state)
		}
		return state
	}
	without := read(nil)
	with := read(map[string]string{"a1": "100.64.0.9"})
	if !reflect.DeepEqual(without.Groups, with.Groups) || !reflect.DeepEqual(without.Sources, with.Sources) {
		t.Fatalf("mounts read %+v / %+v without and with the exit group", without.Groups, with.Groups)
	}
	if got := exitGroupMembers(t, "全球手动"); !reflect.DeepEqual(got, []string{"base", "Sub 01", "Tailscale 出口"}) {
		t.Fatalf("全球手动 = %q", got)
	}
}
