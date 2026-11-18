package core

import (
	"bytes"
	"compress/flate"
	"compress/gzip"
	"compress/zlib"
	"encoding/base64"
	"errors"
	"io"
	"net/http"
	"reflect"
	"strings"
	"sync"
	"time"
)

// What the decrypted requests carried, kept in this process's memory only:
// never written to disk, a log or a spilled reply, and dropped when capture
// goes off, decryption stops or changes root, the app leaves or the Core
// shuts down. Entries and bytes are bounded; each body keeps only its start.
type mitmCaptureStore struct {
	mu      sync.Mutex
	order   []*mitmCaptureEntry
	byID    map[uint64]*mitmCaptureEntry
	bytes   int64
	nextID  uint64
	since   time.Time
	open    map[string]int
	limits  mitmCaptureLimits
	enabled bool
}

type mitmCaptureLimits struct {
	entries int
	bytes   int64
	body    int64
}

// The desktop defaults the app sends anyway; the Core applies them when the
// app sends none.
var mitmDefaultCaptureLimits = mitmCaptureLimits{entries: 2000, bytes: 64 << 20, body: 4 << 20}

type mitmCaptureBody struct {
	data      []byte
	size      int64
	truncated bool
}

type mitmCaptureEntry struct {
	id         uint64
	connection string
	start      time.Time
	method     string
	url        string
	proto      string
	reqHeader  http.Header
	respHeader http.Header
	status     int
	ttfb       time.Duration
	duration   time.Duration
	pending    bool
	err        string
	req, resp  mitmCaptureBody
	cost       int64
	gone       bool
	// Set when a rewrite rule matched: the URL the client asked for and
	// what each rule did.
	originalURL string
	rewrites    []MitmRewriteHit
	// What a side was before rewrite rules changed it, set only for a side
	// they changed: its headers, and its body when that changed too.
	before [2]mitmCaptureOriginal
}

type mitmCaptureOriginal struct {
	header http.Header
	body   *mitmCaptureBody
	// The content coding body is in.
	encoding string
}

// Why an exchange did not complete, as the request list names it.
const (
	mitmExchangeNoResponse     = "noResponse"
	mitmExchangeResponseFailed = "responseFailed"
	mitmExchangeStopped        = "stopped"
	// URL Rewrite's reject-drop closed the connection without an answer.
	mitmExchangeDropped = "dropped"
)

var mitmCaptures = &mitmCaptureStore{
	byID:   map[uint64]*mitmCaptureEntry{},
	open:   map[string]int{},
	limits: mitmDefaultCaptureLimits,
}

func mitmCaptureLimitsOf(runtime *mitmRuntime) mitmCaptureLimits {
	limits := mitmDefaultCaptureLimits
	if runtime == nil {
		return limits
	}
	if v := runtime.setup.Limits["capture-entries"]; v > 0 {
		limits.entries = int(min(v, 1_000_000))
	}
	if v := runtime.setup.Limits["capture-bytes"]; v > 0 {
		limits.bytes = v
	}
	if v := runtime.setup.Limits["max-body-size"]; v > 0 {
		limits.body = v
	}
	// Both bodies of one record fit well within the total, so a record being
	// written never pushes itself out.
	limits.body = min(limits.body, limits.bytes/4)
	return limits
}

// Follows the app's capture switch; turning it on or off starts afresh.
func (s *mitmCaptureStore) setEnabled(enabled bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.enabled != enabled {
		s.clearLocked()
	}
	s.enabled = enabled
}

// A new runtime keeps the records only while it decrypts with the same root.
func (s *mitmCaptureStore) runtimeReplaced(previous, next *mitmRuntime) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if !next.decrypting() || previous == nil || previous.setup.CAFingerprint != next.setup.CAFingerprint {
		s.clearLocked()
	}
	s.limits = mitmCaptureLimitsOf(next)
	s.evictLocked()
}

func (s *mitmCaptureStore) clear() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.clearLocked()
}

func (s *mitmCaptureStore) clearLocked() {
	for _, entry := range s.order {
		entry.gone = true
		entry.req.data, entry.resp.data, entry.before = nil, nil, [2]mitmCaptureOriginal{}
	}
	s.order = nil
	s.byID = map[uint64]*mitmCaptureEntry{}
	s.bytes = 0
	s.since = time.Now()
}

func (s *mitmCaptureStore) openConnection(id string) {
	if id == "" {
		return
	}
	s.mu.Lock()
	s.open[id]++
	s.mu.Unlock()
}

func (s *mitmCaptureStore) closeConnection(id string) {
	if id == "" {
		return
	}
	s.mu.Lock()
	if s.open[id]--; s.open[id] <= 0 {
		delete(s.open, id)
	}
	s.mu.Unlock()
}

func mitmHeaderCost(header http.Header) int64 {
	var n int64
	for name, values := range header {
		for _, value := range values {
			n += int64(len(name) + len(value) + 4)
		}
	}
	return n
}

// Starts a record for a request whose head was just read, or returns nil
// while capture is off.
func (s *mitmCaptureStore) begin(connection, host string, req *http.Request) *mitmCaptureEntry {
	return s.beginScheme(connection, "https", host, req)
}

// begin for a request of scheme (http for plain HTTP on port 80).
func (s *mitmCaptureStore) beginScheme(connection, scheme, host string, req *http.Request) *mitmCaptureEntry {
	if connection == "" {
		return nil
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if !s.enabled {
		return nil
	}
	header := req.Header.Clone()
	header["Host"] = []string{req.Host}
	if len(req.TransferEncoding) > 0 {
		header["Transfer-Encoding"] = append([]string(nil), req.TransferEncoding...)
	}
	s.nextID++
	entry := &mitmCaptureEntry{
		id:         s.nextID,
		connection: connection,
		start:      time.Now(),
		method:     req.Method,
		url:        scheme + "://" + req.Host + req.RequestURI,
		proto:      req.Proto,
		reqHeader:  header,
		pending:    true,
	}
	entry.cost = int64(len(entry.method)+len(entry.url)+len(entry.proto)) + mitmHeaderCost(header)
	s.order = append(s.order, entry)
	s.byID[entry.id] = entry
	s.bytes += entry.cost
	s.evictLocked()
	return entry
}

// After a request script changed the request line or headers.
func (s *mitmCaptureStore) scriptedRequest(entry *mitmCaptureEntry, scheme string, req *http.Request) {
	if entry == nil {
		return
	}
	header := req.Header.Clone()
	header["Host"] = []string{req.Host}
	s.mu.Lock()
	defer s.mu.Unlock()
	if entry.gone {
		return
	}
	cost := mitmHeaderCost(header) - mitmHeaderCost(entry.reqHeader)
	url := scheme + "://" + req.Host + req.RequestURI
	cost += int64(len(url) - len(entry.url))
	entry.reqHeader, entry.url = header, url
	entry.cost += cost
	s.bytes += cost
	s.evictLocked()
}

// Records what the rewrite rules did so far to entry's exchange.
func (s *mitmCaptureStore) noteRewrite(entry *mitmCaptureEntry, rw *mitmRewriteExchange) {
	if entry == nil || !rw.rewritten() {
		return
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if entry.gone {
		return
	}
	var cost int64
	if entry.originalURL == "" && rw.originalURL != entry.url {
		entry.originalURL = rw.originalURL
		cost += int64(len(rw.originalURL))
	}
	for _, hit := range rw.hits[len(entry.rewrites):] {
		cost += int64(len(hit.Rule) + len(hit.Section) + len(hit.Phase) + len(hit.Action) + len(hit.Skipped) + len(hit.Error))
		for _, line := range hit.Logs {
			cost += int64(len(line.Level) + len(line.Text))
		}
		for _, request := range hit.Requests {
			cost += int64(len(request.Method) + len(request.URL) + len(request.Error))
		}
	}
	entry.rewrites = append(entry.rewrites, rw.hits[len(entry.rewrites):]...)
	entry.cost += cost
	s.bytes += cost
	s.evictLocked()
}

func mitmSide(response bool) int {
	if response {
		return 1
	}
	return 0
}

// Keeps before, a side's headers as they came, when rewrite rules made
// them after.
func (s *mitmCaptureStore) originalHeader(entry *mitmCaptureEntry, response bool, before, after http.Header) {
	if entry == nil || before == nil || reflect.DeepEqual(before, after) {
		return
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	original := &entry.before[mitmSide(response)]
	if entry.gone || original.header != nil {
		return
	}
	original.header = before
	cost := mitmHeaderCost(before)
	entry.cost += cost
	s.bytes += cost
	s.evictLocked()
}

func (s *mitmCaptureStore) hasOriginalBody(entry *mitmCaptureEntry, response bool) bool {
	if entry == nil {
		return false
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	return entry.before[mitmSide(response)].body != nil
}

// Keeps a side's body as it came (in coding) when a rule rewrote it.
func (s *mitmCaptureStore) originalBody(entry *mitmCaptureEntry, response bool, data []byte, coding string) {
	if entry == nil {
		return
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if entry.gone {
		return
	}
	original := &entry.before[mitmSide(response)]
	kept := data[:min(int64(len(data)), s.limits.body)]
	original.body = &mitmCaptureBody{data: append([]byte(nil), kept...), size: int64(len(data)), truncated: len(kept) < len(data)}
	original.encoding = coding
	entry.cost += int64(len(kept))
	s.bytes += int64(len(kept))
	s.evictLocked()
}

func (s *mitmCaptureStore) respond(entry *mitmCaptureEntry, resp *http.Response) {
	if entry == nil {
		return
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if entry.gone {
		return
	}
	header := resp.Header.Clone()
	if len(resp.TransferEncoding) > 0 {
		header["Transfer-Encoding"] = append([]string(nil), resp.TransferEncoding...)
	}
	entry.status = resp.StatusCode
	entry.respHeader = header
	entry.ttfb = time.Since(entry.start)
	cost := mitmHeaderCost(header)
	entry.cost += cost
	s.bytes += cost
	s.evictLocked()
}

// Adds the response trailers (gRPC's grpc-status, for one) to the recorded
// response headers once the body has ended.
func (s *mitmCaptureStore) trailers(entry *mitmCaptureEntry, trailer http.Header) {
	if entry == nil || len(trailer) == 0 {
		return
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if entry.gone {
		return
	}
	if entry.respHeader == nil {
		entry.respHeader = http.Header{}
	}
	for name, values := range trailer {
		entry.respHeader[name] = append(entry.respHeader[name], values...)
	}
	cost := mitmHeaderCost(trailer)
	entry.cost += cost
	s.bytes += cost
	s.evictLocked()
}

func (s *mitmCaptureStore) write(entry *mitmCaptureEntry, response bool, p []byte) {
	if entry == nil || len(p) == 0 {
		return
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if entry.gone {
		return
	}
	body := &entry.req
	if response {
		body = &entry.resp
	}
	body.size += int64(len(p))
	room := s.limits.body - int64(len(body.data))
	if int64(len(p)) > room {
		body.truncated = true
	}
	if room <= 0 {
		return
	}
	kept := p[:min(int64(len(p)), room)]
	body.data = append(body.data, kept...)
	entry.cost += int64(len(kept))
	s.bytes += int64(len(kept))
	s.evictLocked()
}

func (s *mitmCaptureStore) finish(entry *mitmCaptureEntry, failure string) {
	if entry == nil {
		return
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if !entry.pending {
		return
	}
	entry.pending = false
	entry.err = failure
	entry.duration = time.Since(entry.start)
}

// Ends a record the session left unfinished: stopped by a pause or new
// settings, or failed before or after the site's response began.
func (s *mitmCaptureStore) fail(entry *mitmCaptureEntry, err error) {
	if entry == nil {
		return
	}
	s.mu.Lock()
	status := entry.status
	s.mu.Unlock()
	switch {
	case err == nil:
		s.finish(entry, "")
	case errors.Is(err, errMitmSetupChanged):
		s.finish(entry, mitmExchangeStopped)
	case status != 0:
		s.finish(entry, mitmExchangeResponseFailed)
	default:
		s.finish(entry, mitmExchangeNoResponse)
	}
}

// The oldest records go first; every request after since is still kept.
func (s *mitmCaptureStore) evictLocked() {
	for len(s.order) > 0 && (len(s.order) > s.limits.entries || s.bytes > s.limits.bytes) {
		oldest := s.order[0]
		s.order[0] = nil
		s.order = s.order[1:]
		delete(s.byID, oldest.id)
		s.bytes -= oldest.cost
		oldest.gone = true
		oldest.req.data, oldest.resp.data, oldest.before = nil, nil, [2]mitmCaptureOriginal{}
		if oldest.start.After(s.since) {
			s.since = oldest.start
		}
	}
}

// A reader that records what passes through it, for a request or response
// body as the proxy forwards it.
type mitmCaptureReader struct {
	r        io.Reader
	entry    *mitmCaptureEntry
	response bool
}

func (c mitmCaptureReader) Read(p []byte) (int, error) {
	n, err := c.r.Read(p)
	if n > 0 {
		mitmCaptures.write(c.entry, c.response, p[:n])
	}
	return n, err
}

// Their replies carry decrypted traffic, so they are never spilled to a file
// however large; a body is bounded by max-body-size.
var mitmCaptureMethods = map[CoreMethod]bool{
	mitmExchangesMethod: true,
	mitmExchangeMethod:  true,
	mitmBodyMethod:      true,
}

type MitmExchangesParams struct {
	ID string `json:"id"`
}

type MitmExchangeParams struct {
	ID uint64 `json:"id"`
}

type MitmBodyParams struct {
	ID       uint64 `json:"id"`
	Response bool   `json:"response"`
	// The body as it came, before a rewrite rule changed it.
	Original bool `json:"original,omitempty"`
}

type MitmExchangeSummary struct {
	ID       uint64    `json:"id"`
	Start    time.Time `json:"start"`
	Pending  bool      `json:"pending"`
	Duration int64     `json:"duration"`
	Method   string    `json:"method"`
	// HTTP/1.1 or HTTP/2.0, as the client spoke it.
	Proto        string `json:"proto"`
	URL          string `json:"url"`
	Status       int    `json:"status"`
	RequestSize  int64  `json:"request-size"`
	ResponseSize int64  `json:"response-size"`
	Error        string `json:"error"`
	// A rewrite rule changed or answered this exchange.
	Rewritten bool `json:"rewritten,omitempty"`
	// A rewrite rule matched but left a message as it was (an oversized,
	// binary or undecodable body, say); Actions say which and why.
	RewriteSkipped bool `json:"rewrite-skipped,omitempty"`
}

type MitmExchangeList struct {
	Capturing bool                  `json:"capturing"`
	Since     *time.Time            `json:"since,omitempty"`
	Exchanges []MitmExchangeSummary `json:"exchanges"`
	Closed    bool                  `json:"closed"`
}

type MitmExchange struct {
	MitmExchangeSummary
	TTFB           int64               `json:"ttfb"`
	OriginalURL    string              `json:"original-url"`
	Proto          string              `json:"proto"`
	Connection     string              `json:"connection"`
	RequestHeader  map[string][]string `json:"request-header"`
	ResponseHeader map[string][]string `json:"response-header"`
	// What the rewrite rules did, in order; empty when none matched.
	Actions []MitmRewriteHit `json:"actions"`
	// A side's headers before rewrite rules changed them, and whether its
	// body as it came is kept (MitmBodyParams.Original); set only for a
	// side the rules changed.
	OriginalRequestHeader  map[string][]string `json:"original-request-header,omitempty"`
	OriginalResponseHeader map[string][]string `json:"original-response-header,omitempty"`
	OriginalRequestBody    bool                `json:"original-request-body,omitempty"`
	OriginalResponseBody   bool                `json:"original-response-body,omitempty"`
}

type MitmBody struct {
	Data      string `json:"data"`
	Truncated bool   `json:"truncated"`
	Encoding  string `json:"encoding"`
}

func (entry *mitmCaptureEntry) summary() MitmExchangeSummary {
	duration := entry.duration
	if entry.pending {
		duration = time.Since(entry.start)
	}
	summary := MitmExchangeSummary{
		ID:           entry.id,
		Start:        entry.start,
		Pending:      entry.pending,
		Duration:     duration.Milliseconds(),
		Method:       entry.method,
		Proto:        entry.proto,
		URL:          entry.url,
		Status:       entry.status,
		RequestSize:  entry.req.size,
		ResponseSize: entry.resp.size,
		Error:        entry.err,
	}
	for _, hit := range entry.rewrites {
		if hit.Skipped != "" {
			summary.RewriteSkipped = true
		} else {
			summary.Rewritten = true
		}
	}
	return summary
}

func handleMitmExchanges(params MitmExchangesParams) MitmExchangeList {
	s := mitmCaptures
	s.mu.Lock()
	defer s.mu.Unlock()
	list := MitmExchangeList{
		Capturing: s.enabled,
		Exchanges: []MitmExchangeSummary{},
		Closed:    s.open[params.ID] == 0,
	}
	if !s.since.IsZero() {
		since := s.since
		list.Since = &since
	}
	for _, entry := range s.order {
		if entry.connection == params.ID {
			list.Exchanges = append(list.Exchanges, entry.summary())
		}
	}
	return list
}

func handleMitmExchange(params MitmExchangeParams) *MitmExchange {
	s := mitmCaptures
	s.mu.Lock()
	defer s.mu.Unlock()
	entry := s.byID[params.ID]
	if entry == nil {
		return nil
	}
	exchange := &MitmExchange{
		MitmExchangeSummary: entry.summary(),
		TTFB:                entry.ttfb.Milliseconds(),
		Proto:               entry.proto,
		Connection:          entry.connection,
		RequestHeader:       entry.reqHeader.Clone(),
		ResponseHeader:      entry.respHeader.Clone(),
		OriginalURL:         entry.originalURL,
		Actions:             append([]MitmRewriteHit{}, entry.rewrites...),
	}
	exchange.OriginalRequestHeader = entry.before[0].header.Clone()
	exchange.OriginalResponseHeader = entry.before[1].header.Clone()
	exchange.OriginalRequestBody = entry.before[0].body != nil
	exchange.OriginalResponseBody = entry.before[1].body != nil

	if exchange.ResponseHeader == nil {
		exchange.ResponseHeader = map[string][]string{}
	}
	return exchange
}

func handleMitmBody(params MitmBodyParams) *MitmBody {
	s := mitmCaptures
	s.mu.Lock()
	entry := s.byID[params.ID]
	if entry == nil {
		s.mu.Unlock()
		return nil
	}
	body, header := entry.req, entry.reqHeader
	if params.Response {
		body, header = entry.resp, entry.respHeader
	}
	if params.Original {
		original := entry.before[mitmSide(params.Response)]
		if original.body == nil {
			s.mu.Unlock()
			return nil
		}
		body, header = *original.body, http.Header{"Content-Encoding": {original.encoding}}
	}
	data := append([]byte(nil), body.data...)
	limit := s.limits.body
	s.mu.Unlock()
	decoded, truncated, encoding := mitmDecodeBody(data, body.truncated, header.Get("Content-Encoding"), limit)
	return &MitmBody{
		Data:      base64.StdEncoding.EncodeToString(decoded),
		Truncated: truncated,
		Encoding:  encoding,
	}
}

var errMitmBodyTooLarge = errors.New("decoded body over the limit")

// Undoes gzip or deflate, up to limit bytes; any other coding, or one that
// fails, comes back as received with the coding named.
func mitmDecodeBody(data []byte, truncated bool, contentEncoding string, limit int64) ([]byte, bool, string) {
	coding := strings.ToLower(strings.TrimSpace(contentEncoding))
	var open func(io.Reader) (io.ReadCloser, error)
	switch coding {
	case "", "identity":
		return data, truncated, ""
	case "gzip", "x-gzip":
		open = func(r io.Reader) (io.ReadCloser, error) { return gzip.NewReader(r) }
	case "deflate":
		// Some servers send raw DEFLATE instead of the zlib stream RFC 9110 names.
		open = func(r io.Reader) (io.ReadCloser, error) {
			if zr, err := zlib.NewReader(r); err == nil {
				return zr, nil
			}
			return flate.NewReader(bytes.NewReader(data)), nil
		}
	default:
		return data, truncated, contentEncoding
	}
	if len(data) == 0 {
		return data, truncated, ""
	}
	reader, err := open(bytes.NewReader(data))
	if err != nil {
		return data, truncated, contentEncoding
	}
	defer reader.Close()
	var out bytes.Buffer
	n, err := io.Copy(&out, io.LimitReader(reader, limit+1))
	if n > limit {
		out.Truncate(int(limit))
		err = errMitmBodyTooLarge
	}
	switch {
	case err == nil:
		return out.Bytes(), truncated, ""
	case errors.Is(err, errMitmBodyTooLarge):
		return out.Bytes(), true, ""
	case truncated && errors.Is(err, io.ErrUnexpectedEOF):
		// The kept start of a longer body decodes as far as it goes.
		return out.Bytes(), true, ""
	default:
		return data, truncated, contentEncoding
	}
}
