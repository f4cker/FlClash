package core

import (
	"errors"
	"io"
	"net"
	"os"
	"path/filepath"
	"reflect"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/metacubex/mihomo/adapter/inbound"
	"github.com/metacubex/mihomo/component/flashguard"
	"github.com/metacubex/mihomo/component/sniffer"
	"github.com/metacubex/mihomo/constant"
	LT "github.com/metacubex/mihomo/listener/tunnel"
	"github.com/metacubex/mihomo/tunnel"
	"go.yaml.in/yaml/v3"
)

// An HTTP request through a tunnel listener to target; true when anything
// came back.
func httpThrough(t *testing.T, target, host string) bool {
	t.Helper()
	listener, err := LT.New("127.0.0.1:0", target, "", inbound.NewListenConfig(), tunnel.Tunnel)
	if err != nil {
		t.Fatal(err)
	}
	defer listener.Close()
	conn, err := net.DialTimeout("tcp", listener.Address(), 2*time.Second)
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(5 * time.Second))
	if _, err := io.WriteString(conn, "GET / HTTP/1.1\r\nHost: "+host+"\r\n\r\n"); err != nil {
		return false
	}
	answer := make([]byte, 3)
	_, err = io.ReadFull(conn, answer)
	return err == nil && string(answer) == "GET"
}

// M-1. With the sniffer overriding destinations, parse-pure-ip on, a
// connection to a Tailscale address carrying an ordinary Host is read by
// its Host from then on. What was protected before sniffing still marks
// it, so the mounted node refuses; an ordinary address is carried under
// its sniffed name, which shows the override took effect.
func TestSniffedOverrideKeepsAProtectedDestinationRefused(t *testing.T) {
	home := withMountHome(t)
	recorder := newEgressRecorder(t)
	writeMountFile(t, home, "mount-1.yaml", guardMountSource)
	profile := strings.Replace(guardProfile, "EGRESS", recorder.port(), 1) + `sniffer:
  enable: true
  parse-pure-ip: true
  override-destination: true
  skip-dst-address: []
  sniff:
    HTTP: {ports: [80], override-destination: true}
`
	cfg := checkOnlyConfig(t, &yaml.Node{Kind: yaml.DocumentNode, Content: []*yaml.Node{rootOf(t, profile)}})
	refused := recordRefusals(t)
	runInTunnel(t, cfg, tunnel.Rule)
	dispatcher, err := sniffer.NewDispatcher(cfg.Sniffer)
	if err != nil {
		t.Fatal(err)
	}
	tunnel.UpdateSniffer(dispatcher)
	t.Cleanup(func() {
		off, _ := sniffer.NewDispatcher(&sniffer.Config{})
		tunnel.UpdateSniffer(off)
	})

	for _, target := range []string{"100.101.2.3:80", "[fd7a:115c:a1e0::9]:80"} {
		if httpThrough(t, target, "nas.example.com") {
			t.Errorf("%s with Host nas.example.com was carried", target)
		}
	}
	wantNothingRecorded(t, recorder, "a sniffed tailnet connection")
	if got := refused.waitFor(t, 2); len(got) != 2 || !strings.Contains(got[0], "100.101.2.3:80") {
		t.Errorf("refusals = %v, want both, naming the address read before sniffing", got)
	}

	if !httpThrough(t, "203.0.113.7:80", "www.example.com") {
		t.Error("an ordinary sniffed connection was not carried")
	}
	wantCarried(t, recorder, 0, "192.0.2.10:1080", "www.example.com:80")
}

// M-2. A nameserver reached through a group sends that group lookups,
// tailnet names among them: proxy-server-nameserver also resolves node
// servers and a Tailscale node's control and DERP names. Each key, policy
// form too, keeps mounts out of the group.
func TestDNSThroughAGroupUnderEveryKeyKeepsMountsOut(t *testing.T) {
	withMountHome(t)
	const base = `proxies:
  - {name: hk, type: socks5, server: 127.0.0.9, port: 1080}
proxy-groups:
  - {name: Main, type: select, proxies: [hk]}
  - {name: Free, type: select, proxies: [hk]}
rules:
  - MATCH,Main
`
	for name, dns := range map[string]string{
		"proxy-server-nameserver":        "  proxy-server-nameserver: ['https://1.1.1.1/dns-query#Free']\n",
		"proxy-server-nameserver-policy": "  proxy-server-nameserver-policy: {'+.example.com': 'tls://1.1.1.1#Free'}\n",
		"proxy-server-nameserver list":   "  proxy-server-nameserver-policy: {'geosite:cn': ['tls://1.1.1.1#Free', 223.5.5.5]}\n",
		"default-nameserver":             "  default-nameserver: ['tls://1.1.1.1#Free']\n",
		"percent-encoded nameserver":     "  nameserver: ['https://1.1.1.1/dns-query#%46%72%65%65']\n",
		"percent-encoded with params":    "  proxy-server-nameserver: ['1.1.1.1#%46ree&h3=true']\n",
	} {
		reasons := groupReasons(t, rootOf(t, base+"dns:\n"+dns))
		if reasons["Free"] != "excluded/dns" || reasons["Main"] != "candidate/" {
			t.Errorf("%s: reasons = %v, want Free excluded for DNS and Main a candidate", name, reasons)
		}
	}
}

// L-1. mihomo reads the proxy of a nameserver from its URL's fragment,
// percent decoded: an encoded group name is that group.
func TestDNSThroughAPercentEncodedGroupKeepsMountsOut(t *testing.T) {
	withMountHome(t)
	const base = `proxies:
  - {name: hk, type: socks5, server: 127.0.0.9, port: 1080}
proxy-groups:
  - {name: 节点选择, type: select, proxies: [hk]}
  - {name: Main, type: select, proxies: [hk]}
rules:
  - MATCH,Main
dns:
  nameserver: ['https://1.1.1.1/dns-query#%E8%8A%82%E7%82%B9%E9%80%89%E6%8B%A9']
`
	if reasons := groupReasons(t, rootOf(t, base)); reasons["节点选择"] != "excluded/dns" || reasons["Main"] != "candidate/" {
		t.Errorf("reasons = %v, want 节点选择 excluded for DNS and Main a candidate", reasons)
	}
	const spaced = `proxies:
  - {name: hk, type: socks5, server: 127.0.0.9, port: 1080}
proxy-groups:
  - {name: " G", type: select, proxies: [hk]}
  - {name: G, type: select, proxies: [hk]}
  - {name: Main, type: select, proxies: [hk]}
rules:
  - MATCH,Main
dns:
`
	for _, nameserver := range []string{"'1.1.1.1#%20G'", "'1.1.1.1# G'", "'tls://1.1.1.1#%20G&h3=true'"} {
		reasons := groupReasons(t, rootOf(t, spaced+"  nameserver: ["+nameserver+"]\n"))
		if reasons[" G"] != "excluded/dns" || reasons["Main"] != "candidate/" {
			t.Errorf("%s: reasons = %v, want \" G\" excluded for DNS and Main a candidate", nameserver, reasons)
		}
	}
	for server, want := range map[string]string{
		"https://1.1.1.1/dns-query#%E8%8A%82%E7%82%B9%E9%80%89%E6%8B%A9": "节点选择",
		"tls://1.1.1.1#Free&h3=true":                                     "Free&h3=true",
		"1.1.1.1#A%20B":                                                  "A B",
		"1.1.1.1#%20G":                                                   " G",
		"1.1.1.1":                                                        "",
	} {
		if got := dnsFragment(server); got != want {
			t.Errorf("dnsFragment(%q) = %q, want %q", server, got, want)
		}
	}
}

// M-3. A node whose endpoints are not its server is never mounted: a
// WireGuard node given peers, OpenVPN, ZeroTier, EasyTier, MASQUE, VLESS
// with an XHTTP download server and Hysteria2 with a realm on. The
// inspection counts each as unsupported, as the provider drops it.
func TestMountSourceExcludesNodesWithUncheckedEndpoints(t *testing.T) {
	home := withMountHome(t)
	source := writeMountFile(t, home, "1.yaml", `proxies:
  - {name: peered, type: wireguard, private-key: zC6Kbw8IgU2If+FmAXfCxeTVpa4Ue9i6nLgEJq8Mtrs=, ip: 10.0.0.2, udp: true, peers: [{server: 100.101.1.1, port: 51820, public-key: x7sR/MNsxJyOT0M84m1UYlOgFTPnUfdA9afSqzFJAFA=, allowed-ips: [0.0.0.0/0]}]}
  - {name: vpn, type: openvpn, server: 192.0.2.1, port: 1194}
  - {name: zt, type: zerotier}
  - {name: et, type: easytier}
  - {name: mq, type: masque, server: 192.0.2.1, port: 443}
  - {name: wg, type: wireguard, server: 192.0.2.1, port: 51820, private-key: zC6Kbw8IgU2If+FmAXfCxeTVpa4Ue9i6nLgEJq8Mtrs=, public-key: x7sR/MNsxJyOT0M84m1UYlOgFTPnUfdA9afSqzFJAFA=, ip: 10.0.0.2, udp: true}
  - {name: dl, type: vless, server: 203.0.113.5, port: 443, uuid: 4d1e2f6a-0f5c-4b3e-9f7a-2c1d0e9b8a71, network: xhttp, xhttp-opts: {path: /x, Download_Settings: {server: 100.101.1.1, path: /admin/x, headers: {X-A: b}}}}
  - {name: realm, type: hysteria2, server: 203.0.113.6, port: 443, password: synthetic, realm_opts: {enable: true, server-url: "http://100.101.1.1/r"}}
  - {name: dl2, type: vless, server: 203.0.113.5, port: 443, uuid: 4d1e2f6a-0f5c-4b3e-9f7a-2c1d0e9b8a71, network: xhttp, xhttp-opts: {path: /x, 1: one, download-settings: {server: 100.101.1.2}}}
  - {name: realm2, type: hysteria2, server: 203.0.113.6, port: 443, password: synthetic, realm-opts: {enable: "true", server-url: "http://100.101.1.1/r"}}
  - {name: xh, type: vless, server: 203.0.113.5, port: 443, uuid: 4d1e2f6a-0f5c-4b3e-9f7a-2c1d0e9b8a71, network: xhttp, xhttp-opts: {path: /x}}
  - {name: hy, type: hysteria2, server: 203.0.113.6, port: 443, password: synthetic, realm-opts: {enable: false, server-url: "http://100.101.1.1/r"}}
  - {name: plain, type: socks5, server: 192.0.2.1, port: 2}
`)
	kept := []string{"wg", "xh", "hy", "plain"}
	got := handleInspectMountSource(MountInspectSourceParams{Path: source})
	if got.Status != mountSourceNodes || got.Count != 4 || got.UnsupportedExcluded != 9 || got.RelayExcluded != 0 || got.Listed != 13 || !reflect.DeepEqual(got.names, kept) {
		t.Errorf("inspection = %+v, want %v kept, nine unsupported", got, kept)
	}
	const profile = `proxy-groups:
  - {name: Auto, type: url-test, include-all-providers: true}
rules:
  - MATCH,Auto
`
	members, report := mountedMembers(t, profile, &MountSetup{Sources: []MountSource{{ID: 1, Label: "S", Path: source}}})
	if !reflect.DeepEqual(members["Auto"], kept) {
		t.Errorf("Auto = %v, want only %v", members["Auto"], kept)
	}
	if source := report.Sources[0]; source.UnsupportedExcluded != 9 || source.RelayExcluded != 0 || len(source.Nodes) != 4 {
		t.Errorf("report = %+v, want nine unsupported and four nodes", source)
	}
}

// The suffixes a mounted node refuses are read from the routing memories
// on disk when a mount is applied, not only set by hand.
func TestMountApplyReadsTailnetSuffixesFromRoutingMemory(t *testing.T) {
	home := withMountHome(t)
	flashguard.SetSuffixes(nil)
	t.Cleanup(func() { flashguard.SetSuffixes(nil) })
	recorder := newEgressRecorder(t)
	if flashguard.ProtectedHost("box.corp.example") {
		t.Fatal("corp.example is protected before any memory is read")
	}
	if err := os.MkdirAll(tailscaleRoutesDir(), 0o700); err != nil {
		t.Fatal(err)
	}
	memory := filepath.Join(tailscaleRoutesDir(), "routes-7.json")
	if err := os.WriteFile(memory, []byte(`{"version": 1, "suffixes": ["Corp.Example."]}`), 0o600); err != nil {
		t.Fatal(err)
	}
	source := writeMountFile(t, home, "1.yaml", guardMountSource)
	root := rootOf(t, strings.Replace(`proxies:
  - {name: egress, type: http, server: 127.0.0.1, port: EGRESS}
proxy-groups:
  - {name: Auto, type: select, include-all-providers: true}
rules:
  - MATCH,Auto
`, "EGRESS", recorder.port(), 1))
	if _, err := applyMountOverrides(root, &MountSetup{Sources: []MountSource{{ID: 1, Label: "S", Path: source}}}); err != nil {
		t.Fatal(err)
	}
	if !slices.Contains(flashguard.Suffixes(), "corp.example") {
		t.Fatalf("suffixes = %v, want corp.example from the memory", flashguard.Suffixes())
	}
	cfg := checkOnlyConfig(t, &yaml.Node{Kind: yaml.DocumentNode, Content: []*yaml.Node{root}})
	refused := recordRefusals(t)
	runInTunnel(t, cfg, tunnel.Rule)
	if carriedTCP(t, "box.corp.example:22", "") {
		t.Error("box.corp.example was carried by the mounted node")
	}
	wantNothingRecorded(t, recorder, "a name under a remembered suffix")
	if got := refused.waitFor(t, 1); len(got) != 1 || !strings.Contains(got[0], "box.corp.example") {
		t.Errorf("refusals = %v", got)
	}
	_, err := cfg.Proxies["Auto"].DialContext(t.Context(), &constant.Metadata{NetWork: constant.TCP, Host: "nas.corp.example", DstPort: 443})
	if !errors.Is(err, flashguard.ErrRefused) {
		t.Errorf("a dial to nas.corp.example = %v, want ErrRefused", err)
	}
	if !carriedTCP(t, guardOrdinary, "") {
		t.Error("an ordinary destination was not carried")
	}
	wantCarried(t, recorder, 0, "192.0.2.10:1080", guardOrdinary)
}
