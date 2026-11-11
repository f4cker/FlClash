package core

import (
	"errors"
	"net/netip"
	"os"
	"path/filepath"
	"testing"

	C "github.com/metacubex/mihomo/constant"
	R "github.com/metacubex/mihomo/rules"
)

func liveAccount(id, user, suffix string, peers ...tailscaleRoutePeer) tailscaleRouteAccount {
	return tailscaleRouteAccount{
		ID:        id,
		Proxy:     "TS " + id,
		Available: true,
		Live: &tailscaleRouteNetmap{
			Identity: TailscaleRouteIdentity{UserID: user, Tailnet: "net-" + user, ControlURL: tailscaleDefaultControlURL, LoginName: user + "@example.com"},
			Suffix:   suffix,
			Peers:    peers,
		},
	}
}

func peer(name, fqdn string, addrs ...string) tailscaleRoutePeer {
	p := tailscaleRoutePeer{Name: name, FQDN: fqdn}
	for _, addr := range addrs {
		p.Addrs = append(p.Addrs, netip.MustParseAddr(addr))
	}
	return p
}

func routeIP(t *testing.T, table *tailscaleRouteTable, addr string) string {
	t.Helper()
	decision, matched, _ := table.matchIP(netip.MustParseAddr(addr))
	if !matched {
		return ""
	}
	return decision.Proxy
}

func routeHost(table *tailscaleRouteTable, host string) string {
	decision, matched, _ := table.matchHost(host)
	if !matched {
		return ""
	}
	return decision.Proxy
}

func targetState(report *TailscaleRoutes, kind, value string) string {
	for _, target := range report.Targets {
		if target.Target.Kind == kind && target.Target.Value == value {
			return target.State
		}
	}
	return ""
}

func TestTailscaleRoutesSingleAccountBindsOnlyWhatItSees(t *testing.T) {
	a := liveAccount("a", "1", "tail-a.ts.net", peer("nas", "nas.tail-a.ts.net.", "100.64.0.2", "fd7a:115c:a1e0::2"))
	result := computeTailscaleRoutes(newTailscaleRouteMemory(), []tailscaleRouteAccount{a}, nil)
	table := result.table
	if got := routeIP(t, table, "100.64.0.2"); got != "TS a" {
		t.Fatalf("known address -> %q", got)
	}
	if got := routeIP(t, table, "fd7a:115c:a1e0::2"); got != "TS a" {
		t.Fatalf("known IPv6 address -> %q", got)
	}
	if got := routeIP(t, table, "100.64.0.9"); got != tailscaleRejectProxy {
		t.Fatalf("an address no account owns -> %q, want REJECT even with one account", got)
	}
	if got := routeIP(t, table, "192.168.1.1"); got != "" {
		t.Fatalf("a private address -> %q, want the profile's rules", got)
	}
	if got := routeHost(table, "NAS.tail-a.ts.net."); got != "TS a" {
		t.Fatalf("device name -> %q", got)
	}
	if got := routeHost(table, "other.tail-a.ts.net"); got != "TS a" {
		t.Fatalf("name under the account's own suffix -> %q", got)
	}
	if got := routeHost(table, "x.tail-b.ts.net"); got != tailscaleRejectProxy {
		t.Fatalf("another ts.net network -> %q", got)
	}
	if got := routeHost(table, "example.com"); got != "" {
		t.Fatalf("an ordinary name -> %q", got)
	}
	if !result.report.Complete || result.report.Accounts[0].Addresses != 2 || result.report.Accounts[0].Domain != "tail-a.ts.net" {
		t.Fatalf("account report = %+v", result.report.Accounts[0])
	}
	if len(result.memory.Bindings) != 4 {
		t.Fatalf("kept %d bindings, want the suffix, the name and two addresses", len(result.memory.Bindings))
	}
}

func TestTailscaleRoutesSharedTargetIsBlockedUntilChosen(t *testing.T) {
	a := liveAccount("a", "1", "tail-a.ts.net", peer("nas", "nas.tail-a.ts.net", "100.64.0.2"))
	b := liveAccount("b", "2", "tail-b.ts.net", peer("nas", "nas.tail-b.ts.net", "100.64.0.2"), peer("pi", "pi.tail-b.ts.net", "100.64.0.3"))
	accounts := []tailscaleRouteAccount{a, b}
	result := computeTailscaleRoutes(newTailscaleRouteMemory(), accounts, nil)
	if got := routeIP(t, result.table, "100.64.0.2"); got != tailscaleRejectProxy {
		t.Fatalf("shared address -> %q", got)
	}
	if got := routeIP(t, result.table, "100.64.0.3"); got != "TS b" {
		t.Fatalf("b's own address -> %q", got)
	}
	if state := targetState(result.report, tailscaleTargetIP, "100.64.0.2"); state != tailscaleRouteConflict {
		t.Fatalf("state = %q", state)
	}

	assignment := TailscaleRouteAssignment{
		Target: TailscaleRouteTarget{Kind: tailscaleTargetIP, Value: "100.64.0.2"},
		Owner:  TailscaleRouteOwner{Kind: tailscaleOwnerManaged, ID: "b"},
	}
	memory, err := assignTailscaleRoutes(result.memory, result.report, accounts, []TailscaleRouteAssignment{assignment})
	if err != nil {
		t.Fatal(err)
	}
	result = computeTailscaleRoutes(memory, accounts, nil)
	if got := routeIP(t, result.table, "100.64.0.2"); got != "TS b" {
		t.Fatalf("assigned address -> %q", got)
	}

	// The conflict goes away and b signs out: the choice holds, nothing moves to a.
	a.Live.Peers = append(a.Live.Peers, peer("other", "other.tail-a.ts.net", "100.64.0.4"))
	b.LoggedOut, b.Live = true, nil
	result = computeTailscaleRoutes(result.memory, []tailscaleRouteAccount{a, b}, nil)
	if got := routeIP(t, result.table, "100.64.0.2"); got != tailscaleRejectProxy {
		t.Fatalf("address assigned to a signed-out account -> %q", got)
	}
	if state := targetState(result.report, tailscaleTargetIP, "100.64.0.2"); state != tailscaleRouteUnavailable {
		t.Fatalf("state = %q", state)
	}
	if got := routeIP(t, result.table, "100.64.0.3"); got != tailscaleRejectProxy {
		t.Fatalf("b's address while b is signed out -> %q", got)
	}
}

func TestTailscaleRoutesWaitForEveryAccountBeforeBindingAnew(t *testing.T) {
	a := liveAccount("a", "1", "", peer("nas", "", "100.64.0.2"))
	b := tailscaleRouteAccount{ID: "b", Proxy: "TS b", Available: true}
	result := computeTailscaleRoutes(newTailscaleRouteMemory(), []tailscaleRouteAccount{a, b}, nil)
	if got := routeIP(t, result.table, "100.64.0.2"); got != tailscaleRejectProxy {
		t.Fatalf("address while b has not loaded -> %q", got)
	}
	if state := targetState(result.report, tailscaleTargetIP, "100.64.0.2"); state != tailscaleRouteUnconfirmed {
		t.Fatalf("state = %q", state)
	}
	if len(result.memory.Bindings) != 0 {
		t.Fatal("bound a target from an incomplete picture")
	}

	// Bound once every account has loaded, it stays bound across a restart.
	b.Live = &tailscaleRouteNetmap{Identity: TailscaleRouteIdentity{UserID: "2"}}
	result = computeTailscaleRoutes(result.memory, []tailscaleRouteAccount{a, b}, nil)
	b.Live = nil
	a.Live = nil
	result = computeTailscaleRoutes(result.memory, []tailscaleRouteAccount{a, b}, nil)
	if got := routeIP(t, result.table, "100.64.0.2"); got != "TS a" {
		t.Fatalf("kept binding while nothing has loaded -> %q", got)
	}
}

func TestTailscaleRoutesTargetsOfARemovedAccountDoNotMove(t *testing.T) {
	a := liveAccount("a", "1", "", peer("nas", "", "100.64.0.2"))
	b := liveAccount("b", "2", "")
	result := computeTailscaleRoutes(newTailscaleRouteMemory(), []tailscaleRouteAccount{a, b}, nil)
	if got := routeIP(t, result.table, "100.64.0.2"); got != "TS a" {
		t.Fatalf("before removal -> %q", got)
	}
	b.Live.Peers = []tailscaleRoutePeer{peer("nas", "", "100.64.0.2")}
	result = computeTailscaleRoutes(result.memory, []tailscaleRouteAccount{b}, nil)
	if got := routeIP(t, result.table, "100.64.0.2"); got != tailscaleRejectProxy {
		t.Fatalf("a's address after a was removed -> %q", got)
	}
	report := result.report
	if state := targetState(report, tailscaleTargetIP, "100.64.0.2"); state != tailscaleRouteConflict {
		t.Fatalf("state = %q", state)
	}
	for _, target := range report.Targets {
		for _, candidate := range target.Candidates {
			if candidate.Owner.ID == "a" && !candidate.Removed {
				t.Fatal("removed account offered as a live candidate")
			}
		}
	}
	// And a conflict stays one when the other side vanishes.
	result = computeTailscaleRoutes(result.memory, []tailscaleRouteAccount{liveAccount("b", "2", "")}, nil)
	if got := routeIP(t, result.table, "100.64.0.2"); got != tailscaleRejectProxy {
		t.Fatalf("released conflict -> %q", got)
	}
}

func TestTailscaleRoutesIdentityChangeNeedsReconfirm(t *testing.T) {
	a := liveAccount("a", "1", "", peer("nas", "", "100.64.0.2"))
	result := computeTailscaleRoutes(newTailscaleRouteMemory(), []tailscaleRouteAccount{a}, nil)
	a.Live.Identity.UserID = "9"
	result = computeTailscaleRoutes(result.memory, []tailscaleRouteAccount{a}, nil)
	if got := routeIP(t, result.table, "100.64.0.2"); got != tailscaleRejectProxy {
		t.Fatalf("address after the account changed -> %q", got)
	}
	if state := targetState(result.report, tailscaleTargetIP, "100.64.0.2"); state != tailscaleRouteReconfirm {
		t.Fatalf("state = %q", state)
	}
}

func TestTailscaleRoutesProfileRouteIsACandidate(t *testing.T) {
	rule, err := R.ParseRule("IP-CIDR", "100.64.0.0/24", "Office", []string{"no-resolve"}, nil)
	if err != nil {
		t.Fatal(err)
	}
	routes, rules := tailscaleProfileRoutes([]C.Rule{rule}, map[string]bool{"Office": true})
	a := liveAccount("a", "1", "", peer("nas", "", "100.64.0.2"), peer("pi", "", "100.64.1.2"))
	accounts := []tailscaleRouteAccount{a}
	result := computeTailscaleRoutes(newTailscaleRouteMemory(), accounts, routes)
	result.table.profileRules = rules
	if got := routeIP(t, result.table, "100.64.0.2"); got != tailscaleRejectProxy {
		t.Fatalf("address the profile also routes -> %q", got)
	}
	if got := routeIP(t, result.table, "100.64.1.2"); got != "TS a" {
		t.Fatalf("address only the account sees -> %q", got)
	}
	var candidates []TailscaleRouteCandidate
	for _, target := range result.report.Targets {
		if target.Target.Value == "100.64.0.2" {
			candidates = target.Candidates
		}
	}
	if len(candidates) != 2 || candidates[1].Owner.Kind != tailscaleOwnerProfile || candidates[1].Rule == "" {
		t.Fatalf("candidates = %+v", candidates)
	}

	memory, err := assignTailscaleRoutes(result.memory, result.report, accounts, []TailscaleRouteAssignment{{
		Target: TailscaleRouteTarget{Kind: tailscaleTargetIP, Value: "100.64.0.2"},
		Owner:  TailscaleRouteOwner{Kind: tailscaleOwnerProfile, ID: "Office"},
	}})
	if err != nil {
		t.Fatal(err)
	}
	result = computeTailscaleRoutes(memory, accounts, routes)
	result.table.profileRules = rules
	tailscaleActiveTable.Store(result.table)
	t.Cleanup(func() { tailscaleActiveTable.Store(nil) })
	ipRule := &tailscaleManagedRule{kind: tailscaleRuleIP}
	if matched, _ := ipRule.Match(&C.Metadata{DstIP: netip.MustParseAddr("100.64.0.2")}, C.RuleMatchHelper{}); matched {
		t.Fatal("an address assigned to the profile's route was taken by the managed rule")
	}
	if matched, _ := ipRule.Match(&C.Metadata{DstIP: netip.MustParseAddr("100.64.0.77")}, C.RuleMatchHelper{}); matched {
		t.Fatal("an unknown address the profile routes was rejected instead")
	}
	if matched, proxy := ipRule.Match(&C.Metadata{DstIP: netip.MustParseAddr("100.70.0.1")}, C.RuleMatchHelper{}); !matched || proxy != tailscaleRejectProxy {
		t.Fatalf("an unknown address outside the profile's route -> %v %q", matched, proxy)
	}
}

func TestTailscaleAssignRefusesANonCandidate(t *testing.T) {
	a := liveAccount("a", "1", "", peer("nas", "", "100.64.0.2"))
	b := liveAccount("b", "2", "", peer("nas", "", "100.64.0.2"))
	result := computeTailscaleRoutes(newTailscaleRouteMemory(), []tailscaleRouteAccount{a, b}, nil)
	_, err := assignTailscaleRoutes(result.memory, result.report, []tailscaleRouteAccount{a, b}, []TailscaleRouteAssignment{{
		Target: TailscaleRouteTarget{Kind: tailscaleTargetIP, Value: "100.64.0.2"},
		Owner:  TailscaleRouteOwner{Kind: tailscaleOwnerManaged, ID: "c"},
	}})
	if !errors.Is(err, errTailscaleAssignInvalid) {
		t.Fatalf("err = %v", err)
	}
}

func TestTailscaleRouteMemoryRoundTrip(t *testing.T) {
	C.SetHomeDir(t.TempDir())
	if memory, err := loadTailscaleRouteMemory(3); err != nil || len(memory.Bindings) != 0 {
		t.Fatalf("absent memory = %+v, %v", memory, err)
	}
	result := computeTailscaleRoutes(newTailscaleRouteMemory(), []tailscaleRouteAccount{liveAccount("a", "1", "", peer("nas", "", "100.64.0.2"))}, nil)
	if err := saveTailscaleRouteMemory(3, result.memory); err != nil {
		t.Fatal(err)
	}
	loaded, err := loadTailscaleRouteMemory(3)
	if err != nil || !loaded.equal(result.memory) {
		t.Fatalf("loaded = %+v, %v", loaded, err)
	}
	if err := os.WriteFile(tailscaleRoutesPath(3), []byte("{"), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := loadTailscaleRouteMemory(3); err == nil {
		t.Fatal("a corrupt memory read as empty")
	}
	if filepath.Dir(tailscaleRoutesPath(3)) != tailscaleRoutesDir() {
		t.Fatal("routes outside the managed directory")
	}
	if err := removeTailscaleRouteMemory(3); err != nil {
		t.Fatal(err)
	}
	if err := removeTailscaleRouteMemory(3); err != nil {
		t.Fatalf("forgetting twice = %v", err)
	}
}

func TestTailscaleManagedKeyIsIndependentOfName(t *testing.T) {
	a := tailscaleManagedKey(1, "id", "")
	if a != tailscaleManagedKey(1, "id", "https://login.tailscale.com") {
		t.Fatal("default control server spelled two ways gives two keys")
	}
	if a == tailscaleManagedKey(2, "id", "") || a == tailscaleManagedKey(1, "id2", "") || a == tailscaleManagedKey(1, "id", "https://hs.example.com") {
		t.Fatal("managed keys collide across profile, ID or control server")
	}
	if a == tailscaleNodeKey(1, "id", "") {
		t.Fatal("a managed key equals a named node's key")
	}
	dir := tailscaleManagedDir(1, "id", "")
	if tailscaleManagedKeyOf(dir) != a || tailscaleManagedKeyOf(filepath.Join("/home", dir)) != a {
		t.Fatal("managed key not read back from its directory")
	}
	if tailscaleManagedKeyOf(filepath.Join(tailscaleNodesDir, a)) != "" {
		t.Fatal("a derived directory read as managed")
	}
}
