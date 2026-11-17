package core

import (
	"context"
	"net/netip"
	"strings"

	"github.com/metacubex/mihomo/component/resolver"
	"github.com/metacubex/mihomo/component/trie"
	C "github.com/metacubex/mihomo/constant"
	cp "github.com/metacubex/mihomo/constant/provider"
	"github.com/metacubex/mihomo/rules/logic"
	rp "github.com/metacubex/mihomo/rules/provider"
	"github.com/metacubex/mihomo/tunnel"
)

type RuleLookupParams struct {
	Host    string `json:"host"`
	Port    uint16 `json:"port,omitempty"`
	Network string `json:"network,omitempty"`
	// Nil resolves: one query through the Core's own resolver, as a rule
	// needing the address would make for a real connection.
	Resolve *bool `json:"resolve,omitempty"`
}

type ChainHop struct {
	Name string `json:"name"`
	Type string `json:"type"`
}

type RuleHit struct {
	RuleView
	// winner, shadowed, pass, no-adapter, no-udp or uncertain.
	Status string `json:"status"`
	// What an uncertain rule waits on: process, port, network, inbound,
	// source, dscp, uid, ip or rematch.
	Reason string `json:"reason,omitempty"`
	Detail string `json:"detail,omitempty"`
	// The entry of a rule set, or the rule of a SUB-RULE list, that matched.
	Entry string `json:"entry,omitempty"`
}

type RuleLookup struct {
	CoreEpoch     uint64 `json:"core-epoch"`
	Mode          string `json:"mode"`
	Host          string `json:"host,omitempty"`
	IP            string `json:"ip,omitempty"`
	IPSource      string `json:"ip-source,omitempty"`
	ResolveError  string `json:"resolve-error,omitempty"`
	ResolveWanted bool   `json:"resolve-wanted"`
	Port          uint16 `json:"port"`
	Network       string `json:"network"`
	ManagedPrefix int    `json:"managed-prefix"`
	Total         int    `json:"total"`
	// Nil when no rule decided: the mode did, nothing matched, or a REMATCH
	// left the answer to a dial this lookup does not make.
	Winner       *RuleHit      `json:"winner,omitempty"`
	Undetermined string        `json:"undetermined,omitempty"`
	Chain        []ChainHop    `json:"chain"`
	Matches      []RuleHit     `json:"matches"`
	Uncertain    []RuleHit     `json:"uncertain"`
	RuleSets     []RuleSetView `json:"rule-sets"`
}

type verdict int

const (
	verdictNo verdict = iota
	verdictYes
	verdictUnknown
)

type evaluation struct {
	verdict verdict
	adapter string
	reason  string
	detail  string
	entry   string
}

type ruleLookup struct {
	state        tunnel.RulesState
	metadata     *C.Metadata
	resolve      bool
	resolved     bool
	ipSource     string
	resolveErr   string
	portKnown    bool
	networkKnown bool
	neededIP     bool
	neededProc   bool
	ruleSets     map[string]bool
	ruleSetOrder []string
	// The rule sets read up to and including the winner; the ones read
	// after it, for the rules it shadows, cannot change the answer.
	setsAtWinner int
}

func (l *ruleLookup) helper() C.RuleMatchHelper {
	return C.RuleMatchHelper{
		ResolveIP: func() {
			l.neededIP = true
			if !l.resolve || l.resolved || l.metadata.Host == "" || l.metadata.Resolved() {
				return
			}
			l.resolved = true
			ctx, cancel := context.WithTimeout(resolver.WithInitiator(context.Background(), resolver.InitiatorRule), resolver.DefaultDNSTimeout)
			defer cancel()
			ip, err := resolver.ResolveIP(ctx, l.metadata.Host)
			if err != nil {
				l.resolveErr = err.Error()
				return
			}
			l.metadata.DstIP = ip
			l.ipSource = "dns"
		},
		FindProcess: func() {
			l.neededProc = true
		},
		CheckPassRule: func(adapterName string) bool {
			adapter, ok := l.state.Proxies[adapterName]
			if !ok {
				return false
			}
			for a := adapter; a != nil; a = a.Unwrap(l.metadata, false) {
				if a.Type() == C.PassRule {
					return true
				}
			}
			return false
		},
	}
}

// What a rule reads that a lookup cannot know: who sent the connection, from
// where, and through which inbound.
func (l *ruleLookup) runtimeReason(rule C.Rule) string {
	switch rule.RuleType() {
	case C.ProcessName, C.ProcessPath, C.ProcessNameRegex, C.ProcessPathRegex,
		C.ProcessNameWildcard, C.ProcessPathWildcard:
		return "process"
	case C.Uid:
		return "uid"
	case C.SrcPort, C.InPort:
		return "port"
	case C.DstPort:
		if !l.portKnown {
			return "port"
		}
	case C.Network:
		if !l.networkKnown {
			return "network"
		}
	case C.InUser, C.InName, C.InType:
		return "inbound"
	case C.DSCP:
		return "dscp"
	case C.SrcGEOIP, C.SrcIPASN, C.SrcIPCIDR, C.SrcIPSuffix:
		return "source"
	case C.RematchName:
		return "rematch"
	}
	return ""
}

func (l *ruleLookup) eval(rule C.Rule, helper C.RuleMatchHelper) evaluation {
	// Matching through a wrapper would count a hit the Core never routed.
	rule, disabled := unwrapRule(rule)
	if disabled {
		return evaluation{verdict: verdictNo}
	}
	if reason := l.runtimeReason(rule); reason != "" {
		return evaluation{verdict: verdictUnknown, adapter: rule.Adapter(), reason: reason, detail: rule.Payload()}
	}
	switch typed := rule.(type) {
	case *rp.RuleSet:
		return l.evalRuleSet(typed, helper)
	case *logic.Logic:
		return l.evalLogic(typed, helper)
	}
	l.neededIP, l.neededProc = false, false
	matched, adapter := rule.Match(l.metadata, helper)
	switch {
	case l.neededProc:
		return evaluation{verdict: verdictUnknown, adapter: rule.Adapter(), reason: "process", detail: rule.Payload()}
	case !matched && l.neededIP && !l.metadata.DstIP.IsValid():
		return evaluation{verdict: verdictUnknown, adapter: rule.Adapter(), reason: "ip", detail: rule.Payload()}
	case matched:
		return evaluation{verdict: verdictYes, adapter: adapter}
	}
	return evaluation{verdict: verdictNo}
}

func (l *ruleLookup) noteRuleSet(name string) {
	if !l.ruleSets[name] {
		l.ruleSets[name] = true
		l.ruleSetOrder = append(l.ruleSetOrder, name)
	}
}

func (l *ruleLookup) evalRuleSet(rule *rp.RuleSet, helper C.RuleMatchHelper) evaluation {
	name := rule.Payload()
	l.noteRuleSet(name)
	provider, ok := l.state.RuleProviders[name]
	if !ok || provider == nil {
		return evaluation{verdict: verdictNo}
	}
	isSrc, noResolve := rule.Options()
	if isSrc {
		return evaluation{verdict: verdictUnknown, adapter: rule.Adapter(), reason: "source", detail: name}
	}
	if noResolve {
		helper.ResolveIP = nil
	}
	if classical, ok := provider.Strategy().(interface{ Rules() []C.Rule }); ok {
		var unknown *evaluation
		for _, inner := range classical.Rules() {
			result := l.eval(inner, helper)
			switch result.verdict {
			case verdictYes:
				return evaluation{verdict: verdictYes, adapter: rule.Adapter(), entry: ruleText(inner)}
			case verdictUnknown:
				if unknown == nil {
					result.adapter = rule.Adapter()
					result.detail = ruleText(inner)
					unknown = &result
				}
			}
		}
		if unknown != nil {
			return *unknown
		}
		return evaluation{verdict: verdictNo}
	}
	result := l.eval(&ruleSetLeaf{rule}, helper)
	if result.verdict == verdictYes {
		result.entry = ruleSetEntryOf(provider, l.metadata)
	}
	return result
}

// ruleSetLeaf lets a domain or IP rule set be matched as a plain rule.
type ruleSetLeaf struct{ *rp.RuleSet }

func (l *ruleLookup) evalLogic(rule *logic.Logic, helper C.RuleMatchHelper) evaluation {
	children := rule.Rules()
	switch rule.RuleType() {
	case C.NOT:
		inner := l.eval(children[0], helper)
		switch inner.verdict {
		case verdictNo:
			return evaluation{verdict: verdictYes, adapter: rule.Adapter()}
		case verdictYes:
			return evaluation{verdict: verdictNo}
		}
		return evaluation{verdict: verdictUnknown, adapter: rule.Adapter(), reason: inner.reason, detail: inner.detail}
	case C.OR:
		var unknown *evaluation
		for _, child := range children {
			result := l.eval(child, helper)
			if result.verdict == verdictYes {
				return evaluation{verdict: verdictYes, adapter: rule.Adapter()}
			}
			if result.verdict == verdictUnknown && unknown == nil {
				unknown = &evaluation{verdict: verdictUnknown, adapter: rule.Adapter(), reason: result.reason, detail: result.detail}
			}
		}
		if unknown != nil {
			return *unknown
		}
		return evaluation{verdict: verdictNo}
	case C.AND:
		var unknown *evaluation
		for _, child := range children {
			result := l.eval(child, helper)
			if result.verdict == verdictNo {
				return evaluation{verdict: verdictNo}
			}
			if result.verdict == verdictUnknown && unknown == nil {
				unknown = &evaluation{verdict: verdictUnknown, adapter: rule.Adapter(), reason: result.reason, detail: result.detail}
			}
		}
		if unknown != nil {
			return *unknown
		}
		return evaluation{verdict: verdictYes, adapter: rule.Adapter()}
	case C.SubRules:
		condition := l.eval(children[0], helper)
		if condition.verdict != verdictYes {
			condition.adapter = rule.Adapter()
			return condition
		}
		return l.evalSubRules(rule.Adapter(), helper)
	}
	return evaluation{verdict: verdictNo}
}

// As matchSubRules walks a sub-rule list: the first rule that matches decides
// unless its target passes, and one that may match stops the walk unanswered.
func (l *ruleLookup) evalSubRules(name string, helper C.RuleMatchHelper) evaluation {
	for _, rule := range l.state.SubRules[name] {
		result := l.eval(rule, helper)
		switch result.verdict {
		case verdictNo:
			continue
		case verdictUnknown:
			if result.detail == "" {
				result.detail = ruleText(rule)
			}
			return result
		}
		adapter := result.adapter
		if adapter == "PASS-RULE" || helper.CheckPassRule != nil && helper.CheckPassRule(adapter) {
			continue
		}
		entry := ruleText(rule) + "," + rule.Adapter()
		if result.entry != "" {
			entry = result.entry
		}
		return evaluation{verdict: verdictYes, adapter: adapter, entry: entry}
	}
	return evaluation{verdict: verdictNo}
}

// Which entry of a domain or IP rule set holds the target, when one can be
// named; the set itself has already said that one does.
func ruleSetEntryOf(provider cp.RuleProvider, metadata *C.Metadata) string {
	switch provider.Behavior() {
	case cp.Domain:
		host := strings.ToLower(metadata.RuleHost())
		if host == "" {
			return ""
		}
		var found string
		eachRuleSetEntry(provider, func(key string) bool {
			core := strings.TrimLeft(key, "+.")
			if !strings.Contains(key, "*") && host != core && !strings.HasSuffix(host, "."+core) {
				return true
			}
			var builder trie.DomainSetBuilder
			if builder.Insert(key) != nil || !builder.Build().Has(host) {
				return true
			}
			found = key
			return false
		})
		return found
	case cp.IPCIDR:
		ip := metadata.DstIP
		if !ip.IsValid() {
			return ""
		}
		var found string
		eachRuleSetEntry(provider, func(entry string) bool {
			if prefix, err := netip.ParsePrefix(entry); err == nil && prefix.Contains(ip.WithZone("").Unmap()) {
				found = entry
				return false
			}
			return true
		})
		return found
	}
	return ""
}

func lookupChain(proxy C.Proxy, metadata *C.Metadata) []ChainHop {
	var chain []ChainHop
	for proxy != nil {
		chain = append(chain, ChainHop{Name: proxy.Name(), Type: proxy.Type().String()})
		if proxy.Type() == C.LoadBalance {
			break
		}
		proxy = proxy.Unwrap(metadata, false)
	}
	return chain
}

func lookupMetadata(params RuleLookupParams) (*C.Metadata, error) {
	host := strings.TrimSpace(params.Host)
	host = strings.TrimSuffix(strings.TrimPrefix(host, "["), "]")
	if host == "" {
		return nil, &MethodError{Code: "invalid_arguments", Message: "a host or IP is required"}
	}
	metadata := &C.Metadata{
		NetWork: C.TCP,
		// Not INNER: rules and process lookup treat the Core's own
		// connections apart, and this stands for an app's.
		Type:    C.HTTP,
		DNSMode: C.DNSNormal,
		Host:    strings.TrimSuffix(strings.ToLower(host), "."),
		DstPort: params.Port,
	}
	if strings.EqualFold(params.Network, "udp") {
		metadata.NetWork = C.UDP
	}
	if metadata.DstPort == 0 {
		metadata.DstPort = 443
	}
	return metadata, nil
}

func handleLookupRule(params RuleLookupParams) (*RuleLookup, error) {
	if !isInit.Load() {
		return nil, errNotInitialized
	}
	epoch, _ := routeStamp()
	metadata, err := lookupMetadata(params)
	if err != nil {
		return nil, err
	}
	state := tunnel.RulesSnapshot()
	lookup := &ruleLookup{
		state:        state,
		metadata:     metadata,
		resolve:      params.Resolve == nil || *params.Resolve,
		portKnown:    params.Port != 0,
		networkKnown: params.Network != "",
		ruleSets:     map[string]bool{},
	}
	inputIP := false
	if _, parseErr := netip.ParseAddr(metadata.Host); parseErr == nil {
		inputIP = true
	}
	if err := tunnel.PrepareMetadata(metadata); err != nil {
		return nil, &MethodError{Code: "lookup_failed", Message: err.Error()}
	}
	switch {
	case inputIP && metadata.Host != "":
		lookup.ipSource = "mapping"
	case inputIP:
		lookup.ipSource = "input"
	}
	if metadata.Host != "" {
		if node, ok := resolver.DefaultHosts.Search(metadata.Host, false); ok {
			metadata.DstIP, _ = node.RandIP()
			lookup.resolved = true
			lookup.ipSource = "hosts"
		}
	}
	result := &RuleLookup{
		CoreEpoch:     epoch,
		Mode:          state.Mode.String(),
		ResolveWanted: lookup.resolve,
		Port:          metadata.DstPort,
		Network:       metadata.NetWork.String(),
		ManagedPrefix: managedPrefix(state.Rules),
		Total:         len(state.Rules),
		Matches:       []RuleHit{},
		Uncertain:     []RuleHit{},
		RuleSets:      []RuleSetView{},
	}
	switch state.Mode {
	case tunnel.Direct:
		result.Chain = lookupChain(state.Proxies["DIRECT"], metadata)
	case tunnel.Global:
		result.Chain = lookupChain(state.Proxies["GLOBAL"], metadata)
	default:
		lookup.matchRules(result)
	}
	result.Host = metadata.Host
	if metadata.DstIP.IsValid() {
		result.IP = metadata.DstIP.String()
	}
	result.IPSource = lookup.ipSource
	result.ResolveError = lookup.resolveErr
	sets := lookup.ruleSetOrder
	if result.Winner != nil {
		sets = sets[:lookup.setsAtWinner]
	}
	for _, name := range sets {
		result.RuleSets = append(result.RuleSets, *ruleSetView(name, state.RuleProviders))
	}
	return result, nil
}

// The loop of tunnel.match, read without dialing or counting: rules a lookup
// cannot decide are set aside, and those after the winner are still read so
// the ones it shadows can be named.
func (l *ruleLookup) matchRules(result *RuleLookup) {
	helper := l.helper()
	metadata := l.metadata
	decided := false
rules:
	for index, raw := range l.state.Rules {
		rule, disabled := unwrapRule(raw)
		if disabled {
			continue
		}
		evaluated := l.eval(rule, helper)
		hit := RuleHit{
			RuleView: ruleView(index, raw, l.state.RuleProviders),
			Reason:   evaluated.reason,
			Detail:   evaluated.detail,
			Entry:    evaluated.entry,
		}
		if evaluated.verdict == verdictUnknown {
			if !decided {
				hit.Status = "uncertain"
				result.Uncertain = append(result.Uncertain, hit)
			}
			continue
		}
		if evaluated.verdict != verdictYes {
			continue
		}
		if decided {
			hit.Status = "shadowed"
			result.Matches = append(result.Matches, hit)
			continue
		}
		adapter, ok := l.state.Proxies[evaluated.adapter]
		if !ok {
			hit.Status = "no-adapter"
			result.Matches = append(result.Matches, hit)
			continue
		}
		for hop := adapter; hop != nil; hop = hop.Unwrap(metadata, false) {
			switch hop.Type() {
			case C.Pass:
				hit.Status = "pass"
				result.Matches = append(result.Matches, hit)
				continue rules
			case C.Rematch:
				hit.Status = "uncertain"
				hit.Reason = "rematch"
				hit.Detail = hop.Name()
				result.Uncertain = append(result.Uncertain, hit)
				result.Undetermined = "rematch"
				return
			}
		}
		if metadata.NetWork == C.UDP && !adapter.SupportUDP() {
			hit.Status = "no-udp"
			result.Matches = append(result.Matches, hit)
			continue
		}
		hit.Status = "winner"
		hit.Target = evaluated.adapter
		winner := hit
		result.Winner = &winner
		result.Matches = append(result.Matches, hit)
		result.Chain = lookupChain(adapter, metadata)
		decided = true
		l.setsAtWinner = len(l.ruleSetOrder)
	}
	if !decided {
		result.Chain = lookupChain(l.state.Proxies["DIRECT"], metadata)
	}
}
