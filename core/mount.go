package core

import (
	"bytes"
	"errors"
	"fmt"
	"io/fs"
	"net"
	"os"
	"slices"
	"strconv"
	"strings"

	"github.com/dlclark/regexp2"
	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/provider"
	"github.com/metacubex/mihomo/common/convert"
	mihomoYaml "github.com/metacubex/mihomo/common/yaml"
	"github.com/metacubex/mihomo/component/age"
	"github.com/metacubex/mihomo/component/flashguard"
	"go.yaml.in/yaml/v3"
)

const mountProviderPrefix = "flash-mount-"

// A file Flash's own updater keeps; mihomo never sees a subscription URL.
type MountSource struct {
	ID    int64  `json:"id"`
	Label string `json:"label"`
	Path  string `json:"path"`
}

// Every ordinary group the isolation checks allow takes every mount, then
// filters it by its own rules; no group is chosen. A host that still sends
// the groups it once chose has them ignored. Revision binds a readback to
// the setup that made it.
type MountSetup struct {
	Target   int64         `json:"target"`
	Revision string        `json:"revision"`
	Sources  []MountSource `json:"sources"`
	reserved []string
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

// Mirrors NewProxiesParser for a mount provider, so a file that would not
// load there is never counted as nodes here.
func inspectMountSource(path, ageSecretKey string, relay *mountRelay) MountSourceInspection {
	buf, err := os.ReadFile(path)
	if err != nil {
		if errors.Is(err, fs.ErrNotExist) {
			return MountSourceInspection{Status: mountSourceMissing}
		}
		return MountSourceInspection{Status: mountSourceReadError}
	}
	if buf, err = age.DecryptBytes(buf, ageKeys(ageSecretKey)...); err != nil {
		return MountSourceInspection{Status: mountSourceInvalid}
	}
	if len(bytes.TrimSpace(buf)) == 0 {
		return MountSourceInspection{Status: mountSourceUnsupported}
	}
	var mappings []map[string]any
	var document any
	root, isMapping := document.(map[string]any)
	if err := mihomoYaml.Unmarshal(buf, &document); err == nil {
		root, isMapping = document.(map[string]any)
	}
	if !isMapping {
		converted, convertErr := convert.ConvertsV2Ray(buf)
		if convertErr != nil || len(converted) == 0 {
			return MountSourceInspection{Status: mountSourceUnsupported}
		}
		mappings = converted
	} else {
		list, ok := root["proxies"].([]any)
		if !ok {
			return MountSourceInspection{Status: mountSourceUnsupported}
		}
		for _, item := range list {
			mapping, _ := item.(map[string]any)
			mappings = append(mappings, mapping)
		}
	}
	inspection := MountSourceInspection{Status: mountSourceNodes, Listed: len(mappings)}
	seen := map[string]struct{}{}
	for _, mapping := range mappings {
		kind, _ := mapping["type"].(string)
		if strings.EqualFold(kind, "tailscale") {
			inspection.TailscaleExcluded++
			continue
		}
		name, ok := mapping["name"].(string)
		if !ok {
			continue
		}
		if _, dup := seen[name]; dup {
			continue
		}
		// Its endpoints are not the server Addr names, so the guard cannot
		// tell whether one is on Tailscale: never built, as the provider.
		if flashguard.UncheckedEndpoints(mapping) {
			seen[name] = struct{}{}
			inspection.UnsupportedExcluded++
			continue
		}
		proxy, err := adapter.ParseProxy(mapping)
		if err != nil {
			return MountSourceInspection{Status: mountSourceInvalid, Listed: len(mappings)}
		}
		_ = proxy.Close()
		seen[name] = struct{}{}
		host, _, splitErr := net.SplitHostPort(proxy.Addr())
		switch {
		case slices.ContainsFunc(proxyOptionValues(mapping, "interface-name"), func(value string) bool { return value != "" }),
			slices.ContainsFunc(proxyOptionValues(mapping, "routing-mark"), func(value string) bool { return value != "" && value != "0" }):
			inspection.UnsupportedExcluded++
		case slices.ContainsFunc(proxyOptionValues(mapping, "dialer-proxy"), relay.reaches),
			splitErr == nil && flashguard.ProtectedServer(host):
			// A server on Tailscale, or a local one, is a relay through it.
			inspection.RelayExcluded++
		default:
			inspection.names = append(inspection.names, name)
		}
	}
	inspection.Count = len(inspection.names)
	if inspection.Count == 0 && inspection.TailscaleExcluded+inspection.RelayExcluded+inspection.UnsupportedExcluded < inspection.Listed {
		return MountSourceInspection{Status: mountSourceInvalid, Listed: len(mappings)}
	}
	return inspection
}

// Auto is a group that takes the mounts; excluded, one kept out of them.
const (
	mountGroupAuto     = "auto"
	mountGroupExcluded = "excluded"
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

func inspectMountTarget(root *yaml.Node) (MountTarget, error) {
	base, err := readMountBase(root)
	if err != nil {
		return MountTarget{}, err
	}
	target := MountTarget{Groups: []MountGroupInfo{}, Relay: []string{}}
	reach := base.tailscaleGroups(newRuleReader(base))
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
}

var reservedProxyNames = []string{"DIRECT", "REJECT", "REJECT-DROP", "PASS", "COMPATIBLE", globalProxyName}

// Each source becomes a file provider over the cache Flash keeps; every
// group the checks allow takes every one, through include-all or a use, and
// keeps its own members and filters. A group left with provider nodes only
// rejects when empty unless the base names its own empty-fallback. Names
// that clash with the base or an earlier source get "(label)" appended.
func applyMountOverrides(root *yaml.Node, setup *MountSetup) (*MountReport, error) {
	report := &MountReport{Target: setup.Target, Revision: setup.Revision, Sources: []MountSourceReport{}, Groups: []MountGroupReport{}}
	if len(setup.Sources) == 0 {
		return report, nil
	}
	refreshGuardSuffixes()
	base, err := readMountBase(root)
	if err != nil {
		return nil, err
	}
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
	reader := newRuleReader(base)
	reach := base.tailscaleGroups(reader)
	relay := newMountRelay(base.relayNames(base.holding()), managed)
	report.gate = newMountGate(base, reader, relay, reach)
	names := make([]string, 0, len(setup.Sources))
	for _, source := range setup.Sources {
		name := mountProviderName(source.ID)
		if mappingValue(providers, name) != nil {
			return nil, fmt.Errorf("proxy provider %s already exists", name)
		}
		inspection := inspectMountSource(source.Path, "", relay)
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
		definition, err := mountProviderNode(source.Path, renames, relay)
		if err != nil {
			return nil, err
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
	report.gate.takeGroups(base, groups)
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

// Checks the groups as they will run, mounts added, against what the
// isolation checks read of the base: no group they keep out may hold a
// mount provider, and whatever such a group may be carried by (members and
// empty-fallback) must be kept out too. Adding mounts adds providers only,
// never a group edge, so a failure here is a gap in those checks; the
// target is refused rather than run.
func checkMountedGroups(groupsNode *yaml.Node, reach map[string]string, taking []MountGroupReport, mountProviders []string) error {
	mounted, err := decodeMappings(groupsNode, "proxy-groups")
	if err != nil {
		return err
	}
	takes := map[string]bool{}
	for _, group := range taking {
		takes[group.Name] = true
	}
	names := map[string]bool{}
	for _, mapping := range mounted {
		names[groupString(mapping, "name")] = true
	}
	for _, mapping := range mounted {
		name := groupString(mapping, "name")
		holdsMount := collectsProviders(mapping) || slices.ContainsFunc(groupList(mapping, "use"), func(use string) bool {
			return slices.Contains(mountProviders, use)
		})
		if holdsMount != takes[name] || holdsMount && reach[name] != "" {
			return errMountIsolation(name)
		}
		if reach[name] == "" {
			continue
		}
		for _, member := range append(groupList(mapping, "proxies"), groupString(mapping, "empty-fallback")) {
			if names[member] && (reach[member] == "" || takes[member]) {
				return errMountIsolation(member)
			}
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
