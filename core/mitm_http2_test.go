package core

import (
	"bufio"
	"bytes"
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/binary"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"net/http/httptrace"
	"net/textproto"
	"strings"
	"sync"
	"testing"
	"time"

	N "github.com/metacubex/mihomo/common/net"
	C "github.com/metacubex/mihomo/constant"
	"golang.org/x/net/http2"
)

// Every socket here is a 127.0.0.1 listener the test makes; the sites are
// httptest servers on loopback, the certificates ephemeral keys in memory.
// Nothing reaches the network, the keychain or a Flash process.

type mitmH2Harness struct {
	site      *httptest.Server
	leafRoots *x509.CertPool
	runtime   *mitmRuntime
	done      chan MitmOutcome
	clientRaw net.Conn
	events    chan MitmConnection
}

// A site on loopback: h2 and http/1.1 when http2Site, else http/1.1 alone.
func newMitmH2Site(t *testing.T, http2Site bool, handler http.Handler) *httptest.Server {
	t.Helper()
	site := httptest.NewUnstartedServer(handler)
	site.EnableHTTP2 = http2Site
	site.StartTLS()
	t.Cleanup(site.Close)
	return site
}

// Starts a decrypted session for a client that offered clientALPN, with
// HTTP/2 decryption set to h2, to site. The session runs serveMitmOffering
// exactly as the selector would hand it over.
func newMitmH2Harness(t *testing.T, site *httptest.Server, clientALPN []string, h2 *bool) *mitmH2Harness {
	t.Helper()
	siteRoots := x509.NewCertPool()
	siteRoots.AddCert(site.Certificate())
	return newMitmH2HarnessTrusting(t, site, clientALPN, h2, siteRoots)
}

// As newMitmH2Harness, verifying the site against siteRoots.
func newMitmH2HarnessTrusting(t *testing.T, site *httptest.Server, clientALPN []string, h2 *bool, siteRoots *x509.CertPool) *mitmH2Harness {
	t.Helper()
	cert, leafRoots := mitmTestIdentity(t)
	oldRoots, oldRuntime := mitmUpstreamRoots, mitmState.Load()
	t.Cleanup(func() { mitmActive.closeAll(); mitmUpstreamRoots = oldRoots; mitmState.Store(oldRuntime) })
	mitmUpstreamRoots = siteRoots
	runtime := &mitmRuntime{setup: MitmSetup{H2: h2}}
	mitmState.Store(runtime)
	h := &mitmH2Harness{site: site, leafRoots: leafRoots, runtime: runtime, done: make(chan MitmOutcome, 1), events: make(chan MitmConnection, 4)}
	oldSend := sendMitmConnection
	sendMitmConnection = func(event *MitmConnection) bool {
		select {
		case h.events <- *event:
		default:
		}
		return true
	}
	t.Cleanup(func() { sendMitmConnection = oldSend })
	clientRaw, proxyClient := mitmLoopbackPair(t)
	proxySite, err := net.DialTimeout("tcp", site.Listener.Addr().String(), time.Second)
	if err != nil {
		t.Fatal(err)
	}
	for _, c := range []net.Conn{clientRaw, proxyClient, proxySite} {
		_ = c.SetDeadline(time.Now().Add(20 * time.Second))
		t.Cleanup(func() { _ = c.Close() })
	}
	h.clientRaw = clientRaw
	go func() {
		h.done <- serveMitmOffering(proxyClient, mitmTrackedConn{proxySite, "h2-connection"}, "example.com", &mitmLeaf{cert: cert}, runtime, clientALPN)
	}()
	return h
}

// The client's TLS, offering protos, verified against the decryption root.
func (h *mitmH2Harness) dial(t *testing.T, protos []string) *tls.Conn {
	t.Helper()
	client := tls.Client(h.clientRaw, &tls.Config{ServerName: "example.com", RootCAs: h.leafRoots, NextProtos: protos})
	if err := client.Handshake(); err != nil {
		t.Fatalf("client handshake: %v", err)
	}
	return client
}

func (h *mitmH2Harness) h2(t *testing.T) *http2.ClientConn {
	t.Helper()
	client := h.dial(t, []string{"h2", "http/1.1"})
	if got := client.ConnectionState().NegotiatedProtocol; got != "h2" {
		t.Fatalf("client negotiated %q, want h2", got)
	}
	cc, err := (&http2.Transport{}).NewClientConn(client)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = cc.Close() })
	return cc
}

func (h *mitmH2Harness) outcome(t *testing.T) MitmOutcome {
	t.Helper()
	select {
	case outcome := <-h.done:
		return outcome
	case <-time.After(5 * time.Second):
		t.Fatal("session did not end")
		return ""
	}
}

func boolPtr(v bool) *bool { return &v }

func TestMitmH2ProtocolChoice(t *testing.T) {
	cases := []struct {
		client []string
		h2     bool
		want   []string
	}{
		{nil, true, []string{"http/1.1"}},
		{[]string{"h2", "http/1.1"}, true, []string{"h2", "http/1.1"}},
		{[]string{"http/1.1", "h2"}, true, []string{"http/1.1", "h2"}},
		{[]string{"h2", "http/1.1"}, false, []string{"http/1.1"}},
		{[]string{"h2"}, true, []string{"h2"}},
		{[]string{"h2"}, false, []string{}},
		{[]string{"spdy/3", "h2", "h2"}, true, []string{"h2"}},
	}
	for _, tc := range cases {
		if got := mitmUpstreamProtos(tc.client, tc.h2); fmt.Sprint(got) != fmt.Sprint(tc.want) {
			t.Errorf("upstream protos for %v h2=%v: %v, want %v", tc.client, tc.h2, got, tc.want)
		}
	}
	if got := mitmClientProtos([]string{"h2", "http/1.1"}, "h2"); fmt.Sprint(got) != "[h2]" {
		t.Errorf("mirror h2: %v", got)
	}
	if got := mitmClientProtos([]string{"h2", "http/1.1"}, ""); fmt.Sprint(got) != "[http/1.1]" {
		t.Errorf("site without ALPN: %v", got)
	}
	if got := mitmClientProtos([]string{"h2"}, "http/1.1"); got != nil {
		t.Errorf("h2-only client with a 1.1 site: %v", got)
	}
	for _, tc := range []struct {
		alpn      []string
		h2, wants bool
	}{
		{nil, false, true}, {[]string{"http/1.1"}, false, true}, {[]string{"h2"}, false, false},
		{[]string{"h2"}, true, true}, {[]string{"spdy/3"}, true, false},
	} {
		if got := (mitmClientHello{alpn: tc.alpn}).decryptable(tc.h2); got != tc.wants {
			t.Errorf("decryptable(%v, h2=%v) = %v", tc.alpn, tc.h2, got)
		}
	}
	if !(&mitmRuntime{}).http2() || (&mitmRuntime{setup: MitmSetup{H2: boolPtr(false)}}).http2() || (*mitmRuntime)(nil).http2() {
		t.Fatal("HTTP/2 decryption is on unless turned off")
	}
}

// An h2 site behind decryption: the client speaks h2, the site sees h2 from
// the proxy, concurrent streams work and each is recorded like a 1.1
// exchange, with its protocol.
func TestMitmH2DecryptsAnH2Site(t *testing.T) {
	withMitmCapture(t, mitmDefaultCaptureLimits)
	site := newMitmH2Site(t, true, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.ProtoMajor != 2 || r.Host != "example.com" {
			http.Error(w, "wrong protocol or host "+r.Proto+" "+r.Host, http.StatusBadRequest)
			return
		}
		body, _ := io.ReadAll(r.Body)
		w.Header().Set("Content-Type", "text/plain")
		w.Header().Set("X-Site", "yes")
		fmt.Fprintf(w, "%s %s %s", r.Method, r.URL.RequestURI(), body)
	}))
	h := newMitmH2Harness(t, site, []string{"h2", "http/1.1"}, nil)
	cc := h.h2(t)
	var wg sync.WaitGroup
	errs := make(chan error, 8)
	for i := 0; i < 8; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			req, _ := http.NewRequest(http.MethodPost, fmt.Sprintf("https://example.com/p/%d?q=a%%2Fb", i), strings.NewReader("hello"))
			resp, err := cc.RoundTrip(req)
			if err != nil {
				errs <- err
				return
			}
			defer resp.Body.Close()
			body, _ := io.ReadAll(resp.Body)
			want := fmt.Sprintf("POST /p/%d?q=a%%2Fb hello", i)
			if resp.StatusCode != 200 || resp.ProtoMajor != 2 || string(body) != want || resp.Header.Get("X-Site") != "yes" {
				errs <- fmt.Errorf("stream %d: %d %s %q", i, resp.StatusCode, resp.Proto, body)
			}
		}(i)
	}
	wg.Wait()
	close(errs)
	for err := range errs {
		t.Error(err)
	}
	if event := <-h.events; event.Outcome != mitmOutcomeDecrypted {
		t.Fatalf("event %+v", event)
	}
	list := handleMitmExchanges(MitmExchangesParams{ID: "h2-connection"})
	if len(list.Exchanges) != 8 {
		t.Fatalf("recorded %d exchanges", len(list.Exchanges))
	}
	for _, summary := range list.Exchanges {
		if summary.Proto != "HTTP/2.0" || summary.Method != "POST" || summary.Status != 200 || !strings.HasPrefix(summary.URL, "https://example.com/p/") || summary.RequestSize != 5 {
			t.Fatalf("summary %+v", summary)
		}
	}
	exchange := handleMitmExchange(MitmExchangeParams{ID: list.Exchanges[0].ID})
	if exchange.ResponseHeader["X-Site"][0] != "yes" || exchange.Proto != "HTTP/2.0" {
		t.Fatalf("exchange %+v", exchange)
	}
	if text, _ := mitmBodyText(t, list.Exchanges[0].ID, false); text != "hello" {
		t.Fatalf("request body %q", text)
	}
	_ = cc.Close()
	if outcome := h.outcome(t); outcome != "" {
		t.Fatalf("outcome %q", outcome)
	}
}

// A site that speaks only HTTP/1.1: a client offering both ends up on 1.1
// on both sides; a client offering h2 alone is not served.
func TestMitmH2FallsBackToHTTP1(t *testing.T) {
	site := newMitmH2Site(t, false, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "%s", r.Proto)
	}))
	t.Run("both offered", func(t *testing.T) {
		h := newMitmH2Harness(t, site, []string{"h2", "http/1.1"}, nil)
		client := h.dial(t, []string{"h2", "http/1.1"})
		if got := client.ConnectionState().NegotiatedProtocol; got != "http/1.1" {
			t.Fatalf("client negotiated %q", got)
		}
		if _, err := io.WriteString(client, "GET / HTTP/1.1\r\nHost: example.com\r\nConnection: close\r\n\r\n"); err != nil {
			t.Fatal(err)
		}
		resp, err := http.ReadResponse(bufio.NewReader(client), nil)
		if err != nil {
			t.Fatal(err)
		}
		body, _ := io.ReadAll(resp.Body)
		if string(body) != "HTTP/1.1" {
			t.Fatalf("site saw %q", body)
		}
		if outcome := h.outcome(t); outcome != "" {
			t.Fatalf("outcome %q", outcome)
		}
	})
	t.Run("h2 only", func(t *testing.T) {
		h := newMitmH2Harness(t, site, []string{"h2"}, nil)
		if outcome := h.outcome(t); outcome != mitmOutcomeUpstreamFailed {
			t.Fatalf("outcome %q", outcome)
		}
	})
}

// With HTTP/2 decryption off, both sides are offered HTTP/1.1 alone, even
// to an h2 site and an h2-capable client.
func TestMitmH2OffAdvertisesHTTP1Only(t *testing.T) {
	site := newMitmH2Site(t, true, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "%s", r.Proto)
	}))
	h := newMitmH2Harness(t, site, []string{"h2", "http/1.1"}, boolPtr(false))
	client := tls.Client(h.clientRaw, &tls.Config{ServerName: "example.com", RootCAs: h.leafRoots, NextProtos: []string{"h2", "http/1.1"}})
	if err := client.Handshake(); err != nil {
		t.Fatal(err)
	}
	if got := client.ConnectionState().NegotiatedProtocol; got != "http/1.1" {
		t.Fatalf("client negotiated %q", got)
	}
	if _, err := io.WriteString(client, "GET / HTTP/1.1\r\nHost: example.com\r\nConnection: close\r\n\r\n"); err != nil {
		t.Fatal(err)
	}
	resp, err := http.ReadResponse(bufio.NewReader(client), nil)
	if err != nil {
		t.Fatal(err)
	}
	body, _ := io.ReadAll(resp.Body)
	if string(body) != "HTTP/1.1" {
		t.Fatalf("site saw %q", body)
	}
}

// The selector: an h2-only client is decrypted while HTTP/2 decryption is on
// and passed through untouched, marked, while it is off.
func TestMitmH2SelectorFollowsTheSetting(t *testing.T) {
	sni := []byte{0, 0, 0, 16, 0, 14, 0, 0, 11, 'e', 'x', 'a', 'm', 'p', 'l', 'e', '.', 'c', 'o', 'm'}
	alpnH2 := []byte{0, 16, 0, 5, 0, 3, 2, 'h', '2'}
	hello := helloFixture(sni, alpnH2)
	original := append([]byte{0x16, 3, 1, byte(len(hello) >> 8), byte(len(hello))}, hello...)
	for _, on := range []bool{true, false} {
		app := newFakeMitmApp(t)
		withMitmSigner(t, app, []string{"example.com"}, func(req *MitmSignRequest) MitmSignResultParams {
			return MitmSignResultParams{Cert: app.leaf(t, req.Host, req.SPKI, nil), CA: app.ca.Raw}
		})
		mitmState.Load().setup.H2 = boolPtr(on)
		events := make(chan MitmConnection, 1)
		oldSend := sendMitmConnection
		sendMitmConnection = func(event *MitmConnection) bool { events <- *event; return true }
		clientRaw, proxyRaw := mitmLoopbackPair(t)
		if _, err := clientRaw.Write(original); err != nil {
			t.Fatal(err)
		}
		buffered := N.NewBufferedConn(proxyRaw)
		selected := mitmInterceptEligible(buffered, &C.Metadata{Host: "example.com", DstPort: 443})
		if selected == nil {
			t.Fatalf("h2=%v: listed host not selected", on)
		}
		if !on {
			proxySite, siteRaw := mitmLoopbackPair(t)
			go selected(buffered, mitmSelectionConn{N.NewExtendedConn(proxySite)})
			got := make([]byte, len(original))
			if _, err := io.ReadFull(siteRaw, got); err != nil || !bytes.Equal(got, original) {
				t.Fatalf("not relayed untouched: %v", err)
			}
			if event := <-events; event.Outcome != mitmOutcomeHTTP2Only {
				t.Fatalf("event %+v", event)
			}
			siteRaw.Close()
			proxySite.Close()
		}
		sendMitmConnection = oldSend
		clientRaw.Close()
		proxyRaw.Close()
		mitmActive.closeAll()
		mitmLeaves.clear()
	}
}

// gRPC framing: a 5-byte prefix per message.
func grpcFrame(msg string) []byte {
	b := make([]byte, 5+len(msg))
	binary.BigEndian.PutUint32(b[1:], uint32(len(msg)))
	copy(b[5:], msg)
	return b
}

func readGRPCFrame(r io.Reader) (string, error) {
	var prefix [5]byte
	if _, err := io.ReadFull(r, prefix[:]); err != nil {
		return "", err
	}
	msg := make([]byte, binary.BigEndian.Uint32(prefix[1:]))
	_, err := io.ReadFull(r, msg)
	return string(msg), err
}

// A gRPC-shaped site (h2 only, application/grpc, grpc-status in trailers):
// unary, server streaming, bidi streaming and a trailers-only error all pass
// through decryption with their trailers, and the streams stay live (each
// bidi reply arrives before the next request message is sent).
func TestMitmH2GRPCShapedStreams(t *testing.T) {
	withMitmCapture(t, mitmDefaultCaptureLimits)
	site := newMitmH2Site(t, true, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.ProtoMajor != 2 || r.Header.Get("Content-Type") != "application/grpc" || r.Header.Get("Te") != "trailers" {
			w.Header().Set("Grpc-Status", "13")
			w.WriteHeader(200)
			return
		}
		flusher := w.(http.Flusher)
		w.Header().Set("Content-Type", "application/grpc")
		w.Header().Set("Trailer", "Grpc-Status, Grpc-Message")
		switch r.URL.Path {
		case "/test.Echo/Unary":
			msg, err := readGRPCFrame(r.Body)
			if err != nil {
				return
			}
			w.Write(grpcFrame("unary:" + msg))
		case "/test.Echo/Server":
			msg, _ := readGRPCFrame(r.Body)
			for i := 0; i < 3; i++ {
				w.Write(grpcFrame(fmt.Sprintf("%s-%d", msg, i)))
				flusher.Flush()
				time.Sleep(10 * time.Millisecond)
			}
		case "/test.Echo/Bidi":
			w.WriteHeader(200)
			flusher.Flush()
			for {
				msg, err := readGRPCFrame(r.Body)
				if err != nil {
					break
				}
				w.Write(grpcFrame("echo:" + msg))
				flusher.Flush()
			}
		case "/test.Echo/Fail":
			// Trailers-only: the status travels in the only HEADERS frame.
			w.Header().Del("Trailer")
			w.Header().Set("Grpc-Status", "5")
			w.Header().Set("Grpc-Message", "not found")
			w.Header()["Content-Length"] = nil // as grpc-go: none
			w.WriteHeader(200)
			return
		}
		w.Header().Set("Grpc-Status", "0")
		w.Header().Set("Grpc-Message", "ok")
	}))
	h := newMitmH2Harness(t, site, []string{"h2"}, nil)
	client := h.dial(t, []string{"h2"})
	cc, err := (&http2.Transport{}).NewClientConn(client)
	if err != nil {
		t.Fatal(err)
	}
	defer cc.Close()
	call := func(method string, body io.Reader) *http.Response {
		t.Helper()
		req, _ := http.NewRequest(http.MethodPost, "https://example.com/test.Echo/"+method, body)
		req.Header.Set("Content-Type", "application/grpc")
		req.Header.Set("Te", "trailers")
		resp, err := cc.RoundTrip(req)
		if err != nil {
			t.Fatalf("%s: %v", method, err)
		}
		return resp
	}
	status := func(resp *http.Response) string {
		_, _ = io.ReadAll(resp.Body)
		return resp.Trailer.Get("Grpc-Status") + "/" + resp.Trailer.Get("Grpc-Message")
	}

	resp := call("Unary", bytes.NewReader(grpcFrame("ping")))
	if msg, err := readGRPCFrame(resp.Body); err != nil || msg != "unary:ping" {
		t.Fatalf("unary %q %v", msg, err)
	}
	if got := status(resp); got != "0/ok" {
		t.Fatalf("unary trailers %q", got)
	}

	resp = call("Server", bytes.NewReader(grpcFrame("s")))
	for i := 0; i < 3; i++ {
		if msg, err := readGRPCFrame(resp.Body); err != nil || msg != fmt.Sprintf("s-%d", i) {
			t.Fatalf("server stream %d: %q %v", i, msg, err)
		}
	}
	if got := status(resp); got != "0/ok" {
		t.Fatalf("server stream trailers %q", got)
	}

	upload, uploadWriter := io.Pipe()
	resp = call("Bidi", upload)
	for i := 0; i < 5; i++ {
		msg := fmt.Sprintf("m%d", i)
		if _, err := uploadWriter.Write(grpcFrame(msg)); err != nil {
			t.Fatal(err)
		}
		// The reply must arrive while the request stream is still open.
		got, err := readGRPCFrame(resp.Body)
		if err != nil || got != "echo:"+msg {
			t.Fatalf("bidi %d: %q %v", i, got, err)
		}
	}
	uploadWriter.Close()
	if got := status(resp); got != "0/ok" {
		t.Fatalf("bidi trailers %q", got)
	}

	resp = call("Fail", http.NoBody)
	body, _ := io.ReadAll(resp.Body)
	if len(body) != 0 || resp.Header.Get("Grpc-Status") != "5" || resp.Header.Get("Grpc-Message") != "not found" {
		t.Fatalf("trailers-only: %q %v", body, resp.Header)
	}
	// It must stay one HEADERS frame that ends the stream (the transport
	// then knows the length is 0): grpc-go fails a status sent as headers
	// followed by an empty DATA frame, "closed without sending trailers".
	if resp.ContentLength != 0 || resp.Header["Content-Length"] != nil {
		t.Fatalf("trailers-only was split from the end of the stream: length %d %v", resp.ContentLength, resp.Header)
	}

	list := handleMitmExchanges(MitmExchangesParams{ID: "h2-connection"})
	if len(list.Exchanges) != 4 {
		t.Fatalf("recorded %d", len(list.Exchanges))
	}
	unary := handleMitmExchange(MitmExchangeParams{ID: list.Exchanges[0].ID})
	if fmt.Sprint(unary.ResponseHeader["Grpc-Status"]) != "[0]" {
		t.Fatalf("recorded trailers %v", unary.ResponseHeader)
	}
}

// A body far larger than any buffer streams through: the client has the
// first megabyte while the site still holds back the rest, and an upload is
// seen by the site before the client has finished sending it.
func TestMitmH2StreamsLargeBodiesWithoutBuffering(t *testing.T) {
	withMitmCapture(t, mitmCaptureLimits{entries: 10, bytes: 1 << 20, body: 64 << 10})
	release := make(chan struct{})
	uploadSeen := make(chan struct{})
	chunk := bytes.Repeat([]byte("x"), 1<<20)
	site := newMitmH2Site(t, true, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/download":
			w.Write(chunk)
			w.(http.Flusher).Flush()
			select {
			case <-release:
			case <-time.After(5 * time.Second):
				return
			}
			for i := 0; i < 15; i++ {
				w.Write(chunk)
			}
		case "/upload":
			var b [1 << 16]byte
			if _, err := io.ReadFull(r.Body, b[:]); err != nil {
				return
			}
			close(uploadSeen)
			n, _ := io.Copy(io.Discard, r.Body)
			fmt.Fprintf(w, "%d", n+int64(len(b)))
		}
	}))
	h := newMitmH2Harness(t, site, []string{"h2", "http/1.1"}, nil)
	cc := h.h2(t)
	req, _ := http.NewRequest(http.MethodGet, "https://example.com/download", nil)
	resp, err := cc.RoundTrip(req)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := io.ReadFull(resp.Body, make([]byte, 1<<20)); err != nil {
		t.Fatalf("first megabyte did not arrive before the rest was sent: %v", err)
	}
	close(release)
	n, err := io.Copy(io.Discard, resp.Body)
	if err != nil || n != 15<<20 {
		t.Fatalf("rest %d %v", n, err)
	}

	upload, uploadWriter := io.Pipe()
	req, _ = http.NewRequest(http.MethodPost, "https://example.com/upload", upload)
	result := make(chan *http.Response, 1)
	go func() {
		resp, err := cc.RoundTrip(req)
		if err != nil {
			t.Error(err)
		}
		result <- resp
	}()
	if _, err := uploadWriter.Write(chunk); err != nil {
		t.Fatal(err)
	}
	select {
	case <-uploadSeen:
	case <-time.After(5 * time.Second):
		t.Fatal("the upload was held back")
	}
	for i := 0; i < 7; i++ {
		uploadWriter.Write(chunk)
	}
	uploadWriter.Close()
	resp = <-result
	body, _ := io.ReadAll(resp.Body)
	if string(body) != fmt.Sprint(8<<20) {
		t.Fatalf("upload size %q", body)
	}
	list := handleMitmExchanges(MitmExchangesParams{ID: "h2-connection"})
	if len(list.Exchanges) != 2 || list.Exchanges[0].ResponseSize != 16<<20 {
		t.Fatalf("exchanges %+v", list.Exchanges)
	}
	if _, body := mitmBodyText(t, list.Exchanges[0].ID, true); !body.Truncated {
		t.Fatal("capture kept more than its cap")
	}
}

// A stream the site resets mid-body is reset to the client, never ended as
// if it were complete.
func TestMitmH2SiteResetIsNotACleanEnd(t *testing.T) {
	site := newMitmH2Site(t, true, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("partial"))
		w.(http.Flusher).Flush()
		panic(http.ErrAbortHandler)
	}))
	h := newMitmH2Harness(t, site, []string{"h2"}, nil)
	client := h.dial(t, []string{"h2"})
	cc, err := (&http2.Transport{}).NewClientConn(client)
	if err != nil {
		t.Fatal(err)
	}
	defer cc.Close()
	req, _ := http.NewRequest(http.MethodGet, "https://example.com/", nil)
	resp, err := cc.RoundTrip(req)
	if err == nil {
		_, err = io.ReadAll(resp.Body)
	}
	if err == nil {
		t.Fatal("a reset stream looked complete")
	}
}

// The site's certificate is verified as ever with h2 offered: an untrusted
// one fails before the client is shown any certificate.
func TestMitmH2UntrustedSiteIsRejected(t *testing.T) {
	site := newMitmH2Site(t, true, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {}))
	h := newMitmH2HarnessTrusting(t, site, []string{"h2", "http/1.1"}, nil, x509.NewCertPool())
	if outcome := h.outcome(t); outcome != mitmOutcomeUpstreamCertificate {
		t.Fatalf("outcome %q", outcome)
	}
	client := tls.Client(h.clientRaw, &tls.Config{ServerName: "example.com", RootCAs: h.leafRoots, NextProtos: []string{"h2"}})
	_ = h.clientRaw.SetDeadline(time.Now().Add(300 * time.Millisecond))
	if err := client.Handshake(); err == nil {
		t.Fatal("the client was served past an untrusted site")
	}
}

// Early hints reach the client ahead of the response, without leaking into
// it; when the site's connection dies the client's session ends too.
func TestMitmH2EarlyHintsAndSiteGone(t *testing.T) {
	site := newMitmH2Site(t, true, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Link", "</style.css>; rel=preload")
		w.WriteHeader(http.StatusEarlyHints)
		w.Header().Del("Link")
		w.Write([]byte("ok"))
	}))
	h := newMitmH2Harness(t, site, []string{"h2", "http/1.1"}, nil)
	cc := h.h2(t)
	var hints []string
	trace := &httptrace.ClientTrace{Got1xxResponse: func(code int, header textproto.MIMEHeader) error {
		hints = append(hints, fmt.Sprint(code, header.Get("Link")))
		return nil
	}}
	req, _ := http.NewRequestWithContext(httptrace.WithClientTrace(context.Background(), trace), http.MethodGet, "https://example.com/", nil)
	resp, err := cc.RoundTrip(req)
	if err != nil {
		t.Fatal(err)
	}
	body, _ := io.ReadAll(resp.Body)
	if string(body) != "ok" || fmt.Sprint(hints) != "[103</style.css>; rel=preload]" || resp.Header.Get("Link") != "" {
		t.Fatalf("body %q hints %v header %v", body, hints, resp.Header)
	}
	site.CloseClientConnections()
	if outcome := h.outcome(t); outcome != "" {
		t.Fatalf("outcome %q", outcome)
	}
}

// A host not in the list is decided from the metadata alone: no byte is
// read and no time is spent, h2 or not.
func TestMitmH2UnlistedHostIsNotTouched(t *testing.T) {
	app := newFakeMitmApp(t)
	withMitmSigner(t, app, []string{"example.com"}, nil)
	clientRaw, proxyRaw := mitmLoopbackPair(t)
	defer clientRaw.Close()
	defer proxyRaw.Close()
	conn := N.NewBufferedConn(proxyRaw)
	start := time.Now()
	if selected := mitmInterceptEligible(conn, &C.Metadata{Host: "other.org", DstPort: 443}); selected != nil {
		t.Fatal("unlisted host selected")
	}
	if elapsed := time.Since(start); elapsed > 5*time.Millisecond {
		t.Fatalf("unlisted host waited %v", elapsed)
	}
	if conn.Peeked() || conn.Reader().Buffered() != 0 {
		t.Fatal("unlisted host was read")
	}
}

func BenchmarkMitmInterceptWantedUnlisted(b *testing.B) {
	previous := mitmState.Load()
	defer mitmState.Store(previous)
	applyMitmSetup(&SetupParams{Mitm: &MitmSetup{Enable: true, Hostname: []string{"example.com", "*.example.net"}, DecryptTLS: true, CAFingerprint: "x"}}, nil)
	metadata := &C.Metadata{Host: "www.unlisted.org", DstPort: 443}
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		if mitmInterceptWanted(metadata) {
			b.Fatal("unlisted host wanted")
		}
	}
}
