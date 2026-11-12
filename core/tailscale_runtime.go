//go:build with_gvisor && !no_tailscale

package core

import (
	"crypto/md5"
	"encoding/hex"
	"strconv"
	"strings"
)

type tailscaleManagedRun struct {
	revision string
	accounts []tailscaleManagedRunAccount
	active   bool
	unknown  bool
}

type tailscaleManagedRunAccount struct {
	id       string
	proxy    string
	attached bool
}

const (
	tailscaleRuntimeConfirmed    = "confirmed"
	tailscaleRuntimeUnconfirmed  = "unconfirmed"
	tailscaleRuntimeNone         = "none"
	tailscaleRuntimeOtherProfile = "other-profile"
)

// The host works the same digest out of the setup it would send, so a viewer
// can tell the running accounts are the ones it shows.
func tailscaleRuntimeRevision(profileID int64, managed []TailscaleManagedSetup, unknown bool) string {
	var b strings.Builder
	b.WriteString(strconv.FormatInt(profileID, 10))
	b.WriteString("|")
	if unknown {
		b.WriteString("1|")
	} else {
		b.WriteString("0|")
	}
	first := true
	for _, account := range managed {
		if account.ID == "" {
			continue
		}
		if !first {
			b.WriteString(",")
		}
		first = false
		b.WriteString(account.ID)
		if account.Attached {
			b.WriteString(":1")
		} else {
			b.WriteString(":0")
		}
	}
	sum := md5.Sum([]byte(b.String()))
	return hex.EncodeToString(sum[:])
}

type TailscaleRuntimeAccount struct {
	ID    string   `json:"id"`
	Node  string   `json:"node"`
	Rules []string `json:"rules"`
}

// What the running config holds of the panel's accounts. Only a confirmed
// state names nodes or rules; the rules come from the live route table.
type TailscaleRuntimeRules struct {
	ProfileID int64                     `json:"profile-id"`
	State     string                    `json:"state"`
	Revision  string                    `json:"revision,omitempty"`
	Accounts  []TailscaleRuntimeAccount `json:"accounts"`
	Proxies   []string                  `json:"proxies"`
}

func handleTailscaleRuntimeRules(params TailscaleRoutesParams) (*TailscaleRuntimeRules, error) {
	result := &TailscaleRuntimeRules{
		ProfileID: params.ProfileID,
		State:     tailscaleRuntimeUnconfirmed,
		Accounts:  []TailscaleRuntimeAccount{},
		Proxies:   []string{},
	}
	if params.ProfileID != tailscaleProfileID() {
		result.State = tailscaleRuntimeOtherProfile
		return result, nil
	}
	tailscaleManagedMu.Lock()
	staged, run, slot := tailscaleStaged, tailscaleRunningRun, tailscaleRunningSlot
	tailscaleManagedMu.Unlock()
	if staged {
		return result, nil
	}
	if run == nil {
		// Nothing injected, or a failed apply cleared it for a config of none.
		result.State = tailscaleRuntimeNone
		return result, nil
	}
	var proxies []string
	for _, account := range run.accounts {
		if account.proxy != "" {
			proxies = append(proxies, account.proxy)
		}
	}
	if !run.active {
		if len(proxies) == 0 {
			result.State = tailscaleRuntimeNone
		} else {
			result.State, result.Proxies = tailscaleRuntimeConfirmed, proxies
		}
		result.Revision = run.revision
		return result, nil
	}
	if run.unknown || slot == nil {
		return result, nil
	}
	table := slot.Load()
	if table == nil {
		return result, nil
	}
	listed := map[string]bool{}
	for _, account := range run.accounts {
		if account.attached {
			if account.proxy == "" {
				return result, nil
			}
			listed[account.id] = true
		}
	}
	// A line of no listed account blocks for all of them, so each lists it.
	lines := table.ruleLines()
	accounts := []TailscaleRuntimeAccount{}
	for _, account := range run.accounts {
		if !account.attached {
			continue
		}
		item := TailscaleRuntimeAccount{ID: account.id, Node: account.proxy, Rules: []string{}}
		for _, line := range lines {
			if !listed[line.account] || line.account == account.id {
				item.Rules = append(item.Rules, line.text)
			}
		}
		accounts = append(accounts, item)
	}
	result.State, result.Accounts, result.Proxies = tailscaleRuntimeConfirmed, accounts, proxies
	result.Revision = run.revision
	return result, nil
}
