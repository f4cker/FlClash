package core

import (
	"errors"
	"os"
	"reflect"
	"slices"
	"strings"
	"testing"

	"github.com/metacubex/mihomo/adapter/provider"
	"go.yaml.in/yaml/v3"
)

func groupKinds(t *testing.T, root *yaml.Node) map[string]string {
	t.Helper()
	target, err := inspectMountTarget(root)
	if err != nil {
		t.Fatal(err)
	}
	kinds := map[string]string{}
	for _, group := range target.Groups {
		kinds[group.Name] = group.Kind + "/" + group.Excluded
	}
	return kinds
}

func wantKinds(t *testing.T, got, want map[string]string) {
	t.Helper()
	for name, kind := range want {
		if got[name] != kind {
			t.Errorf("%s = %s, want %s", name, got[name], kind)
		}
	}
}

func refusedChoice(t *testing.T, profile, group, source string) {
	t.Helper()
	setup := &MountSetup{Groups: []string{group}, Sources: []MountSource{{ID: 1, Label: "S", Path: source}}}
	_, err := applyMountOverrides(rootOf(t, profile), setup)
	var methodErr *MethodError
	if !errors.As(err, &methodErr) || methodErr.Code != "mount_group_changed" {
		t.Errorf("a stored choice of %s = %v, want it refused", group, err)
	}
}

func mountedMembers(t *testing.T, profile string, setup *MountSetup) (map[string][]string, *MountReport) {
	t.Helper()
	root := rootOf(t, profile)
	report, err := applyMountOverrides(root, setup)
	if err != nil {
		t.Fatal(err)
	}
	cfg := checkOnlyConfig(t, &yaml.Node{Kind: yaml.DocumentNode, Content: []*yaml.Node{root}})
	members := map[string][]string{}
	for _, group := range resolveAlias(mappingValue(root, "proxy-groups")).Content {
		name := mappingValue(group, "name").Value
		members[name] = memberNames(t, cfg, name)
	}
	return members, report
}

func TestMountSeesTailscaleNodesHeldByABaseProvider(t *testing.T) {
	home := withMountHome(t)
	writeMountFile(t, home, "cached.yaml", "proxies:\n  - {name: ts-cached, type: tailscale}\n")
	const profile = `proxies:
  - {name: base, type: socks5, server: 127.0.0.9, port: 1080}
proxy-providers:
  tsp: {type: inline, payload: [{name: ts-home, type: tailscale}]}
  cached: {type: file, path: cached.yaml}
  dropped: {type: inline, exclude-type: "SOCKS5|tailscale", payload: [{name: ts-dropped, type: tailscale}]}
proxy-groups:
  - {name: Providers, type: url-test, include-all-providers: true}
  - {name: Uses, type: select, use: [tsp], proxies: [base]}
  - {name: UsesCache, type: select, use: [cached], proxies: [base]}
  - {name: Everything, type: select, include-all: true}
  - {name: Typed, type: url-test, include-all-providers: true, exclude-type: tailscale}
  - {name: Dropped, type: select, use: [dropped], proxies: [base]}
`
	wantKinds(t, groupKinds(t, rootOf(t, profile)), map[string]string{
		"Providers":  "excluded/tailscale",
		"Uses":       "excluded/tailscale",
		"UsesCache":  "excluded/tailscale",
		"Everything": "excluded/tailscale",
		"Typed":      "auto/",
		"Dropped":    "candidate/",
	})
	source := writeMountFile(t, home, "1.yaml", mountSourceB)
	refusedChoice(t, profile, "Uses", source)
	refusedChoice(t, profile, "UsesCache", source)

	loadable := strings.NewReplacer(
		"  cached: {type: file, path: cached.yaml}\n", "",
		"  - {name: UsesCache, type: select, use: [cached], proxies: [base]}\n", "",
	).Replace(profile)
	members, _ := mountedMembers(t, loadable, &MountSetup{Groups: []string{"Dropped"}, Sources: []MountSource{{ID: 1, Label: "S", Path: source}}})
	for _, group := range []string{"Providers", "Everything"} {
		if slices.Contains(members[group], "us") {
			t.Errorf("%s = %v, holds a mounted node", group, members[group])
		}
		if !slices.Contains(members[group], "ts-home") {
			t.Errorf("%s = %v, lost its base provider", group, members[group])
		}
	}
	if !slices.Contains(members["Typed"], "us") || !slices.Contains(members["Dropped"], "us") {
		t.Errorf("Typed = %v, Dropped = %v; want both mounted", members["Typed"], members["Dropped"])
	}
}

func TestMountKeepsGroupsInsideATailscaleGroupFreeOfMountedNodes(t *testing.T) {
	home := withMountHome(t)
	const profile = `proxies:
  - {name: base, type: socks5, server: 127.0.0.9, port: 1080}
  - {name: ts-office, type: tailscale}
proxy-groups:
  - {name: Office, type: fallback, proxies: [ts-office, Pool]}
  - {name: Pool, type: url-test, include-all-providers: true}
  - {name: Desk, type: select, proxies: [ts-office, Inner]}
  - {name: Inner, type: select, proxies: [Deep]}
  - {name: Deep, type: url-test, include-all-providers: true, proxies: [base]}
  - {name: Pick, type: url-test, proxies: [ts-office, Chosen]}
  - {name: Chosen, type: select, proxies: [base]}
  - {name: Free, type: url-test, include-all-providers: true}
rules:
  - IP-CIDR,100.64.0.0/10,Office
  - MATCH,Free
`
	wantKinds(t, groupKinds(t, rootOf(t, profile)), map[string]string{
		"Pool":   "excluded/tailscale",
		"Inner":  "excluded/tailscale",
		"Deep":   "excluded/tailscale",
		"Chosen": "excluded/tailscale",
		"Free":   "auto/",
	})
	source := writeMountFile(t, home, "1.yaml", mountSourceB)
	refusedChoice(t, profile, "Chosen", source)

	members, report := mountedMembers(t, profile, &MountSetup{Sources: []MountSource{{ID: 1, Label: "S", Path: source}}})
	for _, group := range []string{"Pool", "Deep"} {
		if slices.Contains(members[group], "us") {
			t.Errorf("%s = %v, holds a mounted node", group, members[group])
		}
	}
	if !slices.Contains(members["Free"], "us") {
		t.Errorf("Free = %v, want the mounted nodes", members["Free"])
	}
	if !reflect.DeepEqual(report.Groups, []MountGroupReport{{Name: "Free", Via: "auto", Protection: mountProtectionReject, EmptyFallback: "REJECT"}}) {
		t.Errorf("groups = %+v", report.Groups)
	}
}

func TestMountKeepsGroupsATailscaleRuleTargetsOutOfItsTargets(t *testing.T) {
	home := withMountHome(t)
	memory := `{"version": 1, "accounts": {}, "suffixes": ["corp.example"]}`
	if err := os.MkdirAll(tailscaleRoutesDir(), 0o700); err != nil {
		t.Fatal(err)
	}
	writeMountFile(t, tailscaleRoutesDir(), "routes-4.json", memory)
	const profile = `proxies:
  - {name: base, type: socks5, server: 127.0.0.9, port: 1080}
proxy-groups:
  - {name: V4, type: select, proxies: [base]}
  - {name: V6, type: select, proxies: [base]}
  - {name: Net, type: select, proxies: [base]}
  - {name: Tailnet, type: select, proxies: [base]}
  - {name: Device, type: select, proxies: [base]}
  - {name: Wide, type: select, proxies: [base]}
  - {name: Suffix, type: select, proxies: [base]}
  - {name: Sub, type: select, proxies: [base]}
  - {name: Collects, type: url-test, include-all-providers: true}
  - {name: Lan, type: select, proxies: [base]}
  - {name: Google, type: select, proxies: [base]}
  - {name: Source, type: select, proxies: [base]}
  - {name: Main, type: select, proxies: [base]}
  - {name: Final, type: select, proxies: [base]}
sub-rules:
  inner:
    - DOMAIN-WILDCARD,*.corp.example,Sub
rules:
  - IP-CIDR,100.100.0.0/16,V4,no-resolve
  - IP-CIDR6,fd7a:115c:a1e0::/48,V6
  - DOMAIN-SUFFIX,ts.net,Net
  - DOMAIN-SUFFIX,corp.example,Tailnet
  - DOMAIN,box.tail1234.ts.net,Device
  - IP-CIDR,0.0.0.0/0,Wide
  - IP-SUFFIX,0.0.0.7/8,Suffix
  - DOMAIN-KEYWORD,tailscale,Collects
  - IP-CIDR,10.0.0.0/8,Lan
  - DOMAIN-SUFFIX,google.com,Google
  - SRC-IP-CIDR,100.64.0.0/10,Source
  - SUB-RULE,(NETWORK,tcp),inner
  - IP-CIDR,100.64.0.0/10,Final
  - MATCH,Main
`
	want := map[string]string{
		"V4": "excluded/tailscale", "V6": "excluded/tailscale", "Net": "excluded/tailscale",
		"Tailnet": "excluded/tailscale", "Device": "excluded/tailscale", "Wide": "excluded/tailscale",
		"Suffix": "excluded/tailscale", "Sub": "excluded/tailscale", "Collects": "auto/",
		"Lan": "candidate/", "Google": "candidate/", "Source": "candidate/",
		"Main": "candidate/", "Final": "excluded/tailscale",
	}
	wantKinds(t, groupKinds(t, rootOf(t, profile)), want)
	source := writeMountFile(t, home, "1.yaml", mountSourceB)
	for _, managed := range [][]string{nil, {"Work"}} {
		for group, kind := range want {
			setup := &MountSetup{Groups: []string{group}, Sources: []MountSource{{ID: 1, Label: "S", Path: source}}, reserved: managed}
			_, err := applyMountOverrides(rootOf(t, profile), setup)
			excluded := strings.HasPrefix(kind, mountGroupExcluded)
			if refused := err != nil; refused != excluded {
				t.Errorf("managed %v: choosing %s = %v, want refused %v", managed, group, err, excluded)
			}
		}
	}
	final := strings.Replace(profile, "  - MATCH,Main\n", "  - MATCH,Final\n", 1)
	wantKinds(t, groupKinds(t, rootOf(t, final)), map[string]string{"Final": "excluded/tailscale", "Main": "candidate/"})
	tailnet := strings.Replace(profile, "  - DOMAIN-KEYWORD,tailscale,Collects\n", "  - DOMAIN-KEYWORD,ts,Collects\n", 1)
	wantKinds(t, groupKinds(t, rootOf(t, tailnet)), map[string]string{"Collects": "excluded/tailscale"})
}

func TestMountReadsExcludeTypeAsMihomoDoes(t *testing.T) {
	const profile = `proxies:
  - {name: ts-office, type: tailscale}
  - {name: base, type: socks5, server: 127.0.0.9, port: 1080}
proxy-groups:
  - {name: Listed, type: select, include-all-proxies: true, exclude-type: "Wireguard|TAILSCALE"}
  - {name: Longer, type: select, include-all-proxies: true, exclude-type: "tailscale2"}
  - {name: Prefixed, type: select, include-all-proxies: true, exclude-type: "xtailscale|ss"}
  - {name: Filtered, type: select, include-all-proxies: true, filter: "^base$"}
  - {name: Unfiltered, type: select, include-all-proxies: true, exclude-filter: "ts"}
`
	wantKinds(t, groupKinds(t, rootOf(t, profile)), map[string]string{
		"Listed":     "candidate/",
		"Longer":     "excluded/tailscale",
		"Prefixed":   "excluded/tailscale",
		"Filtered":   "excluded/tailscale",
		"Unfiltered": "excluded/tailscale",
	})
}

func TestMountNodeNeverTakesAFlashNameOfAPanelAddedNode(t *testing.T) {
	home := withMountHome(t)
	source := writeMountFile(t, home, "1.yaml", `proxies:
  - {name: "Work (Flash)", type: socks5, server: 127.0.0.1, port: 1}
  - {name: "Work (Flash 3)", type: socks5, server: 127.0.0.1, port: 2}
  - {name: "Tailscale (Flash 2)", type: socks5, server: 127.0.0.1, port: 3}
  - {name: "Work (Flash 01)", type: socks5, server: 127.0.0.1, port: 4}
  - {name: "Work (Flash 1)", type: socks5, server: 127.0.0.1, port: 5}
  - {name: "Home (Flash)", type: socks5, server: 127.0.0.1, port: 6}
`)
	params := &SetupParams{
		Mounts:    &MountSetup{Sources: []MountSource{{ID: 1, Label: "Flash", Path: source}}},
		Tailscale: &TailscaleSetup{Managed: []TailscaleManagedSetup{{ID: "a", Name: "Work"}, {ID: "b"}}},
	}

	report, err := applyMountOverrides(rootOf(t, "proxy-groups:\n  - {name: G, type: select, include-all: true}\n"), mountSetupOf(params))
	if err != nil {
		t.Fatal(err)
	}

	want := []MountNode{
		{"Work (Flash) (Flash)", "Work (Flash)"},
		{"Work (Flash 3) (Flash)", "Work (Flash 3)"},
		{"Tailscale (Flash 2) (Flash)", "Tailscale (Flash 2)"},
		{"Work (Flash 01)", "Work (Flash 01)"},
		{"Work (Flash 1)", "Work (Flash 1)"},
		{"Home (Flash)", "Home (Flash)"},
	}
	if !reflect.DeepEqual(report.Sources[0].Nodes, want) {
		t.Errorf("nodes = %+v, want %+v", report.Sources[0].Nodes, want)
	}
	work := writeMountFile(t, home, "2.yaml", "proxies:\n  - {name: Work, type: socks5, server: 127.0.0.1, port: 1}\n")
	params.Mounts.Sources = []MountSource{{ID: 2, Label: "Flash", Path: work}}
	report, err = applyMountOverrides(rootOf(t, "proxy-groups:\n  - {name: G, type: select, include-all: true}\n"), mountSetupOf(params))
	if err != nil {
		t.Fatal(err)
	}
	if got := report.Sources[0].Nodes[0].Name; got != "Work (Flash #2)" {
		t.Errorf("Work with label Flash = %q, want a name outside the panel's", got)
	}
}

const relayProfile = `proxies:
  - {name: base, type: socks5, server: 127.0.0.9, port: 1080}
  - {name: ts-office, type: tailscale}
  - {name: hop, type: socks5, server: 127.0.0.9, port: 1081, dialer-proxy: ts-office}
proxy-groups:
  - {name: Office, type: select, proxies: [ts-office]}
  - {name: Hops, type: select, proxies: [hop, base]}
  - {name: Proxy, type: select, proxies: [base]}
  - {name: Auto, type: url-test, include-all-providers: true}
rules:
  - MATCH,Auto
`

const relaySource = `proxies:
  - {name: plain, type: socks5, server: 127.0.0.1, port: 1}
  - {name: chained, type: socks5, server: 127.0.0.1, port: 2, dialer-proxy: base}
  - {name: via-node, type: socks5, server: 127.0.0.1, port: 3, dialer-proxy: ts-office}
  - {name: via-group, type: socks5, server: 127.0.0.1, port: 4, dialer-proxy: Office}
  - {name: via-hop, type: socks5, server: 127.0.0.1, port: 5, dialer-proxy: hop}
  - {name: via-hops, type: socks5, server: 127.0.0.1, port: 6, dialer-proxy: Hops}
  - {name: via-managed, type: socks5, server: 127.0.0.1, port: 7, dialer-proxy: Tailscale}
  - {name: via-fallback, type: socks5, server: 127.0.0.1, port: 8, dialer-proxy: "Work (Flash 2)"}
  - {name: ts, type: tailscale}
`

func mountProviderMapping(t *testing.T, root *yaml.Node, name string) map[string]any {
	t.Helper()
	var mapping map[string]any
	if err := resolveAlias(mappingValue(resolveAlias(mappingValue(root, "proxy-providers")), name)).Decode(&mapping); err != nil {
		t.Fatal(err)
	}
	return mapping
}

func TestMountLeavesOutNodesThatRelayThroughTailscale(t *testing.T) {
	home := withMountHome(t)
	path := writeMountFile(t, home, "1.yaml", relaySource)
	root := rootOf(t, relayProfile)
	setup := &MountSetup{Sources: []MountSource{{ID: 1, Label: "S", Path: path}}, reserved: []string{"Tailscale", "Work"}}

	report, err := applyMountOverrides(root, setup)
	if err != nil {
		t.Fatal(err)
	}

	source := report.Sources[0]
	if source.RelayExcluded != 6 || source.TailscaleExcluded != 1 || source.Status != mountSourceNodes {
		t.Errorf("source = %+v, want six relays and one Tailscale node left out", source)
	}
	if want := []MountNode{{"plain", "plain"}, {"chained", "chained"}}; !reflect.DeepEqual(source.Nodes, want) {
		t.Errorf("nodes = %+v, want %+v", source.Nodes, want)
	}
	cfg := checkOnlyConfig(t, &yaml.Node{Kind: yaml.DocumentNode, Content: []*yaml.Node{root}})
	if got := memberNames(t, cfg, "Auto"); !reflect.DeepEqual(got, []string{"plain", "chained"}) {
		t.Errorf("Auto = %v, want only the nodes that do not relay through Tailscale", got)
	}
	pd := cfg.Providers["flash-mount-1"]
	definition := mountProviderMapping(t, root, "flash-mount-1")
	chained, err := provider.ProxyMapping(pd, definition, "chained")
	if err != nil || chained["dialer-proxy"] != "base" {
		t.Errorf("chained = %v, %v; want its own dialer-proxy kept", chained, err)
	}
	if relayed, err := provider.ProxyMapping(pd, definition, "via-node"); err != nil || relayed != nil {
		t.Errorf("via-node = %v, %v; want it left out", relayed, err)
	}

	writeMountFile(t, home, "1.yaml", relaySource+"  - {name: late, type: socks5, server: 127.0.0.1, port: 9, dialer-proxy: \"Tailscale (Flash)\"}\n")
	late, err := provider.ProxyMapping(pd, definition, "late")
	if err != nil || late["dialer-proxy"] != "REJECT" {
		t.Errorf("a node the file gained later = %v, %v; want its dial to fail", late, err)
	}
	if kept, _ := provider.ProxyMapping(pd, definition, "chained"); kept["dialer-proxy"] != "base" {
		t.Errorf("chained after the change = %v", kept)
	}

	target, err := inspectMountTarget(rootOf(t, relayProfile))
	if err != nil {
		t.Fatal(err)
	}
	if want := []string{"Hops", "Office", "hop", "ts-office"}; !reflect.DeepEqual(target.Relay, want) {
		t.Errorf("relay = %v, want %v", target.Relay, want)
	}
	inspected := handleInspectMountSource(MountInspectSourceParams{Path: path, Relay: target.Relay, Managed: []string{"", "Work"}})
	if inspected.Count != 2 || inspected.RelayExcluded != 7 || inspected.TailscaleExcluded != 1 {
		t.Errorf("inspection = %+v, want plain and chained, and the late node left out", inspected)
	}
	unchecked := handleInspectMountSource(MountInspectSourceParams{Path: path})
	if unchecked.RelayExcluded != 0 || unchecked.Count != 9 {
		t.Errorf("inspection without a target = %+v, want nothing checked", unchecked)
	}
}

func TestMountSourceWhoseNodesAllRelayThroughTailscaleIsNoEmptyList(t *testing.T) {
	home := withMountHome(t)
	only := writeMountFile(t, home, "1.yaml", `proxies:
  - {name: a, type: socks5, server: 127.0.0.1, port: 1, dialer-proxy: ts-office}
  - {name: b, type: socks5, server: 127.0.0.1, port: 2, dialer-proxy: Office}
`)
	mixed := writeMountFile(t, home, "2.yaml", `proxies:
  - {name: c, type: socks5, server: 127.0.0.1, port: 1, dialer-proxy: Office}
  - {name: ts, type: tailscale}
`)
	relay := []string{"Office", "ts-office"}
	for path, want := range map[string]MountSourceInspection{
		only:  {Status: mountSourceNodes, Listed: 2, RelayExcluded: 2},
		mixed: {Status: mountSourceNodes, Listed: 2, RelayExcluded: 1, TailscaleExcluded: 1},
	} {
		got := handleInspectMountSource(MountInspectSourceParams{Path: path, Relay: relay})
		got.names, got.relayed = nil, nil
		if !reflect.DeepEqual(got, want) {
			t.Errorf("inspection = %+v, want %+v", got, want)
		}
	}

	members, report := mountedMembers(t, relayProfile, &MountSetup{Sources: []MountSource{
		{ID: 1, Label: "A", Path: only},
		{ID: 2, Label: "B", Path: mixed},
	}})
	if got := members["Auto"]; !reflect.DeepEqual(got, []string{"REJECT"}) {
		t.Errorf("Auto = %v, want only its REJECT fallback", got)
	}
	for _, source := range report.Sources {
		if len(source.Nodes) != 0 || source.RelayExcluded == 0 {
			t.Errorf("source = %+v, want nothing mounted and the relays counted", source)
		}
	}
}

func TestMountPreflightOfTheRunningProfileChecksItsPanelNames(t *testing.T) {
	home := withMountHome(t)
	resetTailscaleSetup(t)
	setTailscaleSetup(&TailscaleSetup{ProfileID: 4, Managed: []TailscaleManagedSetup{{ID: "a", Name: "Work"}}})
	path := writeBaseProfile(t, "proxy-groups:\n  - {name: G, type: select, include-all-providers: true}\n")
	source := writeMountFile(t, home, "1.yaml", "proxies:\n  - {name: Work, type: socks5, server: 127.0.0.1, port: 1}\n  - {name: x, type: socks5, server: 127.0.0.1, port: 2, dialer-proxy: \"Work (Flash)\"}\n")
	for target, want := range map[int64]MountSourceReport{
		4: {ID: 1, Provider: "flash-mount-1", Status: mountSourceNodes, RelayExcluded: 1, Nodes: []MountNode{{"Work (S)", "Work"}}},
		5: {ID: 1, Provider: "flash-mount-1", Status: mountSourceNodes, Nodes: []MountNode{{"Work", "Work"}, {"x", "x"}}},
	} {
		preflight, err := handleMountPreflight(MountPreflightParams{
			Base:   &SetupBase{Path: path, Overlay: "{}"},
			Mounts: &MountSetup{Target: target, Sources: []MountSource{{ID: 1, Label: "S", Path: source}}},
		})
		if err != nil || preflight.Report == nil {
			t.Fatalf("preflight = %+v, %v", preflight, err)
		}
		if got := preflight.Report.Sources[0]; !reflect.DeepEqual(got, want) {
			t.Errorf("target %d: source = %+v, want %+v", target, got, want)
		}
	}
}
