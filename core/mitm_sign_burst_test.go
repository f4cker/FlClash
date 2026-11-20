package core

// A reproduction of a browser opening many listed hosts at once: waves of new
// hosts, each connection waiting on its leaf exactly as mitmInterceptEligible
// does (mitmConnectionLeafWait, then pauseMitm on failure), while K decrypted
// sessions run liveness probes. The Core side is real: leaf cache, issuance,
// requestMitmLeaf, handleMitmSignResult, checkMitmLeaf and the message
// batcher. The app is a model of the macOS path (see burstApp), so that a
// cost can be turned up and its effect read off. The default run is one
// small scenario with only the Core's own costs; the sweep is opt-in:
//
//	FLASH_MITM_BURST=1 go test -run TestMitmSignBurst -v .
//
// FLASH_MITM_BURST_OUT=<file> appends the table rows to a file.

import (
	"context"
	"crypto/x509"
	"fmt"
	"os"
	"slices"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

// The app as the macOS build answers a signing request (lib/providers/mitm.dart
// MitmSignAction.answer, macos/Runner/MitmSignerChannel.swift):
//   - a request reaches Dart through the helper relay (relayIn);
//   - a trust check is shared by every request that arrives while one runs,
//     never cached: coreIdentity, certificate, checkCertificate, then
//     `security verify-cert` (verify), then certificate again;
//   - each native call is one Flutter platform-channel round trip (hop each
//     way, main thread) onto ONE serial dispatch queue, where it costs its own
//     time (keychain reads, csops, ECDSA);
//   - sign is one more native call; more than signCap in flight are refused
//     (signBusy);
//   - results go back one frame at a time through the relay's serial send
//     (sendEach) and reach the Core relayOut later.
type burstModel struct {
	name                        string
	relayIn, relayOut, sendEach time.Duration
	hop                         time.Duration
	identity, certRead          time.Duration
	checkSign, sign, verify     time.Duration
	// The fix in _checkTrust: certificate and checkCertificate in one round.
	batchedCheck bool
	// The app's _maxConcurrentSigns (16); 0 models no cap, for a run that
	// measures the Core alone.
	signCap int64
}

type burstOp struct {
	cost time.Duration
	done chan struct{}
}

type burstApp struct {
	t      *testing.T
	fake   *fakeMitmApp
	model  burstModel
	queue  chan burstOp
	sendMu sync.Mutex

	checkMu  sync.Mutex
	checking chan struct{}
	checks   atomic.Int64

	signing atomic.Int64
	busy    atomic.Int64
	answers sync.WaitGroup
}

func newBurstApp(t *testing.T, fake *fakeMitmApp, model burstModel) *burstApp {
	app := &burstApp{t: t, fake: fake, model: model, queue: make(chan burstOp, 4096)}
	go func() {
		for op := range app.queue {
			time.Sleep(op.cost)
			close(op.done)
		}
	}()
	t.Cleanup(func() { app.answers.Wait(); close(app.queue) })
	return app
}

// One platform-channel call: a hop to the main thread, the serial queue, and
// a hop back.
func (app *burstApp) native(cost time.Duration) {
	time.Sleep(app.model.hop)
	op := burstOp{cost: cost, done: make(chan struct{})}
	app.queue <- op
	<-op.done
	time.Sleep(app.model.hop)
}

// Calls issued together: one round, each queued behind the other.
func (app *burstApp) nativeTogether(costs ...time.Duration) {
	time.Sleep(app.model.hop)
	ops := make([]burstOp, len(costs))
	for i, cost := range costs {
		ops[i] = burstOp{cost: cost, done: make(chan struct{})}
		app.queue <- ops[i]
	}
	for _, op := range ops {
		<-op.done
	}
	time.Sleep(app.model.hop)
}

func (app *burstApp) trustCheck() {
	app.checkMu.Lock()
	if running := app.checking; running != nil {
		app.checkMu.Unlock()
		<-running
		return
	}
	running := make(chan struct{})
	app.checking = running
	app.checkMu.Unlock()
	app.checks.Add(1)
	m := app.model
	app.native(m.identity)
	if m.batchedCheck {
		app.nativeTogether(m.certRead, m.checkSign)
	} else {
		app.native(m.certRead)
		app.native(m.checkSign)
	}
	time.Sleep(m.verify)
	app.native(m.certRead)
	app.checkMu.Lock()
	app.checking = nil
	app.checkMu.Unlock()
	close(running)
}

func (app *burstApp) answer(request MitmSignRequest) {
	defer app.answers.Done()
	time.Sleep(app.model.relayIn)
	app.trustCheck()
	result := MitmSignResultParams{ReqID: request.ReqID}
	if signing := app.signing.Add(1); app.model.signCap > 0 && signing > app.model.signCap {
		app.signing.Add(-1)
		app.busy.Add(1)
		result.Error = "signBusy"
	} else {
		app.native(app.model.sign)
		app.signing.Add(-1)
		result.Cert = app.fake.leaf(app.t, request.Host, request.SPKI, nil)
		result.CA = app.fake.ca.Raw
	}
	app.sendMu.Lock()
	time.Sleep(app.model.sendEach)
	app.sendMu.Unlock()
	time.Sleep(app.model.relayOut)
	handleMitmSignResult(result)
}

type burstWave struct {
	waits             []time.Duration
	served, expired   int
	failed, passed    int
	issues            []time.Duration
	pauses            []string
	livenessFailed    int64
	busy, checks      int64
	requestToWritten  []time.Duration
	batchedToWritten  []time.Duration
	replyToChecked    []time.Duration
	issueStartToQueue []time.Duration
}

func burstPercentile(values []time.Duration, p float64) time.Duration {
	if len(values) == 0 {
		return 0
	}
	sorted := slices.Clone(values)
	slices.Sort(sorted)
	index := int(float64(len(sorted)-1) * p)
	return sorted[index]
}

func burstMs(d time.Duration) string {
	return fmt.Sprintf("%.1f", float64(d)/float64(time.Millisecond))
}

// Runs waves of size new hosts, gap apart, with liveness probes on k
// sessions, and returns one result per wave.
func runMitmSignBurst(t *testing.T, model burstModel, size, waves, k int, gap time.Duration) []burstWave {
	t.Helper()
	fake := newFakeMitmApp(t)
	withMitmState(t)
	applyMitmSetup(&SetupParams{Mitm: &MitmSetup{
		Enable: true, Hostname: []string{"*.burst.example"}, DecryptTLS: true, CAFingerprint: fake.fingerprint(),
	}}, nil)
	defer func() { mitmActive.closeAll(); mitmLeaves.clear(); mitmPaused.Store(nil) }()
	app := newBurstApp(t, fake, model)

	// The real batcher, on queues of its own, hands batches to the model.
	state := make(chan Message, messageQueueSize)
	priority := make(chan Message, messageQueueSize)
	bulk := make(chan Message, messageQueueSize)
	batcherDone := make(chan struct{})
	go func() {
		defer close(batcherDone)
		runMessageBatcher(state, priority, bulk, func(batch []Message) {
			for _, message := range batch {
				if request, ok := message.Data.(*MitmSignRequest); ok {
					app.answers.Add(1)
					go app.answer(*request)
				}
			}
		})
	}()
	// Runs after sendMitmSign is restored (defers run last first), so no
	// issuance enqueues on a closed queue. The batcher has returned before
	// the answers are awaited, so no Add races the Wait, and every answer
	// (which uses t) has ended before this returns.
	defer func() {
		close(priority)
		close(state)
		close(bulk)
		<-batcherDone
		app.answers.Wait()
	}()
	previous := sendMitmSign
	sendMitmSign = func(request *MitmSignRequest) bool {
		return enqueueLatest(priority, Message{Type: MitmSignMessage, Data: request})
	}
	defer func() { sendMitmSign = previous }()

	ring := startMitmSignTiming()
	defer stopMitmSignTiming()

	// Liveness: k sessions each prove the signer on a fresh issuance.
	stop := make(chan struct{})
	var livenessFailed atomic.Int64
	var probes sync.WaitGroup
	for i := 0; i < k; i++ {
		probes.Add(1)
		go func(i int) {
			defer probes.Done()
			ticker := time.NewTicker(gap)
			defer ticker.Stop()
			for {
				select {
				case <-stop:
					return
				case <-ticker.C:
				}
				ctx, cancel := context.WithTimeout(context.Background(), mitmLeafWait)
				leaf, err := mitmLeaves.fresh(ctx, fmt.Sprintf("live%d.burst.example", i))
				cancel()
				if err != nil || leaf == nil {
					livenessFailed.Add(1)
				}
			}
		}(i)
	}

	results := make([]burstWave, 0, waves)
	for wave := 0; wave < waves; wave++ {
		// Each wave is measured on its own: an earlier wave's pause would
		// pass this one through unasked.
		mitmPaused.Store(nil)
		runtime := mitmState.Load()
		var mu sync.Mutex
		result := burstWave{}
		var conns sync.WaitGroup
		for i := 0; i < size; i++ {
			conns.Add(1)
			go func(host string) {
				defer conns.Done()
				if mitmPausedFor(host) {
					mu.Lock()
					result.passed++
					mu.Unlock()
					return
				}
				started := time.Now()
				ctx, cancel := context.WithTimeout(context.Background(), mitmConnectionLeafWait)
				leaf, err := mitmLeaves.get(ctx, host)
				expired := ctx.Err() != nil
				cancel()
				waited := time.Since(started)
				if err != nil {
					pauseMitm(runtime, host, err)
				}
				mu.Lock()
				defer mu.Unlock()
				switch {
				case err == nil && leaf != nil:
					result.served++
					result.waits = append(result.waits, waited)
				case expired:
					result.expired++
					result.waits = append(result.waits, waited)
				default:
					result.failed++
				}
			}(fmt.Sprintf("w%d-%d.burst.example", wave, i))
		}
		conns.Wait()
		if reason := mitmPausedReason(); reason != "" {
			result.pauses = append(result.pauses, reason)
		}
		results = append(results, result)
		time.Sleep(gap)
	}
	close(stop)
	probes.Wait()
	// Let late answers land before the issuances' timing is read.
	deadline := time.Now().Add(mitmLeafWait)
	for time.Now().Before(deadline) {
		mitmLeaves.mu.Lock()
		inflight := len(mitmLeaves.inflight)
		mitmLeaves.mu.Unlock()
		if inflight == 0 {
			break
		}
		time.Sleep(10 * time.Millisecond)
	}
	time.Sleep(50 * time.Millisecond)

	// Per issuance: start to reply checked, and the stages in between.
	type marks map[mitmSignStage]int64
	byIssue := map[uint64]marks{}
	for _, record := range ring.snapshot() {
		if record.Issue == 0 {
			continue
		}
		if byIssue[record.Issue] == nil {
			byIssue[record.Issue] = marks{}
		}
		if _, seen := byIssue[record.Issue][record.Stage]; !seen {
			byIssue[record.Issue][record.Stage] = record.At
		}
	}
	summary := &results[len(results)-1]
	for _, m := range byIssue {
		start, okStart := m[mitmStageIssueStart]
		checked, okChecked := m[mitmStageReplyChecked]
		if okStart && okChecked {
			summary.issues = append(summary.issues, time.Duration(checked-start))
		}
		if queued, ok := m[mitmStageRequestQueued]; ok && okStart {
			summary.issueStartToQueue = append(summary.issueStartToQueue, time.Duration(queued-start))
			if written, ok := m[mitmStageRequestWritten]; ok {
				summary.requestToWritten = append(summary.requestToWritten, time.Duration(written-queued))
			}
		}
		if batched, ok := m[mitmStageRequestBatched]; ok {
			if written, ok := m[mitmStageRequestWritten]; ok {
				summary.batchedToWritten = append(summary.batchedToWritten, time.Duration(written-batched))
			}
		}
		if received, ok := m[mitmStageReplyReceived]; ok && okChecked {
			summary.replyToChecked = append(summary.replyToChecked, time.Duration(checked-received))
		}
	}
	summary.livenessFailed = livenessFailed.Load()
	summary.busy = app.busy.Load()
	summary.checks = app.checks.Load()
	return results
}

func burstReport(t *testing.T, model burstModel, size, k int, waves []burstWave) string {
	var all []time.Duration
	served, expired, failed, passed := 0, 0, 0, 0
	var pauses []string
	var rows []string
	for i, wave := range waves {
		all = append(all, wave.waits...)
		served += wave.served
		expired += wave.expired
		failed += wave.failed
		passed += wave.passed
		pauses = append(pauses, wave.pauses...)
		rows = append(rows, fmt.Sprintf("| %s | %d | %d | %d | %s | %s | %s | %d | %d | %s |", model.name, size, k, i+1,
			burstMs(burstPercentile(wave.waits, 0.5)), burstMs(burstPercentile(wave.waits, 0.95)),
			burstMs(burstPercentile(wave.waits, 1)), wave.expired, wave.failed, strings.Join(wave.pauses, ",")))
	}
	last := waves[len(waves)-1]
	rows = append(rows, fmt.Sprintf("| %s | %d | %d | all | %s | %s | %s | %d | %d | issue p50/p95/max %s/%s/%s; keygen+register p95 %s; queued→written p95 %s; reply→checked p95 %s; checks %d; signBusy %d; liveness failed %d |",
		model.name, size, k, burstMs(burstPercentile(all, 0.5)), burstMs(burstPercentile(all, 0.95)), burstMs(burstPercentile(all, 1)),
		expired, failed,
		burstMs(burstPercentile(last.issues, 0.5)), burstMs(burstPercentile(last.issues, 0.95)), burstMs(burstPercentile(last.issues, 1)),
		burstMs(burstPercentile(last.issueStartToQueue, 0.95)), burstMs(burstPercentile(last.requestToWritten, 0.95)),
		burstMs(burstPercentile(last.replyToChecked, 0.95)), last.checks, last.busy, last.livenessFailed))
	_ = served
	_ = passed
	return strings.Join(rows, "\n")
}

// With the app answering at once, what is left is the Core's own path:
// key generation, the batcher, the reply check. It is far inside the wait.
func TestMitmSignBurstCoreAloneIsFast(t *testing.T) {
	model := burstModel{name: "core-only"}
	waves := runMitmSignBurst(t, model, 20, 3, 4, 150*time.Millisecond)
	t.Log("\n" + burstReport(t, model, 20, 4, waves))
	for i, wave := range waves {
		if wave.expired != 0 || wave.failed != 0 || len(wave.pauses) != 0 {
			t.Fatalf("wave %d: expired %d failed %d pauses %v", i, wave.expired, wave.failed, wave.pauses)
		}
		if p95 := burstPercentile(wave.waits, 0.95); p95 > 150*time.Millisecond {
			t.Fatalf("wave %d: the Core alone took %v (p95)", i, p95)
		}
	}
}

// The signing requests are not held for the batch interval. Measured from
// the batcher's own take (not from sendMitmSign's return, which the batcher
// can beat): a request that waits for the interval waits all of it, from
// the timer the batch's first message started, so a held burst has a
// median near messageBatchInterval and a flushed one near zero. Half the
// interval separates them with room on either side.
func TestMitmSignBurstRequestIsWrittenWithoutTheBatchInterval(t *testing.T) {
	model := burstModel{name: "core-only"}
	waves := runMitmSignBurst(t, model, 6, 3, 0, 100*time.Millisecond)
	last := waves[len(waves)-1]
	if len(last.batchedToWritten) < 6 {
		t.Fatalf("%d requests timed", len(last.batchedToWritten))
	}
	if p50 := burstPercentile(last.batchedToWritten, 0.5); p50 >= messageBatchInterval/2 {
		t.Fatalf("batched→written median %v, not under half the %v batch interval", p50, messageBatchInterval)
	}
}

func TestMitmSignBurstSweep(t *testing.T) {
	if os.Getenv("FLASH_MITM_BURST") == "" {
		t.Skip("set FLASH_MITM_BURST=1 to run the sweep")
	}
	ms := time.Millisecond
	// Measured: /usr/bin/security verify-cert on this Mac through Dart's
	// Process.run, p50 4.9 ms, max 15 ms (60 ms cold). Keychain reads,
	// main-thread hops and relay times are not measurable here: swept.
	idle := burstModel{relayIn: 2 * ms, relayOut: 2 * ms, sendEach: 1 * ms, hop: 1 * ms,
		identity: 1 * ms, certRead: 3 * ms, checkSign: 4 * ms, sign: 5 * ms, verify: 10 * ms, signCap: 16}
	busy := burstModel{relayIn: 10 * ms, relayOut: 10 * ms, sendEach: 3 * ms, hop: 8 * ms,
		identity: 2 * ms, certRead: 15 * ms, checkSign: 17 * ms, sign: 18 * ms, verify: 60 * ms, signCap: 16}
	var models []burstModel
	for _, base := range []struct {
		name  string
		model burstModel
	}{{"idle", idle}, {"busy", busy}} {
		for _, batched := range []bool{false, true} {
			model := base.model
			model.batchedCheck = batched
			model.name = base.name + map[bool]string{false: "/before", true: "/after"}[batched]
			models = append(models, model)
		}
	}
	header := "| model | burst | K | wave | p50 ms | p95 ms | max ms | >500ms | failed | pause |\n|---|---|---|---|---|---|---|---|---|---|"
	out := []string{header}
	for _, model := range models {
		for _, size := range []int{6, 12, 20} {
			waves := runMitmSignBurst(t, model, size, 4, 4, 250*time.Millisecond)
			out = append(out, burstReport(t, model, size, 4, waves))
		}
	}
	table := strings.Join(out, "\n")
	t.Log("\n" + table)
	if path := os.Getenv("FLASH_MITM_BURST_OUT"); path != "" {
		file, err := os.OpenFile(path, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o600)
		if err == nil {
			_, _ = file.WriteString(table + "\n")
			_ = file.Close()
		}
	}
}

// Kept so x509 stays imported when the model changes what it signs.
var _ = x509.ParseCertificate
