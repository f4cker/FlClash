//go:build with_gvisor && !no_tailscale

package core

import (
	"context"
	"encoding/json"
	"errors"
	"net/netip"
	"os"
	"path/filepath"
	"testing"

	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/tailscale/ipn"
)

func newGatedTailscale(t *testing.T, name string) *outbound.Tailscale {
	t.Helper()
	node, err := outbound.NewTailscale(outbound.TailscaleOption{Name: name, AuthKey: "tskey-test"})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = node.Close() })
	return node
}

func TestTailscaleGuardBlocksEveryImplicitStart(t *testing.T) {
	resetTailscaleSetup(t)
	constant.SetHomeDir(t.TempDir())
	setTailscaleSetup(&TailscaleSetup{
		ProfileID: 1,
		Nodes:     []TailscaleNodeSetup{{Name: "guarded", LoggedOut: true}},
	})
	node := newGatedTailscale(t, "guarded")
	metadata := &constant.Metadata{NetWork: constant.TCP, DstIP: netip.MustParseAddr("100.64.0.2"), DstPort: 80}

	if _, err := node.DialContext(context.Background(), metadata); !errors.Is(err, errTailscaleLoggedOut) {
		t.Fatalf("dial through a logged-out node = %v", err)
	}
	if _, err := node.ListenPacketContext(context.Background(), metadata); !errors.Is(err, errTailscaleLoggedOut) {
		t.Fatalf("UDP through a logged-out node = %v", err)
	}
	if _, err := handleTailscaleStart(TailscaleNodeParams{Name: "guarded", Generation: node.Generation()}); !errors.Is(err, errTailscaleLoggedOut) {
		t.Fatalf("tailscale.start of a logged-out node = %v", err)
	}
	if node.Started() {
		t.Fatal("a logged-out node started")
	}
}

func TestTailscaleWithoutIdentityWaitsForLogin(t *testing.T) {
	resetTailscaleSetup(t)
	constant.SetHomeDir(t.TempDir())
	setTailscaleSetup(&TailscaleSetup{ProfileID: 1, Nodes: []TailscaleNodeSetup{{Name: "fresh"}}})
	node := newGatedTailscale(t, "fresh")
	metadata := &constant.Metadata{NetWork: constant.TCP, DstIP: netip.MustParseAddr("100.64.0.2"), DstPort: 80}
	if _, err := node.DialContext(context.Background(), metadata); !errors.Is(err, errTailscaleNeedsLogin) {
		t.Fatalf("dial through a node with no identity = %v", err)
	}
	if node.Started() {
		t.Fatal("traffic registered a node with its auth-key")
	}
}

func TestTailscaleCallsAreBoundToAGeneration(t *testing.T) {
	resetTailscaleSetup(t)
	constant.SetHomeDir(t.TempDir())
	setTailscaleSetup(&TailscaleSetup{ProfileID: 1})
	old := newGatedTailscale(t, "bound")
	current := newGatedTailscale(t, "bound")
	if _, err := boundTailscale("bound", old.Generation()); !errors.Is(err, errTailscaleStaleGeneration) {
		t.Fatalf("a call for the replaced instance = %v", err)
	}
	if got, err := boundTailscale("bound", current.Generation()); err != nil || got != current {
		t.Fatalf("a call for the current instance = %v, %v", got, err)
	}
	if _, err := boundTailscale("missing", current.Generation()); !errors.Is(err, errTailscaleNodeNotFound) {
		t.Fatalf("a call for an unknown node = %v", err)
	}

	closeTailscaleUpTo(old.Generation())
	if !old.Closed() || current.Closed() {
		t.Fatal("closing up to a mark missed the old instance or took the new one")
	}
}

func TestTailscaleSetPrefsRefusesProviderNodes(t *testing.T) {
	resetTailscaleSetup(t)
	constant.SetHomeDir(t.TempDir())
	setTailscaleSetup(&TailscaleSetup{ProfileID: 1})
	node := newGatedTailscale(t, "provided")
	acceptRoutes := true
	_, err := handleTailscaleSetPrefs(TailscalePrefsParams{Name: "provided", Generation: node.Generation(), AcceptRoutes: &acceptRoutes})
	if !errors.Is(err, errTailscaleNotOverridable) {
		t.Fatalf("setPrefs of a provider node = %v", err)
	}
}

func TestTailscalePrefsMatch(t *testing.T) {
	exitIP := netip.MustParseAddr("100.64.0.9")
	cases := []struct {
		name string
		want ipn.MaskedPrefs
		read TailscalePrefs
		ok   bool
	}{
		{"routes on", ipn.MaskedPrefs{Prefs: ipn.Prefs{RouteAll: true}, RouteAllSet: true}, TailscalePrefs{AcceptRoutes: true}, true},
		{"routes ignored", ipn.MaskedPrefs{Prefs: ipn.Prefs{RouteAll: true}, RouteAllSet: true}, TailscalePrefs{}, false},
		{"exit node by IP", ipn.MaskedPrefs{Prefs: ipn.Prefs{ExitNodeIP: exitIP}, ExitNodeIPSet: true}, TailscalePrefs{ExitNodeID: "n1", ExitNodeIP: "100.64.0.9"}, true},
		{"another exit node", ipn.MaskedPrefs{Prefs: ipn.Prefs{ExitNodeIP: exitIP}, ExitNodeIPSet: true}, TailscalePrefs{ExitNodeIP: "100.64.0.8"}, false},
		{"exit node cleared", ipn.MaskedPrefs{ExitNodeIPSet: true}, TailscalePrefs{}, true},
		{"exit node kept", ipn.MaskedPrefs{ExitNodeIPSet: true}, TailscalePrefs{ExitNodeID: "n1"}, false},
		{"auto exit node", ipn.MaskedPrefs{Prefs: ipn.Prefs{AutoExitNode: ipn.AnyExitNode}, ExitNodeIPSet: true}, TailscalePrefs{AutoExitNode: string(ipn.AnyExitNode), ExitNodeID: "n2"}, true},
	}
	for _, c := range cases {
		if got := tailscalePrefsMatch(&c.want, &c.read); got != c.ok {
			t.Errorf("%s: match = %v, want %v", c.name, got, c.ok)
		}
	}
}

func writeTailscaleStateFile(t *testing.T, dir, controlURL string) []byte {
	t.Helper()
	profiles, _ := json.Marshal(map[string]any{
		"a1": map[string]any{
			"Key":            "profile-a1",
			"ControlURL":     controlURL,
			"NetworkProfile": map[string]string{"DomainName": "example.ts.net"},
			"UserProfile":    map[string]string{"LoginName": "alice@example.com", "DisplayName": "Alice"},
		},
	})
	buf, _ := json.Marshal(map[string][]byte{
		"_profiles":        profiles,
		"_current-profile": []byte("a1"),
		"_machinekey":      []byte("privkey:legacy"),
	})
	if err := os.MkdirAll(dir, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, tailscaleStateFile), buf, 0o600); err != nil {
		t.Fatal(err)
	}
	return buf
}

func newMigrationTarget(t *testing.T, option outbound.TailscaleOption) *outbound.Tailscale {
	t.Helper()
	node, err := outbound.NewTailscale(option)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = node.Close() })
	return node
}
