#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/../../../.." && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/tray-status-tests.XXXXXX")
trap 'rm -rf "$work"' EXIT
sources="$root/plugins/tray/macos/tray/Sources/tray"
swiftc -module-cache-path "$work/cache" \
  "$sources/TrayMenu.swift" \
  "$sources/TrayMenuTransientStatus.swift" \
  "$sources/TrayMenuItemView.swift" \
  "$sources/TrayMenuSegmentsView.swift" \
  "$root/plugins/tray/test/native/TrayMenuTransientStatusTests.swift" \
  -o "$work/tray-status-tests"
"$work/tray-status-tests"
