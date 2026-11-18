package core

import (
	"context"
	"encoding/base64"
	"errors"
	"fmt"
	"net/http"
	"net/textproto"
	"runtime/metrics"
	"slices"
	"strconv"
	"strings"
	"sync/atomic"
	"time"
	"unicode/utf8"

	"github.com/dop251/goja"
)

// Why a script left a message as it was.
const (
	mitmSkipScriptTimeout = "scriptTimeout"
	mitmSkipScriptError   = "scriptError"
	mitmSkipScriptMemory  = "scriptMemory"
	mitmSkipScriptNoDone  = "scriptNoDone"
	mitmSkipScriptBusy    = "scriptBusy"
)

// One line a script logged; level is console's (log, info, warn, error,
// debug) or notify for $notification.post.
type MitmScriptLog struct {
	Level string `json:"level"`
	Text  string `json:"text"`
}

// A request a script made with $httpClient.
type MitmScriptRequest struct {
	Method string `json:"method"`
	URL    string `json:"url"`
	Status int    `json:"status,omitempty"`
	Error  string `json:"error,omitempty"`
	TookNs int64  `json:"took-ns,omitempty"`
}

type mitmScriptInput struct {
	response bool
	h2       bool
	url      string
	method   string
	// The request's headers, which a response script sees as $request.
	requestHeader http.Header
	header        http.Header
	status        int
	body          []byte
	hasBody       bool
}

// What $done asked for; nil fields leave that part as it was.
type mitmScriptOutput struct {
	url     *string
	status  int
	header  http.Header
	body    []byte
	bodySet bool
	// An http-request script's $done({response}): answer without the site.
	local *mitmScriptOutput
}

type mitmScriptResult struct {
	out      *mitmScriptOutput
	skip     string
	err      string
	logs     []MitmScriptLog
	requests []MitmScriptRequest
	took     time.Duration
}

var (
	mitmScriptSlots    = make(chan struct{}, 16)
	mitmScriptSlotWait = time.Second
	// Heap growth during a run past which it is stopped; shared by the
	// runs in flight, so it is approximate.
	mitmScriptMemoryLimit = func() *atomic.Uint64 { v := &atomic.Uint64{}; v.Store(192 << 20); return v }()
	// What a run may still take past its timeout to give up a builtin
	// that cannot be interrupted, before its caller stops waiting for it.
	mitmScriptGrace = time.Second
)

const (
	mitmScriptLogLines     = 100
	mitmScriptLogBytes     = 32 << 10
	mitmScriptMaxRequests  = 16
	mitmScriptOutputCap    = 16 << 20
	mitmScriptStringCap    = 32 << 20
	mitmScriptInterruptMem = "memory"
	mitmScriptInterruptEnd = "done"
)

// Runs the script on in. It never takes longer than the script's timeout
// and mitmScriptGrace: a run still going then is abandoned, still holding
// its slot until it ends, and the message passes as it was.
func (s *mitmScript) run(in *mitmScriptInput) mitmScriptResult {
	start := time.Now()
	wait := time.NewTimer(mitmScriptSlotWait)
	select {
	case mitmScriptSlots <- struct{}{}:
		wait.Stop()
	case <-wait.C:
		return mitmScriptResult{skip: mitmSkipScriptBusy}
	}
	results := make(chan mitmScriptResult, 1)
	go func() {
		defer func() { <-mitmScriptSlots }()
		r := newMitmScriptRun(s, in)
		defer r.cancel()
		results <- r.execute()
	}()
	hard := time.NewTimer(s.timeout + mitmScriptGrace)
	defer hard.Stop()
	select {
	case result := <-results:
		result.took = time.Since(start)
		return result
	case <-hard.C:
		return mitmScriptResult{skip: mitmSkipScriptTimeout, err: "timed out", took: time.Since(start)}
	}
}

type mitmScriptTimer struct {
	timer     *time.Timer
	cancelled bool
}

type mitmScriptRun struct {
	script    *mitmScript
	in        *mitmScriptInput
	vm        *goja.Runtime
	ctx       context.Context
	cancel    context.CancelFunc
	jobs      chan func() error
	stopped   chan string
	pending   int
	timers    map[int64]*mitmScriptTimer
	nextTimer int64
	done      bool
	out       *mitmScriptOutput
	outErr    error
	logs      []MitmScriptLog
	logBytes  int
	requests  []MitmScriptRequest
}

func newMitmScriptRun(s *mitmScript, in *mitmScriptInput) *mitmScriptRun {
	ctx, cancel := context.WithTimeout(context.Background(), s.timeout)
	return &mitmScriptRun{
		script:  s,
		in:      in,
		vm:      goja.New(),
		ctx:     ctx,
		cancel:  cancel,
		jobs:    make(chan func() error),
		stopped: make(chan string, 1),
		timers:  map[int64]*mitmScriptTimer{},
	}
}

func mitmHeapBytes() uint64 {
	sample := []metrics.Sample{{Name: "/memory/classes/heap/objects:bytes"}}
	metrics.Read(sample)
	if sample[0].Value.Kind() != metrics.KindUint64 {
		return 0
	}
	return sample[0].Value.Uint64()
}

func (r *mitmScriptRun) watch() {
	base := mitmHeapBytes()
	ticker := time.NewTicker(10 * time.Millisecond)
	defer ticker.Stop()
	for {
		select {
		case <-r.ctx.Done():
			if errors.Is(r.ctx.Err(), context.DeadlineExceeded) {
				r.vm.Interrupt(context.DeadlineExceeded)
			}
			return
		case <-ticker.C:
			if base > 0 && mitmHeapBytes() > base+mitmScriptMemoryLimit.Load() {
				select {
				case r.stopped <- mitmScriptInterruptMem:
				default:
				}
				r.vm.Interrupt(mitmScriptInterruptMem)
				return
			}
		}
	}
}

func (r *mitmScriptRun) execute() (result mitmScriptResult) {
	defer func() {
		if p := recover(); p != nil {
			result = mitmScriptResult{skip: mitmSkipScriptError, err: fmt.Sprint(p)}
		}
		result.logs, result.requests = r.logs, r.requests
	}()
	go r.watch()
	r.vm.SetMaxCallStackSize(1000)
	err := r.install()
	if err == nil {
		_, err = r.vm.RunProgram(r.script.program)
	}
	for {
		switch {
		case r.done && r.outErr != nil:
			return r.failure(r.outErr)
		case r.done:
			return mitmScriptResult{out: r.out}
		case err != nil:
			return r.failure(err)
		case r.pending == 0:
			return mitmScriptResult{skip: mitmSkipScriptNoDone}
		}
		select {
		case job := <-r.jobs:
			r.pending--
			err = job()
		case <-r.ctx.Done():
			return mitmScriptResult{skip: mitmSkipScriptTimeout, err: "timed out"}
		case <-r.stopped:
			return mitmScriptResult{skip: mitmSkipScriptMemory, err: "memory limit"}
		}
	}
}

func (r *mitmScriptRun) failure(err error) mitmScriptResult {
	var interrupted *goja.InterruptedError
	if errors.As(err, &interrupted) {
		if interrupted.Value() == mitmScriptInterruptMem {
			return mitmScriptResult{skip: mitmSkipScriptMemory, err: "memory limit"}
		}
		return mitmScriptResult{skip: mitmSkipScriptTimeout, err: "timed out"}
	}
	text := err.Error()
	var exception *goja.Exception
	if errors.As(err, &exception) {
		text = exception.Error()
	}
	if len(text) > 1000 {
		text = text[:1000]
	}
	r.log("error", text)
	return mitmScriptResult{skip: mitmSkipScriptError, err: text}
}

// Posts job to the run from another goroutine; dropped once it ended.
func (r *mitmScriptRun) post(job func() error) {
	select {
	case r.jobs <- job:
	case <-r.ctx.Done():
	}
}

func (r *mitmScriptRun) log(level, text string) {
	if len(r.logs) >= mitmScriptLogLines || r.logBytes >= mitmScriptLogBytes {
		return
	}
	if room := mitmScriptLogBytes - r.logBytes; len(text) > room {
		text = text[:room]
	}
	r.logBytes += len(text)
	r.logs = append(r.logs, MitmScriptLog{Level: level, Text: text})
}

func (r *mitmScriptRun) call(fn goja.Value, args ...goja.Value) error {
	callable, ok := goja.AssertFunction(fn)
	if !ok {
		return nil
	}
	_, err := callable(goja.Undefined(), args...)
	return err
}

// ---- Values ----

func (r *mitmScriptRun) bytesValue(data []byte) goja.Value {
	buffer := r.vm.NewArrayBuffer(append([]byte(nil), data...))
	array, err := r.vm.New(r.vm.Get("Uint8Array"), r.vm.ToValue(buffer))
	if err != nil {
		panic(err)
	}
	return array
}

func (r *mitmScriptRun) bodyValue(data []byte) goja.Value {
	if r.script.binary {
		return r.bytesValue(data)
	}
	return r.vm.ToValue(string(data))
}

func mitmJSAbsent(v goja.Value) bool {
	return v == nil || goja.IsUndefined(v) || goja.IsNull(v)
}

func (r *mitmScriptRun) bytesOf(v goja.Value) ([]byte, error) {
	var data []byte
	switch x := v.Export().(type) {
	case string:
		data = []byte(x)
	case []byte:
		data = append([]byte(nil), x...)
	case goja.ArrayBuffer:
		data = append([]byte(nil), x.Bytes()...)
	default:
		data = []byte(v.String())
	}
	if len(data) > mitmScriptOutputCap {
		return nil, errors.New("the body a script returned is over 16 MiB")
	}
	return data, nil
}

func (r *mitmScriptRun) headersValue(header http.Header) goja.Value {
	object := r.vm.NewObject()
	names := make([]string, 0, len(header))
	for name := range header {
		names = append(names, name)
	}
	slices.Sort(names)
	for _, name := range names {
		key := name
		if r.in.h2 {
			key = strings.ToLower(name)
		}
		_ = object.Set(key, strings.Join(header[name], ", "))
	}
	return object
}

// Headers a script cannot set: they frame the message or name its host.
func mitmScriptKeptHeader(name string) bool {
	switch name {
	case "Content-Length", "Transfer-Encoding", "Connection", "Keep-Alive", "Proxy-Connection",
		"Upgrade", "Te", "Trailer", "Host":
		return true
	}
	return strings.HasPrefix(name, ":")
}

func (r *mitmScriptRun) headersOf(v goja.Value, original http.Header) http.Header {
	object := v.ToObject(r.vm)
	header := http.Header{}
	for _, key := range object.Keys() {
		value := object.Get(key)
		if mitmJSAbsent(value) {
			continue
		}
		name := textproto.CanonicalMIMEHeaderKey(strings.TrimSpace(key))
		if name == "" || strings.ContainsAny(name, " \t:\r\n") || mitmScriptKeptHeader(name) {
			continue
		}
		var values []string
		if list, ok := value.Export().([]any); ok {
			for _, item := range list {
				values = append(values, fmt.Sprint(item))
			}
		} else {
			values = []string{value.String()}
		}
		if slices.ContainsFunc(values, func(v string) bool { return strings.ContainsAny(v, "\r\n") }) {
			r.log("warn", "header "+name+" has a line break and was left out")
			continue
		}
		if old := original[name]; len(values) == 1 && len(old) > 1 && strings.Join(old, ", ") == values[0] {
			values = old
		}
		header[name] = append(header[name], values...)
	}
	for name, values := range original {
		if mitmScriptKeptHeader(name) {
			header[name] = values
		}
	}
	return header
}

func mitmScriptStatus(v goja.Value) int {
	var status int
	switch x := v.Export().(type) {
	case int64:
		status = int(x)
	case float64:
		status = int(x)
	default:
		for _, field := range strings.Fields(v.String()) {
			if n, err := strconv.Atoi(field); err == nil {
				status = n
				break
			}
		}
	}
	if status < 200 || status > 999 {
		return 0
	}
	return status
}

func (r *mitmScriptRun) message(v goja.Value, original http.Header, response bool) (*mitmScriptOutput, error) {
	out := &mitmScriptOutput{}
	object, ok := v.(*goja.Object)
	if !ok {
		return out, nil
	}
	if !response {
		if url := object.Get("url"); !mitmJSAbsent(url) {
			text := url.String()
			out.url = &text
		}
	} else if status := object.Get("status"); !mitmJSAbsent(status) {
		if out.status = mitmScriptStatus(status); out.status == 0 {
			r.log("warn", "status "+status.String()+" is not a valid status and was left out")
		}
	}
	if headers := object.Get("headers"); !mitmJSAbsent(headers) {
		out.header = r.headersOf(headers, original)
	}
	body := object.Get("bodyBytes")
	if mitmJSAbsent(body) {
		body = object.Get("body")
	}
	if !mitmJSAbsent(body) {
		data, err := r.bytesOf(body)
		if err != nil {
			return nil, err
		}
		out.body, out.bodySet = data, true
	}
	return out, nil
}

func (r *mitmScriptRun) doneWith(v goja.Value) {
	if r.done {
		return
	}
	r.done = true
	out := &mitmScriptOutput{}
	var err error
	if object, ok := v.(*goja.Object); ok && !r.in.response {
		if local := object.Get("response"); !mitmJSAbsent(local) {
			out.local, err = r.message(local, http.Header{}, true)
			if err == nil && out.local.status == 0 {
				out.local.status = http.StatusOK
			}
		} else {
			out, err = r.message(v, r.in.header, false)
		}
	} else if !mitmJSAbsent(v) {
		out, err = r.message(v, r.in.header, r.in.response)
	}
	r.out, r.outErr = out, err
	r.vm.Interrupt(mitmScriptInterruptEnd)
}

// ---- The environment ----

const mitmScriptPrelude = `(function (g, n) {
  var max = n.max;
  function guard(size) { if (size > max) throw new RangeError('Invalid length'); }
  var repeat = String.prototype.repeat, padStart = String.prototype.padStart, padEnd = String.prototype.padEnd;
  var join = Array.prototype.join, fill = Array.prototype.fill;
  function define(o, k, f) { Object.defineProperty(o, k, { value: f, writable: true, configurable: true }); }
  define(String.prototype, 'repeat', function (c) { guard(String(this).length * Number(c)); return repeat.call(this, c); });
  define(String.prototype, 'padStart', function (l, s) { guard(Number(l)); return padStart.call(this, l, s); });
  define(String.prototype, 'padEnd', function (l, s) { guard(Number(l)); return padEnd.call(this, l, s); });
  define(Array.prototype, 'join', function (s) { guard(Number(this.length)); return join.call(this, s); });
  define(Array.prototype, 'fill', function () { guard(Number(this.length) * 8); return fill.apply(this, arguments); });
  ['ArrayBuffer', 'Int8Array', 'Uint8Array', 'Uint8ClampedArray', 'Int16Array', 'Uint16Array', 'Int32Array',
   'Uint32Array', 'Float32Array', 'Float64Array', 'BigInt64Array', 'BigUint64Array'].forEach(function (k) {
    var C = g[k];
    if (!C) return;
    var unit = C.BYTES_PER_ELEMENT || 1;
    g[k] = new Proxy(C, { construct: function (t, a, nt) {
      if (typeof a[0] === 'number') guard(a[0] * unit);
      return Reflect.construct(t, a, nt === g[k] ? t : nt);
    } });
  });
  function text(v) {
    if (typeof v === 'string') return v;
    if (v instanceof Error) return String(v);
    try { var s = JSON.stringify(v); return s === undefined ? String(v) : s; } catch (e) { return String(v); }
  }
  function logger(level) { return function () { n.log(level, Array.prototype.map.call(arguments, text).join(' ')); }; }
  g.console = { log: logger('log'), info: logger('info'), warn: logger('warn'), error: logger('error'), debug: logger('debug') };
  g.$done = function (v) { n.done(v); };
  g.$persistentStore = {
    read: function (k) { return n.read(k === undefined ? null : String(k)); },
    write: function (v, k) { return n.write(v === undefined || v === null ? null : String(v), k === undefined ? null : String(k)); },
    remove: function (k) { return n.write(null, String(k)); }
  };
  g.$notification = { post: function (t, s, b) { n.notify(t == null ? '' : String(t), s == null ? '' : String(s), b == null ? '' : String(b)); } };
  g.$httpClient = {};
  ['get', 'post', 'put', 'delete', 'head', 'options', 'patch'].forEach(function (m) {
    g.$httpClient[m] = function (o, cb) { n.fetch(m.toUpperCase(), typeof o === 'string' ? { url: o } : (o || {}), cb); };
  });
  g.setTimeout = function (f, ms) { return n.timer(f, Number(ms) || 0, false, Array.prototype.slice.call(arguments, 2)); };
  g.setInterval = function (f, ms) { return n.timer(f, Number(ms) || 0, true, Array.prototype.slice.call(arguments, 2)); };
  g.clearTimeout = g.clearInterval = function (id) { if (id != null) n.clear(Number(id)); };
  g.$utils = { geoip: n.geoip, ipasn: n.ipasn, ipaso: n.ipaso, ungzip: n.ungzip };
  g.atob = n.atob;
  g.btoa = n.btoa;
  g.TextEncoder = function () { this.encoding = 'utf-8'; };
  g.TextEncoder.prototype.encode = function (s) { return n.encode(s === undefined ? '' : String(s)); };
  g.TextDecoder = function () { this.encoding = 'utf-8'; };
  g.TextDecoder.prototype.decode = function (b) { return b === undefined ? '' : n.decode(b); };
})(globalThis, __flash)`

func (r *mitmScriptRun) install() error {
	vm := r.vm
	native := vm.NewObject()
	set := func(name string, fn any) { _ = native.Set(name, fn) }
	_ = native.Set("max", mitmScriptStringCap)
	set("log", func(level, text string) { r.log(level, text) })
	set("done", func(v goja.Value) { r.doneWith(v) })
	set("read", func(key goja.Value) goja.Value { return r.storeRead(key) })
	set("write", func(value, key goja.Value) bool { return r.storeWrite(value, key) })
	set("notify", func(title, subtitle, body string) { r.notify(title, subtitle, body) })
	set("fetch", func(method string, options *goja.Object, callback goja.Value) { r.fetch(method, options, callback) })
	set("timer", func(fn goja.Value, ms float64, repeat bool, args []goja.Value) int64 {
		return r.setTimer(fn, ms, repeat, args)
	})
	set("clear", func(id int64) { r.clearTimer(id) })
	set("geoip", func(ip string) string { return mitmScriptGeoIP(ip) })
	set("ipasn", func(ip string) string { asn, _ := mitmScriptASN(ip); return asn })
	set("ipaso", func(ip string) string { _, org := mitmScriptASN(ip); return org })
	set("ungzip", func(v goja.Value) goja.Value { return r.ungzip(v) })
	set("atob", func(s string) string {
		data, err := base64.StdEncoding.DecodeString(strings.TrimRight(s, "="))
		if err != nil {
			data, err = base64.RawStdEncoding.DecodeString(strings.TrimRight(s, "="))
		}
		if err != nil {
			panic(vm.NewTypeError("invalid base64"))
		}
		runes := make([]rune, len(data))
		for i, b := range data {
			runes[i] = rune(b)
		}
		return string(runes)
	})
	set("btoa", func(s string) string {
		data := make([]byte, 0, len(s))
		for _, c := range s {
			if c > 0xff {
				panic(vm.NewTypeError("btoa: character out of range"))
			}
			data = append(data, byte(c))
		}
		return base64.StdEncoding.EncodeToString(data)
	})
	set("encode", func(s string) goja.Value { return r.bytesValue([]byte(s)) })
	set("decode", func(v goja.Value) string {
		data, _ := r.bytesOf(v)
		return strings.ToValidUTF8(string(data), "\uFFFD")
	})
	if err := vm.Set("__flash", native); err != nil {
		return err
	}
	if _, err := vm.RunString(mitmScriptPrelude); err != nil {
		return err
	}
	if _, err := vm.RunString("delete globalThis.__flash"); err != nil {
		return err
	}
	return r.installGlobals()
}

func (r *mitmScriptRun) installGlobals() error {
	vm, in := r.vm, r.in
	request := vm.NewObject()
	_ = request.Set("url", in.url)
	_ = request.Set("method", in.method)
	_ = request.Set("id", strconv.FormatInt(time.Now().UnixNano(), 36))
	if in.response {
		_ = request.Set("headers", r.headersValue(in.requestHeader))
	} else {
		_ = request.Set("headers", r.headersValue(in.header))
		if in.hasBody {
			_ = request.Set("body", r.bodyValue(in.body))
		}
	}
	if err := vm.Set("$request", request); err != nil {
		return err
	}
	if in.response {
		response := vm.NewObject()
		_ = response.Set("status", in.status)
		_ = response.Set("statusCode", in.status)
		_ = response.Set("headers", r.headersValue(in.header))
		if in.hasBody {
			_ = response.Set("body", r.bodyValue(in.body))
		}
		if err := vm.Set("$response", response); err != nil {
			return err
		}
	}
	kind := "http-request"
	if in.response {
		kind = "http-response"
	}
	if err := vm.Set("$script", map[string]any{"name": r.script.name, "type": kind, "startTime": time.Now()}); err != nil {
		return err
	}
	var argument any = r.script.argument
	if r.script.argumentJSON != nil {
		argument = r.script.argumentJSON
	}
	if err := vm.Set("$argument", argument); err != nil {
		return err
	}
	if err := vm.Set("$environment", map[string]any{
		"surge-version": "5.0.0", "surge-build": "3000", "system": "macOS", "language": "en",
	}); err != nil {
		return err
	}
	return vm.Set("$network", map[string]any{"v4": map[string]any{}, "v6": map[string]any{}, "wifi": map[string]any{}})
}

func (r *mitmScriptRun) setTimer(fn goja.Value, ms float64, repeat bool, args []goja.Value) int64 {
	if _, ok := goja.AssertFunction(fn); !ok {
		return 0
	}
	r.nextTimer++
	id := r.nextTimer
	delay := time.Duration(max(ms, 0) * float64(time.Millisecond))
	entry := &mitmScriptTimer{}
	r.timers[id] = entry
	var fire func()
	fire = func() {
		r.post(func() error {
			if entry.cancelled {
				return nil
			}
			err := r.call(fn, args...)
			if repeat && !entry.cancelled && err == nil {
				r.pending++
				entry.timer = time.AfterFunc(max(delay, time.Millisecond), fire)
			} else {
				delete(r.timers, id)
			}
			return err
		})
	}
	r.pending++
	entry.timer = time.AfterFunc(delay, fire)
	return id
}

func (r *mitmScriptRun) clearTimer(id int64) {
	entry := r.timers[id]
	if entry == nil {
		return
	}
	entry.cancelled = true
	delete(r.timers, id)
	if entry.timer.Stop() {
		r.pending--
	}
}

// Body text for a script in text mode: valid UTF-8 only.
func mitmScriptText(data []byte) bool {
	return utf8.Valid(data)
}
