//go:build darwin && !ios

package core

// Only the macOS Core runs under the helper's verified relay, the one channel
// the app may hand the CA key over.
func init() {
	for method, handler := range mitmCAHandlers {
		methodHandlers[method] = handler
	}
}
