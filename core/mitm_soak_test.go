package core

// A loopback soak of the tunnel with the Flash hook installed: a local mixed
// inbound, DIRECT, and echo servers on 127.0.0.1. No TUN, no system proxy,
// no network beyond loopback, no Flash process. Opt in:
//
//	FLASH_MITM_SOAK=1 [FLASH_MITM_SOAK_CONNS=2000] go test -run TestMitmLoopbackSoak -v .

import (
	"bufio"
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"errors"
	"fmt"
	"io"
	"math/big"
	"net"
	"os"
	"os/exec"
	"runtime"
	"slices"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/metacubex/mihomo/adapter"
	mihomoInbound "github.com/metacubex/mihomo/adapter/inbound"
	"github.com/metacubex/mihomo/adapter/outbound"
	N "github.com/metacubex/mihomo/common/net"
	"github.com/metacubex/mihomo/component/resolver"
	"github.com/metacubex/mihomo/component/trie"
	C "github.com/metacubex/mihomo/constant"
	authStore "github.com/metacubex/mihomo/listener/auth"
	LC "github.com/metacubex/mihomo/listener/config"
	"github.com/metacubex/mihomo/listener/mixed"
	"github.com/metacubex/mihomo/listener/socks"
	"github.com/metacubex/mihomo/transport/socks5"
	"github.com/metacubex/mihomo/tunnel"
	"github.com/metacubex/mihomo/tunnel/statistic"
)

type soakKind string

const (
	soakIPEcho     soakKind = "ip-echo"     // nameless, client speaks first
	soakIPGreet    soakKind = "ip-greet"    // nameless, server speaks first
	soakNamedEcho  soakKind = "named-echo"  // unlisted name, client first
	soakNamedGreet soakKind = "named-greet" // unlisted name, server first
	soakIPTLS      soakKind = "ip-tls"      // nameless TLS, unlisted SNI
	soakNamedTLS   soakKind = "named-tls"   // unlisted name, TLS
	soakListedTLS  soakKind = "listed-tls"  // the listed host, TLS
	soakIPUDP      soakKind = "ip-udp"      // nameless UDP to the HTTPS port
	soakNamedUDP   soakKind = "named-udp"   // unlisted name, UDP to the HTTPS port
	soakListedUDP  soakKind = "listed-udp"  // the listed host, UDP to the HTTPS port (QUIC)
)

var soakUnlisted = []soakKind{soakIPEcho, soakIPGreet, soakNamedEcho, soakNamedGreet, soakIPTLS, soakNamedTLS, soakIPUDP, soakNamedUDP}

type soakRig struct {
	mixed, socksUDP      string
	echo, greet, tlsPort int
	roots                *x509.CertPool
	app                  *fakeMitmApp
	listed               []string
	stopServers          func()
	udpSelfEcho          *atomic.Int64
}

type soakResult struct {
	kind    soakKind
	elapsed time.Duration
	err     error
}

type soakStats struct {
	n, failures, timeouts, held int
	p50, p95, p99, max          time.Duration
	firstErr, firstOtherErr     error
}

func soakSummarize(results []soakResult) map[soakKind]*soakStats {
	byKind := map[soakKind][]time.Duration{}
	stats := map[soakKind]*soakStats{}
	for _, r := range results {
		s := stats[r.kind]
		if s == nil {
			s = &soakStats{}
			stats[r.kind] = s
		}
		s.n++
		if r.err != nil {
			s.failures++
			if soakReadTimeout(r.err) {
				s.timeouts++
			} else if s.firstOtherErr == nil {
				s.firstOtherErr = r.err
			}
			if s.firstErr == nil {
				s.firstErr = r.err
			}
			continue
		}
		if r.elapsed > soakHeldOver {
			s.held++
		}
		byKind[r.kind] = append(byKind[r.kind], r.elapsed)
	}
	for kind, d := range byKind {
		slices.Sort(d)
		at := func(q float64) time.Duration { return d[min(len(d)-1, int(q*float64(len(d))))] }
		s := stats[kind]
		s.p50, s.p95, s.p99, s.max = at(0.50), at(0.95), at(0.99), d[len(d)-1]
	}
	return stats
}

func soakReadTimeout(err error) bool {
	var opErr *net.OpError
	return errors.As(err, &opErr) && opErr.Op == "read" && opErr.Timeout()
}

// A connection slower than this was held, not merely scheduled late.
const soakHeldOver = 150 * time.Millisecond

func soakEnvInt(name string, fallback int) int {
	if v, err := strconv.Atoi(os.Getenv(name)); err == nil && v > 0 {
		return v
	}
	return fallback
}

func soakServerIdentity(t *testing.T) (tls.Certificate, *x509.CertPool) {
	t.Helper()
	rootKey, _ := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	now := time.Now()
	rootTemplate := &x509.Certificate{SerialNumber: big.NewInt(1), Subject: pkix.Name{CommonName: "soak root"}, NotBefore: now.Add(-time.Hour), NotAfter: now.Add(time.Hour), IsCA: true, BasicConstraintsValid: true, KeyUsage: x509.KeyUsageCertSign}
	rootDER, err := x509.CreateCertificate(rand.Reader, rootTemplate, rootTemplate, &rootKey.PublicKey, rootKey)
	if err != nil {
		t.Fatal(err)
	}
	root, _ := x509.ParseCertificate(rootDER)
	leafKey, _ := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	template := &x509.Certificate{SerialNumber: big.NewInt(2), DNSNames: []string{"listed.test", "other.test"}, NotBefore: now.Add(-time.Hour), NotAfter: now.Add(time.Hour), KeyUsage: x509.KeyUsageDigitalSignature, ExtKeyUsage: []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth}}
	der, err := x509.CreateCertificate(rand.Reader, template, root, &leafKey.PublicKey, rootKey)
	if err != nil {
		t.Fatal(err)
	}
	pool := x509.NewCertPool()
	pool.AddCert(root)
	return tls.Certificate{Certificate: [][]byte{der}, PrivateKey: leafKey}, pool
}

func soakServe(t *testing.T, listener net.Listener, handle func(net.Conn)) {
	go func() {
		for {
			conn, err := listener.Accept()
			if err != nil {
				return
			}
			go func() {
				soakNoTimeWait(conn)
				defer conn.Close()
				_ = conn.SetDeadline(time.Now().Add(15 * time.Second))
				handle(conn)
			}()
		}
	}()
}

// Thousands of loopback connections a minute would otherwise exhaust the
// ephemeral ports in TIME_WAIT; closing with a reset leaves none.
func soakNoTimeWait(conn net.Conn) {
	if tlsConn, ok := conn.(*tls.Conn); ok {
		conn = tlsConn.NetConn()
	}
	if tcp, ok := conn.(*net.TCPConn); ok {
		_ = tcp.SetLinger(0)
	}
}

func soakLineEcho(conn net.Conn) {
	reader := bufio.NewReader(conn)
	for {
		line, err := reader.ReadString('\n')
		if err != nil {
			return
		}
		if _, err := io.WriteString(conn, line); err != nil {
			return
		}
	}
}

// Bind the IPv4 echo outside Darwin's current automatic port ranges. The
// DIRECT socket is wildcard-bound and Darwin permits it to overlap a specific
// loopback bind, so an ephemeral echo port can make the echo talk to itself.
// Read sysctls only; never change them. TCP and UDP are reserved together.
func soakListenIsolatedEcho(t *testing.T) (net.Listener, net.PacketConn) {
	t.Helper()
	if runtime.GOOS != "darwin" {
		// Preserve portability; the self-echo guard still fails closed, but
		// outside Darwin this fallback cannot guarantee port isolation.
		t.Log("UDP echo port isolation unavailable on this platform")
		for range 100 {
			tcp, err := net.Listen("tcp4", "127.0.0.1:0")
			if err != nil {
				t.Fatal(err)
			}
			udp, err := net.ListenPacket("udp4", tcp.Addr().String())
			if err == nil {
				return tcp, udp
			}
			_ = tcp.Close()
		}
		t.Fatal("could not reserve loopback TCP and UDP echo port")
	}
	names := []string{"net.inet.ip.portrange.first", "net.inet.ip.portrange.last", "net.inet.ip.portrange.hifirst", "net.inet.ip.portrange.hilast", "net.inet.ip.portrange.lowfirst", "net.inet.ip.portrange.lowlast"}
	readRanges := func() [6]int {
		var values [6]int
		for i, name := range names {
			out, err := exec.Command("/usr/sbin/sysctl", "-n", name).Output()
			if err != nil {
				t.Fatalf("read %s: %v", name, err)
			}
			n, err := strconv.Atoi(strings.TrimSpace(string(out)))
			if err != nil || n < 1 || n > 65535 {
				t.Fatalf("invalid %s: %q", name, out)
			}
			values[i] = n
		}
		return values
	}
	ranges := readRanges()
	t.Logf("UDP echo reserved outside Darwin port ranges: default=%d-%d high=%d-%d low=%d-%d", ranges[0], ranges[1], ranges[2], ranges[3], ranges[4], ranges[5])
	t.Cleanup(func() {
		if current := readRanges(); current != ranges {
			t.Errorf("Darwin ephemeral ranges changed during test: %v -> %v", ranges, current)
		}
	})
	inRange := func(n, a, b int) bool { return n >= min(a, b) && n <= max(a, b) }
	for port := 1024; port <= 65535; port++ {
		if inRange(port, ranges[0], ranges[1]) || inRange(port, ranges[2], ranges[3]) || inRange(port, ranges[4], ranges[5]) {
			continue
		}
		addr := net.JoinHostPort("127.0.0.1", strconv.Itoa(port))
		tcp, err := net.Listen("tcp4", addr)
		if err != nil {
			continue
		}
		udp, err := net.ListenPacket("udp4", addr)
		if err != nil {
			_ = tcp.Close()
			continue
		}
		t.Logf("isolated echo address: %s", addr)
		return tcp, udp
	}
	t.Fatal("no free loopback TCP/UDP port outside Darwin ephemeral ranges")
	return nil, nil
}

func newSoakRig(t *testing.T) *soakRig {
	t.Helper()
	listen := func() net.Listener {
		l, err := net.Listen("tcp", "127.0.0.1:0")
		if err != nil {
			t.Fatal(err)
		}
		return l
	}
	echo, greet := listen(), listen()
	plainTLS, udpEcho := soakListenIsolatedEcho(t)
	soakServe(t, echo, soakLineEcho)
	soakServe(t, greet, func(conn net.Conn) {
		if _, err := io.WriteString(conn, "220 ready\n"); err == nil {
			soakLineEcho(conn)
		}
	})
	// UDP echo on the TLS server's port number, which stands in for 443.
	udpSelfEcho := &atomic.Int64{}
	go func() {
		buf := make([]byte, 2048)
		for {
			n, from, err := udpEcho.ReadFrom(buf)
			if err != nil {
				return
			}
			if from.String() == udpEcho.LocalAddr().String() {
				udpSelfEcho.Add(1)
				continue
			}
			_, _ = udpEcho.WriteTo(buf[:n], from)
		}
	}()
	cert, roots := soakServerIdentity(t)
	tlsListener := tls.NewListener(plainTLS, &tls.Config{Certificates: []tls.Certificate{cert}, NextProtos: []string{"http/1.1"}})
	soakServe(t, tlsListener, soakLineEcho)

	// The names resolve to loopback through the tunnel's own hosts.
	hosts := trie.New[resolver.HostValue]()
	value, err := resolver.NewHostValue([]string{"127.0.0.1"})
	if err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"listed.test", "other.test"} {
		if err := hosts.Insert(name, value); err != nil {
			t.Fatal(err)
		}
	}
	oldHosts := resolver.DefaultHosts
	resolver.DefaultHosts = resolver.NewHosts(hosts)

	oldMode, oldStatus := tunnel.Mode(), tunnel.Status()
	oldProxies, oldProviders := tunnel.Proxies(), tunnel.Providers()
	oldHook, oldWanted, oldDrop, oldPort := tunnel.TCPIntercept, tunnel.TCPInterceptWanted, tunnel.UDPDrop, mitmHTTPSPort
	mitmHTTPSPort = uint16(plainTLS.Addr().(*net.TCPAddr).Port)
	tunnel.UpdateProxies(map[string]C.Proxy{"DIRECT": adapter.NewProxy(outbound.NewDirect())}, nil)
	tunnel.SetMode(tunnel.Direct)
	tunnel.OnRunning()
	// A named listener without auth; the default one applies lan-allowed-ips,
	// which a test process leaves empty.
	inbound, err := mixed.NewWithConfig(
		LC.AuthServer{Enable: true, Listen: "127.0.0.1:0", AuthStore: authStore.Nil},
		mihomoInbound.NewListenConfig(), tunnel.Tunnel,
		mihomoInbound.WithInName("SOAK"), mihomoInbound.WithSpecialRules(""),
	)
	if err != nil {
		t.Fatal(err)
	}
	udpInbound, err := socks.NewUDPWithConfig(
		LC.AuthServer{Enable: true, Listen: "[::1]:0", AuthStore: authStore.Nil},
		mihomoInbound.NewListenConfig(), tunnel.Tunnel,
		mihomoInbound.WithInName("SOAK"), mihomoInbound.WithSpecialRules(""),
	)
	if err != nil {
		t.Fatal(err)
	}
	withMitmState(t)
	oldSign, oldConnection := sendMitmSign, sendMitmConnection
	sendMitmConnection = func(*MitmConnection) bool { return true }
	t.Cleanup(func() {
		_ = inbound.Close()
		_ = udpInbound.Close()
		_ = udpEcho.Close()
		tunnel.TCPIntercept, tunnel.TCPInterceptWanted, tunnel.UDPDrop, mitmHTTPSPort = oldHook, oldWanted, oldDrop, oldPort
		sendMitmSign, sendMitmConnection = oldSign, oldConnection
		resolver.DefaultHosts = oldHosts
		tunnel.UpdateProxies(oldProxies, oldProviders)
		tunnel.SetMode(oldMode)
		switch oldStatus {
		case tunnel.Running:
			tunnel.OnRunning()
		case tunnel.Inner:
			tunnel.OnInnerLoading()
		default:
			tunnel.OnSuspend()
		}
	})
	port := func(l net.Listener) int { return l.Addr().(*net.TCPAddr).Port }
	return &soakRig{
		mixed: inbound.Address(), socksUDP: udpInbound.Address(), echo: port(echo), greet: port(greet), tlsPort: port(plainTLS),
		roots: roots, app: newFakeMitmApp(t), listed: []string{"listed.test"}, udpSelfEcho: udpSelfEcho,
		stopServers: func() { _ = echo.Close(); _ = greet.Close(); _ = tlsListener.Close() },
	}
}

// One connection through the mixed inbound (SOCKS5), timed from the dial
// to the first echoed line.
func (rig *soakRig) run(kind soakKind) soakResult {
	started := time.Now()
	err := rig.exchange(kind)
	return soakResult{kind: kind, elapsed: time.Since(started), err: err}
}

// A fresh socket per probe, so each is a new UDP flow the tunnel decides on.
func (rig *soakRig) udpExchange(target string) error {
	// Keep client and SOCKS inbound on IPv6 loopback, separate from IPv4
	// DIRECT responses. Darwin permits a wildcard DIRECT socket to share
	// a port with a more specific IPv4 loopback socket.
	conn, err := net.ListenPacket("udp", "[::1]:0")
	if err != nil {
		return err
	}
	// Held until the phase ends: a port the OS hands out again would ride
	// the tunnel's NAT session of an earlier probe (keyed by source).
	soakHeldUDP.Lock()
	soakHeldUDP.conns = append(soakHeldUDP.conns, conn)
	soakHeldUDP.Unlock()
	relay, err := net.ResolveUDPAddr("udp", rig.socksUDP)
	if err != nil {
		return err
	}
	packet, err := socks5.EncodeUDPPacket(socks5.ParseAddr(target), []byte("ping"))
	if err != nil {
		return err
	}
	// A timeout is a failed probe, even if a retry might succeed.
	buf := make([]byte, 2048)
	if _, err := conn.WriteTo(packet, relay); err != nil {
		return err
	}
	if err := conn.SetReadDeadline(time.Now().Add(soakUDPWait)); err != nil {
		return err
	}
	n, _, err := conn.ReadFrom(buf)
	if err != nil {
		return fmt.Errorf("no echo: %w", err)
	}
	_, payload, err := socks5.DecodeUDPPacket(buf[:n])
	if err != nil || string(payload) != "ping" {
		return fmt.Errorf("echo %q: %v", payload, err)
	}
	return nil
}

// One datagram must be echoed within this deadline.
const soakUDPWait = 400 * time.Millisecond

func (rig *soakRig) exchange(kind soakKind) error {
	switch kind {
	case soakIPUDP:
		return rig.udpExchange(fmt.Sprintf("127.0.0.1:%d", rig.tlsPort))
	case soakNamedUDP:
		return rig.udpExchange(fmt.Sprintf("other.test:%d", rig.tlsPort))
	case soakListedUDP:
		return rig.udpExchange(fmt.Sprintf("listed.test:%d", rig.tlsPort))
	}
	var target string
	switch kind {
	case soakIPEcho:
		target = fmt.Sprintf("127.0.0.1:%d", rig.echo)
	case soakIPGreet:
		target = fmt.Sprintf("127.0.0.1:%d", rig.greet)
	case soakNamedEcho:
		target = fmt.Sprintf("other.test:%d", rig.echo)
	case soakNamedGreet:
		target = fmt.Sprintf("other.test:%d", rig.greet)
	case soakIPTLS:
		target = fmt.Sprintf("127.0.0.1:%d", rig.tlsPort)
	case soakNamedTLS:
		target = fmt.Sprintf("other.test:%d", rig.tlsPort)
	case soakListedTLS:
		target = fmt.Sprintf("listed.test:%d", rig.tlsPort)
	}
	raw, err := net.DialTimeout("tcp", rig.mixed, 5*time.Second)
	if err != nil {
		return err
	}
	soakNoTimeWait(raw)
	defer raw.Close()
	_ = raw.SetDeadline(time.Now().Add(10 * time.Second))
	if _, err := socks5.ClientHandshake(raw, socks5.ParseAddr(target), socks5.CmdConnect, nil); err != nil {
		return fmt.Errorf("socks: %w", err)
	}
	var conn net.Conn = raw
	switch kind {
	case soakIPTLS, soakNamedTLS:
		conn = tls.Client(raw, &tls.Config{ServerName: "other.test", RootCAs: rig.roots, NextProtos: []string{"http/1.1"}})
	case soakListedTLS:
		conn = tls.Client(raw, &tls.Config{ServerName: "listed.test", RootCAs: rig.roots, NextProtos: []string{"http/1.1"}})
	}
	reader := bufio.NewReader(conn)
	if kind == soakIPGreet || kind == soakNamedGreet {
		line, err := reader.ReadString('\n')
		if err != nil || line != "220 ready\n" {
			return fmt.Errorf("greeting %q: %v", line, err)
		}
	}
	if _, err := io.WriteString(conn, "ping\n"); err != nil {
		return err
	}
	line, err := reader.ReadString('\n')
	if err != nil || line != "ping\n" {
		return fmt.Errorf("echo %q: %v", line, err)
	}
	return nil
}

// Runs n connections over workers, cycling through kinds.
func (rig *soakRig) load(n, workers int, kinds []soakKind) []soakResult {
	results := make([]soakResult, n)
	var next atomic.Int64
	var wg sync.WaitGroup
	for range workers {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for {
				i := int(next.Add(1)) - 1
				if i >= n {
					return
				}
				results[i] = rig.run(kinds[i%len(kinds)])
			}
		}()
	}
	wg.Wait()
	return results
}

func (rig *soakRig) mitmOn() {
	applyMitmSetup(&SetupParams{Mitm: &MitmSetup{
		Enable: true, Hostname: rig.listed, DecryptTLS: true, CAFingerprint: rig.app.fingerprint(),
	}}, nil)
}

func (rig *soakRig) mitmOff() { applyMitmSetup(&SetupParams{}, nil) }

func soakHook(conn *N.BufferedConn, metadata *C.Metadata) tunnel.TCPInterceptor {
	// The production hook is still hard-gated off on this branch
	// (mitmIndicatorAvailable); the soak installs the selector it would run.
	return mitmInterceptEligible(conn, metadata)
}

// The hooks exactly as init installs them once the indicator gate opens.
func soakInstallHooks() {
	tunnel.TCPInterceptWanted = mitmInterceptWanted
	tunnel.TCPIntercept = soakHook
	tunnel.UDPDrop = mitmDropsUDP
}

func soakRemoveHooks() {
	tunnel.TCPIntercept, tunnel.TCPInterceptWanted, tunnel.UDPDrop = nil, nil, nil
}

// Whether a median is the baseline's within loopback noise: half again
// plus a couple of milliseconds absorbs scheduler jitter on a busy machine.
func soakWithinNoise(got, base time.Duration) bool {
	return got <= base+base/2+2*time.Millisecond
}

// Holds beyond the baseline's: the tunnel's own peek race (tunnel.go: the
// stop deadline can land before the peek sets its 200 ms one) holds about
// one server-first flow in a few hundred with or without the hook, so the
// allowance is half a percent; a hook that held flows would hold them all.
func soakHeldWithinNoise(s, base *soakStats) bool {
	return s.held <= base.held+max(2, s.n/200)
}

func soakCompare(t *testing.T, report *strings.Builder, scenario string, stats, base map[soakKind]*soakStats) {
	t.Helper()
	for _, kind := range soakUnlisted {
		s, b := stats[kind], base[kind]
		if s == nil || b == nil {
			continue
		}
		if !soakWithinNoise(s.p50, b.p50) || !soakHeldWithinNoise(s, b) {
			t.Errorf("%s, %s: p50 %v held %d fail %d/%d against no hook p50 %v held %d fail %d/%d",
				scenario, kind, s.p50, s.held, s.failures, s.n, b.p50, b.held, b.failures, b.n)
			fmt.Fprintf(report, "OUTSIDE NOISE: %s %s\n", scenario, kind)
		}
	}
}

// Ends the tunnel's UDP sessions, which otherwise idle for a minute: so
// goroutine counts compare like with like, and a later probe whose source
// port the OS reuses cannot ride an earlier flow's session.
var soakHeldUDP struct {
	sync.Mutex
	conns []net.PacketConn
}

func soakCloseUDP() { soakFinishUDP(true) }

func soakFinishUDP(closeClients bool) {
	if closeClients {
		soakHeldUDP.Lock()
		for _, conn := range soakHeldUDP.conns {
			_ = conn.Close()
		}
		soakHeldUDP.conns = nil
		soakHeldUDP.Unlock()
	}
	statistic.DefaultManager.Range(func(c statistic.Tracker) bool {
		if c.Info().Metadata.NetWork == C.UDP {
			_ = c.Close()
		}
		return true
	})
	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		open := 0
		statistic.DefaultManager.Range(func(c statistic.Tracker) bool {
			if c.Info().Metadata.NetWork == C.UDP {
				open++
			}
			return true
		})
		if open == 0 {
			break
		}
		time.Sleep(20 * time.Millisecond)
	}
	time.Sleep(100 * time.Millisecond)
}

func soakSettledGoroutines(baseline int) int {
	deadline := time.Now().Add(5 * time.Second)
	for {
		n := runtime.NumGoroutine()
		if n <= baseline || time.Now().After(deadline) {
			return n
		}
		time.Sleep(50 * time.Millisecond)
	}
}

func soakTable(title string, stats map[soakKind]*soakStats) string {
	var b strings.Builder
	fmt.Fprintf(&b, "\n%s\n| kind | n | fail | read timeout | held >150ms | p50 | p95 | p99 | max |\n|---|---|---|---|---|---|---|---|---|\n", title)
	kinds := make([]string, 0, len(stats))
	for kind := range stats {
		kinds = append(kinds, string(kind))
	}
	slices.Sort(kinds)
	for _, kind := range kinds {
		s := stats[soakKind(kind)]
		ms := func(d time.Duration) string { return fmt.Sprintf("%.1fms", float64(d.Microseconds())/1000) }
		fmt.Fprintf(&b, "| %s | %d | %d | %d | %d | %s | %s | %s | %s |\n", kind, s.n, s.failures, s.timeouts, s.held, ms(s.p50), ms(s.p95), ms(s.p99), ms(s.max))
		if s.firstErr != nil {
			fmt.Fprintf(&b, "|  first error: %v |\n", s.firstErr)
		}
		if s.firstOtherErr != nil {
			fmt.Fprintf(&b, "|  first non-timeout error: %v |\n", s.firstOtherErr)
		}
	}
	return b.String()
}

func TestMitmLoopbackSoak(t *testing.T) {
	if os.Getenv("FLASH_MITM_SOAK") == "" {
		t.Skip("loopback soak; set FLASH_MITM_SOAK=1")
	}
	conns := soakEnvInt("FLASH_MITM_SOAK_CONNS", 2000)
	workers := soakEnvInt("FLASH_MITM_SOAK_WORKERS", 32)
	cycles := soakEnvInt("FLASH_MITM_SOAK_CYCLES", 50)
	rig := newSoakRig(t)
	var report strings.Builder
	fmt.Fprintf(&report, "connections per scenario: %d, workers: %d, GOMAXPROCS %d\n", conns, workers, runtime.GOMAXPROCS(0))
	// Any failure of an unlisted flow is a failure, including UDP timeouts.
	unlistedFailures := func(stats map[soakKind]*soakStats) int {
		n := 0
		for _, kind := range soakUnlisted {
			if s := stats[kind]; s != nil {
				n += s.failures
			}
		}
		return n
	}

	// Warm up sockets and the TLS stack.
	soakRemoveHooks()
	rig.load(200, workers, soakUnlisted)

	// 0: no hook at all (what a build without the Flash hook does).
	base := soakSummarize(rig.load(conns, workers, soakUnlisted))
	soakCloseUDP()
	report.WriteString(soakTable("### 0. no hook", base))

	// 1: the hook installed, decryption off.
	if n := unlistedFailures(base); n != 0 {
		t.Errorf("no hook: %d failures", n)
	}
	soakInstallHooks()
	rig.mitmOff()
	off := soakSummarize(rig.load(conns, workers, soakUnlisted))
	soakCloseUDP()
	report.WriteString(soakTable("### 1. hook installed, MITM off", off))
	if n := unlistedFailures(off); n != 0 {
		t.Errorf("MITM off: %d failures", n)
	}
	soakCompare(t, &report, "MITM off", off, base)

	// 2: decryption on for listed.test, with a signer that is slow, failing
	// or missing. The listed share is one in eight connections.
	mixedKinds := append(append([]soakKind{}, soakUnlisted...), soakListedTLS, soakListedTLS)
	signers := []struct {
		name string
		send func(*MitmSignRequest) bool
	}{
		{"slow (answers after 5 s, with an error)", func(request *MitmSignRequest) bool {
			id := request.ReqID
			time.AfterFunc(5*time.Second, func() { handleMitmSignResult(MitmSignResultParams{ReqID: id, Error: "slow"}) })
			return true
		}},
		{"failing (refuses at once)", func(request *MitmSignRequest) bool {
			id := request.ReqID
			go handleMitmSignResult(MitmSignResultParams{ReqID: id, Error: "refused"})
			return true
		}},
		{"missing (no app to ask)", func(*MitmSignRequest) bool { return false }},
	}
	for _, signer := range signers {
		sendMitmSign = signer.send
		rig.mitmOn()
		stats := soakSummarize(rig.load(conns, workers, mixedKinds))
		soakCloseUDP()
		report.WriteString(soakTable("### 2. MITM on, signer "+signer.name, stats))
		fmt.Fprintf(&report, "pause after: %q\n", mitmPausedReason())
		if n := unlistedFailures(stats); n != 0 {
			t.Errorf("signer %s: %d unlisted failures", signer.name, n)
		}
		soakCompare(t, &report, "signer "+signer.name, stats, base)
		if s := stats[soakListedTLS]; s != nil {
			if s.failures != 0 {
				t.Errorf("signer %s: %d listed failures (%v)", signer.name, s.failures, s.firstErr)
			}
			if s.max > mitmConnectionLeafWait+time.Second {
				t.Errorf("signer %s: a listed connection took %v", signer.name, s.max)
			}
		}
		rig.mitmOff()
	}

	// 3: rapid on/off while unlisted traffic runs.
	sendMitmSign = func(*MitmSignRequest) bool { return false }
	soakCloseUDP()
	before := runtime.NumGoroutine()
	done := make(chan struct{})
	toggled := make(chan time.Duration, 1)
	go func() {
		defer close(done)
		started := time.Now()
		for range cycles {
			rig.mitmOn()
			time.Sleep(20 * time.Millisecond)
			rig.mitmOff()
			time.Sleep(20 * time.Millisecond)
		}
		toggled <- time.Since(started)
	}()
	var toggleResults []soakResult
	for {
		toggleResults = append(toggleResults, rig.load(workers*4, workers, soakUnlisted)...)
		select {
		case <-done:
		default:
			continue
		}
		break
	}
	elapsed := <-toggled
	stats := soakSummarize(toggleResults)
	report.WriteString(soakTable(fmt.Sprintf("### 3. %d on/off cycles in %v while traffic runs", cycles, elapsed.Round(time.Millisecond)), stats))
	if n := unlistedFailures(stats); n != 0 {
		t.Errorf("toggles: %d unlisted failures", n)
	}
	soakCloseUDP()
	after := soakSettledGoroutines(before)
	fmt.Fprintf(&report, "goroutines: %d before the toggles, %d after they settled\n", before, after)
	if after > before+5 {
		buf := make([]byte, 1<<20)
		t.Errorf("goroutine leak: %d -> %d\n%s", before, after, buf[:runtime.Stack(buf, true)])
	}

	// 4: QUIC. With decryption on and the listed host not paused, UDP to it
	// on the HTTPS port is refused; every other UDP flow is untouched.
	sendMitmSign = func(req *MitmSignRequest) bool {
		result := MitmSignResultParams{ReqID: req.ReqID, Cert: rig.app.leaf(t, req.Host, req.SPKI, nil), CA: rig.app.ca.Raw}
		go handleMitmSignResult(result)
		return true
	}
	soakCloseUDP()
	rig.mitmOn()
	// QUIC is blocked only after recent signer proof; failing or missing
	// signers intentionally leave it untouched.
	if _, err := mitmLeaves.fresh(context.Background(), "listed.test"); err != nil {
		t.Fatalf("prepare QUIC signer proof: %v", err)
	}
	udpKinds := []soakKind{soakIPUDP, soakNamedUDP, soakListedUDP}
	udpResults := rig.load(max(conns/4, 30), workers, udpKinds)
	udpStats := soakSummarize(udpResults)
	soakCloseUDP()
	report.WriteString(soakTable("### 4. MITM on: UDP (listed fails = dropped, as it must)", udpStats))
	soakCompare(t, &report, "QUIC on", udpStats, base)
	for _, r := range udpResults {
		if r.kind == soakListedUDP {
			if !soakReadTimeout(r.err) {
				t.Errorf("QUIC to the listed host: expected read timeout, got %v", r.err)
			}
		}
	}
	if n := unlistedFailures(udpStats); n != 0 {
		t.Errorf("QUIC on: %d unlisted failures", n)
	}
	// 阻止 QUIC off: nothing refused.
	off4 := false
	applyMitmSetup(&SetupParams{Mitm: &MitmSetup{
		Enable: true, Hostname: rig.listed, DecryptTLS: true, CAFingerprint: rig.app.fingerprint(), AutoQuicBlock: &off4,
	}}, nil)
	allowed := soakSummarize(rig.load(30, workers, []soakKind{soakListedUDP}))
	soakCloseUDP()
	report.WriteString(soakTable("### 4b. MITM on, 阻止 QUIC off: listed UDP", allowed))
	if s := allowed[soakListedUDP]; s == nil || s.failures != 0 {
		t.Errorf("QUIC to the listed host was refused with 阻止 QUIC off: %+v", s)
	}
	rig.mitmOff()

	soakRemoveHooks()
	rig.stopServers()
	if count := rig.udpSelfEcho.Load(); count > 0 {
		t.Errorf("UDP echo received %d self-addressed packets (possible port collision)", count)
	}
	t.Log(report.String())
	if path := os.Getenv("FLASH_MITM_SOAK_OUT"); path != "" {
		_ = os.WriteFile(path, []byte(report.String()), 0o600)
	}
}

// soakTrace records only observations; it does not influence packet delivery.
type soakTrace struct {
	sync.Mutex
	events map[string][]string
}

func (tr *soakTrace) add(id, event string) {
	tr.Lock()
	if len(tr.events[id]) < 32 {
		tr.events[id] = append(tr.events[id], event)
	}
	tr.Unlock()
}
func (tr *soakTrace) get(id string) []string {
	tr.Lock()
	defer tr.Unlock()
	return append([]string(nil), tr.events[id]...)
}

type soakTracePacket struct {
	C.UDPPacket
	tr *soakTrace
	id string
}

func (p *soakTracePacket) WriteBack(data []byte, addr net.Addr) (int, error) {
	p.tr.add(p.id, fmt.Sprintf("writeback payload=%q from=%s", data, addr))
	return p.UDPPacket.WriteBack(data, addr)
}

type soakTraceProxy struct {
	C.Proxy
	tr             *soakTrace
	loopbackDirect *outbound.Direct
}

func (p *soakTraceProxy) ListenPacketContext(ctx context.Context, m *C.Metadata) (C.PacketConn, error) {
	var c C.PacketConn
	var err error
	if p.loopbackDirect != nil {
		err = p.loopbackDirect.ResolveUDP(ctx, m)
		if err == nil {
			var raw net.PacketConn
			raw, err = net.ListenPacket("udp4", "127.0.0.1:0")
			if err == nil {
				c = outbound.NewPacketConn(raw, p.loopbackDirect)
			}
		}
	} else {
		c, err = p.Proxy.ListenPacketContext(ctx, m)
	}
	if err != nil {
		p.tr.add("source:"+m.SourceAddrPort().String(), "dial error: "+err.Error())
		return nil, err
	}
	src := m.SourceAddrPort().String()
	local := c.LocalAddr()
	if custom, ok := local.(N.CustomAddr); ok {
		local = custom.RawAddr()
	}
	p.tr.add("source:"+src, "upstream local="+local.String())
	return &soakTraceConn{PacketConn: c, tr: p.tr, source: src}, nil
}

type soakTraceConn struct {
	C.PacketConn
	tr     *soakTrace
	source string
}

func (c *soakTraceConn) WaitReadFrom() ([]byte, func(), net.Addr, error) {
	data, put, addr, err := c.PacketConn.WaitReadFrom()
	if err != nil {
		c.tr.add("source:"+c.source, "upstream read error: "+err.Error())
	} else {
		c.tr.add(string(data), fmt.Sprintf("upstream received from=%s", addr))
	}
	return data, put, addr, err
}

type soakTraceTunnel struct {
	C.Tunnel
	tr     *soakTrace
	bypass bool
}

func (s *soakTraceTunnel) HandleUDPPacket(p C.UDPPacket, m *C.Metadata) {
	id := string(p.Data())
	s.tr.add(id, fmt.Sprintf("inbound src=%s dst=%s", p.LocalAddr(), m.String()))
	wrapped := &soakTracePacket{UDPPacket: p, tr: s.tr, id: id}
	if !s.bypass {
		s.Tunnel.HandleUDPPacket(wrapped, m)
		return
	}
	go func() {
		defer p.Drop()
		addr := m.UDPAddr()
		c, err := net.DialUDP("udp", nil, addr)
		if err != nil {
			s.tr.add(id, "bypass dial: "+err.Error())
			return
		}
		defer c.Close()
		_ = c.SetDeadline(time.Now().Add(time.Second))
		_, err = c.Write(p.Data())
		if err != nil {
			s.tr.add(id, "bypass write: "+err.Error())
			return
		}
		b := make([]byte, 2048)
		n, err := c.Read(b)
		if err != nil {
			s.tr.add(id, "bypass read: "+err.Error())
			return
		}
		_, err = wrapped.WriteBack(b[:n], addr)
		if err != nil {
			s.tr.add(id, "bypass writeback: "+err.Error())
		}
	}()
}

// TestMitmUDPTrace compares the actual SOCKS UDP listener, with and without
// the tunnel, to direct UDP. Each packet has a unique phase/probe/attempt ID.
func TestMitmUDPTrace(t *testing.T) {
	if os.Getenv("FLASH_MITM_UDP_TRACE") == "" {
		t.Skip("opt-in loopback diagnostics")
	}
	n := soakEnvInt("FLASH_MITM_SOAK_CONNS", 1000)
	workers := soakEnvInt("FLASH_MITM_SOAK_WORKERS", 8)
	rig := newSoakRig(t)
	defer rig.stopServers()
	soakRemoveHooks()
	rig.mitmOff()
	defer soakCloseUDP()
	tr := &soakTrace{events: make(map[string][]string)}
	tunnel.UpdateProxies(map[string]C.Proxy{"DIRECT": &soakTraceProxy{Proxy: adapter.NewProxy(outbound.NewDirect()), tr: tr}}, nil)
	echoTCP, echo := soakListenIsolatedEcho(t)
	defer echoTCP.Close()
	defer echo.Close()
	go func() {
		b := make([]byte, 2048)
		for {
			n, from, err := echo.ReadFrom(b)
			if err != nil {
				return
			}
			id := string(b[:n])
			tr.add(id, "echo received from="+from.String())
			if from.String() == echo.LocalAddr().String() {
				tr.add(id, "echo self-address collision")
				continue
			}
			_, err = echo.WriteTo(b[:n], from)
			if err != nil {
				tr.add(id, "echo write: "+err.Error())
			} else {
				tr.add(id, "echo sent to="+from.String())
			}
		}
	}()
	listen := func(bypass bool) *socks.UDPListener {
		l, e := socks.NewUDPWithConfig(LC.AuthServer{Enable: true, Listen: "[::1]:0", AuthStore: authStore.Nil}, mihomoInbound.NewListenConfig(), &soakTraceTunnel{Tunnel: tunnel.Tunnel, tr: tr, bypass: bypass}, mihomoInbound.WithInName("SOAK"), mihomoInbound.WithSpecialRules(""))
		if e != nil {
			t.Fatal(e)
		}
		return l
	}
	bypass, forward := listen(true), listen(false)
	defer bypass.Close()
	defer forward.Close()
	type result struct {
		port     string
		id       string
		attempts []string
		err      error
	}
	var previous = map[string]string{}
	for _, phase := range []struct{ name, relay string }{{"direct", echo.LocalAddr().String()}, {"socks-bypass", bypass.Address()}, {"tunnel", forward.Address()}, {"tunnel-again", forward.Address()}, {"tunnel-loopback-bound", forward.Address()}} {
		if phase.name == "tunnel-loopback-bound" {
			direct := outbound.NewDirect()
			tunnel.UpdateProxies(map[string]C.Proxy{"DIRECT": &soakTraceProxy{Proxy: adapter.NewProxy(direct), tr: tr, loopbackDirect: direct}}, nil)
		}
		results := make([]result, n)
		var next atomic.Int64
		var wg sync.WaitGroup
		for range workers {
			wg.Add(1)
			go func() {
				defer wg.Done()
				for {
					i := int(next.Add(1)) - 1
					if i >= n {
						return
					}
					r := &results[i]
					address := "[::1]:0"
					if phase.name == "direct" {
						address = "127.0.0.1:0"
					}
					c, e := net.ListenPacket("udp", address)
					if e != nil {
						r.err = e
						continue
					}
					soakHeldUDP.Lock()
					soakHeldUDP.conns = append(soakHeldUDP.conns, c)
					soakHeldUDP.Unlock()
					r.port = c.LocalAddr().String()
					r.id = fmt.Sprintf("%s-%d", phase.name, i)
					for attempt := 0; attempt < 3; attempt++ {
						id := fmt.Sprintf("%s-%d", r.id, attempt)
						r.attempts = append(r.attempts, id)
						data := []byte(id)
						if phase.name != "direct" {
							data, e = socks5.EncodeUDPPacket(socks5.ParseAddr(echo.LocalAddr().String()), data)
							if e != nil {
								r.err = e
								break
							}
						}
						dest, e := net.ResolveUDPAddr("udp", phase.relay)
						if e != nil {
							r.err = e
							break
						}
						_, e = c.WriteTo(data, dest)
						if e != nil {
							r.err = e
							break
						}
						_ = c.SetReadDeadline(time.Now().Add(soakUDPWait))
						b := make([]byte, 2048)
						size, from, e := c.ReadFrom(b)
						if e == nil {
							payload := b[:size]
							if phase.name != "direct" {
								_, payload, e = socks5.DecodeUDPPacket(payload)
							}
							if e == nil && string(payload) != id {
								e = fmt.Errorf("unexpected payload %q (wanted %q), from %s", payload, id, from)
							}
							if e != nil {
								r.err = e
							}
							break
						}
						if attempt == 0 {
							r.err = e
						}
						if !soakReadTimeout(e) {
							r.err = e
							break
						}
					}
				}
			}()
		}
		wg.Wait()
		fail, reused := 0, 0
		phaseClients := make(map[string]string)
		for _, r := range results {
			phaseClients[r.port] = r.id
		}
		for _, r := range results {
			if prior := previous[r.port]; prior != "" {
				reused++
			}
			if r.err != nil {
				fail++
				t.Logf("TRACE phase=%s source=%s previous=%s failure=%v source-events=%q", phase.name, r.port, previous[r.port], r.err, tr.get("source:"+r.port))
				for _, id := range r.attempts {
					events := tr.get(id)
					t.Logf("TRACE id=%s events=%q", id, events)
					for _, event := range events {
						if strings.HasPrefix(event, "echo received from=") {
							addr := strings.TrimPrefix(event, "echo received from=")
							if other := phaseClients[addr]; other != "" {
								t.Logf("TRACE upstream=%s also-client=%s", addr, other)
							}
						}
					}
				}
			}
			previous[r.port] = phase.name
		}
		t.Logf("TRACE summary phase=%s samples=%d failures=%d reused-prior-phase=%d", phase.name, n, fail, reused)
		if fail > 0 {
			t.Errorf("%s: %d/%d probes failed on first attempt", phase.name, fail, n)
		}
		soakFinishUDP(os.Getenv("FLASH_MITM_UDP_TRACE_HOLD_CLIENTS") == "")
	}
}
