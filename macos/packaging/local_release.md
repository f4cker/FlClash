# Local macOS release: one Flash.app with the bundled SMAppService daemon

This is a local Mac command, not a GitHub runner workflow. It does not enable the
upstream Telegram/Homebrew publishing integrations. Gitta owns merging `main` and
creating/pushing the matching tag. Do that before building: the CLI refuses a dirty
checkout, another branch, mismatched submodules, or a tag not at `main` HEAD.

The arm64 release is a single `Flash.app`. It carries everything the privileged
side needs; there is no separate service bundle, helper package or installer:

```text
Contents/MacOS/Flash                                            GUI
Contents/MacOS/FlClashCore                                      Core (copied by the daemon before use)
Contents/Library/HelperTools/FlashHelper                        daemon (BundleProgram)
Contents/Library/LaunchDaemons/com.layoute.flash.daemon.plist   SMAppService.daemon plist
```

The app registers the daemon itself with `SMAppService.daemon(plistName:)`; macOS
then asks the user to allow Flash under Login Items. Upgrading from a pkg-installed
helper runs one constant cleanup script with administrator authorization.
The existing self-signed identity is retained; this is not Apple Developer ID
signing or notarization. Static checks are not runtime acceptance.

## Persistent local setup

Use the proven local Flutter SDK with dependencies already resolved, Go/Rust/Xcode
available on `PATH`, cached native dependencies, and a graphical Mac session for the
Finder-styled DMG. The build is offline, disables Xcode signing, and denies
`codesign`/`security` execution inside the unsigned build. The Xcode phase
`stage_bundled_daemon.sh` compiles `FlashHelper` (with its `__info_plist`) and copies
the daemon plist; it refuses stale `FlashMaintenance`, legacy plist or
`Resources/HelperInstaller` artifacts instead of deleting them.

Create `.airbuild/local-release/config.json` privately with mode `0600`; do not
commit it or copy credentials into it. Paths must be canonical and absolute:

```json
{
  "schema": 2,
  "sdk": "<Flutter SDK root>",
  "signer": "<executable protected local adapter>",
  "signer_sha256": "<adapter SHA256>"
}
```

Schema 1 configs (with `service*` fields) are rejected. The signer is the
externally maintained adapter to the protected local signing route. The public
tool does not unlock keychains, accept passwords, or invent unattended
authentication.

## Signing contract (schema 2)

`build` stages the fresh unsigned app with `stage_bundle_payload.stage`, which
checks the exact daemon plist schema (`Label` `com.layoute.flash.daemon`,
`BundleProgram`, `MachServices`, `AssociatedBundleIdentifiers`, `ProcessType`; no
`Program`, `KeepAlive`, `RunAtLoad`), that `BundleProgram` is a real Mach-O whose
`__info_plist` names `com.layoute.flash.helper`, and that no legacy artifact is
present. The request (`flash-local-bundle-sign-v2`, mode `bundled-daemon`) binds the
unsigned inventory, the Core/helper/plist hashes and the inside-out order
`core → helper → frameworks → gui`. Every target is signed with the unchanged
certificate pin and designated requirement
`anchor H"PIN" and certificate leaf = H"PIN" and identifier "ID"`.

The adapter answers `{schema: 2, request_sha256, receipt, receipt_sha256}`. The
receipt (schema 2, no `dev0915_signing_scope`) must carry `before.entries` equal to
the request, the same `signing_order`, and `helper_cdhash`, `core_cdhash`,
`core_sha256` and `daemon_plist_sha256` matching what
`stage_bundle_payload.verify_signed` reads from the signed app (strict nested
verification with each pinned requirement, plist sealed in CodeResources `files2`).

## Commands

```sh
python3 macos/packaging/local_release.py check --tag vX.Y.Z --run release-XYZ
python3 macos/packaging/local_release.py build --tag vX.Y.Z --run release-XYZ
python3 macos/packaging/local_release.py sign --tag vX.Y.Z --run release-XYZ
python3 macos/packaging/local_release.py package --tag vX.Y.Z --run release-XYZ
python3 macos/packaging/local_release.py run --tag vX.Y.Z --run release-XYZ [--publish]
```

`check` validates local source/config without building, signing or network.
`package` creates the styled DMG with `tool/macos/make_styled_dmg.sh`, verifies it
and compares the read-only mounted copy with the signed app. Draft/publish phases
are the only network phases and require the runtime-provided `gh` authentication.

Completed phases resume from hash-bound local receipts. Source/config changes,
changed unsigned inputs, signatures, release assets, or notes stop the run. Failed
partial phases are retained for inspection, not silently retried or deleted; use a
new run name after resolving the failure. Only `Flash-X.Y.Z-macos-arm64.dmg` and
`SHA256SUMS` are uploaded; provenance stays in the ignored run directory. Before
publication the tool checks remote main/tag commits, the draft's exact asset
allowlist and notes, and downloads both assets to compare bytes.
