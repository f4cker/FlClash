package core

import (
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/sha256"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/hex"
	"encoding/json"
	"errors"
	"math/big"
	"strings"
	"testing"
	"time"
)

type fakeMitmApp struct {
	key *ecdsa.PrivateKey
	ca  *x509.Certificate
}

func newFakeMitmApp(t *testing.T) *fakeMitmApp {
	t.Helper()
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	template := &x509.Certificate{
		SerialNumber:          big.NewInt(1),
		Subject:               pkix.Name{CommonName: "Flash 本机解密证书（仅此 Mac）"},
		NotBefore:             time.Now().Add(-time.Hour),
		NotAfter:              time.Now().AddDate(1, 0, 0),
		IsCA:                  true,
		BasicConstraintsValid: true,
		MaxPathLenZero:        true,
		KeyUsage:              x509.KeyUsageCertSign | x509.KeyUsageCRLSign,
	}
	der, err := x509.CreateCertificate(rand.Reader, template, template, &key.PublicKey, key)
	if err != nil {
		t.Fatal(err)
	}
	ca, err := x509.ParseCertificate(der)
	if err != nil {
		t.Fatal(err)
	}
	return &fakeMitmApp{key: key, ca: ca}
}

func (app *fakeMitmApp) fingerprint() string {
	sum := sha256.Sum256(app.ca.Raw)
	parts := make([]string, len(sum))
	for i, b := range sum {
		parts[i] = strings.ToUpper(hex.EncodeToString([]byte{b}))
	}
	return strings.Join(parts, ":")
}

func (app *fakeMitmApp) leaf(t *testing.T, host string, spki []byte, edit func(*x509.Certificate)) []byte {
	t.Helper()
	key, err := x509.ParsePKIXPublicKey(spki)
	if err != nil {
		t.Fatal(err)
	}
	template := &x509.Certificate{
		SerialNumber:          big.NewInt(2),
		Subject:               pkix.Name{CommonName: host},
		DNSNames:              []string{host},
		NotBefore:             time.Now().Add(-time.Hour),
		NotAfter:              time.Now().AddDate(0, 0, 7),
		BasicConstraintsValid: true,
		KeyUsage:              x509.KeyUsageDigitalSignature,
		ExtKeyUsage:           []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth},
	}
	if edit != nil {
		edit(template)
	}
	der, err := x509.CreateCertificate(rand.Reader, template, app.ca, key, app.key)
	if err != nil {
		t.Fatal(err)
	}
	return der
}

func withMitmSigner(t *testing.T, app *fakeMitmApp, hosts []string, answer func(*MitmSignRequest) MitmSignResultParams) *[]MitmSignRequest {
	t.Helper()
	withMitmState(t)
	applyMitmSetup(&SetupParams{Mitm: &MitmSetup{
		Enable: true, Hostname: hosts, DecryptTLS: true, CAFingerprint: app.fingerprint(),
	}}, nil)
	previous := sendMitmSign
	t.Cleanup(func() { sendMitmSign = previous })
	sent := &[]MitmSignRequest{}
	sendMitmSign = func(request *MitmSignRequest) bool {
		*sent = append(*sent, *request)
		if answer == nil {
			return true
		}
		result := answer(request)
		result.ReqID = request.ReqID
		go handleMitmSignResult(result)
		return true
	}
	return sent
}

func newLeafKey(t *testing.T) *ecdsa.PrivateKey {
	t.Helper()
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	return key
}

func TestMitmSignRequestCarriesOnlyTheHostAndTheKey(t *testing.T) {
	data, err := json.Marshal(&MitmSignRequest{ReqID: 7, Host: "api.example.com", SPKI: []byte{1, 2}})
	if err != nil {
		t.Fatal(err)
	}
	if string(data) != `{"reqId":7,"host":"api.example.com","spki":"AQI="}` {
		t.Fatalf("request %s", data)
	}
	var message map[string]any
	data, _ = json.Marshal(Message{Type: MitmSignMessage, Data: nil})
	_ = json.Unmarshal(data, &message)
	if message["type"] != "mitmSign" {
		t.Fatalf("message %s", data)
	}
}

func TestMitmLeafIsSignedByTheAppForAListedHost(t *testing.T) {
	app := newFakeMitmApp(t)
	sent := withMitmSigner(t, app, []string{"*.example.com"}, func(request *MitmSignRequest) MitmSignResultParams {
		return MitmSignResultParams{Cert: app.leaf(t, request.Host, request.SPKI, nil), CA: app.ca.Raw}
	})
	key := newLeafKey(t)
	leaf, err := requestMitmLeaf(context.Background(), "API.example.com.", &key.PublicKey)
	if err != nil {
		t.Fatal(err)
	}
	if leaf.DNSNames[0] != "api.example.com" || len(*sent) != 1 || (*sent)[0].Host != "api.example.com" {
		t.Fatalf("leaf %v, sent %+v", leaf.DNSNames, *sent)
	}
	spki, _ := x509.MarshalPKIXPublicKey(&key.PublicKey)
	if string((*sent)[0].SPKI) != string(spki) {
		t.Fatal("the request does not carry the leaf key")
	}
}

func TestMitmLeafIsNeverAskedForOffTheList(t *testing.T) {
	app := newFakeMitmApp(t)
	sent := withMitmSigner(t, app, []string{"api.example.com", "-*.example.org", "*.com"}, nil)
	key := newLeafKey(t)
	for _, host := range []string{"www.example.com", "a.example.org", "example.com", "www.apple.com", "10.0.0.1"} {
		if _, err := requestMitmLeaf(context.Background(), host, &key.PublicKey); !errors.Is(err, errMitmNotListed) {
			t.Errorf("%s: %v", host, err)
		}
	}
	if len(*sent) != 0 {
		t.Fatalf("asked for %+v", *sent)
	}
}

func TestMitmLeafIsNotAskedForWhileDecryptionIsPaused(t *testing.T) {
	app := newFakeMitmApp(t)
	sent := withMitmSigner(t, app, []string{"api.example.com"}, nil)
	applyMitmSetup(&SetupParams{Mitm: &MitmSetup{Enable: true, Hostname: []string{"api.example.com"}}}, nil)
	key := newLeafKey(t)
	if _, err := requestMitmLeaf(context.Background(), "api.example.com", &key.PublicKey); !errors.Is(err, errMitmNotListed) {
		t.Fatal(err)
	}
	if len(*sent) != 0 {
		t.Fatal("asked without a trusted root")
	}
}

func TestMitmLeafRefusalsReachTheCaller(t *testing.T) {
	app := newFakeMitmApp(t)
	withMitmSigner(t, app, []string{"api.example.com"}, func(*MitmSignRequest) MitmSignResultParams {
		return MitmSignResultParams{Error: "core identity check failed"}
	})
	key := newLeafKey(t)
	_, err := requestMitmLeaf(context.Background(), "api.example.com", &key.PublicKey)
	if err == nil || !strings.Contains(err.Error(), "core identity check failed") {
		t.Fatal(err)
	}
}

func TestMitmLeafThatIsNotTheOneAskedForIsRefused(t *testing.T) {
	app := newFakeMitmApp(t)
	other := newFakeMitmApp(t)
	cases := map[string]func(*MitmSignRequest) MitmSignResultParams{
		"another host": func(request *MitmSignRequest) MitmSignResultParams {
			return MitmSignResultParams{Cert: app.leaf(t, "evil.example.com", request.SPKI, nil), CA: app.ca.Raw}
		},
		"another key": func(*MitmSignRequest) MitmSignResultParams {
			spki, _ := x509.MarshalPKIXPublicKey(&newLeafKey(t).PublicKey)
			return MitmSignResultParams{Cert: app.leaf(t, "api.example.com", spki, nil), CA: app.ca.Raw}
		},
		"a CA": func(request *MitmSignRequest) MitmSignResultParams {
			return MitmSignResultParams{Cert: app.leaf(t, request.Host, request.SPKI, func(template *x509.Certificate) {
				template.IsCA = true
				template.KeyUsage |= x509.KeyUsageCertSign
			}), CA: app.ca.Raw}
		},
		"client auth": func(request *MitmSignRequest) MitmSignResultParams {
			return MitmSignResultParams{Cert: app.leaf(t, request.Host, request.SPKI, func(template *x509.Certificate) {
				template.ExtKeyUsage = []x509.ExtKeyUsage{x509.ExtKeyUsageClientAuth}
			}), CA: app.ca.Raw}
		},
		"another root": func(request *MitmSignRequest) MitmSignResultParams {
			return MitmSignResultParams{Cert: other.leaf(t, request.Host, request.SPKI, nil), CA: other.ca.Raw}
		},
		"a root that did not sign it": func(request *MitmSignRequest) MitmSignResultParams {
			return MitmSignResultParams{Cert: other.leaf(t, request.Host, request.SPKI, nil), CA: app.ca.Raw}
		},
		"no certificate": func(*MitmSignRequest) MitmSignResultParams {
			return MitmSignResultParams{}
		},
	}
	for name, answer := range cases {
		t.Run(name, func(t *testing.T) {
			withMitmSigner(t, app, []string{"api.example.com"}, answer)
			key := newLeafKey(t)
			if leaf, err := requestMitmLeaf(context.Background(), "api.example.com", &key.PublicKey); err == nil {
				t.Fatalf("served %v", leaf.DNSNames)
			}
		})
	}
}

func TestMitmLeafWaitsNoLongerThanAsked(t *testing.T) {
	app := newFakeMitmApp(t)
	withMitmSigner(t, app, []string{"api.example.com"}, nil)
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Millisecond)
	defer cancel()
	key := newLeafKey(t)
	if _, err := requestMitmLeaf(ctx, "api.example.com", &key.PublicKey); !errors.Is(err, context.DeadlineExceeded) {
		t.Fatal(err)
	}
	mitmSignMu.Lock()
	defer mitmSignMu.Unlock()
	if len(mitmSignRequests) != 0 {
		t.Fatal("a timed-out request is still waiting")
	}
}

func TestMitmSignResultForNoRequestIsDropped(t *testing.T) {
	if handleMitmSignResult(MitmSignResultParams{ReqID: 1 << 60, Cert: []byte{1}}) {
		t.Fatal("an answer nobody waits for was taken")
	}
}

func TestMitmLeafRequestThatCannotBeSentFails(t *testing.T) {
	app := newFakeMitmApp(t)
	withMitmSigner(t, app, []string{"api.example.com"}, nil)
	sendMitmSign = func(*MitmSignRequest) bool { return false }
	key := newLeafKey(t)
	if _, err := requestMitmLeaf(context.Background(), "api.example.com", &key.PublicKey); !errors.Is(err, errMitmSignDropped) {
		t.Fatal(err)
	}
}

func TestMitmLeafValidityBoundaries(t *testing.T) {
	app := newFakeMitmApp(t)
	key := newLeafKey(t)
	spki, err := x509.MarshalPKIXPublicKey(&key.PublicKey)
	if err != nil {
		t.Fatal(err)
	}
	start := time.Now().UTC().Truncate(time.Second)
	end := start.Add(time.Hour)
	der := app.leaf(t, "api.example.com", spki, func(c *x509.Certificate) { c.NotBefore = start; c.NotAfter = end })
	for _, tc := range []struct {
		when time.Time
		ok   bool
	}{{start.Add(-time.Second), false}, {start, true}, {end.Add(-time.Second), true}, {end, false}} {
		_, err := checkMitmLeafAt(der, app.ca.Raw, "api.example.com", spki, app.fingerprint(), tc.when)
		if (err == nil) != tc.ok {
			t.Errorf("time %v: %v", tc.when, err)
		}
	}
	for _, when := range []time.Time{app.ca.NotBefore.Add(-time.Second), app.ca.NotAfter} {
		// A leaf spanning both tested root boundaries isolates CA validation.
		der := app.leaf(t, "api.example.com", spki, func(c *x509.Certificate) {
			c.NotBefore = app.ca.NotBefore.Add(-time.Hour)
			c.NotAfter = app.ca.NotAfter.Add(time.Hour)
		})
		if _, err := checkMitmLeafAt(der, app.ca.Raw, "api.example.com", spki, app.fingerprint(), when); err == nil {
			t.Errorf("accepted root at %v", when)
		}
	}
}

func TestMitmSignCarriesCallerDeadline(t *testing.T) {
	app := newFakeMitmApp(t)
	sent := withMitmSigner(t, app, []string{"api.example.com"}, func(req *MitmSignRequest) MitmSignResultParams {
		return MitmSignResultParams{Cert: app.leaf(t, req.Host, req.SPKI, nil), CA: app.ca.Raw}
	})
	key := newLeafKey(t)
	deadline := time.Now().Add(4 * time.Second)
	ctx, cancel := context.WithDeadline(context.Background(), deadline)
	defer cancel()
	if _, err := requestMitmLeaf(ctx, "api.example.com", &key.PublicKey); err != nil {
		t.Fatal(err)
	}
	if len(*sent) != 1 || (*sent)[0].DeadlineUnixMillis != deadline.UnixMilli() {
		t.Fatalf("deadline: %+v", *sent)
	}
}
