package core

import (
	"errors"
	"slices"
	"time"

	N "github.com/metacubex/mihomo/common/net"
)

type mitmClientHello struct {
	serverName string
	// nil when the client offered no ALPN.
	alpn []string
}

// A client that names protocols but not HTTP/1.1 (gRPC, an h2-only stack)
// can be served only over HTTP/2, when HTTP/2 decryption is on.
func (hello mitmClientHello) speaksHTTP1() bool {
	return hello.alpn == nil || slices.Contains(hello.alpn, "http/1.1")
}

func (hello mitmClientHello) speaksHTTP2() bool {
	return slices.Contains(hello.alpn, mitmALPNHTTP2)
}

// Whether decryption can serve this client at all: HTTP/1.1 always, HTTP/2
// only while it is turned on.
func (hello mitmClientHello) decryptable(http2 bool) bool {
	return hello.speaksHTTP1() || http2 && hello.speaksHTTP2()
}

// Variables only so socket tests can shorten the waits.
var (
	// The whole peek, first byte to the end of the hello. A TLS client sends
	// its ClientHello as its first flight, at once, and the leg it crosses
	// here is the local one (TUN or a loopback/LAN inbound), already set up
	// before the tunnel sees the connection; the tunnel's own 200 ms peek has
	// run too. A hello still missing after this is passed through untouched
	// (a listed host visibly), never failed, so a short bound only costs
	// decryption of an odd client, while a long one holds every such flow.
	mitmHelloWait = 750 * time.Millisecond
	// The longest a flow on 443 waits for its first packet before it is
	// dialled as it is: a client that has not spoken by then is not sending
	// a ClientHello that could be decrypted in time anyway.
	mitmFirstByteWait = 300 * time.Millisecond
)

// The tunnel's own asynchronous first-byte peek (tunnel.go), already spent
// when a hook runs after it.
const mitmTunnelPeekWait = 200 * time.Millisecond

var errMitmNotHello = errors.New("not a TLS ClientHello")

// The bytes began a TLS handshake record but no ClientHello could be read
// within the wait or the peek buffer: a slow/partial record, a truncated
// stream, or an oversized hello. The connection is passed through with an
// explicit outcome rather than silently.
var errMitmHelloUnsupported = errors.New("partial or oversized TLS ClientHello")

// Reads the ClientHello without consuming it, so a connection left alone
// still carries every byte the client sent. A hello split over several
// handshake records is reassembled within the peek buffer and returned as
// usual; only the record framing differs from a single-record hello.
func peekMitmClientHello(conn *N.BufferedConn) (mitmClientHello, error) {
	return peekMitmClientHelloWithin(conn, mitmHelloWait)
}

// firstByteWait bounds the wait for the first byte separately, so that a
// protocol where the server speaks first is not held for the whole hello
// wait; once a byte is in, the rest of the hello gets mitmHelloWait.
func peekMitmClientHelloWithin(conn *N.BufferedConn, firstByteWait time.Duration) (mitmClientHello, error) {
	defer conn.SetReadDeadline(time.Time{})
	// One bound for the whole peek, so a slow first byte cannot add a second
	// full wait for the rest.
	deadline := time.Now().Add(mitmHelloWait)
	if firstByteWait < mitmHelloWait && conn.Reader().Buffered() == 0 {
		_ = conn.SetReadDeadline(time.Now().Add(firstByteWait))
		if _, err := conn.Peek(1); err != nil {
			return mitmClientHello{}, err
		}
	}
	_ = conn.SetReadDeadline(deadline)
	// Accumulate handshake fragments only within BufferedConn's peek capacity;
	// Peek never consumes bytes, including for malformed or oversized records.
	var handshake []byte
	offset, records := 0, 0
	for {
		if offset+5 > conn.Reader().Size() {
			return mitmClientHello{}, errMitmHelloUnsupported
		}
		header, err := conn.Peek(offset + 5)
		if err != nil {
			// Only a recognized TLS handshake prefix is reported; other
			// protocols that are merely slow are left alone without a warning.
			if records > 0 || mitmLooksLikeTLSRecord(header) {
				return mitmClientHello{}, errMitmHelloUnsupported
			}
			return mitmClientHello{}, err
		}
		h := header[offset:]
		if h[0] != 0x16 || h[1] != 0x03 {
			return mitmClientHello{}, errMitmNotHello
		}
		length := int(h[3])<<8 | int(h[4])
		if length == 0 {
			return mitmClientHello{}, errMitmNotHello
		}
		if offset+5+length > conn.Reader().Size() {
			return mitmClientHello{}, errMitmHelloUnsupported
		}
		record, err := conn.Peek(offset + 5 + length)
		if err != nil {
			// A TLS record header was recognized; preserve bytes and report
			// the incomplete/slow record rather than silently passing it on.
			return mitmClientHello{}, errMitmHelloUnsupported
		}
		handshake = append(handshake, record[offset+5:offset+5+length]...)
		offset += 5 + length
		records++
		if len(handshake) < 4 {
			continue
		}
		if handshake[0] != 1 {
			return mitmClientHello{}, errMitmNotHello
		}
		size := 4 + (int(handshake[1])<<16 | int(handshake[2])<<8 | int(handshake[3]))
		if size > conn.Reader().Size() {
			return mitmClientHello{}, errMitmHelloUnsupported
		}
		if len(handshake) < size {
			continue
		}
		hello, err := parseMitmClientHello(handshake[:size])
		return hello, err
	}
}

func mitmLooksLikeTLSRecord(prefix []byte) bool {
	switch len(prefix) {
	case 0:
		return false
	case 1:
		return prefix[0] == 0x16
	default:
		return prefix[0] == 0x16 && prefix[1] == 0x03
	}
}

type mitmReader struct {
	data []byte
	bad  bool
}

func (r *mitmReader) bytes(n int) []byte {
	if r.bad || n < 0 || n > len(r.data) {
		r.bad = true
		return nil
	}
	out := r.data[:n]
	r.data = r.data[n:]
	return out
}

func (r *mitmReader) uint(n int) int {
	value := 0
	for _, b := range r.bytes(n) {
		value = value<<8 | int(b)
	}
	return value
}

func (r *mitmReader) vector(lengthBytes int) *mitmReader {
	return &mitmReader{data: r.bytes(r.uint(lengthBytes)), bad: r.bad}
}

// Parses a bounded handshake reassembled across one or more TLS records.
func parseMitmClientHello(handshake []byte) (mitmClientHello, error) {
	r := &mitmReader{data: handshake}
	if r.uint(1) != 1 {
		return mitmClientHello{}, errMitmNotHello
	}
	body := r.vector(3)
	body.bytes(2 + 32)
	body.vector(1)
	body.vector(2)
	body.vector(1)
	var hello mitmClientHello
	seenSNI, seenALPN := false, false
	if len(body.data) == 0 {
		return hello, nilIfGood(body, r)
	}
	extensions := body.vector(2)
	for !extensions.bad && len(extensions.data) > 0 {
		kind := extensions.uint(2)
		data := extensions.vector(2)
		switch kind {
		case 0:
			if seenSNI {
				return mitmClientHello{}, errMitmNotHello
			}
			seenSNI = true
			names := data.vector(2)
			for !names.bad && len(names.data) > 0 {
				nameType := names.uint(1)
				name := names.vector(2)
				if name.bad || (nameType == 0 && (hello.serverName != "" || len(name.data) == 0)) {
					return mitmClientHello{}, errMitmNotHello
				}
				if nameType == 0 {
					hello.serverName = string(name.data)
				}
			}
			extensions.bad = extensions.bad || names.bad || len(data.data) != 0
		case 16:
			if seenALPN {
				return mitmClientHello{}, errMitmNotHello
			}
			seenALPN = true
			protocols := data.vector(2)
			hello.alpn = []string{}
			for !protocols.bad && len(protocols.data) > 0 {
				protocol := protocols.vector(1)
				if protocol.bad || len(protocol.data) == 0 {
					return mitmClientHello{}, errMitmNotHello
				}
				hello.alpn = append(hello.alpn, string(protocol.data))
			}
			extensions.bad = extensions.bad || protocols.bad || len(data.data) != 0 || len(hello.alpn) == 0
		}
		extensions.bad = extensions.bad || data.bad
	}
	if len(body.data) != 0 || len(r.data) != 0 {
		return mitmClientHello{}, errMitmNotHello
	}
	return hello, nilIfGood(body, r, extensions)
}

func nilIfGood(readers ...*mitmReader) error {
	for _, r := range readers {
		if r.bad {
			return errMitmNotHello
		}
	}
	return nil
}
