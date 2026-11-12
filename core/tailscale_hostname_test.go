//go:build with_gvisor && !no_tailscale

package core

import (
	"strings"
	"testing"
)

func TestTailscaleHostnameOf(t *testing.T) {
	long := strings.Repeat("a", 70)
	cases := map[string]string{
		"Alices-MacBook-Pro.local":      "alices-macbook-pro-flash",
		"studio.example.com":            "studio-flash",
		"Pat's Mac mini":                "pat-s-mac-mini-flash",
		"-mac_book-":                    "mac-book-flash",
		"":                              "flash",
		".local":                        "flash",
		"Ünïcode":                       "n-code-flash",
		long:                            strings.Repeat("a", 57) + "-flash",
		strings.Repeat("a", 56) + "-bc": strings.Repeat("a", 56) + "-flash",
	}
	for in, want := range cases {
		got := tailscaleHostnameOf(in)
		if got != want {
			t.Errorf("tailscaleHostnameOf(%q) = %q, want %q", in, got, want)
		}
		if len(got) > 63 {
			t.Errorf("tailscaleHostnameOf(%q) is %d long", in, len(got))
		}
	}
}
