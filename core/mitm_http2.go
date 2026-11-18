package core

import (
	"context"
	"errors"
	"io"
	"net"
	"net/http"
	"net/http/httptrace"
	"net/textproto"
	"net/url"
	"slices"
	"strings"
	"sync"

	"github.com/metacubex/mihomo/log"
	"golang.org/x/net/http2"
)

const (
	mitmALPNHTTP1 = "http/1.1"
	mitmALPNHTTP2 = "h2"
)

// What the site is offered: the protocols the client offered that decryption
// can serve, in the client's order. A client that offered none gets
// HTTP/1.1, as before HTTP/2 decryption.
//
// The site is asked first and the client is then offered exactly what the
// site chose (mirroring): both sides of a decrypted connection always speak
// the same protocol, so each h2 stream maps to one upstream stream and no
// h2↔1.1 translation is ever needed. A client that offered both and a site
// that only speaks 1.1 end up on 1.1 on both sides; a client that offered
// h2 alone and a site without h2 is not served (as the site itself would
// not have served it).
func mitmUpstreamProtos(clientALPN []string, http2 bool) []string {
	if clientALPN == nil {
		return []string{mitmALPNHTTP1}
	}
	protos := make([]string, 0, 2)
	for _, proto := range clientALPN {
		if (proto == mitmALPNHTTP1 || proto == mitmALPNHTTP2 && http2) && !slices.Contains(protos, proto) {
			protos = append(protos, proto)
		}
	}
	return protos
}

// What the client is offered once the site has chosen: the site's choice
// alone, or nil when the client cannot speak it.
func mitmClientProtos(clientALPN []string, negotiated string) []string {
	if negotiated == mitmALPNHTTP2 {
		return []string{mitmALPNHTTP2}
	}
	// No ALPN from the site means HTTP/1.1.
	if clientALPN == nil || slices.Contains(clientALPN, mitmALPNHTTP1) {
		return []string{mitmALPNHTTP1}
	}
	return nil
}

// Reports a read error on the upstream connection once, so the client side
// is ended when the site is gone rather than left accepting streams that
// can only fail.
type mitmWatchedConn struct {
	net.Conn
	once sync.Once
	dead chan struct{}
}

func (c *mitmWatchedConn) Read(p []byte) (int, error) {
	n, err := c.Conn.Read(p)
	if err != nil {
		c.once.Do(func() { close(c.dead) })
	}
	return n, err
}

// The HTTP/2 counterpart of mitmHTTP1Duplex: client and upstream are the two
// TLS connections, both having negotiated h2. Every client stream becomes
// one upstream stream on the single upstream connection; headers, bodies and
// trailers stream in both directions at once (gRPC bidi included), and
// nothing is buffered beyond the HTTP/2 flow-control windows. Capture
// records each stream like an HTTP/1.1 exchange, within the same caps.
// Returns when the client connection ends, after which the caller closes both.
func mitmHTTP2Proxy(client, upstream net.Conn, host string, allowed func() bool, control *mitmDuplexControl) error {
	// Silent peers are pinged well within the idle wrappers' read timeout, so
	// a long-lived quiet stream (a gRPC watch) is kept while a dead peer is not.
	ping := mitmIdleTimeout / 3
	watched := &mitmWatchedConn{Conn: upstream, dead: make(chan struct{})}
	transport := &http2.Transport{
		// Never ask for or undo a content coding the client did not.
		DisableCompression: true,
		ReadIdleTimeout:    ping,
		PingTimeout:        ping,
	}
	cc, err := transport.NewClientConn(watched)
	if err != nil {
		log.Warnln("[MITM] %s: HTTP/2 to the site failed: %v", host, err)
		return err
	}
	defer cc.Close()
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() {
		select {
		case <-watched.dead:
			// The site is gone: in-flight streams have failed already, and
			// the client reconnects for new ones.
			if control != nil {
				control.stopAll()
			} else {
				_ = client.Close()
			}
		case <-ctx.Done():
		}
	}()
	server := &http2.Server{
		IdleTimeout:     mitmIdleTimeout,
		ReadIdleTimeout: ping,
		PingTimeout:     ping,
	}
	handler := &mitmHTTP2Handler{cc: cc, host: host, allowed: allowed, connection: control.captureConnection()}
	server.ServeConn(client, &http2.ServeConnOpts{Context: ctx, Handler: handler})
	return nil
}

type mitmHTTP2Handler struct {
	cc         *http2.ClientConn
	host       string
	allowed    func() bool
	connection string
}

// Sent on unchanged except where HTTP/2 itself requires otherwise; Go's
// server would add Content-Type and Date, which are suppressed when the
// site sent none.
func (h *mitmHTTP2Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if !h.allowed() {
		// The settings changed or decryption paused; the session is being
		// torn down by the lifecycle, so this stream is not served.
		panic(http.ErrAbortHandler)
	}
	if r.Method == http.MethodConnect {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}
	// A browser may coalesce another host onto this connection; the leaf is
	// for host alone, so send it to a connection of its own.
	if mitmRequestHost(r.Host) != h.host {
		w.WriteHeader(http.StatusMisdirectedRequest)
		return
	}
	entry := mitmCaptures.begin(h.connection, h.host, r)
	var result error
	defer func() { mitmCaptures.fail(entry, result) }()

	out := r.Clone(r.Context())
	out.RequestURI = ""
	out.URL = &url.URL{Scheme: "https", Host: r.Host, Opaque: r.RequestURI}
	if strings.HasPrefix(r.RequestURI, "//") || r.RequestURI == "" {
		out.URL = &url.URL{Scheme: "https", Host: r.Host, Path: r.URL.Path, RawPath: r.URL.RawPath, RawQuery: r.URL.RawQuery}
	}
	// The client's request trailers, if it declared any, are filled in as
	// its body ends; the transport sends them after the body.
	out.Trailer = r.Trailer
	if _, present := out.Header["User-Agent"]; !present {
		// Otherwise the transport adds its own.
		out.Header["User-Agent"] = []string{""}
	}
	if r.ContentLength == 0 {
		out.Body = http.NoBody
	} else {
		var body io.Reader = r.Body
		if entry != nil {
			body = mitmCaptureReader{r: body, entry: entry}
		}
		out.Body = io.NopCloser(body)
	}
	trace := &httptrace.ClientTrace{
		// Early hints and other informational answers go on as they come;
		// 100 Continue is the client side's own business.
		Got1xxResponse: func(code int, header textproto.MIMEHeader) error {
			if code == http.StatusContinue || code == http.StatusSwitchingProtocols {
				return nil
			}
			fields := w.Header()
			for name, values := range header {
				fields[name] = values
			}
			w.WriteHeader(code)
			for name := range header {
				delete(fields, name)
			}
			return nil
		},
	}
	out = out.WithContext(httptrace.WithClientTrace(out.Context(), trace))
	resp, err := h.cc.RoundTrip(out)
	if err != nil {
		result = err
		if !h.cc.CanTakeNewRequest() {
			log.Debugln("[MITM] %s: HTTP/2 to the site ended: %v", h.host, err)
		}
		panic(http.ErrAbortHandler)
	}
	defer resp.Body.Close()
	mitmCaptures.respond(entry, resp)

	fields := w.Header()
	for name, values := range resp.Header {
		fields[name] = values
	}
	// Trailers are sent below, after the body, by name.
	delete(fields, "Trailer")
	for _, name := range []string{"Content-Type", "Date"} {
		if _, present := resp.Header[name]; !present {
			fields[name] = nil
		}
	}
	// Once the site stops taking new streams (GOAWAY), tell the client too
	// so it opens a new connection; the streams in flight still finish.
	if !h.cc.CanTakeNewRequest() {
		fields["Connection"] = []string{"close"}
	}
	w.WriteHeader(resp.StatusCode)

	var body io.Reader = resp.Body
	if entry != nil {
		body = mitmCaptureReader{r: body, entry: entry, response: true}
	}
	flusher, _ := w.(http.Flusher)
	if flusher != nil {
		flusher.Flush()
	}
	buf := make([]byte, 32<<10)
	for {
		n, err := body.Read(buf)
		if n > 0 {
			if _, werr := w.Write(buf[:n]); werr != nil {
				// The client went away or reset the stream; the deferred
				// Close resets the upstream stream.
				result = werr
				return
			}
			if flusher != nil {
				flusher.Flush()
			}
		}
		if errors.Is(err, io.EOF) {
			break
		}
		if err != nil {
			// A stream the site reset or a connection that broke must not
			// look complete to the client: reset it too.
			result = err
			panic(http.ErrAbortHandler)
		}
	}
	for name, values := range resp.Trailer {
		w.Header()[http.TrailerPrefix+name] = values
	}
	mitmCaptures.trailers(entry, resp.Trailer)
}
