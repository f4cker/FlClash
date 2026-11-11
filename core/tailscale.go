package core

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"net/url"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"

	"github.com/metacubex/mihomo/constant"
	"go.yaml.in/yaml/v3"
)

const (
	tailscaleDefaultControlURL = "https://controlplane.tailscale.com"
	tailscaleNodesDir          = "tailscale-nodes"
	tailscaleLegacyDir         = "tailscale"

	tailscaleSourceOverride     = "override"
	tailscaleSourceProfile      = "profile"
	tailscaleSourceSubscription = "subscription"
	tailscaleSourceDefault      = "default"

	tailscaleWarningLegacyState = "legacy-shared-state-present"
	tailscaleWarningDirInUse    = "state-dir-in-use"
)

var (
	errTailscaleLoggedOut = &MethodError{
		Code:    "tailscale_logged_out",
		Message: "tailscale node was logged out; log in from the Tailscale panel",
	}
	errTailscaleNeedsLogin = &MethodError{
		Code:    "tailscale_needs_login",
		Message: "tailscale node has no device identity yet; log in from the Tailscale panel",
	}
	errTailscaleStaleGeneration = &MethodError{
		Code:    "tailscale_stale_generation",
		Message: "tailscale node was reloaded; read its status again",
	}
	errTailscaleNodeNotFound = &MethodError{
		Code:    "tailscale_node_not_found",
		Message: "tailscale node is not in the running config",
	}
	errTailscaleApplyingPrefs = &MethodError{
		Code:    "tailscale_applying_prefs",
		Message: "tailscale node is applying its saved settings",
	}
	errTailscaleNotOverridable = &MethodError{
		Code:    "tailscale_not_overridable",
		Message: "tailscale node comes from a proxy provider; its settings cannot be saved",
	}
	errTailscaleAuthURLRejected = &MethodError{
		Code:    "tailscale_auth_url_rejected",
		Message: "tailscale auth URL does not belong to the configured control server",
	}
)

type tailscalePin struct {
	loggedOut    *bool
	exitNode     *string
	acceptRoutes *bool
}

type tailscaleConfiguredValues struct {
	exitNode     *string
	acceptRoutes *bool
}

var (
	tailscaleMu      sync.Mutex
	tailscaleSetup   *TailscaleSetup
	tailscalePins    = map[string]*tailscalePin{}
	tailscaleConfigs = map[string]tailscaleConfiguredValues{}
)

// The identity boundary of a node: profile, proxy name and control server.
// Overrides, the logout guard and the default state-dir all share it.
func tailscaleNodeKey(profileID int64, name, controlURL string) string {
	sum := sha256.Sum256([]byte(strconv.FormatInt(profileID, 10) + "\x00" + name + "\x00" + normalizeControlURL(controlURL)))
	return hex.EncodeToString(sum[:16])
}

func normalizeControlURL(raw string) string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return tailscaleDefaultControlURL
	}
	parsed, err := url.Parse(raw)
	if err != nil || parsed.Host == "" {
		return strings.TrimRight(strings.ToLower(raw), "/")
	}
	scheme := strings.ToLower(parsed.Scheme)
	host := strings.ToLower(parsed.Hostname())
	port := parsed.Port()
	if (scheme == "https" && port == "443") || (scheme == "http" && port == "80") {
		port = ""
	}
	if isDefaultControlHost(host) && port == "" && scheme == "https" {
		return tailscaleDefaultControlURL
	}
	hostPort := host
	if port != "" {
		hostPort = net.JoinHostPort(host, port)
	} else if strings.Contains(host, ":") {
		hostPort = "[" + host + "]"
	}
	return scheme + "://" + hostPort + strings.TrimRight(parsed.EscapedPath(), "/")
}

func isDefaultControlHost(host string) bool {
	return host == "controlplane.tailscale.com" || host == "login.tailscale.com"
}

// Only a node the host described gets an isolated dir; without a payload the
// shared default stays, as an older host expects.
func tailscaleStateDir(name, controlURL string) string {
	tailscaleMu.Lock()
	setup := tailscaleSetup
	tailscaleMu.Unlock()
	if setup == nil {
		return ""
	}
	name, _, _ = strings.Cut(name, validationNameSuffix)
	return filepath.Join(tailscaleNodesDir, tailscaleNodeKey(setup.ProfileID, name, controlURL))
}

// A pin is what an IPC action set ahead of the host's next payload; it holds
// until a payload agrees, so a payload already in flight cannot undo it.
func setTailscaleSetup(setup *TailscaleSetup) {
	tailscaleMu.Lock()
	defer tailscaleMu.Unlock()
	tailscaleSetup = setup
	if setup == nil {
		return
	}
	for _, node := range setup.Nodes {
		key := tailscaleNodeKey(setup.ProfileID, node.Name, node.ControlURL)
		pin := tailscalePins[key]
		if pin == nil {
			continue
		}
		if pin.loggedOut != nil && *pin.loggedOut == node.LoggedOut {
			pin.loggedOut = nil
		}
		if pin.exitNode != nil && node.ExitNode != nil && *pin.exitNode == *node.ExitNode {
			pin.exitNode = nil
		}
		if pin.acceptRoutes != nil && node.AcceptRoutes != nil && *pin.acceptRoutes == *node.AcceptRoutes {
			pin.acceptRoutes = nil
		}
		if pin.loggedOut == nil && pin.exitNode == nil && pin.acceptRoutes == nil {
			delete(tailscalePins, key)
		}
	}
}

func tailscaleProfileID() int64 {
	tailscaleMu.Lock()
	defer tailscaleMu.Unlock()
	if tailscaleSetup == nil {
		return 0
	}
	return tailscaleSetup.ProfileID
}

func tailscaleEffectiveNodeLocked(name, controlURL string) (TailscaleNodeSetup, bool) {
	node := TailscaleNodeSetup{Name: name, ControlURL: controlURL}
	if tailscaleSetup == nil {
		return node, false
	}
	found := false
	normalized := normalizeControlURL(controlURL)
	for _, candidate := range tailscaleSetup.Nodes {
		if candidate.Name == name && normalizeControlURL(candidate.ControlURL) == normalized {
			node, found = candidate, true
			break
		}
	}
	if pin := tailscalePins[tailscaleNodeKey(tailscaleSetup.ProfileID, name, controlURL)]; pin != nil {
		found = true
		if pin.loggedOut != nil {
			node.LoggedOut = *pin.loggedOut
		}
		if pin.exitNode != nil {
			node.ExitNode = pin.exitNode
		}
		if pin.acceptRoutes != nil {
			node.AcceptRoutes = pin.acceptRoutes
		}
	}
	return node, found
}

func tailscaleEffectiveNode(name, controlURL string) (TailscaleNodeSetup, bool) {
	tailscaleMu.Lock()
	defer tailscaleMu.Unlock()
	return tailscaleEffectiveNodeLocked(name, controlURL)
}

func tailscaleLoggedOut(name, controlURL string) bool {
	node, _ := tailscaleEffectiveNode(name, controlURL)
	return node.LoggedOut
}

func pinTailscale(name, controlURL string, update func(pin *tailscalePin)) {
	tailscaleMu.Lock()
	defer tailscaleMu.Unlock()
	var profileID int64
	if tailscaleSetup != nil {
		profileID = tailscaleSetup.ProfileID
	}
	key := tailscaleNodeKey(profileID, name, controlURL)
	pin := tailscalePins[key]
	if pin == nil {
		pin = &tailscalePin{}
		tailscalePins[key] = pin
	}
	update(pin)
}

// Runs on the merged document, after the profile's proxies are in place, so a
// subscription update never drops what the user chose in the panel.
func applyTailscaleOverrides(root *yaml.Node) {
	configs := map[string]tailscaleConfiguredValues{}
	defer func() {
		tailscaleMu.Lock()
		tailscaleConfigs = configs
		tailscaleMu.Unlock()
	}()
	proxies := resolveAlias(mappingValue(root, "proxies"))
	if proxies == nil || proxies.Kind != yaml.SequenceNode {
		return
	}
	for i, item := range proxies.Content {
		mapping := resolveAlias(item)
		if mapping == nil || mapping.Kind != yaml.MappingNode {
			continue
		}
		if !strings.EqualFold(scalarValue(mappingValue(mapping, "type")), "tailscale") {
			continue
		}
		name := scalarValue(mappingValue(mapping, "name"))
		controlURL := scalarValue(mappingValue(mapping, "control-url"))
		configured := tailscaleConfiguredValues{}
		if value := mappingValue(mapping, "exit-node"); value != nil && !isNull(resolveAlias(value)) {
			exitNode := scalarValue(value)
			configured.exitNode = &exitNode
		}
		if value := mappingValue(mapping, "accept-routes"); value != nil {
			var acceptRoutes bool
			if resolveAlias(value).Decode(&acceptRoutes) == nil {
				configured.acceptRoutes = &acceptRoutes
			}
		}
		configs[name] = configured

		node, _ := tailscaleEffectiveNode(name, controlURL)
		if node.ExitNode == nil && node.AcceptRoutes == nil {
			continue
		}
		copied := *mapping
		copied.Content = append([]*yaml.Node(nil), mapping.Content...)
		if node.ExitNode != nil {
			setMappingValue(&copied, "exit-node", &yaml.Node{Kind: yaml.ScalarNode, Tag: "!!str", Value: *node.ExitNode})
		}
		if node.AcceptRoutes != nil {
			setMappingValue(&copied, "accept-routes", &yaml.Node{Kind: yaml.ScalarNode, Tag: "!!bool", Value: strconv.FormatBool(*node.AcceptRoutes)})
		}
		proxies.Content[i] = &copied
	}
}

func scalarValue(node *yaml.Node) string {
	node = resolveAlias(node)
	if node == nil || node.Kind != yaml.ScalarNode || isNull(node) {
		return ""
	}
	return node.Value
}

// Custom and script profiles reach the Core as a config.yaml the host wrote;
// overrides go into it the same way they go into a merged base.
func applyTailscaleOverridesToFile(path string, buf []byte) ([]byte, error) {
	tailscaleMu.Lock()
	tailscaleConfigs = map[string]tailscaleConfiguredValues{}
	tailscaleMu.Unlock()
	if !bytes.Contains(bytes.ToLower(buf), []byte("tailscale")) {
		return buf, nil
	}
	var document yaml.Node
	if err := yaml.Unmarshal(buf, &document); err != nil {
		return buf, nil
	}
	root, err := documentMapping(&document)
	if err != nil {
		return buf, nil
	}
	applyTailscaleOverrides(root)
	if !tailscaleHasOverrides() {
		return buf, nil
	}
	merged := &yaml.Node{Kind: yaml.DocumentNode, Content: []*yaml.Node{root}}
	if err := writeConfigDocument(path, merged); err != nil {
		return nil, err
	}
	return os.ReadFile(path)
}

func tailscaleHasOverrides() bool {
	tailscaleMu.Lock()
	defer tailscaleMu.Unlock()
	if len(tailscalePins) > 0 {
		return true
	}
	if tailscaleSetup == nil {
		return false
	}
	for _, node := range tailscaleSetup.Nodes {
		if node.ExitNode != nil || node.AcceptRoutes != nil {
			return true
		}
	}
	return false
}

type TailscaleExitNodeSetting struct {
	Value  string `json:"value"`
	Source string `json:"source"`
}

type TailscaleAcceptRoutesSetting struct {
	Value  bool   `json:"value"`
	Source string `json:"source"`
}

type TailscaleSettings struct {
	ExitNode     TailscaleExitNodeSetting     `json:"exit-node"`
	AcceptRoutes TailscaleAcceptRoutesSetting `json:"accept-routes"`
}

// Overrides reach only the proxies section; a node from a proxy provider runs
// with what its provider says.
func tailscaleOverridable(name string) bool {
	tailscaleMu.Lock()
	defer tailscaleMu.Unlock()
	_, ok := tailscaleConfigs[name]
	return ok
}

func tailscaleSettings(name, controlURL string) TailscaleSettings {
	tailscaleMu.Lock()
	defer tailscaleMu.Unlock()
	node, _ := tailscaleEffectiveNodeLocked(name, controlURL)
	configured := tailscaleConfigs[name]
	configuredSource := tailscaleSourceProfile
	if tailscaleSetup != nil && tailscaleSetup.ConfigSource == tailscaleSourceSubscription {
		configuredSource = tailscaleSourceSubscription
	}
	settings := TailscaleSettings{
		ExitNode:     TailscaleExitNodeSetting{Source: tailscaleSourceDefault},
		AcceptRoutes: TailscaleAcceptRoutesSetting{Source: tailscaleSourceDefault},
	}
	switch {
	case node.ExitNode != nil:
		settings.ExitNode = TailscaleExitNodeSetting{Value: *node.ExitNode, Source: tailscaleSourceOverride}
	case configured.exitNode != nil:
		settings.ExitNode = TailscaleExitNodeSetting{Value: *configured.exitNode, Source: configuredSource}
	}
	switch {
	case node.AcceptRoutes != nil:
		settings.AcceptRoutes = TailscaleAcceptRoutesSetting{Value: *node.AcceptRoutes, Source: tailscaleSourceOverride}
	case configured.acceptRoutes != nil:
		settings.AcceptRoutes = TailscaleAcceptRoutesSetting{Value: *configured.acceptRoutes, Source: configuredSource}
	}
	return settings
}

// Accepts only an https page on the node's own control server; for the
// default server, the two hosts Tailscale serves logins from.
func validateTailscaleAuthURL(authURL, controlURL string) error {
	parsed, err := url.Parse(authURL)
	if err != nil || parsed.Scheme != "https" || parsed.Host == "" || parsed.User != nil {
		return errTailscaleAuthURLRejected
	}
	host := strings.ToLower(parsed.Hostname())
	port := parsed.Port()
	if port == "443" {
		port = ""
	}
	normalized := normalizeControlURL(controlURL)
	if normalized == tailscaleDefaultControlURL {
		if isDefaultControlHost(host) && port == "" {
			return nil
		}
		return errTailscaleAuthURLRejected
	}
	control, err := url.Parse(normalized)
	if err != nil || control.Scheme != "https" {
		return errTailscaleAuthURLRejected
	}
	if host != control.Hostname() || port != control.Port() {
		return errTailscaleAuthURLRejected
	}
	return nil
}

// A FileStore keeps the login profiles under _profiles; an empty map means the
// node never registered or has logged out.
func tailscaleStateHasIdentity(dir string) bool {
	buf, err := os.ReadFile(filepath.Join(dir, "tailscaled.state"))
	if err != nil {
		return false
	}
	var state map[string][]byte
	if err := json.Unmarshal(buf, &state); err != nil {
		return false
	}
	var profiles map[string]json.RawMessage
	if err := json.Unmarshal(state["_profiles"], &profiles); err != nil {
		return false
	}
	return len(profiles) > 0
}

// The dir every node shared before isolation; it is left as it is.
func tailscaleLegacyStatePresent() bool {
	return tailscaleStateHasIdentity(filepath.Join(constant.Path.HomeDir(), tailscaleLegacyDir))
}

func tailscaleStartError(err error) *MethodError {
	if err == nil {
		return nil
	}
	var methodErr *MethodError
	if errors.As(err, &methodErr) {
		return methodErr
	}
	return &MethodError{Code: "tailscale_start_failed", Message: fmt.Sprint(err)}
}
