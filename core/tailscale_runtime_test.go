//go:build with_gvisor && !no_tailscale

package core

import (
	"slices"
	"testing"
)

func TestTailscaleRuntimeRulesListTheLiveTableInMatchOrder(t *testing.T) {
	applyManagedProfile(t, &TailscaleSetup{ProfileID: 7, Managed: []TailscaleManagedSetup{{ID: "a1", Attached: true}}})
	node := managedNode(t, "a1")
	tailscaleManagedMu.Lock()
	tailscaleManagedNodes[node].live = liveAccount("a1", "u1", "tail1.ts.net",
		peer("nas", "nas.tail1.ts.net.", "100.101.1.1", "fd7a:115c:a1e0::1"),
	).Live
	tailscaleManagedMu.Unlock()
	refreshTailscaleRoutes()

	got, err := handleTailscaleRuntimeRules(TailscaleRoutesParams{ProfileID: 7})
	if err != nil {
		t.Fatal(err)
	}
	name := node.Name()
	want := []string{
		"DOMAIN,nas.tail1.ts.net," + name,
		"DOMAIN-SUFFIX,tail1.ts.net," + name,
		"DOMAIN-SUFFIX,ts.net,REJECT",
		"IP-CIDR,100.101.1.1/32," + name,
		"IP-CIDR6,fd7a:115c:a1e0::1/128," + name,
		"IP-CIDR,100.64.0.0/10,REJECT",
		"IP-CIDR6,fd7a:115c:a1e0::/48,REJECT",
	}
	if got.State != tailscaleRuntimeConfirmed || len(got.Accounts) != 1 ||
		got.Accounts[0].ID != "a1" || got.Accounts[0].Node != name ||
		!slices.Equal(got.Accounts[0].Rules, want) || !slices.Equal(got.Proxies, []string{name}) {
		t.Fatalf("runtime rules = %+v", got)
	}
	if got.Revision != "024e57560caeb2e40431dddf60c6336a" {
		t.Fatalf("revision = %q", got.Revision)
	}
}

func TestTailscaleRuntimeRulesWithoutAttachedAccounts(t *testing.T) {
	applyManagedProfile(t, &TailscaleSetup{ProfileID: 7})
	none, _ := handleTailscaleRuntimeRules(TailscaleRoutesParams{ProfileID: 7})
	if none.State != tailscaleRuntimeNone || len(none.Accounts) != 0 || len(none.Proxies) != 0 {
		t.Fatalf("no account = %+v", none)
	}

	applyManagedProfile(t, &TailscaleSetup{ProfileID: 7, Managed: []TailscaleManagedSetup{{ID: "b2"}}})
	detached, _ := handleTailscaleRuntimeRules(TailscaleRoutesParams{ProfileID: 7})
	if detached.State != tailscaleRuntimeConfirmed || len(detached.Accounts) != 0 ||
		!slices.Equal(detached.Proxies, []string{managedNode(t, "b2").Name()}) {
		t.Fatalf("a detached account = %+v", detached)
	}
}

func TestTailscaleRuntimeRulesStayUnconfirmedWhenUnknown(t *testing.T) {
	applyManagedProfile(t, &TailscaleSetup{ProfileID: 7, ManagedUnknown: true})
	unknown, _ := handleTailscaleRuntimeRules(TailscaleRoutesParams{ProfileID: 7})
	if unknown.State != tailscaleRuntimeUnconfirmed || unknown.Revision != "" ||
		len(unknown.Accounts) != 0 || len(unknown.Proxies) != 0 {
		t.Fatalf("unknown accounts = %+v", unknown)
	}

	applyManagedProfile(t, &TailscaleSetup{ProfileID: 7, Managed: []TailscaleManagedSetup{{ID: "a1", Attached: true}}})
	cfg, err := loadConfig(runningConfigPath())
	if err != nil {
		t.Fatal(err)
	}
	injectTailscaleManaged(cfg)
	staged, _ := handleTailscaleRuntimeRules(TailscaleRoutesParams{ProfileID: 7})
	if staged.State != tailscaleRuntimeUnconfirmed || len(staged.Accounts) != 0 {
		t.Fatalf("a config not in force yet = %+v", staged)
	}
	publishTailscaleManaged()
	if settled, _ := handleTailscaleRuntimeRules(TailscaleRoutesParams{ProfileID: 7}); settled.State != tailscaleRuntimeConfirmed {
		t.Fatalf("a settled config = %+v", settled)
	}

	other, _ := handleTailscaleRuntimeRules(TailscaleRoutesParams{ProfileID: 9})
	if other.State != tailscaleRuntimeOtherProfile || len(other.Accounts) != 0 {
		t.Fatalf("another profile = %+v", other)
	}
}
