package core

import (
	"sync/atomic"

	"go.yaml.in/yaml/v3"
)

// The app's own MITM settings. They travel in SetupParams, never in the
// profile: a `mitm` section a subscription or an extension script writes is
// only counted, so the user can be told it was ignored.
type MitmSetup struct {
	Enable   bool     `json:"enable"`
	Hostname []string `json:"hostname"`
	// Sent only once the app has checked the CA is trusted.
	DecryptTLS    bool             `json:"decrypt-tls"`
	CAFingerprint string           `json:"ca-fingerprint"`
	AutoQuicBlock *bool            `json:"auto-quic-block,omitempty"`
	Limits        map[string]int64 `json:"limits,omitempty"`
}

type MitmStatus struct {
	Enable           bool `json:"enable"`
	Hostnames        int  `json:"hostnames"`
	IgnoredHostnames int  `json:"ignored-hostnames"`
	Capture          bool `json:"capture"`
	// Why listed hosts are passing through undecrypted for now, if they are.
	Paused string `json:"paused,omitempty"`
}

type MitmIssue struct {
	Index   int           `json:"index"`
	Code    mitmHostIssue `json:"code"`
	Message string        `json:"message"`
}

var mitmRuleLists = []string{"hostname", "url-rewrite", "header-rewrite", "body-rewrite", "map-local", "script"}

type mitmRuntime struct {
	setup   MitmSetup
	hosts   *mitmHostMatcher
	ignored int
}

var (
	mitmState   atomic.Pointer[mitmRuntime]
	mitmCapture atomic.Bool
)

// The candidate is the whole config about to run, the subscription's base and
// the app's overlay merged, so every `mitm` hostname a profile wrote counts.
func applyMitmSetup(params *SetupParams, candidate []byte) {
	runtime := &mitmRuntime{}
	if params.Mitm != nil {
		runtime.setup = *params.Mitm
		runtime.hosts = compileMitmHosts(params.Mitm.Hostname)
	}
	runtime.ignored = profileMitmHostnames(candidate)
	replaceMitmRuntime(runtime)
}

func profileMitmHostnames(config []byte) int {
	var profile struct {
		Mitm struct {
			Hostname []any `yaml:"hostname"`
		} `yaml:"mitm"`
	}
	if err := yaml.Unmarshal(config, &profile); err != nil {
		return 0
	}
	return len(profile.Mitm.Hostname)
}

func (runtime *mitmRuntime) decrypting() bool {
	return runtime != nil && runtime.setup.Enable && runtime.setup.DecryptTLS &&
		runtime.setup.CAFingerprint != "" && runtime.hosts.Len() > 0
}

// Whether a TLS connection to host is to be decrypted.
func mitmDecrypts(host string) bool {
	runtime := mitmState.Load()
	return runtime.decrypting() && runtime.hosts.Match(host)
}

func handleMitmStatus() MitmStatus {
	runtime := mitmState.Load()
	status := MitmStatus{Capture: mitmCapture.Load()}
	if runtime != nil {
		status.Enable = runtime.decrypting()
		status.Hostnames = runtime.hosts.Len()
		status.IgnoredHostnames = runtime.ignored
	}
	if status.Enable {
		if !mitmIndicatorAvailable {
			status.Paused = "indicatorPending"
		} else {
			status.Paused = mitmPausedReason()
		}
	}
	return status
}

func handleMitmValidate(params map[string][]string) map[string][]MitmIssue {
	result := make(map[string][]MitmIssue, len(mitmRuleLists))
	for _, list := range mitmRuleLists {
		result[list] = []MitmIssue{}
	}
	for index, line := range params["hostname"] {
		if _, issue := parseMitmHostEntry(line); issue != "" {
			result["hostname"] = append(result["hostname"], MitmIssue{
				Index:   index,
				Code:    issue,
				Message: mitmHostIssueMessages[issue],
			})
		}
	}
	return result
}
