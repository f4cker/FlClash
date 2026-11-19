package core

import (
	"bytes"
	"errors"
	"io"
	"net/http"
	"net/url"
	"strings"
	"unicode/utf8"
)

// header is changed in place; body is read only for requires-body.
type mitmScriptMessage struct {
	method        string
	status        int
	requestHeader http.Header
	header        http.Header
	body          io.Reader
	length        int64
	// Why requires-body scripts cannot have the body here; "" when they can.
	bodySkip string
}

type mitmScriptPhase struct {
	body     io.Reader
	length   int64
	changed  bool
	original []byte
	status   int
	// An http-request script answered for the site.
	local      *mitmLocalResponse
	requestURI string
}

func (x *mitmRewriteExchange) scriptRules(response bool) []*mitmRewriteRule {
	if x == nil || x.plain {
		return nil
	}
	index, phase := &x.engine.requestScript, "request"
	if response {
		index, phase = &x.engine.responseScript, "response"
	}
	var matched []*mitmRewriteRule
	for _, rule := range index.candidates(x.host) {
		if x.matches(rule, phase) {
			matched = append(matched, rule)
		}
	}
	return matched
}

func (x *mitmRewriteExchange) recordScript(rule *mitmRewriteRule, phase string, result mitmScriptResult) {
	x.hits = append(x.hits, MitmRewriteHit{
		Rule: rule.id, Section: rule.section, Phase: phase, Action: rule.script.name,
		Skipped: result.skip, TookNs: max(int64(result.took), 1),
		Logs: result.logs, Requests: result.requests, Error: result.err,
	})
	rule.stats.record(result.skip)
}

type mitmScriptBody struct {
	raw     []byte
	decoded []byte
	rest    io.Reader
	read    bool
	skip    string
}

func (x *mitmRewriteExchange) scriptBody(rules []*mitmRewriteRule, msg *mitmScriptMessage) mitmScriptBody {
	var limit int64
	for _, rule := range rules {
		if rule.script.requiresBody {
			limit = max(limit, rule.script.maxSize)
		}
	}
	if limit == 0 {
		return mitmScriptBody{rest: msg.body}
	}
	if msg.bodySkip != "" {
		return mitmScriptBody{rest: msg.body, skip: msg.bodySkip}
	}
	if strings.HasPrefix(strings.ToLower(strings.TrimSpace(msg.header.Get("Content-Type"))), "text/event-stream") {
		return mitmScriptBody{rest: msg.body, skip: mitmSkipStreaming}
	}
	if msg.length > limit {
		return mitmScriptBody{rest: msg.body, skip: mitmSkipOversize}
	}
	var raw []byte
	if msg.body != nil && msg.body != http.NoBody {
		var err error
		raw, err = io.ReadAll(io.LimitReader(msg.body, limit+1))
		if err != nil {
			return mitmScriptBody{rest: io.MultiReader(bytes.NewReader(raw), msg.body), skip: mitmSkipBodyReadFail}
		}
	}
	if int64(len(raw)) > limit {
		return mitmScriptBody{rest: io.MultiReader(bytes.NewReader(raw), msg.body), skip: mitmSkipOversize}
	}
	body := mitmScriptBody{raw: raw, rest: bytes.NewReader(raw), read: true}
	decoded, supported, err := mitmDecodeContent(raw, msg.header.Get("Content-Encoding"), limit)
	switch {
	case !supported:
		body.skip = mitmSkipEncoding
	case errors.Is(err, errMitmRewriteBodyTooLarge):
		body.skip = mitmSkipOversize
	case err != nil:
		body.skip = mitmSkipDecode
	default:
		body.decoded = decoded
	}
	return body
}

func (x *mitmRewriteExchange) runScripts(rules []*mitmRewriteRule, msg *mitmScriptMessage, response bool) mitmScriptPhase {
	phase := "request"
	if response {
		phase = "response"
	}
	out := mitmScriptPhase{body: msg.body}
	if len(rules) == 0 {
		return out
	}
	body := x.scriptBody(rules, msg)
	out.body = body.rest
	current, changed := body.decoded, false
	status := msg.status
	for _, rule := range rules {
		s := rule.script
		in := &mitmScriptInput{
			response: response, h2: x.h2, url: x.url, method: msg.method,
			requestHeader: msg.requestHeader.Clone(), header: msg.header.Clone(), status: status,
		}
		if s.requiresBody {
			skip := body.skip
			switch {
			case skip != "":
			case int64(len(current)) > s.maxSize:
				skip = mitmSkipOversize
			case !s.binary && !utf8.Valid(current):
				skip = mitmSkipNotUTF8
			}
			if skip != "" {
				x.record(rule, phase, s.name, skip)
				continue
			}
			in.body, in.hasBody = current, true
		}
		result := s.run(in)
		x.recordScript(rule, phase, result)
		if result.out == nil {
			continue
		}
		done := result.out
		if done.local != nil {
			local := &mitmLocalResponse{status: done.local.status, header: done.local.header, body: done.local.body}
			if local.header == nil {
				local.header = http.Header{}
			}
			out.local = local
			return out
		}
		if done.url != nil && *done.url != x.url {
			if uri, ok := x.scriptURL(*done.url); ok {
				out.requestURI = uri
			} else {
				x.hits[len(x.hits)-1].Logs = append(x.hits[len(x.hits)-1].Logs,
					MitmScriptLog{Level: "warn", Text: "url " + *done.url + " is on another host or port and was not applied"})
			}
		}
		if done.header != nil {
			for name := range msg.header {
				delete(msg.header, name)
			}
			for name, values := range done.header {
				msg.header[name] = values
			}
		}
		if done.status != 0 && response {
			status = done.status
		}
		if done.bodySet {
			if !s.requiresBody {
				x.hits[len(x.hits)-1].Logs = append(x.hits[len(x.hits)-1].Logs,
					MitmScriptLog{Level: "warn", Text: "body left as it was: the script does not have requires-body=1"})
			} else if !bytes.Equal(done.body, current) {
				current, changed = done.body, true
			}
		}
	}
	if status != msg.status {
		out.status = status
	}
	if changed {
		out.body, out.length, out.changed, out.original = bytes.NewReader(current), int64(len(current)), true, body.raw
	}
	return out
}

// Like a header-mode URL Rewrite, a new URL must keep the host and port.
func (x *mitmRewriteExchange) scriptURL(target string) (string, bool) {
	parsed, err := url.Parse(target)
	if err != nil || parsed.Host == "" {
		return "", false
	}
	port := parsed.Port()
	if port == "" {
		port = mitmDefaultPort(parsed.Scheme)
	}
	if normalizeMitmHost(parsed.Hostname()) != x.host || port != x.port() {
		return "", false
	}
	requestURI := parsed.RequestURI()
	x.url = x.scheme + "://" + x.authority + requestURI
	return requestURI, true
}
