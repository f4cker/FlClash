package core

import (
	"bufio"
	"encoding/binary"
	"errors"
	"io"
	"net"
	"net/http"
	"net/netip"
	"os"
	"reflect"
	"slices"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/metacubex/mihomo/adapter/inbound"
	"github.com/metacubex/mihomo/adapter/outboundgroup"
	"github.com/metacubex/mihomo/component/flashguard"
	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/constant"
	LT "github.com/metacubex/mihomo/listener/tunnel"
	"github.com/metacubex/mihomo/tunnel"
	"go.yaml.in/yaml/v3"
)

// The fake egress every mounted node leaves through: an HTTP CONNECT proxy
// on loopback that the node's dialer-proxy points at, so the node's own
// server stays a TEST-NET address. It records the node server a CONNECT asks
// for, then answers SOCKS5 as that server would, records where the node sends
// the connection and echoes it.
type egressRecorder struct {
	addr    string
	mu      sync.Mutex
	servers []string
	targets []string
}

func newEgressRecorder(t *testing.T) *egressRecorder {
	t.Helper()
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = listener.Close() })
	recorder := &egressRecorder{addr: listener.Addr().String()}
	go func() {
		for {
			conn, err := listener.Accept()
			if err != nil {
				return
			}
			go recorder.serve(conn)
		}
	}()
	return recorder
}

func (r *egressRecorder) port() string {
	_, port, _ := net.SplitHostPort(r.addr)
	return port
}

func (r *egressRecorder) record(list *[]string, value string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	*list = append(*list, value)
}

func (r *egressRecorder) seen() ([]string, []string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	return slices.Clone(r.servers), slices.Clone(r.targets)
}

func (r *egressRecorder) serve(conn net.Conn) {
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(10 * time.Second))
	reader := bufio.NewReader(conn)
	request, err := http.ReadRequest(reader)
	if err != nil || request.Method != http.MethodConnect {
		return
	}
	r.record(&r.servers, request.Host)
	if _, err := io.WriteString(conn, "HTTP/1.1 200 Connection established\r\n\r\n"); err != nil {
		return
	}
	head := make([]byte, 2)
	if _, err := io.ReadFull(reader, head); err != nil || head[0] != 5 {
		return
	}
	if _, err := io.ReadFull(reader, make([]byte, head[1])); err != nil {
		return
	}
	if _, err := conn.Write([]byte{5, 0}); err != nil {
		return
	}
	request4 := make([]byte, 4)
	if _, err := io.ReadFull(reader, request4); err != nil {
		return
	}
	var host string
	switch request4[3] {
	case 1, 4:
		size := 4
		if request4[3] == 4 {
			size = 16
		}
		ip := make([]byte, size)
		if _, err := io.ReadFull(reader, ip); err != nil {
			return
		}
		addr, _ := netip.AddrFromSlice(ip)
		host = addr.String()
	case 3:
		size, err := reader.ReadByte()
		if err != nil {
			return
		}
		name := make([]byte, size)
		if _, err := io.ReadFull(reader, name); err != nil {
			return
		}
		host = string(name)
	default:
		return
	}
	port := make([]byte, 2)
	if _, err := io.ReadFull(reader, port); err != nil {
		return
	}
	r.record(&r.targets, net.JoinHostPort(host, strconv.Itoa(int(binary.BigEndian.Uint16(port)))))
	if request4[1] != 1 {
		return
	}
	if _, err := conn.Write([]byte{5, 0, 0, 1, 0, 0, 0, 0, 0, 0}); err != nil {
		return
	}
	_, _ = io.Copy(conn, reader)
}

type refusals struct {
	mu   sync.Mutex
	list []string
}

func recordRefusals(t *testing.T) *refusals {
	t.Helper()
	recorded := &refusals{}
	previous := flashguard.OnRefuse
	flashguard.OnRefuse = func(node, reason string) {
		recorded.mu.Lock()
		defer recorded.mu.Unlock()
		recorded.list = append(recorded.list, node+": "+reason)
	}
	t.Cleanup(func() { flashguard.OnRefuse = previous })
	return recorded
}

func (r *refusals) count() int {
	r.mu.Lock()
	defer r.mu.Unlock()
	return len(r.list)
}

func (r *refusals) waitFor(t *testing.T, count int) []string {
	t.Helper()
	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		if r.count() >= count {
			break
		}
		time.Sleep(20 * time.Millisecond)
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	return slices.Clone(r.list)
}

// Runs cfg in the tunnel as executor.ApplyConfig installs it.
func runInTunnel(t *testing.T, cfg *config.Config, mode tunnel.TunnelMode) {
	t.Helper()
	keepTunnel(t)
	tunnel.UpdateProxies(cfg.Proxies, cfg.Providers)
	tunnel.UpdateRules(cfg.Rules, cfg.SubRules, cfg.RuleProviders)
	tunnel.SetMode(mode)
	tunnel.OnRunning()
}

func selectIn(t *testing.T, cfg *config.Config, group, name string) {
	t.Helper()
	selectable, ok := adapterAs[outboundgroup.SelectAble](cfg.Proxies[group])
	if !ok {
		t.Fatalf("%s cannot be selected in", group)
	}
	if err := selectable.Set(name); err != nil {
		t.Fatalf("select %s in %s: %v", name, group, err)
	}
}

// A real tunnel listener, as a tunnels: entry or a listener with proxy: or
// rule: builds one, forwards a TCP connection to target. True when the
// connection was carried end to end.
func carriedTCP(t *testing.T, target, proxy string, additions ...inbound.Addition) bool {
	t.Helper()
	listener, err := LT.New("127.0.0.1:0", target, proxy, inbound.NewListenConfig(), tunnel.Tunnel, additions...)
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
	if _, err := conn.Write([]byte("ping")); err != nil {
		return false
	}
	answer := make([]byte, 4)
	_, err = io.ReadFull(conn, answer)
	return err == nil && string(answer) == "ping"
}

const guardProfile = `proxies:
  - {name: egress, type: http, server: 127.0.0.1, port: EGRESS}
  - {name: jump, type: http, server: 192.0.2.50, port: 8080, dialer-proxy: Auto}
proxy-providers:
  flash-mount-1: {type: file, path: mount-1.yaml}
proxy-groups:
  - {name: Auto, type: select, use: [flash-mount-1]}
rules:
  - IP-CIDR,100.70.0.0/16,jump,no-resolve
  - SUB-RULE,(DST-PORT,8443),sub
  - MATCH,Auto
sub-rules:
  sub:
    - MATCH,Auto
`

const guardMountSource = "proxies:\n  - {name: m1, type: socks5, server: 192.0.2.10, port: 1080, udp: true, dialer-proxy: egress}\n"

// Tailscale destinations a mounted node must refuse, by the names the tunnel
// reads them under, with one ordinary destination it must carry.
var guardBlocked = []string{"100.100.1.1:22", "[fd7a:115c:a1e0::1]:22", "nas.tail1.ts.net:22", "box.corp.example:22"}

const guardOrdinary = "203.0.113.7:443"

// The profile is built by hand, past the mount checks, so every group here
// holds a mounted node however Tailscale traffic is routed to it: what keeps
// it out is the runtime guard alone.
func guardedConfig(t *testing.T) (*config.Config, *egressRecorder, string) {
	t.Helper()
	home := withMountHome(t)
	recorder := newEgressRecorder(t)
	writeMountFile(t, home, "mount-1.yaml", guardMountSource)
	flashguard.SetSuffixes([]string{"corp.example"})
	t.Cleanup(func() { flashguard.SetSuffixes(nil) })
	profile := strings.Replace(guardProfile, "EGRESS", recorder.port(), 1)
	cfg := checkOnlyConfig(t, &yaml.Node{Kind: yaml.DocumentNode, Content: []*yaml.Node{rootOf(t, profile)}})
	if got := memberNames(t, cfg, "Auto"); !slices.Equal(got, []string{"m1"}) {
		t.Fatalf("Auto = %v, want the mounted m1", got)
	}
	return cfg, recorder, home
}

func wantNothingRecorded(t *testing.T, recorder *egressRecorder, what string) {
	t.Helper()
	if servers, targets := recorder.seen(); len(servers) > 0 || len(targets) > 0 {
		t.Errorf("%s reached the mounted node's egress: servers %v, targets %v", what, servers, targets)
	}
}

func wantCarried(t *testing.T, recorder *egressRecorder, before int, server, target string) {
	t.Helper()
	servers, targets := recorder.seen()
	if len(servers) <= before || servers[len(servers)-1] != server || targets[len(targets)-1] != target {
		t.Errorf("egress saw servers %v, targets %v; want %s to %s last", servers, targets, server, target)
	}
}

func TestMountedNodeRefusesTailscaleOnEveryTunnelPath(t *testing.T) {
	cfg, recorder, _ := guardedConfig(t)
	refused := recordRefusals(t)
	runInTunnel(t, cfg, tunnel.Rule)

	paths := []struct {
		name      string
		proxy     string
		port      string
		additions []inbound.Addition
	}{
		{"MATCH rule", "", "22", nil},
		{"sub-rule MATCH", "", "8443", nil},
		{"listener or tunnel proxy", "Auto", "22", nil},
		{"listener sub-rule", "", "22", []inbound.Addition{inbound.WithSpecialRules("sub")}},
	}
	want := 0
	for _, path := range paths {
		for _, blocked := range guardBlocked {
			host, _, _ := net.SplitHostPort(blocked)
			target := net.JoinHostPort(host, path.port)
			if carriedTCP(t, target, path.proxy, path.additions...) {
				t.Errorf("%s: %s was carried", path.name, target)
			}
			want++
		}
	}
	// A rule sends 100.70.0.0/16 to jump, a base proxy whose dialer-proxy is
	// Auto: what it dials for a Tailscale address is refused too.
	if carriedTCP(t, "100.70.1.1:22", "") {
		t.Error("100.70.1.1 was carried through jump and a mounted node")
	}
	want++
	wantNothingRecorded(t, recorder, "Tailscale traffic")
	if got := refused.waitFor(t, want); len(got) != want {
		t.Errorf("refusals = %d, want %d: %v", len(got), want, got)
	}

	// The positive control: an ordinary destination, by every path, leaves
	// through the mounted node to its server.
	for _, path := range paths {
		_, before := recorder.seen()
		host, _, _ := net.SplitHostPort(guardOrdinary)
		target := net.JoinHostPort(host, path.port)
		if !carriedTCP(t, target, path.proxy, path.additions...) {
			t.Errorf("%s: ordinary %s was not carried", path.name, target)
		}
		wantCarried(t, recorder, len(before), "192.0.2.10:1080", target)
	}
}

func TestMountedNodeRefusesTailscaleInGlobalMode(t *testing.T) {
	cfg, recorder, _ := guardedConfig(t)
	refused := recordRefusals(t)
	runInTunnel(t, cfg, tunnel.Global)
	selectIn(t, cfg, globalProxyName, "Auto")
	for _, blocked := range guardBlocked {
		if carriedTCP(t, blocked, "") {
			t.Errorf("GLOBAL carried %s", blocked)
		}
	}
	wantNothingRecorded(t, recorder, "Tailscale traffic in global mode")
	if got := refused.waitFor(t, len(guardBlocked)); len(got) != len(guardBlocked) {
		t.Errorf("refusals = %v", got)
	}
	if !carriedTCP(t, guardOrdinary, "") {
		t.Error("GLOBAL did not carry an ordinary destination")
	}
	wantCarried(t, recorder, 0, "192.0.2.10:1080", guardOrdinary)

	// Switching back to rule mode changes nothing the guard does.
	tunnel.SetMode(tunnel.Rule)
	if carriedTCP(t, guardBlocked[0], "") {
		t.Error("rule mode after global carried a Tailscale address")
	}
}

func TestMountedNodeAddedByAProviderUpdateRefusesItsFirstConnection(t *testing.T) {
	cfg, recorder, _ := guardedConfig(t)
	refused := recordRefusals(t)
	runInTunnel(t, cfg, tunnel.Rule)
	update := guardMountSource + "  - {name: m2, type: socks5, server: 192.0.2.11, port: 1080, dialer-proxy: egress}\n" +
		"  - {name: loop, type: socks5, server: 127.0.0.1, port: 1055}\n"
	if _, _, err := cfg.Providers["flash-mount-1"].(sideUpdater).SideUpdate([]byte(update)); err != nil {
		t.Fatal(err)
	}
	if got := memberNames(t, cfg, "Auto"); !slices.Equal(got, []string{"m1", "m2"}) {
		t.Fatalf("Auto after the update = %v, want [m1 m2]: a loopback server is dropped", got)
	}
	selectIn(t, cfg, "Auto", "m2")
	if carriedTCP(t, guardBlocked[0], "") {
		t.Error("m2's first connection carried a Tailscale address")
	}
	wantNothingRecorded(t, recorder, "m2's first Tailscale connection")
	if got := refused.waitFor(t, 1); len(got) != 1 || !strings.HasPrefix(got[0], "m2: ") {
		t.Errorf("refusals = %v, want m2's", got)
	}
	if !carriedTCP(t, guardOrdinary, "") {
		t.Error("m2 did not carry an ordinary destination")
	}
	wantCarried(t, recorder, 0, "192.0.2.11:1080", guardOrdinary)
}

// UDP takes the same tunnel entry. A UDP tunnel listener sends a datagram
// to a Tailscale address through the mounted SOCKS5 node: the association it
// would open is refused before its TCP control connection reaches the egress.
func TestMountedNodeRefusesTailscaleUDP(t *testing.T) {
	cfg, recorder, _ := guardedConfig(t)
	refused := recordRefusals(t)
	runInTunnel(t, cfg, tunnel.Rule)
	for i, blocked := range guardBlocked[:2] {
		listener, err := LT.NewUDP("127.0.0.1:0", blocked, "Auto", inbound.NewListenConfig(), tunnel.Tunnel)
		if err != nil {
			t.Fatal(err)
		}
		conn, err := net.Dial("udp", listener.Address())
		if err != nil {
			t.Fatal(err)
		}
		if _, err := conn.Write([]byte("ping")); err != nil {
			t.Fatal(err)
		}
		if got := refused.waitFor(t, i+1); len(got) != i+1 {
			t.Errorf("a datagram to %s: refusals %v", blocked, got)
		}
		_ = conn.Close()
		_ = listener.Close()
	}
	wantNothingRecorded(t, recorder, "a Tailscale datagram")
}

type fakeUDPPacket struct {
	data  []byte
	local net.Addr
}

func (p *fakeUDPPacket) Data() []byte { return p.data }

func (p *fakeUDPPacket) WriteBack([]byte, net.Addr) (int, error) { return 0, nil }

func (p *fakeUDPPacket) Drop() {}

func (p *fakeUDPPacket) LocalAddr() net.Addr { return p.local }

// The tunnel keys a UDP mapping by source alone, so a second destination
// from one source reuses the connection the first opened. A mounted node's
// connection refuses each datagram to a Tailscale address; ordinary ones go
// on. The node here is a direct one, so the positive control is a real
// datagram to a loopback echo.
func TestMountedNodeRefusesATailscaleDatagramOnAReusedConnection(t *testing.T) {
	home := withMountHome(t)
	writeMountFile(t, home, "mount-2.yaml", "proxies:\n  - {name: u1, type: direct, udp: true}\n")
	cfg := checkOnlyConfig(t, &yaml.Node{Kind: yaml.DocumentNode, Content: []*yaml.Node{rootOf(t, `proxy-providers:
  flash-mount-2: {type: file, path: mount-2.yaml}
proxy-groups:
  - {name: Udp, type: select, use: [flash-mount-2]}
rules:
  - MATCH,Udp
`)}})
	refused := recordRefusals(t)
	runInTunnel(t, cfg, tunnel.Rule)
	echo, err := net.ListenPacket("udp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer echo.Close()
	received := make(chan string, 4)
	go func() {
		buf := make([]byte, 64)
		for {
			n, _, err := echo.ReadFrom(buf)
			if err != nil {
				return
			}
			received <- string(buf[:n])
		}
	}()
	source := &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1), Port: 40001}
	send := func(payload, target string) {
		metadata := &constant.Metadata{NetWork: constant.UDP, Type: constant.SOCKS5, SrcIP: netip.MustParseAddr("127.0.0.1"), SrcPort: 40001}
		if err := metadata.SetRemoteAddress(target); err != nil {
			t.Fatal(err)
		}
		tunnel.Tunnel.HandleUDPPacket(&fakeUDPPacket{data: []byte(payload), local: source}, metadata)
	}
	send("first", echo.LocalAddr().String())
	select {
	case got := <-received:
		if got != "first" {
			t.Errorf("echo received %q", got)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("an ordinary datagram through the mounted node never arrived")
	}
	send("second", "100.100.1.1:41641")
	if got := refused.waitFor(t, 1); len(got) != 1 || !strings.Contains(got[0], "100.100.1.1:41641") {
		t.Errorf("refusals = %v, want the datagram to 100.100.1.1 refused", got)
	}
	send("third", echo.LocalAddr().String())
	select {
	case got := <-received:
		if got != "third" {
			t.Errorf("echo received %q, want only ordinary datagrams", got)
		}
	case <-time.After(5 * time.Second):
		t.Error("the reused connection stopped carrying ordinary datagrams")
	}
}

// A classical rule set an update sends Tailscale ranges to a mounted group
// through: the gate refuses it and the set and its file keep what was
// checked. Taken past the gate, as a reload from elsewhere would, the runtime
// guard still refuses the connection.
func TestMountedClassicalRuleSetUpdateIsRefusedTwice(t *testing.T) {
	home := withMountHome(t)
	recorder := newEgressRecorder(t)
	refused := recordRefusals(t)
	lan := writeMountFile(t, home, "lan.txt", "IP-CIDR,10.0.0.0/8\n")
	source := writeMountFile(t, home, "1.yaml", guardMountSource)
	profile := strings.Replace(`proxies:
  - {name: egress, type: http, server: 127.0.0.1, port: EGRESS}
proxy-groups:
  - {name: Lan, type: select, proxies: [DIRECT]}
rule-providers:
  lan: {type: file, behavior: classical, format: text, path: lan.txt}
rules:
  - RULE-SET,lan,Lan,no-resolve
  - MATCH,REJECT
`, "EGRESS", recorder.port(), 1)
	root := rootOf(t, profile)
	report, err := applyMountOverrides(root, &MountSetup{Groups: []string{"Lan"}, Sources: []MountSource{{ID: 1, Label: "S", Path: source}}})
	if err != nil {
		t.Fatal(err)
	}
	installMountGate(report)
	t.Cleanup(func() { installMountGate(nil) })
	cfg := checkOnlyConfig(t, &yaml.Node{Kind: yaml.DocumentNode, Content: []*yaml.Node{root}})
	runInTunnel(t, cfg, tunnel.Rule)
	selectIn(t, cfg, "Lan", "m1")
	// The set's update result has an unexported type; call it as the
	// fetcher's interval update calls it.
	sideUpdate := func(buf []byte) error {
		results := reflect.ValueOf(cfg.RuleProviders["lan"]).MethodByName("SideUpdate").Call([]reflect.Value{reflect.ValueOf(buf)})
		err, _ := results[2].Interface().(error)
		return err
	}

	reaching := []byte("IP-CIDR,10.0.0.0/8\nIP-CIDR,100.64.0.0/10\n")
	if err := sideUpdate(reaching); err == nil {
		t.Fatal("a classical update sending 100.64.0.0/10 to Lan was taken")
	}
	if buf, _ := os.ReadFile(lan); string(buf) != "IP-CIDR,10.0.0.0/8\n" {
		t.Errorf("the rule set file = %q, want what was checked", buf)
	}
	if !slices.Contains(handleMountState().Refused, "lan") {
		t.Errorf("refused = %v, want lan", handleMountState().Refused)
	}
	if carriedTCP(t, "100.100.1.1:22", "") {
		t.Error("100.100.1.1 was carried after the refused update")
	}

	installMountGate(nil)
	if err := sideUpdate(reaching); err != nil {
		t.Fatal(err)
	}
	if carriedTCP(t, "100.100.1.1:22", "") {
		t.Error("100.100.1.1 was carried through Lan's mounted node")
	}
	wantNothingRecorded(t, recorder, "Tailscale traffic through a rule set")
	if got := refused.waitFor(t, 1); len(got) != 1 {
		t.Errorf("refusals = %v, want the one through Lan", got)
	}
	if !carriedTCP(t, "10.1.2.3:80", "") {
		t.Error("Lan's mounted node did not carry 10.1.2.3")
	}
	wantCarried(t, recorder, 0, "192.0.2.10:1080", "10.1.2.3:80")
}

// The guard never turns a refusal into another way out.
func TestMountedNodeRefusalIsFinal(t *testing.T) {
	cfg, recorder, _ := guardedConfig(t)
	recordRefusals(t)
	runInTunnel(t, cfg, tunnel.Rule)
	_, err := cfg.Proxies["Auto"].DialContext(flashguard.WithCarrier(t.Context(), "a test"), &constant.Metadata{NetWork: constant.TCP, DstIP: netip.MustParseAddr("203.0.113.9"), DstPort: 443})
	if !errors.Is(err, flashguard.ErrRefused) {
		t.Errorf("Auto under a carrier = %v, want ErrRefused", err)
	}
	wantNothingRecorded(t, recorder, "a carried dial")
}
