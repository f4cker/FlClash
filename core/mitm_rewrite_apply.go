package core

import (
	"bytes"
	"compress/flate"
	"compress/gzip"
	"compress/zlib"
	"errors"
	"io"
	"mime"
	"net"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"sync"
	"time"
	"unicode/utf8"

	"github.com/andybalholm/brotli"
	"github.com/metacubex/mihomo/log"
)

// One request/response being rewritten. nil when no rule can apply to its
// host, which is the case for nearly every request: the check is one atomic
// load and a few map lookups, and allocates nothing.
type mitmRewriteExchange struct {
	engine *mitmRewriteEngine
	scheme string
	host   string
	// host, with the connection's port when it is not the scheme's default.
	authority   string
	url         string
	originalURL string
	plain       bool
	h2          bool
	hits        []MitmRewriteHit
}

// For a decrypted request (plain false) or a plain-HTTP one, given its host
// and port as the connection knows them (port 0: the scheme's default) and
// its request-target.
func mitmRewriteBegin(scheme, host string, port uint16, requestURI string, plain bool) *mitmRewriteExchange {
	engine := mitmRewrite.Load()
	if engine.empty() || requestURI == "" || requestURI[0] != '/' {
		return nil
	}
	if plain {
		if runtime := mitmState.Load(); runtime == nil || !runtime.setup.Enable || !engine.plain.mayMatch(host) {
			return nil
		}
	} else if !engine.url.mayMatch(host) && !engine.requestHeader.mayMatch(host) &&
		!engine.responseHeader.mayMatch(host) && !engine.requestBody.mayMatch(host) &&
		!engine.responseBody.mayMatch(host) && !engine.mapLocal.mayMatch(host) &&
		!engine.requestScript.mayMatch(host) && !engine.responseScript.mayMatch(host) {
		return nil
	}
	authority := host
	if strings.Contains(host, ":") {
		authority = "[" + host + "]"
	}
	if port != 0 && strconv.Itoa(int(port)) != mitmDefaultPort(scheme) {
		authority = net.JoinHostPort(host, strconv.Itoa(int(port)))
	}
	u := scheme + "://" + authority + requestURI
	return &mitmRewriteExchange{engine: engine, scheme: scheme, host: host, authority: authority, url: u, originalURL: u, plain: plain}
}

// Records an applied rule with the time since start, at least 1ns so a
// measured rule never reads as unmeasured.
func (x *mitmRewriteExchange) recordApplied(rule *mitmRewriteRule, phase, action string, start time.Time) {
	x.record(rule, phase, action, "")
	x.hits[len(x.hits)-1].TookNs = max(int64(time.Since(start)), 1)
}

func (x *mitmRewriteExchange) record(rule *mitmRewriteRule, phase, action, skip string) {
	x.hits = append(x.hits, MitmRewriteHit{Rule: rule.id, Section: rule.section, Phase: phase, Action: action, Skipped: skip})
	rule.stats.record(skip)
	if skip != "" {
		log.Debugln("[MITM] rewrite %s rule %s skipped: %s", rule.section, rule.id, skip)
	}
}

// Whether rule's URL pattern matches the current URL; a match that timed
// out is recorded as a skip and counts as no match.
func (x *mitmRewriteExchange) matches(rule *mitmRewriteRule, phase string) bool {
	ok, err := rule.url.match(x.url)
	if err != nil {
		x.record(rule, phase, "", mitmSkipTimeout)
		return false
	}
	return ok
}

func (x *mitmRewriteExchange) rewritten() bool {
	return x != nil && len(x.hits) > 0
}

// What the request phase decided.
type mitmRequestDecision struct {
	// Answer with this instead of asking the site.
	local *mitmLocalResponse
	// Drop the request without an answer (reject-drop).
	drop bool
	// The new request-target, when a header-mode URL Rewrite applied.
	requestURI string
}

// Steps 1-3 of the order in mitm_rewrite.go, on header in place.
func (x *mitmRewriteExchange) request(header http.Header) (decision mitmRequestDecision) {
	if x == nil {
		return
	}
	if !x.plain {
		x.rewriteHeader(&x.engine.requestHeader, header, "request")
	}
	index := &x.engine.url
	if x.plain {
		index = &x.engine.plain
	}
	for _, rule := range index.candidates(x.host) {
		if !x.matches(rule, "request") {
			continue
		}
		decision = x.applyURL(rule)
		if decision.local != nil || decision.drop {
			return decision
		}
		break
	}
	if x.plain {
		return decision
	}
	for _, rule := range x.engine.mapLocal.candidates(x.host) {
		start := time.Now()
		if x.matches(rule, "request") {
			x.recordApplied(rule, "request", "map-local", start)
			decision.local = rule.local
			return decision
		}
	}
	return decision
}

func (x *mitmRewriteExchange) applyURL(rule *mitmRewriteRule) mitmRequestDecision {
	start := time.Now()
	action := string(rule.urlAction)
	switch rule.urlAction {
	case mitmURLRejectDrop:
		x.recordApplied(rule, "request", action, start)
		return mitmRequestDecision{drop: true}
	case mitmURLReject, mitmURLRejectNoDrop:
		x.recordApplied(rule, "request", action, start)
		return mitmRequestDecision{local: &mitmLocalResponse{status: http.StatusNotFound, header: http.Header{}}}
	case mitmURLReject200:
		x.recordApplied(rule, "request", action, start)
		return mitmRequestDecision{local: &mitmLocalResponse{status: http.StatusOK, header: http.Header{}}}
	case mitmURLRejectImg:
		x.recordApplied(rule, "request", action, start)
		return mitmRequestDecision{local: &mitmLocalResponse{status: http.StatusOK, header: http.Header{"Content-Type": {"image/gif"}}, body: mitmTinyGIF}}
	case mitmURLRejectDict:
		x.recordApplied(rule, "request", action, start)
		return mitmRequestDecision{local: &mitmLocalResponse{status: http.StatusOK, header: http.Header{"Content-Type": {"application/json"}}, body: []byte("{}")}}
	case mitmURLRejectArray:
		x.recordApplied(rule, "request", action, start)
		return mitmRequestDecision{local: &mitmLocalResponse{status: http.StatusOK, header: http.Header{"Content-Type": {"application/json"}}, body: []byte("[]")}}
	}
	target, _, err := rule.url.replaceAll(x.url, rule.replacement)
	if err != nil {
		x.record(rule, "request", action, mitmSkipTimeout)
		return mitmRequestDecision{}
	}
	parsed, err := url.Parse(target)
	if err != nil || parsed.Host == "" {
		x.record(rule, "request", action, mitmSkipInvalidURL)
		return mitmRequestDecision{}
	}
	switch strings.ToLower(parsed.Scheme) {
	case "http", "https", "ws", "wss":
	default:
		x.record(rule, "request", action, mitmSkipInvalidURL)
		return mitmRequestDecision{}
	}
	if rule.urlAction == mitmURL302 || rule.urlAction == mitmURL307 {
		x.recordApplied(rule, "request", action, start)
		status := http.StatusFound
		if rule.urlAction == mitmURL307 {
			status = http.StatusTemporaryRedirect
		}
		return mitmRequestDecision{local: &mitmLocalResponse{status: status, header: http.Header{"Location": {target}}}}
	}
	// Header mode rewrites in place, on the connection the request came
	// on: only a target on the same host and port can be served there. The
	// scheme of the connection stays.
	host, port := parsed.Hostname(), parsed.Port()
	if port == "" {
		port = mitmDefaultPort(parsed.Scheme)
	}
	if normalizeMitmHost(host) != x.host || port != x.port() {
		x.record(rule, "request", action, mitmSkipCrossHost)
		return mitmRequestDecision{}
	}
	requestURI := parsed.RequestURI()
	x.url = x.scheme + "://" + x.authority + requestURI
	x.recordApplied(rule, "request", action, start)
	return mitmRequestDecision{requestURI: requestURI}
}

// The connection's port.
func (x *mitmRewriteExchange) port() string {
	if _, port, err := net.SplitHostPort(x.authority); err == nil {
		return port
	}
	return mitmDefaultPort(x.scheme)
}

func mitmDefaultPort(scheme string) string {
	switch strings.ToLower(scheme) {
	case "https", "wss":
		return "443"
	}
	return "80"
}

// Response-side Header Rewrite, on the request's final URL.
func (x *mitmRewriteExchange) responseHeader(header http.Header) {
	if x == nil || x.plain {
		return
	}
	x.rewriteHeader(&x.engine.responseHeader, header, "response")
}

func (x *mitmRewriteExchange) rewriteHeader(index *mitmRuleIndex, header http.Header, phase string) {
	for _, rule := range index.candidates(x.host) {
		if !x.matches(rule, phase) {
			continue
		}
		start := time.Now()
		_, present := header[rule.field]
		switch rule.headerOp {
		case mitmHeaderAdd:
			header.Add(rule.field, rule.value)
		case mitmHeaderDel:
			header.Del(rule.field)
		case mitmHeaderReplace:
			if present {
				header.Set(rule.field, rule.value)
			}
		case mitmHeaderReplaceRegex:
			if present {
				values := header[rule.field]
				replaced := make([]string, len(values))
				failed := false
				for i, value := range values {
					result, _, err := rule.valueRegex.replaceAll(value, rule.valueResult)
					if err != nil {
						failed = true
						break
					}
					replaced[i] = result
				}
				if failed {
					x.record(rule, phase, string(rule.headerOp), mitmSkipTimeout)
					continue
				}
				header[rule.field] = replaced
			}
		}
		x.recordApplied(rule, phase, string(rule.headerOp), start)
	}
}

// The Body Rewrite rules whose pattern matches, in order; nil for none.
func (x *mitmRewriteExchange) bodyRules(response bool) []*mitmRewriteRule {
	if x == nil || x.plain {
		return nil
	}
	index, phase := &x.engine.requestBody, "request"
	if response {
		index, phase = &x.engine.responseBody, "response"
	}
	var matched []*mitmRewriteRule
	for _, rule := range index.candidates(x.host) {
		if x.matches(rule, phase) {
			matched = append(matched, rule)
		}
	}
	return matched
}

func (x *mitmRewriteExchange) skipAll(rules []*mitmRewriteRule, phase, skip string) {
	for _, rule := range rules {
		x.record(rule, phase, "body", skip)
	}
}

// Whether a body of this Content-Type is text a regex may rewrite. No type
// at all is let through to the UTF-8 check; a stream (SSE) never is.
func mitmTextContent(contentType string) bool {
	if strings.TrimSpace(contentType) == "" {
		return true
	}
	media, _, err := mime.ParseMediaType(contentType)
	if err != nil {
		media = strings.ToLower(strings.TrimSpace(strings.Split(contentType, ";")[0]))
	}
	switch {
	case media == "text/event-stream":
		return false
	case strings.HasPrefix(media, "text/"):
		return true
	case strings.HasSuffix(media, "+json"), strings.HasSuffix(media, "+xml"):
		return true
	}
	switch media {
	case "application/json", "application/javascript", "application/x-javascript",
		"application/ecmascript", "application/xml", "application/x-www-form-urlencoded",
		"application/graphql", "application/x-plist":
		return true
	}
	return false
}

var errMitmRewriteBodyTooLarge = errors.New("decoded body over the rewrite limit")

// Undoes a content coding for rewriting, within limit. ok is false when the
// coding is not one Flash undoes (an unsupported coding is not an error).
func mitmDecodeContent(data []byte, coding string, limit int64) (decoded []byte, supported bool, err error) {
	var reader io.Reader
	switch strings.ToLower(strings.TrimSpace(coding)) {
	case "", "identity":
		return data, true, nil
	case "gzip", "x-gzip":
		zr, err := gzip.NewReader(bytes.NewReader(data))
		if err != nil {
			return nil, true, err
		}
		defer zr.Close()
		reader = zr
	case "deflate":
		if zr, err := zlib.NewReader(bytes.NewReader(data)); err == nil {
			defer zr.Close()
			reader = zr
		} else {
			fr := flate.NewReader(bytes.NewReader(data))
			defer fr.Close()
			reader = fr
		}
	case "br":
		reader = brotli.NewReader(bytes.NewReader(data))
	default:
		return nil, false, nil
	}
	var out bytes.Buffer
	n, err := io.Copy(&out, io.LimitReader(reader, limit+1))
	if err != nil {
		return nil, true, err
	}
	if n > limit {
		return nil, true, errMitmRewriteBodyTooLarge
	}
	return out.Bytes(), true, nil
}

// The outcome of a body rewrite.
type mitmBodyResult struct {
	// The body to send on: the rewritten one, or the original in full.
	body io.Reader
	// Its length when changed (identity coding, framed by Content-Length).
	length  int64
	changed bool
	// When changed: the body as it came, still in its content coding.
	original []byte
}

// Rewrites a body with rules (from bodyRules). Reads it only up to the
// limit; a body that is larger, not text, or that cannot be decoded passes
// on unchanged and complete, the rest still streaming from body. length is
// the declared length, -1 when unknown. A read error from body is left for
// the caller's copy to meet, exactly as without rewriting.
func (x *mitmRewriteExchange) rewriteBody(rules []*mitmRewriteRule, header http.Header, body io.Reader, length int64, response bool) mitmBodyResult {
	phase := "request"
	if response {
		phase = "response"
	}
	unchanged := mitmBodyResult{body: body}
	if len(rules) == 0 {
		return unchanged
	}
	if !mitmTextContent(header.Get("Content-Type")) {
		skip := mitmSkipNotText
		if strings.HasPrefix(strings.ToLower(strings.TrimSpace(header.Get("Content-Type"))), "text/event-stream") {
			skip = mitmSkipStreaming
		}
		x.skipAll(rules, phase, skip)
		return unchanged
	}
	limit := x.engine.bodyLimit
	if length > limit {
		x.skipAll(rules, phase, mitmSkipOversize)
		return unchanged
	}
	var raw []byte
	if body != nil && body != http.NoBody {
		var err error
		raw, err = io.ReadAll(io.LimitReader(body, limit+1))
		if err != nil {
			x.skipAll(rules, phase, mitmSkipBodyReadFail)
			return mitmBodyResult{body: io.MultiReader(bytes.NewReader(raw), body)}
		}
	}
	original := mitmBodyResult{body: bytes.NewReader(raw)}
	if int64(len(raw)) > limit {
		x.skipAll(rules, phase, mitmSkipOversize)
		return mitmBodyResult{body: io.MultiReader(bytes.NewReader(raw), body)}
	}
	text, supported, err := mitmDecodeContent(raw, header.Get("Content-Encoding"), limit)
	switch {
	case !supported:
		x.skipAll(rules, phase, mitmSkipEncoding)
		return original
	case errors.Is(err, errMitmRewriteBodyTooLarge):
		x.skipAll(rules, phase, mitmSkipOversize)
		return original
	case err != nil:
		x.skipAll(rules, phase, mitmSkipDecode)
		return original
	case !utf8.Valid(text):
		x.skipAll(rules, phase, mitmSkipNotUTF8)
		return original
	}
	current := string(text)
	for _, rule := range rules {
		start := time.Now()
		next, failed := current, false
		for _, pair := range rule.pairs {
			result, _, err := pair.re.replaceAll(next, pair.replacement)
			if err != nil {
				failed = true
				break
			}
			next = result
		}
		if failed {
			x.record(rule, phase, "body", mitmSkipTimeout)
			continue
		}
		current = next
		x.recordApplied(rule, phase, "body", start)
	}
	if current == string(text) {
		return original
	}
	return mitmBodyResult{body: strings.NewReader(current), length: int64(len(current)), changed: true, original: raw}
}

// Fixes up the headers of a body rewriteBody changed: it is sent decoded,
// framed by its new length.
func mitmRewrittenBodyHeader(header http.Header, length int64) {
	header.Del("Content-Encoding")
	header.Del("Transfer-Encoding")
	header.Set("Content-Length", strconv.FormatInt(length, 10))
}

// The local answer as an HTTP/1.1 response to req.
func (local *mitmLocalResponse) http1() *http.Response {
	header := local.header.Clone()
	if header == nil {
		header = http.Header{}
	}
	body := io.NopCloser(bytes.NewReader(local.body))
	if len(local.body) == 0 {
		body = http.NoBody
	}
	return &http.Response{
		StatusCode:    local.status,
		Status:        mitmStatusText(local.status),
		Proto:         "HTTP/1.1",
		ProtoMajor:    1,
		ProtoMinor:    1,
		Header:        header,
		Body:          body,
		ContentLength: int64(len(local.body)),
	}
}

func mitmStatusText(status int) string {
	text := http.StatusText(status)
	if text == "" {
		text = "Status"
	}
	return strconv.Itoa(status) + " " + text
}

// Hosts as the rewrite engine keys them: lower case, no port.
func mitmRewriteHost(host string) string {
	if h, _, err := net.SplitHostPort(host); err == nil {
		host = h
	}
	return normalizeMitmHost(host)
}

// What the request list was told of one connection's rewrites, so that it
// hears once of the first applied rule and once of the first failed one.
type mitmRewriteReport struct {
	mu              sync.Mutex
	applied, failed bool
}

func (r *mitmRewriteReport) note(connection string, rw *mitmRewriteExchange) {
	if r == nil || connection == "" || !rw.rewritten() {
		return
	}
	var applied, failed *MitmRewriteHit
	for i := range rw.hits {
		if rw.hits[i].Skipped == "" {
			applied = &rw.hits[i]
		} else {
			failed = &rw.hits[i]
		}
	}
	r.mu.Lock()
	var hit *MitmRewriteHit
	switch {
	case failed != nil && !r.failed:
		hit, r.failed = failed, true
		r.applied = r.applied || applied != nil
	case applied != nil && !r.applied:
		hit, r.applied = applied, true
	}
	event := MitmConnectionRewrite{Applied: r.applied, Failed: r.failed}
	r.mu.Unlock()
	if hit == nil {
		return
	}
	copied := *hit
	event.Hit = &copied
	sendMitmConnection(&MitmConnection{Id: connection, Rewrite: &event})
}
