package core

import (
	"bytes"
	"crypto/sha256"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"
	"testing"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/component/flashguard"
	"github.com/metacubex/mihomo/constant"
	"go.yaml.in/yaml/v3"
)

func snapshotReport(snapshot *mountSnapshot, relay *mountRelay) MountSourceReport {
	inspection := snapshot.admit(relay)
	report := MountSourceReport{Status: inspection.Status, TailscaleExcluded: inspection.TailscaleExcluded, RelayExcluded: inspection.RelayExcluded, UnsupportedExcluded: inspection.UnsupportedExcluded}
	for _, name := range inspection.names {
		report.Nodes = append(report.Nodes, MountNode{Original: name, Name: name + " (Source)"})
	}
	return report
}

func TestMountSnapshotCacheContentIdentityAndBounds(t *testing.T) {
	var cache mountSnapshotCache
	var calls atomic.Int32
	decode := func(buf []byte) *mountSnapshot { calls.Add(1); return decodeMountSnapshot(buf) }
	data := []byte(mountSourceB)
	first := cache.get(data, decode)
	var workers sync.WaitGroup
	for i := 0; i < 12; i++ {
		workers.Add(1)
		go func() {
			defer workers.Done()
			if cache.get(data, decode) != first {
				t.Error("cache did not share immutable snapshot")
			}
		}()
	}
	workers.Wait()
	if calls.Load() != 1 {
		t.Fatalf("decode calls=%d", calls.Load())
	}
	changed := bytes.ReplaceAll(data, []byte("192.0.2.2"), []byte("192.0.2.3"))
	if cache.get(changed, decode) == first {
		t.Fatal("changed bytes reused snapshot")
	}
	for i := 0; i < mountSnapshotEntries+2; i++ {
		cache.get([]byte(fmt.Sprintf("proxies: []\n# %d", i)), decode)
	}
	if len(cache.entries) > mountSnapshotEntries || cache.bytes > mountSnapshotBytes {
		t.Fatalf("unbounded cache: entries=%d bytes=%d", len(cache.entries), cache.bytes)
	}
	if cache.get(data, decode) == first {
		t.Fatal("oldest snapshot not evicted")
	}
	huge := func([]byte) *mountSnapshot { return &mountSnapshot{payload: make([]byte, mountSnapshotBytes+1)} }
	var oversized mountSnapshotCache
	oversized.get(data, huge)
	if len(oversized.entries) != 0 {
		t.Fatal("oversized snapshot cached")
	}
}

func TestMountSnapshotAdmissionRechecksGuardAndRelay(t *testing.T) {
	flashguard.SetSuffixes(nil)
	t.Cleanup(func() { flashguard.SetSuffixes(nil) })
	snapshot := decodeMountSnapshot([]byte("proxies:\n - {name: x, type: socks5, server: host.private.invalid, port: 1080, dialer-proxy: relay}\n"))
	if got := snapshot.admit(nil); got.Count != 1 {
		t.Fatalf("initial: %+v", got)
	}
	relay := newMountRelay(map[string]bool{"relay": true}, nil)
	if got := snapshot.admit(relay); got.Count != 0 || got.RelayExcluded != 1 {
		t.Fatalf("relay: %+v", got)
	}
	if got := snapshot.admit(nil); got.Count != 1 {
		t.Fatal("admission mutated cached snapshot")
	}
	flashguard.SetSuffixes([]string{"private.invalid"})
	if got := snapshot.admit(nil); got.Count != 0 || got.RelayExcluded != 1 {
		t.Fatalf("fresh suffix: %+v", got)
	}
}

func TestMountSnapshotPayloadAndFreshFileIsolation(t *testing.T) {
	home := withMountHome(t)
	raw := mountTimingFixture(10, 5000)
	snapshot := decodeMountSnapshot(raw)
	var document map[string]any
	if err := yaml.Unmarshal(snapshot.payload, &document); err != nil {
		t.Fatal(err)
	}
	if len(document) != 1 || document["proxies"] == nil {
		t.Fatalf("provider input contains non-node sections: %v", document)
	}
	first, err := snapshot.providerPath()
	if err != nil {
		t.Fatal(err)
	}
	second, err := snapshot.providerPath()
	if err != nil {
		t.Fatal(err)
	}
	if first == second || filepath.Dir(first) != filepath.Join(home, "mount-nodes") {
		t.Fatal("preflight reused provider path")
	}
	if err := os.WriteFile(second, []byte("candidate"), 0600); err != nil {
		t.Fatal(err)
	}
	before, err := os.ReadFile(first)
	if err != nil || !bytes.Equal(before, snapshot.payload) {
		t.Fatal("candidate changed original provider input")
	}
}

func TestMountRefreshEndpointProofAndFallback(t *testing.T) {
	original := "proxies:\n - {name: x, type: socks5, server: 192.0.2.1, port: 1080, username: user, password: pass}\n"
	before := decodeMountSnapshot([]byte(original))
	ambiguous := decodeMountSnapshot([]byte(strings.ReplaceAll(original, "port: 1080", "port: 1080, Port: 1080")))
	if mountRefreshCompatible(ambiguous, ambiguous, snapshotReport(ambiguous, nil), nil) {
		t.Fatal("ambiguous endpoint spelling accepted for hot update")
	}
	source := snapshotReport(before, nil)
	for name, tc := range map[string]struct {
		text string
		hot  bool
	}{
		"same":                   {original, true},
		"endpoint":               {strings.ReplaceAll(strings.ReplaceAll(original, "192.0.2.1", "198.51.100.2"), "1080", "2080"), true},
		"unrelated source rules": {original + "rules: [MATCH,REJECT]\n", true},
		"name":                   {strings.ReplaceAll(original, "name: x", "name: y"), false},
		"credentials":            {strings.ReplaceAll(original, "password: pass", "password: changed"), false},
		"type":                   {strings.ReplaceAll(original, "type: socks5", "type: http"), false},
		"dialer":                 {strings.ReplaceAll(original, "password: pass", "password: pass, dialer-proxy: other"), false},
		"membership":             {original + " - {name: y, type: socks5, server: 192.0.2.2, port: 1}\n", false},
		"protected":              {strings.ReplaceAll(original, "192.0.2.1", "100.100.100.100"), false},
		"invalid":                {strings.ReplaceAll(original, "1080", "invalid"), false},
	} {
		t.Run(name, func(t *testing.T) {
			after := decodeMountSnapshot([]byte(tc.text))
			if got := mountRefreshCompatible(before, after, source, nil); got != tc.hot {
				t.Fatalf("hot=%v want %v inspection=%+v", got, tc.hot, after.inspection)
			}
		})
	}
}

func TestMountRefreshGenerationAndRuntimeReadback(t *testing.T) {
	report := &MountReport{Target: 4, Revision: "before"}
	params := MountRefreshParams{Target: 4, Generation: 9, Revision: "before", NextRevision: "after"}
	if !mountRefreshCurrent(params, report, 9, false) {
		t.Fatal("matching identity rejected")
	}
	for _, changed := range []MountRefreshParams{{Target: 5, Generation: 9, Revision: "before", NextRevision: "after"}, {Target: 4, Generation: 8, Revision: "before", NextRevision: "after"}, {Target: 4, Generation: 9, Revision: "other", NextRevision: "after"}} {
		if mountRefreshCurrent(changed, report, 9, false) {
			t.Fatal("stale identity accepted")
		}
	}
	if mountRefreshCurrent(params, report, 9, true) || mountRefreshCurrent(params, nil, 9, false) {
		t.Fatal("blocked or absent accepted")
	}
	snapshot := decodeMountSnapshot([]byte(mountSourceB))
	source := snapshotReport(snapshot, nil)
	proxies := []constant.Proxy{}
	for _, node := range snapshot.nodes {
		proxy, err := adapter.ParseProxy(map[string]any{"name": node.name + " (Source)", "type": "socks5", "server": "192.0.2.2", "port": 1080})
		if err != nil {
			t.Fatal(err)
		}
		defer proxy.Close()
		proxies = append(proxies, proxy)
	}
	if mountRefreshMatches(proxies, snapshot, source) {
		t.Fatal("names-only readback accepted wrong endpoint")
	}
}

func TestMountRefreshPublicationRetentionAndRollback(t *testing.T) {
	before, after := []byte("old"), []byte("next")
	for _, tc := range []struct {
		name                                  string
		failUpdate, badReadback, failRollback bool
		want                                  string
		calls                                 int
	}{
		{name: "success", want: "applied", calls: 1},
		{name: "parse or atomic write failure", failUpdate: true, want: "kept", calls: 1},
		{name: "readback failure rolls back", badReadback: true, want: "kept", calls: 2},
		{name: "rollback failure explicit", badReadback: true, failRollback: true, want: "unknown", calls: 2},
	} {
		t.Run(tc.name, func(t *testing.T) {
			disk, runtime := bytes.Clone(before), bytes.Clone(before)
			calls := 0
			outcome, err := refreshMountProvider(before, after, func(data []byte) error {
				calls++
				if calls == 1 && tc.failUpdate || calls == 2 && tc.failRollback {
					return errors.New("injected write failure")
				}
				disk, runtime = bytes.Clone(data), bytes.Clone(data)
				return nil
			}, func(next bool) bool {
				if next && tc.badReadback {
					return false
				}
				expected := before
				if next {
					expected = after
				}
				return bytes.Equal(runtime, expected)
			}, func() ([]byte, error) { return disk, nil })
			if outcome != tc.want || calls != tc.calls {
				t.Fatalf("outcome=%s calls=%d error=%v", outcome, calls, err)
			}
			if outcome == "kept" && (!bytes.Equal(disk, before) || !bytes.Equal(runtime, before)) {
				t.Fatal("kept did not preserve old file and runtime")
			}
			if outcome == "applied" && err != nil || outcome != "applied" && err == nil {
				t.Fatalf("wrong error: %v", err)
			}
		})
	}
}

func TestMountRefreshBatchFallbackBeforeMutation(t *testing.T) {
	mountStateMu.Lock()
	previous, generation, blocked, fallback := appliedMountReport, mountGeneration, runningConfigBlocked, runningConfigDefault
	report := &MountReport{Target: 42, Revision: "old"}
	appliedMountReport, mountGeneration, runningConfigBlocked, runningConfigDefault = report, 7, false, false
	mountStateMu.Unlock()
	t.Cleanup(func() {
		mountStateMu.Lock()
		appliedMountReport, mountGeneration, runningConfigBlocked, runningConfigDefault = previous, generation, blocked, fallback
		mountStateMu.Unlock()
	})
	params := MountRefreshParams{Target: 42, Generation: 7, Revision: "old", NextRevision: "next", Sources: []MountRefreshSource{{ID: 1}, {ID: 2}}}
	result := handleRefreshMountSources(params)
	if result.Outcome != "requiresApply" || result.State.Generation != 7 || result.State.Report != report {
		t.Fatalf("batch mutated state: %+v", result)
	}
	params.Generation = 6
	if got := handleRefreshMountSources(params); got.Outcome != "superseded" {
		t.Fatalf("stale batch fell through: %+v", got)
	}
}

func TestMountStagedInputLifecycleAndCanonicalRetention(t *testing.T) {
	home := withMountHome(t)
	raw := mountSourceB + "rules: [MATCH,REJECT]\n"
	source := writeMountFile(t, home, "canonical.yaml", raw)
	setup := &MountSetup{Sources: []MountSource{{ID: 1, Label: "Source", Path: source}}, stageInputs: true}
	report, err := applyMountOverrides(rootOf(t, "proxy-groups: [{name: G, type: select, include-all-providers: true}]\n"), setup)
	if err != nil {
		t.Fatal(err)
	}
	input, ok := report.inputs[1]
	if !ok || input.path == source {
		t.Fatal("applied provider uses canonical input")
	}
	bytesBefore, err := os.ReadFile(source)
	if err != nil || string(bytesBefore) != raw {
		t.Fatal("canonical profile changed")
	}
	report.discardInputs()
	if _, err := os.Stat(input.path); !os.IsNotExist(err) {
		t.Fatalf("unpublished input leaked: %v", err)
	}
	setup.stageInputs = false
	preview, err := applyMountOverrides(rootOf(t, "proxy-groups: [{name: G, type: select, include-all-providers: true}]\n"), setup)
	if err != nil || len(preview.inputs) != 0 {
		t.Fatalf("preview staged files: %+v %v", preview, err)
	}
	setup.stageInputs = true
	setup.Sources = append(setup.Sources, setup.Sources[0])
	if _, err := applyMountOverrides(rootOf(t, "proxy-groups: [{name: G, type: select, include-all-providers: true}]\n"), setup); err == nil {
		t.Fatal("duplicate source accepted")
	}
	entries, err := os.ReadDir(filepath.Join(home, "mount-nodes"))
	if err != nil || len(entries) != 0 {
		t.Fatalf("failed staging leaked files: %v %v", entries, err)
	}
}

func TestMountSnapshotSameSizeSameMtimeInvalidates(t *testing.T) {
	path := writeMountFile(t, t.TempDir(), "source", mountSourceB)
	info, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	before := readMountSnapshot(path, "")
	changed := strings.ReplaceAll(mountSourceB, "192.0.2.2", "192.0.2.3")
	if err := os.WriteFile(path, []byte(changed), 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.Chtimes(path, info.ModTime(), info.ModTime()); err != nil {
		t.Fatal(err)
	}
	after := readMountSnapshot(path, "")
	if before == after || bytes.Equal(before.payload, after.payload) {
		t.Fatal("same file metadata hid changed source bytes")
	}
}

func TestMountSnapshotPureProxyValidationAndExclusions(t *testing.T) {
	for _, definition := range []string{
		"{name: x, type: socks5, server: 192.0.2.1, port: 1080}",
		"{name: x, type: http, server: 192.0.2.1, port: 1080, tls: true}",
		"{name: x, type: socks5, server: 192.0.2.1, port: invalid}",
		"{name: x, type: ss, server: 192.0.2.1, port: 443, cipher: invalid, password: secret}",
		"{name: x, type: vmess, server: 192.0.2.1, port: 443, uuid: invalid}",
		"{name: x, type: unknown, server: 192.0.2.1, port: 443}",
	} {
		var mapping map[string]any
		if err := yaml.Unmarshal([]byte(definition), &mapping); err != nil {
			t.Fatal(err)
		}
		proxy, err := adapter.ParseProxy(mapping)
		if proxy != nil {
			defer proxy.Close()
		}
		snapshot := decodeMountSnapshot([]byte("proxies: [" + definition + "]\n"))
		if got := snapshot.admit(nil); (got.Status == mountSourceNodes) != (err == nil) {
			t.Fatalf("ParseProxy parity failed for %s: parser=%v snapshot=%+v", definition, err, got)
		}
	}
	source := `proxies:
 - {name: ts, type: tailscale}
 - {name: mesh, type: easytier}
 - {name: interface, type: socks5, server: 192.0.2.1, port: 1, Interface_Name: en0}
 - {name: mark, type: socks5, server: 192.0.2.1, port: 1, Routing_Mark: 7}
 - {name: tailnet, type: socks5, server: 100.64.0.1, port: 1}
 - {name: managed, type: socks5, server: 192.0.2.1, port: 1, Dialer_Proxy: 'Work (Flash 2)'}
 - {name: plain, type: socks5, server: 192.0.2.1, port: 1}
 - {name: plain, type: socks5, server: 192.0.2.2, port: 2}
`
	got := decodeMountSnapshot([]byte(source)).admit(newMountRelay(nil, managedBases([]string{"Work"})))
	if got.Status != mountSourceNodes || got.Count != 1 || got.TailscaleExcluded != 1 || got.UnsupportedExcluded != 3 || got.RelayExcluded != 2 || got.names[0] != "plain" {
		t.Fatalf("exclusions changed: %+v", got)
	}
}

// Exercise the handler's preparation/publication path without starting a native
// provider, watcher, or hub. Production supplies the same operations from FILE
// and SideUpdate; these callbacks inject canonical-installation races.
func TestMountRefreshHandlerSourceReplacementAndInitialReadFailure(t *testing.T) {
	original := []byte("proxies: [{name: x, type: socks5, server: 192.0.2.1, port: 1080}]\n")
	requested := bytes.ReplaceAll(original, []byte("192.0.2.1"), []byte("192.0.2.2"))
	newer := bytes.ReplaceAll(original, []byte("192.0.2.1"), []byte("192.0.2.3"))
	before := decodeMountSnapshot(original)
	digest := fmt.Sprintf("%x", sha256.Sum256(requested))
	for _, tc := range []struct {
		name                                                                          string
		duringDecode, duringNativeParse, failRollback, initialReadError, missingInput bool
		want                                                                          string
		updates                                                                       int
	}{
		{name: "current source", want: "applied", updates: 1},
		{name: "replacement after initial digest during decode", duringDecode: true, want: "superseded"},
		{name: "replacement during native parse rolls back", duringNativeParse: true, want: "superseded", updates: 2},
		{name: "replacement with unproven rollback", duringNativeParse: true, failRollback: true, want: "unknown", updates: 2},
		{name: "initial provider read error", initialReadError: true, want: "unknown"},
		{name: "missing initial provider file", missingInput: true, want: "unknown"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			raw, disk, runtime := bytes.Clone(requested), bytes.Clone(before.payload), bytes.Clone(before.payload)
			updates, sourceReads := 0, 0
			missing := filepath.Join(t.TempDir(), "missing-provider")
			outcome, candidate, err := refreshMountSource(mountProviderInput{snapshot: before}, snapshotReport(before, nil), digest, mountRefreshSourceIO{
				readSource: func() ([]byte, error) { sourceReads++; return bytes.Clone(raw), nil },
				readInput: func() ([]byte, error) {
					if tc.initialReadError {
						return nil, os.ErrPermission
					}
					if tc.missingInput {
						return os.ReadFile(missing)
					}
					return bytes.Clone(disk), nil
				},
				decode: func(data []byte) *mountSnapshot {
					if tc.duringDecode {
						raw = bytes.Clone(newer)
					}
					return decodeMountSnapshot(data)
				},
				update: func(data []byte) error {
					updates++
					if updates == 2 && tc.failRollback {
						return errors.New("injected rollback failure")
					}
					if updates == 1 && tc.duringNativeParse {
						raw = bytes.Clone(newer)
					}
					disk, runtime = bytes.Clone(data), bytes.Clone(data)
					return nil
				},
				matches: func(snapshot *mountSnapshot) bool { return bytes.Equal(runtime, snapshot.payload) },
			})
			if outcome != tc.want || updates != tc.updates {
				t.Fatalf("outcome=%s updates=%d error=%v", outcome, updates, err)
			}
			if outcome != "applied" && candidate != nil {
				t.Fatal("stale candidate available to advance report")
			}
			if tc.initialReadError || tc.missingInput {
				if err == nil || sourceReads != 0 {
					t.Fatalf("unproven input not rejected first: reads=%d err=%v", sourceReads, err)
				}
			}
			if outcome == "superseded" && (!bytes.Equal(disk, before.payload) || !bytes.Equal(runtime, before.payload)) {
				t.Fatal("superseded refresh left stale publication")
			}
			if outcome == "applied" && (candidate == nil || sourceReads != 3) {
				t.Fatalf("missing candidate or publication digest checks: reads=%d", sourceReads)
			}
		})
	}
}

func TestFirstInitSweepsDecryptedNodesALostCoreLeft(t *testing.T) {
	home := withMountHome(t)
	previousInit := isInit.Load()
	t.Cleanup(func() { isInit.Store(previousInit) })
	stale, err := decodeMountSnapshot(mountTimingFixture(2, 10)).providerPath()
	if err != nil {
		t.Fatal(err)
	}

	isInit.Store(true)
	if err := handleInit(&InitParams{HomeDir: home}); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(stale); err != nil {
		t.Fatalf("a repeated init removed a live input: %v", err)
	}

	isInit.Store(false)
	if err := handleInit(&InitParams{HomeDir: home}); err != nil {
		t.Fatal(err)
	}
	entries, err := os.ReadDir(filepath.Join(home, "mount-nodes"))
	if err != nil || len(entries) != 0 {
		t.Fatalf("stale decrypted nodes kept: %v %v", entries, err)
	}
}
