package core

import (
	"net"
	"testing"

	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/listener"
)

func listenerTestConfig(t *testing.T, mixedPort int) *config.Config {
	t.Helper()
	cfg, err := config.ParseRawConfig(config.DefaultRawConfig())
	if err != nil {
		t.Fatalf("ParseRawConfig: %v", err)
	}
	cfg.General.MixedPort = mixedPort
	cfg.General.AllowLan = false
	return cfg
}

func freeLoopbackPort(t *testing.T) int {
	t.Helper()
	probe, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	port := probe.Addr().(*net.TCPAddr).Port
	_ = probe.Close()
	return port
}

func startListenersFor(t *testing.T, cfg *config.Config) {
	t.Helper()
	withCurrentConfig(t, cfg)
	t.Cleanup(func() {
		handleStopListener()
		listener.SetAllowLan(false)
	})
	handleStartListener()
}

func TestListeningMixedPortIsZeroWhileStopped(t *testing.T) {
	isRunning.Store(false)
	if got := handleListeningMixedPort(); got != 0 {
		t.Errorf("port = %d while stopped, want 0", got)
	}
}

func TestListeningMixedPortReportsTheBoundPort(t *testing.T) {
	port := freeLoopbackPort(t)
	startListenersFor(t, listenerTestConfig(t, port))

	if got := handleListeningMixedPort(); got != port {
		t.Errorf("port = %d, want %d", got, port)
	}
}

func TestListeningMixedPortIsZeroWhenThePortIsTaken(t *testing.T) {
	holder, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	defer holder.Close()
	port := holder.Addr().(*net.TCPAddr).Port

	startListenersFor(t, listenerTestConfig(t, port))

	if got := handleListeningMixedPort(); got != 0 {
		t.Errorf("port = %d while another socket holds %d, want 0", got, port)
	}
}

func TestListeningPortsReportsEachInboundTheCoreHolds(t *testing.T) {
	cfg := listenerTestConfig(t, freeLoopbackPort(t))
	cfg.General.SocksPort = freeLoopbackPort(t)
	holder, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	defer holder.Close()
	cfg.General.Port = holder.Addr().(*net.TCPAddr).Port
	startListenersFor(t, cfg)

	got := handleListeningPorts()

	want := ListeningPorts{MixedPort: cfg.General.MixedPort, SocksPort: cfg.General.SocksPort}
	if got != want {
		t.Errorf("ports = %+v, want %+v with the taken http port at 0", got, want)
	}
}

func TestListeningPortsIsEmptyWhileStopped(t *testing.T) {
	isRunning.Store(false)
	if got := handleListeningPorts(); got != (ListeningPorts{}) {
		t.Errorf("ports = %+v while stopped, want none", got)
	}
}
