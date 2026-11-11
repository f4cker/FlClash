package core

import (
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"go.yaml.in/yaml/v3"
)

func resetTailscaleSetup(t *testing.T) {
	t.Helper()
	reset := func() {
		tailscaleMu.Lock()
		tailscaleSetup = nil
		tailscalePins = map[string]*tailscalePin{}
		tailscaleConfigs = map[string]tailscaleConfiguredValues{}
		tailscaleMu.Unlock()
	}
	reset()
	t.Cleanup(reset)
}

func TestNormalizeControlURL(t *testing.T) {
	cases := map[string]string{
		"":                                    tailscaleDefaultControlURL,
		"https://login.tailscale.com":         tailscaleDefaultControlURL,
		"HTTPS://Controlplane.Tailscale.com/": tailscaleDefaultControlURL,
		"https://hs.example.com:443/":         "https://hs.example.com",
		"https://HS.example.com:8443/base/":   "https://hs.example.com:8443/base",
		"http://10.0.0.1:80":                  "http://10.0.0.1",
	}
	for input, want := range cases {
		if got := normalizeControlURL(input); got != want {
			t.Errorf("normalizeControlURL(%q) = %q, want %q", input, got, want)
		}
	}
}

func TestTailscaleNodeKeySeparatesContexts(t *testing.T) {
	base := tailscaleNodeKey(1, "ts", "")
	if base != tailscaleNodeKey(1, "ts", "https://login.tailscale.com/") {
		t.Fatal("the default control server under another spelling changed the key")
	}
	for name, other := range map[string]string{
		"profile": tailscaleNodeKey(2, "ts", ""),
		"name":    tailscaleNodeKey(1, "ts2", ""),
		"control": tailscaleNodeKey(1, "ts", "https://hs.example.com"),
	} {
		if other == base {
			t.Errorf("a different %s kept the key", name)
		}
	}
	if len(base) != 32 || !isHex(base) {
		t.Fatalf("key %q is not an opaque hash", base)
	}
}

func isHex(value string) bool {
	return strings.Trim(value, "0123456789abcdef") == ""
}

func TestTailscaleStateDirIsDerivedPerNode(t *testing.T) {
	resetTailscaleSetup(t)
	if dir := tailscaleStateDir("ts", ""); dir != "" {
		t.Fatalf("without a payload the dir = %q, want the shared default", dir)
	}
	setTailscaleSetup(&TailscaleSetup{ProfileID: 7})
	dir := tailscaleStateDir("ts", "https://hs.example.com")
	want := filepath.Join(tailscaleNodesDir, tailscaleNodeKey(7, "ts", "https://hs.example.com"))
	if dir != want {
		t.Fatalf("dir = %q, want %q", dir, want)
	}
	if probe := tailscaleStateDir("ts"+validationNameSuffix, "https://hs.example.com"); probe != want {
		t.Fatalf("a validation probe got %q, want the node's own %q", probe, want)
	}
	if strings.Contains(dir, "hs.example.com") {
		t.Fatalf("dir %q leaks the control server", dir)
	}
}

const tailscaleProfile = `proxies:
  - {name: a, type: tailscale, exit-node: 100.64.0.9, accept-routes: true}
  - {name: b, type: tailscale, control-url: "https://hs.example.com"}
  - {name: c, type: socks5, server: 127.0.0.1, port: 1080}
proxy-groups:
  - {name: g, type: select, proxies: [a, b, c]}
rules:
  - MATCH,g
`

func proxyMapping(t *testing.T, root *yaml.Node, name string) map[string]any {
	t.Helper()
	var proxies []map[string]any
	if err := mappingValue(root, "proxies").Decode(&proxies); err != nil {
		t.Fatal(err)
	}
	for _, proxy := range proxies {
		if proxy["name"] == name {
			return proxy
		}
	}
	t.Fatalf("no proxy %q", name)
	return nil
}

func TestTailscaleOverridesMergeAfterProxies(t *testing.T) {
	resetTailscaleSetup(t)
	path := writeBaseProfile(t, tailscaleProfile)
	noExit, acceptRoutes := "", true
	setTailscaleSetup(&TailscaleSetup{
		ProfileID:    3,
		ConfigSource: tailscaleSourceSubscription,
		Nodes: []TailscaleNodeSetup{
			{Name: "a", ExitNode: &noExit},
			{Name: "b", ControlURL: "https://hs.example.com/", AcceptRoutes: &acceptRoutes},
		},
	})
	document, _, err := mergeProfileBase(&SetupBase{Path: path, Overlay: `{"mixed-port": 7890}`}, true, nil)
	if err != nil {
		t.Fatal(err)
	}
	root := document.Content[0]
	a, b := proxyMapping(t, root, "a"), proxyMapping(t, root, "b")
	if a["exit-node"] != "" || a["accept-routes"] != true {
		t.Fatalf("a = %v, want the exit node cleared and accept-routes kept", a)
	}
	if b["accept-routes"] != true || b["exit-node"] != nil {
		t.Fatalf("b = %v, want accept-routes set and nothing else", b)
	}
	if buf, _ := os.ReadFile(path); string(buf) != tailscaleProfile {
		t.Fatal("the profile file was rewritten")
	}

	settings := tailscaleSettings("a", "")
	if settings.ExitNode != (TailscaleExitNodeSetting{Value: "", Source: tailscaleSourceOverride}) {
		t.Fatalf("a exit node = %+v", settings.ExitNode)
	}
	if settings.AcceptRoutes != (TailscaleAcceptRoutesSetting{Value: true, Source: tailscaleSourceSubscription}) {
		t.Fatalf("a accept-routes = %+v", settings.AcceptRoutes)
	}
	settings = tailscaleSettings("b", "https://hs.example.com")
	if settings.ExitNode.Source != tailscaleSourceDefault || settings.AcceptRoutes.Source != tailscaleSourceOverride {
		t.Fatalf("b settings = %+v", settings)
	}
	if !tailscaleInProxies("a") || tailscaleInProxies("from-provider") {
		t.Fatal("a proxy of a provider counted as one of the proxies section")
	}

	built, _, err := mergeProfileBase(&SetupBase{Path: path, Overlay: `{}`}, false, nil)
	if err != nil {
		t.Fatal(err)
	}
	if proxyMapping(t, built.Content[0], "a")["exit-node"] != "100.64.0.9" {
		t.Fatal("a built profile took the overrides of the running one")
	}
}

func TestTailscaleOverrideOfAnotherControlServerIsIgnored(t *testing.T) {
	resetTailscaleSetup(t)
	path := writeBaseProfile(t, tailscaleProfile)
	acceptRoutes := true
	setTailscaleSetup(&TailscaleSetup{
		ProfileID: 3,
		Nodes:     []TailscaleNodeSetup{{Name: "b", AcceptRoutes: &acceptRoutes}},
	})
	document, _, err := mergeProfileBase(&SetupBase{Path: path, Overlay: `{}`}, true, nil)
	if err != nil {
		t.Fatal(err)
	}
	if b := proxyMapping(t, document.Content[0], "b"); b["accept-routes"] != nil {
		t.Fatalf("b = %v, took an override saved for the default control server", b)
	}
	if settings := tailscaleSettings("a", ""); settings.ExitNode.Source != tailscaleSourceProfile {
		t.Fatalf("a exit node source = %q, want profile", settings.ExitNode.Source)
	}
}

func TestTailscaleOverridesReachAWrittenConfig(t *testing.T) {
	resetTailscaleSetup(t)
	path := writeBaseProfile(t, tailscaleProfile)
	exitNode := "100.64.0.1"
	setTailscaleSetup(&TailscaleSetup{
		ProfileID: 1,
		Nodes:     []TailscaleNodeSetup{{Name: "a", ExitNode: &exitNode}},
	})
	buf, err := applyTailscaleOverridesToFile(path, []byte(tailscaleProfile))
	if err != nil {
		t.Fatal(err)
	}
	var document yaml.Node
	if err := yaml.Unmarshal(buf, &document); err != nil {
		t.Fatal(err)
	}
	if a := proxyMapping(t, document.Content[0], "a"); a["exit-node"] != exitNode {
		t.Fatalf("a = %v", a)
	}
}

func TestTailscalePinsHoldUntilAPayloadAgrees(t *testing.T) {
	resetTailscaleSetup(t)
	setTailscaleSetup(&TailscaleSetup{ProfileID: 1, Nodes: []TailscaleNodeSetup{{Name: "a"}}})
	loggedOut := true
	pinTailscale(tailscaleRef{name: "a"}, func(pin *tailscalePin) { pin.loggedOut = &loggedOut })
	if !tailscaleLoggedOut(tailscaleRef{name: "a"}) {
		t.Fatal("the logout guard did not apply at once")
	}
	setTailscaleSetup(&TailscaleSetup{ProfileID: 1, Nodes: []TailscaleNodeSetup{{Name: "a"}}})
	if !tailscaleLoggedOut(tailscaleRef{name: "a"}) {
		t.Fatal("a payload sent before the logout lifted its guard")
	}
	setTailscaleSetup(&TailscaleSetup{ProfileID: 1, Nodes: []TailscaleNodeSetup{{Name: "a", LoggedOut: true}}})
	setTailscaleSetup(&TailscaleSetup{ProfileID: 1, Nodes: []TailscaleNodeSetup{{Name: "a"}}})
	if tailscaleLoggedOut(tailscaleRef{name: "a"}) {
		t.Fatal("the pin outlived the payload that agreed with it")
	}
}

func TestValidateTailscaleAuthURL(t *testing.T) {
	cases := []struct {
		authURL, controlURL string
		ok                  bool
	}{
		{"https://login.tailscale.com/a/abc", "", true},
		{"https://controlplane.tailscale.com/a/abc", "https://login.tailscale.com", true},
		{"http://login.tailscale.com/a/abc", "", false},
		{"https://login.tailscale.com.evil.example/a/abc", "", false},
		{"https://user@login.tailscale.com/a/abc", "", false},
		{"https://login.tailscale.com:8443/a/abc", "", false},
		{"javascript:alert(1)", "", false},
		{"file:///etc/passwd", "", false},
		{"https://hs.example.com/register/abc", "https://hs.example.com", true},
		{"https://hs.example.com:8443/register/abc", "https://hs.example.com:8443/", true},
		{"https://hs.example.com/register/abc", "https://hs.example.com:8443", false},
		{"https://login.tailscale.com/a/abc", "https://hs.example.com", false},
		{"http://hs.example.com/register/abc", "http://hs.example.com", false},
	}
	for _, c := range cases {
		err := validateTailscaleAuthURL(c.authURL, c.controlURL)
		if (err == nil) != c.ok {
			t.Errorf("validateTailscaleAuthURL(%q, %q) = %v, want ok=%v", c.authURL, c.controlURL, err, c.ok)
		}
		if err != nil && !errors.Is(err, errTailscaleAuthURLRejected) {
			t.Errorf("rejection of %q is %v", c.authURL, err)
		}
	}
}

func TestTailscaleStateHasIdentity(t *testing.T) {
	dir := t.TempDir()
	if tailscaleStateHasIdentity(dir) {
		t.Fatal("an empty dir has an identity")
	}
	write := func(content string) {
		if err := os.WriteFile(filepath.Join(dir, "tailscaled.state"), []byte(content), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	write(`{"_profiles": "e30="}`)
	if tailscaleStateHasIdentity(dir) {
		t.Fatal("a logged-out state has an identity")
	}
	write(`{"_profiles": "eyJhYmMiOnt9fQ=="}`)
	if !tailscaleStateHasIdentity(dir) {
		t.Fatal("a state with a login profile has no identity")
	}
}
