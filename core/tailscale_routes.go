package core

import (
	"cmp"
	"encoding/json"
	"errors"
	"net/netip"
	"os"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"

	"github.com/metacubex/mihomo/adapter/outboundgroup"
	C "github.com/metacubex/mihomo/constant"
)

// Routing for panel-added accounts. Every target (a device address, a full
// device name or a network suffix) goes to the one account proven to own it;
// a target with no proven owner, or more than one, is rejected, and so is the
// rest of the Tailscale ranges. Owners and user choices are kept on disk, so a
// restart or an account still loading never frees a target to another one.

const (
	tailscaleTargetIP     = "ip"
	tailscaleTargetFQDN   = "fqdn"
	tailscaleTargetSuffix = "suffix"

	tailscaleOwnerManaged = "managed"
	tailscaleOwnerProfile = "profile"

	tailscaleRouteBound       = "bound"
	tailscaleRouteAssigned    = "assigned"
	tailscaleRouteConflict    = "conflict"
	tailscaleRouteUnconfirmed = "unconfirmed"
	tailscaleRouteReconfirm   = "reconfirm"
	tailscaleRouteUnavailable = "unavailable"

	tailscaleProtectedSuffix = "ts.net"
	tailscaleRejectProxy     = "REJECT"
	tailscaleRoutesVersion   = 1
)

var tailscaleProtectedPrefixes = []netip.Prefix{
	netip.MustParsePrefix("100.64.0.0/10"),
	netip.MustParsePrefix("fd7a:115c:a1e0::/48"),
}

var errTailscaleAssignInvalid = &MethodError{
	Code:    "tailscale_assign_invalid",
	Message: "the target or the account is not a candidate for it any more",
}

var errTailscaleProfileNotCurrent = &MethodError{
	Code:    "tailscale_profile_not_current",
	Message: "the profile is not the one the Core runs",
}

type TailscaleRouteTarget struct {
	Kind  string `json:"kind"`
	Value string `json:"value"`
}

func (t TailscaleRouteTarget) key() string { return t.Kind + ":" + t.Value }

// A managed owner is a panel-added account by its ID; a profile owner is one
// of the profile's own Tailscale proxies, which a rule of its routes there.
type TailscaleRouteOwner struct {
	Kind string `json:"kind"`
	ID   string `json:"id"`
}

// What tells one account from another: never the email, which only labels it.
type TailscaleRouteIdentity struct {
	UserID     string `json:"user-id"`
	Tailnet    string `json:"tailnet"`
	ControlURL string `json:"control-url"`
	LoginName  string `json:"login-name,omitempty"`
}

func (i TailscaleRouteIdentity) same(other TailscaleRouteIdentity) bool {
	return i.UserID == other.UserID && i.Tailnet == other.Tailnet && i.ControlURL == other.ControlURL
}

type tailscaleRouteBinding struct {
	Target   TailscaleRouteTarget    `json:"target"`
	Owner    TailscaleRouteOwner     `json:"owner"`
	Identity *TailscaleRouteIdentity `json:"identity,omitempty"`
	// The user chose it; an automatic one was the only owner seen.
	Assigned bool `json:"assigned"`
}

type tailscaleRouteClash struct {
	Target TailscaleRouteTarget  `json:"target"`
	Owners []TailscaleRouteOwner `json:"owners"`
}

type tailscaleRouteMemory struct {
	Version   int                               `json:"version"`
	Accounts  map[string]TailscaleRouteIdentity `json:"accounts"`
	Bindings  []tailscaleRouteBinding           `json:"bindings"`
	Conflicts []tailscaleRouteClash             `json:"conflicts"`
	Suffixes  []string                          `json:"suffixes"`
	// Each account's last device list, still claiming while it is signed out.
	Lists map[string]tailscaleRouteList `json:"lists,omitempty"`
}

type tailscaleRouteList struct {
	Suffix string               `json:"suffix,omitempty"`
	Peers  []tailscaleRoutePeer `json:"peers,omitempty"`
}

func newTailscaleRouteMemory() *tailscaleRouteMemory {
	return &tailscaleRouteMemory{Version: tailscaleRoutesVersion, Accounts: map[string]TailscaleRouteIdentity{}}
}

func (m *tailscaleRouteMemory) clone() *tailscaleRouteMemory {
	buf, _ := json.Marshal(m)
	copied := newTailscaleRouteMemory()
	_ = json.Unmarshal(buf, copied)
	if copied.Accounts == nil {
		copied.Accounts = map[string]TailscaleRouteIdentity{}
	}
	return copied
}

func (m *tailscaleRouteMemory) equal(other *tailscaleRouteMemory) bool {
	a, _ := json.Marshal(m)
	b, _ := json.Marshal(other)
	return string(a) == string(b)
}

type tailscaleRoutePeer struct {
	Name  string       `json:"name,omitempty"`
	FQDN  string       `json:"fqdn,omitempty"`
	Addrs []netip.Addr `json:"addrs,omitempty"`
}

// One account's device list, read from its running node.
type tailscaleRouteNetmap struct {
	Identity TailscaleRouteIdentity
	Suffix   string
	Peers    []tailscaleRoutePeer
}

// An attached account as the routing sees it; Live is nil until its node has
// reported a device list for the instance now running.
type tailscaleRouteAccount struct {
	ID        string
	Proxy     string
	LoggedOut bool
	Available bool
	Live      *tailscaleRouteNetmap
}

// A rule of the profile that sends something to one of its own Tailscale
// proxies, or to a group holding one; a managed target it covers is a
// conflict, not taken silently. A name target carries its device addresses.
type tailscaleProfileRoute struct {
	Proxy string
	Rule  string
	Match func(TailscaleRouteTarget, []netip.Addr) bool
}

type tailscaleRouteDecision struct {
	// Empty leaves the connection to the rules after the managed ones.
	Proxy string
}

type tailscaleSuffixDecision struct {
	suffix   string
	decision tailscaleRouteDecision
}

type tailscaleRouteTable struct {
	ips             map[netip.Addr]tailscaleRouteDecision
	fqdns           map[string]tailscaleRouteDecision
	suffixes        []tailscaleSuffixDecision
	protectSuffixes []string
	profileRules    []C.Rule
}

type TailscaleRouteCandidate struct {
	Owner   TailscaleRouteOwner `json:"owner"`
	Device  string              `json:"device,omitempty"`
	Label   string              `json:"label,omitempty"`
	Tailnet string              `json:"tailnet,omitempty"`
	Rule    string              `json:"rule,omitempty"`
	// The account is no longer in the profile.
	Removed bool `json:"removed"`
}

type TailscaleRouteTargetReport struct {
	Target     TailscaleRouteTarget      `json:"target"`
	State      string                    `json:"state"`
	Owner      *TailscaleRouteOwner      `json:"owner,omitempty"`
	Candidates []TailscaleRouteCandidate `json:"candidates"`
}

type TailscaleRouteAccountReport struct {
	ID        string                  `json:"id"`
	Proxy     string                  `json:"proxy"`
	Identity  *TailscaleRouteIdentity `json:"identity,omitempty"`
	Fresh     bool                    `json:"fresh"`
	Available bool                    `json:"available"`
	LoggedOut bool                    `json:"logged-out"`
	// Set only when the suffix is routed to this account.
	Domain    string `json:"domain,omitempty"`
	Addresses int    `json:"addresses"`
}

type TailscaleRoutes struct {
	ProfileID int64 `json:"profile-id"`
	// The managed rules are in the running config.
	Active bool `json:"active"`
	// Every attached, signed-in account has a device list for its running node.
	Complete bool `json:"complete"`
	// What the routing remembers is on disk.
	Saved bool `json:"saved"`
	// The kept routing could not be read; every target is blocked meanwhile.
	Unreadable        bool                          `json:"unreadable"`
	Revision          uint64                        `json:"revision"`
	Accounts          []TailscaleRouteAccountReport `json:"accounts"`
	Targets           []TailscaleRouteTargetReport  `json:"targets"`
	ProtectedPrefixes []string                      `json:"protected-prefixes"`
	ProtectedSuffixes []string                      `json:"protected-suffixes"`
}

func ipTarget(addr netip.Addr) TailscaleRouteTarget {
	return TailscaleRouteTarget{Kind: tailscaleTargetIP, Value: addr.Unmap().String()}
}

func normalizeTailscaleHost(host string) string {
	return strings.TrimSuffix(strings.ToLower(strings.TrimSpace(host)), ".")
}

type tailscaleSeen struct {
	target  TailscaleRouteTarget
	owners  []TailscaleRouteOwner
	devices map[TailscaleRouteOwner]string
	rules   map[TailscaleRouteOwner]string
	addrs   []netip.Addr
}

func (s *tailscaleSeen) add(owner TailscaleRouteOwner, device, rule string) {
	if !slices.Contains(s.owners, owner) {
		s.owners = append(s.owners, owner)
	}
	if device != "" && s.devices[owner] == "" {
		s.devices[owner] = device
	}
	if rule != "" && s.rules[owner] == "" {
		s.rules[owner] = rule
	}
}

type tailscaleRouteResult struct {
	table  *tailscaleRouteTable
	memory *tailscaleRouteMemory
	report *TailscaleRoutes
}

func sortTailscaleOwners(owners []TailscaleRouteOwner) {
	slices.SortFunc(owners, func(a, b TailscaleRouteOwner) int {
		return cmp.Or(cmp.Compare(a.Kind, b.Kind), cmp.Compare(a.ID, b.ID))
	})
}

// Works out every target's owner from what the accounts report now and what
// was kept before; the memory returned is what must be kept next.
func computeTailscaleRoutes(memory *tailscaleRouteMemory, accounts []tailscaleRouteAccount, profile []tailscaleProfileRoute) tailscaleRouteResult {
	next := memory.clone()
	byID := map[string]*tailscaleRouteAccount{}
	complete := true
	lists := map[string]tailscaleRouteList{}
	for i := range accounts {
		account := &accounts[i]
		byID[account.ID] = account
		switch list, kept := next.Lists[account.ID]; {
		case account.Live != nil:
			next.Accounts[account.ID] = account.Live.Identity
			lists[account.ID] = tailscaleRouteList{Suffix: account.Live.Suffix, Peers: account.Live.Peers}
		case account.LoggedOut && kept:
			lists[account.ID] = list
		default:
			complete = false
			if kept {
				lists[account.ID] = list
			}
		}
	}
	next.Lists = nil
	for id, list := range lists {
		if next.Lists == nil {
			next.Lists = map[string]tailscaleRouteList{}
		}
		next.Lists[id] = list
	}
	identityOf := func(id string) (TailscaleRouteIdentity, bool) {
		if account := byID[id]; account != nil && account.Live != nil {
			return account.Live.Identity, true
		}
		identity, ok := next.Accounts[id]
		return identity, ok
	}

	seen := map[string]*tailscaleSeen{}
	see := func(target TailscaleRouteTarget, owner TailscaleRouteOwner, device, rule string) *tailscaleSeen {
		entry := seen[target.key()]
		if entry == nil {
			entry = &tailscaleSeen{target: target, devices: map[TailscaleRouteOwner]string{}, rules: map[TailscaleRouteOwner]string{}}
			seen[target.key()] = entry
		}
		if owner != (TailscaleRouteOwner{}) {
			entry.add(owner, device, rule)
		}
		return entry
	}
	addAddrs := func(entry *tailscaleSeen, addrs []netip.Addr) {
		for _, addr := range addrs {
			if !slices.Contains(entry.addrs, addr) {
				entry.addrs = append(entry.addrs, addr)
			}
		}
	}
	for _, account := range accounts {
		list, ok := lists[account.ID]
		// A kept list claims only for a signed-out account.
		if !ok || (account.Live == nil && !account.LoggedOut) {
			continue
		}
		owner := TailscaleRouteOwner{Kind: tailscaleOwnerManaged, ID: account.ID}
		var suffixEntry *tailscaleSeen
		if suffix := normalizeTailscaleHost(list.Suffix); suffix != "" {
			suffixEntry = see(TailscaleRouteTarget{Kind: tailscaleTargetSuffix, Value: suffix}, owner, "", "")
			if !slices.Contains(next.Suffixes, suffix) {
				next.Suffixes = append(next.Suffixes, suffix)
			}
		}
		for _, peer := range list.Peers {
			if fqdn := normalizeTailscaleHost(peer.FQDN); fqdn != "" {
				addAddrs(see(TailscaleRouteTarget{Kind: tailscaleTargetFQDN, Value: fqdn}, owner, peer.Name, ""), peer.Addrs)
			}
			if suffixEntry != nil {
				addAddrs(suffixEntry, peer.Addrs)
			}
			for _, addr := range peer.Addrs {
				see(ipTarget(addr), owner, peer.Name, "")
			}
		}
	}
	for _, entry := range seen {
		for _, route := range profile {
			if route.Match != nil && route.Match(entry.target, entry.addrs) {
				entry.add(TailscaleRouteOwner{Kind: tailscaleOwnerProfile, ID: route.Proxy}, "", route.Rule)
			}
		}
	}

	bindings := map[string]tailscaleRouteBinding{}
	for _, binding := range next.Bindings {
		bindings[binding.Target.key()] = binding
		see(binding.Target, binding.Owner, "", "")
	}
	conflicts := map[string]tailscaleRouteClash{}
	for _, conflict := range next.Conflicts {
		conflicts[conflict.Target.key()] = conflict
		for _, owner := range conflict.Owners {
			see(conflict.Target, owner, "", "")
		}
	}

	table := &tailscaleRouteTable{
		ips:             map[netip.Addr]tailscaleRouteDecision{},
		fqdns:           map[string]tailscaleRouteDecision{},
		protectSuffixes: []string{tailscaleProtectedSuffix},
	}
	report := &TailscaleRoutes{
		Complete: complete,
		Accounts: []TailscaleRouteAccountReport{},
		Targets:  []TailscaleRouteTargetReport{},
	}
	serve := func(binding tailscaleRouteBinding, addrs []netip.Addr) (tailscaleRouteDecision, string) {
		if binding.Owner.Kind == tailscaleOwnerProfile {
			// Sent straight to the profile's proxy, never left to rules that
			// may now send it elsewhere; gone from the profile, it is blocked.
			if slices.ContainsFunc(profile, func(route tailscaleProfileRoute) bool {
				return route.Proxy == binding.Owner.ID && route.Match != nil && route.Match(binding.Target, addrs)
			}) {
				return tailscaleRouteDecision{Proxy: binding.Owner.ID}, ""
			}
			return tailscaleRouteDecision{Proxy: tailscaleRejectProxy}, tailscaleRouteUnavailable
		}
		account := byID[binding.Owner.ID]
		if identity, ok := identityOf(binding.Owner.ID); ok && binding.Identity != nil && !binding.Identity.same(identity) {
			return tailscaleRouteDecision{Proxy: tailscaleRejectProxy}, tailscaleRouteReconfirm
		}
		if account == nil || account.LoggedOut || !account.Available {
			return tailscaleRouteDecision{Proxy: tailscaleRejectProxy}, tailscaleRouteUnavailable
		}
		return tailscaleRouteDecision{Proxy: account.Proxy}, ""
	}

	keys := make([]string, 0, len(seen))
	for key := range seen {
		keys = append(keys, key)
	}
	slices.Sort(keys)
	next.Bindings = next.Bindings[:0]
	next.Conflicts = next.Conflicts[:0]
	for _, key := range keys {
		entry := seen[key]
		sortTailscaleOwners(entry.owners)
		binding, bound := bindings[key]
		conflict, conflicted := conflicts[key]
		state := ""
		var decision tailscaleRouteDecision
		var owner *TailscaleRouteOwner
		switch {
		case bound && binding.Assigned:
			decision, state = serve(binding, entry.addrs)
			if state == "" {
				state = tailscaleRouteAssigned
			}
			owner = &binding.Owner
		case len(entry.owners) > 1 || conflicted:
			state = tailscaleRouteConflict
			decision = tailscaleRouteDecision{Proxy: tailscaleRejectProxy}
		case bound:
			decision, state = serve(binding, entry.addrs)
			if state == "" {
				state = tailscaleRouteBound
			}
			owner = &binding.Owner
		case complete && len(entry.owners) == 1 && entry.owners[0].Kind == tailscaleOwnerManaged:
			binding = tailscaleRouteBinding{Target: entry.target, Owner: entry.owners[0]}
			if identity, ok := identityOf(binding.Owner.ID); ok {
				binding.Identity = &identity
			}
			bound = true
			decision, state = serve(binding, entry.addrs)
			if state == "" {
				state = tailscaleRouteBound
			}
			owner = &binding.Owner
		default:
			state = tailscaleRouteUnconfirmed
			decision = tailscaleRouteDecision{Proxy: tailscaleRejectProxy}
		}
		if bound && (binding.Assigned || state != tailscaleRouteConflict) {
			next.Bindings = append(next.Bindings, binding)
		}
		if state == tailscaleRouteConflict || conflicted {
			conflict.Target = entry.target
			conflict.Owners = mergeTailscaleOwners(conflict.Owners, entry.owners)
			next.Conflicts = append(next.Conflicts, conflict)
		}

		switch entry.target.Kind {
		case tailscaleTargetIP:
			if addr, err := netip.ParseAddr(entry.target.Value); err == nil {
				table.ips[addr] = decision
			}
		case tailscaleTargetFQDN:
			table.fqdns[entry.target.Value] = decision
		case tailscaleTargetSuffix:
			table.suffixes = append(table.suffixes, tailscaleSuffixDecision{suffix: entry.target.Value, decision: decision})
		}

		targetReport := TailscaleRouteTargetReport{Target: entry.target, State: state, Owner: owner, Candidates: []TailscaleRouteCandidate{}}
		for _, candidate := range entry.owners {
			item := TailscaleRouteCandidate{Owner: candidate, Device: entry.devices[candidate], Rule: entry.rules[candidate]}
			if candidate.Kind == tailscaleOwnerManaged {
				if identity, ok := identityOf(candidate.ID); ok {
					item.Label, item.Tailnet = identity.LoginName, identity.Tailnet
				}
				item.Removed = byID[candidate.ID] == nil
			} else {
				item.Label = candidate.ID
			}
			targetReport.Candidates = append(targetReport.Candidates, item)
		}
		report.Targets = append(report.Targets, targetReport)
	}
	if len(next.Bindings) == 0 {
		next.Bindings = nil
	}
	if len(next.Conflicts) == 0 {
		next.Conflicts = nil
	}
	next.Suffixes = slices.DeleteFunc(next.Suffixes, func(suffix string) bool {
		return !tailscaleSuffixKept(suffix, lists, next)
	})
	if len(next.Suffixes) == 0 {
		next.Suffixes = nil
	}
	slices.Sort(next.Suffixes)
	for _, suffix := range next.Suffixes {
		if suffix != tailscaleProtectedSuffix && !strings.HasSuffix(suffix, "."+tailscaleProtectedSuffix) {
			table.protectSuffixes = append(table.protectSuffixes, suffix)
		}
	}
	slices.SortStableFunc(table.suffixes, func(a, b tailscaleSuffixDecision) int {
		return cmp.Compare(len(b.suffix), len(a.suffix))
	})

	for _, account := range accounts {
		item := TailscaleRouteAccountReport{
			ID:        account.ID,
			Proxy:     account.Proxy,
			Fresh:     account.Live != nil,
			Available: account.Available && !account.LoggedOut,
			LoggedOut: account.LoggedOut,
		}
		if identity, ok := identityOf(account.ID); ok {
			item.Identity = &identity
		}
		for _, target := range report.Targets {
			if target.Owner == nil || target.Owner.Kind != tailscaleOwnerManaged || target.Owner.ID != account.ID {
				continue
			}
			if target.State != tailscaleRouteBound && target.State != tailscaleRouteAssigned {
				continue
			}
			switch target.Target.Kind {
			case tailscaleTargetIP:
				item.Addresses++
			case tailscaleTargetSuffix:
				item.Domain = target.Target.Value
			}
		}
		report.Accounts = append(report.Accounts, item)
	}
	for _, prefix := range tailscaleProtectedPrefixes {
		report.ProtectedPrefixes = append(report.ProtectedPrefixes, prefix.String())
	}
	report.ProtectedSuffixes = append([]string(nil), table.protectSuffixes...)
	return tailscaleRouteResult{table: table, memory: next, report: report}
}

// A suffix stays blocked while an account or a kept binding refers to it.
func tailscaleSuffixKept(suffix string, lists map[string]tailscaleRouteList, memory *tailscaleRouteMemory) bool {
	under := func(target TailscaleRouteTarget) bool {
		return target.Kind != tailscaleTargetIP && (target.Value == suffix || strings.HasSuffix(target.Value, "."+suffix))
	}
	for _, list := range lists {
		if normalizeTailscaleHost(list.Suffix) == suffix {
			return true
		}
	}
	return slices.ContainsFunc(memory.Bindings, func(b tailscaleRouteBinding) bool { return under(b.Target) }) ||
		slices.ContainsFunc(memory.Conflicts, func(c tailscaleRouteClash) bool { return under(c.Target) })
}

func mergeTailscaleOwners(a, b []TailscaleRouteOwner) []TailscaleRouteOwner {
	merged := append([]TailscaleRouteOwner(nil), a...)
	for _, owner := range b {
		if !slices.Contains(merged, owner) {
			merged = append(merged, owner)
		}
	}
	sortTailscaleOwners(merged)
	return merged
}

type TailscaleRouteAssignment struct {
	Target TailscaleRouteTarget `json:"target"`
	Owner  TailscaleRouteOwner  `json:"owner"`
}

// Each choice must name a candidate the report offers for its target and an
// account whose identity is known, which the binding keeps from then on.
func assignTailscaleRoutes(memory *tailscaleRouteMemory, report *TailscaleRoutes, accounts []tailscaleRouteAccount, assignments []TailscaleRouteAssignment) (*tailscaleRouteMemory, error) {
	next := memory.clone()
	attached := map[string]bool{}
	for _, account := range accounts {
		attached[account.ID] = true
		if account.Live != nil {
			next.Accounts[account.ID] = account.Live.Identity
		}
	}
	targets := map[string]TailscaleRouteTargetReport{}
	for _, target := range report.Targets {
		targets[target.Target.key()] = target
	}
	for _, assignment := range assignments {
		target, ok := targets[assignment.Target.key()]
		if !ok || !slices.ContainsFunc(target.Candidates, func(c TailscaleRouteCandidate) bool {
			return c.Owner == assignment.Owner && !c.Removed
		}) {
			return nil, errTailscaleAssignInvalid
		}
		binding := tailscaleRouteBinding{Target: target.Target, Owner: assignment.Owner, Assigned: true}
		if assignment.Owner.Kind == tailscaleOwnerManaged {
			identity, known := next.Accounts[assignment.Owner.ID]
			if !known || !attached[assignment.Owner.ID] {
				return nil, errTailscaleAssignInvalid
			}
			binding.Identity = &identity
		}
		next.Bindings = slices.DeleteFunc(next.Bindings, func(b tailscaleRouteBinding) bool {
			return b.Target.key() == binding.Target.key()
		})
		next.Bindings = append(next.Bindings, binding)
	}
	return next, nil
}

func (t *tailscaleRouteTable) matchHost(host string) (tailscaleRouteDecision, bool, bool) {
	host = normalizeTailscaleHost(host)
	if host == "" {
		return tailscaleRouteDecision{}, false, false
	}
	if decision, ok := t.fqdns[host]; ok {
		return decision, true, false
	}
	for _, suffix := range t.suffixes {
		if host == suffix.suffix || strings.HasSuffix(host, "."+suffix.suffix) {
			return suffix.decision, true, false
		}
	}
	for _, suffix := range t.protectSuffixes {
		if host == suffix || strings.HasSuffix(host, "."+suffix) {
			return tailscaleRouteDecision{Proxy: tailscaleRejectProxy}, true, true
		}
	}
	return tailscaleRouteDecision{}, false, false
}

func (t *tailscaleRouteTable) matchIP(addr netip.Addr) (tailscaleRouteDecision, bool, bool) {
	if !addr.IsValid() {
		return tailscaleRouteDecision{}, false, false
	}
	addr = addr.Unmap().WithZone("")
	if decision, ok := t.ips[addr]; ok {
		return decision, true, false
	}
	for _, prefix := range tailscaleProtectedPrefixes {
		if prefix.Contains(addr) {
			return tailscaleRouteDecision{Proxy: tailscaleRejectProxy}, true, true
		}
	}
	return tailscaleRouteDecision{}, false, false
}

// The table one config's managed rules read; each config has its own.
type tailscaleRouteSlot = atomic.Pointer[tailscaleRouteTable]

const (
	tailscaleRuleHost = iota
	tailscaleRuleIP
)

// The two managed rules at the head of the rules: one for names, one for
// addresses. Neither resolves a name; a target no account owns goes to the
// profile's own Tailscale proxy when one of its rules sends it there, and is
// rejected otherwise.
type tailscaleManagedRule struct {
	kind int
	slot *tailscaleRouteSlot
}

func (r *tailscaleManagedRule) Match(metadata *C.Metadata, helper C.RuleMatchHelper) (bool, string) {
	if r.slot == nil {
		return false, ""
	}
	table := r.slot.Load()
	if table == nil {
		return false, ""
	}
	var (
		decision         tailscaleRouteDecision
		matched, protect bool
	)
	if r.kind == tailscaleRuleHost {
		decision, matched, protect = table.matchHost(metadata.Host)
	} else {
		decision, matched, protect = table.matchIP(metadata.DstIP)
	}
	if !matched || decision.Proxy == "" {
		return false, ""
	}
	if protect {
		unresolved := C.RuleMatchHelper{FindProcess: helper.FindProcess, CheckPassRule: helper.CheckPassRule}
		for _, rule := range table.profileRules {
			if ok, adapter := rule.Match(metadata, unresolved); ok {
				return true, adapter
			}
		}
	}
	return true, decision.Proxy
}

func (r *tailscaleManagedRule) RuleType() C.RuleType {
	if r.kind == tailscaleRuleHost {
		return C.DomainSuffix
	}
	return C.IPCIDR
}

func (r *tailscaleManagedRule) Adapter() string { return "Tailscale (FlClash)" }

func (r *tailscaleManagedRule) Payload() string {
	if r.kind == tailscaleRuleHost {
		return "tailscale-managed-domains"
	}
	return "tailscale-managed-addresses"
}

func (r *tailscaleManagedRule) ProviderNames() []string { return nil }

// Rules whose payload names exactly what they match.
var tailscaleProfileRuleTypes = []C.RuleType{
	C.Domain, C.DomainSuffix, C.DomainKeyword, C.DomainRegex, C.DomainWildcard, C.IPCIDR, C.IPSuffix,
}

func tailscaleProfileRuleIsIP(rule C.Rule) bool {
	return rule.RuleType() == C.IPCIDR || rule.RuleType() == C.IPSuffix
}

// The profile's own Tailscale proxies, and every proxy or group through which
// a rule can reach one of them.
func tailscaleProfileAdapters(proxies map[string]C.Proxy) (map[string]bool, map[string]bool) {
	own := map[string]bool{}
	for name, proxy := range proxies {
		if proxy.Type() == C.Tailscale {
			own[name] = true
		}
	}
	reach := map[string]bool{}
	var holds func(name string, visiting map[string]bool) bool
	holds = func(name string, visiting map[string]bool) bool {
		if own[name] || reach[name] {
			return true
		}
		proxy := proxies[name]
		if proxy == nil || visiting[name] {
			return false
		}
		group, ok := proxy.Adapter().(outboundgroup.ProxyGroup)
		if !ok {
			return false
		}
		visiting[name] = true
		return slices.ContainsFunc(group.Proxies(), func(member C.Proxy) bool {
			return holds(member.Name(), visiting)
		})
	}
	for name := range proxies {
		if holds(name, map[string]bool{}) {
			reach[name] = true
		}
	}
	return own, reach
}

func tailscaleProfileRoutes(rules []C.Rule, own, reach map[string]bool) ([]tailscaleProfileRoute, []C.Rule) {
	var routes []tailscaleProfileRoute
	var direct []C.Rule
	for _, rule := range rules {
		if rule.RuleType() == C.MATCH || !reach[rule.Adapter()] && !own[rule.Adapter()] {
			continue
		}
		if own[rule.Adapter()] {
			direct = append(direct, rule)
		}
		route := tailscaleProfileRoute{
			Proxy: rule.Adapter(),
			Rule:  rule.RuleType().String() + "," + rule.Payload() + "," + rule.Adapter(),
			Match: func(TailscaleRouteTarget, []netip.Addr) bool { return true },
		}
		if slices.Contains(tailscaleProfileRuleTypes, rule.RuleType()) {
			route.Match = func(target TailscaleRouteTarget, addrs []netip.Addr) bool {
				return tailscaleProfileRuleMatches(rule, target, addrs)
			}
		}
		routes = append(routes, route)
	}
	return routes, direct
}

// Whether a name or address rule covers a target: an address rule covers a
// name whose device address it holds, a name rule a network under its name.
func tailscaleProfileRuleMatches(rule C.Rule, target TailscaleRouteTarget, addrs []netip.Addr) bool {
	matchIP := func(addr netip.Addr) bool {
		ok, _ := rule.Match(&C.Metadata{DstIP: addr}, C.RuleMatchHelper{})
		return ok
	}
	if target.Kind == tailscaleTargetIP {
		addr, err := netip.ParseAddr(target.Value)
		return err == nil && matchIP(addr)
	}
	if tailscaleProfileRuleIsIP(rule) {
		return slices.ContainsFunc(addrs, matchIP)
	}
	if ok, _ := rule.Match(&C.Metadata{Host: target.Value}, C.RuleMatchHelper{}); ok {
		return true
	}
	if target.Kind != tailscaleTargetSuffix {
		return false
	}
	payload := normalizeTailscaleHost(rule.Payload())
	switch rule.RuleType() {
	case C.Domain, C.DomainSuffix:
		return strings.HasSuffix(payload, "."+target.Value)
	}
	return false
}

func tailscaleRoutesPath(profileID int64) string {
	return filepath.Join(tailscaleRoutesDir(), "routes-"+strconv.FormatInt(profileID, 10)+".json")
}

func tailscaleRoutesDir() string {
	return filepath.Join(tailscaleHomeDir(), tailscaleNodesDir, tailscaleManagedDirName)
}

// An unreadable file is an error, never an empty memory that would free targets.
func loadTailscaleRouteMemory(profileID int64) (*tailscaleRouteMemory, error) {
	buf, err := os.ReadFile(tailscaleRoutesPath(profileID))
	if errors.Is(err, os.ErrNotExist) {
		return newTailscaleRouteMemory(), nil
	}
	if err != nil {
		return nil, err
	}
	memory := newTailscaleRouteMemory()
	if err := json.Unmarshal(buf, memory); err != nil {
		return nil, err
	}
	if memory.Accounts == nil {
		memory.Accounts = map[string]TailscaleRouteIdentity{}
	}
	return memory, nil
}

var saveTailscaleRouteMemory = func(profileID int64, memory *tailscaleRouteMemory) error {
	buf, err := json.MarshalIndent(memory, "", "  ")
	if err != nil {
		return err
	}
	return writeTailscaleFile(tailscaleRoutesPath(profileID), buf)
}

var removeTailscaleRouteMemory = func(profileID int64) error {
	err := os.Remove(tailscaleRoutesPath(profileID))
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	return err
}

// The live routing state of the profile the Core runs.
type tailscaleRouter struct {
	mu        sync.Mutex
	profileID int64
	memory    *tailscaleRouteMemory
	persisted *tailscaleRouteMemory
	loadErr   error
	saved     bool
	report    *TailscaleRoutes
	revision  uint64
	forgotten bool
}

var tailscaleRouting = &tailscaleRouter{}
