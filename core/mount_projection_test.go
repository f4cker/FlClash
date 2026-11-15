package core

import (
	"crypto/md5"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"testing"

	"go.yaml.in/yaml/v3"
)

func TestMountTargetProjectionIgnoresNonNodeSections(t *testing.T) {
	text := `proxies:
  - {name: node, type: direct}
proxy-groups:
  - {name: Auto, type: select, include-all-proxies: true}
dns: not-a-dns-config
rules: not-a-rule-list
rule-providers:
  remote: {type: http, url: 'https://must-not-resolve.invalid/rules'}
`
	path := filepath.Join(t.TempDir(), "42.yaml")
	if err := os.WriteFile(path, []byte(text), 0600); err != nil {
		t.Fatal(err)
	}
	params := MountTargetParams{Base: &SetupBase{Path: path, Overlay: "invalid: ["}, Projection: true}
	result, err := handleInspectMountTarget(params)
	if err != nil {
		t.Fatal(err)
	}
	if len(result.Groups) != 1 || result.Groups[0].Name != "Auto" || result.Groups[0].Kind != mountGroupAuto {
		t.Fatalf("unexpected projection: %#v", result)
	}
	root, err := mountTargetProjection(params)
	if err != nil {
		t.Fatal(err)
	}
	for _, key := range []string{"dns", "rules", "rule-providers"} {
		if mappingValue(root, key) != nil {
			t.Fatalf("projection contains %s", key)
		}
	}
	if _, err := handleInspectMountTarget(MountTargetParams{Base: params.Base}); err == nil {
		t.Fatal("authoritative inspection unexpectedly accepted invalid overlay")
	}
	if after, err := os.ReadFile(path); err != nil || string(after) != text {
		t.Fatalf("projection changed source: %v", err)
	}
}

func TestMountTargetProjectionConfinesBaseProvidersWithoutWriting(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "42.yaml")
	text := `proxy-groups:
  - {name: Auto, type: select, use: [remote, local, embedded]}
proxy-providers:
  remote: {type: http, url: 'https://must-not-resolve.invalid/nodes', path: /must-not-read/nodes}
  local: {type: file, path: /must-not-read/local}
  embedded: {type: inline, payload: [{name: embedded, type: direct}]}
`
	if err := os.WriteFile(path, []byte(text), 0600); err != nil {
		t.Fatal(err)
	}
	root, err := mountTargetProjection(MountTargetParams{Base: &SetupBase{Path: path}, Projection: true})
	if err != nil {
		t.Fatal(err)
	}
	var providers map[string]map[string]any
	if err := mappingValue(root, "proxy-providers").Decode(&providers); err != nil {
		t.Fatal(err)
	}
	for name, key := range map[string]string{"remote": "remote@https://must-not-resolve.invalid/nodes", "local": "proxy-providers/local"} {
		want := filepath.Join(dir, "providers", "42", "proxies", fmt.Sprintf("%x", md5.Sum([]byte(key))))
		if providers[name]["path"] != want {
			t.Fatalf("%s: path = %v, want %s", name, providers[name]["path"], want)
		}
	}
	if _, exists := providers["embedded"]["path"]; exists {
		t.Fatal("inline provider gained a path")
	}
	if _, err := handleInspectMountTarget(MountTargetParams{Base: &SetupBase{Path: path}, Projection: true}); err != nil {
		t.Fatal(err)
	}
	entries, err := os.ReadDir(dir)
	if err != nil || len(entries) != 1 || entries[0].Name() != "42.yaml" {
		t.Fatalf("projection wrote provider files: %v, %v", entries, err)
	}
}

func TestMountTargetProjectionPreservesCustomDefinitionsAndAliases(t *testing.T) {
	text := `proxies: &nodes [{name: Relay, type: direct}]
proxy-providers:
  app: {type: inline, payload: *nodes, override: {additional-prefix: '[app] '}}
proxy-groups:
  - {name: 'My group', type: select, use: [app], hidden: true, filter: 'HK', empty-fallback: REJECT}
`
	got, err := handleInspectMountTarget(MountTargetParams{Config: text, Projection: true})
	if err != nil {
		t.Fatal(err)
	}
	var document yaml.Node
	if err := yaml.Unmarshal([]byte(text), &document); err != nil {
		t.Fatal(err)
	}
	want, err := inspectMountTarget(document.Content[0], 0)
	if err != nil || !reflect.DeepEqual(*got, want) {
		t.Fatalf("custom semantics changed: got %#v want %#v, %v", got, want, err)
	}
}
