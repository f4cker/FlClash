package core

import (
	"context"
	"net"
	"sync"
	"sync/atomic"
	"time"
)

type mitmPair struct {
	host           string
	client, remote net.Conn
}
type mitmConnections struct {
	mu     sync.Mutex
	active map[*mitmPair]struct{}
}

var mitmActive = &mitmConnections{active: make(map[*mitmPair]struct{})}

// Register before writing any TLS bytes. Reconfiguration publishes the new
// runtime before closing old sessions, so racing registrations are rejected.
func (m *mitmConnections) add(runtime *mitmRuntime, host string, client, remote net.Conn) (func(), bool) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if runtime == nil || mitmState.Load() != runtime || mitmPausedFor(host) {
		return nil, false
	}
	pair := &mitmPair{host: host, client: client, remote: remote}
	m.active[pair] = struct{}{}
	return func() { m.mu.Lock(); delete(m.active, pair); m.mu.Unlock() }, true
}

func (m *mitmConnections) closeAll() {
	m.mu.Lock()
	pairs := make([]*mitmPair, 0, len(m.active))
	for pair := range m.active {
		pairs = append(pairs, pair)
		delete(m.active, pair)
	}
	m.mu.Unlock()
	for _, pair := range pairs {
		_ = pair.client.Close()
		_ = pair.remote.Close()
	}
}

// Pause publication, registration check, and session extraction share a lock.
func (m *mitmConnections) pauseGlobal(runtime *mitmRuntime, reason string) (*mitmPause, bool) {
	m.mu.Lock()
	if mitmState.Load() != runtime {
		m.mu.Unlock()
		return nil, false
	}
	previous := mitmPaused.Swap(&mitmPause{runtime: runtime, until: time.Now().Add(mitmPauseFor), reason: reason})
	pairs := make([]*mitmPair, 0, len(m.active))
	for pair := range m.active {
		pairs = append(pairs, pair)
		delete(m.active, pair)
	}
	m.mu.Unlock()
	for _, pair := range pairs {
		_ = pair.client.Close()
		_ = pair.remote.Close()
	}
	return previous, true
}

func (m *mitmConnections) pauseHost(runtime *mitmRuntime, host, reason string) {
	m.mu.Lock()
	if mitmState.Load() != runtime {
		m.mu.Unlock()
		return
	}
	mitmHostPauses.Store(host, mitmPause{runtime: runtime, until: time.Now().Add(mitmPauseFor), reason: reason})
	var pairs []*mitmPair
	for pair := range m.active {
		if pair.host == host {
			pairs = append(pairs, pair)
			delete(m.active, pair)
		}
	}
	m.mu.Unlock()
	for _, pair := range pairs {
		_ = pair.client.Close()
		_ = pair.remote.Close()
	}
}

// Publish configuration and clear its pauses atomically with session
// registration. Old sessions are closed after releasing the registry lock.
func replaceMitmRuntime(runtime *mitmRuntime) {
	mitmActive.mu.Lock()
	// Block both new cache calls and sign registration while detaching old
	// work. No new-runtime work can be invalidated after publication.
	mitmLeaves.mu.Lock()
	mitmSignMu.Lock()
	pending := mitmSignRequests
	mitmSignRequests = map[uint64]*mitmSignPending{}
	mitmLeaves.inflight = map[mitmLeafKey]*mitmLeafCall{}
	mitmLeaves.generation++
	previous := mitmState.Load()
	mitmState.Store(runtime)
	mitmCaptures.runtimeReplaced(previous, runtime)
	mitmPaused.Store(nil)
	mitmHostPauses.Clear()
	pairs := make([]*mitmPair, 0, len(mitmActive.active))
	for pair := range mitmActive.active {
		pairs = append(pairs, pair)
		delete(mitmActive.active, pair)
	}
	mitmSignMu.Unlock()
	mitmLeaves.mu.Unlock()
	mitmActive.mu.Unlock()
	for _, request := range pending {
		request.answer <- mitmSignAnswer{err: errMitmSetupChanged}
	}
	for _, pair := range pairs {
		_ = pair.client.Close()
		_ = pair.remote.Close()
	}
}

// Desktop control relay closure means the signer can no longer approve leaves.
func mitmSignerGone() { replaceMitmRuntime(nil) }

// Bound stalled readers/writers without imposing a total body-size/time cap;
// progress refreshes the appropriate deadline on every operation. Writing
// also counts as progress for a read already blocked on the same connection:
// the response reader starts with the upload and waits on the site for as
// long as the upload keeps moving, so it expires only after the connection
// has been idle in both directions for the timeout.
type mitmIdleConn struct {
	net.Conn
	timeout                           time.Duration
	closing                           atomic.Bool
	readMu, writeMu                   sync.Mutex
	readInterrupted, writeInterrupted bool
	// UnixNano of the last write-driven read-deadline refresh; throttles it.
	readRefreshed atomic.Int64
}

// Cancellation and deadline refresh are serialized so a subsequent operation
// cannot revive a direction after it has been interrupted. Locks are never
// held over the actual network I/O.
func (c *mitmIdleConn) interruptRead() error {
	c.readMu.Lock()
	defer c.readMu.Unlock()
	c.readInterrupted = true
	return c.Conn.SetReadDeadline(time.Now())
}
func (c *mitmIdleConn) interruptWrite() error {
	c.writeMu.Lock()
	defer c.writeMu.Unlock()
	c.writeInterrupted = true
	return c.Conn.SetWriteDeadline(time.Now())
}

// Keep external TLS deadline updates from resurrecting an interrupted I/O.
func (c *mitmIdleConn) SetReadDeadline(deadline time.Time) error {
	c.readMu.Lock()
	defer c.readMu.Unlock()
	if c.readInterrupted {
		deadline = time.Now()
	}
	return c.Conn.SetReadDeadline(deadline)
}
func (c *mitmIdleConn) SetWriteDeadline(deadline time.Time) error {
	c.writeMu.Lock()
	defer c.writeMu.Unlock()
	if c.writeInterrupted {
		deadline = time.Now()
	}
	return c.Conn.SetWriteDeadline(deadline)
}
func (c *mitmIdleConn) SetDeadline(deadline time.Time) error {
	if err := c.SetReadDeadline(deadline); err != nil {
		return err
	}
	return c.SetWriteDeadline(deadline)
}
func (c *mitmIdleConn) Read(p []byte) (int, error) {
	c.readMu.Lock()
	if c.readInterrupted {
		c.readMu.Unlock()
		return 0, net.ErrClosed
	}
	err := c.Conn.SetReadDeadline(time.Now().Add(c.timeout))
	c.readMu.Unlock()
	if err != nil {
		return 0, err
	}
	return c.Conn.Read(p)
}
func (c *mitmIdleConn) Write(p []byte) (int, error) {
	c.writeMu.Lock()
	if c.writeInterrupted {
		c.writeMu.Unlock()
		return 0, net.ErrClosed
	}
	timeout := c.timeout
	if c.closing.Load() {
		timeout = time.Second
	}
	err := c.Conn.SetWriteDeadline(time.Now().Add(timeout))
	c.writeMu.Unlock()
	if err != nil {
		return 0, err
	}
	n, err := c.Conn.Write(p)
	if n > 0 {
		c.refreshRead()
	}
	return n, err
}

// Throttled to a quarter of the timeout, so a pending read still expires no
// sooner than three quarters of the timeout after the last write progress.
// An interrupted read is never revived.
func (c *mitmIdleConn) refreshRead() {
	now := time.Now()
	if now.UnixNano()-c.readRefreshed.Load() < int64(c.timeout/4) {
		return
	}
	c.extendRead(now)
}

// Gives a pending read a full idle period from now, unless interrupted.
func (c *mitmIdleConn) extendRead(now time.Time) {
	c.readRefreshed.Store(now.UnixNano())
	c.readMu.Lock()
	defer c.readMu.Unlock()
	if !c.readInterrupted {
		_ = c.Conn.SetReadDeadline(now.Add(c.timeout))
	}
}

// Every probe uses a new core-generated key. Only a valid leaf under the
// pinned nonexportable CA can renew it; a plain IPC liveness claim cannot.
// A failed, dropped or expired probe atomically pauses and closes sessions.
func monitorMitmLiveness(ctx context.Context, runtime *mitmRuntime, host string, interval time.Duration, issue func(context.Context, string) (*mitmLeaf, error)) {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
		}
		probeCtx, cancel := context.WithTimeout(ctx, mitmLeafWait)
		leaf, err := issue(probeCtx, host)
		cancel()
		if ctx.Err() != nil {
			return
		}
		if err != nil || leaf == nil {
			mitmActive.pauseGlobal(runtime, "livenessUnavailable")
			return
		}
	}
}
