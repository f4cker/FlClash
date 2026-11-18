package core

import (
	"bytes"
	"compress/gzip"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"
)

// Writes each script into a fresh resources directory, named by its hash
// as the app names it; returns the file names in order.
func withMitmScripts(t *testing.T, sources ...string) []string {
	t.Helper()
	dir := t.TempDir()
	old := mitmResourcesDir
	mitmResourcesDir = func() string { return dir }
	t.Cleanup(func() { mitmResourcesDir = old })
	names := make([]string, len(sources))
	for i, source := range sources {
		sum := sha256.Sum256([]byte(source))
		names[i] = hex.EncodeToString(sum[:]) + ".js"
		if err := os.WriteFile(filepath.Join(dir, names[i]), []byte(source), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	return names
}

func withMitmScriptStore(t *testing.T) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "store.json")
	old := mitmScriptStorePath
	mitmScriptStorePath = func() string { return path }
	t.Cleanup(func() {
		mitmScriptStorePath = old
		mitmScriptStore.mu.Lock()
		mitmScriptStore.values = nil
		mitmScriptStore.mu.Unlock()
	})
	return path
}

func withMitmScriptRules(t *testing.T, lines ...string) *mitmRewriteEngine {
	t.Helper()
	previous, runtime := mitmRewrite.Load(), mitmState.Load()
	t.Cleanup(func() { mitmRewrite.Store(previous); mitmState.Store(runtime) })
	setup := &MitmSetup{Enable: true}
	for i, line := range lines {
		setup.Script = append(setup.Script, MitmScriptRule{ID: string(rune('a' + i)), Line: line})
	}
	mitmRewrite.Store(nil)
	installMitmRewrite(setup)
	return mitmRewrite.Load()
}

func testScript(t *testing.T, line, source string) *mitmScript {
	t.Helper()
	names := withMitmScripts(t, source)
	rule, err := parseMitmScriptLine(strings.ReplaceAll(line, "FILE", names[0]))
	if err != nil {
		t.Fatal(err)
	}
	if err := loadMitmScript(rule.script, nil); err != nil {
		t.Fatal(err)
	}
	return rule.script
}

func scriptResponseInput(body string) *mitmScriptInput {
	return &mitmScriptInput{
		response: true, url: "https://example.com/a", method: "GET",
		requestHeader: http.Header{"Accept": {"*/*"}}, header: http.Header{"Content-Type": {"application/json"}},
		status: 200, body: []byte(body), hasBody: true,
	}
}

func TestMitmScriptParsesSurgeLines(t *testing.T) {
	rule, err := parseMitmScriptLine(`ads = type=http-response,pattern=^https:\/\/a\.com\/(x|y),requires-body=1,max-size=0,timeout=30,script-path=abc.js,argument="a=1,b=2"`)
	if err != nil {
		t.Fatal(err)
	}
	s := rule.script
	if !rule.response || !s.requiresBody || s.timeout != mitmScriptMaxTimeout || s.argument != "a=1,b=2" || s.file != "abc.js" || s.maxSize != mitmDefaultRewriteBodyLimit || rule.host != "a.com" {
		t.Fatalf("parsed %+v %+v", rule, s)
	}
	rule, err = parseMitmScriptLine(`x = type=http-request,pattern=^http,script-path=b.js,argument-json={"k":[1]},binary-body-mode=true,max-size=100`)
	if err != nil || rule.response || !rule.script.binary || rule.script.maxSize != 100 || rule.script.argumentJSON == nil {
		t.Fatalf("json %v %+v", err, rule)
	}
	for line, code := range map[string]string{
		`x = type=cron,cronexp="* * * * *",script-path=a.js`:       "scriptType",
		`x = type=http-request,script-path=a.js`:                   "scriptPattern",
		`x = type=http-request,pattern=^a`:                         "scriptPath",
		`x = type=http-request,pattern=^a,script-path=https://x/a`: "dataURL",
		`x = type=http-request,pattern=^a,script-path=../a.js`:     "dataFileName",
		`x = type=http-request,pattern=^a,script-path=a,timeout=0`: "scriptTimeout",
		`x = type=http-request,pattern=^a,script-path="a`:          "unterminatedQuote",
	} {
		_, err := parseMitmScriptLine(line)
		var ruleErr *mitmRuleError
		if !errors.As(err, &ruleErr) || ruleErr.kind != code {
			t.Errorf("%s: %v, want %s", line, err, code)
		}
	}
	if rule, err := parseMitmScriptLine("# x = type=http-request"); rule != nil || err != nil {
		t.Fatal("comment")
	}
}

func TestMitmScriptRewritesAResponse(t *testing.T) {
	s := testScript(t, `t = type=http-response,pattern=^https,requires-body=1,script-path=FILE,argument=k`, `
		let body = JSON.parse($response.body);
		body.ads = []; body.arg = $argument; body.method = $request.method;
		console.log('seen', $request.url, {n: 1});
		$done({status: '201 Created', headers: Object.assign({}, $response.headers, {'X-Script': '1', 'Content-Length': '1'}), body: JSON.stringify(body)});`)
	result := s.run(scriptResponseInput(`{"ads":[1]}`))
	out := result.out
	if result.skip != "" || out == nil || string(out.body) != `{"ads":[],"arg":"k","method":"GET"}` || out.status != 201 || out.header.Get("X-Script") != "1" || out.header.Get("Content-Length") != "" {
		t.Fatalf("result %+v out %+v", result, out)
	}
	if len(result.logs) != 1 || result.logs[0].Text != `seen https://example.com/a {"n":1}` || result.logs[0].Level != "log" {
		t.Fatalf("logs %+v", result.logs)
	}
}

func TestMitmScriptRequestAnswersLocally(t *testing.T) {
	s := testScript(t, `t = type=http-request,pattern=^https,script-path=FILE`,
		`$done({response: {headers: {'Content-Type': 'text/plain'}, body: 'local'}})`)
	result := s.run(&mitmScriptInput{url: "https://example.com/", method: "GET", header: http.Header{}})
	if result.out == nil || result.out.local == nil || result.out.local.status != 200 || string(result.out.local.body) != "local" {
		t.Fatalf("%+v", result)
	}
}

func TestMitmScriptFailuresPassTheMessage(t *testing.T) {
	cases := map[string]string{
		`throw new Error('boom')`:     mitmSkipScriptError,
		`$done(`:                      "",
		`let x = 1`:                   mitmSkipScriptNoDone,
		`while (true) {}`:             mitmSkipScriptTimeout,
		`setTimeout(() => {}, 60000)`: mitmSkipScriptTimeout,
		`'x'.repeat(1 << 30)`:         mitmSkipScriptError,
		`new Uint8Array(1 << 30)`:     mitmSkipScriptError,
		`let a = []; while (true) a.push("x".repeat(4 << 20) + a.length)`: mitmSkipScriptMemory,
	}
	oldLimit := mitmScriptMemoryLimit.Swap(48 << 20)
	defer mitmScriptMemoryLimit.Store(oldLimit)
	for source, want := range cases {
		names := withMitmScripts(t, source)
		timeout := "1"
		if want == mitmSkipScriptMemory {
			timeout = "8"
		}
		rule, err := parseMitmScriptLine(`t = type=http-response,pattern=^https,timeout=` + timeout + `,script-path=` + names[0])
		if err != nil {
			t.Fatal(err)
		}
		if err := loadMitmScript(rule.script, nil); err != nil {
			if want != "" {
				t.Fatalf("%s: %v", source, err)
			}
			continue
		}
		start := time.Now()
		result := rule.script.run(scriptResponseInput("{}"))
		if result.skip != want || result.out != nil {
			t.Errorf("%s: skip %q err %q, want %s", source, result.skip, result.err, want)
		}
		if took := time.Since(start); took > rule.script.timeout+mitmScriptGrace+500*time.Millisecond {
			t.Errorf("%s took %v", source, took)
		}
	}
}

func TestMitmScriptStoreTimersAndHelpers(t *testing.T) {
	path := withMitmScriptStore(t)
	s := testScript(t, `t = type=http-response,pattern=^https,script-path=FILE`, `
		$persistentStore.write('v1', 'k');
		$persistentStore.write('mine');
		const bytes = new TextEncoder().encode('hé');
		setTimeout(function (a) {
			$done({body: [$persistentStore.read('k'), $persistentStore.read(), a, btoa('hi'), atob('aGk='), bytes.length,
				new TextDecoder().decode(bytes), typeof $utils.geoip, $persistentStore.read('none')].join('|')});
		}, 10, 'arg');`)
	result := s.run(scriptResponseInput(""))
	if result.out == nil || string(result.out.body) != "v1|mine|arg|aGk=|hi|3|hé|function|" {
		t.Fatalf("%+v %+v", result, result.out)
	}
	data, err := os.ReadFile(path)
	if err != nil || !strings.Contains(string(data), `"@t":"mine"`) {
		t.Fatalf("store file %q %v", data, err)
	}
}

func TestMitmScriptBinaryAndUngzip(t *testing.T) {
	var zipped bytes.Buffer
	zw := gzip.NewWriter(&zipped)
	_, _ = zw.Write([]byte("inner"))
	_ = zw.Close()
	s := testScript(t, `t = type=http-response,pattern=^https,requires-body=1,binary-body-mode=1,script-path=FILE`, `
		const raw = $utils.ungzip($response.body);
		const out = new Uint8Array(raw.length + 1);
		out.set(raw); out[raw.length] = 0x21;
		$done({bodyBytes: out.buffer});`)
	in := scriptResponseInput("")
	in.body = zipped.Bytes()
	result := s.run(in)
	if result.out == nil || string(result.out.body) != "inner!" {
		t.Fatalf("%+v", result)
	}
}

func TestMitmScriptHTTPClient(t *testing.T) {
	site := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		w.Header().Set("X-Got", r.Header.Get("X-Send")+string(body))
		_, _ = io.WriteString(w, "fetched")
	}))
	defer site.Close()
	old := mitmScriptHTTP
	mitmScriptHTTP = func(ctx context.Context, method, url string, header map[string][]string, body io.Reader) (int, map[string][]string, io.ReadCloser, error) {
		req, _ := http.NewRequestWithContext(ctx, method, url, body)
		for k, v := range header {
			req.Header[k] = v
		}
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			return 0, nil, nil, err
		}
		return resp.StatusCode, resp.Header, resp.Body, nil
	}
	defer func() { mitmScriptHTTP = old }()
	s := testScript(t, `t = type=http-response,pattern=^https,script-path=FILE`, `
		$httpClient.post({url: '`+site.URL+`/p', headers: {'X-Send': 'h'}, body: 'b'}, function (err, resp, data) {
			$httpClient.get('ftp://x', function (err2) {
				$done({body: [err, resp.status, resp.headers['X-Got'], data, err2].join('|')});
			});
		});`)
	result := s.run(scriptResponseInput(""))
	if result.out == nil || string(result.out.body) != "|200|hb|fetched|invalid URL" {
		t.Fatalf("%+v", result)
	}
	if len(result.requests) != 1 || result.requests[0].Status != 200 || result.requests[0].Method != "POST" || result.requests[0].TookNs == 0 {
		t.Fatalf("requests %+v", result.requests)
	}
}

func TestMitmScriptConcurrentRuns(t *testing.T) {
	s := testScript(t, `t = type=http-response,pattern=^https,requires-body=1,script-path=FILE`,
		`setTimeout(() => $done({body: $response.body + '!'}), 5)`)
	var wg sync.WaitGroup
	for i := 0; i < 32; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if result := s.run(scriptResponseInput("x")); result.out == nil || string(result.out.body) != "x!" {
				t.Errorf("%+v", result)
			}
		}()
	}
	wg.Wait()
}

func scriptLine(name, kind, extra, file string) string {
	return name + " = type=" + kind + `,pattern=^https?:\/\/example\.com\/` + extra + ",script-path=" + file
}

func TestMitmScriptHTTP1Session(t *testing.T) {
	withMitmCapture(t, mitmDefaultCaptureLimits)
	names := withMitmScripts(t,
		`$request.headers['X-Script'] = 'req'; $done({url: $request.url.replace('/old', '/new'), headers: $request.headers})`,
		`$done({response: {status: 403, body: 'blocked'}})`,
		`$done({body: $response.body.toUpperCase(), headers: Object.assign($response.headers, {'X-Resp': '1'})})`,
		`throw new Error('bad')`,
		`$done({body: $request.body + '&b=2'})`,
	)
	withMitmScriptRules(t,
		scriptLine("rq", "http-request", "(old|v2)", names[0]),
		scriptLine("block", "http-request", "block", names[1]),
		scriptLine("upper", "http-response", "v2", names[2]+",requires-body=1"),
		scriptLine("bad", "http-response", "v2", names[3]),
		scriptLine("form", "http-request", "form", names[4]+",requires-body=1"),
	)
	h := startRewriteH1(t, false, rewriteTestSite)

	resp, body := h.do(t, get("/old"))
	if resp.Header.Get("X-Seen") != "/new" || body != "site" {
		t.Fatalf("url: %v %q", resp.Header, body)
	}
	resp, body = h.do(t, get("/block"))
	if resp.StatusCode != 403 || body != "blocked" || h.hits.Load() != 1 {
		t.Fatalf("local: %d %q", resp.StatusCode, body)
	}
	resp, body = h.do(t, "GET /v2/x HTTP/1.1\r\nHost: example.com\r\nAccept-Encoding: gzip\r\n\r\n")
	if body != `{"ADS":[1,2],"OK":TRUE}` || resp.Header.Get("X-Resp") != "1" || resp.Header.Get("Content-Encoding") != "" || resp.ContentLength != int64(len(body)) {
		t.Fatalf("response: %v %q", resp.Header, body)
	}
	hits := rewriteHits(t, "rw-conn")
	if len(hits) != 3 || hits[1].Action != "upper" || hits[2].Skipped != mitmSkipScriptError || hits[2].Error == "" || len(hits[2].Logs) != 1 || hits[2].Logs[0].Level != "error" {
		t.Fatalf("hits %+v", hits)
	}
	_, body = h.do(t, "POST /form HTTP/1.1\r\nHost: example.com\r\nContent-Type: text/plain\r\nContent-Length: 3\r\n\r\na=1")
	if body != "a=1&b=2|7" {
		t.Fatalf("request body %q", body)
	}
	_, body = h.do(t, "POST /form HTTP/1.1\r\nHost: example.com\r\nTransfer-Encoding: chunked\r\n\r\n3\r\na=1\r\n0\r\n\r\n")
	if body != "a=1|" || !hasSkip(rewriteHits(t, "rw-conn"), "request", mitmSkipFraming) {
		t.Fatalf("chunked %q", body)
	}
}

func TestMitmScriptHTTP2(t *testing.T) {
	withMitmCapture(t, mitmDefaultCaptureLimits)
	names := withMitmScripts(t,
		`$done({headers: Object.assign($request.headers, {'x-req': $request.headers['user-agent'] ? 'ua' : 'none'})})`,
		`$done({body: JSON.stringify({wrapped: $response.body, h: $response.headers['x-seen']})})`,
	)
	withMitmScriptRules(t,
		scriptLine("rq", "http-request", "", names[0]),
		scriptLine("rs", "http-response", "", names[1]+",requires-body=1"),
	)
	site := newMitmH2Site(t, true, http.HandlerFunc(rewriteTestSite))
	h := newMitmH2Harness(t, site, []string{"h2", "http/1.1"}, nil)
	cc := h.h2(t)
	req, _ := http.NewRequest("GET", "https://example.com/x", nil)
	req.Header.Set("User-Agent", "t")
	resp, err := cc.RoundTrip(req)
	if err != nil {
		t.Fatal(err)
	}
	body, _ := io.ReadAll(resp.Body)
	resp.Body.Close()
	if string(body) != `{"wrapped":"site","h":"/x ua"}` || resp.ContentLength != int64(len(body)) {
		t.Fatalf("%q %v", body, resp.Header)
	}
	_ = cc.Close()
	if outcome := h.outcome(t); outcome != "" {
		t.Fatalf("outcome %q", outcome)
	}
}

func TestMitmScriptOversizeAndBinaryPass(t *testing.T) {
	withMitmCapture(t, mitmDefaultCaptureLimits)
	names := withMitmScripts(t, `$done({body: 'changed'})`)
	withMitmScriptRules(t,
		scriptLine("small", "http-response", "", names[0]+",requires-body=1,max-size=2"),
	)
	h := startRewriteH1(t, false, rewriteTestSite)
	_, body := h.do(t, get("/x"))
	if body != "site" || !hasSkip(rewriteHits(t, "rw-conn"), "response", mitmSkipOversize) {
		t.Fatalf("oversize %q", body)
	}
	_, body = h.do(t, get("/bin"))
	if body != `"ads":[1]` {
		t.Fatalf("bin %q", body)
	}
}

func TestMitmScriptValidateReportsSyntax(t *testing.T) {
	names := withMitmScripts(t, `function (`)
	issues := handleMitmValidate(map[string][]string{mitmSectionScript: {
		scriptLine("x", "http-request", "", names[0]),
		scriptLine("y", "http-request", "", "missing.js"),
	}})
	if len(issues[mitmSectionScript]) != 2 {
		t.Fatalf("%+v", issues)
	}
	engine := withMitmScriptRules(t, scriptLine("x", "http-request", "", names[0]))
	if engine == nil || len(engine.issues) != 1 || len(engine.rules) != 0 {
		t.Fatalf("engine %+v", engine)
	}
}
