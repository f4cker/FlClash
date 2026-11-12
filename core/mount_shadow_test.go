//go:build with_gvisor && !no_tailscale

package core

import (
	"context"
	"fmt"
	"net/netip"
	"os"
	"regexp"
	"slices"
	"strings"
	"testing"

	"github.com/metacubex/mihomo/component/flashguard"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
)

// A typical airport profile: category selectors over region groups.
func liteProfile() string {
	regions := []struct{ name, filter string }{
		{"香港策略", "(?i)港|HK"}, {"台湾策略", "(?i)台|TW"}, {"日本策略", "(?i)日本|JP"},
		{"狮城策略", "(?i)新加坡|狮城|SG"}, {"韩国策略", "(?i)韩|KR"}, {"美国策略", "(?i)美|US"},
	}
	var regionNames []string
	for _, region := range regions {
		regionNames = append(regionNames, region.name)
	}
	picks := strings.Join(regionNames, ", ")
	var b strings.Builder
	b.WriteString(`proxy-providers:
  airport:
    type: inline
    payload:
      - {name: 香港 A01, type: socks5, server: 192.0.2.10, port: 1080}
      - {name: 美国 A01, type: socks5, server: 192.0.2.11, port: 1080}
proxy-groups:
`)
	for _, category := range []string{"即时通讯", "社交平台", "人工智能", "开发服务", "国际媒体", "谷歌服务", "国外流量"} {
		fmt.Fprintf(&b, "  - {name: %s, type: select, proxies: [%s, 故障转移, 全球手动, DIRECT]}\n", category, picks)
	}
	b.WriteString("  - {name: 苹果服务, type: select, proxies: [DIRECT, " + picks + ", 全球手动]}\n")
	b.WriteString("  - {name: 国内流量, type: select, proxies: [DIRECT, 全球手动]}\n")
	b.WriteString("  - {name: 故障转移, type: fallback, include-all: true, url: 'https://www.gstatic.com/generate_204', interval: 300}\n")
	b.WriteString("  - {name: 全球手动, type: select, include-all: true}\n")
	for _, region := range regions {
		fmt.Fprintf(&b, "  - {name: %s, type: url-test, include-all: true, filter: '%s', url: 'https://www.gstatic.com/generate_204', interval: 300}\n", region.name, region.filter)
	}
	b.WriteString("rule-providers:\n")
	sets := []struct{ name, behavior, format, target string }{
		{"private", "domain", "yaml", "DIRECT"}, {"lancidr", "ipcidr", "text", "DIRECT"},
		{"applications", "classical", "text", "DIRECT"}, {"telegram", "ipcidr", "mrs", "即时通讯"},
		{"telegram-domain", "domain", "mrs", "即时通讯"}, {"twitter", "domain", "mrs", "社交平台"},
		{"facebook", "classical", "yaml", "社交平台"}, {"openai", "classical", "text", "人工智能"},
		{"claude", "domain", "text", "人工智能"}, {"github", "domain", "mrs", "开发服务"},
		{"youtube", "domain", "mrs", "国际媒体"}, {"netflix", "classical", "yaml", "国际媒体"},
		{"netflix-ip", "ipcidr", "mrs", "国际媒体"}, {"google", "domain", "mrs", "谷歌服务"},
		{"google-ip", "ipcidr", "mrs", "谷歌服务"}, {"apple", "domain", "text", "苹果服务"},
		{"proxy", "domain", "yaml", "国外流量"}, {"gfw", "domain", "mrs", "国外流量"},
		{"cn", "domain", "mrs", "国内流量"}, {"cn-ip", "ipcidr", "mrs", "国内流量"},
	}
	for _, set := range sets {
		fmt.Fprintf(&b, "  %s: {type: http, behavior: %s, format: %s, url: 'http://127.0.0.1:9/%s', path: ./rules/%s.%s, interval: 86400}\n",
			set.name, set.behavior, set.format, set.name, set.name, set.format)
	}
	b.WriteString("rules:\n")
	for _, set := range sets {
		suffix := ""
		if set.behavior == "ipcidr" {
			suffix = ",no-resolve"
		}
		fmt.Fprintf(&b, "  - RULE-SET,%s,%s%s\n", set.name, set.target, suffix)
	}
	b.WriteString("  - GEOIP,private,DIRECT,no-resolve\n  - GEOIP,CN,国内流量\n  - MATCH,国外流量\n")
	return b.String()
}

// liteGroupLine is the flow line declaring group in profile.
func liteGroupLine(profile, group string) string {
	for _, line := range strings.Split(profile, "\n") {
		if strings.Contains(line, "{name: "+group+",") {
			return line
		}
	}
	return ""
}

var liteOrdinaryGroups = []string{
	"即时通讯", "社交平台", "人工智能", "开发服务", "国际媒体", "谷歌服务", "苹果服务", "国外流量", "国内流量",
	"故障转移", "全球手动", "香港策略", "台湾策略", "日本策略", "狮城策略", "韩国策略", "美国策略",
}

const liteMountSource = `proxies:
  - {name: 香港 M01, type: socks5, server: 192.0.2.20, port: 1080}
  - {name: 台湾 M01, type: socks5, server: 192.0.2.21, port: 1080}
  - {name: 日本 M01, type: socks5, server: 192.0.2.22, port: 1080}
  - {name: 新加坡 M01, type: socks5, server: 192.0.2.23, port: 1080}
  - {name: 韩国 M01, type: socks5, server: 192.0.2.24, port: 1080}
  - {name: 美国 M01, type: socks5, server: 192.0.2.25, port: 1080}
`

// Some send tailnet names and ranges; the .mrs ones were never downloaded.
func writeLiteRuleSets(t *testing.T, home string) {
	t.Helper()
	dir := home + "/rules"
	if err := os.MkdirAll(dir, 0o700); err != nil {
		t.Fatal(err)
	}
	writeMountFile(t, dir, "private.yaml", "payload:\n  - '+.local'\n  - '+.ts.net'\n")
	writeMountFile(t, dir, "lancidr.text", "10.0.0.0/8\n100.64.0.0/10\n192.168.0.0/16\n")
	writeMountFile(t, dir, "proxy.yaml", "payload:\n  - '+.ts.net'\n  - '+.corp.example'\n  - '+.google.com'\n")
	writeMountFile(t, dir, "openai.text", "DOMAIN-SUFFIX,openai.com\nIP-CIDR,100.64.0.0/10,no-resolve\n")
}

func TestMountedAirportProfileKeepsTailscaleOffMountedNodes(t *testing.T) {
	home := withMountHome(t)
	writeLiteRuleSets(t, home)
	if err := os.MkdirAll(tailscaleRoutesDir(), 0o700); err != nil {
		t.Fatal(err)
	}
	writeMountFile(t, tailscaleRoutesDir(), "routes-9.json",
		`{"version": 1, "accounts": {}, "suffixes": ["corp.example"], "lists": {"m1": {"suffix": "corp.example"}}}`)
	profile := liteProfile()

	base, err := readMountBase(rootOf(t, profile))
	if err != nil {
		t.Fatal(err)
	}
	if reach := base.tailscaleGroups(newRuleReader(base)); reach["即时通讯"] == "" || reach["国外流量"] == "" {
		t.Errorf("without managed rules: 即时通讯 %q, 国外流量 %q; want both excluded", reach["即时通讯"], reach["国外流量"])
	}
	target, err := inspectMountTarget(rootOf(t, profile), 9)
	if err != nil {
		t.Fatal(err)
	}
	for _, group := range target.Groups {
		if group.Kind == mountGroupExcluded {
			t.Errorf("inspect with managed rules: %s excluded for %s", group.Name, group.Reason)
		}
	}

	source := writeMountFile(t, home, "1.yaml", liteMountSource)
	mounts := &MountSetup{Target: 9, Revision: "r", Sources: []MountSource{{ID: 1, Label: "S", Path: source}}}
	setup := &TailscaleSetup{ProfileID: 9, Managed: []TailscaleManagedSetup{{ID: "m1", Name: "Work", Attached: true}}}
	applyMountedTailscale(t, home, liteSections(profile, false), liteSections(profile, true), mounts, setup)
	if state := handleMountState(); state.Blocked || len(state.Refused) > 0 {
		t.Fatalf("state = blocked %v, refused %v", state.Blocked, state.Refused)
	}

	proxies := tunnel.Proxies()
	mountedIn := func(group string) []string {
		var names []string
		for _, member := range groupMembers(t, proxies, group) {
			if strings.HasSuffix(member, " M01") {
				names = append(names, member)
			}
		}
		return names
	}
	all := []string{"香港 M01", "台湾 M01", "日本 M01", "新加坡 M01", "韩国 M01", "美国 M01"}
	for _, group := range liteOrdinaryGroups {
		want := all
		if !strings.Contains(liteGroupLine(profile, group), "include-all") {
			want = nil
		} else if filter := liteFilterOf(profile, group); filter != nil {
			want = slices.DeleteFunc(slices.Clone(all), func(name string) bool { return !filter.MatchString(name) })
		}
		if got := mountedIn(group); !slices.Equal(got, want) {
			t.Errorf("%s holds mounted %v, want %v", group, got, want)
		}
	}

	for _, dest := range []struct {
		label string
		meta  constant.Metadata
	}{
		{"tailnet IPv4", constant.Metadata{DstIP: netip.MustParseAddr("100.101.102.103"), DstPort: 443}},
		{"tailnet IPv6", constant.Metadata{DstIP: netip.MustParseAddr("fd7a:115c:a1e0::1"), DstPort: 443}},
		{"MagicDNS name", constant.Metadata{Host: "nas.tail1234.ts.net", DstPort: 443}},
		{"MagicDNS name as typed", constant.Metadata{Host: "NAS.Tail1234.TS.NET.", DstPort: 443}},
		{"remembered suffix", constant.Metadata{Host: "git.corp.example", DstPort: 443}},
		{"MagicDNS name resolving", constant.Metadata{Host: "nas.tail1234.ts.net", DstIP: netip.MustParseAddr("100.101.102.103"), DstPort: 22}},
		{"other name already resolved", constant.Metadata{Host: "nas.example.com", DstIP: netip.MustParseAddr("100.101.102.103"), DstPort: 22}},
	} {
		for _, network := range []constant.NetWork{constant.TCP, constant.UDP} {
			meta := dest.meta
			meta.NetWork = network
			name := matchRules(t, proxies, &meta, netip.Addr{})
			if member := mountedMemberOf(proxies, name, map[string]bool{}); member != "" || strings.HasSuffix(name, " M01") {
				t.Errorf("%s over %v goes to %s, which can take the mounted node %s", dest.label, network, name, member)
			}
			if proxy := proxies[name]; name != "REJECT" && proxy.Type() != constant.Tailscale {
				t.Errorf("%s over %v goes to %s; want the managed node or REJECT", dest.label, network, name)
			}
		}
	}
	// Another name resolved into a tailnet range only after the managed
	// rules may reach a mounted node, which refuses it.
	other := &constant.Metadata{NetWork: constant.TCP, Host: "nas.example.com", DstPort: 22}
	if name := matchRules(t, proxies, other, netip.MustParseAddr("100.101.102.103")); name != "国外流量" {
		t.Errorf("nas.example.com goes to %s; want 国外流量, the case the guard holds", name)
	}
	for _, name := range all {
		if err := flashguard.Check(context.Background(), name, "192.0.2.20", other); !flashguard.IsRefused(err) {
			t.Errorf("%s dialing nas.example.com resolved to 100.101.102.103 = %v; want refused", name, err)
		}
	}
	ordinary := &constant.Metadata{NetWork: constant.TCP, Host: "example.org", DstPort: 443}
	if name := matchRules(t, proxies, ordinary, netip.Addr{}); name != "国外流量" || mountedMemberOf(proxies, name, map[string]bool{}) == "" {
		t.Errorf("example.org goes to %s; want 国外流量 holding mounted nodes", name)
	}
}

// As the tunnel matches: the first rule whose adapter exists and, for UDP,
// supports it.
func matchRules(t *testing.T, proxies map[string]constant.Proxy, meta *constant.Metadata, resolved netip.Addr) string {
	t.Helper()
	resolve := func() {
		if !meta.DstIP.IsValid() {
			meta.DstIP = resolved
		}
	}
	for _, rule := range tunnel.Rules() {
		matched, name := rule.Match(meta, constant.RuleMatchHelper{ResolveIP: resolve, FindProcess: func() {}})
		if !matched {
			continue
		}
		proxy, ok := proxies[name]
		if !ok || meta.NetWork == constant.UDP && !proxy.SupportUDP() {
			continue
		}
		return name
	}
	t.Fatalf("no rule matched %+v", meta)
	return ""
}

func groupMembers(t *testing.T, proxies map[string]constant.Proxy, group string) []string {
	t.Helper()
	proxyGroup, ok := adapterAs[interface{ Proxies() []constant.Proxy }](proxies[group])
	if !ok {
		t.Fatalf("%s is not a group", group)
	}
	var names []string
	for _, member := range proxyGroup.Proxies() {
		names = append(names, member.Name())
	}
	return names
}

func liteSections(profile string, providers bool) string {
	var b strings.Builder
	in := false
	for _, line := range strings.SplitAfter(profile, "\n") {
		if line != "" && line[0] != ' ' {
			in = strings.HasPrefix(line, "proxy-providers:") || strings.HasPrefix(line, "rule-providers:")
		}
		if in == providers {
			b.WriteString(line)
		}
	}
	return b.String()
}

func liteFilterOf(profile, group string) *regexp.Regexp {
	for _, line := range strings.Split(profile, "\n") {
		if !strings.Contains(line, "name: "+group+",") {
			continue
		}
		if _, filter, ok := strings.Cut(line, "filter: '"); ok {
			filter, _, _ = strings.Cut(filter, "'")
			return regexp.MustCompile(filter)
		}
	}
	return nil
}
