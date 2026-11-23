//go:build !android

package core

import (
	"bytes"
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/metacubex/mihomo/log"
)

type frameConn struct{ *bytes.Reader }

func (frameConn) Write(p []byte) (int, error)      { return len(p), nil }
func (frameConn) Close() error                     { return nil }
func (frameConn) SetWriteDeadline(time.Time) error { return nil }

func TestServerLogsOnlyTheLengthOfAGarbledFrame(t *testing.T) {
	subscriber := log.Subscribe()
	defer log.UnSubscribe(subscriber)
	frame := []byte(`{"id":"9","method":"mitm.setCA","arguments":{"p12":"MIIKsecretsecretsecret","passphrase":"hunter2-passphrase"`)
	var input bytes.Buffer
	_, _ = writeFrame(&input, frame)
	serve(frameConn{Reader: bytes.NewReader(input.Bytes())})
	seen := ""
	drainLogStream(t, subscriber, time.Second, func(payload string) bool {
		if strings.Contains(payload, "server unmarshal error") {
			seen = payload
			return true
		}
		return false
	})
	if seen == "" {
		t.Fatal("the garbled frame was not reported")
	}
	if strings.Contains(seen, "hunter2") || strings.Contains(seen, "MIIK") || !strings.Contains(seen, fmt.Sprintf("%d bytes", len(frame))) {
		t.Fatalf("logged %q", seen)
	}
}
