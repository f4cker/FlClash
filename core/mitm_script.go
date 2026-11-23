package core

import (
	"encoding/json"
	"io"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/dop251/goja"
)

// Phase 2c: Surge [Script] lines whose script-path names a file the app
// downloaded into the resources directory. Scripts run after the rewrite
// rules of their phase; a script that fails leaves the message as it was.

const mitmSectionScript = "script"

type mitmScript struct {
	name         string
	response     bool
	requiresBody bool
	binary       bool
	maxSize      int64
	timeout      time.Duration
	argument     string
	argumentJSON any
	file         string
	program      *goja.Program
}

// The cap keeps a stuck script from holding its request for good, yet lets
// Script Hub's converters, which fetch remote files, run as their modules ask
// (timeout=300). lib/common/mitm_script.dart mitmScriptMaxTimeout mirrors it.
const (
	mitmScriptDefaultTimeout = 10 * time.Second
	mitmScriptMaxTimeout     = 120 * time.Second
	mitmScriptFileLimit      = 8 << 20
	mitmScriptBodyCap        = 8 << 20
)

// Splits `key=value,...` as lib/common/mitm_module.dart _scriptParams does.
func mitmScriptParams(text string) (map[string]string, bool) {
	params := map[string]string{}
	add := func(item string) {
		eq := strings.IndexByte(item, '=')
		if eq <= 0 {
			return
		}
		value := strings.TrimSpace(item[eq+1:])
		if len(value) >= 2 && value[0] == '"' && value[len(value)-1] == '"' {
			value = strings.ReplaceAll(value[1:len(value)-1], `\"`, `"`)
		}
		params[strings.ToLower(strings.TrimSpace(item[:eq]))] = value
	}
	quoted, class, depth, start := false, false, 0, 0
	for i := 0; i < len(text); i++ {
		c := text[i]
		switch {
		case quoted:
			if c == '\\' && i+1 < len(text) && text[i+1] == '"' {
				i++
			} else if c == '"' {
				quoted = false
			}
		case c == '\\':
			i++
		case c == '"':
			quoted = true
		case class:
			class = c != ']'
		case c == '[':
			class = true
		case c == '(' || c == '{':
			depth++
		case (c == ')' || c == '}') && depth > 0:
			depth--
		case c == ',' && depth == 0:
			add(text[start:i])
			start = i + 1
		}
	}
	if quoted {
		return nil, false
	}
	add(text[start:])
	return params, true
}

func mitmTruthy(value string) bool {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case "1", "true", "yes", "on":
		return true
	}
	return false
}

func parseMitmScriptLine(line string) (*mitmRewriteRule, error) {
	line = strings.TrimSpace(line)
	if mitmIsComment(line) {
		return nil, nil
	}
	eq := strings.IndexByte(line, '=')
	if eq <= 0 {
		return nil, mitmRuleErr("scriptLine", nil, "expected <name> = type=...,pattern=...,script-path=...")
	}
	name := strings.TrimSpace(line[:eq])
	params, ok := mitmScriptParams(line[eq+1:])
	if !ok {
		return nil, mitmRuleErr("unterminatedQuote", []string{"script"}, "unterminated quote in script")
	}
	script := &mitmScript{name: name, timeout: mitmScriptDefaultTimeout, maxSize: mitmDefaultRewriteBodyLimit}
	switch kind := strings.ToLower(params["type"]); kind {
	case "http-request":
	case "http-response":
		script.response = true
	case "":
		return nil, mitmRuleErr("scriptLine", nil, "a script needs type=http-request or type=http-response")
	default:
		return nil, mitmRuleErr("scriptType", []string{strconv.Quote(kind)}, "%s scripts are not supported", kind)
	}
	pattern := params["pattern"]
	if pattern == "" {
		return nil, mitmRuleErr("scriptPattern", nil, "a script needs a pattern")
	}
	re, err := compileMitmRegex(pattern, false)
	if err != nil {
		return nil, mitmRuleErr("urlRegex", nil, "invalid URL regex: %v", err)
	}
	file := params["script-path"]
	switch {
	case file == "":
		return nil, mitmRuleErr("scriptPath", nil, "a script needs script-path")
	case strings.HasPrefix(file, "http://") || strings.HasPrefix(file, "https://"):
		return nil, mitmRuleErr("dataURL", nil, "a script from a URL must be downloaded by the app first")
	case strings.ContainsAny(file, `/\`) || strings.HasPrefix(file, "."):
		return nil, mitmRuleErr("dataFileName", []string{strconv.Quote(file)}, "script-path must name a file in the resources directory, got %q", file)
	}
	script.file = file
	script.requiresBody = mitmTruthy(params["requires-body"])
	script.binary = mitmTruthy(params["binary-body-mode"])
	if v, present := params["max-size"]; present {
		size, err := strconv.ParseInt(strings.TrimSpace(v), 10, 64)
		if err != nil {
			return nil, mitmRuleErr("scriptMaxSize", []string{strconv.Quote(v)}, "max-size must be a number of bytes, got %q", v)
		}
		if size > 0 {
			script.maxSize = min(size, mitmScriptBodyCap)
		}
	}
	if v, present := params["timeout"]; present {
		seconds, err := strconv.ParseFloat(strings.TrimSpace(v), 64)
		if err != nil || seconds <= 0 {
			return nil, mitmRuleErr("scriptTimeout", []string{strconv.Quote(v)}, "timeout must be a number of seconds, got %q", v)
		}
		script.timeout = min(time.Duration(seconds*float64(time.Second)), mitmScriptMaxTimeout)
	}
	if v, present := params["argument-json"]; present {
		if err := json.Unmarshal([]byte(v), &script.argumentJSON); err != nil {
			return nil, mitmRuleErr("scriptArgument", nil, "argument-json is not JSON: %v", err)
		}
	} else {
		script.argument = params["argument"]
	}
	rule := &mitmRewriteRule{section: mitmSectionScript, url: re, response: script.response, script: script}
	rule.host = mitmPatternHost(re.source)
	return rule, nil
}

// A file already compiled is reused: its name is its content's hash.
func loadMitmScript(script *mitmScript, previous map[string]*goja.Program) error {
	if program := previous[script.file]; program != nil {
		script.program = program
		return nil
	}
	f, err := os.Open(filepath.Join(mitmResourcesDir(), script.file))
	if err != nil {
		return mitmRuleErr("scriptUnreadable", []string{script.file}, "script file %s cannot be read", script.file)
	}
	defer f.Close()
	source, err := io.ReadAll(io.LimitReader(f, mitmScriptFileLimit+1))
	if err != nil {
		return mitmRuleErr("scriptUnreadable", []string{script.file}, "script file %s cannot be read", script.file)
	}
	if len(source) > mitmScriptFileLimit {
		return mitmRuleErr("scriptTooLarge", []string{script.file}, "script file %s is over 8 MiB", script.file)
	}
	program, err := goja.Compile(script.name, mitmStripBOM(string(source)), false)
	if err != nil {
		return mitmRuleErr("scriptSyntax", []string{err.Error()}, "script does not compile: %v", err)
	}
	script.program = program
	return nil
}

func mitmStripBOM(source string) string {
	return strings.TrimPrefix(source, "\ufeff")
}

func (engine *mitmRewriteEngine) scriptPrograms() map[string]*goja.Program {
	programs := map[string]*goja.Program{}
	if engine == nil {
		return programs
	}
	for _, rule := range engine.rules {
		if rule.script != nil && rule.script.program != nil {
			programs[rule.script.file] = rule.script.program
		}
	}
	return programs
}

type MitmScriptRule struct {
	ID   string `json:"id"`
	Line string `json:"line"`
}
