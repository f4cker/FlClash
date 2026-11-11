//go:build with_gvisor && !no_tailscale

package core

import (
	"bytes"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"sync"
	"testing"

	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/constant"
)

func setupLegacyMigration(t *testing.T) []byte {
	t.Helper()
	resetTailscaleSetup(t)
	constant.SetHomeDir(t.TempDir())
	setTailscaleSetup(&TailscaleSetup{ProfileID: 1})
	live := tailscaleDirLive
	readCopy, writeCopy := readTailscaleCopy, writeTailscaleCopy
	t.Cleanup(func() {
		tailscaleDirLive = live
		readTailscaleCopy, writeTailscaleCopy = readCopy, writeCopy
	})
	tailscaleDirLive = func(string, *outbound.Tailscale) bool { return false }
	return writeTailscaleStateFile(t, tailscaleLegacyStateDir(), "https://login.tailscale.com")
}

func assertLegacyUnchanged(t *testing.T, original []byte) {
	t.Helper()
	buf, err := os.ReadFile(filepath.Join(tailscaleLegacyStateDir(), tailscaleStateFile))
	if err != nil || !bytes.Equal(buf, original) {
		t.Fatalf("the legacy state changed: %v", err)
	}
}

func assertNoMarker(t *testing.T) {
	t.Helper()
	if _, err := os.Stat(tailscaleLegacyMarkerPath()); !os.IsNotExist(err) {
		t.Fatalf("a marker is left: %v", err)
	}
}

func describeLegacy(t *testing.T, node *outbound.Tailscale) *TailscaleLegacyIdentity {
	t.Helper()
	legacy := describeTailscale(node, []*outbound.Tailscale{node}).Legacy
	if legacy == nil {
		t.Fatal("no legacy login reported")
	}
	return legacy
}

// What the panel sends: the token of the offer it showed.
func migrateConfirmed(node *outbound.Tailscale, token string) (*TailscaleMigrateResult, error) {
	return handleTailscaleMigrateLegacy(TailscaleMigrateParams{
		Name:       node.Name(),
		Generation: node.Generation(),
		OfferToken: token,
	})
}

func migrateShown(t *testing.T, node *outbound.Tailscale) (*TailscaleMigrateResult, error) {
	t.Helper()
	return migrateConfirmed(node, describeLegacy(t, node).OfferToken)
}

func TestTailscaleLegacyIdentityIsReportedWithoutTouchingIt(t *testing.T) {
	original := setupLegacyMigration(t)
	node := newMigrationTarget(t, outbound.TailscaleOption{Name: "home"})
	described := describeTailscale(node, []*outbound.Tailscale{node})
	legacy := described.Legacy
	if legacy == nil || legacy.LoginName != "alice@example.com" || legacy.DisplayName != "Alice" ||
		legacy.Tailnet != "example.ts.net" || legacy.ControlURL != tailscaleDefaultControlURL {
		t.Fatalf("legacy identity = %+v", legacy)
	}
	if strings.Contains(legacy.Fingerprint, "legacy") || legacy.MigratedTo != nil {
		t.Fatalf("fingerprint %q leaks the key, or the login reads as moved", legacy.Fingerprint)
	}
	if legacy.Eligibility != tailscaleLegacyEligible || legacy.OfferToken == "" {
		t.Fatalf("eligibility %q token %q", legacy.Eligibility, legacy.OfferToken)
	}
	if !slices.Contains(described.Warnings, tailscaleWarningLegacyState) {
		t.Fatal("the legacy warning is gone")
	}
	explicit := newMigrationTarget(t, outbound.TailscaleOption{Name: "pinned", StateDir: "pinned"})
	if describeTailscale(explicit, nil).Legacy != nil {
		t.Fatal("a node with its own state-dir was offered the legacy login")
	}
	assertLegacyUnchanged(t, original)
}

func TestTailscaleMigrateLegacyCopiesToOneNodeOnly(t *testing.T) {
	original := setupLegacyMigration(t)
	first := newMigrationTarget(t, outbound.TailscaleOption{Name: "home"})
	second := newMigrationTarget(t, outbound.TailscaleOption{Name: "office"})
	secondToken := describeLegacy(t, second).OfferToken
	pinTailscale(tailscaleRef{name: "home"}, func(pin *tailscalePin) { loggedOut := true; pin.loggedOut = &loggedOut })

	result, err := migrateShown(t, first)
	if err != nil {
		t.Fatal(err)
	}
	copied, err := os.ReadFile(filepath.Join(first.Option().StateDir, tailscaleStateFile))
	if err != nil || !bytes.Equal(copied, original) {
		t.Fatalf("the copy differs from the legacy state: %v", err)
	}
	assertLegacyUnchanged(t, original)
	if result.Outcome != tailscaleMigrateMigrated || !result.ArchiveIntact || result.Error != nil {
		t.Fatalf("result = %+v", result)
	}
	if !result.Node.HasIdentity || result.Node.LoggedOut || result.ReapplyRequired {
		t.Fatalf("read-back = %+v", result.Node)
	}
	if result.Migration.Name != "home" || result.Migration.ProfileID != 1 || result.Node.Legacy.MigratedTo == nil {
		t.Fatalf("marker = %+v", result.Migration)
	}
	if got := describeLegacy(t, second); got.Eligibility != tailscaleLegacyMigrated || got.OfferToken != "" {
		t.Fatalf("the other node still reads %+v", got)
	}

	_, err = migrateConfirmed(second, secondToken)
	if !errors.Is(err, errTailscaleLegacyMigrated) {
		t.Fatalf("a second migration = %v", err)
	}
	if tailscaleStateHasIdentity(second.Option().StateDir) {
		t.Fatal("the second node received the login")
	}
}

// Two panels confirming at once, each with a token it was really shown.
func TestTailscaleMigrateLegacyConcurrentRequestsHaveOneWinner(t *testing.T) {
	setupLegacyMigration(t)
	setTailscaleSetup(&TailscaleSetup{ProfileID: 1})
	names := []string{"a", "b", "c", "d", "e", "f"}
	nodes := make([]*outbound.Tailscale, len(names))
	tokens := make([]string, len(names))
	for i, name := range names {
		nodes[i] = newMigrationTarget(t, outbound.TailscaleOption{Name: name})
		tokens[i] = describeLegacy(t, nodes[i]).OfferToken
	}
	errs := make([]error, len(names))
	results := make([]*TailscaleMigrateResult, len(names))
	var wg sync.WaitGroup
	for i := range nodes {
		wg.Add(1)
		go func() {
			defer wg.Done()
			results[i], errs[i] = migrateConfirmed(nodes[i], tokens[i])
		}()
	}
	wg.Wait()
	winners := 0
	for i := range nodes {
		switch {
		case errs[i] == nil && results[i].Outcome == tailscaleMigrateMigrated:
			winners++
		case errors.Is(errs[i], errTailscaleLegacyMigrated):
		default:
			t.Fatalf("%s: %+v %v", names[i], results[i], errs[i])
		}
	}
	holders := 0
	for _, node := range nodes {
		if tailscaleStateHasIdentity(node.Option().StateDir) {
			holders++
		}
	}
	if winners != 1 || holders != 1 {
		t.Fatalf("%d winners, %d nodes hold the login", winners, holders)
	}
}

func TestTailscaleLegacyMarkerClaimIsExclusive(t *testing.T) {
	setupLegacyMigration(t)
	marker := TailscaleLegacyMigration{Fingerprint: "f", ProfileID: 1, Name: "a"}
	if err := claimTailscaleLegacyMarker(marker); err != nil {
		t.Fatal(err)
	}
	marker.Name = "b"
	if err := claimTailscaleLegacyMarker(marker); !errors.Is(err, os.ErrExist) {
		t.Fatalf("a second claim = %v", err)
	}
	buf, _ := os.ReadFile(tailscaleLegacyMarkerPath())
	var held TailscaleLegacyMigration
	if json.Unmarshal(buf, &held) != nil || held.Name != "a" {
		t.Fatalf("the first claim was replaced: %s", buf)
	}
}

func TestTailscaleMigrateLegacyHonoursTheHostMarker(t *testing.T) {
	setupLegacyMigration(t)
	node := newMigrationTarget(t, outbound.TailscaleOption{Name: "home"})
	token := describeLegacy(t, node).OfferToken
	fingerprint := readTailscaleLegacyIdentity().Fingerprint
	setTailscaleSetup(&TailscaleSetup{
		ProfileID:       1,
		LegacyMigration: &TailscaleLegacyMigration{Fingerprint: fingerprint, ProfileID: 2, Name: "elsewhere"},
	})
	_, err := migrateConfirmed(node, token)
	if !errors.Is(err, errTailscaleLegacyMigrated) {
		t.Fatalf("migration past the host's marker = %v", err)
	}
}

// A confirmation is bound to what it showed; nothing is written past one that
// no longer holds.
func TestTailscaleMigrateLegacyRefusesAChangedConfirmation(t *testing.T) {
	cases := []struct {
		name   string
		change func(t *testing.T, node *outbound.Tailscale)
		token  func(shown string) string
		want   error
	}{
		{name: "no token", token: func(string) string { return "" }, want: errTailscaleLegacyChanged},
		{name: "forged token", token: func(string) string { return "00" }, want: errTailscaleLegacyChanged},
		{
			name: "profile switched",
			change: func(*testing.T, *outbound.Tailscale) {
				setTailscaleSetup(&TailscaleSetup{ProfileID: 2})
			},
			want: errTailscaleLegacyChanged,
		},
		{
			name: "archive replaced",
			change: func(t *testing.T, _ *outbound.Tailscale) {
				rewriteLegacyArchive(t, func(state map[string][]byte) { state["_machinekey"] = []byte("privkey:other") })
			},
			want: errTailscaleLegacyChanged,
		},
		{
			name: "account changed",
			change: func(t *testing.T, _ *outbound.Tailscale) {
				rewriteLegacyArchive(t, func(state map[string][]byte) {
					state["_profiles"] = bytes.ReplaceAll(state["_profiles"], []byte("alice@"), []byte("bob@"))
				})
			},
			want: errTailscaleLegacyChanged,
		},
		{
			name: "target logged in meanwhile",
			change: func(t *testing.T, node *outbound.Tailscale) {
				writeTailscaleStateFile(t, node.Option().StateDir, "")
			},
			want: errTailscaleHasIdentity,
		},
		{
			name: "archive taken meanwhile",
			change: func(t *testing.T, _ *outbound.Tailscale) {
				if err := claimTailscaleLegacyMarker(TailscaleLegacyMigration{
					Fingerprint: readTailscaleLegacyIdentity().Fingerprint, ProfileID: 1, Name: "other",
				}); err != nil {
					t.Fatal(err)
				}
			},
			want: errTailscaleLegacyMigrated,
		},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			setupLegacyMigration(t)
			node := newMigrationTarget(t, outbound.TailscaleOption{Name: "home"})
			token := describeLegacy(t, node).OfferToken
			if c.change != nil {
				c.change(t, node)
			}
			if c.token != nil {
				token = c.token(token)
			}
			_, err := migrateConfirmed(node, token)
			if !errors.Is(err, c.want) {
				t.Fatalf("err = %v, want %v", err, c.want)
			}
			if c.want == errTailscaleLegacyChanged {
				assertNoMarker(t)
				if tailscaleStateHasIdentity(node.Option().StateDir) {
					t.Fatal("a refused migration wrote the target")
				}
			}
		})
	}
}

func rewriteLegacyArchive(t *testing.T, edit func(state map[string][]byte)) {
	t.Helper()
	state, err := readTailscaleState(tailscaleLegacyStateDir())
	if err != nil {
		t.Fatal(err)
	}
	edit(state)
	buf, _ := json.Marshal(state)
	if err := os.WriteFile(filepath.Join(tailscaleLegacyStateDir(), tailscaleStateFile), buf, 0o600); err != nil {
		t.Fatal(err)
	}
}

func TestTailscaleMigrateLegacyRefusals(t *testing.T) {
	cases := []struct {
		name        string
		option      outbound.TailscaleOption
		before      func(t *testing.T, node *outbound.Tailscale)
		eligibility string
		want        error
	}{
		{name: "other control server", option: outbound.TailscaleOption{ControlURL: "https://hs.example.com"},
			eligibility: tailscaleLegacyControlMismatch, want: errTailscaleLegacyControlMismatch},
		{
			name: "own identity",
			before: func(t *testing.T, node *outbound.Tailscale) {
				writeTailscaleStateFile(t, node.Option().StateDir, "")
			},
			eligibility: tailscaleLegacyHasIdentity,
			want:        errTailscaleHasIdentity,
		},
		{
			name: "legacy dir in use",
			before: func(*testing.T, *outbound.Tailscale) {
				tailscaleDirLive = func(dir string, _ *outbound.Tailscale) bool { return dir == tailscaleLegacyStateDir() }
			},
			eligibility: tailscaleLegacyInUse,
			want:        errTailscaleLegacyInUse,
		},
		{
			name: "archive unreadable",
			before: func(t *testing.T, _ *outbound.Tailscale) {
				if err := os.WriteFile(filepath.Join(tailscaleLegacyStateDir(), tailscaleStateFile), []byte("{"), 0o600); err != nil {
					t.Fatal(err)
				}
			},
			eligibility: tailscaleLegacyUnreadable,
			want:        errTailscaleLegacyUnreadable,
		},
		{
			name: "target unreadable",
			before: func(t *testing.T, node *outbound.Tailscale) {
				if err := os.MkdirAll(filepath.Join(node.Option().StateDir, tailscaleStateFile), 0o700); err != nil {
					t.Fatal(err)
				}
			},
			eligibility: tailscaleLegacyUnconfirmed,
			want:        errTailscaleLegacyUnconfirmed,
		},
		{
			name: "no legacy login",
			before: func(t *testing.T, _ *outbound.Tailscale) {
				if err := os.RemoveAll(tailscaleLegacyStateDir()); err != nil {
					t.Fatal(err)
				}
			},
			want: errTailscaleLegacyNotFound,
		},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			setupLegacyMigration(t)
			c.option.Name = "target"
			node := newMigrationTarget(t, c.option)
			token := describeLegacy(t, node).OfferToken
			if c.before != nil {
				c.before(t, node)
			}
			legacy := describeTailscale(node, nil).Legacy
			switch {
			case c.eligibility == "" && legacy != nil:
				t.Fatalf("a gone archive is still reported: %+v", legacy)
			case c.eligibility != "" && (legacy == nil || legacy.Eligibility != c.eligibility || legacy.OfferToken != ""):
				t.Fatalf("legacy = %+v, want %s", legacy, c.eligibility)
			}
			_, err := migrateConfirmed(node, token)
			if !errors.Is(err, c.want) {
				t.Fatalf("err = %v, want %v", err, c.want)
			}
			assertNoMarker(t)
		})
	}
	t.Run("explicit state-dir", func(t *testing.T) {
		setupLegacyMigration(t)
		node := newMigrationTarget(t, outbound.TailscaleOption{Name: "target", StateDir: "mine"})
		if _, err := migrateConfirmed(node, "any"); !errors.Is(err, errTailscaleNotIsolated) {
			t.Fatalf("err = %v", err)
		}
	})
}

func TestTailscaleMigrateLegacyFailedCopyLeavesTargetUntouched(t *testing.T) {
	original := setupLegacyMigration(t)
	node := newMigrationTarget(t, outbound.TailscaleOption{Name: "home"})
	dir := node.Option().StateDir
	if err := os.MkdirAll(dir, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.Chmod(dir, 0o500); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.Chmod(dir, 0o700) })
	result, err := migrateShown(t, node)
	if err != nil {
		t.Fatal(err)
	}
	if result.Outcome != tailscaleMigrateFailed || result.Stage != tailscaleMigrateStageCopy ||
		!result.TargetUntouched || !result.ArchiveIntact ||
		result.Error == nil || result.Error.Code != "tailscale_migrate_failed" {
		t.Fatalf("result = %+v", result)
	}
	if strings.Contains(result.Error.Message, constant.Path.HomeDir()) {
		t.Fatalf("the error names a path: %q", result.Error.Message)
	}
	assertNoMarker(t)
	assertLegacyUnchanged(t, original)
	if describeLegacy(t, node).Eligibility != tailscaleLegacyEligible {
		t.Fatal("a failed copy took the offer away")
	}

	if err := os.Chmod(dir, 0o700); err != nil {
		t.Fatal(err)
	}
	retried, err := migrateShown(t, node)
	if err != nil || retried.Outcome != tailscaleMigrateMigrated {
		t.Fatalf("retry = %+v %v", retried, err)
	}
}

func TestTailscaleMigrateLegacyUnconfirmedCopyKeepsTheClaim(t *testing.T) {
	setupLegacyMigration(t)
	node := newMigrationTarget(t, outbound.TailscaleOption{Name: "home"})
	other := newMigrationTarget(t, outbound.TailscaleOption{Name: "office"})
	otherToken := describeLegacy(t, other).OfferToken
	readTailscaleCopy = func(string) ([]byte, error) { return []byte("{}"), nil }
	result, err := migrateShown(t, node)
	if err != nil {
		t.Fatal(err)
	}
	if result.Outcome != tailscaleMigrateUnknown || result.Stage != tailscaleMigrateStageVerify ||
		result.TargetUntouched || !result.ArchiveIntact {
		t.Fatalf("result = %+v", result)
	}
	if _, err := os.Stat(tailscaleLegacyMarkerPath()); err != nil {
		t.Fatalf("the claim was dropped on an unknown outcome: %v", err)
	}
	if _, err := migrateConfirmed(other, otherToken); !errors.Is(err, errTailscaleLegacyMigrated) {
		t.Fatalf("another node took a login that may already be copied: %v", err)
	}
}

func TestTailscaleMigrateLegacyReportsAnArchiveThatChanged(t *testing.T) {
	setupLegacyMigration(t)
	node := newMigrationTarget(t, outbound.TailscaleOption{Name: "home"})
	readTailscaleCopy = func(path string) ([]byte, error) {
		if err := os.Remove(filepath.Join(tailscaleLegacyStateDir(), tailscaleStateFile)); err != nil {
			t.Fatal(err)
		}
		return os.ReadFile(path)
	}
	result, err := migrateShown(t, node)
	if err != nil {
		t.Fatal(err)
	}
	if result.Outcome != tailscaleMigrateMigrated || result.Stage != "" || result.ArchiveIntact {
		t.Fatalf("result = %+v", result)
	}
}

func TestTailscaleMigrateLegacyFailedClaimLeavesTargetUntouched(t *testing.T) {
	original := setupLegacyMigration(t)
	node := newMigrationTarget(t, outbound.TailscaleOption{Name: "home"})
	nodes := filepath.Dir(tailscaleLegacyMarkerPath())
	if err := os.MkdirAll(nodes, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.Chmod(nodes, 0o500); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.Chmod(nodes, 0o700) })
	result, err := migrateShown(t, node)
	if err != nil {
		t.Fatal(err)
	}
	if result.Outcome != tailscaleMigrateFailed || result.Stage != tailscaleMigrateStageClaim ||
		!result.TargetUntouched || !result.ArchiveIntact {
		t.Fatalf("result = %+v", result)
	}
	if _, err := os.Stat(filepath.Join(node.Option().StateDir, tailscaleStateFile)); !os.IsNotExist(err) {
		t.Fatalf("a failed claim wrote the target: %v", err)
	}
	assertNoMarker(t)
	assertLegacyUnchanged(t, original)
}

func TestTailscaleMigrateLegacyFailedWriteWithATargetLeftIsUnknown(t *testing.T) {
	setupLegacyMigration(t)
	node := newMigrationTarget(t, outbound.TailscaleOption{Name: "home"})
	writeTailscaleCopy = func(path string, buf []byte) error {
		if err := writeTailscaleFile(path, buf[:len(buf)/2]); err != nil {
			t.Fatal(err)
		}
		return errors.New("sync failed")
	}
	result, err := migrateShown(t, node)
	if err != nil {
		t.Fatal(err)
	}
	if result.Outcome != tailscaleMigrateUnknown || result.Stage != tailscaleMigrateStageCopy ||
		result.TargetUntouched || !result.ArchiveIntact {
		t.Fatalf("result = %+v", result)
	}
	if _, err := os.Stat(tailscaleLegacyMarkerPath()); err != nil {
		t.Fatalf("the claim was dropped with a target left: %v", err)
	}
}

func TestTailscaleMigrateLegacyFailedCopyReportsAnArchiveThatChanged(t *testing.T) {
	setupLegacyMigration(t)
	node := newMigrationTarget(t, outbound.TailscaleOption{Name: "home"})
	writeTailscaleCopy = func(string, []byte) error {
		rewriteLegacyArchive(t, func(state map[string][]byte) { state["extra"] = []byte("1") })
		return errors.New("disk full")
	}
	result, err := migrateShown(t, node)
	if err != nil {
		t.Fatal(err)
	}
	if result.Outcome != tailscaleMigrateFailed || result.Stage != tailscaleMigrateStageCopy ||
		!result.TargetUntouched || result.ArchiveIntact {
		t.Fatalf("result = %+v", result)
	}
}
