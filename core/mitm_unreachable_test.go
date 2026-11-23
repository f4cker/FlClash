package core

import (
	"bufio"
	"context"
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outbound"
	N "github.com/metacubex/mihomo/common/net"
	"github.com/metacubex/mihomo/component/resolver"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
	"github.com/metacubex/mihomo/tunnel/statistic"
)

// Script Hub's front page: a site that does not exist.
const scriptHubLine = `Script Hub: 前端 = type=http-request,pattern=^https?:\/\/script\.hub\/($|edit\/|reload),timeout=300,script-path=`

const scriptHubSource = `$done({response: {status: 200, headers: {'Content-Type': 'text/html'}, body: 'hub ' + $request.url}})`

// A script that rewrites the request and lets it go on to the site.
const scriptPassLine = `pass = type=http-request,pattern=^https?:\/\/script\.hub\/pass,script-path=PASS`

const scriptPassSource = `$done({headers: Object.assign($request.headers, {'X-Script': 'pass'})})`

// DIRECT that cannot resolve any name, failing at once as a lookup with no
// address does, so the tunnel does not retry.
type mitmNoSuchHost struct{ C.ProxyAdapter }

func (mitmNoSuchHost) DialContext(context.Context, *C.Metadata) (C.Conn, error) {
	return nil, fmt.Errorf("dial: %w", resolver.ErrIPNotFound)
}

func withUnreachableMitm(t *testing.T, setup MitmSetup, scripts ...string) *x509.CertPool {
	t.Helper()
	app := newFakeMitmApp(t)
	withMitmState(t)
	names := withMitmScripts(t, scriptHubSource, scriptPassSource)
	for i, line := range scripts {
		if strings.HasSuffix(line, "=") {
			line += names[0]
		}
		setup.Script = append(setup.Script, MitmScriptRule{ID: fmt.Sprint(i), Line: strings.Replace(line, "PASS", names[1], 1)})
	}
	setup.Enable, setup.DecryptTLS, setup.CAFingerprint = true, true, app.fingerprint()
	previousRewrite := mitmRewrite.Load()
	applyMitmSetup(&SetupParams{Mitm: &setup}, nil)
	previousSign := sendMitmSign
	sendMitmSign = func(request *MitmSignRequest) bool {
		result := MitmSignResultParams{ReqID: request.ReqID, Cert: app.leaf(t, request.Host, request.SPKI, nil), CA: app.ca.Raw}
		go handleMitmSignResult(result)
		return true
	}
	oldMode, oldStatus := tunnel.Mode(), tunnel.Status()
	oldProxies, oldProviders := tunnel.Proxies(), tunnel.Providers()
	tunnel.UpdateProxies(map[string]C.Proxy{"DIRECT": adapter.NewProxy(mitmNoSuchHost{outbound.NewDirect()})}, nil)
	tunnel.SetMode(tunnel.Direct)
	tunnel.OnRunning()
	t.Cleanup(func() {
		mitmActive.closeAll()
		mitmLeaves.clear()
		mitmPaused.Store(nil)
		sendMitmSign = previousSign
		mitmRewrite.Store(previousRewrite)
		tunnel.UpdateProxies(oldProxies, oldProviders)
		tunnel.SetMode(oldMode)
		switch oldStatus {
		case tunnel.Running:
			tunnel.OnRunning()
		case tunnel.Inner:
			tunnel.OnInnerLoading()
		default:
			tunnel.OnSuspend()
		}
	})
	roots := x509.NewCertPool()
	roots.AddCert(app.ca)
	return roots
}

// done closes once the actual tunnel let go of the flow.
func unreachableFlow(t *testing.T, host string, port uint16) (net.Conn, <-chan struct{}) {
	t.Helper()
	client, inbound := net.Pipe()
	t.Cleanup(func() { _ = client.Close(); _ = inbound.Close() })
	_ = client.SetDeadline(time.Now().Add(5 * time.Second))
	metadata := &C.Metadata{NetWork: C.TCP, Type: C.HTTP, Host: host, DstPort: port}
	done := make(chan struct{})
	go func() { defer close(done); tunnel.Tunnel.HandleTCPConn(inbound, metadata) }()
	return client, done
}

func unreachableGet(t *testing.T, conn io.ReadWriter, reader *bufio.Reader, host, path string) (int, string) {
	t.Helper()
	if _, err := fmt.Fprintf(conn, "GET %s HTTP/1.1\r\nHost: %s\r\n\r\n", path, host); err != nil {
		t.Fatal(err)
	}
	resp, err := http.ReadResponse(reader, nil)
	if err != nil {
		t.Fatal(err)
	}
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatal(err)
	}
	return resp.StatusCode, string(body)
}

func trackedHost(host string) bool {
	found := false
	statistic.DefaultManager.Range(func(c statistic.Tracker) bool {
		found = found || c.Info().Metadata.Host == host
		return !found
	})
	return found
}

func TestMitmUnreachableHostIsAnsweredByItsScript(t *testing.T) {
	roots := withUnreachableMitm(t, MitmSetup{Hostname: []string{"script.hub", "*.script.hub"}}, scriptHubLine)
	events := make(chan MitmConnection, 4)
	oldSend := sendMitmConnection
	sendMitmConnection = func(event *MitmConnection) bool { events <- *event; return true }
	t.Cleanup(func() { sendMitmConnection = oldSend })
	failures := make(chan string, 4)
	oldNotify := tunnel.DefaultDialFailureNotify
	tunnel.DefaultDialFailureNotify = func(metadata *C.Metadata, _ C.Rule, _ C.Proxy, _ error) { failures <- metadata.Host }
	t.Cleanup(func() { tunnel.DefaultDialFailureNotify = oldNotify })
	raw, done := unreachableFlow(t, "SCRIPT.HUB.", mitmHTTPSPort)
	client := tls.Client(raw, &tls.Config{ServerName: "script.hub", RootCAs: roots, NextProtos: []string{"h2", "http/1.1"}})
	if err := client.Handshake(); err != nil {
		t.Fatalf("the client did not complete TLS: %v", err)
	}
	if proto := client.ConnectionState().NegotiatedProtocol; proto != "http/1.1" {
		t.Fatalf("protocol %q", proto)
	}
	reader := bufio.NewReader(client)
	if status, body := unreachableGet(t, client, reader, "script.hub", "/"); status != 200 || body != "hub https://script.hub/" {
		t.Fatalf("script answer %d %q", status, body)
	}
	if !trackedHost("SCRIPT.HUB.") {
		t.Fatal("the request list has no connection for the answered host")
	}
	if host := <-failures; host != "SCRIPT.HUB." {
		t.Fatalf("dial failure notified for %q", host)
	}
	if status, body := unreachableGet(t, client, reader, "script.hub", "/nothing"); status != http.StatusBadGateway || body != mitmUnreachableText {
		t.Fatalf("unanswered %d %q", status, body)
	}
	if event := <-events; event.Outcome != mitmOutcomeDecrypted || event.Id == "" {
		t.Fatalf("event %+v", event)
	}
	_ = client.Close()
	<-done
}

// A listed host no rule could answer fails as it always did: no TLS.
func TestMitmUnreachableHostWithoutRulesStillCloses(t *testing.T) {
	roots := withUnreachableMitm(t, MitmSetup{Hostname: []string{"script.hub", "other.example"}}, scriptHubLine)
	raw, done := unreachableFlow(t, "other.example", mitmHTTPSPort)
	client := tls.Client(raw, &tls.Config{ServerName: "other.example", RootCAs: roots})
	if err := client.Handshake(); err == nil {
		t.Fatal("a host without rules completed TLS without its site")
	}
	<-done
	if trackedHost("other.example") {
		t.Fatal("a failed dial left a connection in the request list")
	}
}

// The dial succeeds but TLS to the site does not: the script still answers,
// and nothing past the failed handshake is written to the site.
func TestMitmUnreachableTLSFailureIsAnsweredByItsScript(t *testing.T) {
	roots := withUnreachableMitm(t, MitmSetup{Hostname: []string{"script.hub"}}, scriptHubLine, scriptPassLine)
	clientRaw, proxyRaw := mitmLoopbackPair(t)
	defer clientRaw.Close()
	defer proxyRaw.Close()
	proxySite, siteRaw := mitmLoopbackPair(t)
	defer proxySite.Close()
	// The site reads the ClientHello record and hangs up.
	siteRead := make(chan int64, 1)
	go func() {
		header := make([]byte, 5)
		if _, err := io.ReadFull(siteRaw, header); err == nil {
			_, _ = io.CopyN(io.Discard, siteRaw, int64(header[3])<<8|int64(header[4]))
		}
		_ = siteRaw.(*net.TCPConn).CloseWrite()
		n, _ := io.Copy(io.Discard, siteRaw)
		siteRead <- n
		_ = siteRaw.Close()
	}()
	served := make(chan struct{})
	go func() {
		defer close(served)
		client := N.NewBufferedConn(proxyRaw)
		selected := mitmInterceptEligible(client, &C.Metadata{Host: "script.hub", DstPort: mitmHTTPSPort})
		if selected == nil {
			_ = proxyRaw.Close()
			return
		}
		selected(client, mitmSelectionConn{N.NewExtendedConn(proxySite)})
		_ = proxySite.Close()
	}()
	client := tls.Client(clientRaw, &tls.Config{ServerName: "script.hub", RootCAs: roots, NextProtos: []string{"http/1.1"}})
	reader := bufio.NewReader(client)
	if status, body := unreachableGet(t, client, reader, "script.hub", "/edit/x"); status != 200 || body != "hub https://script.hub/edit/x" {
		t.Fatalf("script answer %d %q", status, body)
	}
	if status, body := unreachableGet(t, client, reader, "script.hub", "/pass"); status != http.StatusBadGateway || body != mitmUnreachableText {
		t.Fatalf("a request the script passed on %d %q", status, body)
	}
	// The failed site is let go of while the session goes on.
	select {
	case n := <-siteRead:
		if n != 0 {
			t.Fatalf("the failed site was sent %d bytes past its ClientHello", n)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("the failed site is still held open")
	}
	_ = client.Close()
	<-served
}

func TestMitmUnreachableCertificateFailureStillCloses(t *testing.T) {
	withUnreachableMitm(t, MitmSetup{Hostname: []string{"script.hub"}}, scriptHubLine)
	cert, _ := mitmTestIdentity(t)
	oldRoots := mitmUpstreamRoots
	mitmUpstreamRoots = x509.NewCertPool()
	t.Cleanup(func() { mitmUpstreamRoots = oldRoots })
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer listener.Close()
	go func() {
		c, err := listener.Accept()
		if err != nil {
			return
		}
		defer c.Close()
		_ = c.SetDeadline(time.Now().Add(3 * time.Second))
		_ = tls.Server(c, &tls.Config{Certificates: []tls.Certificate{cert}}).Handshake()
	}()
	remote, err := net.DialTimeout("tcp", listener.Addr().String(), 3*time.Second)
	if err != nil {
		t.Fatal(err)
	}
	defer remote.Close()
	clientRaw, mitmClient := net.Pipe()
	defer clientRaw.Close()
	_ = clientRaw.SetDeadline(time.Now().Add(3 * time.Second))
	outcome := serveMitm(mitmClient, mitmIDConn{remote}, "script.hub", &mitmLeaf{cert: cert}, mitmState.Load())
	if outcome != mitmOutcomeUpstreamCertificate {
		t.Fatalf("outcome %q", outcome)
	}
	_ = mitmClient.Close()
	if n, _ := clientRaw.Read(make([]byte, 1)); n != 0 {
		t.Fatal("the client got TLS from a site whose certificate failed")
	}
}

// HTTP/2 alone cannot be answered without the site: the flow fails as before.
func TestMitmUnreachableHTTP2OnlyClientStillCloses(t *testing.T) {
	roots := withUnreachableMitm(t, MitmSetup{Hostname: []string{"script.hub"}}, scriptHubLine)
	raw, done := unreachableFlow(t, "script.hub", mitmHTTPSPort)
	client := tls.Client(raw, &tls.Config{ServerName: "script.hub", RootCAs: roots, NextProtos: []string{"h2"}})
	if err := client.Handshake(); err == nil {
		t.Fatal("an HTTP/2-only client completed TLS without the site")
	}
	<-done
	if trackedHost("script.hub") {
		t.Fatal("a failed dial left a connection in the request list")
	}
}

func TestMitmStandInOnlyForTheChosenDecryption(t *testing.T) {
	withUnreachableMitm(t, MitmSetup{Hostname: []string{"script.hub"}}, scriptHubLine)
	proxy := adapter.NewProxy(outbound.NewDirect())
	offer := func() *C.Metadata {
		metadata := &C.Metadata{Host: "script.hub", DstPort: mitmHTTPSPort}
		mitmOfferStandIn(metadata, func(*N.BufferedConn, C.Conn) {}, "script.hub")
		return metadata
	}
	if mitmUnreachableStandIn(&C.Metadata{Host: "script.hub", DstPort: mitmHTTPSPort}, proxy) != nil {
		t.Fatal("a stand-in for a flow no decrypting interceptor took")
	}
	metadata := offer()
	if mitmUnreachableStandIn(metadata, proxy) == nil || mitmUnreachableStandIn(metadata, proxy) != nil {
		t.Fatal("a chosen flow gets one stand-in")
	}
	mitmPaused.Store(&mitmPause{runtime: mitmState.Load(), until: time.Now().Add(time.Minute), reason: "test"})
	if mitmUnreachableStandIn(offer(), proxy) != nil {
		t.Fatal("a stand-in while decryption is paused")
	}
	mitmPaused.Store(nil)
	mitmState.Store(&mitmRuntime{})
	if mitmUnreachableStandIn(offer(), proxy) != nil {
		t.Fatal("a stand-in while MITM is off")
	}
}

func TestMitmAnsweringRulesNameTheirHost(t *testing.T) {
	setup := MitmSetup{Hostname: []string{"script.hub"}, Rewrite: []MitmRewriteRule{
		{ID: "m", Section: mitmSectionMap, Line: `^https:\/\/local\.example\/ data-type=text data="hi"`},
	}}
	withUnreachableMitm(t, setup, `any = type=http-request,pattern=^https:\/\/.*\/x,script-path=`)
	engine := mitmRewrite.Load()
	if engine.answersWithoutSite("other.example") || engine.answersWithoutSite("script.hub") {
		t.Fatal("a pattern naming no host answers for every host")
	}
	if !engine.answersWithoutSite("local.example") {
		t.Fatal("Map Local alone does not answer for its host")
	}
}

func TestMitmForceHTTPEngineIgnoresEveryHost(t *testing.T) {
	matcher := compileMitmHTTPEngineHosts([]string{"*", " ", "*:80", "a.example:80"})
	if matcher.Match("b.example") || !matcher.Match("a.example") {
		t.Fatal("force-http-engine-hosts took every host")
	}
}

func TestMitmLongScriptsShareFewSlots(t *testing.T) {
	oldWait := mitmScriptSlotWait
	mitmScriptSlotWait = 50 * time.Millisecond
	t.Cleanup(func() { mitmScriptSlotWait = oldWait })
	for range cap(mitmScriptLongSlots) {
		mitmScriptLongSlots <- struct{}{}
	}
	t.Cleanup(func() {
		for range cap(mitmScriptLongSlots) {
			<-mitmScriptLongSlots
		}
	})
	source := `$done({response: {body: 'ok'}})`
	in := &mitmScriptInput{url: "https://a.com/", method: "GET", header: http.Header{}}
	long := testScript(t, `l = type=http-request,pattern=^https,timeout=30,script-path=FILE`, source)
	if result := long.run(in); result.skip != mitmSkipScriptBusy {
		t.Fatalf("a long run past the long slots: %+v", result)
	}
	short := testScript(t, `s = type=http-request,pattern=^https,timeout=10,script-path=FILE`, source)
	if result := short.run(in); result.out == nil || result.out.local == nil {
		t.Fatalf("a short run while the long slots are taken: %+v", result)
	}
}

func TestMitmForceHTTPEngineScriptsPlainHTTPWithoutSite(t *testing.T) {
	withUnreachableMitm(t, MitmSetup{Hostname: []string{"script.hub"}, ForceHTTPEngine: []string{"script.hub", "*.script.hub"}}, scriptHubLine)
	raw, done := unreachableFlow(t, "script.hub", mitmPlainHTTPPort)
	reader := bufio.NewReader(raw)
	if status, body := unreachableGet(t, raw, reader, "script.hub", "/"); status != 200 || body != "hub http://script.hub/" {
		t.Fatalf("script answer %d %q", status, body)
	}
	if status, body := unreachableGet(t, raw, reader, "script.hub", "/nothing"); status != http.StatusBadGateway || body != mitmUnreachableText {
		t.Fatalf("unanswered %d %q", status, body)
	}
	if _, err := io.WriteString(raw, "POST /form HTTP/1.1\r\nHost: script.hub\r\nContent-Length: 5\r\n\r\nhello"); err != nil {
		t.Fatal(err)
	}
	if resp, err := http.ReadResponse(reader, nil); err != nil || resp.StatusCode != http.StatusBadGateway {
		t.Fatalf("POST %v %v", resp, err)
	} else {
		_, _ = io.Copy(io.Discard, resp.Body)
	}
	if status, _ := unreachableGet(t, raw, reader, "script.hub", "/"); status != 200 {
		t.Fatalf("after a POST %d", status)
	}
	_ = raw.Close()
	<-done
}

// Without force-http-engine-hosts plain HTTP is not scripted, so a failed
// dial closes the flow as before.
func TestMitmPlainHTTPWithoutForceHTTPEngineStillCloses(t *testing.T) {
	withUnreachableMitm(t, MitmSetup{Hostname: []string{"script.hub"}}, scriptHubLine)
	raw, done := unreachableFlow(t, "script.hub", mitmPlainHTTPPort)
	go func() { _, _ = io.WriteString(raw, "GET / HTTP/1.1\r\nHost: script.hub\r\n\r\n") }()
	if _, err := http.ReadResponse(bufio.NewReader(raw), nil); err == nil {
		t.Fatal("plain HTTP was answered without force-http-engine-hosts")
	}
	<-done
}

func TestMitmForceHTTPEngineScriptsPlainHTTP(t *testing.T) {
	withMitmCapture(t, mitmDefaultCaptureLimits)
	names := withMitmScripts(t,
		`$done({headers: Object.assign($request.headers, {'X-Script': 'req'})})`,
		`$done({response: {status: 403, body: 'blocked'}})`,
	)
	previous, runtime := mitmRewrite.Load(), mitmState.Load()
	t.Cleanup(func() { mitmRewrite.Store(previous); mitmState.Store(runtime) })
	setup := &MitmSetup{Enable: true, ForceHTTPEngine: []string{"example.com:80"}, Script: []MitmScriptRule{
		{ID: "a", Line: `rq = type=http-request,pattern=^http:\/\/example\.com\/old,script-path=` + names[0]},
		{ID: "b", Line: `block = type=http-request,pattern=^http:\/\/example\.com\/block,script-path=` + names[1]},
	}}
	mitmState.Store(&mitmRuntime{setup: setup.withoutRewrite()})
	mitmRewrite.Store(nil)
	installMitmRewrite(setup)
	if !mitmPlainWanted(&C.Metadata{Host: "example.com", DstPort: mitmPlainHTTPPort}) {
		t.Fatal("a force-http-engine host with scripts is not read on plain HTTP")
	}
	h := startRewriteH1(t, true, func(w http.ResponseWriter, r *http.Request) {
		_, _ = io.WriteString(w, r.Header.Get("X-Script"))
	})
	if _, body := h.do(t, get("/old")); body != "req" {
		t.Fatalf("request script on plain HTTP: %q", body)
	}
	if resp, body := h.do(t, get("/block")); resp.StatusCode != 403 || body != "blocked" || h.hits.Load() != 1 {
		t.Fatalf("local answer on plain HTTP: %d %q", resp.StatusCode, body)
	}
	if hits := rewriteHits(t, "rw-conn"); len(hits) != 1 || hits[0].Action != "block" {
		t.Fatalf("hits %+v", hits)
	}
}

func TestMitmScriptTimeoutIsCappedNotRefused(t *testing.T) {
	for timeout, want := range map[string]time.Duration{"300": mitmScriptMaxTimeout, "30": 30 * time.Second, "0.5": 500 * time.Millisecond} {
		rule, err := parseMitmScriptLine(`x = type=http-request,pattern=^https:\/\/a\.com\/,timeout=` + timeout + `,script-path=a.js`)
		if err != nil || rule.script.timeout != want {
			t.Fatalf("timeout=%s: %v %v", timeout, rule, err)
		}
	}
	if mitmScriptMaxTimeout != 120*time.Second || !strings.Contains(scriptHubLine, "timeout=300") {
		t.Fatal("lib/common/mitm_script.dart mitmScriptMaxTimeout mirrors this cap")
	}
}

// FLASH_SCRIPT_HUB_JS names a copy of Script Hub's script-hub.js.
func TestMitmScriptHubFrontPage(t *testing.T) {
	source, err := os.ReadFile(os.Getenv("FLASH_SCRIPT_HUB_JS"))
	if err != nil {
		t.Skip("FLASH_SCRIPT_HUB_JS is not a readable script-hub.js")
	}
	s := testScript(t, scriptHubLine+"FILE", string(source))
	for _, url := range []string{"https://script.hub/", "https://script.hub/edit/_start_/x/_end_/a.sgmodule"} {
		result := s.run(&mitmScriptInput{url: url, method: "GET", header: http.Header{"Host": {"script.hub"}}})
		for _, line := range result.logs {
			t.Logf("%s: %s", line.Level, line.Text)
		}
		local := result.out
		if local != nil {
			local = local.local
		}
		if local == nil || local.status != 200 || !strings.Contains(string(local.body), "Script Hub") ||
			!strings.Contains(local.header.Get("Content-Type"), "text/html") {
			t.Fatalf("%s: skip %q err %q out %+v", url, result.skip, result.err, result.out)
		}
	}
}
