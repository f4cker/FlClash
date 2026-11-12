package core

import (
	"fmt"
	"slices"
	"strings"
	"testing"
)

const aclLikeProfile = `proxies:
  - {name: hk, type: socks5, server: 127.0.0.9, port: 1080}
proxy-groups:
  - {name: 🚀 节点选择, type: select, proxies: [♻️ 自动选择, DIRECT, hk]}
  - {name: ♻️ 自动选择, type: url-test, include-all-providers: true}
  - {name: 📲 电报消息, type: select, proxies: [🚀 节点选择, ♻️ 自动选择, DIRECT]}
  - {name: 🎯 全球直连, type: select, proxies: [DIRECT, 🚀 节点选择]}
  - {name: 🛑 全球拦截, type: select, proxies: [REJECT, DIRECT]}
  - {name: 🐟 漏网之鱼, type: select, proxies: [🚀 节点选择, 🎯 全球直连, hk]}
rule-providers:
  LocalAreaNetwork: {type: inline, behavior: classical, payload: ['IP-CIDR,192.168.0.0/16', 'IP-CIDR,100.64.0.0/10', 'DOMAIN-SUFFIX,local']}
  BanAD: {type: file, behavior: domain, path: banad.yaml}
rules:
  - RULE-SET,LocalAreaNetwork,🎯 全球直连
  - RULE-SET,BanAD,🛑 全球拦截
  - DOMAIN-SUFFIX,t.me,📲 电报消息
  - GEOIP,CN,🎯 全球直连
  - MATCH,🐟 漏网之鱼
`

// Synthetic configs shaped like the ones mounts meet, each with what the
// mount check makes of every group; run with -v for the table.
func TestMountRepresentativeConfigs(t *testing.T) {
	home := withMountHome(t)
	writeMountFile(t, home, "banad.yaml", "payload:\n  - '+.ads.example'\n")
	directOnly := strings.Replace(aclLikeProfile, "[DIRECT, 🚀 节点选择]", "[DIRECT]", 1)
	uncached := strings.Replace(aclLikeProfile,
		"LocalAreaNetwork: {type: inline, behavior: classical, payload: ['IP-CIDR,192.168.0.0/16', 'IP-CIDR,100.64.0.0/10', 'DOMAIN-SUFFIX,local']}",
		"LocalAreaNetwork: {type: http, behavior: classical, url: 'https://rules.invalid/lan.yaml'}", 1)
	const plain = `proxies:
  - {name: hk, type: socks5, server: 127.0.0.9, port: 1080}
proxy-groups:
  - {name: Proxy, type: select, proxies: [Auto, hk]}
  - {name: Auto, type: url-test, include-all-providers: true}
  - {name: Direct, type: select, proxies: [DIRECT, Proxy]}
rules:
  - DOMAIN-SUFFIX,example.cn,Direct
  - MATCH,Proxy
`
	fixed := "fixed//"
	for _, tc := range []struct {
		name    string
		profile string
		want    map[string]string
	}{
		{"acl-like, LAN rule set on a direct-or-proxy switch", aclLikeProfile, map[string]string{
			"🎯 全球直连": fixed, "🚀 节点选择": fixed, "♻️ 自动选择": "excluded/tailscale/member",
			"📲 电报消息": fixed, "🛑 全球拦截": fixed, "🐟 漏网之鱼": fixed,
		}},
		{"acl-like, direct-only LAN target", directOnly, map[string]string{
			"🎯 全球直连": fixed, "🚀 节点选择": fixed, "♻️ 自动选择": "auto//",
			"📲 电报消息": fixed, "🛑 全球拦截": fixed, "🐟 漏网之鱼": fixed,
		}},
		{"acl-like, LAN rule set not cached", uncached, map[string]string{
			"🎯 全球直连": fixed, "🚀 节点选择": fixed,
			"♻️ 自动选择": "excluded/tailscale/member", "📲 电报消息": fixed, "🛑 全球拦截": fixed,
		}},
		{"plain", plain, map[string]string{"Proxy": fixed, "Auto": "auto//", "Direct": fixed}},
	} {
		target, err := inspectMountTarget(rootOf(t, tc.profile), 0)
		if err != nil {
			t.Fatal(err)
		}
		var table strings.Builder
		for _, group := range target.Groups {
			got := fmt.Sprintf("%s/%s/%s", group.Kind, group.Excluded, group.Reason)
			fmt.Fprintf(&table, "\n  %-8s %s", got, group.Name)
			if want, ok := tc.want[group.Name]; ok && got != want {
				t.Errorf("%s: %s = %s, want %s", tc.name, group.Name, got, want)
			}
		}
		t.Logf("%s; relay %v:%s", tc.name, target.Relay, table.String())
	}

	// The LAN switch may select 自动选择, the only collecting group.
	source := writeMountFile(t, home, "1.yaml", mountSourceB)
	setup := &MountSetup{Sources: []MountSource{{ID: 1, Label: "S", Path: source}}}
	members, report := mountedMembers(t, aclLikeProfile, setup)
	if len(report.Groups) != 0 || slices.Contains(members["♻️ 自动选择"], "us") {
		t.Errorf("groups = %+v, 自动选择 = %v; want nothing mounted", report.Groups, members["♻️ 自动选择"])
	}
	members, report = mountedMembers(t, directOnly, setup)
	if len(report.Groups) != 1 || !slices.Contains(members["♻️ 自动选择"], "us") {
		t.Errorf("groups = %+v, 自动选择 = %v; want only 自动选择 mounted", report.Groups, members["♻️ 自动选择"])
	}
	for _, group := range []string{"🚀 节点选择", "📲 电报消息", "🐟 漏网之鱼", "🎯 全球直连"} {
		if slices.Contains(members[group], "us") {
			t.Errorf("%s = %v, want its members as written", group, members[group])
		}
	}
}
