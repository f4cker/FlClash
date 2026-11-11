//go:build with_gvisor && !no_tailscale

package core

import (
	"context"
	"testing"

	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/dns"
	D "github.com/miekg/dns"
)

type markedDNSClient struct{ calls int }

func (c *markedDNSClient) ExchangeContext(_ context.Context, m *D.Msg) (*D.Msg, error) {
	c.calls++
	reply := new(D.Msg)
	reply.SetRcode(m, D.RcodeNameError)
	return reply, nil
}

func (c *markedDNSClient) Address() string { return "marked" }

func (c *markedDNSClient) ResetConnection() {}

const mountTailscaleBase = `proxies:
  - {name: office, type: tailscale}
proxy-groups:
  - {name: G, type: select, include-all-providers: true}
  - {name: Office, type: select, proxies: [office]}
rules:
  - MATCH,G
`

func TestMountChecksBuildNoTailscaleNodeAndKeepItsResolver(t *testing.T) {
	home := withMountHome(t)
	withCurrentConfig(t, nil)
	running := &markedDNSClient{}
	t.Cleanup(dns.RegisterTailscaleDnsClient("office", running))
	before := len(outbound.TailscaleInstances())
	base := &SetupBase{Path: writeBaseProfile(t, mountTailscaleBase), Overlay: "{}"}
	mounts := &MountSetup{Revision: "r", Sources: []MountSource{{ID: 1, Label: "S", Path: writeMountFile(t, home, "1.yaml", mountSourceB)}}}

	preflight, err := handleMountPreflight(MountPreflightParams{Base: base, Mounts: mounts})
	if err != nil || preflight.Error != "" {
		t.Fatalf("preflight = %+v, %v", preflight, err)
	}
	if err := checkMountedSetup(&SetupParams{Base: base, Mounts: mounts}); err != nil {
		t.Fatalf("check = %v", err)
	}

	if after := len(outbound.TailscaleInstances()); after != before {
		t.Errorf("Tailscale instances %d -> %d; a check built a node", before, after)
	}
	resolver := dns.NewResolver(dns.Config{Main: []dns.NameServer{{Net: "tailscale", Addr: "office"}}})
	query := new(D.Msg)
	query.SetQuestion("host.example.", D.TypeA)
	if _, err := resolver.ExchangeContext(context.Background(), query); err != nil && running.calls == 0 {
		t.Fatalf("exchange = %v", err)
	}
	if running.calls == 0 {
		t.Error("the running node's resolver was replaced by a check")
	}
}
