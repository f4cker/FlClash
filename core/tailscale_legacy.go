//go:build with_gvisor && !no_tailscale

package core

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"

	"github.com/metacubex/mihomo/adapter/outbound"
)

const (
	tailscaleMigrateMigrated = "migrated"
	tailscaleMigrateFailed   = "failed"
	tailscaleMigrateUnknown  = "unknown"

	tailscaleMigrateStageClaim  = "claim"
	tailscaleMigrateStageCopy   = "copy"
	tailscaleMigrateStageVerify = "verify"
)

var (
	errTailscaleLegacyUnreadable = &MethodError{
		Code:    "tailscale_legacy_unreadable",
		Message: "the shared login could not be read",
	}
	errTailscaleLegacyUnconfirmed = &MethodError{
		Code:    "tailscale_legacy_unconfirmed",
		Message: "whether the shared login can move to this node could not be read",
	}
	errTailscaleLegacyChanged = &MethodError{
		Code:    "tailscale_legacy_changed",
		Message: "the node or the shared login changed since it was confirmed",
	}
)

// Held for a whole migration, so two nodes asking at once cannot both pass the
// checks; the marker link backs it up across anything that bypasses it.
var tailscaleLegacyMu sync.Mutex

var (
	readTailscaleCopy  = os.ReadFile
	writeTailscaleCopy = writeTailscaleFile
)

type TailscaleMigrateResult struct {
	Generation uint64 `json:"generation"`
	// failed only with the target confirmed untouched; anything else unclear is unknown.
	Outcome         string                   `json:"outcome"`
	Stage           string                   `json:"stage,omitempty"`
	Migration       TailscaleLegacyMigration `json:"migration"`
	Node            TailscaleNode            `json:"node"`
	ReapplyRequired bool                     `json:"reapply-required"`
	TargetUntouched bool                     `json:"target-untouched"`
	ArchiveIntact   bool                     `json:"archive-intact"`
	Error           *MethodError             `json:"error,omitempty"`
}

func describeTailscaleLegacy(t *outbound.Tailscale) *TailscaleLegacyIdentity {
	identity, _, _ := readTailscaleLegacyArchive()
	if identity == nil {
		return nil
	}
	identity.Eligibility, _ = tailscaleLegacyEligibility(t, identity)
	if identity.Eligibility == tailscaleLegacyEligible {
		identity.OfferToken = tailscaleLegacyOfferToken(t, identity)
	}
	return identity
}

func tailscaleLegacyEligibility(t *outbound.Tailscale, identity *TailscaleLegacyIdentity) (string, error) {
	if identity.Eligibility != "" {
		return identity.Eligibility, nil
	}
	option := t.Option()
	managedID := tailscaleManagedIDOf(t)
	if !tailscaleIsManaged(t) && (t.ExplicitStateDir() || !strings.Contains(option.StateDir, tailscaleNodesDir)) {
		return tailscaleLegacyNotIsolated, nil
	}
	if identity.MigratedTo != nil && !identity.MigratedTo.names(tailscaleProfileID(), t.Name(), managedID, option.ControlURL) {
		return tailscaleLegacyMigrated, nil
	}
	if identity.ControlURL != normalizeControlURL(option.ControlURL) {
		return tailscaleLegacyControlMismatch, nil
	}
	has, err := tailscaleStateIdentity(option.StateDir)
	switch {
	case err != nil:
		return tailscaleLegacyUnconfirmed, err
	case has:
		return tailscaleLegacyHasIdentity, nil
	case tailscaleDirLive(tailscaleLegacyStateDir(), nil):
		return tailscaleLegacyInUse, nil
	case tailscaleDirLive(option.StateDir, t):
		return tailscaleLegacyDirInUse, nil
	}
	return tailscaleLegacyEligible, nil
}

// Covers everything the confirmation shows, so any change to it refuses.
func tailscaleLegacyOfferToken(t *outbound.Tailscale, identity *TailscaleLegacyIdentity) string {
	fields := []string{
		strconv.FormatInt(tailscaleProfileID(), 10),
		t.Name(),
		tailscaleManagedIDOf(t),
		strconv.FormatUint(t.Generation(), 10),
		normalizeControlURL(t.Option().ControlURL),
		identity.Fingerprint,
		identity.LoginName,
		identity.DisplayName,
		identity.Tailnet,
		identity.ControlURL,
	}
	sum := sha256.Sum256([]byte(strings.Join(fields, "\x00")))
	return hex.EncodeToString(sum[:16])
}

func tailscaleLegacyRefusal(eligibility string) *MethodError {
	switch eligibility {
	case tailscaleLegacyNotIsolated:
		return errTailscaleNotIsolated
	case tailscaleLegacyMigrated:
		return errTailscaleLegacyMigrated
	case tailscaleLegacyControlMismatch:
		return errTailscaleLegacyControlMismatch
	case tailscaleLegacyHasIdentity:
		return errTailscaleHasIdentity
	case tailscaleLegacyInUse:
		return errTailscaleLegacyInUse
	case tailscaleLegacyDirInUse:
		return errTailscaleStateDirBusy
	case tailscaleLegacyUnreadable:
		return errTailscaleLegacyUnreadable
	}
	return errTailscaleLegacyUnconfirmed
}

// Every refusal returns before anything is written; the copy is the bytes the
// checks read, so what was confirmed is what is copied.
func handleTailscaleMigrateLegacy(params TailscaleMigrateParams) (*TailscaleMigrateResult, error) {
	tailscaleLegacyMu.Lock()
	defer tailscaleLegacyMu.Unlock()
	t, err := boundTailscale(params.Name, params.ManagedID, params.Generation)
	if err != nil {
		return nil, err
	}
	defer lockTailscaleNode(t)()
	identity, archive, _ := readTailscaleLegacyArchive()
	if identity == nil {
		return nil, errTailscaleLegacyNotFound
	}
	if eligibility, _ := tailscaleLegacyEligibility(t, identity); eligibility != tailscaleLegacyEligible {
		return nil, tailscaleLegacyRefusal(eligibility)
	}
	if params.OfferToken == "" || params.OfferToken != tailscaleLegacyOfferToken(t, identity) {
		return nil, errTailscaleLegacyChanged
	}
	option := t.Option()
	result := &TailscaleMigrateResult{
		Generation: t.Generation(),
		Migration: TailscaleLegacyMigration{
			Fingerprint: identity.Fingerprint,
			ProfileID:   tailscaleProfileID(),
			Name:        t.Name(),
			ControlURL:  normalizeControlURL(option.ControlURL),
			ManagedID:   tailscaleManagedIDOf(t),
		},
		ArchiveIntact: true,
	}
	// A claim this node left behind on a failed copy is its own to resume.
	if identity.MigratedTo == nil {
		if err := claimTailscaleLegacyMarker(result.Migration); err != nil {
			if errors.Is(err, os.ErrExist) {
				return nil, errTailscaleLegacyMigrated
			}
			result.Outcome = tailscaleMigrateFailed
			result.Stage = tailscaleMigrateStageClaim
			result.TargetUntouched = true
			result.Error = tailscaleMigrateError(err)
			return settleTailscaleMigration(t, result, archive), nil
		}
	}
	if t.Started() {
		closeTailscaleConnections(t.Name())
		_ = t.Close()
		finishTailscaleReapply(t)
		result.ReapplyRequired = true
	}
	target := filepath.Join(option.StateDir, tailscaleStateFile)
	if err := writeTailscaleCopy(target, archive); err != nil {
		result.Stage = tailscaleMigrateStageCopy
		settleFailedTailscaleCopy(result, target)
		result.Error = tailscaleMigrateError(err)
	} else if copied, err := readTailscaleCopy(target); err != nil || !bytes.Equal(copied, archive) {
		result.Outcome = tailscaleMigrateUnknown
		result.Stage = tailscaleMigrateStageVerify
		result.Error = &MethodError{Code: "tailscale_migrate_unconfirmed", Message: "the copy did not read back as written"}
	} else {
		result.Outcome = tailscaleMigrateMigrated
		loggedOut := false
		pinTailscale(tailscaleRefOfNode(t), func(pin *tailscalePin) { pin.loggedOut = &loggedOut })
	}
	return settleTailscaleMigration(t, result, archive), nil
}

// The archive is never written; reading it again is what proves it intact.
func settleTailscaleMigration(t *outbound.Tailscale, result *TailscaleMigrateResult, archive []byte) *TailscaleMigrateResult {
	if now, err := os.ReadFile(filepath.Join(tailscaleLegacyStateDir(), tailscaleStateFile)); err != nil || !bytes.Equal(now, archive) {
		result.ArchiveIntact = false
	}
	result.Node = describeTailscale(t, currentTailscaleNodes())
	return result
}

// A failed write is a failure only once the target is seen without a state
// file; the claim is dropped then, so the archive stays free for a retry.
func settleFailedTailscaleCopy(result *TailscaleMigrateResult, target string) {
	if _, err := os.Lstat(target); !errors.Is(err, os.ErrNotExist) {
		result.Outcome = tailscaleMigrateUnknown
		return
	}
	result.Outcome = tailscaleMigrateFailed
	result.TargetUntouched = true
	_ = os.Remove(tailscaleLegacyMarkerPath())
}

func tailscaleMigrateError(err error) *MethodError {
	var pathErr *os.PathError
	if errors.As(err, &pathErr) {
		err = pathErr.Err
	}
	var linkErr *os.LinkError
	if errors.As(err, &linkErr) {
		err = linkErr.Err
	}
	return &MethodError{Code: "tailscale_migrate_failed", Message: err.Error()}
}
