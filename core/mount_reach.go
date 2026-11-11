package core

import (
	"encoding/json"
	"net"
	"net/netip"
	"os"
	"path/filepath"
	"slices"
	"strconv"
	"strings"

	"github.com/dlclark/regexp2"
	"github.com/metacubex/mihomo/adapter/provider"
	"github.com/metacubex/mihomo/common/convert"
	mihomoYaml "github.com/metacubex/mihomo/common/yaml"
	"github.com/metacubex/mihomo/component/age"
	"github.com/metacubex/mihomo/component/flashguard"
	"github.com/metacubex/mihomo/component/geodata"
	"github.com/metacubex/mihomo/constant"
	cp "github.com/metacubex/mihomo/constant/provider"
	RC "github.com/metacubex/mihomo/rules/common"
	"github.com/metacubex/mihomo/rules/logic"
	rp "github.com/metacubex/mihomo/rules/provider"
	"go.yaml.in/yaml/v3"
	"go4.org/netipx"
)

// Why a group may not take mounted nodes. Unknown is a provider or rule set
// whose content cannot be read, which is never taken to hold nothing.
const (
	reachHolds       = "holds"
	reachProviderUnk = "provider-unknown"
	reachRule        = "rule"
	reachRuleUnk     = "rule-unknown"
	reachMember      = "member"
	// A group a Tailscale node, or a proxy Tailscale traffic takes, dials
	// through: its mounted node would carry the tailnet.
	reachCarrier = "carrier"
	// Tailscale traffic is sent to GLOBAL, which may select any group.
	reachGlobal = "global"
	// DNS queries, tailnet names among them, go out through the group.
	reachDNS = "dns"
	// A proxy dials through the group. A proxy that keeps its own session
	// or dials in the background (WireGuard, QUIC, mux) puts what it later
	// carries, a tailnet connection too, on what it dialed once: no mounted
	// node down that chain is asked again.
	reachDialer = "dialer"
)

// A base as the mount checks read it, before any mount is added.
type mountBase struct {
	proxyTypes   map[string]string
	proxyDialers map[string][]string
	groups       []map[string]any
	providers    map[string]baseProvider
	ruleSets     map[string]ruleSetContent
	// The profile's rules followed by every sub-rule's.
	rules    []string
	subRules map[string][]string
	// What a listener sends without rules, and the sub-rule it takes.
	listenerProxies []string
	listenerRules   []string
	// A tunnel's proxy, with the address it forwards to.
	tunnels []mountTunnel
	// The proxies DNS servers are reached through; rules when they follow them.
	dnsProxies []string
	dnsRules   bool
}

type mountTunnel struct {
	proxy  string
	target string
}

// What a base provider holds, from its payload and cache. Filters are not
// applied, so a Tailscale node they would drop still counts.
type baseProvider struct {
	names     []string
	tailscale bool
	unknown   bool
	gated     bool
	dialers   []string
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
	base := &mountBase{proxyTypes: map[string]string{}, proxyDialers: map[string][]string{}, groups: groups}
	for _, mapping := range proxies {
		name := groupString(mapping, "name")
		base.proxyTypes[name] = strings.ToLower(groupString(mapping, "type"))
		if dialers := proxyOptionValues(mapping, "dialer-proxy"); len(dialers) > 0 {
			base.proxyDialers[name] = dialers
		}
	}
	if providers := resolveAlias(mappingValue(root, "proxy-providers")); providers != nil && providers.Kind == yaml.MappingNode {
		base.providers = readBaseProviders(providers)
	}
	base.ruleSets = map[string]ruleSetContent{}
	if ruleSets := resolveAlias(mappingValue(root, "rule-providers")); ruleSets != nil && ruleSets.Kind == yaml.MappingNode {
		base.ruleSets = readBaseRuleSets(ruleSets)
	}
	base.rules = ruleLines(mappingValue(root, "rules"))
	base.subRules = map[string][]string{}
	if subRules := resolveAlias(mappingValue(root, "sub-rules")); subRules != nil && subRules.Kind == yaml.MappingNode {
		for i := 1; i < len(subRules.Content); i += 2 {
			lines := ruleLines(subRules.Content[i])
			base.subRules[subRules.Content[i-1].Value] = lines
			base.rules = append(base.rules, lines...)
		}
	}
	listeners, err := decodeMappings(mappingValue(root, "listeners"), "listeners")
	if err != nil {
		return nil, err
	}
	for _, mapping := range listeners {
		if proxy := groupString(mapping, "proxy"); proxy != "" {
			base.listenerProxies = append(base.listenerProxies, proxy)
		} else if rule := groupString(mapping, "rule"); rule != "" {
			base.listenerRules = append(base.listenerRules, rule)
		}
	}
	if tunnels := resolveAlias(mappingValue(root, "tunnels")); tunnels != nil && tunnels.Kind == yaml.SequenceNode {
		for _, item := range tunnels.Content {
			base.tunnels = append(base.tunnels, readMountTunnel(resolveAlias(item)))
		}
	}
	base.readDNS(resolveAlias(mappingValue(root, "dns")))
	return base, nil
}

// As mihomo reads a nameserver: a fragment part without = names the proxy.
func (b *mountBase) readDNS(node *yaml.Node) {
	var mapping map[string]any
	if node == nil || node.Kind != yaml.MappingNode || node.Decode(&mapping) != nil {
		return
	}
	b.dnsRules = groupFlag(mapping, "respect-rules")
	var servers []string
	// proxy-server-nameserver also resolves node servers and a Tailscale
	// node's control and DERP names.
	for _, key := range []string{"nameserver", "fallback", "direct-nameserver", "default-nameserver", "proxy-server-nameserver"} {
		servers = append(servers, groupList(mapping, key)...)
	}
	for _, key := range []string{"nameserver-policy", "proxy-server-nameserver-policy"} {
		policy, _ := providerOption(mapping, key).(map[string]any)
		for _, value := range policy {
			switch typed := value.(type) {
			case string:
				servers = append(servers, strings.Split(typed, ";")...)
			case []any:
				servers = append(servers, groupList(map[string]any{"v": typed}, "v")...)
			}
		}
	}
	for _, server := range servers {
		_, fragment, ok := strings.Cut(server, "#")
		if !ok {
			continue
		}
		for _, part := range strings.Split(fragment, "&") {
			if part = strings.TrimSpace(part); part != "" && !strings.Contains(part, "=") {
				if part == "RULES" {
					b.dnsRules = true
				} else {
					b.dnsProxies = append(b.dnsProxies, part)
				}
			}
		}
	}
}

// As mihomo reads a tunnel: "network,address,target,proxy" or a mapping.
func readMountTunnel(node *yaml.Node) mountTunnel {
	if node.Kind == yaml.ScalarNode {
		parts := strings.Split(node.Value, ",")
		for i := range parts {
			parts[i] = strings.TrimSpace(parts[i])
		}
		if len(parts) == 4 {
			return mountTunnel{proxy: parts[3], target: parts[2]}
		}
		return mountTunnel{}
	}
	var mapping map[string]any
	if node.Decode(&mapping) != nil {
		return mountTunnel{}
	}
	return mountTunnel{proxy: groupString(mapping, "proxy"), target: groupString(mapping, "target")}
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

// Every value a proxy option is given under any spelling the proxy decoder
// accepts: case ignored and _ read as -.
func proxyOptionValues(mapping map[string]any, key string) []string {
	var values []string
	for name, value := range mapping {
		if strings.EqualFold(strings.ReplaceAll(name, "_", "-"), key) {
			if text := provider.WeakString(value); text != "" {
				values = append(values, text)
			}
		}
	}
	slices.Sort(values)
	return values
}

func providerOption(mapping map[string]any, key string) any {
	if value, ok := mapping[key]; ok {
		return value
	}
	for name, value := range mapping {
		if strings.EqualFold(name, key) {
			return value
		}
	}
	return nil
}

func providerString(mapping map[string]any, key string) string {
	value, _ := providerOption(mapping, key).(string)
	return value
}

// An override-expr renaming is not followed.
func readBaseProviders(providers *yaml.Node) map[string]baseProvider {
	read := map[string]baseProvider{}
	for i := 0; i+1 < len(providers.Content); i += 2 {
		var mapping map[string]any
		if resolveAlias(providers.Content[i+1]).Decode(&mapping) != nil {
			read[providers.Content[i].Value] = baseProvider{unknown: true}
			continue
		}
		read[providers.Content[i].Value] = readBaseProvider(mapping)
	}
	return read
}

func readBaseProvider(mapping map[string]any) baseProvider {
	var p baseProvider
	var nodes []map[string]any
	payload, _ := providerOption(mapping, "payload").([]any)
	for _, item := range payload {
		if node, ok := item.(map[string]any); ok {
			nodes = append(nodes, node)
		}
	}
	switch kind := providerString(mapping, "type"); kind {
	case "inline":
	case "file", "http":
		p.gated = true
		path := providerString(mapping, "path")
		if path == "" && kind == "http" {
			path = constant.Path.GetPathByHash("proxies", providerString(mapping, "url"))
		}
		cached, ok := cachedProxies(constant.Path.Resolve(path), providerString(mapping, "age-secret-key"))
		p.unknown = !ok
		nodes = append(nodes, cached...)
	default:
		p.unknown = true
	}
	override, _ := providerOption(mapping, "override").(map[string]any)
	excluded := typeExcluded(providerString(mapping, "exclude-type"), "tailscale")
	for _, chain := range []string{providerString(mapping, "dialer-proxy"), providerString(override, "dialer-proxy")} {
		if chain != "" {
			p.dialers = append(p.dialers, chain)
		}
	}
	if expressions := providerOption(override, "override-expr"); expressions != nil && strings.Contains(strings.ToLower(provider.WeakString(expressions)), "dialer") {
		p.unknown = true
	}
	for _, node := range nodes {
		if excluded && strings.EqualFold(groupString(node, "type"), "tailscale") {
			continue
		}
		p.names = append(p.names, overriddenName(groupString(node, "name"), override))
		p.tailscale = p.tailscale || strings.EqualFold(groupString(node, "type"), "tailscale")
		p.dialers = append(p.dialers, proxyOptionValues(node, "dialer-proxy")...)
	}
	return p
}

func cachedProxies(path, ageSecretKey string) ([]map[string]any, bool) {
	buf, err := os.ReadFile(path)
	if err != nil {
		return nil, false
	}
	if buf, err = age.DecryptBytes(buf, ageKeys(ageSecretKey)...); err != nil {
		return nil, false
	}
	var document struct {
		Proxies []map[string]any `yaml:"proxies"`
	}
	if mihomoYaml.Unmarshal(buf, &document) != nil || document.Proxies == nil {
		converted, err := convert.ConvertsV2Ray(buf)
		if err != nil {
			return nil, false
		}
		return converted, true
	}
	return document.Proxies, true
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
		slices.Sort(names)
		return names
	}
	return groupList(group, "use")
}

// The groups holding a Tailscale node, or perhaps one through an unread provider.
func (b *mountBase) holding() map[string]string {
	hasTailscale := false
	for _, kind := range b.proxyTypes {
		hasTailscale = hasTailscale || kind == "tailscale"
	}
	reach := map[string]string{}
	holds := func(group map[string]any) string {
		excluded := typeExcluded(groupString(group, "exclude-type"), "tailscale")
		if !excluded && hasTailscale && (groupFlag(group, "include-all") || groupFlag(group, "include-all-proxies")) {
			return reachHolds
		}
		reason := ""
		for _, name := range b.groupProviders(group) {
			switch p := b.providers[name]; {
			case p.unknown:
				reason = reachProviderUnk
			case p.tailscale && !excluded:
				return reachHolds
			}
		}
		for _, member := range groupList(group, "proxies") {
			if reach[member] == reachHolds || !excluded && b.proxyTypes[member] == "tailscale" {
				return reachHolds
			}
			if reach[member] != "" {
				reason = reach[member]
			}
		}
		// An empty-fallback is what the group takes once it holds nothing.
		if fallback := groupString(group, "empty-fallback"); fallback != "" {
			if reach[fallback] == reachHolds || b.proxyTypes[fallback] == "tailscale" {
				return reachHolds
			}
			if reach[fallback] != "" {
				reason = reach[fallback]
			}
		}
		return reason
	}
	for changed := true; changed; {
		changed = false
		for _, group := range b.groups {
			name := groupString(group, "name")
			if reason := holds(group); reason != "" && reason != reach[name] && reach[name] != reachHolds {
				reach[name], changed = reason, true
			}
		}
	}
	return reach
}

// The groups mounts must stay out of: those holding a Tailscale node, those a
// rule other than the final MATCH (the main group), a listener or a tunnel
// sends Tailscale ranges or tailnet names to, every group inside one,
// whatever is selected now, and every group such a group or a Tailscale node
// dials through. Tailscale traffic sent to GLOBAL keeps mounts out of all.
func (b *mountBase) tailscaleGroups(reader *ruleReader) map[string]string {
	reach := b.holding()
	groups := b.groupNames()
	targets := b.tailscaleTargets(reader)
	global := ""
	names := make([]string, 0, len(targets))
	for target := range targets {
		names = append(names, target)
	}
	slices.Sort(names)
	for _, target := range names {
		reason := reachRule
		if targets[target] == ruleUnknown {
			reason = reachRuleUnk
		}
		switch {
		case target == globalProxyName:
			global = reachGlobal
		case groups[target] && reach[target] == "":
			reach[target] = reason
		}
	}
	byName := b.groupsByName()
	var queue []string
	for name := range reach {
		queue = append(queue, name)
	}
	slices.Sort(queue)
	for len(queue) > 0 {
		name := queue[0]
		queue = queue[1:]
		for _, member := range groupList(byName[name], "proxies") {
			if groups[member] && reach[member] == "" {
				reach[member] = reachMember
				queue = append(queue, member)
			}
		}
	}

	// What carries Tailscale traffic: Tailscale nodes, proxies it is sent to
	// and the groups above, and down from each what it is a member or a
	// dialer-proxy of, as any selection may be.
	seen := map[string]bool{}
	reason := reachCarrier
	carry := func(name string) {
		b.walk(name, byName, seen, func(group string) {
			if reach[group] == "" {
				reach[group] = reason
			}
		}, func() {
			switch {
			case global != "":
			case reason == reachDialer:
				global = reachDialer
			default:
				global = reachGlobal
			}
		})
	}
	var seeds []string
	for name, kind := range b.proxyTypes {
		if kind == "tailscale" {
			seeds = append(seeds, name)
		}
	}
	for name := range reach {
		seeds = append(seeds, name)
	}
	for _, target := range names {
		if !groups[target] {
			seeds = append(seeds, target)
		}
	}
	slices.Sort(seeds)
	for _, name := range seeds {
		carry(name)
	}
	for _, name := range sortedKeys(b.providers) {
		if p := b.providers[name]; p.tailscale {
			for _, dialer := range p.dialers {
				carry(dialer)
			}
		}
	}
	// A DNS server reached through a group takes every lookup it is asked,
	// a tailnet name too; one reached by rules may take any group.
	for _, proxy := range b.dnsProxies {
		switch {
		case proxy == globalProxyName:
			b.dnsRules = true
		case groups[proxy] && reach[proxy] == "":
			reach[proxy] = reachDNS
		}
		carry(proxy)
	}
	// Whatever any proxy, provider node, provider or override names as its
	// dialer-proxy: a mounted node there would carry that proxy's session.
	reason = reachDialer
	for _, name := range sortedKeys(b.proxyDialers) {
		for _, dialer := range b.proxyDialers[name] {
			carry(dialer)
		}
	}
	for _, name := range sortedKeys(b.providers) {
		for _, dialer := range b.providers[name].dialers {
			carry(dialer)
		}
	}
	if global != "" {
		for name := range groups {
			if reach[name] == "" {
				reach[name] = global
			}
		}
	}
	if b.dnsRules {
		for name := range groups {
			if reach[name] == "" {
				reach[name] = reachDNS
			}
		}
	}
	return reach
}

func sortedKeys[V any](m map[string]V) []string {
	keys := make([]string, 0, len(m))
	for key := range m {
		keys = append(keys, key)
	}
	slices.Sort(keys)
	return keys
}

func (b *mountBase) groupsByName() map[string]map[string]any {
	byName := make(map[string]map[string]any, len(b.groups))
	for _, group := range b.groups {
		byName[groupString(group, "name")] = group
	}
	return byName
}

// walk visits what a connection through name may be carried by: a group,
// its members and empty-fallback, its providers' dialers and, when it
// collects every proxy, theirs; a proxy's dialers. GLOBAL stands for every
// group and is not followed.
func (b *mountBase) walk(name string, byName map[string]map[string]any, seen map[string]bool, group func(string), global func()) {
	if name == "" || seen[name] {
		return
	}
	seen[name] = true
	if name == globalProxyName {
		global()
		return
	}
	mapping, isGroup := byName[name]
	if !isGroup {
		for _, dialer := range b.proxyDialers[name] {
			b.walk(dialer, byName, seen, group, global)
		}
		return
	}
	group(name)
	for _, member := range groupList(mapping, "proxies") {
		b.walk(member, byName, seen, group, global)
	}
	b.walk(groupString(mapping, "empty-fallback"), byName, seen, group, global)
	for _, p := range b.groupProviders(mapping) {
		for _, dialer := range b.providers[p].dialers {
			b.walk(dialer, byName, seen, group, global)
		}
	}
	if groupFlag(mapping, "include-all") || groupFlag(mapping, "include-all-proxies") {
		for _, proxy := range sortedKeys(b.proxyDialers) {
			b.walk(proxy, byName, seen, group, global)
		}
	}
}

var builtinProxyNames = []string{"DIRECT", "REJECT", "REJECT-DROP", "PASS", "COMPATIBLE"}

// The names a proxy may take as its dialer-proxy without any group holding
// mounts (taking) down its chain: a built-in one, or a base proxy or group
// whose every member and dialer, followed down, avoids them. A name the
// base does not define is never one.
func (b *mountBase) dialSafe(taking map[string]bool) map[string]bool {
	byName := b.groupsByName()
	safe := map[string]bool{}
	for _, name := range builtinProxyNames {
		safe[name] = true
	}
	candidates := append(sortedKeys(b.proxyTypes), sortedKeys(byName)...)
	if _, defined := byName[globalProxyName]; !defined {
		candidates = append(candidates, globalProxyName)
	}
	for _, name := range candidates {
		reaches := false
		b.walk(name, byName, map[string]bool{}, func(group string) {
			reaches = reaches || taking[group]
		}, func() {
			reaches = reaches || len(taking) > 0
		})
		safe[name] = !reaches
	}
	return safe
}

// Every target Tailscale traffic may be sent to, by how surely: a rule whose
// condition reaches it, everything in a sub-rule entered by one, a listener's
// proxy and the final MATCH of a listener's sub-rule, a tunnel's proxy to a
// Tailscale address.
func (b *mountBase) tailscaleTargets(reader *ruleReader) map[string]int {
	targets := map[string]int{}
	add := func(target string, kind int) {
		if target != "" && kind > targets[target] {
			targets[target] = kind
		}
	}
	for _, line := range b.rules {
		target, kind := reader.ruleTarget(line)
		if kind != ruleMisses {
			add(target, kind)
		}
	}
	entered := map[string]int{}
	enter := func(lines []string, carried int) bool {
		changed := false
		for _, line := range lines {
			tp, payload, target, _ := RC.ParseRulePayload(line, true)
			if tp != "SUB-RULE" {
				continue
			}
			kind := max(carried, reader.subRuleCondition(payload))
			if kind > entered[target] {
				entered[target], changed = kind, true
			}
		}
		return changed
	}
	for changed := enter(b.rules, ruleMisses); changed; {
		changed = false
		for name, kind := range entered {
			changed = enter(b.subRules[name], kind) || changed
		}
	}
	for name, kind := range entered {
		if kind == ruleMisses {
			continue
		}
		for _, line := range b.subRules[name] {
			if tp, _, target, _ := RC.ParseRulePayload(line, true); tp != "SUB-RULE" {
				add(target, kind)
			}
		}
	}
	for _, name := range b.listenerRules {
		for _, line := range b.subRules[name] {
			if tp, _, target, _ := RC.ParseRulePayload(line, true); tp == "MATCH" {
				add(target, ruleReaches)
			}
		}
	}
	for _, proxy := range b.listenerProxies {
		add(proxy, ruleReaches)
	}
	for _, tunnel := range b.tunnels {
		host, _, err := net.SplitHostPort(tunnel.target)
		if err != nil || flashguard.ProtectedHost(host) {
			add(tunnel.proxy, ruleReaches)
		}
	}
	return targets
}

// The names a mount node's dialer-proxy must not lead to: a Tailscale node,
// a group holding one, and a base proxy or group that relays through those.
// Only holding counts: a group a rule targets or one inside it relays nowhere.
func (b *mountBase) relayNames(holding map[string]string) map[string]bool {
	relay := map[string]bool{}
	for name, kind := range b.proxyTypes {
		if kind == "tailscale" {
			relay[name] = true
		}
	}
	for name := range holding {
		relay[name] = true
	}
	for changed := true; changed; {
		changed = false
		chained := false
		for name, dialers := range b.proxyDialers {
			if !relay[name] && slices.ContainsFunc(dialers, func(dialer string) bool { return relay[dialer] }) {
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
			members := append(groupList(group, "proxies"), groupString(group, "empty-fallback"))
			if all && chained || slices.ContainsFunc(members, func(member string) bool { return relay[member] }) ||
				slices.ContainsFunc(b.groupProviders(group), func(p string) bool { return b.providerRelays(p, relay) }) {
				relay[name], changed = true, true
			}
		}
	}
	return relay
}

func (b *mountBase) providerRelays(name string, relay map[string]bool) bool {
	p := b.providers[name]
	return p.unknown || slices.ContainsFunc(p.dialers, func(dialer string) bool { return relay[dialer] })
}

const (
	ruleMisses = iota
	ruleUnknown
	ruleReaches
)

type ruleSetContent struct {
	reaches bool
	unknown bool
	gated   bool
}

func readBaseRuleSets(ruleSets *yaml.Node) map[string]ruleSetContent {
	read := map[string]ruleSetContent{}
	reader := &ruleReader{suffixes: tailnetSuffixes()}
	for i := 0; i+1 < len(ruleSets.Content); i += 2 {
		var mapping map[string]any
		if resolveAlias(ruleSets.Content[i+1]).Decode(&mapping) != nil {
			read[ruleSets.Content[i].Value] = ruleSetContent{unknown: true}
			continue
		}
		read[ruleSets.Content[i].Value] = reader.readRuleSet(mapping)
	}
	return read
}

func (r *ruleReader) readRuleSet(mapping map[string]any) ruleSetContent {
	behavior, err := cp.ParseBehavior(providerString(mapping, "behavior"))
	if err != nil {
		return ruleSetContent{unknown: true}
	}
	var payload []string
	items, _ := providerOption(mapping, "payload").([]any)
	for _, item := range items {
		if line, ok := item.(string); ok {
			payload = append(payload, line)
		}
	}
	var strategy any
	switch kind := providerString(mapping, "type"); kind {
	case "inline":
		strategy = rp.ParseInlineRuleSet(payload, behavior, recordRule)
	case "file", "http":
		format, err := cp.ParseRuleFormat(providerString(mapping, "format"))
		if err != nil {
			return ruleSetContent{unknown: true}
		}
		path := providerString(mapping, "path")
		if path == "" && kind == "http" {
			path = constant.Path.GetPathByHash("rules", providerString(mapping, "url"))
		}
		buf, err := os.ReadFile(constant.Path.Resolve(path))
		if err != nil {
			return ruleSetContent{unknown: true}
		}
		if strategy, err = rp.ParseRuleSet(buf, behavior, format, recordRule); err != nil {
			return ruleSetContent{unknown: true}
		}
		content := r.ruleSetReach(strategy)
		// A payload is what the set holds until its file loads.
		if len(payload) > 0 {
			inline := r.ruleSetReach(rp.ParseInlineRuleSet(payload, behavior, recordRule))
			content.reaches = content.reaches || inline.reaches
			content.unknown = content.unknown || inline.unknown
		}
		content.gated = true
		return content
	default:
		return ruleSetContent{unknown: true}
	}
	return r.ruleSetReach(strategy)
}

func (r *ruleReader) ruleSetReach(strategy any) ruleSetContent {
	switch r.strategyReach(strategy) {
	case ruleReaches:
		return ruleSetContent{reaches: true}
	case ruleUnknown:
		return ruleSetContent{unknown: true}
	}
	return ruleSetContent{}
}

func (r *ruleReader) strategyReach(strategy any) int {
	switch typed := strategy.(type) {
	case interface{ ToIpCidr() *netipx.IPSet }:
		set := typed.ToIpCidr()
		if set != nil && slices.ContainsFunc(tailscaleProtectedPrefixes, set.OverlapsPrefix) {
			return ruleReaches
		}
	case interface{ Rules() []constant.Rule }:
		reach := ruleMisses
		for _, rule := range typed.Rules() {
			if recorded, ok := rule.(*recordedRule); ok {
				reach = max(reach, r.condition(recorded.tp, recorded.payload, recorded.params))
			}
		}
		return reach
	case interface {
		Match(*constant.Metadata, constant.RuleMatchHelper) bool
		DumpMrs(func(string) bool)
	}:
		for _, suffix := range r.suffixes {
			for _, host := range []string{suffix, "host." + suffix} {
				if typed.Match(&constant.Metadata{Host: host}, constant.RuleMatchHelper{}) {
					return ruleReaches
				}
			}
		}
		reach := ruleMisses
		typed.DumpMrs(func(key string) bool {
			key = strings.TrimLeft(strings.TrimPrefix(key, "+"), "*.")
			if slices.ContainsFunc(r.suffixes, func(suffix string) bool { return key == suffix || strings.HasSuffix(key, "."+suffix) }) {
				reach = ruleReaches
				return false
			}
			return true
		})
		return reach
	case nil:
		return ruleUnknown
	}
	return ruleMisses
}

// A classical or logic sub-rule as written, read without being built: a
// GEOIP or GEOSITE built here would load or download its database.
type recordedRule struct {
	tp      string
	payload string
	params  []string
}

func (r *recordedRule) RuleType() constant.RuleType { return constant.MATCH }

func (r *recordedRule) Match(*constant.Metadata, constant.RuleMatchHelper) (bool, string) {
	return false, ""
}

func (r *recordedRule) Adapter() string { return "" }

func (r *recordedRule) Payload() string { return r.payload }

func (r *recordedRule) ProviderNames() []string { return nil }

func recordRule(tp, payload, _ string, params []string, _ map[string][]constant.Rule) (constant.Rule, error) {
	return &recordedRule{tp: tp, payload: payload, params: params}, nil
}

type ruleReader struct {
	suffixes []string
	ruleSets map[string]ruleSetContent
	// The rule sets a rule reads to send something to a group.
	used map[string]bool
}

func newRuleReader(base *mountBase) *ruleReader {
	return &ruleReader{suffixes: tailnetSuffixes(), ruleSets: base.ruleSets, used: map[string]bool{}}
}

func (r *ruleReader) ruleTarget(line string) (string, int) {
	tp, payload, target, params := RC.ParseRulePayload(line, true)
	if target == "" || tp == "MATCH" || tp == "SUB-RULE" {
		return "", ruleMisses
	}
	return target, r.condition(tp, payload, params)
}

// What a SUB-RULE line's condition lets into its sub-rule.
func (r *ruleReader) subRuleCondition(payload string) int {
	reach := ruleMisses
	_, err := logic.NewSubRule(payload, "", nil, func(tp, payload, _ string, params []string, _ map[string][]constant.Rule) (constant.Rule, error) {
		reach = max(reach, r.condition(tp, payload, params))
		return &recordedRule{tp: tp, payload: payload}, nil
	})
	if err != nil {
		return ruleUnknown
	}
	return reach
}

func (r *ruleReader) condition(tp, payload string, params []string) int {
	if isSrc, _ := RC.ParseParams(params); isSrc {
		return ruleMisses
	}
	switch tp {
	case "IP-CIDR", "IP-CIDR6":
		prefix, err := netip.ParsePrefix(payload)
		if err != nil {
			return ruleUnknown
		}
		return reachIf(slices.ContainsFunc(tailscaleProtectedPrefixes, prefix.Masked().Overlaps))
	case "IP-SUFFIX":
		return r.ipSuffix(payload)
	case "GEOIP":
		return reachIf(strings.EqualFold(payload, "lan") || strings.EqualFold(payload, "private"))
	case "RULE-SET":
		if r.used != nil {
			r.used[payload] = true
		}
		content, ok := r.ruleSets[payload]
		switch {
		case !ok || content.unknown:
			return ruleUnknown
		case content.reaches:
			return ruleReaches
		}
		return ruleMisses
	case "NOT":
		return ruleReaches
	case "AND", "OR":
		reach := ruleMisses
		sub := func(tp, payload, _ string, params []string, _ map[string][]constant.Rule) (constant.Rule, error) {
			reach = max(reach, r.condition(tp, payload, params))
			return &recordedRule{tp: tp, payload: payload}, nil
		}
		var err error
		if tp == "AND" {
			_, err = logic.NewAND(payload, "", sub)
		} else {
			_, err = logic.NewOR(payload, "", sub)
		}
		if err != nil {
			return ruleUnknown
		}
		return reach
	}
	return r.domain(tp, payload)
}

func reachIf(reaches bool) int {
	if reaches {
		return ruleReaches
	}
	return ruleMisses
}

func (r *ruleReader) ipSuffix(payload string) int {
	rule, err := RC.NewIPSuffix(payload, "", false, true)
	if err != nil {
		return ruleUnknown
	}
	suffix, _ := netip.ParsePrefix(payload)
	return reachIf(slices.ContainsFunc(tailscaleProtectedPrefixes, func(prefix netip.Prefix) bool {
		candidate, ok := joinPrefixBits(prefix, suffix.Addr())
		if !ok {
			return false
		}
		matched, _ := rule.Match(&constant.Metadata{DstIP: candidate}, constant.RuleMatchHelper{})
		return matched
	}))
}

// Destination-agnostic rules (ports, processes, networks) are not read:
// like MATCH they are the profile's own catch-alls.
func (r *ruleReader) domain(tp, payload string) int {
	var rule constant.Rule
	var err error
	switch tp {
	case "GEOSITE":
		return r.geosite(payload)
	case "DOMAIN":
		rule = RC.NewDomain(payload, "")
	case "DOMAIN-SUFFIX":
		rule = RC.NewDomainSuffix(payload, "")
	case "DOMAIN-KEYWORD":
		rule = RC.NewDomainKeyword(payload, "")
	case "DOMAIN-REGEX":
		rule, err = RC.NewDomainRegex(payload, "")
	case "DOMAIN-WILDCARD":
		rule, err = RC.NewDomainWildcard(payload, "")
	default:
		return ruleMisses
	}
	if err != nil {
		return ruleUnknown
	}
	return reachIf(slices.ContainsFunc(r.suffixes, func(suffix string) bool {
		if tailscaleProfileRuleMatches(rule, TailscaleRouteTarget{Kind: tailscaleTargetSuffix, Value: suffix}, nil) {
			return true
		}
		matched, _ := rule.Match(&constant.Metadata{Host: "host." + suffix}, constant.RuleMatchHelper{})
		return matched
	}))
}

// A GEOSITE category is read from the database already on disk, never one
// it would download; without it the category is unknown.
func (r *ruleReader) geosite(payload string) int {
	if _, err := os.Stat(constant.Path.GeoSite()); err != nil {
		return ruleUnknown
	}
	matcher, err := geodata.LoadGeoSiteMatcher(payload)
	if err != nil {
		return ruleUnknown
	}
	return reachIf(slices.ContainsFunc(r.suffixes, func(suffix string) bool {
		return matcher.ApplyDomain(suffix) || matcher.ApplyDomain("host."+suffix)
	}))
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

// GLOBAL holds every proxy and group, so once anything relays it does too.
func newMountRelay(names map[string]bool, managed []string) *mountRelay {
	relay := &mountRelay{names: names, managed: managed}
	if relay.names == nil {
		relay.names = map[string]bool{}
	}
	if !relay.empty() {
		relay.names[globalProxyName] = true
	}
	return relay
}

func (r *mountRelay) reaches(name string) bool {
	return r != nil && name != "" && (r.names[name] || managedNameFamily(name, r.managed))
}

func (r *mountRelay) empty() bool {
	return r == nil || len(r.names) == 0 && len(r.managed) == 0
}

// What the mount provider drops a dialer-proxy by: exactly what reaches holds.
func (r *mountRelay) pattern() string {
	var parts []string
	for name := range r.names {
		parts = append(parts, regexp2.Escape(name))
	}
	slices.Sort(parts)
	for _, base := range r.managed {
		parts = append(parts, regexp2.Escape(base)+`(?: \(Flash(?: (?:[2-9]|[1-9][0-9]+))?\))?`)
	}
	return "^(?:" + strings.Join(parts, "|") + ")$"
}
