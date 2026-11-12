package core

import (
	"bufio"
	"encoding/binary"
	"errors"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"net/netip"
	"slices"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/metacubex/mihomo/adapter/inbound"
	"github.com/metacubex/mihomo/adapter/outboundgroup"
	"github.com/metacubex/mihomo/component/flashguard"
	"github.com/metacubex/mihomo/constant"
	cp "github.com/metacubex/mihomo/constant/provider"
	"github.com/metacubex/mihomo/hub/executor"
	LT "github.com/metacubex/mihomo/listener/tunnel"
	"github.com/metacubex/mihomo/tunnel"
	"go.yaml.in/yaml/v3"
)

// A SOCKS5 egress on loopback that records what reaches it, TCP and UDP.
// As a mounted node's egress (its dialer-proxy) it also answers as the
// node's own server, nested: a CONNECT to that server is recorded in
// servers and the stream is then read as the node's SOCKS5 session, and a
// datagram to that server is unwrapped once more. As a base proxy's egress
// it records each CONNECT target and datagram destination as is. Nothing
// read here comes from the guard: it sees only bytes that left.
type socksRecorder struct {
	addr    string
	nested  string
	relay   net.PacketConn
	mu      sync.Mutex
	servers []string
	targets []string
	packets []string
}

func newSocksRecorder(t *testing.T, nested string) *socksRecorder {
	t.Helper()
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	relay, err := net.ListenPacket("udp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		_ = listener.Close()
		_ = relay.Close()
	})
	r := &socksRecorder{addr: listener.Addr().String(), nested: nested, relay: relay}
	go func() {
		for {
			conn, err := listener.Accept()
			if err != nil {
				return
			}
			go r.serve(conn)
		}
	}()
	go r.serveUDP()
	return r
}

func (r *socksRecorder) port() string {
	_, port, _ := net.SplitHostPort(r.addr)
	return port
}

func (r *socksRecorder) record(list *[]string, value string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	*list = append(*list, value)
}

func (r *socksRecorder) seen() (servers, targets, packets []string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	return slices.Clone(r.servers), slices.Clone(r.targets), slices.Clone(r.packets)
}

func (r *socksRecorder) empty() bool {
	servers, targets, packets := r.seen()
	return len(servers)+len(targets)+len(packets) == 0
}

func readSocksAddr(reader *bufio.Reader, atyp byte) (string, error) {
	var host string
	switch atyp {
	case 1, 4:
		size := 4
		if atyp == 4 {
			size = 16
		}
		ip := make([]byte, size)
		if _, err := io.ReadFull(reader, ip); err != nil {
			return "", err
		}
		addr, _ := netip.AddrFromSlice(ip)
		host = addr.String()
	case 3:
		size, err := reader.ReadByte()
		if err != nil {
			return "", err
		}
		name := make([]byte, size)
		if _, err := io.ReadFull(reader, name); err != nil {
			return "", err
		}
		host = string(name)
	default:
		return "", errors.New("bad address type")
	}
	port := make([]byte, 2)
	if _, err := io.ReadFull(reader, port); err != nil {
		return "", err
	}
	return net.JoinHostPort(host, strconv.Itoa(int(binary.BigEndian.Uint16(port)))), nil
}

// One SOCKS5 greeting and request; the command and its address.
func acceptSocks(reader *bufio.Reader, conn net.Conn) (byte, string, error) {
	head := make([]byte, 2)
	if _, err := io.ReadFull(reader, head); err != nil || head[0] != 5 {
		return 0, "", errors.New("not SOCKS5")
	}
	if _, err := io.ReadFull(reader, make([]byte, head[1])); err != nil {
		return 0, "", err
	}
	if _, err := conn.Write([]byte{5, 0}); err != nil {
		return 0, "", err
	}
	request := make([]byte, 4)
	if _, err := io.ReadFull(reader, request); err != nil {
		return 0, "", err
	}
	target, err := readSocksAddr(reader, request[3])
	return request[1], target, err
}

func socksReply(conn net.Conn, bound netip.AddrPort) error {
	reply := []byte{5, 0, 0, 1}
	reply = append(reply, bound.Addr().AsSlice()...)
	reply = binary.BigEndian.AppendUint16(reply, bound.Port())
	_, err := conn.Write(reply)
	return err
}

func (r *socksRecorder) serve(conn net.Conn) {
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(20 * time.Second))
	reader := bufio.NewReader(conn)
	cmd, target, err := acceptSocks(reader, conn)
	if err != nil {
		return
	}
	relay := netip.MustParseAddrPort(r.relay.LocalAddr().String())
	switch {
	case cmd == 3:
		if socksReply(conn, relay) == nil {
			_, _ = io.Copy(io.Discard, reader)
		}
		return
	case cmd != 1:
		return
	case target != r.nested:
		r.record(&r.targets, target)
		if socksReply(conn, netip.AddrPortFrom(netip.IPv4Unspecified(), 0)) == nil {
			_, _ = io.Copy(conn, reader)
		}
		return
	}
	r.record(&r.servers, target)
	if socksReply(conn, netip.AddrPortFrom(netip.IPv4Unspecified(), 0)) != nil {
		return
	}
	cmd, inner, err := acceptSocks(reader, conn)
	if err != nil {
		return
	}
	switch cmd {
	case 1:
		r.record(&r.targets, inner)
		if socksReply(conn, netip.AddrPortFrom(netip.IPv4Unspecified(), 0)) == nil {
			_, _ = io.Copy(conn, reader)
		}
	case 3:
		// The node sends its datagrams to its own server address.
		port, _ := strconv.Atoi(r.nested[strings.LastIndex(r.nested, ":")+1:])
		if socksReply(conn, netip.AddrPortFrom(netip.IPv4Unspecified(), uint16(port))) == nil {
			_, _ = io.Copy(io.Discard, reader)
		}
	}
}

func parseSocksDatagram(packet []byte) (string, []byte, bool) {
	if len(packet) < 4 || packet[2] != 0 {
		return "", nil, false
	}
	reader := bufio.NewReader(strings.NewReader(string(packet[4:])))
	dest, err := readSocksAddr(reader, packet[3])
	if err != nil {
		return "", nil, false
	}
	rest, _ := io.ReadAll(reader)
	return dest, rest, true
}

func (r *socksRecorder) serveUDP() {
	buf := make([]byte, 65536)
	for {
		n, _, err := r.relay.ReadFrom(buf)
		if err != nil {
			return
		}
		dest, payload, ok := parseSocksDatagram(buf[:n])
		if !ok {
			continue
		}
		if dest == r.nested {
			inner, _, ok := parseSocksDatagram(payload)
			if !ok {
				continue
			}
			dest = r.nested + ">" + inner
		}
		r.record(&r.packets, dest)
	}
}

func waitUntil(t *testing.T, what string, done func() bool) {
	t.Helper()
	deadline := time.Now().Add(8 * time.Second)
	for time.Now().Before(deadline) {
		if done() {
			return
		}
		time.Sleep(25 * time.Millisecond)
	}
	t.Errorf("timed out waiting for %s", what)
}

// A TCP connection through a tunnel listener, as carriedTCP, given up after
// wait: a hop whose own server is unreachable never answers.
func tcpThrough(t *testing.T, target, proxy string, wait time.Duration) bool {
	t.Helper()
	listener, err := LT.New("127.0.0.1:0", target, proxy, inbound.NewListenConfig(), tunnel.Tunnel)
	if err != nil {
		t.Fatal(err)
	}
	defer listener.Close()
	conn, err := net.DialTimeout("tcp", listener.Address(), 2*time.Second)
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(wait))
	if _, err := conn.Write([]byte("ping")); err != nil {
		return false
	}
	answer := make([]byte, 4)
	_, err = io.ReadFull(conn, answer)
	return err == nil && string(answer) == "ping"
}

func sendDatagram(t *testing.T, srcPort uint16, payload, target string) {
	t.Helper()
	metadata := &constant.Metadata{NetWork: constant.UDP, Type: constant.SOCKS5, SrcIP: netip.MustParseAddr("127.0.0.1"), SrcPort: srcPort}
	if err := metadata.SetRemoteAddress(target); err != nil {
		t.Fatal(err)
	}
	source := &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1), Port: int(srcPort)}
	tunnel.Tunnel.HandleUDPPacket(&fakeUDPPacket{data: []byte(payload), local: source}, metadata)
}

func selectRunning(t *testing.T, group, name string) {
	t.Helper()
	selectable, ok := adapterAs[outboundgroup.SelectAble](tunnel.Proxies()[group])
	if !ok {
		t.Fatalf("%s cannot be selected in", group)
	}
	if err := selectable.Set(name); err != nil {
		t.Fatalf("select %s in %s: %v", name, group, err)
	}
}

func runningMembers(t *testing.T, group string) []string {
	t.Helper()
	proxyGroup, ok := adapterAs[outboundgroup.ProxyGroup](tunnel.Proxies()[group])
	if !ok {
		t.Fatalf("%s is not a running group", group)
	}
	var names []string
	for _, member := range proxyGroup.Proxies() {
		names = append(names, member.Name())
	}
	return names
}

// Applies profile with one mounted source through Flash's own apply, as
// the host does, and leaves it running.
func applyMounted(t *testing.T, home, profile, source string) {
	t.Helper()
	applyMountedOverlay(t, home, profile, "{}", source)
}

// The overlay is what Flash builds beside the base: providers and rules
// sit there, the base gives proxies and groups.
func applyMountedOverlay(t *testing.T, home, profile, overlay, source string) {
	t.Helper()
	withCurrentConfig(t, nil)
	keepTunnel(t)
	t.Cleanup(func() {
		setMountState(nil, false, false)
		installMountGate(nil, nil)
	})
	base := writeMountFile(t, home, "base.yaml", profile)
	err := applyConfig(&SetupParams{
		Base:   &SetupBase{Path: base, Overlay: overlay},
		Mounts: &MountSetup{Revision: "r", Sources: []MountSource{{ID: 1, Label: "S", Path: source}}},
	})
	if err != nil {
		t.Fatalf("applyConfig = %v", err)
	}
	if tunnel.Status() != tunnel.Running {
		t.Fatal("the applied profile is not running")
	}
}

// Applies cfg as an external controller's PUT /configs does.
func applyFromElsewhere(t *testing.T, profile string) {
	t.Helper()
	keepTunnel(t)
	t.Cleanup(func() { installMountGate(nil, nil) })
	cfg, err := executor.ParseWithBytes([]byte(profile))
	if err != nil {
		t.Fatalf("parse = %v", err)
	}
	executor.ApplyConfig(cfg, true)
}

// Every mounted node leaves through egress, a base SOCKS5 proxy at the
// mount recorder, so its server stays a TEST-NET address.
const hopMountSource = "proxies:\n  - {name: m1, type: socks5, server: 192.0.2.10, port: 1080, udp: true, dialer-proxy: egress}\n"

const hopMountServer = "192.0.2.10:1080"

// Hops that keep a session or dial in the background, each dialing
// through 节点选择: WireGuard, hysteria2 (QUIC) and Shadowsocks with smux.
// Their servers are TEST-NET addresses only the recorders ever see.
const hopProfile = `proxies:
  - {name: egress, type: socks5, server: 127.0.0.1, port: MOUNT, udp: true}
  - {name: base1, type: socks5, server: 127.0.0.1, port: BASE, udp: true}
  - {name: wg-home, type: wireguard, server: 192.0.2.60, port: 51820, ip: 10.9.0.2, udp: true, private-key: zC6Kbw8IgU2If+FmAXfCxeTVpa4Ue9i6nLgEJq8Mtrs=, public-key: x7sR/MNsxJyOT0M84m1UYlOgFTPnUfdA9afSqzFJAFA=, dialer-proxy: 节点选择}
  - {name: hy-home, type: hysteria2, server: 192.0.2.61, port: 443, password: synthetic, sni: hop.example, dialer-proxy: 节点选择}
  - {name: mux-home, type: ss, server: 192.0.2.62, port: 8388, cipher: aes-128-gcm, password: synthetic, smux: {enabled: true, protocol: smux}, dialer-proxy: 节点选择}
proxy-groups:
  - SELECT
  - {name: Auto, type: select, include-all-providers: true}
rules:
  - MATCH,Auto
`

func hopConfig(profile string, mount, base *socksRecorder, selectGroup string) string {
	return strings.NewReplacer("MOUNT", mount.port(), "BASE", base.port(), "SELECT", selectGroup).Replace(profile)
}

// The hop endpoints each hop opens its session to, as a recorder lists them.
var hopEndpoints = map[string]string{
	"wg-home":  "192.0.2.60:51820",
	"hy-home":  "192.0.2.61:443",
	"mux-home": "192.0.2.62:8388",
}

func sawEndpoint(r *socksRecorder, endpoint string) bool {
	_, targets, packets := r.seen()
	return slices.Contains(targets, endpoint) || slices.ContainsFunc(packets, func(packet string) bool {
		return packet == endpoint || strings.HasSuffix(packet, ">"+endpoint)
	})
}

// H-A. A proxy dialing through a group keeps its session there: once open,
// a later tailnet connection rides it and no mounted node is asked. Flash
// keeps every group any proxy dials through free of mounts, so through the
// real apply, in Global mode, each hop opens its session on the base proxy
// and neither its first, ordinary, connection nor a later tailnet one
// reaches the mounted node's egress.
func TestHopSessionsNeverRideAMountedNode(t *testing.T) {
	home := withMountHome(t)
	mount := newSocksRecorder(t, hopMountServer)
	base := newSocksRecorder(t, "")
	source := writeMountFile(t, home, "1.yaml", hopMountSource)
	profile := hopConfig(hopProfile, mount, base, "{name: 节点选择, type: select, proxies: [base1], include-all-providers: true}")

	reasons := groupReasons(t, rootOf(t, profile))
	if reasons["节点选择"] != "excluded/dialer" || reasons["Auto"] != "auto/" {
		t.Fatalf("reasons = %v, want 节点选择 excluded for its dialers and Auto taking mounts", reasons)
	}
	applyMounted(t, home, profile, source)
	if got := runningMembers(t, "节点选择"); !slices.Equal(got, []string{"base1"}) {
		t.Fatalf("节点选择 = %v, want base1 alone", got)
	}
	if got := runningMembers(t, "Auto"); !slices.Equal(got, []string{"m1"}) {
		t.Fatalf("Auto = %v, want the mounted m1", got)
	}

	tunnel.SetMode(tunnel.Global)
	for _, hop := range []string{"mux-home", "wg-home", "hy-home"} {
		selectRunning(t, globalProxyName, hop)
		_ = tcpThrough(t, guardOrdinary, "", 2*time.Second)
		waitUntil(t, hop+"'s session on base1", func() bool { return sawEndpoint(base, hopEndpoints[hop]) })
		_ = tcpThrough(t, "100.100.1.1:22", "", 2*time.Second)
		_ = tcpThrough(t, "nas.tail1.ts.net:22", "", time.Second)
	}
	time.Sleep(300 * time.Millisecond)
	if servers, targets, packets := mount.seen(); len(servers)+len(targets)+len(packets) > 0 {
		t.Errorf("the mounted node's egress saw servers %v, targets %v, packets %v", servers, targets, packets)
	}

	// Positive control: an ordinary connection through Auto leaves through
	// the mounted node, nested in its own server's session.
	tunnel.SetMode(tunnel.Rule)
	if !tcpThrough(t, guardOrdinary, "", 5*time.Second) {
		t.Error("Auto did not carry an ordinary destination")
	}
	if servers, targets, _ := mount.seen(); !slices.Equal(servers, []string{hopMountServer}) || !slices.Equal(targets, []string{guardOrdinary}) {
		t.Errorf("mount egress saw servers %v, targets %v; want m1 carrying %s", servers, targets, guardOrdinary)
	}
}

// The same hops with a mounted node where they dial, built by hand past
// every exclusion: each hop's session reaches the mounted node marked as a
// hop session, which it refuses, so the recorder sees none of them. The
// check before running finds the chain too, and the config applied from
// elsewhere is held.
func TestHopSessionsOnAMountedNodeAreRefusedAndFoundBeforeRunning(t *testing.T) {
	home := withMountHome(t)
	mount := newSocksRecorder(t, hopMountServer)
	base := newSocksRecorder(t, "")
	writeMountFile(t, home, "mount-1.yaml", hopMountSource)
	profile := hopConfig(hopProfile, mount, base, "{name: 节点选择, type: select, use: [flash-mount-1]}") +
		"proxy-providers:\n  flash-mount-1: {type: file, path: mount-1.yaml}\n"
	profile = strings.Replace(profile, "{name: Auto, type: select, include-all-providers: true}", "{name: Auto, type: select, proxies: [base1]}", 1)
	cfg := checkOnlyConfig(t, &yaml.Node{Kind: yaml.DocumentNode, Content: []*yaml.Node{rootOf(t, profile)}})
	refused := recordRefusals(t)
	runInTunnel(t, cfg, tunnel.Global)
	for _, hop := range []string{"mux-home", "wg-home", "hy-home"} {
		selectIn(t, cfg, globalProxyName, hop)
		_ = tcpThrough(t, guardOrdinary, "", 2*time.Second)
		_ = tcpThrough(t, "100.100.1.1:22", "", time.Second)
		waitUntil(t, hop+"'s session refused by m1", func() bool {
			return slices.ContainsFunc(refused.waitFor(t, 0), func(r string) bool {
				return r == "m1: it would carry the session of a proxy dialing through 节点选择"
			})
		})
		refused.mu.Lock()
		refused.list = nil
		refused.mu.Unlock()
	}
	time.Sleep(300 * time.Millisecond)
	if servers, targets, packets := mount.seen(); len(servers)+len(targets)+len(packets) > 0 {
		t.Errorf("the mounted node's egress saw servers %v, targets %v, packets %v", servers, targets, packets)
	}
	err := mountDialerViolation(cfg.Proxies, cfg.Providers)
	if err == nil || !strings.Contains(err.Error(), "m1") {
		t.Fatalf("the check before running = %v, want the hop through m1 found", err)
	}

	// Applied as an external controller would, the config is held: the
	// tunnel never runs, so nothing at all is carried.
	applyFromElsewhere(t, profile)
	if tunnel.Status() == tunnel.Running {
		t.Fatal("a config whose hop dials through a mounted node runs")
	}
	if tcpThrough(t, "100.100.1.1:22", "mux-home", time.Second) {
		t.Error("the held config carried a connection")
	}
	if !mount.empty() {
		t.Error("the held config reached the mount egress")
	}
}

// Applied from elsewhere while the mount provider still loads, it is held all the same.
func TestAHopThroughAMountStillLoadingIsHeld(t *testing.T) {
	withMountHome(t)
	mount := newSocksRecorder(t, hopMountServer)
	base := newSocksRecorder(t, "")
	requested, release := make(chan struct{}, 1), make(chan struct{})
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		select {
		case requested <- struct{}{}:
		default:
		}
		select {
		case <-release:
		case <-r.Context().Done():
			return
		}
		_, _ = io.WriteString(w, hopMountSource)
	}))
	t.Cleanup(server.Close)
	var once sync.Once
	t.Cleanup(func() { once.Do(func() { close(release) }) })
	profile := hopConfig(hopProfile, mount, base, "{name: 节点选择, type: select, use: [flash-mount-1]}") +
		"proxy-providers:\n  flash-mount-1: {type: http, url: '" + server.URL + "/m.yaml', proxy: DIRECT, interval: 0}\n"
	profile = strings.Replace(profile, "{name: Auto, type: select, include-all-providers: true}", "{name: Auto, type: select, proxies: [base1]}", 1)

	applyFromElsewhere(t, profile)
	running := tunnel.Status() == tunnel.Running
	select {
	case <-requested:
	case <-time.After(5 * time.Second):
		t.Fatal("the mount provider was never fetched")
	}
	if running {
		t.Error("a config whose hop dials through a mount still loading runs")
	}
	once.Do(func() { close(release) })
	waitUntil(t, "m1 loaded", func() bool { return slices.Contains(runningMembers(t, "节点选择"), "m1") })
	for _, hop := range []string{"mux-home", "wg-home", "hy-home"} {
		for _, target := range []string{guardOrdinary, "100.100.1.1:22"} {
			if tcpThrough(t, target, hop, time.Second) {
				t.Errorf("%s carried a connection to %s", hop, target)
			}
		}
	}
	time.Sleep(300 * time.Millisecond)
	if servers, targets, packets := mount.seen(); len(servers)+len(targets)+len(packets) > 0 {
		t.Errorf("the mounted node's egress saw servers %v, targets %v, packets %v", servers, targets, packets)
	}
}

// A proxy of a replaced config looks its dialer-proxy up by name in the
// config running now. Should that group hold a mounted node, the old
// proxy's session is refused there: it never rides the new mount.
func TestAReplacedConfigsHopNeverDialsThroughTheNewMounts(t *testing.T) {
	home := withMountHome(t)
	mount := newSocksRecorder(t, hopMountServer)
	base := newSocksRecorder(t, "")
	source := writeMountFile(t, home, "1.yaml", hopMountSource)
	old := checkOnlyConfig(t, &yaml.Node{Kind: yaml.DocumentNode, Content: []*yaml.Node{rootOf(t, strings.Replace(`proxies:
  - {name: base1, type: socks5, server: 127.0.0.1, port: BASE, udp: true}
  - {name: home, type: socks5, server: 192.0.2.70, port: 1080, udp: true, dialer-proxy: G}
proxy-groups:
  - {name: G, type: select, proxies: [base1]}
rules:
  - MATCH,home
`, "BASE", base.port(), 1))}})
	hop := old.Proxies["home"]

	// The new config's G is no dialer group, so it takes the mount.
	profile := strings.NewReplacer("MOUNT", mount.port(), "BASE", base.port()).Replace(`proxies:
  - {name: egress, type: socks5, server: 127.0.0.1, port: MOUNT, udp: true}
  - {name: base1, type: socks5, server: 127.0.0.1, port: BASE, udp: true}
proxy-groups:
  - {name: G, type: select, proxies: [base1], include-all-providers: true}
rules:
  - MATCH,G
`)
	applyMounted(t, home, profile, source)
	selectRunning(t, "G", "m1")
	refused := recordRefusals(t)
	ordinary := &constant.Metadata{NetWork: constant.TCP, DstIP: netip.MustParseAddr("203.0.113.9"), DstPort: 443}
	if conn, err := hop.DialContext(t.Context(), ordinary); !errors.Is(err, flashguard.ErrRefused) {
		if conn != nil {
			_ = conn.Close()
		}
		t.Errorf("the old hop's TCP dial = %v, want ErrRefused", err)
	}
	udp := &constant.Metadata{NetWork: constant.UDP, DstIP: netip.MustParseAddr("100.100.1.1"), DstPort: 41641}
	if pc, err := hop.ListenPacketContext(t.Context(), udp); !errors.Is(err, flashguard.ErrRefused) {
		if pc != nil {
			_ = pc.Close()
		}
		t.Errorf("the old hop's UDP session = %v, want ErrRefused", err)
	}
	if got := refused.waitFor(t, 2); len(got) != 2 {
		t.Errorf("refusals = %v, want both sessions", got)
	}
	time.Sleep(200 * time.Millisecond)
	if !mount.empty() {
		servers, targets, packets := mount.seen()
		t.Errorf("the old hop rode the new mount: %v %v %v", servers, targets, packets)
	}
}

// H-B. The tunnel keys a UDP mapping by source alone: a second datagram from
// one source reuses the connection the first opened, here a Shadowsocks
// hop's. Through the real apply its dialer group takes no mounts, so the
// ordinary datagram and the tailnet one after it both leave by base1 and
// neither reaches the mounted node's egress.
func TestReusedUDPThroughAHopNeverReachesAMountedNode(t *testing.T) {
	home := withMountHome(t)
	mount := newSocksRecorder(t, hopMountServer)
	base := newSocksRecorder(t, "")
	source := writeMountFile(t, home, "1.yaml", hopMountSource)
	const udpProfile = `proxies:
  - {name: egress, type: socks5, server: 127.0.0.1, port: MOUNT, udp: true}
  - {name: base1, type: socks5, server: 127.0.0.1, port: BASE, udp: true}
  - {name: home, type: ss, server: 192.0.2.70, port: 8388, cipher: aes-128-gcm, password: synthetic, udp: true, dialer-proxy: 节点选择}
proxy-groups:
  - SELECT
  - {name: Auto, type: select, include-all-providers: true}
rules:
  - DST-PORT,5353,Auto
  - MATCH,home
`
	profile := hopConfig(udpProfile, mount, base, "{name: 节点选择, type: select, proxies: [base1], include-all-providers: true}")
	applyMounted(t, home, profile, source)

	// home's packets alone: a hop of an earlier test may still send.
	homePackets := func() int {
		_, _, packets := base.seen()
		return len(slices.DeleteFunc(slices.Clone(packets), func(p string) bool { return p != "192.0.2.70:8388" }))
	}
	sendDatagram(t, 40101, "first", "203.0.113.53:53")
	waitUntil(t, "the first datagram on base1", func() bool { return homePackets() >= 1 })
	sendDatagram(t, 40101, "second", "100.100.1.1:41641")
	waitUntil(t, "the reused connection's second datagram", func() bool { return homePackets() >= 2 })
	if got := homePackets(); got != 2 {
		t.Errorf("base1 saw %d of home's datagrams, want both inside home's session", got)
	}
	time.Sleep(300 * time.Millisecond)
	if !mount.empty() {
		servers, targets, packets := mount.seen()
		t.Errorf("the mounted node's egress saw servers %v, targets %v, packets %v", servers, targets, packets)
	}

	// Positive control: an ordinary datagram through Auto leaves through m1.
	sendDatagram(t, 40102, "third", "203.0.113.53:5353")
	waitUntil(t, "an ordinary datagram through m1", func() bool {
		_, _, packets := mount.seen()
		return slices.Equal(packets, []string{hopMountServer + ">203.0.113.53:5353"})
	})
}

// The same reuse with the hop dialing through a mounted node, built by hand
// past every exclusion: home's session is refused by the mounted node, as a
// hop session, so neither datagram reaches its egress. The check before
// running finds the chain too.
func TestReusedUDPThroughAHopOnAMountedNodeIsRefusedAndFoundBeforeRunning(t *testing.T) {
	home := withMountHome(t)
	mount := newSocksRecorder(t, hopMountServer)
	base := newSocksRecorder(t, "")
	writeMountFile(t, home, "mount-1.yaml", hopMountSource)
	profile := strings.NewReplacer("MOUNT", mount.port(), "BASE", base.port()).Replace(`proxies:
  - {name: egress, type: socks5, server: 127.0.0.1, port: MOUNT, udp: true}
  - {name: home, type: ss, server: 192.0.2.70, port: 8388, cipher: aes-128-gcm, password: synthetic, udp: true, dialer-proxy: 节点选择}
proxy-providers:
  flash-mount-1: {type: file, path: mount-1.yaml}
proxy-groups:
  - {name: 节点选择, type: select, use: [flash-mount-1]}
rules:
  - MATCH,home
`)
	cfg := checkOnlyConfig(t, &yaml.Node{Kind: yaml.DocumentNode, Content: []*yaml.Node{rootOf(t, profile)}})
	refused := recordRefusals(t)
	runInTunnel(t, cfg, tunnel.Rule)
	sendDatagram(t, 40201, "first", "203.0.113.53:53")
	sendDatagram(t, 40201, "second", "100.100.1.1:41641")
	got := refused.waitFor(t, 1)
	if !slices.Contains(got, "m1: it would carry the session of a proxy dialing through 节点选择") {
		t.Errorf("refusals = %v, want home's session refused by m1", got)
	}
	time.Sleep(500 * time.Millisecond)
	if !mount.empty() {
		servers, targets, packets := mount.seen()
		t.Errorf("the mounted node's egress saw servers %v, targets %v, packets %v", servers, targets, packets)
	}
	if err := mountDialerViolation(cfg.Proxies, cfg.Providers); err == nil || !strings.Contains(err.Error(), "home dials through 节点选择") {
		t.Errorf("the check before running = %v, want home through 节点选择 found", err)
	}
}

// A base provider update that adds a dialer-proxy into a group holding
// mounts, or a Tailscale node chained there, is refused and the provider
// keeps what was checked; a dialer clear of mounts is taken. Taken past
// the gate, the added node's session is seen on the mounted node's egress.
func TestProviderUpdateAddingADialerThroughAMountIsRefused(t *testing.T) {
	home := withMountHome(t)
	mount := newSocksRecorder(t, hopMountServer)
	base := newSocksRecorder(t, "")
	source := writeMountFile(t, home, "1.yaml", hopMountSource)
	writeMountFile(t, home, "sub.yaml", "proxies:\n  - {name: a, type: socks5, server: 192.0.2.80, port: 1080, dialer-proxy: base1}\n")
	profile := strings.NewReplacer("MOUNT", mount.port(), "BASE", base.port()).Replace(`proxies:
  - {name: egress, type: socks5, server: 127.0.0.1, port: MOUNT, udp: true}
  - {name: base1, type: socks5, server: 127.0.0.1, port: BASE, udp: true}
proxy-groups:
  - {name: Free, type: select, use: [sub]}
  - {name: Later, type: select, use: [late]}
  - {name: Auto, type: select, include-all-proxies: true, exclude-filter: "^egress$"}
rules:
  - MATCH,Auto
`)
	const overlay = "proxy-providers:\n  sub: {type: file, path: sub.yaml}\n  late: {type: file, path: late.yaml}\n"
	applyMountedOverlay(t, home, profile, overlay, source)
	if got := runningMembers(t, "Auto"); !slices.Contains(got, "m1") {
		t.Fatalf("Auto = %v, want m1 mounted", got)
	}
	sub := tunnel.Providers()["sub"].(sideUpdater)
	late := tunnel.Providers()["late"].(sideUpdater)
	chained := []byte("proxies:\n  - {name: x, type: socks5, server: 192.0.2.81, port: 1080, Dialer_Proxy: Auto}\n")
	for name, update := range map[string][]byte{
		"a node dialing through Auto":   chained,
		"a node dialing through GLOBAL": []byte("proxies:\n  - {name: x, type: socks5, server: 192.0.2.81, port: 1080, dialer-proxy: GLOBAL}\n"),
		"a node naming no proxy":        []byte("proxies:\n  - {name: x, type: socks5, server: 192.0.2.81, port: 1080, dialer-proxy: m1}\n"),
		"a Tailscale node through Auto": []byte("proxies:\n  - {name: t, type: tailscale, dialer-proxy: Auto}\n"),
	} {
		if _, _, err := sub.SideUpdate(update); err == nil {
			t.Errorf("sub took %s", name)
		}
	}
	if _, _, err := late.SideUpdate(chained); err == nil {
		t.Error("an unread provider took a node dialing through Auto")
	}
	if got := runningMembers(t, "Free"); !slices.Equal(got, []string{"a", "m1"}) {
		t.Errorf("Free = %v, want what was checked", got)
	}
	if refusedNow := handleMountState().Refused; !slices.Equal(refusedNow, []string{"late", "sub"}) {
		t.Errorf("refused = %v, want [late sub]", refusedNow)
	}
	if _, _, err := sub.SideUpdate([]byte("proxies:\n  - {name: a, type: socks5, server: 192.0.2.80, port: 1080, dialer-proxy: base1}\n  - {name: y, type: socks5, server: 192.0.2.82, port: 1080, dialer-proxy: base1}\n")); err != nil {
		t.Errorf("an update dialing clear of mounts = %v, want it taken", err)
	}
	if !mount.empty() {
		t.Errorf("the refused updates reached the mount egress")
	}

	// Without the gate the chained node is taken, and its session reaches
	// m1, which refuses it as a hop session: the runtime layer under the
	// gate, and nothing reaches the egress.
	installMountGate(nil, nil)
	if _, _, err := sub.SideUpdate(chained); err != nil {
		t.Fatal(err)
	}
	refused := recordRefusals(t)
	selectRunning(t, "Auto", "m1")
	selectRunning(t, "Free", "x")
	_ = tcpThrough(t, guardOrdinary, "Free", 2*time.Second)
	if got := refused.waitFor(t, 1); !slices.Contains(got, "m1: it would carry the session of a proxy dialing through Auto") {
		t.Errorf("refusals = %v, want x's session refused by m1", got)
	}
	if !mount.empty() {
		t.Error("x's session reached the mount egress")
	}
}

// L-b. A config applied from elsewhere replaces the last Flash apply's
// gate: one without mounts is not gated by stale allowances, one with
// mounts is gated closed and checked before it runs.
func TestConfigFromElsewhereReplacesTheMountGate(t *testing.T) {
	home := withMountHome(t)
	mount := newSocksRecorder(t, hopMountServer)
	writeMountFile(t, home, "mount-1.yaml", hopMountSource)
	writeMountFile(t, home, "sub.yaml", "proxies:\n  - {name: a, type: socks5, server: 192.0.2.80, port: 1080}\n")
	writeMountFile(t, home, "lan.txt", "10.0.0.0/8\n")
	source := writeMountFile(t, home, "1.yaml", hopMountSource)
	profile := strings.Replace(`proxies:
  - {name: egress, type: socks5, server: 127.0.0.1, port: MOUNT, udp: true}
proxy-groups:
  - {name: Auto, type: select, include-all-providers: true}
rules:
  - MATCH,Auto
`, "MOUNT", mount.port(), 1)
	applyMountedOverlay(t, home, profile, "proxy-providers:\n  sub: {type: file, path: sub.yaml}\n", source)
	mountGateMu.Lock()
	flashGate := activeMountGate
	mountGateMu.Unlock()
	if flashGate == nil || flashGate.external {
		t.Fatal("Flash's apply installed no gate of its own")
	}

	// Without mounts: nothing is gated, by stale allowances or otherwise.
	applyFromElsewhere(t, strings.Replace(profile, "include-all-providers: true", "use: [sub]", 1)+"proxy-providers:\n  sub: {type: file, path: sub.yaml}\n")
	mountGateMu.Lock()
	gate := activeMountGate
	mountGateMu.Unlock()
	if gate != nil {
		t.Fatal("a config from elsewhere without mounts kept the last apply's gate")
	}
	if tunnel.Status() != tunnel.Running {
		t.Fatal("a config from elsewhere without mounts was held")
	}

	// With mounts, as Flash wrote them: gated closed and checked first.
	external := strings.Replace(`proxies:
  - {name: egress, type: socks5, server: 127.0.0.1, port: MOUNT, udp: true}
proxy-providers:
  sub: {type: file, path: sub.yaml}
  flash-mount-1: {type: file, path: mount-1.yaml}
rule-providers:
  lan: {type: file, behavior: ipcidr, format: text, path: lan.txt}
proxy-groups:
  - {name: Auto, type: select, use: [flash-mount-1, sub]}
rules:
  - RULE-SET,lan,DIRECT
  - MATCH,Auto
`, "MOUNT", mount.port(), 1)
	applyFromElsewhere(t, external)
	mountGateMu.Lock()
	gate = activeMountGate
	mountGateMu.Unlock()
	if gate == nil || !gate.external {
		t.Fatal("a config from elsewhere with mounts is not gated closed")
	}
	if tunnel.Status() != tunnel.Running {
		t.Fatal("a config from elsewhere whose groups keep mounts off every hop was held")
	}
	sub := tunnel.Providers()["sub"].(sideUpdater)
	if _, _, err := sub.SideUpdate([]byte("proxies:\n  - {name: t, type: tailscale}\n")); err == nil {
		t.Error("the closed gate took a Tailscale node")
	}
	if _, _, err := sub.SideUpdate([]byte("proxies:\n  - {name: b, type: socks5, server: 192.0.2.83, port: 1080, dialer-proxy: base}\n")); err == nil {
		t.Error("the closed gate took a dialer-proxy")
	}
	if err := gateMountRuleSet("lan", nil, []byte("100.64.0.0/10\n"), cp.IPCIDR, cp.TextRule); err == nil {
		t.Error("the closed gate took a rule set sending Tailscale addresses")
	}
	if err := gateMountRuleSet("lan", nil, []byte("192.168.0.0/16\n"), cp.IPCIDR, cp.TextRule); err != nil {
		t.Errorf("the closed gate refused an ordinary rule set: %v", err)
	}
	// Positive control: the external config carries an ordinary connection
	// through m1 and the runtime guard refuses a tailnet one.
	selectRunning(t, "Auto", "m1")
	if !tcpThrough(t, guardOrdinary, "", 5*time.Second) {
		t.Error("the external config did not carry an ordinary destination through m1")
	}
	if tcpThrough(t, "100.100.1.1:22", "", 2*time.Second) {
		t.Error("the external config carried a Tailscale address")
	}
	if _, targets, _ := mount.seen(); !slices.Equal(targets, []string{guardOrdinary}) {
		t.Errorf("mount egress saw %v, want only the ordinary destination", targets)
	}
}

// L-e. A refusal under a hop reaches the tunnel as ErrRefused, however the
// hop wraps it, so the tunnel never retries it or tries another node.
func TestRefusalSurvivesEveryHopsWrapping(t *testing.T) {
	home := withMountHome(t)
	mount := newSocksRecorder(t, hopMountServer)
	writeMountFile(t, home, "mount-1.yaml", hopMountSource)
	profile := strings.Replace(`proxies:
  - {name: egress, type: socks5, server: 127.0.0.1, port: MOUNT, udp: true}
  - {name: ss-hop, type: ss, server: 192.0.2.90, port: 8388, cipher: aes-128-gcm, password: synthetic, udp: true, dialer-proxy: Auto}
  - {name: mux-hop, type: ss, server: 192.0.2.90, port: 8389, cipher: aes-128-gcm, password: synthetic, smux: {enabled: true}, dialer-proxy: Auto}
  - {name: socks-hop, type: socks5, server: 192.0.2.90, port: 1080, udp: true, dialer-proxy: Auto}
  - {name: http-hop, type: http, server: 192.0.2.90, port: 8080, dialer-proxy: Auto}
  - {name: trojan-hop, type: trojan, server: 192.0.2.90, port: 443, password: synthetic, sni: hop.example, udp: true, dialer-proxy: Auto}
  - {name: vless-hop, type: vless, server: 192.0.2.90, port: 443, uuid: 4d1e2f6a-0f5c-4b3e-9f7a-2c1d0e9b8a71, udp: true, dialer-proxy: Auto}
  - {name: vmess-hop, type: vmess, server: 192.0.2.90, port: 443, uuid: 4d1e2f6a-0f5c-4b3e-9f7a-2c1d0e9b8a71, alterId: 0, cipher: auto, udp: true, dialer-proxy: Auto}
  - {name: chain, type: socks5, server: 192.0.2.91, port: 1080, udp: true, dialer-proxy: ss-hop}
proxy-providers:
  flash-mount-1: {type: file, path: mount-1.yaml}
proxy-groups:
  - {name: Auto, type: select, use: [flash-mount-1]}
rules:
  - MATCH,Auto
`, "MOUNT", mount.port(), 1)
	cfg := checkOnlyConfig(t, &yaml.Node{Kind: yaml.DocumentNode, Content: []*yaml.Node{rootOf(t, profile)}})
	runInTunnel(t, cfg, tunnel.Rule)
	recordRefusals(t)
	ordinary := &constant.Metadata{NetWork: constant.TCP, DstIP: netip.MustParseAddr("203.0.113.9"), DstPort: 443}
	for _, hop := range []string{"ss-hop", "mux-hop", "socks-hop", "http-hop", "trojan-hop", "vless-hop", "vmess-hop", "chain"} {
		ctx := flashguard.WithCarrier(t.Context(), "a test")
		conn, err := cfg.Proxies[hop].DialContext(ctx, ordinary)
		if conn != nil {
			_ = conn.Close()
		}
		if !errors.Is(err, flashguard.ErrRefused) {
			t.Errorf("%s TCP = %v, want ErrRefused", hop, err)
		}
		if !cfg.Proxies[hop].SupportUDP() {
			continue
		}
		udp := &constant.Metadata{NetWork: constant.UDP, DstIP: netip.MustParseAddr("203.0.113.9"), DstPort: 53}
		pc, err := cfg.Proxies[hop].ListenPacketContext(ctx, udp)
		if pc != nil {
			_ = pc.Close()
		}
		if !errors.Is(err, flashguard.ErrRefused) {
			t.Errorf("%s UDP = %v, want ErrRefused", hop, err)
		}
	}
	if !mount.empty() {
		servers, targets, packets := mount.seen()
		t.Errorf("a refused dial reached the egress: %v %v %v", servers, targets, packets)
	}
}
