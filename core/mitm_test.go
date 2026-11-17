package core

import (
	"testing"
)

func withMitmState(t *testing.T) {
	t.Helper()
	previous := mitmState.Load()
	capture := mitmCapture.Load()
	t.Cleanup(func() {
		mitmState.Store(previous)
		mitmCapture.Store(capture)
	})
}

func TestMitmSetupTakesHostnamesFromTheAppOnly(t *testing.T) {
	withMitmState(t)
	overlay := "mixed-port: 7890\nmitm:\n  enable: true\n  hostname:\n    - '*.bank.example'\n    - pay.example.org\n    - '-x.example'\n"
	applyMitmSetup(&SetupParams{
		Mitm: &MitmSetup{
			Enable:        true,
			Hostname:      []string{"api.example.com", "*.com"},
			DecryptTLS:    true,
			CAFingerprint: "AA:BB",
		},
	}, []byte(overlay))
	status := handleMitmStatus()
	if !status.Enable || status.Hostnames != 1 || status.IgnoredHostnames != 3 {
		t.Fatalf("status %+v", status)
	}
	if !mitmDecrypts("api.example.com") {
		t.Error("the user's host is not decrypted")
	}
	for _, host := range []string{"www.bank.example", "pay.example.org", "www.example.com"} {
		if mitmDecrypts(host) {
			t.Errorf("%s decrypted from the profile or an over-broad entry", host)
		}
	}
}

func TestMitmSetupWithoutTheAppSectionDecryptsNothing(t *testing.T) {
	withMitmState(t)
	applyMitmSetup(&SetupParams{}, []byte("mitm:\n  enable: true\n  hostname: [api.example.com]\n"))
	status := handleMitmStatus()
	if status.Enable || status.Hostnames != 0 || status.IgnoredHostnames != 1 {
		t.Fatalf("status %+v", status)
	}
	if mitmDecrypts("api.example.com") {
		t.Error("a profile hostname was decrypted")
	}
}

func TestMitmDecryptsOnlyWithATrustedCA(t *testing.T) {
	withMitmState(t)
	for _, setup := range []MitmSetup{
		{Enable: false, Hostname: []string{"api.example.com"}, DecryptTLS: true, CAFingerprint: "AA"},
		{Enable: true, Hostname: []string{"api.example.com"}, DecryptTLS: false, CAFingerprint: "AA"},
		{Enable: true, Hostname: []string{"api.example.com"}, DecryptTLS: true},
		{Enable: true, Hostname: []string{"*.com"}, DecryptTLS: true, CAFingerprint: "AA"},
	} {
		applyMitmSetup(&SetupParams{Mitm: &setup}, nil)
		if mitmDecrypts("api.example.com") || handleMitmStatus().Enable {
			t.Errorf("decrypting with %+v", setup)
		}
	}
}

func TestMitmCaptureFollowsTheOptions(t *testing.T) {
	withMitmState(t)
	previous := skipCertVerify.Load()
	t.Cleanup(func() { skipCertVerify.Store(previous) })
	applyOptions(CoreOptions{MITMCapture: true})
	if !handleMitmStatus().Capture {
		t.Error("capture option ignored")
	}
	applyOptions(CoreOptions{})
	if handleMitmStatus().Capture {
		t.Error("capture stayed on")
	}
}
