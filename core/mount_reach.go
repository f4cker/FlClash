package core

import (
	"encoding/json"
	"net/netip"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"strconv"
	"strings"

	"github.com/dlclark/regexp2"
	"github.com/metacubex/mihomo/common/convert"
	mihomoYaml "github.com/metacubex/mihomo/common/yaml"
	"github.com/metacubex/mihomo/component/age"
	"github.com/metacubex/mihomo/constant"
	RC "github.com/metacubex/mihomo/rules/common"
	"go.yaml.in/yaml/v3"
)

// A base as the mount checks read it, before any mount is added.
type mountBase struct {
	proxyTypes   map[string]string
	proxyDialers map[string]string
	groups       []map[string]any
	providers    map[string]baseProvider
	rules        []string
}

// What a base provider holds, from its payload or cache. Filters are not
// applied, so a Tailscale node they would drop still counts.
type baseProvider struct {
	names     []string
	tailscale bool
}

func readMountBase(root *yaml.Node) (*mountBase, error) {
	proxies, err := decodeMappings(mappingValue(root, "proxies"), "proxies")
	if err != nil {
		return nil, err
	}
	groups, err := decodeMappings(mappingValue(root, "proxy-groups"), "proxy-groups")
	if err != nil {
		return nil, err
	}
	base := &mountBase{proxyTypes: map[string]string{}, proxyDialers: map[string]string{}, groups: groups}
	for _, mapping := range proxies {
		name := groupString(mapping, "name")
		base.proxyTypes[name] = strings.ToLower(groupString(mapping, "type"))
		if dialer := groupString(mapping, "dialer-proxy"); dialer != "" {
			base.proxyDialers[name] = dialer
		}
	}
	if providers := resolveAlias(mappingValue(root, "proxy-providers")); providers != nil && providers.Kind == yaml.MappingNode {
		base.providers = readBaseProviders(providers)
	}
	base.rules = ruleLines(mappingValue(root, "rules"))
	if subRules := resolveAlias(mappingValue(root, "sub-rules")); subRules != nil && subRules.Kind == yaml.MappingNode {
		for i := 1; i < len(subRules.Content); i += 2 {
			base.rules = append(base.rules, ruleLines(subRules.Content[i])...)
		}
	}
	return base, nil
}

func ruleLines(node *yaml.Node) []string {
	var lines []string
	if node = resolveAlias(node); node == nil || node.Kind != yaml.SequenceNode {
		return nil
	}
	for _, item := range node.Content {
		if item = resolveAlias(item); item.Kind == yaml.ScalarNode {
			lines = append(lines, item.Value)
		}
	}
	return lines
}

// An override-expr renaming is not followed.
func readBaseProviders(providers *yaml.Node) map[string]baseProvider {
	read := map[string]baseProvider{}
	for i := 0; i+1 < len(providers.Content); i += 2 {
		var mapping map[string]any
		if resolveAlias(providers.Content[i+1]).Decode(&mapping) != nil {
			read[providers.Content[i].Value] = baseProvider{}
			continue
		}
		var nodes []map[string]any
		switch groupString(mapping, "type") {
		case "inline":
			payload, _ := mapping["payload"].([]any)
			for _, item := range payload {
				if node, ok := item.(map[string]any); ok {
					nodes = append(nodes, node)
				}
			}
		case "file", "http":
			path := groupString(mapping, "path")
			if path == "" && groupString(mapping, "type") == "http" {
				path = constant.Path.GetPathByHash("proxies", groupString(mapping, "url"))
			}
			nodes = cachedProxies(constant.Path.Resolve(path), groupString(mapping, "age-secret-key"))
		}
		override, _ := mapping["override"].(map[string]any)
		excluded := typeExcluded(groupString(mapping, "exclude-type"), "tailscale")
		var provider baseProvider
		for _, node := range nodes {
			provider.names = append(provider.names, overriddenName(groupString(node, "name"), override))
			if !excluded && strings.EqualFold(groupString(node, "type"), "tailscale") {
				provider.tailscale = true
			}
		}
		read[providers.Content[i].Value] = provider
	}
	return read
}

func cachedProxies(path, ageSecretKey string) []map[string]any {
	buf, err := os.ReadFile(path)
	if err != nil {
		return nil
	}
	if buf, err = age.DecryptBytes(buf, ageKeys(ageSecretKey)...); err != nil {
		return nil
	}
	var document struct {
		Proxies []map[string]any `yaml:"proxies"`
	}
	if mihomoYaml.Unmarshal(buf, &document) != nil || document.Proxies == nil {
		document.Proxies, _ = convert.ConvertsV2Ray(buf)
	}
	return document.Proxies
}

// As mihomo reads exclude-type: a | list, each compared ignoring case.
func typeExcluded(excludeType, kind string) bool {
	if excludeType == "" {
		return false
	}
	return slices.ContainsFunc(strings.Split(excludeType, "|"), func(item string) bool {
		return strings.EqualFold(item, kind)
	})
}

func (b *mountBase) groupNames() map[string]bool {
	names := make(map[string]bool, len(b.groups))
	for _, group := range b.groups {
		names[groupString(group, "name")] = true
	}
	return names
}

func (b *mountBase) groupProviders(group map[string]any) []string {
	if groupFlag(group, "include-all") || groupFlag(group, "include-all-providers") {
		names := make([]string, 0, len(b.providers))
		for name := range b.providers {
			names = append(names, name)
		}
		return names
	}
	return groupList(group, "use")
}

// The groups mounts must stay out of: those holding a Tailscale node, those
// a rule sends Tailscale ranges or tailnet names to, and every group inside
// one of them. The final MATCH alone never counts: it is the main group.
func (b *mountBase) tailscaleGroups(suffixes []string) map[string]bool {
	hasTailscale := false
	for _, kind := range b.proxyTypes {
		hasTailscale = hasTailscale || kind == "tailscale"
	}
	reach := map[string]bool{}
	holds := func(group map[string]any) bool {
		excluded := typeExcluded(groupString(group, "exclude-type"), "tailscale")
		if !excluded {
			if hasTailscale && (groupFlag(group, "include-all") || groupFlag(group, "include-all-proxies")) {
				return true
			}
			if slices.ContainsFunc(b.groupProviders(group), func(name string) bool { return b.providers[name].tailscale }) {
				return true
			}
		}
		return slices.ContainsFunc(groupList(group, "proxies"), func(member string) bool {
			return reach[member] || !excluded && b.proxyTypes[member] == "tailscale"
		})
	}
	for changed := true; changed; {
		changed = false
		for _, group := range b.groups {
			if name := groupString(group, "name"); !reach[name] && holds(group) {
				reach[name], changed = true, true
			}
		}
	}
	groups := b.groupNames()
	for _, line := range b.rules {
		if target, ok := tailscaleRuleTarget(line, suffixes); ok && groups[target] {
			reach[target] = true
		}
	}
	byName := make(map[string]map[string]any, len(b.groups))
	for _, group := range b.groups {
		byName[groupString(group, "name")] = group
	}
	var queue []string
	for name := range reach {
		queue = append(queue, name)
	}
	for len(queue) > 0 {
		name := queue[0]
		queue = queue[1:]
		for _, member := range groupList(byName[name], "proxies") {
			if groups[member] && !reach[member] {
				reach[member] = true
				queue = append(queue, member)
			}
		}
	}
	return reach
}

// The names a mount node's dialer-proxy must not lead to: a Tailscale node,
// a group reaching one, and a base proxy or group that relays through those.
func (b *mountBase) relayNames(reach map[string]bool) map[string]bool {
	relay := map[string]bool{}
	for name, kind := range b.proxyTypes {
		if kind == "tailscale" {
			relay[name] = true
		}
	}
	for name := range reach {
		relay[name] = true
	}
	for changed := true; changed; {
		changed = false
		chained := false
		for name, dialer := range b.proxyDialers {
			if relay[dialer] && !relay[name] {
				relay[name], changed = true, true
			}
			chained = chained || relay[name] && b.proxyTypes[name] != "tailscale"
		}
		for _, group := range b.groups {
			name := groupString(group, "name")
			if relay[name] {
				continue
			}
			all := groupFlag(group, "include-all") || groupFlag(group, "include-all-proxies")
			if all && chained || slices.ContainsFunc(groupList(group, "proxies"), func(member string) bool { return relay[member] }) {
				relay[name], changed = true, true
			}
		}
	}
	return relay
}

// Whether a rule other than MATCH sends something of the Tailscale ranges or
// a tailnet suffix to its target. Only rules whose payload names exactly
// what they match are read; a rule set or GEOIP is not opened.
func tailscaleRuleTarget(line string, suffixes []string) (string, bool) {
	tp, payload, target, params := RC.ParseRulePayload(line, true)
	if isSrc, _ := RC.ParseParams(params); isSrc || target == "" {
		return "", false
	}
	switch tp {
	case "IP-CIDR", "IP-CIDR6":
		prefix, err := netip.ParsePrefix(payload)
		if err != nil {
			return "", false
		}
		return target, slices.ContainsFunc(tailscaleProtectedPrefixes, prefix.Masked().Overlaps)
	case "IP-SUFFIX":
		rule, err := RC.NewIPSuffix(payload, target, false, true)
		if err != nil {
			return "", false
		}
		suffix, _ := netip.ParsePrefix(payload)
		return target, slices.ContainsFunc(tailscaleProtectedPrefixes, func(prefix netip.Prefix) bool {
			candidate, ok := joinPrefixBits(prefix, suffix.Addr())
			if !ok {
				return false
			}
			matched, _ := rule.Match(&constant.Metadata{DstIP: candidate}, constant.RuleMatchHelper{})
			return matched
		})
	}
	var rule constant.Rule
	var err error
	switch tp {
	case "DOMAIN":
		rule = RC.NewDomain(payload, target)
	case "DOMAIN-SUFFIX":
		rule = RC.NewDomainSuffix(payload, target)
	case "DOMAIN-KEYWORD":
		rule = RC.NewDomainKeyword(payload, target)
	case "DOMAIN-REGEX":
		rule, err = RC.NewDomainRegex(payload, target)
	case "DOMAIN-WILDCARD":
		rule, err = RC.NewDomainWildcard(payload, target)
	default:
		return "", false
	}
	if err != nil {
		return "", false
	}
	return target, slices.ContainsFunc(suffixes, func(suffix string) bool {
		if tailscaleProfileRuleMatches(rule, TailscaleRouteTarget{Kind: tailscaleTargetSuffix, Value: suffix}, nil) {
			return true
		}
		matched, _ := rule.Match(&constant.Metadata{Host: "host." + suffix}, constant.RuleMatchHelper{})
		return matched
	})
}

// The address of prefix whose host bits are taken from addr.
func joinPrefixBits(prefix netip.Prefix, addr netip.Addr) (netip.Addr, bool) {
	addr = addr.Unmap()
	base := prefix.Addr()
	if base.Is4() != addr.Is4() {
		return netip.Addr{}, false
	}
	high, low := base.AsSlice(), addr.AsSlice()
	for i := range high {
		for bit := 0; bit < 8; bit++ {
			if i*8+bit >= prefix.Bits() {
				mask := byte(0x80 >> bit)
				high[i] = high[i]&^mask | low[i]&mask
			}
		}
	}
	joined, ok := netip.AddrFromSlice(high)
	return joined, ok
}

// ts.net and every tailnet suffix a profile's routing kept on disk.
func tailnetSuffixes() []string {
	suffixes := []string{tailscaleProtectedSuffix}
	files, _ := filepath.Glob(filepath.Join(tailscaleRoutesDir(), "routes-*.json"))
	for _, file := range files {
		buf, err := os.ReadFile(file)
		if err != nil {
			continue
		}
		var memory tailscaleRouteMemory
		if json.Unmarshal(buf, &memory) != nil {
			continue
		}
		for _, suffix := range memory.Suffixes {
			if suffix = normalizeTailscaleHost(suffix); suffix != "" && !slices.Contains(suffixes, suffix) {
				suffixes = append(suffixes, suffix)
			}
		}
	}
	return suffixes
}

// A panel-added node is named Name, or "Name (Flash)", "Name (Flash N)"
// once Name is taken; a mount must never hold any of them.
func managedNameFamily(name string, bases []string) bool {
	return slices.ContainsFunc(bases, func(base string) bool {
		if name == base || name == base+" (Flash)" {
			return true
		}
		number, ok := strings.CutPrefix(name, base+" (Flash ")
		if number, ok = strings.CutSuffix(number, ")"); !ok {
			return false
		}
		n, err := strconv.Atoi(number)
		return err == nil && n > 1 && strconv.Itoa(n) == number
	})
}

func managedBases(names []string) []string {
	bases := make([]string, 0, len(names))
	for _, name := range names {
		if name == "" {
			name = tailscaleManagedBaseName
		}
		bases = append(bases, name)
	}
	return bases
}

// What a mount node's dialer-proxy is checked against; nil checks nothing.
type mountRelay struct {
	names   map[string]bool
	managed []string
}

func (r *mountRelay) reaches(name string) bool {
	return r != nil && name != "" && (r.names[name] || managedNameFamily(name, r.managed))
}

func (r *mountRelay) empty() bool {
	return r == nil || len(r.names) == 0 && len(r.managed) == 0
}

// The yq-style test pattern for every name a dialer-proxy must not lead to.
func (r *mountRelay) pattern() string {
	var parts []string
	for name := range r.names {
		parts = append(parts, regexp.QuoteMeta(name))
	}
	slices.Sort(parts)
	for _, base := range r.managed {
		parts = append(parts, regexp.QuoteMeta(base)+`( \(Flash( [0-9]+)?\))?`)
	}
	return "^(" + strings.Join(parts, "|") + ")$"
}

// A node the file gains after this apply, before the next one, keeps its
// chain into Tailscale only as a dial that fails.
func (r *mountRelay) backstop() string {
	quoted := strings.NewReplacer(`\`, `\\`, `"`, `\"`, "\n", `\n`).Replace(r.pattern())
	return `(select((."dialer-proxy" // "") | test("` + quoted + `")) | ."dialer-proxy") = "REJECT"`
}

func exactNamesFilter(names []string) string {
	quoted := make([]string, 0, len(names))
	for _, name := range names {
		quoted = append(quoted, regexp2.Escape(name))
	}
	return "^(?:" + strings.Join(quoted, "|") + ")$"
}
