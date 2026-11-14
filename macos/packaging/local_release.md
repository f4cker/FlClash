# Local macOS GUI-only release

This is a local Mac command, not a GitHub runner workflow. It does not enable the
upstream Telegram/Homebrew publishing integrations. Gitta owns merging `main` and
creating/pushing the matching tag. Do that before building: the CLI refuses a dirty
checkout, another branch, mismatched submodules, or a tag not at `main` HEAD.

The current delivery is `0.9.8+2026111405`, arm64 GUI-only. It retains the stable
helper build `2026111402` and Core SHA256
`0441127a849029cab427e74f334c4b4aa3ba025f525003bf85ded03ba81820b5`.
The DMG is not a first-time helper installer. No helper PKGs are uploaded.
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

After source merge/tag coordination and local setup:

```sh
python3 macos/packaging/local_release.py check --tag v0.9.8 --run release-098
python3 macos/packaging/local_release.py run --tag v0.9.8 --run release-098
```

`check` validates local source/config/service inputs without building, signing or
network. `run` actually builds a fresh unsigned GUI, stages the exact retained
Core, invokes the protected signer, statically verifies signatures and receipts,
creates the styled DMG through `build_split_packages.sh gui-only`, verifies its
read-only mounted bundle copy, and creates/verifies a GitHub **draft**. It does not
launch/install the app, helper or Core. Only draft/publish phases access GitHub.
The command requires the runtime-provided `gh` authentication, not a personal login.

To explicitly publish in one invocation, use `run ... --publish`. To publish a
previously verified draft, use:

```sh
python3 macos/packaging/local_release.py publish --tag v0.9.8 --run release-098
```

Individual `build`, `sign`, `package`, and `draft` phases accept the same options.
Completed phases resume from hash-bound local receipts. Source/config changes,
changed unsigned inputs, signatures, service bytes, release assets, or notes stop
the run. Failed partial phases are retained for inspection, not silently retried
or deleted; use a new run name after resolving the failure. A GitHub draft created
before a local checkpoint failure is not silently adopted. No automatic deletion
of a remote release, tag, previous build, or existing mounted volume occurs.

Only `Flash-0.9.8-macos-arm64.dmg` and `SHA256SUMS` are uploaded. Provenance, guard
outputs and manifests remain in the ignored run directory; `.airbuild` is never
uploaded wholesale. GitHub-generated notes are appended to the structured
changelog markers/JSON consumed by the app. Before publication the tool checks
remote main/tag commits, the draft's exact asset-name allowlist and notes, then
downloads its two assets to compare their actual bytes with local SHA256 hashes.

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
GUI staging/compatibility sealing. The fresh compiler output and Xcode build
requests remain under `<run>/build/new-xcode-macos/`.

The adapter verifies the supplied request pin, refreshes only the proven route's
exact source/path/hash/build bindings, and uses its existing protected private
pipe/guard mechanism. It signs the requested `<run>/gui/Flash.app` **in place**;
it must not stage again, substitute a prebuilt GUI, sign Core, rebuild/sign the
service, or change unsigned inputs before signing. Any private signing provenance
stays local. Public receipt hashes bind data, not authority to unlock/sign: the
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
bash -n macos/packaging/build_local_gui.sh macos/packaging/stage_managed_helper.sh
```

Mock tests exercise command flow and failure boundaries without SDK hooks,
application execution, credentials, signing or network. They do not establish
that the operator's private adapter, fresh native build, Finder DMG creation or
GitHub publication has run successfully.
