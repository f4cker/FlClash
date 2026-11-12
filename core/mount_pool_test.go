//go:build with_gvisor && !no_tailscale

package core

import (
	"context"
	"errors"
	"fmt"
	"net/netip"
	"os"
	"reflect"
	"slices"
	"strings"
	"testing"

	"github.com/metacubex/mihomo/component/flashguard"
	"github.com/metacubex/mihomo/component/geodata"
	"github.com/metacubex/mihomo/component/geodata/router"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
	"go.yaml.in/yaml/v3"
	"google.golang.org/protobuf/proto"
)

func TestMountPoolLiteWithoutRuleCaches(t *testing.T) {
	for _, managed := range []int64{0, 9} {
		t.Run(fmt.Sprint(managed), func(t *testing.T) {
			home := withMountHome(t)
			for _, group := range mustMountTarget(t, liteProfile(), managed).Groups {
				if group.Kind == mountGroupExcluded {
					t.Fatalf("%s: %+v", group.Name, group)
				}
			}
			// The offline apply keeps the real rule list, with file-only providers and synthetic GeoIP.
			profile := strings.ReplaceAll(liteProfile(), "type: http, behavior:", "type: file, behavior:")
			profile = strings.ReplaceAll(profile, "interval: 300", "interval: 0")
			profile = strings.ReplaceAll(profile, "url: 'https://www.gstatic.com/generate_204'", "url: ''")
			profile = "geodata-mode: true\n" + profile
			writeSyntheticMountGeoIP(t)
			source := writeMountFile(t, home, "source.yaml", liteMountSource+"rules: [MATCH,REJECT]\ndns: {enable: true, nameserver: [203.0.113.99]}\nproxy-groups: [{name: remote-group, type: select, proxies: [DIRECT]}]\n")
			basePath := writeMountFile(t, home, "base.yaml", profile)
			withCurrentConfig(t, nil)
			keepTunnel(t)
			t.Cleanup(func() { installMountGate(nil, nil); setMountState(nil, false, false) })
			setup := &MountSetup{Target: 9, Revision: "pool-snapshot", Sources: []MountSource{{ID: 42, Label: "Synthetic", Path: source}}, managedRules: managed != 0, managedProfile: managed}
			var snapshot map[string][]string
			for pass := 0; pass < 2; pass++ {
				if err := applyConfig(&SetupParams{Base: &SetupBase{Path: basePath, Overlay: mountPoolOverlay(t, profile)}, Mounts: setup}); err != nil {
					t.Fatal(err)
				}
				waitProviderLoads(t)
				if state := handleMountState(); state.Blocked || state.Report == nil || len(state.Report.Groups) != 8 || len(state.Refused) != 0 {
					t.Fatalf("state: %+v", state)
				}
				got := map[string][]string{}
				for _, group := range liteOrdinaryGroups {
					got[group] = runningMembers(t, group)
					if !strings.Contains(liteGroupLine(profile, group), "include-all") {
						expected := groupList(mustGroup(t, rootOf(t, profile), group), "proxies")
						if !slices.Equal(got[group], expected) {
							t.Errorf("fixed %s = %v, want %v", group, got[group], expected)
						}
						continue
					}
					var mounted []string
					for _, name := range got[group] {
						if strings.HasSuffix(name, " M01") {
							mounted = append(mounted, name)
						}
					}
					var want []string
					for _, name := range []string{"香港 M01", "台湾 M01", "日本 M01", "新加坡 M01", "韩国 M01", "美国 M01"} {
						if filter := liteFilterOf(profile, group); filter == nil || filter.MatchString(name) {
							want = append(want, name)
						}
					}
					if !slices.Equal(mounted, want) {
						t.Errorf("%s mounted = %v, want %v", group, mounted, want)
					}
					t.Logf("pass %d %s mounted=%v", pass, group, mounted)
				}
				if pass == 0 {
					snapshot = got
				} else if !reflect.DeepEqual(got, snapshot) {
					t.Error("reload changed the snapshot")
				}
				document, _, err := mountedDocument(&SetupBase{Path: basePath, Overlay: mountPoolOverlay(t, profile)}, "", setup)
				if err != nil {
					t.Fatal(err)
				}
				root := document.Content[0]
				for _, key := range []string{"rules", "dns", "proxies"} {
					if nodeText(t, mappingValue(root, key)) != nodeText(t, mappingValue(rootOf(t, profile), key)) {
						t.Errorf("base %s changed", key)
					}
				}
				if mappingValue(root, "proxy-groups") == nil || tunnel.Proxies()["remote-group"] != nil {
					t.Error("source groups imported")
				}
			}
			if buf, _ := os.ReadFile(basePath); string(buf) != profile {
				t.Error("base file changed")
			}
			if buf, _ := os.ReadFile(source); string(buf) != liteMountSource+"rules: [MATCH,REJECT]\ndns: {enable: true, nameserver: [203.0.113.99]}\nproxy-groups: [{name: remote-group, type: select, proxies: [DIRECT]}]\n" {
				t.Error("source file changed")
			}
		})
	}
}

func mustMountTarget(t *testing.T, profile string, managed int64) MountTarget {
	t.Helper()
	target, err := inspectMountTarget(rootOf(t, profile), managed)
	if err != nil {
		t.Fatal(err)
	}
	return target
}
func mustGroup(t *testing.T, root *yaml.Node, name string) map[string]any {
	t.Helper()
	mappings, err := decodeMappings(mappingValue(root, "proxy-groups"), "proxy-groups")
	if err != nil {
		t.Fatal(err)
	}
	for _, group := range mappings {
		if groupString(group, "name") == name {
			return group
		}
	}
	t.Fatalf("group %s missing", name)
	return nil
}
func nodeText(t *testing.T, node *yaml.Node) string {
	t.Helper()
	if node == nil {
		return ""
	}
	data, err := yaml.Marshal(node)
	if err != nil {
		t.Fatal(err)
	}
	return string(data)
}

func TestMountPoolDNSDialersAndUnreadCaches(t *testing.T) {
	home := withMountHome(t)
	source := writeMountFile(t, home, "source.yaml", mountFilterSource)
	const profile = `proxies:
  - {name: base, type: socks5, server: 192.0.2.1, port: 1080}
  - {name: ordinary-transit, type: socks5, server: 192.0.2.2, port: 1080, dialer-proxy: Auto}
proxy-providers:
  unread: {type: file, path: unrelated-missing.yaml}
proxy-groups:
  - {name: Parent, type: select, proxies: [Auto, base]}
  - {name: Auto, type: select, include-all-providers: true, filter: '^hk', exclude-type: http}
rule-providers:
  unread-rules: {type: file, behavior: domain, path: unrelated-missing-rules.yaml}
rules:
  - RULE-SET,unread-rules,Parent
  - DOMAIN-SUFFIX,ts.net,Auto
  - MATCH,Parent
`
	for name, dns := range map[string]string{"rules": "dns: {respect-rules: true, nameserver: [1.1.1.1], proxy-server-nameserver: [1.1.1.1]}\n", "named": "dns: {nameserver: ['https://1.1.1.1/dns-query#Auto']}\n"} {
		t.Run(name, func(t *testing.T) {
			for _, managed := range []int64{0, 9} {
				target := mustMountTarget(t, profile+dns, managed)
				if target.Groups[1].Kind != mountGroupAuto || len(target.Relay) != 0 {
					t.Fatalf("target = %+v", target)
				}
			}
			applyMountedOverlay(t, home, profile+dns, mountPoolOverlay(t, profile+dns), source)
			waitProviderLoads(t)
			if got := runningMembers(t, "Auto"); !slices.Equal(got, []string{"hk-1"}) {
				t.Errorf("Auto = %v", got)
			}
			if got := runningMembers(t, "Parent"); !slices.Equal(got, []string{"Auto", "base"}) {
				t.Errorf("Parent = %v", got)
			}
			if state := handleMountState(); state.Blocked || len(state.Refused) != 0 {
				t.Fatalf("state = %+v", state)
			}
			if err := mountDialerViolation(tunnel.Proxies(), tunnel.Providers()); err != nil {
				t.Fatal(err)
			}
		})
	}
}

func TestMountPoolDependenciesUseActualFilteredMembership(t *testing.T) {
	home := withMountHome(t)
	const profile = `proxy-groups:
  - {name: G, type: select, include-all-providers: true, filter: '^B$'}
rules: ["MATCH,G"]
`
	for name, content := range map[string]string{
		"valid-filtered": "proxies:\n  - {name: A, type: socks5, server: 192.0.2.1, port: 1080, dialer-proxy: G}\n  - {name: B, type: socks5, server: 192.0.2.2, port: 1080}\n",
		"cycle":          "proxies:\n  - {name: B, type: socks5, server: 192.0.2.1, port: 1080, dialer-proxy: G}\n",
		"missing":        "proxies:\n  - {name: B, type: socks5, server: 192.0.2.1, port: 1080, dialer-proxy: absent}\n",
		"internal-cycle": "proxies:\n  - {name: A, type: socks5, server: 192.0.2.1, port: 1080, dialer-proxy: B}\n  - {name: B, type: socks5, server: 192.0.2.2, port: 1080, dialer-proxy: A}\n",
		"malformed":      "proxies:\n  - {name: B, type: invalid}\n",
	} {
		t.Run(name, func(t *testing.T) {
			source := writeMountFile(t, home, name+".yaml", content)
			document, _, err := mountedConfigDocument([]byte(profile), &MountSetup{Sources: []MountSource{{ID: 1, Path: source}}})
			if err == nil {
				err = parseDocument(document)
			}
			if name == "valid-filtered" {
				if err != nil {
					t.Fatal(err)
				}
				applyMountedOverlay(t, home, profile, mountPoolOverlay(t, profile), source)
				if got := runningMembers(t, "G"); !slices.Equal(got, []string{"B"}) {
					t.Errorf("G = %v", got)
				}
			} else if err == nil {
				t.Fatal("invalid introduced object accepted")
			} else {
				t.Log(err)
			}
		})
	}
}

func TestMountPoolInternalReferencesFollowCollisionRenames(t *testing.T) {
	home := withMountHome(t)
	const profile = `proxies:
  - {name: B, type: socks5, server: 192.0.2.3, port: 1080}
proxy-groups:
  - {name: G, type: select, include-all-providers: true}
rules: ["MATCH,G"]
`
	source := writeMountFile(t, home, "source.yaml", "proxies:\n  - {name: A, type: socks5, server: 192.0.2.1, port: 1080, dialer-proxy: B}\n  - {name: B, type: socks5, server: 192.0.2.2, port: 1080}\n")
	applyMountedOverlay(t, home, profile, mountPoolOverlay(t, profile), source)
	for _, proxy := range tunnel.Providers()[mountProviderName(1)].Proxies() {
		if proxy.Name() == "A" && proxy.ProxyInfo().DialerProxy != "B (S)" {
			t.Errorf("A dialer = %q", proxy.ProxyInfo().DialerProxy)
		}
	}
}

func TestMountPoolKeepsActualTailscaleConnectionGuard(t *testing.T) {
	home := withMountHome(t)
	source := writeMountFile(t, home, "source.yaml", mountFilterSource)
	applyMounted(t, home, "proxy-groups: [{name: Auto, type: select, include-all-providers: true}]\nrules: [\"MATCH,Auto\"]\n", source)
	proxy := tunnel.Providers()[mountProviderName(1)].Proxies()[0]
	for _, meta := range []*constant.Metadata{{NetWork: constant.TCP, Host: "nas.ts.net", DstPort: 443}, {NetWork: constant.TCP, DstIP: netip.MustParseAddr("100.101.1.1"), DstPort: 443}} {
		if conn, err := proxy.DialContext(context.Background(), meta); !errors.Is(err, flashguard.ErrRefused) {
			if conn != nil {
				_ = conn.Close()
			}
			t.Errorf("protected dial = %v", err)
		}
	}
	node := newTailscaleThrough(t, "actual-node", "Auto")
	if conn, err := node.SystemDial(t.Context(), "tcp", "203.0.113.20:443"); !errors.Is(err, flashguard.ErrRefused) {
		if conn != nil {
			_ = conn.Close()
		}
		t.Errorf("TS carrier = %v", err)
	}
	if pc, err := node.SystemListenPacket(t.Context(), "udp", "0.0.0.0:0"); !errors.Is(err, flashguard.ErrRefused) {
		if pc != nil {
			_ = pc.Close()
		}
		t.Errorf("TS UDP carrier = %v", err)
	}
}

func mountPoolOverlay(t *testing.T, profile string) string {
	t.Helper()
	root := rootOf(t, profile)
	overlay := &yaml.Node{Kind: yaml.MappingNode, Tag: "!!map"}
	for i := 0; i < len(root.Content); i += 2 {
		if !slices.Contains(profileBulkSections, root.Content[i].Value) {
			overlay.Content = append(overlay.Content, root.Content[i], root.Content[i+1])
		}
	}
	return nodeText(t, overlay)
}

func TestMountPoolOrdinaryCollectorsDoNotBecomeTailscaleDedicated(t *testing.T) {
	home := withMountHome(t)
	const profile = `proxies:
  - {name: ts-office, type: tailscale}
  - {name: base, type: socks5, server: 192.0.2.1, port: 1080}
proxy-groups:
  - {name: Dedicated, type: select, proxies: [ts-office], include-all-providers: true}
  - {name: Filtered, type: select, include-all: true, filter: '^hk'}
  - {name: All, type: select, include-all: true}
  - {name: Mixed, type: select, proxies: [ts-office, base], include-all-providers: true}
  - {name: Parent, type: select, proxies: [Dedicated, base], include-all-providers: true}
rules:
  - DOMAIN-SUFFIX,ts.net,Parent
  - MATCH,Parent
`
	target := mustMountTarget(t, profile, 0)
	for _, group := range target.Groups {
		if group.Name == "Dedicated" {
			if group.Kind != mountGroupExcluded {
				t.Errorf("dedicated = %+v", group)
			}
			continue
		}
		if group.Kind != mountGroupAuto {
			t.Errorf("ordinary = %+v", group)
		}
	}
	source := writeMountFile(t, home, "source.yaml", mountFilterSource)
	checkMountTaking(t, "", profile, &MountSetup{Sources: []MountSource{{ID: 1, Path: source}}}, map[string]bool{"Dedicated": false, "Filtered": true, "All": true, "Mixed": true, "Parent": true})
}

func TestMountPoolDedicatedUsesActualBaseCandidates(t *testing.T) {
	home := withMountHome(t)
	const profile = `proxies:
  - {name: ts-office, type: tailscale}
  - {name: base, type: socks5, server: 192.0.2.1, port: 1080}
proxy-providers:
  ts-provider: {type: inline, payload: [{name: ts-provider-node, type: tailscale}]}
  ordinary: {type: inline, payload: [{name: ordinary-provider-node, type: socks5, server: 192.0.2.2, port: 1080}]}
proxy-groups:
  - {name: ExplicitPlusAll, type: select, proxies: [ts-office], include-all: true}
  - {name: ProviderPlusAll, type: select, use: [ts-provider], include-all-providers: true}
  - {name: ProviderTypeOut, type: select, use: [ts-provider], include-all-providers: true, exclude-type: tailscale}
  - {name: ProviderNameOut, type: select, use: [ts-provider], include-all-providers: true, filter: '^hk'}
  - {name: Dedicated, type: select, use: [ts-provider]}
rules: ['MATCH,ExplicitPlusAll']
`
	for _, group := range mustMountTarget(t, profile, 0).Groups {
		want := mountGroupAuto
		if group.Name == "Dedicated" {
			want = mountGroupExcluded
		}
		if group.Kind != want {
			t.Errorf("%s = %+v, want %s", group.Name, group, want)
		}
	}
	source := writeMountFile(t, home, "source.yaml", mountFilterSource)
	checkMountTaking(t, "", profile, &MountSetup{Sources: []MountSource{{ID: 1, Path: source}}}, map[string]bool{"ExplicitPlusAll": true, "ProviderPlusAll": true, "ProviderTypeOut": true, "ProviderNameOut": true, "Dedicated": false})
}

func writeSyntheticMountGeoIP(t *testing.T) {
	t.Helper()
	beforeMode := geodata.GeodataMode()
	t.Cleanup(func() { geodata.SetGeodataMode(beforeMode); geodata.ClearGeoIPCache() })
	ipdata, err := proto.Marshal(&router.GeoIPList{Entry: []*router.GeoIP{{CountryCode: "CN", Cidr: []*router.CIDR{{Ip: []byte{198, 51, 100, 0}, Prefix: 24}}}, {CountryCode: "PRIVATE", Cidr: []*router.CIDR{{Ip: []byte{10, 0, 0, 0}, Prefix: 8}}}}})
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(constant.Path.GeoIP(), ipdata, 0600); err != nil {
		t.Fatal(err)
	}
	geodata.ClearGeoIPCache()
}
