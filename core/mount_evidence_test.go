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
	switchedOn := "excluded/tailscale/rule"
	for _, tc := range []struct {
		name    string
		profile string
		want    map[string]string
	}{
		{"acl-like, LAN rule set on a direct-or-proxy switch", aclLikeProfile, map[string]string{
			"🎯 全球直连": switchedOn, "🚀 节点选择": "excluded/tailscale/member", "♻️ 自动选择": "excluded/tailscale/member",
			"📲 电报消息": "candidate//", "🛑 全球拦截": "candidate//", "🐟 漏网之鱼": "candidate//",
		}},
		{"acl-like, direct-only LAN target", directOnly, map[string]string{
			"🎯 全球直连": switchedOn, "🚀 节点选择": "candidate//", "♻️ 自动选择": "auto//",
			"📲 电报消息": "candidate//", "🛑 全球拦截": "candidate//", "🐟 漏网之鱼": "candidate//",
		}},
		{"acl-like, LAN rule set not cached", uncached, map[string]string{
			"🎯 全球直连": "excluded/tailscale/rule-unknown", "🚀 节点选择": "excluded/tailscale/member",
			"♻️ 自动选择": "excluded/tailscale/member", "📲 电报消息": "candidate//", "🛑 全球拦截": "candidate//",
		}},
		{"plain", plain, map[string]string{"Proxy": "candidate//", "Auto": "auto//", "Direct": "candidate//"}},
	} {
		target, err := inspectMountTarget(rootOf(t, tc.profile))
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

	source := writeMountFile(t, home, "1.yaml", mountSourceB)
	members, _ := mountedMembers(t, aclLikeProfile, &MountSetup{Groups: []string{"🐟 漏网之鱼", "📲 电报消息"}, Sources: []MountSource{{ID: 1, Label: "S", Path: source}}})
	for _, group := range []string{"🎯 全球直连", "🚀 节点选择", "♻️ 自动选择"} {
		if slices.Contains(members[group], "us") {
			t.Errorf("%s = %v, a LAN route could reach a mounted node", group, members[group])
		}
	}
	if !slices.Contains(members["🐟 漏网之鱼"], "us") || !slices.Contains(members["📲 电报消息"], "us") {
		t.Errorf("漏网之鱼 = %v, 电报消息 = %v; want both mounted", members["🐟 漏网之鱼"], members["📲 电报消息"])
	}
	t.Logf("mounted into 漏网之鱼 and 电报消息: %v", members)
}
