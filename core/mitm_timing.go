package core

import (
	"context"
	"errors"
	"sync"
	"sync/atomic"
	"time"
)

// Stage timing of the signing chain, for tests and internal investigation
// only. Nothing records unless a recorder is installed (none is in
// production), it lives in memory alone, is bounded, and a record holds
// numbers only: never a host, address, URL, certificate or error text.
type mitmSignStage uint8

const (
	mitmStageIssueStart mitmSignStage = iota + 1
	// The Core made the leaf key.
	mitmStageKeyReady
	// sendMitmSign returned (queued for the batcher, or dropped).
	mitmStageRequestQueued
	// The batcher took the request into a batch.
	mitmStageRequestBatched
	// The batch holding the request was handed to the transport and written.
	mitmStageRequestWritten
	// handleMitmSignResult matched the reply to its pending request.
	mitmStageReplyReceived
	// The reply's leaf was checked (Result: ok or why not).
	mitmStageReplyChecked
	// The issuer returned (Result: its outcome).
	mitmStageIssueDone
	// The issuance's leaf was kept, or dropped as its generation changed.
	mitmStageAdopted
	mitmStageDroppedGeneration
	// A connection's wait ended: served, expired at its own deadline, or failed.
	mitmStageWaiterServed
	mitmStageWaiterExpired
	mitmStageWaiterFailed
	// A global pause was published (Result: its reason).
	mitmStagePause
)

type mitmSignResultCode uint8

const (
	mitmResultNone mitmSignResultCode = iota
	mitmResultOK
	mitmResultRefused
	mitmResultDropped
	mitmResultTimeout
	mitmResultSetupChanged
	mitmResultNotListed
	mitmResultUnusable
	// Pause reasons the app's refusals do not already name.
	mitmResultLiveness
)

// One record. Every field is a number: see mitm_timing_test.go, which keeps
// it that way.
type mitmSignTiming struct {
	// The issuance this belongs to (process-local, 0 for a pause).
	Issue uint64
	// The signing request's ReqID once one exists.
	ReqID  uint64
	Stage  mitmSignStage
	Result mitmSignResultCode
	// Monotonic nanoseconds since the recorder was installed.
	At int64
}

const mitmSignTimingCap = 256

// A bounded ring of records; the oldest go first.
type mitmSignTimingRing struct {
	mu      sync.Mutex
	started time.Time
	records []mitmSignTiming
	next    int
	full    bool
}

var (
	mitmSignTimer    atomic.Pointer[mitmSignTimingRing]
	mitmSignIssueSeq atomic.Uint64
)

func newMitmSignTimingRing() *mitmSignTimingRing {
	return &mitmSignTimingRing{started: time.Now(), records: make([]mitmSignTiming, mitmSignTimingCap)}
}

func (ring *mitmSignTimingRing) add(record mitmSignTiming) {
	record.At = int64(time.Since(ring.started))
	ring.mu.Lock()
	ring.records[ring.next] = record
	ring.next++
	if ring.next == len(ring.records) {
		ring.next = 0
		ring.full = true
	}
	ring.mu.Unlock()
}

// The records, oldest first.
func (ring *mitmSignTimingRing) snapshot() []mitmSignTiming {
	ring.mu.Lock()
	defer ring.mu.Unlock()
	if !ring.full {
		return append([]mitmSignTiming(nil), ring.records[:ring.next]...)
	}
	return append(append([]mitmSignTiming(nil), ring.records[ring.next:]...), ring.records[:ring.next]...)
}

// Installs a fresh recorder and returns it; stopMitmSignTiming removes it,
// and its records with it.
func startMitmSignTiming() *mitmSignTimingRing {
	ring := newMitmSignTimingRing()
	mitmSignTimer.Store(ring)
	return ring
}

func stopMitmSignTiming() {
	mitmSignTimer.Store(nil)
}

func mitmTime(issue, reqID uint64, stage mitmSignStage, result mitmSignResultCode) {
	if ring := mitmSignTimer.Load(); ring != nil {
		ring.add(mitmSignTiming{Issue: issue, ReqID: reqID, Stage: stage, Result: result})
	}
}

// The issuance an issuer runs for, carried in its context only while a
// recorder is installed.
type mitmTimingIssueKey struct{}

func mitmTimingIssue(ctx context.Context) uint64 {
	issue, _ := ctx.Value(mitmTimingIssueKey{}).(uint64)
	return issue
}

func mitmTimingResult(err error) mitmSignResultCode {
	var refusal mitmAppRefusal
	switch {
	case err == nil:
		return mitmResultOK
	case errors.Is(err, errMitmNotListed):
		return mitmResultNotListed
	case errors.Is(err, errMitmSetupChanged):
		return mitmResultSetupChanged
	case errors.As(err, &refusal):
		return mitmResultRefused
	case errors.Is(err, errMitmSignDropped):
		return mitmResultDropped
	case errors.Is(err, context.DeadlineExceeded):
		return mitmResultTimeout
	default:
		return mitmResultUnusable
	}
}

func mitmTimingPauseResult(reason string) mitmSignResultCode {
	switch reason {
	case "signTimeout":
		return mitmResultTimeout
	case "appUnavailable":
		return mitmResultDropped
	case "leafUnusable":
		return mitmResultUnusable
	case "livenessUnavailable":
		return mitmResultLiveness
	default:
		return mitmResultRefused
	}
}
