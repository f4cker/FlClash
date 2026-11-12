//go:build with_gvisor && !no_tailscale

package core

import (
	"context"
	"regexp"
	"slices"
	"strconv"
	"sync"
	"sync/atomic"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/adapter/outboundgroup"
	"github.com/metacubex/mihomo/common/utils"
	"github.com/metacubex/mihomo/config"
	C "github.com/metacubex/mihomo/constant"
	P "github.com/metacubex/mihomo/constant/provider"
	"github.com/metacubex/mihomo/tunnel"
)

// The runtime group holding the panel's exit nodes. It is offered last in
// every manual select group, never written to the file, and never seen by the
// tailnet ownership or the mount checks: it carries traffic to the internet.
const tailscaleExitGroupBase = "Tailscale 出口"

// The group's names in every language; a saved choice of one follows the group.
var tailscaleExitGroupBases = []string{tailscaleExitGroupBase, "Tailscale exit"}

// The selectedMap key the host keeps the exit group's choice under, by account.
const tailscaleExitSelectionKey = "\x00tailscale-exit"

const (
	tailscaleExitApplied     = "applied"
	tailscaleExitUnavailable = "unavailable"
	tailscaleExitUnknown     = "unknown"
)

type tailscaleExitAccount struct {
	id     string
	base   string
	label  string
	exit   string
	node   *outbound.Tailscale
	member C.Proxy
	name   atomic.Value
}

func (a *tailscaleExitAccount) memberName() string {
	name, _ := a.name.Load().(string)
	return name
}

type tailscaleExitRuntime struct {
	mu       sync.Mutex
	name     string
	group    C.Proxy
	selector *outboundgroup.Selector
	accounts []*tailscaleExitAccount
	taken    map[string]bool
	version  atomic.Uint32
	active   atomic.Bool
}

var (
	tailscaleExitMu      sync.Mutex
	tailscaleExitRunning *tailscaleExitRuntime
	tailscaleExitStaged  *tailscaleExitRuntime
	tailscaleExitPending bool
)

func runningTailscaleExit() *tailscaleExitRuntime {
	tailscaleExitMu.Lock()
	defer tailscaleExitMu.Unlock()
	return tailscaleExitRunning
}

// A node of the group: the account's own node under the name the group shows.
type tailscaleExitMember struct {
	C.ProxyAdapter
	account *tailscaleExitAccount
}

func (m *tailscaleExitMember) Name() string { return m.account.memberName() }

func (m *tailscaleExitMember) Unwrap(*C.Metadata, bool) C.Proxy { return nil }

type tailscaleExitProvider struct {
	runtime *tailscaleExitRuntime
}

func (p *tailscaleExitProvider) Name() string                 { return "flash-tailscale-exit" }
func (p *tailscaleExitProvider) VehicleType() P.VehicleType   { return P.Compatible }
func (p *tailscaleExitProvider) Type() P.ProviderType         { return P.Proxy }
func (p *tailscaleExitProvider) Initial() error               { return nil }
func (p *tailscaleExitProvider) Update() error                { return nil }
func (p *tailscaleExitProvider) Count() int                   { return len(p.Proxies()) }
func (p *tailscaleExitProvider) Touch()                       {}
func (p *tailscaleExitProvider) HealthCheck()                 {}
func (p *tailscaleExitProvider) Version() uint32              { return p.runtime.version.Load() }
func (p *tailscaleExitProvider) HealthCheckURL() string       { return "" }
func (p *tailscaleExitProvider) MarshalJSON() ([]byte, error) { return []byte(`{}`), nil }
func (p *tailscaleExitProvider) RegisterHealthCheckTask(string, utils.IntRanges[uint16], string, uint) {
}

func (p *tailscaleExitProvider) Proxies() []C.Proxy {
	return p.runtime.members()
}

func (rt *tailscaleExitRuntime) members() []C.Proxy {
	rt.mu.Lock()
	defer rt.mu.Unlock()
	var members []C.Proxy
	for _, account := range rt.accounts {
		if account.exit != "" {
			members = append(members, account.member)
		}
	}
	return members
}

// Offered to the manual groups while it holds a node.
func (rt *tailscaleExitRuntime) offered() []C.Proxy {
	if rt == nil || !rt.active.Load() {
		return nil
	}
	return []C.Proxy{rt.group}
}

// Names follow the labels; a label another node or member holds gets a number.
func (rt *tailscaleExitRuntime) renameLocked() {
	used := map[string]bool{}
	for _, account := range rt.accounts {
		base := account.label
		if base == "" {
			base = account.exit + " · " + account.base
		}
		name := base
		for i := 2; rt.taken[name] || used[name] || name == rt.name; i++ {
			name = base + " (" + strconv.Itoa(i) + ")"
		}
		used[name] = true
		account.name.Store(name)
	}
	active := slices.ContainsFunc(rt.accounts, func(account *tailscaleExitAccount) bool { return account.exit != "" })
	rt.active.Store(active)
	rt.version.Add(1)
}

var tailscaleExitAliasPattern = regexp.MustCompile(`^(.+?)(?: \(Flash(?: \d+)?\))?$`)

func tailscaleExitAlias(name string, bases []string) bool {
	match := tailscaleExitAliasPattern.FindStringSubmatch(name)
	return match != nil && slices.Contains(bases, match[1])
}

func tailscaleExitGroupName(cfg *config.Config, base string) string {
	if base == "" {
		base = tailscaleExitGroupBase
	}
	return tailscaleManagedName(cfg, base)
}

type tailscaleExitSeed struct {
	setup TailscaleManagedSetup
	node  *outbound.Tailscale
	proxy C.Proxy
}

// Builds the group over the attached accounts' nodes and offers it to every
// manual select group of the config. Called after the ownership and mount
// reads of the config, so neither can count it.
func stageTailscaleExit(cfg *config.Config, base string, seeds []tailscaleExitSeed) {
	tailscaleExitMu.Lock()
	tailscaleExitStaged, tailscaleExitPending = nil, true
	tailscaleExitMu.Unlock()
	for _, seed := range seeds {
		expected := seed.setup.ExitNode != nil && *seed.setup.ExitNode != ""
		seed.node.SetExitExpected(&expected)
	}
	if len(seeds) == 0 {
		return
	}
	reject := cfg.Proxies["REJECT"]
	if reject == nil {
		return
	}
	rt := &tailscaleExitRuntime{name: tailscaleExitGroupName(cfg, base), taken: map[string]bool{}}
	for name := range cfg.Proxies {
		rt.taken[name] = true
	}
	for _, seed := range seeds {
		account := &tailscaleExitAccount{id: seed.setup.ID, base: seed.proxy.Name(), label: seed.setup.ExitLabel, node: seed.node}
		if seed.setup.ExitNode != nil {
			account.exit = *seed.setup.ExitNode
		}
		account.member = adapter.NewProxy(&tailscaleExitMember{ProxyAdapter: seed.proxy.Adapter(), account: account})
		rt.accounts = append(rt.accounts, account)
	}
	rt.renameLocked()
	selector, err := outboundgroup.NewSelector(
		outboundgroup.GroupCommonOption{Name: rt.name},
		outboundgroup.SelectorOption{},
		reject,
		[]P.ProxyProvider{&tailscaleExitProvider{runtime: rt}},
	)
	if err != nil {
		logError("[Tailscale] exit group not added: %v", err)
		return
	}
	rt.selector, rt.group = selector, adapter.NewProxy(selector)
	for _, proxy := range cfg.Proxies {
		parent, ok := adapterAs[*outboundgroup.Selector](proxy)
		if !ok || isBuiltInGlobal(proxy) {
			continue
		}
		parent.SetRuntimeProxies(rt.offered)
	}
	cfg.Proxies[rt.name] = rt.group
	tailscaleExitMu.Lock()
	tailscaleExitStaged = rt
	tailscaleExitMu.Unlock()
}

func publishTailscaleExit() {
	tailscaleExitMu.Lock()
	defer tailscaleExitMu.Unlock()
	if tailscaleExitPending {
		tailscaleExitRunning, tailscaleExitStaged, tailscaleExitPending = tailscaleExitStaged, nil, false
	}
}

func clearTailscaleExit() {
	tailscaleExitMu.Lock()
	tailscaleExitStaged, tailscaleExitPending = nil, true
	tailscaleExitMu.Unlock()
}

// The staged group counts too: the mount check runs before it is published.
func isTailscaleExitGroup(proxy C.Proxy) bool {
	if proxy == nil {
		return false
	}
	tailscaleExitMu.Lock()
	runtimes := []*tailscaleExitRuntime{tailscaleExitRunning, tailscaleExitStaged}
	tailscaleExitMu.Unlock()
	selector, _ := adapterAs[*outboundgroup.Selector](proxy)
	return slices.ContainsFunc(runtimes, func(rt *tailscaleExitRuntime) bool {
		return rt != nil && (proxy == rt.group || selector != nil && selector == rt.selector)
	})
}

// The group's members are not in the tunnel; they are found by name here.
func tailscaleExitMemberNamed(name string) C.Proxy {
	rt := runningTailscaleExit()
	if rt == nil {
		return nil
	}
	for _, member := range rt.members() {
		if member.Name() == name {
			return member
		}
	}
	return nil
}

func tailscaleExitShown() (string, []C.Proxy) {
	rt := runningTailscaleExit()
	if rt == nil || !rt.active.Load() {
		return "", nil
	}
	return rt.name, rt.members()
}

// Takes a setPrefs change of a panel-added node's exit: the group follows
// what the node now holds, and a choice of the renamed node stays on it.
func tailscaleExitPrefsChanged(t *outbound.Tailscale, exitNode, label *string, outcome string) {
	t.InvalidateExitState()
	if exitNode == nil || outcome == tailscaleOutcomeFailed {
		return
	}
	expected := *exitNode != ""
	t.SetExitExpected(&expected)
	rt := runningTailscaleExit()
	if rt == nil {
		return
	}
	id := tailscaleManagedIDOf(t)
	selectMu.Lock()
	defer selectMu.Unlock()
	now := rt.selector.Now()
	rt.mu.Lock()
	var changed *tailscaleExitAccount
	for _, account := range rt.accounts {
		if account.id == id && id != "" {
			changed = account
		}
	}
	if changed == nil {
		rt.mu.Unlock()
		return
	}
	before := changed.memberName()
	selected := now == before
	changed.exit, changed.node = *exitNode, t
	if label != nil {
		changed.label = *label
	}
	rt.renameLocked()
	after := changed.memberName()
	rt.mu.Unlock()
	if selected && after != before {
		rt.selector.ForceSet(after)
	}
}

// Brings the saved choices back onto the group: its own by account, and a
// group's pick of it under a name it had before, in another language too.
func followTailscaleExitSelections(mapping map[string]string) {
	rt := runningTailscaleExit()
	if rt == nil {
		return
	}
	selectMu.Lock()
	defer selectMu.Unlock()
	if id := mapping[tailscaleExitSelectionKey]; id != "" {
		rt.mu.Lock()
		var name string
		for _, account := range rt.accounts {
			if account.id == id && account.exit != "" {
				name = account.memberName()
			}
		}
		rt.mu.Unlock()
		if name != "" {
			rt.selector.ForceSet(name)
		}
	}
	proxies := tunnel.Proxies()
	bases := append([]string{tailscaleExitGroupBase}, tailscaleExitGroupBases...)
	if match := tailscaleExitAliasPattern.FindStringSubmatch(rt.name); match != nil {
		bases = append(bases, match[1])
	}
	for group, selected := range mapping {
		if selected == rt.name || proxies[selected] != nil || !tailscaleExitAlias(selected, bases) {
			continue
		}
		if parent, ok := adapterAs[*outboundgroup.Selector](proxies[group]); ok && !isBuiltInGlobal(proxies[group]) {
			parent.ForceSet(rt.name)
		}
	}
}

type TailscaleExitAccountState struct {
	ID       string `json:"id"`
	Member   string `json:"member"`
	ExitNode string `json:"exit-node"`
	// applied, unavailable or unknown.
	State  string `json:"state"`
	Reason string `json:"reason,omitempty"`
}

type TailscaleExitParent struct {
	Name    string   `json:"name"`
	Now     string   `json:"now"`
	Members []string `json:"members"`
}

// What the running config holds of the exit group, read from it.
type TailscaleExitReport struct {
	ProfileID int64 `json:"profile-id"`
	// confirmed, none, unconfirmed (a config is on its way) or other-profile.
	State    string                      `json:"state"`
	Group    string                      `json:"group,omitempty"`
	Selected string                      `json:"selected,omitempty"`
	Parents  []TailscaleExitParent       `json:"parents"`
	Accounts []TailscaleExitAccountState `json:"accounts"`
}

func handleTailscaleExit(params TailscaleRoutesParams) (*TailscaleExitReport, error) {
	report := &TailscaleExitReport{
		ProfileID: params.ProfileID,
		State:     tailscaleRuntimeUnconfirmed,
		Parents:   []TailscaleExitParent{},
		Accounts:  []TailscaleExitAccountState{},
	}
	if params.ProfileID != tailscaleProfileID() {
		report.State = tailscaleRuntimeOtherProfile
		return report, nil
	}
	tailscaleExitMu.Lock()
	rt, pending := tailscaleExitRunning, tailscaleExitPending
	tailscaleExitMu.Unlock()
	if pending {
		return report, nil
	}
	if rt == nil {
		report.State = tailscaleRuntimeNone
		return report, nil
	}
	report.State = tailscaleRuntimeConfirmed
	rt.mu.Lock()
	accounts := slices.Clone(rt.accounts)
	type read struct {
		id, exit, name string
		node           *outbound.Tailscale
	}
	var reads []read
	for _, account := range accounts {
		if account.exit != "" {
			reads = append(reads, read{account.id, account.exit, account.memberName(), account.node})
		}
	}
	rt.mu.Unlock()
	for _, item := range reads {
		state := TailscaleExitAccountState{ID: item.id, Member: item.name, ExitNode: item.exit}
		state.State, state.Reason = tailscaleExitAccountState(item.node)
		report.Accounts = append(report.Accounts, state)
	}
	if !rt.active.Load() {
		return report, nil
	}
	report.Group = rt.name
	now := rt.selector.Now()
	for _, item := range reads {
		if item.name == now {
			report.Selected = item.id
		}
	}
	proxies := tunnel.Proxies()
	for _, name := range tailscaleExitParentOrder(proxies) {
		parent, ok := adapterAs[*outboundgroup.Selector](proxies[name])
		if !ok || !slices.Contains(parent.RuntimeProxies(), rt.group) {
			continue
		}
		entry := TailscaleExitParent{Name: name, Now: parent.Now(), Members: []string{}}
		for _, member := range parent.Proxies() {
			entry.Members = append(entry.Members, member.Name())
		}
		report.Parents = append(report.Parents, entry)
	}
	return report, nil
}

// The config's own order, then any group it does not list.
func tailscaleExitParentOrder(proxies map[string]C.Proxy) []string {
	names := slices.Clone(config.GetProxyNameList())
	seen := map[string]bool{}
	for _, name := range names {
		seen[name] = true
	}
	for _, name := range sortedKeys(proxies) {
		if !seen[name] {
			names = append(names, name)
		}
	}
	return names
}

func tailscaleExitAccountState(t *outbound.Tailscale) (string, string) {
	if t == nil || t.Closed() {
		return tailscaleExitUnknown, ""
	}
	ref := tailscaleRefOfNode(t)
	if tailscaleLoggedOut(ref) || !tailscaleStateHasIdentity(t.Option().StateDir) {
		return tailscaleExitUnavailable, outbound.TailscaleExitNeedsLogin
	}
	if !t.Started() {
		return tailscaleExitUnknown, ""
	}
	ctx, cancel := context.WithTimeout(context.Background(), tailscaleActionTimeout)
	defer cancel()
	state := t.ExitState(ctx, true)
	switch {
	case state.Refuses():
		return tailscaleExitUnavailable, state.Reason
	case state.Configured && state.Reason == "":
		return tailscaleExitApplied, ""
	}
	return tailscaleExitUnknown, ""
}
