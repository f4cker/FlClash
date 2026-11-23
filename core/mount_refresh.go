package core

import (
	"bytes"
	"crypto/sha256"
	"fmt"
	"maps"
	"os"
	"slices"

	"github.com/metacubex/mihomo/adapter/provider"
	"github.com/metacubex/mihomo/component/age"
	"github.com/metacubex/mihomo/constant"
	cp "github.com/metacubex/mihomo/constant/provider"
	"github.com/metacubex/mihomo/tunnel"
)

type mountProviderInput struct {
	source   MountSource
	path     string
	snapshot *mountSnapshot
	relay    *mountRelay
}

func (report *MountReport) discardInputs() {
	if report == nil {
		return
	}
	live := map[string]bool{}
	for _, pd := range tunnel.ProvidersSnapshot() {
		if native, ok := pd.(*provider.ProxySetProvider); ok {
			live[native.Vehicle().Path()] = true
		}
	}
	for _, input := range report.inputs {
		if !live[input.path] {
			_ = os.Remove(input.path)
		}
	}
}

type MountRefreshSource struct {
	ID     int64  `json:"id"`
	Digest string `json:"digest"`
}

type MountRefreshParams struct {
	Target       int64                `json:"target"`
	Generation   uint64               `json:"generation"`
	Revision     string               `json:"revision"`
	NextRevision string               `json:"next-revision"`
	Sources      []MountRefreshSource `json:"sources"`
}

type MountRefreshResult struct {
	Outcome string            `json:"outcome"`
	State   MountRuntimeState `json:"state"`
	Error   string            `json:"error,omitempty"`
}

func mountRefreshCurrent(params MountRefreshParams, report *MountReport, generation uint64, blocked bool) bool {
	return report != nil && !blocked && params.Target == report.Target && params.Generation == generation && params.Revision == report.Revision && params.NextRevision != ""
}

func mountRefreshCompatible(before, after *mountSnapshot, source MountSourceReport, relay *mountRelay) bool {
	if before == nil || after == nil || !before.canonicalEndpoints || !after.canonicalEndpoints || before.shape != after.shape || after.inspection.Status != mountSourceNodes {
		return false
	}
	inspection := after.admit(relay)
	if inspection.Status != source.Status || inspection.TailscaleExcluded != source.TailscaleExcluded || inspection.RelayExcluded != source.RelayExcluded || inspection.UnsupportedExcluded != source.UnsupportedExcluded || len(inspection.names) != len(source.Nodes) {
		return false
	}
	for i, node := range source.Nodes {
		if node.Original != inspection.names[i] {
			return false
		}
	}
	return true
}

func mountRefreshMatches(proxies []constant.Proxy, snapshot *mountSnapshot, source MountSourceReport) bool {
	if !sameNodeNames(proxies, source.Nodes) {
		return false
	}
	addresses := make(map[string]string, len(snapshot.nodes))
	for _, node := range snapshot.nodes {
		addresses[node.name] = node.addr
	}
	expected := make(map[string]string, len(source.Nodes))
	for _, node := range source.Nodes {
		addr, ok := addresses[node.Original]
		if !ok {
			return false
		}
		expected[node.Name] = addr
	}
	for _, proxy := range proxies {
		if proxy.Addr() != expected[proxy.Name()] {
			return false
		}
	}
	return true
}

// The native FILE fetcher owns serialization and atomic writes. Readback
// proves the public result; failed rollback never masquerades as retention.
func refreshMountProvider(before, after []byte, update func([]byte) error, matches func(bool) bool, read func() ([]byte, error)) (string, error) {
	confirmed := func(next bool) bool {
		data, err := read()
		expected := before
		if next {
			expected = after
		}
		return err == nil && bytes.Equal(data, expected) && matches(next)
	}
	err := update(after)
	if err == nil && confirmed(true) {
		return "applied", nil
	}
	if err == nil {
		err = fmt.Errorf("mount provider update readback did not match")
	}
	if confirmed(false) {
		return "kept", err
	}
	if rollback := update(before); rollback != nil {
		return "unknown", fmt.Errorf("%w; rollback failed: %v", err, rollback)
	}
	if !confirmed(false) {
		return "unknown", fmt.Errorf("%w; rollback readback did not match", err)
	}
	return "kept", err
}

// The handler supplies only existing native/file operations; this seam also lets
// pure tests inject source replacement during decode and native publication.
// Dart must serialize canonical installation with this IPC on its existing queue:
// digest checks detect races, but are not a cross-process filesystem lock.
type mountRefreshSourceIO struct {
	readSource func() ([]byte, error)
	readInput  func() ([]byte, error)
	decode     func([]byte) *mountSnapshot
	update     func([]byte) error
	matches    func(*mountSnapshot) bool
}

func refreshMountSource(input mountProviderInput, source MountSourceReport, digest string, io mountRefreshSourceIO) (string, *mountSnapshot, error) {
	old, err := io.readInput()
	if err != nil {
		return "unknown", nil, err
	}
	if !bytes.Equal(old, input.snapshot.payload) || !io.matches(input.snapshot) {
		return "superseded", nil, nil
	}
	data, err := io.readSource()
	if err != nil {
		return "kept", nil, err
	}
	if fmt.Sprintf("%x", sha256.Sum256(data)) != digest {
		return "superseded", nil, nil
	}
	data, err = age.DecryptBytes(data, ageKeys(string(input.source.AgeSecretKey))...)
	if err != nil {
		return "kept", nil, err
	}
	candidate := io.decode(data)
	if candidate.inspection.Status != mountSourceNodes {
		return "kept", nil, fmt.Errorf("mount source is %s", candidate.inspection.Status)
	}
	if !mountRefreshCompatible(input.snapshot, candidate, source, input.relay) {
		return "requiresApply", nil, nil
	}
	current := func() error {
		raw, err := io.readSource()
		if err != nil {
			return fmt.Errorf("mount source identity could not be verified: %w", err)
		}
		if fmt.Sprintf("%x", sha256.Sum256(raw)) != digest {
			return fmt.Errorf("mount source changed during refresh")
		}
		return nil
	}
	// Re-read after decoding/admission, immediately before native SideUpdate.
	if err := current(); err != nil {
		return "superseded", nil, err
	}
	var sourceChanged error
	outcome, err := refreshMountProvider(old, candidate.payload, io.update,
		func(next bool) bool {
			expected := input.snapshot
			if next {
				expected = candidate
			}
			if !io.matches(expected) {
				return false
			}
			if next {
				sourceChanged = current() // after native parsing, publication, and file/runtime readback
				return sourceChanged == nil
			}
			return true
		}, io.readInput)
	if sourceChanged != nil {
		if outcome == "kept" {
			return "superseded", nil, sourceChanged
		}
		return "unknown", nil, fmt.Errorf("%v; %w", sourceChanged, err)
	}
	if outcome != "applied" {
		return outcome, nil, err
	}
	return outcome, candidate, nil
}

func handleRefreshMountSources(params MountRefreshParams) MountRefreshResult {
	configMu.Lock()
	defer configMu.Unlock()
	result := func(outcome string, err error) MountRefreshResult {
		answer := MountRefreshResult{Outcome: outcome, State: handleMountState()}
		if err != nil {
			answer.Error = err.Error()
		}
		return answer
	}
	mountStateMu.Lock()
	report, generation, blocked := appliedMountReport, mountGeneration, runningConfigBlocked || runningConfigDefault
	mountStateMu.Unlock()
	if !mountRefreshCurrent(params, report, generation, blocked) {
		return result("superseded", nil)
	}
	if len(params.Sources) != 1 {
		return result("requiresApply", nil)
	}
	requested := params.Sources[0]
	input, ok := report.inputs[requested.ID]
	if !ok || input.snapshot == nil {
		return result("requiresApply", nil)
	}
	index := slices.IndexFunc(report.Sources, func(source MountSourceReport) bool { return source.ID == requested.ID })
	if index < 0 {
		return result("superseded", nil)
	}
	source := report.Sources[index]
	live := tunnel.ProvidersSnapshot()[source.Provider]
	native, ok := live.(*provider.ProxySetProvider)
	if !ok || currentConfig == nil || currentConfig.Providers[source.Provider] != live || native.VehicleType() != cp.File || native.Vehicle().Path() != input.path {
		return result("superseded", nil)
	}
	key := providerUpdateScope + source.Provider
	if !claimUpdate(key) {
		return result("superseded", nil)
	}
	defer releaseUpdate(key)
	refreshGuardSuffixes()
	outcome, candidate, err := refreshMountSource(input, source, requested.Digest, mountRefreshSourceIO{
		readSource: func() ([]byte, error) { return os.ReadFile(input.source.Path) },
		readInput:  func() ([]byte, error) { return os.ReadFile(input.path) },
		decode:     func(data []byte) *mountSnapshot { return mountSnapshots.get(data, decodeMountSnapshot) },
		update: func(buf []byte) error {
			if tunnel.ProvidersSnapshot()[source.Provider] != live {
				return fmt.Errorf("mount provider was replaced")
			}
			_, _, err := native.SideUpdate(buf)
			return err
		},
		matches: func(expected *mountSnapshot) bool {
			return tunnel.ProvidersSnapshot()[source.Provider] == live && mountRefreshMatches(native.Proxies(), expected, source)
		},
	})
	if outcome != "applied" {
		return result(outcome, err)
	}
	if tunnel.ProvidersSnapshot()[source.Provider] != live {
		return result("unknown", fmt.Errorf("mount provider was replaced during update"))
	}
	next := *report
	next.Revision = params.NextRevision
	next.inputs = maps.Clone(report.inputs)
	input.snapshot = candidate
	next.inputs[requested.ID] = input
	mountStateMu.Lock()
	appliedMountReport = &next
	mountGeneration++
	mountStateMu.Unlock()
	refreshRoute()
	scheduleReclaimOwnership()
	return result("applied", nil)
}
