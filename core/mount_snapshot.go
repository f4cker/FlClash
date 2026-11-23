package core

import (
	"bytes"
	"crypto/sha256"
	"errors"
	"fmt"
	"io/fs"
	"maps"
	"net"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"sync"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/provider"
	"github.com/metacubex/mihomo/common/convert"
	"github.com/metacubex/mihomo/component/age"
	"github.com/metacubex/mihomo/component/flashguard"
	"github.com/metacubex/mihomo/constant"
	"go.yaml.in/yaml/v3"
)

const (
	mountSnapshotVersion = "v1"
	mountSnapshotEntries = 32
	mountSnapshotBytes   = 16 << 20
)

type mountSnapshotNode struct {
	name    string
	host    string
	addr    string
	dialers []string
}

type mountSnapshot struct {
	inspection         MountSourceInspection
	nodes              []mountSnapshotNode
	payload            []byte
	shape              [sha256.Size]byte
	canonicalEndpoints bool
}

type mountSnapshotCache struct {
	sync.Mutex
	entries map[[sha256.Size]byte]*mountSnapshot
	order   [][sha256.Size]byte
	bytes   int
}

var mountSnapshots mountSnapshotCache

func readMountSnapshot(path, secretKey string) *mountSnapshot {
	buf, err := os.ReadFile(path)
	if err != nil {
		status := mountSourceReadError
		if errors.Is(err, fs.ErrNotExist) {
			status = mountSourceMissing
		}
		return &mountSnapshot{inspection: MountSourceInspection{Status: status}}
	}
	buf, err = age.DecryptBytes(buf, ageKeys(secretKey)...)
	if err != nil {
		return &mountSnapshot{inspection: MountSourceInspection{Status: mountSourceInvalid}}
	}
	return mountSnapshots.get(buf, decodeMountSnapshot)
}

func (cache *mountSnapshotCache) get(buf []byte, decode func([]byte) *mountSnapshot) *mountSnapshot {
	hash := sha256.New()
	_, _ = hash.Write([]byte(mountSnapshotVersion + "\x00"))
	_, _ = hash.Write(buf)
	key := [sha256.Size]byte(hash.Sum(nil))
	cache.Lock()
	defer cache.Unlock()
	if snapshot := cache.entries[key]; snapshot != nil {
		return snapshot
	}
	snapshot := decode(buf)
	cost := len(snapshot.payload) + len(snapshot.nodes)*128
	if cost > mountSnapshotBytes {
		return snapshot
	}
	for len(cache.order) > 0 && (len(cache.order) >= mountSnapshotEntries || cache.bytes+cost > mountSnapshotBytes) {
		oldest := cache.entries[cache.order[0]]
		cache.bytes -= len(oldest.payload) + len(oldest.nodes)*128
		delete(cache.entries, cache.order[0])
		cache.order = cache.order[1:]
	}
	if cache.entries == nil {
		cache.entries = make(map[[sha256.Size]byte]*mountSnapshot)
	}
	cache.entries[key] = snapshot
	cache.order = append(cache.order, key)
	cache.bytes += cost
	return snapshot
}

func decodeMountSnapshot(buf []byte) *mountSnapshot {
	snapshot := &mountSnapshot{inspection: MountSourceInspection{Status: mountSourceUnsupported}}
	if len(bytes.TrimSpace(buf)) == 0 {
		return snapshot
	}
	var schema provider.ProxySchema
	if err := yaml.Unmarshal(buf, &schema); err != nil {
		converted, err := convert.ConvertsV2Ray(buf)
		if err != nil || len(converted) == 0 {
			return snapshot
		}
		schema.Proxies = converted
	}
	if schema.Proxies == nil {
		return snapshot
	}
	snapshot.inspection = MountSourceInspection{Status: mountSourceNodes, Listed: len(schema.Proxies)}
	snapshot.canonicalEndpoints = true
	invalid := func() *mountSnapshot {
		return &mountSnapshot{inspection: MountSourceInspection{Status: mountSourceInvalid, Listed: len(schema.Proxies)}}
	}
	payload, err := yaml.Marshal(schema)
	if err != nil {
		return invalid()
	}
	seen := map[string]bool{}
	for _, mapping := range schema.Proxies {
		for key := range mapping {
			if strings.EqualFold(key, "server") && key != "server" || strings.EqualFold(key, "port") && key != "port" {
				snapshot.canonicalEndpoints = false
			}
		}
		kind, _ := mapping["type"].(string)
		if strings.EqualFold(kind, "tailscale") {
			snapshot.inspection.TailscaleExcluded++
			continue
		}
		name, ok := mapping["name"].(string)
		if !ok || seen[name] {
			continue
		}
		seen[name] = true
		if flashguard.UncheckedEndpoints(mapping) {
			snapshot.inspection.UnsupportedExcluded++
			continue
		}
		dialers := proxyOptionValues(mapping, "dialer-proxy")
		interfaces := proxyOptionValues(mapping, "interface-name")
		marks := proxyOptionValues(mapping, "routing-mark")
		parsed := maps.Clone(mapping)
		for _, key := range []string{"dialer-proxy", "interface-name", "routing-mark"} {
			canonicalMountOption(parsed, key)
		}
		proxy, err := adapter.ParseProxy(parsed)
		if err != nil {
			return invalid()
		}
		addr := proxy.Addr()
		host, _, _ := net.SplitHostPort(addr)
		info := proxy.ProxyInfo()
		_ = proxy.Close()
		if info.Interface != "" || info.RoutingMark != 0 || slices.ContainsFunc(interfaces, func(value string) bool { return value != "" }) || slices.ContainsFunc(marks, func(value string) bool { return value != "" && value != "0" }) {
			snapshot.inspection.UnsupportedExcluded++
			continue
		}
		snapshot.nodes = append(snapshot.nodes, mountSnapshotNode{name: name, host: host, addr: addr, dialers: dialers})
	}
	if len(snapshot.nodes) == 0 && snapshot.inspection.TailscaleExcluded+snapshot.inspection.UnsupportedExcluded < snapshot.inspection.Listed {
		return invalid()
	}
	snapshot.payload = payload
	shape := make([]map[string]any, len(schema.Proxies))
	for i, mapping := range schema.Proxies {
		shape[i] = maps.Clone(mapping)
		delete(shape[i], "server")
		delete(shape[i], "port")
	}
	encoded, err := yaml.Marshal(shape)
	if err != nil {
		return invalid()
	}
	snapshot.shape = sha256.Sum256(encoded)
	return snapshot
}

// Keep the provider's deterministic alias choice without losing any alias
// from the immutable payload or its admission metadata.
func canonicalMountOption(mapping map[string]any, key string) {
	var spellings []string
	for name := range mapping {
		if strings.EqualFold(strings.ReplaceAll(name, "_", "-"), key) {
			spellings = append(spellings, name)
		}
	}
	if len(spellings) == 0 {
		return
	}
	slices.Sort(spellings)
	chosen := spellings[0]
	if _, ok := mapping[key]; ok {
		chosen = key
	}
	value := mapping[chosen]
	for _, name := range spellings {
		delete(mapping, name)
	}
	switch value.(type) {
	case string, int, int64, uint64, float64:
		value = provider.WeakString(value)
	}
	mapping[key] = value
}

func (snapshot *mountSnapshot) admit(relay *mountRelay) MountSourceInspection {
	inspection := snapshot.inspection
	if inspection.Status != mountSourceNodes {
		return inspection
	}
	for _, node := range snapshot.nodes {
		if slices.ContainsFunc(node.dialers, relay.reaches) || node.host != "" && flashguard.ProtectedServer(node.host) {
			inspection.RelayExcluded++
			continue
		}
		inspection.names = append(inspection.names, node.name)
		if len(node.dialers) > 0 {
			if inspection.dialers == nil {
				inspection.dialers = map[string][]string{}
			}
			inspection.dialers[node.name] = slices.Clone(node.dialers)
		}
	}
	inspection.Count = len(inspection.names)
	if inspection.Count == 0 && inspection.TailscaleExcluded+inspection.RelayExcluded+inspection.UnsupportedExcluded < inspection.Listed {
		return MountSourceInspection{Status: mountSourceInvalid, Listed: inspection.Listed}
	}
	return inspection
}

// Each full-config candidate gets an unpublished input; SideUpdate alone
// changes the path a running native provider watches.
func (snapshot *mountSnapshot) providerPath() (string, error) {
	if snapshot.inspection.Status != mountSourceNodes {
		return "", fmt.Errorf("mount source is %s", snapshot.inspection.Status)
	}
	dir := mountNodesDir()
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return "", err
	}
	info, err := os.Lstat(dir)
	if err != nil || !info.IsDir() || info.Mode()&os.ModeSymlink != 0 {
		return "", fmt.Errorf("mount snapshot directory is not a directory: %s", dir)
	}
	reclaimDirOwnership(dir)
	file, err := os.CreateTemp(dir, "source-*.yaml")
	if err != nil {
		return "", err
	}
	_, writeErr := file.Write(snapshot.payload)
	if err := errors.Join(writeErr, file.Close()); err != nil {
		_ = os.Remove(file.Name())
		return "", err
	}
	scheduleReclaimOwnership()
	return file.Name(), nil
}

func mountNodesDir() string {
	return filepath.Join(constant.Path.HomeDir(), "mount-nodes")
}

// A setup without base or mounts reloads config.yaml, so its inputs stay.
func clearMountNodes() {
	dir := mountNodesDir()
	entries, err := os.ReadDir(dir)
	if err != nil {
		return
	}
	kept := runningMountInputs()
	for _, entry := range entries {
		path := filepath.Join(dir, entry.Name())
		if !kept[path] {
			_ = os.RemoveAll(path)
		}
	}
}

func runningMountInputs() map[string]bool {
	buf, err := os.ReadFile(runningConfigPath())
	if err == nil {
		buf, err = age.DecryptBytes(buf)
	}
	var running struct {
		Providers map[string]struct {
			Path string `yaml:"path"`
		} `yaml:"proxy-providers"`
	}
	if err != nil || yaml.Unmarshal(buf, &running) != nil {
		return nil
	}
	kept := map[string]bool{}
	for name, provider := range running.Providers {
		if strings.HasPrefix(name, mountProviderPrefix) && provider.Path != "" {
			kept[filepath.Clean(constant.Path.Resolve(provider.Path))] = true
		}
	}
	return kept
}
