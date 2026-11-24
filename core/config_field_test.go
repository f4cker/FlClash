package core

import (
	"encoding/json"
	"net/netip"
	"os"
	"regexp"
	"strings"
	"testing"

	"github.com/metacubex/mihomo/config"
	"go.yaml.in/yaml/v3"
)

// The app checks these fields as it saves them, and holds itself to the same
// file in test/common/config_field_test.dart.
type configFieldVector struct {
	Value string `json:"value"`
	OK    bool   `json:"ok"`
}

func loadConfigFieldVectors(t *testing.T) map[string][]configFieldVector {
	t.Helper()
	data, err := os.ReadFile("testdata/config_field_vectors.json")
	if err != nil {
		t.Fatal(err)
	}
	var vectors map[string][]configFieldVector
	if err := json.Unmarshal(data, &vectors); err != nil {
		t.Fatal(err)
	}
	return vectors
}

func parseFieldConfig(dns map[string]any, hosts map[string]any) error {
	doc := map[string]any{"dns": dns, "profile": map[string]any{"store-fake-ip": false}}
	if hosts != nil {
		doc["hosts"] = hosts
	}
	buf, err := yaml.Marshal(doc)
	if err != nil {
		return err
	}
	raw, err := config.UnmarshalRawConfig(buf)
	if err != nil {
		return err
	}
	_, err = config.ParseRawConfig(raw)
	return err
}

func fieldDNS() map[string]any {
	return map[string]any{
		"enable":             false,
		"nameserver":         []string{"223.5.5.5"},
		"default-nameserver": []string{"223.5.5.5"},
	}
}

// The app splits a hosts value as lib/common/string.dart does.
var hostsSeparators = regexp.MustCompile(`[, ;]+`)

// listener/sing_tun/server.go reads dns-hijack so, and fails TUN on an error.
func parseDNSHijack(d string) error {
	if _, after, ok := strings.Cut(d, "://"); ok {
		d = after
	}
	_, err := netip.ParseAddrPort(strings.Replace(d, "any", "0.0.0.0", 1))
	return err
}

func checkConfigField(kind, value string) error {
	dns := fieldDNS()
	switch kind {
	case "nameserver":
		dns["nameserver"] = []string{value}
	case "default-nameserver":
		dns["default-nameserver"] = []string{value}
	case "fake-ip-filter-rule":
		dns["enhanced-mode"] = "fake-ip"
		dns["fake-ip-range"] = "198.18.0.1/16"
		dns["fake-ip-filter-mode"] = "rule"
		dns["fake-ip-filter"] = []string{value}
	case "fake-ip-filter-domain":
		dns["enhanced-mode"] = "fake-ip"
		dns["fake-ip-range"] = "198.18.0.1/16"
		dns["fake-ip-filter"] = []string{value}
	case "fake-ip-range", "fake-ip-range6":
		dns["enhanced-mode"] = "fake-ip"
		dns["fake-ip-range"] = ""
		dns[kind] = value
	case "dns-hijack":
		return parseDNSHijack(value)
	case "hosts":
		var parts []string
		for _, part := range hostsSeparators.Split(value, -1) {
			if part != "" {
				parts = append(parts, part)
			}
		}
		var hostValue any = value
		if len(parts) > 1 {
			hostValue = parts
		}
		return parseFieldConfig(dns, map[string]any{"example.com": hostValue})
	}
	return parseFieldConfig(dns, nil)
}

func TestConfigFieldVectors(t *testing.T) {
	for kind, vectors := range loadConfigFieldVectors(t) {
		for _, vector := range vectors {
			err := checkConfigField(kind, vector.Value)
			if (err == nil) != vector.OK {
				t.Errorf("%s %q: want ok=%v, got %v", kind, vector.Value, vector.OK, err)
			}
		}
	}
}

// The same maps test/common/config_field_test.dart finds cycles in.
func TestHostsCycles(t *testing.T) {
	for _, tc := range []struct {
		hosts map[string]any
		cycle bool
	}{
		{map[string]any{"a.com": "b.com", "b.com": "a.com."}, true},
		{map[string]any{"a.com": "b.com", "b.com": "c.com", "c.com": "a.com"}, true},
		{map[string]any{"a.com": "b.com", "b.com": "1.1.1.1"}, false},
		{map[string]any{"a.com": "b.com", "c.com": "b.com"}, false},
	} {
		err := parseFieldConfig(fieldDNS(), tc.hosts)
		if (err != nil) != tc.cycle {
			t.Errorf("%v: want cycle=%v, got %v", tc.hosts, tc.cycle, err)
		}
	}
}
