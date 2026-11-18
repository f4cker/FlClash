package core

import (
	"errors"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/dlclark/regexp2"
)

// Surge's patterns are ICU (NSRegularExpression) regexes, and real modules
// use what RE2 lacks: lookahead, lookbehind, backreferences. A pattern Go's
// regexp accepts runs there (linear time); any other falls back to a
// backtracking engine bounded by a match timeout, after which the rule is
// skipped for that message and the traffic passes unchanged.
type mitmRegex struct {
	source string
	re     *regexp.Regexp
	re2    *regexp2.Regexp
}

// A backtracking match that runs longer than this is abandoned.
var mitmRegexTimeout = 100 * time.Millisecond

var errMitmRegexTimeout = errors.New("regex match timed out")

func compileMitmRegex(source string, multiline bool) (*mitmRegex, error) {
	if source == "" {
		return nil, errors.New("empty regex")
	}
	goSource := source
	if multiline {
		goSource = "(?m)" + source
	}
	if re, err := regexp.Compile(goSource); err == nil {
		return &mitmRegex{source: source, re: re}, nil
	}
	options := regexp2.RegexOptions(regexp2.None)
	if multiline {
		options |= regexp2.Multiline
	}
	re2, err := regexp2.Compile(source, options)
	if err != nil {
		return nil, err
	}
	re2.MatchTimeout = mitmRegexTimeout
	return &mitmRegex{source: source, re2: re2}, nil
}

func (r *mitmRegex) match(s string) (bool, error) {
	if r.re != nil {
		return r.re.MatchString(s), nil
	}
	ok, err := r.re2.MatchString(s)
	if err != nil {
		return false, errMitmRegexTimeout
	}
	return ok, nil
}

// Replaces every match of r in s with template, expanding $0-$99, $& and
// $$ as Surge (ICU) and JavaScript do. Reports whether anything matched.
func (r *mitmRegex) replaceAll(s, template string) (string, bool, error) {
	if r.re != nil {
		matches := r.re.FindAllStringSubmatchIndex(s, -1)
		if len(matches) == 0 {
			return s, false, nil
		}
		var b strings.Builder
		last := 0
		for _, m := range matches {
			b.WriteString(s[last:m[0]])
			groups := make([]string, len(m)/2)
			for i := range groups {
				if m[2*i] >= 0 {
					groups[i] = s[m[2*i]:m[2*i+1]]
				}
			}
			expandMitmTemplate(&b, template, groups)
			last = m[1]
		}
		b.WriteString(s[last:])
		return b.String(), true, nil
	}
	runes := []rune(s)
	m, err := r.re2.FindRunesMatch(runes)
	if err != nil {
		return s, false, errMitmRegexTimeout
	}
	if m == nil {
		return s, false, nil
	}
	var b strings.Builder
	last := 0
	for m != nil {
		b.WriteString(string(runes[last:m.Index]))
		all := m.Groups()
		groups := make([]string, len(all))
		for i, g := range all {
			if len(g.Captures) > 0 {
				groups[i] = g.String()
			}
		}
		expandMitmTemplate(&b, template, groups)
		last = m.Index + m.Length
		if m.Length == 0 && last >= len(runes) {
			break
		}
		if m, err = r.re2.FindNextMatch(m); err != nil {
			return s, false, errMitmRegexTimeout
		}
	}
	if last < len(runes) {
		b.WriteString(string(runes[last:]))
	}
	return b.String(), true, nil
}

func expandMitmTemplate(b *strings.Builder, template string, groups []string) {
	for i := 0; i < len(template); i++ {
		c := template[i]
		if c != '$' || i+1 >= len(template) {
			b.WriteByte(c)
			continue
		}
		next := template[i+1]
		switch {
		case next == '$':
			b.WriteByte('$')
			i++
		case next == '&':
			b.WriteString(groups[0])
			i++
		case next >= '0' && next <= '9':
			// Two digits when that group exists, as in JavaScript.
			n, width := int(next-'0'), 1
			if i+2 < len(template) && template[i+2] >= '0' && template[i+2] <= '9' {
				if two, _ := strconv.Atoi(template[i+1 : i+3]); two < len(groups) {
					n, width = two, 2
				}
			}
			if n < len(groups) {
				b.WriteString(groups[n])
				i += width
			} else {
				b.WriteByte(c)
			}
		default:
			b.WriteByte(c)
		}
	}
}

// The one host a URL pattern can match, when it is spelled out: patterns
// like ^https?:\/\/api\.example\.com\/... (by far the common form) are
// indexed by host so a request is tested only against its host's rules and
// the patterns that name no single host. "" means the pattern may match any
// host. Conservative: anything unusual yields "".
func mitmPatternHost(pattern string) string {
	if !strings.HasPrefix(pattern, "^") || mitmTopLevelAlternation(pattern) {
		return ""
	}
	rest := pattern[1:]
	sep := strings.Index(rest, ":")
	if sep <= 0 {
		return ""
	}
	for _, c := range rest[:sep] {
		if !strings.ContainsRune("https?()", c) {
			return ""
		}
	}
	rest = rest[sep+1:]
	switch {
	case strings.HasPrefix(rest, `\/\/`):
		rest = rest[4:]
	case strings.HasPrefix(rest, "//"):
		rest = rest[2:]
	default:
		return ""
	}
	var host strings.Builder
	for i := 0; i < len(rest); i++ {
		c := rest[i]
		switch {
		case c >= 'a' && c <= 'z' || c >= '0' && c <= '9' || c == '-':
			host.WriteByte(c)
		case c >= 'A' && c <= 'Z':
			host.WriteByte(c + 'a' - 'A')
		case c == '\\' && i+1 < len(rest) && (rest[i+1] == '.' || rest[i+1] == '-'):
			host.WriteByte(rest[i+1])
			i++
		case c == '\\' && i+1 < len(rest) && (rest[i+1] == '/' || rest[i+1] == '?'):
			return mitmIndexedHost(host.String())
		case c == '/' || c == ':':
			return mitmIndexedHost(host.String())
		case c == '$' && i+1 == len(rest):
			return mitmIndexedHost(host.String())
		default:
			return ""
		}
	}
	return ""
}

func mitmIndexedHost(host string) string {
	if host == "" || strings.HasSuffix(host, ".") || strings.HasPrefix(host, ".") {
		return ""
	}
	return host
}

// Whether a | outside every group and class could bypass the ^ anchor.
func mitmTopLevelAlternation(pattern string) bool {
	depth, class := 0, false
	for i := 0; i < len(pattern); i++ {
		switch c := pattern[i]; {
		case c == '\\':
			i++
		case class:
			if c == ']' {
				class = false
			}
		case c == '[':
			class = true
		case c == '(':
			depth++
		case c == ')':
			depth--
		case c == '|' && depth <= 0:
			return true
		}
	}
	return false
}
