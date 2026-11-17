package core

import (
	"net/netip"
	"strings"

	"golang.org/x/net/publicsuffix"
)

// The app's signer (macos/Runner/MitmHostPolicy.swift) applies the same rules
// to the same list; core/testdata/mitm_hostname_vectors.json holds both to it.

type mitmHostIssue string

const (
	mitmHostInvalid    mitmHostIssue = "invalid"
	mitmHostAddress    mitmHostIssue = "address"
	mitmHostOverBroad  mitmHostIssue = "over-broad"
	mitmHostAppleOwned mitmHostIssue = "apple-service"
)

var mitmHostIssueMessages = map[mitmHostIssue]string{
	mitmHostInvalid:    "not a hostname: write api.example.com or *.example.com",
	mitmHostAddress:    "IP addresses and ports cannot be decrypted, only hostnames",
	mitmHostOverBroad:  "too broad: it covers a whole public suffix such as *.com or *.co.uk",
	mitmHostAppleOwned: "Apple system services stop working when decrypted, so their domains cannot be added",
}

// Decrypting these breaks iCloud, push, App Store, software update and
// activation; a whole suffix of them stays out, whatever the list says.
var mitmAppleDomains = []string{
	"apple",
	"apple.com",
	"apple.com.cn",
	"apple.co",
	"apple-cloudkit.com",
	"apple-dns.cn",
	"apple-dns.net",
	"apple-livephotoskit.com",
	"apple-mapkit.com",
	"aaplimg.com",
	"appattest.apple.com",
	"appstore.com",
	"cdn-apple.com",
	"icloud.com",
	"icloud.com.cn",
	"icloud-content.com",
	"icloud-content.com.cn",
	"itunes.com",
	"itunes.apple.com",
	"mac.com",
	"me.com",
	"mzstatic.com",
	"push.apple.com",
}

type mitmHostEntry struct {
	exclude  bool
	wildcard bool
	// The host itself, or the domain under a wildcard.
	base string
}

func normalizeMitmHost(host string) string {
	return strings.TrimSuffix(strings.ToLower(strings.TrimSpace(host)), ".")
}

func validDNSName(name string) bool {
	if name == "" || len(name) > 253 {
		return false
	}
	letters := false
	for _, label := range strings.Split(name, ".") {
		if label == "" || len(label) > 63 || label[0] == '-' || label[len(label)-1] == '-' {
			return false
		}
		letters = false
		for i := 0; i < len(label); i++ {
			c := label[i]
			switch {
			case c >= 'a' && c <= 'z':
				letters = true
			case c >= '0' && c <= '9' || c == '-':
			default:
				return false
			}
		}
	}
	// No top-level domain is all digits; such a name is an address.
	return letters
}

func isMitmAppleDomain(host string) bool {
	for _, domain := range mitmAppleDomains {
		if host == domain || strings.HasSuffix(host, "."+domain) {
			return true
		}
	}
	return false
}

// A name that is a public suffix, or under none, has no eTLD+1.
func isPublicSuffix(name string) bool {
	_, err := publicsuffix.EffectiveTLDPlusOne(name)
	return err != nil
}

func looksLikeAddress(text string) bool {
	if _, err := netip.ParseAddr(strings.Trim(text, "[]")); err == nil {
		return true
	}
	if _, err := netip.ParseAddrPort(text); err == nil {
		return true
	}
	return strings.Contains(text, ":")
}

// Exclusions are held only to the syntax: taking a host out of decryption is
// safe however broad it is.
func parseMitmHostEntry(line string) (mitmHostEntry, mitmHostIssue) {
	text := normalizeMitmHost(line)
	entry := mitmHostEntry{}
	if rest, found := strings.CutPrefix(text, "-"); found {
		entry.exclude = true
		text = normalizeMitmHost(rest)
	}
	if text == "*" || text == "*." {
		if entry.exclude {
			return entry, mitmHostInvalid
		}
		return entry, mitmHostOverBroad
	}
	if looksLikeAddress(text) {
		return entry, mitmHostAddress
	}
	if base, found := strings.CutPrefix(text, "*."); found {
		entry.wildcard = true
		text = base
	}
	if !validDNSName(text) {
		return entry, mitmHostInvalid
	}
	entry.base = text
	if entry.exclude {
		return entry, ""
	}
	if isPublicSuffix(text) {
		return entry, mitmHostOverBroad
	}
	if isMitmAppleDomain(text) {
		return entry, mitmHostAppleOwned
	}
	return entry, ""
}

func (entry mitmHostEntry) matches(host string) bool {
	if entry.wildcard {
		return strings.HasSuffix(host, "."+entry.base)
	}
	return host == entry.base
}

// The first entry that matches decides; an entry with an issue is skipped as
// if it were not written.
type mitmHostMatcher struct {
	entries []mitmHostEntry
}

func compileMitmHosts(lines []string) *mitmHostMatcher {
	matcher := &mitmHostMatcher{}
	for _, line := range lines {
		if entry, issue := parseMitmHostEntry(line); issue == "" {
			matcher.entries = append(matcher.entries, entry)
		}
	}
	return matcher
}

func (matcher *mitmHostMatcher) Match(host string) bool {
	if matcher == nil {
		return false
	}
	host = normalizeMitmHost(host)
	if !validDNSName(host) || isMitmAppleDomain(host) {
		return false
	}
	for _, entry := range matcher.entries {
		if entry.matches(host) {
			return !entry.exclude
		}
	}
	return false
}

func (matcher *mitmHostMatcher) Len() int {
	if matcher == nil {
		return 0
	}
	return len(matcher.entries)
}
