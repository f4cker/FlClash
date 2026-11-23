package core

import (
	"context"
	"errors"
	"net"
	"sync/atomic"
	"testing"
	"time"
)

func keptLeafCount() int {
	mitmLeaves.mu.Lock()
	defer mitmLeaves.mu.Unlock()
	return len(mitmLeaves.ready)
}

func getLeaf(host string) (*mitmLeaf, error) {
	ctx, cancel := context.WithTimeout(context.Background(), mitmConnectionLeafWait)
	defer cancel()
	return mitmLeaves.get(ctx, host)
}

func TestMitmClearNeverServesALeafSignedBeforeIt(t *testing.T) {
	withCoreSigner(t, "example.com")
	kept, err := getLeaf("example.com")
	if err != nil || keptLeafCount() != 1 {
		t.Fatalf("first leaf: %v, kept %d", err, keptLeafCount())
	}
	if again, _ := getLeaf("example.com"); again != kept {
		t.Fatal("the kept leaf was not reused while leased")
	}
	if _, err := handleMitmSetCASeq(MitmCAParams{}, 0); err != nil {
		t.Fatal(err)
	}
	leaf, err := getLeaf("example.com")
	if leaf != nil || !isRefusal("trustUnavailable")(err) {
		t.Fatalf("after the clear: leaf %v, %v", leaf != nil, err)
	}
}

func TestMitmClearDropsAnIssuanceInFlight(t *testing.T) {
	generated := withCoreSigner(t, "example.com")
	started, release := make(chan struct{}), make(chan struct{})
	mitmLeaves.issuer = func(ctx context.Context, host string) (*mitmLeaf, error) {
		leaf, err := issueMitmLeaf(ctx, host)
		close(started)
		<-release
		return leaf, err
	}
	t.Cleanup(func() { mitmLeaves.issuer = nil })
	result := make(chan error, 1)
	go func() {
		_, err := mitmLeaves.get(context.Background(), "example.com")
		result <- err
	}()
	<-started
	if _, err := handleMitmSetCASeq(MitmCAParams{}, 0); err != nil {
		t.Fatal(err)
	}
	close(release)
	if err := <-result; !errors.Is(err, errMitmSetupChanged) {
		t.Fatalf("a leaf signed before the clear was handed out: %v", err)
	}
	if keptLeafCount() != 0 {
		t.Fatal("a leaf signed before the clear was kept")
	}
	_ = generated
}

func TestMitmKeptLeafStopsAtTheLeaseEnd(t *testing.T) {
	withMitmCAState(t)
	mitmCALeaseMax = 300 * time.Millisecond
	withCoreSignerLeased(t, "example.com")
	leaseEnd, _ := mitmCA.Load().lease(time.Now())
	leaf, err := getLeaf("example.com")
	if err != nil {
		t.Fatal(err)
	}
	mitmLeaves.mu.Lock()
	var reuseTill time.Time
	for _, ready := range mitmLeaves.ready {
		reuseTill = ready.reuseTill
	}
	proof := time.Time{}
	for _, till := range mitmLeaves.quicProof {
		proof = till
	}
	generation := mitmLeaves.generation
	mitmLeaves.mu.Unlock()
	if reuseTill.After(leaseEnd) || proof.After(leaseEnd) {
		t.Fatalf("reuse till %v / QUIC proof %v past the lease end %v", reuseTill, proof, leaseEnd)
	}
	time.Sleep(time.Until(leaseEnd) + 50*time.Millisecond)
	if again, err := getLeaf("example.com"); again == leaf || !isRefusal("trustUnavailable")(err) {
		t.Fatalf("after the lease: same leaf %v, %v", again == leaf, err)
	}
	mitmLeaves.mu.Lock()
	forgotten := mitmLeaves.generation > generation
	mitmLeaves.mu.Unlock()
	if !forgotten {
		t.Error("the lapse did not forget in-flight leaves")
	}
}

// withCoreSigner after the caller shortened the lease.
func withCoreSignerLeased(t *testing.T, hosts ...string) MitmGeneratedCA {
	t.Helper()
	leaseMax := mitmCALeaseMax
	generated := withCoreSigner(t, hosts...)
	mitmCALeaseMax = leaseMax
	leaseTestCA(t)
	return generated
}

type revocationTimes struct {
	handshakes, sessions time.Duration
}

// The app renews every lease/2, then stops at R right after a check passed
// (trust revoked, or the app hung or quit with the relay kept open). Times
// are measured from R; the liveness interval is the real one scaled alike.
func measureMitmRevocation(t *testing.T, lease time.Duration) revocationTimes {
	t.Helper()
	withMitmCAState(t)
	mitmCALeaseMax = lease
	withCoreSignerLeased(t, "example.com")
	runtime := mitmState.Load()
	interval := lease * mitmLivenessInterval / (10 * time.Second)

	renewing := atomic.Bool{}
	renewing.Store(true)
	renewed := make(chan struct{})
	go func() {
		defer close(renewed)
		for renewing.Load() {
			check, err := handleMitmIssueCheck()
			if err == nil {
				_, _ = handleMitmTrustLease(MitmTrustLeaseParams{Fingerprint: runtime.setup.CAFingerprint, Check: check.Check})
			}
			time.Sleep(lease / 2)
		}
	}()

	client, clientPeer := net.Pipe()
	remote, remotePeer := net.Pipe()
	t.Cleanup(func() { _ = clientPeer.Close(); _ = remotePeer.Close() })
	remove, ok := mitmActive.add(runtime, "example.com", client, remote)
	if !ok {
		t.Fatal("session registration failed")
	}
	defer remove()
	ctx, stop := context.WithCancel(context.Background())
	defer stop()
	go monitorMitmLiveness(ctx, runtime, "example.com", interval, mitmLeaves.fresh)

	time.Sleep(3 * lease)
	if _, err := getLeaf("example.com"); err != nil {
		t.Fatalf("renewed signer refused: %v", err)
	}
	renewing.Store(false)
	<-renewed
	revoked := time.Now()
	leaseTestCA(t)
	if _, err := getLeaf("example.com"); err != nil {
		t.Fatal(err)
	}

	sessionClosed := make(chan time.Time, 1)
	go func() {
		buffer := make([]byte, 1)
		_, _ = clientPeer.Read(buffer)
		sessionClosed <- time.Now()
	}()
	var times revocationTimes
	deadline := revoked.Add(4*lease + 2*interval)
	for time.Now().Before(deadline) {
		if _, err := getLeaf("example.com"); err != nil {
			times.handshakes = time.Since(revoked)
			break
		}
		time.Sleep(lease / 100)
	}
	select {
	case at := <-sessionClosed:
		times.sessions = at.Sub(revoked)
	case <-time.After(time.Until(deadline)):
	}
	if times.handshakes == 0 || times.sessions == 0 {
		t.Fatalf("not stopped by %v: handshakes %v sessions %v", deadline.Sub(revoked), times.handshakes, times.sessions)
	}
	if reason := mitmPausedReason(); reason != "livenessUnavailable" {
		t.Errorf("pause reason %q, want livenessUnavailable", reason)
	}
	return times
}

func TestMitmRevocationStopsSigningWithinTheLease(t *testing.T) {
	const lease = 400 * time.Millisecond
	scale := float64(10*time.Second) / float64(lease)
	times := measureMitmRevocation(t, lease)
	t.Logf("scaled to a 10s lease: new handshakes stop %.1fs and sessions %.1fs after R",
		times.handshakes.Seconds()*scale, times.sessions.Seconds()*scale)
	slack := lease / 5
	if times.handshakes > lease+slack {
		t.Errorf("new handshakes stopped %v after R, want within the %v lease", times.handshakes, lease)
	}
	if times.handshakes < lease-slack {
		t.Errorf("new handshakes stopped %v after R, before the %v lease ran out", times.handshakes, lease)
	}
	if limit := 2*lease + slack; times.sessions > limit {
		t.Errorf("sessions stopped %v after R, want within %v", times.sessions, limit)
	}
}

// The production constants, against today's app-sign bounds (an issuance up
// to mitmLeafWait old, reused mitmLeafReuseFor, then a liveness deadline).
func TestMitmRevocationBoundIsNoLaterThanTheAppSigner(t *testing.T) {
	handshakes := mitmCALeaseMax
	sessions := mitmCALeaseMax + mitmLivenessInterval
	todayHandshakes := mitmLeafWait + mitmLeafReuseFor
	todaySessions := mitmLeafWait + mitmLivenessInterval + mitmLeafWait
	if handshakes > 10*time.Second || handshakes > todayHandshakes {
		t.Errorf("handshakes bound %v, today %v", handshakes, todayHandshakes)
	}
	if sessions > 20*time.Second || sessions > todaySessions {
		t.Errorf("sessions bound %v, today %v", sessions, todaySessions)
	}
	if mitmConnectionLeafWait != 500*time.Millisecond || mitmPauseFor != 30*time.Second {
		t.Error("the connection wait or the global pause changed")
	}
}
