package core

import (
	"bufio"
	"bytes"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"strconv"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

// memoryHTTP is a deterministic in-memory peer; it does not use a socket.
type memoryHTTP struct {
	input  *strings.Reader
	output bytes.Buffer
}

func (m *memoryHTTP) Read(p []byte) (int, error)  { return m.input.Read(p) }
func (m *memoryHTTP) Write(p []byte) (int, error) { return m.output.Write(p) }
func httpPeer(s string) *memoryHTTP               { return &memoryHTTP{input: strings.NewReader(s)} }

// Ensure EOF between complete requests is a normal close.
func TestMitmDuplexEmptyConnection(t *testing.T) {
	client, site := httpPeer(""), httpPeer("")
	if err := mitmHTTP1Duplex(client, site, "example.com", func() bool { return true }, nil); err != nil {
		t.Fatal(err)
	}
	if site.output.Len() != 0 || client.output.Len() != 0 {
		t.Fatal("unexpected bytes")
	}
}

// A 103 after a completed upload is forwarded before the final response, and
// a fully completed exchange keeps both connections for the next request.
func TestMitmDuplexForwards103ThenFinalAndKeepsAlive(t *testing.T) {
	client, proxyClient := net.Pipe()
	proxySite, site := net.Pipe()
	defer client.Close()
	defer site.Close()
	_ = client.SetDeadline(time.Now().Add(4 * time.Second))
	_ = site.SetDeadline(time.Now().Add(4 * time.Second))
	pc := &mitmIdleConn{Conn: proxyClient, timeout: 2 * time.Second}
	ps := &mitmIdleConn{Conn: proxySite, timeout: 2 * time.Second}
	completed := make(chan error, 2)
	done := make(chan error, 1)
	go func() {
		defer proxyClient.Close()
		defer proxySite.Close()
		done <- mitmHTTP1Duplex(pc, ps, "example.com", func() bool { return true }, &mitmDuplexControl{client: pc, upstream: ps, uploadComplete: func(err error) { completed <- err }})
	}()
	siteDone := make(chan error, 1)
	go func() {
		r := bufio.NewReader(site)
		req, err := http.ReadRequest(r)
		if err == nil {
			var body []byte
			if body, err = io.ReadAll(req.Body); err == nil && string(body) != "data" {
				err = fmt.Errorf("body %q", body)
			}
		}
		if err == nil {
			err = <-completed
		}
		if err == nil {
			_, err = io.WriteString(site, "HTTP/1.1 103 Early Hints\r\nLink: </a>; rel=preload\r\n\r\nHTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok")
		}
		if err == nil {
			if req, err = http.ReadRequest(r); err == nil && req.URL.Path != "/two" {
				err = fmt.Errorf("second request %q", req.URL.Path)
			}
		}
		if err == nil {
			_, err = io.WriteString(site, "HTTP/1.1 204 No Content\r\nConnection: close\r\n\r\n")
		}
		siteDone <- err
	}()
	if _, err := io.WriteString(client, "POST /one HTTP/1.1\r\nHost: example.com\r\nContent-Length: 4\r\n\r\ndata"); err != nil {
		t.Fatal(err)
	}
	reader := bufio.NewReader(client)
	hint, err := http.ReadResponse(reader, nil)
	if err != nil || hint.StatusCode != 103 || hint.Header.Get("Link") == "" {
		t.Fatalf("interim %v %v", hint, err)
	}
	final, err := http.ReadResponse(reader, nil)
	if err != nil || final.StatusCode != 200 || final.Close {
		t.Fatalf("final %v %v", final, err)
	}
	if body, err := io.ReadAll(final.Body); err != nil || string(body) != "ok" {
		t.Fatalf("body %q: %v", body, err)
	}
	if _, err := io.WriteString(client, "GET /two HTTP/1.1\r\nHost: example.com\r\n\r\n"); err != nil {
		t.Fatal(err)
	}
	if second, err := http.ReadResponse(reader, nil); err != nil || second.StatusCode != 204 {
		t.Fatalf("second %v %v", second, err)
	}
	if err := <-siteDone; err != nil {
		t.Fatal(err)
	}
	if err := <-done; err != nil {
		t.Fatal(err)
	}
}

// Exercise the production duplex path with an incomplete body. A final response
// must arrive without consuming the rest of the body or parsing a new request.
func TestMitmDuplexEarlyFinalPartialBodies(t *testing.T) {
	for _, framing := range []string{"length", "chunked"} {
		for _, status := range []string{"401 Unauthorized", "413 Payload Too Large"} {
			t.Run(framing+"/"+status, func(t *testing.T) {
				client, pcRaw := net.Pipe()
				psRaw, site := net.Pipe()
				defer client.Close()
				defer site.Close()
				_ = client.SetDeadline(time.Now().Add(4 * time.Second))
				_ = site.SetDeadline(time.Now().Add(4 * time.Second))
				pc := &mitmIdleConn{Conn: pcRaw, timeout: 2 * time.Second}
				ps := &mitmIdleConn{Conn: psRaw, timeout: 2 * time.Second}
				done := make(chan error, 1)
				go func() {
					err := mitmHTTP1Duplex(pc, ps, "example.com", func() bool { return true }, &mitmDuplexControl{client: pc, upstream: ps})
					_ = pcRaw.Close()
					_ = psRaw.Close()
					done <- err
				}()
				siteDone := make(chan error, 1)
				partialSent := make(chan struct{})
				go func() {
					reader := bufio.NewReader(site)
					_, err := http.ReadRequest(reader)
					<-partialSent
					if err == nil {
						_, err = io.WriteString(site, "HTTP/1.1 "+status+"\r\nContent-Length: 3\r\n\r\nno!")
					}
					if err == nil {
						b, e := io.ReadAll(reader)
						if e != nil || bytes.Contains(b, []byte("POST /")) {
							err = fmt.Errorf("unexpected upstream bytes %q: %v", b, e)
						}
					}
					siteDone <- err
				}()
				header, body := "Content-Length: 1000000\r\n", "abc"
				if framing == "chunked" {
					header, body = "Transfer-Encoding: chunked\r\n", "3\r\nabc\r\n"
				}
				if _, err := io.WriteString(client, "POST / HTTP/1.1\r\nHost: example.com\r\n"+header+"\r\n"+body); err != nil {
					t.Fatal(err)
				}
				close(partialSent)
				resp, err := http.ReadResponse(bufio.NewReader(client), nil)
				if err != nil {
					t.Fatal(err)
				}
				b, err := io.ReadAll(resp.Body)
				if err != nil || string(b) != "no!" || !resp.Close || !strings.HasPrefix(status, strconv.Itoa(resp.StatusCode)) {
					t.Fatalf("response %+v body %q: %v", resp, b, err)
				}
				select {
				case err := <-done:
					if err != nil {
						t.Fatal(err)
					}
				case <-time.After(2 * time.Second):
					t.Fatal("relay did not stop")
				}
				select {
				case err := <-siteDone:
					if err != nil {
						t.Fatal(err)
					}
				case <-time.After(2 * time.Second):
					t.Fatal("site did not stop")
				}
			})
		}
	}
}

func TestMitmDuplexRejectsSwitchAndLimitsInterim(t *testing.T) {
	for _, tc := range []struct {
		name, response string
		allowed        int
	}{
		{"switch", "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\n\r\n", 0},
		{"nine", strings.Repeat("HTTP/1.1 100 Continue\r\n\r\n", 9), 8},
	} {
		t.Run(tc.name, func(t *testing.T) {
			client, proxyClient := net.Pipe()
			proxySite, site := net.Pipe()
			defer client.Close()
			defer site.Close()
			_ = client.SetDeadline(time.Now().Add(3 * time.Second))
			_ = site.SetDeadline(time.Now().Add(3 * time.Second))
			pc := &mitmIdleConn{Conn: proxyClient, timeout: time.Second}
			ps := &mitmIdleConn{Conn: proxySite, timeout: time.Second}
			done := make(chan error, 1)
			go func() {
				defer proxyClient.Close()
				defer proxySite.Close()
				done <- mitmHTTP1Duplex(pc, ps, "example.com", func() bool { return true }, &mitmDuplexControl{client: pc, upstream: ps})
			}()
			go func() { _, _ = io.WriteString(client, "GET / HTTP/1.1\r\nHost: example.com\r\n\r\n") }()
			siteDone := make(chan struct{})
			go func() {
				defer close(siteDone)
				_, err := http.ReadRequest(bufio.NewReader(site))
				if err == nil {
					_, _ = io.WriteString(site, tc.response)
				}
			}()
			reader := bufio.NewReader(client)
			for i := 0; i < tc.allowed; i++ {
				r, err := http.ReadResponse(reader, nil)
				if err != nil || r.StatusCode != 100 {
					t.Fatalf("interim %d: %v %v", i, r, err)
				}
			}
			if _, err := http.ReadResponse(reader, nil); err == nil {
				t.Fatal("unexpected response forwarded")
			}
			select {
			case err := <-done:
				if !errors.Is(err, errMitmHTTP1) {
					t.Fatalf("got %v", err)
				}
			case <-time.After(2 * time.Second):
				t.Fatal("relay did not join")
			}
			<-siteDone
		})
	}
}

func TestMitmDuplexChunkedTrailersAndReuse(t *testing.T) {
	client, proxyClient := net.Pipe()
	proxySite, site := net.Pipe()
	defer client.Close()
	defer site.Close()
	_ = client.SetDeadline(time.Now().Add(4 * time.Second))
	_ = site.SetDeadline(time.Now().Add(4 * time.Second))
	pc := &mitmIdleConn{Conn: proxyClient, timeout: 2 * time.Second}
	ps := &mitmIdleConn{Conn: proxySite, timeout: 2 * time.Second}
	completed := make(chan error, 2)
	done := make(chan error, 1)
	go func() {
		defer proxyClient.Close()
		defer proxySite.Close()
		done <- mitmHTTP1Duplex(pc, ps, "example.com", func() bool { return true }, &mitmDuplexControl{client: pc, upstream: ps, uploadComplete: func(err error) { completed <- err }})
	}()
	siteDone := make(chan error, 1)
	go func() {
		r := bufio.NewReader(site)
		req, err := http.ReadRequest(r)
		if err != nil {
			siteDone <- err
			return
		}
		body, err := io.ReadAll(req.Body)
		if err != nil {
			siteDone <- err
			return
		}
		if string(body) != "data" || req.Trailer.Get("X-Check") != "yes" {
			siteDone <- errors.New("request body or trailer missing")
			return
		}
		if err = <-completed; err != nil {
			siteDone <- err
			return
		}
		if _, err = io.WriteString(site, "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nTrailer: X-Result\r\n\r\n2\r\nok\r\n0\r\nX-Result: done\r\n\r\n"); err != nil {
			siteDone <- err
			return
		}
		req, err = http.ReadRequest(r)
		if err != nil {
			siteDone <- err
			return
		}
		if req.URL.Path != "/second" {
			siteDone <- errors.New("second request missing")
			return
		}
		_, err = io.WriteString(site, "HTTP/1.1 204 No Content\r\nConnection: close\r\n\r\n")
		siteDone <- err
	}()
	if _, err := io.WriteString(client, "POST /first HTTP/1.1\r\nHost: example.com\r\nTransfer-Encoding: chunked\r\nTrailer: X-Check\r\n\r\n4\r\ndata\r\n0\r\nX-Check: yes\r\n\r\n"); err != nil {
		t.Fatal(err)
	}
	reader := bufio.NewReader(client)
	resp, err := http.ReadResponse(reader, nil)
	if err != nil {
		t.Fatal(err)
	}
	body, err := io.ReadAll(resp.Body)
	if err != nil || string(body) != "ok" || resp.Trailer.Get("X-Result") != "done" {
		t.Fatalf("body %q trailer %v error %v", body, resp.Trailer, err)
	}
	if _, err = io.WriteString(client, "GET /second HTTP/1.1\r\nHost: example.com\r\nConnection: close\r\n\r\n"); err != nil {
		t.Fatal(err)
	}
	resp, err = http.ReadResponse(reader, nil)
	if err != nil || resp.StatusCode != 204 {
		t.Fatalf("second response %v %v", resp, err)
	}
	if err = <-siteDone; err != nil {
		t.Fatal(err)
	}
	if err = <-done; err != nil {
		t.Fatal(err)
	}
}

func TestMitmDuplexMalformedChunkDoesNotReplay(t *testing.T) {
	client, proxyClient := net.Pipe()
	proxySite, site := net.Pipe()
	defer client.Close()
	defer site.Close()
	_ = client.SetDeadline(time.Now().Add(4 * time.Second))
	_ = site.SetDeadline(time.Now().Add(4 * time.Second))
	pc := &mitmIdleConn{Conn: proxyClient, timeout: 2 * time.Second}
	ps := &mitmIdleConn{Conn: proxySite, timeout: 2 * time.Second}
	done := make(chan error, 1)
	go func() {
		defer proxyClient.Close()
		defer proxySite.Close()
		done <- mitmHTTP1Duplex(pc, ps, "example.com", func() bool { return true }, &mitmDuplexControl{client: pc, upstream: ps})
	}()
	siteDone := make(chan error, 1)
	go func() {
		req, err := http.ReadRequest(bufio.NewReader(site))
		if err == nil {
			_, err = io.ReadAll(req.Body)
		}
		siteDone <- err
	}()
	go func() {
		_, _ = io.WriteString(client, "POST / HTTP/1.1\r\nHost: example.com\r\nTransfer-Encoding: chunked\r\n\r\nxyz\r\nGET /replay HTTP/1.1\r\nHost: example.com\r\n\r\n")
	}()
	select {
	case err := <-done:
		if err == nil {
			t.Fatal("malformed upload accepted")
		}
	case <-time.After(3 * time.Second):
		t.Fatal("relay did not cancel response reader")
	}
	if err := <-siteDone; err == nil {
		t.Fatal("upstream saw complete chunked body")
	}
}

func TestMitmDuplexTruncatedAndCloseDelimitedResponses(t *testing.T) {
	for _, tc := range []struct {
		name, wire string
		wantErr    bool
	}{
		{"truncated length", "HTTP/1.1 200 OK\r\nContent-Length: 6\r\n\r\nhi", true},
		{"truncated chunk trailer", "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nTrailer: X-Foo\r\n\r\n2\r\nhi\r\n0\r\nX-Foo: incomplete", true},
		{"close delimited", "HTTP/1.1 200 OK\r\nConnection: close\r\n\r\nhi", false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			client, pcRaw := mitmLoopbackPair(t)
			psRaw, site := mitmLoopbackPair(t)
			defer client.Close()
			defer site.Close()
			_ = client.SetDeadline(time.Now().Add(4 * time.Second))
			_ = site.SetDeadline(time.Now().Add(4 * time.Second))
			pc := &mitmIdleConn{Conn: pcRaw, timeout: 2 * time.Second}
			ps := &mitmIdleConn{Conn: psRaw, timeout: 2 * time.Second}
			done := make(chan error, 1)
			go func() {
				err := mitmHTTP1Duplex(pc, ps, "example.com", func() bool { return true }, &mitmDuplexControl{client: pc, upstream: ps})
				_ = pcRaw.Close()
				_ = psRaw.Close()
				done <- err
			}()
			siteDone := make(chan error, 1)
			go func() {
				_, err := http.ReadRequest(bufio.NewReader(site))
				if err == nil {
					_, err = io.WriteString(site, tc.wire)
				}
				_ = site.Close()
				siteDone <- err
			}()
			if _, err := io.WriteString(client, "GET / HTTP/1.1\r\nHost: example.com\r\nConnection: close\r\n\r\n"); err != nil {
				t.Fatal(err)
			}
			resp, err := http.ReadResponse(bufio.NewReader(client), nil)
			if err != nil {
				t.Fatal(err)
			}
			body, bodyErr := io.ReadAll(resp.Body)
			if tc.wantErr && bodyErr == nil {
				t.Fatalf("accepted truncated response: %q", body)
			}
			if !tc.wantErr && (bodyErr != nil || string(body) != "hi" || !resp.Close) {
				t.Fatalf("body=%q close=%v error=%v", body, resp.Close, bodyErr)
			}
			if err = <-siteDone; err != nil {
				t.Fatal(err)
			}
			err = <-done
			if tc.wantErr == (err == nil) {
				t.Fatalf("relay error: %v", err)
			}
		})
	}
}

func TestMitmDuplexTruncatedRequestsStopWithoutReplay(t *testing.T) {
	for _, tc := range []struct{ name, wire string }{
		{"length", "POST / HTTP/1.1\r\nHost: example.com\r\nContent-Length: 8\r\n\r\nabc"},
		{"chunk trailer", "POST / HTTP/1.1\r\nHost: example.com\r\nTransfer-Encoding: chunked\r\nTrailer: X-Foo\r\n\r\n1\r\na\r\n0\r\nX-Foo: incomplete"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			client, pcRaw := net.Pipe()
			psRaw, site := net.Pipe()
			defer client.Close()
			defer site.Close()
			_ = client.SetDeadline(time.Now().Add(4 * time.Second))
			_ = site.SetDeadline(time.Now().Add(4 * time.Second))
			pc := &mitmIdleConn{Conn: pcRaw, timeout: 2 * time.Second}
			ps := &mitmIdleConn{Conn: psRaw, timeout: 2 * time.Second}
			done := make(chan error, 1)
			go func() {
				err := mitmHTTP1Duplex(pc, ps, "example.com", func() bool { return true }, &mitmDuplexControl{client: pc, upstream: ps})
				_ = pcRaw.Close()
				_ = psRaw.Close()
				done <- err
			}()
			siteDone := make(chan error, 1)
			go func() {
				req, err := http.ReadRequest(bufio.NewReader(site))
				if err == nil {
					_, err = io.ReadAll(req.Body)
				}
				siteDone <- err
			}()
			if _, err := io.WriteString(client, tc.wire); err != nil {
				t.Fatal(err)
			}
			_ = client.Close()
			select {
			case err := <-done:
				if err == nil {
					t.Fatal("incomplete upload succeeded")
				}
			case <-time.After(3 * time.Second):
				t.Fatal("workers did not terminate")
			}
			if err := <-siteDone; err == nil {
				t.Fatal("upstream observed completed framing")
			}
		})
	}
}

func TestMitmDuplexExpectContinue(t *testing.T) {
	for _, mode := range []string{"continue", "reject", "timeout"} {
		t.Run(mode, func(t *testing.T) {
			client, pcRaw := net.Pipe()
			psRaw, site := net.Pipe()
			defer client.Close()
			defer site.Close()
			_ = client.SetDeadline(time.Now().Add(4 * time.Second))
			_ = site.SetDeadline(time.Now().Add(4 * time.Second))
			timeout := 2 * time.Second
			if mode == "timeout" {
				timeout = 150 * time.Millisecond
			}
			pc := &mitmIdleConn{Conn: pcRaw, timeout: timeout}
			ps := &mitmIdleConn{Conn: psRaw, timeout: 2 * time.Second}
			done := make(chan error, 1)
			go func() {
				err := mitmHTTP1Duplex(pc, ps, "example.com", func() bool { return true }, &mitmDuplexControl{client: pc, upstream: ps})
				_ = pcRaw.Close()
				_ = psRaw.Close()
				done <- err
			}()
			release := make(chan struct{})
			defer close(release)
			siteDone := make(chan error, 1)
			go func() {
				req, err := http.ReadRequest(bufio.NewReader(site))
				if err != nil {
					siteDone <- err
					return
				}
				if req.Header.Get("Expect") != "100-continue" {
					siteDone <- errors.New("expect header missing")
					return
				}
				switch mode {
				case "continue":
					_, err = io.WriteString(site, "HTTP/1.1 100 Continue\r\n\r\n")
					if err == nil {
						var body []byte
						body, err = io.ReadAll(req.Body)
						if err == nil && string(body) != "data" {
							err = errors.New("unexpected upload")
						}
					}
					if err == nil {
						_, err = io.WriteString(site, "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok")
					}
				case "reject":
					_, err = io.WriteString(site, "HTTP/1.1 413 Payload Too Large\r\nContent-Length: 0\r\n\r\n")
				case "timeout":
					<-release
				}
				siteDone <- err
			}()
			if _, err := io.WriteString(client, "POST / HTTP/1.1\r\nHost: example.com\r\nExpect: 100-continue\r\nContent-Length: 4\r\nConnection: close\r\n\r\n"); err != nil {
				t.Fatal(err)
			}
			reader := bufio.NewReader(client)
			if mode == "timeout" {
				select {
				case err := <-done:
					if err == nil {
						t.Fatal("timeout accepted")
					}
				case <-time.After(3 * time.Second):
					t.Fatal("timeout did not stop workers")
				}
				return
			}
			resp, err := http.ReadResponse(reader, nil)
			if err != nil {
				t.Fatal(err)
			}
			if mode == "continue" {
				if resp.StatusCode != 100 {
					t.Fatalf("got %d", resp.StatusCode)
				}
				if _, err = io.WriteString(client, "data"); err != nil {
					t.Fatal(err)
				}
				resp, err = http.ReadResponse(reader, nil)
				if err != nil || resp.StatusCode != 200 {
					t.Fatalf("final response %v %v", resp, err)
				}
				body, err := io.ReadAll(resp.Body)
				if err != nil || string(body) != "ok" {
					t.Fatalf("body %q err %v", body, err)
				}
			} else if resp.StatusCode != 413 || !resp.Close {
				t.Fatalf("reject response %+v", resp)
			}
			if err = <-siteDone; err != nil {
				t.Fatal(err)
			}
			if err = <-done; err != nil {
				t.Fatal(err)
			}
		})
	}
}

func TestMitmDuplexRejectsUnsafeRequests(t *testing.T) {
	for _, request := range []string{
		"GET / HTTP/1.0\r\nHost: example.com\r\n\r\n",
		"PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n",
		"GET / HTTP/1.1\r\nHost: other.com\r\n\r\n",
		"CONNECT example.com:443 HTTP/1.1\r\nHost: example.com\r\n\r\n",
		"GET http://example.com/ HTTP/1.1\r\nHost: example.com\r\n\r\n",
		"GET / HTTP/1.1\r\nHost: example.com\r\nUpgrade: websocket\r\n\r\n",
		"POST / HTTP/1.1\r\nHost: example.com\r\nExpect: unsupported\r\nContent-Length: 1\r\n\r\nx",
		"POST / HTTP/1.1\r\nHost: example.com\r\nContent-Length: 1\r\nTransfer-Encoding: chunked\r\n\r\n",
		"POST / HTTP/1.1\r\nHost: example.com\r\nContent-Length: 1\r\nContent-Length: 1\r\n\r\n",
		"GET / HTTP/1.1\r\nHost: example.com\r\nX: first\r\n continuation\r\n\r\n",
		"GET / HTTP/1.1\r\nHost: example.com\r\nX: first\nY: second\r\n\r\n",
		"GET / HTTP/1.1\r\nHost: example.com\r\nX: " + strings.Repeat("a", mitmHTTPHeaderLimit) + "\r\n\r\n",
	} {
		client, site := httpPeer(request), httpPeer("")
		if err := mitmHTTP1Duplex(client, site, "example.com", func() bool { return true }, nil); err == nil || site.output.Len() != 0 {
			t.Fatalf("accepted %q: %v", request, err)
		}
	}
}

type mitmSecondWriteConn struct {
	net.Conn
	count  atomic.Int32
	second chan struct{}
}

func (c *mitmSecondWriteConn) Write(p []byte) (int, error) {
	if c.count.Add(1) == 2 {
		close(c.second)
	}
	return c.Conn.Write(p)
}

func TestMitmDuplexEarlyFinalInterruptsBlockedUpstreamWrite(t *testing.T) {
	client, pcRaw := net.Pipe()
	psRaw, site := net.Pipe()
	defer client.Close()
	defer site.Close()
	_ = client.SetDeadline(time.Now().Add(4 * time.Second))
	_ = site.SetDeadline(time.Now().Add(4 * time.Second))
	observed := &mitmSecondWriteConn{Conn: psRaw, second: make(chan struct{})}
	pc := &mitmIdleConn{Conn: pcRaw, timeout: 2 * time.Second}
	ps := &mitmIdleConn{Conn: observed, timeout: 2 * time.Second}
	done := make(chan error, 1)
	go func() {
		err := mitmHTTP1Duplex(pc, ps, "example.com", func() bool { return true }, &mitmDuplexControl{client: pc, upstream: ps})
		_ = pcRaw.Close()
		_ = psRaw.Close()
		done <- err
	}()
	siteDone := make(chan error, 1)
	go func() {
		_, err := http.ReadRequest(bufio.NewReader(site))
		if err == nil {
			<-observed.second
			_, err = io.WriteString(site, "HTTP/1.1 413 Payload Too Large\r\nContent-Length: 0\r\n\r\n")
		}
		siteDone <- err
	}()
	if _, err := io.WriteString(client, "POST / HTTP/1.1\r\nHost: example.com\r\nContent-Length: 1000000\r\n\r\n"); err != nil {
		t.Fatal(err)
	}
	writer := make(chan error, 1)
	go func() { _, err := client.Write(bytes.Repeat([]byte("x"), 1000000)); writer <- err }()
	resp, err := http.ReadResponse(bufio.NewReader(client), nil)
	if err != nil || resp.StatusCode != 413 || !resp.Close {
		t.Fatalf("response %v %v", resp, err)
	}
	select {
	case err := <-done:
		if err != nil {
			t.Fatal(err)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("relay did not join blocked upload")
	}
	if err = <-siteDone; err != nil {
		t.Fatal(err)
	}
	select {
	case <-writer:
	case <-time.After(time.Second):
		t.Fatal("client upload remained blocked")
	}
}

func TestMitmDuplexNoReplayOnSecondRequestOrInvalidation(t *testing.T) {
	for _, mode := range []string{"wrong host", "setup changed"} {
		t.Run(mode, func(t *testing.T) {
			client, pcRaw := net.Pipe()
			psRaw, site := net.Pipe()
			defer client.Close()
			defer site.Close()
			_ = client.SetDeadline(time.Now().Add(4 * time.Second))
			_ = site.SetDeadline(time.Now().Add(4 * time.Second))
			pc := &mitmIdleConn{Conn: pcRaw, timeout: 2 * time.Second}
			ps := &mitmIdleConn{Conn: psRaw, timeout: 2 * time.Second}
			var allowed atomic.Bool
			allowed.Store(true)
			published := make(chan struct{}, 1)
			control := &mitmDuplexControl{client: pc, upstream: ps, uploadComplete: func(error) {
				if mode == "setup changed" {
					allowed.Store(false)
				}
				published <- struct{}{}
			}}
			done := make(chan error, 1)
			go func() {
				err := mitmHTTP1Duplex(pc, ps, "example.com", allowed.Load, control)
				_ = pcRaw.Close()
				_ = psRaw.Close()
				done <- err
			}()
			siteDone := make(chan error, 1)
			go func() {
				reader := bufio.NewReader(site)
				req, err := http.ReadRequest(reader)
				if err != nil {
					siteDone <- err
					return
				}
				if req.URL.Path != "/first" {
					siteDone <- errors.New("wrong first request")
					return
				}
				<-published
				if _, err = io.WriteString(site, "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n"); err != nil {
					siteDone <- err
					return
				}
				_, err = http.ReadRequest(reader)
				if err == nil {
					siteDone <- errors.New("unexpected second request")
					return
				}
				siteDone <- nil
			}()
			if _, err := io.WriteString(client, "GET /first HTTP/1.1\r\nHost: example.com\r\n\r\n"); err != nil {
				t.Fatal(err)
			}
			if _, err := http.ReadResponse(bufio.NewReader(client), nil); err != nil {
				t.Fatal(err)
			}
			if mode == "wrong host" {
				if _, err := io.WriteString(client, "GET /second HTTP/1.1\r\nHost: other.com\r\n\r\n"); err != nil {
					t.Fatal(err)
				}
			}
			err := <-done
			if mode == "wrong host" && !errors.Is(err, errMitmHTTP1) {
				t.Fatalf("error %v", err)
			}
			if mode == "setup changed" && !errors.Is(err, errMitmSetupChanged) {
				t.Fatalf("error %v", err)
			}
			if err := <-siteDone; err != nil {
				t.Fatal(err)
			}
		})
	}
}

// An interim write must not prevent upload-failure or lifecycle cancellation.
func TestMitmDuplexBlockedInterimWriteStops(t *testing.T) {
	for _, mode := range []string{"upload failure", "lifecycle"} {
		t.Run(mode, func(t *testing.T) {
			client, pcRaw := net.Pipe()
			psRaw, site := net.Pipe()
			defer client.Close()
			defer site.Close()
			_ = client.SetDeadline(time.Now().Add(5 * time.Second))
			_ = site.SetDeadline(time.Now().Add(5 * time.Second))
			// Signal on the first write, before it blocks on the unread client.
			signaled := &mitmFirstWriteConn{Conn: pcRaw, started: make(chan struct{})}
			pc := &mitmIdleConn{Conn: signaled, timeout: 4 * time.Second}
			ps := &mitmIdleConn{Conn: psRaw, timeout: 4 * time.Second}
			control := &mitmDuplexControl{client: pc, upstream: ps}
			done := make(chan error, 1)
			go func() {
				err := mitmHTTP1Duplex(pc, ps, "example.com", func() bool { return true }, control)
				_ = pcRaw.Close()
				_ = psRaw.Close()
				done <- err
			}()
			siteDone := make(chan error, 1)
			go func() {
				_, err := http.ReadRequest(bufio.NewReader(site))
				if err == nil {
					_, err = io.WriteString(site, "HTTP/1.1 103 Early Hints\r\n\r\n")
				}
				siteDone <- err
			}()
			if _, err := io.WriteString(client, "POST / HTTP/1.1\r\nHost: example.com\r\nTransfer-Encoding: chunked\r\n\r\n"); err != nil {
				t.Fatal(err)
			}
			select {
			case <-signaled.started:
			case <-time.After(2 * time.Second):
				t.Fatal("interim write not started")
			}
			if mode == "upload failure" {
				if _, err := io.WriteString(client, "Z\r\n"); err != nil {
					t.Fatal(err)
				}
			} else {
				// Runtime replacement/liveness closes the registered raw pair.
				_ = pcRaw.Close()
				_ = psRaw.Close()
			}
			select {
			case err := <-done:
				if err == nil {
					t.Fatal("expected failure")
				}
			case <-time.After(2500 * time.Millisecond):
				t.Fatal("blocked interim write prevented shutdown")
			}
			if err := <-siteDone; err != nil {
				t.Fatal(err)
			}
		})
	}
}

type mitmFirstWriteConn struct {
	net.Conn
	started chan struct{}
	once    atomic.Bool
}

func (c *mitmFirstWriteConn) Write(p []byte) (int, error) {
	if c.once.CompareAndSwap(false, true) {
		close(c.started)
	}
	return c.Conn.Write(p)
}
