//go:build with_gvisor && !no_tailscale

package core

import (
	"context"
	"encoding/json"
	"slices"
	"strconv"
	"sync"
	"time"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/config"
	C "github.com/metacubex/mihomo/constant"
	RW "github.com/metacubex/mihomo/rules/wrapper"
	"github.com/metacubex/mihomo/tunnel"
	"github.com/metacubex/tailscale/ipn"
)

const tailscaleManagedBaseName = "Tailscale"

const tailscaleWatchRetry = 5 * time.Second

type tailscaleManagedNode struct {
	key      string
	watching bool
	cancel   context.CancelFunc
	live     *tailscaleRouteNetmap
}

var (
	tailscaleManagedMu        sync.Mutex
	tailscaleManagedNodes     = map[*outbound.Tailscale]*tailscaleManagedNode{}
	tailscaleManagedInjecting = map[string]bool{}
	// What the config applied last holds of the profile's own Tailscale routes.
	tailscaleManagedProfile      []tailscaleProfileRoute
	tailscaleManagedProfileRules []C.Rule
	tailscaleManagedActive       bool
	// The host could not read its accounts: protect everything, keep nothing.
	tailscaleManagedUnknown bool
	// A config being applied reads the staged slot until hub.ApplyConfig runs it.
	tailscaleRunningSlot *tailscaleRouteSlot
	tailscaleStagedSlot  *tailscaleRouteSlot
	tailscaleStaged      bool
	// Names a provider loaded after the parse also uses; never given again.
	tailscaleManagedNameClash = map[string]bool{}
)

func tailscaleInjecting(stateDir string) bool {
	tailscaleManagedMu.Lock()
	defer tailscaleManagedMu.Unlock()
	return tailscaleManagedInjecting[stateDir]
}

// Only a node this file built is managed; a profile node that names a managed
// directory is caught by the directory claim instead.
func tailscaleIsManaged(t *outbound.Tailscale) bool {
	tailscaleManagedMu.Lock()
	defer tailscaleManagedMu.Unlock()
	_, ok := tailscaleManagedNodes[t]
	return ok
}

func tailscaleRefOfNode(t *outbound.Tailscale) tailscaleRef {
	option := t.Option()
	ref := tailscaleRef{name: option.Name, controlURL: option.ControlURL}
	tailscaleManagedMu.Lock()
	if node := tailscaleManagedNodes[t]; node != nil {
		ref.managedKey = node.key
	}
	tailscaleManagedMu.Unlock()
	return ref
}

func tailscaleManagedIDOf(t *outbound.Tailscale) string {
	ref := tailscaleRefOfNode(t)
	if !ref.managed() {
		return ""
	}
	managed, _ := tailscaleManagedSetupOf(ref.managedKey)
	return managed.ID
}

func forgetTailscaleManaged(t *outbound.Tailscale) {
	tailscaleManagedMu.Lock()
	var cancel context.CancelFunc
	if node := tailscaleManagedNodes[t]; node != nil {
		cancel = node.cancel
	}
	delete(tailscaleManagedNodes, t)
	tailscaleManagedMu.Unlock()
	if cancel != nil {
		cancel()
	}
}

func tailscaleProxyNameTaken(cfg *config.Config, name string) bool {
	if _, ok := cfg.Proxies[name]; ok {
		return true
	}
	tailscaleManagedMu.Lock()
	clash := tailscaleManagedNameClash[name]
	tailscaleManagedMu.Unlock()
	if clash {
		return true
	}
	for _, pd := range cfg.Providers {
		if slices.ContainsFunc(pd.Proxies(), func(proxy C.Proxy) bool { return proxy.Name() == name }) {
			return true
		}
	}
	return false
}

func tailscaleManagedName(cfg *config.Config, base string) string {
	if base == "" {
		base = tailscaleManagedBaseName
	}
	if !tailscaleProxyNameTaken(cfg, base) {
		return base
	}
	for i := 1; ; i++ {
		name := base + " (FlClash)"
		if i > 1 {
			name = base + " (FlClash " + strconv.Itoa(i) + ")"
		}
		if !tailscaleProxyNameTaken(cfg, name) {
			return name
		}
	}
}

var buildTailscaleManagedProxy = func(mapping map[string]any) (C.Proxy, error) {
	return adapter.ParseProxy(mapping, adapter.WithTunnelForAPI(tunnel.Tunnel))
}

// Adds the panel's nodes to the parsed config and, once any is attached, the
// two managed rules at the head of its rules. Nothing goes into a group or the
// config file. An attached account that fails to build still turns the rules
// on, so its targets and the ranges stay blocked.
func injectTailscaleManaged(cfg *config.Config) {
	tailscaleMu.Lock()
	var managed []TailscaleManagedSetup
	var profileID int64
	var unknown bool
	if tailscaleSetup != nil {
		managed = append(managed, tailscaleSetup.Managed...)
		profileID = tailscaleSetup.ProfileID
		unknown = tailscaleSetup.ManagedUnknown
	}
	tailscaleMu.Unlock()

	own, reach := tailscaleProfileAdapters(cfg.Proxies)
	attached := unknown
	for _, account := range managed {
		if account.ID == "" {
			continue
		}
		attached = attached || account.Attached
		dir := tailscaleManagedDir(profileID, account.ID, account.ControlURL)
		mapping := map[string]any{
			"name":      tailscaleManagedName(cfg, account.Name),
			"type":      "tailscale",
			"state-dir": dir,
			"udp":       true,
		}
		if account.ControlURL != "" {
			mapping["control-url"] = account.ControlURL
		}
		if account.ExitNode != nil {
			mapping["exit-node"] = *account.ExitNode
		}
		if account.AcceptRoutes != nil {
			mapping["accept-routes"] = *account.AcceptRoutes
		}
		tailscaleManagedMu.Lock()
		tailscaleManagedInjecting[dir] = true
		tailscaleManagedMu.Unlock()
		proxy, err := buildTailscaleManagedProxy(mapping)
		tailscaleManagedMu.Lock()
		delete(tailscaleManagedInjecting, dir)
		tailscaleManagedMu.Unlock()
		if err != nil {
			logError("[Tailscale] panel-added node not added: %v", err)
			continue
		}
		node := tailscaleInstanceOf(proxy.Name(), dir)
		if node == nil {
			continue
		}
		tailscaleManagedMu.Lock()
		tailscaleManagedNodes[node] = &tailscaleManagedNode{key: tailscaleManagedKey(profileID, account.ID, account.ControlURL)}
		tailscaleManagedMu.Unlock()
		cfg.Proxies[proxy.Name()] = proxy
	}

	routes, profileRules := tailscaleProfileRoutes(cfg.Rules, own, reach)
	var slot *tailscaleRouteSlot
	if attached {
		slot = new(tailscaleRouteSlot)
		rules := []C.Rule{
			RW.NewRuleWrapper(&tailscaleManagedRule{kind: tailscaleRuleHost, slot: slot}),
			RW.NewRuleWrapper(&tailscaleManagedRule{kind: tailscaleRuleIP, slot: slot}),
		}
		cfg.Rules = append(rules, cfg.Rules...)
	}
	tailscaleManagedMu.Lock()
	tailscaleManagedProfile, tailscaleManagedProfileRules = routes, profileRules
	tailscaleManagedActive, tailscaleManagedUnknown = attached, unknown
	tailscaleStagedSlot, tailscaleStaged = slot, true
	tailscaleManagedMu.Unlock()
	reloadTailscaleRoutes()
}

// Called once hub.ApplyConfig installed the config injected last: from now on
// the routing follows its rules.
func publishTailscaleManaged() {
	tailscaleManagedMu.Lock()
	if tailscaleStaged {
		tailscaleRunningSlot, tailscaleStagedSlot, tailscaleStaged = tailscaleStagedSlot, nil, false
	}
	names := map[string]bool{}
	for t := range tailscaleManagedNodes {
		names[t.Name()] = true
	}
	tailscaleManagedMu.Unlock()
	for _, pd := range tunnel.Providers() {
		for _, proxy := range pd.Proxies() {
			if names[proxy.Name()] {
				logError("[Tailscale] panel-added node %q shares its name with a node of %s; it is renamed on the next apply", proxy.Name(), pd.Name())
				tailscaleManagedMu.Lock()
				tailscaleManagedNameClash[proxy.Name()] = true
				tailscaleManagedMu.Unlock()
			}
		}
	}
	refreshTailscaleRoutes()
}

// The parser wraps the adapter, so the instance is found by what it was built with.
func tailscaleInstanceOf(name, stateDir string) *outbound.Tailscale {
	var found *outbound.Tailscale
	for _, t := range outbound.TailscaleInstances() {
		if t.Name() == name && t.Option().StateDir == C.Path.Resolve(stateDir) && !t.Closed() && (found == nil || t.Generation() > found.Generation()) {
			found = t
		}
	}
	return found
}

func clearTailscaleManaged() {
	tailscaleManagedMu.Lock()
	tailscaleManagedProfile, tailscaleManagedProfileRules = nil, nil
	tailscaleManagedActive, tailscaleManagedUnknown = false, false
	tailscaleStagedSlot, tailscaleStaged = nil, true
	tailscaleManagedMu.Unlock()
	reloadTailscaleRoutes()
}

// Brings back every attached account that still has its login and was not
// signed out; a draft or a guarded one waits for the user.
func startTailscaleManaged() {
	for _, t := range currentTailscaleNodes() {
		ref := tailscaleRefOfNode(t)
		if !ref.managed() {
			continue
		}
		managed, ok := tailscaleManagedSetupOf(ref.managedKey)
		if !ok || !managed.Attached || tailscaleLoggedOut(ref) || !tailscaleStateHasIdentity(t.Option().StateDir) {
			continue
		}
		safeGo("tailscale managed start", func() {
			ctx, cancel := context.WithTimeout(context.Background(), tailscaleActionTimeout)
			defer cancel()
			if err := t.Start(ctx, outbound.TailscaleStartOptions{}); err != nil {
				logError("[Tailscale](%s) panel-added node did not start: %v", t.Name(), err)
			}
		})
	}
}

func watchTailscaleManaged(t *outbound.Tailscale, state string) {
	tailscaleManagedMu.Lock()
	node := tailscaleManagedNodes[t]
	if node == nil {
		tailscaleManagedMu.Unlock()
		return
	}
	if state != ipn.Running.String() {
		node.live = nil
		tailscaleManagedMu.Unlock()
		refreshTailscaleRoutes()
		return
	}
	if node.watching {
		tailscaleManagedMu.Unlock()
		return
	}
	ctx, cancel := context.WithCancel(context.Background())
	node.watching, node.cancel = true, cancel
	tailscaleManagedMu.Unlock()
	safeGo("tailscale managed devices", func() {
		defer func() {
			tailscaleManagedMu.Lock()
			node.watching, node.cancel, node.live = false, nil, nil
			current := tailscaleManagedNodes[t] == node
			tailscaleManagedMu.Unlock()
			stopped := ctx.Err() != nil
			cancel()
			if !current {
				return
			}
			// A list nobody keeps current any more is not a loaded one.
			refreshTailscaleRoutes()
			if !stopped && !t.Closed() && t.BackendState() == ipn.Running.String() {
				time.AfterFunc(tailscaleWatchRetry, func() {
					safeGo("tailscale managed devices retry", func() {
						watchTailscaleManaged(t, t.BackendState())
					})
				})
			}
		}()
		watchTailscaleDevices(ctx, t, node)
	})
}

func watchTailscaleDevices(ctx context.Context, t *outbound.Tailscale, node *tailscaleManagedNode) {
	lc, err := t.LocalClient()
	if err != nil {
		return
	}
	watcher, err := lc.WatchIPNBus(ctx, ipn.NotifyInitialNetMap|ipn.NotifyRateLimit)
	if err != nil {
		return
	}
	defer watcher.Close()
	for {
		n, err := watcher.Next()
		if err != nil {
			return
		}
		if n.NetMap == nil && n.State == nil {
			continue
		}
		if t.BackendState() != ipn.Running.String() {
			continue
		}
		live, err := readTailscaleDevices(ctx, t)
		if err != nil {
			continue
		}
		tailscaleManagedMu.Lock()
		current := tailscaleManagedNodes[t] == node
		if current {
			node.live = live
		}
		tailscaleManagedMu.Unlock()
		if !current {
			return
		}
		refreshTailscaleRoutes()
	}
}

func readTailscaleDevices(ctx context.Context, t *outbound.Tailscale) (*tailscaleRouteNetmap, error) {
	lc, err := t.LocalClient()
	if err != nil {
		return nil, err
	}
	readCtx, cancel := context.WithTimeout(ctx, tailscaleActionTimeout)
	defer cancel()
	st, err := lc.Status(readCtx)
	if err != nil {
		return nil, err
	}
	if st.Self == nil || st.Self.UserID.IsZero() {
		return nil, errTailscaleNeedsLogin
	}
	live := &tailscaleRouteNetmap{
		Identity: TailscaleRouteIdentity{
			UserID:     strconv.FormatInt(int64(st.Self.UserID), 10),
			ControlURL: normalizeControlURL(t.Option().ControlURL),
		},
	}
	if user, ok := st.User[st.Self.UserID]; ok {
		live.Identity.LoginName = user.LoginName
	}
	if st.CurrentTailnet != nil {
		live.Identity.Tailnet = st.CurrentTailnet.Name
		live.Suffix = st.CurrentTailnet.MagicDNSSuffix
	}
	for _, peer := range st.Peer {
		item := tailscaleRoutePeer{Name: peer.HostName, FQDN: peer.DNSName}
		for _, addr := range peer.TailscaleIPs {
			item.Addrs = append(item.Addrs, addr)
		}
		live.Peers = append(live.Peers, item)
	}
	slices.SortFunc(live.Peers, func(a, b tailscaleRoutePeer) int {
		switch {
		case a.FQDN < b.FQDN:
			return -1
		case a.FQDN > b.FQDN:
			return 1
		}
		return 0
	})
	return live, nil
}

func tailscaleRouteAccounts() []tailscaleRouteAccount {
	tailscaleMu.Lock()
	var managed []TailscaleManagedSetup
	var profileID int64
	if tailscaleSetup != nil {
		managed = append(managed, tailscaleSetup.Managed...)
		profileID = tailscaleSetup.ProfileID
	}
	tailscaleMu.Unlock()
	instances := map[string]*outbound.Tailscale{}
	for _, t := range currentTailscaleNodes() {
		if ref := tailscaleRefOfNode(t); ref.managed() {
			instances[ref.managedKey] = t
		}
	}
	var accounts []tailscaleRouteAccount
	for _, account := range managed {
		if !account.Attached || account.ID == "" {
			continue
		}
		key := tailscaleManagedKey(profileID, account.ID, account.ControlURL)
		item := tailscaleRouteAccount{
			ID:        account.ID,
			LoggedOut: tailscaleLoggedOut(tailscaleRef{managedKey: key}),
		}
		if t := instances[key]; t != nil && !t.Closed() {
			item.Proxy, item.Available = t.Name(), true
			tailscaleManagedMu.Lock()
			if node := tailscaleManagedNodes[t]; node != nil && node.live != nil && !item.LoggedOut {
				live := *node.live
				item.Live = &live
			}
			tailscaleManagedMu.Unlock()
		}
		accounts = append(accounts, item)
	}
	return accounts
}

// Works the routes out again and keeps what changed; an unreadable kept state
// blocks every target rather than letting one move.
func refreshTailscaleRoutes() {
	r := tailscaleRouting
	r.mu.Lock()
	defer r.mu.Unlock()
	r.refreshLocked()
}

// A new config may keep routes again for a profile they were forgotten for.
func reloadTailscaleRoutes() {
	r := tailscaleRouting
	r.mu.Lock()
	defer r.mu.Unlock()
	r.forgotten = false
	r.refreshLocked()
}

func (r *tailscaleRouter) ensureLoadedLocked(profileID int64) {
	if r.profileID == profileID && r.memory != nil && r.loadErr == nil {
		return
	}
	if r.profileID != profileID {
		r.forgotten = false
	}
	r.profileID = profileID
	memory, err := loadTailscaleRouteMemory(profileID)
	r.memory, r.loadErr = memory, err
	r.persisted = nil
	if err == nil {
		r.persisted = memory.clone()
	}
}

func (r *tailscaleRouter) refreshLocked() {
	profileID := tailscaleProfileID()
	r.ensureLoadedLocked(profileID)
	accounts := tailscaleRouteAccounts()
	tailscaleManagedMu.Lock()
	profile, profileRules, active, unknown := tailscaleManagedProfile, tailscaleManagedProfileRules, tailscaleManagedActive, tailscaleManagedUnknown
	slot := tailscaleRunningSlot
	if tailscaleStaged {
		slot = tailscaleStagedSlot
	}
	tailscaleManagedMu.Unlock()

	memory := r.memory
	if r.loadErr != nil {
		memory = newTailscaleRouteMemory()
		for i := range accounts {
			accounts[i].Live = nil
		}
	}
	result := computeTailscaleRoutes(memory, accounts, profile)
	result.table.profileRules = profileRules
	if slot != nil {
		slot.Store(result.table)
	}
	if r.loadErr == nil && !unknown && !r.forgotten {
		r.memory = result.memory
		if r.persisted == nil || !r.persisted.equal(result.memory) {
			if err := saveTailscaleRouteMemory(profileID, result.memory); err != nil {
				logError("[Tailscale] routing state not saved: %v", err)
			} else {
				r.persisted = result.memory.clone()
			}
		}
	}
	report := result.report
	report.ProfileID = profileID
	report.Active = active
	report.Unreadable = r.loadErr != nil
	report.Saved = r.loadErr == nil && r.persisted != nil && r.persisted.equal(r.memory)
	report.Revision = r.revision
	if r.report == nil || !sameTailscaleRoutes(r.report, report) {
		r.revision++
		report.Revision = r.revision
		sendMessage(TailscaleRoutesMessage, &TailscaleRoutesEvent{ProfileID: profileID, Revision: r.revision})
	}
	r.report = report
}

type TailscaleRoutesEvent struct {
	ProfileID int64  `json:"profile-id"`
	Revision  uint64 `json:"revision"`
}

func sameTailscaleRoutes(a, b *TailscaleRoutes) bool {
	copied := *a
	copied.Revision = b.Revision
	left, _ := json.Marshal(&copied)
	right, _ := json.Marshal(b)
	return string(left) == string(right)
}

func handleTailscaleRoutes(params TailscaleRoutesParams) (*TailscaleRoutes, error) {
	r := tailscaleRouting
	r.mu.Lock()
	defer r.mu.Unlock()
	if params.ProfileID != tailscaleProfileID() {
		return nil, errTailscaleProfileNotCurrent
	}
	r.refreshLocked()
	report := *r.report
	return &report, nil
}

type TailscaleAssignResult struct {
	// applied: kept on disk and in force; failed: nothing was kept.
	Outcome string           `json:"outcome"`
	Routes  *TailscaleRoutes `json:"routes,omitempty"`
	Error   *MethodError     `json:"error,omitempty"`
}

func handleTailscaleAssign(params TailscaleAssignParams) (*TailscaleAssignResult, error) {
	r := tailscaleRouting
	r.mu.Lock()
	defer r.mu.Unlock()
	if params.ProfileID != tailscaleProfileID() {
		return nil, errTailscaleProfileNotCurrent
	}
	r.refreshLocked()
	if r.loadErr != nil {
		return &TailscaleAssignResult{Outcome: tailscaleOutcomeFailed, Error: asMethodError(r.loadErr)}, nil
	}
	next, err := assignTailscaleRoutes(r.memory, r.report, tailscaleRouteAccounts(), params.Assignments)
	if err != nil {
		return nil, err
	}
	if err := saveTailscaleRouteMemory(params.ProfileID, next); err != nil {
		return &TailscaleAssignResult{Outcome: tailscaleOutcomeFailed, Error: asMethodError(err)}, nil
	}
	r.memory, r.persisted = next, next.clone()
	r.refreshLocked()
	report := *r.report
	return &TailscaleAssignResult{Outcome: tailscaleOutcomeApplied, Routes: &report}, nil
}

type TailscaleForgetResult struct {
	Outcome string       `json:"outcome"`
	Error   *MethodError `json:"error,omitempty"`
}

// Drops what a profile's routing kept; the host calls it once the profile, or
// its last panel-added account, is gone. Login archives stay on disk.
func handleTailscaleForgetRoutes(params TailscaleRoutesParams) (*TailscaleForgetResult, error) {
	r := tailscaleRouting
	r.mu.Lock()
	defer r.mu.Unlock()
	if err := removeTailscaleRouteMemory(params.ProfileID); err != nil {
		return &TailscaleForgetResult{Outcome: tailscaleOutcomeFailed, Error: asMethodError(err)}, nil
	}
	if params.ProfileID == r.profileID {
		r.memory, r.persisted, r.loadErr, r.forgotten = newTailscaleRouteMemory(), newTailscaleRouteMemory(), nil, true
		r.refreshLocked()
	}
	return &TailscaleForgetResult{Outcome: tailscaleOutcomeConfirmed}, nil
}
