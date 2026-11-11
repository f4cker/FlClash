//go:build !with_gvisor || no_tailscale

package core

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
