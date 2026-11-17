package core

import (
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/tls"
	"crypto/x509"
	"errors"
	"io"
	"net"
	"sync"
	"sync/atomic"
	"time"

	N "github.com/metacubex/mihomo/common/net"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/log"
	"github.com/metacubex/mihomo/tunnel"
)

// What became of a listed connection that was not decrypted end to end. The
// request list shows it; nothing of the traffic itself is in it.
type MitmOutcome string

const (
	// The client refused the app's certificate: pinned, or the root untrusted.
	mitmOutcomeRefused MitmOutcome = "refused"
	// The site's own certificate failed the system's verification.
	mitmOutcomeUpstreamCertificate MitmOutcome = "upstreamCertificate"
	mitmOutcomeUpstreamFailed      MitmOutcome = "upstreamFailed"
	mitmOutcomeClientFailed        MitmOutcome = "clientFailed"
	mitmOutcomeHTTP1Failed         MitmOutcome = "http1Failed"
	mitmOutcomeUnsupportedHello    MitmOutcome = "unsupportedHello"
	mitmOutcomeMissingSNI          MitmOutcome = "missingSNI"
	mitmOutcomePrecommit           MitmOutcome = "precommit"
	mitmOutcomeDecrypted           MitmOutcome = "decrypted"
	// The client offered only protocols other than HTTP/1.1; passed through.
	mitmOutcomeHTTP2Only MitmOutcome = "http2Only"
	// Decryption is paused (for every listed host or this one); the
	// connection went through untouched.
	mitmOutcomePaused MitmOutcome = "paused"
)

type MitmConnection struct {
	Id      string      `json:"id"`
	Outcome MitmOutcome `json:"outcome"`
}

// Decryption must remain disabled until step 5 supplies an always-visible indicator.
// This is deliberately not controlled by configuration or an RPC.
const mitmIndicatorAvailable = false

// UDP is never blocked until live signer and trust state can be verified.
const mitmQUICLivenessAvailable = false

const (
	mitmLeafWait      = 8 * time.Second
	mitmHandshakeWait = 10 * time.Second
	mitmPauseFor      = 30 * time.Second
	// A live session must obtain a fresh CA-signed leaf every interval. The
	// app checks trust before signing; an 8-second issuance deadline bounds a
	// lost/stalled response. Concurrent issuance can be shared for up to eight
	// seconds, so detection is at most 26 seconds plus scheduler/OS stalls:
	// one issuance age + 10-second interval + next issuance deadline. This is
	// not instantaneous external trust-revocation notification.
	mitmLivenessInterval = 10 * time.Second
)

// A variable only so socket tests can shorten it. An idle client or site at
// a message boundary ends the session cleanly (close_notify, no failure).
var mitmIdleTimeout = 30 * time.Second

var (
	sendMitmConnection = func(connection *MitmConnection) bool {
		return sendMessage(MitmConnectionMessage, connection)
	}
	// Tests verify the site against their own root; nil is the system's.
	mitmUpstreamRoots *x509.CertPool
)

func init() {
	// A nil hook preserves the tunnel's asynchronous peek while gated off.
	if mitmIndicatorAvailable {
		tunnel.TCPIntercept = mitmIntercept
	}
	if mitmIndicatorAvailable && mitmQUICLivenessAvailable {
		tunnel.UDPDrop = mitmDropsUDP
	}
}

type mitmLeaf struct {
	cert     tls.Certificate
	notAfter time.Time
}

type mitmLeafCall struct {
	done chan struct{}
	leaf *mitmLeaf
	err  error
}

// Coalesce concurrent requests only. Do not reuse signed leaves for later
// connections: the app may have exited, revoked trust, or removed the key.
type mitmLeafKey struct {
	runtime *mitmRuntime
	host    string
}

type mitmLeafCache struct {
	mu         sync.Mutex
	generation uint64
	issuer     func(context.Context, string) (*mitmLeaf, error)
	inflight   map[mitmLeafKey]*mitmLeafCall
}

var mitmLeaves = &mitmLeafCache{inflight: map[mitmLeafKey]*mitmLeafCall{}}

func (cache *mitmLeafCache) clear() {
	cache.mu.Lock()
	cache.inflight = map[mitmLeafKey]*mitmLeafCall{}
	cache.generation++
	cache.mu.Unlock()
}

func (cache *mitmLeafCache) get(ctx context.Context, host string) (*mitmLeaf, error) {
	key := mitmLeafKey{runtime: mitmState.Load(), host: host}
	cache.mu.Lock()
	call := cache.inflight[key]
	if call == nil {
		call = &mitmLeafCall{done: make(chan struct{})}
		cache.inflight[key] = call
		go cache.issue(key, host, call, cache.generation)
	}
	cache.mu.Unlock()
	select {
	case <-call.done:
		return call.leaf, call.err
	case <-ctx.Done():
		return nil, ctx.Err()
	}
}

var errMitmSetupChanged = errors.New("MITM setup changed during signing")

func (cache *mitmLeafCache) issue(key mitmLeafKey, host string, call *mitmLeafCall, generation uint64) {
	ctx, cancel := context.WithTimeout(context.Background(), mitmLeafWait)
	defer cancel()
	issuer := cache.issuer
	if issuer == nil {
		issuer = issueMitmLeaf
	}
	call.leaf, call.err = issuer(ctx, host)
	cache.mu.Lock()
	if cache.generation != generation {
		call.leaf, call.err = nil, errMitmSetupChanged
		cache.mu.Unlock()
		close(call.done)
		return
	}
	delete(cache.inflight, key)
	cache.mu.Unlock()
	close(call.done)
}

func issueMitmLeaf(ctx context.Context, host string) (*mitmLeaf, error) {
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		return nil, err
	}
	leaf, err := requestMitmLeaf(ctx, host, &key.PublicKey)
	if err != nil {
		return nil, err
	}
	return &mitmLeaf{
		cert:     tls.Certificate{Certificate: [][]byte{leaf.Raw}, PrivateKey: key, Leaf: leaf},
		notAfter: leaf.NotAfter,
	}, nil
}

type mitmPause struct {
	runtime *mitmRuntime
	until   time.Time
	reason  string
}

var (
	mitmPaused     atomic.Pointer[mitmPause]
	mitmHostPauses sync.Map
)

// Why decryption is passing every listed connection through, or "".
func mitmPausedReason() string {
	if pause := mitmPaused.Load(); pause != nil && pause.runtime == mitmState.Load() && time.Now().Before(pause.until) {
		return pause.reason
	}
	return ""
}

func mitmPausedFor(host string) bool {
	return mitmPauseReasonFor(host) != ""
}

// Why host passes through now, or "": the global pause first, else its own.
func mitmPauseReasonFor(host string) string {
	if reason := mitmPausedReason(); reason != "" {
		return reason
	}
	value, found := mitmHostPauses.Load(host)
	if !found {
		return ""
	}
	pause := value.(mitmPause)
	if pause.runtime == mitmState.Load() && time.Now().Before(pause.until) {
		return pause.reason
	}
	return ""
}

// A paused listed host goes through untouched, and the request list says
// so. A host the app itself says is not listed gets no mark: to the user it
// is not a decryption host at all.
func mitmPausedOutcomeFor(host string) MitmOutcome {
	switch mitmPauseReasonFor(host) {
	case "", "notListed":
		return ""
	}
	return mitmOutcomePaused
}

func mitmPassThroughReporting(outcome MitmOutcome) tunnel.TCPInterceptor {
	return func(client *N.BufferedConn, remote C.Conn) {
		reportMitmOutcome(remote, outcome)
		N.Relay(client, remote)
	}
}

// A failure that says nothing about host alone pauses every listed host, so
// the next connections pass through at once instead of each waiting.
func pauseMitm(runtime *mitmRuntime, host string, err error) {
	if mitmState.Load() != runtime {
		return
	}
	var refusal mitmAppRefusal
	reason := ""
	switch {
	case errors.Is(err, errMitmNotListed), errors.Is(err, errMitmSetupChanged):
		return
	case errors.As(err, &refusal):
		switch refusal {
		case "notListed", "badKey":
			mitmActive.pauseHost(runtime, host, string(refusal))
			log.Debugln("[MITM] %s passed through: the app refused it (%s)", host, string(refusal))
			return
		}
		reason = string(refusal)
	case errors.Is(err, errMitmSignDropped):
		reason = "appUnavailable"
	case errors.Is(err, context.DeadlineExceeded):
		reason = "signTimeout"
	default:
		reason = "leafRejected"
	}
	// Publishing the pause and excluding registrations are one critical section.
	previous, published := mitmActive.pauseGlobal(runtime, reason)
	if !published {
		return
	}
	if previous == nil || previous.reason != reason || time.Now().After(previous.until) {
		log.Infoln("[MITM] decryption paused, listed hosts pass through: %s", reason)
	}
}

// Decides before the dial: a listed host gets a leaf first, and any failure
// leaves the connection as it came, every byte unread.
func mitmIntercept(conn *N.BufferedConn, metadata *C.Metadata) tunnel.TCPInterceptor {
	if !mitmIndicatorAvailable {
		return nil
	}
	return mitmInterceptEligible(conn, metadata)
}

// Split out only so socket tests can exercise the real selector while the
// production hook remains hard-gated until the always-visible indicator.
func mitmInterceptEligible(conn *N.BufferedConn, metadata *C.Metadata) tunnel.TCPInterceptor {
	runtime := mitmState.Load()
	if !runtime.decrypting() {
		return nil
	}
	if metadata.Host != "" && !runtime.hosts.Match(normalizeMitmHost(metadata.Host)) {
		return nil
	}
	firstByteWait := mitmHelloWait
	if metadata.Host == "" && metadata.DstPort != 443 {
		firstByteWait = mitmFirstByteWait
	}
	hello, err := peekMitmClientHelloWithin(conn, firstByteWait)
	passThroughUnsupported := mitmPassThroughReporting(mitmOutcomeUnsupportedHello)
	if errors.Is(err, errMitmHelloUnsupported) {
		// A TLS record began but no hello could be read, so no SNI either.
		// The host is listed, or (IP-only flow) unknown: in both cases this
		// is an explicit, indeterminate passthrough, never a silent one. An
		// IP-only flow to an unlisted site can therefore warn too.
		return passThroughUnsupported
	}
	if err != nil {
		// A listed HTTPS host whose client sent nothing within the wait
		// (e.g. a late-binding pool) is passed through, but visibly.
		var timeout interface{ Timeout() bool }
		if metadata.Host != "" && metadata.DstPort == 443 && conn.Reader().Buffered() == 0 &&
			errors.As(err, &timeout) && timeout.Timeout() {
			return passThroughUnsupported
		}
		return nil
	}
	if hello.serverName == "" {
		if metadata.Host == "" {
			return nil
		}
		return mitmPassThroughReporting(mitmOutcomeMissingSNI)
	}
	host := normalizeMitmHost(hello.serverName)
	if !runtime.hosts.Match(host) || (metadata.Host != "" && normalizeMitmHost(metadata.Host) != host) {
		return nil
	}
	if !hello.speaksHTTP1() {
		return mitmPassThroughReporting(mitmOutcomeHTTP2Only)
	}
	// A pause is reported only for the host as listed now; the relay is the
	// same untouched one a nil result gets.
	if mitmPausedFor(host) {
		if outcome := mitmPausedOutcomeFor(host); outcome != "" {
			return mitmPassThroughReporting(outcome)
		}
		return nil
	}
	ctx, cancel := context.WithTimeout(context.Background(), mitmLeafWait)
	defer cancel()
	leaf, err := mitmLeaves.get(ctx, host)
	if err != nil {
		pauseMitm(runtime, host, err)
		if outcome := mitmPausedOutcomeFor(host); outcome != "" && mitmState.Load() == runtime {
			return mitmPassThroughReporting(outcome)
		}
		return nil
	}
	if mitmState.Load() != runtime || !runtime.hosts.Match(host) {
		return nil
	}
	// Do not mark the tracker as decrypted before TLS commits; this may
	// still take the untouched precommit passthrough path.
	return func(client *N.BufferedConn, remote C.Conn) {
		mitmServeSelected(client, remote, host, leaf, runtime)
	}
}

// No bytes have been sent upstream at registration; rejection is the last
// safe point for replay-free passthrough on this same connection.
func mitmServeSelected(client *N.BufferedConn, remote C.Conn, host string, leaf *mitmLeaf, runtime *mitmRuntime) {
	if outcome := serveMitm(client, remote, host, leaf, runtime); outcome == mitmOutcomePrecommit {
		// A pause that won the race is still shown; a new setup is not.
		if mitmState.Load() == runtime {
			if paused := mitmPausedOutcomeFor(host); paused != "" {
				reportMitmOutcome(remote, paused)
			}
		}
		N.Relay(client, remote)
	} else if outcome != "" {
		reportMitmOutcome(remote, outcome)
	}
}

func reportMitmOutcome(remote net.Conn, outcome MitmOutcome) {
	if id := mitmTrackerID(remote); id != "" {
		sendMitmConnection(&MitmConnection{Id: id, Outcome: outcome})
	}
}

// The ID the request list knows a connection by, from its tracker.
func mitmTrackerID(remote net.Conn) string {
	if tracker, ok := remote.(interface{ ID() string }); ok {
		return tracker.ID()
	}
	return ""
}

// Go TLS accepts bare transport EOF at a record boundary as clean EOF. That
// is unsafe for close-delimited HTTP bodies: require an authenticated alert.
var errMitmUncleanTLS = errors.New("upstream TLS closed without close_notify")

type mitmStrictTLSConn struct{ net.Conn }

func (c mitmStrictTLSConn) Read(p []byte) (int, error) {
	n, err := c.Conn.Read(p)
	if errors.Is(err, io.EOF) {
		if n > 0 {
			return n, nil
		}
		return 0, errMitmUncleanTLS
	}
	return n, err
}

// The site is verified in full before the client sees a certificate, and
// both sides speak HTTP/1.1 alone.
func serveMitm(client, remote net.Conn, host string, leaf *mitmLeaf, runtime *mitmRuntime) MitmOutcome {
	remove, ok := mitmActive.add(runtime, host, client, remote)
	if !ok {
		return mitmOutcomePrecommit
	}
	defer remove()
	livenessCtx, stopLiveness := context.WithCancel(context.Background())
	defer stopLiveness()
	go monitorMitmLiveness(livenessCtx, runtime, host, mitmLivenessInterval, mitmLeaves.get)
	remoteIdle := &mitmIdleConn{Conn: remote, timeout: mitmIdleTimeout}
	upstream := tls.Client(mitmStrictTLSConn{remoteIdle}, &tls.Config{
		ServerName: host,
		RootCAs:    mitmUpstreamRoots,
		NextProtos: []string{"http/1.1"},
		MinVersion: tls.VersionTLS12,
	})
	ctx, cancel := context.WithTimeout(context.Background(), mitmHandshakeWait)
	defer cancel()
	if err := upstream.HandshakeContext(ctx); err != nil {
		var verification *tls.CertificateVerificationError
		if errors.As(err, &verification) {
			log.Warnln("[MITM] %s: the site's certificate failed verification: %v", host, verification.Err)
			return mitmOutcomeUpstreamCertificate
		}
		log.Warnln("[MITM] %s: TLS to the site failed: %v", host, err)
		return mitmOutcomeUpstreamFailed
	}
	// Once the upstream handshake commits, close its TLS wrapper on exit.
	defer func() { remoteIdle.closing.Store(true); _ = upstream.Close() }()
	clientIdle := &mitmIdleConn{Conn: client, timeout: mitmIdleTimeout}
	server := tls.Server(clientIdle, &tls.Config{
		Certificates: []tls.Certificate{leaf.cert},
		NextProtos:   []string{"http/1.1"},
		MinVersion:   tls.VersionTLS12,
	})
	if err := server.HandshakeContext(ctx); err != nil {
		var alert *net.OpError
		if errors.As(err, &alert) && alert.Op == "remote error" {
			log.Infoln("[MITM] %s: the client refused the decryption certificate: %v", host, err)
			return mitmOutcomeRefused
		}
		log.Debugln("[MITM] %s: TLS from the client failed: %v", host, err)
		return mitmOutcomeClientFailed
	}
	// Closing the wrapper emits close_notify before the tunnel closes raw TCP.
	// The idle wrapper caps the alert write so a stalled peer cannot hang exit.
	defer func() { clientIdle.closing.Store(true); _ = server.Close() }()
	// The tracker exists by now; neither fallback nor a failed handshake may
	// publish success. Later HTTP failure can still be reported separately.
	reportMitmOutcome(remote, mitmOutcomeDecrypted)
	connection := mitmTrackerID(remote)
	mitmCaptures.openConnection(connection)
	defer mitmCaptures.closeConnection(connection)
	if err := mitmHTTP1Duplex(server, upstream, host, func() bool { return mitmState.Load() == runtime && !mitmPausedFor(host) }, &mitmDuplexControl{client: clientIdle, upstream: remoteIdle, connection: connection}); err != nil {
		// Do not authenticate a truncated close-delimited response with a
		// close_notify. Abort the raw transport before deferred TLS cleanup.
		_ = client.Close()
		return mitmOutcomeHTTP1Failed
	}
	return ""
}

// QUIC to a host being decrypted is refused so the client falls back to TCP;
// while decryption is paused it goes through.
func mitmDropsUDP(metadata *C.Metadata) bool {
	if !mitmIndicatorAvailable || !mitmQUICLivenessAvailable || metadata.DstPort != 443 || metadata.Host == "" {
		return false
	}
	runtime := mitmState.Load()
	if runtime == nil || runtime.setup.AutoQuicBlock != nil && !*runtime.setup.AutoQuicBlock {
		return false
	}
	host := normalizeMitmHost(metadata.Host)
	return mitmDecrypts(host) && !mitmPausedFor(host)
}
