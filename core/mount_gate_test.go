package core

import (
	"errors"
	"fmt"
	"testing"

	cp "github.com/metacubex/mihomo/constant/provider"
)

func TestMountGateRefusalIsItsOwnError(t *testing.T) {
	installMountGate(nil, nil)
	t.Cleanup(func() { installMountGate(nil, nil) })
	mountGateMu.Lock()
	activeMountGate = &mountGate{external: true}
	mountGateMu.Unlock()

	err := gateMountProxies("sub", []map[string]any{{"name": "t", "type": "tailscale"}}, nil)
	var refused *mountUpdateRefused
	if !errors.As(err, &refused) || refused.name != "sub" {
		t.Fatalf("err = %v, want a mount refusal of sub", err)
	}
	if want := "sub now holds a Tailscale node while subscription nodes are mounted; apply the profile again to take it"; err.Error() != want {
		t.Errorf("message = %q, want %q", err.Error(), want)
	}
}

type swappingProxyProvider struct {
	fakeProxyProvider
	t   *testing.T
	err error
}

func (p *swappingProxyProvider) Update() error {
	withTunnelProviders(p.t, map[string]cp.ProxyProvider{p.name: &fakeProxyProvider{name: p.name, vehicle: cp.HTTP}}, nil)
	return p.err
}

func TestProviderUpdateRefusedByTheMountGateHasItsOwnCode(t *testing.T) {
	const name = "subscription"
	refusal := fmt.Errorf("parse: %w", &mountUpdateRefused{name: name, what: "holds a Tailscale node"})
	kept := &failingProxyProvider{fakeProxyProvider: fakeProxyProvider{name: name, vehicle: cp.HTTP}, err: refusal}
	swapped := &swappingProxyProvider{fakeProxyProvider: fakeProxyProvider{name: name, vehicle: cp.HTTP}, t: t, err: refusal}
	for _, tc := range []struct {
		provider cp.ProxyProvider
		kept     bool
	}{{kept, true}, {swapped, false}} {
		withTunnelProviders(t, map[string]cp.ProxyProvider{name: tc.provider}, nil)
		methodError := asMethodError(handleUpdateExternalProvider(NameParams{Name: name}))
		if methodError.Code != "provider_update_refused_mount" {
			t.Fatalf("code = %q, want provider_update_refused_mount", methodError.Code)
		}
		details, ok := methodError.Details.(map[string]any)
		if !ok || details["providerName"] != name || details["kept"] != tc.kept {
			t.Errorf("details = %#v, want providerName %q and kept %v", methodError.Details, name, tc.kept)
		}
	}

	other := &failingProxyProvider{fakeProxyProvider: fakeProxyProvider{name: name, vehicle: cp.HTTP}, err: errors.New("proxy 0: unsupported type")}
	withTunnelProviders(t, map[string]cp.ProxyProvider{name: other}, nil)
	if code := asMethodError(handleUpdateExternalProvider(NameParams{Name: name})).Code; code != "provider_update_error" {
		t.Errorf("code = %q, want provider_update_error for another parse failure", code)
	}
}
