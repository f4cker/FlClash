package core

import (
	"testing"
	"time"

	"github.com/metacubex/mihomo/common/observable"
	"github.com/metacubex/mihomo/log"
)

func drainLogStream(t *testing.T, subscriber observable.Subscription[log.Event], window time.Duration, match func(string) bool) bool {
	t.Helper()
	deadline := time.After(window)
	for {
		select {
		case event, ok := <-subscriber:
			if !ok {
				return false
			}
			if match(event.Payload) {
				return true
			}
		case <-deadline:
			return false
		}
	}
}
