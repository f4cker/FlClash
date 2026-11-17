package core

import (
	"bufio"
	"bytes"
	"errors"
	"io"
	"net"
	"net/http"
	"strings"
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
type mitmUploadWriter struct{ w *bufio.Writer }

func newMitmUploadWriter(w io.Writer) *mitmUploadWriter {
	return &mitmUploadWriter{w: bufio.NewWriterSize(w, 16<<10)}
}
func (u *mitmUploadWriter) Write(p []byte) (int, error)       { return u.w.Write(p) }
func (u *mitmUploadWriter) WriteByte(c byte) error            { return u.w.WriteByte(c) }
func (u *mitmUploadWriter) WriteString(s string) (int, error) { return u.w.WriteString(s) }
func (u *mitmUploadWriter) Flush() error                      { return u.w.Flush() }

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
	// Optional nonblocking observer, used to synchronize exchange tests.
	uploadComplete func(error)
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
func mitmHTTP1Duplex(client, upstream io.ReadWriter, host string, allowed func() bool, control *mitmDuplexControl) error {
	requests := bufio.NewReaderSize(client, mitmHTTPHeaderLimit)
	responses := bufio.NewReaderSize(upstream, mitmHTTPHeaderLimit)
	for {
		if !allowed() {
			return errMitmSetupChanged
		}
		if err := mitmPeekHeader(requests); err != nil {
			if errors.Is(err, io.EOF) && requests.Buffered() == 0 {
				return nil
			}
			return err
		}
		req, err := http.ReadRequest(requests)
		if err != nil {
			return err
		}
		if req.ProtoMajor != 1 || req.ProtoMinor != 1 || req.Method == http.MethodConnect || req.URL.IsAbs() || req.URL.Host != "" || mitmRequestHost(req.Host) != host || req.Header.Get("Upgrade") != "" {
			return errMitmHTTP1
		}
		if expect, present := req.Header["Expect"]; present && (len(expect) != 1 || !strings.EqualFold(strings.TrimSpace(expect[0]), "100-continue")) {
			return errMitmHTTP1
		}
		if !allowed() {
			return errMitmSetupChanged
		}
		if _, present := req.Header["User-Agent"]; !present {
			req.Header["User-Agent"] = []string{""}
		}
		originalBody := req.Body
		uploadWriter := newMitmUploadWriter(upstream)
		if req.Body != nil {
			req.Body = mitmUploadBody{body: req.Body, writer: uploadWriter}
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
			go func() {
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
						err := resp.Write(client)
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
					resp.Body = mitmNoDrainBody{resp.Body}
				}
				err := resp.Write(client)
				if err == nil && originalResponseBody != nil {
					err = originalResponseBody.Close()
				}
				if err != nil {
					join()
					return err
				}
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
