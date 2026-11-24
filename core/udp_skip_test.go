package core

import (
	"context"
	"encoding/json"
	"maps"
	"net"
	"net/netip"
	"slices"
	"testing"
	"time"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/adapter/outboundgroup"
	"github.com/metacubex/mihomo/adapter/provider"
	"github.com/metacubex/mihomo/constant"
	cp "github.com/metacubex/mihomo/constant/provider"
	"github.com/metacubex/mihomo/rules"
	"github.com/metacubex/mihomo/tunnel"
	"github.com/metacubex/mihomo/tunnel/statistic"
)

func udpLessProxy(t *testing.T, name string) constant.Proxy {
	t.Helper()
	http, err := outbound.NewHttp(outbound.HttpOption{Name: name, Server: "127.0.0.1", Port: 1})
	if err != nil {
		t.Fatalf("NewHttp: %v", err)
	}
	return adapter.NewProxy(http)
}

func udpGroup(t *testing.T, name string, disableUDP bool, members ...constant.Proxy) constant.Proxy {
	t.Helper()
	health := provider.NewHealthCheck(members, "", 0, 0, true, nil)
	pd, err := provider.NewCompatibleProvider(name+"-provider", members, health)
	if err != nil {
		t.Fatalf("NewCompatibleProvider: %v", err)
	}
	group, err := outboundgroup.NewSelector(
		outboundgroup.GroupCommonOption{Name: name, DisableUDP: disableUDP},
		outboundgroup.SelectorOption{},
		namedProxy("COMPATIBLE"),
		[]cp.ProxyProvider{pd},
	)
	if err != nil {
		t.Fatalf("NewSelector: %v", err)
	}
	return adapter.NewProxy(group)
}

func routeWith(t *testing.T, mode tunnel.TunnelMode, proxies map[string]constant.Proxy, policy string) {
	t.Helper()
	keepTunnel(t)
	proxies["DIRECT"] = namedProxy("DIRECT")
	tunnel.UpdateProxies(proxies, nil)
	domain, err := rules.ParseRule("DOMAIN", "example.com", policy, nil, nil)
	if err != nil {
		t.Fatalf("ParseRule: %v", err)
	}
	tunnel.UpdateRules([]constant.Rule{domain}, nil, nil)
	tunnel.SetMode(mode)
	currentRuleTable.observe()
}

func routeFlow(t *testing.T, network constant.NetWork, host string) (*constant.Metadata, constant.Proxy, constant.Rule) {
	t.Helper()
	metadata := &constant.Metadata{NetWork: network, Type: constant.SOCKS5, Host: host, DstPort: 443}
	proxy, rule, err := tunnel.ResolveRouteRule(metadata)
	if err != nil {
		t.Fatalf("resolve %s %s: %v", network, host, err)
	}
	return metadata, proxy, rule
}

func TestUDPFlowRecordsTheRuleItsSelectionCouldNotCarry(t *testing.T) {
	group := udpGroup(t, "Proxy", false, udpLessProxy(t, "http-a"), namedProxy("node-b"))
	routeWith(t, tunnel.Rule, map[string]constant.Proxy{"Proxy": group}, "Proxy")

	udp, proxy, rule := routeFlow(t, constant.UDP, "example.com")
	if proxy.Name() != "DIRECT" || rule != nil {
		t.Fatalf("UDP routed to %s by %v, want DIRECT by no rule", proxy.Name(), rule)
	}
	want := []constant.UDPSkip{{Type: "Domain", Payload: "example.com", Adapter: "Proxy", Refused: "http-a", Cause: tunnel.UDPSkipUnsupported}}
	if !slices.Equal(udp.UDPSkipped, want) || udp.RouteReason != tunnel.RouteNoMatch {
		t.Errorf("UDP recorded %+v / %q, want %+v / %q", udp.UDPSkipped, udp.RouteReason, want, tunnel.RouteNoMatch)
	}
	info := &statistic.TrackerInfo{Metadata: udp, Start: time.Now()}
	if index := currentRuleTable.indexOfSkipped(info, true); index == nil || *index != 0 {
		t.Errorf("skipped rule index = %v, want 0", index)
	}
	data, _ := json.Marshal(udp)
	var encoded map[string]any
	_ = json.Unmarshal(data, &encoded)
	if encoded["routeReason"] != "no-match" || len(encoded["udpSkipped"].([]any)) != 1 {
		t.Errorf("metadata JSON = %s, want its udpSkipped and routeReason", data)
	}

	tcp, proxy, rule := routeFlow(t, constant.TCP, "example.com")
	if proxy.Name() != "Proxy" || rule == nil || tcp.UDPSkipped != nil || tcp.RouteReason != "" {
		t.Errorf("TCP routed to %s by %v with %+v / %q, want Proxy by its rule and nothing recorded",
			proxy.Name(), rule, tcp.UDPSkipped, tcp.RouteReason)
	}

	if err := group.Adapter().(*outboundgroup.Selector).Set("node-b"); err != nil {
		t.Fatalf("Set: %v", err)
	}
	carried, proxy, rule := routeFlow(t, constant.UDP, "example.com")
	if proxy.Name() != "Proxy" || rule == nil || carried.UDPSkipped != nil || carried.RouteReason != "" {
		t.Errorf("UDP over a UDP node routed to %s by %v with %+v, want Proxy by its rule", proxy.Name(), rule, carried.UDPSkipped)
	}
	if !slices.Equal(udp.UDPSkipped, want) {
		t.Errorf("the earlier flow's record changed to %+v", udp.UDPSkipped)
	}
}

func TestUDPSkipNamesAGroupThatDisablesUDP(t *testing.T) {
	group := udpGroup(t, "Proxy", true, namedProxy("node-b"))
	routeWith(t, tunnel.Rule, map[string]constant.Proxy{"Proxy": group}, "Proxy")

	udp, proxy, _ := routeFlow(t, constant.UDP, "example.com")
	want := []constant.UDPSkip{{Type: "Domain", Payload: "example.com", Adapter: "Proxy", Refused: "Proxy", Cause: tunnel.UDPSkipDisabled}}
	if proxy.Name() != "DIRECT" || !slices.Equal(udp.UDPSkipped, want) {
		t.Errorf("UDP routed to %s with %+v, want DIRECT with %+v", proxy.Name(), udp.UDPSkipped, want)
	}
}

func TestRouteReasonRecordsWhyNoRuleDecided(t *testing.T) {
	routeWith(t, tunnel.Rule, map[string]constant.Proxy{"GLOBAL": namedProxy("GLOBAL")}, "DIRECT")
	if m, _, _ := routeFlow(t, constant.TCP, "example.org"); m.RouteReason != tunnel.RouteNoMatch {
		t.Errorf("unmatched reason = %q", m.RouteReason)
	}
	if m, _, rule := routeFlow(t, constant.TCP, "example.com"); rule == nil || m.RouteReason != "" {
		t.Errorf("a rule that picked DIRECT recorded %q", m.RouteReason)
	}
	tunnel.SetMode(tunnel.Direct)
	if m, _, _ := routeFlow(t, constant.TCP, "example.com"); m.RouteReason != tunnel.RouteModeDirect {
		t.Errorf("direct mode reason = %q", m.RouteReason)
	}
	tunnel.SetMode(tunnel.Global)
	if m, _, _ := routeFlow(t, constant.TCP, "example.com"); m.RouteReason != tunnel.RouteModeGlobal {
		t.Errorf("global mode reason = %q", m.RouteReason)
	}

	special := func(kind constant.Type) string {
		metadata := &constant.Metadata{NetWork: constant.TCP, Type: kind, Host: "example.com", DstPort: 443, SpecialProxy: "DIRECT"}
		if _, _, err := tunnel.ResolveRouteRule(metadata); err != nil {
			t.Fatalf("resolve: %v", err)
		}
		return metadata.RouteReason
	}
	if got := special(constant.INNER); got != tunnel.RouteInternal {
		t.Errorf("inner special proxy reason = %q", got)
	}
	if got := special(constant.SOCKS5); got != tunnel.RouteSpecial {
		t.Errorf("listener special proxy reason = %q, want it not taken as internal", got)
	}
}

func TestProxyViewTellsUnknownFromUnsupported(t *testing.T) {
	encode := func(proxy constant.Proxy) map[string]any {
		t.Helper()
		data, err := json.Marshal(proxyView(proxy))
		if err != nil {
			t.Fatalf("marshal %s: %v", proxy.Name(), err)
		}
		view := map[string]any{}
		_ = json.Unmarshal(data, &view)
		return view
	}

	http := encode(udpLessProxy(t, "http-a"))
	if http["udp"] != false || http["tfo"] != false {
		t.Errorf("UDP-less node view = %v, want udp and tfo present as false", http)
	}
	reject := encode(adapter.NewProxy(outbound.NewReject()))
	if _, exist := reject["udp"]; exist {
		t.Errorf("REJECT view = %v, want no capability for an action", reject)
	}

	follows := udpGroup(t, "follows", false, udpLessProxy(t, "http-b"), namedProxy("node-c"))
	if view := encode(follows); view["udp"] != false || view["disableUdp"] != false || view["name"] != "follows" {
		t.Errorf("group view = %v, want udp false from its selection, disableUdp false", view)
	}
	_ = follows.Adapter().(*outboundgroup.Selector).Set("node-c")
	if view := encode(follows); view["udp"] != true {
		t.Errorf("group view after selecting a UDP node = %v, want udp true", view)
	}
	if view := encode(udpGroup(t, "off", true, namedProxy("node-d"))); view["udp"] != false || view["disableUdp"] != true {
		t.Errorf("disabled group view = %v, want udp false, disableUdp true", view)
	}
}

type udpRule struct{ tp, payload, target string }

// routeRules installs rules in order, with named sub-rule sets, over proxies.
func routeRules(t *testing.T, proxies map[string]constant.Proxy, sub map[string][]udpRule, list ...udpRule) {
	t.Helper()
	keepTunnel(t)
	proxies["DIRECT"] = namedProxy("DIRECT")
	tunnel.UpdateProxies(proxies, nil)
	subRules := map[string][]constant.Rule{}
	parse := func(r udpRule) constant.Rule {
		rule, err := rules.ParseRule(r.tp, r.payload, r.target, nil, subRules)
		if err != nil {
			t.Fatalf("ParseRule %v: %v", r, err)
		}
		return rule
	}
	for name, list := range sub {
		for _, r := range list {
			subRules[name] = append(subRules[name], parse(r))
		}
	}
	parsed := make([]constant.Rule, 0, len(list))
	for _, r := range list {
		parsed = append(parsed, parse(r))
	}
	tunnel.UpdateRules(parsed, subRules, nil)
	tunnel.SetMode(tunnel.Rule)
	currentRuleTable.observe()
}

func rematchProxy(t *testing.T, name string, option outbound.RematchOption) constant.Proxy {
	t.Helper()
	option.Name = name
	rematch, err := outbound.NewRematch(option)
	if err != nil {
		t.Fatalf("NewRematch: %v", err)
	}
	return adapter.NewProxy(rematch)
}

func skipOf(payload, adapter, refused string) constant.UDPSkip {
	return constant.UDPSkip{Type: "Domain", Payload: payload, Adapter: adapter, Refused: refused, Cause: tunnel.UDPSkipUnsupported}
}

func TestUDPSkipThenALaterRuleDecides(t *testing.T) {
	routeRules(t, map[string]constant.Proxy{
		"Off": udpGroup(t, "Off", false, udpLessProxy(t, "http-a")),
		"On":  namedProxy("On"),
	}, nil, udpRule{"DOMAIN", "example.com", "Off"}, udpRule{"DOMAIN-SUFFIX", "com", "On"})

	m, proxy, rule := routeFlow(t, constant.UDP, "example.com")
	if proxy.Name() != "On" || rule == nil || rule.Payload() != "com" {
		t.Fatalf("routed to %s by %v, want On by the later rule", proxy.Name(), rule)
	}
	if want := []constant.UDPSkip{skipOf("example.com", "Off", "http-a")}; !slices.Equal(m.UDPSkipped, want) || m.RouteReason != "" {
		t.Errorf("recorded %+v / %q, want %+v and no reason", m.UDPSkipped, m.RouteReason, want)
	}
}

func TestUDPSkipKeepsThreeAndPassesOverPass(t *testing.T) {
	proxies := map[string]constant.Proxy{"PASS": adapter.NewProxy(outbound.NewPass())}
	list := []udpRule{{"DOMAIN", "example.com", "PASS"}}
	for _, name := range []string{"a", "b", "c", "d"} {
		proxies[name] = udpGroup(t, name, false, udpLessProxy(t, "http-"+name))
		list = append(list, udpRule{"DOMAIN-KEYWORD", name, name})
	}
	routeRules(t, proxies, nil, list...)

	m, proxy, _ := routeFlow(t, constant.UDP, "abcd.example.com")
	want := []constant.UDPSkip{
		{Type: "DomainKeyword", Payload: "a", Adapter: "a", Refused: "http-a", Cause: tunnel.UDPSkipUnsupported},
		{Type: "DomainKeyword", Payload: "b", Adapter: "b", Refused: "http-b", Cause: tunnel.UDPSkipUnsupported},
		{Type: "DomainKeyword", Payload: "c", Adapter: "c", Refused: "http-c", Cause: tunnel.UDPSkipUnsupported},
	}
	if proxy.Name() != "DIRECT" || !slices.Equal(m.UDPSkipped, want) || m.RouteReason != tunnel.RouteNoMatch {
		t.Errorf("routed to %s with %+v / %q, want DIRECT with the first three skips and no PASS",
			proxy.Name(), m.UDPSkipped, m.RouteReason)
	}
}

func TestUDPSkipSurvivesRematch(t *testing.T) {
	sub := "after"
	again := "again"
	routeRules(t, map[string]constant.Proxy{
		"Off":   udpGroup(t, "Off", false, udpLessProxy(t, "http-a")),
		"On":    namedProxy("On"),
		"ToSub": rematchProxy(t, "ToSub", outbound.RematchOption{TargetSubRule: &sub}),
		"Again": rematchProxy(t, "Again", outbound.RematchOption{TargetRematchName: &again}),
	}, map[string][]udpRule{sub: {{"MATCH", "", "On"}}},
		udpRule{"DOMAIN", "example.com", "Off"},
		udpRule{"DOMAIN", "example.com", "ToSub"},
		udpRule{"DOMAIN", "example.org", "Off"},
		udpRule{"DOMAIN", "example.org", "Again"},
	)

	m, proxy, rule := routeFlow(t, constant.UDP, "example.com")
	if proxy.Name() != "On" || rule == nil {
		t.Fatalf("routed to %s by %v, want On by the sub-rule after rematch", proxy.Name(), rule)
	}
	if want := []constant.UDPSkip{skipOf("example.com", "Off", "http-a")}; !slices.Equal(m.UDPSkipped, want) || m.RouteReason != "" {
		t.Errorf("recorded %+v / %q, want the skip before the rematch", m.UDPSkipped, m.RouteReason)
	}

	// A rematch that runs the same rules again records their skip once.
	m, proxy, _ = routeFlow(t, constant.UDP, "example.org")
	if want := []constant.UDPSkip{skipOf("example.org", "Off", "http-a")}; proxy.Name() != "Again" || !slices.Equal(m.UDPSkipped, want) {
		t.Errorf("routed to %s with %+v, want Again with one skip", proxy.Name(), m.UDPSkipped)
	}
}

func TestUDPSkipNamesTheSubRule(t *testing.T) {
	routeRules(t, map[string]constant.Proxy{
		"Off": udpGroup(t, "Off", false, udpLessProxy(t, "http-a")),
	}, map[string][]udpRule{"inner": {{"MATCH", "", "Off"}}},
		udpRule{"SUB-RULE", "(DOMAIN,example.com)", "inner"},
	)

	m, proxy, _ := routeFlow(t, constant.UDP, "example.com")
	if proxy.Name() != "DIRECT" || len(m.UDPSkipped) != 1 {
		t.Fatalf("routed to %s with %+v, want DIRECT with one skip", proxy.Name(), m.UDPSkipped)
	}
	if skip := m.UDPSkipped[0]; skip.Type != "SubRules" || skip.Adapter != "Off" || skip.Refused != "http-a" {
		t.Errorf("skip = %+v, want the outer SUB-RULE pointing at Off", skip)
	}
}

type routedUDPPacket struct{ from net.Addr }

func (p *routedUDPPacket) Data() []byte                                { return []byte{0} }
func (p *routedUDPPacket) WriteBack(b []byte, _ net.Addr) (int, error) { return len(b), nil }
func (p *routedUDPPacket) Drop()                                       {}
func (p *routedUDPPacket) LocalAddr() net.Addr                         { return p.from }

func trackedUDP(t *testing.T, dst netip.AddrPort) *constant.Metadata {
	t.Helper()
	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		var found *constant.Metadata
		statistic.DefaultManager.Range(func(c statistic.Tracker) bool {
			if m := c.Info().Metadata; m.NetWork == constant.UDP && m.AddrPort() == dst {
				found = m
				_ = c.Close()
				return false
			}
			return true
		})
		if found != nil {
			return found
		}
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatalf("no UDP connection to %s was tracked", dst)
	return nil
}

// The NAT path routes a clone; the packet's own metadata keeps no record.
func TestUDPSkipRecordedOnTheTrackedFlowOnly(t *testing.T) {
	routeRules(t, map[string]constant.Proxy{
		"Off": udpGroup(t, "Off", false, udpLessProxy(t, "http-a")),
	}, nil, udpRule{"IP-CIDR", "127.0.0.0/8", "Off"})
	tunnel.OnRunning()

	dst := netip.MustParseAddrPort("127.0.0.1:9")
	metadata := &constant.Metadata{
		NetWork: constant.UDP, Type: constant.SOCKS5,
		SrcIP: netip.MustParseAddr("127.0.0.1"), SrcPort: 40001,
		DstIP: dst.Addr(), DstPort: dst.Port(),
	}
	tunnel.Tunnel.HandleUDPPacket(&routedUDPPacket{from: &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1), Port: 40001}}, metadata)

	tracked := trackedUDP(t, dst)
	want := []constant.UDPSkip{{Type: "IPCIDR", Payload: "127.0.0.0/8", Adapter: "Off", Refused: "http-a", Cause: tunnel.UDPSkipUnsupported}}
	if !slices.Equal(tracked.UDPSkipped, want) || tracked.RouteReason != tunnel.RouteNoMatch {
		t.Errorf("tracked %+v / %q, want %+v / %q", tracked.UDPSkipped, tracked.RouteReason, want, tunnel.RouteNoMatch)
	}
	if tracked == metadata || metadata.UDPSkipped != nil || metadata.RouteReason != "" {
		t.Errorf("the packet's metadata was written: %+v / %q", metadata.UDPSkipped, metadata.RouteReason)
	}
}

func TestDNSDialerPinnedToDirectIsInternal(t *testing.T) {
	routeRules(t, map[string]constant.Proxy{}, nil)
	tunnel.OnRunning()
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	defer listener.Close()

	conn, err := tunnel.NewDNSDialer(nil, nil, "DIRECT").DialContext(context.Background(), "tcp", listener.Addr().String())
	if err != nil {
		t.Fatalf("dial: %v", err)
	}
	defer conn.Close()
	tracker, ok := conn.(statistic.Tracker)
	if !ok {
		t.Fatalf("conn %T is not tracked", conn)
	}
	if m := tracker.Info().Metadata; m.RouteReason != tunnel.RouteInternal {
		t.Errorf("pinned DNS reason = %q, want %q", m.RouteReason, tunnel.RouteInternal)
	}
}

func TestProxyViewUoTIsTheConfigNotSmux(t *testing.T) {
	uotOf := func(extra map[string]any) any {
		t.Helper()
		mapping := map[string]any{
			"name": "ss", "type": "ss", "server": "192.0.2.3", "port": 8388,
			"cipher": "aes-128-gcm", "password": "p", "smux": map[string]any{"enabled": true},
		}
		maps.Copy(mapping, extra)
		proxy, err := adapter.ParseProxy(mapping)
		if err != nil {
			t.Fatalf("ParseProxy: %v", err)
		}
		if !proxy.SupportUOT() {
			t.Fatalf("smux SupportUOT = false, want the wrapper to report true")
		}
		data, _ := json.Marshal(proxyView(proxy))
		view := map[string]any{}
		_ = json.Unmarshal(data, &view)
		return view["uot"]
	}
	if uot := uotOf(nil); uot != false {
		t.Errorf("smux node without udp-over-tcp: uot = %v, want false", uot)
	}
	if uot := uotOf(map[string]any{"udp-over-tcp": true}); uot != true {
		t.Errorf("smux node with udp-over-tcp: uot = %v, want true", uot)
	}
}
