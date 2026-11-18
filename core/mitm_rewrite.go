package core

import (
	"encoding/base64"
	"errors"
	"fmt"
	"io"
	"mime"
	"net/http"
	"net/textproto"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/metacubex/mihomo/constant"
)

// Phase 2b: Surge-compatible rewriting of decrypted traffic.
//
// Sections ([URL Rewrite], [Header Rewrite], [Body Rewrite], [Map Local])
// travel from the app as one line per rule, each with the app's ID for it,
// inside the MITM setup (mitm.update), never in the profile. A line that
// does not parse is reported (mitm.validate, mitm.rewriteStatus) and left
// out; the others still run. Nothing a rule does at run time can fail a
// connection: a rule that cannot apply (oversized or undecodable body, a
// regex that times out, a header that would change the framing) is skipped
// for that message, which then passes unchanged, and the skip is recorded.
//
// Order, per request (Surge's: https://manual.nssurge.com/http/overview.md):
//  1. Header Rewrite, http-request rules, in order, on the original URL.
//  2. URL Rewrite: the first rule whose pattern matches decides. reject*,
//     302 and 307 answer locally; header rewrites the URL in place (same
//     host only) and evaluation continues with the new URL.
//  3. Map Local: the first matching rule answers locally.
//  4. Body Rewrite, http-request rules, all matching, in order.
//  5. The request goes upstream. On the response: Header Rewrite
//     http-response rules, then Body Rewrite http-response rules, matched
//     against the request's final URL.
//
// Only URL Rewrite's reject/302/307 also run on plain HTTP (port 80); all
// of it runs only while the MITM switch is on.

const (
	mitmSectionURL    = "url-rewrite"
	mitmSectionHeader = "header-rewrite"
	mitmSectionBody   = "body-rewrite"
	mitmSectionMap    = "map-local"
)

var mitmRewriteSections = []string{mitmSectionURL, mitmSectionHeader, mitmSectionBody, mitmSectionMap}

// The section headers a pasted Surge profile or module uses.
var mitmSectionTitles = map[string]string{
	"url rewrite":    mitmSectionURL,
	"header rewrite": mitmSectionHeader,
	"body rewrite":   mitmSectionBody,
	"map local":      mitmSectionMap,
}

// One rule as the app sends it.
type MitmRewriteRule struct {
	ID      string `json:"id"`
	Section string `json:"section"`
	Line    string `json:"line"`
}

// Why a rule line was left out.
type MitmRewriteIssue struct {
	Rule    string `json:"rule,omitempty"`
	Section string `json:"section,omitempty"`
	// 1-based, within pasted text; 0 for rules sent one by one.
	Line    int    `json:"line,omitempty"`
	Message string `json:"message"`
}

// What a rule did to one message, for the request record.
// JSON names follow the app's MitmAction: kind is the section, detail the
// action the rule took.
type MitmRewriteHit struct {
	Rule    string `json:"rule"`
	Section string `json:"kind"`
	Phase   string `json:"phase"`
	Action  string `json:"detail"`
	// Set when the rule matched but could not apply; the message passed
	// on unchanged by it.
	Skipped string `json:"skipped,omitempty"`
}

// Why a matching rule left a message as it was.
const (
	mitmSkipOversize   = "oversize"
	mitmSkipNotText    = "notText"
	mitmSkipNotUTF8    = "notUTF8"
	mitmSkipDecode     = "decodeFailed"
	mitmSkipEncoding   = "unsupportedEncoding"
	mitmSkipTimeout    = "regexTimeout"
	mitmSkipCrossHost  = "crossHost"
	mitmSkipInvalidURL = "invalidURL"
	mitmSkipFraming    = "framing"
	mitmSkipStreaming  = "streaming"
	// The site answered while the request was still being uploaded.
	mitmSkipUploading    = "uploading"
	mitmSkipBodyReadFail = "bodyReadFailed"
)

type mitmURLAction string

const (
	mitmURLHeader       mitmURLAction = "header"
	mitmURL302          mitmURLAction = "302"
	mitmURL307          mitmURLAction = "307"
	mitmURLReject       mitmURLAction = "reject"
	mitmURLReject200    mitmURLAction = "reject-200"
	mitmURLRejectImg    mitmURLAction = "reject-img"
	mitmURLRejectDict   mitmURLAction = "reject-dict"
	mitmURLRejectArray  mitmURLAction = "reject-array"
	mitmURLRejectDrop   mitmURLAction = "reject-drop"
	mitmURLRejectNoDrop mitmURLAction = "reject-no-drop"
)

var mitmURLActions = map[string]mitmURLAction{
	"header":         mitmURLHeader,
	"302":            mitmURL302,
	"307":            mitmURL307,
	"reject":         mitmURLReject,
	"reject-200":     mitmURLReject200,
	"reject-img":     mitmURLRejectImg,
	"reject-tinygif": mitmURLRejectImg,
	"reject-dict":    mitmURLRejectDict,
	"reject-array":   mitmURLRejectArray,
	"reject-drop":    mitmURLRejectDrop,
	"reject-no-drop": mitmURLRejectNoDrop,
}

// A transparent 1×1 GIF, as REJECT-TINYGIF returns.
var mitmTinyGIF = []byte{
	0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00, 0x01, 0x00, 0x80, 0x00,
	0x00, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0x21, 0xf9, 0x04, 0x01, 0x00,
	0x00, 0x00, 0x00, 0x2c, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00,
	0x00, 0x02, 0x02, 0x44, 0x01, 0x00, 0x3b,
}

type mitmHeaderOp string

const (
	mitmHeaderAdd          mitmHeaderOp = "header-add"
	mitmHeaderDel          mitmHeaderOp = "header-del"
	mitmHeaderReplace      mitmHeaderOp = "header-replace"
	mitmHeaderReplaceRegex mitmHeaderOp = "header-replace-regex"
)

type mitmBodyPair struct {
	re          *mitmRegex
	replacement string
}

// A response built without the site: reject*, redirects, Map Local.
type mitmLocalResponse struct {
	status int
	header http.Header
	body   []byte
	// For data-type=file: the resources directory's file the body is read
	// from when the rules are installed.
	file string
}

type mitmRewriteRule struct {
	id      string
	section string
	line    string
	order   int
	url     *mitmRegex
	host    string
	// Response-side Header and Body Rewrite.
	response bool

	urlAction   mitmURLAction
	replacement string

	headerOp    mitmHeaderOp
	field       string
	value       string
	valueRegex  *mitmRegex
	valueResult string

	pairs []mitmBodyPair

	local *mitmLocalResponse

	stats *mitmRewriteStats
}

type mitmRewriteStats struct {
	hits, skips atomic.Int64
	mu          sync.Mutex
	lastSkip    string
	lastSkipAt  time.Time
}

func (s *mitmRewriteStats) record(skip string) {
	if skip == "" {
		s.hits.Add(1)
		return
	}
	s.skips.Add(1)
	s.mu.Lock()
	s.lastSkip, s.lastSkipAt = skip, time.Now()
	s.mu.Unlock()
}

// Rules of one kind, indexed by the host their pattern names.
type mitmRuleIndex struct {
	byHost  map[string][]*mitmRewriteRule
	generic []*mitmRewriteRule
}

func (x *mitmRuleIndex) add(rule *mitmRewriteRule) {
	if rule.host == "" {
		x.generic = append(x.generic, rule)
		return
	}
	if x.byHost == nil {
		x.byHost = map[string][]*mitmRewriteRule{}
	}
	x.byHost[rule.host] = append(x.byHost[rule.host], rule)
}

func (x *mitmRuleIndex) empty() bool {
	return x == nil || len(x.generic) == 0 && len(x.byHost) == 0
}

func (x *mitmRuleIndex) mayMatch(host string) bool {
	return len(x.generic) > 0 || len(x.byHost[host]) > 0
}

// The candidates for host in rule order; nil when there are none, so a
// request on a host no rule names costs one map lookup.
func (x *mitmRuleIndex) candidates(host string) []*mitmRewriteRule {
	named := x.byHost[host]
	switch {
	case len(named) == 0:
		return x.generic
	case len(x.generic) == 0:
		return named
	}
	merged := make([]*mitmRewriteRule, 0, len(named)+len(x.generic))
	i, j := 0, 0
	for i < len(named) || j < len(x.generic) {
		if j >= len(x.generic) || i < len(named) && named[i].order < x.generic[j].order {
			merged = append(merged, named[i])
			i++
		} else {
			merged = append(merged, x.generic[j])
			j++
		}
	}
	return merged
}

// Compiled once per settings change; immutable afterwards but for counters.
type mitmRewriteEngine struct {
	rules          []*mitmRewriteRule
	issues         []MitmRewriteIssue
	url            mitmRuleIndex
	plain          mitmRuleIndex
	requestHeader  mitmRuleIndex
	responseHeader mitmRuleIndex
	requestBody    mitmRuleIndex
	responseBody   mitmRuleIndex
	mapLocal       mitmRuleIndex
	bodyLimit      int64
}

// The default most a rewritten body may be; larger ones pass unchanged.
const mitmDefaultRewriteBodyLimit = 1 << 20

var mitmRewrite atomic.Pointer[mitmRewriteEngine]

func (e *mitmRewriteEngine) empty() bool {
	return e == nil || len(e.rules) == 0
}

// Installs the rules of a setup; nil (MITM off) removes them. Counters of a
// rule whose ID and line are unchanged carry over.
func installMitmRewrite(setup *MitmSetup) {
	if setup == nil || !setup.Enable {
		mitmRewrite.Store(nil)
		return
	}
	limit := int64(mitmDefaultRewriteBodyLimit)
	if v := setup.Limits["rewrite-body-size"]; v > 0 {
		limit = v
	}
	engine := compileMitmRewrite(setup.Rewrite, limit, mitmRewrite.Load())
	if engine.empty() && len(engine.issues) == 0 {
		engine = nil
	}
	mitmRewrite.Store(engine)
}

func compileMitmRewrite(rules []MitmRewriteRule, bodyLimit int64, previous *mitmRewriteEngine) *mitmRewriteEngine {
	kept := map[string]*mitmRewriteRule{}
	if previous != nil {
		for _, rule := range previous.rules {
			kept[rule.id+"\x00"+rule.section] = rule
		}
	}
	engine := &mitmRewriteEngine{bodyLimit: bodyLimit}
	for i, spec := range rules {
		rule, err := parseMitmRewriteLine(spec.Section, spec.Line)
		if err != nil {
			engine.issues = append(engine.issues, MitmRewriteIssue{Rule: spec.ID, Section: spec.Section, Message: err.Error()})
			continue
		}
		if rule == nil {
			continue
		}
		if rule.local != nil && rule.local.file != "" {
			if err := loadMitmLocalFile(rule.local); err != nil {
				engine.issues = append(engine.issues, MitmRewriteIssue{Rule: spec.ID, Section: spec.Section, Message: err.Error()})
				continue
			}
		}
		rule.id, rule.order, rule.line = spec.ID, i, spec.Line
		if old := kept[spec.ID+"\x00"+spec.Section]; old != nil && old.line == spec.Line {
			rule.stats = old.stats
		} else {
			rule.stats = &mitmRewriteStats{}
		}
		engine.rules = append(engine.rules, rule)
		switch rule.section {
		case mitmSectionURL:
			engine.url.add(rule)
			if rule.urlAction != mitmURLHeader {
				engine.plain.add(rule)
			}
		case mitmSectionHeader:
			if rule.response {
				engine.responseHeader.add(rule)
			} else {
				engine.requestHeader.add(rule)
			}
		case mitmSectionBody:
			if rule.response {
				engine.responseBody.add(rule)
			} else {
				engine.requestBody.add(rule)
			}
		case mitmSectionMap:
			engine.mapLocal.add(rule)
		}
	}
	return engine
}

// The most a Map Local file may hold (the app's maxMitmResourceSize).
const mitmLocalFileLimit = 16 << 20

// Where the app keeps Map Local files; a variable only for tests.
var mitmResourcesDir = func() string {
	return filepath.Join(constant.Path.HomeDir(), "mitm", "resources")
}

func loadMitmLocalFile(local *mitmLocalResponse) error {
	f, err := os.Open(filepath.Join(mitmResourcesDir(), local.file))
	if err != nil {
		return fmt.Errorf("map-local file %s cannot be read", local.file)
	}
	defer f.Close()
	body, err := io.ReadAll(io.LimitReader(f, mitmLocalFileLimit+1))
	if err != nil {
		return fmt.Errorf("map-local file %s cannot be read", local.file)
	}
	if len(body) > mitmLocalFileLimit {
		return fmt.Errorf("map-local file %s is over 16 MiB", local.file)
	}
	local.body = body
	return nil
}

// ---- Parsing ----

var errMitmRewriteComment = errors.New("comment")

// Splits a line into fields on spaces. A field that starts with a quote and
// whose closing quote ends it is one field; whether the quotes are kept is
// the caller's choice (see mitmUnquote). Any other quote is literal: real
// rules match JSON such as "storefrontId"\x20:\x20"\d{6}".
func mitmFields(line string) []string {
	var fields []string
	i := 0
	for i < len(line) {
		for i < len(line) && (line[i] == ' ' || line[i] == '\t') {
			i++
		}
		if i >= len(line) {
			break
		}
		if q := line[i]; q == '"' || q == '\'' {
			if end := strings.IndexByte(line[i+1:], q); end >= 0 {
				close := i + 1 + end
				if close+1 == len(line) || line[close+1] == ' ' || line[close+1] == '\t' {
					fields = append(fields, line[i:close+1])
					i = close + 1
					continue
				}
			}
		}
		start := i
		for i < len(line) && line[i] != ' ' && line[i] != '\t' {
			i++
		}
		fields = append(fields, line[start:i])
	}
	return fields
}

// Removes a field's enclosing quotes. Patterns keep them unless the quoted
// text has a space (the only reason to quote a pattern); values lose them.
func mitmUnquote(field string, pattern bool) string {
	if len(field) < 2 || field[0] != field[len(field)-1] || field[0] != '"' && field[0] != '\'' {
		return field
	}
	inner := field[1 : len(field)-1]
	if pattern && !strings.ContainsAny(inner, " \t") {
		return field
	}
	return inner
}

func mitmIsComment(line string) bool {
	return line == "" || strings.HasPrefix(line, "#") || strings.HasPrefix(line, ";") || strings.HasPrefix(line, "//")
}

// Parses one rule line of section. A blank or comment line is (nil, nil).
func parseMitmRewriteLine(section, line string) (*mitmRewriteRule, error) {
	line = strings.TrimSpace(line)
	if mitmIsComment(line) {
		return nil, nil
	}
	var (
		rule *mitmRewriteRule
		err  error
	)
	switch section {
	case mitmSectionURL:
		rule, err = parseMitmURLRewrite(line)
	case mitmSectionHeader:
		rule, err = parseMitmHeaderRewrite(line)
	case mitmSectionBody:
		rule, err = parseMitmBodyRewrite(line)
	case mitmSectionMap:
		rule, err = parseMitmMapLocal(line)
	default:
		return nil, fmt.Errorf("unknown section %q", section)
	}
	if err != nil {
		return nil, err
	}
	rule.section = section
	rule.host = mitmPatternHost(rule.url.source)
	return rule, nil
}

func compileMitmURLPattern(field string) (*mitmRegex, error) {
	re, err := compileMitmRegex(mitmUnquote(field, true), false)
	if err != nil {
		return nil, fmt.Errorf("invalid URL regex: %v", err)
	}
	return re, nil
}

// <regex> <replacement> [type]; type defaults to header. Also accepted, as
// Loon and Quantumult X write them and modules carry them: "<regex> reject"
// with the placeholder left out, and "<regex> <type> <replacement>".
func parseMitmURLRewrite(line string) (*mitmRewriteRule, error) {
	fields := mitmFields(line)
	var pattern, replacement, kind string
	switch len(fields) {
	case 2:
		pattern = fields[0]
		if _, ok := mitmURLActions[strings.ToLower(fields[1])]; ok && strings.HasPrefix(strings.ToLower(fields[1]), "reject") {
			kind = fields[1]
		} else {
			replacement, kind = fields[1], "header"
		}
	case 3:
		pattern, replacement, kind = fields[0], fields[1], fields[2]
		if _, ok := mitmURLActions[strings.ToLower(kind)]; !ok {
			if _, swapped := mitmURLActions[strings.ToLower(replacement)]; swapped {
				replacement, kind = kind, replacement
			}
		}
	default:
		return nil, fmt.Errorf("expected <regex> <replacement> <type>, got %d fields", len(fields))
	}
	action, ok := mitmURLActions[strings.ToLower(kind)]
	if !ok {
		return nil, fmt.Errorf("unknown URL rewrite type %q", kind)
	}
	re, err := compileMitmURLPattern(pattern)
	if err != nil {
		return nil, err
	}
	replacement = mitmUnquote(replacement, false)
	switch action {
	case mitmURLHeader, mitmURL302, mitmURL307:
		if replacement == "" || replacement == "-" || replacement == "_" {
			return nil, errors.New("a redirect or header rewrite needs a replacement URL")
		}
	}
	return &mitmRewriteRule{url: re, urlAction: action, replacement: replacement}, nil
}

// [http-request|http-response] <regex> <action> <field> [value [template]].
func parseMitmHeaderRewrite(line string) (*mitmRewriteRule, error) {
	fields := mitmFields(line)
	rule := &mitmRewriteRule{}
	if len(fields) > 0 {
		switch strings.ToLower(fields[0]) {
		case "http-request":
			fields = fields[1:]
		case "http-response":
			rule.response = true
			fields = fields[1:]
		}
	}
	if len(fields) < 3 {
		return nil, errors.New("expected [http-request|http-response] <regex> <action> <header> [value]")
	}
	re, err := compileMitmURLPattern(fields[0])
	if err != nil {
		return nil, err
	}
	rule.url = re
	rule.headerOp = mitmHeaderOp(strings.ToLower(fields[1]))
	rule.field = textproto.CanonicalMIMEHeaderKey(mitmUnquote(fields[2], false))
	if rule.field == "" || strings.ContainsAny(rule.field, " :\r\n") {
		return nil, fmt.Errorf("invalid header name %q", fields[2])
	}
	if mitmFramingHeader(rule.field) {
		return nil, fmt.Errorf("%s cannot be rewritten: it frames the message", rule.field)
	}
	rest := fields[3:]
	join := func(parts []string) string {
		values := make([]string, len(parts))
		for i, part := range parts {
			values[i] = mitmUnquote(part, false)
		}
		return strings.Join(values, " ")
	}
	switch rule.headerOp {
	case mitmHeaderDel:
	case mitmHeaderAdd, mitmHeaderReplace:
		if len(rest) == 0 {
			return nil, fmt.Errorf("%s needs a value", rule.headerOp)
		}
		rule.value = join(rest)
	case mitmHeaderReplaceRegex:
		if len(rest) < 2 {
			return nil, errors.New("header-replace-regex needs <regex> <replacement>")
		}
		if rule.valueRegex, err = compileMitmRegex(mitmUnquote(rest[0], true), false); err != nil {
			return nil, fmt.Errorf("invalid header regex: %v", err)
		}
		rule.valueResult = join(rest[1:])
	default:
		return nil, fmt.Errorf("unknown header action %q", fields[1])
	}
	if strings.ContainsAny(rule.value+rule.valueResult, "\r\n") {
		return nil, errors.New("a header value cannot contain a line break")
	}
	return rule, nil
}

// Content-Length and Transfer-Encoding frame the message; Host names the
// site the connection was decrypted for. Surge refuses changes to the
// former too.
func mitmFramingHeader(field string) bool {
	switch field {
	case "Content-Length", "Transfer-Encoding", "Host", "Connection", "Upgrade", "Trailer", "Te":
		return true
	}
	return strings.HasPrefix(field, ":")
}

// http-request|http-response <regex> <regex1> <replacement1> [...].
func parseMitmBodyRewrite(line string) (*mitmRewriteRule, error) {
	fields := mitmFields(line)
	if len(fields) == 0 {
		return nil, errors.New("empty rule")
	}
	rule := &mitmRewriteRule{}
	switch strings.ToLower(fields[0]) {
	case "http-request":
	case "http-response":
		rule.response = true
	case "http-request-jq", "http-response-jq":
		return nil, errors.New("jq body rewrite is not supported yet")
	default:
		return nil, errors.New("a body rewrite starts with http-request or http-response")
	}
	fields = fields[1:]
	if len(fields) < 3 || len(fields)%2 != 1 {
		return nil, errors.New("expected <url-regex> followed by pairs of <regex> <replacement>")
	}
	re, err := compileMitmURLPattern(fields[0])
	if err != nil {
		return nil, err
	}
	rule.url = re
	for i := 1; i < len(fields); i += 2 {
		pair, err := compileMitmRegex(mitmUnquote(fields[i], true), true)
		if err != nil {
			return nil, fmt.Errorf("invalid body regex %q: %v", fields[i], err)
		}
		rule.pairs = append(rule.pairs, mitmBodyPair{re: pair, replacement: mitmUnquote(fields[i+1], true)})
	}
	return rule, nil
}

// Splits Map Local's key=value parameters; a value may be "quoted" and then
// runs to the quote that ends a field.
func mitmParams(text string) (map[string]string, error) {
	params := map[string]string{}
	i := 0
	for i < len(text) {
		for i < len(text) && (text[i] == ' ' || text[i] == '\t') {
			i++
		}
		if i >= len(text) {
			break
		}
		eq := strings.IndexByte(text[i:], '=')
		if eq <= 0 {
			end := strings.IndexAny(text[i:], " \t")
			if end < 0 {
				end = len(text) - i
			}
			return nil, fmt.Errorf("expected key=value, got %q", text[i:i+end])
		}
		key := strings.ToLower(strings.TrimSpace(text[i : i+eq]))
		i += eq + 1
		var value string
		if i < len(text) && text[i] == '"' {
			end := -1
			for j := i + 1; j < len(text); j++ {
				if text[j] == '"' && (j+1 == len(text) || text[j+1] == ' ' || text[j+1] == '\t') {
					end = j
					break
				}
			}
			if end < 0 {
				return nil, fmt.Errorf("unterminated quote in %s", key)
			}
			value = text[i+1 : end]
			i = end + 1
		} else {
			end := strings.IndexAny(text[i:], " \t")
			if end < 0 {
				end = len(text) - i
			}
			value = text[i : i+end]
			i += end
		}
		params[key] = value
	}
	return params, nil
}

// <regex> [data-type=text|tiny-gif|base64|file] [data="..."]
// [status-code=200..999] [header="a:b|c:d"].
func parseMitmMapLocal(line string) (*mitmRewriteRule, error) {
	pattern, rest, _ := strings.Cut(line, " ")
	if fields := mitmFields(line); len(fields) > 0 && strings.HasPrefix(fields[0], `"`) {
		pattern = fields[0]
		rest = strings.TrimPrefix(strings.TrimSpace(line), fields[0])
	}
	re, err := compileMitmURLPattern(pattern)
	if err != nil {
		return nil, err
	}
	params, err := mitmParams(rest)
	if err != nil {
		return nil, err
	}
	local := &mitmLocalResponse{status: http.StatusOK, header: http.Header{}}
	dataType := strings.ToLower(params["data-type"])
	data, hasData := params["data"]
	if dataType == "" {
		dataType = "file"
	}
	contentType := ""
	switch dataType {
	case "text":
		local.body = []byte(data)
		contentType = "text/plain; charset=utf-8"
	case "tiny-gif":
		local.body = mitmTinyGIF
		contentType = "image/gif"
	case "base64":
		if local.body, err = base64.StdEncoding.DecodeString(strings.TrimSpace(data)); err != nil {
			return nil, fmt.Errorf("data is not valid base64: %v", err)
		}
		contentType = "application/octet-stream"
	case "file":
		// The Core never fetches a URL for a rule, and reads files only from
		// the app's resources directory (mitm/resources), by the bare name
		// the app saved a download or attachment under.
		if !hasData || data == "" {
			return nil, errors.New("data-type=file needs data")
		}
		if strings.HasPrefix(data, "http://") || strings.HasPrefix(data, "https://") {
			return nil, errors.New("data from a URL must be downloaded by the app first")
		}
		if strings.ContainsAny(data, `/\`) || data == "." || data == ".." || strings.HasPrefix(data, ".") {
			return nil, fmt.Errorf("data must name a file in the resources directory, got %q", data)
		}
		local.file = data
		contentType = mime.TypeByExtension(filepath.Ext(data))
		if contentType == "" {
			contentType = "application/octet-stream"
		}
	default:
		return nil, fmt.Errorf("unknown data-type %q", dataType)
	}
	if code, present := params["status-code"]; present {
		status, err := strconv.Atoi(code)
		if err != nil || status < 200 || status > 999 {
			return nil, fmt.Errorf("status-code must be 200-999, got %q", code)
		}
		local.status = status
	}
	if header, present := params["header"]; present && header != "" {
		if err := parseMitmLocalHeader(local.header, header); err != nil {
			return nil, err
		}
	}
	if local.header.Get("Content-Type") == "" {
		local.header.Set("Content-Type", contentType)
	}
	for key := range params {
		switch key {
		case "data-type", "data", "status-code", "header":
		default:
			return nil, fmt.Errorf("unknown parameter %q", key)
		}
	}
	return &mitmRewriteRule{url: re, local: local}, nil
}

// "a:b|foo:bar", or base64 of newline-separated header lines when it has
// no colon.
func parseMitmLocalHeader(header http.Header, value string) error {
	var lines []string
	if !strings.Contains(value, ":") {
		decoded, err := base64.StdEncoding.DecodeString(value)
		if err != nil {
			return fmt.Errorf("header is neither a:b|c:d nor base64: %v", err)
		}
		lines = strings.Split(strings.ReplaceAll(string(decoded), "\r\n", "\n"), "\n")
	} else {
		lines = strings.Split(value, "|")
	}
	for _, line := range lines {
		if strings.TrimSpace(line) == "" {
			continue
		}
		name, val, ok := strings.Cut(line, ":")
		name = textproto.CanonicalMIMEHeaderKey(strings.TrimSpace(name))
		if !ok || name == "" || strings.ContainsAny(name, " \r\n") || strings.ContainsAny(val, "\r\n") {
			return fmt.Errorf("invalid header %q", line)
		}
		if mitmFramingHeader(name) {
			continue
		}
		header.Add(name, strings.TrimSpace(val))
	}
	return nil
}

// One rule line of pasted text.
type MitmRewriteLine struct {
	Section string `json:"section"`
	Line    string `json:"line"`
	// 1-based.
	Number int `json:"number"`
}

type MitmRewriteParse struct {
	Rules  []MitmRewriteLine  `json:"rules"`
	Issues []MitmRewriteIssue `json:"issues"`
}

// Parses Surge sections pasted as they are: the four rewrite sections are
// taken, every other section and each line that does not parse is reported
// with its line number, and nothing stops the rest.
func parseMitmRewriteText(text string) MitmRewriteParse {
	result := MitmRewriteParse{Rules: []MitmRewriteLine{}, Issues: []MitmRewriteIssue{}}
	section, skipping := "", false
	for i, raw := range strings.Split(strings.ReplaceAll(text, "\r\n", "\n"), "\n") {
		number := i + 1
		line := strings.TrimSpace(raw)
		if strings.HasPrefix(line, "#!") || mitmIsComment(line) {
			continue
		}
		if strings.HasPrefix(line, "[") && strings.HasSuffix(line, "]") {
			title := strings.ToLower(strings.TrimSpace(line[1 : len(line)-1]))
			if known, ok := mitmSectionTitles[title]; ok {
				section, skipping = known, false
			} else {
				section, skipping = "", true
				result.Issues = append(result.Issues, MitmRewriteIssue{Line: number, Message: fmt.Sprintf("section %s is not a rewrite section; its lines are skipped", line)})
			}
			continue
		}
		if skipping {
			continue
		}
		if section == "" {
			result.Issues = append(result.Issues, MitmRewriteIssue{Line: number, Message: "line outside [URL Rewrite], [Header Rewrite], [Body Rewrite] or [Map Local]"})
			continue
		}
		if _, err := parseMitmRewriteLine(section, line); err != nil {
			result.Issues = append(result.Issues, MitmRewriteIssue{Section: section, Line: number, Message: err.Error()})
			continue
		}
		result.Rules = append(result.Rules, MitmRewriteLine{Section: section, Line: line, Number: number})
	}
	return result
}

// ---- Status ----

type MitmRewriteRuleStatus struct {
	Rule       string     `json:"rule"`
	Section    string     `json:"section"`
	Hits       int64      `json:"hits"`
	Skips      int64      `json:"skips"`
	LastSkip   string     `json:"last-skip,omitempty"`
	LastSkipAt *time.Time `json:"last-skip-at,omitempty"`
}

type MitmRewriteStatus struct {
	Active    bool                    `json:"active"`
	BodyLimit int64                   `json:"body-limit"`
	Issues    []MitmRewriteIssue      `json:"issues"`
	Rules     []MitmRewriteRuleStatus `json:"rules"`
}

func handleMitmRewriteStatus() MitmRewriteStatus {
	engine := mitmRewrite.Load()
	status := MitmRewriteStatus{Issues: []MitmRewriteIssue{}, Rules: []MitmRewriteRuleStatus{}}
	if engine == nil {
		return status
	}
	status.Active = !engine.empty()
	status.BodyLimit = engine.bodyLimit
	status.Issues = append(status.Issues, engine.issues...)
	for _, rule := range engine.rules {
		entry := MitmRewriteRuleStatus{Rule: rule.id, Section: rule.section, Hits: rule.stats.hits.Load(), Skips: rule.stats.skips.Load()}
		rule.stats.mu.Lock()
		if rule.stats.lastSkip != "" {
			at := rule.stats.lastSkipAt
			entry.LastSkip, entry.LastSkipAt = rule.stats.lastSkip, &at
		}
		rule.stats.mu.Unlock()
		status.Rules = append(status.Rules, entry)
	}
	return status
}

type MitmRewriteParseParams struct {
	Text string `json:"text"`
}

func handleMitmRewriteParse(params MitmRewriteParseParams) MitmRewriteParse {
	return parseMitmRewriteText(params.Text)
}
