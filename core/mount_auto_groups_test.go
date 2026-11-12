package core

import (
	"errors"
	"reflect"
	"slices"
	"testing"

	"go.yaml.in/yaml/v3"
)

const mountFilterSource = `proxies:
  - {name: hk-1, type: socks5, server: 192.0.2.31, port: 1080}
  - {name: us-1, type: socks5, server: 192.0.2.32, port: 1080}
  - {name: jp-1, type: http, server: 192.0.2.33, port: 8080}
`

// Mounts join only a group that collects or uses providers or proxies, as new
// subscription nodes would; filter skips a group's own proxies.
func TestMountedNodesJoinOnlyGroupsThatAcceptNewNodes(t *testing.T) {
	home := withMountHome(t)
	const profile = `proxies:
  - {name: base, type: socks5, server: 127.0.0.9, port: 1080}
  - {name: base-us, type: socks5, server: 127.0.0.9, port: 1081}
proxy-providers:
  sub: {type: inline, payload: [{name: sub-hk, type: socks5, server: 127.0.0.9, port: 1082}]}
proxy-groups:
  - {name: Parent, type: fallback, proxies: [Nested, Filtered]}
  - {name: Nodes, type: select, proxies: [base, base-us]}
  - {name: Nested, type: url-test, proxies: [base-us], include-all-providers: true}
  - {name: Filtered, type: select, proxies: [base, base-us], use: [sub], filter: "^hk"}
  - {name: Excluding, type: fallback, include-all-proxies: true, exclude-filter: "us"}
  - {name: Typed, type: load-balance, use: [sub], exclude-type: http}
  - {name: Nothing, type: select, use: [sub], filter: "^none$"}
  - {name: Collects, type: url-test, include-all-providers: true, filter: "hk"}
  - {name: All, type: select, include-all: true, exclude-filter: "sub"}
  - {name: AllProxies, type: select, include-all-proxies: true}
  - {name: Shy, type: select, include-all-proxies: true, hidden: true}
  - {name: ShyFixed, type: select, proxies: [base], hidden: true}
rules:
  - MATCH,Parent
`
	source := writeMountFile(t, home, "1.yaml", mountFilterSource)
	root := rootOf(t, profile)
	target, err := inspectMountTarget(rootOf(t, profile), 0)
	if err != nil {
		t.Fatal(err)
	}
	kinds := map[string]string{}
	for _, group := range target.Groups {
		kinds[group.Name] = group.Kind
	}
	for _, fixed := range []string{"Parent", "Nodes", "ShyFixed"} {
		if kinds[fixed] != mountGroupFixed {
			t.Errorf("%s = %s, want fixed", fixed, kinds[fixed])
		}
	}
	report, err := applyMountOverrides(root, &MountSetup{Sources: []MountSource{{ID: 1, Label: "S", Path: source}}})
	if err != nil {
		t.Fatal(err)
	}
	cfg := checkOnlyConfig(t, &yaml.Node{Kind: yaml.DocumentNode, Content: []*yaml.Node{root}})
	for group, want := range map[string][]string{
		"Parent":     {"Nested", "Filtered"},
		"Nodes":      {"base", "base-us"},
		"Nested":     {"base-us", "hk-1", "us-1", "jp-1", "sub-hk"},
		"Filtered":   {"base", "base-us", "hk-1"},
		"Excluding":  {"base", "hk-1", "jp-1"},
		"Typed":      {"sub-hk", "hk-1", "us-1"},
		"Nothing":    {"REJECT"},
		"Collects":   {"hk-1", "sub-hk"},
		"All":        {"base", "base-us", "hk-1", "us-1", "jp-1"},
		"AllProxies": {"base", "base-us", "hk-1", "us-1", "jp-1"},
		"Shy":        {"base", "base-us", "hk-1", "us-1", "jp-1"},
		"ShyFixed":   {"base"},
	} {
		if got := memberNames(t, cfg, group); !reflect.DeepEqual(got, want) {
			t.Errorf("%s = %v, want %v", group, got, want)
		}
	}
	wantGroups := []MountGroupReport{
		{Name: "Nested", Via: "auto", Protection: mountProtectionOriginal},
		{Name: "Filtered", Via: "use", Protection: mountProtectionOriginal},
		{Name: "Excluding", Via: "use", Protection: mountProtectionOriginal},
		{Name: "Typed", Via: "use", Protection: mountProtectionReject, EmptyFallback: "REJECT"},
		{Name: "Nothing", Via: "use", Protection: mountProtectionReject, EmptyFallback: "REJECT"},
		{Name: "Collects", Via: "auto", Protection: mountProtectionReject, EmptyFallback: "REJECT"},
		{Name: "All", Via: "auto", Protection: mountProtectionOriginal},
		{Name: "AllProxies", Via: "use", Protection: mountProtectionOriginal},
		{Name: "Shy", Via: "use", Protection: mountProtectionOriginal},
	}
	if !reflect.DeepEqual(report.Groups, wantGroups) {
		t.Errorf("groups = %+v, want %+v", report.Groups, wantGroups)
	}
	mountProviders := map[string]struct{}{mountProviderName(1): {}}
	for group, want := range map[string]MountRuntimeGroup{
		"Nothing":  {Name: "Nothing", Present: true, Members: 0, Mounted: 0, Empty: true, Fallback: "REJECT"},
		"Filtered": {Name: "Filtered", Present: true, Members: 3, Mounted: 1, Fallback: "COMPATIBLE"},
	} {
		if got := mountRuntimeGroup(cfg.Proxies[group], group, mountProviders); got != want {
			t.Errorf("%s runtime = %+v, want %+v", group, got, want)
		}
	}
}

func TestMountAddsNothingWhenNoGroupAcceptsNewNodes(t *testing.T) {
	home := withMountHome(t)
	const profile = `proxies:
  - {name: hk, type: socks5, server: 127.0.0.9, port: 1080}
proxy-groups:
  - {name: Select, type: select, proxies: [HK, DIRECT]}
  - {name: HK, type: fallback, proxies: [hk]}
rules:
  - MATCH,Select
`
	source := writeMountFile(t, home, "1.yaml", mountFilterSource)
	target, err := inspectMountTarget(rootOf(t, profile), 0)
	if err != nil {
		t.Fatal(err)
	}
	for _, group := range target.Groups {
		if group.Kind != mountGroupFixed || group.Excluded != "" || group.Reason != "" {
			t.Errorf("%s = %+v, want only fixed", group.Name, group)
		}
	}
	root := rootOf(t, profile)
	report, err := applyMountOverrides(root, &MountSetup{Sources: []MountSource{{ID: 1, Label: "S", Path: source}}})
	if err != nil {
		t.Fatal(err)
	}
	if len(report.Groups) != 0 {
		t.Errorf("groups = %+v, want none", report.Groups)
	}
	cfg := checkOnlyConfig(t, &yaml.Node{Kind: yaml.DocumentNode, Content: []*yaml.Node{root}})
	for group, want := range map[string][]string{"Select": {"HK", "DIRECT"}, "HK": {"hk"}} {
		if got := memberNames(t, cfg, group); !reflect.DeepEqual(got, want) {
			t.Errorf("%s = %v, want %v", group, got, want)
		}
	}
}

// Kept-out groups that collect every provider are built as without the
// mounts, GLOBAL and unsupported types included.
func TestMountKeepsBuiltinAndUnsupportedGroupsFreeOfMounts(t *testing.T) {
	home := withMountHome(t)
	const profile = `proxies:
  - {name: base, type: socks5, server: 127.0.0.9, port: 1080}
proxy-groups:
  - {name: Main, type: select, proxies: [base], include-all-providers: true}
  - {name: GLOBAL, type: select, include-all: true}
rules:
  - MATCH,Main
`
	source := writeMountFile(t, home, "1.yaml", mountSourceB)
	checkMountTaking(t, "", profile, &MountSetup{Sources: []MountSource{{ID: 1, Label: "S", Path: source}}}, map[string]bool{
		"Main": true, "GLOBAL": false,
	})
}

// The check on the groups as they will run refuses what the isolation
// reading would have missed: a kept-out group holding a mount provider, a
// group taking mounts the report does not list, and a kept-out group whose
// member or empty-fallback takes them.
func TestMountedGroupsAreCheckedAsTheyWillRun(t *testing.T) {
	groupsOf := func(content string) *yaml.Node {
		return resolveAlias(mappingValue(rootOf(t, content), "proxy-groups"))
	}
	mount := []string{mountProviderName(1)}
	taking := []MountGroupReport{{Name: "Free"}}
	for name, tc := range map[string]struct {
		groups string
		reach  map[string]string
		taking []MountGroupReport
		want   string
	}{
		"kept-out group uses a mount": {
			groups: "proxy-groups:\n  - {name: Lan, type: select, use: [flash-mount-1]}\n  - {name: Free, type: select, use: [flash-mount-1]}\n",
			reach:  map[string]string{"Lan": reachHolds}, taking: taking, want: "Lan",
		},
		"kept-out group collects every provider": {
			groups: "proxy-groups:\n  - {name: Lan, type: select, include-all: true}\n  - {name: Free, type: select, use: [flash-mount-1]}\n",
			reach:  map[string]string{"Lan": reachHolds}, taking: taking, want: "Lan",
		},
		"unreported group takes mounts": {
			groups: "proxy-groups:\n  - {name: Other, type: select, use: [flash-mount-1]}\n  - {name: Free, type: select, use: [flash-mount-1]}\n",
			taking: taking, want: "Other",
		},
		"member of a kept-out group takes mounts": {
			groups: "proxy-groups:\n  - {name: Lan, type: select, proxies: [DIRECT, Free]}\n  - {name: Free, type: select, use: [flash-mount-1]}\n",
			reach:  map[string]string{"Lan": reachHolds}, taking: taking,
		},
		"empty-fallback of a kept-out group takes mounts": {
			groups: "proxy-groups:\n  - {name: Lan, type: select, proxies: [DIRECT], empty-fallback: Free}\n  - {name: Free, type: select, use: [flash-mount-1]}\n",
			reach:  map[string]string{"Lan": reachHolds}, taking: taking,
		},
		"a sound plan": {
			groups: "proxy-groups:\n  - {name: Lan, type: select, proxies: [DIRECT, Inner]}\n  - {name: Inner, type: select, proxies: [DIRECT]}\n  - {name: Free, type: select, use: [flash-mount-1]}\n",
			reach:  map[string]string{"Lan": reachHolds, "Inner": reachHolds}, taking: taking,
		},
	} {
		err := checkMountedGroups(groupsOf(tc.groups), tc.reach, tc.taking, mount)
		var methodErr *MethodError
		switch {
		case tc.want == "" && err != nil:
			t.Errorf("%s = %v, want it taken", name, err)
		case tc.want != "" && (!errors.As(err, &methodErr) || methodErr.Code != "mount_isolation_check" || methodErr.Details != tc.want):
			t.Errorf("%s = %v, want %s refused", name, err, tc.want)
		}
	}
}

// A direct-only branch a Tailscale rule targets stays without mounts once
// every other group takes them: the proof that it only exits DIRECT or
// REJECT is judged on the groups as they run.
func TestMountLeavesADirectOnlyTailscaleBranchDirect(t *testing.T) {
	home := withMountHome(t)
	const profile = `proxies:
  - {name: base, type: socks5, server: 127.0.0.9, port: 1080}
proxy-groups:
  - {name: Main, type: select, proxies: [base, Auto], include-all-providers: true}
  - {name: Auto, type: url-test, include-all-providers: true}
  - {name: Lan, type: select, proxies: [DIRECT, Block], include-all-providers: true}
  - {name: Block, type: select, proxies: [REJECT], include-all-providers: true}
  - {name: Switch, type: select, proxies: [DIRECT, Main], include-all-providers: true}
  - {name: Free, type: select, proxies: [base], include-all-providers: true}
rules:
  - IP-CIDR,100.64.0.0/10,Lan
  - DOMAIN-SUFFIX,ts.net,Switch
  - MATCH,Main
`
	source := writeMountFile(t, home, "1.yaml", mountSourceB)
	setup := &MountSetup{Sources: []MountSource{{ID: 1, Label: "S", Path: source}}}
	checkMountTaking(t, "", profile, setup, map[string]bool{
		"Lan": true, "Block": true, "Switch": true, "Main": true, "Auto": true, "Free": true,
	})
	members, _ := mountedMembers(t, profile, setup)
	if !slices.Equal(members["Lan"][:2], []string{"DIRECT", "Block"}) || members["Block"][0] != "REJECT" {
		t.Errorf("Lan = %v, Block = %v; want them as written", members["Lan"], members["Block"])
	}
	if !slices.Contains(members["Auto"], "us") {
		t.Errorf("Auto = %v, the switch could pick a mounted node through Main", members["Auto"])
	}
}
