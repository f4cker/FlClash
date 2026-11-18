package core

import (
	"bufio"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"io"
	"math/big"
	"net"
	"net/http"
	"os"
	"strings"
	"testing"
	"time"

	"golang.org/x/net/http2"
)

// Opt-in (FLASH_MITM_LIVE=1): real sites over the network, decrypted on
// loopback exactly as the selector hands a session over, the sites verified
// against the system roots. No proxy or system setting is touched.
func TestMitmH2LiveSites(t *testing.T) {
	if os.Getenv("FLASH_MITM_LIVE") != "1" {
		t.Skip("set FLASH_MITM_LIVE=1 to reach real sites")
	}
	for _, site := range []struct{ host, path string }{
		{"www.google.com", "/"},
		{"www.cloudflare.com", "/cdn-cgi/trace"},
		{"nghttp2.org", "/"},
		{"go.dev", "/"},
	} {
		for _, protos := range [][]string{{"h2", "http/1.1"}, {"http/1.1"}} {
			t.Run(site.host+"/"+strings.Join(protos, ","), func(t *testing.T) {
				mitmLiveFetch(t, site.host, site.path, protos)
			})
		}
	}
}

func mitmLiveFetch(t *testing.T, host, path string, protos []string) {
	leaf, leafRoots := mitmLiveIdentity(t, host)
	oldRoots, oldRuntime := mitmUpstreamRoots, mitmState.Load()
	t.Cleanup(func() { mitmActive.closeAll(); mitmUpstreamRoots = oldRoots; mitmState.Store(oldRuntime) })
	mitmUpstreamRoots = nil // the system's
	withMitmCapture(t, mitmDefaultCaptureLimits)
	runtime := &mitmRuntime{setup: MitmSetup{}}
	mitmState.Store(runtime)
	oldSend := sendMitmConnection
	sendMitmConnection = func(*MitmConnection) bool { return true }
	t.Cleanup(func() { sendMitmConnection = oldSend })

	remote, err := net.DialTimeout("tcp", net.JoinHostPort(host, "443"), 10*time.Second)
	if err != nil {
		t.Skipf("network: %v", err)
	}
	clientRaw, proxyClient := mitmLoopbackPair(t)
	for _, c := range []net.Conn{clientRaw, proxyClient, remote} {
		_ = c.SetDeadline(time.Now().Add(30 * time.Second))
		t.Cleanup(func() { _ = c.Close() })
	}
	id := "live-" + host
	done := make(chan MitmOutcome, 1)
	go func() {
		done <- serveMitmOffering(proxyClient, mitmTrackedConn{remote, id}, host, &mitmLeaf{cert: leaf}, runtime, protos)
	}()
	client := tls.Client(clientRaw, &tls.Config{ServerName: host, RootCAs: leafRoots, NextProtos: protos})
	if err := client.Handshake(); err != nil {
		select {
		case outcome := <-done:
			t.Fatalf("handshake: %v (outcome %q)", err, outcome)
		case <-time.After(time.Second):
			t.Fatalf("handshake: %v", err)
		}
	}
	negotiated := client.ConnectionState().NegotiatedProtocol
	req, _ := http.NewRequest(http.MethodGet, "https://"+host+path, nil)
	req.Header.Set("User-Agent", "Flash-MITM-live-test")
	var resp *http.Response
	if negotiated == "h2" {
		cc, err := (&http2.Transport{}).NewClientConn(client)
		if err != nil {
			t.Fatal(err)
		}
		defer cc.Close()
		resp, err = cc.RoundTrip(req)
		if err != nil {
			t.Fatal(err)
		}
	} else {
		req.Close = true
		if err := req.Write(client); err != nil {
			t.Fatal(err)
		}
		resp, err = http.ReadResponse(bufio.NewReader(client), req)
		if err != nil {
			t.Fatal(err)
		}
	}
	body, err := io.ReadAll(resp.Body)
	resp.Body.Close()
	if err != nil {
		t.Fatalf("body: %v", err)
	}
	if resp.StatusCode >= 500 {
		t.Fatalf("status %d", resp.StatusCode)
	}
	if want := map[bool]string{true: "HTTP/2.0", false: "HTTP/1.1"}[strings.Contains(strings.Join(protos, ","), "h2")]; resp.Proto != want {
		t.Errorf("proto %s, want %s", resp.Proto, want)
	}
	list := handleMitmExchanges(MitmExchangesParams{ID: id})
	if len(list.Exchanges) != 1 || list.Exchanges[0].Status != resp.StatusCode || list.Exchanges[0].Proto != resp.Proto {
		t.Fatalf("captured %+v", list.Exchanges)
	}
	t.Logf("%s %s ALPN=%s status=%d body=%dB captured=%dB", host, resp.Proto, negotiated, resp.StatusCode, len(body), list.Exchanges[0].ResponseSize)
}

// A root and a leaf for host, in memory for this test only.
func mitmLiveIdentity(t *testing.T, host string) (tls.Certificate, *x509.CertPool) {
	t.Helper()
	now := time.Now()
	rootKey, _ := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	rootTemplate := &x509.Certificate{SerialNumber: big.NewInt(1), Subject: pkix.Name{CommonName: "in-memory live test root"}, NotBefore: now.Add(-time.Hour), NotAfter: now.Add(time.Hour), IsCA: true, BasicConstraintsValid: true, KeyUsage: x509.KeyUsageCertSign}
	rootDER, err := x509.CreateCertificate(rand.Reader, rootTemplate, rootTemplate, &rootKey.PublicKey, rootKey)
	if err != nil {
		t.Fatal(err)
	}
	root, _ := x509.ParseCertificate(rootDER)
	leafKey, _ := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	template := &x509.Certificate{SerialNumber: big.NewInt(2), DNSNames: []string{host}, NotBefore: now.Add(-time.Hour), NotAfter: now.Add(time.Hour), KeyUsage: x509.KeyUsageDigitalSignature, ExtKeyUsage: []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth}}
	der, err := x509.CreateCertificate(rand.Reader, template, root, &leafKey.PublicKey, rootKey)
	if err != nil {
		t.Fatal(err)
	}
	pool := x509.NewCertPool()
	pool.AddCert(root)
	return tls.Certificate{Certificate: [][]byte{der}, PrivateKey: leafKey}, pool
}
