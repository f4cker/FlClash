package core

import (
	"bytes"
	"crypto/sha256"
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/provider"
	"github.com/metacubex/mihomo/component/resource"
	"github.com/metacubex/mihomo/constant"
	"go.yaml.in/yaml/v3"
)

func mountTimingFixture(nodes, rules int) []byte {
	var text strings.Builder
	text.WriteString("proxies:\n")
	for i := 0; i < nodes; i++ {
		fmt.Fprintf(&text, "  - {name: node-%d, type: socks5, server: 192.0.2.1, port: 1080}\n", i)
	}
	text.WriteString("proxy-groups:\n  - {name: Select, type: select, include-all-providers: true}\nrules:\n")
	for i := 0; i < rules; i++ {
		fmt.Fprintf(&text, "  - DOMAIN,synthetic-%d.invalid,DIRECT\n", i)
	}
	return []byte(text.String())
}

func TestMountNodeStageTimings(t *testing.T) {
	withMountHome(t)
	for _, size := range []struct{ nodes, rules int }{{10, 0}, {10, 5000}, {100, 0}, {100, 5000}} {
		t.Run(fmt.Sprintf("nodes=%d/rules=%d", size.nodes, size.rules), func(t *testing.T) {
			data := mountTimingFixture(size.nodes, size.rules)
			path := writeMountFile(t, t.TempDir(), "source.yaml", string(data))
			for iteration := 0; iteration < 3; iteration++ {
				start := time.Now()
				if _, err := os.ReadFile(path); err != nil {
					t.Fatal(err)
				}
				read := time.Since(start)
				start = time.Now()
				var document map[string]any
				if err := yaml.Unmarshal(data, &document); err != nil {
					t.Fatal(err)
				}
				decode := time.Since(start)
				start = time.Now()
				for _, entry := range document["proxies"].([]any) {
					proxy, err := adapter.ParseProxy(entry.(map[string]any))
					if err != nil {
						t.Fatal(err)
					}
					_ = proxy.Close()
				}
				nodes := time.Since(start)
				start = time.Now()
				inspection := inspectMountSource(path, "", nil)
				source := time.Since(start)
				if inspection.Count != size.nodes {
					t.Fatalf("inspection: %+v", inspection)
				}
				start = time.Now()
				if _, err := handleInspectMountTarget(MountTargetParams{Config: string(data)}); err != nil {
					t.Fatal(err)
				}
				target := time.Since(start)
				t.Logf("iteration=%d bytes=%d read_probe_calls=1 decode_probe_calls=1 node_probe_calls=%d source_calls=1 target_calls=1 read_us=%d decode_probe_us=%d node_probe_us=%d source_us=%d target_us=%d download=not_executed queue=not_executed apply=not_executed", iteration, len(data), size.nodes, read.Microseconds(), decode.Microseconds(), nodes.Microseconds(), source.Microseconds(), target.Microseconds())
			}
		})
	}
}

// Wrap only the actual native atomic FILE writer to count/time publication.
// No provider, health checker, Initial(), watcher, hub, or network is constructed.
type mountTimingFileVehicle struct {
	*resource.FileVehicle
	writes, written int
	writeTime       time.Duration
}

func (v *mountTimingFileVehicle) Write(data []byte) error {
	v.writes++
	v.written += len(data)
	start := time.Now()
	err := v.FileVehicle.Write(data)
	v.writeTime += time.Since(start)
	return err
}

func TestMountNativeOfflineComparison(t *testing.T) {
	for _, size := range []struct{ nodes, rules int }{{10, 0}, {10, 5000}, {100, 0}, {100, 5000}} {
		t.Run(fmt.Sprintf("nodes=%d/rules=%d", size.nodes, size.rules), func(t *testing.T) {
			beforeRaw := mountTimingFixture(size.nodes, size.rules)
			afterRaw := bytes.ReplaceAll(beforeRaw, []byte("192.0.2.1"), []byte("192.0.2.2"))
			before, after := decodeMountSnapshot(beforeRaw), decodeMountSnapshot(afterRaw)
			report := snapshotReport(before, nil)
			for i := range report.Nodes {
				report.Nodes[i].Name = report.Nodes[i].Original
			}
			var cache mountSnapshotCache // first helper call cold, next two reuse identical content
			for iteration := 0; iteration < 3; iteration++ {
				for _, mode := range []string{"before_raw_FILE_input", "after_proxy_FILE_input", "after_refresh_helper"} {
					t.Run(fmt.Sprintf("iteration=%d/%s", iteration, mode), func(t *testing.T) {
						initial, next := before.payload, after.payload
						if mode == "before_raw_FILE_input" {
							initial, next = beforeRaw, afterRaw
						}
						inputPath := writeMountFile(t, t.TempDir(), "provider.yaml", string(initial))
						sourcePath := writeMountFile(t, t.TempDir(), "canonical.yaml", string(afterRaw))
						vehicle := &mountTimingFileVehicle{FileVehicle: resource.NewFileVehicle(inputPath)}
						parses, nodes, parsedBytes := 0, 0, 0
						var parseTime time.Duration
						var published []constant.Proxy
						parser := func(data []byte) ([]constant.Proxy, error) {
							parses++
							parsedBytes += len(data)
							start := time.Now()
							defer func() { parseTime += time.Since(start) }()
							var schema provider.ProxySchema
							if err := yaml.Unmarshal(data, &schema); err != nil {
								return nil, err
							}
							var proxies []constant.Proxy
							for _, mapping := range schema.Proxies {
								nodes++
								proxy, err := adapter.ParseProxy(mapping)
								if err != nil {
									for _, p := range proxies {
										_ = p.Close()
									}
									return nil, err
								}
								proxies = append(proxies, proxy)
							}
							return proxies, nil
						}
						fetcher := resource.NewFetcher("offline-timing", 0, vehicle, nil, parser, func(proxies []constant.Proxy) {
							for _, p := range published {
								_ = p.Close()
							}
							published = proxies
						})
						defer func() {
							_ = fetcher.Close()
							for _, p := range published {
								_ = p.Close()
							}
						}()
						// Seed native hash/runtime without Initial(), which would start a watcher.
						if _, _, err := fetcher.Update(); err != nil {
							t.Fatal(err)
						}
						parses, nodes, parsedBytes = 0, 0, 0
						parseTime = 0
						sourceReads, inputReads, decodes, updates := 0, 0, 0, 0
						digest := fmt.Sprintf("%x", sha256.Sum256(afterRaw))
						start := time.Now()
						if mode == "after_refresh_helper" {
							outcome, candidate, err := refreshMountSource(mountProviderInput{snapshot: before}, report, digest, mountRefreshSourceIO{
								readSource: func() ([]byte, error) { sourceReads++; return os.ReadFile(sourcePath) },
								readInput:  func() ([]byte, error) { inputReads++; return os.ReadFile(inputPath) },
								decode: func(data []byte) *mountSnapshot {
									return cache.get(data, func(data []byte) *mountSnapshot { decodes++; return decodeMountSnapshot(data) })
								},
								update:  func(data []byte) error { updates++; _, _, err := fetcher.SideUpdate(data); return err },
								matches: func(snapshot *mountSnapshot) bool { return mountRefreshMatches(published, snapshot, report) },
							})
							if err != nil || outcome != "applied" || candidate == nil {
								t.Fatalf("outcome=%s err=%v", outcome, err)
							}
						} else {
							updates++
							if _, _, err := fetcher.SideUpdate(next); err != nil {
								t.Fatal(err)
							}
						}
						elapsed := time.Since(start)
						if parses != 1 || nodes != size.nodes || vehicle.writes != 1 || updates != 1 {
							t.Fatalf("unexpected native counts parse=%d nodes=%d write=%d updates=%d", parses, nodes, vehicle.writes, updates)
						}
						if mode == "after_refresh_helper" && (sourceReads != 3 || inputReads != 2 || decodes != map[bool]int{true: 1, false: 0}[iteration == 0]) {
							t.Fatalf("helper counts source=%d input=%d decode=%d", sourceReads, inputReads, decodes)
						}
						disk, err := os.ReadFile(inputPath)
						if err != nil || !bytes.Equal(disk, next) || !mountRefreshMatches(published, after, report) {
							t.Fatal("native FILE/runtime publication not verified")
						}
						canonical, err := os.ReadFile(sourcePath)
						if err != nil || !bytes.Equal(canonical, afterRaw) {
							t.Fatal("canonical source changed")
						}
						t.Logf("mode=%s iteration=%d nodes=%d rules=%d source_bytes=%d payload_bytes=%d elapsed_us=%d native_parse_us=%d atomic_write_us=%d native_update_calls=%d native_parse_calls=%d native_node_parse_calls=%d native_parse_bytes=%d file_write_calls=%d file_write_bytes=%d source_read_calls=%d provider_read_calls=%d snapshot_decode_calls=%d download=not_executed queue=not_executed full_apply=not_executed", mode, iteration, size.nodes, size.rules, len(afterRaw), len(after.payload), elapsed.Microseconds(), parseTime.Microseconds(), vehicle.writeTime.Microseconds(), updates, parses, nodes, parsedBytes, vehicle.writes, vehicle.written, sourceReads, inputReads, decodes)
					})
				}
			}
		})
	}
}
