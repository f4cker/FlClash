package core

import (
	"context"
	"reflect"
	"slices"
	"testing"
	"time"
)

// A record must stay numbers alone: no host, address, URL, certificate or
// error text can get into one.
func TestMitmSignTimingRecordHoldsNumbersOnly(t *testing.T) {
	record := reflect.TypeOf(mitmSignTiming{})
	for i := 0; i < record.NumField(); i++ {
		field := record.Field(i)
		switch field.Type.Kind() {
		case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64,
			reflect.Uint, reflect.Uint8, reflect.Uint16, reflect.Uint32, reflect.Uint64:
		default:
			t.Fatalf("field %s is %s, not a number", field.Name, field.Type)
		}
	}
}

func TestMitmSignTimingIsOffUnlessStarted(t *testing.T) {
	stopMitmSignTiming()
	mitmTime(1, 1, mitmStageIssueStart, mitmResultNone)
	if mitmSignTimer.Load() != nil {
		t.Fatal("a recorder exists without a start")
	}
	ring := startMitmSignTiming()
	if got := len(ring.snapshot()); got != 0 {
		t.Fatalf("a fresh recorder holds %d records", got)
	}
	stopMitmSignTiming()
}

func TestMitmSignTimingRingIsBounded(t *testing.T) {
	ring := startMitmSignTiming()
	defer stopMitmSignTiming()
	total := mitmSignTimingCap + 40
	for i := 1; i <= total; i++ {
		mitmTime(uint64(i), 0, mitmStageIssueStart, mitmResultNone)
	}
	records := ring.snapshot()
	if len(records) != mitmSignTimingCap {
		t.Fatalf("%d records, want the cap %d", len(records), mitmSignTimingCap)
	}
	// The oldest went first, the rest are in order.
	if records[0].Issue != uint64(total-mitmSignTimingCap+1) || records[len(records)-1].Issue != uint64(total) {
		t.Fatalf("kept %d..%d", records[0].Issue, records[len(records)-1].Issue)
	}
	for i := 1; i < len(records); i++ {
		if records[i].Issue != records[i-1].Issue+1 || records[i].At < records[i-1].At {
			t.Fatalf("record %d out of order", i)
		}
	}
}

func TestMitmSignTimingStopDropsTheRecords(t *testing.T) {
	ring := startMitmSignTiming()
	mitmTime(1, 0, mitmStageIssueStart, mitmResultNone)
	stopMitmSignTiming()
	mitmTime(2, 0, mitmStageIssueStart, mitmResultNone)
	if got := len(ring.snapshot()); got != 1 {
		t.Fatalf("a stopped recorder took %d records", got)
	}
	next := startMitmSignTiming()
	defer stopMitmSignTiming()
	if next == ring || len(next.snapshot()) != 0 {
		t.Fatal("a new start reused the old records")
	}
}

// One issuance through the real cache, signer request, batcher and reply
// check leaves every stage in order, under one issue number.
func TestMitmSignTimingFollowsAnIssuance(t *testing.T) {
	fake := newFakeMitmApp(t)
	withMitmState(t)
	applyMitmSetup(&SetupParams{Mitm: &MitmSetup{
		Enable: true, Hostname: []string{"*.timing.example"}, DecryptTLS: true, CAFingerprint: fake.fingerprint(),
	}}, nil)
	defer func() { mitmActive.closeAll(); mitmLeaves.clear(); mitmPaused.Store(nil) }()
	priority := make(chan Message, 4)
	go runMessageBatcher(closedMessages(), priority, closedMessages(), func(batch []Message) {
		for _, message := range batch {
			if request, ok := message.Data.(*MitmSignRequest); ok {
				go handleMitmSignResult(MitmSignResultParams{
					ReqID: request.ReqID,
					Cert:  fake.leaf(t, request.Host, request.SPKI, nil),
					CA:    fake.ca.Raw,
				})
			}
		}
	})
	defer close(priority)
	previous := sendMitmSign
	sendMitmSign = func(request *MitmSignRequest) bool {
		return enqueueLatest(priority, Message{Type: MitmSignMessage, Data: request})
	}
	defer func() { sendMitmSign = previous }()

	ring := startMitmSignTiming()
	defer stopMitmSignTiming()
	ctx, cancel := context.WithTimeout(context.Background(), mitmConnectionLeafWait)
	defer cancel()
	if _, err := mitmLeaves.get(ctx, "a.timing.example"); err != nil {
		t.Fatal(err)
	}
	var stages []mitmSignStage
	var issue uint64
	for _, record := range ring.snapshot() {
		if issue == 0 {
			issue = record.Issue
		}
		if record.Issue != issue {
			t.Fatalf("records of issues %d and %d", issue, record.Issue)
		}
		stages = append(stages, record.Stage)
	}
	want := []mitmSignStage{
		mitmStageIssueStart, mitmStageKeyReady, mitmStageRequestQueued, mitmStageRequestBatched,
		mitmStageRequestWritten, mitmStageReplyReceived, mitmStageReplyChecked, mitmStageIssueDone,
		mitmStageAdopted, mitmStageWaiterServed,
	}
	// The batcher may take the request before sendMitmSign returns.
	queued := slices.Index(stages, mitmStageRequestQueued)
	batched := slices.Index(stages, mitmStageRequestBatched)
	if queued > batched {
		stages[queued], stages[batched] = stages[batched], stages[queued]
	}
	if !slices.Equal(stages, want) {
		t.Fatalf("stages %v, want %v", stages, want)
	}
}

// A signing request is written once nothing else is ready, not after the
// batch interval, while another priority message still waits for it.
func TestRunMessageBatcherSendsASigningRequestAtOnce(t *testing.T) {
	firstBatch := func(message Message) time.Duration {
		priority := make(chan Message, 1)
		sent := make(chan time.Time, 1)
		go runMessageBatcher(closedMessages(), priority, closedMessages(), func([]Message) {
			select {
			case sent <- time.Now():
			default:
			}
		})
		defer close(priority)
		start := time.Now()
		priority <- message
		select {
		case at := <-sent:
			return at.Sub(start)
		case <-time.After(2 * time.Second):
			t.Fatal("nothing was sent")
			return 0
		}
	}
	// The fastest of several runs, so a slow scheduler cannot fail it.
	fastest := func(message Message) time.Duration {
		best := time.Hour
		for i := 0; i < 8; i++ {
			best = min(best, firstBatch(message))
		}
		return best
	}
	if sign := fastest(Message{Type: MitmSignMessage, Data: &MitmSignRequest{}}); sign >= messageBatchInterval/2 {
		t.Fatalf("a signing request went after %v", sign)
	}
	if other := fastest(Message{Type: DelayMessage, Data: 1}); other < messageBatchInterval/2 {
		t.Fatalf("a delay message went after %v, before the interval", other)
	}
}
