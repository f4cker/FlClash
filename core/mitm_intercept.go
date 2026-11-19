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
	// Decrypted over HTTP/2, then the HTTP/2 session to the site failed.
	mitmOutcomeHTTP2Failed      MitmOutcome = "http2Failed"
	mitmOutcomeUnsupportedHello MitmOutcome = "unsupportedHello"
	mitmOutcomeMissingSNI       MitmOutcome = "missingSNI"
	mitmOutcomePrecommit        MitmOutcome = "precommit"
	mitmOutcomeDecrypted        MitmOutcome = "decrypted"
	// The client offered no protocol decryption serves (HTTP/1.1, or h2
	// while HTTP/2 decryption is on); passed through.
	mitmOutcomeHTTP2Only MitmOutcome = "http2Only"
	// Decryption is paused (for every listed host or this one); the
	// connection went through untouched.
	mitmOutcomePaused MitmOutcome = "paused"
)

type MitmConnection struct {
	Id      string      `json:"id"`
	Outcome MitmOutcome `json:"outcome"`
	// Why a paused connection passed through: a reason the status reports.
	PauseReason string `json:"pauseReason,omitempty"`
	// Set, with no outcome, when a rewrite rule first applied or first
	// failed on the connection.
	Rewrite *MitmConnectionRewrite `json:"rewrite,omitempty"`
}

// What rewrite rules did on one connection so far: applied when any
// changed or answered a request, failed when any matched but left the
// message as it was. The hit is the latest of its kind.
type MitmConnectionRewrite struct {
	Applied bool            `json:"applied"`
	Failed  bool            `json:"failed"`
	Hit     *MitmRewriteHit `json:"hit,omitempty"`
}

// Step 5 supplies the always-visible indicator (page bar and tray), so listed
// hosts may be decrypted. This is deliberately not controlled by configuration
// or an RPC; setting it to false disables decryption entirely.
const mitmIndicatorAvailable = true

// The one port decryption looks at: HTTPS. Host entries carry no port, so a
// flow to any other port is never held, read or decrypted. A variable only
// so loopback tests can stand a server in for it.
var mitmHTTPSPort uint16 = 443

// How long a connection waits for its leaf before it is relayed untouched
// (and listed hosts pause). The app signs in memory over local IPC: one
// ECDSA signature and a round trip, a few milliseconds even under load, so
// half a second is two orders of magnitude of headroom. A signer that is
// slower than that is treated as failing; the issuance itself goes on (up
// to mitmLeafWait) and a leaf it brings is cached for the next connection.
var mitmConnectionLeafWait = 500 * time.Millisecond

// A signed leaf may only be reused while its signing proof is recent, and
// never within mitmLeafExpiryMargin of its own expiry. Long sessions also
// prove the app alive through the liveness check, which never takes a cached leaf.
const (
	mitmLeafReuseFor     = mitmLivenessInterval
	mitmLeafExpiryMargin = 5 * time.Minute
	mitmLeafCacheMax     = 512
)

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
	// A nil hook preserves the tunnel's asynchronous peek if gated off.
	if mitmIndicatorAvailable {
		tunnel.TCPInterceptWanted = mitmInterceptWanted
		tunnel.TCPIntercept = mitmIntercept
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

// Concurrent requests for a host under one setup share one issuance.
type mitmLeafKey struct {
	runtime *mitmRuntime
	host    string
}

// A signed leaf is kept per host and CA. A setup that drops the CA (trust
// revoked, the app gone) stops decryption outright, and a new CA is a new
// key, so a kept leaf never outlives the trust it was signed under; a pause
// (the signer failing) empties the cache too.
type mitmReadyKey struct {
	fingerprint string
	host        string
}

type mitmReadyLeaf struct {
	leaf      *mitmLeaf
	reuseTill time.Time
}

type mitmLeafCache struct {
	mu         sync.Mutex
	generation uint64
	issuer     func(context.Context, string) (*mitmLeaf, error)
	inflight   map[mitmLeafKey]*mitmLeafCall
	ready      map[mitmReadyKey]mitmReadyLeaf
	quicProof  map[mitmLeafKey]time.Time
}

var mitmLeaves = &mitmLeafCache{inflight: map[mitmLeafKey]*mitmLeafCall{}}

func (cache *mitmLeafCache) clear() {
	cache.mu.Lock()
	cache.inflight = map[mitmLeafKey]*mitmLeafCall{}
	cache.ready = nil
	cache.quicProof = nil
	cache.generation++
	cache.mu.Unlock()
}

// Forgets kept leaves and prevents in-flight issuances from repopulating them.
func (cache *mitmLeafCache) forget() {
	cache.mu.Lock()
	cache.ready = nil
	cache.quicProof = nil
	cache.inflight = map[mitmLeafKey]*mitmLeafCall{}
	cache.generation++
	cache.mu.Unlock()
}

func mitmReadyKeyOf(runtime *mitmRuntime, host string) mitmReadyKey {
	key := mitmReadyKey{host: host}
	if runtime != nil {
		key.fingerprint = runtime.setup.CAFingerprint
	}
	return key
}

// Under cache.mu.
func (cache *mitmLeafCache) keep(runtime *mitmRuntime, host string, leaf *mitmLeaf) {
	if runtime == nil || leaf == nil || runtime.setup.CAFingerprint == "" {
		return
	}
	now := time.Now()
	till := leaf.notAfter.Add(-mitmLeafExpiryMargin)
	if limit := now.Add(mitmLeafReuseFor); till.After(limit) {
		till = limit
	}
	if !till.After(now) {
		return
	}
	if cache.ready == nil {
		cache.ready = map[mitmReadyKey]mitmReadyLeaf{}
	}
	if len(cache.ready) >= mitmLeafCacheMax {
		for key, kept := range cache.ready {
			if !now.Before(kept.reuseTill) {
				delete(cache.ready, key)
			}
		}
		if len(cache.ready) >= mitmLeafCacheMax {
			cache.ready = map[mitmReadyKey]mitmReadyLeaf{}
		}
	}
	cache.ready[mitmReadyKeyOf(runtime, host)] = mitmReadyLeaf{leaf: leaf, reuseTill: till}
}

// A leaf for host: a kept one while still valid, else a new issuance.
func (cache *mitmLeafCache) get(ctx context.Context, host string) (*mitmLeaf, error) {
	runtime := mitmState.Load()
	cache.mu.Lock()
	if kept, found := cache.ready[mitmReadyKeyOf(runtime, host)]; found {
		if time.Now().Before(kept.reuseTill) {
			cache.mu.Unlock()
			return kept.leaf, nil
		}
		delete(cache.ready, mitmReadyKeyOf(runtime, host))
	}
	cache.mu.Unlock()
	return cache.fresh(ctx, host)
}

// A newly signed leaf, never a kept one: the liveness check's proof that the
// app still signs.
func (cache *mitmLeafCache) fresh(ctx context.Context, host string) (*mitmLeaf, error) {
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
	if call.err == nil && call.leaf != nil {
		cache.keep(key.runtime, host, call.leaf)
		if cache.quicProof == nil || len(cache.quicProof) >= mitmLeafCacheMax {
			cache.quicProof = make(map[mitmLeafKey]time.Time)
		}
		cache.quicProof[key] = time.Now().Add(mitmLivenessInterval)
	}
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
	mitmPaused        atomic.Pointer[mitmPause]
	mitmHostPauses    sync.Map
	mitmPauseLoggedAt atomic.Int64
)

const mitmPauseLogEvery = 10 * time.Second

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
// so and why. A host the app itself says is not listed gets no mark: to the
// user it is not a decryption host at all.
func mitmShownPauseReason(host string) string {
	switch reason := mitmPauseReasonFor(host); reason {
	case "", "notListed":
		return ""
	default:
		return reason
	}
}

func mitmPausedPassThrough(host string) tunnel.TCPInterceptor {
	reason := mitmShownPauseReason(host)
	if reason == "" {
		return nil
	}
	return func(client *N.BufferedConn, remote C.Conn) {
		reportMitmPause(remote, reason)
		N.Relay(client, remote)
	}
}

func reportMitmPause(remote net.Conn, reason string) {
	if id := mitmTrackerID(remote); id != "" {
		sendMitmConnection(&MitmConnection{Id: id, Outcome: mitmOutcomePaused, PauseReason: reason})
	}
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
		reason = "leafUnusable"
	}
	// Publishing the pause and excluding registrations are one critical section.
	previous, published := mitmActive.pauseGlobal(runtime, reason)
	if !published {
		return
	}
	// Each pause that begins or changes is logged; one that keeps extending
	// is logged again at most every mitmPauseLogEvery.
	now := time.Now()
	last := mitmPauseLoggedAt.Load()
	if previous == nil || previous.reason != reason || now.After(previous.until) ||
		now.UnixNano()-last >= int64(mitmPauseLogEvery) {
		mitmPauseLoggedAt.Store(now.UnixNano())
		log.Warnln("[MITM] decryption paused for %s, listed hosts pass through: %s (%s: %v)",
			mitmPauseFor, reason, host, err)
	}
}

// From the metadata alone: could decryption take this flow? Only HTTPS, and
// there a named flow only when its name is listed; a nameless one is read
// for its SNI. Plain HTTP only for URL Rewrite (mitm_plain.go). Every other
// flow dials at once, as without the hook.
func mitmInterceptWanted(metadata *C.Metadata) bool {
	if metadata.DstPort == mitmPlainHTTPPort {
		return mitmPlainWanted(metadata)
	}
	runtime := mitmState.Load()
	if !runtime.decrypting() || metadata.DstPort != mitmHTTPSPort {
		return false
	}
	return metadata.Host == "" || runtime.hosts.Match(normalizeMitmHost(metadata.Host))
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
	if metadata.DstPort == mitmPlainHTTPPort {
		return mitmPlainIntercept(conn, metadata)
	}
	if !mitmInterceptWanted(metadata) {
		return nil
	}
	runtime := mitmState.Load()
	// The first packet is waited for at most mitmFirstByteWait in all; the
	// tunnel's own peek, when it ran, already spent up to its 200 ms of it.
	firstByteWait := mitmFirstByteWait
	if conn.Peeked() && conn.Reader().Buffered() == 0 {
		firstByteWait -= mitmTunnelPeekWait
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
		if metadata.Host != "" && conn.Reader().Buffered() == 0 &&
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
	if !hello.decryptable(runtime.http2()) {
		return mitmPassThroughReporting(mitmOutcomeHTTP2Only)
	}
	// A pause is reported only for the host as listed now; the relay is the
	// same untouched one a nil result gets.
	if mitmPausedFor(host) {
		return mitmPausedPassThrough(host)
	}
	ctx, cancel := context.WithTimeout(context.Background(), mitmConnectionLeafWait)
	defer cancel()
	leaf, err := mitmLeaves.get(ctx, host)
	if err != nil {
		pauseMitm(runtime, host, err)
		if mitmState.Load() != runtime {
			return nil
		}
		return mitmPausedPassThrough(host)
	}
	if mitmState.Load() != runtime || !runtime.hosts.Match(host) {
		return nil
	}
	// Do not mark the tracker as decrypted before TLS commits; this may
	// still take the untouched precommit passthrough path.
	return func(client *N.BufferedConn, remote C.Conn) {
		mitmServeSelected(client, remote, host, leaf, runtime, hello.alpn)
	}
}

// No bytes have been sent upstream at registration; rejection is the last
// safe point for replay-free passthrough on this same connection.
func mitmServeSelected(client *N.BufferedConn, remote C.Conn, host string, leaf *mitmLeaf, runtime *mitmRuntime, clientALPN []string) {
	if outcome := serveMitmOffering(client, remote, host, leaf, runtime, clientALPN); outcome == mitmOutcomePrecommit {
		// A pause that won the race is still shown; a new setup is not.
		if mitmState.Load() == runtime {
			if reason := mitmShownPauseReason(host); reason != "" {
				reportMitmPause(remote, reason)
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

// As serveMitm with a client that offered no ALPN: HTTP/1.1 on both sides.
func serveMitm(client, remote net.Conn, host string, leaf *mitmLeaf, runtime *mitmRuntime) MitmOutcome {
	return serveMitmOffering(client, remote, host, leaf, runtime, nil)
}

// The site is verified in full before the client sees a certificate. The
// site is offered what the client offered and decryption serves (see
// mitmUpstreamProtos); the client is then offered the site's choice alone.
func serveMitmOffering(client, remote net.Conn, host string, leaf *mitmLeaf, runtime *mitmRuntime, clientALPN []string) MitmOutcome {
	remove, ok := mitmActive.add(runtime, host, client, remote)
	if !ok {
		return mitmOutcomePrecommit
	}
	defer remove()
	livenessCtx, stopLiveness := context.WithCancel(context.Background())
	defer stopLiveness()
	go monitorMitmLiveness(livenessCtx, runtime, host, mitmLivenessInterval, mitmLeaves.fresh)
	remoteIdle := &mitmIdleConn{Conn: remote, timeout: mitmIdleTimeout}
	upstream := tls.Client(mitmStrictTLSConn{remoteIdle}, &tls.Config{
		ServerName: host,
		RootCAs:    mitmUpstreamRoots,
		NextProtos: mitmUpstreamProtos(clientALPN, runtime.http2()),
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
	negotiated := upstream.ConnectionState().NegotiatedProtocol
	clientProtos := mitmClientProtos(clientALPN, negotiated)
	if clientProtos == nil {
		// The client offered h2 alone and the site does not speak it.
		log.Warnln("[MITM] %s: the client speaks only HTTP/2 and the site does not", host)
		return mitmOutcomeUpstreamFailed
	}
	clientIdle := &mitmIdleConn{Conn: client, timeout: mitmIdleTimeout}
	server := tls.Server(clientIdle, &tls.Config{
		Certificates: []tls.Certificate{leaf.cert},
		NextProtos:   clientProtos,
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
	http2 := negotiated == mitmALPNHTTP2
	if http2 && server.ConnectionState().NegotiatedProtocol != mitmALPNHTTP2 {
		log.Debugln("[MITM] %s: the client did not take HTTP/2", host)
		return mitmOutcomeClientFailed
	}
	// The tracker exists by now; neither fallback nor a failed handshake may
	// publish success. Later HTTP failure can still be reported separately.
	reportMitmOutcome(remote, mitmOutcomeDecrypted)
	connection := mitmTrackerID(remote)
	mitmCaptures.openConnection(connection)
	defer mitmCaptures.closeConnection(connection)
	allowed := func() bool { return mitmState.Load() == runtime && !mitmPausedFor(host) }
	control := &mitmDuplexControl{client: clientIdle, upstream: remoteIdle, connection: connection, port: mitmHTTPSPort}
	if http2 {
		if err := mitmHTTP2Proxy(server, upstream, host, allowed, control); err != nil {
			_ = client.Close()
			return mitmOutcomeHTTP2Failed
		}
		return ""
	}
	if err := mitmHTTP1Duplex(server, upstream, host, allowed, control); err != nil {
		// Do not authenticate a truncated close-delimited response with a
		// close_notify. Abort the raw transport before deferred TLS cleanup.
		_ = client.Close()
		return mitmOutcomeHTTP1Failed
	}
	return ""
}

var mitmQuicProbe = make(chan struct{}, 1)

// Without a recent host-specific signing proof, QUIC passes while one bounded
// probe runs. A dead signer must not strand a QUIC-only client indefinitely.
func mitmDropsUDP(metadata *C.Metadata) bool {
	if metadata.DstPort != mitmHTTPSPort || metadata.Host == "" {
		return false
	}
	runtime := mitmState.Load()
	if !runtime.decrypting() || runtime.setup.AutoQuicBlock != nil && !*runtime.setup.AutoQuicBlock {
		return false
	}
	host := normalizeMitmHost(metadata.Host)
	if !runtime.hosts.Match(host) || mitmPausedFor(host) {
		return false
	}
	mitmLeaves.mu.Lock()
	proof := mitmLeaves.quicProof[mitmLeafKey{runtime: runtime, host: host}]
	mitmLeaves.mu.Unlock()
	if time.Now().Before(proof) && mitmState.Load() == runtime && !mitmPausedFor(host) {
		return true
	}
	select {
	case mitmQuicProbe <- struct{}{}:
		go func() {
			defer func() { <-mitmQuicProbe }()
			ctx, cancel := context.WithTimeout(context.Background(), mitmLeafWait)
			defer cancel()
			if _, err := mitmLeaves.fresh(ctx, host); err != nil {
				pauseMitm(runtime, host, err)
			}
		}()
	default:
	}
	return false
}
