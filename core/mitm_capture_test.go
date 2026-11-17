package core

import (
	"bufio"
	"bytes"
	"compress/gzip"
	"crypto/tls"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/metacubex/mihomo/log"
)

// A remote that names its tracker, as the tunnel's tracked dial does.
type mitmTrackedConn struct {
	net.Conn
	id string
}

func (c mitmTrackedConn) ID() string { return c.id }

// Fresh, enabled capture with the given limits; restored afterwards.
func withMitmCapture(t *testing.T, limits mitmCaptureLimits) {
	t.Helper()
	s := mitmCaptures
	s.mu.Lock()
	previousLimits, previousEnabled := s.limits, s.enabled
	s.limits = limits
	s.mu.Unlock()
	s.clear()
	s.setEnabled(true)
	oldSend := sendMitmConnection
	sendMitmConnection = func(*MitmConnection) bool { return true }
	t.Cleanup(func() {
		sendMitmConnection = oldSend
		s.setEnabled(previousEnabled)
		s.clear()
		s.mu.Lock()
		s.limits = previousLimits
		s.open = map[string]int{}
		s.mu.Unlock()
	})
}

// The TLS harness with a tracked remote, so the session records under id.
func newMitmCaptureHarness(t *testing.T, id string) *mitmTLSHarness {
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
		h.done <- serveMitm(h.proxyClient, mitmTrackedConn{h.proxySite, id}, "example.com", &mitmLeaf{cert: cert}, runtime)
	}()
	h.client = tls.Client(mitmStrictTLSConn{h.clientRaw}, &tls.Config{ServerName: "example.com", RootCAs: roots})
	return h
}

func mitmGzip(t *testing.T, text string) []byte {
	t.Helper()
	var b bytes.Buffer
	w := gzip.NewWriter(&b)
	_, _ = w.Write([]byte(text))
	if err := w.Close(); err != nil {
		t.Fatal(err)
	}
	return b.Bytes()
}

func mitmBodyText(t *testing.T, id uint64, response bool) (string, *MitmBody) {
	t.Helper()
	body := handleMitmBody(MitmBodyParams{ID: id, Response: response})
	if body == nil {
		t.Fatalf("body %d gone", id)
	}
	data, err := base64.StdEncoding.DecodeString(body.Data)
	if err != nil {
		t.Fatal(err)
	}
	return string(data), body
}

// Two requests on one decrypted keep-alive connection are recorded in order
// with their heads, decoded bodies, sizes and timing; the list says the
// connection is open until the session ends.
func TestMitmCaptureRecordsDecryptedExchanges(t *testing.T) {
	withMitmCapture(t, mitmDefaultCaptureLimits)
	h := newMitmCaptureHarness(t, "tracker-a")
	gz := mitmGzip(t, `{"hello":"world"}`)
	siteDone := make(chan error, 1)
	go func() {
		site := h.site()
		r := bufio.NewReader(site)
		for i, wire := range []string{
			fmt.Sprintf("HTTP/1.1 201 Created\r\nContent-Type: application/json\r\nContent-Encoding: gzip\r\nContent-Length: %d\r\n\r\n%s", len(gz), gz),
			"HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nX-Site: yes\r\n\r\n5\r\nhello\r\n6\r\n world\r\n0\r\n\r\n",
		} {
			req, err := http.ReadRequest(r)
			if err != nil {
				siteDone <- err
				return
			}
			_, _ = io.Copy(io.Discard, req.Body)
			if _, err = io.WriteString(site, wire); err != nil {
				siteDone <- fmt.Errorf("response %d: %w", i, err)
				return
			}
		}
		_, _ = io.ReadAll(r)
		siteDone <- nil
	}()
	reader := bufio.NewReader(h.client)
	if _, err := io.WriteString(h.client, "POST /api/items?x=1 HTTP/1.1\r\nHost: example.com\r\nContent-Type: text/plain\r\nContent-Length: 12\r\n\r\nrequest-body"); err != nil {
		t.Fatal(err)
	}
	resp, err := http.ReadResponse(reader, nil)
	if err != nil {
		t.Fatal(err)
	}
	_, _ = io.Copy(io.Discard, resp.Body)
	if _, err := io.WriteString(h.client, "GET /two HTTP/1.1\r\nHost: example.com\r\n\r\n"); err != nil {
		t.Fatal(err)
	}
	resp, err = http.ReadResponse(reader, nil)
	if err != nil {
		t.Fatal(err)
	}
	_, _ = io.Copy(io.Discard, resp.Body)

	list := handleMitmExchanges(MitmExchangesParams{ID: "tracker-a"})
	if !list.Capturing || list.Closed || list.Since == nil || len(list.Exchanges) != 2 {
		t.Fatalf("list %+v", list)
	}
	first, second := list.Exchanges[0], list.Exchanges[1]
	if first.Method != "POST" || first.URL != "https://example.com/api/items?x=1" || first.Status != 201 ||
		first.Pending || first.RequestSize != 12 || first.ResponseSize != int64(len(gz)) || first.Error != "" {
		t.Fatalf("first %+v", first)
	}
	if second.Method != "GET" || second.Status != 200 || second.ResponseSize != 11 || second.ID <= first.ID {
		t.Fatalf("second %+v", second)
	}
	exchange := handleMitmExchange(MitmExchangeParams{ID: first.ID})
	if exchange == nil || exchange.Proto != "HTTP/1.1" || exchange.Connection != "tracker-a" ||
		exchange.RequestHeader["Host"][0] != "example.com" || exchange.ResponseHeader["Content-Encoding"][0] != "gzip" {
		t.Fatalf("exchange %+v", exchange)
	}
	if _, present := exchange.RequestHeader["User-Agent"]; present {
		t.Fatal("recorded the proxy's own User-Agent suppression")
	}
	if text, _ := mitmBodyText(t, first.ID, false); text != "request-body" {
		t.Fatalf("request body %q", text)
	}
	if text, body := mitmBodyText(t, first.ID, true); text != `{"hello":"world"}` || body.Encoding != "" || body.Truncated {
		t.Fatalf("gzip response %q %+v", text, body)
	}
	if text, _ := mitmBodyText(t, second.ID, true); text != "hello world" {
		t.Fatalf("chunked response %q", text)
	}
	if got := handleMitmExchange(MitmExchangeParams{ID: second.ID}).ResponseHeader["Transfer-Encoding"]; len(got) != 1 || got[0] != "chunked" {
		t.Fatalf("transfer encoding %v", got)
	}
	_ = h.client.Close()
	if outcome := h.outcome(t); outcome != "" {
		t.Fatalf("outcome %q", outcome)
	}
	if !handleMitmExchanges(MitmExchangesParams{ID: "tracker-a"}).Closed {
		t.Fatal("connection still listed as open")
	}
	if err := <-siteDone; err != nil {
		t.Fatal(err)
	}
	if other := handleMitmExchanges(MitmExchangesParams{ID: "tracker-b"}); len(other.Exchanges) != 0 || !other.Closed {
		t.Fatalf("other connection %+v", other)
	}
}

// Bodies keep only their first max-body-size bytes, marked truncated, while
// the sizes count everything forwarded; the client still gets it all.
func TestMitmCaptureTruncatesBodies(t *testing.T) {
	withMitmCapture(t, mitmCaptureLimits{entries: 10, bytes: 1 << 20, body: 8})
	h := newMitmCaptureHarness(t, "tracker-t")
	siteDone := make(chan error, 1)
	go func() {
		site := h.site()
		req, err := http.ReadRequest(bufio.NewReader(site))
		if err == nil {
			_, _ = io.Copy(io.Discard, req.Body)
			_, err = io.WriteString(site, "HTTP/1.1 200 OK\r\nContent-Length: 20\r\nConnection: close\r\n\r\n0123456789abcdefghij")
		}
		_ = site.Close()
		siteDone <- err
	}()
	if _, err := io.WriteString(h.client, "PUT / HTTP/1.1\r\nHost: example.com\r\nContent-Length: 10\r\n\r\nABCDEFGHIJ"); err != nil {
		t.Fatal(err)
	}
	resp, err := http.ReadResponse(bufio.NewReader(h.client), nil)
	if err != nil {
		t.Fatal(err)
	}
	if body, _ := io.ReadAll(resp.Body); string(body) != "0123456789abcdefghij" {
		t.Fatalf("client got %q", body)
	}
	if outcome := h.outcome(t); outcome != "" {
		t.Fatalf("outcome %q", outcome)
	}
	if err := <-siteDone; err != nil {
		t.Fatal(err)
	}
	list := handleMitmExchanges(MitmExchangesParams{ID: "tracker-t"})
	if len(list.Exchanges) != 1 || list.Exchanges[0].RequestSize != 10 || list.Exchanges[0].ResponseSize != 20 {
		t.Fatalf("list %+v", list)
	}
	id := list.Exchanges[0].ID
	if text, body := mitmBodyText(t, id, false); text != "ABCDEFGH" || !body.Truncated {
		t.Fatalf("request %q %+v", text, body)
	}
	if text, body := mitmBodyText(t, id, true); text != "01234567" || !body.Truncated {
		t.Fatalf("response %q %+v", text, body)
	}
}

// An exchange the site breaks off is recorded as failed: before its
// response as noResponse, during its body as responseFailed.
func TestMitmCaptureRecordsFailedExchanges(t *testing.T) {
	for _, tc := range []struct {
		name, wire, want string
	}{
		{"no response", "", mitmExchangeNoResponse},
		{"cut body", "HTTP/1.1 200 OK\r\nContent-Length: 100\r\n\r\npartial", mitmExchangeResponseFailed},
	} {
		t.Run(tc.name, func(t *testing.T) {
			withMitmCapture(t, mitmDefaultCaptureLimits)
			h := newMitmCaptureHarness(t, "tracker-f")
			go func() {
				site := h.site()
				if _, err := http.ReadRequest(bufio.NewReader(site)); err == nil && tc.wire != "" {
					_, _ = io.WriteString(site, tc.wire)
				}
				_ = site.Close()
			}()
			if _, err := io.WriteString(h.client, "GET / HTTP/1.1\r\nHost: example.com\r\n\r\n"); err != nil {
				t.Fatal(err)
			}
			_, _ = io.ReadAll(h.client)
			if outcome := h.outcome(t); outcome != mitmOutcomeHTTP1Failed {
				t.Fatalf("outcome %q", outcome)
			}
			list := handleMitmExchanges(MitmExchangesParams{ID: "tracker-f"})
			if len(list.Exchanges) != 1 || list.Exchanges[0].Pending || list.Exchanges[0].Error != tc.want {
				t.Fatalf("list %+v", list)
			}
		})
	}
}

// With capture off nothing is recorded, and the list says so.
func TestMitmCaptureOffRecordsNothing(t *testing.T) {
	withMitmCapture(t, mitmDefaultCaptureLimits)
	mitmCaptures.setEnabled(false)
	h := newMitmCaptureHarness(t, "tracker-off")
	go func() {
		site := h.site()
		if _, err := http.ReadRequest(bufio.NewReader(site)); err == nil {
			_, _ = io.WriteString(site, "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok")
		}
		_ = site.Close()
	}()
	if _, err := io.WriteString(h.client, "GET / HTTP/1.1\r\nHost: example.com\r\n\r\n"); err != nil {
		t.Fatal(err)
	}
	_, _ = io.ReadAll(h.client)
	h.outcome(t)
	if list := handleMitmExchanges(MitmExchangesParams{ID: "tracker-off"}); list.Capturing || len(list.Exchanges) != 0 {
		t.Fatalf("list %+v", list)
	}
}

func mitmCaptureRequest(method, target string) *http.Request {
	req, _ := http.ReadRequest(bufio.NewReader(strings.NewReader(method + " " + target + " HTTP/1.1\r\nHost: example.com\r\n\r\n")))
	return req
}

// The oldest records go first past either limit, and since moves to the
// newest one dropped.
func TestMitmCaptureEvictsOldestPastItsLimits(t *testing.T) {
	withMitmCapture(t, mitmCaptureLimits{entries: 3, bytes: 1 << 20, body: 1 << 10})
	s := mitmCaptures
	var entries []*mitmCaptureEntry
	for i := 0; i < 5; i++ {
		entry := s.begin("c", "example.com", mitmCaptureRequest("GET", fmt.Sprintf("/%d", i)))
		s.finish(entry, "")
		entries = append(entries, entry)
		time.Sleep(time.Millisecond)
	}
	list := handleMitmExchanges(MitmExchangesParams{ID: "c"})
	if len(list.Exchanges) != 3 || list.Exchanges[0].URL != "https://example.com/2" {
		t.Fatalf("list %+v", list)
	}
	if !list.Since.Equal(entries[1].start) || handleMitmExchange(MitmExchangeParams{ID: entries[1].id}) != nil {
		t.Fatalf("since %v, dropped entry still served", list.Since)
	}
	// Bytes: a body large enough pushes out the others, oldest first, and
	// the record being written stays.
	s.mu.Lock()
	s.limits.bytes = 1100
	s.mu.Unlock()
	big := s.begin("c", "example.com", mitmCaptureRequest("POST", "/big"))
	s.write(big, false, bytes.Repeat([]byte("x"), 1000))
	s.mu.Lock()
	total, limit, kept := s.bytes, s.limits.bytes, len(s.order)
	s.mu.Unlock()
	if total > limit || kept != 1 || s.byID[big.id] == nil {
		t.Fatalf("bytes %d of %d, %d kept", total, limit, kept)
	}
	// A record dropped while its body still streams stays dropped.
	s.write(entries[4], true, []byte("late"))
	if entries[4].resp.size != 0 {
		t.Fatal("wrote into a dropped record")
	}
}

// Turning capture off, stopping decryption, a new root, the app leaving
// and shutdown all drop every record; a settings change that keeps
// decrypting with the same root keeps them.
func TestMitmCaptureIsClearedWhenDecryptionStopsOrChanges(t *testing.T) {
	withMitmState(t)
	decrypting := func(fingerprint string) *mitmRuntime {
		return &mitmRuntime{
			setup: MitmSetup{Enable: true, DecryptTLS: true, CAFingerprint: fingerprint, Hostname: []string{"example.com"}},
			hosts: compileMitmHosts([]string{"example.com"}),
		}
	}
	record := func() uint64 {
		entry := mitmCaptures.begin("c", "example.com", mitmCaptureRequest("GET", "/"))
		mitmCaptures.write(entry, true, []byte("secret"))
		mitmCaptures.finish(entry, "")
		return entry.id
	}
	kept := func(id uint64) bool { return handleMitmExchange(MitmExchangeParams{ID: id}) != nil }
	for _, tc := range []struct {
		name  string
		after func()
		keep  bool
	}{
		{"same root, new hostnames", func() {
			next := decrypting("AA")
			next.setup.Hostname = []string{"example.com", "example.org"}
			replaceMitmRuntime(next)
		}, true},
		{"capture off", func() { applyOptions(CoreOptions{}) }, false},
		{"decryption off", func() { replaceMitmRuntime(&mitmRuntime{}) }, false},
		{"new root", func() { replaceMitmRuntime(decrypting("BB")) }, false},
		{"app gone", mitmSignerGone, false},
		{"shutdown", func() { replaceMitmRuntime(nil) }, false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			withMitmCapture(t, mitmDefaultCaptureLimits)
			applyOptions(CoreOptions{MITMCapture: true})
			replaceMitmRuntime(decrypting("AA"))
			id := record()
			tc.after()
			if kept(id) != tc.keep {
				t.Fatalf("kept %v, want %v", kept(id), tc.keep)
			}
		})
	}
}

// gzip and deflate are undone up to the body limit; other codings, and a
// stream that fails, come back as received with the coding named.
func TestMitmDecodeBody(t *testing.T) {
	gz := mitmGzip(t, strings.Repeat("abc", 100))
	cases := []struct {
		name          string
		data          []byte
		truncated     bool
		coding        string
		limit         int64
		want          string
		wantTruncated bool
		wantEncoding  string
	}{
		{"identity", []byte("plain"), false, "", 100, "plain", false, ""},
		{"gzip", gz, false, "gzip", 1000, strings.Repeat("abc", 100), false, ""},
		{"gzip over limit", gz, false, "gzip", 10, "abcabcabca", true, ""},
		{"gzip kept start", gz[:len(gz)/2], true, "gzip", 1000, "", true, ""},
		{"corrupt gzip", []byte("not gzip"), false, "gzip", 1000, "not gzip", false, "gzip"},
		{"brotli", []byte{1, 2, 3}, false, "br", 1000, "\x01\x02\x03", false, "br"},
		{"stacked", []byte("x"), false, "gzip, br", 1000, "x", false, "gzip, br"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			out, truncated, encoding := mitmDecodeBody(tc.data, tc.truncated, tc.coding, tc.limit)
			if tc.name == "gzip kept start" {
				if !strings.HasPrefix(strings.Repeat("abc", 100), string(out)) || !truncated || encoding != "" {
					t.Fatalf("got %q %v %q", out, truncated, encoding)
				}
				return
			}
			if string(out) != tc.want || truncated != tc.wantTruncated || encoding != tc.wantEncoding {
				t.Fatalf("got %q %v %q", out, truncated, encoding)
			}
		})
	}
}

// The capture methods answer in the reply frame however large, never with a
// spilled file, and a record no longer kept answers null.
func TestMitmCaptureRepliesAreNeverSpilled(t *testing.T) {
	home := withSpillHome(t, 64)
	withMitmCapture(t, mitmDefaultCaptureLimits)
	entry := mitmCaptures.begin("c", "example.com", mitmCaptureRequest("GET", "/"))
	mitmCaptures.write(entry, true, bytes.Repeat([]byte("s"), 4096))
	mitmCaptures.finish(entry, "")
	for _, call := range []struct {
		method CoreMethod
		args   any
	}{
		{mitmExchangesMethod, MitmExchangesParams{ID: "c"}},
		{mitmExchangeMethod, MitmExchangeParams{ID: entry.id}},
		{mitmBodyMethod, MitmBodyParams{ID: entry.id, Response: true}},
	} {
		arguments, _ := json.Marshal(call.args)
		var envelope MethodResponse
		if err := json.Unmarshal(handleMethodCall(&MethodCall{ID: "1", Method: call.method, Arguments: arguments}), &envelope); err != nil {
			t.Fatal(err)
		}
		if envelope.File != "" || envelope.Error != nil || envelope.Result == nil {
			t.Fatalf("%s: %+v", call.method, envelope)
		}
	}
	if files, _ := os.ReadDir(filepath.Join(home, spilledResponseDirName)); len(files) != 0 {
		t.Fatalf("spilled %d files", len(files))
	}
	arguments, _ := json.Marshal(MitmBodyParams{ID: entry.id + 1})
	var envelope MethodResponse
	_ = json.Unmarshal(handleMethodCall(&MethodCall{ID: "2", Method: mitmBodyMethod, Arguments: arguments}), &envelope)
	if envelope.Result != nil || envelope.Error != nil {
		t.Fatalf("missing record %+v", envelope)
	}
}

// Nothing a decrypted request or response carried reaches the log stream,
// at any level, whether the exchange succeeds or fails.
func TestMitmCaptureKeepsTrafficOutOfLogs(t *testing.T) {
	const marker = "plaintext-marker-7f3a"
	previousLevel := log.Level()
	log.SetLevel(log.DEBUG)
	defer log.SetLevel(previousLevel)
	subscriber := log.Subscribe()
	defer log.UnSubscribe(subscriber)
	withMitmCapture(t, mitmDefaultCaptureLimits)
	for _, broken := range []bool{false, true} {
		h := newMitmCaptureHarness(t, "tracker-log")
		go func() {
			site := h.site()
			if _, err := http.ReadRequest(bufio.NewReader(site)); err == nil {
				if broken {
					_, _ = io.WriteString(site, "HTTP/1.1 200 OK\r\nX-Secret: "+marker+"\r\nContent-Length: 999\r\n\r\n"+marker)
				} else {
					_, _ = io.WriteString(site, "HTTP/1.1 200 OK\r\nX-Secret: "+marker+"\r\nContent-Length: 21\r\nConnection: close\r\n\r\n"+marker)
				}
			}
			_ = site.Close()
		}()
		if _, err := io.WriteString(h.client, "POST /"+marker+" HTTP/1.1\r\nHost: example.com\r\nCookie: "+marker+"\r\nContent-Length: 21\r\n\r\n"+marker); err != nil {
			t.Fatal(err)
		}
		_, _ = io.ReadAll(h.client)
		h.outcome(t)
	}
	deadline := time.After(300 * time.Millisecond)
drain:
	for {
		select {
		case event, ok := <-subscriber:
			if !ok {
				break drain
			}
			if strings.Contains(event.Payload, marker) {
				t.Fatalf("decrypted traffic reached the log stream: %q", event.Payload)
			}
		case <-deadline:
			break drain
		}
	}
	if list := handleMitmExchanges(MitmExchangesParams{ID: "tracker-log"}); len(list.Exchanges) != 2 {
		t.Fatalf("the exchanges were not captured, so this proves nothing: %+v", list)
	}
}

// The app's limits apply, with the defaults for any it leaves out, and a
// body never takes more than a quarter of the total.
func TestMitmCaptureLimitsFollowTheSetup(t *testing.T) {
	if got := mitmCaptureLimitsOf(nil); got != mitmDefaultCaptureLimits {
		t.Fatalf("nil runtime %+v", got)
	}
	runtime := &mitmRuntime{setup: MitmSetup{Limits: map[string]int64{"capture-entries": 500, "capture-bytes": 16 << 20, "max-body-size": 2 << 20}}}
	if got := mitmCaptureLimitsOf(runtime); got != (mitmCaptureLimits{entries: 500, bytes: 16 << 20, body: 2 << 20}) {
		t.Fatalf("android limits %+v", got)
	}
	runtime.setup.Limits = map[string]int64{"capture-bytes": 1 << 20}
	if got := mitmCaptureLimitsOf(runtime); got != (mitmCaptureLimits{entries: 2000, bytes: 1 << 20, body: 256 << 10}) {
		t.Fatalf("small total %+v", got)
	}
}

// The replies carry exactly the keys the app's models read.
func TestMitmCaptureRepliesMatchTheAppModels(t *testing.T) {
	keys := func(v any) []string {
		data, err := json.Marshal(v)
		if err != nil {
			t.Fatal(err)
		}
		var m map[string]any
		_ = json.Unmarshal(data, &m)
		var out []string
		for k := range m {
			out = append(out, k)
		}
		slices.Sort(out)
		return out
	}
	since := time.Now()
	for _, tc := range []struct {
		value any
		want  string
	}{
		{MitmExchangeList{Since: &since}, "capturing closed exchanges since"},
		{MitmExchange{}, "actions connection duration error id method original-url pending proto request-header request-size response-header response-size start status ttfb url"},
		{MitmBody{}, "data encoding truncated"},
	} {
		if got := strings.Join(keys(tc.value), " "); got != tc.want {
			t.Fatalf("%T keys %q, want %q", tc.value, got, tc.want)
		}
	}
}
