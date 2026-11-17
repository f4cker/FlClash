package core

import (
	"encoding/json"
	"os"
	"testing"
)

type mitmHostVectors struct {
	Validate []struct {
		Line  string `json:"line"`
		Issue string `json:"issue"`
	} `json:"validate"`
	Match []struct {
		List    []string `json:"list"`
		Host    string   `json:"host"`
		Decrypt bool     `json:"decrypt"`
	} `json:"match"`
}

func loadMitmHostVectors(t *testing.T) mitmHostVectors {
	t.Helper()
	data, err := os.ReadFile("testdata/mitm_hostname_vectors.json")
	if err != nil {
		t.Fatal(err)
	}
	var vectors mitmHostVectors
	if err := json.Unmarshal(data, &vectors); err != nil {
		t.Fatal(err)
	}
	if len(vectors.Validate) == 0 || len(vectors.Match) == 0 {
		t.Fatal("no vectors")
	}
	return vectors
}

func TestMitmHostnameValidationVectors(t *testing.T) {
	for _, vector := range loadMitmHostVectors(t).Validate {
		if _, issue := parseMitmHostEntry(vector.Line); string(issue) != vector.Issue {
			t.Errorf("%q: issue %q, want %q", vector.Line, issue, vector.Issue)
		}
	}
}

func TestMitmHostnameMatchVectors(t *testing.T) {
	for _, vector := range loadMitmHostVectors(t).Match {
		if got := compileMitmHosts(vector.List).Match(vector.Host); got != vector.Decrypt {
			t.Errorf("%v / %q: decrypt %v, want %v", vector.List, vector.Host, got, vector.Decrypt)
		}
	}
}

func TestEveryAppleDomainIsRefusedAndNeverMatched(t *testing.T) {
	for _, domain := range mitmAppleDomains {
		for _, line := range []string{domain, "*." + domain, "www." + domain} {
			if _, issue := parseMitmHostEntry(line); issue == "" {
				t.Errorf("%q accepted", line)
			}
		}
		matcher := &mitmHostMatcher{entries: []mitmHostEntry{{base: "www." + domain}, {wildcard: true, base: domain}}}
		if matcher.Match("www." + domain) {
			t.Errorf("%s matched through an entry that skipped validation", domain)
		}
	}
}

func TestMitmValidateAnswersEveryList(t *testing.T) {
	result := handleMitmValidate(map[string][]string{
		"hostname":    {"api.example.com", "*.com", "apple.com", "-x.example.com", "bad host"},
		"url-rewrite": {"anything"},
	})
	if len(result) != len(mitmRuleLists) {
		t.Fatalf("lists %v", result)
	}
	for _, list := range mitmRuleLists[1:] {
		if issues := result[list]; issues == nil || len(issues) != 0 {
			t.Errorf("%s: %v", list, issues)
		}
	}
	issues := result["hostname"]
	want := []struct {
		index int
		code  mitmHostIssue
	}{{1, mitmHostOverBroad}, {2, mitmHostAppleOwned}, {4, mitmHostInvalid}}
	if len(issues) != len(want) {
		t.Fatalf("hostname issues %v", issues)
	}
	for i, issue := range issues {
		if issue.Index != want[i].index || issue.Code != want[i].code || issue.Message == "" {
			t.Errorf("issue %d: %+v", i, issue)
		}
	}
	encoded, _ := json.Marshal(result)
	var decoded map[string][]map[string]any
	if err := json.Unmarshal(encoded, &decoded); err != nil || decoded["hostname"][0]["index"] != float64(1) {
		t.Errorf("wire form %s", encoded)
	}
}
