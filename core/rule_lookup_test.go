package core

import (
	"context"
	"net/netip"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/component/resolver"
	"github.com/metacubex/mihomo/component/resource"
	"github.com/metacubex/mihomo/component/trie"
	"github.com/metacubex/mihomo/constant"
	cp "github.com/metacubex/mihomo/constant/provider"
	"github.com/metacubex/mihomo/rules"
	"github.com/metacubex/mihomo/rules/common"
	rp "github.com/metacubex/mihomo/rules/provider"
	RW "github.com/metacubex/mihomo/rules/wrapper"
	"github.com/metacubex/mihomo/tunnel"
	D "github.com/miekg/dns"
)

// stubResolver answers every name with one address and counts the questions,
// so no test reaches the network.
type stubResolver struct {
	ip      netip.Addr
	queries atomic.Int32
}

func (r *stubResolver) answer() ([]netip.Addr, error) {
	r.queries.Add(1)
	return []netip.Addr{r.ip}, nil
}

func (r *stubResolver) LookupIP(context.Context, string) ([]netip.Addr, error) {
	return r.answer()
}
func (r *stubResolver) LookupIPv4(context.Context, string) ([]netip.Addr, error) {
	return r.answer()
}
func (r *stubResolver) LookupIPv6(context.Context, string) ([]netip.Addr, error) {
	return r.answer()
}
func (r *stubResolver) ResolveECH(context.Context, string) ([]byte, error) { return nil, nil }
func (r *stubResolver) ExchangeContext(context.Context, *D.Msg) (*D.Msg, error) {
	return nil, nil
}
func (r *stubResolver) Invalid() bool    { return true }
func (r *stubResolver) ClearCache()      {}
func (r *stubResolver) ResetConnection() {}

func withStubResolver(t *testing.T, ip string) *stubResolver {
	t.Helper()
	stub := &stubResolver{ip: netip.MustParseAddr(ip)}
	previous := resolver.DefaultResolver
	resolver.DefaultResolver = stub
	t.Cleanup(func() { resolver.DefaultResolver = previous })
	return stub
}

func withHosts(t *testing.T, host, ip string) {
	t.Helper()
	tree := trie.New[resolver.HostValue]()
	value, err := resolver.NewHostValue([]string{ip})
	if err != nil {
		t.Fatalf("NewHostValue: %v", err)
	}
	if err := tree.Insert(host, value); err != nil {
		t.Fatalf("Insert: %v", err)
	}
	previous := resolver.DefaultHosts
	resolver.DefaultHosts = resolver.NewHosts(tree)
	t.Cleanup(func() { resolver.DefaultHosts = previous })
}

type ruleWorld struct {
	proxies   map[string]constant.Proxy
	providers map[string]cp.RuleProvider
	subRules  map[string][]constant.Rule
}

func newRuleWorld(t *testing.T, proxies ...string) *ruleWorld {
	t.Helper()
	rp.SetTunnel(tunnel.Tunnel)
	world := &ruleWorld{
		proxies: map[string]constant.Proxy{
			"DIRECT": namedProxy("DIRECT"),
			"REJECT": adapter.NewProxy(outbound.NewReject()),
			"PASS":   adapter.NewProxy(outbound.NewPass()),
		},
		providers: map[string]cp.RuleProvider{},
		subRules:  map[string][]constant.Rule{},
	}
	for _, name := range proxies {
		world.proxies[name] = namedProxy(name)
	}
	return world
}

func (w *ruleWorld) parse(t *testing.T, line string) constant.Rule {
	t.Helper()
	tp, payload, target, params := common.ParseRulePayload(line, true)
	rule, err := rules.ParseRule(tp, payload, target, params, w.subRules)
	if err != nil {
		t.Fatalf("ParseRule(%q): %v", line, err)
	}
	return rule
}

func (w *ruleWorld) ruleSet(t *testing.T, name string, behavior cp.RuleBehavior, payload ...string) {
	t.Helper()
	provider := rp.NewRuleSetProvider(
		name, behavior, cp.YamlRule, 0,
		resource.NewFileVehicle(filepath.Join(t.TempDir(), name+".yaml")),
		nil, nil, rules.ParseRule,
	).(*rp.RuleSetProvider)
	body := "payload:\n"
	for _, entry := range payload {
		body += "  - '" + entry + "'\n"
	}
	if _, _, err := provider.SideUpdate([]byte(body)); err != nil {
		t.Fatalf("SideUpdate: %v", err)
	}
	w.providers[name] = provider
}

// apply installs the rules as a config would: each top-level rule wrapped.
func (w *ruleWorld) apply(t *testing.T, lines ...string) []constant.Rule {
	t.Helper()
	tunnel.UpdateProxies(w.proxies, nil)
	tunnel.UpdateRules(nil, w.subRules, w.providers)
	parsed := make([]constant.Rule, 0, len(lines))
	for _, line := range lines {
		parsed = append(parsed, RW.NewRuleWrapper(w.parse(t, line)))
	}
	tunnel.UpdateRules(parsed, w.subRules, w.providers)
	previousMode := tunnel.Mode()
	tunnel.SetMode(tunnel.Rule)
	isInit.Store(true)
	t.Cleanup(func() {
		isInit.Store(false)
		tunnel.SetMode(previousMode)
		tunnel.UpdateProxies(nil, nil)
		tunnel.UpdateRules(nil, nil, nil)
	})
	return parsed
}

func lookup(t *testing.T, host string, resolve bool) *RuleLookup {
	t.Helper()
	result, err := handleLookupRule(RuleLookupParams{Host: host, Resolve: &resolve})
	if err != nil {
		t.Fatalf("lookup %s: %v", host, err)
	}
	return result
}

func winnerIndex(result *RuleLookup) int {
	if result.Winner == nil {
		return -1
	}
	return result.Winner.Index
}

// realRoute asks the tunnel's own matcher, which counts and resolves as a
// connection would.
func realRoute(t *testing.T, host string) (string, int) {
	t.Helper()
	metadata, err := lookupMetadata(RuleLookupParams{Host: host})
	if err != nil {
		t.Fatal(err)
	}
	proxy, rule, err := tunnel.ResolveRouteRule(metadata)
	if err != nil {
		t.Fatalf("ResolveRouteRule: %v", err)
	}
	index := -1
	for i, candidate := range tunnel.RulesSnapshot().Rules {
		if wrapper, ok := candidate.(constant.RuleWrapper); ok && (constant.Rule(wrapper) == rule || wrapper.Unwrap() == rule) {
			index = i
		}
	}
	return proxy.Name(), index
}

func TestRuleLookupFindsTheWinnerAndWhatItShadows(t *testing.T) {
	world := newRuleWorld(t, "Proxy", "HK")
	world.ruleSet(t, "streaming", cp.Domain, "+.netflix.com", "nflxvideo.net")
	world.ruleSet(t, "mixed", cp.Classical, "DOMAIN-KEYWORD,flix", "IP-CIDR,10.0.0.0/8")
	world.apply(t,
		"DOMAIN-SUFFIX,added.example,Proxy", // an added rule
		"RULE-SET,streaming,HK",             // a rule-set
		"RULE-SET,mixed,Proxy",
		"DOMAIN-KEYWORD,netflix,DIRECT", // a subscription rule
		"MATCH,DIRECT",
	)

	added := lookup(t, "www.added.example", false)
	if winnerIndex(added) != 0 || added.Winner.Target != "Proxy" || added.Winner.Status != "winner" {
		t.Errorf("added rule lookup = %+v, want rule 0 to Proxy", added.Winner)
	}

	streaming := lookup(t, "www.netflix.com", false)
	if winnerIndex(streaming) != 1 || streaming.Winner.Entry != "+.netflix.com" {
		t.Fatalf("rule-set lookup winner = %+v, want rule 1 by +.netflix.com", streaming.Winner)
	}
	var shadowed []int
	for _, hit := range streaming.Matches {
		if hit.Status == "shadowed" {
			shadowed = append(shadowed, hit.Index)
		}
	}
	if len(shadowed) != 3 || shadowed[0] != 2 || shadowed[1] != 3 || shadowed[2] != 4 {
		t.Errorf("shadowed = %v, want the classical set, the keyword and MATCH", shadowed)
	}
	if mixed := streaming.Matches[1]; mixed.Entry != "DOMAIN-KEYWORD,flix" {
		t.Errorf("classical entry = %q, want the rule inside the set", mixed.Entry)
	}
	if len(streaming.RuleSets) != 2 || streaming.RuleSets[0].Name != "streaming" || streaming.RuleSets[0].Count != 2 {
		t.Errorf("rule sets = %+v, want both sets the lookup read", streaming.RuleSets)
	}
	if len(streaming.Chain) == 0 || streaming.Chain[0].Name != "HK" {
		t.Errorf("chain = %+v, want it to start at HK", streaming.Chain)
	}

	fallback := lookup(t, "example.org", false)
	if winnerIndex(fallback) != 4 || fallback.Winner.Type != "MATCH" {
		t.Errorf("fallback = %+v, want MATCH", fallback.Winner)
	}
}

func TestRuleLookupResolvesOnceForIPRules(t *testing.T) {
	world := newRuleWorld(t, "Proxy")
	world.apply(t,
		"DOMAIN,never.example,Proxy",
		"IP-CIDR,203.0.113.0/24,Proxy",
		"IP-CIDR,198.51.100.0/24,REJECT",
		"MATCH,DIRECT",
	)
	stub := withStubResolver(t, "203.0.113.7")

	unresolved := lookup(t, "cdn.example", false)
	if stub.queries.Load() != 0 {
		t.Fatalf("resolve=false asked the resolver %d times", stub.queries.Load())
	}
	if winnerIndex(unresolved) != 3 || len(unresolved.Uncertain) != 2 || unresolved.Uncertain[0].Reason != "ip" {
		t.Errorf("without resolving = winner %+v uncertain %+v, want MATCH behind two IP rules it cannot read", unresolved.Winner, unresolved.Uncertain)
	}

	resolved := lookup(t, "cdn.example", true)
	if got := stub.queries.Load(); got != 1 {
		t.Errorf("resolve=true asked the resolver %d times, want once", got)
	}
	if winnerIndex(resolved) != 1 || resolved.IP != "203.0.113.7" || resolved.IPSource != "dns" || len(resolved.Uncertain) != 0 {
		t.Errorf("resolved = %+v ip %s from %s, want the first IP rule by DNS", resolved.Winner, resolved.IP, resolved.IPSource)
	}

	withHosts(t, "hosted.example", "198.51.100.9")
	hosted := lookup(t, "hosted.example", true)
	if winnerIndex(hosted) != 2 || hosted.IPSource != "hosts" {
		t.Errorf("hosts lookup = %+v from %s, want the second IP rule by hosts", hosted.Winner, hosted.IPSource)
	}
	if got := stub.queries.Load(); got != 1 {
		t.Errorf("a hosts entry still asked the resolver (%d queries)", got)
	}

	ip := lookup(t, "198.51.100.1", true)
	if winnerIndex(ip) != 2 || ip.IPSource != "input" {
		t.Errorf("ip lookup = %+v from %s, want the second IP rule from the input", ip.Winner, ip.IPSource)
	}
}

func TestRuleLookupSetsAsideWhatItCannotKnow(t *testing.T) {
	world := newRuleWorld(t, "Proxy")
	world.apply(t,
		"PROCESS-NAME,curl,Proxy",
		"AND,((NETWORK,UDP),(DOMAIN,example.com)),REJECT",
		"SRC-IP-CIDR,192.168.0.0/16,Proxy",
		"DOMAIN,example.com,DIRECT",
		"PROCESS-NAME,late,Proxy",
	)
	result := lookup(t, "example.com", false)
	if winnerIndex(result) != 3 {
		t.Fatalf("winner = %+v, want rule 3", result.Winner)
	}
	reasons := []string{}
	for _, hit := range result.Uncertain {
		reasons = append(reasons, hit.Reason)
	}
	if strings.Join(reasons, ",") != "process,network,source" {
		t.Errorf("uncertain reasons = %v, want process,network,source before the winner only", reasons)
	}

	known, err := handleLookupRule(RuleLookupParams{Host: "example.com", Network: "tcp"})
	if err != nil {
		t.Fatal(err)
	}
	if len(known.Uncertain) != 2 {
		t.Errorf("with the network given, uncertain = %+v, want the AND decided", known.Uncertain)
	}
}

func TestRuleLookupPassesAndSkipsMissingProviders(t *testing.T) {
	world := newRuleWorld(t, "Proxy")
	world.providers["gone"] = nil
	world.ruleSet(t, "empty", cp.Domain)
	world.apply(t,
		"DOMAIN,example.com,PASS",
		"RULE-SET,empty,Proxy",
		"DOMAIN-SUFFIX,com,Proxy",
	)
	delete(world.providers, "gone")

	result := lookup(t, "example.com", false)
	if len(result.Matches) != 2 || result.Matches[0].Status != "pass" || winnerIndex(result) != 2 {
		t.Errorf("matches = %+v, want the PASS rule then the winner", result.Matches)
	}
	if len(result.RuleSets) != 1 || result.RuleSets[0].Name != "empty" || result.RuleSets[0].Count != 0 {
		t.Errorf("rule sets = %+v, want the empty set reported", result.RuleSets)
	}

	tunnel.UpdateRules(tunnel.RulesSnapshot().Rules, nil, map[string]cp.RuleProvider{})
	missing := lookup(t, "example.com", false)
	if len(missing.RuleSets) != 1 || missing.RuleSets[0].Status != "absent" {
		t.Errorf("rule sets = %+v, want the missing set marked absent", missing.RuleSets)
	}
	if winnerIndex(missing) != 2 {
		t.Errorf("winner = %+v with the provider gone, want rule 2", missing.Winner)
	}
}

func TestRuleLookupWalksSubRules(t *testing.T) {
	world := newRuleWorld(t, "Proxy", "HK")
	world.subRules["inner"] = []constant.Rule{
		world.parse(t, "DOMAIN,skip.example.com,PASS"),
		world.parse(t, "PROCESS-NAME,curl,HK"),
		world.parse(t, "DOMAIN-SUFFIX,example.com,Proxy"),
	}
	world.subRules["plain"] = []constant.Rule{
		world.parse(t, "DOMAIN-SUFFIX,example.org,HK"),
	}
	world.apply(t,
		"SUB-RULE,(DOMAIN-SUFFIX,example.org),plain",
		"SUB-RULE,(DOMAIN-SUFFIX,example.com),inner",
		"MATCH,DIRECT",
	)

	plain := lookup(t, "www.example.org", false)
	if winnerIndex(plain) != 0 || plain.Winner.Target != "HK" || plain.Winner.Entry != "DOMAIN-SUFFIX,example.org,HK" {
		t.Errorf("sub-rule = %+v, want rule 0 to HK", plain.Winner)
	}

	stopped := lookup(t, "www.example.com", false)
	if winnerIndex(stopped) != 2 || len(stopped.Uncertain) != 1 || stopped.Uncertain[0].Index != 1 || stopped.Uncertain[0].Reason != "process" {
		t.Errorf("sub-rule walk = winner %+v uncertain %+v, want it to stop at the process rule", stopped.Winner, stopped.Uncertain)
	}
}

func TestRuleLookupLeavesCountersAlone(t *testing.T) {
	world := newRuleWorld(t, "Proxy")
	parsed := world.apply(t, "DOMAIN-KEYWORD,example,Proxy", "MATCH,DIRECT")
	lookup(t, "example.com", false)
	lookup(t, "other.org", false)
	for i, rule := range parsed {
		wrapper := rule.(constant.RuleWrapper)
		if wrapper.HitCount() != 0 || wrapper.MissCount() != 0 {
			t.Errorf("rule %d counted %d hits %d misses from a lookup", i, wrapper.HitCount(), wrapper.MissCount())
		}
	}
}

func TestRuleLookupAgreesWithTheTunnel(t *testing.T) {
	world := newRuleWorld(t, "Proxy", "HK", "JP")
	world.ruleSet(t, "ads", cp.Domain, "+.ads.example", "tracker.example.net")
	world.ruleSet(t, "lan", cp.IPCIDR, "10.0.0.0/8", "192.168.0.0/16")
	world.ruleSet(t, "classic", cp.Classical, "DOMAIN-SUFFIX,jp.example", "IP-CIDR,203.0.113.0/24")
	world.subRules["sub"] = []constant.Rule{world.parse(t, "DOMAIN-KEYWORD,video,JP")}
	world.apply(t,
		"RULE-SET,ads,REJECT",
		"DOMAIN,pass.example.com,PASS",
		"RULE-SET,classic,JP",
		"SUB-RULE,(DOMAIN-SUFFIX,stream.example),sub",
		"OR,((DOMAIN,a.example),(DOMAIN-SUFFIX,b.example)),HK",
		"RULE-SET,lan,DIRECT,no-resolve",
		"NOT,((DOMAIN-SUFFIX,example.com)),Proxy",
		"DOMAIN-SUFFIX,example.com,HK",
		"MATCH,DIRECT",
	)
	withHosts(t, "router.example.com", "192.168.1.1")
	withStubResolver(t, "198.51.100.1")
	hosts := []string{
		"x.ads.example", "tracker.example.net", "pass.example.com", "www.jp.example",
		"video.stream.example", "audio.stream.example", "b.example", "a.example",
		"www.example.com", "10.1.2.3", "router.example.com", "8.8.8.8",
	}
	for _, host := range hosts {
		name, index := realRoute(t, host)
		got := lookup(t, host, true)
		gotName := ""
		if len(got.Chain) > 0 {
			gotName = got.Chain[0].Name
		}
		if winnerIndex(got) != index || gotName != name || len(got.Uncertain) != 0 {
			t.Errorf("%s: lookup says rule %d via %s (uncertain %+v), the tunnel rule %d via %s",
				host, winnerIndex(got), gotName, got.Uncertain, index, name)
		}
	}
}

func TestRuleListAndEntries(t *testing.T) {
	world := newRuleWorld(t, "Proxy")
	world.ruleSet(t, "streaming", cp.Domain, "+.netflix.com", "nflxvideo.net", ".hulu.com")
	world.apply(t,
		"RULE-SET,streaming,Proxy",
		"AND,((DOMAIN,a.example),(NETWORK,TCP)),Proxy",
		"MATCH,DIRECT",
	)

	list, err := handleListRules(RuleListParams{})
	if err != nil {
		t.Fatal(err)
	}
	if list.Total != 3 || list.Rules[0].RuleSet == nil || list.Rules[0].RuleSet.Count != 3 || list.Rules[0].RuleSet.Status != "ok" {
		t.Fatalf("list = %+v, want the rule set described", list.Rules)
	}
	if got := list.Rules[1].Payload; got != "((DOMAIN,a.example),(NETWORK,tcp))" {
		t.Errorf("logic payload = %q, want the config spelling", got)
	}

	if got := list.Rules[1].RulePayload; got == "" {
		t.Errorf("rule payload left out, want mihomo's own spelling for request matching")
	}

	filtered, err := handleListRules(RuleListParams{Filter: "hulu"})
	if err != nil {
		t.Fatal(err)
	}
	if len(filtered.Rules) != 0 || len(filtered.Filtered) != 1 || filtered.SetMatches["streaming"] != 1 {
		t.Errorf("filtered = %+v, want the set found by its entry", filtered)
	}

	page, err := handleRuleSetEntries(RuleSetEntriesParams{Name: "streaming", Offset: 1, Limit: 1})
	if err != nil {
		t.Fatal(err)
	}
	if page.Total != 3 || page.Matched != 3 || len(page.Entries) != 1 || page.Entries[0] != ".hulu.com" {
		t.Errorf("page = %+v, want the second sorted entry", page)
	}
	if _, err := handleRuleSetEntries(RuleSetEntriesParams{Name: "../etc/passwd"}); err == nil {
		t.Errorf("a name that is no rule set was read")
	}
}

func TestRuleMethodsWaitForTheCore(t *testing.T) {
	isInit.Store(false)
	if _, err := handleLookupRule(RuleLookupParams{Host: "example.com"}); err != errNotInitialized {
		t.Errorf("lookup before init = %v", err)
	}
	if _, err := handleListRules(RuleListParams{}); err != errNotInitialized {
		t.Errorf("list before init = %v", err)
	}
}
