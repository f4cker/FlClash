## Flash VERSION — macOS arm64

- [Download Flash-VERSION-macos-arm64.dmg](https://github.com/f4cker/FlClash/releases/download/vVERSION/Flash-VERSION-macos-arm64.dmg)
- [SHA256SUMS](https://github.com/f4cker/FlClash/releases/download/vVERSION/SHA256SUMS)
- [Changelog](https://github.com/f4cker/FlClash/blob/main/CHANGELOG.md)

Apple Silicon release with one embedded install package for the
service wrapper build **2026111408**, retaining helper binary build **2026111402**.
Install the helper from the app with
macOS administrator authorization; no separate helper download is required. The
helper and released Core bytes remain unchanged; the managed GUI has no loose
Core copy. The wrapper adds the app icon under a new outer signature.
Public assets are only the DMG
and `SHA256SUMS`; the helper package stays inside the app.

Self-signed with the existing Flash identity, **not Apple Developer ID signed and
not notarized**. Static packaging/signature verification does not establish full
test-suite or runtime acceptance.
