package core

import (
	"bytes"
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"testing"

	"github.com/metacubex/mihomo/config"
	"go.yaml.in/yaml/v3"
)

func TestSetupRejectsOrdinaryCandidatesBeforeReplacingHealthyListeners(t *testing.T) {
	for name, overlay := range map[string]string{
		"yaml":            "dns: [unterminated",
		"group":           "proxy-groups: [{name: bad, type: select, proxies: [missing]}]",
		"rule":            "rules: [\"MATCH,missing\"]",
		"dns":             "dns: {enable: true, nameserver: []}",
		"mixed-tailscale": "proxies: [{name: ts, type: Tailscale}]",
		"mixed-easytier":  "proxies: [{name: mesh, type: EasyTier}]",
	} {
		t.Run(name, func(t *testing.T) {
			withMountHome(t)
			resetTailscaleSetup(t)
			setMountState(nil, false, false)
			t.Cleanup(func() { setMountState(nil, false, false) })
			running := listenerTestConfig(t, freeLoopbackPort(t))
			startListenersFor(t, running)
			ports := handleListeningPorts()
			if ports.MixedPort == 0 {
				t.Fatal("healthy listener was not bound")
			}
			before := []byte("rules: [\"MATCH,REJECT\"]\n")
			if err := os.WriteFile(runningConfigPath(), before, 0o600); err != nil {
				t.Fatal(err)
			}
			setup := &TailscaleSetup{ProfileID: 7}
			setTailscaleSetup(setup)
			tailscaleConfigs["old"] = tailscaleConfiguredValues{}
			url, skip := currentTestURL(), skipCertVerify.Load()
			exitRevision := tailscaleExitSnapshot()
			err := applyConfig(&SetupParams{
				Base:      &SetupBase{Path: writeBaseProfile(t, "{}"), Overlay: overlay},
				Options:   CoreOptions{TestURL: "https://candidate.invalid", SkipCertVerify: !skip},
				Tailscale: &TailscaleSetup{ProfileID: 8},
			})
			outcome := "unknown"
			if name == "yaml" || name == "mixed-tailscale" || name == "mixed-easytier" {
				outcome = "kept"
			}
			var rejected *MethodError
			if !errors.As(err, &rejected) || rejected.Code != "config_rejected" ||
				!reflect.DeepEqual(rejected.Details, map[string]string{"outcome": outcome}) {
				t.Fatalf("applyConfig = %v, want config_rejected %s", err, outcome)
			}
			if currentConfig != running || handleListeningPorts() != ports {
				t.Error("rejection replaced the actual currentConfig or bound listeners")
			}
			after, err := os.ReadFile(runningConfigPath())
			if err != nil || !bytes.Equal(after, before) {
				t.Errorf("running file changed: %q, %v", after, err)
			}
			if currentTestURL() != url || skipCertVerify.Load() != skip {
				t.Error("rejection changed Core options")
			}
			if tailscaleSetup != setup || len(tailscaleConfigs) != 1 || tailscaleExitSnapshot() != exitRevision {
				t.Error("rejection changed Tailscale setup, configured values or exit revision")
			}
		})
	}
}

func TestWholeProfileCanUseAnExistingSetupBaseAsCandidate(t *testing.T) {
	withMountHome(t)
	resetTailscaleSetup(t)
	before := []byte("rules: [\"MATCH,REJECT\"]\n")
	if err := os.WriteFile(runningConfigPath(), before, 0o600); err != nil {
		t.Fatal(err)
	}
	path := writeBaseProfile(t, "proxies: [{name: local, type: socks5, server: 192.0.2.1, port: 1080}]\nrules: [\"MATCH,local\"]\n")
	candidate, err := prepareSetupConfig(&SetupParams{Base: &SetupBase{
		Path: path, Overlay: "mixed-port: 0\nallow-lan: false\nrules: []\n",
	}})
	if err != nil {
		t.Fatal(err)
	}
	defer os.Remove(candidate.path)
	if candidate.path == runningConfigPath() || filepath.Dir(candidate.path) != filepath.Dir(runningConfigPath()) {
		t.Fatal("candidate is not a separate same-directory staging file")
	}
	raw, err := readRawConfig(candidate.path)
	if err != nil || raw.MixedPort != 0 || raw.AllowLan || len(raw.Proxy) != 1 ||
		!reflect.DeepEqual(raw.Rule, []string{"MATCH,local"}) {
		t.Fatalf("candidate = %+v, %v; want exact whole profile without duplicate rules", raw, err)
	}
	after, err := os.ReadFile(runningConfigPath())
	if err != nil || !bytes.Equal(after, before) {
		t.Fatal("preparation replaced the running file")
	}
}

func TestCandidateTailscaleOverridesUseIncomingSetupWithoutPublishing(t *testing.T) {
	resetTailscaleSetup(t)
	old := &TailscaleSetup{ProfileID: 7}
	setTailscaleSetup(old)
	tailscaleConfigs["old"] = tailscaleConfiguredValues{}
	exit := "100.64.0.2"
	routes := false
	incoming := &TailscaleSetup{ProfileID: 8, Nodes: []TailscaleNodeSetup{{Name: "ts", ExitNode: &exit, AcceptRoutes: &routes}}}
	pinned := "100.64.0.3"
	key := tailscaleNodeKey(8, "ts", "")
	tailscalePins[key] = &tailscalePin{exitNode: &pinned}
	var document yaml.Node
	if err := yaml.Unmarshal([]byte("proxies: [{name: ts, type: tailscale, accept-routes: true}]"), &document); err != nil {
		t.Fatal(err)
	}
	tailscaleMu.Lock()
	configured := tailscaleOverridesForSetupLocked(document.Content[0], incoming)
	tailscaleMu.Unlock()
	raw := config.DefaultRawConfig()
	if err := document.Decode(raw); err != nil {
		t.Fatal(err)
	}
	if raw.Proxy[0]["exit-node"] != pinned || raw.Proxy[0]["accept-routes"] != false {
		t.Fatalf("candidate overrides = %+v, want incoming setup plus pin", raw.Proxy)
	}
	if configured["ts"].acceptRoutes == nil || !*configured["ts"].acceptRoutes ||
		tailscaleSetup != old || len(tailscaleConfigs) != 1 || tailscalePins[key].exitNode != &pinned {
		t.Error("candidate preparation published settings or consumed a pin")
	}
}

func TestLoadConfigWithBaseRejectsSemanticErrorsBeforeWriting(t *testing.T) {
	resetTailscaleSetup(t)
	path := filepath.Join(t.TempDir(), "config.yaml")
	before := []byte("rules: [\"MATCH,REJECT\"]\n")
	if err := os.WriteFile(path, before, 0o600); err != nil {
		t.Fatal(err)
	}
	_, _, err := loadConfigWithBase(&SetupBase{
		Path: writeBaseProfile(t, "{}"), Overlay: "dns: {enable: true, nameserver: []}",
	}, path, nil)
	if err == nil {
		t.Fatal("semantic DNS error was accepted")
	}
	after, readErr := os.ReadFile(path)
	if readErr != nil || !bytes.Equal(after, before) {
		t.Fatal("semantic rejection overwrote the running file")
	}
}

func TestColdInvalidTunRequestDoesNotInstallDefaultRouting(t *testing.T) {
	withMountHome(t)
	withCurrentConfig(t, nil)
	resetTailscaleSetup(t)
	err := applyConfig(&SetupParams{Base: &SetupBase{
		Path: writeBaseProfile(t, "{}"), Overlay: "tun: {enable: true}\ndns: {enable: true, nameserver: []}\n",
	}})
	var rejected *MethodError
	if !errors.As(err, &rejected) || rejected.Code != "config_rejected" ||
		!reflect.DeepEqual(rejected.Details, map[string]string{"outcome": "unknown"}) {
		t.Fatalf("applyConfig = %v, want explicit semantic-preflight uncertainty", err)
	}
	if currentConfig != nil {
		t.Error("invalid requested TUN installed a default config")
	}
	if _, err := os.Stat(runningConfigPath()); !os.IsNotExist(err) {
		t.Errorf("running config was written on cold rejection: %v", err)
	}
}
