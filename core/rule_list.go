package core

import (
	"os"
	"strings"
	"time"

	C "github.com/metacubex/mihomo/constant"
	cp "github.com/metacubex/mihomo/constant/provider"
	"github.com/metacubex/mihomo/rules/logic"
	"github.com/metacubex/mihomo/tunnel"
)

const ruleSetEntriesMaxLimit = 500

type RuleSetView struct {
	Name      string    `json:"name"`
	Behavior  string    `json:"behavior"`
	Count     int       `json:"count"`
	UpdatedAt time.Time `json:"updated-at"`
	Vehicle   string    `json:"vehicle"`
	// ok, missing (no file was ever loaded), failed (a file is there but
	// nothing loaded from it) or absent (the config holds no such provider).
	Status   string `json:"status"`
	Interval int64  `json:"interval"`
}

type RuleView struct {
	Index    int    `json:"index"`
	Type     string `json:"type"`
	RuleType string `json:"rule-type"`
	Payload  string `json:"payload"`
	// mihomo's own rendering, as a request's rulePayload carries it, when it
	// differs from Payload.
	RulePayload string       `json:"rule-payload,omitempty"`
	Target      string       `json:"target"`
	Disabled    bool         `json:"disabled,omitempty"`
	Managed     bool         `json:"managed,omitempty"`
	RuleSet     *RuleSetView `json:"rule-set,omitempty"`
}

type RuleListParams struct {
	Filter string `json:"filter,omitempty"`
}

type RuleList struct {
	CoreEpoch     uint64 `json:"core-epoch"`
	Mode          string `json:"mode"`
	ManagedPrefix int    `json:"managed-prefix"`
	Total         int    `json:"total"`
	// Left out when filtering: the host keeps the list it read unfiltered.
	Rules []RuleView `json:"rules,omitempty"`
	// The rules whose text, or whose rule set's entries, hold the filter.
	Filtered   []int          `json:"filtered,omitempty"`
	SetMatches map[string]int `json:"set-matches,omitempty"`
}

type RuleSetEntriesParams struct {
	Name   string `json:"name"`
	Offset int    `json:"offset"`
	Limit  int    `json:"limit"`
	Filter string `json:"filter,omitempty"`
}

type RuleSetEntries struct {
	CoreEpoch uint64   `json:"core-epoch"`
	Name      string   `json:"name"`
	Behavior  string   `json:"behavior"`
	Total     int      `json:"total"`
	Matched   int      `json:"matched"`
	Offset    int      `json:"offset"`
	Entries   []string `json:"entries"`
}

// The spelling a config uses for each rule type; IP-CIDR6 reads as IP-CIDR.
var ruleConfigNames = map[C.RuleType]string{
	C.Domain:              "DOMAIN",
	C.DomainSuffix:        "DOMAIN-SUFFIX",
	C.DomainKeyword:       "DOMAIN-KEYWORD",
	C.DomainRegex:         "DOMAIN-REGEX",
	C.DomainWildcard:      "DOMAIN-WILDCARD",
	C.GEOSITE:             "GEOSITE",
	C.GEOIP:               "GEOIP",
	C.SrcGEOIP:            "SRC-GEOIP",
	C.IPASN:               "IP-ASN",
	C.SrcIPASN:            "SRC-IP-ASN",
	C.IPCIDR:              "IP-CIDR",
	C.SrcIPCIDR:           "SRC-IP-CIDR",
	C.IPSuffix:            "IP-SUFFIX",
	C.SrcIPSuffix:         "SRC-IP-SUFFIX",
	C.SrcPort:             "SRC-PORT",
	C.DstPort:             "DST-PORT",
	C.InPort:              "IN-PORT",
	C.DSCP:                "DSCP",
	C.InUser:              "IN-USER",
	C.InName:              "IN-NAME",
	C.InType:              "IN-TYPE",
	C.ProcessName:         "PROCESS-NAME",
	C.ProcessPath:         "PROCESS-PATH",
	C.ProcessNameRegex:    "PROCESS-NAME-REGEX",
	C.ProcessPathRegex:    "PROCESS-PATH-REGEX",
	C.ProcessNameWildcard: "PROCESS-NAME-WILDCARD",
	C.ProcessPathWildcard: "PROCESS-PATH-WILDCARD",
	C.RematchName:         "REMATCH-NAME",
	C.RuleSet:             "RULE-SET",
	C.Network:             "NETWORK",
	C.Uid:                 "UID",
	C.SubRules:            "SUB-RULE",
	C.MATCH:               "MATCH",
	C.AND:                 "AND",
	C.OR:                  "OR",
	C.NOT:                 "NOT",
}

func ruleConfigName(rule C.Rule) string {
	if name, ok := ruleConfigNames[rule.RuleType()]; ok {
		return name
	}
	return strings.ToUpper(rule.RuleType().String())
}

func unwrapRule(rule C.Rule) (C.Rule, bool) {
	if wrapper, ok := rule.(C.RuleWrapper); ok {
		return wrapper.Unwrap(), wrapper.IsDisabled()
	}
	return rule, false
}

// mihomo renders a logic rule's payload with its own type names; this one
// reads as the config wrote it.
func rulePayload(rule C.Rule) string {
	combined, ok := rule.(*logic.Logic)
	if !ok || rule.RuleType() == C.SubRules {
		return rule.Payload()
	}
	parts := make([]string, 0, len(combined.Rules()))
	for _, inner := range combined.Rules() {
		parts = append(parts, "("+ruleText(inner)+")")
	}
	return "(" + strings.Join(parts, ",") + ")"
}

func ruleText(rule C.Rule) string {
	if rule.RuleType() == C.MATCH {
		return "MATCH"
	}
	return ruleConfigName(rule) + "," + rulePayload(rule)
}

func ruleSetView(name string, providers map[string]cp.RuleProvider) *RuleSetView {
	view := &RuleSetView{Name: name, Status: "absent"}
	provider, ok := providers[name]
	if !ok || provider == nil {
		return view
	}
	view.Behavior = strings.ToLower(provider.Behavior().String())
	view.Vehicle = provider.VehicleType().String()
	if provider.Strategy() != nil {
		view.Count = provider.Count()
	}
	if timed, ok := provider.(interface{ UpdatedAt() time.Time }); ok {
		view.UpdatedAt = timed.UpdatedAt()
	}
	if periodic, ok := provider.(interface{ Interval() time.Duration }); ok {
		view.Interval = int64(periodic.Interval() / time.Second)
	}
	view.Status = "ok"
	if provider.VehicleType() == cp.Inline || provider.VehicleType() == cp.Compatible {
		return view
	}
	if view.UpdatedAt.IsZero() && view.Count == 0 {
		view.Status = "missing"
		if held, ok := provider.(interface{ Vehicle() cp.Vehicle }); ok {
			if _, err := os.Stat(held.Vehicle().Path()); err == nil {
				view.Status = "failed"
			}
		}
	}
	return view
}

func ruleView(index int, raw C.Rule, providers map[string]cp.RuleProvider) RuleView {
	rule, disabled := unwrapRule(raw)
	_, managed := rule.(*tailscaleManagedRule)
	view := RuleView{
		Index:    index,
		Type:     ruleConfigName(rule),
		RuleType: rule.RuleType().String(),
		Payload:  rulePayload(rule),
		Target:   rule.Adapter(),
		Disabled: disabled,
		Managed:  managed,
	}
	if raw := rule.Payload(); raw != view.Payload {
		view.RulePayload = raw
	}
	if rule.RuleType() == C.RuleSet {
		view.RuleSet = ruleSetView(rule.Payload(), providers)
	}
	return view
}

func managedPrefix(rules []C.Rule) int {
	count := 0
	for _, raw := range rules {
		rule, _ := unwrapRule(raw)
		if _, ok := rule.(*tailscaleManagedRule); !ok {
			break
		}
		count++
	}
	return count
}

func handleListRules(params RuleListParams) (*RuleList, error) {
	if !isInit.Load() {
		return nil, errNotInitialized
	}
	epoch, _ := routeStamp()
	state := tunnel.RulesSnapshot()
	list := &RuleList{
		CoreEpoch:     epoch,
		Mode:          state.Mode.String(),
		ManagedPrefix: managedPrefix(state.Rules),
		Total:         len(state.Rules),
	}
	filter := strings.ToLower(strings.TrimSpace(params.Filter))
	if filter == "" {
		list.Rules = make([]RuleView, 0, len(state.Rules))
		for index, raw := range state.Rules {
			list.Rules = append(list.Rules, ruleView(index, raw, state.RuleProviders))
		}
		return list, nil
	}
	list.Filtered = []int{}
	list.SetMatches = map[string]int{}
	counted := map[string]int{}
	for index, raw := range state.Rules {
		view := ruleView(index, raw, state.RuleProviders)
		text := strings.ToLower(view.Type + "," + view.Payload + "," + view.Target)
		hit := strings.Contains(text, filter)
		if view.RuleSet != nil {
			name := view.RuleSet.Name
			count, seen := counted[name]
			if !seen {
				count = countRuleSetEntries(state.RuleProviders[name], filter)
				counted[name] = count
			}
			if count > 0 {
				list.SetMatches[name] = count
				hit = true
			}
		}
		if hit {
			list.Filtered = append(list.Filtered, index)
		}
	}
	return list, nil
}

// eachRuleSetEntry walks what a loaded rule set holds as its file would write
// it: a classical set by rule, a domain set by key ("+.x" covers x and its
// subdomains, ".x" only the subdomains) in sorted order, an IP set by CIDR.
func eachRuleSetEntry(provider cp.RuleProvider, f func(entry string) bool) {
	if provider == nil {
		return
	}
	switch strategy := provider.Strategy().(type) {
	case interface{ Rules() []C.Rule }:
		for _, rule := range strategy.Rules() {
			if !f(ruleText(rule)) {
				return
			}
		}
	case interface{ DumpMrs(func(string) bool) }:
		strategy.DumpMrs(f)
	}
}

func countRuleSetEntries(provider cp.RuleProvider, filter string) int {
	count := 0
	eachRuleSetEntry(provider, func(entry string) bool {
		if strings.Contains(strings.ToLower(entry), filter) {
			count++
		}
		return true
	})
	return count
}

// A rule set is read by the name the running config gave it, never by a
// path: the Core may run as root.
func handleRuleSetEntries(params RuleSetEntriesParams) (*RuleSetEntries, error) {
	if !isInit.Load() {
		return nil, errNotInitialized
	}
	epoch, _ := routeStamp()
	provider, ok := tunnel.RuleProvidersSnapshot()[params.Name]
	if !ok || provider == nil {
		return nil, &MethodError{Code: "rule_set_not_found", Message: "no rule set named " + params.Name}
	}
	limit := params.Limit
	if limit <= 0 || limit > ruleSetEntriesMaxLimit {
		limit = ruleSetEntriesMaxLimit
	}
	offset := max(params.Offset, 0)
	filter := strings.ToLower(strings.TrimSpace(params.Filter))
	result := &RuleSetEntries{
		CoreEpoch: epoch,
		Name:      params.Name,
		Behavior:  strings.ToLower(provider.Behavior().String()),
		Offset:    offset,
		Entries:   []string{},
	}
	eachRuleSetEntry(provider, func(entry string) bool {
		result.Total++
		if filter != "" && !strings.Contains(strings.ToLower(entry), filter) {
			return true
		}
		if result.Matched >= offset && len(result.Entries) < limit {
			result.Entries = append(result.Entries, entry)
		}
		result.Matched++
		return true
	})
	return result, nil
}
