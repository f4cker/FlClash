package core

import (
	"context"
	"sync/atomic"
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

// On 443 a flow waits for its first packet at most mitmFirstByteWait in all,
// counting the tunnel's own peek when it ran; once a record has begun, the
// whole hello is bounded by mitmHelloWait.
func TestMitmHTTPSPeekIsBounded(t *testing.T) {
	app := newFakeMitmApp(t)
	withMitmSigner(t, app, []string{"example.com"}, nil)
	if mitmFirstByteWait > 300*time.Millisecond || mitmHelloWait >= time.Second {
		t.Fatalf("waits %v / %v", mitmFirstByteWait, mitmHelloWait)
	}
	for _, host := range []string{"", "example.com"} {
		// Silent client, no earlier peek.
		clientRaw, proxyRaw := mitmLoopbackPair(t)
		started := time.Now()
		mitmInterceptEligible(N.NewBufferedConn(proxyRaw), &C.Metadata{Host: host, DstPort: 443})
		if elapsed := time.Since(started); elapsed > mitmFirstByteWait+100*time.Millisecond {
			t.Fatalf("%q silent: held %v", host, elapsed)
		}
		_ = clientRaw.Close()
		_ = proxyRaw.Close()

		// Silent client after the tunnel's 200 ms peek: only the rest.
		clientRaw, proxyRaw = mitmLoopbackPair(t)
		conn := N.NewBufferedConn(proxyRaw)
		_ = conn.SetReadDeadline(time.Now().Add(mitmTunnelPeekWait))
		_, _ = conn.Peek(1)
		_ = conn.SetReadDeadline(time.Time{})
		started = time.Now()
		mitmInterceptEligible(conn, &C.Metadata{Host: host, DstPort: 443})
		if elapsed := time.Since(started); elapsed > mitmFirstByteWait-mitmTunnelPeekWait+100*time.Millisecond {
			t.Fatalf("%q after the tunnel peek: held %v more", host, elapsed)
		}
		_ = clientRaw.Close()
		_ = proxyRaw.Close()

		// A record begun and never ended.
		clientRaw, proxyRaw = mitmLoopbackPair(t)
		_, _ = clientRaw.Write([]byte{0x16, 3, 3})
		started = time.Now()
		mitmInterceptEligible(N.NewBufferedConn(proxyRaw), &C.Metadata{Host: host, DstPort: 443})
		if elapsed := time.Since(started); elapsed > mitmHelloWait+150*time.Millisecond {
			t.Fatalf("%q stalled record: held %v", host, elapsed)
		}
		_ = clientRaw.Close()
		_ = proxyRaw.Close()
	}
}

// Only HTTPS is looked at, and there a named flow only when listed.
func TestMitmInterceptWantedFromMetadataAlone(t *testing.T) {
	withMitmState(t)
	cases := []struct {
		host string
		port uint16
		want bool
	}{
		{"", 443, true},
		{"example.com", 443, true},
		{"EXAMPLE.com.", 443, true},
		{"other.test", 443, false},
		{"example.com", 8443, false},
		{"", 80, false},
		{"", 22, false},
	}
	mitmState.Store(nil)
	for _, tc := range cases {
		if mitmInterceptWanted(&C.Metadata{Host: tc.host, DstPort: tc.port}) {
			t.Fatalf("off: wanted %q:%d", tc.host, tc.port)
		}
	}
	app := newFakeMitmApp(t)
	withMitmSigner(t, app, []string{"example.com"}, nil)
	for _, tc := range cases {
		if got := mitmInterceptWanted(&C.Metadata{Host: tc.host, DstPort: tc.port}); got != tc.want {
			t.Fatalf("on: %q:%d wanted=%v", tc.host, tc.port, got)
		}
	}
}

// QUIC to a listed host is dropped exactly while it is decrypted; nothing
// else is ever touched.
func TestMitmDropsQUICOnlyForListedHostsWhileDecrypting(t *testing.T) {
	app := newFakeMitmApp(t)
	withMitmSigner(t, app, []string{"example.com"}, func(req *MitmSignRequest) MitmSignResultParams {
		return MitmSignResultParams{Cert: app.leaf(t, req.Host, req.SPKI, nil), CA: app.ca.Raw}
	})
	defer func() { mitmPaused.Store(nil); mitmHostPauses.Clear() }()
	if _, err := mitmLeaves.fresh(context.Background(), "example.com"); err != nil {
		t.Fatal(err)
	}
	listed := &C.Metadata{NetWork: C.UDP, Host: "example.com", DstPort: 443}
	if !mitmDropsUDP(listed) {
		t.Fatal("listed QUIC not dropped while decrypting")
	}
	for _, metadata := range []*C.Metadata{
		{NetWork: C.UDP, Host: "other.test", DstPort: 443},
		{NetWork: C.UDP, DstPort: 443},
		{NetWork: C.UDP, Host: "example.com", DstPort: 8443},
	} {
		if mitmDropsUDP(metadata) {
			t.Fatalf("dropped %+v", metadata)
		}
	}
	// Paused: TCP passes through, so QUIC may too.
	mitmActive.pauseGlobal(mitmState.Load(), "signTimeout")
	if mitmDropsUDP(listed) {
		t.Fatal("dropped while paused")
	}
	mitmPaused.Store(nil)
	// 阻止 QUIC turned off.
	off := false
	applyMitmSetup(&SetupParams{Mitm: &MitmSetup{
		Enable: true, Hostname: []string{"example.com"}, DecryptTLS: true, CAFingerprint: app.fingerprint(), AutoQuicBlock: &off,
	}}, nil)
	if mitmDropsUDP(listed) {
		t.Fatal("dropped with 阻止 QUIC off")
	}
	// MITM off.
	applyMitmSetup(&SetupParams{}, nil)
	if mitmDropsUDP(listed) {
		t.Fatal("dropped with MITM off")
	}
}

// A signed leaf is kept per host and CA: the next connection takes it, a new
// CA or a pause does not, and the liveness check always signs anew.
func TestMitmLeafIsKeptPerHostAndCA(t *testing.T) {
	app := newFakeMitmApp(t)
	withMitmSigner(t, app, []string{"example.com", "two.test"}, nil)
	var issued atomic.Int32
	notAfter := time.Now().Add(7 * 24 * time.Hour)
	mitmLeaves.clear()
	mitmLeaves.issuer = func(context.Context, string) (*mitmLeaf, error) {
		issued.Add(1)
		return &mitmLeaf{notAfter: notAfter}, nil
	}
	defer func() { mitmLeaves.clear(); mitmLeaves.issuer = nil; mitmPaused.Store(nil) }()
	get := func(host string) *mitmLeaf {
		t.Helper()
		leaf, err := mitmLeaves.get(context.Background(), host)
		if err != nil {
			t.Fatal(err)
		}
		return leaf
	}
	first := get("example.com")
	if get("example.com") != first || issued.Load() != 1 {
		t.Fatalf("not kept: %d issuances", issued.Load())
	}
	// Another setup with the same CA keeps it.
	applyMitmSetup(&SetupParams{Mitm: &MitmSetup{
		Enable: true, Hostname: []string{"example.com", "two.test"}, DecryptTLS: true, CAFingerprint: app.fingerprint(),
	}}, nil)
	if get("example.com") != first || issued.Load() != 1 {
		t.Fatal("a setup with the same CA dropped the kept leaf")
	}
	get("two.test")
	if issued.Load() != 2 {
		t.Fatal("hosts share a leaf")
	}
	// The liveness check signs anew.
	if _, err := mitmLeaves.fresh(context.Background(), "example.com"); err != nil || issued.Load() != 3 {
		t.Fatalf("fresh took a kept leaf: %v %d", err, issued.Load())
	}
	// A new CA is a new key.
	applyMitmSetup(&SetupParams{Mitm: &MitmSetup{
		Enable: true, Hostname: []string{"example.com"}, DecryptTLS: true, CAFingerprint: "AA:BB",
	}}, nil)
	get("example.com")
	if issued.Load() != 4 {
		t.Fatal("a leaf outlived its CA")
	}
	// A pause forgets every kept leaf.
	mitmActive.pauseGlobal(mitmState.Load(), "signTimeout")
	mitmPaused.Store(nil)
	get("example.com")
	if issued.Load() != 5 {
		t.Fatal("a leaf outlived a failing signer")
	}
	// A leaf near its expiry is not kept.
	notAfter = time.Now().Add(mitmLeafExpiryMargin / 2)
	mitmLeaves.clear()
	get("example.com")
	get("example.com")
	if issued.Load() != 7 {
		t.Fatalf("a leaf about to expire was reused: %d", issued.Load())
	}
}

// Short connections cannot keep reusing a leaf after the signer stops trusting
// the root, even when no connection lasts long enough for a liveness probe.
func TestMitmShortConnectionsRecheckRevokedTrust(t *testing.T) {
	app := newFakeMitmApp(t)
	var checks atomic.Int32
	withMitmSigner(t, app, []string{"example.com"}, func(req *MitmSignRequest) MitmSignResultParams {
		if checks.Add(1) > 1 {
			return MitmSignResultParams{Error: "trustUnavailable"}
		}
		return MitmSignResultParams{Cert: app.leaf(t, req.Host, req.SPKI, nil), CA: app.ca.Raw}
	})
	mitmLeaves.clear()
	defer mitmLeaves.clear()
	first, err := mitmLeaves.get(context.Background(), "example.com")
	if err != nil {
		t.Fatal(err)
	}
	// Multiple short connections may reuse only the original, unextended proof.
	for i := 0; i < 3; i++ {
		leaf, err := mitmLeaves.get(context.Background(), "example.com")
		if err != nil || leaf != first || checks.Load() != 1 {
			t.Fatalf("fresh proof not reused: leaf=%v err=%v checks=%d", leaf, err, checks.Load())
		}
	}
	mitmLeaves.mu.Lock()
	key := mitmReadyKeyOf(mitmState.Load(), "example.com")
	kept := mitmLeaves.ready[key]
	if remaining := time.Until(kept.reuseTill); remaining > mitmLivenessInterval || remaining <= 0 {
		mitmLeaves.mu.Unlock()
		t.Fatalf("incorrect trust proof lifetime: %v", remaining)
	}
	// Advance just the cached proof deadline without a real ten-second wait.
	kept.reuseTill = time.Now().Add(-time.Second)
	mitmLeaves.ready[key] = kept
	mitmLeaves.mu.Unlock()
	for i := 0; i < 2; i++ {
		leaf, err := mitmLeaves.get(context.Background(), "example.com")
		if err == nil || leaf != nil {
			t.Fatalf("revoked trust reused old leaf: leaf=%v err=%v", leaf, err)
		}
	}
	if checks.Load() != 3 {
		t.Fatalf("expected fresh signer refusals, got %d checks", checks.Load())
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
	if mitmConnectionLeafWait > 500*time.Millisecond {
		t.Fatalf("leaf wait %v", mitmConnectionLeafWait)
	}
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

func TestMitmQUICRequiresRecentSignerProof(t *testing.T) {
	app := newFakeMitmApp(t)
	withMitmSigner(t, app, []string{"example.com"}, nil)
	entered := make(chan struct{}, 1)
	resume := make(chan struct{})
	oldIssuer := mitmLeaves.issuer
	t.Cleanup(func() { mitmLeaves.issuer = oldIssuer })
	mitmLeaves.issuer = func(ctx context.Context, host string) (*mitmLeaf, error) {
		entered <- struct{}{}
		<-resume
		return &mitmLeaf{notAfter: time.Now().Add(time.Hour)}, nil
	}
	listed := &C.Metadata{NetWork: C.UDP, Host: "example.com", DstPort: 443}
	if mitmDropsUDP(listed) {
		t.Fatal("unproved signer blocked QUIC")
	}
	<-entered
	if mitmDropsUDP(listed) {
		t.Fatal("pending signer blocked QUIC")
	}
	mitmLeaves.mu.Lock()
	call := mitmLeaves.inflight[mitmLeafKey{runtime: mitmState.Load(), host: "example.com"}]
	mitmLeaves.mu.Unlock()
	if call == nil {
		t.Fatal("probe not registered")
	}
	close(resume)
	<-call.done
	mitmQuicProbe <- struct{}{}
	<-mitmQuicProbe
	if !mitmDropsUDP(listed) {
		t.Fatal("fresh proof did not block QUIC")
	}
	mitmLeaves.mu.Lock()
	mitmLeaves.quicProof[mitmLeafKey{runtime: mitmState.Load(), host: "example.com"}] = time.Now().Add(-time.Second)
	mitmLeaves.mu.Unlock()
	// Keep the proof-expiry check from starting another asynchronous probe.
	mitmQuicProbe <- struct{}{}
	if mitmDropsUDP(listed) {
		t.Fatal("expired proof blocked QUIC")
	}
	<-mitmQuicProbe
	mitmSignerGone()
	if mitmDropsUDP(listed) {
		t.Fatal("disconnected signer blocked QUIC")
	}
}

func TestMitmQUICFailedProbePassesThroughAndPauses(t *testing.T) {
	app := newFakeMitmApp(t)
	withMitmSigner(t, app, []string{"example.com"}, nil)
	called := make(chan struct{})
	oldIssuer := mitmLeaves.issuer
	t.Cleanup(func() { mitmLeaves.issuer = oldIssuer })
	mitmLeaves.issuer = func(ctx context.Context, host string) (*mitmLeaf, error) {
		close(called)
		return nil, errMitmSignDropped
	}
	listed := &C.Metadata{NetWork: C.UDP, Host: "example.com", DstPort: 443}
	if mitmDropsUDP(listed) {
		t.Fatal("unproved signer blocked QUIC")
	}
	<-called
	mitmQuicProbe <- struct{}{}
	<-mitmQuicProbe
	if mitmDropsUDP(listed) {
		t.Fatal("failed signer blocked QUIC")
	}
	if reason := mitmPausedReason(); reason != "appUnavailable" {
		t.Fatalf("pause = %q", reason)
	}
}

func TestMitmSignerReconnectDoesNotReuseOldLeaf(t *testing.T) {
	app := newFakeMitmApp(t)
	withMitmSigner(t, app, []string{"example.com"}, nil)
	oldIssuer := mitmLeaves.issuer
	t.Cleanup(func() { mitmLeaves.issuer = oldIssuer })
	mitmLeaves.clear()
	var issued int
	mitmLeaves.issuer = func(ctx context.Context, host string) (*mitmLeaf, error) {
		issued++
		if issued == 1 {
			return &mitmLeaf{notAfter: time.Now().Add(time.Hour)}, nil
		}
		return nil, errMitmSignDropped
	}
	if _, err := mitmLeaves.get(context.Background(), "example.com"); err != nil {
		t.Fatal(err)
	}
	same := mitmState.Load().setup
	mitmSignerGone()
	applyMitmSetup(&SetupParams{Mitm: &same}, nil)
	if _, err := mitmLeaves.get(context.Background(), "example.com"); err == nil {
		t.Fatal("reused a leaf from the disconnected signer")
	}
	if issued != 2 {
		t.Fatalf("issuer called %d times", issued)
	}
}

func TestUnverifiedQUICCannotReportReadyWhileIndicatorGated(t *testing.T) {
	app := newFakeMitmApp(t)
	withMitmSigner(t, app, []string{"example.com"}, nil)
	mitmQuicProbe <- struct{}{}
	defer func() { <-mitmQuicProbe }()
	metadata := &C.Metadata{NetWork: C.UDP, Host: "example.com", DstPort: 443}
	if mitmDropsUDP(metadata) {
		t.Fatal("unverified QUIC did not pass")
	}
	if status := mitmStatus(false); !status.Enable || status.Paused != "indicatorPending" {
		t.Fatalf("unverified state was reported ready: %+v", status)
	}
	if status := handleMitmStatus(); !status.Enable || status.Paused != "partialConnections" {
		t.Fatalf("potential passthrough not reported: %+v", status)
	}
}

func TestMitmGlobalPauseRejectsLateLeafAndProof(t *testing.T) {
	app := newFakeMitmApp(t)
	withMitmSigner(t, app, []string{"a.example", "b.example"}, nil)
	mitmLeaves.clear()
	oldIssuer := mitmLeaves.issuer
	t.Cleanup(func() { mitmLeaves.issuer = oldIssuer })
	entered := make(chan struct{})
	resume := make(chan struct{})
	var issued atomic.Int32
	mitmLeaves.issuer = func(ctx context.Context, host string) (*mitmLeaf, error) {
		issued.Add(1)
		if host == "b.example" && issued.Load() == 1 {
			close(entered)
			<-resume
			return &mitmLeaf{notAfter: time.Now().Add(time.Hour)}, nil
		}
		return nil, errMitmSignDropped
	}
	result := make(chan error, 1)
	go func() { _, err := mitmLeaves.fresh(context.Background(), "b.example"); result <- err }()
	<-entered
	runtime := mitmState.Load()
	pauseMitm(runtime, "a.example", errMitmSignDropped)
	close(resume)
	if err := <-result; err != errMitmSetupChanged {
		t.Fatalf("late issuance: %v", err)
	}
	mitmLeaves.mu.Lock()
	ready, proof := len(mitmLeaves.ready), len(mitmLeaves.quicProof)
	mitmLeaves.mu.Unlock()
	if ready != 0 || proof != 0 {
		t.Fatal("late issuance repopulated cache")
	}
	mitmPaused.Store(nil)
	if _, err := mitmLeaves.get(context.Background(), "b.example"); err != errMitmSignDropped {
		t.Fatalf("old leaf survived pause: %v", err)
	}
	if issued.Load() != 2 {
		t.Fatalf("issuer called %d times", issued.Load())
	}
}
