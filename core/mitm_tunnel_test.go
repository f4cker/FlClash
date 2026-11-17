package core

import (
	"io"
	"net"
	"net/netip"
	"testing"
	"time"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outbound"
	N "github.com/metacubex/mihomo/common/net"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
)

// The only socket is a loopback listener; no Flash process, proxy service or TUN.
func TestMitmGateOffDoesNotDelayActualTunnelDial(t *testing.T) {
	if tunnel.TCPIntercept != nil || tunnel.UDPDrop != nil {
		t.Fatal("disabled hooks must be nil")
	}
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer listener.Close()
	oldMode, oldStatus := tunnel.Mode(), tunnel.Status()
	oldProxies, oldProviders := tunnel.Proxies(), tunnel.Providers()
	defer func() {
		tunnel.UpdateProxies(oldProxies, oldProviders)
		tunnel.SetMode(oldMode)
		switch oldStatus {
		case tunnel.Running:
			tunnel.OnRunning()
		case tunnel.Inner:
			tunnel.OnInnerLoading()
		default:
			tunnel.OnSuspend()
		}
	}()
	tunnel.UpdateProxies(map[string]C.Proxy{"DIRECT": adapter.NewProxy(outbound.NewDirect())}, nil)
	tunnel.SetMode(tunnel.Direct)
	tunnel.OnRunning()
	client, inbound := net.Pipe()
	defer client.Close()
	defer inbound.Close()
	addr := listener.Addr().(*net.TCPAddr)
	metadata := &C.Metadata{NetWork: C.TCP, Type: C.HTTP, DstIP: netip.MustParseAddr("127.0.0.1"), DstPort: uint16(addr.Port)}
	done := make(chan struct{})
	go func() { defer close(done); tunnel.Tunnel.HandleTCPConn(inbound, metadata) }()
	tcp := listener.(*net.TCPListener)
	_ = tcp.SetDeadline(time.Now().Add(150 * time.Millisecond))
	accepted, err := tcp.Accept()
	if err != nil {
		t.Fatalf("server-first dial waited for client peek: %v", err)
	}
	defer accepted.Close()
	_ = accepted.SetDeadline(time.Now().Add(time.Second))
	_ = client.SetDeadline(time.Now().Add(time.Second))
	if _, err := accepted.Write([]byte("hello")); err != nil {
		t.Fatal(err)
	}
	var b [5]byte
	if _, err := io.ReadFull(client, b[:]); err != nil || string(b[:]) != "hello" {
		t.Fatalf("greeting %q: %v", b, err)
	}
	_ = client.Close()
	_ = accepted.Close()
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("tunnel did not close")
	}
}

func TestMitmPrecommitConfigChangeRelaysThroughActualTunnel(t *testing.T) {
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer listener.Close()
	oldMode, oldStatus := tunnel.Mode(), tunnel.Status()
	oldProxies, oldProviders := tunnel.Proxies(), tunnel.Providers()
	oldHook, oldRuntime := tunnel.TCPIntercept, mitmState.Load()
	defer func() {
		tunnel.TCPIntercept = oldHook
		mitmState.Store(oldRuntime)
		tunnel.UpdateProxies(oldProxies, oldProviders)
		tunnel.SetMode(oldMode)
		switch oldStatus {
		case tunnel.Running:
			tunnel.OnRunning()
		case tunnel.Inner:
			tunnel.OnInnerLoading()
		default:
			tunnel.OnSuspend()
		}
	}()
	tunnel.UpdateProxies(map[string]C.Proxy{"DIRECT": adapter.NewProxy(outbound.NewDirect())}, nil)
	tunnel.SetMode(tunnel.Direct)
	tunnel.OnRunning()
	old := &mitmRuntime{}
	mitmState.Store(old)
	tunnel.TCPIntercept = func(_ *N.BufferedConn, _ *C.Metadata) tunnel.TCPInterceptor {
		return func(client *N.BufferedConn, remote C.Conn) {
			// Deterministically replace configuration after the interceptor was selected,
			// immediately before active-session registration (before any upstream TLS).
			mitmState.Store(&mitmRuntime{})
			mitmServeSelected(client, remote, "example.com", nil, old)
		}
	}
	client, inbound := net.Pipe()
	defer client.Close()
	defer inbound.Close()
	addr := listener.Addr().(*net.TCPAddr)
	metadata := &C.Metadata{NetWork: C.TCP, Type: C.HTTP, DstIP: netip.MustParseAddr("127.0.0.1"), DstPort: uint16(addr.Port)}
	done := make(chan struct{})
	go func() { defer close(done); tunnel.Tunnel.HandleTCPConn(inbound, metadata) }()
	_ = client.SetDeadline(time.Now().Add(2 * time.Second))
	sent := []byte("unchanged-client-hello")
	wrote := make(chan error, 1)
	go func() { _, err := client.Write(sent); wrote <- err }()
	tcp := listener.(*net.TCPListener)
	_ = tcp.SetDeadline(time.Now().Add(2 * time.Second))
	accepted, err := tcp.Accept()
	if err != nil {
		t.Fatal(err)
	}
	defer accepted.Close()
	_ = accepted.SetDeadline(time.Now().Add(2 * time.Second))
	got := make([]byte, len(sent))
	if _, err := io.ReadFull(accepted, got); err != nil || string(got) != string(sent) {
		t.Fatalf("relay %q: %v", got, err)
	}
	if err := <-wrote; err != nil {
		t.Fatal(err)
	}
	_ = client.Close()
	_ = accepted.Close()
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("tunnel did not stop")
	}
}
