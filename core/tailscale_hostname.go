//go:build with_gvisor && !no_tailscale

package core

import (
	"os"
	"strings"
)

const tailscaleHostnameSuffix = "-flash"

func tailscaleManagedHostname() string {
	host, _ := os.Hostname()
	return tailscaleHostnameOf(host)
}

func tailscaleHostnameOf(host string) string {
	host, _, _ = strings.Cut(strings.TrimSpace(host), ".")
	label := strings.Map(func(r rune) rune {
		if (r < 'a' || r > 'z') && (r < '0' || r > '9') && r != '-' {
			return '-'
		}
		return r
	}, strings.ToLower(host))
	base := strings.Trim(label, "-")
	if limit := 63 - len(tailscaleHostnameSuffix); len(base) > limit {
		base = strings.TrimRight(base[:limit], "-")
	}
	if base == "" {
		return "flash"
	}
	return base + tailscaleHostnameSuffix
}
