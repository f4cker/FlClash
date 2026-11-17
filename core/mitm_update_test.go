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
	before.ignored = 2
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
		if now.ignored != 2 {
			t.Fatalf("change %d lost the profile's ignored count: %d", index, now.ignored)
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
