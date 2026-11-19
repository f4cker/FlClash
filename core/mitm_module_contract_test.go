package core

import (
	"encoding/json"
	"net/http"
	"os"
	"strings"
	"testing"
)

func TestFlashNormalizedModuleContract(t *testing.T) {
	path := os.Getenv("FLASH_MODULE_CONTRACT")
	if path == "" {
		t.Skip("run through test/common/mitm_flash_test.dart")
	}
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var fixtures []struct {
		Name    string            `json:"name"`
		Rewrite []MitmRewriteRule `json:"rewrite"`
		Script  []string          `json:"script"`
	}
	if err := json.Unmarshal(data, &fixtures); err != nil {
		t.Fatal(err)
	}
	if len(fixtures) != 4 {
		t.Fatalf("formats = %d", len(fixtures))
	}
	for _, fixture := range fixtures {
		t.Run(fixture.Name, func(t *testing.T) {
			withMitmRewrite(t, 0, fixture.Rewrite...)
			x := mitmRewriteBegin("https", "example.com", 0, "/ad", false)
			decision := x.request(http.Header{})
			if decision.local == nil {
				t.Fatal("imported rejection did not execute")
			}
			if len(fixture.Script) != 1 {
				t.Fatal("missing imported HTTP script")
			}
			script := testScript(t, strings.ReplaceAll(fixture.Script[0], "fixture.js", "FILE"), `$done({body: "from-import"})`)
			result := script.run(scriptResponseInput("original"))
			if result.skip != "" || result.out == nil || string(result.out.body) != "from-import" {
				t.Fatalf("imported script did not execute: %+v", result)
			}
		})
	}
}
