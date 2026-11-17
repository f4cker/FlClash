package core

import (
	"testing"
	"time"

	N "github.com/metacubex/mihomo/common/net"
	C "github.com/metacubex/mihomo/constant"
)

// Only loopback sockets; no Flash process, proxy service or TUN.

// A flow without a name off port 443 is never held, whatever its client
// sends or does not send: there is no SNI to wait for that could matter.
func TestMitmHostlessOffHTTPSPortIsNeverHeld(t *testing.T) {
	app := newFakeMitmApp(t)
	withMitmSigner(t, app, []string{"example.com"}, nil)
	sni := []byte{0, 0, 0, 16, 0, 14, 0, 0, 11, 'e', 'x', 'a', 'm', 'p', 'l', 'e', '.', 'c', 'o', 'm'}
	hello := helloFixture(sni)
	record := append([]byte{0x16, 3, 3, byte(len(hello) >> 8), byte(len(hello))}, hello...)
	for _, tc := range []struct {
		name  string
		port  uint16
		first []byte
	}{
		{"silent client", 8443, nil},
		{"server first", 22, nil},
		{"a listed hello on another port", 8443, record},
		{"plain HTTP", 80, []byte("GET / HTTP/1.1\r\n")},
	} {
		t.Run(tc.name, func(t *testing.T) {
			clientRaw, proxyRaw := mitmLoopbackPair(t)
			defer clientRaw.Close()
			defer proxyRaw.Close()
			if tc.first != nil {
				if _, err := clientRaw.Write(tc.first); err != nil {
					t.Fatal(err)
				}
			}
			conn := N.NewBufferedConn(proxyRaw)
			started := time.Now()
			if selected := mitmInterceptEligible(conn, &C.Metadata{DstPort: tc.port}); selected != nil {
				t.Fatal("selected a nameless flow off 443")
			}
			if elapsed := time.Since(started); elapsed > 20*time.Millisecond {
				t.Fatalf("held %v", elapsed)
			}
			if conn.Reader().Buffered() != 0 {
				t.Fatal("read from a flow it does not take")
			}
		})
	}
}

// On 443 the whole peek is bounded by the hello wait, well under two
// seconds, even when the first byte comes late and the rest never does.
func TestMitmHTTPSPeekIsBoundedAsAWhole(t *testing.T) {
	app := newFakeMitmApp(t)
	withMitmSigner(t, app, []string{"example.com"}, nil)
	if mitmHelloWait >= time.Second {
		t.Fatalf("hello wait %v", mitmHelloWait)
	}
	for _, host := range []string{"", "example.com"} {
		clientRaw, proxyRaw := mitmLoopbackPair(t)
		go func() {
			time.Sleep(mitmHelloWait / 2)
			_, _ = clientRaw.Write([]byte{0x16, 3, 3}) // a record begun, never ended
		}()
		started := time.Now()
		mitmInterceptEligible(N.NewBufferedConn(proxyRaw), &C.Metadata{Host: host, DstPort: 443})
		if elapsed := time.Since(started); elapsed > mitmHelloWait+150*time.Millisecond {
			t.Fatalf("%q held %v", host, elapsed)
		}
		_ = clientRaw.Close()
		_ = proxyRaw.Close()
	}
}

// A signer that does not answer costs a listed connection at most the
// connection's leaf wait, then it is relayed untouched; a nameless or
// unlisted flow meanwhile is not held by it, and the pause that follows
// touches listed hosts alone.
func TestMitmSlowSignerHoldsOnlyItsOwnConnection(t *testing.T) {
	app := newFakeMitmApp(t)
	// Slow, then failing: answers only well after the connection gave up.
	asked := make(chan struct{}, 4)
	withMitmSigner(t, app, []string{"example.com"}, func(*MitmSignRequest) MitmSignResultParams {
		asked <- struct{}{}
		time.Sleep(time.Second)
		return MitmSignResultParams{Error: "slow and failing"}
	})
	defer func() { mitmActive.closeAll(); mitmLeaves.clear(); mitmPaused.Store(nil) }()
	oldWait := mitmConnectionLeafWait
	mitmConnectionLeafWait = 300 * time.Millisecond
	defer func() { mitmConnectionLeafWait = oldWait }()
	events := make(chan MitmConnection, 8)
	oldSend := sendMitmConnection
	sendMitmConnection = func(event *MitmConnection) bool { events <- *event; return true }
	defer func() { sendMitmConnection = oldSend }()

	tlsHello := func(host string) []byte {
		name := []byte(host)
		entry := append([]byte{0, byte(len(name) >> 8), byte(len(name))}, name...)
		list := append([]byte{byte(len(entry) >> 8), byte(len(entry))}, entry...)
		ext := append([]byte{0, 0, byte(len(list) >> 8), byte(len(list))}, list...)
		hello := helloFixture(ext)
		return append([]byte{0x16, 3, 3, byte(len(hello) >> 8), byte(len(hello))}, hello...)
	}

	listed := make(chan time.Duration, 1)
	go func() {
		clientRaw, proxyRaw := mitmLoopbackPair(t)
		defer clientRaw.Close()
		defer proxyRaw.Close()
		_, _ = clientRaw.Write(tlsHello("example.com"))
		started := time.Now()
		selected := mitmInterceptEligible(N.NewBufferedConn(proxyRaw), &C.Metadata{Host: "example.com", DstPort: 443})
		if selected == nil {
			listed <- -1
			return
		}
		listed <- time.Since(started)
	}()
	time.Sleep(50 * time.Millisecond) // the listed one is now waiting on the signer

	for _, tc := range []struct {
		name string
		meta *C.Metadata
		sni  string
	}{
		{"unlisted name", &C.Metadata{Host: "other.test", DstPort: 443}, "other.test"},
		{"nameless unlisted SNI", &C.Metadata{DstPort: 443}, "other.test"},
		{"nameless other port", &C.Metadata{DstPort: 8080}, ""},
	} {
		clientRaw, proxyRaw := mitmLoopbackPair(t)
		if tc.sni != "" {
			_, _ = clientRaw.Write(tlsHello(tc.sni))
		}
		started := time.Now()
		if selected := mitmInterceptEligible(N.NewBufferedConn(proxyRaw), tc.meta); selected != nil {
			t.Fatalf("%s: selected", tc.name)
		}
		if elapsed := time.Since(started); elapsed > 50*time.Millisecond {
			t.Fatalf("%s: held %v while a listed host waited to be signed", tc.name, elapsed)
		}
		_ = clientRaw.Close()
		_ = proxyRaw.Close()
	}

	elapsed := <-listed
	if elapsed < 0 {
		t.Fatal("the listed host was not marked as passed through")
	}
	if elapsed > mitmConnectionLeafWait+200*time.Millisecond {
		t.Fatalf("listed host held %v", elapsed)
	}
	if reason := mitmPausedReason(); reason != "signTimeout" {
		t.Fatalf("pause %q", reason)
	}
	// Paused: an unlisted host is still not looked at, let alone marked.
	clientRaw, proxyRaw := mitmLoopbackPair(t)
	defer clientRaw.Close()
	defer proxyRaw.Close()
	_, _ = clientRaw.Write(tlsHello("other.test"))
	if selected := mitmInterceptEligible(N.NewBufferedConn(proxyRaw), &C.Metadata{DstPort: 443}); selected != nil {
		t.Fatal("a pause selected an unlisted host")
	}
	<-asked // the issuance read the signer before the test restores it
	select {
	case event := <-events:
		t.Fatalf("an event without a tracker: %+v", event)
	default:
	}
}
