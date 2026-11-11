//go:build with_gvisor && !no_tailscale

package core

import (
	"context"
	"errors"
	"slices"
	"sort"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/tunnel/statistic"
	"github.com/metacubex/tailscale/ipn"
	"github.com/metacubex/tailscale/ipn/ipnstate"
	"github.com/metacubex/tailscale/tailcfg"
)

var (
	tailscaleActionTimeout = 30 * time.Second
	tailscaleAuthURLWait   = 20 * time.Second
	tailscalePollInterval  = 250 * time.Millisecond
)

func init() {
	outbound.TailscaleStateDirHook = tailscaleStateDir
	outbound.TailscaleStartGate = tailscaleStartGate
	outbound.TailscaleStateHook = onTailscaleState
	outbound.TailscaleOptionHook = adjustTailscaleOption
}

var tailscaleReplacing atomic.Uint64

func markTailscaleReplaced(mark uint64) { tailscaleReplacing.Store(mark) }

// A node from a proxy provider is built outside the merged document, so its
// saved settings reach it here. One whose name and control server a node of
// another source shares gets none: a record cannot tell the two apart.
func adjustTailscaleOption(option *outbound.TailscaleOption) {
	if strings.Contains(option.Name, validationNameSuffix) {
		return
	}
	if option.ProviderName == "" && tailscaleInProxies(option.Name) {
		return
	}
	if tailscaleKeyShared(*option, nil) {
		return
	}
	node, _ := tailscaleEffectiveNode(option.Name, option.ControlURL)
	if node.ExitNode != nil {
		option.ExitNode = *node.ExitNode
	}
	if node.AcceptRoutes != nil {
		acceptRoutes := *node.AcceptRoutes
		option.AcceptRoutes = &acceptRoutes
	}
}

func tailscaleKeyShared(option outbound.TailscaleOption, self *outbound.Tailscale) bool {
	controlURL := normalizeControlURL(option.ControlURL)
	replacing := tailscaleReplacing.Load()
	return slices.ContainsFunc(outbound.TailscaleInstances(), func(other *outbound.Tailscale) bool {
		if other == self || other.Name() != option.Name || other.Generation() <= replacing || other.Closed() {
			return false
		}
		otherOption := other.Option()
		return otherOption.ProviderName != option.ProviderName && normalizeControlURL(otherOption.ControlURL) == controlURL
	})
}

func tailscaleOverridable(t *outbound.Tailscale) bool {
	return !tailscaleKeyShared(t.Option(), t)
}

// A node another one shares its key with reports only what it was built with.
func tailscaleNodeSettings(t *outbound.Tailscale, overridable bool) TailscaleSettings {
	option := t.Option()
	tailscaleMu.Lock()
	defer tailscaleMu.Unlock()
	source := tailscaleConfigSourceLocked()
	configured, inProxies := tailscaleConfigs[t.Name()]
	if option.ProviderName != "" || !inProxies {
		written := t.ConfiguredOption()
		configured = tailscaleConfiguredValues{acceptRoutes: written.AcceptRoutes}
		if written.ExitNode != "" {
			configured.exitNode = &written.ExitNode
		}
		if option.ProviderName != "" {
			source = tailscaleSourceProvider
		}
	}
	var node TailscaleNodeSetup
	if overridable {
		node, _ = tailscaleEffectiveNodeLocked(t.Name(), option.ControlURL)
	} else {
		configuredExit := ""
		if configured.exitNode != nil {
			configuredExit = *configured.exitNode
		}
		if option.ExitNode != configuredExit {
			node.ExitNode = &option.ExitNode
		}
		if routes := option.AcceptRoutes; routes != nil && (configured.acceptRoutes == nil || *configured.acceptRoutes != *routes) {
			node.AcceptRoutes = routes
		}
	}
	return tailscaleSettingsOver(node, configured, source)
}

// Traffic, DNS and delay tests never log a node back in: a node the user
// logged out of stays out, and one with no identity waits for a login.
func tailscaleStartGate(t *outbound.Tailscale, started bool) error {
	option := t.Option()
	if tailscaleLoggedOut(t.Name(), option.ControlURL) {
		return errTailscaleLoggedOut
	}
	if !started && !tailscaleStateHasIdentity(option.StateDir) {
		return errTailscaleNeedsLogin
	}
	if started && t.BackendState() == ipn.Running.String() && tailscaleReapplyPending(t) {
		return errTailscaleApplyingPrefs
	}
	return nil
}

type TailscaleStateEvent struct {
	Name         string `json:"name"`
	Generation   uint64 `json:"generation"`
	State        string `json:"state"`
	AuthURLReady bool   `json:"auth-url-ready"`
}

// After a logout and a new login in one instance the prefs start over, so the
// ones the config and the panel set are applied again once it runs; dials wait
// for that instead of leaving through a node without its exit node. The value
// is whether the apply has begun.
var (
	tailscaleReapplyMu sync.Mutex
	tailscaleReapply   = map[*outbound.Tailscale]bool{}
)

func markTailscaleReapply(t *outbound.Tailscale) {
	tailscaleReapplyMu.Lock()
	defer tailscaleReapplyMu.Unlock()
	if _, ok := tailscaleReapply[t]; !ok {
		tailscaleReapply[t] = false
	}
}

func tailscaleReapplyPending(t *outbound.Tailscale) bool {
	tailscaleReapplyMu.Lock()
	defer tailscaleReapplyMu.Unlock()
	_, ok := tailscaleReapply[t]
	return ok
}

func claimTailscaleReapply(t *outbound.Tailscale) bool {
	tailscaleReapplyMu.Lock()
	defer tailscaleReapplyMu.Unlock()
	begun, ok := tailscaleReapply[t]
	if !ok || begun {
		return false
	}
	tailscaleReapply[t] = true
	return true
}

func finishTailscaleReapply(t *outbound.Tailscale) {
	tailscaleReapplyMu.Lock()
	defer tailscaleReapplyMu.Unlock()
	delete(tailscaleReapply, t)
}

func onTailscaleState(t *outbound.Tailscale, state string, authURLReady bool) {
	if strings.Contains(t.Name(), validationNameSuffix) {
		return
	}
	sendMessage(TailscaleStateMessage, &TailscaleStateEvent{
		Name:         t.Name(),
		Generation:   t.Generation(),
		State:        state,
		AuthURLReady: authURLReady,
	})
	if state != ipn.Running.String() {
		return
	}
	if claimTailscaleReapply(t) {
		safeGo("tailscale reapply prefs", func() {
			defer finishTailscaleReapply(t)
			option := t.Option()
			var node TailscaleNodeSetup
			if tailscaleOverridable(t) {
				node, _ = tailscaleEffectiveNode(t.Name(), option.ControlURL)
			}
			exitNode := node.ExitNode
			if exitNode == nil && option.ExitNode != "" {
				exitNode = &option.ExitNode
			}
			acceptRoutes := node.AcceptRoutes
			if acceptRoutes == nil {
				acceptRoutes = option.AcceptRoutes
			}
			if _, err := editTailscalePrefs(t, exitNode, acceptRoutes); err != nil {
				logError("[Tailscale](%s) reapply prefs failed: %v", t.Name(), err)
			}
		})
	}
}

func tailscaleGenerationMark() uint64 {
	var mark uint64
	for _, t := range outbound.TailscaleInstances() {
		mark = max(mark, t.Generation())
	}
	return mark
}

func closeTailscaleUpTo(mark uint64) {
	for _, t := range outbound.TailscaleInstances() {
		if t.Generation() <= mark {
			_ = t.Close()
			finishTailscaleReapply(t)
		}
	}
}

// The node of each name the running config holds: the newest instance.
func currentTailscaleNodes() []*outbound.Tailscale {
	latest := map[string]*outbound.Tailscale{}
	for _, t := range outbound.TailscaleInstances() {
		if strings.Contains(t.Name(), validationNameSuffix) || t.Closed() {
			continue
		}
		if previous := latest[t.Name()]; previous == nil || previous.Generation() < t.Generation() {
			latest[t.Name()] = t
		}
	}
	nodes := make([]*outbound.Tailscale, 0, len(latest))
	for _, t := range latest {
		nodes = append(nodes, t)
	}
	sort.Slice(nodes, func(i, j int) bool { return nodes[i].Generation() < nodes[j].Generation() })
	return nodes
}

func boundTailscale(name string, generation uint64) (*outbound.Tailscale, error) {
	for _, t := range currentTailscaleNodes() {
		if t.Name() != name {
			continue
		}
		if t.Generation() != generation {
			return nil, errTailscaleStaleGeneration
		}
		return t, nil
	}
	return nil, errTailscaleNodeNotFound
}

var tailscaleNodeLocks sync.Map

// Actions on one node run one at a time; other nodes are not held up.
func lockTailscaleNode(name string) func() {
	value, _ := tailscaleNodeLocks.LoadOrStore(name, &sync.Mutex{})
	mu := value.(*sync.Mutex)
	mu.Lock()
	return mu.Unlock
}

type TailscaleNode struct {
	ProfileID    int64                    `json:"profile-id"`
	Name         string                   `json:"name"`
	Generation   uint64                   `json:"generation"`
	ControlURL   string                   `json:"control-url"`
	Hostname     string                   `json:"hostname"`
	StateDirMode string                   `json:"state-dir-mode"`
	Started      bool                     `json:"started"`
	BackendState string                   `json:"backend-state"`
	LoggedOut    bool                     `json:"logged-out"`
	HasIdentity  bool                     `json:"has-identity"`
	AuthKey      bool                     `json:"auth-key"`
	Ephemeral    bool                     `json:"ephemeral"`
	Overridable  bool                     `json:"overridable"`
	StartError   *MethodError             `json:"start-error,omitempty"`
	Settings     TailscaleSettings        `json:"settings"`
	Warnings     []string                 `json:"warnings"`
	Legacy       *TailscaleLegacyIdentity `json:"legacy,omitempty"`
}

func describeTailscale(t *outbound.Tailscale, nodes []*outbound.Tailscale) TailscaleNode {
	option := t.Option()
	mode := "derived"
	switch {
	case t.ExplicitStateDir():
		mode = "explicit"
	case !strings.Contains(option.StateDir, tailscaleNodesDir):
		mode = "shared"
	}
	overridable := tailscaleOverridable(t)
	node := TailscaleNode{
		ProfileID:    tailscaleProfileID(),
		Name:         t.Name(),
		Generation:   t.Generation(),
		ControlURL:   normalizeControlURL(option.ControlURL),
		Hostname:     option.Hostname,
		StateDirMode: mode,
		Started:      t.Started(),
		BackendState: t.BackendState(),
		LoggedOut:    tailscaleLoggedOut(t.Name(), option.ControlURL),
		HasIdentity:  tailscaleStateHasIdentity(option.StateDir),
		AuthKey:      option.AuthKey != "",
		Ephemeral:    option.Ephemeral,
		Overridable:  overridable,
		StartError:   tailscaleStartError(t.LastStartError()),
		Settings:     tailscaleNodeSettings(t, overridable),
		Warnings:     []string{},
	}
	if !t.ExplicitStateDir() {
		if legacy := describeTailscaleLegacy(t); legacy != nil {
			node.Warnings = append(node.Warnings, tailscaleWarningLegacyState)
			node.Legacy = legacy
		}
	}
	var inUse *outbound.TailscaleStateDirInUseError
	sharesDir := slices.ContainsFunc(nodes, func(other *outbound.Tailscale) bool {
		return other != t && other.Option().StateDir == option.StateDir
	})
	if sharesDir || errors.As(t.LastStartError(), &inUse) {
		node.Warnings = append(node.Warnings, tailscaleWarningDirInUse)
	}
	return node
}

func handleTailscaleNodes() []TailscaleNode {
	nodes := currentTailscaleNodes()
	result := make([]TailscaleNode, 0, len(nodes))
	for _, t := range nodes {
		result = append(result, describeTailscale(t, nodes))
	}
	return result
}

type TailscaleUser struct {
	ID            string `json:"id"`
	LoginName     string `json:"login-name"`
	DisplayName   string `json:"display-name"`
	ProfilePicURL string `json:"profile-pic-url"`
}

type TailscalePeer struct {
	ID             string     `json:"id"`
	HostName       string     `json:"host-name"`
	DNSName        string     `json:"dns-name"`
	OS             string     `json:"os"`
	UserID         string     `json:"user-id"`
	AltSharerUser  string     `json:"alt-sharer-user-id,omitempty"`
	Addresses      []string   `json:"addresses"`
	Tags           []string   `json:"tags"`
	Online         bool       `json:"online"`
	ExitNode       bool       `json:"exit-node"`
	ExitNodeOption bool       `json:"exit-node-option"`
	ShareeNode     bool       `json:"sharee-node"`
	Expired        bool       `json:"expired"`
	KeyExpiry      *time.Time `json:"key-expiry,omitempty"`
}

type TailscaleTailnet struct {
	Name            string `json:"name"`
	MagicDNSSuffix  string `json:"magic-dns-suffix"`
	MagicDNSEnabled bool   `json:"magic-dns-enabled"`
}

type TailscalePrefs struct {
	ExitNodeID   string `json:"exit-node-id"`
	ExitNodeIP   string `json:"exit-node-ip"`
	AutoExitNode string `json:"auto-exit-node"`
	AcceptRoutes bool   `json:"accept-routes"`
}

type TailscaleStatus struct {
	Node         TailscaleNode            `json:"node"`
	AuthURLReady bool                     `json:"auth-url-ready"`
	HaveNodeKey  bool                     `json:"have-node-key"`
	Self         *TailscalePeer           `json:"self,omitempty"`
	LoginUser    *TailscaleUser           `json:"login-user,omitempty"`
	Tailnet      *TailscaleTailnet        `json:"tailnet,omitempty"`
	Users        map[string]TailscaleUser `json:"users"`
	Peers        []TailscalePeer          `json:"peers"`
	Prefs        *TailscalePrefs          `json:"prefs,omitempty"`
	Health       []string                 `json:"health"`
}

// Reads only: a node that has not started stays that way.
func handleTailscaleStatus(params TailscaleNodeParams) (*TailscaleStatus, error) {
	t, err := boundTailscale(params.Name, params.Generation)
	if err != nil {
		return nil, err
	}
	status := &TailscaleStatus{
		Node:   describeTailscale(t, currentTailscaleNodes()),
		Users:  map[string]TailscaleUser{},
		Peers:  []TailscalePeer{},
		Health: []string{},
	}
	if !status.Node.Started {
		return status, nil
	}
	lc, err := t.LocalClient()
	if err != nil {
		return status, nil
	}
	ctx, cancel := context.WithTimeout(context.Background(), tailscaleActionTimeout)
	defer cancel()
	st, err := lc.Status(ctx)
	if err != nil {
		return nil, err
	}
	status.Node.BackendState = st.BackendState
	status.AuthURLReady = st.AuthURL != ""
	status.HaveNodeKey = st.HaveNodeKey
	status.Health = append(status.Health, st.Health...)
	if st.Self != nil {
		self := tailscalePeer(st.Self)
		status.Self = &self
	}
	if st.CurrentTailnet != nil {
		status.Tailnet = &TailscaleTailnet{
			Name:            st.CurrentTailnet.Name,
			MagicDNSSuffix:  st.CurrentTailnet.MagicDNSSuffix,
			MagicDNSEnabled: st.CurrentTailnet.MagicDNSEnabled,
		}
	}
	for _, user := range st.User {
		converted := tailscaleUser(user)
		status.Users[converted.ID] = converted
	}
	if current, _, err := lc.ProfileStatus(ctx); err == nil && !current.UserProfile.ID.IsZero() {
		user := tailscaleUser(current.UserProfile)
		status.LoginUser = &user
	}
	for _, peer := range st.Peer {
		status.Peers = append(status.Peers, tailscalePeer(peer))
	}
	sort.Slice(status.Peers, func(i, j int) bool { return status.Peers[i].ID < status.Peers[j].ID })
	if prefs, err := lc.GetPrefs(ctx); err == nil {
		status.Prefs = tailscalePrefsOf(prefs, st)
	}
	return status, nil
}

func tailscaleUser(user tailcfg.UserProfile) TailscaleUser {
	return TailscaleUser{
		ID:            strconv.FormatInt(int64(user.ID), 10),
		LoginName:     user.LoginName,
		DisplayName:   user.DisplayName,
		ProfilePicURL: user.ProfilePicURL,
	}
}

func tailscalePeer(peer *ipnstate.PeerStatus) TailscalePeer {
	result := TailscalePeer{
		ID:             string(peer.ID),
		HostName:       peer.HostName,
		DNSName:        peer.DNSName,
		OS:             peer.OS,
		UserID:         strconv.FormatInt(int64(peer.UserID), 10),
		Addresses:      []string{},
		Tags:           []string{},
		Online:         peer.Online,
		ExitNode:       peer.ExitNode,
		ExitNodeOption: peer.ExitNodeOption,
		ShareeNode:     peer.ShareeNode,
		Expired:        peer.Expired,
		KeyExpiry:      peer.KeyExpiry,
	}
	if peer.AltSharerUserID != 0 {
		result.AltSharerUser = strconv.FormatInt(int64(peer.AltSharerUserID), 10)
	}
	for _, addr := range peer.TailscaleIPs {
		result.Addresses = append(result.Addresses, addr.String())
	}
	if peer.Tags != nil {
		result.Tags = append(result.Tags, peer.Tags.AsSlice()...)
	}
	return result
}

func tailscalePrefsOf(prefs *ipn.Prefs, st *ipnstate.Status) *TailscalePrefs {
	result := &TailscalePrefs{
		ExitNodeID:   string(prefs.ExitNodeID),
		AutoExitNode: string(prefs.AutoExitNode),
		AcceptRoutes: prefs.RouteAll,
	}
	switch {
	case prefs.ExitNodeIP.IsValid():
		result.ExitNodeIP = prefs.ExitNodeIP.String()
	case !prefs.ExitNodeID.IsZero() && st != nil:
		for _, peer := range st.Peer {
			if peer.ID == prefs.ExitNodeID && len(peer.TailscaleIPs) > 0 {
				result.ExitNodeIP = peer.TailscaleIPs[0].String()
				break
			}
		}
	}
	return result
}

// The panel's "prepare": an explicit start of a node not logged out.
func handleTailscaleStart(params TailscaleNodeParams) (*TailscaleNode, error) {
	t, err := boundTailscale(params.Name, params.Generation)
	if err != nil {
		return nil, err
	}
	defer lockTailscaleNode(t.Name())()
	if tailscaleLoggedOut(t.Name(), t.Option().ControlURL) {
		return nil, errTailscaleLoggedOut
	}
	ctx, cancel := context.WithTimeout(context.Background(), tailscaleActionTimeout)
	defer cancel()
	if err := t.Start(ctx, outbound.TailscaleStartOptions{Explicit: true}); err != nil {
		return nil, tailscaleStartError(err)
	}
	node := describeTailscale(t, currentTailscaleNodes())
	return &node, nil
}

type TailscaleLoginResult struct {
	Generation uint64 `json:"generation"`
	State      string `json:"state"`
	// The only place the URL ever leaves the Core; it is not logged.
	AuthURL string `json:"auth-url,omitempty"`
	// No URL arrived in time and the node still needs one; read the status again.
	Pending bool `json:"pending"`
}

// The one action that lifts the logout guard.
func handleTailscaleLogin(params TailscaleLoginParams) (*TailscaleLoginResult, error) {
	t, err := boundTailscale(params.Name, params.Generation)
	if err != nil {
		return nil, err
	}
	defer lockTailscaleNode(t.Name())()
	option := t.Option()
	loggedIn := false
	pinTailscale(t.Name(), option.ControlURL, func(pin *tailscalePin) { pin.loggedOut = &loggedIn })

	ctx, cancel := context.WithTimeout(context.Background(), tailscaleActionTimeout)
	defer cancel()
	if err := t.Start(ctx, outbound.TailscaleStartOptions{Explicit: true}); err != nil {
		return nil, tailscaleStartError(err)
	}
	lc, err := t.LocalClient()
	if err != nil {
		return nil, tailscaleStartError(err)
	}
	st, err := lc.StatusWithoutPeers(ctx)
	if err != nil {
		return nil, err
	}
	result := &TailscaleLoginResult{Generation: t.Generation(), State: st.BackendState}
	if st.BackendState == ipn.Running.String() && !params.Reauth {
		return result, nil
	}
	if st.BackendState == ipn.NeedsLogin.String() && !st.HaveNodeKey && option.AuthKey != "" {
		// An instance started for a logout dropped its key; the user asked for it now.
		if err := lc.Start(ctx, ipn.Options{AuthKey: option.AuthKey}); err != nil {
			return nil, err
		}
		markTailscaleReapply(t)
	}
	if err := lc.StartLoginInteractive(ctx); err != nil {
		return nil, err
	}

	waitCtx, waitCancel := context.WithTimeout(context.Background(), tailscaleAuthURLWait)
	defer waitCancel()
	for {
		st, err = lc.StatusWithoutPeers(waitCtx)
		if err == nil {
			result.State = st.BackendState
			if st.AuthURL != "" {
				if err := validateTailscaleAuthURL(st.AuthURL, option.ControlURL); err != nil {
					return nil, err
				}
				result.AuthURL = st.AuthURL
				return result, nil
			}
			if st.BackendState != ipn.NeedsLogin.String() && st.BackendState != ipn.NoState.String() &&
				(st.BackendState != ipn.Running.String() || !params.Reauth) {
				return result, nil
			}
		}
		select {
		case <-waitCtx.Done():
			result.Pending = true
			return result, nil
		case <-time.After(tailscalePollInterval):
		}
	}
}

const (
	tailscaleOutcomeConfirmed  = "confirmed"
	tailscaleOutcomeApplied    = "applied"
	tailscaleOutcomeNotRunning = "not-running"
	tailscaleOutcomeFailed     = "failed"
	tailscaleOutcomeUnknown    = "unknown"
)

type TailscaleLogoutResult struct {
	Generation uint64 `json:"generation"`
	State      string `json:"state"`
	// confirmed only when the server took the logout and no identity is left on disk.
	Outcome         string       `json:"outcome"`
	ServerConfirmed bool         `json:"server-confirmed"`
	IdentityCleared bool         `json:"identity-cleared"`
	Error           *MethodError `json:"error,omitempty"`
}

// The guard goes up before anything else, so whatever fails afterwards the
// node does not log itself back in; the result tells what was confirmed.
func handleTailscaleLogout(params TailscaleNodeParams) (*TailscaleLogoutResult, error) {
	t, err := boundTailscale(params.Name, params.Generation)
	if err != nil {
		return nil, err
	}
	defer lockTailscaleNode(t.Name())()
	option := t.Option()
	loggedOut := true
	pinTailscale(t.Name(), option.ControlURL, func(pin *tailscalePin) { pin.loggedOut = &loggedOut })
	closeTailscaleConnections(t.Name())

	result := &TailscaleLogoutResult{Generation: t.Generation(), Outcome: tailscaleOutcomeUnknown}
	if !t.Started() && !tailscaleStateHasIdentity(option.StateDir) {
		result.IdentityCleared = true
		result.Outcome = tailscaleOutcomeConfirmed
		return result, nil
	}
	ctx, cancel := context.WithTimeout(context.Background(), tailscaleActionTimeout)
	defer cancel()
	if err := t.Start(ctx, outbound.TailscaleStartOptions{Explicit: true, WithoutAuthKey: true}); err != nil {
		result.Error = tailscaleStartError(err)
		return result, nil
	}
	lc, err := t.LocalClient()
	if err != nil {
		result.Error = tailscaleStartError(err)
		return result, nil
	}
	logoutErr := lc.Logout(ctx)
	markTailscaleReapply(t)
	if st, err := lc.StatusWithoutPeers(ctx); err == nil {
		result.State = st.BackendState
		result.ServerConfirmed = logoutErr == nil && !st.HaveNodeKey && st.BackendState == ipn.NeedsLogin.String()
	}
	result.IdentityCleared = !tailscaleStateHasIdentity(option.StateDir)
	if logoutErr != nil {
		result.Error = &MethodError{Code: "tailscale_logout_failed", Message: logoutErr.Error()}
	}
	if result.ServerConfirmed && result.IdentityCleared {
		result.Outcome = tailscaleOutcomeConfirmed
	}
	return result, nil
}

func closeTailscaleConnections(name string) {
	statistic.DefaultManager.Range(func(c statistic.Tracker) bool {
		if slices.Contains(c.Chains(), name) {
			_ = c.Close()
		}
		return true
	})
}

type TailscalePrefsResult struct {
	Generation uint64 `json:"generation"`
	// applied, not-running, failed (the node kept its prefs) or unknown.
	Outcome string          `json:"outcome"`
	Prefs   *TailscalePrefs `json:"prefs,omitempty"`
	Error   *MethodError    `json:"error,omitempty"`
}

// The host stores the override first; the pin keeps it for the next instance
// even if a payload without it is already on its way.
func handleTailscaleSetPrefs(params TailscalePrefsParams) (*TailscalePrefsResult, error) {
	t, err := boundTailscale(params.Name, params.Generation)
	if err != nil {
		return nil, err
	}
	defer lockTailscaleNode(t.Name())()
	if !tailscaleOverridable(t) {
		return nil, errTailscaleOverrideAmbiguous
	}
	option := t.Option()
	pinTailscale(t.Name(), option.ControlURL, func(pin *tailscalePin) {
		if params.ExitNode != nil {
			pin.exitNode = params.ExitNode
		}
		if params.AcceptRoutes != nil {
			pin.acceptRoutes = params.AcceptRoutes
		}
	})
	result := &TailscalePrefsResult{Generation: t.Generation(), Outcome: tailscaleOutcomeNotRunning}
	if !t.Started() || t.BackendState() != ipn.Running.String() {
		markTailscaleReapply(t)
		return result, nil
	}
	prefs, err := editTailscalePrefs(t, params.ExitNode, params.AcceptRoutes)
	result.Prefs = prefs
	switch {
	case err == nil:
		result.Outcome = tailscaleOutcomeApplied
	case errors.Is(err, errTailscalePrefsUnconfirmed):
		result.Outcome = tailscaleOutcomeUnknown
	default:
		result.Outcome = tailscaleOutcomeFailed
		result.Error = asMethodError(err)
	}
	return result, nil
}

var errTailscalePrefsUnconfirmed = errors.New("tailscale prefs change could not be read back")

// An error other than errTailscalePrefsUnconfirmed means the node never took
// the change; the read-back decides between applied and unknown.
func editTailscalePrefs(t *outbound.Tailscale, exitNode *string, acceptRoutes *bool) (*TailscalePrefs, error) {
	lc, err := t.LocalClient()
	if err != nil {
		return nil, err
	}
	ctx, cancel := context.WithTimeout(context.Background(), tailscaleActionTimeout)
	defer cancel()
	st, err := lc.Status(ctx)
	if err != nil {
		return nil, err
	}
	mp, err := tailscaleMaskedPrefs(exitNode, acceptRoutes, st)
	if err != nil || mp == nil {
		return nil, err
	}
	if _, err := lc.EditPrefs(ctx, mp); err != nil {
		if ctx.Err() != nil {
			return nil, errTailscalePrefsUnconfirmed
		}
		return nil, err
	}
	prefs, err := lc.GetPrefs(ctx)
	if err != nil {
		return nil, errTailscalePrefsUnconfirmed
	}
	if st, err = lc.Status(ctx); err != nil {
		return nil, errTailscalePrefsUnconfirmed
	}
	read := tailscalePrefsOf(prefs, st)
	if !tailscalePrefsMatch(mp, read) {
		return read, errTailscalePrefsUnconfirmed
	}
	return read, nil
}

func tailscaleMaskedPrefs(exitNode *string, acceptRoutes *bool, st *ipnstate.Status) (*ipn.MaskedPrefs, error) {
	mp := &ipn.MaskedPrefs{}
	if acceptRoutes != nil {
		mp.RouteAll = *acceptRoutes
		mp.RouteAllSet = true
	}
	if exitNode != nil {
		mp.ExitNodeIDSet, mp.ExitNodeIPSet, mp.AutoExitNodeSet = true, true, true
		if auto, ok := ipn.ParseAutoExitNodeString(*exitNode); ok {
			mp.AutoExitNode = auto
		} else if *exitNode != "" {
			if err := mp.SetExitNodeIP(*exitNode, st); err != nil {
				return nil, &MethodError{Code: "tailscale_exit_node_invalid", Message: err.Error()}
			}
		}
	}
	if !mp.RouteAllSet && !mp.ExitNodeIPSet {
		return nil, nil
	}
	return mp, nil
}

func tailscalePrefsMatch(want *ipn.MaskedPrefs, read *TailscalePrefs) bool {
	if want.RouteAllSet && read.AcceptRoutes != want.RouteAll {
		return false
	}
	if !want.ExitNodeIPSet {
		return true
	}
	if read.AutoExitNode != string(want.AutoExitNode) {
		return false
	}
	if want.AutoExitNode != "" {
		return true
	}
	if !want.ExitNodeIP.IsValid() {
		return read.ExitNodeIP == "" && read.ExitNodeID == ""
	}
	return read.ExitNodeIP == want.ExitNodeIP.String()
}

var tailscaleDirLive = func(dir string, except *outbound.Tailscale) bool {
	return slices.ContainsFunc(outbound.TailscaleInstances(), func(t *outbound.Tailscale) bool {
		return t != except && !t.Closed() && t.Started() && t.Option().StateDir == dir
	})
}
