package core

import (
	"bufio"
	"bytes"
	"compress/gzip"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/andybalholm/brotli"
	N "github.com/metacubex/mihomo/common/net"
	C "github.com/metacubex/mihomo/constant"
)

// Installs rules as an enabled setup would and restores the previous
// engine and runtime afterwards.
func withMitmRewrite(t *testing.T, limit int64, rules ...MitmRewriteRule) *mitmRewriteEngine {
	t.Helper()
	previous, runtime := mitmRewrite.Load(), mitmState.Load()
	t.Cleanup(func() { mitmRewrite.Store(previous); mitmState.Store(runtime) })
	setup := &MitmSetup{Enable: true, Rewrite: rules}
	if limit > 0 {
		setup.Limits = map[string]int64{"rewrite-body-size": limit}
	}
	mitmRewrite.Store(nil)
	installMitmRewrite(setup)
	return mitmRewrite.Load()
}

func rwRule(id, section, line string) MitmRewriteRule {
	return MitmRewriteRule{ID: id, Section: section, Line: line}
}

func TestMitmRewriteParsesSurgeLines(t *testing.T) {
	valid := []struct{ section, line string }{
		{mitmSectionURL, `^https?:\/\/api\.example\.com\/ad - reject`},
		{mitmSectionURL, `^https?:\/\/api\.example\.com\/ad _ REJECT-TINYGIF`},
		{mitmSectionURL, `^https:\/\/app\.bilibili\.com\/x\/v2\/splash - reject-dict`},
		{mitmSectionURL, `^https:\/\/r\.inews\.qq\.com\/ad reject-img`},
		{mitmSectionURL, `^http:\/\/example\.com\/old https://example.com/new 302`},
		{mitmSectionURL, `^https?:\/\/(www\.)?g\.cn https://www.google.com 307`},
		{mitmSectionURL, `^https:\/\/x\.com\/(.*) https://x.com/v2/$1 header`},
		{mitmSectionURL, `^https:\/\/x\.com\/(.*) https://x.com/v2/$1`},
		{mitmSectionURL, `^https:\/\/x\.com\/a reject-drop`},
		{mitmSectionHeader, `http-request ^https?:\/\/www\.zhihu\.com header-replace-regex User-Agent .+iPhone.+ "Mozilla/5.0 (Macintosh)"`},
		{mitmSectionHeader, `^https:\/\/www\.bing\.com header-add X-Test 1`},
		{mitmSectionHeader, `http-response ^https:\/\/x\.com header-del Set-Cookie`},
		{mitmSectionHeader, `http-request ^https:\/\/x\.com header-replace Accept-Language en-US`},
		{mitmSectionBody, `http-response ^https:\/\/api\.x\.com\/v1 "ads":\[.*?\] "ads":[]`},
		{mitmSectionBody, `http-request ^https:\/\/api\.x\.com\/v1 a=1 a=2 b=(\d) b=$1$1`},
		{mitmSectionBody, `http-response ^https:\/\/x\.com (?<=foo)bar baz`},
		{mitmSectionMap, `^https:\/\/x\.com\/a data-type=text data="{}" status-code=200 header="Content-Type:application/json|X-A:b"`},
		{mitmSectionMap, `^https:\/\/x\.com\/gif data-type=tiny-gif`},
		{mitmSectionMap, `^https:\/\/x\.com\/b data-type=base64 data="aGVsbG8="`},
		{mitmSectionMap, `^https:\/\/x\.com\/c data-type=text data="a b" header="` + "WC1BOiBiCg==" + `"`},
	}
	for _, tc := range valid {
		rule, err := parseMitmRewriteLine(tc.section, tc.line)
		if err != nil || rule == nil {
			t.Errorf("%s %q: %v", tc.section, tc.line, err)
		}
	}
	invalid := []struct{ section, line, want string }{
		{mitmSectionURL, `^https:\/\/x\.com a b c d`, "fields"},
		{mitmSectionURL, `^https:\/\/x\.com https://y frob`, "unknown URL rewrite type"},
		{mitmSectionURL, `(unclosed https://a 302`, "invalid URL regex"},
		{mitmSectionURL, `^https:\/\/x\.com - 302`, "replacement"},
		{mitmSectionHeader, `http-request ^x header-add Content-Length 5`, "frames"},
		{mitmSectionHeader, `^x header-frob A b`, "unknown header action"},
		{mitmSectionHeader, `^x header-add A`, "needs a value"},
		{mitmSectionBody, `http-response-jq ^x '.a'`, "jq"},
		{mitmSectionBody, `http-request ^x onlyone`, "pairs"},
		{mitmSectionBody, `^x a b`, "starts with"},
		{mitmSectionMap, `^x data-type=file data="../a.json"`, "resources directory"},
		{mitmSectionMap, `^x data-type=file`, "needs data"},
		{mitmSectionMap, `^x data="https://a.example/reject-dict.json"`, "URL"},
		{mitmSectionMap, `^x data-type=text data="a" status-code=99`, "status-code"},
		{mitmSectionMap, `^x data-type=text data="a" colour=red`, "unknown parameter"},
		{"script", `^x a`, "unknown section"},
	}
	for _, tc := range invalid {
		if _, err := parseMitmRewriteLine(tc.section, tc.line); err == nil || !strings.Contains(err.Error(), tc.want) {
			t.Errorf("%s %q: error %v, want %q", tc.section, tc.line, err, tc.want)
		}
	}
	if rule, err := parseMitmRewriteLine(mitmSectionURL, "  # a comment"); rule != nil || err != nil {
		t.Errorf("comment: %v %v", rule, err)
	}
}

func TestMitmRewriteMapLocalDefaults(t *testing.T) {
	rule, err := parseMitmRewriteLine(mitmSectionMap, `^https:\/\/x\.com\/a data-type=text data="{}" status-code=201 header="Content-Type:application/json|X-A:b|Content-Length:9"`)
	if err != nil {
		t.Fatal(err)
	}
	local := rule.local
	if local.status != 201 || string(local.body) != "{}" || local.header.Get("Content-Type") != "application/json" || local.header.Get("X-A") != "b" || local.header.Get("Content-Length") != "" {
		t.Fatalf("local %+v", local)
	}
	gif, _ := parseMitmRewriteLine(mitmSectionMap, `^x data-type=tiny-gif`)
	if gif.local.header.Get("Content-Type") != "image/gif" || !bytes.Equal(gif.local.body, mitmTinyGIF) {
		t.Fatalf("gif %+v", gif.local)
	}
	b64, _ := parseMitmRewriteLine(mitmSectionMap, `^x data-type=base64 data="aGVsbG8="`)
	if string(b64.local.body) != "hello" || b64.local.header.Get("Content-Type") != "application/octet-stream" {
		t.Fatalf("base64 %+v", b64.local)
	}
}

func TestMitmRewriteMapLocalFiles(t *testing.T) {
	dir := t.TempDir()
	old := mitmResourcesDir
	mitmResourcesDir = func() string { return dir }
	t.Cleanup(func() { mitmResourcesDir = old })
	if err := os.WriteFile(filepath.Join(dir, "0123abcd.json"), []byte(`{"a":1}`), 0o600); err != nil {
		t.Fatal(err)
	}
	engine := withMitmRewrite(t, 0,
		rwRule("1", mitmSectionMap, `^https:\/\/a\.com\/x data="0123abcd.json"`),
		rwRule("2", mitmSectionMap, `^https:\/\/a\.com\/y data-type=file data="missing.json"`),
	)
	if len(engine.rules) != 1 || len(engine.issues) != 1 || engine.issues[0].Rule != "2" {
		t.Fatalf("engine rules %d issues %+v", len(engine.rules), engine.issues)
	}
	local := engine.rules[0].local
	if string(local.body) != `{"a":1}` || local.header.Get("Content-Type") != "application/json" {
		t.Fatalf("local %+v", local)
	}
}

// Pasted text: rewrite sections are taken, every other line is reported
// with its number, and a bad line leaves its neighbours alone.
func TestMitmRewriteParsesPastedText(t *testing.T) {
	text := strings.Join([]string{
		"#!name=Test module",                            // 1
		"[General]",                                     // 2
		"skip-proxy = 1.2.3.4",                          // 3
		"[URL Rewrite]",                                 // 4
		`^https:\/\/a\.com\/ad - reject`,                // 5
		`^https:\/\/a\.com bogus-type frob`,             // 6
		"# comment",                                     // 7
		"[Header Rewrite]",                              // 8
		`^https:\/\/a\.com header-add X-A 1`,            // 9
		"[Body Rewrite]",                                // 10
		`http-response-jq ^x '.a'`,                      // 11
		`http-response ^https:\/\/a\.com a b`,           // 12
		"[Map Local]",                                   // 13
		`^https:\/\/a\.com\/m data-type=text data="ok"`, // 14
		"[MITM]",                    // 15
		"hostname = %APPEND% a.com", // 16
	}, "\r\n")
	result := handleMitmRewriteParse(MitmRewriteParseParams{Text: text})
	var numbers []int
	for _, rule := range result.Rules {
		numbers = append(numbers, rule.Number)
	}
	if fmt.Sprint(numbers) != "[5 9 12 14]" {
		t.Fatalf("rules at %v: %+v", numbers, result.Rules)
	}
	var issues []int
	for _, issue := range result.Issues {
		issues = append(issues, issue.Line)
	}
	if fmt.Sprint(issues) != "[2 6 11 15]" {
		t.Fatalf("issues at %v: %+v", issues, result.Issues)
	}
	if loose := parseMitmRewriteText("^x - reject\n"); len(loose.Rules) != 0 || len(loose.Issues) != 1 || loose.Issues[0].Line != 1 {
		t.Fatalf("a line outside every section: %+v", loose)
	}
}

func TestMitmRewriteValidateAndInstallKeepGoodRules(t *testing.T) {
	result := handleMitmValidate(map[string][]string{
		"url-rewrite": {`^https:\/\/a\.com - reject`, `(bad https://x 302`},
		"map-local":   {`^x data-type=file data="a/b"`},
	})
	if len(result["url-rewrite"]) != 1 || result["url-rewrite"][0].Index != 1 || result["url-rewrite"][0].Code != mitmRewriteInvalid || len(result["map-local"]) != 1 || len(result["hostname"]) != 0 {
		t.Fatalf("validate %+v", result)
	}
	engine := withMitmRewrite(t, 0,
		rwRule("1", mitmSectionURL, `(bad https://x 302`),
		rwRule("2", mitmSectionURL, `^https:\/\/a\.com\/ad - reject`),
	)
	if len(engine.rules) != 1 || len(engine.issues) != 1 || engine.issues[0].Rule != "1" {
		t.Fatalf("engine %+v", engine)
	}
	status := handleMitmRewriteStatus()
	if !status.Active || len(status.Rules) != 1 || len(status.Issues) != 1 || status.BodyLimit != mitmDefaultRewriteBodyLimit {
		t.Fatalf("status %+v", status)
	}
}

func TestMitmRewriteCountersSurviveAnUnchangedReinstall(t *testing.T) {
	rules := []MitmRewriteRule{rwRule("a", mitmSectionURL, `^https:\/\/a\.com\/ad - reject`), rwRule("b", mitmSectionURL, `^https:\/\/a\.com\/x - reject`)}
	withMitmRewrite(t, 0, rules...)
	x := mitmRewriteBegin("https", "a.com", "/ad", false)
	x.request(http.Header{})
	rules[1].Line = `^https:\/\/a\.com\/y - reject`
	installMitmRewrite(&MitmSetup{Enable: true, Rewrite: rules})
	status := handleMitmRewriteStatus()
	if status.Rules[0].Hits != 1 || status.Rules[1].Hits != 0 {
		t.Fatalf("status %+v", status.Rules)
	}
}

func TestMitmRegexTemplatesAndFallback(t *testing.T) {
	re, _ := compileMitmRegex(`(\w+)@(\w+)`, false)
	if got, ok, _ := re.replaceAll("a@b c@d", "$2[$1]$$&$&"); !ok || got != "b[a]$&a@b d[c]$&c@d" {
		t.Fatalf("template %q", got)
	}
	look, err := compileMitmRegex(`(?<=id=)\d+`, true)
	if err != nil || look.re2 == nil {
		t.Fatalf("lookbehind %v", err)
	}
	if got, _, _ := look.replaceAll("id=12&x=34 id=5", "0"); got != "id=0&x=34 id=0" {
		t.Fatalf("lookbehind %q", got)
	}
	back, _ := compileMitmRegex(`(a)\1`, false)
	if ok, _ := back.match("xaay"); !ok {
		t.Fatal("backreference")
	}
	old := mitmRegexTimeout
	mitmRegexTimeout = 20 * time.Millisecond
	defer func() { mitmRegexTimeout = old }()
	slow, err := compileMitmRegex(`(?=a)(a+)+b`, false)
	if err != nil {
		t.Fatal(err)
	}
	start := time.Now()
	if _, err := slow.match(strings.Repeat("a", 40)); err != errMitmRegexTimeout {
		t.Fatalf("catastrophic match: %v", err)
	}
	if time.Since(start) > 2*time.Second {
		t.Fatal("the timeout did not bound the match")
	}
}

func TestMitmPatternHostIndex(t *testing.T) {
	for pattern, want := range map[string]string{
		`^https?:\/\/api\.example\.com\/v1`: "api.example.com",
		`^https:\/\/API\.example\.com\/`:    "api.example.com",
		`^http:\/\/a-b\.com$`:               "a-b.com",
		`^https:\/\/a\.com:8443\/`:          "a.com",
		`^https?:\/\/(www\.)?g\.cn`:         "",
		`^https:\/\/.+\.example\.com`:       "",
		`^https:\/\/a\.com|b\.com`:          "",
		`example\.com`:                      "",
		`^https:\/\/a\.com`:                 "",
	} {
		if got := mitmPatternHost(pattern); got != want {
			t.Errorf("%s: %q, want %q", pattern, got, want)
		}
	}
	engine := withMitmRewrite(t, 0,
		rwRule("1", mitmSectionURL, `^https:\/\/a\.com\/ - reject`),
		rwRule("2", mitmSectionURL, `\/generic - reject`),
		rwRule("3", mitmSectionURL, `^https:\/\/a\.com\/x - reject`),
	)
	var order []string
	for _, rule := range engine.url.candidates("a.com") {
		order = append(order, rule.id)
	}
	if fmt.Sprint(order) != "[1 2 3]" || len(engine.url.candidates("b.com")) != 1 {
		t.Fatalf("candidates %v", order)
	}
	if allocs := testing.AllocsPerRun(100, func() {
		if mitmRewriteBegin("https", "b.com", "/x", false) == nil {
			t.Fatal("generic rule ignored")
		}
	}); allocs > 2 {
		t.Errorf("begin allocates %v", allocs)
	}
	withMitmRewrite(t, 0, rwRule("1", mitmSectionURL, `^https:\/\/a\.com\/ - reject`))
	if allocs := testing.AllocsPerRun(100, func() {
		if mitmRewriteBegin("https", "b.com", "/x", false) != nil {
			t.Fatal("unnamed host")
		}
	}); allocs != 0 {
		t.Errorf("an unnamed host allocates %v", allocs)
	}
}

func TestMitmRewriteURLDecisions(t *testing.T) {
	withMitmRewrite(t, 0,
		rwRule("move", mitmSectionURL, `^https:\/\/a\.com\/v1\/(.*) https://a.com/v2/$1 header`),
		rwRule("cross", mitmSectionURL, `^https:\/\/a\.com\/cross https://b.com/ header`),
		rwRule("bad", mitmSectionURL, `^https:\/\/a\.com\/bad ftp://a.com/ 302`),
		rwRule("after", mitmSectionMap, `^https:\/\/a\.com\/v2\/local data-type=text data="m"`),
		rwRule("307", mitmSectionURL, `^https:\/\/a\.com\/t(.*) https://c.com/t$1 307`),
	)
	x := mitmRewriteBegin("https", "a.com", "/v1/local?q=1", false)
	d := x.request(http.Header{})
	if d.local == nil || string(d.local.body) != "m" || x.url != "https://a.com/v2/local?q=1" || x.originalURL != "https://a.com/v1/local?q=1" {
		t.Fatalf("header then map local: %+v %s", d, x.url)
	}
	x = mitmRewriteBegin("https", "a.com", "/cross", false)
	if d := x.request(http.Header{}); d.requestURI != "" || d.local != nil || x.hits[0].Skipped != mitmSkipCrossHost {
		t.Fatalf("cross host: %+v %+v", d, x.hits)
	}
	x = mitmRewriteBegin("https", "a.com", "/bad", false)
	if d := x.request(http.Header{}); d.local != nil || x.hits[0].Skipped != mitmSkipInvalidURL {
		t.Fatalf("bad target: %+v %+v", d, x.hits)
	}
	x = mitmRewriteBegin("https", "a.com", "/tx?y", false)
	if d := x.request(http.Header{}); d.local == nil || d.local.status != 307 || d.local.header.Get("Location") != "https://c.com/tx?y" {
		t.Fatalf("307: %+v", d)
	}
}

func gzipped(t *testing.T, s string) []byte {
	var b bytes.Buffer
	w := gzip.NewWriter(&b)
	_, _ = w.Write([]byte(s))
	_ = w.Close()
	return b.Bytes()
}

func TestMitmRewriteBodyCases(t *testing.T) {
	withMitmRewrite(t, 64, rwRule("ads", mitmSectionBody, `http-response ^https:\/\/a\.com\/ "ads":\[.*?\] "ads":[]`))
	run := func(contentType, encoding string, body []byte, length int64) (*mitmRewriteExchange, mitmBodyResult, http.Header) {
		x := mitmRewriteBegin("https", "a.com", "/", false)
		header := http.Header{"Content-Type": {contentType}}
		if encoding != "" {
			header.Set("Content-Encoding", encoding)
		}
		return x, x.rewriteBody(x.bodyRules(true), header, bytes.NewReader(body), length, true), header
	}
	read := func(r io.Reader) string { b, _ := io.ReadAll(r); return string(b) }

	_, res, _ := run("application/json", "gzip", gzipped(t, `{"ads":[1,2],"x":1}`), -1)
	if !res.changed || read(res.body) != `{"ads":[],"x":1}` || res.length != 16 {
		t.Fatalf("gzip json: %+v", res)
	}
	var br bytes.Buffer
	bw := brotli.NewWriter(&br)
	_, _ = bw.Write([]byte(`{"ads":[3]}`))
	_ = bw.Close()
	if _, res, _ := run("application/json; charset=utf-8", "br", br.Bytes(), int64(br.Len())); !res.changed || read(res.body) != `{"ads":[]}` {
		t.Fatalf("br: %+v", res)
	}
	cases := []struct {
		name, contentType, encoding string
		body                        []byte
		length                      int64
		skip                        string
	}{
		{"binary", "image/png", "", []byte(`"ads":[1]`), 9, mitmSkipNotText},
		{"sse", "text/event-stream", "", []byte(`"ads":[1]`), -1, mitmSkipStreaming},
		{"declared oversize", "text/plain", "", []byte(`"ads":[1]`), 65, mitmSkipOversize},
		{"oversize", "text/plain", "", []byte(strings.Repeat("x", 100) + `"ads":[1]`), -1, mitmSkipOversize},
		{"bad gzip", "text/plain", "gzip", []byte("not gzip"), -1, mitmSkipDecode},
		{"zstd", "text/plain", "zstd", []byte("whatever"), -1, mitmSkipEncoding},
		{"not utf-8", "text/plain", "", []byte("\xff\xfe\"ads\":[1]"), -1, mitmSkipNotUTF8},
		{"gzip bomb", "text/plain", "gzip", gzipped(t, strings.Repeat("a", 1000)), -1, mitmSkipOversize},
	}
	for _, tc := range cases {
		x, res, header := run(tc.contentType, tc.encoding, tc.body, tc.length)
		if res.changed || read(res.body) != string(tc.body) || len(x.hits) != 1 || x.hits[0].Skipped != tc.skip || header.Get("Content-Encoding") != tc.encoding {
			t.Errorf("%s: changed=%v hits=%+v", tc.name, res.changed, x.hits)
		}
	}
	// A body nothing matched in is passed on as it came, still encoded.
	x, res, _ := run("text/plain", "gzip", gzipped(t, "nothing"), -1)
	if res.changed || !bytes.Equal([]byte(read(res.body)), gzipped(t, "nothing")) || x.hits[0].Skipped != "" {
		t.Fatalf("no match: %+v %+v", res, x.hits)
	}
	if status := handleMitmRewriteStatus(); status.Rules[0].Skips != int64(len(cases)) || status.Rules[0].LastSkip == "" {
		t.Fatalf("status %+v", status.Rules[0])
	}
}

// ---- HTTP/1.1 sessions ----

type rewriteH1 struct {
	conn net.Conn
	r    *bufio.Reader
	hits *atomic.Int64
	done chan error
}

func startRewriteH1(t *testing.T, plain bool, handler http.HandlerFunc) *rewriteH1 {
	t.Helper()
	h := &rewriteH1{hits: &atomic.Int64{}, done: make(chan error, 1)}
	site := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		h.hits.Add(1)
		handler(w, r)
	}))
	t.Cleanup(site.Close)
	clientRaw, proxyClient := mitmLoopbackPair(t)
	up, err := net.DialTimeout("tcp", site.Listener.Addr().String(), time.Second)
	if err != nil {
		t.Fatal(err)
	}
	for _, c := range []net.Conn{clientRaw, proxyClient, up} {
		_ = c.SetDeadline(time.Now().Add(10 * time.Second))
		t.Cleanup(func() { _ = c.Close() })
	}
	pc := &mitmIdleConn{Conn: proxyClient, timeout: 5 * time.Second}
	ps := &mitmIdleConn{Conn: up, timeout: 5 * time.Second}
	control := &mitmDuplexControl{client: pc, upstream: ps, connection: "rw-conn", plain: plain}
	go func() {
		err := mitmHTTP1Duplex(pc, ps, "example.com", func() bool { return true }, control)
		_ = proxyClient.Close()
		_ = up.Close()
		h.done <- err
	}()
	h.conn, h.r = clientRaw, bufio.NewReader(clientRaw)
	return h
}

func (h *rewriteH1) do(t *testing.T, raw string) (*http.Response, string) {
	t.Helper()
	if _, err := io.WriteString(h.conn, raw); err != nil {
		t.Fatal(err)
	}
	resp, err := http.ReadResponse(h.r, nil)
	if err != nil {
		t.Fatalf("response to %q: %v", strings.SplitN(raw, "\r\n", 2)[0], err)
	}
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatal(err)
	}
	return resp, string(body)
}

func get(path string) string {
	return "GET " + path + " HTTP/1.1\r\nHost: example.com\r\n\r\n"
}

func rewriteTestRules() []MitmRewriteRule {
	return []MitmRewriteRule{
		rwRule("dict", mitmSectionURL, `^https?:\/\/example\.com\/ad - reject-dict`),
		rwRule("moved", mitmSectionURL, `^https?:\/\/example\.com\/old https://example.com/new 302`),
		rwRule("v2", mitmSectionURL, `^https?:\/\/example\.com\/v1\/(.*) https://example.com/v2/$1 header`),
		rwRule("drop", mitmSectionURL, `^https?:\/\/example\.com\/drop - reject-drop`),
		rwRule("addreq", mitmSectionHeader, `http-request ^https?:\/\/example\.com\/ header-add X-Req 1`),
		rwRule("ua", mitmSectionHeader, `http-request ^https?:\/\/example\.com\/ header-replace-regex User-Agent iPhone Mac`),
		rwRule("delresp", mitmSectionHeader, `http-response ^https?:\/\/example\.com\/ header-del X-Remove`),
		rwRule("ads", mitmSectionBody, `http-response ^https?:\/\/example\.com\/ "ads":\[.*?\] "ads":[]`),
		rwRule("form", mitmSectionBody, `http-request ^https?:\/\/example\.com\/form a=1 a=2`),
		rwRule("local", mitmSectionMap, `^https?:\/\/example\.com\/local data-type=text data="from map" header="X-Local:yes"`),
	}
}

func rewriteTestSite(w http.ResponseWriter, r *http.Request) {
	switch {
	case r.URL.Path == "/form":
		body, _ := io.ReadAll(r.Body)
		w.Header().Set("Content-Type", "text/plain")
		fmt.Fprintf(w, "%s|%s", body, r.Header.Get("Content-Length"))
	case r.URL.Path == "/bin":
		w.Header().Set("Content-Type", "image/png")
		_, _ = w.Write([]byte(`"ads":[1]`))
	case strings.HasPrefix(r.URL.Path, "/v2/"):
		w.Header().Set("Content-Type", "application/json")
		w.Header().Set("Content-Encoding", "gzip")
		w.Header().Set("X-Remove", "1")
		w.Header().Set("X-Seen", r.URL.RequestURI()+" "+r.Header.Get("X-Req")+" "+r.Header.Get("User-Agent"))
		var b bytes.Buffer
		zw := gzip.NewWriter(&b)
		_, _ = zw.Write([]byte(`{"ads":[1,2],"ok":true}`))
		_ = zw.Close()
		_, _ = w.Write(b.Bytes())
	default:
		w.Header().Set("X-Seen", r.URL.RequestURI()+" "+r.Header.Get("X-Req"))
		_, _ = io.WriteString(w, "site")
	}
}

func TestMitmRewriteHTTP1Session(t *testing.T) {
	withMitmCapture(t, mitmDefaultCaptureLimits)
	withMitmRewrite(t, 0, rewriteTestRules()...)
	h := startRewriteH1(t, false, rewriteTestSite)

	resp, body := h.do(t, get("/ad"))
	if resp.StatusCode != 200 || body != "{}" || resp.Header.Get("Content-Type") != "application/json" || resp.ContentLength != 2 {
		t.Fatalf("reject-dict: %d %q %v", resp.StatusCode, body, resp.Header)
	}
	// A rejected upload is drained, and the connection carries on.
	resp, _ = h.do(t, "POST /old HTTP/1.1\r\nHost: example.com\r\nContent-Length: 3\r\n\r\nxyz")
	if resp.StatusCode != 302 || resp.Header.Get("Location") != "https://example.com/new" {
		t.Fatalf("302: %d %v", resp.StatusCode, resp.Header)
	}
	resp, body = h.do(t, get("/local"))
	if resp.StatusCode != 200 || body != "from map" || resp.Header.Get("X-Local") != "yes" {
		t.Fatalf("map local: %d %q", resp.StatusCode, body)
	}
	if h.hits.Load() != 0 {
		t.Fatalf("the site was asked %d times for locally answered requests", h.hits.Load())
	}
	resp, body = h.do(t, "GET /v1/x?q=1 HTTP/1.1\r\nHost: example.com\r\nUser-Agent: iPhone\r\nAccept-Encoding: gzip\r\n\r\n")
	if body != `{"ads":[],"ok":true}` || resp.ContentLength != int64(len(body)) || resp.Header.Get("Content-Encoding") != "" || resp.Header.Get("X-Remove") != "" || resp.Header.Get("X-Seen") != "/v2/x?q=1 1 Mac" {
		t.Fatalf("rewritten: %q %d %v", body, resp.ContentLength, resp.Header)
	}
	resp, body = h.do(t, get("/bin"))
	if body != `"ads":[1]` || resp.Header.Get("Content-Type") != "image/png" {
		t.Fatalf("binary: %q", body)
	}
	resp, body = h.do(t, "POST /form HTTP/1.1\r\nHost: example.com\r\nContent-Type: application/x-www-form-urlencoded\r\nContent-Length: 7\r\n\r\na=1&b=1")
	if body != "a=2&b=1|7" {
		t.Fatalf("request body: %q", body)
	}
	// Chunked uploads pass unchanged.
	resp, body = h.do(t, "POST /form HTTP/1.1\r\nHost: example.com\r\nContent-Type: text/plain\r\nTransfer-Encoding: chunked\r\n\r\n3\r\na=1\r\n0\r\n\r\n")
	if body != "a=1|" {
		t.Fatalf("chunked upload: %q", body)
	}
	list := handleMitmExchanges(MitmExchangesParams{ID: "rw-conn"})
	if len(list.Exchanges) != 7 {
		t.Fatalf("recorded %d", len(list.Exchanges))
	}
	for i, summary := range list.Exchanges {
		wantSkipped := i == 4 || i == 6
		if !summary.Rewritten || summary.RewriteSkipped != wantSkipped {
			t.Errorf("exchange %d %s: rewritten=%v skipped=%v", i, summary.URL, summary.Rewritten, summary.RewriteSkipped)
		}
	}
	moved := handleMitmExchange(MitmExchangeParams{ID: list.Exchanges[3].ID})
	if moved.URL != "https://example.com/v2/x?q=1" || moved.OriginalURL != "https://example.com/v1/x?q=1" || len(moved.Actions) == 0 {
		t.Fatalf("exchange %+v", moved)
	}
	if text, _ := mitmBodyText(t, list.Exchanges[3].ID, true); text != `{"ads":[],"ok":true}` {
		t.Fatalf("recorded body %q", text)
	}
	if _, err := io.WriteString(h.conn, get("/drop")); err != nil {
		t.Fatal(err)
	}
	if _, err := http.ReadResponse(h.r, nil); err == nil {
		t.Fatal("reject-drop answered")
	}
	if err := <-h.done; err != nil {
		t.Fatalf("session: %v", err)
	}
	list = handleMitmExchanges(MitmExchangesParams{ID: "rw-conn"})
	if last := list.Exchanges[len(list.Exchanges)-1]; last.Error != mitmExchangeDropped {
		t.Fatalf("drop recorded as %+v", last)
	}
}

// With no rule for the host, a session is byte-for-byte what it was.
func TestMitmRewriteHTTP1UnmatchedHostUntouched(t *testing.T) {
	withMitmRewrite(t, 0, rwRule("x", mitmSectionBody, `http-response ^https:\/\/other\.com\/ a b`), rwRule("y", mitmSectionHeader, `^https:\/\/other\.com\/ header-add X-A 1`))
	h := startRewriteH1(t, false, func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain")
		_, _ = io.WriteString(w, "a a "+r.Header.Get("X-A"))
	})
	if _, body := h.do(t, get("/")); body != "a a " {
		t.Fatalf("body %q", body)
	}
}

// ---- HTTP/2 ----

func TestMitmRewriteHTTP2(t *testing.T) {
	withMitmCapture(t, mitmDefaultCaptureLimits)
	withMitmRewrite(t, 0, rewriteTestRules()...)
	var hits atomic.Int64
	site := newMitmH2Site(t, true, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		hits.Add(1)
		if strings.HasPrefix(r.URL.Path, "/v2/") {
			w.Header().Set("Trailer", "X-Trailer")
			rewriteTestSite(w, r)
			w.Header().Set("X-Trailer", "kept")
			return
		}
		rewriteTestSite(w, r)
	}))
	h := newMitmH2Harness(t, site, []string{"h2", "http/1.1"}, nil)
	cc := h.h2(t)
	do := func(method, path, body string, header http.Header) (*http.Response, string, error) {
		var r io.Reader
		if body != "" {
			r = strings.NewReader(body)
		}
		req, _ := http.NewRequest(method, "https://example.com"+path, r)
		for k, v := range header {
			req.Header[k] = v
		}
		resp, err := cc.RoundTrip(req)
		if err != nil {
			return nil, "", err
		}
		defer resp.Body.Close()
		b, err := io.ReadAll(resp.Body)
		return resp, string(b), err
	}
	resp, body, err := do("GET", "/ad", "", nil)
	if err != nil || resp.StatusCode != 200 || body != "{}" || resp.Header.Get("Content-Length") != "2" {
		t.Fatalf("reject-dict: %v %v %q", err, resp, body)
	}
	resp, body, err = do("GET", "/local", "", nil)
	if err != nil || body != "from map" || resp.Header.Get("X-Local") != "yes" {
		t.Fatalf("map local: %v %q", err, body)
	}
	if _, _, err = do("GET", "/drop", "", nil); err == nil {
		t.Fatal("reject-drop answered")
	}
	if hits.Load() != 0 {
		t.Fatalf("site asked %d times", hits.Load())
	}
	resp, body, err = do("GET", "/v1/x", "", http.Header{"Accept-Encoding": {"gzip"}, "User-Agent": {"iPhone"}})
	if err != nil || body != `{"ads":[],"ok":true}` || resp.ContentLength != int64(len(body)) || resp.Header.Get("Content-Encoding") != "" || resp.Header.Get("X-Remove") != "" || resp.Header.Get("X-Seen") != "/v2/x 1 Mac" || resp.Trailer.Get("X-Trailer") != "kept" {
		t.Fatalf("rewritten: %v %q %v trailer %v", err, body, resp.Header, resp.Trailer)
	}
	_, body, err = do("POST", "/form", "a=1", http.Header{"Content-Type": {"text/plain"}})
	if err != nil || body != "a=2|3" {
		t.Fatalf("request body: %v %q", err, body)
	}
	list := handleMitmExchanges(MitmExchangesParams{ID: "h2-connection"})
	if len(list.Exchanges) != 5 || list.Exchanges[2].Error != mitmExchangeDropped {
		t.Fatalf("recorded %+v", list.Exchanges)
	}
	_ = cc.Close()
	if outcome := h.outcome(t); outcome != "" {
		t.Fatalf("outcome %q", outcome)
	}
}

// ---- Plain HTTP and the switch ----

type plainFlow struct {
	client net.Conn
	r      *bufio.Reader
	done   chan struct{}
}

// Offers the hook a port-80 flow whose client already sent first, as the
// tunnel would; returns nil when the hook leaves the flow alone.
func startPlainFlow(t *testing.T, site *httptest.Server, first string) *plainFlow {
	t.Helper()
	clientRaw, proxyClient := mitmLoopbackPair(t)
	for _, c := range []net.Conn{clientRaw, proxyClient} {
		_ = c.SetDeadline(time.Now().Add(10 * time.Second))
		t.Cleanup(func() { _ = c.Close() })
	}
	if _, err := io.WriteString(clientRaw, first); err != nil {
		t.Fatal(err)
	}
	buffered := N.NewBufferedConn(proxyClient)
	intercept := mitmInterceptEligible(buffered, &C.Metadata{DstPort: mitmPlainHTTPPort, Host: "example.com"})
	if intercept == nil {
		if buffered.Reader().Buffered() != 0 {
			// Peeked bytes stay for the relay; nothing was consumed.
			if b, _ := buffered.Peek(buffered.Reader().Buffered()); string(b) != first[:len(b)] {
				t.Fatal("peeked bytes changed")
			}
		}
		return nil
	}
	up, err := net.DialTimeout("tcp", site.Listener.Addr().String(), time.Second)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = up.Close() })
	f := &plainFlow{client: clientRaw, r: bufio.NewReader(clientRaw), done: make(chan struct{})}
	go func() {
		defer close(f.done)
		intercept(buffered, mitmSelectionConn{N.NewExtendedConn(up)})
		// As the tunnel does once the interceptor returns.
		_ = buffered.Close()
		_ = up.Close()
	}()
	return f
}

func TestMitmPlainHTTPRejectAndRedirectOnly(t *testing.T) {
	withMitmCapture(t, mitmDefaultCaptureLimits)
	withMitmRewrite(t, 0, rewriteTestRules()...)
	mitmState.Store(&mitmRuntime{setup: MitmSetup{Enable: true}})
	oldPort := mitmPlainHTTPPort
	mitmPlainHTTPPort = 8080
	t.Cleanup(func() { mitmPlainHTTPPort = oldPort })

	var seen atomic.Value
	site := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		seen.Store(r.URL.RequestURI() + "|" + r.Header.Get("X-Req"))
		w.Header().Set("Content-Type", "application/json")
		w.Header().Set("X-Remove", "1")
		_, _ = io.WriteString(w, `{"ads":[1]}`)
	}))
	t.Cleanup(site.Close)

	if !mitmInterceptWanted(&C.Metadata{DstPort: 8080, Host: "example.com"}) || mitmInterceptWanted(&C.Metadata{DstPort: 8080, Host: "other.com"}) || mitmInterceptWanted(&C.Metadata{DstPort: 8080}) {
		t.Fatal("port-80 selection")
	}
	// Not taken: HTTP/1.0, absolute-form, another Host, an upgrade, not HTTP.
	for _, first := range []string{
		"GET /ad HTTP/1.0\r\nHost: example.com\r\n\r\n",
		"GET http://example.com/ad HTTP/1.1\r\nHost: example.com\r\n\r\n",
		"GET /ad HTTP/1.1\r\nHost: other.com\r\n\r\n",
		"GET /ad HTTP/1.1\r\nHost: example.com\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n",
		"\x16\x03\x01\x00\x05hello",
	} {
		if startPlainFlow(t, site, first) != nil {
			t.Errorf("took %q", first)
		}
	}

	f := startPlainFlow(t, site, get("/ad"))
	if f == nil {
		t.Fatal("not taken")
	}
	read := func() (*http.Response, string) {
		resp, err := http.ReadResponse(f.r, nil)
		if err != nil {
			t.Fatal(err)
		}
		b, _ := io.ReadAll(resp.Body)
		return resp, string(b)
	}
	if resp, body := read(); resp.StatusCode != 200 || body != "{}" {
		t.Fatalf("reject: %d %q", resp.StatusCode, body)
	}
	_, _ = io.WriteString(f.client, get("/old"))
	if resp, _ := read(); resp.StatusCode != 302 {
		t.Fatalf("redirect: %d", resp.StatusCode)
	}
	// Everything else passes unchanged: no header, body, map-local or
	// header-mode URL rewriting on plain HTTP.
	_, _ = io.WriteString(f.client, get("/v1/x"))
	resp, body := read()
	if body != `{"ads":[1]}` || resp.Header.Get("X-Remove") != "1" || seen.Load() != "/v1/x|" {
		t.Fatalf("plain pass: %q %v %v", body, resp.Header, seen.Load())
	}
	_, _ = io.WriteString(f.client, get("/local"))
	if _, body := read(); body == "from map" {
		t.Fatal("map local on plain HTTP")
	}
	// Turning the switch off ends the flow before the next request is
	// rewritten.
	mitmState.Store(&mitmRuntime{setup: MitmSetup{Enable: false}})
	_, _ = io.WriteString(f.client, get("/ad"))
	if resp, err := http.ReadResponse(f.r, nil); err == nil {
		b, _ := io.ReadAll(resp.Body)
		t.Fatalf("answered after the switch went off: %d %q", resp.StatusCode, b)
	}
	<-f.done
}

// The MITM switch off: no rewrite at all, port 80 included, whatever the
// rules say.
func TestMitmRewriteOffMeansNoRewrite(t *testing.T) {
	withMitmState(t)
	rules := rewriteTestRules()
	withMitmRewrite(t, 0, rules...)

	applyMitmSetup(&SetupParams{Mitm: &MitmSetup{Enable: false, Rewrite: rules}}, nil)
	if mitmRewrite.Load() != nil || handleMitmRewriteStatus().Active {
		t.Fatal("rules installed with the switch off")
	}
	if mitmInterceptWanted(&C.Metadata{DstPort: mitmPlainHTTPPort, Host: "example.com"}) {
		t.Fatal("port 80 held with the switch off")
	}
	if mitmRewriteBegin("https", "example.com", "/ad", false) != nil || mitmRewriteBegin("http", "example.com", "/ad", true) != nil {
		t.Fatal("rewrite began with the switch off")
	}

	applyMitmSetup(&SetupParams{Mitm: &MitmSetup{Enable: true, Rewrite: rules}}, nil)
	if mitmRewrite.Load() == nil || !mitmInterceptWanted(&C.Metadata{DstPort: mitmPlainHTTPPort, Host: "example.com"}) {
		t.Fatal("the switch on installs nothing")
	}
	handleMitmDisable()
	if mitmRewrite.Load() != nil || mitmInterceptWanted(&C.Metadata{DstPort: mitmPlainHTTPPort, Host: "example.com"}) {
		t.Fatal("mitm.disable left rewriting on")
	}

	applyMitmSetup(&SetupParams{Mitm: &MitmSetup{Enable: true, Rewrite: rules}}, nil)
	if err := handleMitmUpdate(MitmUpdateParams{Setup: &MitmSetup{Enable: false, Rewrite: rules}}); err != nil {
		t.Fatal(err)
	}
	if mitmRewrite.Load() != nil {
		t.Fatal("mitm.update with the switch off left rewriting on")
	}
	applyMitmSetup(&SetupParams{}, nil)
	if mitmRewrite.Load() != nil {
		t.Fatal("a setup without MITM left rewriting on")
	}

	// A stale engine (installed before the switch went off) still does
	// nothing on port 80.
	mitmRewrite.Store(compileMitmRewrite(rules, mitmDefaultRewriteBodyLimit, nil))
	mitmState.Store(&mitmRuntime{setup: MitmSetup{Enable: false}})
	if mitmPlainWanted(&C.Metadata{DstPort: mitmPlainHTTPPort, Host: "example.com"}) || mitmRewriteBegin("http", "example.com", "/ad", true) != nil {
		t.Fatal("plain rewrite ran with the switch off")
	}

	// End to end: a decrypted session with the switch off passes everything.
	mitmRewrite.Store(nil)
	h := startRewriteH1(t, false, rewriteTestSite)
	if resp, body := h.do(t, get("/ad")); resp.StatusCode != 200 || body != "site" {
		t.Fatalf("off: %d %q", resp.StatusCode, body)
	}
}

// Rule changes alone keep sessions; the decryption settings still end them.
func TestMitmRewriteRuleChangeKeepsTheRuntime(t *testing.T) {
	withMitmState(t)
	withMitmRewrite(t, 0)
	setup := MitmSetup{Enable: true, Hostname: []string{"example.com"}, DecryptTLS: true, CAFingerprint: "AA"}
	applyMitmSetup(&SetupParams{Mitm: &setup}, nil)
	before := mitmState.Load()
	changed := setup
	changed.Rewrite = []MitmRewriteRule{rwRule("1", mitmSectionURL, `^https:\/\/example\.com\/ad - reject`)}
	if err := handleMitmUpdate(MitmUpdateParams{Setup: &changed}); err != nil {
		t.Fatal(err)
	}
	if mitmState.Load() != before {
		t.Fatal("a rule change replaced the runtime")
	}
	if mitmRewrite.Load() == nil || len(mitmRewrite.Load().rules) != 1 {
		t.Fatal("the new rule is not in force")
	}
	if !strings.Contains(strconv.Quote(handleMitmRewriteStatus().Rules[0].Rule), "1") {
		t.Fatal("status")
	}
}
