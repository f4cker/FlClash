# Project move handoff — 2026-11-13

**New agent: read this file first, then `AGENTS.md`. Chat history is not moved.**
This is the existing Flash/FlClash Flutter project (Flutter **3.47.x**), currently
focused on macOS, not a new iOS app. Do not generate an iOS manifest.

## Supported source checkout

The repository root, originally `/Users/layoute/SideWork/FlClash` (`R`), now
contains the latest source and is the supported checkout to transport and use.
Its branch is `chore/move-ready-20261113`; the full source-base commit is
`4330c6af758b0f8acdffda4fb67e03c8fb745e13`.
The move-preparation commit on this branch adds only the handoff, source-tool
archive, agent pointer and one narrow ignore exception on top of that source-base
commit; it does not alter application logic. These files are committed locally
with the subject `chore: prepare latest source for workspace move`.
No push or merge was performed. Parent-verified GitHub status on
**2026-11-13**:

- `f4cker/FlClash`: source-base commit
  `4330c6af758b0f8acdffda4fb67e03c8fb745e13` was **not found**; remote `main`
  remains at `fc42fc70f4e14cb7054e47cbae2de80d8d289d8e`.
- `f4cker/Clash.Meta`: pin `15af7cd6e534971e6f07bcba1d50f63f5cc8134c`
  is already on remote branch `flash/0.9.5`.
- `f4cker/prism_ui`: pin `268cecc7c99caa8c8732863e6706214ce790eba5`
  is already on remote branch `flash/0.9.5`.

The submodule remote checks do **not** make GitHub a backup of the latest
superproject source or the local move-preparation commit; carry the local repository.

Retained refs, not reset or deleted:

- `main`: `fc42fc70f4e14cb7054e47cbae2de80d8d289d8e` (old root source).
- `fix/exit-group-cleanup`: `4330c6af758b0f8acdffda4fb67e03c8fb745e13`;
  original worktree `W` is `R/.airbuild/worktree/exit-cleanup`.

The root has clean, exact submodule pins:

| Submodule | Commit |
| --- | --- |
| `core/Clash.Meta` | `15af7cd6e534971e6f07bcba1d50f63f5cc8134c` |
| `plugins/prism_ui` | `268cecc7c99caa8c8732863e6706214ce790eba5` |

Root submodule `.git` files use relative links to
`.git/modules/core/Clash.Meta` and `.git/modules/plugins/prism_ui`; their
`core.worktree` links are relative too. These root module Gitdirs have no object
alternates and are self-contained when carried with the root `.git` directory.
The parent agent reports full Git-object closure checks (`git fsck`) **PASS** for
the main repository and both root submodule repositories: no missing objects.
This does not establish runtime acceptance or a remote backup.

## What to carry, and what stays behind

No actual move has been performed. For a subsequent owner-authorized move, carry
**all of root `.git/`**, including refs, objects and `.git/modules/`, plus all
nonignored project files, hidden project files included, and both submodule source
trees at the pins above. Include the new `PROJECT-MOVE.md`, `.agents/` guidance,
and the tracked `project-move/` archive and manifest. Copying only visible
files, or only the superproject without submodule contents/metadata, is insufficient.
Preserve file bytes, modes and symlinks. Keep the original until arrival checks pass.

`.airbuild/` and `docs/` (including `.airbuild/docs/`) are ignored, not the
transported handoff. Do not carry ignored build/cache or private material merely
because `.git/` is carried. Old worktree metadata inside `.git/worktrees/` contains
absolute paths; W's submodule alternates also point to absolute original-Mac paths.
Those links become stale after relocation. Use the root checkout, **not W**; do not
use, repair, remove or prune old worktrees/alternates automatically. Preserve that
metadata and the retained refs for a separately authorized decision; no automatic
GC/prune, fetch, reset or submodule update is part of arrival.

Private/signing exclusions are explicit:

- Actual signing identity and encrypted backup are outside this project on the
  original Mac at `/Users/layoute/Library/Application Support/Flash Signing`.
  They are **never migrated by this project move**.
- W's original signing-provision folder is preserved in place, ignored, and **not
  transferred**:
  `/Users/layoute/SideWork/FlClash/.airbuild/worktree/exit-cleanup/.airbuild/evidence/mac-authorization/signing-provision`.
  Do not copy or touch that folder, its tools, or its frozen executables.
- Ignored private settings remain on the original Mac in
  `R/.airbuild/move-essentials/private-configs`; they are **not transferred
  automatically**. Do not include `.env`, `.fvmrc`, `env.json`, identity files or
  credentials. If settings are needed at the destination, obtain them from the
  owner through a private channel.

Portable code does **not** mean the destination is ready to sign.

## Archival tool sources, not a build entrypoint

`project-move/tool-source.zip` preserves exact source bytes from these original
locations, with path, byte count and SHA-256 provenance in
`project-move/tool-source-manifest.json`:

- `R/.airbuild/move-essentials/build-tool-source`: all 21 `.py`/`.sh` files.
- `R/.airbuild/tools`: five source scripts.
- `W/.airbuild/tools`: 16 `.py`/`.sh` or text `xcrun` source files only.

This is a **source-only, archival/incomplete snapshot**, not a new build entrypoint
or a claim that old tooling can be replayed. No archived script was imported or
executed. Reviewed source text was scanned for embedded credentials/private-key
blocks without printing possible secret values; none were detected. Password
variable names and public certificate fingerprints are not credentials.
`prepared.json`/prepared metadata, data, evidence, binaries, signing-provision,
private configs and identities are excluded. Existing tracked image assets suffice;
no extra images were archived.

Archived scripts can contain absolute original SDK/Mac paths and depend on deleted
proof/evidence or tools not carried here. Review and adapt them only with later
owner consent; **do not execute them on arrival**. Prior build/cache, diagnosis,
delivery and rollback artifacts were deleted intentionally during authorized move
preparation. Old qualifiers are not replayable against those deleted dependencies.
The original five-file Desktop delivery was kept and its checks **PASS**; that
original delivery is outside this project move and is not transferred by it.

## Read-only arrival checks (no fetch)

From the transported root, run only read-only checks initially:

```sh
git --no-optional-locks status --short --branch
git branch --show-current
git rev-parse HEAD
git rev-parse main fix/exit-group-cleanup
git submodule status
git -C core/Clash.Meta --no-optional-locks status --short
git -C core/Clash.Meta rev-parse HEAD
git -C plugins/prism_ui --no-optional-locks status --short
git -C plugins/prism_ui rev-parse HEAD
```

Compare the retained refs and both pins with this document. On the prepared
branch, HEAD is the move-preparation commit with the source-base commit above as
its direct parent; its five changed paths are `.agents/project.md`, `.gitignore`,
`PROJECT-MOVE.md`, `project-move/tool-source.zip` and
`project-move/tool-source-manifest.json`. The working tree should be clean.
Submodules must be clean and initialized (no `-`, `+` or conflict prefix).
Inspect the root submodule
`.git` links and archive manifest/hashes without executing the sources. Stop on
missing objects, incorrect pins, unexpected changes or external root-module Git
links; do not fetch or silently repair. Do not run build/dependency-install commands
from general project instructions as part of these arrival checks.

Actual runtime acceptance on the **original test Mac is still pending**. This
handoff grants **no new build, runtime, signing, keychain, install, network or push
permission**. No application logic was changed by this handoff.
