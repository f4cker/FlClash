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
	} {
		reasons := groupReasons(t, rootOf(t, base+"dns:\n"+dns))
		if reasons["Free"] != "excluded/dns" || reasons["Main"] != "candidate/" {
			t.Errorf("%s: reasons = %v, want Free excluded for DNS and Main a candidate", name, reasons)
		}
	}
}

// M-3. A node whose endpoints are not its server is never mounted: a
// WireGuard node given peers, OpenVPN, ZeroTier, EasyTier and MASQUE. The
// inspection counts each as relay-excluded, as the provider drops it.
func TestMountSourceExcludesNodesWithUncheckedEndpoints(t *testing.T) {
	home := withMountHome(t)
	source := writeMountFile(t, home, "1.yaml", `proxies:
  - {name: peered, type: wireguard, private-key: zC6Kbw8IgU2If+FmAXfCxeTVpa4Ue9i6nLgEJq8Mtrs=, ip: 10.0.0.2, udp: true, peers: [{server: 100.101.1.1, port: 51820, public-key: x7sR/MNsxJyOT0M84m1UYlOgFTPnUfdA9afSqzFJAFA=, allowed-ips: [0.0.0.0/0]}]}
  - {name: vpn, type: openvpn, server: 192.0.2.1, port: 1194}
  - {name: zt, type: zerotier}
  - {name: et, type: easytier}
  - {name: mq, type: masque, server: 192.0.2.1, port: 443}
  - {name: wg, type: wireguard, server: 192.0.2.1, port: 51820, private-key: zC6Kbw8IgU2If+FmAXfCxeTVpa4Ue9i6nLgEJq8Mtrs=, public-key: x7sR/MNsxJyOT0M84m1UYlOgFTPnUfdA9afSqzFJAFA=, ip: 10.0.0.2, udp: true}
  - {name: plain, type: socks5, server: 192.0.2.1, port: 2}
`)
	got := handleInspectMountSource(MountInspectSourceParams{Path: source})
	if got.Status != mountSourceNodes || got.Count != 2 || got.RelayExcluded != 5 || got.Listed != 7 || !reflect.DeepEqual(got.names, []string{"wg", "plain"}) {
		t.Errorf("inspection = %+v, want wg and plain kept, five relay-excluded", got)
	}
	const profile = `proxy-groups:
  - {name: Auto, type: url-test, include-all-providers: true}
rules:
  - MATCH,Auto
`
	members, report := mountedMembers(t, profile, &MountSetup{Sources: []MountSource{{ID: 1, Label: "S", Path: source}}})
	if !reflect.DeepEqual(members["Auto"], []string{"wg", "plain"}) {
		t.Errorf("Auto = %v, want only wg and plain", members["Auto"])
	}
	if source := report.Sources[0]; source.RelayExcluded != 5 || len(source.Nodes) != 2 {
		t.Errorf("report = %+v, want five relay-excluded and two nodes", source)
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
