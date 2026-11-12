//go:build !with_gvisor || no_tailscale

package core

import "github.com/metacubex/mihomo/config"

var errTailscaleUnsupported = &MethodError{
	Code:    "tailscale_unsupported",
	Message: "this core is built without tailscale support",
}

func tailscaleGenerationMark() uint64 { return 0 }

func closeTailscaleUpTo(uint64) {}

func markTailscaleReplaced(uint64) {}

func handleTailscaleNodes() []any { return []any{} }

func handleTailscaleStatus(TailscaleNodeParams) (any, error) { return nil, errTailscaleUnsupported }

func handleTailscaleStart(TailscaleNodeParams) (any, error) { return nil, errTailscaleUnsupported }

func handleTailscaleLogin(TailscaleLoginParams) (any, error) { return nil, errTailscaleUnsupported }

func handleTailscaleLogout(TailscaleNodeParams) (any, error) { return nil, errTailscaleUnsupported }

func handleTailscaleSetPrefs(TailscalePrefsParams) (any, error) { return nil, errTailscaleUnsupported }

func handleTailscaleMigrateLegacy(TailscaleMigrateParams) (any, error) {
	return nil, errTailscaleUnsupported
}

const tailscaleManagedBuilt = false

func injectTailscaleManaged(*config.Config) {}

func clearTailscaleManaged() {}

func publishTailscaleManaged() {}

func startTailscaleManaged() {}

func handleTailscaleRoutes(TailscaleRoutesParams) (any, error) { return nil, errTailscaleUnsupported }

func handleTailscaleAssign(TailscaleAssignParams) (any, error) { return nil, errTailscaleUnsupported }

func handleTailscaleForgetRoutes(TailscaleRoutesParams) (any, error) {
	return nil, errTailscaleUnsupported
}

func handleTailscaleManagedState(TailscaleRoutesParams) (any, error) {
	return nil, errTailscaleUnsupported
}

func handleTailscaleRuntimeRules(TailscaleRoutesParams) (any, error) {
	return nil, errTailscaleUnsupported
}
