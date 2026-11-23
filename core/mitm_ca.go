package core

import (
	"bytes"
	"crypto"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha1"
	"crypto/sha256"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/base64"
	"encoding/hex"
	"encoding/pem"
	"errors"
	"fmt"
	"math/big"
	"strings"
	"time"

	"software.sslmate.com/src/go-pkcs12"
)

// The CA the Core signs leaves with on macOS, held as the app stores it: a
// PKCS#12 file and its passphrase, neither of which may reach a log.
const (
	mitmCAMark       = "[MITM CA]"
	mitmCheckHost    = "mitm-check.flclash.invalid"
	mitmCAP12Max     = 64 << 10
	mitmRootLifetime = 365 * 24 * time.Hour
	mitmLeafLifetime = 7 * 24 * time.Hour
	mitmCertBackdate = 5 * time.Minute
)

// Prints as a mark with any verb; JSON still carries the bytes. fmt skips
// Format on an unexported field, so never hold these in one.
type mitmCAP12 []byte

func (mitmCAP12) Format(state fmt.State, _ rune) { _, _ = state.Write([]byte(mitmCAMark)) }

type mitmCAPassphrase string

func (mitmCAPassphrase) Format(state fmt.State, _ rune) { _, _ = state.Write([]byte(mitmCAMark)) }

// Field names as lib/models/core.dart MitmCertificate reads them.
type MitmCertificate struct {
	PEM         string    `json:"pem"`
	Fingerprint string    `json:"fingerprint"`
	Subject     string    `json:"subject"`
	NotBefore   time.Time `json:"not-before"`
	NotAfter    time.Time `json:"not-after"`
}

type MitmCAParams struct {
	P12         mitmCAP12        `json:"p12,omitempty"`
	Passphrase  mitmCAPassphrase `json:"passphrase,omitempty"`
	Fingerprint string           `json:"fingerprint,omitempty"`
}

func (MitmCAParams) Format(state fmt.State, _ rune) { _, _ = state.Write([]byte(mitmCAMark)) }

type MitmGeneratedCA struct {
	P12        mitmCAP12        `json:"p12"`
	Passphrase mitmCAPassphrase `json:"passphrase"`
	MitmCertificate
}

func (MitmGeneratedCA) Format(state fmt.State, _ rune) { _, _ = state.Write([]byte(mitmCAMark)) }

// Why a CA is refused, as a stable code for the app to word.
type mitmCARefusal string

const (
	mitmCABadP12          mitmCARefusal = "badP12"
	mitmCABadPassphrase   mitmCARefusal = "badPassphrase"
	mitmCANotCA           mitmCARefusal = "notCA"
	mitmCANotRoot         mitmCARefusal = "notRoot"
	mitmCAKeyMismatch     mitmCARefusal = "keyMismatch"
	mitmCAUnsupportedKey  mitmCARefusal = "unsupportedKey"
	mitmCANotYetValid     mitmCARefusal = "notYetValid"
	mitmCAExpired         mitmCARefusal = "expired"
	mitmCANoCertSign      mitmCARefusal = "noCertSign"
	mitmCANoServerAuth    mitmCARefusal = "noServerAuth"
	mitmCANameConstraints mitmCARefusal = "nameConstraints"
	mitmCACriticalExt     mitmCARefusal = "unknownCriticalExtension"
	mitmCAFingerprint     mitmCARefusal = "fingerprintMismatch"
	mitmCANotLoaded       mitmCARefusal = "notLoaded"
	mitmCAUnknownCheck    mitmCARefusal = "unknownCheck"
	mitmCALeaseLapsed     mitmCARefusal = "leaseLapsed"
	mitmCASuperseded      mitmCARefusal = "superseded"
	mitmCAWeakSignature   mitmCARefusal = "weakSignature"
	mitmCAUnsupported     mitmCARefusal = "unsupportedPlatform"
)

func (refusal mitmCARefusal) Error() string {
	return "MITM CA refused: " + string(refusal)
}

func mitmCAMethodError(err error) error {
	var refusal mitmCARefusal
	if errors.As(err, &refusal) {
		return &MethodError{Code: "mitm_ca", Message: refusal.Error(), Details: map[string]string{"reason": string(refusal)}}
	}
	return &MethodError{Code: "mitm_ca", Message: "MITM CA operation failed", Details: map[string]string{"reason": "failed"}}
}

func mitmFingerprintHex(der []byte) string {
	sum := sha256.Sum256(der)
	return hex.EncodeToString(sum[:])
}

// Colon-separated upper-case hex, as MitmCertificateBuilder.fingerprint.
func mitmFingerprintDisplay(der []byte) string {
	sum := sha256.Sum256(der)
	parts := make([]string, len(sum))
	for i, b := range sum {
		parts[i] = strings.ToUpper(hex.EncodeToString([]byte{b}))
	}
	return strings.Join(parts, ":")
}

func mitmCertificateInfo(cert *x509.Certificate) MitmCertificate {
	return MitmCertificate{
		PEM:         string(pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: cert.Raw})),
		Fingerprint: mitmFingerprintDisplay(cert.Raw),
		Subject:     cert.Subject.CommonName,
		NotBefore:   cert.NotBefore.UTC(),
		NotAfter:    cert.NotAfter.UTC(),
	}
}

// Decodes and vets a CA; the caller keeps neither input.
func decodeMitmCA(p12 mitmCAP12, passphrase mitmCAPassphrase, now time.Time) (crypto.Signer, *x509.Certificate, error) {
	if len(p12) == 0 || len(p12) > mitmCAP12Max {
		return nil, nil, mitmCABadP12
	}
	key, first, chain, err := pkcs12.DecodeChain(p12, string(passphrase))
	switch {
	case errors.Is(err, pkcs12.ErrIncorrectPassword), errors.Is(err, pkcs12.ErrDecryption):
		return nil, nil, mitmCABadPassphrase
	case err != nil:
		return nil, nil, mitmCABadP12
	}
	signer, ok := key.(crypto.Signer)
	if !ok {
		return nil, nil, mitmCAUnsupportedKey
	}
	var cert *x509.Certificate
	for _, candidate := range append([]*x509.Certificate{first}, chain...) {
		if publicKeyEqual(candidate.PublicKey, signer.Public()) {
			cert = candidate
			break
		}
	}
	if cert == nil {
		return nil, nil, mitmCAKeyMismatch
	}
	if err := vetMitmCA(cert, signer, now); err != nil {
		return nil, nil, err
	}
	return signer, cert, nil
}

func publicKeyEqual(a, b crypto.PublicKey) bool {
	equal, ok := a.(interface{ Equal(crypto.PublicKey) bool })
	return ok && equal.Equal(b)
}

// Leaves it signs must pass a browser, not only checkMitmLeafAt.
func vetMitmCA(cert *x509.Certificate, key crypto.Signer, now time.Time) error {
	switch public := key.Public().(type) {
	case *ecdsa.PublicKey:
		if public.Curve != elliptic.P256() && public.Curve != elliptic.P384() {
			return mitmCAUnsupportedKey
		}
	case *rsa.PublicKey:
		if public.N.BitLen() < 2048 {
			return mitmCAUnsupportedKey
		}
	default:
		return mitmCAUnsupportedKey
	}
	switch {
	case !cert.BasicConstraintsValid || !cert.IsCA:
		return mitmCANotCA
	case cert.KeyUsage&x509.KeyUsageCertSign == 0:
		return mitmCANoCertSign
	case !bytes.Equal(cert.RawIssuer, cert.RawSubject):
		return mitmCANotRoot
	case mitmWeakSignature(cert.SignatureAlgorithm):
		return mitmCAWeakSignature
	case cert.CheckSignatureFrom(cert) != nil:
		return mitmCANotRoot
	case now.Before(cert.NotBefore):
		return mitmCANotYetValid
	case !now.Before(cert.NotAfter):
		return mitmCAExpired
	case !mitmEKUAllowsServerAuth(cert):
		return mitmCANoServerAuth
	case mitmHasNameConstraints(cert):
		return mitmCANameConstraints
	case len(cert.UnhandledCriticalExtensions) > 0:
		return mitmCACriticalExt
	}
	return nil
}

func mitmWeakSignature(algorithm x509.SignatureAlgorithm) bool {
	switch algorithm {
	case x509.MD2WithRSA, x509.MD5WithRSA, x509.SHA1WithRSA, x509.DSAWithSHA1, x509.ECDSAWithSHA1:
		return true
	}
	return false
}

func mitmEKUAllowsServerAuth(cert *x509.Certificate) bool {
	if len(cert.ExtKeyUsage) == 0 && len(cert.UnknownExtKeyUsage) == 0 {
		return true
	}
	for _, usage := range cert.ExtKeyUsage {
		if usage == x509.ExtKeyUsageServerAuth || usage == x509.ExtKeyUsageAny {
			return true
		}
	}
	return false
}

// The user's list changes; a constrained root would refuse some of it.
func mitmHasNameConstraints(cert *x509.Certificate) bool {
	return cert.PermittedDNSDomainsCritical || len(cert.PermittedDNSDomains) > 0 ||
		len(cert.ExcludedDNSDomains) > 0 || len(cert.PermittedIPRanges) > 0 ||
		len(cert.ExcludedIPRanges) > 0 || len(cert.PermittedEmailAddresses) > 0 ||
		len(cert.ExcludedEmailAddresses) > 0 || len(cert.PermittedURIDomains) > 0 ||
		len(cert.ExcludedURIDomains) > 0
}

func handleMitmInspectCA(params MitmCAParams) (MitmCertificate, error) {
	_, cert, err := decodeMitmCA(params.P12, params.Passphrase, time.Now())
	clear(params.P12)
	if err != nil {
		return MitmCertificate{}, mitmCAMethodError(err)
	}
	return mitmCertificateInfo(cert), nil
}

func mitmSerial() (*big.Int, error) {
	serial := make([]byte, 16)
	if _, err := rand.Read(serial); err != nil {
		return nil, err
	}
	serial[0] = serial[0]&0x7f | 0x40
	return new(big.Int).SetBytes(serial), nil
}

// Distinct from the legacy keychain root's "Flash 本机解密证书（仅此 Mac）", so
// removing that one by its label never touches this one.
func mitmRootName(now time.Time, keyID []byte) string {
	return fmt.Sprintf("Flash 解密证书 %s %x", now.UTC().Format("2006-01-02"), keyID[:4])
}

// MitmCertificateBuilder.root: one year, path length 0, keyCertSign and
// cRLSign, EKU serverAuth, no name constraints.
func mitmRootTemplate(key *ecdsa.PrivateKey, now time.Time) (*x509.Certificate, error) {
	serial, err := mitmSerial()
	if err != nil {
		return nil, err
	}
	point, err := key.PublicKey.Bytes()
	if err != nil {
		return nil, err
	}
	keyID := sha1.Sum(point)
	name := pkix.Name{Organization: []string{"Flash"}, CommonName: mitmRootName(now, keyID[:])}
	notBefore := now.Add(-mitmCertBackdate)
	return &x509.Certificate{
		SerialNumber:          serial,
		Subject:               name,
		NotBefore:             notBefore,
		NotAfter:              notBefore.Add(mitmRootLifetime),
		IsCA:                  true,
		BasicConstraintsValid: true,
		MaxPathLen:            0,
		MaxPathLenZero:        true,
		KeyUsage:              x509.KeyUsageCertSign | x509.KeyUsageCRLSign,
		ExtKeyUsage:           []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth},
		SubjectKeyId:          keyID[:],
	}, nil
}

func generateMitmCA(now time.Time) (MitmGeneratedCA, error) {
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		return MitmGeneratedCA{}, err
	}
	template, err := mitmRootTemplate(key, now)
	if err != nil {
		return MitmGeneratedCA{}, err
	}
	der, err := x509.CreateCertificate(rand.Reader, template, template, &key.PublicKey, key)
	if err != nil {
		return MitmGeneratedCA{}, err
	}
	cert, err := x509.ParseCertificate(der)
	if err != nil {
		return MitmGeneratedCA{}, err
	}
	secret := make([]byte, 32)
	if _, err := rand.Read(secret); err != nil {
		return MitmGeneratedCA{}, err
	}
	passphrase := base64.RawURLEncoding.EncodeToString(secret)
	p12, err := pkcs12.Modern2023.Encode(key, cert, nil, passphrase)
	if err != nil {
		return MitmGeneratedCA{}, err
	}
	return MitmGeneratedCA{P12: p12, Passphrase: mitmCAPassphrase(passphrase), MitmCertificate: mitmCertificateInfo(cert)}, nil
}

func handleMitmGenerateCA() (MitmGeneratedCA, error) {
	generated, err := generateMitmCA(time.Now())
	if err != nil {
		return MitmGeneratedCA{}, mitmCAMethodError(err)
	}
	return generated, nil
}

func mitmLeafNotAfter(now, limit time.Time) time.Time {
	notAfter := now.Add(mitmLeafLifetime - mitmCertBackdate)
	if notAfter.After(limit) {
		return limit
	}
	return notAfter
}

// MitmCertificateBuilder.leaf: host alone, seven days but never past the
// root, never a CA. The issuer and AKI come from the CA as it is.
func signMitmLeaf(key crypto.Signer, ca *x509.Certificate, host string, public crypto.PublicKey, now time.Time) ([]byte, error) {
	if !validDNSName(host) || host != normalizeMitmHost(host) {
		return nil, errMitmBadHost
	}
	serial, err := mitmSerial()
	if err != nil {
		return nil, err
	}
	template := &x509.Certificate{
		SerialNumber:          serial,
		Subject:               pkix.Name{CommonName: host},
		DNSNames:              []string{host},
		NotBefore:             now.Add(-mitmCertBackdate),
		NotAfter:              mitmLeafNotAfter(now, ca.NotAfter),
		BasicConstraintsValid: true,
		KeyUsage:              x509.KeyUsageDigitalSignature,
		ExtKeyUsage:           []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth},
	}
	return x509.CreateCertificate(rand.Reader, template, ca, public, key)
}

var errMitmBadHost = errors.New("not a DNS name a leaf can be signed for")
