package core

import (
	"bufio"
	"bytes"
	"crypto/sha256"
	"crypto/tls"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"testing"
	"time"

	N "github.com/metacubex/mihomo/common/net"
	C "github.com/metacubex/mihomo/constant"
)

// All sockets here are 127.0.0.1 listeners created by the test; certificates
// are ephemeral in-memory keys. Nothing reaches the network or the keychain.

type mitmTLSHarness struct {
	cert                   tls.Certificate
	client                 *tls.Conn
	clientRaw, siteRaw     net.Conn
	done                   chan MitmOutcome
	proxyClient, proxySite net.Conn
}

func newMitmTLSHarness(t *testing.T) *mitmTLSHarness {
	t.Helper()
	cert, roots := mitmTestIdentity(t)
	oldRoots, oldRuntime := mitmUpstreamRoots, mitmState.Load()
	t.Cleanup(func() { mitmActive.closeAll(); mitmUpstreamRoots = oldRoots; mitmState.Store(oldRuntime) })
	mitmUpstreamRoots = roots
	runtime := &mitmRuntime{}
	mitmState.Store(runtime)
	h := &mitmTLSHarness{cert: cert, done: make(chan MitmOutcome, 1)}
	h.clientRaw, h.proxyClient = mitmLoopbackPair(t)
	h.proxySite, h.siteRaw = mitmLoopbackPair(t)
	for _, c := range []net.Conn{h.clientRaw, h.proxyClient, h.proxySite, h.siteRaw} {
		_ = c.SetDeadline(time.Now().Add(15 * time.Second))
		t.Cleanup(func() { _ = c.Close() })
	}
	go func() {
		h.done <- serveMitm(h.proxyClient, h.proxySite, "example.com", &mitmLeaf{cert: cert}, runtime)
	}()
	// The strict wrapper turns a bare TCP EOF into an error, so io.EOF from
	// this client proves an authenticated close_notify from the proxy.
	h.client = tls.Client(mitmStrictTLSConn{h.clientRaw}, &tls.Config{ServerName: "example.com", RootCAs: roots})
	return h
}

func (h *mitmTLSHarness) site() *tls.Conn {
	return tls.Server(h.siteRaw, &tls.Config{Certificates: []tls.Certificate{h.cert}})
}

func (h *mitmTLSHarness) outcome(t *testing.T) MitmOutcome {
	t.Helper()
	select {
	case outcome := <-h.done:
		return outcome
	case <-time.After(3 * time.Second):
		t.Fatal("relay did not stop")
		return ""
	}
}

func (h *mitmTLSHarness) expectCloseNotify(t *testing.T) {
	t.Helper()
	var b [1]byte
	if n, err := h.client.Read(b[:]); n != 0 || !errors.Is(err, io.EOF) {
		t.Fatalf("expected close_notify EOF, got %d %v", n, err)
	}
}

// A close-delimited upstream body read through EOF by a real Go TLS client
// must end with an authenticated close_notify, not a bare transport close.
func TestMitmTLSCloseDelimitedBodyEndsWithCloseNotify(t *testing.T) {
	h := newMitmTLSHarness(t)
	siteDone := make(chan error, 1)
	go func() {
		site := h.site()
		_, err := http.ReadRequest(bufio.NewReader(site))
		if err == nil {
			_, err = io.WriteString(site, "HTTP/1.1 200 OK\r\nConnection: close\r\n\r\nclose-delimited body")
		}
		if e := site.Close(); err == nil {
			err = e
		}
		siteDone <- err
	}()
	if _, err := io.WriteString(h.client, "GET / HTTP/1.1\r\nHost: example.com\r\n\r\n"); err != nil {
		t.Fatal(err)
	}
	reader := bufio.NewReader(h.client)
	resp, err := http.ReadResponse(reader, nil)
	if err != nil {
		t.Fatal(err)
	}
	body, err := io.ReadAll(resp.Body)
	if err != nil || string(body) != "close-delimited body" || !resp.Close {
		t.Fatalf("body %q close=%v err=%v", body, resp.Close, err)
	}
	// Read through EOF of the TLS stream itself.
	rest, err := io.ReadAll(reader)
	if err != nil || len(rest) != 0 {
		t.Fatalf("after body: %q %v (want clean close_notify EOF)", rest, err)
	}
	if outcome := h.outcome(t); outcome != "" {
		t.Fatalf("outcome %q", outcome)
	}
	if err := <-siteDone; err != nil {
		t.Fatal(err)
	}
}

// A large streamed upload and download complete and the session is reused.
func TestMitmTLSStreamingUploadDownloadAndKeepalive(t *testing.T) {
	h := newMitmTLSHarness(t)
	upload := bytes.Repeat([]byte("0123456789abcdef"), 512<<10)   // 8 MiB
	download := bytes.Repeat([]byte("fedcba9876543210"), 256<<10) // 4 MiB
	uploadSum := sha256.Sum256(upload)
	siteDone := make(chan error, 1)
	go func() {
		site := h.site()
		r := bufio.NewReader(site)
		req, err := http.ReadRequest(r)
		if err != nil {
			siteDone <- err
			return
		}
		hash := sha256.New()
		n, err := io.Copy(hash, req.Body)
		if err != nil || n != int64(len(upload)) || !bytes.Equal(hash.Sum(nil), uploadSum[:]) {
			siteDone <- fmt.Errorf("upload n=%d err=%v", n, err)
			return
		}
		if _, err = fmt.Fprintf(site, "HTTP/1.1 200 OK\r\nContent-Length: %d\r\n\r\n", len(download)); err == nil {
			_, err = site.Write(download)
		}
		if err == nil {
			if req, err = http.ReadRequest(r); err == nil && req.URL.Path != "/second" {
				err = fmt.Errorf("second %q", req.URL.Path)
			}
		}
		if err == nil {
			_, err = io.WriteString(site, "HTTP/1.1 200 OK\r\nContent-Length: 6\r\nConnection: close\r\n\r\nsecond")
		}
		_ = site.Close()
		siteDone <- err
	}()
	writeDone := make(chan error, 1)
	go func() {
		_, err := io.WriteString(h.client, "POST /first HTTP/1.1\r\nHost: example.com\r\nTransfer-Encoding: chunked\r\n\r\n")
		for off := 0; err == nil && off < len(upload); off += 64 << 10 {
			_, err = fmt.Fprintf(h.client, "%x\r\n%s\r\n", 64<<10, upload[off:off+64<<10])
		}
		if err == nil {
			_, err = io.WriteString(h.client, "0\r\n\r\n")
		}
		writeDone <- err
	}()
	reader := bufio.NewReader(h.client)
	resp, err := http.ReadResponse(reader, nil)
	if err != nil {
		t.Fatal(err)
	}
	body, err := io.ReadAll(resp.Body)
	if err != nil || !bytes.Equal(body, download) || resp.Close {
		t.Fatalf("download %d bytes close=%v err=%v", len(body), resp.Close, err)
	}
	if err := <-writeDone; err != nil {
		t.Fatal(err)
	}
	if _, err := io.WriteString(h.client, "GET /second HTTP/1.1\r\nHost: example.com\r\n\r\n"); err != nil {
		t.Fatal(err)
	}
	resp, err = http.ReadResponse(reader, nil)
	if err != nil {
		t.Fatal(err)
	}
	if body, err := io.ReadAll(resp.Body); err != nil || string(body) != "second" {
		t.Fatalf("second %q %v", body, err)
	}
	h.expectCloseNotify(t)
	if outcome := h.outcome(t); outcome != "" {
		t.Fatalf("outcome %q", outcome)
	}
	if err := <-siteDone; err != nil {
		t.Fatal(err)
	}
}

// Early 401/413 while the client keeps streaming a large body: the response
// arrives promptly, the session closes with close_notify, the site never sees
// a complete body or a second request, and the blocked client writer is freed.
func TestMitmTLSEarlyFinalWhileClientStreams(t *testing.T) {
	for _, status := range []string{"401 Unauthorized", "413 Payload Too Large"} {
		t.Run(status, func(t *testing.T) {
			h := newMitmTLSHarness(t)
			siteDone := make(chan error, 1)
			go func() {
				site := h.site()
				r := bufio.NewReader(site)
				req, err := http.ReadRequest(r)
				if err != nil {
					siteDone <- err
					return
				}
				// Read a little of the body, then refuse and stop reading.
				var head [1024]byte
				if _, err = io.ReadFull(req.Body, head[:]); err != nil {
					siteDone <- err
					return
				}
				if _, err = io.WriteString(site, "HTTP/1.1 "+status+"\r\nContent-Length: 7\r\n\r\nrefused"); err != nil {
					siteDone <- err
					return
				}
				// Whatever follows must be the abandoned body, never a new request.
				rest, _ := io.ReadAll(r)
				if bytes.Contains(rest, []byte("HTTP/1.1")) {
					siteDone <- fmt.Errorf("site saw another request")
					return
				}
				siteDone <- nil
			}()
			if _, err := io.WriteString(h.client, "POST / HTTP/1.1\r\nHost: example.com\r\nContent-Length: 1073741824\r\n\r\n"); err != nil {
				t.Fatal(err)
			}
			writerDone := make(chan error, 1)
			go func() {
				block := bytes.Repeat([]byte("u"), 32<<10)
				var err error
				for err == nil {
					_, err = h.client.Write(block)
				}
				writerDone <- err
			}()
			started := time.Now()
			resp, err := http.ReadResponse(bufio.NewReader(h.client), nil)
			if err != nil {
				t.Fatal(err)
			}
			body, err := io.ReadAll(resp.Body)
			if err != nil || string(body) != "refused" || !resp.Close || !bytes.HasPrefix([]byte(status), []byte(fmt.Sprint(resp.StatusCode))) {
				t.Fatalf("response %d close=%v body=%q err=%v", resp.StatusCode, resp.Close, body, err)
			}
			if time.Since(started) > 3*time.Second {
				t.Fatal("early response stalled behind the upload")
			}
			if outcome := h.outcome(t); outcome != "" {
				t.Fatalf("outcome %q", outcome)
			}
			select {
			case err := <-siteDone:
				if err != nil {
					t.Fatal(err)
				}
			case <-time.After(3 * time.Second):
				t.Fatal("site was not released")
			}
			_ = h.clientRaw.Close()
			select {
			case <-writerDone:
			case <-time.After(3 * time.Second):
				t.Fatal("client writer stayed blocked")
			}
		})
	}
}

// Body bytes are forwarded as they arrive, not held until a buffer fills or
// the body ends: the site sees a slow upload's first bytes while the client
// still waits to send the rest.
func TestMitmTLSSlowUploadBytesReachSitePromptly(t *testing.T) {
	h := newMitmTLSHarness(t)
	firstSeen := make(chan struct{})
	siteDone := make(chan error, 1)
	go func() {
		site := h.site()
		r := bufio.NewReader(site)
		req, err := http.ReadRequest(r)
		if err != nil {
			siteDone <- err
			return
		}
		var first [5]byte
		if _, err = io.ReadFull(req.Body, first[:]); err != nil || string(first[:]) != "first" {
			siteDone <- fmt.Errorf("first %q: %v", first, err)
			return
		}
		close(firstSeen)
		rest, err := io.ReadAll(req.Body)
		if err == nil && string(rest) != "-then-rest" {
			err = fmt.Errorf("rest %q", rest)
		}
		if err == nil {
			_, err = io.WriteString(site, "HTTP/1.1 204 No Content\r\nConnection: close\r\n\r\n")
		}
		_ = site.Close()
		siteDone <- err
	}()
	if _, err := io.WriteString(h.client, "POST / HTTP/1.1\r\nHost: example.com\r\nContent-Length: 15\r\n\r\nfirst"); err != nil {
		t.Fatal(err)
	}
	select {
	case <-firstSeen:
	case err := <-siteDone:
		t.Fatal(err)
	case <-time.After(3 * time.Second):
		t.Fatal("partial upload was held back from the site")
	}
	if _, err := io.WriteString(h.client, "-then-rest"); err != nil {
		t.Fatal(err)
	}
	resp, err := http.ReadResponse(bufio.NewReader(h.client), nil)
	if err != nil || resp.StatusCode != 204 {
		t.Fatalf("response %v %v", resp, err)
	}
	h.expectCloseNotify(t)
	if outcome := h.outcome(t); outcome != "" {
		t.Fatalf("outcome %q", outcome)
	}
	if err := <-siteDone; err != nil {
		t.Fatal(err)
	}
}

// Either peer disconnecting during an upload stops both sides within a bound,
// never completes the upstream body and never replays the request.
func TestMitmTLSDisconnectDuringUpload(t *testing.T) {
	for _, who := range []string{"client", "site"} {
		t.Run(who, func(t *testing.T) {
			h := newMitmTLSHarness(t)
			siteDone := make(chan error, 1)
			gotRequest := make(chan struct{})
			go func() {
				site := h.site()
				r := bufio.NewReader(site)
				req, err := http.ReadRequest(r)
				if err != nil {
					siteDone <- err
					return
				}
				close(gotRequest)
				if who == "site" {
					var head [4]byte
					_, _ = io.ReadFull(req.Body, head[:])
					_ = h.siteRaw.Close()
					siteDone <- nil
					return
				}
				if _, err = io.ReadAll(req.Body); err == nil {
					siteDone <- errors.New("site received a complete body")
					return
				}
				if _, err = http.ReadRequest(r); err == nil {
					siteDone <- errors.New("request replayed")
					return
				}
				siteDone <- nil
			}()
			if _, err := io.WriteString(h.client, "POST / HTTP/1.1\r\nHost: example.com\r\nContent-Length: 100000\r\n\r\npartial-body"); err != nil {
				t.Fatal(err)
			}
			<-gotRequest
			if who == "client" {
				_ = h.clientRaw.Close()
			} else {
				_, err := http.ReadResponse(bufio.NewReader(h.client), nil)
				if err == nil {
					t.Fatal("got a response from a site that hung up")
				}
			}
			if outcome := h.outcome(t); outcome != mitmOutcomeHTTP1Failed {
				t.Fatalf("outcome %q", outcome)
			}
			select {
			case err := <-siteDone:
				if err != nil {
					t.Fatal(err)
				}
			case <-time.After(3 * time.Second):
				t.Fatal("site was not released")
			}
		})
	}
}

// A TLS record that arrives slowly, in pieces, after the hello wait must be
// passed through byte for byte with an explicit outcome; a slow non-TLS
// protocol must be passed through without one.
func TestMitmSelectorSlowRecordReportsPassthroughOverSockets(t *testing.T) {
	sni := []byte{0, 0, 0, 16, 0, 14, 0, 0, 11, 'e', 'x', 'a', 'm', 'p', 'l', 'e', '.', 'c', 'o', 'm'}
	hello := helloFixture(sni)
	tlsRecord := append([]byte{0x16, 3, 3, byte(len(hello) >> 8), byte(len(hello))}, hello...)
	for _, tc := range []struct {
		name          string
		first, rest   []byte
		host          string
		wantOutcome   bool
		wantIntercept bool
	}{
		{"tls listed host", tlsRecord[:9], tlsRecord[9:], "example.com", true, true},
		{"tls ip only", tlsRecord[:9], tlsRecord[9:], "", true, true},
		{"tls header only", tlsRecord[:1], tlsRecord[1:], "example.com", true, true},
		{"non tls", []byte("GET / HT"), []byte("TP/1.1\r\nHost: example.com\r\n\r\n"), "example.com", false, false},
		{"silent", nil, []byte("late"), "example.com", false, false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			app := newFakeMitmApp(t)
			withMitmSigner(t, app, []string{"example.com"}, nil)
			oldWait := mitmHelloWait
			mitmHelloWait = 200 * time.Millisecond
			defer func() { mitmHelloWait = oldWait }()
			events := make(chan MitmConnection, 4)
			oldSend := sendMitmConnection
			sendMitmConnection = func(event *MitmConnection) bool { events <- *event; return true }
			defer func() { sendMitmConnection = oldSend }()
			clientRaw, proxyRaw := mitmLoopbackPair(t)
			defer clientRaw.Close()
			defer proxyRaw.Close()
			proxySite, siteRaw := mitmLoopbackPair(t)
			defer proxySite.Close()
			defer siteRaw.Close()
			if len(tc.first) > 0 {
				if _, err := clientRaw.Write(tc.first); err != nil {
					t.Fatal(err)
				}
			}
			client := N.NewBufferedConn(proxyRaw)
			started := time.Now()
			selected := mitmInterceptEligible(client, &C.Metadata{Host: tc.host})
			if elapsed := time.Since(started); elapsed > 2*time.Second {
				t.Fatalf("selector waited %v", elapsed)
			}
			if (selected != nil) != tc.wantIntercept {
				t.Fatalf("selected=%v", selected != nil)
			}
			relayed := make(chan struct{})
			go func() {
				defer close(relayed)
				if selected != nil {
					selected(client, mitmSelectionConn{N.NewExtendedConn(proxySite)})
				} else {
					N.Relay(client, proxySite)
				}
			}()
			// The rest arrives well after the wait; the deadline was cleared.
			time.Sleep(300 * time.Millisecond)
			if _, err := clientRaw.Write(tc.rest); err != nil {
				t.Fatal(err)
			}
			want := append(append([]byte{}, tc.first...), tc.rest...)
			got := make([]byte, len(want))
			if _, err := io.ReadFull(siteRaw, got); err != nil || !bytes.Equal(got, want) {
				t.Fatalf("relayed %q: %v", got, err)
			}
			_ = clientRaw.Close()
			_ = siteRaw.Close()
			<-relayed
			select {
			case event := <-events:
				if !tc.wantOutcome || event.Outcome != mitmOutcomeUnsupportedHello || event.Id != "selection-test" {
					t.Fatalf("event %+v", event)
				}
			default:
				if tc.wantOutcome {
					t.Fatal("no passthrough outcome")
				}
			}
		})
	}
}

// The response reader starts with the upload. An upload that keeps making
// progress for longer than the idle timeout must not expire that reader; a
// site that then stays silent for the idle timeout still does.
func TestMitmDuplexUploadProgressKeepsResponseReaderAlive(t *testing.T) {
	for _, silent := range []bool{false, true} {
		t.Run(fmt.Sprintf("silent=%v", silent), func(t *testing.T) {
			client, pcRaw := mitmLoopbackPair(t)
			psRaw, site := mitmLoopbackPair(t)
			defer client.Close()
			defer site.Close()
			const idle = 300 * time.Millisecond
			pc := &mitmIdleConn{Conn: pcRaw, timeout: idle}
			ps := &mitmIdleConn{Conn: psRaw, timeout: idle}
			done := make(chan error, 1)
			go func() {
				err := mitmHTTP1Duplex(pc, ps, "example.com", func() bool { return true }, &mitmDuplexControl{client: pc, upstream: ps})
				_ = pcRaw.Close()
				_ = psRaw.Close()
				done <- err
			}()
			const pieces = 12 // 12 × 100 ms ≈ four idle periods of upload
			siteDone := make(chan error, 1)
			go func() {
				req, err := http.ReadRequest(bufio.NewReader(site))
				if err == nil {
					var body []byte
					if body, err = io.ReadAll(req.Body); err == nil && len(body) != pieces {
						err = fmt.Errorf("body %q", body)
					}
				}
				if err == nil && silent {
					time.Sleep(4 * idle)
				}
				if err == nil {
					_, err = io.WriteString(site, "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok")
				}
				siteDone <- err
			}()
			if _, err := fmt.Fprintf(client, "POST / HTTP/1.1\r\nHost: example.com\r\nContent-Length: %d\r\n\r\n", pieces); err != nil {
				t.Fatal(err)
			}
			for i := 0; i < pieces; i++ {
				time.Sleep(idle / 3)
				if _, err := client.Write([]byte("x")); err != nil {
					t.Fatal(err)
				}
			}
			resp, err := http.ReadResponse(bufio.NewReader(client), nil)
			if silent {
				if err == nil {
					t.Fatal("a silent site outlived the idle timeout")
				}
			} else if err != nil || resp.StatusCode != 200 {
				t.Fatalf("response %v %v", resp, err)
			}
			select {
			case err := <-done:
				if silent == (err == nil) {
					t.Fatalf("relay error %v", err)
				}
			case <-time.After(3 * time.Second):
				t.Fatal("relay did not stop")
			}
			<-siteDone
		})
	}
}
