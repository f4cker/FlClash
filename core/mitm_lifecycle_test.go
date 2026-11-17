package core

import (
	"context"
	"errors"
	"io"
	"net"
	"sync"
	"testing"
	"time"
)

func TestMitmConfigSwitchClosesActiveSessions(t *testing.T) {
	original := mitmState.Load()
	defer func() { mitmActive.closeAll(); mitmState.Store(original) }()
	old := &mitmRuntime{}
	mitmState.Store(old)
	client, clientPeer := net.Pipe()
	remote, remotePeer := net.Pipe()
	defer clientPeer.Close()
	defer remotePeer.Close()
	remove, ok := mitmActive.add(old, "example.com", client, remote)
	if !ok {
		t.Fatal("registration failed")
	}
	defer remove()
	replaceMitmRuntime(&mitmRuntime{})
	if _, err := clientPeer.Write([]byte("x")); !errors.Is(err, io.ErrClosedPipe) {
		t.Fatalf("client not closed: %v", err)
	}
	if _, err := remotePeer.Write([]byte("x")); !errors.Is(err, io.ErrClosedPipe) {
		t.Fatalf("upstream not closed: %v", err)
	}
	if _, ok := mitmActive.add(old, "example.com", client, remote); ok {
		t.Fatal("stale runtime registered")
	}
}

func TestMitmSignerExitClosesActiveSessions(t *testing.T) {
	original := mitmState.Load()
	defer func() { mitmActive.closeAll(); mitmState.Store(original) }()
	runtime := &mitmRuntime{}
	mitmState.Store(runtime)
	client, peer := net.Pipe()
	defer peer.Close()
	remote, remotePeer := net.Pipe()
	defer remotePeer.Close()
	remove, ok := mitmActive.add(runtime, "example.com", client, remote)
	if !ok {
		t.Fatal("registration failed")
	}
	defer remove()
	mitmSignerGone()
	if mitmState.Load() != nil {
		t.Fatal("signer exit left runtime active")
	}
	if _, err := peer.Write([]byte("x")); !errors.Is(err, io.ErrClosedPipe) {
		t.Fatalf("client not closed: %v", err)
	}
	if _, err := remotePeer.Write([]byte("x")); !errors.Is(err, io.ErrClosedPipe) {
		t.Fatalf("remote not closed: %v", err)
	}
}

func TestMitmIdleTimeoutStopsStalledRead(t *testing.T) {
	conn, peer := net.Pipe()
	defer conn.Close()
	defer peer.Close()
	idle := &mitmIdleConn{Conn: conn, timeout: 20 * time.Millisecond}
	_, err := idle.Read(make([]byte, 1))
	var e net.Error
	if !errors.As(err, &e) || !e.Timeout() {
		t.Fatalf("wanted timeout, got %v", err)
	}
}

func TestMitmSignerExitCancelsPendingRequest(t *testing.T) {
	original := mitmState.Load()
	defer func() { cancelMitmSignRequests(); mitmState.Store(original) }()
	mitmState.Store(&mitmRuntime{})
	pending := &mitmSignPending{answer: make(chan mitmSignAnswer, 1)}
	mitmSignMu.Lock()
	mitmSignRequests[987654321] = pending
	mitmSignMu.Unlock()
	mitmSignerGone()
	select {
	case answer := <-pending.answer:
		if !errors.Is(answer.err, errMitmSetupChanged) {
			t.Fatalf("unexpected result: %v", answer.err)
		}
	default:
		t.Fatal("pending signer request was not cancelled")
	}
	if handleMitmSignResult(MitmSignResultParams{ReqID: 987654321}) {
		t.Fatal("late signer result was accepted")
	}
}

type closeBarrierConn struct {
	net.Conn
	started chan struct{}
	release chan struct{}
}

func (c *closeBarrierConn) Close() error { close(c.started); <-c.release; return c.Conn.Close() }

func TestMitmPauseRejectsRegistrationWhileClosing(t *testing.T) {
	previous := mitmState.Load()
	defer func() { mitmActive.closeAll(); mitmPaused.Store(nil); mitmState.Store(previous) }()
	runtime := &mitmRuntime{}
	mitmState.Store(runtime)
	mitmPaused.Store(nil)
	conn, peer := net.Pipe()
	defer peer.Close()
	remote, remotePeer := net.Pipe()
	defer remotePeer.Close()
	barrier := &closeBarrierConn{Conn: conn, started: make(chan struct{}), release: make(chan struct{})}
	remove, ok := mitmActive.add(runtime, "example.com", barrier, remote)
	if !ok {
		t.Fatal("registration failed")
	}
	defer remove()
	done := make(chan struct{})
	go func() { pauseMitm(runtime, "example.com", errMitmSignDropped); close(done) }()
	<-barrier.started
	c2, p2 := net.Pipe()
	defer c2.Close()
	defer p2.Close()
	r2, rp2 := net.Pipe()
	defer r2.Close()
	defer rp2.Close()
	if remove2, ok := mitmActive.add(runtime, "example.com", c2, r2); ok {
		remove2()
		t.Fatal("registered during global pause")
	}
	close(barrier.release)
	<-done
}

func TestMitmLivenessFailureClosesExistingSession(t *testing.T) {
	old, oldPause := mitmState.Load(), mitmPaused.Load()
	defer func() { mitmActive.closeAll(); mitmState.Store(old); mitmPaused.Store(oldPause) }()
	runtime := &mitmRuntime{}
	mitmState.Store(runtime)
	mitmPaused.Store(nil)
	client, clientPeer := net.Pipe()
	defer clientPeer.Close()
	remote, remotePeer := net.Pipe()
	defer remotePeer.Close()
	remove, ok := mitmActive.add(runtime, "example.com", client, remote)
	if !ok {
		t.Fatal("registration failed")
	}
	defer remove()
	checks := 0
	done := make(chan struct{})
	go func() {
		defer close(done)
		monitorMitmLiveness(context.Background(), runtime, "example.com", time.Millisecond, func(context.Context, string) (*mitmLeaf, error) {
			checks++
			if checks == 1 {
				return &mitmLeaf{}, nil
			}
			return nil, errors.New("trust removed")
		})
	}()
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("probe did not finish")
	}
	if checks != 2 || mitmPausedReason() != "livenessUnavailable" {
		t.Fatal("failed probe did not pause")
	}
	if _, err := clientPeer.Write([]byte("x")); !errors.Is(err, io.ErrClosedPipe) {
		t.Fatalf("client still open: %v", err)
	}
	if _, err := remotePeer.Write([]byte("x")); !errors.Is(err, io.ErrClosedPipe) {
		t.Fatalf("upstream still open: %v", err)
	}
}

func TestMitmLivenessCancelledProbeDoesNotPauseNewRuntime(t *testing.T) {
	old, oldPause := mitmState.Load(), mitmPaused.Load()
	defer func() { mitmActive.closeAll(); mitmState.Store(old); mitmPaused.Store(oldPause) }()
	previous := &mitmRuntime{}
	mitmState.Store(previous)
	mitmPaused.Store(nil)
	started := make(chan struct{})
	release := make(chan struct{})
	done := make(chan struct{})
	go func() {
		defer close(done)
		monitorMitmLiveness(context.Background(), previous, "example.com", time.Millisecond, func(context.Context, string) (*mitmLeaf, error) {
			close(started)
			<-release
			return nil, errors.New("old signer failed")
		})
	}()
	<-started
	current := &mitmRuntime{}
	mitmState.Store(current)
	close(release)
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("probe did not finish")
	}
	if mitmPausedReason() != "" {
		t.Fatal("old probe paused new runtime")
	}
}

// A real ephemeral CA signs the first fresh public key. Losing the app's
// trust approval on the next probe closes an otherwise-idle connection.
func TestMitmLivenessUsesFreshSignedLeafAndClosesOnTrustRefusal(t *testing.T) {
	app := newFakeMitmApp(t)
	oldPause := mitmPaused.Load()
	defer mitmPaused.Store(oldPause)
	checks := 0
	withMitmSigner(t, app, []string{"api.example.com"}, func(req *MitmSignRequest) MitmSignResultParams {
		checks++
		if checks > 1 {
			return MitmSignResultParams{Error: "trustUnavailable"}
		}
		return MitmSignResultParams{Cert: app.leaf(t, req.Host, req.SPKI, nil), CA: app.ca.Raw}
	})
	mitmPaused.Store(nil)
	runtime := mitmState.Load()
	client, clientPeer := net.Pipe()
	defer clientPeer.Close()
	remote, remotePeer := net.Pipe()
	defer remotePeer.Close()
	remove, ok := mitmActive.add(runtime, "api.example.com", client, remote)
	if !ok {
		t.Fatal("registration failed")
	}
	defer remove()
	done := make(chan struct{})
	go func() {
		defer close(done)
		monitorMitmLiveness(context.Background(), runtime, "api.example.com", time.Millisecond, issueMitmLeaf)
	}()
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("probe did not finish")
	}
	if checks != 2 || mitmPausedReason() != "livenessUnavailable" {
		t.Fatalf("checks %d pause %s", checks, mitmPausedReason())
	}
	if _, err := clientPeer.Write([]byte("x")); !errors.Is(err, io.ErrClosedPipe) {
		t.Fatalf("client still open: %v", err)
	}
}

// Cleanup of old sockets may block after publication; it must never cancel
// requests or invalidate issuance that belongs to the newly published setup.
func TestMitmReplacementDoesNotCancelNewWorkDuringOldClose(t *testing.T) {
	old := mitmState.Load()
	defer func() {
		mitmActive.closeAll()
		cancelMitmSignRequests()
		mitmState.Store(old)
		mitmLeaves.clear()
		mitmLeaves.issuer = nil
	}()
	previous, current := &mitmRuntime{}, &mitmRuntime{}
	mitmState.Store(previous)
	c, cp := net.Pipe()
	defer cp.Close()
	r, rp := net.Pipe()
	defer rp.Close()
	barrier := &closeBarrierConn{Conn: c, started: make(chan struct{}), release: make(chan struct{})}
	remove, ok := mitmActive.add(previous, "example.com", barrier, r)
	if !ok {
		t.Fatal("registration failed")
	}
	defer remove()
	done := make(chan struct{})
	go func() { replaceMitmRuntime(current); close(done) }()
	<-barrier.started
	if mitmState.Load() != current {
		t.Fatal("new runtime not published")
	}
	pending := &mitmSignPending{answer: make(chan mitmSignAnswer, 1)}
	mitmSignMu.Lock()
	mitmSignRequests[987654322] = pending
	mitmSignMu.Unlock()
	started, release, result := make(chan struct{}), make(chan struct{}), make(chan error, 1)
	mitmLeaves.issuer = func(context.Context, string) (*mitmLeaf, error) { close(started); <-release; return &mitmLeaf{}, nil }
	go func() { _, err := mitmLeaves.get(context.Background(), "example.com"); result <- err }()
	<-started
	close(barrier.release)
	<-done
	select {
	case <-pending.answer:
		t.Fatal("new request cancelled")
	default:
	}
	close(release)
	if err := <-result; err != nil {
		t.Fatalf("new issuance invalidated: %v", err)
	}
}

func TestMitmConcurrentReplacementsDoNotCancelNewestRequests(t *testing.T) {
	old := mitmState.Load()
	defer func() { mitmActive.closeAll(); cancelMitmSignRequests(); mitmState.Store(old); mitmLeaves.clear() }()
	first, second, third := &mitmRuntime{}, &mitmRuntime{}, &mitmRuntime{}
	mitmState.Store(first)
	c, cp := net.Pipe()
	defer cp.Close()
	r, rp := net.Pipe()
	defer rp.Close()
	barrier := &closeBarrierConn{Conn: c, started: make(chan struct{}), release: make(chan struct{})}
	remove, ok := mitmActive.add(first, "example.com", barrier, r)
	if !ok {
		t.Fatal("registration failed")
	}
	defer remove()
	done := make(chan struct{})
	go func() { replaceMitmRuntime(second); close(done) }()
	<-barrier.started
	oldPending := &mitmSignPending{answer: make(chan mitmSignAnswer, 1)}
	mitmSignMu.Lock()
	mitmSignRequests[987654323] = oldPending
	mitmSignMu.Unlock()
	replaceMitmRuntime(third)
	select {
	case result := <-oldPending.answer:
		if !errors.Is(result.err, errMitmSetupChanged) {
			t.Fatal(result.err)
		}
	default:
		t.Fatal("second generation not cancelled")
	}
	current := &mitmSignPending{answer: make(chan mitmSignAnswer, 1)}
	mitmSignMu.Lock()
	mitmSignRequests[987654324] = current
	mitmSignMu.Unlock()
	close(barrier.release)
	<-done
	select {
	case <-current.answer:
		t.Fatal("old cleanup cancelled newest request")
	default:
	}
	if mitmState.Load() != third {
		t.Fatal("older replacement overwrote latest")
	}
}

type mitmObservedIOConn struct {
	net.Conn
	readStarted, writeStarted chan struct{}
	readOnce, writeOnce       sync.Once
}

func (c *mitmObservedIOConn) Read(p []byte) (int, error) {
	c.readOnce.Do(func() { close(c.readStarted) })
	return c.Conn.Read(p)
}
func (c *mitmObservedIOConn) Write(p []byte) (int, error) {
	c.writeOnce.Do(func() { close(c.writeStarted) })
	return c.Conn.Write(p)
}

func TestMitmDirectionalInterruptIsStickyAndIndependent(t *testing.T) {
	for _, which := range []string{"read", "write"} {
		t.Run(which, func(t *testing.T) {
			raw, peer := net.Pipe()
			defer raw.Close()
			defer peer.Close()
			observed := &mitmObservedIOConn{Conn: raw, readStarted: make(chan struct{}), writeStarted: make(chan struct{})}
			idle := &mitmIdleConn{Conn: observed, timeout: time.Minute}
			done := make(chan error, 1)
			go func() {
				if which == "read" {
					_, err := idle.Read(make([]byte, 1))
					done <- err
				} else {
					_, err := idle.Write([]byte("x"))
					done <- err
				}
			}()
			if which == "read" {
				<-observed.readStarted
				_ = idle.interruptRead()
				_ = idle.SetReadDeadline(time.Now().Add(time.Minute))
			} else {
				<-observed.writeStarted
				_ = idle.interruptWrite()
				_ = idle.SetWriteDeadline(time.Now().Add(time.Minute))
			}
			select {
			case err := <-done:
				if err == nil {
					t.Fatal("interrupted I/O succeeded")
				}
			case <-time.After(time.Second):
				t.Fatal("interrupted I/O remained blocked")
			}
			if which == "read" {
				if _, err := idle.Read(make([]byte, 1)); !errors.Is(err, net.ErrClosed) {
					t.Fatalf("read revived: %v", err)
				}
				go func() { _, _ = peer.Read(make([]byte, 1)) }()
				if _, err := idle.Write([]byte("y")); err != nil {
					t.Fatalf("unrelated write failed: %v", err)
				}
			} else {
				if _, err := idle.Write([]byte("x")); !errors.Is(err, net.ErrClosed) {
					t.Fatalf("write revived: %v", err)
				}
				go func() { _, _ = peer.Write([]byte("y")) }()
				if _, err := idle.Read(make([]byte, 1)); err != nil {
					t.Fatalf("unrelated read failed: %v", err)
				}
			}
		})
	}
}

type mitmFailDeadlineConn struct{ net.Conn }

func (c mitmFailDeadlineConn) SetReadDeadline(time.Time) error {
	return errors.New("deadline unavailable")
}
func (c mitmFailDeadlineConn) SetWriteDeadline(time.Time) error {
	return errors.New("deadline unavailable")
}
func TestMitmDuplexDeadlineFailureClosesRawSockets(t *testing.T) {
	client, clientPeer := net.Pipe()
	upstream, site := net.Pipe()
	defer clientPeer.Close()
	defer site.Close()
	control := &mitmDuplexControl{client: &mitmIdleConn{Conn: mitmFailDeadlineConn{client}}, upstream: &mitmIdleConn{Conn: mitmFailDeadlineConn{upstream}}}
	reads := make(chan error, 2)
	go func() { _, err := clientPeer.Read(make([]byte, 1)); reads <- err }()
	go func() { _, err := site.Read(make([]byte, 1)); reads <- err }()
	control.stopUpload()
	for i := 0; i < 2; i++ {
		select {
		case err := <-reads:
			if err == nil {
				t.Fatal("raw socket not closed")
			}
		case <-time.After(time.Second):
			t.Fatal("raw-close fallback failed")
		}
	}
}

// Test cleanup only: wake pending sign waiters. Production replacement
// detaches them atomically in replaceMitmRuntime.
func cancelMitmSignRequests() {
	mitmSignMu.Lock()
	pending := mitmSignRequests
	mitmSignRequests = map[uint64]*mitmSignPending{}
	mitmSignMu.Unlock()
	for _, request := range pending {
		request.answer <- mitmSignAnswer{err: errMitmSetupChanged}
	}
}
