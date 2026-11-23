package core

import (
	"context"
	"crypto"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"sync"
	"sync/atomic"
	"time"

	"github.com/metacubex/mihomo/log"
)

// Signing a listed host needs two states: loaded (the app handed the CA over
// a verified relay; only the trust-check leaf may be signed) and leased (a
// trust check of that CA passed). A lease runs from when the Core issued the
// check's leaf, so neither app delay nor wall-clock changes can extend it.
const mitmSignerCore = "core"

var (
	mitmCALeaseMax  = 10 * time.Second
	mitmCAChecksMax = 16

	mitmCA          atomic.Pointer[mitmLoadedCA]
	mitmCAIntentSeq uint64
	// Held while the CA key signs; a clear waits for it to drain.
	mitmCASigning sync.RWMutex
	// How far tests move the wall clock past the monotonic one.
	mitmWallSkew atomic.Int64
)

func mitmWallNow() time.Time {
	return time.Now().Round(0).Add(time.Duration(mitmWallSkew.Load()))
}

// Go's monotonic clock stands still while the Mac sleeps and the wall clock
// may be set back, so a deadline holds only while both say so.
func mitmBefore(now, deadline time.Time) bool {
	return now.Before(deadline) && mitmWallNow().Before(deadline.Round(0))
}

func mitmRemaining(deadline time.Time) time.Duration {
	return min(time.Until(deadline), deadline.Round(0).Sub(mitmWallNow()))
}

type mitmLoadedCA struct {
	key         crypto.Signer
	cert        *x509.Certificate
	fingerprint string

	mu         sync.Mutex
	retired    bool
	leaseUntil time.Time
	checks     map[string]time.Time
	expiry     *time.Timer
}

type MitmCAState struct {
	Loaded      bool   `json:"loaded"`
	Fingerprint string `json:"fingerprint,omitempty"`
	LeaseMillis int64  `json:"lease-millis"`
}

type MitmTrustLeaseParams struct {
	Fingerprint string `json:"fingerprint"`
	Check       string `json:"check"`
	// Shortens the lease below mitmCALeaseMax; never lengthens it.
	ValidForMillis int64 `json:"valid-for-millis,omitempty"`
}

type MitmCheckCertificate struct {
	PEM   string `json:"pem"`
	Check string `json:"check"`
}

const mitmTrustUnavailable = "trustUnavailable"

func (runtime *mitmRuntime) coreSigns() bool {
	return runtime != nil && runtime.setup.Signer == mitmSignerCore
}

func (ca *mitmLoadedCA) lease(now time.Time) (time.Time, bool) {
	ca.mu.Lock()
	defer ca.mu.Unlock()
	return ca.leaseUntil, !ca.retired && mitmBefore(now, ca.leaseUntil)
}

func (ca *mitmLoadedCA) retire() {
	ca.mu.Lock()
	ca.retired = true
	ca.endLeaseLocked()
	ca.mu.Unlock()
}

// The CA stays loaded; checks issued so far can no longer grant a lease.
func (ca *mitmLoadedCA) endLease() {
	ca.mu.Lock()
	ca.endLeaseLocked()
	ca.mu.Unlock()
}

func (ca *mitmLoadedCA) endLeaseLocked() {
	ca.leaseUntil = time.Time{}
	ca.checks = nil
	if ca.expiry != nil {
		ca.expiry.Stop()
		ca.expiry = nil
	}
}

// Under ca.mu: a lapsed lease is ended, so no check issued under it renews it.
func (ca *mitmLoadedCA) lapsedLocked(now time.Time) bool {
	if ca.leaseUntil.IsZero() || mitmBefore(now, ca.leaseUntil) {
		return false
	}
	ca.endLeaseLocked()
	return true
}

// A lease vouches for the decryption it was renewed under: turning that off,
// away from the Core or to another CA ends it. A new CA's lease is kept
// while decryption stays on; with decryption off no lease is kept.
func endMitmLeaseFor(previous, next *mitmRuntime) {
	if !next.decrypting() {
		if ca := mitmCA.Load(); ca != nil {
			ca.endLease()
		}
		return
	}
	if !previous.coreSigns() || !previous.decrypting() {
		return
	}
	fingerprint := normalizeMitmFingerprint(previous.setup.CAFingerprint)
	if next.coreSigns() && next.decrypting() && normalizeMitmFingerprint(next.setup.CAFingerprint) == fingerprint {
		return
	}
	if ca := mitmCA.Load(); ca != nil && ca.fingerprint == fingerprint {
		ca.endLease()
	}
}

func currentMitmCAState() MitmCAState {
	ca := mitmCA.Load()
	if ca == nil {
		return MitmCAState{}
	}
	state := MitmCAState{Loaded: true, Fingerprint: mitmFingerprintDisplay(ca.cert.Raw)}
	if until, leased := ca.lease(time.Now()); leased {
		state.LeaseMillis = mitmRemaining(until).Milliseconds()
	}
	return state
}

func markMitmCAIntent(seq uint64) {
	mitmIntentMu.Lock()
	if seq > mitmCAIntentSeq {
		mitmCAIntentSeq = seq
	}
	mitmIntentMu.Unlock()
}

// Loads the CA, or with no p12 clears it. Of calls racing on their own
// goroutines, only the one the app sent last applies.
func handleMitmSetCASeq(params MitmCAParams, seq uint64) (MitmCAState, error) {
	var next *mitmLoadedCA
	if len(params.P12) == 0 && params.Fingerprint != "" {
		return MitmCAState{}, mitmCABadP12
	}
	if len(params.P12) > 0 {
		key, cert, err := decodeMitmCA(params.P12, params.Passphrase, time.Now())
		clear(params.P12)
		if err != nil {
			return MitmCAState{}, err
		}
		fingerprint := mitmFingerprintHex(cert.Raw)
		if normalizeMitmFingerprint(params.Fingerprint) != fingerprint {
			return MitmCAState{}, mitmCAFingerprint
		}
		next = &mitmLoadedCA{key: key, cert: cert, fingerprint: fingerprint}
	}
	mitmIntentMu.Lock()
	defer mitmIntentMu.Unlock()
	if seq != 0 && seq != mitmCAIntentSeq {
		return currentMitmCAState(), nil
	}
	previous := mitmCA.Load()
	if next != nil && previous != nil && previous.fingerprint == next.fingerprint {
		return currentMitmCAState(), nil
	}
	installMitmCA(previous, next)
	return currentMitmCAState(), nil
}

// Under mitmIntentMu. Returns once no issuance holds the outgoing key, and
// leaves of the outgoing CA are never served again.
func installMitmCA(previous, next *mitmLoadedCA) {
	mitmCA.Store(next)
	if previous == nil {
		return
	}
	previous.retire()
	mitmCASigning.Lock()
	defer mitmCASigning.Unlock()
	runtime := mitmState.Load()
	if !runtime.coreSigns() {
		return
	}
	mitmLeaves.forget()
	if previous.fingerprint == normalizeMitmFingerprint(runtime.setup.CAFingerprint) {
		mitmActive.closeAll()
	}
	log.Infoln("[MITM] the signing CA was removed")
}

// The leaf only the trust check asks for: the fixed check host over a
// throwaway key, whatever host the caller names, and never a listed host.
func handleMitmIssueCheck() (MitmCheckCertificate, error) {
	mitmCASigning.RLock()
	defer mitmCASigning.RUnlock()
	ca := mitmCA.Load()
	if ca == nil {
		return MitmCheckCertificate{}, mitmCANotLoaded
	}
	now := time.Now()
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		return MitmCheckCertificate{}, err
	}
	der, err := signMitmLeaf(ca.key, ca.cert, mitmCheckHost, &key.PublicKey, now)
	if err != nil {
		return MitmCheckCertificate{}, err
	}
	spki, err := x509.MarshalPKIXPublicKey(&key.PublicKey)
	if err != nil {
		return MitmCheckCertificate{}, err
	}
	leaf, err := checkMitmLeafAt(der, ca.cert.Raw, mitmCheckHost, spki, ca.fingerprint, now)
	if err != nil {
		return MitmCheckCertificate{}, err
	}
	check := leaf.SerialNumber.Text(16)
	ca.mu.Lock()
	if ca.retired {
		ca.mu.Unlock()
		return MitmCheckCertificate{}, mitmCANotLoaded
	}
	lapsed := ca.lapsedLocked(time.Now())
	if ca.checks == nil || len(ca.checks) >= mitmCAChecksMax {
		ca.checks = map[string]time.Time{}
	}
	ca.checks[check] = now
	ca.mu.Unlock()
	if lapsed {
		mitmCALapsed(ca)
	}
	return MitmCheckCertificate{PEM: mitmCertificateInfo(leaf).PEM, Check: check}, nil
}

// A check of the loaded CA passed: listed hosts may be signed until the
// check's leaf is mitmCALeaseMax old. Each check grants one lease, and
// redeeming it supersedes older checks. A check issued before the lease
// lapsed or was ended never restarts signing.
func handleMitmTrustLease(params MitmTrustLeaseParams) (MitmCAState, error) {
	ca := mitmCA.Load()
	if ca == nil {
		return MitmCAState{}, mitmCANotLoaded
	}
	if normalizeMitmFingerprint(params.Fingerprint) != ca.fingerprint {
		return MitmCAState{}, mitmCAFingerprint
	}
	length := mitmCALeaseMax
	if valid := time.Duration(params.ValidForMillis) * time.Millisecond; valid > 0 && valid < length {
		length = valid
	}
	now := time.Now()
	ca.mu.Lock()
	issued, found := ca.checks[params.Check]
	if ca.retired || !found {
		ca.mu.Unlock()
		return MitmCAState{}, mitmCAUnknownCheck
	}
	delete(ca.checks, params.Check)
	for other, otherIssued := range ca.checks {
		if otherIssued.Before(issued) {
			delete(ca.checks, other)
		}
	}
	until := issued.Add(length)
	if lapsed := ca.lapsedLocked(now); lapsed || !mitmBefore(now, until) {
		ca.mu.Unlock()
		if lapsed {
			mitmCALapsed(ca)
		}
		return MitmCAState{}, mitmCALeaseLapsed
	}
	if until.After(ca.leaseUntil) {
		ca.leaseUntil = until
		if ca.expiry != nil {
			ca.expiry.Stop()
		}
		ca.expiry = time.AfterFunc(until.Sub(now), func() { mitmCALeaseEnded(ca) })
	}
	ca.mu.Unlock()
	resumeMitmAfterLease(ca)
	return currentMitmCAState(), nil
}

// A fresh lease for the runtime's CA lifts the pause its lapse caused, so a
// relay that came back with the CA reloaded decrypts again at once.
func resumeMitmAfterLease(ca *mitmLoadedCA) {
	runtime := mitmState.Load()
	if mitmCA.Load() != ca || !runtime.coreSigns() || !runtime.decrypting() ||
		normalizeMitmFingerprint(runtime.setup.CAFingerprint) != ca.fingerprint {
		return
	}
	if _, leased := ca.lease(time.Now()); !leased {
		return
	}
	mitmActive.mu.Lock()
	defer mitmActive.mu.Unlock()
	pause := mitmPaused.Load()
	if mitmState.Load() != runtime || pause == nil || pause.runtime != runtime || pause.reason != mitmTrustUnavailable {
		return
	}
	if mitmPaused.CompareAndSwap(pause, nil) {
		log.Infoln("[MITM] decryption resumed: a fresh trust lease")
	}
}

// Kept leaves already stop at the lease's end; this also drops in-flight ones.
func mitmCALeaseEnded(ca *mitmLoadedCA) {
	ca.mu.Lock()
	lapsed := ca.lapsedLocked(time.Now())
	ca.mu.Unlock()
	if lapsed {
		mitmCALapsed(ca)
	}
}

func mitmCALapsed(ca *mitmLoadedCA) {
	if mitmCA.Load() != ca {
		return
	}
	if runtime := mitmState.Load(); runtime.coreSigns() {
		mitmLeaves.forget()
		log.Infoln("[MITM] the trust lease of the signing CA lapsed")
	}
}

// A leaf the Core signed whose CA was cleared or whose lease ended.
func (leaf *mitmLeaf) revoked() bool {
	if leaf == nil || leaf.ca == nil {
		return false
	}
	_, leased := leaf.ca.lease(time.Now())
	return !leased || mitmCA.Load() != leaf.ca
}

// Under mitmIntentMu: the relay that handed the CA over is gone.
func dropMitmCA(seq uint64) {
	if seq > mitmCAIntentSeq {
		mitmCAIntentSeq = seq
	}
	if previous := mitmCA.Swap(nil); previous != nil {
		previous.retire()
	}
}

// The Core's own issuance: the native signer's gates, on the runtime the
// connection was chosen under.
func issueMitmLeafLocal(runtime *mitmRuntime, host string) (*mitmLeaf, error) {
	mitmCASigning.RLock()
	defer mitmCASigning.RUnlock()
	if !runtime.decrypting() || !runtime.hosts.Match(host) {
		return nil, errMitmNotListed
	}
	if host == mitmCheckHost || !validDNSName(host) {
		return nil, mitmAppRefusal("notListed")
	}
	ca := mitmCA.Load()
	if ca == nil || ca.fingerprint != normalizeMitmFingerprint(runtime.setup.CAFingerprint) {
		return nil, mitmAppRefusal(mitmTrustUnavailable)
	}
	now := time.Now()
	leaseEnd, leased := ca.lease(now)
	if !leased {
		return nil, mitmAppRefusal(mitmTrustUnavailable)
	}
	if !now.Before(ca.cert.NotAfter) {
		return nil, mitmAppRefusal("rootExpired")
	}
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		return nil, err
	}
	der, err := signMitmLeaf(ca.key, ca.cert, host, &key.PublicKey, now)
	if err != nil {
		return nil, mitmAppRefusal("signFailed")
	}
	spki, err := x509.MarshalPKIXPublicKey(&key.PublicKey)
	if err != nil {
		return nil, err
	}
	leaf, err := checkMitmLeafAt(der, ca.cert.Raw, host, spki, runtime.setup.CAFingerprint, now)
	if err != nil {
		return nil, err
	}
	if mitmState.Load() != runtime {
		return nil, errMitmSetupChanged
	}
	issued := &mitmLeaf{
		cert:     tls.Certificate{Certificate: [][]byte{leaf.Raw}, PrivateKey: key, Leaf: leaf},
		notAfter: leaf.NotAfter,
		leaseEnd: leaseEnd,
		ca:       ca,
	}
	if issued.revoked() {
		return nil, mitmAppRefusal(mitmTrustUnavailable)
	}
	return issued, nil
}

func issueMitmLeafFor(ctx context.Context, host string) (*mitmLeaf, bool, error) {
	runtime := mitmState.Load()
	if !runtime.coreSigns() {
		return nil, false, nil
	}
	if err := ctx.Err(); err != nil {
		return nil, true, err
	}
	leaf, err := issueMitmLeafLocal(runtime, normalizeMitmHost(host))
	return leaf, true, err
}

// The arguments of these methods hold the CA key; a decode error never
// echoes them.
func decodeMitmCAArguments[P any](call *MethodCall) (params P, err error) {
	if len(call.Arguments) == 0 || string(call.Arguments) == "null" {
		return params, nil
	}
	err = json.Unmarshal(call.Arguments, &params)
	clear(call.Arguments)
	if err != nil {
		return params, &MethodError{Code: "invalid_arguments", Message: "invalid arguments for " + string(call.Method)}
	}
	return params, nil
}

func handleMitmSetCACall(call *MethodCall) (any, error) {
	params, err := decodeMitmCAArguments[MitmCAParams](call)
	if err != nil {
		return nil, err
	}
	state, err := handleMitmSetCASeq(params, call.seq)
	if err != nil {
		return nil, mitmCAMethodError(err)
	}
	return state, nil
}

func handleMitmInspectCACall(call *MethodCall) (any, error) {
	params, err := decodeMitmCAArguments[MitmCAParams](call)
	if err != nil {
		return nil, err
	}
	return handleMitmInspectCA(params)
}

func handleMitmGenerateCACall(*MethodCall) (any, error) {
	return handleMitmGenerateCA()
}

func handleMitmIssueCheckCall(*MethodCall) (any, error) {
	check, err := handleMitmIssueCheck()
	if err != nil {
		return nil, mitmCAMethodError(err)
	}
	return check, nil
}

func handleMitmTrustLeaseCall(call *MethodCall) (any, error) {
	params, err := decodeArguments[MitmTrustLeaseParams](call)
	if err != nil {
		return nil, err
	}
	state, err := handleMitmTrustLease(params)
	if err != nil {
		return nil, mitmCAMethodError(err)
	}
	return state, nil
}

func handleMitmCAStateCall(*MethodCall) (any, error) {
	return currentMitmCAState(), nil
}

// Clears the CA as setCA with no p12 does. The reply means no leaf is being
// signed, none signed before is served again and decrypted sessions under
// the CA are closed. The helper sends it when the app's connection drops.
func handleMitmStopSigningCall(call *MethodCall) (any, error) {
	return handleMitmSetCASeq(MitmCAParams{}, call.seq)
}

// Never written to a spill file, whatever their size.
var mitmCASecretMethods = map[CoreMethod]bool{
	mitmSetCAMethod:               true,
	mitmInspectCAMethod:           true,
	mitmGenerateCertificateMethod: true,
	mitmIssueCertificateMethod:    true,
	mitmTrustLeaseMethod:          true,
	mitmCAStateMethod:             true,
	mitmStopSigningMethod:         true,
}

var mitmCAHandlers = map[CoreMethod]methodHandler{
	mitmSetCAMethod:               handleMitmSetCACall,
	mitmInspectCAMethod:           handleMitmInspectCACall,
	mitmGenerateCertificateMethod: handleMitmGenerateCACall,
	mitmIssueCertificateMethod:    handleMitmIssueCheckCall,
	mitmTrustLeaseMethod:          handleMitmTrustLeaseCall,
	mitmCAStateMethod:             handleMitmCAStateCall,
	mitmStopSigningMethod:         handleMitmStopSigningCall,
}
