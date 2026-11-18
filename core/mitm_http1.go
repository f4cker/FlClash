package core

import (
	"bufio"
	"bytes"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"sync"
	"time"
)

// Headers are buffered only up to this size. Bodies are streamed by net/http;
// neither request nor response bodies are accumulated in memory here.
const mitmHTTPHeaderLimit = 64 << 10

var errMitmHTTP1 = errors.New("unsupported or invalid HTTP/1.1 exchange")

// Ensure the complete header fits before net/http parses it. Peek does not
// consume bytes: a parse error closes the already-intercepted connection, not
// a replay of a request whose TLS handshake or upstream write already began.
func mitmPeekHeader(r *bufio.Reader) error {
	for n := 1; n <= mitmHTTPHeaderLimit; n++ {
		b, err := r.Peek(n)
		if err != nil {
			return err
		}
		if n >= 4 && string(b[n-4:n]) == "\r\n\r\n" {
			// Reject ambiguous framing before Go normalizes any headers.
			if bytes.IndexByte(bytes.ReplaceAll(b, []byte("\r\n"), nil), '\n') >= 0 || bytes.IndexByte(bytes.ReplaceAll(b, []byte("\r\n"), nil), '\r') >= 0 {
				return errMitmHTTP1
			}
			var lengths, transfers int
			lines := bytes.Split(b, []byte("\r\n"))
			for _, line := range lines[1:] {
				if len(line) == 0 {
					continue
				}
				if line[0] == ' ' || line[0] == '\t' {
					return errMitmHTTP1
				}
				name, _, ok := bytes.Cut(line, []byte(":"))
				if !ok {
					return errMitmHTTP1
				}
				if bytes.EqualFold(name, []byte("Content-Length")) {
					lengths++
				}
				if bytes.EqualFold(name, []byte("Transfer-Encoding")) {
					transfers++
				}
			}
			if lengths > 1 || transfers > 1 || lengths > 0 && transfers > 0 {
				return errMitmHTTP1
			}
			return nil
		}
	}
	return errMitmHTTP1
}

func mitmRequestHost(host string) string {
	if strings.Contains(host, ":") {
		h, port, err := net.SplitHostPort(host)
		if err != nil || port == "" {
			return ""
		}
		host = h
	}
	return normalizeMitmHost(host)
}

// A Close that never drains a partially received HTTP body. The owning
// connection is closed when an exchange aborts; successful bodies are closed
// separately only after their framing has been fully consumed.
type mitmNoDrainBody struct{ io.Reader }

func (mitmNoDrainBody) Close() error { return nil }

// Request.Write would otherwise copy a Content-Length body through its own
// 4 KiB bufio.Writer, holding a slow upload's bytes back from the site until
// that buffer fills. With this writer (an io.ByteWriter, so Request.Write adds
// no buffer of its own) header bytes still coalesce, and the request body
// flushes everything written so far before each read from the client: every
// byte received goes upstream before the proxy waits for more.
// Deliberately no ReadFrom: bufio.Writer.ReadFrom reads into its own buffer,
// which a flush from inside the body's Read would corrupt.
// The mutex covers net/http's body probe: for GET-like methods with a body,
// Request.Write reads the body from a second goroutine while still writing
// headers, so a Flush from that Read must not overlap a header write.
type mitmUploadWriter struct {
	mu sync.Mutex
	w  *bufio.Writer
}

func newMitmUploadWriter(w io.Writer) *mitmUploadWriter {
	return &mitmUploadWriter{w: bufio.NewWriterSize(w, 16<<10)}
}
func (u *mitmUploadWriter) Write(p []byte) (int, error) {
	u.mu.Lock()
	defer u.mu.Unlock()
	return u.w.Write(p)
}
func (u *mitmUploadWriter) WriteByte(c byte) error {
	u.mu.Lock()
	defer u.mu.Unlock()
	return u.w.WriteByte(c)
}
func (u *mitmUploadWriter) WriteString(s string) (int, error) {
	u.mu.Lock()
	defer u.mu.Unlock()
	return u.w.WriteString(s)
}
func (u *mitmUploadWriter) Flush() error {
	u.mu.Lock()
	defer u.mu.Unlock()
	return u.w.Flush()
}

// Writes a response that has no body by definition (1xx, 204, 304, or any
// answer to HEAD) with the headers as received. Response.Write would invent
// "Content-Length: 0" for answers to POST/PUT/PATCH (forbidden on 1xx/204)
// and drop the Content-Length of a 304 or a HEAD answer.
func mitmWriteHeaderOnly(w io.Writer, resp *http.Response, method string) error {
	header := resp.Header.Clone()
	if resp.StatusCode < 200 || resp.StatusCode == http.StatusNoContent {
		header.Del("Content-Length")
		header.Del("Transfer-Encoding")
	} else if method == http.MethodHead && len(resp.TransferEncoding) > 0 {
		// net/http moves Transfer-Encoding out of the header map.
		header["Transfer-Encoding"] = resp.TransferEncoding
	}
	reason := strings.TrimSpace(strings.TrimPrefix(resp.Status, strconv.Itoa(resp.StatusCode)))
	var b bytes.Buffer
	fmt.Fprintf(&b, "HTTP/1.1 %03d %s\r\n", resp.StatusCode, reason)
	if err := header.Write(&b); err != nil {
		return err
	}
	b.WriteString("\r\n")
	_, err := w.Write(b.Bytes())
	return err
}

func mitmHeaderOnly(resp *http.Response, method string) bool {
	return method == http.MethodHead || resp.StatusCode < 200 ||
		resp.StatusCode == http.StatusNoContent || resp.StatusCode == http.StatusNotModified
}

// What ends a session cleanly at a message boundary, when no request or
// response is in flight: the client or the site closing (with or without
// close_notify), resetting, or staying idle past the timeout. Nothing can
// be truncated there, so the client gets a close_notify and no failure is
// reported. Unsolicited upstream bytes are an error, except a 408, which
// servers send as they drop an idle keep-alive connection.
func mitmUpstreamIdleEnd(err error, responses *bufio.Reader) error {
	if err != nil {
		return nil
	}
	n := responses.Buffered()
	if n > 12 {
		n = 12
	}
	b, _ := responses.Peek(n)
	if len(b) == 12 && (bytes.HasPrefix(b, []byte("HTTP/1.1 408")) || bytes.HasPrefix(b, []byte("HTTP/1.0 408"))) {
		return nil
	}
	return errMitmHTTP1
}

// The request body as the upload worker reads it: flushes pending upstream
// bytes before blocking on the client, and never drains on Close.
type mitmUploadBody struct {
	body   io.Reader
	writer *mitmUploadWriter
}

func (b mitmUploadBody) Read(p []byte) (int, error) {
	if err := b.writer.Flush(); err != nil {
		return 0, err
	}
	return b.body.Read(p)
}
func (mitmUploadBody) Close() error { return nil }

type mitmDuplexControl struct {
	client, upstream *mitmIdleConn
	// The tracker ID the exchanges are recorded under; none when empty.
	connection string
	// Optional nonblocking observer, used to synchronize exchange tests.
	uploadComplete func(error)
	// The port the flow was to; 0 for the scheme's default.
	port uint16
	// Plain HTTP (port 80), served only for URL Rewrite's reject and
	// redirects: nothing else is rewritten and only answered requests are
	// recorded.
	plain bool
}

func (c *mitmDuplexControl) flowPort() uint16 {
	if c == nil {
		return 0
	}
	return c.port
}

func (c *mitmDuplexControl) isPlain() bool {
	return c != nil && c.plain
}

func (c *mitmDuplexControl) uploaded(err error) {
	if c != nil && c.uploadComplete != nil {
		c.uploadComplete(err)
	}
}

// Interrupt only the request direction: client reads and upstream writes.
// The response direction stays usable for forwarding an early final response.
func (c *mitmDuplexControl) stopUpload() {
	if c == nil {
		return
	}
	if err := c.client.interruptRead(); err != nil {
		_ = c.client.Conn.Close()
	}
	if err := c.upstream.interruptWrite(); err != nil {
		_ = c.upstream.Conn.Close()
	}
}
func (c *mitmDuplexControl) stopClientRead() {
	if c != nil {
		if err := c.client.interruptRead(); err != nil {
			_ = c.client.Conn.Close()
		}
	}
}
func (c *mitmDuplexControl) stopUpstreamRead() {
	if c != nil {
		if err := c.upstream.interruptRead(); err != nil {
			_ = c.upstream.Conn.Close()
		}
	}
}

// An exchange starts on an upstream read that may have been waiting since
// the connection went idle; give it a full idle period from now.
func (c *mitmDuplexControl) exchangeStarted() {
	if c != nil {
		c.upstream.extendRead(time.Now())
	}
}

func (c *mitmDuplexControl) captureConnection() string {
	if c == nil {
		return ""
	}
	return c.connection
}

func (c *mitmDuplexControl) stopAll() {
	if c == nil {
		return
	}
	c.stopUpload()
	if err := c.client.interruptWrite(); err != nil {
		_ = c.client.Conn.Close()
	}
	if err := c.upstream.interruptRead(); err != nil {
		_ = c.upstream.Conn.Close()
	}
}

type mitmResponseResult struct {
	response *http.Response
	err      error
}

// One exchange at a time, full duplex within it: no retries, replay, CONNECT
// or upgrades; Expect is limited to 100-continue. Each request is
// re-serialized once by an upload worker while the coordinator reads the
// upstream response, so 1xx and early final responses (401/413 before the
// body ends) reach the client without waiting for the upload. An early final
// response stops the upload, forces Connection: close and ends the session;
// neither connection is reused unless the request and the response both
// completed. Bodies stream; nothing is buffered beyond the header limit.
// The caller owns the TLS connections and closes them only after every
// worker has stopped. Exactly one goroutine reads upstream at any moment.
// A nil control is accepted only by tests whose peers never block.
func mitmHTTP1Duplex(client, upstream io.ReadWriter, host string, allowed func() bool, control *mitmDuplexControl) (result error) {
	// The exchange in progress, if capture records it; whatever ends the
	// session ends its record too.
	var entry *mitmCaptureEntry
	defer func() { mitmCaptures.fail(entry, result) }()
	requests := bufio.NewReaderSize(client, mitmHTTPHeaderLimit)
	responses := bufio.NewReaderSize(upstream, mitmHTTPHeaderLimit)
	// Between exchanges the watcher is the one upstream reader: it only
	// peeks, so a response that begins later is still intact for the next
	// exchange, which takes the watcher over before reading.
	var watch chan error
	stopWatch := func() {
		if watch != nil {
			control.stopUpstreamRead()
			<-watch
			watch = nil
		}
	}
	for {
		if !allowed() {
			stopWatch()
			return errMitmSetupChanged
		}
		if watch == nil {
			watch = make(chan error, 1)
			go func(watch chan error) {
				_, err := responses.Peek(1)
				watch <- err
			}(watch)
		}
		header := make(chan error, 1)
		go func() { header <- mitmPeekHeader(requests) }()
		select {
		case err := <-header:
			if err != nil {
				stopWatch()
				if !allowed() {
					return errMitmSetupChanged
				}
				if requests.Buffered() == 0 {
					// Client closed or idled out between requests (D4).
					return nil
				}
				return err
			}
			select {
			case err := <-watch:
				// The site left before this request could be sent; end as the
				// site did, without sending it.
				watch = nil
				return mitmUpstreamIdleEnd(err, responses)
			default:
			}
		case err := <-watch:
			// The site closed (or spoke) while idle: pass the close on now
			// rather than let the client reuse a dead session (D3).
			watch = nil
			control.stopClientRead()
			<-header
			if !allowed() {
				return errMitmSetupChanged
			}
			// A request that had begun arriving goes unanswered, as it would
			// have from the site itself.
			return mitmUpstreamIdleEnd(err, responses)
		}
		pendingWatch := watch
		watch = nil
		control.exchangeStarted()
		req, err := http.ReadRequest(requests)
		if err != nil {
			<-joinWatch(control, pendingWatch)
			return err
		}
		if req.ProtoMajor != 1 || req.ProtoMinor != 1 || req.Method == http.MethodConnect || req.URL.IsAbs() || req.URL.Host != "" || mitmRequestHost(req.Host) != host || req.Header.Get("Upgrade") != "" {
			<-joinWatch(control, pendingWatch)
			return errMitmHTTP1
		}
		if expect, present := req.Header["Expect"]; present && (len(expect) != 1 || !strings.EqualFold(strings.TrimSpace(expect[0]), "100-continue")) {
			<-joinWatch(control, pendingWatch)
			return errMitmHTTP1
		}
		if !allowed() {
			<-joinWatch(control, pendingWatch)
			return errMitmSetupChanged
		}
		scheme := "https"
		if control.isPlain() {
			scheme = "http"
		}
		rw := mitmRewriteBegin(scheme, host, control.flowPort(), req.RequestURI, control.isPlain())
		decision := rw.request(req.Header)
		if decision.drop {
			<-joinWatch(control, pendingWatch)
			entry = mitmCaptures.beginScheme(control.captureConnection(), scheme, host, req)
			mitmCaptures.noteRewrite(entry, rw)
			mitmCaptures.finish(entry, mitmExchangeDropped)
			return nil
		}
		if decision.local != nil {
			entry = mitmCaptures.beginScheme(control.captureConnection(), scheme, host, req)
			mitmCaptures.noteRewrite(entry, rw)
			keep, err := mitmAnswerHTTP1(client, req, decision.local, entry)
			if err != nil || !keep {
				<-joinWatch(control, pendingWatch)
				return err
			}
			// The site was never asked; the idle watch carries on.
			watch = pendingWatch
			continue
		}
		if decision.requestURI != "" {
			if target, err := url.ParseRequestURI(decision.requestURI); err == nil {
				req.URL, req.RequestURI = target, decision.requestURI
			}
		}
		if !control.isPlain() {
			entry = mitmCaptures.beginScheme(control.captureConnection(), scheme, host, req)
			mitmCaptures.noteRewrite(entry, rw)
		}
		if _, present := req.Header["User-Agent"]; !present {
			req.Header["User-Agent"] = []string{""}
		}
		originalBody := req.Body
		if rules := rw.bodyRules(false); len(rules) > 0 {
			if len(req.TransferEncoding) > 0 || req.Header.Get("Expect") != "" {
				// As Surge: chunked or 100-continue uploads go on unchanged.
				rw.skipAll(rules, "request", mitmSkipFraming)
			} else {
				result := rw.rewriteBody(rules, req.Header, req.Body, req.ContentLength, false)
				switch {
				case result.changed && result.length == 0:
					req.Header.Del("Content-Encoding")
					req.Body, req.ContentLength = http.NoBody, 0
				case result.changed:
					mitmRewrittenBodyHeader(req.Header, result.length)
					req.Body, req.ContentLength = io.NopCloser(result.body), result.length
				case req.Body != nil && req.Body != http.NoBody:
					req.Body = io.NopCloser(result.body)
				}
			}
			mitmCaptures.noteRewrite(entry, rw)
		}
		uploadWriter := newMitmUploadWriter(upstream)
		// http.NoBody must stay as it is: any other body with length 0 makes
		// Request.Write send "Transfer-Encoding: chunked" for POST/PUT/PATCH
		// instead of the client's "Content-Length: 0".
		if req.Body != nil && req.Body != http.NoBody {
			var body io.Reader = req.Body
			if entry != nil {
				body = mitmCaptureReader{r: body, entry: entry}
			}
			req.Body = mitmUploadBody{body: body, writer: uploadWriter}
		}
		// ReadResponse consults only the immutable request method, not the live
		// request whose Body and trailers are in use by the upload goroutine.
		responseRequest := &http.Request{Method: req.Method}
		upload := make(chan error, 1)
		go func() {
			err := req.Write(uploadWriter)
			if err == nil {
				err = uploadWriter.Flush()
			}
			upload <- err
		}()
		readResponse := func() <-chan mitmResponseResult {
			result := make(chan mitmResponseResult, 1)
			wait := pendingWatch
			pendingWatch = nil
			go func() {
				if wait != nil {
					if err := <-wait; err != nil {
						result <- mitmResponseResult{err: err}
						return
					}
				}
				if err := mitmPeekHeader(responses); err != nil {
					result <- mitmResponseResult{err: err}
					return
				}
				r, err := http.ReadResponse(responses, responseRequest)
				result <- mitmResponseResult{response: r, err: err}
			}()
			return result
		}
		response := readResponse()
		uploadPending, responsePending := true, true
		var uploadErr error
		// All exits join both workers after cancelling their blocked directions.
		join := func() {
			control.stopAll()
			if uploadPending {
				<-upload
				uploadPending = false
			}
			if responsePending {
				<-response
				responsePending = false
			}
		}
		var failureTimer *time.Timer
		var failure <-chan time.Time
		interim := 0
		for {
			select {
			case err := <-upload:
				uploadPending = false
				uploadErr = err
				control.uploaded(err)
				upload = nil
				if err != nil {
					failureTimer = time.NewTimer(time.Second)
					failure = failureTimer.C
				}
			case result := <-response:
				responsePending = false
				if result.err != nil {
					if failureTimer != nil {
						failureTimer.Stop()
					}
					join()
					return result.err
				}
				resp := result.response
				if control.isPlain() && resp.ProtoMajor == 1 && resp.ProtoMinor == 0 {
					// Plain sites still answer in HTTP/1.0; the client asked in
					// HTTP/1.1, and the session ends with this response.
					resp.Proto, resp.ProtoMinor, resp.Close = "HTTP/1.1", 1, true
				}
				if resp.ProtoMajor != 1 || resp.ProtoMinor != 1 || resp.StatusCode == http.StatusSwitchingProtocols || resp.Header.Get("Upgrade") != "" {
					if failureTimer != nil {
						failureTimer.Stop()
					}
					join()
					return errMitmHTTP1
				}
				if resp.StatusCode < 200 {
					if interim >= 8 {
						if failureTimer != nil {
							failureTimer.Stop()
						}
						join()
						return errMitmHTTP1
					}
					interim++
					// A client can stop reading an interim response while the upload
					// fails. Keep observing upload failure and its bounded grace period
					// rather than blocking the coordinator in Response.Write.
					written := make(chan error, 1)
					go func() {
						err := mitmWriteHeaderOnly(client, resp, req.Method)
						if err == nil {
							err = resp.Body.Close()
						}
						written <- err
					}()
				interimWrite:
					for {
						select {
						case err := <-written:
							if err != nil {
								if failureTimer != nil {
									failureTimer.Stop()
								}
								join()
								return err
							}
							break interimWrite
						case err := <-upload:
							uploadPending = false
							uploadErr = err
							control.uploaded(err)
							upload = nil
							if err != nil {
								failureTimer = time.NewTimer(time.Second)
								failure = failureTimer.C
							}
						case <-failure:
							control.stopAll()
							<-written
							join()
							return uploadErr
						}
					}
					response = readResponse()
					responsePending = true
					continue
				}
				if failureTimer != nil {
					failureTimer.Stop()
				}
				var rewrittenBody io.Reader
				if rw != nil && !rw.plain {
					rw.responseHeader(resp.Header)
					if rules := rw.bodyRules(true); len(rules) == 0 || mitmHeaderOnly(resp, req.Method) {
					} else if !mitmUploadSettles(upload, &uploadPending, &uploadErr, control) {
						// The site answers while the client is still sending:
						// holding the answer back to rewrite it could stall a
						// client that waits for it, so it streams on unchanged.
						if !uploadPending {
							upload = nil
						}
						rw.skipAll(rules, "response", mitmSkipUploading)
					} else {
						upload = nil
						result := rw.rewriteBody(rules, resp.Header, resp.Body, resp.ContentLength, true)
						rewrittenBody = result.body
						if result.changed {
							mitmRewrittenBodyHeader(resp.Header, result.length)
							resp.ContentLength, resp.TransferEncoding, resp.Trailer = result.length, nil, nil
						}
					}
					mitmCaptures.noteRewrite(entry, rw)
				}
				mitmCaptures.respond(entry, resp)
				// Conservatively allow reuse only when completed upload is observable.
				if uploadPending {
					select {
					case uploadErr = <-upload:
						uploadPending = false
						control.uploaded(uploadErr)
						upload = nil
					default:
					}
				}
				early := uploadPending || uploadErr != nil
				if early {
					control.stopUpload()
					resp.Close = true
					resp.Header.Set("Connection", "close")
				}
				// A TLS client may accept a bare downstream EOF even without a
				// close_notify. Reframe EOF-delimited upstream bodies as chunked
				// so truncation cannot look like a complete HTTP message. Go's
				// writer emits the terminal chunk only after the body reaches EOF;
				// the upstream TLS wrapper makes that EOF authenticated.
				if resp.ContentLength < 0 && len(resp.TransferEncoding) == 0 && req.Method != http.MethodHead && resp.StatusCode != http.StatusNoContent && resp.StatusCode != http.StatusNotModified {
					resp.TransferEncoding = []string{"chunked"}
				}
				originalResponseBody := resp.Body
				if resp.Body != nil {
					var body io.Reader = resp.Body
					if rewrittenBody != nil {
						body = rewrittenBody
					}
					if entry != nil {
						body = mitmCaptureReader{r: body, entry: entry, response: true}
					}
					resp.Body = mitmNoDrainBody{body}
				}
				var err error
				if mitmHeaderOnly(resp, req.Method) {
					err = mitmWriteHeaderOnly(client, resp, req.Method)
				} else {
					err = resp.Write(client)
				}
				if err == nil && originalResponseBody != nil {
					err = originalResponseBody.Close()
				}
				if err != nil {
					join()
					return err
				}
				mitmCaptures.finish(entry, "")
				if early {
					if uploadPending {
						<-upload
						uploadPending = false
					}
					return nil
				}
				if originalBody != nil {
					if err = originalBody.Close(); err != nil {
						return err
					}
				}
				if req.Close || resp.Close {
					return nil
				}
				if !allowed() {
					return errMitmSetupChanged
				}
				goto nextExchange
			case <-failure:
				join()
				return uploadErr
			}
		}
	nextExchange:
	}
}

// Joins an idle watcher that an exchange took over but never handed to a
// response reader, interrupting the upstream read it is blocked in.
// How long a response to be rewritten waits for the upload it answers to
// finish: a site normally answers once it has read the whole request, as
// the upload's last write returns.
var mitmUploadSettleWait = 200 * time.Millisecond

// Whether the upload has finished, or does within mitmUploadSettleWait,
// without error. A result read here is taken as the duplex loop takes it;
// an upload still running stays pending for the loop.
func mitmUploadSettles(upload chan error, pending *bool, uploadErr *error, control *mitmDuplexControl) bool {
	if !*pending {
		return *uploadErr == nil
	}
	timer := time.NewTimer(mitmUploadSettleWait)
	defer timer.Stop()
	select {
	case err := <-upload:
		*pending, *uploadErr = false, err
		control.uploaded(err)
		return err == nil
	case <-timer.C:
		return false
	}
}

func joinWatch(control *mitmDuplexControl, watch chan error) <-chan error {
	if watch == nil {
		closed := make(chan error)
		close(closed)
		return closed
	}
	control.stopUpstreamRead()
	return watch
}

// The most of a request body read and dropped so a locally answered
// request can keep its connection; a larger or unframed one closes it.
const mitmLocalDrainLimit = 1 << 20

// Answers req with local (reject, redirect, Map Local) without the site.
// keep reports whether the connection can take the next request.
func mitmAnswerHTTP1(client io.Writer, req *http.Request, local *mitmLocalResponse, entry *mitmCaptureEntry) (keep bool, err error) {
	keep = !req.Close
	if req.Body != nil && req.Body != http.NoBody {
		if _, expect := req.Header["Expect"]; expect || req.ContentLength < 0 || req.ContentLength > mitmLocalDrainLimit {
			keep = false
		} else if _, err := io.Copy(io.Discard, req.Body); err != nil {
			return false, err
		}
	}
	resp := local.http1()
	resp.Request = req
	if !keep {
		resp.Close = true
	}
	mitmCaptures.respond(entry, resp)
	mitmCaptures.write(entry, true, local.body)
	if req.Method == http.MethodHead {
		resp.Header.Set("Content-Length", strconv.Itoa(len(local.body)))
		if !keep {
			resp.Header.Set("Connection", "close")
		}
		err = mitmWriteHeaderOnly(client, resp, req.Method)
	} else {
		err = resp.Write(client)
	}
	if err != nil {
		return false, err
	}
	mitmCaptures.finish(entry, "")
	return keep, nil
}
