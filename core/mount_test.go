package core

import (
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"slices"
	"strings"
	"testing"

	"github.com/metacubex/mihomo/adapter/outboundgroup"
	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
	"go.yaml.in/yaml/v3"
)

const mountSourceA = `proxies:
  - {name: hk, type: socks5, server: 127.0.0.1, port: 1080}
  - {name: shared, type: socks5, server: 127.0.0.1, port: 1081}
  - {name: ts, type: tailscale}
`

const mountSourceB = `proxies:
  - {name: shared, type: socks5, server: 127.0.0.2, port: 1080}
  - {name: us, type: socks5, server: 127.0.0.2, port: 1081}
`

func writeMountFile(t *testing.T, dir, name, content string) string {
	t.Helper()
	path := filepath.Join(dir, name)
	if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
		t.Fatal(err)
	}
	return path
}

func withMountHome(t *testing.T) string {
	t.Helper()
	home := t.TempDir()
	previous := constant.Path.HomeDir()
	constant.SetHomeDir(home)
	t.Cleanup(func() { constant.SetHomeDir(previous) })
	return home
}

func TestInspectMountSourceClassifiesWhatAProviderWouldLoad(t *testing.T) {
	dir := t.TempDir()
	for name, tc := range map[string]struct {
		content string
		want    MountSourceInspection
	}{
		"nodes":           {mountSourceA, MountSourceInspection{Status: mountSourceNodes, Count: 2, Listed: 3, TailscaleExcluded: 1}},
		"explicit empty":  {"proxies: []\n", MountSourceInspection{Status: mountSourceNodes}},
		"full config":     {"mixed-port: 1\nrules: [MATCH,DIRECT]\n" + mountSourceB, MountSourceInspection{Status: mountSourceNodes, Count: 2, Listed: 2}},
		"only tailscale":  {"proxies:\n  - {name: ts, type: tailscale}\n", MountSourceInspection{Status: mountSourceNodes, Listed: 1, TailscaleExcluded: 1}},
		"no proxies key":  {"rules: []\n", MountSourceInspection{Status: mountSourceUnsupported}},
		"providers only":  {"proxy-providers:\n  p: {type: http, url: http://example.invalid/sub}\n", MountSourceInspection{Status: mountSourceUnsupported}},
		"null proxies":    {"proxies:\n", MountSourceInspection{Status: mountSourceUnsupported}},
		"empty body":      {"  \n", MountSourceInspection{Status: mountSourceUnsupported}},
		"html page":       {"<html><body>blocked</body></html>", MountSourceInspection{Status: mountSourceUnsupported}},
		"nameless nodes":  {"proxies:\n  - {type: socks5, server: 127.0.0.1, port: 1}\n", MountSourceInspection{Status: mountSourceInvalid, Listed: 1}},
		"node that fails": {"proxies:\n  - {name: x, type: nope}\n", MountSourceInspection{Status: mountSourceInvalid, Listed: 1}},
		"share links":     {"trojan://secret@127.0.0.1:443#t1\n", MountSourceInspection{Status: mountSourceNodes, Count: 1, Listed: 1}},
	} {
		t.Run(name, func(t *testing.T) {
			got := inspectMountSource(writeMountFile(t, dir, strings.ReplaceAll(name, " ", "-")+".yaml", tc.content), "", nil)
			got.names = nil
			if !reflect.DeepEqual(got, tc.want) {
				t.Errorf("inspection = %+v, want %+v", got, tc.want)
			}
		})
	}
	if got := inspectMountSource(filepath.Join(dir, "absent.yaml"), "", nil); got.Status != mountSourceMissing {
		t.Errorf("absent file = %+v, want missing", got)
	}
}

const mountTargetProfile = `proxies:
  - {name: base, type: socks5, server: 127.0.0.9, port: 1080}
  - {name: shared, type: socks5, server: 127.0.0.9, port: 1081}
  - {name: office, type: tailscale}
proxy-groups:
  - {name: Proxy, type: select, proxies: [base, Auto]}
  - {name: Auto, type: url-test, include-all-providers: true, filter: "^hk"}
  - {name: All, type: select, include-all: true, hidden: true}
  - {name: Lazy, type: fallback, proxies: [base], interval: 0}
  - {name: Hidden, type: select, proxies: [base], hidden: true}
  - {name: Office, type: select, proxies: [office]}
  - {name: Chain, type: relay, proxies: [base]}
  - {name: Direct, type: select, proxies: [base], empty-fallback: DIRECT, exclude-filter: x}
  - {name: GLOBAL, type: select, proxies: [Proxy]}
rules:
  - MATCH,Proxy
`

func rootOf(t *testing.T, content string) *yaml.Node {
	t.Helper()
	var document yaml.Node
	if err := yaml.Unmarshal([]byte(content), &document); err != nil {
		t.Fatal(err)
	}
	root, err := documentMapping(&document)
	if err != nil {
		t.Fatal(err)
	}
	return root
}

func TestInspectMountTargetSortsGroupsByWhatAMountMayDo(t *testing.T) {
	target, err := inspectMountTarget(rootOf(t, mountTargetProfile))
	if err != nil {
		t.Fatal(err)
	}
	got := map[string]MountGroupInfo{}
	for _, group := range target.Groups {
		got[group.Name] = group
	}
	for name, want := range map[string]MountGroupInfo{
		"Proxy":  {Name: "Proxy", Type: "select", Kind: mountGroupCandidate, Probe: "none"},
		"Auto":   {Name: "Auto", Type: "url-test", Kind: mountGroupAuto, Collects: "providers", Filter: true, Probe: "probes"},
		"All":    {Name: "All", Type: "select", Kind: mountGroupExcluded, Excluded: "tailscale", Reason: reachHolds, Hidden: true, Probe: "none"},
		"Lazy":   {Name: "Lazy", Type: "fallback", Kind: mountGroupCandidate, Probe: "unknown"},
		"Hidden": {Name: "Hidden", Type: "select", Kind: mountGroupExcluded, Excluded: "hidden", Hidden: true, Probe: "none"},
		"Office": {Name: "Office", Type: "select", Kind: mountGroupExcluded, Excluded: "tailscale", Reason: reachHolds, Probe: "none"},
		"Chain":  {Name: "Chain", Type: "relay", Kind: mountGroupExcluded, Excluded: "type", Probe: "probes"},
		"Direct": {Name: "Direct", Type: "select", Kind: mountGroupCandidate, ExcludeFilter: true, EmptyFallback: "DIRECT", Probe: "none"},
		"GLOBAL": {Name: "GLOBAL", Type: "select", Kind: mountGroupExcluded, Excluded: "builtin", Probe: "none"},
	} {
		if got[name] != want {
			t.Errorf("%s = %+v, want %+v", name, got[name], want)
		}
	}
}

func TestMountKeepsEveryGroupThatReachesTailscaleOutOfItsTargets(t *testing.T) {
	const profile = `proxies:
  - {name: base, type: socks5, server: 127.0.0.9, port: 1080}
  - {name: ts-office, type: tailscale}
proxy-groups:
  - {name: Proxy, type: select, proxies: [base]}
  - {name: Office, type: select, proxies: [ts-office, Proxy]}
  - {name: Outer, type: url-test, proxies: [Office, base]}
  - {name: Collects, type: select, include-all-proxies: true}
  - {name: Filtered, type: select, include-all-proxies: true, exclude-type: "Tailscale|Wireguard"}
rules:
  - IP-CIDR,100.64.0.0/10,Office
  - MATCH,Proxy
`
	target, err := inspectMountTarget(rootOf(t, profile))
	if err != nil {
		t.Fatal(err)
	}
	got := map[string]string{}
	for _, group := range target.Groups {
		got[group.Name] = group.Kind + "/" + group.Excluded
	}
	want := map[string]string{
		"Proxy":    "excluded/tailscale",
		"Office":   "excluded/tailscale",
		"Outer":    "excluded/tailscale",
		"Collects": "excluded/tailscale",
		"Filtered": "candidate/",
	}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("groups = %v, want %v", got, want)
	}

	home := withMountHome(t)
	for _, chosen := range []string{"Office", "Outer", "Proxy"} {
		setup := &MountSetup{Groups: []string{chosen}, Sources: []MountSource{{ID: 1, Path: writeMountFile(t, home, "1.yaml", mountSourceB)}}}
		_, err := applyMountOverrides(rootOf(t, profile), setup)
		var methodErr *MethodError
		if !errors.As(err, &methodErr) || methodErr.Code != "mount_group_changed" {
			t.Errorf("a stored choice of %s = %v, want it refused", chosen, err)
		}
	}
}

func TestMountGroupsThatCannotBeReadAreAnErrorNotFewerGroups(t *testing.T) {
	home := withMountHome(t)
	source := writeMountFile(t, home, "1.yaml", mountSourceB)
	for name, profile := range map[string]string{
		"groups not a list":   "proxy-groups: {G: {type: select}}\n",
		"group not a mapping": "proxy-groups:\n  - G\n  - {name: H, type: select, include-all: true}\n",
		"null group":          "proxy-groups:\n  -\n  - {name: H, type: select, include-all: true}\n",
		"proxies not a list":  "proxies: x\nproxy-groups:\n  - {name: H, type: select, include-all: true}\n",
		"proxy not a mapping": "proxies: [x]\nproxy-groups:\n  - {name: H, type: select, include-all: true}\n",
	} {
		t.Run(name, func(t *testing.T) {
			if target, err := inspectMountTarget(rootOf(t, profile)); err == nil {
				t.Errorf("inspect = %+v, want an error", target)
			}
			setup := &MountSetup{Sources: []MountSource{{ID: 1, Path: source}}}
			if report, err := applyMountOverrides(rootOf(t, profile), setup); err == nil {
				t.Errorf("apply = %+v, want an error", report)
			}
		})
	}
	if target, err := inspectMountTarget(rootOf(t, "proxy-groups:\n")); err != nil || len(target.Groups) != 0 {
		t.Errorf("null groups = %+v, %v; want none and no error", target, err)
	}
}

func mountedConfig(t *testing.T, profile string, setup *MountSetup) (*config.Config, *MountReport) {
	t.Helper()
	path := writeBaseProfile(t, profile)
	cfg, report, err := loadConfigWithBase(&SetupBase{Path: path, Overlay: "{}"}, filepath.Join(t.TempDir(), "config.yaml"), setup)
	if err != nil {
		t.Fatalf("loadConfigWithBase = %v", err)
	}
	t.Cleanup(func() {
		for _, pd := range cfg.Providers {
			if closer, ok := pd.(interface{ Close() error }); ok {
				_ = closer.Close()
			}
		}
	})
	for _, pd := range cfg.Providers {
		_ = pd.Initial()
	}
	return cfg, report
}

func memberNames(t *testing.T, cfg *config.Config, group string) []string {
	t.Helper()
	proxyGroup, ok := adapterAs[outboundgroup.ProxyGroup](cfg.Proxies[group])
	if !ok {
		t.Fatalf("%s is not a group", group)
	}
	var names []string
	for _, member := range proxyGroup.Proxies() {
		names = append(names, member.Name())
	}
	return names
}

func TestMountsReachAutoAndChosenGroupsWithSuffixesOnlyOnClashes(t *testing.T) {
	home := withMountHome(t)
	setup := &MountSetup{Revision: "r1", Groups: []string{"Proxy", "Direct"}, Sources: []MountSource{
		{ID: 7, Label: "Sub A", Path: writeMountFile(t, home, "7.yaml", mountSourceA)},
		{ID: 9, Label: "Sub B", Path: writeMountFile(t, home, "9.yaml", mountSourceB)},
	}}

	loadable := strings.NewReplacer(
		"type: tailscale", "type: socks5, server: 127.0.0.9, port: 1082",
		"  - {name: Chain, type: relay, proxies: [base]}\n", "",
	).Replace(mountTargetProfile)
	cfg, report := mountedConfig(t, loadable, setup)

	if got, want := memberNames(t, cfg, "Proxy"), []string{"base", "Auto", "hk", "shared (Sub A)", "shared (Sub B)", "us"}; !reflect.DeepEqual(got, want) {
		t.Errorf("Proxy members = %v, want %v", got, want)
	}
	if got, want := memberNames(t, cfg, "Auto"), []string{"hk"}; !reflect.DeepEqual(got, want) {
		t.Errorf("Auto members = %v, want %v", got, want)
	}
	if got := memberNames(t, cfg, "Lazy"); !reflect.DeepEqual(got, []string{"base"}) {
		t.Errorf("an unchosen group changed: %v", got)
	}
	if report.Renamed != 2 || report.Revision != "r1" {
		t.Errorf("report = %+v, want two renames on r1", report)
	}
	wantSources := []MountSourceReport{
		{ID: 7, Provider: "flash-mount-7", Status: mountSourceNodes, TailscaleExcluded: 1, Nodes: []MountNode{{"hk", "hk"}, {"shared (Sub A)", "shared"}}},
		{ID: 9, Provider: "flash-mount-9", Status: mountSourceNodes, Nodes: []MountNode{{"shared (Sub B)", "shared"}, {"us", "us"}}},
	}
	if !reflect.DeepEqual(report.Sources, wantSources) {
		t.Errorf("sources = %+v, want %+v", report.Sources, wantSources)
	}
	wantGroups := []MountGroupReport{
		{Name: "Proxy", Via: "use", Protection: mountProtectionOriginal},
		{Name: "Auto", Via: "auto", Protection: mountProtectionReject, EmptyFallback: "REJECT"},
		{Name: "All", Via: "auto", Protection: mountProtectionOriginal},
		{Name: "Direct", Via: "use", Protection: mountProtectionBase, EmptyFallback: "DIRECT"},
	}
	if !reflect.DeepEqual(report.Groups, wantGroups) {
		t.Errorf("groups = %+v, want %+v", report.Groups, wantGroups)
	}
	for group, want := range map[string]string{"Proxy": "COMPATIBLE", "All": "COMPATIBLE", "Auto": "REJECT"} {
		if got := mountRuntimeGroup(cfg.Proxies[group], group, nil).Fallback; got != want {
			t.Errorf("%s empty-fallback = %s, want %s", group, got, want)
		}
	}
	if got := memberNames(t, cfg, "All"); slices.Contains(got, "ts") || !slices.Contains(got, "hk") {
		t.Errorf("All members = %v, want mounted nodes and no Tailscale node from a mount", got)
	}
}

func TestMountNodeTakesTheSuffixWhenItSharesAManagedTailscaleName(t *testing.T) {
	home := withMountHome(t)
	source := writeMountFile(t, home, "1.yaml", `proxies:
  - {name: hk, type: socks5, server: 127.0.0.1, port: 1080}
  - {name: Tailscale, type: socks5, server: 127.0.0.1, port: 1081}
  - {name: us, type: socks5, server: 127.0.0.1, port: 1082}
`)
	params := &SetupParams{
		Mounts: &MountSetup{Sources: []MountSource{{ID: 1, Label: "S", Path: source}}},
		Tailscale: &TailscaleSetup{Managed: []TailscaleManagedSetup{
			{ID: "a", Name: "hk"},
			{ID: "b"},
			{Name: "us"},
		}},
	}

	report, err := applyMountOverrides(rootOf(t, "proxy-groups:\n  - {name: G, type: select, include-all: true}\n"), mountSetupOf(params))
	if err != nil {
		t.Fatal(err)
	}

	want := []MountNode{{"hk (S)", "hk"}, {"Tailscale (S)", "Tailscale"}, {"us", "us"}}
	if !reflect.DeepEqual(report.Sources[0].Nodes, want) {
		t.Errorf("nodes = %+v, want %+v", report.Sources[0].Nodes, want)
	}
	if params.Mounts.reserved != nil {
		t.Error("the setup the host sent was changed")
	}
}

func TestMountNodeTakesTheSuffixWhenABaseProviderHoldsItsName(t *testing.T) {
	home := withMountHome(t)
	writeMountFile(t, home, "own.yaml", "proxies:\n  - {name: us, type: socks5, server: 127.0.0.3, port: 1}\n  - {name: jp, type: socks5, server: 127.0.0.3, port: 2}\n")
	source := writeMountFile(t, home, "1.yaml", `proxies:
  - {name: hk, type: socks5, server: 127.0.0.1, port: 1080}
  - {name: us, type: socks5, server: 127.0.0.1, port: 1081}
  - {name: P-us-P, type: socks5, server: 127.0.0.1, port: 1082}
  - {name: P-Japan-P, type: socks5, server: 127.0.0.1, port: 1083}
`)
	const base = `proxy-providers:
  inline: {type: inline, payload: [{name: hk, type: socks5, server: 127.0.0.2, port: 1}]}
  own:
    type: file
    path: own.yaml
    override:
      additional-prefix: P-
      proxy-name: [{pattern: "^jp$", target: Japan}]
      additional-suffix: -P
proxy-groups:
  - {name: G, type: select, include-all: true}
`
	report, err := applyMountOverrides(rootOf(t, base), &MountSetup{Sources: []MountSource{{ID: 1, Label: "S", Path: source}}})
	if err != nil {
		t.Fatal(err)
	}

	want := []MountNode{{"hk (S)", "hk"}, {"us", "us"}, {"P-us-P (S)", "P-us-P"}, {"P-Japan-P (S)", "P-Japan-P"}}
	if !reflect.DeepEqual(report.Sources[0].Nodes, want) {
		t.Errorf("nodes = %+v, want %+v", report.Sources[0].Nodes, want)
	}
}

func TestMountSuffixKeepsMetacharactersLiteral(t *testing.T) {
	home := withMountHome(t)
	const base = `proxies:
  - {name: "a.b ($1)", type: socks5, server: 127.0.0.9, port: 1080}
  - {name: "a.b ($1) (S$1)", type: socks5, server: 127.0.0.9, port: 1081}
proxy-groups:
  - {name: G, type: select, include-all-providers: true}
`
	source := `proxies:
  - {name: "a.b ($1)", type: socks5, server: 127.0.0.1, port: 1080}
  - {name: "axb ($1)", type: socks5, server: 127.0.0.1, port: 1081}
`
	setup := &MountSetup{Sources: []MountSource{{ID: 3, Label: "S$1", Path: writeMountFile(t, home, "3.yaml", source)}}}

	cfg, _ := mountedConfig(t, base, setup)

	want := []string{"a.b ($1) (S$1 #3)", "axb ($1)"}
	if got := memberNames(t, cfg, "G"); !reflect.DeepEqual(got, want) {
		t.Errorf("G members = %v, want %v", got, want)
	}
}

func TestMountedEmptyListLeavesAProtectedGroupRejecting(t *testing.T) {
	home := withMountHome(t)
	const base = `proxy-groups:
  - {name: G, type: select, include-all-providers: true}
rules:
  - MATCH,G
`
	setup := &MountSetup{Sources: []MountSource{{ID: 1, Label: "S", Path: writeMountFile(t, home, "1.yaml", "proxies: []\n")}}}

	cfg, report := mountedConfig(t, base, setup)

	if got := memberNames(t, cfg, "G"); !reflect.DeepEqual(got, []string{"REJECT"}) {
		t.Errorf("G members = %v, want the REJECT fallback", got)
	}
	runtime := mountRuntimeGroup(cfg.Proxies["G"], "G", map[string]struct{}{"flash-mount-1": {}})
	if !runtime.Empty || runtime.Fallback != "REJECT" || runtime.Mounted != 0 {
		t.Errorf("runtime = %+v, want an empty group falling back to REJECT", runtime)
	}
	if report.Sources[0].Status != mountSourceNodes || len(report.Sources[0].Nodes) != 0 {
		t.Errorf("source = %+v, want a successful empty list", report.Sources[0])
	}
}

func TestMountRefusesAChosenGroupThatIsGone(t *testing.T) {
	home := withMountHome(t)
	path := writeBaseProfile(t, mountTargetProfile)
	setup := &MountSetup{Groups: []string{"Hidden"}, Sources: []MountSource{{ID: 1, Path: writeMountFile(t, home, "1.yaml", mountSourceB)}}}

	_, _, err := mergeProfileBase(&SetupBase{Path: path, Overlay: "{}"}, false, setup)

	var methodErr *MethodError
	if !errors.As(err, &methodErr) || methodErr.Code != "mount_group_changed" || methodErr.Details != "Hidden" {
		t.Fatalf("merge = %v, want mount_group_changed for Hidden", err)
	}
}

func TestMountPreflightReportsWhatTheApplyWouldRefuse(t *testing.T) {
	home := withMountHome(t)
	const base = `proxy-groups:
  - {name: G, type: select, include-all-providers: true}
`
	path := writeBaseProfile(t, base)
	source := writeMountFile(t, home, "1.yaml", mountSourceB)

	without, err := handleMountPreflight(MountPreflightParams{Base: &SetupBase{Path: path, Overlay: "{}"}, Mounts: &MountSetup{}})
	if err != nil || without.Error == "" {
		t.Errorf("preflight without mounts = %+v, %v; want a parse error", without, err)
	}
	with, err := handleMountPreflight(MountPreflightParams{
		Base:   &SetupBase{Path: path, Overlay: "{}"},
		Mounts: &MountSetup{Revision: "r", Sources: []MountSource{{ID: 1, Label: "S", Path: source}}},
	})
	if err != nil || with.Error != "" || with.Report == nil || with.Report.Revision != "r" {
		t.Errorf("preflight with a mount = %+v, %v; want a clean report", with, err)
	}
	gone, err := handleMountPreflight(MountPreflightParams{
		Config: base,
		Mounts: &MountSetup{Groups: []string{"Nope"}, Sources: []MountSource{{ID: 1, Path: source}}},
	})
	if err != nil || gone.ErrorCode != "mount_group_changed" {
		t.Errorf("preflight on a missing group = %+v, %v", gone, err)
	}
}

func TestApplyConfigKeepsTheRunningConfigWhenAMountedProfileFails(t *testing.T) {
	home := withMountHome(t)
	withCurrentConfig(t, nil)
	keepTunnel(t)
	t.Cleanup(func() { setMountState(nil, false, false) })
	good := writeMountFile(t, home, "base.yaml", `proxy-groups:
  - {name: G, type: select, include-all-providers: true}
rules:
  - MATCH,G
`)
	source := writeMountFile(t, home, "1.yaml", mountSourceB)
	params := &SetupParams{
		Base:   &SetupBase{Path: good, Overlay: "{}"},
		Mounts: &MountSetup{Revision: "r1", Sources: []MountSource{{ID: 1, Label: "S", Path: source}}},
	}
	if err := applyConfig(params); err != nil {
		t.Fatalf("applyConfig = %v", err)
	}
	running := currentConfig
	state := handleMountState()
	if state.Report == nil || state.Report.Revision != "r1" || len(state.Sources) != 1 || !state.Sources[0].Present {
		t.Fatalf("state = %+v, want r1 with its provider", state)
	}

	params.Mounts = &MountSetup{Revision: "r2"}
	err := applyConfig(params)

	var methodErr *MethodError
	if !errors.As(err, &methodErr) || methodErr.Code != "mount_rejected" ||
		!reflect.DeepEqual(methodErr.Details, map[string]string{"outcome": mountOutcomeKept}) {
		t.Fatalf("applyConfig = %v, want mount_rejected kept", err)
	}
	if currentConfig != running || handleMountState().Report.Revision != "r1" {
		t.Error("a rejected mounted profile replaced the running config")
	}
}

func TestApplyConfigBlocksWhenAMountedProfileFailsWithNothingRunning(t *testing.T) {
	home := withMountHome(t)
	withCurrentConfig(t, nil)
	keepTunnel(t)
	t.Cleanup(func() { setMountState(nil, false, false) })
	base := writeMountFile(t, home, "base.yaml", `proxy-groups:
  - {name: G, type: select, include-all-providers: true}
`)

	err := applyConfig(&SetupParams{Base: &SetupBase{Path: base, Overlay: "{}"}, Mounts: &MountSetup{}})

	var methodErr *MethodError
	if !errors.As(err, &methodErr) || methodErr.Code != "mount_rejected" ||
		!reflect.DeepEqual(methodErr.Details, map[string]string{"outcome": mountOutcomeBlocked}) {
		t.Fatalf("applyConfig = %v, want mount_rejected blocked", err)
	}
	if !handleMountState().Blocked {
		t.Error("the state does not say every connection is rejected")
	}
	global, ok := adapterAs[outboundgroup.ProxyGroup](tunnel.Proxies()[globalProxyName])
	if !ok || len(global.Proxies()) != 1 || global.Proxies()[0].Name() != "REJECT" {
		t.Error("GLOBAL can reach something other than REJECT")
	}
	if rules := ruleStrings(currentConfig); !reflect.DeepEqual(rules, []string{"Match,,REJECT"}) {
		t.Errorf("rules = %v, want only MATCH,REJECT", rules)
	}
}

func TestApplyConfigBlocksWhenAMountedProfileFailsOverTheDefaultConfig(t *testing.T) {
	home := withMountHome(t)
	withCurrentConfig(t, nil)
	keepTunnel(t)
	t.Cleanup(func() { setMountState(nil, false, false) })
	broken := writeMountFile(t, home, "broken.yaml", "proxy-groups:\n  - {name: G, type: select, proxies: [nope]}\n")
	var methodErr *MethodError
	if err := applyConfig(&SetupParams{Base: &SetupBase{Path: broken, Overlay: "{}"}}); !errors.As(err, &methodErr) || methodErr.Code != "config_rejected" {
		t.Fatalf("applyConfig = %v, want the default config running", err)
	}
	failing := writeMountFile(t, home, "base.yaml", "proxy-groups:\n  - {name: G, type: select, include-all-providers: true}\n")

	err := applyConfig(&SetupParams{Base: &SetupBase{Path: failing, Overlay: "{}"}, Mounts: &MountSetup{}})

	if !errors.As(err, &methodErr) || methodErr.Code != "mount_rejected" ||
		!reflect.DeepEqual(methodErr.Details, map[string]string{"outcome": mountOutcomeBlocked}) {
		t.Fatalf("applyConfig = %v, want mount_rejected blocked, never kept", err)
	}
	if !handleMountState().Blocked {
		t.Error("the direct-only default is still running")
	}
}

func TestApplyConfigFollowsASelectionToItsSourceWhenNamesShift(t *testing.T) {
	home := withMountHome(t)
	withCurrentConfig(t, nil)
	keepTunnel(t)
	t.Cleanup(func() {
		setMountState(nil, false, false)
		mountSelectionBasis = map[int64]*MountReport{}
	})
	base := writeMountFile(t, home, "base.yaml", `proxies:
  - {name: base, type: socks5, server: 127.0.0.9, port: 1}
proxy-groups:
  - {name: G, type: select, proxies: [base], include-all-providers: true}
rules:
  - MATCH,G
`)
	sourceA := writeMountFile(t, home, "1.yaml", "proxies:\n  - {name: us, type: socks5, server: 127.0.0.1, port: 1}\n")
	sourceB := writeMountFile(t, home, "2.yaml", "proxies:\n  - {name: hk, type: socks5, server: 127.0.0.2, port: 1}\n  - {name: jp, type: socks5, server: 127.0.0.2, port: 2}\n")
	apply := func(selected string, revision string) MountRuntimeState {
		t.Helper()
		err := applyConfig(&SetupParams{
			Base:        &SetupBase{Path: base, Overlay: "{}"},
			SelectedMap: map[string]string{"G": selected},
			Mounts: &MountSetup{Target: 5, Revision: revision, Sources: []MountSource{
				{ID: 1, Label: "A", Path: sourceA},
				{ID: 2, Label: "B", Path: sourceB},
			}},
		})
		if err != nil {
			t.Fatalf("applyConfig %s = %v", revision, err)
		}
		return handleMountState()
	}
	now := func() string {
		selector, _ := adapterAs[*outboundgroup.Selector](tunnel.Proxies()["G"])
		return selector.Now()
	}

	apply("hk", "r1")
	if now() != "hk" {
		t.Fatalf("G = %s, want B's hk", now())
	}

	writeMountFile(t, home, "1.yaml", "proxies:\n  - {name: hk, type: socks5, server: 127.0.0.1, port: 2}\n")
	state := apply("hk", "r2")
	if now() != "hk (B)" || !reflect.DeepEqual(state.Moved, map[string]string{"G": "hk (B)"}) {
		t.Fatalf("G = %s, moved %v; want B's node, now hk (B)", now(), state.Moved)
	}

	writeMountFile(t, home, "2.yaml", "proxies:\n  - {name: jp, type: socks5, server: 127.0.0.2, port: 2}\n")
	state = apply("hk (B)", "r3")
	if now() != "base" || !reflect.DeepEqual(state.Lost, []string{"G"}) {
		t.Fatalf("G = %s, lost %v; want the group's default, never A's hk", now(), state.Lost)
	}
}

func TestLoadMountedConfigWithoutABaseMountsIntoConfigYaml(t *testing.T) {
	home := withMountHome(t)
	configPath := writeMountFile(t, home, "config.yaml", `proxy-groups:
  - {name: G, type: select, proxies: [DIRECT]}
`)
	source := writeMountFile(t, home, "1.yaml", mountSourceB)

	cfg, report, err := loadMountedConfig(configPath, &MountSetup{Groups: []string{"G"}, Sources: []MountSource{{ID: 1, Path: source}}})
	if err != nil {
		t.Fatalf("loadMountedConfig = %v", err)
	}
	for _, pd := range cfg.Providers {
		_ = pd.Initial()
	}
	if got := memberNames(t, cfg, "G"); !reflect.DeepEqual(got, []string{"DIRECT", "shared", "us"}) {
		t.Errorf("G members = %v", got)
	}
	if len(report.Groups) != 1 || report.Groups[0].Via != "use" {
		t.Errorf("groups = %+v", report.Groups)
	}
}

const mountTailscaleAutoProfile = `proxies:
  - {name: base, type: socks5, server: 127.0.0.9, port: 1080}
  - {name: ts-office, type: tailscale}
proxy-groups:
  - {name: Office, type: select, proxies: [ts-office, Proxy]}
  - {name: Proxy, type: select, proxies: [base]}
  - {name: Everything, type: select, include-all: true}
  - {name: Routed, type: url-test, include-all-providers: true, proxies: [Office]}
  - {name: Auto, type: url-test, include-all-providers: true}
rules:
  - IP-CIDR,100.64.0.0/10,Routed
  - MATCH,Auto
`

// The merged document parsed as an apply would, with Tailscale nodes built
// as direct stand-ins so no node starts.
func checkOnlyConfig(t *testing.T, document *yaml.Node) *config.Config {
	t.Helper()
	raw := config.DefaultRawConfig()
	if err := document.Decode(raw); err != nil {
		t.Fatal(err)
	}
	for i, mapping := range raw.Proxy {
		raw.Proxy[i] = checkOnlyProxy(mapping)
	}
	for _, provider := range raw.ProxyProvider {
		payload, _ := provider["payload"].([]any)
		for i, item := range payload {
			if mapping, ok := item.(map[string]any); ok {
				payload[i] = checkOnlyProxy(mapping)
			}
		}
	}
	cfg, err := config.ParseRawConfig(raw)
	if err != nil {
		t.Fatalf("parse = %v", err)
	}
	t.Cleanup(func() {
		for _, pd := range cfg.Providers {
			if closer, ok := pd.(interface{ Close() error }); ok {
				_ = closer.Close()
			}
		}
	})
	for _, pd := range cfg.Providers {
		_ = pd.Initial()
	}
	return cfg
}

func groupYAML(t *testing.T, root *yaml.Node, name string) string {
	t.Helper()
	for _, item := range resolveAlias(mappingValue(root, "proxy-groups")).Content {
		if mappingValue(item, "name").Value == name {
			out, err := yaml.Marshal(item)
			if err != nil {
				t.Fatal(err)
			}
			return string(out)
		}
	}
	t.Fatalf("no group %s", name)
	return ""
}

func TestMountKeepsAutoGroupsThatReachTailscaleFreeOfMountedNodes(t *testing.T) {
	home := withMountHome(t)
	params := &SetupParams{
		Base: &SetupBase{
			Path:    writeBaseProfile(t, mountTailscaleAutoProfile),
			Overlay: "proxy-providers:\n  own: {type: inline, payload: [{name: own-node, type: socks5, server: 127.0.0.9, port: 1081}]}\n",
		},
		Mounts: &MountSetup{Revision: "r", Sources: []MountSource{
			{ID: 3, Label: "Sub", Path: writeMountFile(t, home, "3.yaml", mountSourceB)},
		}},
		Tailscale: &TailscaleSetup{Managed: []TailscaleManagedSetup{{ID: "m1", Name: "us"}}},
	}
	plain, _, err := mountedDocument(params.Base, "", nil)
	if err != nil {
		t.Fatal(err)
	}
	document, report, err := mountedDocument(params.Base, "", mountSetupOf(params))
	if err != nil {
		t.Fatal(err)
	}
	cfg := checkOnlyConfig(t, document)

	for group, want := range map[string][]string{
		"Everything": {"base", "ts-office", "own-node"},
		"Routed":     {"Office", "own-node"},
		"Office":     {"ts-office", "Proxy"},
		"Auto":       {"shared", "us (Sub)", "own-node"},
	} {
		if got := memberNames(t, cfg, group); !reflect.DeepEqual(got, want) {
			t.Errorf("%s members = %v, want %v", group, got, want)
		}
	}
	wantGroups := []MountGroupReport{{Name: "Auto", Via: "auto", Protection: mountProtectionReject, EmptyFallback: "REJECT"}}
	if !reflect.DeepEqual(report.Groups, wantGroups) {
		t.Errorf("groups = %+v, want %+v", report.Groups, wantGroups)
	}

	plainRoot, mountedRoot := plain.Content[0], document.Content[0]
	if got, want := groupYAML(t, mountedRoot, "Office"), groupYAML(t, plainRoot, "Office"); got != want {
		t.Errorf("the Tailscale group changed:\n%s\nwant\n%s", got, want)
	}
	before, _ := yaml.Marshal(mappingValue(plainRoot, "proxies"))
	after, _ := yaml.Marshal(mappingValue(mountedRoot, "proxies"))
	if string(before) != string(after) {
		t.Errorf("base proxies changed:\n%s\nwant\n%s", after, before)
	}

	target, err := inspectMountTarget(plainRoot)
	if err != nil {
		t.Fatal(err)
	}
	kinds := map[string]string{}
	for _, group := range target.Groups {
		kinds[group.Name] = group.Kind + "/" + group.Excluded
	}
	for name, want := range map[string]string{"Everything": "excluded/tailscale", "Routed": "excluded/tailscale", "Auto": "auto/"} {
		if kinds[name] != want {
			t.Errorf("%s = %s, want %s", name, kinds[name], want)
		}
	}
}
