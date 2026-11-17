package core

import (
	"bytes"
	"context"
	"errors"
	"io"
	"net"
	"sync/atomic"
	"testing"
	"time"

	N "github.com/metacubex/mihomo/common/net"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
)

// The always-visible indicator exists, so the TCP hook is installed; it still
// decrypts nothing unless decryption is set up with a CA and listed hosts.
// QUIC blocking stays off until signer and trust liveness can be verified.
func TestInterceptionGatedOnVisibleIndicator(t *testing.T) {
	if !mitmIndicatorAvailable {
		t.Fatal("the always-visible indicator gate is expected on for this build")
	}
	if mitmQUICLivenessAvailable {
		t.Fatal("QUIC blocking requires verified signer and trust liveness")
	}
	if tunnel.TCPIntercept == nil || tunnel.TCPInterceptWanted == nil {
		t.Fatal("the TCP interception hooks must be installed when the indicator is available")
	}
	if tunnel.UDPDrop != nil {
		t.Fatal("the UDP drop hook must stay uninstalled while QUIC liveness is unavailable")
	}
	original := mitmState.Load()
	defer mitmState.Store(original)
	mitmState.Store(nil)
	if mitmInterceptWanted(&C.Metadata{DstPort: 443, Host: "example.com"}) ||
		mitmInterceptWanted(&C.Metadata{DstPort: 443}) {
		t.Fatal("no flow may wait for a peek while decryption is not set up")
	}
	if mitmIntercept(nil, &C.Metadata{DstPort: 443, Host: "example.com"}) != nil {
		t.Fatal("nothing may be intercepted while decryption is not set up")
	}
	if status := handleMitmStatus(); status.Enable || status.Paused != "" {
		t.Fatalf("status without setup = %+v", status)
	}
	if mitmDropsUDP(&C.Metadata{DstPort: 443, Host: "example.com"}) {
		t.Fatal("QUIC must pass through while QUIC liveness is unavailable")
	}
}

// Only flows the selector could take wait for the client's first bytes.
func TestMitmInterceptWantedOnlyListedOrHostless(t *testing.T) {
	original := mitmState.Load()
	defer mitmState.Store(original)
	mitmState.Store(&mitmRuntime{
		setup: MitmSetup{Enable: true, DecryptTLS: true, CAFingerprint: "fp", Hostname: []string{"example.com"}},
		hosts: compileMitmHosts([]string{"example.com"}),
	})
	for _, tc := range []struct {
		host string
		want bool
	}{{"example.com", true}, {"EXAMPLE.com.", true}, {"other.org", false}, {"", true}} {
		if got := mitmInterceptWanted(&C.Metadata{DstPort: 443, Host: tc.host}); got != tc.want {
			t.Errorf("host %q: wanted %v, want %v", tc.host, got, tc.want)
		}
	}
	mitmState.Store(&mitmRuntime{
		setup: MitmSetup{Enable: false, DecryptTLS: true, CAFingerprint: "fp", Hostname: []string{"example.com"}},
		hosts: compileMitmHosts([]string{"example.com"}),
	})
	if mitmInterceptWanted(&C.Metadata{DstPort: 443, Host: "example.com"}) {
		t.Error("a listed host waits while decryption is off")
	}
}

func TestMitmHelloALPN(t *testing.T) {
	for _, tc := range []struct {
		alpn []string
		want bool
	}{
		{nil, true}, {[]string{"h2"}, false}, {[]string{"h2", "http/1.1"}, true}, {[]string{}, false},
	} {
		if got := (mitmClientHello{alpn: tc.alpn}).speaksHTTP1(); got != tc.want {
			t.Errorf("ALPN %v: got %v", tc.alpn, got)
		}
	}
}

func TestMitmHelloRejectsTruncated(t *testing.T) {
	for _, data := range [][]byte{nil, {1}, {1, 0, 0, 4, 0}, {2, 0, 0, 0}} {
		if _, err := parseMitmClientHello(data); err == nil {
			t.Errorf("accepted %x", data)
		}
	}
}

// All synchronization here is in-memory; no certificates, sockets or Flash.
func TestMitmLeafCacheClearInvalidatesInFlight(t *testing.T) {
	started := make(chan struct{})
	release := make(chan struct{})
	cache := &mitmLeafCache{
		inflight: map[mitmLeafKey]*mitmLeafCall{},
		issuer: func(context.Context, string) (*mitmLeaf, error) {
			close(started)
			<-release
			return &mitmLeaf{notAfter: time.Now().Add(48 * time.Hour)}, nil
		},
	}
	done := make(chan error, 1)
	go func() { _, err := cache.get(context.Background(), "example.com"); done <- err }()
	<-started
	cache.clear()
	close(release)
	if err := <-done; !errors.Is(err, errMitmSetupChanged) {
		t.Fatalf("stale issuance returned %v", err)
	}
	cache.mu.Lock()
	defer cache.mu.Unlock()
	if len(cache.inflight) != 0 {
		t.Fatal("stale issuance repopulated cache")
	}
}

func TestMitmLeafCacheClearDoesNotEraseNewInflight(t *testing.T) {
	firstStarted, secondStarted := make(chan struct{}), make(chan struct{})
	firstRelease, secondRelease := make(chan struct{}), make(chan struct{})
	var count atomic.Int32
	cache := &mitmLeafCache{
		inflight: map[mitmLeafKey]*mitmLeafCall{},
		issuer: func(context.Context, string) (*mitmLeaf, error) {
			if count.Add(1) == 1 {
				close(firstStarted)
				<-firstRelease
			} else {
				close(secondStarted)
				<-secondRelease
			}
			return &mitmLeaf{notAfter: time.Now().Add(48 * time.Hour)}, nil
		},
	}
	done1, done2 := make(chan error, 1), make(chan error, 1)
	go func() { _, err := cache.get(context.Background(), "example.com"); done1 <- err }()
	<-firstStarted
	cache.clear()
	go func() { _, err := cache.get(context.Background(), "example.com"); done2 <- err }()
	<-secondStarted
	close(firstRelease)
	if err := <-done1; !errors.Is(err, errMitmSetupChanged) {
		t.Fatalf("old call: %v", err)
	}
	cache.mu.Lock()
	n := len(cache.inflight)
	cache.mu.Unlock()
	if n != 1 {
		t.Fatalf("old call erased new call: %d", n)
	}
	close(secondRelease)
	if err := <-done2; err != nil {
		t.Fatalf("new call: %v", err)
	}
}

// helloFixture constructs only public protocol bytes, without TLS or sockets.
func helloFixture(extensions ...[]byte) []byte {
	vec := func(b []byte) []byte { return append([]byte{byte(len(b) >> 8), byte(len(b))}, b...) }
	body := make([]byte, 34)
	body = append(body, 0)             // empty session ID
	body = append(body, 0, 2, 0x13, 1) // cipher suite
	body = append(body, 1, 0)          // compression
	var ext []byte
	for _, e := range extensions {
		ext = append(ext, e...)
	}
	body = append(body, vec(ext)...)
	return append([]byte{1, byte(len(body) >> 16), byte(len(body) >> 8), byte(len(body))}, body...)
}

func TestMitmHelloParsesAndRejectsAmbiguity(t *testing.T) {
	sni := []byte{0, 0, 0, 16, 0, 14, 0, 0, 11, 'e', 'x', 'a', 'm', 'p', 'l', 'e', '.', 'c', 'o', 'm'}
	alpn := []byte{0, 16, 0, 11, 0, 9, 8, 'h', 't', 't', 'p', '/', '1', '.', '1'}
	h, err := parseMitmClientHello(helloFixture(sni, alpn))
	if err != nil || h.serverName != "example.com" || !h.speaksHTTP1() {
		t.Fatalf("hello=%+v err=%v", h, err)
	}
	for _, input := range [][]byte{helloFixture(sni, sni), helloFixture(alpn, alpn), helloFixture([]byte{0, 16, 0, 3, 0, 1, 0})} {
		if _, err := parseMitmClientHello(input); err == nil {
			t.Fatalf("accepted ambiguous input %x", input)
		}
	}
}

// memoryConn never opens a socket; Peek and subsequent Read share its buffer.
type memoryConn struct{ *bytes.Reader }

func (c *memoryConn) Write(p []byte) (int, error)      { return len(p), nil }
func (c *memoryConn) Close() error                     { return nil }
func (c *memoryConn) LocalAddr() net.Addr              { return nil }
func (c *memoryConn) RemoteAddr() net.Addr             { return nil }
func (c *memoryConn) SetDeadline(time.Time) error      { return nil }
func (c *memoryConn) SetReadDeadline(time.Time) error  { return nil }
func (c *memoryConn) SetWriteDeadline(time.Time) error { return nil }

func TestMitmHelloPeekPreservesPassthroughBytes(t *testing.T) {
	sni := []byte{0, 0, 0, 16, 0, 14, 0, 0, 11, 'e', 'x', 'a', 'm', 'p', 'l', 'e', '.', 'c', 'o', 'm'}
	hello := helloFixture(sni)
	record := append([]byte{0x16, 0x03, 0x03, byte(len(hello) >> 8), byte(len(hello))}, hello...)
	original := append(record, []byte("following bytes")...)
	conn := N.NewBufferedConn(&memoryConn{bytes.NewReader(original)})
	parsed, err := peekMitmClientHello(conn)
	if err != nil || parsed.serverName != "example.com" {
		t.Fatalf("peek: %+v %v", parsed, err)
	}
	got, err := io.ReadAll(conn)
	if err != nil || !bytes.Equal(got, original) {
		t.Fatalf("peek changed passthrough bytes: %v", err)
	}
}

func TestMitmFragmentedHelloPassesThroughUnchanged(t *testing.T) {
	record := []byte{0x16, 0x03, 0x03, 0, 5, 1, 0, 0, 30, 0}
	conn := N.NewBufferedConn(&memoryConn{bytes.NewReader(record)})
	if _, err := peekMitmClientHello(conn); !errors.Is(err, errMitmHelloUnsupported) {
		t.Fatalf("got %v", err)
	}
	got, err := io.ReadAll(conn)
	if err != nil || !bytes.Equal(got, record) {
		t.Fatalf("peek changed bytes: %v", err)
	}
}

// Fragmentation can reveal a listed SNI even for an IP-only destination,
// while still leaving every original TLS byte available to passthrough.
func TestMitmFragmentedHelloRecoversSNIWithoutConsumption(t *testing.T) {
	sni := []byte{0, 0, 0, 16, 0, 14, 0, 0, 11, 'e', 'x', 'a', 'm', 'p', 'l', 'e', '.', 'c', 'o', 'm'}
	hello := helloFixture(sni)
	record := func(b []byte) []byte { return append([]byte{0x16, 3, 3, byte(len(b) >> 8), byte(len(b))}, b...) }
	original := append(record(hello[:7]), record(hello[7:])...)
	conn := N.NewBufferedConn(&memoryConn{bytes.NewReader(original)})
	parsed, err := peekMitmClientHello(conn)
	if err != nil || parsed.serverName != "example.com" {
		t.Fatalf("hello %+v: %v", parsed, err)
	}
	got, err := io.ReadAll(conn)
	if err != nil || !bytes.Equal(got, original) {
		t.Fatalf("changed passthrough: %v", err)
	}
}

func TestMitmSlowPartialTLSRecordWarnsAndPreservesBytes(t *testing.T) {
	raw, peer := net.Pipe()
	defer raw.Close()
	defer peer.Close()
	conn := N.NewBufferedConn(raw)
	first := []byte{0x16, 0x03, 0x03, 0x00, 0x08, 0x01, 0x00}
	rest := []byte{0, 4, 1, 2, 3, 4}
	go func() { _, _ = peer.Write(first) }()
	_, err := peekMitmClientHello(conn)
	if !errors.Is(err, errMitmHelloUnsupported) {
		t.Fatalf("expected partial TLS warning: %v", err)
	}
	go func() { _, _ = peer.Write(rest) }()
	want := append(append([]byte{}, first...), rest...)
	got := make([]byte, len(want))
	if _, err := io.ReadFull(conn, got); err != nil || !bytes.Equal(got, want) {
		t.Fatalf("fallback bytes %x err=%v", got, err)
	}
}
