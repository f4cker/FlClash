package core

import (
	"bufio"
	"bytes"
	"net"
	"net/http"
	"time"

	N "github.com/metacubex/mihomo/common/net"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
)

// Plain HTTP (port 80) is read only for URL Rewrite's reject and redirects,
// only while the MITM switch is on, and only on a flow to a named host some
// such rule's pattern may match. A flow is taken when its first request is
// one the HTTP/1.1 session serves (origin-form HTTP/1.1, no CONNECT or
// Upgrade, Host the flow's own); anything else is relayed untouched, every
// byte unread. A taken flow forwards each request it does not answer as it
// came: nothing else is rewritten, and capture records only the requests
// a rule answered.

// A variable only so loopback tests can stand a server in for it.
var mitmPlainHTTPPort uint16 = 80

// Plain HTTP keep-alive connections idle far longer than decrypted ones
// are allowed to; a quiet one ends cleanly after this.
var mitmPlainIdleTimeout = 5 * time.Minute

// Could a URL Rewrite answer a request of this flow? From the metadata
// alone, so every other flow dials at once.
func mitmPlainWanted(metadata *C.Metadata) bool {
	if metadata.DstPort != mitmPlainHTTPPort || metadata.Host == "" {
		return false
	}
	runtime := mitmState.Load()
	if runtime == nil || !runtime.setup.Enable {
		return false
	}
	engine := mitmRewrite.Load()
	return engine != nil && engine.plain.mayMatch(normalizeMitmHost(metadata.Host))
}

func mitmPlainIntercept(conn *N.BufferedConn, metadata *C.Metadata) tunnel.TCPInterceptor {
	if !mitmPlainWanted(metadata) {
		return nil
	}
	host := normalizeMitmHost(metadata.Host)
	wait := mitmFirstByteWait
	if conn.Peeked() && conn.Reader().Buffered() == 0 {
		wait -= mitmTunnelPeekWait
	}
	if !mitmPlainFirstRequest(conn, host, wait) {
		return nil
	}
	return func(client *N.BufferedConn, remote C.Conn) {
		serveMitmPlain(client, remote, host)
	}
}

// Whether the flow's first request is one the session serves. Peeks only.
func mitmPlainFirstRequest(conn *N.BufferedConn, host string, firstByteWait time.Duration) bool {
	defer conn.SetReadDeadline(time.Time{})
	if conn.Reader().Buffered() == 0 {
		_ = conn.SetReadDeadline(time.Now().Add(firstByteWait))
		if _, err := conn.Peek(1); err != nil {
			return false
		}
	}
	// A request line starts with a method in capitals; TLS and the rest
	// are left alone at once.
	if first, err := conn.Peek(1); err != nil || first[0] < 'A' || first[0] > 'Z' {
		return false
	}
	_ = conn.SetReadDeadline(time.Now().Add(mitmHelloWait))
	// Within BufferedConn's buffer: a larger head is relayed untouched.
	if err := mitmPeekHeader(conn.Reader()); err != nil {
		return false
	}
	head, err := conn.Peek(conn.Reader().Buffered())
	if err != nil {
		return false
	}
	req, err := http.ReadRequest(bufio.NewReader(bytes.NewReader(head)))
	if err != nil {
		return false
	}
	return req.ProtoMajor == 1 && req.ProtoMinor == 1 && req.Method != http.MethodConnect &&
		!req.URL.IsAbs() && req.URL.Host == "" && req.Header.Get("Upgrade") == "" &&
		mitmRequestHost(req.Host) == host
}

// Serves a taken plain flow until either side ends it or the switch goes
// off; the tunnel closes both connections afterwards.
func serveMitmPlain(client net.Conn, remote net.Conn, host string) {
	connection := mitmTrackerID(remote)
	mitmCaptures.openConnection(connection)
	defer mitmCaptures.closeConnection(connection)
	clientIdle := &mitmIdleConn{Conn: client, timeout: mitmPlainIdleTimeout}
	remoteIdle := &mitmIdleConn{Conn: remote, timeout: mitmPlainIdleTimeout}
	allowed := func() bool {
		runtime := mitmState.Load()
		return runtime != nil && runtime.setup.Enable
	}
	control := &mitmDuplexControl{client: clientIdle, upstream: remoteIdle, connection: connection, port: mitmPlainHTTPPort, plain: true}
	_ = mitmHTTP1Duplex(clientIdle, remoteIdle, host, allowed, control)
}
