package core

import (
	"os"
	"path/filepath"
	"reflect"
	"testing"

	"github.com/metacubex/mihomo/config"
)

func TestHandleGetConfigKeepsAnUnquotedShortIDAsWritten(t *testing.T) {
	profile := `proxies:
  - name: octal
    type: vless
    reality-opts: {public-key: k, short-id: 0123}
  - name: zeros
    type: vless
    reality-opts:
      short-id: 00
  - name: exponent
    type: vless
    reality-opts:
      short-id: 1e5
  - name: quoted
    type: vless
    reality-opts:
      short-id: "0189"
  - name: hex
    type: vless
    reality-opts:
      short-id: 0a1b
listeners:
  - name: in
    type: vless
    reality-config:
      short-id: [01234567, ""]
`
	path := filepath.Join(t.TempDir(), "profile.yaml")
	if err := os.WriteFile(path, []byte(profile), 0o600); err != nil {
		t.Fatalf("write profile: %v", err)
	}

	raw, err := readRawConfig(path)
	if err != nil {
		t.Fatalf("handleGetConfig = %v", err)
	}

	want := map[string]string{
		"octal":    "0123",
		"zeros":    "00",
		"exponent": "1e5",
		"quoted":   "0189",
		"hex":      "0a1b",
	}
	for _, proxy := range raw.Proxy {
		name := proxy["name"].(string)
		got := proxy["reality-opts"].(map[string]any)["short-id"]
		if got != want[name] {
			t.Errorf("%s short-id = %#v, want %q", name, got, want[name])
		}
	}
	ids := raw.Listeners[0]["reality-config"].(map[string]any)["short-id"].([]any)
	if ids[0] != "01234567" || ids[1] != "" {
		t.Errorf("listener short-id = %#v, want [01234567 \"\"]", ids)
	}
}

func TestHandleGetConfigLeavesProfilesWithoutShortIDsToMihomo(t *testing.T) {
	path := filepath.Join(t.TempDir(), "profile.yaml")
	if err := os.WriteFile(path, []byte("mixed-port: 7899\n"), 0o600); err != nil {
		t.Fatalf("write profile: %v", err)
	}

	raw, err := readRawConfig(path)
	if err != nil {
		t.Fatalf("handleGetConfig = %v", err)
	}
	if raw.MixedPort != 7899 || raw.Mode.String() == "" {
		t.Errorf("raw config = port %d mode %q, want 7899 and the default mode", raw.MixedPort, raw.Mode)
	}
}

func TestUnmarshalRawConfigWithoutRetaggingMatchesMihomo(t *testing.T) {
	profiles := []string{
		`# short-id
mixed-port: 7899
`,
		`# short-id
`,
		`x-defaults: &defaults {type: vless, reality-opts: {short-id: "0123"}}
proxies:
  - {<<: *defaults, name: a}
rules: ["MATCH,DIRECT"]
`,
		`proxies: [{name: a, reality-opts: {short-id: abcdef}}]`,
		`# short-id
mixed-port: invalid
`,
		`# short-id
mixed-port: 1
mixed-port: 2
`,
		`# short-id
proxies: [`,
	}
	for _, profile := range profiles {
		t.Run(profile, func(t *testing.T) {
			got, err := unmarshalRawConfig([]byte(profile))
			want, wantErr := config.UnmarshalRawConfig([]byte(profile))
			if (err == nil) != (wantErr == nil) {
				t.Fatalf("error = %v, want %v", err, wantErr)
			}
			if err == nil && !reflect.DeepEqual(got, want) {
				t.Error("decoded configuration differs from mihomo")
			}
		})
	}
}
