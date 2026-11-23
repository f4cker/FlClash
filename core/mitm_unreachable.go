package core

import (
	"bufio"
	"context"
	"io"
	"net"
	"net/http"
	"strings"
	"sync"

	N "github.com/metacubex/mihomo/common/net"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/log"
	"github.com/metacubex/mihomo/tunnel"
)

// A host a request script or Map Local rule names (Script Hub's script.hub,
// which does not exist) is still decrypted when its dial or TLS fails: the
// rules answer what they can, the rest gets a 502, and the failed site is
// never written to. Every other host, and any bad certificate, fails as before.

const mitmUnreachableText = "Flash: the site could not be reached and no script answered.\n"

// Tracked in place of a failed dial; it is closed, so any other use of it
// ends the flow as the failed dial did.
type mitmUnreachableConn struct {
	N.ExtendedConn
	chain C.Chain
}

func (c *mitmUnreachableConn) Chains() C.Chain                 { return c.chain }
func (c *mitmUnreachableConn) ProviderChains() C.Chain         { return nil }
func (c *mitmUnreachableConn) AppendToChains(a C.ProxyAdapter) { c.chain = append(c.chain, a.Name()) }
func (c *mitmUnreachableConn) RemoteDestination() string       { return "" }

var mitmSiteless sync.Map // host by flow, until the tunnel runs its interceptor or asks for a stand-in

func mitmOfferStandIn(metadata *C.Metadata, intercept tunnel.TCPInterceptor, host string) tunnel.TCPInterceptor {
	if intercept == nil || host == "" {
		return intercept
	}
	mitmSiteless.Store(metadata, host)
	return func(client *N.BufferedConn, remote C.Conn) {
		mitmSiteless.Delete(metadata)
		intercept(client, remote)
	}
}

func mitmInterceptDone(metadata *C.Metadata) { mitmSiteless.Delete(metadata) }

func mitmUnreachableStandIn(metadata *C.Metadata, proxy C.Proxy) C.Conn {
	chosen, ok := mitmSiteless.LoadAndDelete(metadata)
	if !ok {
		return nil
	}
	host := chosen.(string)
	engine := mitmRewrite.Load()
	switch {
	case metadata.DstPort == mitmHTTPSPort:
		if !mitmDecrypts(host) || mitmPausedFor(host) || !engine.answersWithoutSite(host) {
			return nil
		}
	case metadata.DstPort == mitmPlainHTTPPort:
		if !mitmPlainWanted(metadata) || !engine.forcesHTTPEngine(host) || !engine.answersWithoutSite(host) {
			return nil
		}
	default:
		return nil
	}
	near, far := net.Pipe()
	_ = far.Close()
	_ = near.Close()
	log.Infoln("[MITM] the site could not be reached; its rules answer instead")
	return &mitmUnreachableConn{ExtendedConn: N.NewExtendedConn(near), chain: C.Chain{proxy.Name()}}
}

// The flow's own connection, one below the tracker: anything further down
// may be a session other flows share.
func mitmCloseUnderTracker(remote net.Conn) {
	if tracker, ok := remote.(interface{ Upstream() any }); ok {
		if conn, ok := tracker.Upstream().(io.Closer); ok {
			_ = conn.Close()
		}
	}
}

func mitmUnreachable(remote net.Conn) bool {
	var conn any = remote
	for range 8 {
		if _, ok := conn.(*mitmUnreachableConn); ok {
			return true
		}
		wrapper, ok := conn.(interface{ Upstream() any })
		if !ok {
			return false
		}
		conn = wrapper.Upstream()
	}
	return false
}

func serveMitmWithoutSite(client, remote net.Conn, host string, leaf *mitmLeaf, runtime *mitmRuntime, clientALPN []string, failed MitmOutcome) MitmOutcome {
	if !mitmRewrite.Load().answersWithoutSite(host) {
		return failed
	}
	protos := mitmClientProtos(clientALPN, "")
	if protos == nil {
		log.Warnln("[MITM] the client speaks only HTTP/2 and the site could not be reached")
		return failed
	}
	ctx, cancel := context.WithTimeout(context.Background(), mitmHandshakeWait)
	defer cancel()
	server, clientIdle, outcome := mitmClientHandshake(ctx, client, leaf, protos)
	if server == nil {
		return outcome
	}
	defer func() { clientIdle.closing.Store(true); _ = server.Close() }()
	reportMitmOutcome(remote, mitmOutcomeDecrypted)
	connection := mitmTrackerID(remote)
	mitmCaptures.openConnection(connection)
	defer mitmCaptures.closeConnection(connection)
	allowed := func() bool { return mitmState.Load() == runtime && !mitmPausedFor(host) }
	control := &mitmDuplexControl{client: clientIdle, connection: connection, port: mitmHTTPSPort}
	if err := mitmHTTP1WithoutSite(server, host, allowed, control); err != nil {
		_ = client.Close()
		return mitmOutcomeHTTP1Failed
	}
	return ""
}

func mitmHTTP1WithoutSite(client io.ReadWriter, host string, allowed func() bool, control *mitmDuplexControl) error {
	near, far := net.Pipe()
	defer near.Close()
	go mitmAnswerUnreachable(far)
	control.upstream = &mitmIdleConn{Conn: near, timeout: control.client.timeout}
	return mitmHTTP1Duplex(client, control.upstream, host, allowed, control)
}

func mitmAnswerUnreachable(conn net.Conn) {
	defer conn.Close()
	requests := bufio.NewReader(conn)
	for {
		req, err := http.ReadRequest(requests)
		if err != nil {
			return
		}
		if _, err := io.Copy(io.Discard, req.Body); err != nil {
			return
		}
		resp := &http.Response{
			StatusCode: http.StatusBadGateway, ProtoMajor: 1, ProtoMinor: 1, Request: req, Close: req.Close,
			Header: http.Header{
				"Content-Type":  {"text/plain; charset=utf-8"},
				"Cache-Control": {"no-store"},
			},
			ContentLength: int64(len(mitmUnreachableText)),
			Body:          io.NopCloser(strings.NewReader(mitmUnreachableText)),
		}
		if err := resp.Write(conn); err != nil || req.Close {
			return
		}
	}
}
