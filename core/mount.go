package core

import (
	"bytes"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"slices"
	"strconv"
	"strings"

	"github.com/dlclark/regexp2"
	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/common/convert"
	mihomoYaml "github.com/metacubex/mihomo/common/yaml"
	"github.com/metacubex/mihomo/component/age"
	"go.yaml.in/yaml/v3"
)

const mountProviderPrefix = "flash-mount-"

// A file Flash's own updater keeps; mihomo never sees a subscription URL.
type MountSource struct {
	ID    int64  `json:"id"`
	Label string `json:"label"`
	Path  string `json:"path"`
}

// Groups are the explicitly chosen ones; auto-collecting groups take every
// mount on their own. Revision binds a readback to the setup that made it.
type MountSetup struct {
	Revision string        `json:"revision"`
	Sources  []MountSource `json:"sources"`
	Groups   []string      `json:"groups,omitempty"`
}

const (
	mountSourceNodes       = "nodes"
	mountSourceUnsupported = "unsupported"
	mountSourceInvalid     = "invalid"
	mountSourceMissing     = "missing"
	mountSourceReadError   = "read-error"
)

// Count is what the mount provider would hold: Listed less Tailscale nodes,
// nameless entries and repeated names.
type MountSourceInspection struct {
	Status            string `json:"status"`
	Count             int    `json:"count"`
	Listed            int    `json:"listed"`
	TailscaleExcluded int    `json:"tailscale-excluded"`
	names             []string
}

func mountProviderName(id int64) string {
	return mountProviderPrefix + strconv.FormatInt(id, 10)
}

func handleInspectMountSource(params PathParams) MountSourceInspection {
	return inspectMountSource(params.Path)
}

// Mirrors NewProxiesParser for a mount provider, so a file that would not
// load there is never counted as nodes here.
func inspectMountSource(path string) MountSourceInspection {
	buf, err := os.ReadFile(path)
	if err != nil {
		if errors.Is(err, fs.ErrNotExist) {
			return MountSourceInspection{Status: mountSourceMissing}
		}
		return MountSourceInspection{Status: mountSourceReadError}
	}
	if buf, err = age.DecryptBytes(buf); err != nil {
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
		proxy, err := adapter.ParseProxy(mapping)
		if err != nil {
			return MountSourceInspection{Status: mountSourceInvalid, Listed: len(mappings)}
		}
		_ = proxy.Close()
		seen[name] = struct{}{}
		inspection.names = append(inspection.names, name)
	}
	inspection.Count = len(inspection.names)
	if inspection.Count == 0 && inspection.TailscaleExcluded < inspection.Listed {
		return MountSourceInspection{Status: mountSourceInvalid, Listed: len(mappings)}
	}
	return inspection
}

const (
	mountGroupAuto      = "auto"
	mountGroupCandidate = "candidate"
	mountGroupExcluded  = "excluded"
)

// What the mount panel needs of one base group. Filters are only flagged:
// the host shows the hint, never the pattern.
type MountGroupInfo struct {
	Name          string `json:"name"`
	Type          string `json:"type"`
	Kind          string `json:"kind"`
	Excluded      string `json:"excluded,omitempty"`
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
}

var mountableGroupTypes = []string{"select", "url-test", "fallback", "load-balance"}

func groupFlag(mapping map[string]any, key string) bool {
	switch value := mapping[key].(type) {
	case bool:
		return value
	case string:
		parsed, _ := strconv.ParseBool(value)
		return parsed
	}
	return false
}

func groupString(mapping map[string]any, key string) string {
	value, _ := mapping[key].(string)
	return value
}

func groupList(mapping map[string]any, key string) []string {
	items, _ := mapping[key].([]any)
	names := make([]string, 0, len(items))
	for _, item := range items {
		if name, ok := item.(string); ok {
			names = append(names, name)
		}
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

func proxyTypesOf(root *yaml.Node) (map[string]string, error) {
	proxies, err := decodeMappings(mappingValue(root, "proxies"), "proxies")
	if err != nil {
		return nil, err
	}
	proxyTypes := map[string]string{}
	for _, mapping := range proxies {
		proxyTypes[groupString(mapping, "name")] = strings.ToLower(groupString(mapping, "type"))
	}
	return proxyTypes, nil
}

func inspectMountTarget(root *yaml.Node) (MountTarget, error) {
	proxyTypes, err := proxyTypesOf(root)
	if err != nil {
		return MountTarget{}, err
	}
	groups, err := decodeMappings(mappingValue(root, "proxy-groups"), "proxy-groups")
	if err != nil {
		return MountTarget{}, err
	}
	target := MountTarget{Groups: []MountGroupInfo{}}
	for _, mapping := range groups {
		target.Groups = append(target.Groups, mountGroupInfo(mapping, proxyTypes))
	}
	return target, nil
}

func mountGroupInfo(mapping map[string]any, proxyTypes map[string]string) MountGroupInfo {
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
	switch {
	case !slices.Contains(mountableGroupTypes, kind):
		info.Kind, info.Excluded = mountGroupExcluded, "type"
	case info.Name == globalProxyName:
		info.Kind, info.Excluded = mountGroupExcluded, "builtin"
	case includeAll || groupFlag(mapping, "include-all-providers"):
		info.Kind, info.Collects = mountGroupAuto, "providers"
		if includeAll || groupFlag(mapping, "include-all-proxies") {
			info.Collects = "all"
		}
	case info.Hidden:
		info.Kind, info.Excluded = mountGroupExcluded, "hidden"
	case tailscaleOnlyGroup(mapping, proxyTypes):
		info.Kind, info.Excluded = mountGroupExcluded, "tailscale"
	default:
		info.Kind = mountGroupCandidate
	}
	return info
}

// A group whose own members are all Tailscale nodes is a dedicated route.
func tailscaleOnlyGroup(mapping map[string]any, proxyTypes map[string]string) bool {
	members := groupList(mapping, "proxies")
	if len(members) == 0 || len(groupList(mapping, "use")) > 0 || groupFlag(mapping, "include-all-proxies") {
		return false
	}
	for _, member := range members {
		if proxyTypes[member] != "tailscale" {
			return false
		}
	}
	return true
}

type MountNode struct {
	Name     string `json:"name"`
	Original string `json:"original"`
}

type MountSourceReport struct {
	ID                int64       `json:"id"`
	Provider          string      `json:"provider"`
	Status            string      `json:"status"`
	TailscaleExcluded int         `json:"tailscale-excluded"`
	Nodes             []MountNode `json:"nodes"`
}

const (
	mountProtectionReject = "reject"
	mountProtectionBase   = "base"
)

// Via is auto for a group that collects every provider, use for a chosen one.
type MountGroupReport struct {
	Name          string `json:"name"`
	Via           string `json:"via"`
	Protection    string `json:"protection"`
	EmptyFallback string `json:"empty-fallback"`
}

type MountReport struct {
	Revision string              `json:"revision"`
	Sources  []MountSourceReport `json:"sources"`
	Groups   []MountGroupReport  `json:"groups"`
	Renamed  int                 `json:"renamed"`
}

func errMountGroupChanged(name string) error {
	return &MethodError{
		Code:    "mount_group_changed",
		Message: fmt.Sprintf("target group %q is gone or no longer takes subscription nodes", name),
		Details: name,
	}
}

var reservedProxyNames = []string{"DIRECT", "REJECT", "REJECT-DROP", "PASS", "COMPATIBLE", globalProxyName}

// Each source becomes a file provider over the cache Flash keeps; chosen
// groups gain a use of every one, and a group that now takes mounted nodes
// rejects when empty unless the base names its own empty-fallback. Names
// that clash with the base or an earlier source get "(label)" appended.
func applyMountOverrides(root *yaml.Node, setup *MountSetup) (*MountReport, error) {
	report := &MountReport{Revision: setup.Revision, Sources: []MountSourceReport{}, Groups: []MountGroupReport{}}
	if len(setup.Sources) == 0 {
		return report, nil
	}
	taken := map[string]struct{}{}
	for _, name := range reservedProxyNames {
		taken[name] = struct{}{}
	}
	proxyTypes, err := proxyTypesOf(root)
	if err != nil {
		return nil, err
	}
	for name := range proxyTypes {
		taken[name] = struct{}{}
	}
	groupsNode := resolveAlias(mappingValue(root, "proxy-groups"))
	groupMappings, err := decodeMappings(groupsNode, "proxy-groups")
	if err != nil {
		return nil, err
	}
	for _, mapping := range groupMappings {
		taken[groupString(mapping, "name")] = struct{}{}
	}

	providers := resolveAlias(mappingValue(root, "proxy-providers"))
	if providers == nil || isNull(providers) {
		providers = &yaml.Node{Kind: yaml.MappingNode, Tag: "!!map"}
		setMappingValue(root, "proxy-providers", providers)
	} else if providers.Kind != yaml.MappingNode {
		return nil, errors.New("proxy-providers must be a mapping")
	}
	names := make([]string, 0, len(setup.Sources))
	for _, source := range setup.Sources {
		name := mountProviderName(source.ID)
		if mappingValue(providers, name) != nil {
			return nil, fmt.Errorf("proxy provider %s already exists", name)
		}
		inspection := inspectMountSource(source.Path)
		nodes, renames := mountNodeNames(source, inspection.names, taken)
		report.Renamed += len(renames)
		report.Sources = append(report.Sources, MountSourceReport{
			ID:                source.ID,
			Provider:          name,
			Status:            inspection.Status,
			TailscaleExcluded: inspection.TailscaleExcluded,
			Nodes:             nodes,
		})
		definition, err := mountProviderNode(source.Path, renames)
		if err != nil {
			return nil, err
		}
		setMappingValue(providers, name, definition)
		names = append(names, name)
	}
	groups, err := applyMountGroups(groupsNode, groupMappings, proxyTypes, setup.Groups, names)
	if err != nil {
		return nil, err
	}
	report.Groups = groups
	return report, nil
}

func mountNodeNames(source MountSource, originals []string, taken map[string]struct{}) ([]MountNode, []MountNode) {
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
		return inTaken || inOwn
	}
	nodes := make([]MountNode, 0, len(originals))
	var renames []MountNode
	for _, original := range originals {
		name := original
		if _, clash := taken[original]; clash {
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

func mountProviderNode(path string, renames []MountNode) (*yaml.Node, error) {
	definition := map[string]any{
		"type":              "file",
		"path":              path,
		"flash-allow-empty": true,
		"exclude-type":      "tailscale",
	}
	if len(renames) > 0 {
		rules := make([]map[string]any, 0, len(renames))
		for _, rename := range renames {
			rules = append(rules, map[string]any{
				"pattern": "^" + regexp2.Escape(rename.Original) + "$",
				"target":  strings.ReplaceAll(rename.Name, "$", "$$"),
			})
		}
		definition["override"] = map[string]any{"proxy-name": rules}
	}
	var node yaml.Node
	if err := node.Encode(definition); err != nil {
		return nil, err
	}
	return &node, nil
}

func applyMountGroups(groupsNode *yaml.Node, mappings []map[string]any, proxyTypes map[string]string, chosen []string, providers []string) ([]MountGroupReport, error) {
	reports := []MountGroupReport{}
	found := map[string]bool{}
	for i, mapping := range mappings {
		node := resolveAlias(groupsNode.Content[i])
		info := mountGroupInfo(mapping, proxyTypes)
		via := ""
		switch {
		case info.Kind == mountGroupAuto:
			via = "auto"
		case slices.Contains(chosen, info.Name) && info.Kind == mountGroupCandidate:
			via = "use"
		}
		if slices.Contains(chosen, info.Name) && via != "" {
			found[info.Name] = true
		}
		if via == "" {
			continue
		}
		copied := *node
		copied.Content = append([]*yaml.Node(nil), node.Content...)
		if via == "use" {
			uses := append(groupList(mapping, "use"), providers...)
			var useNode yaml.Node
			if err := useNode.Encode(uniqueStrings(uses)); err != nil {
				return nil, err
			}
			setMappingValue(&copied, "use", &useNode)
		}
		report := MountGroupReport{Name: info.Name, Via: via, Protection: mountProtectionBase, EmptyFallback: info.EmptyFallback}
		if info.EmptyFallback == "" {
			report.Protection, report.EmptyFallback = mountProtectionReject, "REJECT"
			setMappingValue(&copied, "empty-fallback", &yaml.Node{Kind: yaml.ScalarNode, Tag: "!!str", Value: "REJECT"})
		}
		groupsNode.Content[i] = &copied
		reports = append(reports, report)
	}
	for _, name := range chosen {
		if !found[name] {
			return nil, errMountGroupChanged(name)
		}
	}
	return reports, nil
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
