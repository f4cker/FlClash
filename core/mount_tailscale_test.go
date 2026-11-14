//go:build with_gvisor && !no_tailscale

package core

import (
	"context"
	"errors"
	"fmt"
	"net/netip"
	"reflect"
	"slices"
	"testing"

	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/adapter/outboundgroup"
	"github.com/metacubex/mihomo/component/flashguard"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/dns"
	"github.com/metacubex/mihomo/tunnel"
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

func applyMountedTailscale(t *testing.T, home, profile, overlay string, mounts *MountSetup, setup *TailscaleSetup) {
	t.Helper()
	resetTailscaleSetup(t)
	withCurrentConfig(t, nil)
	keepTunnel(t)
	t.Cleanup(func() {
		closeTailscaleUpTo(tailscaleGenerationMark())
		tailscaleManagedMu.Lock()
		tailscaleRunningSlot, tailscaleStagedSlot, tailscaleStaged = nil, nil, false
		tailscaleManagedNameClash = map[string]bool{}
		tailscaleManagedMu.Unlock()
		tailscaleRouting = &tailscaleRouter{}
		setMountState(nil, false, false)
		mountSelectionBasis = map[int64]*MountReport{}
	})
	base := &SetupBase{Path: writeMountFile(t, home, "base.yaml", profile), Overlay: overlay}
	if err := applyConfig(&SetupParams{Base: base, Mounts: mounts, Tailscale: setup}); err != nil {
		t.Fatalf("applyConfig = %v", err)
	}
	waitProviderLoads(t)
}

func TestMountedNodeNeverRenamesAPanelAddedNode(t *testing.T) {
	home := withMountHome(t)
	const profile = `proxies:
  - {name: Work, type: socks5, server: 127.0.0.9, port: 1080}
proxy-groups:
  - {name: G, type: select, include-all-providers: true}
rules:
  - MATCH,G
`
	source := writeMountFile(t, home, "1.yaml", `proxies:
  - {name: "Work (Flash)", type: socks5, server: 192.0.2.1, port: 1}
  - {name: Work, type: socks5, server: 192.0.2.1, port: 2}
`)
	mounts := &MountSetup{Target: 9, Revision: "r", Sources: []MountSource{{ID: 1, Label: "S", Path: source}}}
	setup := &TailscaleSetup{ProfileID: 9, Managed: []TailscaleManagedSetup{{ID: "m1", Name: "Work", Attached: true}}}

	for range 2 {
		applyMountedTailscale(t, home, profile, "{}", mounts, setup)
		if name := managedNode(t, "m1").Name(); name != "Work (Flash)" {
			t.Fatalf("the panel-added node is %q, want Work (Flash)", name)
		}
		tailscaleManagedMu.Lock()
		clashes := len(tailscaleManagedNameClash)
		tailscaleManagedMu.Unlock()
		if clashes != 0 {
			t.Fatal("a mounted node took a panel-added node's name")
		}
		state := handleMountState()
		if want := []MountNode{{"Work (Flash) (S)", "Work (Flash)"}, {"Work (S)", "Work"}}; !reflect.DeepEqual(state.Report.Sources[0].Nodes, want) {
			t.Fatalf("nodes = %+v, want %+v", state.Report.Sources[0].Nodes, want)
		}
		if !state.Sources[0].Matches {
			t.Fatalf("source = %+v, want its nodes loaded as reported", state.Sources[0])
		}
	}
}

const mountTailscaleInvariantProviders = `proxy-providers:
  tsp: {type: inline, payload: [{name: ts-home, type: tailscale}]}
  own: {type: inline, payload: [{name: own-node, type: socks5, server: 127.0.0.9, port: 1081}]}
`

const mountTailscaleInvariantProfile = `proxies:
  - {name: base, type: socks5, server: 127.0.0.9, port: 1080}
  - {name: ts-office, type: tailscale}
proxy-groups:
  - {name: Main, type: select, proxies: [Auto, base]}
  - {name: Office, type: fallback, proxies: [ts-office, Pool]}
  - {name: Pool, type: url-test, include-all-providers: true, exclude-type: tailscale}
  - {name: Home, type: url-test, use: [tsp, own]}
  - {name: Everything, type: select, include-all-providers: true}
  - {name: Tailnet, type: select, proxies: [base], include-all-providers: true, exclude-type: tailscale}
  - {name: Auto, type: url-test, include-all-providers: true, exclude-type: tailscale}
rules:
  - IP-CIDR,100.64.0.0/10,Tailnet,no-resolve
  - DOMAIN-SUFFIX,ts.net,Office
  - MATCH,Main
`

// Rule sets (an overlay section, as the host sends them), a LAN rule on a direct-or-proxy switch, and relays spelled as
// the proxy decoder still reads them.
const mountTailscaleRuleSetProviders = `proxy-providers:
  own: {type: inline, payload: [{name: own-node, type: socks5, server: 127.0.0.9, port: 1081}]}
  chain: {type: inline, dialer-proxy: ts-office, payload: [{name: chain-node, type: socks5, server: 127.0.0.9, port: 1083}]}
rule-providers:
  tailnet: {type: inline, behavior: ipcidr, payload: [100.100.0.0/16]}
  names: {type: inline, behavior: domain, payload: ['+.ts.net']}
  office: {type: inline, behavior: classical, payload: ['DOMAIN-SUFFIX,ts.net']}
`

const mountTailscaleRuleSetProfile = `proxies:
  - {name: base, type: socks5, server: 127.0.0.9, port: 1080}
  - {name: ts-office, type: tailscale}
  - {name: hop, type: socks5, server: 127.0.0.9, port: 1082, Dialer_Proxy: ts-office}
proxy-groups:
  - {name: Main, type: select, proxies: [Auto, base]}
  - {name: Direct, type: select, proxies: [DIRECT, Proxy]}
  - {name: Proxy, type: select, proxies: [Pool, base]}
  - {name: Pool, type: url-test, include-all-providers: true}
  - {name: Names, type: url-test, include-all-providers: true}
  - {name: Office, type: select, proxies: [ts-office, Pool]}
  - {name: Hops, type: select, proxies: [hop, base]}
  - {name: Auto, type: url-test, include-all-providers: true}
rules:
  - RULE-SET,tailnet,Direct
  - RULE-SET,names,Names
  - RULE-SET,office,Office
  - GEOIP,LAN,Direct,no-resolve
  - MATCH,Main
`

const mountTailscaleInvariantRelays = `  - {name: relay, type: socks5, server: 192.0.2.2, port: 2, dialer-proxy: ts-office}
  - {name: spelled, type: socks5, server: 192.0.2.2, port: 3, DIALER_PROXY: Office}
  - {name: global, type: socks5, server: 192.0.2.2, port: 4, dialer-proxy: GLOBAL}
  - {name: bound, type: socks5, server: 192.0.2.2, port: 5, interface-name: utun9}
`

// What a Tailscale route can end up on, followed through every group, must
// never be a mounted node. GLOBAL holds everything and serves global mode
// only, where no rule routes.
func TestMountedConfigNeverRoutesTailscaleThroughAMountedNode(t *testing.T) {
	profiles := map[string][3]string{
		"groups": {mountTailscaleInvariantProfile, mountTailscaleInvariantProviders, ""},
		"rule-set": {mountTailscaleRuleSetProfile, mountTailscaleRuleSetProviders,
			"  - {name: hopper, type: socks5, server: 192.0.2.2, port: 6, Dialer-Proxy: Hops}\n" +
				""},
	}
	for _, kind := range []string{"groups", "rule-set"} {
		for _, attached := range []bool{false, true} {
			t.Run(fmt.Sprintf("%s/attached=%v", kind, attached), func(t *testing.T) {
				checkMountedTailscaleInvariant(t, profiles[kind][0], profiles[kind][1], profiles[kind][2], attached)
			})
		}
	}
}

func checkMountedTailscaleInvariant(t *testing.T, profile, providers, relays string, attached bool) {
	home := withMountHome(t)
	source := writeMountFile(t, home, "1.yaml", mountSourceB+mountTailscaleInvariantRelays+relays)
	setup := &TailscaleSetup{ProfileID: 9}
	if attached {
		setup.Managed = []TailscaleManagedSetup{{ID: "m1", Name: "Work", Attached: true}}
	}
	mounts := &MountSetup{Target: 9, Revision: "r", Sources: []MountSource{{ID: 1, Label: "S", Path: source}}}
	applyMountedTailscale(t, home, profile, providers, mounts, setup)

	proxies := tunnel.Proxies()
	for _, provider := range tunnel.Providers() {
		if !flashguard.IsMountProvider(provider.Name()) {
			continue
		}
		for _, proxy := range provider.Proxies() {
			meta := &constant.Metadata{NetWork: constant.TCP, DstIP: netip.MustParseAddr("100.101.1.1"), DstPort: 443}
			if conn, err := proxy.DialContext(t.Context(), meta); !errors.Is(err, flashguard.ErrRefused) {
				if conn != nil {
					_ = conn.Close()
				}
				t.Errorf("%s protected connection = %v", proxy.Name(), err)
			}
		}
	}
	if member := mountedMemberOf(proxies, "Main", map[string]bool{}); member == "" {
		t.Error("the main group has no mounted node; the mount did nothing")
	}
	for name, proxy := range proxies {
		group, ok := adapterAs[outboundgroup.ProxyGroup](proxy)
		if !ok {
			continue
		}
		for _, member := range group.Proxies() {
			if slices.Contains([]string{"relay", "spelled", "global", "bound", "hopper", "chained"}, member.Name()) {
				t.Errorf("%s holds %s, which relays through Tailscale or binds an interface", name, member.Name())
			}
		}
	}
	if state := handleMountState(); state.Blocked || len(state.Refused) > 0 {
		t.Errorf("state = blocked %v, refused %v; want the mounted profile running", state.Blocked, state.Refused)
	}
}
