package core

import (
	"errors"
	"fmt"
	"slices"
	"strconv"
	"strings"

	"github.com/dlclark/regexp2"
	"github.com/metacubex/mihomo/adapter/provider"
	"go.yaml.in/yaml/v3"
)

const mountProviderPrefix = "flash-mount-"

// A file Flash's own updater keeps; mihomo never sees a subscription URL.
type MountSource struct {
	ID           int64  `json:"id"`
	Label        string `json:"label"`
	Path         string `json:"path"`
	AgeSecretKey string `json:"age-secret-key,omitempty"`
}

// Groups collect mounted nodes by their own declarations and filters.
// Revision binds a readback to the setup that made it.
type MountSetup struct {
	Target      int64         `json:"target"`
	Revision    string        `json:"revision"`
	Sources     []MountSource `json:"sources"`
	reserved    []string
	stageInputs bool
	// The managed Tailscale rules run ahead of the profile's own, with the
	// routes kept for managedProfile.
	managedRules   bool
	managedProfile int64
}

const (
	mountSourceNodes       = "nodes"
	mountSourceUnsupported = "unsupported"
	mountSourceInvalid     = "invalid"
	mountSourceMissing     = "missing"
	mountSourceReadError   = "read-error"
)

// Count is what the mount provider would hold: Listed less Tailscale nodes,
// nameless entries and repeated names; Unsupported, paths it cannot check.
type MountSourceInspection struct {
	Status              string `json:"status"`
	Count               int    `json:"count"`
	Listed              int    `json:"listed"`
	TailscaleExcluded   int    `json:"tailscale-excluded"`
	RelayExcluded       int    `json:"relay-excluded"`
	UnsupportedExcluded int    `json:"unsupported-excluded"`
	names               []string
	dialers             map[string][]string
}

func mountProviderName(id int64) string {
	return mountProviderPrefix + strconv.FormatInt(id, 10)
}

type MountInspectSourceParams struct {
	Path         string   `json:"path"`
	AgeSecretKey string   `json:"age-secret-key,omitempty"`
	Relay        []string `json:"relay,omitempty"`
	Managed      []string `json:"managed,omitempty"`
}

func handleInspectMountSource(params MountInspectSourceParams) MountSourceInspection {
	var relay *mountRelay
	if params.Relay != nil || params.Managed != nil {
		names := map[string]bool{}
		for _, name := range params.Relay {
			names[name] = true
		}
		relay = newMountRelay(names, managedBases(params.Managed))
	}
	refreshGuardSuffixes()
	return inspectMountSource(params.Path, params.AgeSecretKey, relay)
}

func ageKeys(secretKey string) []string {
	if secretKey == "" {
		return nil
	}
	return []string{secretKey}
}

func inspectMountSource(path, ageSecretKey string, relay *mountRelay) MountSourceInspection {
	return readMountSnapshot(path, ageSecretKey).admit(relay)
}

// Auto is a group that takes the mounts; excluded, one kept out of them;
// fixed, one that only lists its members and so takes no new node.
const (
	mountGroupAuto     = "auto"
	mountGroupExcluded = "excluded"
	mountGroupFixed    = "fixed"
)

// What the mount panel needs of one base group. Filters are only flagged:
// the host shows the hint, never the pattern.
type MountGroupInfo struct {
	Name          string `json:"name"`
	Type          string `json:"type"`
	Kind          string `json:"kind"`
	Excluded      string `json:"excluded,omitempty"`
	Reason        string `json:"reason,omitempty"`
	Collects      string `json:"collects,omitempty"`
	Hidden        bool   `json:"hidden,omitempty"`
	Filter        bool   `json:"filter,omitempty"`
	ExcludeFilter bool   `json:"exclude-filter,omitempty"`
	ExcludeType   bool   `json:"exclude-type,omitempty"`
	Uses          bool   `json:"uses,omitempty"`
	Probe         string `json:"probe"`
	EmptyFallback string `json:"empty-fallback,omitempty"`
}

type MountTarget struct {
	Groups []MountGroupInfo `json:"groups"`
	Relay  []string         `json:"relay"`
}

var mountableGroupTypes = []string{"select", "url-test", "fallback", "load-balance"}

// Group keys are read as mihomo's group decoder reads them: the exact key
// first, then any spelling of it ignoring case; numbers are taken as names.
func groupFlag(mapping map[string]any, key string) bool {
	switch value := providerOption(mapping, key).(type) {
	case bool:
		return value
	case int:
		return value != 0
	case int64:
		return value != 0
	case uint64:
		return value != 0
	case string:
		parsed, _ := strconv.ParseBool(value)
		return parsed
	}
	return false
}

func groupString(mapping map[string]any, key string) string {
	value := providerOption(mapping, key)
	if value == nil {
		return ""
	}
	if _, ok := value.([]any); ok {
		return ""
	}
	if _, ok := value.(map[string]any); ok {
		return ""
	}
	return provider.WeakString(value)
}

func groupList(mapping map[string]any, key string) []string {
	items, _ := providerOption(mapping, key).([]any)
	names := make([]string, 0, len(items))
	for _, item := range items {
		switch item.(type) {
		case nil, []any, map[string]any:
			continue
		}
		names = append(names, provider.WeakString(item))
	}
	return names
}

// A list that cannot be read is an error, never fewer groups or proxies.
func decodeMappings(node *yaml.Node, key string) ([]map[string]any, error) {
	node = resolveAlias(node)
	if node == nil || isNull(node) {
		return nil, nil
	}
	if node.Kind != yaml.SequenceNode {
		return nil, fmt.Errorf("%s is not a list", key)
	}
	mappings := make([]map[string]any, 0, len(node.Content))
	for i, item := range node.Content {
		var mapping map[string]any
		if err := resolveAlias(item).Decode(&mapping); err != nil || mapping == nil {
			return nil, fmt.Errorf("%s entry %d cannot be read", key, i+1)
		}
		mappings = append(mappings, mapping)
	}
	return mappings, nil
}

// managedProfile is the target when its apply puts the managed Tailscale
// rules first, 0 otherwise.
func inspectMountTarget(root *yaml.Node, managedProfile int64) (MountTarget, error) {
	base, err := readMountBase(root)
	if err != nil {
		return MountTarget{}, err
	}
	base.managedRules, base.managedProfile = managedProfile != 0, managedProfile
	target := MountTarget{Groups: []MountGroupInfo{}, Relay: []string{}}
	reach := base.dedicatedGroups()
	for _, mapping := range base.groups {
		target.Groups = append(target.Groups, mountGroupInfo(mapping, reach[groupString(mapping, "name")]))
	}
	for name := range newMountRelay(base.relayNames(base.holding()), nil).names {
		target.Relay = append(target.Relay, name)
	}
	slices.Sort(target.Relay)
	return target, nil
}

func mountGroupInfo(mapping map[string]any, reach string) MountGroupInfo {
	reachesTailscale := reach != ""
	kind := strings.ToLower(groupString(mapping, "type"))
	info := MountGroupInfo{
		Name:          groupString(mapping, "name"),
		Type:          kind,
		Hidden:        groupFlag(mapping, "hidden"),
		Filter:        groupString(mapping, "filter") != "",
		ExcludeFilter: groupString(mapping, "exclude-filter") != "",
		ExcludeType:   groupString(mapping, "exclude-type") != "",
		Uses:          len(groupList(mapping, "use")) > 0,
		EmptyFallback: groupString(mapping, "empty-fallback"),
		Probe:         "none",
	}
	if kind != "select" {
		info.Probe = "probes"
		if interval, ok := mapping["interval"]; ok && fmt.Sprint(interval) == "0" {
			info.Probe = "unknown"
		}
	}
	includeAll := groupFlag(mapping, "include-all")
	// Hidden groups take mounts as visible ones do: hiding is the Proxies
	// page's concern, never a group rule.
	switch {
	case !acceptsNewNodes(mapping):
		info.Kind = mountGroupFixed
	case !slices.Contains(mountableGroupTypes, kind):
		info.Kind, info.Excluded = mountGroupExcluded, "type"
	case info.Name == globalProxyName:
		info.Kind, info.Excluded = mountGroupExcluded, "builtin"
	case reachesTailscale:
		info.Kind, info.Excluded, info.Reason = mountGroupExcluded, "tailscale", reach
	default:
		info.Kind = mountGroupAuto
		if collectsProviders(mapping) {
			info.Collects = "providers"
			if includeAll || groupFlag(mapping, "include-all-proxies") {
				info.Collects = "all"
			}
		}
	}
	return info
}

// Mounted nodes join a group as new subscription nodes would: only one
// that collects proxies or providers, or uses one, takes any.
func acceptsNewNodes(mapping map[string]any) bool {
	return collectsProviders(mapping) || groupFlag(mapping, "include-all-proxies") || len(groupList(mapping, "use")) > 0
}

func collectsProviders(mapping map[string]any) bool {
	return groupFlag(mapping, "include-all") || groupFlag(mapping, "include-all-providers")
}

type MountNode struct {
	Name     string `json:"name"`
	Original string `json:"original"`
}

type MountSourceReport struct {
	ID                  int64       `json:"id"`
	Provider            string      `json:"provider"`
	Status              string      `json:"status"`
	TailscaleExcluded   int         `json:"tailscale-excluded"`
	RelayExcluded       int         `json:"relay-excluded"`
	UnsupportedExcluded int         `json:"unsupported-excluded"`
	Nodes               []MountNode `json:"nodes"`
	// A skipped source's names from before, still holding their place.
	held []MountNode
}

// Original is a group that also holds base proxies, left with mihomo's
// default empty behaviour as before the mount.
const (
	mountProtectionReject   = "reject"
	mountProtectionBase     = "base"
	mountProtectionOriginal = "original"
)

// Via is auto for a group that collects every provider on its own, use for
// one the mounts are added to.
type MountGroupReport struct {
	Name          string `json:"name"`
	Via           string `json:"via"`
	Protection    string `json:"protection"`
	EmptyFallback string `json:"empty-fallback"`
}

type MountReport struct {
	Target   int64               `json:"target"`
	Revision string              `json:"revision"`
	Sources  []MountSourceReport `json:"sources"`
	Groups   []MountGroupReport  `json:"groups"`
	Renamed  int                 `json:"renamed"`
	gate     *mountGate
	inputs   map[int64]mountProviderInput
}

var reservedProxyNames = []string{"DIRECT", "REJECT", "REJECT-DROP", "PASS", "COMPATIBLE", globalProxyName}

// Each source becomes a file provider over the cache Flash keeps; every
// group that accepts new nodes and the checks allow takes every one,
// through include-all or a use, and keeps its own members and filters. A group left with provider nodes only
// rejects when empty unless the base names its own empty-fallback. Names
// that clash with the base or an earlier source get "(label)" appended.
func applyMountOverrides(root *yaml.Node, setup *MountSetup) (*MountReport, error) {
	report := &MountReport{Target: setup.Target, Revision: setup.Revision, Sources: []MountSourceReport{}, Groups: []MountGroupReport{}}
	complete := false
	defer func() {
		if !complete {
			report.discardInputs()
		}
	}()
	if len(setup.Sources) == 0 {
		return report, nil
	}
	refreshGuardSuffixes()
	base, err := readMountBase(root)
	if err != nil {
		return nil, err
	}
	base.managedRules, base.managedProfile = setup.managedRules, setup.managedProfile
	taken := map[string]struct{}{}
	for _, name := range reservedProxyNames {
		taken[name] = struct{}{}
	}
	for name := range base.proxyTypes {
		taken[name] = struct{}{}
	}
	for _, mapping := range base.groups {
		taken[groupString(mapping, "name")] = struct{}{}
	}
	managed := managedBases(setup.reserved)
	reserved := func(name string) bool { return managedNameFamily(name, managed) }
	held := heldMountNodes(setup.Target)

	providers := resolveAlias(mappingValue(root, "proxy-providers"))
	if providers == nil || isNull(providers) {
		providers = &yaml.Node{Kind: yaml.MappingNode, Tag: "!!map"}
		setMappingValue(root, "proxy-providers", providers)
	} else if providers.Kind != yaml.MappingNode {
		return nil, errors.New("proxy-providers must be a mapping")
	}
	var baseProviders []string
	for name, provider := range base.providers {
		baseProviders = append(baseProviders, name)
		for _, node := range provider.names {
			taken[node] = struct{}{}
		}
	}
	slices.Sort(baseProviders)
	reach := base.dedicatedGroups()
	relay := newMountRelay(base.relayNames(base.holding()), managed)
	report.gate = &mountGate{}
	report.inputs = make(map[int64]mountProviderInput, len(setup.Sources))
	names := make([]string, 0, len(setup.Sources))
	dependencies := map[string][]string{}
	var mounted []string
	for _, source := range setup.Sources {
		name := mountProviderName(source.ID)
		if mappingValue(providers, name) != nil {
			return nil, fmt.Errorf("proxy provider %s already exists", name)
		}
		snapshot := readMountSnapshot(source.Path, source.AgeSecretKey)
		inspection := snapshot.admit(relay)
		// A source whose copy cannot be read mounts as an empty provider, so
		// one broken subscription does not hold back the rest and a group
		// left with nothing falls back as for an empty list. Its last names
		// stay taken, so no other source's node takes one of them.
		if inspection.Status != mountSourceNodes {
			for _, node := range held[source.ID] {
				taken[node.Name] = struct{}{}
			}
			report.Sources = append(report.Sources, MountSourceReport{ID: source.ID, Provider: name, Status: inspection.Status, Nodes: []MountNode{}, held: held[source.ID]})
			setMappingValue(providers, name, skippedMountProviderNode())
			names = append(names, name)
			continue
		}
		path := source.Path
		if setup.stageInputs {
			var err error
			path, err = snapshot.providerPath()
			if err != nil {
				return nil, err
			}
			report.inputs[source.ID] = mountProviderInput{source: source, path: path, snapshot: snapshot, relay: relay}
		}
		nodes, renames := mountNodeNames(source, inspection.names, taken, reserved)
		report.Renamed += len(renames)
		report.Sources = append(report.Sources, MountSourceReport{
			ID:                  source.ID,
			Provider:            name,
			Status:              inspection.Status,
			TailscaleExcluded:   inspection.TailscaleExcluded,
			RelayExcluded:       inspection.RelayExcluded,
			UnsupportedExcluded: inspection.UnsupportedExcluded,
			Nodes:               nodes,
		})
		own := map[string]string{}
		for _, node := range nodes {
			own[node.Original] = node.Name
			mounted = append(mounted, node.Name)
		}
		for original, dialers := range inspection.dialers {
			for _, dialer := range dialers {
				if renamed, ok := own[dialer]; ok {
					dialer = renamed
				}
				dependencies[own[original]] = append(dependencies[own[original]], dialer)
			}
		}
		definition, err := mountProviderNode(path, renames, relay)
		if err != nil {
			return nil, err
		}
		if len(renames) > 0 && len(inspection.dialers) > 0 {
			override := mappingValue(definition, "override")
			var expressions []string
			for _, node := range nodes {
				for _, dialer := range inspection.dialers[node.Original] {
					if renamed, ok := own[dialer]; ok && renamed != dialer {
						expressions = append(expressions, fmt.Sprintf("(select(.name == %s) | .dialer-proxy) = %s", strconv.Quote(node.Name), strconv.Quote(renamed)))
					}
				}
			}
			if len(expressions) > 0 {
				var expressionsNode yaml.Node
				if err := expressionsNode.Encode(expressions); err != nil {
					return nil, err
				}
				setMappingValue(override, "override-expr", &expressionsNode)
			}
		}
		setMappingValue(providers, name, definition)
		names = append(names, name)
	}
	groupsNode := resolveAlias(mappingValue(root, "proxy-groups"))
	groups, err := applyMountGroups(groupsNode, base.groups, reach, names, baseProviders)
	if err != nil {
		return nil, err
	}
	if err := checkMountedGroups(groupsNode, reach, groups, names); err != nil {
		return nil, err
	}
	report.Groups = groups
	if err := checkMountBaseDependencies(base, mounted, dependencies); err != nil {
		return nil, report.explainSkip(err)
	}
	complete = true
	return report, nil
}

func overriddenName(name string, override map[string]any) string {
	rules, _ := override["proxy-name"].([]any)
	for _, item := range rules {
		rule, _ := item.(map[string]any)
		pattern, err := regexp2.Compile(groupString(rule, "pattern"), regexp2.None)
		if err != nil {
			continue
		}
		if replaced, err := pattern.Replace(name, groupString(rule, "target"), 0, -1); err == nil {
			name = replaced
		}
	}
	return groupString(override, "additional-prefix") + name + groupString(override, "additional-suffix")
}

func mountNodeNames(source MountSource, originals []string, taken map[string]struct{}, reserved func(string) bool) ([]MountNode, []MountNode) {
	own := make(map[string]struct{}, len(originals))
	for _, name := range originals {
		own[name] = struct{}{}
	}
	label := strings.TrimSpace(source.Label)
	if label == "" {
		label = "#" + strconv.FormatInt(source.ID, 10)
	}
	used := func(name string) bool {
		_, inTaken := taken[name]
		_, inOwn := own[name]
		return inTaken || inOwn || reserved(name)
	}
	nodes := make([]MountNode, 0, len(originals))
	var renames []MountNode
	for _, original := range originals {
		name := original
		if _, clash := taken[original]; clash || reserved(original) {
			name = fmt.Sprintf("%s (%s)", original, label)
			for attempt := 1; used(name); attempt++ {
				suffix := "#" + strconv.FormatInt(source.ID, 10)
				if attempt > 1 {
					suffix += "-" + strconv.Itoa(attempt)
				}
				name = fmt.Sprintf("%s (%s %s)", original, label, suffix)
			}
			renames = append(renames, MountNode{Name: name, Original: original})
			own[name] = struct{}{}
		}
		nodes = append(nodes, MountNode{Name: name, Original: original})
	}
	for _, node := range nodes {
		taken[node.Name] = struct{}{}
	}
	return nodes, renames
}

func skippedMountProviderNode() *yaml.Node {
	return &yaml.Node{Kind: yaml.MappingNode, Tag: "!!map", Content: []*yaml.Node{
		{Kind: yaml.ScalarNode, Tag: "!!str", Value: "type"},
		{Kind: yaml.ScalarNode, Tag: "!!str", Value: "inline"},
		{Kind: yaml.ScalarNode, Tag: "!!str", Value: "flash-allow-empty"},
		{Kind: yaml.ScalarNode, Tag: "!!bool", Value: "true"},
		{Kind: yaml.ScalarNode, Tag: "!!str", Value: "payload"},
		{Kind: yaml.SequenceNode, Tag: "!!seq", Style: yaml.FlowStyle},
	}}
}

// The provider drops what the inspection counts out, by the same reading.
func mountProviderNode(path string, renames []MountNode, relay *mountRelay) (*yaml.Node, error) {
	definition := map[string]any{
		"type":                    "file",
		"path":                    path,
		"flash-allow-empty":       true,
		"flash-exclude-interface": true,
		"exclude-type":            "tailscale",
	}
	if !relay.empty() {
		definition["flash-exclude-dialer"] = relay.pattern()
	}
	override := map[string]any{}
	if len(renames) > 0 {
		rules := make([]map[string]any, 0, len(renames))
		for _, rename := range renames {
			rules = append(rules, map[string]any{
				"pattern": "^" + regexp2.Escape(rename.Original) + "$",
				"target":  strings.ReplaceAll(rename.Name, "$", "$$"),
			})
		}
		override["proxy-name"] = rules
	}
	if len(override) > 0 {
		definition["override"] = override
	}
	var node yaml.Node
	if err := node.Encode(definition); err != nil {
		return nil, err
	}
	return &node, nil
}

func applyMountGroups(groupsNode *yaml.Node, mappings []map[string]any, reach map[string]string, providers []string, baseProviders []string) ([]MountGroupReport, error) {
	reports := []MountGroupReport{}
	for i, mapping := range mappings {
		node := resolveAlias(groupsNode.Content[i])
		info := mountGroupInfo(mapping, reach[groupString(mapping, "name")])
		if info.Kind != mountGroupAuto {
			// A kept-out group that collects every provider would collect
			// the mounts too: it is built as without them.
			if collectsProviders(mapping) {
				pinned, err := pinBaseProviders(node, mapping, baseProviders)
				if err != nil {
					return nil, err
				}
				groupsNode.Content[i] = pinned
			}
			continue
		}
		via := "auto"
		copied := *node
		copied.Content = append([]*yaml.Node(nil), node.Content...)
		if !collectsProviders(mapping) {
			via = "use"
			uses := append(groupList(mapping, "use"), providers...)
			var useNode yaml.Node
			if err := useNode.Encode(uniqueStrings(uses)); err != nil {
				return nil, err
			}
			setMappingValue(&copied, "use", &useNode)
		}
		report := MountGroupReport{Name: info.Name, Via: via, Protection: mountProtectionBase, EmptyFallback: info.EmptyFallback}
		holdsBase := len(groupList(mapping, "proxies")) > 0 || groupFlag(mapping, "include-all") || groupFlag(mapping, "include-all-proxies")
		if info.EmptyFallback == "" && holdsBase {
			report.Protection = mountProtectionOriginal
		} else if info.EmptyFallback == "" {
			report.Protection, report.EmptyFallback = mountProtectionReject, "REJECT"
			setMappingValue(&copied, "empty-fallback", &yaml.Node{Kind: yaml.ScalarNode, Tag: "!!str", Value: "REJECT"})
		}
		groupsNode.Content[i] = &copied
		reports = append(reports, report)
	}
	return reports, nil
}

func errMountIsolation(name string) error {
	return &MethodError{
		Code:    "mount_isolation_check",
		Message: fmt.Sprintf("group %q would take mounted nodes the isolation checks keep out", name),
		Details: name,
	}
}

// Check direct provider admission, not the base configuration's routing graph.
func checkMountedGroups(groupsNode *yaml.Node, reach map[string]string, taking []MountGroupReport, mountProviders []string) error {
	mounted, err := decodeMappings(groupsNode, "proxy-groups")
	if err != nil {
		return err
	}
	takes := map[string]bool{}
	for _, group := range taking {
		takes[group.Name] = true
	}
	for _, mapping := range mounted {
		name := groupString(mapping, "name")
		holdsMount := collectsProviders(mapping) || slices.ContainsFunc(groupList(mapping, "use"), func(use string) bool {
			return slices.Contains(mountProviders, use)
		})
		if holdsMount != takes[name] || holdsMount && reach[name] != "" {
			return errMountIsolation(name)
		}
	}
	return nil
}

// A group reaching Tailscale is built as without the mounts: include-all
// becomes include-all-proxies and only the base's providers are used.
func pinBaseProviders(node *yaml.Node, mapping map[string]any, baseProviders []string) (*yaml.Node, error) {
	pinned := *node
	pinned.Content = append([]*yaml.Node(nil), node.Content...)
	off := func() *yaml.Node { return &yaml.Node{Kind: yaml.ScalarNode, Tag: "!!bool", Value: "false"} }
	if groupFlag(mapping, "include-all") {
		setMappingValue(&pinned, "include-all", off())
		setMappingValue(&pinned, "include-all-proxies", &yaml.Node{Kind: yaml.ScalarNode, Tag: "!!bool", Value: "true"})
	}
	setMappingValue(&pinned, "include-all-providers", off())
	var useNode yaml.Node
	if err := useNode.Encode(append([]string{}, baseProviders...)); err != nil {
		return nil, err
	}
	setMappingValue(&pinned, "use", &useNode)
	if len(baseProviders) == 0 && len(groupList(mapping, "proxies")) == 0 && !groupFlag(mapping, "include-all") && !groupFlag(mapping, "include-all-proxies") {
		var rejectNode yaml.Node
		if err := rejectNode.Encode([]string{"REJECT"}); err != nil {
			return nil, err
		}
		setMappingValue(&pinned, "proxies", &rejectNode)
	}
	return &pinned, nil
}

func uniqueStrings(values []string) []string {
	seen := make(map[string]struct{}, len(values))
	unique := make([]string, 0, len(values))
	for _, value := range values {
		if _, ok := seen[value]; ok {
			continue
		}
		seen[value] = struct{}{}
		unique = append(unique, value)
	}
	return unique
}
