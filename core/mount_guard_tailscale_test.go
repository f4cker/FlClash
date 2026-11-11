//go:build with_gvisor && !no_tailscale

package core

import (
	"errors"
	"strings"
	"testing"

	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/component/flashguard"
	"github.com/metacubex/mihomo/tunnel"
)

func newTailscaleThrough(t *testing.T, name, dialerProxy string) *outbound.Tailscale {
	t.Helper()
	node, err := outbound.NewTailscale(outbound.TailscaleOption{
		BasicOption: outbound.BasicOption{DialerProxy: dialerProxy, TunnelForAPI: tunnel.Tunnel},
		Name:        name,
		StateDir:    "tailscale-" + name,
	})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = node.Close() })
	return node
}

// A Tailscale node reaches control, DERP and peers through SystemDial. With
// dialer-proxy on a group whose selection is a mounted node, every such dial
// is refused whatever its public address, and none reaches the egress; the
// same node through a base proxy is carried.
func TestTailscaleNodeNeverDialsThroughAMountedNode(t *testing.T) {
	cfg, recorder, _ := guardedConfig(t)
	refused := recordRefusals(t)
	runInTunnel(t, cfg, tunnel.Rule)

	carried := newTailscaleThrough(t, "ts-office", "Auto")
	for _, address := range []string{"203.0.113.20:443", "derp1.example:443"} {
		if conn, err := carried.SystemDial(t.Context(), "tcp", address); !errors.Is(err, flashguard.ErrRefused) {
			if conn != nil {
				_ = conn.Close()
			}
			t.Errorf("SystemDial %s through Auto = %v, want ErrRefused", address, err)
		}
	}
	if pc, err := carried.SystemListenPacket(t.Context(), "udp", "0.0.0.0:0"); !errors.Is(err, flashguard.ErrRefused) {
		if pc != nil {
			_ = pc.Close()
		}
		t.Errorf("SystemListenPacket through Auto = %v, want ErrRefused", err)
	}
	wantNothingRecorded(t, recorder, "a Tailscale node's own dial")
	if got := refused.waitFor(t, 3); len(got) != 3 || !strings.Contains(got[0], "the Tailscale node ts-office") {
		t.Errorf("refusals = %v, want three naming ts-office", got)
	}

	// Positive control: dialer-proxy on the base egress, no mounted node.
	direct := newTailscaleThrough(t, "ts-home", "egress")
	conn, err := direct.SystemDial(t.Context(), "tcp", "203.0.113.20:443")
	if err != nil {
		t.Fatalf("SystemDial through egress = %v", err)
	}
	_ = conn.Close()
	if servers, _ := recorder.seen(); len(servers) != 1 || servers[0] != "203.0.113.20:443" {
		t.Errorf("egress saw %v, want the node's own dial", servers)
	}
}
