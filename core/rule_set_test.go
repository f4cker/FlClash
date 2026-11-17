package core

import (
	"errors"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	"github.com/metacubex/mihomo/component/resource"
	"github.com/metacubex/mihomo/constant"
	cp "github.com/metacubex/mihomo/constant/provider"
	rp "github.com/metacubex/mihomo/rules/provider"
	"go.yaml.in/yaml/v3"
)

func TestClassifyRuleSetPicksTheBehaviorTheEntriesFit(t *testing.T) {
	cases := []struct {
		name     string
		entries  []string
		behavior cp.RuleBehavior
		keys     []string
	}{
		{"domains", []string{"example.com", "+.example.org", "*.example.net"}, cp.Domain, []string{"example.com", "+.example.org", "*.example.net"}},
		{"ranges and bare addresses", []string{"10.0.0.0/8", "1.1.1.1", "2001:db8::1"}, cp.IPCIDR, []string{"10.0.0.0/8", "1.1.1.1/32", "2001:db8::1/128"}},
		{"domain rules", []string{"DOMAIN,example.com", "domain-suffix, example.org"}, cp.Domain, []string{"example.com", "+.example.org"}},
		{"range rules", []string{"IP-CIDR,10.0.0.0/8", "IP-CIDR6,2001:db8::/32"}, cp.IPCIDR, []string{"10.0.0.0/8", "2001:db8::/32"}},
		{"a keyword rule", []string{"DOMAIN,example.com", "DOMAIN-KEYWORD,example"}, cp.Classical, nil},
		{"a rule with an option", []string{"IP-CIDR,10.0.0.0/8,no-resolve"}, cp.Classical, nil},
		{"domain and range rules together", []string{"DOMAIN,example.com", "IP-CIDR,10.0.0.0/8"}, cp.Classical, nil},
		{"a wildcard in a literal domain rule", []string{"DOMAIN-SUFFIX,.example.com"}, cp.Classical, nil},
		{"a stray line among rules", []string{"DOMAIN,example.com", "example.org"}, cp.Classical, nil},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			behavior, keys, err := classifyRuleSet(c.entries)
			if err != nil {
				t.Fatalf("classify: %v", err)
			}
			if behavior != c.behavior || !slices.Equal(keys, c.keys) {
				t.Fatalf("classify = %s %q, want %s %q", behavior, keys, c.behavior, c.keys)
			}
		})
	}
}

func TestClassifyRuleSetRejectsWhatHasNoBehavior(t *testing.T) {
	if _, _, err := classifyRuleSet(nil); err != errRuleSetEmpty {
		t.Errorf("empty set: err = %v, want %v", err, errRuleSetEmpty)
	}
	if _, _, err := classifyRuleSet([]string{"example.com", "10.0.0.0/8"}); err != errRuleSetMixed {
		t.Errorf("mixed set: err = %v, want %v", err, errRuleSetMixed)
	}
}

func TestCompileRuleSetReadsEachSourceFormat(t *testing.T) {
	var domainMrs strings.Builder
	if err := rp.ConvertToMrs([]byte("example.com\nexample.org\n"), cp.Domain, cp.TextRule, &domainMrs); err != nil {
		t.Fatal(err)
	}
	cases := []struct {
		name     string
		source   string
		info     RuleSetInfo
		compiles bool
	}{
		{"yaml domains", "payload:\n  - '+.example.com'\n", RuleSetInfo{"domain", "yaml", 1}, true},
		{"text ranges with comments", "# ranges\n10.0.0.0/8\n\n// more\n192.168.0.0/16\n", RuleSetInfo{"ipcidr", "text", 2}, true},
		{"yaml classical", "payload:\n  - DOMAIN-KEYWORD,example\n", RuleSetInfo{"classical", "yaml", 1}, false},
		{"text classical", "PROCESS-NAME,curl\n", RuleSetInfo{"classical", "text", 1}, false},
		{"mrs", domainMrs.String(), RuleSetInfo{"domain", "mrs", 2}, false},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			info, mrs, err := compileRuleSet([]byte(c.source), false)
			if err != nil {
				t.Fatalf("compile: %v", err)
			}
			if *info != c.info {
				t.Fatalf("info = %+v, want %+v", *info, c.info)
			}
			if (mrs != nil) != c.compiles {
				t.Fatalf("produced mrs = %t, want %t", mrs != nil, c.compiles)
			}
		})
	}
}

func TestCompileRuleSetRejectsUnusableSources(t *testing.T) {
	cases := map[string]struct {
		source string
		err    error
	}{
		"empty yaml":         {"payload: []\n", errRuleSetEmpty},
		"only invalid names": {"bad/name\n", errRuleSetEmpty},
		"mixed lines":        {"example.com\n10.0.0.0/8\n", errRuleSetMixed},
		"broken mrs":         {string(zstdMagic) + "garbage", errRuleSetInvalid},
	}
	for name, c := range cases {
		if _, _, err := compileRuleSet([]byte(c.source), false); err != c.err {
			t.Errorf("%s: err = %v, want %v", name, err, c.err)
		}
	}
}

func TestCompileRuleSetKeepsAnEmptySetAsClassical(t *testing.T) {
	cases := map[string]RuleSetInfo{
		"":                {"classical", "text", 0},
		"# nothing yet\n": {"classical", "text", 0},
		"payload: []\n":   {"classical", "yaml", 0},
	}
	for source, want := range cases {
		info, mrs, err := compileRuleSet([]byte(source), true)
		if err != nil || *info != want || mrs != nil {
			t.Errorf("%q: info = %+v, mrs = %t, err = %v; want %+v", source, info, mrs != nil, err, want)
		}
	}
	if _, _, err := compileRuleSet([]byte("bad/name\n"), true); err != errRuleSetEmpty {
		t.Errorf("entries none of which parse: err = %v, want %v", err, errRuleSetEmpty)
	}
}

func withRuleSetHome(t *testing.T) string {
	t.Helper()
	previous := constant.Path.HomeDir()
	home := t.TempDir()
	constant.SetHomeDir(home)
	isInit.Store(true)
	t.Cleanup(func() {
		constant.SetHomeDir(previous)
		isInit.Store(false)
	})
	return filepath.Join(home, "providers", "rules")
}

func TestHandleCompileRuleSetWritesTheMrsBesideTheSource(t *testing.T) {
	dir := withRuleSetHome(t)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "set"), []byte("DOMAIN-SUFFIX,example.com\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	info, err := handleCompileRuleSet(CompileRuleSetParams{Name: "set"})
	if err != nil {
		t.Fatalf("compile: %v", err)
	}
	if *info != (RuleSetInfo{"domain", "text", 1}) {
		t.Fatalf("info = %+v", *info)
	}
	dump, err := handleDumpRuleSet(PathParams{Path: filepath.Join(dir, "set.mrs")})
	if err != nil || dump != "+.example.com\n" {
		t.Fatalf("dump = %q, %v", dump, err)
	}
}

func TestHandleCompileRuleSetWritesThroughNoPlantedLink(t *testing.T) {
	dir := withRuleSetHome(t)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "set"), []byte("DOMAIN-SUFFIX,example.com\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	outside := filepath.Join(t.TempDir(), "outside")
	if err := os.WriteFile(outside, []byte("kept"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(outside, filepath.Join(dir, "set.mrs.tmp")); err != nil {
		t.Skipf("symlink: %v", err)
	}
	if _, err := handleCompileRuleSet(CompileRuleSetParams{Name: "set"}); err != nil {
		t.Fatalf("compile: %v", err)
	}
	if got, _ := os.ReadFile(outside); string(got) != "kept" {
		t.Fatalf("the link target was written: %q", got)
	}
	if info, err := os.Lstat(filepath.Join(dir, "set.mrs")); err != nil || !info.Mode().IsRegular() {
		t.Fatalf("set.mrs = %v, %v", info, err)
	}
}

func TestHandleCompileRuleSetTakesOnlyAFileName(t *testing.T) {
	withRuleSetHome(t)
	for _, name := range []string{"", "..", "../profiles/1", "a/b", `a\b`, ".hidden"} {
		_, err := handleCompileRuleSet(CompileRuleSetParams{Name: name})
		var methodErr *MethodError
		if !errors.As(err, &methodErr) || methodErr.Code != "invalid_arguments" {
			t.Errorf("name %q: err = %v, want invalid_arguments", name, err)
		}
	}
}

func TestHandleCompileRuleSetKeepsTheLastDownloadOnFailure(t *testing.T) {
	dir := withRuleSetHome(t)
	body := "example.com\n"
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(body))
	}))
	defer server.Close()

	if _, err := handleCompileRuleSet(CompileRuleSetParams{Name: "remote", URL: server.URL}); err != nil {
		t.Fatalf("first download: %v", err)
	}
	body = "example.com\n10.0.0.0/8\n"
	if _, err := handleCompileRuleSet(CompileRuleSetParams{Name: "remote", URL: server.URL}); err != errRuleSetMixed {
		t.Fatalf("second download: err = %v, want %v", err, errRuleSetMixed)
	}
	source, err := os.ReadFile(filepath.Join(dir, "remote"))
	if err != nil || string(source) != "example.com\n" {
		t.Fatalf("source = %q, %v; want the first download", source, err)
	}
	if dump, err := handleDumpRuleSet(PathParams{Path: filepath.Join(dir, "remote.mrs")}); err != nil || dump != "example.com\n" {
		t.Fatalf("mrs dump = %q, %v; want the first download", dump, err)
	}
}

func TestHandleCompileRuleSetRejectsAnEmptyDownload(t *testing.T) {
	withRuleSetHome(t)
	server := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {}))
	defer server.Close()

	if _, err := handleCompileRuleSet(CompileRuleSetParams{Name: "remote", URL: server.URL}); err != errRuleSetEmpty {
		t.Fatalf("err = %v, want %v", err, errRuleSetEmpty)
	}
}

func TestHandleCompileRuleSetReportsAFailedRequest(t *testing.T) {
	withRuleSetHome(t)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusNotFound)
	}))
	defer server.Close()

	_, err := handleCompileRuleSet(CompileRuleSetParams{Name: "remote", URL: server.URL})
	var methodErr *MethodError
	if !errors.As(err, &methodErr) || methodErr.Code != "request_bad_response" {
		t.Fatalf("err = %v, want request_bad_response", err)
	}
	if details, _ := methodErr.Details.(map[string]any); details["statusCode"] != http.StatusNotFound {
		t.Fatalf("details = %v, want the status code", methodErr.Details)
	}
}

// Consumes the actual Flutter generator's fixture. No provider is initialized,
// so constructing the HTTP vehicles cannot make a network request.
func TestGeneratedProviderFixtureOffline(t *testing.T) {
	home := os.Getenv("FLASH_GENERATED_HOME")
	if home == "" {
		t.Skip("set FLASH_GENERATED_HOME to the generated test fixture")
	}
	previous := constant.Path.HomeDir()
	constant.SetHomeDir(home)
	t.Cleanup(func() { constant.SetHomeDir(previous) })
	data, err := os.ReadFile(filepath.Join(home, "generated.yaml"))
	if err != nil {
		t.Fatal(err)
	}
	var config struct {
		Providers map[string]map[string]any `yaml:"rule-providers"`
		Rules     []string                  `yaml:"rules"`
	}
	if err := yaml.Unmarshal(data, &config); err != nil {
		t.Fatal(err)
	}
	added := config.Providers["flash-added-ads"]
	subscription := config.Providers["ads"]
	if added == nil || subscription == nil {
		t.Fatalf("providers = %#v", config.Providers)
	}
	if added["path"] == subscription["path"] {
		t.Fatal("added and subscription provider share a path")
	}
	if !slices.Contains(config.Rules, "RULE-SET,flash-added-ads,REJECT") || !slices.Contains(config.Rules, "RULE-SET,ads,DIRECT") {
		t.Fatalf("rules = %v", config.Rules)
	}
	for name, definition := range config.Providers {
		p, err := rp.ParseRuleProvider(name, definition, nil, func(string) resource.BundleFile { return nil })
		if err != nil {
			t.Fatalf("%s provider parse: %v", name, err)
		}
		if name == "flash-added-ads" && p.Behavior() != cp.Domain {
			t.Fatalf("added behavior: %v", p.Behavior())
		}
		if name == "ads" && p.Behavior() != cp.IPCIDR {
			t.Fatalf("subscription behavior: %v", p.Behavior())
		}
	}
	content, err := os.ReadFile(added["path"].(string))
	if err != nil {
		t.Fatal(err)
	}
	strategy, err := rp.ParseRuleSet(content, cp.Domain, cp.YamlRule, nil)
	if err != nil {
		t.Fatal(err)
	}
	matcher := strategy.(interface {
		Match(*constant.Metadata, constant.RuleMatchHelper) bool
		Count() int
	})
	if matcher.Count() != 2 || !matcher.Match(&constant.Metadata{Host: "localhost"}, constant.RuleMatchHelper{}) || !matcher.Match(&constant.Metadata{Host: "www.example.test"}, constant.RuleMatchHelper{}) {
		t.Fatalf("generated content count or match failed: %d", matcher.Count())
	}
}

func TestCoreDomainSingleLabelAndSuffixPatterns(t *testing.T) {
	for _, source := range []string{"localhost\n", "+.localhost\n", ".localhost\n"} {
		strategy, err := rp.ParseRuleSet([]byte(source), cp.Domain, cp.TextRule, nil)
		if err != nil {
			t.Fatalf("%q: %v", source, err)
		}
		m := strategy.(interface {
			Count() int
			Match(*constant.Metadata, constant.RuleMatchHelper) bool
		})
		if m.Count() != 1 {
			t.Fatalf("%q count = %d", source, m.Count())
		}
		host := "localhost"
		if strings.HasPrefix(source, ".") {
			host = "x.localhost"
		}
		if !m.Match(&constant.Metadata{Host: host}, constant.RuleMatchHelper{}) {
			t.Fatalf("%q did not match %q", source, host)
		}
	}
}
