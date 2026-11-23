package core

import (
	"errors"
	"os"
	"path/filepath"
	"strings"

	"github.com/metacubex/mihomo/component/age"
	"github.com/metacubex/mihomo/config"
	"go.yaml.in/yaml/v3"
)

type setupPreflightError struct{ error }

type setupCandidate struct {
	path    string
	report  *MountReport
	configs map[string]tailscaleConfiguredValues
}

func prepareSetupConfig(params *SetupParams) (*setupCandidate, error) {
	var document *yaml.Node
	var report *MountReport
	var err error
	retained := false
	defer func() {
		if !retained {
			report.discardInputs()
		}
	}()
	if params.Base != nil {
		document, report, err = mergeProfileBase(params.Base, false, mountSetupOf(params))
	} else {
		var buf []byte
		buf, err = os.ReadFile(runningConfigPath())
		if err == nil {
			buf, err = age.DecryptBytes(buf)
		}
		if err == nil {
			document, report, err = mountedConfigDocument(buf, mountSetupOf(params))
		}
	}
	if err != nil {
		return nil, err
	}
	tailscaleMu.Lock()
	configs := tailscaleOverridesForSetupLocked(document.Content[0], params.Tailscale)
	tailscaleMu.Unlock()
	if err := validateSetupDocument(document, params.Tailscale); err != nil {
		return nil, report.explainSkip(err)
	}
	path, err := writeDocumentFile(filepath.Dir(runningConfigPath()), ".config-candidate-*.yaml", document)
	if err != nil {
		return nil, &setupPreflightError{err}
	}
	retained = true
	return &setupCandidate{path: path, report: report, configs: configs}, nil
}

// The full cross-reference/DNS/rule check must not replace a live mesh node's
// resolver; its own options are checked separately under an isolated name.
func validateSetupDocument(document *yaml.Node, setup *TailscaleSetup) error {
	raw := config.DefaultRawConfig()
	if err := document.Decode(raw); err != nil {
		return err
	}
	validate := func(mapping map[string]any) error {
		kind, _ := mapping["type"].(string)
		if kind != "tailscale" && kind != "easytier" {
			if strings.EqualFold(kind, "tailscale") || strings.EqualFold(kind, "easytier") {
				return errors.New("unsupported proxy type: " + kind)
			}
			return nil
		}
		probe := make(map[string]any, len(mapping))
		for key, value := range mapping {
			probe[key] = value
		}
		if kind == "tailscale" {
			name, _ := mapping["name"].(string)
			controlURL, _ := mapping["control-url"].(string)
			tailscaleMu.Lock()
			node, _ := tailscaleEffectiveNodeForSetupLocked(tailscaleRef{name: name, controlURL: controlURL}, setup)
			tailscaleMu.Unlock()
			if node.ExitNode != nil {
				probe["exit-node"] = *node.ExitNode
			}
			if node.AcceptRoutes != nil {
				probe["accept-routes"] = *node.AcceptRoutes
			}
		}
		if issues := handleValidateProxies(ProxiesParams{Proxies: []map[string]any{probe}}); len(issues) != 0 {
			return errors.New(issues[0].Message)
		}
		return nil
	}
	for _, mapping := range raw.Proxy {
		if err := validate(mapping); err != nil {
			return err
		}
	}
	for _, provider := range raw.ProxyProvider {
		if payload, ok := provider["payload"].([]any); ok {
			for _, item := range payload {
				if mapping, ok := item.(map[string]any); ok {
					if err := validate(mapping); err != nil {
						return err
					}
				}
			}
		}
	}
	if err := parseDocument(document); err != nil {
		return &setupPreflightError{errors.New(strings.ReplaceAll(err.Error(), validationNameSuffix, ""))}
	}
	return nil
}
