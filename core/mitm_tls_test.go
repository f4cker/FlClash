package core

import (
	"bufio"
	"bytes"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"errors"
	"fmt"
	"io"
	"math/big"
	"net"
	"net/http"
	"sync/atomic"
	"testing"
	"time"

	N "github.com/metacubex/mihomo/common/net"
	C "github.com/metacubex/mihomo/constant"
)

// Only ephemeral Go keys and DER in memory: no keychain, files or listeners.
func mitmTestIdentity(t *testing.T) (tls.Certificate, *x509.CertPool) {
	t.Helper()
	rootKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	now := time.Now()
	rootTemplate := &x509.Certificate{SerialNumber: big.NewInt(1), Subject: pkix.Name{CommonName: "in-memory test root"}, NotBefore: now.Add(-time.Hour), NotAfter: now.Add(time.Hour), IsCA: true, BasicConstraintsValid: true, KeyUsage: x509.KeyUsageCertSign}
	rootDER, err := x509.CreateCertificate(rand.Reader, rootTemplate, rootTemplate, &rootKey.PublicKey, rootKey)
	if err != nil {
		t.Fatal(err)
	}
	root, err := x509.ParseCertificate(rootDER)
	if err != nil {
		t.Fatal(err)
	}
	leafKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	template := &x509.Certificate{SerialNumber: big.NewInt(2), DNSNames: []string{"example.com"}, NotBefore: now.Add(-time.Hour), NotAfter: now.Add(time.Hour), KeyUsage: x509.KeyUsageDigitalSignature, ExtKeyUsage: []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth}}
	der, err := x509.CreateCertificate(rand.Reader, template, root, &leafKey.PublicKey, rootKey)
	if err != nil {
		t.Fatal(err)
	}
	pool := x509.NewCertPool()
	pool.AddCert(root)
	return tls.Certificate{Certificate: [][]byte{der}, PrivateKey: leafKey}, pool
}

type mitmIDConn struct{ net.Conn }

func (mitmIDConn) ID() string { return "connection-1" }

func TestMitmTLSHTTP1InMemory(t *testing.T) {
	cert, roots := mitmTestIdentity(t)
	oldRoots, oldRuntime := mitmUpstreamRoots, mitmState.Load()
	defer func() { mitmActive.closeAll(); mitmUpstreamRoots = oldRoots; mitmState.Store(oldRuntime) }()
	mitmUpstreamRoots = roots
	runtime := &mitmRuntime{}
	mitmState.Store(runtime)
	clientRaw, mitmClient := net.Pipe()
	defer clientRaw.Close()
	defer mitmClient.Close()
	mitmRemote, siteRaw := net.Pipe()
	defer mitmRemote.Close()
	defer siteRaw.Close()
	deadline := time.Now().Add(3 * time.Second)
	for _, c := range []net.Conn{clientRaw, mitmClient, mitmRemote, siteRaw} {
		_ = c.SetDeadline(deadline)
	}
	siteDone := make(chan error, 1)
	go func() {
		site := tls.Server(siteRaw, &tls.Config{Certificates: []tls.Certificate{cert}, NextProtos: []string{"http/1.1"}})
		req, err := http.ReadRequest(bufio.NewReader(site))
		if err != nil {
			siteDone <- err
			return
		}
		if req.URL.Path != "/test" {
			siteDone <- errMitmHTTP1
			return
		}
		_, err = site.Write([]byte("HTTP/1.1 103 Early Hints\r\nLink: </a>; rel=preload\r\n\r\nHTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok"))
		siteDone <- err
	}()
	events := make(chan MitmConnection, 1)
	oldSend := sendMitmConnection
	sendMitmConnection = func(event *MitmConnection) bool { events <- *event; return true }
	defer func() { sendMitmConnection = oldSend }()
	outcome := make(chan MitmOutcome, 1)
	go func() {
		outcome <- serveMitm(mitmClient, mitmIDConn{mitmRemote}, "example.com", &mitmLeaf{cert: cert}, runtime)
	}()
	client := tls.Client(clientRaw, &tls.Config{ServerName: "example.com", RootCAs: roots, NextProtos: []string{"http/1.1"}})
	if _, err := client.Write([]byte("GET /test HTTP/1.1\r\nHost: example.com\r\nConnection: close\r\n\r\n")); err != nil {
		t.Fatal(err)
	}
	reader := bufio.NewReader(client)
	info, err := http.ReadResponse(reader, nil)
	if err != nil || info.StatusCode != 103 {
		t.Fatalf("interim response: %v %v", info, err)
	}
	resp, err := http.ReadResponse(reader, nil)
	if err != nil {
		t.Fatal(err)
	}
	body, err := io.ReadAll(resp.Body)
	if err != nil || string(body) != "ok" {
		t.Fatalf("body %q %v", body, err)
	}
	if err := <-siteDone; err != nil {
		t.Fatal(err)
	}
	if got := <-outcome; got != "" {
		t.Fatalf("outcome %q", got)
	}
	select {
	case event := <-events:
		if event.Id != "connection-1" || event.Outcome != mitmOutcomeDecrypted {
			t.Fatalf("event %+v", event)
		}
	default:
		t.Fatal("missing success event")
	}
}

func TestMitmTLSRejectsUntrustedUpstreamBeforeClientHandshake(t *testing.T) {
	cert, _ := mitmTestIdentity(t)
	oldRoots, oldRuntime := mitmUpstreamRoots, mitmState.Load()
	defer func() { mitmActive.closeAll(); mitmUpstreamRoots = oldRoots; mitmState.Store(oldRuntime) }()
	mitmUpstreamRoots = x509.NewCertPool()
	runtime := &mitmRuntime{}
	mitmState.Store(runtime)
	clientRaw, mitmClient := net.Pipe()
	defer clientRaw.Close()
	defer mitmClient.Close()
	// Loopback only: socket buffering avoids net.Pipe's mutual-write deadlock
	// when TLS sends a rejection alert during the server's handshake write.
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer listener.Close()
	siteDone := make(chan struct{})
	go func() {
		defer close(siteDone)
		c, err := listener.Accept()
		if err != nil {
			return
		}
		defer c.Close()
		_ = c.SetDeadline(time.Now().Add(3 * time.Second))
		_ = tls.Server(c, &tls.Config{Certificates: []tls.Certificate{cert}}).Handshake()
	}()
	mitmRemote, err := net.DialTimeout("tcp", listener.Addr().String(), 3*time.Second)
	if err != nil {
		t.Fatal(err)
	}
	defer mitmRemote.Close()
	_ = clientRaw.SetDeadline(time.Now().Add(3 * time.Second))
	events := make(chan MitmConnection, 1)
	oldSend := sendMitmConnection
	sendMitmConnection = func(event *MitmConnection) bool { events <- *event; return true }
	defer func() { sendMitmConnection = oldSend }()
	outcome := serveMitm(mitmClient, mitmIDConn{mitmRemote}, "example.com", &mitmLeaf{cert: cert}, runtime)
	select {
	case event := <-events:
		t.Fatalf("unexpected success event: %+v", event)
	default:
	}
	if outcome != mitmOutcomeUpstreamCertificate {
		t.Fatalf("outcome %q", outcome)
	}
	_ = mitmClient.Close()
	var b [1]byte
	if n, _ := clientRaw.Read(b[:]); n != 0 {
		t.Fatal("client received TLS bytes despite upstream verification failure")
	}
	<-siteDone
}

func TestMitmPrecommitDoesNotReportSuccess(t *testing.T) {
	old := mitmState.Load()
	defer mitmState.Store(old)
	stale := &mitmRuntime{}
	mitmState.Store(&mitmRuntime{})
	events := make(chan MitmConnection, 1)
	oldSend := sendMitmConnection
	sendMitmConnection = func(event *MitmConnection) bool { events <- *event; return true }
	defer func() { sendMitmConnection = oldSend }()
	client, clientPeer := net.Pipe()
	defer client.Close()
	defer clientPeer.Close()
	remote, remotePeer := net.Pipe()
	defer remote.Close()
	defer remotePeer.Close()
	if got := serveMitm(client, mitmIDConn{remote}, "example.com", &mitmLeaf{}, stale); got != mitmOutcomePrecommit {
		t.Fatalf("outcome %q", got)
	}
	select {
	case event := <-events:
		t.Fatalf("unexpected event %+v", event)
	default:
	}
}

func TestMitmClientRejectsCertificateWithoutSuccessEvent(t *testing.T) {
	cert, roots := mitmTestIdentity(t)
	oldRoots, oldRuntime, oldSend := mitmUpstreamRoots, mitmState.Load(), sendMitmConnection
	defer func() {
		mitmActive.closeAll()
		mitmUpstreamRoots = oldRoots
		mitmState.Store(oldRuntime)
		sendMitmConnection = oldSend
	}()
	mitmUpstreamRoots = roots
	runtime := &mitmRuntime{}
	mitmState.Store(runtime)
	events := make(chan MitmConnection, 1)
	sendMitmConnection = func(event *MitmConnection) bool { events <- *event; return true }
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer listener.Close()
	clientRaw, err := net.DialTimeout("tcp", listener.Addr().String(), time.Second)
	if err != nil {
		t.Fatal(err)
	}
	defer clientRaw.Close()
	mitmClient, err := listener.Accept()
	if err != nil {
		t.Fatal(err)
	}
	defer mitmClient.Close()
	mitmRemote, siteRaw := net.Pipe()
	defer mitmRemote.Close()
	defer siteRaw.Close()
	for _, c := range []net.Conn{clientRaw, mitmClient, mitmRemote, siteRaw} {
		_ = c.SetDeadline(time.Now().Add(3 * time.Second))
	}
	siteDone := make(chan error, 1)
	go func() {
		siteDone <- tls.Server(siteRaw, &tls.Config{Certificates: []tls.Certificate{cert}}).Handshake()
	}()
	done := make(chan MitmOutcome, 1)
	go func() {
		done <- serveMitm(mitmClient, mitmIDConn{mitmRemote}, "example.com", &mitmLeaf{cert: cert}, runtime)
	}()
	client := tls.Client(clientRaw, &tls.Config{ServerName: "example.com", RootCAs: x509.NewCertPool()})
	if err := client.Handshake(); err == nil {
		t.Fatal("client unexpectedly trusted interception certificate")
	}
	got := <-done
	if got != mitmOutcomeRefused && got != mitmOutcomeClientFailed {
		t.Fatalf("outcome %q", got)
	}
	if err := <-siteDone; err != nil {
		t.Fatalf("site handshake: %v", err)
	}
	select {
	case event := <-events:
		t.Fatalf("unexpected success %+v", event)
	default:
	}
}

func mitmLoopbackPair(t *testing.T) (net.Conn, net.Conn) {
	t.Helper()
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer l.Close()
	c, err := net.DialTimeout("tcp", l.Addr().String(), time.Second)
	if err != nil {
		t.Fatal(err)
	}
	s, err := l.Accept()
	if err != nil {
		c.Close()
		t.Fatal(err)
	}
	_ = c.SetDeadline(time.Now().Add(5 * time.Second))
	_ = s.SetDeadline(time.Now().Add(5 * time.Second))
	return c, s
}

func TestMitmTLSCloseDelimitedResponseHasCloseNotify(t *testing.T) {
	cert, roots := mitmTestIdentity(t)
	oldRoots, oldRuntime := mitmUpstreamRoots, mitmState.Load()
	defer func() { mitmActive.closeAll(); mitmUpstreamRoots = oldRoots; mitmState.Store(oldRuntime) }()
	mitmUpstreamRoots = roots
	runtime := &mitmRuntime{}
	mitmState.Store(runtime)
	clientRaw, proxyClient := mitmLoopbackPair(t)
	defer clientRaw.Close()
	defer proxyClient.Close()
	proxySite, siteRaw := mitmLoopbackPair(t)
	defer proxySite.Close()
	defer siteRaw.Close()
	siteDone := make(chan error, 1)
	go func() {
		site := tls.Server(siteRaw, &tls.Config{Certificates: []tls.Certificate{cert}})
		_, err := http.ReadRequest(bufio.NewReader(site))
		if err == nil {
			_, err = io.WriteString(site, "HTTP/1.1 200 OK\r\nConnection: close\r\n\r\nclose-delimited")
		}
		if closeErr := site.Close(); err == nil {
			err = closeErr
		}
		siteDone <- err
	}()
	proxyDone := make(chan MitmOutcome, 1)
	go func() { proxyDone <- serveMitm(proxyClient, proxySite, "example.com", &mitmLeaf{cert: cert}, runtime) }()
	client := tls.Client(clientRaw, &tls.Config{ServerName: "example.com", RootCAs: roots})
	if _, err := io.WriteString(client, "GET / HTTP/1.1\r\nHost: example.com\r\nConnection: close\r\n\r\n"); err != nil {
		t.Fatal(err)
	}
	resp, err := http.ReadResponse(bufio.NewReader(client), nil)
	if err != nil {
		t.Fatal(err)
	}
	body, err := io.ReadAll(resp.Body)
	if err != nil || string(body) != "close-delimited" {
		t.Fatalf("body %q error %v", body, err)
	}
	if got := <-proxyDone; got != "" {
		t.Fatalf("outcome %q", got)
	}
	if err := <-siteDone; err != nil {
		t.Fatalf("site: %v", err)
	}
}

// Split the client's first TLS handshake record without changing the
// handshake transcript. Subsequent traffic is forwarded normally.
type fragmentedHelloConn struct {
	net.Conn
	split bool
}

func (c *fragmentedHelloConn) Write(p []byte) (int, error) {
	if c.split || len(p) < 12 || p[0] != 0x16 {
		return c.Conn.Write(p)
	}
	size := int(p[3])<<8 | int(p[4])
	if size+5 != len(p) {
		return c.Conn.Write(p)
	}
	c.split = true
	cut := 7
	a := append([]byte{p[0], p[1], p[2], 0, byte(cut)}, p[5:5+cut]...)
	rest := p[5+cut:]
	b := append([]byte{p[0], p[1], p[2], byte(len(rest) >> 8), byte(len(rest))}, rest...)
	if _, err := c.Conn.Write(a); err != nil {
		return 0, err
	}
	if _, err := c.Conn.Write(b); err != nil {
		return 0, err
	}
	return len(p), nil
}

func TestMitmFragmentedHelloCompletesTLSAndHTTP(t *testing.T) {
	cert, roots := mitmTestIdentity(t)
	oldRoots, oldRuntime := mitmUpstreamRoots, mitmState.Load()
	defer func() { mitmActive.closeAll(); mitmUpstreamRoots = oldRoots; mitmState.Store(oldRuntime) }()
	mitmUpstreamRoots = roots
	runtime := &mitmRuntime{}
	mitmState.Store(runtime)
	clientRaw, proxyRaw := mitmLoopbackPair(t)
	defer clientRaw.Close()
	defer proxyRaw.Close()
	proxySite, siteRaw := mitmLoopbackPair(t)
	defer proxySite.Close()
	defer siteRaw.Close()
	siteDone := make(chan error, 1)
	go func() {
		site := tls.Server(siteRaw, &tls.Config{Certificates: []tls.Certificate{cert}})
		_, err := http.ReadRequest(bufio.NewReader(site))
		if err == nil {
			_, err = io.WriteString(site, "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok")
		}
		siteDone <- err
	}()
	done := make(chan error, 1)
	go func() {
		buffered := N.NewBufferedConn(proxyRaw)
		hello, err := peekMitmClientHello(buffered)
		if err != nil {
			done <- err
			return
		}
		if hello.serverName != "example.com" {
			done <- errMitmNotHello
			return
		}
		if outcome := serveMitm(buffered, proxySite, "example.com", &mitmLeaf{cert: cert}, runtime); outcome != "" {
			done <- errors.New(string(outcome))
			return
		}
		done <- nil
	}()
	fragmented := &fragmentedHelloConn{Conn: clientRaw}
	client := tls.Client(fragmented, &tls.Config{ServerName: "example.com", RootCAs: roots})
	if _, err := io.WriteString(client, "GET / HTTP/1.1\r\nHost: example.com\r\nConnection: close\r\n\r\n"); err != nil {
		t.Fatal(err)
	}
	resp, err := http.ReadResponse(bufio.NewReader(client), nil)
	if err != nil {
		t.Fatal(err)
	}
	body, err := io.ReadAll(resp.Body)
	if err != nil || string(body) != "ok" {
		t.Fatalf("body %q: %v", body, err)
	}
	if !fragmented.split {
		t.Fatal("client hello was not fragmented")
	}
	if err := <-siteDone; err != nil {
		t.Fatal(err)
	}
	if err := <-done; err != nil {
		t.Fatal(err)
	}
}

// Implements only the chain metadata used by the tunnel's interceptor type.
type mitmSelectionConn struct{ N.ExtendedConn }

func (c mitmSelectionConn) Chains() C.Chain               { return nil }
func (c mitmSelectionConn) ProviderChains() C.Chain       { return nil }
func (c mitmSelectionConn) AppendToChains(C.ProxyAdapter) {}
func (c mitmSelectionConn) RemoteDestination() string     { return "" }
func (c mitmSelectionConn) ID() string                    { return "selection-test" }

func TestMitmSelectorInterceptsFragmentedHello(t *testing.T) {
	app := newFakeMitmApp(t)
	withMitmSigner(t, app, []string{"example.com"}, func(req *MitmSignRequest) MitmSignResultParams {
		return MitmSignResultParams{Cert: app.leaf(t, req.Host, req.SPKI, nil), CA: app.ca.Raw}
	})
	defer func() { mitmActive.closeAll(); mitmLeaves.clear(); mitmPaused.Store(nil) }()
	siteCert, siteRoots := mitmTestIdentity(t)
	oldRoots := mitmUpstreamRoots
	defer func() { mitmUpstreamRoots = oldRoots }()
	mitmUpstreamRoots = siteRoots
	appRoots := x509.NewCertPool()
	appRoots.AddCert(app.ca)
	clientRaw, proxyRaw := mitmLoopbackPair(t)
	defer clientRaw.Close()
	defer proxyRaw.Close()
	proxySite, siteRaw := mitmLoopbackPair(t)
	defer proxySite.Close()
	defer siteRaw.Close()
	siteDone := make(chan error, 1)
	go func() {
		site := tls.Server(siteRaw, &tls.Config{Certificates: []tls.Certificate{siteCert}})
		_, err := http.ReadRequest(bufio.NewReader(site))
		if err == nil {
			_, err = io.WriteString(site, "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok")
		}
		siteDone <- err
	}()
	done := make(chan error, 1)
	go func() {
		client := N.NewBufferedConn(proxyRaw)
		selected := mitmInterceptEligible(client, &C.Metadata{Host: "example.com"})
		if selected == nil {
			done <- errors.New("selector returned passthrough")
			return
		}
		selected(client, mitmSelectionConn{N.NewExtendedConn(proxySite)})
		done <- nil
	}()
	fragmented := &fragmentedHelloConn{Conn: clientRaw}
	client := tls.Client(fragmented, &tls.Config{ServerName: "example.com", RootCAs: appRoots})
	if _, err := io.WriteString(client, "GET / HTTP/1.1\r\nHost: example.com\r\nConnection: close\r\n\r\n"); err != nil {
		t.Fatal(err)
	}
	response, err := http.ReadResponse(bufio.NewReader(client), nil)
	if err != nil {
		t.Fatal(err)
	}
	body, err := io.ReadAll(response.Body)
	if err != nil || string(body) != "ok" {
		t.Fatalf("body %q: %v", body, err)
	}
	if !fragmented.split {
		t.Fatal("hello not fragmented")
	}
	if err := <-siteDone; err != nil {
		t.Fatal(err)
	}
	if err := <-done; err != nil {
		t.Fatal(err)
	}
}

func TestMitmSelectorFragmentedHelloSignerUnavailableRelaysExactly(t *testing.T) {
	app := newFakeMitmApp(t)
	withMitmSigner(t, app, []string{"example.com"}, nil)
	defer func() { mitmActive.closeAll(); mitmLeaves.clear(); mitmPaused.Store(nil) }()
	oldSend := sendMitmSign
	sendMitmSign = func(*MitmSignRequest) bool { return false }
	defer func() { sendMitmSign = oldSend }()
	sni := []byte{0, 0, 0, 16, 0, 14, 0, 0, 11, 'e', 'x', 'a', 'm', 'p', 'l', 'e', '.', 'c', 'o', 'm'}
	hello := helloFixture(sni)
	record := func(b []byte) []byte { return append([]byte{0x16, 3, 3, byte(len(b) >> 8), byte(len(b))}, b...) }
	original := append(record(hello[:7]), record(hello[7:])...)
	original = append(original, []byte("later bytes")...)
	clientRaw, proxyRaw := mitmLoopbackPair(t)
	defer clientRaw.Close()
	defer proxyRaw.Close()
	proxySite, siteRaw := mitmLoopbackPair(t)
	defer proxySite.Close()
	defer siteRaw.Close()
	done := make(chan bool, 1)
	go func() {
		client := N.NewBufferedConn(proxyRaw)
		selected := mitmInterceptEligible(client, &C.Metadata{Host: "example.com"})
		if selected != nil {
			done <- false
			return
		}
		done <- true
		N.Relay(client, proxySite)
	}()
	if _, err := clientRaw.Write(original); err != nil {
		t.Fatal(err)
	}
	if !<-done {
		t.Fatal("unavailable signer selected interception")
	}
	got := make([]byte, len(original))
	if _, err := io.ReadFull(siteRaw, got); err != nil || !bytes.Equal(got, original) {
		t.Fatalf("relayed %x: %v", got, err)
	}
}

func TestMitmTLSCloseNotifyHasBoundAndHandlesConcurrentSocketClose(t *testing.T) {
	for _, tc := range []struct {
		name   string
		cancel bool
	}{{"stalled peer", false}, {"cancelled socket", true}} {
		t.Run(tc.name, func(t *testing.T) {
			cert, roots := mitmTestIdentity(t)
			serverRaw, clientRaw := net.Pipe()
			defer serverRaw.Close()
			defer clientRaw.Close()
			idle := &mitmIdleConn{Conn: serverRaw, timeout: mitmIdleTimeout}
			server := tls.Server(idle, &tls.Config{Certificates: []tls.Certificate{cert}})
			client := tls.Client(clientRaw, &tls.Config{ServerName: "example.com", RootCAs: roots})
			handshake := make(chan error, 1)
			go func() { handshake <- server.Handshake() }()
			if err := client.Handshake(); err != nil {
				t.Fatal(err)
			}
			if err := <-handshake; err != nil {
				t.Fatal(err)
			}
			idle.closing.Store(true)
			done := make(chan error, 1)
			started := time.Now()
			go func() { done <- server.Close() }()
			if tc.cancel {
				_ = serverRaw.Close()
			}
			select {
			case err := <-done:
				if err == nil {
					t.Fatal("expected failed alert on unread or closed pipe")
				}
				if time.Since(started) > 2*time.Second {
					t.Fatal("close notify exceeded bound")
				}
			case <-time.After(3 * time.Second):
				_ = serverRaw.Close()
				t.Fatal("close notify hung")
			}
		})
	}
}

func TestMitmTLSEarlyFinalResponseStopsUpload(t *testing.T) {
	for _, status := range []string{"401 Unauthorized", "413 Payload Too Large"} {
		t.Run(status, func(t *testing.T) {
			cert, roots := mitmTestIdentity(t)
			oldRoots, oldRuntime := mitmUpstreamRoots, mitmState.Load()
			defer func() { mitmActive.closeAll(); mitmUpstreamRoots = oldRoots; mitmState.Store(oldRuntime) }()
			mitmUpstreamRoots = roots
			runtime := &mitmRuntime{}
			mitmState.Store(runtime)
			clientRaw, proxyClient := mitmLoopbackPair(t)
			defer clientRaw.Close()
			defer proxyClient.Close()
			proxySite, siteRaw := mitmLoopbackPair(t)
			defer proxySite.Close()
			defer siteRaw.Close()
			release := make(chan struct{})
			defer close(release)
			siteDone := make(chan error, 1)
			go func() {
				site := tls.Server(siteRaw, &tls.Config{Certificates: []tls.Certificate{cert}})
				_, err := http.ReadRequest(bufio.NewReader(site))
				if err == nil {
					_, err = io.WriteString(site, "HTTP/1.1 103 Early Hints\r\nLink: </x>\r\n\r\nHTTP/1.1 "+status+"\r\nContent-Length: 3\r\n\r\nno!")
				}
				siteDone <- err
				<-release
				_ = site.Close()
			}()
			proxyDone := make(chan MitmOutcome, 1)
			go func() { proxyDone <- serveMitm(proxyClient, proxySite, "example.com", &mitmLeaf{cert: cert}, runtime) }()
			client := tls.Client(clientRaw, &tls.Config{ServerName: "example.com", RootCAs: roots})
			if _, err := io.WriteString(client, "POST / HTTP/1.1\r\nHost: example.com\r\nContent-Length: 1000000\r\n\r\npartial"); err != nil {
				t.Fatal(err)
			}
			reader := bufio.NewReader(client)
			early, err := http.ReadResponse(reader, nil)
			if err != nil || early.StatusCode != 103 {
				t.Fatalf("interim %v %v", early, err)
			}
			final, err := http.ReadResponse(reader, nil)
			if err != nil {
				t.Fatal(err)
			}
			body, err := io.ReadAll(final.Body)
			if err != nil || string(body) != "no!" || !final.Close {
				t.Fatalf("response %+v body=%q err=%v", final, body, err)
			}
			var closeByte [1]byte
			if _, err := client.Read(closeByte[:]); !errors.Is(err, io.EOF) {
				t.Fatalf("expected TLS close-notify EOF, got %v", err)
			}
			select {
			case result := <-proxyDone:
				if result != "" {
					t.Fatalf("outcome %q", result)
				}
			case <-time.After(2 * time.Second):
				t.Fatal("relay did not stop after early final")
			}
			if err := <-siteDone; err != nil {
				t.Fatal(err)
			}
		})
	}
}

func TestMitmDuplexTLSRuntimeAndLivenessShutdown(t *testing.T) {
	for _, mode := range []string{"runtime", "pause"} {
		t.Run(mode, func(t *testing.T) {
			cert, roots := mitmTestIdentity(t)
			oldRoots, oldRuntime, oldPause := mitmUpstreamRoots, mitmState.Load(), mitmPaused.Load()
			defer func() {
				mitmActive.closeAll()
				mitmUpstreamRoots = oldRoots
				mitmState.Store(oldRuntime)
				mitmPaused.Store(oldPause)
			}()
			mitmUpstreamRoots = roots
			runtime := &mitmRuntime{}
			mitmState.Store(runtime)
			mitmPaused.Store(nil)
			clientRaw, proxyClient := mitmLoopbackPair(t)
			defer clientRaw.Close()
			defer proxyClient.Close()
			proxySite, siteRaw := mitmLoopbackPair(t)
			defer proxySite.Close()
			defer siteRaw.Close()
			started := make(chan error, 1)
			siteDone := make(chan struct{})
			go func() {
				defer close(siteDone)
				site := tls.Server(siteRaw, &tls.Config{Certificates: []tls.Certificate{cert}})
				req, err := http.ReadRequest(bufio.NewReader(site))
				started <- err
				if err == nil {
					_, _ = io.ReadAll(req.Body)
				}
				_ = site.Close()
			}()
			done := make(chan MitmOutcome, 1)
			go func() { done <- serveMitm(proxyClient, proxySite, "example.com", &mitmLeaf{cert: cert}, runtime) }()
			client := tls.Client(clientRaw, &tls.Config{ServerName: "example.com", RootCAs: roots})
			if _, err := io.WriteString(client, "POST / HTTP/1.1\r\nHost: example.com\r\nContent-Length: 1000000\r\n\r\npartial"); err != nil {
				t.Fatal(err)
			}
			if err := <-started; err != nil {
				t.Fatal(err)
			}
			if mode == "runtime" {
				replaceMitmRuntime(&mitmRuntime{})
			} else if _, ok := mitmActive.pauseGlobal(runtime, "test"); !ok {
				t.Fatal("pause rejected")
			}
			select {
			case result := <-done:
				if result != mitmOutcomeHTTP1Failed {
					t.Fatalf("outcome %q", result)
				}
			case <-time.After(2 * time.Second):
				t.Fatal("active TLS relay did not stop")
			}
			select {
			case <-siteDone:
			case <-time.After(2 * time.Second):
				t.Fatal("upstream worker did not stop")
			}
		})
	}
}

func TestMitmDuplexTLSExpectContinue(t *testing.T) {
	for _, mode := range []string{"continue", "reject"} {
		t.Run(mode, func(t *testing.T) {
			cert, roots := mitmTestIdentity(t)
			oldRoots, oldRuntime := mitmUpstreamRoots, mitmState.Load()
			defer func() { mitmActive.closeAll(); mitmUpstreamRoots = oldRoots; mitmState.Store(oldRuntime) }()
			mitmUpstreamRoots = roots
			runtime := &mitmRuntime{}
			mitmState.Store(runtime)
			clientRaw, proxyClient := mitmLoopbackPair(t)
			defer clientRaw.Close()
			defer proxyClient.Close()
			proxySite, siteRaw := mitmLoopbackPair(t)
			defer proxySite.Close()
			defer siteRaw.Close()
			siteDone := make(chan error, 1)
			go func() {
				site := tls.Server(siteRaw, &tls.Config{Certificates: []tls.Certificate{cert}})
				req, err := http.ReadRequest(bufio.NewReader(site))
				if err == nil && req.Header.Get("Expect") != "100-continue" {
					err = errors.New("expect missing")
				}
				if err == nil && mode == "continue" {
					_, err = io.WriteString(site, "HTTP/1.1 100 Continue\r\n\r\n")
					if err == nil {
						var b []byte
						b, err = io.ReadAll(req.Body)
						if err == nil && string(b) != "data" {
							err = errors.New("wrong body")
						}
					}
				}
				if err == nil {
					if mode == "continue" {
						_, err = io.WriteString(site, "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok")
					} else {
						_, err = io.WriteString(site, "HTTP/1.1 413 Payload Too Large\r\nContent-Length: 0\r\n\r\n")
					}
				}
				siteDone <- err
				_ = site.Close()
			}()
			done := make(chan MitmOutcome, 1)
			go func() { done <- serveMitm(proxyClient, proxySite, "example.com", &mitmLeaf{cert: cert}, runtime) }()
			client := tls.Client(clientRaw, &tls.Config{ServerName: "example.com", RootCAs: roots})
			if _, err := io.WriteString(client, "POST / HTTP/1.1\r\nHost: example.com\r\nExpect: 100-continue\r\nContent-Length: 4\r\nConnection: close\r\n\r\n"); err != nil {
				t.Fatal(err)
			}
			reader := bufio.NewReader(client)
			resp, err := http.ReadResponse(reader, nil)
			if err != nil {
				t.Fatal(err)
			}
			if mode == "continue" {
				if resp.StatusCode != 100 {
					t.Fatalf("status %d", resp.StatusCode)
				}
				if _, err = io.WriteString(client, "data"); err != nil {
					t.Fatal(err)
				}
				resp, err = http.ReadResponse(reader, nil)
				if err != nil || resp.StatusCode != 200 {
					t.Fatalf("response %v %v", resp, err)
				}
				body, err := io.ReadAll(resp.Body)
				if err != nil || string(body) != "ok" {
					t.Fatalf("body %q %v", body, err)
				}
			} else if resp.StatusCode != 413 || !resp.Close {
				t.Fatalf("response %+v", resp)
			}
			if err = <-siteDone; err != nil {
				t.Fatal(err)
			}
			select {
			case result := <-done:
				if result != "" {
					t.Fatalf("outcome %q", result)
				}
			case <-time.After(2 * time.Second):
				t.Fatal("relay did not stop")
			}
		})
	}
}

// crypto/tls accepts bare EOF at a record boundary, so record raw EOF too:
// seeing it proves the proxy did not send a TLS close_notify after truncation.
type mitmObserveEOFConn struct {
	net.Conn
	eof atomic.Bool
}

func (c *mitmObserveEOFConn) Read(p []byte) (int, error) {
	n, err := c.Conn.Read(p)
	if errors.Is(err, io.EOF) {
		c.eof.Store(true)
	}
	return n, err
}

func TestMitmTLSUncleanCloseDelimitedResponseAbortsDownstream(t *testing.T) {
	cert, roots := mitmTestIdentity(t)
	oldRoots, oldRuntime := mitmUpstreamRoots, mitmState.Load()
	defer func() { mitmActive.closeAll(); mitmUpstreamRoots = oldRoots; mitmState.Store(oldRuntime) }()
	mitmUpstreamRoots = roots
	runtime := &mitmRuntime{}
	mitmState.Store(runtime)
	clientRaw, proxyClient := mitmLoopbackPair(t)
	defer clientRaw.Close()
	defer proxyClient.Close()
	proxySite, siteRaw := mitmLoopbackPair(t)
	defer proxySite.Close()
	defer siteRaw.Close()
	siteDone := make(chan error, 1)
	go func() {
		site := tls.Server(siteRaw, &tls.Config{Certificates: []tls.Certificate{cert}})
		_, err := http.ReadRequest(bufio.NewReader(site))
		if err == nil {
			_, err = io.WriteString(site, "HTTP/1.1 200 OK\r\nConnection: close\r\n\r\npartial")
		}
		// Deliberately bypass TLS.Close to omit close_notify.
		_ = siteRaw.Close()
		siteDone <- err
	}()
	done := make(chan MitmOutcome, 1)
	go func() { done <- serveMitm(proxyClient, proxySite, "example.com", &mitmLeaf{cert: cert}, runtime) }()
	observed := &mitmObserveEOFConn{Conn: clientRaw}
	client := tls.Client(observed, &tls.Config{ServerName: "example.com", RootCAs: roots})
	if _, err := io.WriteString(client, "GET / HTTP/1.1\r\nHost: example.com\r\nConnection: close\r\n\r\n"); err != nil {
		t.Fatal(err)
	}
	resp, err := http.ReadResponse(bufio.NewReader(client), nil)
	if err != nil {
		t.Fatal(err)
	}
	body, bodyErr := io.ReadAll(resp.Body)
	if string(body) != "partial" || !errors.Is(bodyErr, io.ErrUnexpectedEOF) || !observed.eof.Load() || len(resp.TransferEncoding) != 1 || resp.TransferEncoding[0] != "chunked" {
		t.Fatalf("body %q err=%v transfer=%v raw EOF=%v", body, bodyErr, resp.TransferEncoding, observed.eof.Load())
	}
	if outcome := <-done; outcome != mitmOutcomeHTTP1Failed {
		t.Fatalf("outcome %q", outcome)
	}
	if err := <-siteDone; err != nil {
		t.Fatal(err)
	}
}

func TestMitmTLSCloseDelimitedStreamingFraming(t *testing.T) {
	for _, early := range []bool{false, true} {
		for _, clean := range []bool{false, true} {
			name := fmt.Sprintf("early=%v/clean=%v", early, clean)
			t.Run(name, func(t *testing.T) {
				cert, roots := mitmTestIdentity(t)
				oldRoots, oldRuntime := mitmUpstreamRoots, mitmState.Load()
				defer func() { mitmActive.closeAll(); mitmUpstreamRoots = oldRoots; mitmState.Store(oldRuntime) }()
				mitmUpstreamRoots = roots
				runtime := &mitmRuntime{}
				mitmState.Store(runtime)
				clientRaw, proxyClient := mitmLoopbackPair(t)
				defer clientRaw.Close()
				defer proxyClient.Close()
				proxySite, siteRaw := mitmLoopbackPair(t)
				defer proxySite.Close()
				defer siteRaw.Close()
				start := make(chan struct{})
				finish := make(chan struct{})
				siteDone := make(chan error, 1)
				defer func() {
					select {
					case <-finish:
					default:
						close(finish)
					}
				}()
				go func() {
					site := tls.Server(siteRaw, &tls.Config{Certificates: []tls.Certificate{cert}})
					_, err := http.ReadRequest(bufio.NewReader(site))
					<-start
					if err == nil {
						_, err = io.WriteString(site, "HTTP/1.1 413 Payload Too Large\r\nConnection: close\r\n\r\npart")
					}
					<-finish
					if err == nil {
						_, err = io.WriteString(site, "ial")
					}
					if clean {
						if e := site.Close(); err == nil {
							err = e
						}
					} else {
						_ = siteRaw.Close()
					}
					siteDone <- err
				}()
				done := make(chan MitmOutcome, 1)
				go func() { done <- serveMitm(proxyClient, proxySite, "example.com", &mitmLeaf{cert: cert}, runtime) }()
				client := tls.Client(clientRaw, &tls.Config{ServerName: "example.com", RootCAs: roots})
				request := "GET / HTTP/1.1\r\nHost: example.com\r\nConnection: close\r\n\r\n"
				if early {
					request = "POST / HTTP/1.1\r\nHost: example.com\r\nContent-Length: 1000000\r\n\r\npartial"
				}
				if _, err := io.WriteString(client, request); err != nil {
					close(start)
					t.Fatal(err)
				}
				close(start)
				resp, err := http.ReadResponse(bufio.NewReader(client), nil)
				if err != nil {
					t.Fatal(err)
				}
				if !resp.Close || len(resp.TransferEncoding) != 1 || resp.TransferEncoding[0] != "chunked" {
					t.Fatalf("wrong framing: %+v", resp)
				}
				// This must arrive before allowing the upstream to finish: no buffering of
				// the complete body, even for early-final responses during upload.
				var first [4]byte
				if _, err := io.ReadFull(resp.Body, first[:]); err != nil || string(first[:]) != "part" {
					t.Fatalf("first body %q: %v", first, err)
				}
				close(finish)
				rest, err := io.ReadAll(resp.Body)
				if string(rest) != "ial" || (clean && err != nil) || (!clean && !errors.Is(err, io.ErrUnexpectedEOF)) {
					t.Fatalf("rest %q error %v clean=%v", rest, err, clean)
				}
				select {
				case result := <-done:
					if clean && result != "" || !clean && result != mitmOutcomeHTTP1Failed {
						t.Fatalf("outcome %q", result)
					}
				case <-time.After(2 * time.Second):
					t.Fatal("relay did not stop")
				}
				if err := <-siteDone; err != nil {
					t.Fatal(err)
				}
			})
		}
	}
}

func TestMitmTLSResponseFramingCases(t *testing.T) {
	for _, tc := range []struct {
		name, method, wire, body string
		status                   int
		chunked, rawClose, fail  bool
	}{
		{name: "head", method: "HEAD", wire: "HTTP/1.1 200 OK\r\nContent-Length: 17\r\nConnection: close\r\n\r\n", status: 200},
		{name: "204", method: "GET", wire: "HTTP/1.1 204 No Content\r\nConnection: close\r\n\r\n", status: 204},
		{name: "304", method: "GET", wire: "HTTP/1.1 304 Not Modified\r\nContent-Length: 17\r\nConnection: close\r\n\r\n", status: 304},
		{name: "http10", method: "GET", wire: "HTTP/1.0 200 OK\r\nContent-Length: 0\r\n\r\n", fail: true},
		{name: "chunked trailers", method: "GET", wire: "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nTrailer: X-Test\r\nConnection: close\r\n\r\n3\r\nabc\r\n0\r\nX-Test: done\r\n\r\n", status: 200, body: "abc", chunked: true},
		{name: "empty close delimited", method: "GET", wire: "HTTP/1.1 200 OK\r\nConnection: close\r\n\r\n", status: 200, chunked: true},
		{name: "empty truncated", method: "GET", wire: "HTTP/1.1 200 OK\r\nConnection: close\r\n\r\n", status: 200, chunked: true, rawClose: true, fail: true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			cert, roots := mitmTestIdentity(t)
			oldRoots, oldRuntime := mitmUpstreamRoots, mitmState.Load()
			defer func() { mitmActive.closeAll(); mitmUpstreamRoots = oldRoots; mitmState.Store(oldRuntime) }()
			mitmUpstreamRoots = roots
			runtime := &mitmRuntime{}
			mitmState.Store(runtime)
			clientRaw, proxyClient := mitmLoopbackPair(t)
			defer clientRaw.Close()
			defer proxyClient.Close()
			proxySite, siteRaw := mitmLoopbackPair(t)
			defer proxySite.Close()
			defer siteRaw.Close()
			siteDone := make(chan error, 1)
			go func() {
				site := tls.Server(siteRaw, &tls.Config{Certificates: []tls.Certificate{cert}})
				_, err := http.ReadRequest(bufio.NewReader(site))
				if err == nil {
					_, err = io.WriteString(site, tc.wire)
				}
				if tc.rawClose {
					_ = siteRaw.Close()
				} else {
					_ = site.Close()
				}
				siteDone <- err
			}()
			done := make(chan MitmOutcome, 1)
			go func() { done <- serveMitm(proxyClient, proxySite, "example.com", &mitmLeaf{cert: cert}, runtime) }()
			client := tls.Client(clientRaw, &tls.Config{ServerName: "example.com", RootCAs: roots})
			if _, err := io.WriteString(client, tc.method+" / HTTP/1.1\r\nHost: example.com\r\nConnection: close\r\n\r\n"); err != nil {
				t.Fatal(err)
			}
			resp, err := http.ReadResponse(bufio.NewReader(client), &http.Request{Method: tc.method})
			if tc.name == "http10" {
				if err == nil {
					t.Fatal("accepted HTTP/1.0")
				}
			} else {
				if err != nil {
					t.Fatal(err)
				}
				body, readErr := io.ReadAll(resp.Body)
				if resp.StatusCode != tc.status || string(body) != tc.body || (tc.rawClose && !errors.Is(readErr, io.ErrUnexpectedEOF)) || (!tc.rawClose && readErr != nil) {
					t.Fatalf("status=%d body=%q err=%v", resp.StatusCode, body, readErr)
				}
				if got := len(resp.TransferEncoding) == 1 && resp.TransferEncoding[0] == "chunked"; got != tc.chunked {
					t.Fatalf("transfer encoding %v", resp.TransferEncoding)
				}
				if tc.name == "chunked trailers" && resp.Trailer.Get("X-Test") != "done" {
					t.Fatalf("trailers %v", resp.Trailer)
				}
				if tc.name == "head" && resp.ContentLength != 17 {
					t.Fatalf("content length %d", resp.ContentLength)
				}
			}
			select {
			case result := <-done:
				if tc.fail && result != mitmOutcomeHTTP1Failed || !tc.fail && result != "" {
					t.Fatalf("outcome %q", result)
				}
			case <-time.After(2 * time.Second):
				t.Fatal("relay did not stop")
			}
			if err := <-siteDone; err != nil {
				t.Fatal(err)
			}
		})
	}
}

type mitmObserveWriteErrorConn struct {
	net.Conn
	failed atomic.Bool
}

func (c *mitmObserveWriteErrorConn) Write(p []byte) (int, error) {
	n, err := c.Conn.Write(p)
	if err != nil {
		c.failed.Store(true)
	}
	return n, err
}

func TestMitmTLSResponseStreamingDisconnectAndReplacement(t *testing.T) {
	for _, mode := range []string{"downstream disconnect", "runtime replacement"} {
		t.Run(mode, func(t *testing.T) {
			cert, roots := mitmTestIdentity(t)
			oldRoots, oldRuntime := mitmUpstreamRoots, mitmState.Load()
			defer func() { mitmActive.closeAll(); mitmUpstreamRoots = oldRoots; mitmState.Store(oldRuntime) }()
			mitmUpstreamRoots = roots
			runtime := &mitmRuntime{}
			mitmState.Store(runtime)
			clientRaw, proxyClientRaw := mitmLoopbackPair(t)
			defer clientRaw.Close()
			defer proxyClientRaw.Close()
			proxyClient := &mitmObserveWriteErrorConn{Conn: proxyClientRaw}
			proxySite, siteRaw := mitmLoopbackPair(t)
			defer proxySite.Close()
			defer siteRaw.Close()
			send := make(chan struct{})
			siteDone := make(chan struct{})
			defer func() {
				select {
				case <-send:
				default:
					close(send)
				}
			}()
			go func() {
				defer close(siteDone)
				site := tls.Server(siteRaw, &tls.Config{Certificates: []tls.Certificate{cert}})
				_, err := http.ReadRequest(bufio.NewReader(site))
				if err == nil {
					_, err = io.WriteString(site, "HTTP/1.1 200 OK\r\nConnection: close\r\n\r\npart")
				}
				<-send
				block := bytes.Repeat([]byte("x"), 32<<10)
				for err == nil {
					_, err = site.Write(block)
				}
				_ = siteRaw.Close()
			}()
			done := make(chan MitmOutcome, 1)
			go func() { done <- serveMitm(proxyClient, proxySite, "example.com", &mitmLeaf{cert: cert}, runtime) }()
			client := tls.Client(clientRaw, &tls.Config{ServerName: "example.com", RootCAs: roots})
			if _, err := io.WriteString(client, "GET / HTTP/1.1\r\nHost: example.com\r\nConnection: close\r\n\r\n"); err != nil {
				t.Fatal(err)
			}
			resp, err := http.ReadResponse(bufio.NewReader(client), nil)
			if err != nil {
				t.Fatal(err)
			}
			var first [4]byte
			if _, err := io.ReadFull(resp.Body, first[:]); err != nil || string(first[:]) != "part" {
				t.Fatalf("body %q: %v", first, err)
			}
			if mode == "downstream disconnect" {
				if tcp, ok := clientRaw.(*net.TCPConn); ok {
					_ = tcp.SetLinger(0)
				}
				_ = clientRaw.Close()
				close(send)
			} else {
				replaceMitmRuntime(&mitmRuntime{})
				close(send)
			}
			select {
			case outcome := <-done:
				if outcome != mitmOutcomeHTTP1Failed {
					t.Fatalf("outcome %q", outcome)
				}
			case <-time.After(3 * time.Second):
				t.Fatal("relay did not terminate")
			}
			select {
			case <-siteDone:
			case <-time.After(3 * time.Second):
				t.Fatal("site did not terminate")
			}
			if mode == "downstream disconnect" && !proxyClient.failed.Load() {
				t.Fatal("no downstream write failure observed")
			}
		})
	}
}
