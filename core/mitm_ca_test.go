package core

import (
	"bytes"
	"context"
	"crypto"
	"crypto/ecdsa"
	"crypto/ed25519"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha1"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/asn1"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"math/big"
	"strings"
	"testing"
	"time"

	"github.com/metacubex/mihomo/common/observable"
	"github.com/metacubex/mihomo/log"
	"software.sslmate.com/src/go-pkcs12"
)

// Every CA here is made in memory; no test reads or writes a keychain.
func withMitmCAState(t *testing.T) {
	t.Helper()
	withMitmState(t)
	previousCA, leaseMax := mitmCA.Load(), mitmCALeaseMax
	previousPause := mitmPaused.Load()
	t.Cleanup(func() {
		if ca := mitmCA.Swap(previousCA); ca != nil && ca != previousCA {
			ca.retire()
		}
		mitmCALeaseMax = leaseMax
		mitmPaused.Store(previousPause)
		mitmHostPauses.Clear()
		mitmActive.closeAll()
		mitmLeaves.clear()
	})
	mitmCA.Store(nil)
	mitmPaused.Store(nil)
	mitmHostPauses.Clear()
	mitmLeaves.clear()
}

func generatedTestCA(t *testing.T) MitmGeneratedCA {
	t.Helper()
	generated, err := generateMitmCA(time.Now())
	if err != nil {
		t.Fatal(err)
	}
	return generated
}

type testCAOptions struct {
	key    crypto.Signer
	edit   func(*x509.Certificate)
	parent *x509.Certificate
	signer crypto.Signer
	p12Key crypto.Signer
}

func testCAP12(t *testing.T, options testCAOptions) ([]byte, string, *x509.Certificate) {
	t.Helper()
	key := options.key
	if key == nil {
		key = newLeafKey(t)
	}
	template := &x509.Certificate{
		SerialNumber:          big.NewInt(7),
		Subject:               pkix.Name{CommonName: "Imported Test CA"},
		NotBefore:             time.Now().Add(-time.Hour),
		NotAfter:              time.Now().AddDate(1, 0, 0),
		IsCA:                  true,
		BasicConstraintsValid: true,
		KeyUsage:              x509.KeyUsageCertSign | x509.KeyUsageCRLSign,
	}
	if options.edit != nil {
		options.edit(template)
	}
	parent, signer := template, key
	if options.parent != nil {
		parent, signer = options.parent, options.signer
	}
	der, err := x509.CreateCertificate(rand.Reader, template, parent, key.Public(), signer)
	if err != nil {
		t.Fatal(err)
	}
	cert, err := x509.ParseCertificate(der)
	if err != nil {
		t.Fatal(err)
	}
	p12Key := options.p12Key
	if p12Key == nil {
		p12Key = key
	}
	p12, err := pkcs12.Modern2023.Encode(p12Key, cert, nil, "import-pass")
	if err != nil {
		t.Fatal(err)
	}
	return p12, "import-pass", cert
}

func loadTestCA(t *testing.T, p12 []byte, passphrase string, cert *x509.Certificate) {
	t.Helper()
	_, err := handleMitmSetCASeq(MitmCAParams{P12: p12, Passphrase: mitmCAPassphrase(passphrase), Fingerprint: mitmFingerprintDisplay(cert.Raw)}, 0)
	if err != nil {
		t.Fatal(err)
	}
}

func leaseTestCA(t *testing.T) MitmCAState {
	t.Helper()
	check, err := handleMitmIssueCheck()
	if err != nil {
		t.Fatal(err)
	}
	state, err := handleMitmTrustLease(MitmTrustLeaseParams{Fingerprint: mitmCA.Load().fingerprint, Check: check.Check})
	if err != nil {
		t.Fatal(err)
	}
	return state
}

func coreSignerSetup(fingerprint string, hosts ...string) *MitmSetup {
	return &MitmSetup{Enable: true, Hostname: hosts, DecryptTLS: true, CAFingerprint: fingerprint, Signer: mitmSignerCore}
}

// A generated CA, loaded and leased, under a core-signer setup for hosts.
func withCoreSigner(t *testing.T, hosts ...string) MitmGeneratedCA {
	t.Helper()
	withMitmCAState(t)
	generated := generatedTestCA(t)
	if _, err := handleMitmSetCASeq(MitmCAParams{P12: bytes.Clone(generated.P12), Passphrase: generated.Passphrase, Fingerprint: generated.Fingerprint}, 0); err != nil {
		t.Fatal(err)
	}
	if err := handleMitmUpdate(MitmUpdateParams{Setup: coreSignerSetup(generated.Fingerprint, hosts...)}); err != nil {
		t.Fatal(err)
	}
	previous := sendMitmSign
	sendMitmSign = func(*MitmSignRequest) bool {
		t.Error("the core signer asked the app for a leaf")
		return false
	}
	t.Cleanup(func() { sendMitmSign = previous })
	leaseTestCA(t)
	return generated
}

func extensionCritical(cert *x509.Certificate, oid asn1.ObjectIdentifier) (critical, found bool) {
	for _, extension := range cert.Extensions {
		if extension.Id.Equal(oid) {
			return extension.Critical, true
		}
	}
	return false, false
}

var (
	oidBasicConstraints = asn1.ObjectIdentifier{2, 5, 29, 19}
	oidKeyUsage         = asn1.ObjectIdentifier{2, 5, 29, 15}
	oidExtKeyUsage      = asn1.ObjectIdentifier{2, 5, 29, 37}
	oidPBES2            = asn1.ObjectIdentifier{1, 2, 840, 113549, 1, 5, 13}
	oidAES256CBC        = asn1.ObjectIdentifier{2, 16, 840, 1, 101, 3, 4, 1, 42}
)

func TestMitmGeneratedRootFollowsTheSwiftTemplateUnderADistinctName(t *testing.T) {
	now := time.Now()
	generated := generatedTestCA(t)
	key, cert, err := pkcs12.Decode(generated.P12, string(generated.Passphrase))
	if err != nil {
		t.Fatalf("the generated p12 does not open with its passphrase: %v", err)
	}
	ecKey := key.(*ecdsa.PrivateKey)
	point, _ := ecKey.PublicKey.Bytes()
	keyID := sha1.Sum(point)
	name := cert.Subject.CommonName
	switch {
	case ecKey.Curve != elliptic.P256():
		t.Error("root key is not P-256")
	case !cert.IsCA || !cert.BasicConstraintsValid || cert.MaxPathLen != 0 || !cert.MaxPathLenZero:
		t.Errorf("basic constraints = CA %v pathLen %d zero %v, want a CA with path length 0", cert.IsCA, cert.MaxPathLen, cert.MaxPathLenZero)
	case cert.KeyUsage != x509.KeyUsageCertSign|x509.KeyUsageCRLSign:
		t.Errorf("key usage = %v", cert.KeyUsage)
	case len(cert.ExtKeyUsage) != 1 || cert.ExtKeyUsage[0] != x509.ExtKeyUsageServerAuth:
		t.Errorf("EKU = %v", cert.ExtKeyUsage)
	case len(cert.AuthorityKeyId) != 0:
		t.Error("the root carries an AKI")
	case !bytes.Equal(cert.SubjectKeyId, keyID[:]):
		t.Error("SKI is not SHA-1 of the public point")
	case name == "Flash 本机解密证书（仅此 Mac）" || strings.Contains(name, "仅此 Mac") || !strings.HasPrefix(name, "Flash 解密证书 "+now.UTC().Format("2006-01-02")+" "):
		t.Errorf("CN %q is not distinct from the legacy root", name)
	case !strings.HasSuffix(name, hex.EncodeToString(keyID[:4])):
		t.Errorf("CN %q does not carry the key identifier", name)
	case len(cert.Subject.Organization) != 1 || cert.Subject.Organization[0] != "Flash":
		t.Errorf("O = %v", cert.Subject.Organization)
	case cert.NotAfter.Sub(cert.NotBefore) != mitmRootLifetime || now.Sub(cert.NotBefore) < mitmCertBackdate-time.Second:
		t.Errorf("validity %v – %v", cert.NotBefore, cert.NotAfter)
	case len(cert.SerialNumber.Bytes()) != 16 || cert.SerialNumber.Bytes()[0]&0xc0 != 0x40:
		t.Errorf("serial %x", cert.SerialNumber.Bytes())
	case mitmHasNameConstraints(cert):
		t.Error("root carries name constraints")
	}
	if critical, found := extensionCritical(cert, oidBasicConstraints); !found || !critical {
		t.Error("basic constraints not critical")
	}
	if critical, found := extensionCritical(cert, oidKeyUsage); !found || !critical {
		t.Error("key usage not critical")
	}
	if critical, _ := extensionCritical(cert, oidExtKeyUsage); critical {
		t.Error("EKU critical")
	}
	if generated.Fingerprint != mitmFingerprintDisplay(cert.Raw) || generated.Subject != name ||
		!generated.NotAfter.Equal(cert.NotAfter) || !strings.HasPrefix(generated.PEM, "-----BEGIN CERTIFICATE-----") {
		t.Errorf("metadata does not describe the root: %s %s", generated.Fingerprint, generated.Subject)
	}
	if raw, _ := base64.RawURLEncoding.DecodeString(string(generated.Passphrase)); len(raw) != 32 {
		t.Errorf("passphrase carries %d random bytes, want 32", len(raw))
	}
	pbes2, _ := asn1.Marshal(oidPBES2)
	aes, _ := asn1.Marshal(oidAES256CBC)
	if !bytes.Contains(generated.P12, pbes2) || !bytes.Contains(generated.P12, aes) {
		t.Error("the p12 is not PBES2/AES-256 (go-pkcs12 Modern2023)")
	}
	if other := generatedTestCA(t); other.Passphrase == generated.Passphrase || other.Fingerprint == generated.Fingerprint {
		t.Error("two generations share a passphrase or a root")
	}
}

func TestMitmCoreLeafFollowsTheSwiftTemplate(t *testing.T) {
	withCoreSigner(t, "example.com")
	ca := mitmCA.Load()
	before := time.Now()
	leaf, err := issueMitmLeaf(context.Background(), "Example.COM.")
	if err != nil {
		t.Fatal(err)
	}
	cert := leaf.cert.Leaf
	spki, _ := x509.MarshalPKIXPublicKey(leaf.cert.PrivateKey.(*ecdsa.PrivateKey).Public())
	if _, err := checkMitmLeafAt(cert.Raw, ca.cert.Raw, "example.com", spki, mitmState.Load().setup.CAFingerprint, time.Now()); err != nil {
		t.Fatalf("the Core's own leaf fails the app-leaf check: %v", err)
	}
	switch {
	case !bytes.Equal(cert.RawIssuer, ca.cert.RawSubject):
		t.Error("issuer is not the CA's subject")
	case !bytes.Equal(cert.AuthorityKeyId, ca.cert.SubjectKeyId):
		t.Error("AKI is not the CA's SKI")
	case cert.Subject.CommonName != "example.com" || len(cert.DNSNames) != 1 || cert.DNSNames[0] != "example.com":
		t.Errorf("names CN %q SAN %v", cert.Subject.CommonName, cert.DNSNames)
	case cert.IsCA || !cert.BasicConstraintsValid || cert.MaxPathLen != -1:
		t.Error("basic constraints are not an empty leaf's")
	case cert.KeyUsage != x509.KeyUsageDigitalSignature:
		t.Errorf("key usage = %v", cert.KeyUsage)
	case cert.SignatureAlgorithm != x509.ECDSAWithSHA256:
		t.Errorf("signature %v", cert.SignatureAlgorithm)
	case len(cert.SerialNumber.Bytes()) != 16 || cert.SerialNumber.Bytes()[0]&0xc0 != 0x40:
		t.Errorf("serial %x", cert.SerialNumber.Bytes())
	case cert.NotBefore.After(before.Add(-mitmCertBackdate)) || cert.NotBefore.Before(before.Add(-mitmCertBackdate-2*time.Second)):
		t.Errorf("notBefore %v", cert.NotBefore)
	}
	if want := mitmLeafNotAfter(cert.NotBefore.Add(mitmCertBackdate), ca.cert.NotAfter); !cert.NotAfter.Equal(want.Truncate(time.Second)) {
		t.Errorf("notAfter %v, want %v", cert.NotAfter, want)
	}
	if critical, _ := extensionCritical(cert, oidBasicConstraints); !critical {
		t.Error("basic constraints not critical")
	}
	if critical, _ := extensionCritical(cert, oidKeyUsage); !critical {
		t.Error("key usage not critical")
	}
	if critical, found := extensionCritical(cert, oidExtKeyUsage); !found || critical {
		t.Error("EKU missing or critical")
	}
	if len(cert.SubjectKeyId) != 0 {
		t.Error("the leaf carries an SKI")
	}
}

func TestMitmLeafNeverOutlivesAnImportedRoot(t *testing.T) {
	withMitmCAState(t)
	p12, pass, cert := testCAP12(t, testCAOptions{edit: func(template *x509.Certificate) {
		template.NotAfter = time.Now().Add(26 * time.Hour)
	}})
	loadTestCA(t, p12, pass, cert)
	if err := handleMitmUpdate(MitmUpdateParams{Setup: coreSignerSetup(mitmFingerprintDisplay(cert.Raw), "example.com")}); err != nil {
		t.Fatal(err)
	}
	leaseTestCA(t)
	leaf, err := issueMitmLeaf(context.Background(), "example.com")
	if err != nil {
		t.Fatal(err)
	}
	if !leaf.notAfter.Equal(cert.NotAfter) {
		t.Errorf("leaf notAfter %v, want the root's %v", leaf.notAfter, cert.NotAfter)
	}
	if leaf.cert.Leaf.Issuer.CommonName != "Imported Test CA" {
		t.Errorf("issuer %q, want the imported root's own subject", leaf.cert.Leaf.Issuer.CommonName)
	}
}

func TestMitmCAImportAcceptsOnlyARootBrowsersTakeLeavesFrom(t *testing.T) {
	rsaKey := func(bits int) crypto.Signer {
		key, err := rsa.GenerateKey(rand.Reader, bits)
		if err != nil {
			t.Fatal(err)
		}
		return key
	}
	ecKey := func(curve elliptic.Curve) crypto.Signer {
		key, err := ecdsa.GenerateKey(curve, rand.Reader)
		if err != nil {
			t.Fatal(err)
		}
		return key
	}
	_, edKey, _ := ed25519.GenerateKey(rand.Reader)
	otherKey := newLeafKey(t)
	_, _, otherRoot := testCAP12(t, testCAOptions{key: otherKey})
	cases := []struct {
		name    string
		options testCAOptions
		pass    string
		want    mitmCARefusal
	}{
		{name: "P-256", options: testCAOptions{}},
		{name: "P-384", options: testCAOptions{key: ecKey(elliptic.P384())}},
		{name: "RSA 2048", options: testCAOptions{key: rsaKey(2048)}},
		{name: "EKU any", options: testCAOptions{edit: func(c *x509.Certificate) { c.ExtKeyUsage = []x509.ExtKeyUsage{x509.ExtKeyUsageAny} }}},
		{name: "wrong passphrase", pass: "nope", want: mitmCABadPassphrase},
		{name: "RSA 1024", options: testCAOptions{key: rsaKey(1024)}, want: mitmCAUnsupportedKey},
		{name: "P-224", options: testCAOptions{key: ecKey(elliptic.P224())}, want: mitmCAUnsupportedKey},
		{name: "Ed25519", options: testCAOptions{key: edKey}, want: mitmCAUnsupportedKey},
		{name: "not a CA", options: testCAOptions{edit: func(c *x509.Certificate) { c.IsCA = false }}, want: mitmCANotCA},
		{name: "no keyCertSign", options: testCAOptions{edit: func(c *x509.Certificate) { c.KeyUsage = x509.KeyUsageDigitalSignature }}, want: mitmCANoCertSign},
		{name: "client auth only", options: testCAOptions{edit: func(c *x509.Certificate) { c.ExtKeyUsage = []x509.ExtKeyUsage{x509.ExtKeyUsageClientAuth} }}, want: mitmCANoServerAuth},
		{name: "permitted names", options: testCAOptions{edit: func(c *x509.Certificate) { c.PermittedDNSDomains = []string{"example.com"} }}, want: mitmCANameConstraints},
		{name: "excluded names", options: testCAOptions{edit: func(c *x509.Certificate) { c.ExcludedDNSDomains = []string{"bank.example"} }}, want: mitmCANameConstraints},
		{name: "expired", options: testCAOptions{edit: func(c *x509.Certificate) { c.NotAfter = time.Now().Add(-time.Minute) }}, want: mitmCAExpired},
		{name: "not yet valid", options: testCAOptions{edit: func(c *x509.Certificate) { c.NotBefore = time.Now().Add(time.Hour) }}, want: mitmCANotYetValid},
		{name: "intermediate", options: testCAOptions{parent: otherRoot, signer: otherKey, edit: func(c *x509.Certificate) { c.Issuer = otherRoot.Subject }}, want: mitmCANotRoot},
		{name: "key of another certificate", options: testCAOptions{p12Key: newLeafKey(t)}, want: mitmCAKeyMismatch},
	}
	for _, test := range cases {
		t.Run(test.name, func(t *testing.T) {
			p12, pass, cert := testCAP12(t, test.options)
			if test.pass != "" {
				pass = test.pass
			}
			info, err := handleMitmInspectCA(MitmCAParams{P12: p12, Passphrase: mitmCAPassphrase(pass)})
			if test.want == "" {
				if err != nil || info.Fingerprint != mitmFingerprintDisplay(cert.Raw) || info.Subject != "Imported Test CA" {
					t.Fatalf("inspect = %+v, %v; want the root accepted", info, err)
				}
				return
			}
			var methodErr *MethodError
			if !errors.As(err, &methodErr) || methodErr.Details.(map[string]string)["reason"] != string(test.want) {
				t.Fatalf("inspect error = %v, want %s", err, test.want)
			}
			if strings.Contains(methodErr.Message, pass) {
				t.Error("the error names the passphrase")
			}
		})
	}
	for _, garbage := range [][]byte{nil, []byte("not a p12"), make([]byte, mitmCAP12Max+1)} {
		if _, _, err := decodeMitmCA(garbage, "x", time.Now()); !errors.Is(err, mitmCABadP12) {
			t.Errorf("garbage of %d bytes: %v", len(garbage), err)
		}
	}
}

func TestMitmSetCARequiresTheNamedFingerprint(t *testing.T) {
	withMitmCAState(t)
	generated := generatedTestCA(t)
	other := generatedTestCA(t)
	_, err := handleMitmSetCASeq(MitmCAParams{P12: generated.P12, Passphrase: generated.Passphrase, Fingerprint: other.Fingerprint}, 0)
	if !errors.Is(err, mitmCAFingerprint) || mitmCA.Load() != nil {
		t.Fatalf("setCA under another fingerprint = %v, loaded %v", err, mitmCA.Load() != nil)
	}
}

func TestMitmCASecretsPrintAsAMarkWithEveryVerb(t *testing.T) {
	generated := generatedTestCA(t)
	encoded := base64.StdEncoding.EncodeToString(generated.P12)
	params := MitmCAParams{P12: generated.P12, Passphrase: generated.Passphrase, Fingerprint: generated.Fingerprint}
	values := []any{generated.P12, generated.Passphrase, params, &params, generated, &generated,
		struct{ Params MitmCAParams }{params}, []any{generated.P12, generated.Passphrase}}
	for _, verb := range []string{"%v", "%+v", "%#v", "%s", "%q", "%x", "%X", "%d", "%10.3v", "%-v", "%08x"} {
		for _, value := range values {
			printed := fmt.Sprintf(verb, value)
			if !strings.Contains(printed, mitmCAMark) || strings.Contains(printed, string(generated.Passphrase)) ||
				strings.Contains(printed, encoded[:16]) || strings.Contains(printed, hex.EncodeToString(generated.P12[:8])) {
				t.Fatalf("%s of %T printed %q", verb, value, printed)
			}
		}
	}
	if data, _ := json.Marshal(params); !strings.Contains(string(data), encoded) {
		t.Error("JSON no longer carries the p12 the app sent")
	}
}

func TestMitmCAMethodsLogNoSecretAndAreNeverSpilled(t *testing.T) {
	skipUnlessMitmCAHandled(t)
	withMitmCAState(t)
	generated := generatedTestCA(t)
	encoded := base64.StdEncoding.EncodeToString(generated.P12)
	subscriber := logSubscribe(t)
	call := func(method CoreMethod, arguments string) string {
		return string(handleMethodCall(&MethodCall{ID: "1", Method: method, Arguments: json.RawMessage(arguments)}))
	}
	good := fmt.Sprintf(`{"p12":%q,"passphrase":%q,"fingerprint":%q}`, encoded, generated.Passphrase, generated.Fingerprint)
	wrong := fmt.Sprintf(`{"p12":%q,"passphrase":"wrong-%s"}`, encoded, generated.Passphrase)
	for _, reply := range []string{
		call(mitmInspectCAMethod, wrong),
		call(mitmSetCAMethod, wrong),
		call(mitmSetCAMethod, good[:len(good)/2]),
		call(mitmSetCAMethod, `{"p12":"!!!","passphrase":"`+string(generated.Passphrase)+`"}`),
		call(mitmSetCAMethod, good),
		call(mitmIssueCertificateMethod, `{"host":"example.com"}`),
		call(mitmSetCAMethod, `null`),
	} {
		if strings.Contains(reply, string(generated.Passphrase)) || strings.Contains(reply, encoded[:32]) {
			t.Fatalf("a reply carries the CA: %s", reply)
		}
		if strings.Contains(reply, `"file"`) {
			t.Fatalf("a CA reply was spilled: %s", reply)
		}
	}
	if reply := call(mitmGenerateCertificateMethod, ``); !strings.Contains(reply, `"passphrase"`) || strings.Contains(reply, `"file"`) {
		t.Fatalf("generate reply = %.80s", reply)
	}
	for method := range mitmCAHandlers {
		if !mitmCASecretMethods[method] {
			t.Errorf("%s may be spilled", method)
		}
	}
	logError("probe %v %v", MitmCAParams{P12: generated.P12, Passphrase: generated.Passphrase}, generated)
	if leaked := drainLogStream(t, subscriber, 300*time.Millisecond, func(payload string) bool {
		return strings.Contains(payload, string(generated.Passphrase)) || strings.Contains(payload, encoded[:32])
	}); leaked {
		t.Fatal("the log carries the CA")
	}
}

func TestMitmCoreSignerGates(t *testing.T) {
	cases := []struct {
		name  string
		hosts []string
		host  string
		edit  func(*MitmSetup)
		want  func(error) bool
	}{
		{name: "listed", hosts: []string{"example.com"}, host: "example.com", want: func(err error) bool { return err == nil }},
		{name: "not listed", hosts: []string{"example.com"}, host: "other.com", want: isErr(errMitmNotListed)},
		{name: "excluded", hosts: []string{"-a.example.com", "*.example.com"}, host: "a.example.com", want: isErr(errMitmNotListed)},
		{name: "decryption off", hosts: []string{"example.com"}, host: "example.com", edit: func(s *MitmSetup) { s.DecryptTLS = false }, want: isErr(errMitmNotListed)},
		{name: "check host on the listed path", hosts: []string{mitmCheckHost}, host: mitmCheckHost, want: isRefusal("notListed")},
		{name: "not a DNS name", hosts: []string{"*.example.com"}, host: "a_b.example.com", want: isErr(errMitmNotListed)},
		{name: "runtime under another CA", hosts: []string{"example.com"}, host: "example.com", edit: func(s *MitmSetup) { s.CAFingerprint = strings.Repeat("ab", 32) }, want: isRefusal("trustUnavailable")},
	}
	for _, test := range cases {
		t.Run(test.name, func(t *testing.T) {
			generated := withCoreSigner(t, test.hosts...)
			setup := coreSignerSetup(generated.Fingerprint, test.hosts...)
			if test.edit != nil {
				test.edit(setup)
				if err := handleMitmUpdate(MitmUpdateParams{Setup: setup}); err != nil {
					t.Fatal(err)
				}
			}
			_, err := issueMitmLeaf(context.Background(), test.host)
			if !test.want(err) {
				t.Fatalf("issue %s = %v", test.host, err)
			}
		})
	}
	t.Run("invalid name even when matched", func(t *testing.T) {
		withCoreSigner(t, "*.example.com")
		runtime := &mitmRuntime{setup: *coreSignerSetup(mitmFingerprintDisplay(mitmCA.Load().cert.Raw)), hosts: &mitmHostMatcher{entries: []mitmHostEntry{{wildcard: true, base: "example.com"}}}}
		runtime.setup.Hostname = []string{"*.example.com"}
		mitmState.Store(runtime)
		if _, err := issueMitmLeafLocal(runtime, "x.example.com"); err != nil {
			t.Errorf("x.example.com: %v", err)
		}
		// The matcher applies validDNSName itself; the signer's own check
		// stays as a second gate.
		for _, host := range []string{"*.example.com", "a..example.com", "a_b.example.com"} {
			if _, err := issueMitmLeafLocal(runtime, host); !errors.Is(err, errMitmNotListed) {
				t.Errorf("%s: %v, want not listed", host, err)
			}
		}
	})
}

func skipUnlessMitmCAHandled(t *testing.T) {
	t.Helper()
	if _, handled := methodHandlers[mitmSetCAMethod]; !handled {
		t.Skip("the CA methods are dispatched on macOS only")
	}
}

func logSubscribe(t *testing.T) observable.Subscription[log.Event] {
	t.Helper()
	subscriber := log.Subscribe()
	t.Cleanup(func() { log.UnSubscribe(subscriber) })
	return subscriber
}

func isErr(target error) func(error) bool {
	return func(err error) bool { return errors.Is(err, target) }
}

func isRefusal(reason string) func(error) bool {
	return func(err error) bool {
		var refusal mitmAppRefusal
		return errors.As(err, &refusal) && string(refusal) == reason
	}
}

func TestMitmLoadedCASignsOnlyTheCheckHostUntilLeased(t *testing.T) {
	skipUnlessMitmCAHandled(t)
	withMitmCAState(t)
	generated := generatedTestCA(t)
	if _, err := handleMitmIssueCheck(); !errors.Is(err, mitmCANotLoaded) {
		t.Fatalf("check without a CA = %v", err)
	}
	if _, err := handleMitmSetCASeq(MitmCAParams{P12: generated.P12, Passphrase: generated.Passphrase, Fingerprint: generated.Fingerprint}, 0); err != nil {
		t.Fatal(err)
	}
	if err := handleMitmUpdate(MitmUpdateParams{Setup: coreSignerSetup(generated.Fingerprint, "example.com")}); err != nil {
		t.Fatal(err)
	}
	if _, err := issueMitmLeaf(context.Background(), "example.com"); !isRefusal("trustUnavailable")(err) {
		t.Fatalf("loaded but not leased: %v", err)
	}
	reply := handleMethodCall(&MethodCall{ID: "1", Method: mitmIssueCertificateMethod, Arguments: json.RawMessage(`{"host":"example.com"}`)})
	var response struct {
		Result MitmCheckCertificate `json:"result"`
	}
	if err := json.Unmarshal(reply, &response); err != nil {
		t.Fatal(err)
	}
	block, _ := pem.Decode([]byte(response.Result.PEM))
	if block == nil {
		t.Fatalf("issueCertificate reply = %s", reply)
	}
	leaf, err := x509.ParseCertificate(block.Bytes)
	if err != nil || len(leaf.DNSNames) != 1 || leaf.DNSNames[0] != mitmCheckHost || leaf.Subject.CommonName != mitmCheckHost {
		t.Fatalf("check leaf names %v (%v), want the check host whatever was asked", leaf.DNSNames, err)
	}
	if leaf.SerialNumber.Text(16) != response.Result.Check {
		t.Error("the check id is not the check leaf's serial")
	}
	if _, err := handleMitmTrustLease(MitmTrustLeaseParams{Fingerprint: generated.Fingerprint, Check: response.Result.Check}); err != nil {
		t.Fatal(err)
	}
	if _, err := issueMitmLeaf(context.Background(), "example.com"); err != nil {
		t.Fatalf("leased: %v", err)
	}
}

func TestMitmTrustLeaseRunsFromTheCheckAndOnlyOnce(t *testing.T) {
	withMitmCAState(t)
	mitmCALeaseMax = 400 * time.Millisecond
	generated := generatedTestCA(t)
	loadTestCAGenerated(t, generated)
	check, _ := handleMitmIssueCheck()
	time.Sleep(150 * time.Millisecond)
	state, err := handleMitmTrustLease(MitmTrustLeaseParams{Fingerprint: generated.Fingerprint, Check: check.Check})
	if err != nil {
		t.Fatal(err)
	}
	if state.LeaseMillis > 260 || state.LeaseMillis <= 0 {
		t.Errorf("lease %dms after a 150ms-old check, want at most 250ms", state.LeaseMillis)
	}
	if _, err := handleMitmTrustLease(MitmTrustLeaseParams{Fingerprint: generated.Fingerprint, Check: check.Check}); !errors.Is(err, mitmCAUnknownCheck) {
		t.Errorf("a check reused: %v", err)
	}
	if _, err := handleMitmTrustLease(MitmTrustLeaseParams{Fingerprint: generated.Fingerprint, Check: "40"}); !errors.Is(err, mitmCAUnknownCheck) {
		t.Errorf("an unknown check: %v", err)
	}
	short, _ := handleMitmIssueCheck()
	if state, _ := handleMitmTrustLease(MitmTrustLeaseParams{Fingerprint: generated.Fingerprint, Check: short.Check, ValidForMillis: 3_600_000}); state.LeaseMillis > 400 {
		t.Errorf("an hour asked for, %dms granted", state.LeaseMillis)
	}
	other := generatedTestCA(t)
	late, _ := handleMitmIssueCheck()
	if _, err := handleMitmTrustLease(MitmTrustLeaseParams{Fingerprint: other.Fingerprint, Check: late.Check}); !errors.Is(err, mitmCAFingerprint) {
		t.Errorf("lease under another fingerprint: %v", err)
	}
	stale, _ := handleMitmIssueCheck()
	time.Sleep(450 * time.Millisecond)
	if _, err := handleMitmTrustLease(MitmTrustLeaseParams{Fingerprint: generated.Fingerprint, Check: stale.Check}); !errors.Is(err, mitmCALeaseLapsed) && !errors.Is(err, mitmCAUnknownCheck) {
		t.Errorf("a check older than the lease: %v", err)
	}
}

func loadTestCAGenerated(t *testing.T, generated MitmGeneratedCA) {
	t.Helper()
	if _, err := handleMitmSetCASeq(MitmCAParams{P12: bytes.Clone(generated.P12), Passphrase: generated.Passphrase, Fingerprint: generated.Fingerprint}, 0); err != nil {
		t.Fatal(err)
	}
}

// Calls run on their own goroutines; one the app sent earlier that runs
// later must not undo a clear.
func TestMitmCAIntentsApplyInTheOrderSent(t *testing.T) {
	withMitmCAState(t)
	generated := generatedTestCA(t)
	load := MitmCAParams{P12: bytes.Clone(generated.P12), Passphrase: generated.Passphrase, Fingerprint: generated.Fingerprint}
	loadSeq, clearSeq := methodCallSeq.Add(1), methodCallSeq.Add(1)
	markMitmCAIntent(loadSeq)
	markMitmCAIntent(clearSeq)
	if _, err := handleMitmSetCASeq(MitmCAParams{}, clearSeq); err != nil {
		t.Fatal(err)
	}
	if state, err := handleMitmSetCASeq(load, loadSeq); err != nil || state.Loaded || mitmCA.Load() != nil {
		t.Fatalf("an earlier setCA reloaded the CA after the clear: %+v %v", state, err)
	}

	loadTestCAGenerated(t, generated)
	check, _ := handleMitmIssueCheck()
	_, _ = handleMitmSetCASeq(MitmCAParams{}, 0)
	loadTestCAGenerated(t, generated)
	if _, err := handleMitmTrustLease(MitmTrustLeaseParams{Fingerprint: generated.Fingerprint, Check: check.Check}); !errors.Is(err, mitmCAUnknownCheck) {
		t.Fatalf("a lease from before a clear applied to the CA loaded after it: %v", err)
	}

	pending := methodCallSeq.Add(1)
	markMitmCAIntent(pending)
	mitmSignerGone()
	if mitmCA.Load() != nil {
		t.Fatal("the CA outlived the relay")
	}
	if state, _ := handleMitmSetCASeq(load, pending); state.Loaded {
		t.Fatal("a setCA sent before the relay closed loaded the CA after it")
	}
}

func TestMitmAppSignerNeverUsesTheLoadedCA(t *testing.T) {
	generated := withCoreSigner(t, "example.com")
	setup := coreSignerSetup(generated.Fingerprint, "example.com")
	setup.Signer = ""
	if err := handleMitmUpdate(MitmUpdateParams{Setup: setup}); err != nil {
		t.Fatal(err)
	}
	asked := 0
	sendMitmSign = func(*MitmSignRequest) bool { asked++; return false }
	if _, err := issueMitmLeaf(context.Background(), "example.com"); !errors.Is(err, errMitmSignDropped) || asked != 1 {
		t.Fatalf("app mode = %v after %d asks, want the app asked", err, asked)
	}
}

func TestMitmSignerModeChangeDropsKeptLeaves(t *testing.T) {
	generated := withCoreSigner(t, "example.com")
	if _, err := mitmLeaves.get(context.Background(), "example.com"); err != nil {
		t.Fatal(err)
	}
	setup := coreSignerSetup(generated.Fingerprint, "example.com")
	setup.Signer = "app"
	if err := handleMitmUpdate(MitmUpdateParams{Setup: setup}); err != nil {
		t.Fatal(err)
	}
	mitmLeaves.mu.Lock()
	kept := len(mitmLeaves.ready)
	mitmLeaves.mu.Unlock()
	if kept != 0 {
		t.Fatal("a leaf the Core signed is kept for the app signer")
	}
}

func TestMitmSHA1RootIsAWeakSignatureNotANonRoot(t *testing.T) {
	withMitmCAState(t)
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	p12, pass, _ := testCAP12(t, testCAOptions{key: key, edit: func(template *x509.Certificate) {
		template.SignatureAlgorithm = x509.SHA1WithRSA
	}})
	if _, _, err := decodeMitmCA(p12, mitmCAPassphrase(pass), time.Now()); !errors.Is(err, mitmCAWeakSignature) {
		t.Fatalf("SHA-1 root: %v", err)
	}
}

// fmt never calls Format on an unexported field: holding a secret in one
// would print it. This pins the limitation the types' comment warns of.
func TestMitmCASecretInAnUnexportedFieldIsNotMasked(t *testing.T) {
	holder := struct{ passphrase mitmCAPassphrase }{"hunter2"}
	if !strings.Contains(fmt.Sprintf("%+v", holder), "hunter2") {
		t.Skip("fmt now masks unexported fields too")
	}
	if strings.Contains(fmt.Sprintf("%+v", struct{ Passphrase mitmCAPassphrase }{"hunter2"}), "hunter2") {
		t.Fatal("an exported field printed the secret")
	}
}
