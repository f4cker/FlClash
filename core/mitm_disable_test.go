package core

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/metacubex/mihomo/constant"
)

func TestMitmDisableEndsDecryptionAndKeepsTheCount(t *testing.T) {
	app := newFakeMitmApp(t)
	withMitmSigner(t, app, []string{"example.com"}, nil)
	on := mitmState.Load()
	on.ignored = 3
	if !on.decrypting() {
		t.Fatal("setup")
	}
	handleMitmDisable()
	off := mitmState.Load()
	if off.decrypting() || off.ignored != 3 {
		t.Fatalf("after disable: decrypting=%v ignored=%d", off.decrypting(), off.ignored)
	}
	if status := handleMitmStatus(); status.Enable {
		t.Fatalf("status %+v", status)
	}
	// Already off: nothing replaced, so nothing in flight is cut.
	handleMitmDisable()
	if mitmState.Load() != off {
		t.Fatal("an idle disable replaced the runtime")
	}
}

// A setup that turns MITM off and is then refused must not leave an earlier
// decryption running; a refused setup that keeps MITM on leaves it as it was.
func TestRejectedSetupWithoutMitmStillEndsDecryption(t *testing.T) {
	home := t.TempDir()
	previous := constant.Path.HomeDir()
	constant.SetHomeDir(home)
	t.Cleanup(func() { constant.SetHomeDir(previous) })
	withCurrentConfig(t, nil)
	keepTunnel(t)
	if err := os.WriteFile(filepath.Join(home, "config.yaml"), []byte("proxies: [unterminated\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	app := newFakeMitmApp(t)
	withMitmSigner(t, app, []string{"example.com"}, nil)
	on := mitmState.Load()

	kept := &MitmSetup{Enable: true, Hostname: []string{"example.com"}, DecryptTLS: true, CAFingerprint: app.fingerprint()}
	if err := applyConfig(&SetupParams{Mitm: kept}); err == nil {
		t.Fatal("the broken profile was accepted")
	}
	if mitmState.Load() != on {
		t.Fatal("a refused setup with MITM on changed the running decryption")
	}

	if err := applyConfig(&SetupParams{}); err == nil {
		t.Fatal("the broken profile was accepted")
	}
	if mitmState.Load().decrypting() {
		t.Fatal("a refused setup without MITM left decryption running")
	}
}
