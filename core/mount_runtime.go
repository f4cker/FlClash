package core

import (
	"cmp"
	"crypto/md5"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"sync"

	"github.com/metacubex/mihomo/adapter/outboundgroup"
	"github.com/metacubex/mihomo/component/age"
	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
	"go.yaml.in/yaml/v3"
)

const (
	mountOutcomeKept    = "kept"
	mountOutcomeBlocked = "blocked"
)

var (
	mountStateMu    sync.Mutex
	mountGeneration uint64
	// What the running config was built with; nil when it holds no mounts.
	appliedMountReport *MountReport
	// The running config is the one that rejects every connection.
	runningConfigBlocked bool
	// The running config is mihomo's default, which sends everything direct.
	runningConfigDefault bool
	mountSelectionBasis  = map[int64]*MountReport{}
	mountSelectionMoved  map[string]string
	mountSelectionLost   []string
)

// A mounted selection follows its source and original name; once its source
// drops that node it is dropped, never moved to another node of that name.
func followMountSelections(selected map[string]string, report *MountReport) map[string]string {
	mountStateMu.Lock()
	defer mountStateMu.Unlock()
	mountSelectionMoved, mountSelectionLost = nil, nil
	if report == nil {
		return selected
	}
	before := mountSelectionBasis[report.Target]
	mountSelectionBasis[report.Target] = report
	if before == nil {
		return selected
	}
	type identity struct {
		source   int64
		original string
	}
	owners := map[string]identity{}
	for _, source := range before.Sources {
		for _, node := range source.Nodes {
			owners[node.Name] = identity{source.ID, node.Original}
		}
	}
	names := map[identity]string{}
	unread := map[int64]bool{}
	for _, source := range report.Sources {
		unread[source.ID] = source.Status != mountSourceNodes
		for _, node := range source.Nodes {
			names[identity{source.ID, node.Original}] = node.Name
		}
	}
	followed := make(map[string]string, len(selected))
	for group, name := range selected {
		owner, mounted := owners[name]
		next, listed := names[owner]
		switch {
		case !mounted || unread[owner.source]:
			followed[group] = name
		case !listed:
			mountSelectionLost = append(mountSelectionLost, group)
		default:
			followed[group] = next
			if next != name {
				if mountSelectionMoved == nil {
					mountSelectionMoved = map[string]string{}
				}
				mountSelectionMoved[group] = next
			}
		}
	}
	slices.Sort(mountSelectionLost)
	return followed
}

func setMountState(report *MountReport, blocked, fallback bool) {
	mountStateMu.Lock()
	defer mountStateMu.Unlock()
	previous := appliedMountReport
	appliedMountReport = report
	if previous != report {
		previous.discardInputs()
	}
	mountGeneration++
	runningConfigBlocked = blocked
	runningConfigDefault = fallback
}

func runningConfigKeepable() bool {
	mountStateMu.Lock()
	defer mountStateMu.Unlock()
	return !runningConfigBlocked && !runningConfigDefault
}

// Panel-added Tailscale nodes are named after the parse, so a mount node of
// the same name is the one that takes a suffix.
func mountSetupOf(params *SetupParams) *MountSetup {
	if params.Mounts == nil {
		return nil
	}
	setup := withManagedNames(params.Mounts, params.Tailscale)
	setup.stageInputs = true
	return setup
}

func withManagedNames(mounts *MountSetup, tailscale *TailscaleSetup) *MountSetup {
	setup := *mounts
	setup.reserved = nil
	if setup.managedRules = tailscaleManagedRules(tailscale); setup.managedRules {
		setup.managedProfile = tailscale.ProfileID
	}
	if tailscale != nil {
		for _, managed := range tailscale.Managed {
			if managed.ID != "" {
				setup.reserved = append(setup.reserved, cmp.Or(managed.Name, tailscaleManagedBaseName))
			}
		}
	}
	return &setup
}

func tailscaleManagedRules(setup *TailscaleSetup) bool {
	return tailscaleManagedBuilt && setup != nil && (setup.ManagedUnknown || slices.ContainsFunc(setup.Managed, func(account TailscaleManagedSetup) bool {
		return account.ID != "" && account.Attached
	}))
}

func managedTargetOf(params MountTargetParams) int64 {
	if !tailscaleManagedBuilt {
		return 0
	}
	return params.ManagedTarget
}

// The running profile's preflight sees its panel-added names as its apply.
func preflightMountSetup(mounts *MountSetup) *MountSetup {
	tailscaleMu.Lock()
	setup := tailscaleSetup
	tailscaleMu.Unlock()
	if setup == nil || mounts.Target == 0 || setup.ProfileID != mounts.Target {
		setup = nil
	}
	return withManagedNames(mounts, setup)
}

func checkMountedSetup(params *SetupParams) error {
	document, report, err := mountedDocument(params.Base, runningConfigPath(), mountSetupOf(params))
	defer report.discardInputs()
	if err != nil {
		return err
	}
	return parseDocument(document)
}

func mountRejected(err error, outcome string) error {
	return &MethodError{Code: "mount_rejected", Message: err.Error(), Details: map[string]string{"outcome": outcome}}
}

// Stands in for mihomo's default when a mounted profile fails: that default
// sends everything direct, which a failed mount must never do.
func blockingConfig() (*config.Config, error) {
	raw := config.DefaultRawConfig()
	raw.Rule = []string{"MATCH,REJECT"}
	raw.ProxyGroup = []map[string]any{{"name": globalProxyName, "type": "select", "proxies": []string{"REJECT"}}}
	return config.ParseRawConfig(raw)
}

// The document the setup would run, mounts included, without the Tailscale
// overrides, which only touch Tailscale nodes and must not be set by a check.
func mountedDocument(base *SetupBase, configPath string, mounts *MountSetup) (*yaml.Node, *MountReport, error) {
	if base != nil {
		return mergeProfileBase(base, false, mounts)
	}
	buf, err := os.ReadFile(configPath)
	if err != nil {
		return nil, nil, err
	}
	return mountedConfigDocument(buf, mounts)
}

func mountedConfigDocument(buf []byte, mounts *MountSetup) (*yaml.Node, *MountReport, error) {
	var document yaml.Node
	if err := yaml.Unmarshal(buf, &document); err != nil {
		return nil, nil, err
	}
	root, err := documentMapping(&document)
	if err != nil {
		return nil, nil, err
	}
	var report *MountReport
	if mounts != nil {
		if report, err = applyMountOverrides(root, mounts); err != nil {
			return nil, nil, err
		}
	}
	return &yaml.Node{Kind: yaml.DocumentNode, Content: []*yaml.Node{root}}, report, nil
}

// Built Tailscale or EasyTier nodes take the running node's resolver.
func parseDocument(document *yaml.Node) error {
	raw := config.DefaultRawConfig()
	if err := document.Decode(raw); err != nil {
		return err
	}
	for i, mapping := range raw.Proxy {
		raw.Proxy[i] = checkOnlyProxy(mapping)
	}
	for _, provider := range raw.ProxyProvider {
		if payload, ok := provider["payload"].([]any); ok {
			for i, item := range payload {
				if mapping, ok := item.(map[string]any); ok {
					payload[i] = checkOnlyProxy(mapping)
				}
			}
		}
	}
	cfg, err := config.ParseRawConfig(raw)
	if err != nil {
		return err
	}
	var mountErr error
	for name, pd := range cfg.Providers {
		if strings.HasPrefix(name, mountProviderPrefix) {
			if err := pd.Initial(); err != nil && mountErr == nil {
				mountErr = err
			}
		}
	}
	if mountErr == nil {
		mountErr = mountDialerViolation(cfg.Proxies, cfg.Providers)
	}
	for _, proxy := range cfg.Proxies {
		_ = proxy.Close()
	}
	for _, pd := range cfg.Providers {
		for _, proxy := range pd.Proxies() {
			_ = proxy.Close()
		}
		if closer, ok := pd.(interface{ Close() error }); ok {
			_ = closer.Close()
		}
	}
	return mountErr
}

func checkOnlyProxy(mapping map[string]any) map[string]any {
	switch kind, _ := mapping["type"].(string); strings.ToLower(kind) {
	case "tailscale", "easytier":
		probe := map[string]any{"name": mapping["name"], "type": "direct"}
		if dialer, ok := mapping["dialer-proxy"]; ok {
			probe["dialer-proxy"] = dialer
		}
		return probe
	}
	return mapping
}

type MountPreflightParams struct {
	Base   *SetupBase  `json:"base,omitempty"`
	Config string      `json:"config,omitempty"`
	Mounts *MountSetup `json:"mounts"`
}

type MountPreflight struct {
	Error     string       `json:"error,omitempty"`
	ErrorCode string       `json:"error-code,omitempty"`
	Report    *MountReport `json:"report,omitempty"`
}

// Without a base the host sends the profile it built, which is not the
// running config.yaml when the target is not the current profile.
func handleMountPreflight(params MountPreflightParams) (*MountPreflight, error) {
	defer scheduleLoadMemoryRelease()
	mounts := params.Mounts
	if mounts == nil {
		mounts = &MountSetup{}
	}
	configPath := ""
	if params.Base == nil {
		file, err := os.CreateTemp(constant.Path.HomeDir(), ".mount-preflight-*.yaml")
		if err != nil {
			return nil, err
		}
		configPath = file.Name()
		defer os.Remove(configPath)
		_, err = file.WriteString(params.Config)
		if closeErr := file.Close(); err == nil {
			err = closeErr
		}
		if err != nil {
			return nil, err
		}
	}
	configMu.Lock()
	defer configMu.Unlock()
	document, report, err := mountedDocument(params.Base, configPath, preflightMountSetup(mounts))
	if err == nil {
		err = parseDocument(document)
	}
	if err != nil {
		result := &MountPreflight{Error: err.Error(), ErrorCode: asMethodError(err).Code}
		return result, nil
	}
	return &MountPreflight{Report: report}, nil
}

type MountTargetParams struct {
	Base       *SetupBase `json:"base,omitempty"`
	Config     string     `json:"config,omitempty"`
	Projection bool       `json:"projection,omitempty"`
	// Set when the target's apply puts the managed Tailscale rules first.
	ManagedTarget int64 `json:"managed-target,omitempty"`
}

// Reads the groups only: a base that does not parse alone, as one whose
// groups collect nothing but mounts, still has groups to show.
func handleInspectMountTarget(params MountTargetParams) (*MountTarget, error) {
	defer scheduleLoadMemoryRelease()
	var root *yaml.Node
	if params.Projection {
		var err error
		root, err = mountTargetProjection(params)
		if err != nil {
			return nil, err
		}
	} else if params.Base != nil {
		document, _, err := mergeProfileBase(params.Base, false, nil)
		if err != nil {
			return nil, err
		}
		root = document.Content[0]
	} else {
		var document yaml.Node
		if err := yaml.Unmarshal([]byte(params.Config), &document); err != nil {
			return nil, err
		}
		mapping, err := documentMapping(&document)
		if err != nil {
			return nil, err
		}
		root = mapping
	}
	target, err := inspectMountTarget(root, managedTargetOf(params))
	if err != nil {
		return nil, err
	}
	return &target, nil
}

func mountTargetProjection(params MountTargetParams) (*yaml.Node, error) {
	buf := []byte(params.Config)
	if params.Base != nil {
		var err error
		buf, err = os.ReadFile(params.Base.Path)
		if err != nil {
			return nil, err
		}
		buf, err = age.DecryptBytes(buf)
		if err != nil {
			return nil, err
		}
	}
	var document yaml.Node
	if err := yaml.Unmarshal(buf, &document); err != nil {
		return nil, err
	}
	root, err := documentMapping(&document)
	if err != nil {
		return nil, err
	}
	projection := &yaml.Node{Kind: yaml.MappingNode, Tag: "!!map"}
	for _, key := range []string{"proxies", "proxy-groups", "proxy-providers"} {
		if value := mappingValue(root, key); value != nil {
			setMappingValue(projection, key, value)
		}
	}
	if params.Base != nil {
		providers := mappingValue(projection, "proxy-providers")
		if providers != nil {
			var definitions map[string]map[string]any
			if err := providers.Decode(&definitions); err != nil {
				return nil, err
			}
			for name, definition := range definitions {
				if definition == nil || definition["type"] == "inline" {
					continue
				}
				key := "proxy-providers/" + name
				if url, ok := definition["url"].(string); ok && url != "" {
					key = name + "@" + url
				}
				id := strings.TrimSuffix(filepath.Base(params.Base.Path), filepath.Ext(params.Base.Path))
				definition["path"] = filepath.Join(filepath.Dir(params.Base.Path), "providers", id, "proxies", fmt.Sprintf("%x", md5.Sum([]byte(key))))
			}
			var confined yaml.Node
			if err := confined.Encode(definitions); err != nil {
				return nil, err
			}
			setMappingValue(projection, "proxy-providers", &confined)
		}
	}
	return projection, nil
}

type MountRuntimeSource struct {
	ID       int64  `json:"id"`
	Provider string `json:"provider"`
	Present  bool   `json:"present"`
	Count    int    `json:"count"`
	Matches  bool   `json:"matches"`
}

// Empty is a group down to its empty-fallback; Mounted counts the members
// that came from a mount provider.
type MountRuntimeGroup struct {
	Name     string `json:"name"`
	Present  bool   `json:"present"`
	Members  int    `json:"members"`
	Mounted  int    `json:"mounted"`
	Empty    bool   `json:"empty"`
	Fallback string `json:"fallback,omitempty"`
}

// Moved and Lost: the selections the last apply followed or dropped.
// Refused: base providers and rule sets whose update was refused because it
// would reach Tailscale where the mount check saw nothing.
type MountRuntimeState struct {
	Generation uint64               `json:"generation"`
	Blocked    bool                 `json:"blocked"`
	Refused    []string             `json:"refused,omitempty"`
	Report     *MountReport         `json:"report,omitempty"`
	Sources    []MountRuntimeSource `json:"sources"`
	Groups     []MountRuntimeGroup  `json:"groups"`
	Moved      map[string]string    `json:"moved,omitempty"`
	Lost       []string             `json:"lost,omitempty"`
}

func handleMountState() MountRuntimeState {
	mountStateMu.Lock()
	report, blocked, generation := appliedMountReport, runningConfigBlocked, mountGeneration
	moved, lost := mountSelectionMoved, mountSelectionLost
	mountStateMu.Unlock()
	state := MountRuntimeState{Generation: generation, Blocked: blocked, Refused: mountGateState(), Report: report, Sources: []MountRuntimeSource{}, Groups: []MountRuntimeGroup{}, Moved: moved, Lost: lost}
	if report == nil {
		return state
	}
	providers := tunnel.ProvidersSnapshot()
	mountProviders := map[string]struct{}{}
	for _, source := range report.Sources {
		mountProviders[source.Provider] = struct{}{}
		runtime := MountRuntimeSource{ID: source.ID, Provider: source.Provider}
		if pd, ok := providers[source.Provider]; ok {
			proxies := pd.Proxies()
			runtime.Present, runtime.Count = true, len(proxies)
			runtime.Matches = sameNodeNames(proxies, source.Nodes)
		}
		state.Sources = append(state.Sources, runtime)
	}
	proxies := tunnel.Proxies()
	for _, group := range report.Groups {
		state.Groups = append(state.Groups, mountRuntimeGroup(proxies[group.Name], group.Name, mountProviders))
	}
	return state
}

func sameNodeNames(proxies []constant.Proxy, nodes []MountNode) bool {
	if len(proxies) != len(nodes) {
		return false
	}
	expected := make(map[string]struct{}, len(nodes))
	for _, node := range nodes {
		expected[node.Name] = struct{}{}
	}
	for _, proxy := range proxies {
		if _, ok := expected[proxy.Name()]; !ok {
			return false
		}
	}
	return true
}

func mountRuntimeGroup(proxy constant.Proxy, name string, mountProviders map[string]struct{}) MountRuntimeGroup {
	runtime := MountRuntimeGroup{Name: name}
	group, ok := adapterAs[outboundgroup.ProxyGroup](proxy)
	if !ok {
		return runtime
	}
	runtime.Present = true
	members := slices.DeleteFunc(slices.Clone(group.Proxies()), isTailscaleExitGroup)
	runtime.Members = len(members)
	for _, member := range members {
		if _, ok := mountProviders[member.ProxyInfo().ProviderName]; ok {
			runtime.Mounted++
		}
	}
	withFallback, ok := group.(interface{ EmptyFallback() constant.Proxy })
	if !ok {
		return runtime
	}
	fallback := withFallback.EmptyFallback()
	runtime.Fallback = fallback.Name()
	if len(members) != 1 || members[0] != fallback {
		return runtime
	}
	for _, pd := range group.Providers() {
		for _, member := range pd.Proxies() {
			if member == fallback {
				return runtime
			}
		}
	}
	runtime.Empty, runtime.Members = true, 0
	return runtime
}
