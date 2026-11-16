# Destination-Mac migration: check adaptations

Scope: move the local Flash macOS release route from the original Mac
(`/Users/layoute/SideWork/FlClash`, `exit-cleanup` worktree) to this Mac (user
`lavas`, uid 501, root checkout under AirBuild `projects/770e9d36…`). Rule applied:
paths and original-Mac layout checks may be adapted; signing-identity, private-key
access and file-integrity checks are never skipped. Each original-Mac-only check
below is replaced with an equally strict or stricter one. No check was weakened.

Original ignored/private files were backed up (`.orig`) under
`.airbuild/local-release/migration/orig/` before modification; frozen tools
(`signing-provision`, its sources, the encrypted backup) are unchanged.

## Tracked public sources (this commit)

| File | Change |
| --- | --- |
| `sign_fixed_payload.py` | `WORKTREE` → this root checkout; `KEYCHAIN` → `/Users/lavas/…/Flash Signing/FlashSigning.keychain-db`. Certificate SHA1/SHA256 and verifier pins unchanged. |
| `sign_split_payload.py` | `KEYCHAIN` rebound; `FIXED_SIGNER_SHA256` and `WRAPPER_VERIFIER_SHA256` recomputed from the rebound bytes. |
| `qualify_native_loads.py`, `qualify_split_loads.py` | `ROOT`/`REAL_HOME` rebound; `NATIVE_SHA256` recomputed. |
| `verify_split_service.py`, `local_release.py` | Service-receipt path translation (below). |
| `Tests/test_fixed_signing.py`, `Tests/test_split_qualification.py` | Expected keychain path / fixed-signer pin. |

## Service receipt path (decision B)

The reviewed 1503 service receipt `service-current-schema.json`
(SHA256 `eed26f32…79a6`, unchanged) records the original absolute service path.
The only receipt writer re-signs the service, which would change released signed
bytes, so the receipt is not regenerated or edited. Instead
`verify_split_service.receipt_app_matches` accepts exactly one recorded value
(`/Users/layoute/SideWork/FlClash/.airbuild/local-release/service-core-1503/service-payload/Flash.app`)
for exactly one current canonical location (`ROOT/.airbuild/local-release/service-core-1503/service-payload/Flash.app`),
for phase `service` only. GUI receipts still require their own exact path. All other
receipt checks remain: receipt SHA256 pin, schema/phase, certificate pins,
compatibility, after-tree SHA256 and entries, Core binding.

## Service signature display digest (option A, owner-approved)

Each receipt target slice records `display_sha256`, the SHA256 of the raw
`codesign --display --verbose=4` text. That text is host-rendered: absolute
`Executable=` path, local-time-zone `Signed Time=`, and codesign/OS version (receipt
from macOS 27.0.1/26A434, codesign `d517c9be…`; this Mac 27.2/26B123, codesign
`f9e0b219…`). It can't be reproduced here even though the signed bytes are identical.
For the migrated service receipt only, `verify_split_service.migrated_display_targets`
replaces the raw-text comparison by parsing the current display and requiring:
exact `Executable` (current path), `Identifier`, `CDHash` / `CandidateCDHashFull`
prefix equal to the receipt cdhash, a single `Authority=Flash Local Code Signing`,
`TeamIdentifier=not set`, no `Timestamp`, not adhoc, CodeDirectory flags exactly
`0x10000(runtime)`, and a present `Signed Time`. Every other slice field (flags,
entitlements, leaf certificate SHA1/SHA256), every other target field and the
exact byte tree are still compared to the receipt exactly. The raw host-text
digest is no longer compared for this one receipt.

## Protected private route (ignored, not committed)

- **Paths:** templates, adapter `ROOT`, `config.json` (SDK = project Flutter 3.47.4,
  service/receipt/adapter paths); template pins, `PINS_SHA256` and `signer_sha256`
  recomputed from actual bytes (`gui-template-pins.json` → `e01afea9…`).
- **Preflight ancestry:** the AirBuild-managed parent of `ROOT` is mode `02755`.
  Exactly that one pinned directory may carry exactly `S_ISGID` (no write
  permission, and on Darwin it doesn't change group inheritance); owner, write,
  setuid and sticky rules are unchanged for it and for every other directory.
- **Guard signing-directory layout:** originally `{keychain, .fl4ADC6B31, Backups/, FlashSigning.cer}`
  with metadata-only preservation of the backup `.p12` and `.cer`. Here the
  directory holds `{FlashSigning.keychain-db, .fl4ADC6B31, tools/}` and `tools/`
  holds exactly its six reviewed entries. The frozen ACL creator
  `tools/signing-provision` is checked: regular file, same uid, one link, mode
  exactly 0500, no allow-ACL, size 77664, full SHA256 `4bdb5a6b…6b60`,
  `originalTool` path equality, metadata unchanged through the session. This is
  stricter than before (content hash in addition to metadata).
- **Guard key items:** the native PKCS#12 import created no separate public-key
  item (one private key, one certificate, one identity). The guard now requires
  exactly 0 public keys and 1 key item total, and keeps the private-label check
  against SHA1 of the pinned canonical public key. It also adds a check that the
  identity's private key is that single key item. The ACL check (codesign + frozen
  creator, no allow-all, private and non-extractable attributes) is unchanged.
- **Guard success marker:** `backup-metadata-preserved` → `creator-tool-preserved`
  (adapter updated to match).

## Host environment adaptations (no check change)

- `qualify_split_loads.DRIVER_SHA256` was stale (it pinned `sign_split_payload.py` from
  `86b1ae04`). It is re-pinned to the current rebound signer, and the full packaging
  test suite passes (251 tests, 2 skipped).
- `sign_split_payload.REVIEWED_HOST` (macOS 27.0.1/26A434, codesign `d517c9be…`)
  is left as is. It gates only direct service signing/qualification, which the GUI
  route doesn't use. If the service is ever re-signed on this Mac, re-pin it here.
- The Rust toolchain lives in `.airbuild/tools` (rustup/cargo, toolchain 1.99.0), not
  `~/.cargo`. Release phases run with `PATH=.airbuild/tools/shims:$PATH`, and the
  build scripts are unchanged.
- `.airbuild/local-release/config.json` is restored to the required mode 0600; the
  archive restore had left it 0644.
