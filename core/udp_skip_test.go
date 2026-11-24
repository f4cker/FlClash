package core

import (
	"encoding/json"
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
