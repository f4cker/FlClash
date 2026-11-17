package core

import (
	"encoding/json"
	"io"
	"net"
	"testing"

	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel/statistic"
)

func trackedPlainConnection(t *testing.T) (string, net.Conn) {
	t.Helper()
	local, remote := net.Pipe()
	go func() { _, _ = io.Copy(io.Discard, remote) }()
	tracker := statistic.NewTCPTracker(
		outbound.NewConn(local, outbound.NewDirectWithOption(outbound.DirectOption{Name: "DIRECT"})),
		statistic.DefaultManager,
		&constant.Metadata{Host: "unlisted.example", DstPort: 443},
		nil, 0, 0, true,
	)
	t.Cleanup(func() { _ = tracker.Close(); _ = remote.Close() })
	return tracker.ID(), tracker
}

func trackedOpen(id string) bool {
	return statistic.DefaultManager.Get(id) != nil
}

// A change of trust or hosts reaches the Core as mitm.update: the runtime is
// replaced, and connections outside decryption stay open.
func TestMitmUpdateLeavesOtherConnectionsOpen(t *testing.T) {
	app := newFakeMitmApp(t)
	withMitmSigner(t, app, []string{"example.com"}, nil)
	before := mitmState.Load()
	before.ignored.Store(2)
	id, conn := trackedPlainConnection(t)

	changes := []*MitmSetup{
		{Enable: true, Hostname: []string{"example.com", "other.example"}, DecryptTLS: true, CAFingerprint: app.fingerprint()},
		{Enable: true, Hostname: []string{"other.example"}, DecryptTLS: false, CAFingerprint: ""},
		{Enable: true, Hostname: []string{"other.example"}, DecryptTLS: true, CAFingerprint: app.fingerprint(), Limits: map[string]int64{"capture-entries": 10}},
		nil,
	}
	for index, setup := range changes {
		previous := mitmState.Load()
		raw, _ := json.Marshal(map[string]any{"setup": setup})
		var params MitmUpdateParams
		if err := json.Unmarshal(raw, &params); err != nil {
			t.Fatal(err)
		}
		if err := handleMitmUpdate(params); err != nil {
			t.Fatalf("change %d: %v", index, err)
		}
		now := mitmState.Load()
		if now == previous {
			t.Fatalf("change %d was not applied", index)
		}
		if now.ignored.Load() != 2 {
			t.Fatalf("change %d lost the profile's ignored count: %d", index, now.ignored.Load())
		}
		if !trackedOpen(id) {
			t.Fatalf("change %d closed a connection outside decryption", index)
		}
		if _, err := conn.Write([]byte("x")); err != nil {
			t.Fatalf("change %d: connection unusable: %v", index, err)
		}
	}
	if mitmState.Load().decrypting() {
		t.Fatal("a null setup left decryption on")
	}
}

// The same settings again replace nothing, so decrypted sessions go on.
func TestMitmUpdateWithSameSettingsKeepsTheRuntime(t *testing.T) {
	app := newFakeMitmApp(t)
	withMitmSigner(t, app, []string{"example.com"}, nil)
	on := mitmState.Load()
	same := on.setup
	same.Hostname = append([]string(nil), on.setup.Hostname...)
	if err := handleMitmUpdate(MitmUpdateParams{Setup: &same}); err != nil {
		t.Fatal(err)
	}
	if mitmState.Load() != on {
		t.Fatal("identical settings replaced the runtime")
	}
	if !mitmDecrypts("example.com") {
		t.Fatal("decryption lost")
	}
}

func TestMitmUpdateIsARegisteredMethod(t *testing.T) {
	if methodHandlers[mitmUpdateMethod] == nil {
		t.Fatal("mitm.update has no handler")
	}
}

func TestMitmUpdateArrivalOrderWinsWhenHandlersAreBlocked(t *testing.T) {
	original := mitmState.Load()
	t.Cleanup(func() { replaceMitmRuntime(original) })
	replaceMitmRuntime(nil)
	configMu.Lock()
	replies := make(chan []byte, 2)
	old := &MethodCall{Method: mitmUpdateMethod, Arguments: json.RawMessage(`{"setup":{"enable":true,"hostname":["old.example"],"decrypt-tls":true,"ca-fingerprint":"ca"}}`)}
	newer := &MethodCall{Method: mitmUpdateMethod, Arguments: json.RawMessage(`{"setup":null}`)}
	dispatchMethodCall(old, func(data []byte) { replies <- data })
	dispatchMethodCall(newer, func(data []byte) { replies <- data })
	configMu.Unlock()
	for range 2 {
		<-replies
	}
	if mitmState.Load().decrypting() {
		t.Fatal("older enable restored decryption")
	}
}

func TestMitmUpdateRestrictiveIntentWins(t *testing.T) {
	original := mitmState.Load()
	t.Cleanup(func() { replaceMitmRuntime(original) })
	for _, setup := range []string{
		`{"enable":true,"hostname":["new.example"],"decrypt-tls":true,"ca-fingerprint":"ca"}`,
		`{"enable":true,"hostname":["old.example"],"decrypt-tls":false}`,
	} {
		configMu.Lock()
		replies := make(chan []byte, 2)
		dispatchMethodCall(&MethodCall{Method: mitmUpdateMethod, Arguments: json.RawMessage(`{"setup":{"enable":true,"hostname":["old.example"],"decrypt-tls":true,"ca-fingerprint":"ca"}}`)}, func(b []byte) { replies <- b })
		dispatchMethodCall(&MethodCall{Method: mitmUpdateMethod, Arguments: json.RawMessage(`{"setup":` + setup + `}`)}, func(b []byte) { replies <- b })
		configMu.Unlock()
		for range 2 {
			<-replies
		}
		if mitmDecrypts("old.example") {
			t.Fatalf("older setup restored access: %s", setup)
		}
	}
}

func TestManagedSetupDoesNotRestoreMitm(t *testing.T) {
	original := mitmState.Load()
	t.Cleanup(func() { replaceMitmRuntime(original) })
	replaceMitmRuntime(nil)
	updateMitmIgnored([]byte("mitm:\n  hostname: [ignored.example]\n"))
	runtime := mitmState.Load()
	if runtime.decrypting() || runtime.ignored.Load() != 1 {
		t.Fatalf("unexpected runtime: %+v", runtime)
	}
	old := setupConfig
	wasInit := isInit.Load()
	t.Cleanup(func() { setupConfig = old; isInit.Store(wasInit) })
	isInit.Store(true)
	setupConfig = func(params *SetupParams) error {
		if !params.mitmManaged {
			t.Error("RPC setup can replace MITM settings")
		}
		return nil
	}
	_, err := handleManagedSetupCall(&MethodCall{Arguments: json.RawMessage(`{"mitm":{"enable":true}}`)})
	if err != nil {
		t.Fatal(err)
	}
}

func TestFailedNewIntentDoesNotAllowOlderEnable(t *testing.T) {
	original := mitmState.Load()
	t.Cleanup(func() { replaceMitmRuntime(original) })
	replaceMitmRuntime(nil)
	configMu.Lock()
	replies := make(chan []byte, 2)
	dispatchMethodCall(&MethodCall{ID: "old", Method: mitmUpdateMethod, Arguments: json.RawMessage(`{"setup":{"enable":true,"hostname":["old.example"],"decrypt-tls":true,"ca-fingerprint":"ca"}}`)}, func(b []byte) { replies <- b })
	dispatchMethodCall(&MethodCall{ID: "new", Method: mitmUpdateMethod, Arguments: json.RawMessage(`{"setup":"invalid"}`)}, func(b []byte) { replies <- b })
	configMu.Unlock()
	var failure bool
	for range 2 {
		var response MethodResponse
		if err := json.Unmarshal(<-replies, &response); err != nil {
			t.Fatal(err)
		}
		if response.ID == "new" && response.Error != nil {
			failure = true
		}
	}
	if !failure {
		t.Fatal("newer failure was not reported")
	}
	if mitmState.Load().decrypting() {
		t.Fatal("older enable applied after failed intent")
	}
}

func TestInFlightSetupCannotRestoreSupersededMitm(t *testing.T) {
	original := mitmState.Load()
	previousSetup := setupConfig
	wasInit := isInit.Load()
	t.Cleanup(func() { setupConfig = previousSetup; isInit.Store(wasInit); replaceMitmRuntime(original) })
	replaceMitmRuntime(nil)
	isInit.Store(true)
	entered, resume := make(chan struct{}), make(chan struct{})
	setupConfig = func(params *SetupParams) error {
		if !params.mitmManaged {
			t.Error("setup did not fence MITM")
		}
		close(entered)
		<-resume
		updateMitmIgnored([]byte("mitm:\n  hostname: [profile.example]\n"))
		return nil
	}
	replies := make(chan []byte, 2)
	dispatchMethodCall(&MethodCall{Method: configSetupMethod, Arguments: json.RawMessage(`{"mitm":{"enable":true,"hostname":["old.example"],"decrypt-tls":true,"ca-fingerprint":"ca"}}`)}, func(b []byte) { replies <- b })
	<-entered
	dispatchMethodCall(&MethodCall{Method: mitmUpdateMethod, Arguments: json.RawMessage(`{"setup":null}`)}, func(b []byte) { replies <- b })
	<-replies
	close(resume)
	<-replies
	if mitmState.Load().decrypting() || mitmState.Load().ignored.Load() != 1 {
		t.Fatal("setup restored a stale MITM snapshot")
	}
}

func TestSignerDisconnectSupersedesBlockedEnable(t *testing.T) {
	original := mitmState.Load()
	t.Cleanup(func() { replaceMitmRuntime(original) })
	replaceMitmRuntime(nil)
	configMu.Lock()
	replies := make(chan []byte, 1)
	dispatchMethodCall(&MethodCall{Method: mitmUpdateMethod, Arguments: json.RawMessage(`{"setup":{"enable":true,"hostname":["old.example"],"decrypt-tls":true,"ca-fingerprint":"ca"}}`)}, func(b []byte) { replies <- b })
	mitmSignerGone()
	configMu.Unlock()
	<-replies
	if mitmState.Load().decrypting() {
		t.Fatal("blocked enable revived a departed signer")
	}
}

func TestSetupMetadataPreservesSessionsAndPause(t *testing.T) {
	app := newFakeMitmApp(t)
	withMitmSigner(t, app, []string{"example.com"}, nil)
	runtime := mitmState.Load()
	client, peer := net.Pipe()
	remote, remotePeer := net.Pipe()
	defer peer.Close()
	defer remotePeer.Close()
	remove, ok := mitmActive.add(runtime, "example.com", client, remote)
	if !ok {
		t.Fatal("register failed")
	}
	defer remove()
	updateMitmIgnored([]byte("mitm:\n  hostname: [a.example, b.example]\n"))
	if mitmState.Load() != runtime || runtime.ignored.Load() != 2 {
		t.Fatal("metadata replaced runtime")
	}
	mitmActive.mu.Lock()
	active := len(mitmActive.active)
	mitmActive.mu.Unlock()
	if active != 1 {
		t.Fatal("metadata closed active session")
	}
	mitmActive.pauseGlobal(runtime, "appUnavailable")
	updateMitmIgnored([]byte("mitm:\n  hostname: [a.example]\n"))
	if mitmState.Load() != runtime || runtime.ignored.Load() != 1 || mitmPausedReason() != "appUnavailable" {
		t.Fatal("metadata cleared pause")
	}
}
