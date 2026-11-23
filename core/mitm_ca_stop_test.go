package core

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net"
	"strings"
	"testing"
	"time"
)

func leasedNow() bool {
	ca := mitmCA.Load()
	if ca == nil {
		return false
	}
	_, leased := ca.lease(time.Now())
	return leased
}

func issueCheck(t *testing.T) string {
	t.Helper()
	check, err := handleMitmIssueCheck()
	if err != nil {
		t.Fatal(err)
	}
	return check.Check
}

func redeem(fingerprint, check string) error {
	_, err := handleMitmTrustLease(MitmTrustLeaseParams{Fingerprint: fingerprint, Check: check})
	return err
}

func withWallSkew(t *testing.T, skew time.Duration) {
	t.Helper()
	mitmWallSkew.Store(int64(skew))
	t.Cleanup(func() { mitmWallSkew.Store(0) })
}

func TestMitmLeaseEndsWithTheDecryptionItVouchedFor(t *testing.T) {
	cases := []struct {
		name string
		turn func(t *testing.T, setup *MitmSetup)
	}{
		{name: "decryption off", turn: func(t *testing.T, setup *MitmSetup) {
			setup.DecryptTLS = false
			updateSetup(t, setup)
		}},
		{name: "signer leaves the Core", turn: func(t *testing.T, setup *MitmSetup) {
			setup.Signer = "app"
			updateSetup(t, setup)
		}},
		{name: "fingerprint changes", turn: func(t *testing.T, setup *MitmSetup) {
			setup.CAFingerprint = strings.Repeat("AB:", 31) + "AB"
			updateSetup(t, setup)
		}},
		{name: "mitm.disable", turn: func(*testing.T, *MitmSetup) { handleMitmDisable() }},
		{name: "update to null", turn: func(t *testing.T, _ *MitmSetup) {
			if err := handleMitmUpdate(MitmUpdateParams{}); err != nil {
				t.Fatal(err)
			}
		}},
	}
	for _, test := range cases {
		t.Run(test.name, func(t *testing.T) {
			generated := withCoreSigner(t, "example.com")
			pending := issueCheck(t)
			test.turn(t, coreSignerSetup(generated.Fingerprint, "example.com"))
			ca := mitmCA.Load()
			if ca == nil || leasedNow() {
				t.Fatalf("CA loaded %v, leased %v: want the CA kept and the lease gone", ca != nil, leasedNow())
			}
			ca.mu.Lock()
			timer := ca.expiry
			ca.mu.Unlock()
			if timer != nil {
				t.Error("the lease's expiry timer outlived it")
			}
			updateSetup(t, coreSignerSetup(generated.Fingerprint, "example.com"))
			if _, err := issueMitmLeaf(context.Background(), "example.com"); !isRefusal("trustUnavailable")(err) {
				t.Fatalf("back on without a fresh check: %v", err)
			}
			if err := redeem(generated.Fingerprint, pending); !errors.Is(err, mitmCAUnknownCheck) {
				t.Fatalf("a check issued before the switch leased after it: %v", err)
			}
			if err := redeem(generated.Fingerprint, issueCheck(t)); err != nil {
				t.Fatalf("the check leaf no longer works: %v", err)
			}
			if _, err := issueMitmLeaf(context.Background(), "example.com"); err != nil {
				t.Fatalf("a fresh check: %v", err)
			}
		})
	}
	t.Run("a new CA's lease survives the switch to it", func(t *testing.T) {
		withCoreSigner(t, "example.com")
		next := generatedTestCA(t)
		loadTestCAGenerated(t, next)
		if err := redeem(next.Fingerprint, issueCheck(t)); err != nil {
			t.Fatal(err)
		}
		updateSetup(t, coreSignerSetup(next.Fingerprint, "example.com"))
		if _, err := issueMitmLeaf(context.Background(), "example.com"); err != nil {
			t.Fatalf("rotated: %v", err)
		}
	})
}

func updateSetup(t *testing.T, setup *MitmSetup) {
	t.Helper()
	if err := handleMitmUpdate(MitmUpdateParams{Setup: setup}); err != nil {
		t.Fatal(err)
	}
}

// A sleeping Mac stops the monotonic clock, simulated by moving the wall
// clock alone. Waking undoes the skew, which a real wall clock never does:
// only what was seen to lapse meanwhile must stay ended.
func TestMitmLeaseAndKeptLeavesDoNotOutliveASleep(t *testing.T) {
	generated := withCoreSigner(t, "example.com")
	kept, err := getLeaf("example.com")
	if err != nil {
		t.Fatal(err)
	}
	beforeSleep := issueCheck(t)
	withWallSkew(t, mitmCALeaseMax)
	if leasedNow() {
		t.Fatal("the lease survived a sleep as long as itself")
	}
	if leaf, err := getLeaf("example.com"); leaf == kept || !isRefusal("trustUnavailable")(err) {
		t.Fatalf("after the sleep: kept leaf served %v, %v", leaf == kept, err)
	}
	if state := currentMitmCAState(); state.LeaseMillis != 0 {
		t.Errorf("lease-millis %d after the sleep", state.LeaseMillis)
	}
	if err := redeem(generated.Fingerprint, beforeSleep); err == nil {
		t.Fatal("a check from before the sleep restarted signing")
	}
	mitmWallSkew.Store(0)
	if leasedNow() {
		t.Fatal("the lease seen to lapse came back")
	}
	if err := redeem(generated.Fingerprint, issueCheck(t)); err != nil {
		t.Fatalf("a check after waking: %v", err)
	}
	if _, err := getLeaf("example.com"); err != nil {
		t.Fatalf("after a fresh check: %v", err)
	}
}

func TestMitmWallClockSetBackDoesNotExtendTheLease(t *testing.T) {
	withMitmCAState(t)
	mitmCALeaseMax = 200 * time.Millisecond
	withCoreSignerLeased(t, "example.com")
	withWallSkew(t, -time.Hour)
	time.Sleep(250 * time.Millisecond)
	if leasedNow() {
		t.Fatal("setting the clock back extended the lease")
	}
}

// Notice lost: once the app stops renewing, signing ends mitmCALeaseMax
// after the last check that passed was issued, and not before.
func TestMitmSigningEndsAtTheCapFromTheLastCheck(t *testing.T) {
	if mitmCALeaseMax != 10*time.Second {
		t.Fatalf("the cap is %v, want 10s", mitmCALeaseMax)
	}
	withMitmCAState(t)
	mitmCALeaseMax = 600 * time.Millisecond
	generated := withCoreSigner(t, "example.com")
	time.Sleep(200 * time.Millisecond)
	checked := time.Now()
	last := issueCheck(t)
	issued := time.Now()
	time.Sleep(100 * time.Millisecond)
	if err := redeem(generated.Fingerprint, last); err != nil {
		t.Fatal(err)
	}
	time.Sleep(time.Until(checked.Add(mitmCALeaseMax - 150*time.Millisecond)))
	if _, err := issueMitmLeafLocal(mitmState.Load(), "example.com"); err != nil {
		t.Fatalf("150ms before the cap: %v", err)
	}
	time.Sleep(time.Until(issued.Add(mitmCALeaseMax + 20*time.Millisecond)))
	if _, err := issueMitmLeafLocal(mitmState.Load(), "example.com"); !isRefusal("trustUnavailable")(err) {
		t.Fatalf("past the cap: %v", err)
	}
	if leaf, err := getLeaf("example.com"); leaf != nil || err == nil {
		t.Fatal("a kept leaf outlived the cap")
	}
}

func TestMitmLateLeaseNeverRestartsSigning(t *testing.T) {
	t.Run("after stopSigning", func(t *testing.T) {
		generated := withCoreSigner(t, "example.com")
		late := issueCheck(t)
		handleMethodCall(&MethodCall{Method: mitmStopSigningMethod})
		loadTestCAGenerated(t, generated)
		if err := redeem(generated.Fingerprint, late); !errors.Is(err, mitmCAUnknownCheck) {
			t.Fatalf("late lease: %v", err)
		}
		if _, err := issueMitmLeaf(context.Background(), "example.com"); !isRefusal("trustUnavailable")(err) {
			t.Fatalf("signing restarted: %v", err)
		}
	})
	t.Run("after a clear, with no CA", func(t *testing.T) {
		generated := withCoreSigner(t, "example.com")
		late := issueCheck(t)
		if _, err := handleMitmSetCASeq(MitmCAParams{}, 0); err != nil {
			t.Fatal(err)
		}
		if err := redeem(generated.Fingerprint, late); !errors.Is(err, mitmCANotLoaded) {
			t.Fatalf("late lease: %v", err)
		}
	})
	t.Run("after expiry", func(t *testing.T) {
		withMitmCAState(t)
		mitmCALeaseMax = 300 * time.Millisecond
		generated := withCoreSignerLeased(t, "example.com")
		time.Sleep(150 * time.Millisecond)
		late := issueCheck(t)
		time.Sleep(200 * time.Millisecond)
		// The lease lapsed; the check's own 300ms have not.
		if err := redeem(generated.Fingerprint, late); err == nil {
			t.Fatal("a check issued under a lapsed lease restarted signing")
		}
		if leasedNow() {
			t.Fatal("leased after expiry")
		}
	})
	t.Run("after expiry the timer has not seen yet", func(t *testing.T) {
		generated := withCoreSigner(t, "example.com")
		late := issueCheck(t)
		ca := mitmCA.Load()
		ca.mu.Lock()
		ca.leaseUntil = time.Now().Add(-time.Millisecond)
		ca.mu.Unlock()
		if err := redeem(generated.Fingerprint, late); !errors.Is(err, mitmCALeaseLapsed) {
			t.Fatalf("late lease: %v", err)
		}
	})
	t.Run("superseded check", func(t *testing.T) {
		generated := withCoreSigner(t, "example.com")
		older, newer := issueCheck(t), issueCheck(t)
		if err := redeem(generated.Fingerprint, newer); err != nil {
			t.Fatal(err)
		}
		until, _ := mitmCA.Load().lease(time.Now())
		if err := redeem(generated.Fingerprint, older); !errors.Is(err, mitmCAUnknownCheck) {
			t.Fatalf("superseded check: %v", err)
		}
		if again, _ := mitmCA.Load().lease(time.Now()); !again.Equal(until) {
			t.Fatal("a superseded check moved the lease")
		}
	})
}

// Normal quit: the reply to mitm.stopSigning comes only once the issuance
// holding the key has finished, and nothing it signed is served.
func TestMitmStopSigningRepliesOnceSigningHasStopped(t *testing.T) {
	skipUnlessMitmCAHandled(t)
	withCoreSigner(t, "example.com")
	if _, err := getLeaf("example.com"); err != nil {
		t.Fatal(err)
	}
	client, peer := net.Pipe()
	defer peer.Close()
	remote, remotePeer := net.Pipe()
	defer remotePeer.Close()
	remove, ok := mitmActive.add(mitmState.Load(), "example.com", client, remote)
	if !ok {
		t.Fatal("session not registered")
	}
	defer remove()

	mitmCASigning.RLock()
	replied := make(chan []byte, 1)
	dispatchMethodCall(&MethodCall{ID: "7", Method: mitmStopSigningMethod}, func(data []byte) { replied <- data })
	select {
	case <-replied:
		t.Fatal("replied while a leaf was still being signed")
	case <-time.After(100 * time.Millisecond):
	}
	mitmCASigning.RUnlock()
	var reply struct {
		ID     string       `json:"id"`
		Result MitmCAState  `json:"result"`
		Error  *MethodError `json:"error"`
	}
	select {
	case data := <-replied:
		if err := json.Unmarshal(data, &reply); err != nil || reply.Error != nil || reply.ID != "7" || reply.Result.Loaded {
			t.Fatalf("reply %s", data)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("no reply")
	}
	if mitmCA.Load() != nil || keptLeafCount() != 0 {
		t.Fatal("the CA or a kept leaf survived the stop")
	}
	if _, err := peer.Write([]byte{0}); err == nil {
		t.Error("a decrypted session survived the stop")
	}
	if _, err := getLeaf("example.com"); !isRefusal("trustUnavailable")(err) {
		t.Fatalf("after the stop: %v", err)
	}
}

// The helper's frame carries no id and arrives after whatever the app sent:
// a setCA still decoding when it lands does not load the CA after it.
func TestMitmHelperStopFrameOutranksAnEarlierSetCA(t *testing.T) {
	skipUnlessMitmCAHandled(t)
	generated := withCoreSigner(t, "example.com")
	earlier := methodCallSeq.Add(1)
	markMitmCAIntent(earlier)
	var frame MethodCall
	if err := json.Unmarshal([]byte(`{"method":"mitm.stopSigning"}`), &frame); err != nil {
		t.Fatal(err)
	}
	done := make(chan []byte, 1)
	dispatchMethodCall(&frame, func(data []byte) { done <- data })
	<-done
	if state, _ := handleMitmSetCASeq(MitmCAParams{P12: bytes.Clone(generated.P12), Passphrase: generated.Passphrase, Fingerprint: generated.Fingerprint}, earlier); state.Loaded {
		t.Fatal("a setCA sent before the stop loaded the CA after it")
	}
}

func TestMitmLeafSignedUnderAClearedCAIsRevoked(t *testing.T) {
	withCoreSigner(t, "example.com")
	leaf, err := issueMitmLeafLocal(mitmState.Load(), "example.com")
	if err != nil || leaf.revoked() {
		t.Fatalf("fresh leaf: %v revoked %v", err, leaf != nil && leaf.revoked())
	}
	mitmCA.Load().endLease()
	if !leaf.revoked() {
		t.Fatal("a leaf outlived its lease")
	}
	leaseTestCA(t)
	if leaf.revoked() {
		t.Fatal("a renewed lease revoked the leaf")
	}
	if _, err := handleMitmSetCASeq(MitmCAParams{}, 0); err != nil {
		t.Fatal(err)
	}
	if !leaf.revoked() {
		t.Fatal("a leaf outlived its CA")
	}
	client, peer := net.Pipe()
	defer peer.Close()
	remote, remotePeer := net.Pipe()
	defer remotePeer.Close()
	runtime := mitmState.Load()
	if outcome := serveMitm(client, remote, "example.com", leaf, runtime); outcome != mitmOutcomePrecommit {
		t.Fatalf("a session started on a revoked leaf: %v", outcome)
	}
	if (&mitmLeaf{}).revoked() {
		t.Error("an app-signed leaf counts as revoked")
	}
}

func TestMitmRootExpiredWhileLoadedRefusesSigning(t *testing.T) {
	withCoreSigner(t, "example.com")
	mitmCA.Load().cert.NotAfter = time.Now().Add(-time.Second)
	if _, err := issueMitmLeafLocal(mitmState.Load(), "example.com"); !isRefusal("rootExpired")(err) {
		t.Fatalf("expired root: %v", err)
	}
}

func TestMitmDisableThenAppSignerDropsTheCoreLeaves(t *testing.T) {
	generated := withCoreSigner(t, "example.com")
	if _, err := getLeaf("example.com"); err != nil {
		t.Fatal(err)
	}
	handleMitmDisable()
	setup := coreSignerSetup(generated.Fingerprint, "example.com")
	setup.Signer = "app"
	updateSetup(t, setup)
	if keptLeafCount() != 0 {
		t.Fatal("a Core leaf is kept for the app signer across a disable")
	}
}

func TestMitmSetCANamingACAWithoutItIsAnError(t *testing.T) {
	generated := withCoreSigner(t, "example.com")
	if _, err := handleMitmSetCASeq(MitmCAParams{Fingerprint: generated.Fingerprint}, 0); !errors.Is(err, mitmCABadP12) {
		t.Fatalf("setCA without its p12: %v", err)
	}
	if mitmCA.Load() == nil {
		t.Fatal("a malformed setCA cleared the CA")
	}
}
