package core

import (
	"bytes"
	"context"
	"crypto"
	"crypto/sha256"
	"crypto/x509"
	"encoding/hex"
	"errors"
	"fmt"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

// The Core holds no CA key: the app keeps it in the login keychain and signs
// a leaf from these two values alone, building every other field itself, so
// nothing the Core sends can make it sign a CA or a host off the user's list.
type MitmSignRequest struct {
	ReqID uint64 `json:"reqId"`
	Host  string `json:"host"`
	// DER SubjectPublicKeyInfo of the leaf key the Core made.
	SPKI []byte `json:"spki"`
	// Absolute wall-clock deadline allows the app to subtract relay time.
	DeadlineUnixMillis int64 `json:"deadlineUnixMillis,omitempty"`
	// Stage timing only (mitm_timing.go); never sent.
	timing uint64
}

type MitmSignResultParams struct {
	ReqID uint64 `json:"reqId"`
	Cert  []byte `json:"cert,omitempty"`
	CA    []byte `json:"ca,omitempty"`
	Error string `json:"error,omitempty"`
}

type mitmSignAnswer struct {
	leaf *x509.Certificate
	err  error
}

type mitmSignPending struct {
	host   string
	spki   []byte
	answer chan mitmSignAnswer
	timing uint64
}

const mitmSignTimeout = 10 * time.Second

var (
	mitmSignSeq      atomic.Uint64
	mitmSignMu       sync.Mutex
	mitmSignRequests = map[uint64]*mitmSignPending{}

	sendMitmSign = func(request *MitmSignRequest) bool {
		return sendMessage(MitmSignMessage, request)
	}

	errMitmNotListed   = errors.New("host is not on the decryption list")
	errMitmSignDropped = errors.New("the app did not receive the signing request")
)

// Asks the app for a leaf for host over key; the caller passes the connection
// through untouched on any error.
func requestMitmLeaf(ctx context.Context, host string, key crypto.PublicKey) (*x509.Certificate, error) {
	host = normalizeMitmHost(host)
	runtime := mitmState.Load()
	if !runtime.decrypting() || !runtime.hosts.Match(host) {
		return nil, errMitmNotListed
	}
	spki, err := x509.MarshalPKIXPublicKey(key)
	if err != nil {
		return nil, err
	}
	ctx, cancel := context.WithTimeout(ctx, mitmSignTimeout)
	defer cancel()
	deadline, _ := ctx.Deadline()
	if ctx.Err() != nil {
		return nil, ctx.Err()
	}
	timing := mitmTimingIssue(ctx)
	request := &MitmSignRequest{ReqID: mitmSignSeq.Add(1), Host: host, SPKI: spki, DeadlineUnixMillis: deadline.UnixMilli(), timing: timing}
	pending := &mitmSignPending{host: host, spki: spki, answer: make(chan mitmSignAnswer, 1), timing: timing}
	mitmSignMu.Lock()
	if mitmState.Load() != runtime {
		mitmSignMu.Unlock()
		return nil, errMitmSetupChanged
	}
	mitmSignRequests[request.ReqID] = pending
	mitmSignMu.Unlock()
	defer func() {
		mitmSignMu.Lock()
		delete(mitmSignRequests, request.ReqID)
		mitmSignMu.Unlock()
	}()
	if !sendMitmSign(request) {
		mitmTime(timing, request.ReqID, mitmStageRequestQueued, mitmResultDropped)
		return nil, errMitmSignDropped
	}
	mitmTime(timing, request.ReqID, mitmStageRequestQueued, mitmResultOK)
	select {
	case result := <-pending.answer:
		return result.leaf, result.err
	case <-ctx.Done():
		return nil, ctx.Err()
	}
}

func handleMitmSignResult(params MitmSignResultParams) bool {
	mitmSignMu.Lock()
	pending, found := mitmSignRequests[params.ReqID]
	if found {
		delete(mitmSignRequests, params.ReqID)
	}
	mitmSignMu.Unlock()
	if !found {
		return false
	}
	mitmTime(pending.timing, params.ReqID, mitmStageReplyReceived, mitmResultNone)
	var result mitmSignAnswer
	switch {
	case params.Error != "":
		result.err = mitmAppRefusal(params.Error)
	case len(params.Cert) == 0:
		result.err = errors.New("the app answered without a certificate")
	default:
		result.leaf, result.err = checkMitmLeaf(params.Cert, params.CA, pending.host, pending.spki, mitmTrustedCA())
	}
	mitmTime(pending.timing, params.ReqID, mitmStageReplyChecked, mitmTimingResult(result.err))
	pending.answer <- result
	return true
}

// The app's reason, as MitmSigner names it: coreIdentity, notListed, noRoot,
// rootExpired, badKey, signFailed or disabled.
type mitmAppRefusal string

func (refusal mitmAppRefusal) Error() string {
	return "the app refused to sign: " + string(refusal)
}

func mitmTrustedCA() string {
	runtime := mitmState.Load()
	if !runtime.decrypting() {
		return ""
	}
	return runtime.setup.CAFingerprint
}

func normalizeMitmFingerprint(fingerprint string) string {
	return strings.ToLower(strings.NewReplacer(":", "", " ", "").Replace(fingerprint))
}

// Even from the app, only the leaf asked for, under the trusted root, is served.
func checkMitmLeaf(der, caDER []byte, host string, spki []byte, trustedCA string) (*x509.Certificate, error) {
	return checkMitmLeafAt(der, caDER, host, spki, trustedCA, time.Now())
}

func checkMitmLeafAt(der, caDER []byte, host string, spki []byte, trustedCA string, now time.Time) (*x509.Certificate, error) {
	leaf, err := x509.ParseCertificate(der)
	if err != nil {
		return nil, err
	}
	ca, err := x509.ParseCertificate(caDER)
	if err != nil {
		return nil, fmt.Errorf("signing root: %w", err)
	}
	sum := sha256.Sum256(ca.Raw)
	switch {
	case now.Before(leaf.NotBefore) || !now.Before(leaf.NotAfter):
		return nil, errors.New("signed certificate is not currently valid")
	case now.Before(ca.NotBefore) || !now.Before(ca.NotAfter):
		return nil, errors.New("signing root is not currently valid")
	case trustedCA == "" || hex.EncodeToString(sum[:]) != normalizeMitmFingerprint(trustedCA):
		return nil, errors.New("signed by a root other than the trusted one")
	case leaf.CheckSignatureFrom(ca) != nil:
		return nil, errors.New("signature does not verify against the trusted root")
	case leaf.IsCA || !leaf.BasicConstraintsValid:
		return nil, errors.New("signed certificate is not a leaf")
	case !bytes.Equal(leaf.RawSubjectPublicKeyInfo, spki):
		return nil, errors.New("signed certificate carries another key")
	case len(leaf.DNSNames) != 1 || leaf.DNSNames[0] != host || len(leaf.IPAddresses) != 0:
		return nil, fmt.Errorf("signed certificate names %v, not %s", leaf.DNSNames, host)
	case len(leaf.ExtKeyUsage) != 1 || leaf.ExtKeyUsage[0] != x509.ExtKeyUsageServerAuth:
		return nil, errors.New("signed certificate is not for server authentication")
	}
	return leaf, nil
}
