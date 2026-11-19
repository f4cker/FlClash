package core

import (
	"bytes"
	"compress/gzip"
	"context"
	"encoding/json"
	"errors"
	"io"
	"net"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
	"unicode/utf8"

	"github.com/dop251/goja"
	mihomoHttp "github.com/metacubex/mihomo/component/http"
	"github.com/metacubex/mihomo/component/mmdb"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/log"
)

// $persistentStore: one JSON file of strings shared by every script, kept
// in memory once read. A script's own key (none given) is its name.
const (
	mitmScriptStoreValueCap = 1 << 20
	mitmScriptStoreCap      = 8 << 20
)

var mitmScriptStorePath = func() string {
	return filepath.Join(constant.Path.HomeDir(), "mitm", "script-store.json")
}

var mitmScriptStore struct {
	mu     sync.Mutex
	path   string
	values map[string]string
	size   int
}

func mitmScriptStoreLoad() {
	path := mitmScriptStorePath()
	if mitmScriptStore.values != nil && mitmScriptStore.path == path {
		return
	}
	mitmScriptStore.path, mitmScriptStore.values, mitmScriptStore.size = path, map[string]string{}, 0
	data, err := os.ReadFile(path)
	if err != nil {
		return
	}
	var values map[string]string
	if json.Unmarshal(data, &values) != nil {
		return
	}
	for key, value := range values {
		if mitmScriptStore.size+len(key)+len(value) > mitmScriptStoreCap {
			break
		}
		mitmScriptStore.values[key] = value
		mitmScriptStore.size += len(key) + len(value)
	}
}

func mitmScriptStoreSave() error {
	data, err := json.Marshal(mitmScriptStore.values)
	if err != nil {
		return err
	}
	path := mitmScriptStore.path
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	temporary := path + ".tmp"
	if err := os.WriteFile(temporary, data, 0o600); err != nil {
		return err
	}
	return os.Rename(temporary, path)
}

func (r *mitmScriptRun) storeKey(key goja.Value) string {
	if mitmJSAbsent(key) {
		return "@" + r.script.name
	}
	return key.String()
}

func (r *mitmScriptRun) storeRead(key goja.Value) goja.Value {
	mitmScriptStore.mu.Lock()
	defer mitmScriptStore.mu.Unlock()
	mitmScriptStoreLoad()
	value, ok := mitmScriptStore.values[r.storeKey(key)]
	if !ok {
		return goja.Null()
	}
	return r.vm.ToValue(value)
}

// A null value removes the key.
func (r *mitmScriptRun) storeWrite(value, key goja.Value) bool {
	name := r.storeKey(key)
	mitmScriptStore.mu.Lock()
	defer mitmScriptStore.mu.Unlock()
	mitmScriptStoreLoad()
	old, had := mitmScriptStore.values[name]
	size := mitmScriptStore.size
	if had {
		size -= len(name) + len(old)
	}
	if mitmJSAbsent(value) {
		if !had {
			return true
		}
		delete(mitmScriptStore.values, name)
	} else {
		text := value.String()
		if len(text) > mitmScriptStoreValueCap || size+len(name)+len(text) > mitmScriptStoreCap {
			r.log("warn", "$persistentStore is full; "+name+" was not written")
			return false
		}
		mitmScriptStore.values[name] = text
		size += len(name) + len(text)
	}
	mitmScriptStore.size = size
	if err := mitmScriptStoreSave(); err != nil {
		log.Warnln("[MITM] script store not saved: %v", err)
	}
	return true
}

// $notification.post shows in the script's log and, within the limits
// below, as a system notification the app posts.
const (
	mitmNotificationWindow    = time.Minute
	mitmNotificationPerScript = 3
	mitmNotificationTotal     = 10
	mitmNotificationTitleCap  = 256
	mitmNotificationBodyCap   = 2048
)

type MitmNotification struct {
	Script   string `json:"script"`
	Title    string `json:"title"`
	Subtitle string `json:"subtitle,omitempty"`
	Body     string `json:"body,omitempty"`
}

var (
	sendMitmNotification = func(notification *MitmNotification) bool {
		return sendMessage(MitmNotificationMessage, notification)
	}
	mitmNotificationClock = time.Now
	mitmNotificationTimes struct {
		mu       sync.Mutex
		all      []time.Time
		byScript map[string][]time.Time
	}
)

// Whether one more notification from script fits the per-script and total
// limits over the last mitmNotificationWindow; a fitting one is counted.
func mitmNotificationAllowed(script string) bool {
	times := &mitmNotificationTimes
	times.mu.Lock()
	defer times.mu.Unlock()
	now := mitmNotificationClock()
	recent := func(list []time.Time) []time.Time {
		kept := list[:0]
		for _, at := range list {
			if now.Sub(at) < mitmNotificationWindow {
				kept = append(kept, at)
			}
		}
		return kept
	}
	if times.byScript == nil {
		times.byScript = map[string][]time.Time{}
	}
	times.all = recent(times.all)
	for name, list := range times.byScript {
		if list = recent(list); len(list) == 0 {
			delete(times.byScript, name)
		} else {
			times.byScript[name] = list
		}
	}
	if len(times.all) >= mitmNotificationTotal || len(times.byScript[script]) >= mitmNotificationPerScript {
		return false
	}
	times.all = append(times.all, now)
	times.byScript[script] = append(times.byScript[script], now)
	return true
}

func mitmTruncate(text string, limit int) string {
	if len(text) <= limit {
		return text
	}
	text = text[:limit]
	for len(text) > 0 && !utf8.ValidString(text) {
		text = text[:len(text)-1]
	}
	return text
}

func (r *mitmScriptRun) notify(title, subtitle, body string) {
	text := strings.Join(slicesNonEmpty(title, subtitle, body), " · ")
	if text == "" {
		return
	}
	if !mitmNotificationAllowed(r.script.name) {
		r.log("notify", text+" (not shown: too many notifications)")
		return
	}
	r.log("notify", text)
	sendMitmNotification(&MitmNotification{
		Script:   r.script.name,
		Title:    mitmTruncate(title, mitmNotificationTitleCap),
		Subtitle: mitmTruncate(subtitle, mitmNotificationTitleCap),
		Body:     mitmTruncate(body, mitmNotificationBodyCap),
	})
}

func slicesNonEmpty(values ...string) []string {
	var out []string
	for _, v := range values {
		if v != "" {
			out = append(out, v)
		}
	}
	return out
}

// $httpClient: through Flash's own tunnel, so by its rules and proxies; a
// script's requests are never decrypted themselves.
var mitmScriptHTTP = func(ctx context.Context, method, url string, header map[string][]string, body io.Reader) (int, map[string][]string, io.ReadCloser, error) {
	resp, err := mihomoHttp.HttpRequest(ctx, url, method, header, body)
	if err != nil {
		return 0, nil, nil, err
	}
	return resp.StatusCode, resp.Header, resp.Body, nil
}

func (r *mitmScriptRun) fetch(method string, options *goja.Object, callback goja.Value) {
	url := ""
	if options != nil {
		if v := options.Get("url"); !mitmJSAbsent(v) {
			url = v.String()
		}
	}
	entry := MitmScriptRequest{Method: method, URL: url}
	r.pending++
	if len(r.requests) >= mitmScriptMaxRequests {
		entry.Error = "too many requests"
		r.log("warn", "$httpClient: over 16 requests in one run, "+url+" not sent")
		go r.post(func() error { return r.fetched(entry, callback, nil, 0, nil) })
		return
	}
	if !strings.HasPrefix(url, "http://") && !strings.HasPrefix(url, "https://") {
		entry.Error = "invalid URL"
		go r.post(func() error { return r.fetched(entry, callback, nil, 0, nil) })
		return
	}
	header := map[string][]string{}
	var body []byte
	timeout := r.script.timeout
	binary := false
	if options != nil {
		if v := options.Get("headers"); !mitmJSAbsent(v) {
			object := v.ToObject(r.vm)
			for _, key := range object.Keys() {
				value := object.Get(key).String()
				if !strings.ContainsAny(key+value, "\r\n") {
					header[key] = []string{value}
				}
			}
		}
		if v := options.Get("body"); !mitmJSAbsent(v) {
			if typed, ok := v.(*goja.Object); ok && typed.ClassName() == "Object" {
				if data, err := json.Marshal(v.Export()); err == nil {
					body = data
				}
			} else {
				body, _ = r.bytesOf(v)
			}
		}
		if v := options.Get("timeout"); !mitmJSAbsent(v) {
			if seconds := v.ToFloat(); seconds > 0 {
				timeout = min(timeout, time.Duration(seconds*float64(time.Second)))
			}
		}
		if v := options.Get("binary-mode"); v != nil {
			binary = v.ToBoolean()
		}
	}
	r.requests = append(r.requests, entry)
	index := len(r.requests) - 1
	go func() {
		ctx, cancel := context.WithTimeout(r.ctx, timeout)
		defer cancel()
		start := time.Now()
		var reader io.Reader
		if body != nil {
			reader = bytes.NewReader(body)
		}
		status, responseHeader, responseBody, err := mitmScriptHTTP(ctx, method, url, header, reader)
		var data []byte
		if err == nil {
			data, err = io.ReadAll(io.LimitReader(responseBody, mitmScriptOutputCap+1))
			responseBody.Close()
			if err == nil && len(data) > mitmScriptOutputCap {
				err = errors.New("response over 16 MiB")
			}
		}
		took := time.Since(start)
		r.post(func() error {
			done := r.requests[index]
			done.Status, done.TookNs = status, max(int64(took), 1)
			if err != nil {
				done.Status, done.Error = 0, err.Error()
			}
			r.requests[index] = done
			if err != nil {
				return r.fetched(done, callback, nil, 0, nil)
			}
			return r.fetched(done, callback, responseHeader, status, &mitmScriptFetched{data: data, binary: binary})
		})
	}()
}

type mitmScriptFetched struct {
	data   []byte
	binary bool
}

func (r *mitmScriptRun) fetched(entry MitmScriptRequest, callback goja.Value, header map[string][]string, status int, got *mitmScriptFetched) error {
	if got == nil {
		return r.call(callback, r.vm.ToValue(entry.Error), goja.Undefined(), goja.Undefined())
	}
	response := r.vm.NewObject()
	_ = response.Set("status", status)
	_ = response.Set("statusCode", status)
	headers := r.vm.NewObject()
	for name, values := range header {
		_ = headers.Set(name, strings.Join(values, ", "))
	}
	_ = response.Set("headers", headers)
	var data goja.Value = r.vm.ToValue(string(got.data))
	if got.binary {
		data = r.bytesValue(got.data)
	}
	return r.call(callback, goja.Null(), response, data)
}

func (r *mitmScriptRun) ungzip(v goja.Value) goja.Value {
	data, err := r.bytesOf(v)
	if err != nil {
		return goja.Undefined()
	}
	zr, err := gzip.NewReader(bytes.NewReader(data))
	if err != nil {
		return goja.Undefined()
	}
	defer zr.Close()
	out, err := io.ReadAll(io.LimitReader(zr, mitmScriptOutputCap+1))
	if err != nil || len(out) > mitmScriptOutputCap {
		return goja.Undefined()
	}
	return r.bytesValue(out)
}

// The MMDB and ASN readers end the process on a file they cannot open, so
// a file is only handed to them once it checked out.
func mitmScriptGeoIP(ip string) string {
	parsed := net.ParseIP(strings.TrimSpace(ip))
	if parsed == nil || !mitmScriptDatabase(constant.Path.MMDB()) {
		return ""
	}
	codes := mmdb.IPInstance().LookupCode(parsed)
	if len(codes) == 0 {
		return ""
	}
	return strings.ToUpper(codes[0])
}

func mitmScriptASN(ip string) (string, string) {
	parsed := net.ParseIP(strings.TrimSpace(ip))
	if parsed == nil || !mitmScriptDatabase(constant.Path.ASN()) {
		return "", ""
	}
	return mmdb.ASNInstance().LookupASN(parsed)
}

var mitmScriptDatabases sync.Map

func mitmScriptDatabase(path string) bool {
	if ok, seen := mitmScriptDatabases.Load(path); seen {
		return ok.(bool)
	}
	ok := false
	if info, err := os.Stat(path); err == nil && info.Size() > 0 {
		ok = mmdb.Verify(path)
	}
	mitmScriptDatabases.Store(path, ok)
	return ok
}
