# Local macOS release with embedded helper installers

This is a local Mac command, not a GitHub runner workflow. It does not enable the
upstream Telegram/Homebrew publishing integrations. Gitta owns merging `main` and
creating/pushing the matching tag. Do that before building: the CLI refuses a dirty
checkout, another branch, mismatched submodules, or a tag not at `main` HEAD.

The arm64 release embeds first-install and repair packages for the unchanged stable
helper build `2026111402` and retains Core SHA256
`0441127a849029cab427e74f334c4b4aa3ba025f525003bf85ded03ba81820b5`.
The app can request macOS administrator authorization to install or repair that
helper; first-time users do not need a separate helper download. No helper PKGs
are uploaded as separate public assets. Version/tag selection remains a separate
release coordination step.
The existing self-signed identity is retained; this is not Apple Developer ID
signing or notarization. Static checks are not runtime acceptance.

## Persistent local setup

Use the proven local Flutter **3.47.4** SDK with dependencies already resolved,
Go/Rust/Xcode available on `PATH`, cached native dependencies, and a graphical Mac
session for the existing Finder-styled DMG route. The build is offline, disables
Xcode signing, and denies `codesign`/`security` execution inside the unsigned build.
It preserves old compiler/output caches in the run's `build/kept-caches`, forces
fresh compilation, and leaves new ordinary project build caches in place. It does
not change global SDK configuration. A missing dependency fails; resolve it
separately rather than silently enabling network access.

Create `.airbuild/local-release/config.json` privately with mode `0600`; do not
commit it or copy credentials into it. All paths must be canonical absolute paths:

```json
{
  "schema": 1,
  "sdk": "<Flutter SDK root>",
  "signer": "<executable protected local adapter>",
  "signer_sha256": "<adapter SHA256>",
  "service": "<existing stable 1402 service Flash.app>",
  "service_receipt": "<existing current-schema service receipt>",
  "service_receipt_sha256": "<service receipt SHA256>"
}
```

The signer is a required externally maintained adapter to the existing protected
local signing route. The public tool does not unlock keychains, accept passwords,
copy private guard code, or invent unattended authentication. The adapter must be
wired and reviewed locally before the real release invocation; a placeholder or
a direct invocation of the old hardcoded tracked signer is not sufficient.

## Commands

For the pending `0.9.9+2026111406` local artifact, use separate phases after review,
commit, and local tag coordination. A matching local `v0.9.9` tag at clean `main`
HEAD is required even for `check`; this tool never creates or moves tags.
These phases do not create a GitHub draft or publish:

```sh
python3 macos/packaging/local_release.py check --tag v0.9.9 --run release-099-embedded
python3 macos/packaging/local_release.py build --tag v0.9.9 --run release-099-embedded
python3 macos/packaging/local_release.py sign --tag v0.9.9 --run release-099-embedded
python3 macos/packaging/local_release.py package --tag v0.9.9 --run release-099-embedded
```

Use a new run name after a partial failure. Each phase requires the same source,
config, and run binding. Signing still requires separate authorization for the
protected adapter; packaging does not install or launch the delivered code.

Only when GitHub draft creation is separately authorized, after source merge/tag
coordination and local setup:

```sh
python3 macos/packaging/local_release.py check --tag vX.Y.Z --run release-XYZ
python3 macos/packaging/local_release.py run --tag vX.Y.Z --run release-XYZ
```

`check` validates local source/config/service inputs without building, signing or
network. `run` actually builds a fresh unsigned GUI, stages the exact retained
Core, builds and embeds install/repair packages from the exact signed stable service,
invokes the protected GUI signer, statically verifies signatures and receipts,
creates the styled DMG through `build_split_packages.sh gui-only`, verifies its
read-only mounted bundle copy, and creates/verifies a GitHub **draft**. It does not
launch/install the app, helper or Core. Only draft/publish phases access GitHub.
The command requires the runtime-provided `gh` authentication, not a personal login.

To explicitly publish in one invocation, use `run ... --publish`. To publish a
previously verified draft, use:

```sh
python3 macos/packaging/local_release.py publish --tag vX.Y.Z --run release-XYZ
```

Individual `build`, `sign`, `package`, and `draft` phases accept the same options.
Completed phases resume from hash-bound local receipts. Source/config changes,
changed unsigned inputs, signatures, service bytes, release assets, or notes stop
the run. Failed partial phases are retained for inspection, not silently retried
or deleted; use a new run name after resolving the failure. A GitHub draft created
before a local checkpoint failure is not silently adopted. No automatic deletion
of a remote release, tag, previous build, or existing mounted volume occurs.

Only `Flash-X.Y.Z-macos-arm64.dmg` and `SHA256SUMS` are uploaded. Provenance, guard
outputs and manifests remain in the ignored run directory; `.airbuild` is never
uploaded wholesale. GitHub-generated notes are appended to the structured
changelog markers/JSON consumed by the app. Before publication the tool checks
remote main/tag commits, the draft's exact asset-name allowlist and notes, then
downloads its two assets to compare their actual bytes with local SHA256 hashes.

## Embedded installer contract

After `stage_gui` and before the unsigned GUI inventory/signing request, the local
CLI runs `build_split_packages.sh embedded-released-service`. This narrow route
verifies the existing service signing receipt, fixed identity, exact stable build
and Core, then reuses the helper-update route's package construction, raw package
normalization, transactional install/repair scripts, and exact signed
`FlashMaintenance`. It does not compile or re-sign service code and does not claim
new compile evidence. The existing helper-update route still requires its compile
receipt. Neither route executes the delivered installer scripts during packaging.

Both expanded packages are checked with `stage_split_payload.verify_expanded`:
service payload inventory, reviewed scripts, executable modes, and signed
maintenance bytes must match exactly. Package work stays under the ignored run's
`helper-packages/`; only these resources are copied into the unsigned GUI:

```text
Contents/Resources/HelperInstaller/Flash-helper-install.pkg
Contents/Resources/HelperInstaller/Flash-helper-repair.pkg
Contents/Resources/HelperInstaller/manifest.json
```

`manifest.json` has exactly this contract, with lowercase SHA256 of the final
package bytes (no plist and no additional service fields):

```json
{
  "schema": 1,
  "packages": {
    "install": {"file": "Flash-helper-install.pkg", "sha256": "<SHA256>"},
    "repair": {"file": "Flash-helper-repair.pkg", "sha256": "<SHA256>"}
  }
}
```

Resources have mode `0644` and their directories `0755`, including under umask
`077`. They enter the unsigned inventory and outer app signature together with the
fresh GUI. Exact-copy verification of the mounted DMG includes them. The packages
are internal resources, not separately published or Developer ID signed PKGs;
the installed service binaries retain their existing signatures. Packaging/static
checks do not establish first-install, repair, authorization UI, or runtime acceptance.

## Protected adapter contract (version 1)

The invocation is an argv array, never a shell command:

```text
<signer> --request <run/sign-request.json> --request-sha256 <SHA256> --response <run/sign-response.json>
```

The request has `schema: "flash-local-gui-sign-v1"`, `source` (`head`, `tag`,
`version`, `build`), absolute `run` and unsigned `app`, `mode: "gui-only"`,
`certificate_sha1`, `core_sha256`, `service`, `service_receipt`,
`service_receipt_sha256`, `unsigned_entries`, `build_log_sha256`, and
`public_sources` (project-relative packaging Python sources and their SHA256).
`unsigned_entries` is the existing fixed verifier's exact inventory after tracked
GUI staging/compatibility sealing and embedded installer creation. The retained
`mode: "gui-only"` identifies the signing scope (only GUI code is signed), not a
requirement for an already-installed helper. The fresh compiler output and Xcode build
requests remain under `<run>/build/new-xcode-macos/`.

The adapter verifies the supplied request pin, refreshes only the proven route's
exact source/path/hash/build bindings, and uses its existing protected private
pipe/guard mechanism. It signs the requested `<run>/gui/Flash.app` **in place**;
it must not stage again, substitute a prebuilt GUI, sign Core, rebuild/sign the
service, or change unsigned inputs before signing. Any private signing provenance
stays local. A fresh-output comparison must account for the two verified package
resources and their manifest added by tracked staging; it must not ignore other
resource differences. Public receipt hashes bind data, not authority to unlock/sign: the
external guard remains responsible for freezing inputs and excluding writers.

On success write a new regular response file with exactly:

```json
{
  "schema": 1,
  "request_sha256": "<request SHA256>",
  "gui_receipt": "<absolute current-schema GUI receipt inside this run>",
  "gui_receipt_sha256": "<receipt SHA256>"
}
```

The GUI receipt is schema 1 accepted by `verify_split_service.py`: phase/app,
static verification, exact certificate pins, compatibility, retained Core hash,
before/after inventories and tree hashes, signature targets and library
constraint. Projecting the proven protected route receipt into this existing
schema is allowed; `before.entries` must equal request `unsigned_entries` exactly.
The public CLI independently verifies that binding and all existing static
signature/constraint checks before packaging. Nonzero adapter exit is fatal.

## Source-only verification

```sh
python3 -B -m unittest discover -s macos/packaging/Tests -p 'test_*.py'
bash -n macos/packaging/build_local_gui.sh macos/packaging/stage_managed_helper.sh macos/packaging/build_split_packages.sh
```

Mock tests exercise command flow and failure boundaries without SDK hooks,
application execution, credentials, signing or network. They do not establish
that the operator's private adapter, fresh native build, Finder DMG creation or
GitHub publication has run successfully.
