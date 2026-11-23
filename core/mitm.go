package core

import (
	"errors"
	"reflect"
	"sync"
	"sync/atomic"

	"github.com/metacubex/mihomo/log"
	"go.yaml.in/yaml/v3"
)

// The app's own MITM settings. They travel in SetupParams, never in the
// profile: a `mitm` section a subscription or an extension script writes is
// only counted, so the user can be told it was ignored.
type MitmSetup struct {
	Enable   bool     `json:"enable"`
	Hostname []string `json:"hostname"`
	// Sent only once the app has checked the CA is trusted.
	DecryptTLS    bool   `json:"decrypt-tls"`
	CAFingerprint string `json:"ca-fingerprint"`
	AutoQuicBlock *bool  `json:"auto-quic-block,omitempty"`
	// Surge's h2: decrypt HTTP/2 as well. Absent means on; off advertises
	// HTTP/1.1 alone, and a client that offers only h2 passes through.
	H2     *bool            `json:"h2,omitempty"`
	Limits map[string]int64 `json:"limits,omitempty"`
	// The current profile's rewrite rules (phase 2b). They change without
	// ending any session: only the settings above do that.
	Rewrite []MitmRewriteRule `json:"rewrite,omitempty"`
	// Phase 2c scripts, installed with the rewrite rules.
	Script []MitmScriptRule `json:"script,omitempty"`
	// Surge's force-http-engine-hosts: plain HTTP to these hosts is
	// rewritten and scripted as a decrypted request is.
	ForceHTTPEngine []string `json:"force-http-engine-hosts,omitempty"`
}

// The setup without its rewrite rules, which are installed on their own.
func (setup MitmSetup) withoutRewrite() MitmSetup {
	setup.Rewrite, setup.Script, setup.ForceHTTPEngine = nil, nil, nil
	return setup
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
	// For a rewrite rule or a script, what is wrong as a stable code and the
	// values its text names, as MitmRewriteIssue has them; the app words it
	// and keeps Message for details.
	Kind string   `json:"kind,omitempty"`
	Args []string `json:"args,omitempty"`
}

// The issue of a rewrite rule or a script that does not load.
func mitmRuleIssue(index int, err error) MitmIssue {
	issue := MitmIssue{Index: index, Code: mitmRewriteInvalid, Message: err.Error()}
	var ruleErr *mitmRuleError
	if errors.As(err, &ruleErr) {
		issue.Kind, issue.Args = ruleErr.kind, ruleErr.args
	}
	return issue
}

var mitmRuleLists = []string{"hostname", "url-rewrite", "header-rewrite", "body-rewrite", "map-local", "script"}

type mitmRuntime struct {
	setup   MitmSetup
	hosts   *mitmHostMatcher
	ignored atomic.Int64
}

var (
	mitmState     atomic.Pointer[mitmRuntime]
	mitmCapture   atomic.Bool
	mitmIntentMu  sync.Mutex
	mitmIntentSeq uint64
)

// The candidate is the whole config about to run, the subscription's base and
// the app's overlay merged, so every `mitm` hostname a profile wrote counts.
func applyMitmSetup(params *SetupParams, candidate []byte) {
	runtime := &mitmRuntime{}
	if params.Mitm != nil {
		runtime.setup = params.Mitm.withoutRewrite()
		runtime.hosts = compileMitmHosts(params.Mitm.Hostname)
	}
	runtime.ignored.Store(int64(profileMitmHostnames(candidate)))
	installMitmRewrite(params.Mitm)
	replaceMitmRuntime(runtime)
}

func updateMitmIgnored(candidate []byte) {
	ignored := int64(profileMitmHostnames(candidate))
	for {
		runtime := mitmState.Load()
		if runtime == nil {
			runtime = &mitmRuntime{}
			if !mitmState.CompareAndSwap(nil, runtime) {
				continue
			}
		}
		runtime.ignored.Store(ignored)
		return
	}
}

func markMitmIntent(seq uint64) {
	mitmIntentMu.Lock()
	if seq > mitmIntentSeq {
		mitmIntentSeq = seq
	}
	mitmIntentMu.Unlock()
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

// Whether HTTP/2 is offered to both sides of a decrypted connection.
func (runtime *mitmRuntime) http2() bool {
	return runtime != nil && (runtime.setup.H2 == nil || *runtime.setup.H2)
}

// Whether a TLS connection to host is to be decrypted.
func mitmDecrypts(host string) bool {
	runtime := mitmState.Load()
	return runtime.decrypting() && runtime.hosts.Match(host)
}

// Turns decryption off without a setup, so the app's "off" reaches the Core
// even when a setup cannot be made or is refused. Ending decryption needs
// nothing checked; a Core already not decrypting is left as it is.
func handleMitmDisable() {
	previous := mitmState.Load()
	// Rewriting stops with the switch, plain HTTP included.
	installMitmRewrite(nil)
	if !previous.decrypting() && (previous == nil || !previous.setup.Enable) {
		return
	}
	runtime := &mitmRuntime{}
	runtime.ignored.Store(previous.ignored.Load())
	replaceMitmRuntime(runtime)
	log.Infoln("[MITM] decryption turned off")
}

type MitmUpdateParams struct {
	// Null turns decryption off.
	Setup *MitmSetup `json:"setup"`
}

// Hands the Core new MITM settings (on/off, trusted CA, hosts, limits)
// without a config reload, so no connection outside decryption is touched:
// only decrypted sessions end, and only when the settings really changed.
// Serialised with profile setup, which does not change these settings.
func handleMitmUpdate(params MitmUpdateParams) error {
	return handleMitmUpdateSeq(params, 0)
}

func handleMitmUpdateSeq(params MitmUpdateParams, seq uint64) error {
	configMu.Lock()
	defer configMu.Unlock()
	mitmIntentMu.Lock()
	defer mitmIntentMu.Unlock()
	if seq != 0 && seq != mitmIntentSeq {
		return nil
	}
	previous := mitmState.Load()
	runtime := &mitmRuntime{}
	if previous != nil {
		runtime.ignored.Store(previous.ignored.Load())
	}
	if params.Setup != nil {
		runtime.setup = params.Setup.withoutRewrite()
		runtime.hosts = compileMitmHosts(params.Setup.Hostname)
	}
	// Rewrite rules take effect for the next message on every session; a
	// change to them alone leaves the sessions as they are.
	installMitmRewrite(params.Setup)
	if previous != nil && reflect.DeepEqual(previous.setup, runtime.setup) {
		return nil
	}
	replaceMitmRuntime(runtime)
	log.Infoln("[MITM] settings updated: decrypting=%v hosts=%d", runtime.decrypting(), runtime.hosts.Len())
	return nil
}

func handleMitmStatus() MitmStatus {
	return mitmStatus(mitmIndicatorAvailable)
}

func mitmStatus(indicatorAvailable bool) MitmStatus {
	runtime := mitmState.Load()
	status := MitmStatus{Capture: mitmCapture.Load()}
	if runtime != nil {
		status.Enable = runtime.decrypting()
		status.Hostnames = runtime.hosts.Len()
		status.IgnoredHostnames = int(runtime.ignored.Load())
	}
	if status.Enable {
		if !indicatorAvailable {
			status.Paused = "indicatorPending"
		} else if reason := mitmPausedReason(); reason != "" {
			status.Paused = reason
		} else {
			status.Paused = "partialConnections"
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
	for _, section := range mitmRewriteSections {
		for index, line := range params[section] {
			if _, err := parseMitmRewriteLine(section, line); err != nil {
				result[section] = append(result[section], mitmRuleIssue(index, err))
			}
		}
	}
	programs := mitmRewrite.Load().scriptPrograms()
	for index, line := range params[mitmSectionScript] {
		rule, err := parseMitmScriptLine(line)
		if err == nil && rule != nil {
			err = loadMitmScript(rule.script, programs)
		}
		if err != nil {
			result[mitmSectionScript] = append(result[mitmSectionScript], mitmRuleIssue(index, err))
		}
	}
	return result
}

// The one issue code of a rewrite rule; the message says what is wrong.
const mitmRewriteInvalid mitmHostIssue = "invalidRule"
