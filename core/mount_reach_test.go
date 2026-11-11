package core

import (
	"os"
	"reflect"
	"slices"
	"strings"
	"testing"

	"github.com/metacubex/mihomo/constant"
	cp "github.com/metacubex/mihomo/constant/provider"
	rp "github.com/metacubex/mihomo/rules/provider"
	"go.yaml.in/yaml/v3"
)

func groupReasons(t *testing.T, root *yaml.Node) map[string]string {
	t.Helper()
	target, err := inspectMountTarget(root)
	if err != nil {
		t.Fatal(err)
	}
	reasons := map[string]string{}
	for _, group := range target.Groups {
		reasons[group.Name] = group.Kind + "/" + group.Reason
	}
	return reasons
}

func TestMountReadsRuleSetsGeoIPAndLogicRules(t *testing.T) {
	home := withMountHome(t)
	writeMountFile(t, home, "names.yaml", "payload:\n  - '+.ts.net'\n")
	writeMountFile(t, home, "plain.txt", "google.com\n")
	writeMountFile(t, home, "classic.yaml", "payload:\n  - IP-CIDR6,fd7a:115c:a1e0::/48\n  - DOMAIN,example.com\n")
	writeMountFile(t, home, "classic-miss.yaml", "payload:\n  - DOMAIN,example.com\n  - GEOIP,CN\n")
	writeMountFile(t, home, "broken.mrs", "not a binary rule set\n")
	writeMountFile(t, home, "late.txt", "10.0.0.0/8\n")
	groups := []string{"CGNAT", "Lan", "Names", "Plain", "Classic", "ClassicMiss", "Remote", "Broken", "Missing",
		"Payload", "GeoLan", "GeoPrivate", "GeoCN", "And", "Or", "OrMiss", "Not", "Main"}
	var profile strings.Builder
	profile.WriteString(`proxies:
  - {name: base, type: socks5, server: 127.0.0.9, port: 1080}
rule-providers:
  cgnat: {type: inline, behavior: ipcidr, payload: [100.100.0.0/16]}
  lan: {type: inline, behavior: ipcidr, payload: [192.168.0.0/16]}
  names: {type: file, behavior: domain, path: names.yaml}
  plain: {type: file, behavior: domain, format: text, path: plain.txt}
  classic: {type: file, behavior: classical, path: classic.yaml}
  classic-miss: {type: file, behavior: classical, path: classic-miss.yaml}
  remote: {type: http, behavior: domain, url: "https://rules.invalid/remote.yaml"}
  broken: {type: file, behavior: ipcidr, format: mrs, path: broken.mrs}
  payload: {type: file, behavior: ipcidr, format: text, path: late.txt, payload: [100.64.0.0/10]}
proxy-groups:
`)
	for _, name := range groups {
		profile.WriteString("  - {name: " + name + ", type: select, proxies: [base]}\n")
	}
	profile.WriteString(`rules:
  - RULE-SET,cgnat,CGNAT
  - RULE-SET,lan,Lan
  - RULE-SET,names,Names
  - RULE-SET,plain,Plain
  - RULE-SET,classic,Classic
  - RULE-SET,classic-miss,ClassicMiss
  - RULE-SET,remote,Remote
  - RULE-SET,broken,Broken
  - RULE-SET,missing,Missing
  - RULE-SET,payload,Payload
  - GEOIP,LAN,GeoLan,no-resolve
  - GEOIP,private,GeoPrivate
  - GEOIP,CN,GeoCN
  - AND,((NETWORK,tcp),(IP-CIDR,100.64.0.0/10)),And
  - OR,((DOMAIN,example.com),(DOMAIN-SUFFIX,ts.net)),Or
  - OR,((DOMAIN,example.com),(NETWORK,udp)),OrMiss
  - NOT,((DOMAIN,example.com)),Not
  - MATCH,Main
`)
	want := map[string]string{
		"CGNAT": "excluded/rule", "Lan": "candidate/", "Names": "excluded/rule", "Plain": "candidate/",
		"Classic": "excluded/rule", "ClassicMiss": "candidate/",
		"Remote": "excluded/rule-unknown", "Broken": "excluded/rule-unknown", "Missing": "excluded/rule-unknown",
		"Payload": "excluded/rule", "GeoLan": "excluded/rule", "GeoPrivate": "excluded/rule", "GeoCN": "candidate/",
		"And": "excluded/rule", "Or": "excluded/rule", "OrMiss": "candidate/", "Not": "excluded/rule", "Main": "candidate/",
	}
	got := groupReasons(t, rootOf(t, profile.String()))
	for name, reason := range want {
		if got[name] != reason {
			t.Errorf("%s = %s, want %s", name, got[name], reason)
		}
	}
	// An unread rule set is no empty one, and its cache is left as it is.
	if _, err := os.Stat(constant.Path.GetPathByHash("rules", "https://rules.invalid/remote.yaml")); !os.IsNotExist(err) {
		t.Errorf("the remote rule set's cache = %v, want it left absent", err)
	}
	source := writeMountFile(t, home, "1.yaml", mountSourceB)
	for name, reason := range want {
		setup := &MountSetup{Groups: []string{name}, Sources: []MountSource{{ID: 1, Label: "S", Path: source}}}
		_, err := applyMountOverrides(rootOf(t, profile.String()), setup)
		if refused := err != nil; refused != strings.HasPrefix(reason, mountGroupExcluded) {
			t.Errorf("choosing %s = %v, want refused %v", name, err, !refused)
		}
	}
}

func TestMountFollowsARuleTargetIntoEveryBranchThatMayProxy(t *testing.T) {
	home := withMountHome(t)
	const profile = `proxies:
  - {name: base, type: socks5, server: 127.0.0.9, port: 1080}
proxy-groups:
  - {name: Direct, type: select, proxies: [DIRECT, Proxy]}
  - {name: Proxy, type: select, proxies: [Auto, base]}
  - {name: Auto, type: url-test, include-all-providers: true}
  - {name: OnlyDirect, type: select, proxies: [DIRECT, REJECT]}
  - {name: Free, type: url-test, include-all-providers: true}
  - {name: Main, type: select, proxies: [Free, base]}
rules:
  - GEOIP,LAN,Direct
  - IP-CIDR,100.64.0.0/10,OnlyDirect
  - MATCH,Main
`
	wantReasons := map[string]string{
		"Direct": "excluded/rule", "Proxy": "excluded/member", "Auto": "excluded/member",
		"OnlyDirect": "excluded/rule", "Free": "auto/", "Main": "candidate/",
	}
	got := groupReasons(t, rootOf(t, profile))
	for name, reason := range wantReasons {
		if got[name] != reason {
			t.Errorf("%s = %s, want %s", name, got[name], reason)
		}
	}
	source := writeMountFile(t, home, "1.yaml", mountSourceB)
	members, report := mountedMembers(t, profile, &MountSetup{Groups: []string{"Main"}, Sources: []MountSource{{ID: 1, Label: "S", Path: source}}})
	if slices.Contains(members["Auto"], "us") {
		t.Errorf("Auto = %v, a LAN route through Direct could pick a mounted node", members["Auto"])
	}
	if !slices.Contains(members["Free"], "us") || !slices.Contains(members["Main"], "us") {
		t.Errorf("Free = %v, Main = %v; want both mounted", members["Free"], members["Main"])
	}
	if len(report.Groups) != 2 {
		t.Errorf("groups = %+v, want Free and Main", report.Groups)
	}
}

func TestMountReadsChainsSetOnProvidersAndAnyKeySpelling(t *testing.T) {
	withMountHome(t)
	const profile = `proxies:
  - {name: base, type: socks5, server: 127.0.0.9, port: 1080}
  - {name: ts-office, type: tailscale}
  - {name: spelled, type: socks5, server: 127.0.0.9, port: 1081, Dialer_Proxy: ts-office}
  - {name: numbered, type: socks5, server: 127.0.0.9, port: 1082, dialer-proxy: 7}
proxy-providers:
  chain: {type: inline, dialer-proxy: Office, payload: [{name: c1, type: socks5, server: 127.0.0.9, port: 1}]}
  over: {type: inline, override: {dialer-proxy: ts-office}, payload: [{name: o1, type: socks5, server: 127.0.0.9, port: 2}]}
  inner: {type: inline, payload: [{name: i1, type: socks5, server: 127.0.0.9, port: 3, DIALER-PROXY: Office}]}
  clean: {type: inline, payload: [{name: k1, type: socks5, server: 127.0.0.9, port: 4, dialer-proxy: base}]}
proxy-groups:
  - {name: Office, type: select, proxies: [ts-office]}
  - {name: UsesChain, type: select, use: [chain]}
  - {name: UsesOver, type: select, use: [over]}
  - {name: UsesInner, type: select, use: [inner]}
  - {name: UsesClean, type: select, use: [clean]}
  - {name: HasSpelled, type: select, proxies: [spelled]}
  - {name: Lan, type: select, proxies: [base]}
rules:
  - IP-CIDR,100.64.0.0/10,Lan
  - MATCH,UsesClean
`
	target, err := inspectMountTarget(rootOf(t, profile))
	if err != nil {
		t.Fatal(err)
	}
	// Lan takes Tailscale traffic but relays nothing through it.
	want := []string{"GLOBAL", "HasSpelled", "Office", "UsesChain", "UsesInner", "UsesOver", "spelled", "ts-office"}
	if !reflect.DeepEqual(target.Relay, want) {
		t.Errorf("relay = %v, want %v", target.Relay, want)
	}
	if empty := newMountRelay(nil, nil); !empty.empty() || empty.reaches(globalProxyName) {
		t.Error("with nothing to relay through, GLOBAL is no relay either")
	}
}

func TestMountProviderDropsNodesThatBindAnInterface(t *testing.T) {
	home := withMountHome(t)
	only := writeMountFile(t, home, "1.yaml", `proxies:
  - {name: a, type: socks5, server: 192.0.2.1, port: 1, interface-name: utun4}
  - {name: b, type: socks5, server: 192.0.2.1, port: 2, Interface_Name: en0}
`)
	got := handleInspectMountSource(MountInspectSourceParams{Path: only})
	got.names = nil
	if want := (MountSourceInspection{Status: mountSourceNodes, Listed: 2, UnsupportedExcluded: 2}); !reflect.DeepEqual(got, want) {
		t.Errorf("inspection = %+v, want %+v", got, want)
	}
	const profile = `proxies:
  - {name: base, type: socks5, server: 127.0.0.9, port: 1080}
proxy-groups:
  - {name: Auto, type: url-test, include-all-providers: true}
rules:
  - MATCH,Auto
`
	members, report := mountedMembers(t, profile, &MountSetup{Sources: []MountSource{{ID: 1, Label: "S", Path: only}}})
	if !reflect.DeepEqual(members["Auto"], []string{"REJECT"}) {
		t.Errorf("Auto = %v, want only its REJECT fallback", members["Auto"])
	}
	if source := report.Sources[0]; source.UnsupportedExcluded != 2 || len(source.Nodes) != 0 {
		t.Errorf("source = %+v, want both nodes counted out", source)
	}
}

func TestMountSeesBaseProvidersItCannotReadOnlyWhereTheyAreUsed(t *testing.T) {
	home := withMountHome(t)
	const profile = `proxies:
  - {name: base, type: socks5, server: 127.0.0.9, port: 1080}
proxy-providers:
  remote: {type: http, url: "https://sub.invalid/list.yaml"}
  hidden: {type: inline, override: {override-expr: ['dialer-proxy = "x"']}, payload: [{name: h1, type: socks5, server: 127.0.0.9, port: 2}]}
proxy-groups:
  - {name: Remote, type: select, use: [remote]}
  - {name: Hidden, type: select, use: [hidden]}
  - {name: Outer, type: select, proxies: [Remote, base]}
  - {name: Other, type: select, proxies: [base]}
  - {name: Auto, type: url-test, include-all-providers: true}
rules:
  - MATCH,Other
`
	got := groupReasons(t, rootOf(t, profile))
	for name, reason := range map[string]string{
		"Remote": "excluded/provider-unknown", "Hidden": "excluded/provider-unknown", "Outer": "excluded/provider-unknown",
		"Other": "candidate/", "Auto": "excluded/provider-unknown",
	} {
		if got[name] != reason {
			t.Errorf("%s = %s, want %s", name, got[name], reason)
		}
	}
	if _, err := os.Stat(constant.Path.GetPathByHash("proxies", "https://sub.invalid/list.yaml")); !os.IsNotExist(err) {
		t.Errorf("the remote provider's cache = %v, want it left absent", err)
	}
	source := writeMountFile(t, home, "1.yaml", mountSourceB)
	if _, err := applyMountOverrides(rootOf(t, profile), &MountSetup{Groups: []string{"Other"}, Sources: []MountSource{{ID: 1, Label: "S", Path: source}}}); err != nil {
		t.Errorf("choosing Other = %v, want it mounted", err)
	}
}

type sideUpdater interface {
	SideUpdate([]byte) ([]constant.Proxy, bool, error)
}

func TestMountGateRefusesWhatABaseLoadsAfterTheCheck(t *testing.T) {
	home := withMountHome(t)
	writeMountFile(t, home, "sub.yaml", "proxies:\n  - {name: a, type: socks5, server: 127.0.0.9, port: 1}\n")
	writeMountFile(t, home, "lan.txt", "10.0.0.0/8\n")
	const profile = `proxies:
  - {name: base, type: socks5, server: 127.0.0.9, port: 1080}
  - {name: ts-office, type: tailscale}
proxy-providers:
  sub: {type: file, path: sub.yaml}
rule-providers:
  lan: {type: file, behavior: ipcidr, format: text, path: lan.txt}
  unused: {type: file, behavior: ipcidr, format: text, path: lan.txt}
proxy-groups:
  - {name: Office, type: select, proxies: [ts-office]}
  - {name: Lan, type: select, proxies: [base]}
  - {name: Auto, type: url-test, include-all-providers: true}
rules:
  - RULE-SET,lan,Lan
  - MATCH,Auto
`
	root := rootOf(t, profile)
	source := writeMountFile(t, home, "1.yaml", mountSourceB)
	report, err := applyMountOverrides(root, &MountSetup{Sources: []MountSource{{ID: 1, Label: "S", Path: source}}})
	if err != nil {
		t.Fatal(err)
	}
	installMountGate(report, nil)
	t.Cleanup(func() { installMountGate(nil, nil) })
	cfg := checkOnlyConfig(t, &yaml.Node{Kind: yaml.DocumentNode, Content: []*yaml.Node{root}})
	if got := memberNames(t, cfg, "Auto"); !slices.Contains(got, "a") || !slices.Contains(got, "us") {
		t.Fatalf("Auto = %v, want the base and mounted nodes", got)
	}

	pd := cfg.Providers["sub"].(sideUpdater)
	if _, _, err := pd.SideUpdate([]byte("proxies:\n  - {name: r, type: socks5, server: 127.0.0.9, port: 2, DIALER_PROXY: Office}\n")); err == nil {
		t.Error("an update relaying through Tailscale was taken")
	}
	if got := memberNames(t, cfg, "Auto"); !slices.Contains(got, "a") || slices.Contains(got, "r") {
		t.Errorf("Auto after a refused update = %v, want the loaded node kept", got)
	}
	if err := gateMountProxies("sub", []map[string]any{{"name": "t", "type": "Tailscale"}}, nil); err == nil {
		t.Error("an update holding a Tailscale node was taken")
	}
	if _, _, err := pd.SideUpdate([]byte("proxies:\n  - {name: b, type: socks5, server: 127.0.0.9, port: 3}\n")); err != nil {
		t.Errorf("a plain update = %v, want it taken", err)
	}

	gate := func(name, raw string) error {
		return rp.RuleSetGate(name, nil, []byte(raw), cp.IPCIDR, cp.TextRule)
	}
	if gate("lan", "100.100.0.0/16\n") == nil {
		t.Error("a rule set update sending Tailscale addresses to Lan was taken")
	}
	if err := gate("lan", "192.168.0.0/16\n"); err != nil {
		t.Errorf("a rule set update without Tailscale = %v", err)
	}
	if err := gate("unused", "100.100.0.0/16\n"); err != nil {
		t.Errorf("a rule set no rule reads = %v, want it taken", err)
	}
	if got := handleMountState().Refused; !reflect.DeepEqual(got, []string{"lan", "sub"}) {
		t.Errorf("refused = %v, want [lan sub]", got)
	}

	installMountGate(nil, nil)
	if err := gateMountProxies("sub", []map[string]any{{"name": "t", "type": "tailscale"}}, nil); err != nil {
		t.Errorf("without mounts = %v, want nothing gated", err)
	}
}

func TestMountRuntimeCheckFindsAMountedNodeOnATailscalePath(t *testing.T) {
	home := withMountHome(t)
	const profile = `proxies:
  - {name: base, type: socks5, server: 127.0.0.9, port: 1080}
proxy-groups:
  - {name: Main, type: select, proxies: [Auto, base]}
  - {name: Auto, type: url-test, include-all-providers: true}
  - {name: Lan, type: select, proxies: [base]}
rules:
  - MATCH,Main
`
	source := writeMountFile(t, home, "1.yaml", mountSourceB)
	root := rootOf(t, profile)
	if _, err := applyMountOverrides(root, &MountSetup{Sources: []MountSource{{ID: 1, Label: "S", Path: source}}}); err != nil {
		t.Fatal(err)
	}
	cfg := checkOnlyConfig(t, &yaml.Node{Kind: yaml.DocumentNode, Content: []*yaml.Node{root}})
	if err := mountRuntimeViolation(cfg.Proxies, map[string]string{"Lan": reachRule}); err != nil {
		t.Errorf("Lan = %v, want no mounted node found", err)
	}
	if err := mountRuntimeViolation(cfg.Proxies, map[string]string{"Main": reachRule}); err == nil {
		t.Error("Main reaches a mounted node through Auto, want it found")
	}
}

// Round 4: every path the review found Tailscale traffic could take into a
// group that is not a rule target, each with the reason the panel shows.
func TestMountExcludesEveryGroupTailscaleTrafficMayTake(t *testing.T) {
	withMountHome(t)
	const base = `proxies:
  - {name: hk, type: socks5, server: 127.0.0.9, port: 1080}
  - {name: ts-office, type: tailscale, dialer-proxy: Auto}
  - {name: jump, type: socks5, server: 127.0.0.9, port: 1081, dialer-proxy: Pick}
proxy-groups:
  - {name: Main, type: select, proxies: [Auto, hk]}
  - {name: Auto, type: url-test, include-all-providers: true}
  - {name: Pick, type: select, proxies: [Inner]}
  - {name: Inner, type: select, proxies: [hk]}
  - {name: Free, type: select, proxies: [hk]}
rules:
  - IP-CIDR,100.64.0.0/10,jump,no-resolve
  - MATCH,Main
`
	wantReasons := func(name, profile string, want map[string]string) {
		t.Helper()
		got := groupReasons(t, rootOf(t, profile))
		for group, reason := range want {
			if got[group] != reason {
				t.Errorf("%s: %s = %s, want %s", name, group, got[group], reason)
			}
		}
	}
	wantReasons("dialer chains", base, map[string]string{
		"Auto": "excluded/carrier", "Pick": "excluded/carrier", "Inner": "excluded/carrier",
		"Main": "candidate/", "Free": "candidate/",
	})
	plain := strings.NewReplacer(", dialer-proxy: Auto}", "}", "  - IP-CIDR,100.64.0.0/10,jump,no-resolve\n", "").Replace(base)
	// jump still dials through Pick: whatever it carries, Pick may not take
	// mounts, nor anything Pick may select.
	wantReasons("no Tailscale chain", plain, map[string]string{"Auto": "auto/", "Pick": "excluded/dialer", "Inner": "excluded/dialer", "Free": "candidate/"})
	unchained := strings.Replace(plain, ", dialer-proxy: Pick}", "}", 1)
	wantReasons("no chain", unchained, map[string]string{"Auto": "auto/", "Pick": "candidate/", "Inner": "candidate/", "Free": "candidate/"})

	cases := []struct {
		name, add string
		want      map[string]string
	}{
		{"GLOBAL target", "rules:\n  - IP-CIDR,100.64.0.0/10,GLOBAL\n", map[string]string{"Free": "excluded/global", "Main": "excluded/global"}},
		{"listener proxy", "listeners:\n  - {name: in, type: mixed, port: 7891, proxy: Free}\n", map[string]string{"Free": "excluded/rule", "Main": "candidate/"}},
		{"listener sub-rule", "listeners:\n  - {name: in, type: mixed, port: 7891, rule: side}\nsub-rules:\n  side:\n    - MATCH,Free\n", map[string]string{"Free": "excluded/rule"}},
		{"tunnel", "tunnels:\n  - tcp,127.0.0.1:2222,100.100.1.1:22,Free\n  - {network: [tcp], address: 127.0.0.1:2223, target: 192.0.2.1:22, proxy: Main}\n", map[string]string{"Free": "excluded/rule", "Main": "candidate/"}},
		{"sub-rule entered by a tailnet condition", "sub-rules:\n  side:\n    - DST-PORT,22,Free\n    - MATCH,Main\n", map[string]string{"Free": "excluded/rule", "Main": "excluded/rule"}},
		{"GEOSITE without a database", "rules:\n  - GEOSITE,tailscale,Free\n", map[string]string{"Free": "excluded/rule-unknown"}},
		{"DNS through a group", "dns:\n  nameserver: ['https://1.1.1.1/dns-query#Free&h3=true']\n", map[string]string{"Free": "excluded/dns", "Main": "candidate/"}},
		{"DNS by rules", "dns:\n  respect-rules: true\n  nameserver: [1.1.1.1]\n", map[string]string{"Free": "excluded/dns", "Main": "excluded/dns"}},
		{"empty-fallback on a Tailscale node", "", map[string]string{"Fallen": "excluded/holds"}},
		{"group keys in any case", "", map[string]string{"Spelled": "excluded/holds"}},
	}
	for _, tc := range cases {
		profile := plain
		switch tc.name {
		case "empty-fallback on a Tailscale node":
			profile = strings.Replace(profile, "proxy-groups:\n", "proxy-groups:\n  - {name: Fallen, type: select, proxies: [hk], filter: none, empty-fallback: ts-office}\n", 1)
		case "group keys in any case":
			profile = strings.Replace(profile, "proxy-groups:\n", "proxy-groups:\n  - {Name: Spelled, Type: select, Proxies: [ts-office]}\n", 1)
		case "sub-rule entered by a tailnet condition":
			profile = strings.Replace(profile, "  - MATCH,Main\n", "  - SUB-RULE,(IP-CIDR,100.64.0.0/10),side\n  - MATCH,Main\n", 1) + tc.add
		case "GLOBAL target", "GEOSITE without a database":
			profile = strings.Replace(profile, "rules:\n", tc.add, 1)
		default:
			profile += tc.add
		}
		wantReasons(tc.name, profile, tc.want)
	}
}

func TestMountSourceDropsNodesWhoseServerIsOnTailscaleOrLocal(t *testing.T) {
	home := withMountHome(t)
	source := writeMountFile(t, home, "1.yaml", `proxies:
  - {name: loop, type: socks5, server: 127.0.0.1, port: 1055}
  - {name: tailnet, type: socks5, server: 100.100.2.3, port: 1080}
  - {name: magic, type: socks5, server: box.tail1.ts.net, port: 1080}
  - {name: marked, type: socks5, server: 192.0.2.1, port: 1, routing-mark: 6666}
  - {name: plain, type: socks5, server: 192.0.2.1, port: 2}
`)
	got := handleInspectMountSource(MountInspectSourceParams{Path: source})
	if got.Count != 1 || got.RelayExcluded != 3 || got.UnsupportedExcluded != 1 || !reflect.DeepEqual(got.names, []string{"plain"}) {
		t.Errorf("inspection = %+v, want plain kept, three relays and one mark counted out", got)
	}
	const profile = `proxies:
  - {name: base, type: socks5, server: 127.0.0.9, port: 1080}
proxy-groups:
  - {name: Auto, type: url-test, include-all-providers: true}
rules:
  - MATCH,Auto
`
	members, report := mountedMembers(t, profile, &MountSetup{Sources: []MountSource{{ID: 1, Label: "S", Path: source}}})
	if !reflect.DeepEqual(members["Auto"], []string{"plain"}) {
		t.Errorf("Auto = %v, want only plain", members["Auto"])
	}
	if names := report.Sources[0].Nodes; len(names) != 1 || names[0].Name != "plain" {
		t.Errorf("report nodes = %+v, want plain", names)
	}
}
