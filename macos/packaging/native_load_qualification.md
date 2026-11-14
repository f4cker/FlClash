# Exact-artifact native-load qualification

Candidate opt-in is not runtime proof; see [candidate policy](candidate_policy.md).
Stage and statically sign the final candidate once using the reviewed fixed-identity
signing driver. Its `Flash.signing-static.json` must still declare
`actualGUIloads=false` and `packaging_accepted=false`. Do not rebuild, alter,
re-sign, or distribute that candidate after qualification.

## Inputs and authorization

Use non-root `/usr/bin/python3 -I -S -B` and canonical absolute paths. `APP` must
be the protected staged `Flash.app` accepted by `sign_fixed_payload.py`.
`METADATA` is the frozen build JSON: matching version/build, the fixed certificate
SHA-1, empty `apple_team`, `runtime_acceptance=false`, `actualGUIloads=false`,
`packaging_accepted=false`, and `defines` containing `APP_ENV="stable"`,
`MACOS_MANAGED_HELPER=true`, and integer `FC_MANAGED_CANDIDATE_ENABLED=1`.
Metadata declares build provenance; the harness does not recover compiled macros.

Stop all cooperative bundle, metadata, signing-source, and evidence writers
before the final freeze. This is local cooperative evidence, not protection
against a hostile same-UID process. The dedicated evidence directory must already
exist at `.airbuild/evidence/native-load-qualification` under the worktree and
pass the signing driver's directory/ACL checks. `EVIDENCE` must be a new `.json`
file there; creation is exclusive with mode 0600. Temporary HOME/cache/config
paths live only below `.airbuild/native-load-scratch`.

**Only after separate explicit human permission to execute this exact signed GUI:**

```sh
/usr/bin/python3 -I -S -B macos/packaging/qualify_native_loads.py \
  --run-approved-probe --app "$APP" --build-metadata "$METADATA" --evidence "$EVIDENCE"
```

This directly launches only the diagnostic GUI arguments under `sandbox-exec`
and native `/usr/bin/arch`, never normal startup, Core, helper, or installer.
The child receives a fresh challenge and sanitized environment, is supervised
by its owned PID, has a 25-second deadline and 64-KiB limit per output stream,
and must exit zero with one challenge-bound `FLASH_NATIVE_LOADS` JSON record
passing `flutter_pixel`, `rust_utf8`, `objective_c_string`, and `sqlite_memory`.
Failures, timeouts, malformed/partial output, wrong executable, or input mutation
leave unqualified evidence. Retry with a fresh evidence filename after review.

The default-deny profile forbids networking, forks, helper lookup, reads of known
real app/signing/keychain/evidence data, sysctl writes, and filesystem writes
outside scratch. The installed OS `dyld-support.sb` supplies necessary dyld
bootstrap operations; its SHA-256 and the OS version/build/architecture are bound
into before/after evidence. A nested policy import/include is refused pending
review. System-only `true` and native `arch` fixtures validated the bootstrap fix;
those are not GUI or four-probe qualification. The profile deliberately fails
closed if an unreviewed GUI facility is required; do not broaden it silently.
OS-managed Cocoa/Flutter/WindowServer/GPU caches or preferences may still be
affected despite child filesystem restrictions. Do not promise zero OS effects.

## Verification and packaging

Verification never launches GUI code:

```sh
/usr/bin/python3 -I -S -B macos/packaging/qualify_native_loads.py \
  --verify-evidence --app "$APP" --build-metadata "$METADATA" --evidence "$EVIDENCE"

/bin/bash macos/packaging/build_managed_packages.sh \
  "$APP" "$NEW_OUTPUT" "$EVIDENCE" "$METADATA"
```

The builder rejects missing/stale/failed/partial/wrong-artifact evidence before
creating output. Environment acceptance bits are not supported. It revalidates
current signed bytes, public certificates/entitlements for every slice, source
hashes, report/metadata and host binding, then checks the copied bundle and each
statically expanded package. Expansion never installs or runs installer scripts.
Install/repair payload inventory must exactly match the qualified signed bundle;
script sources, the maintenance binary, payload location/count, and extra payload
are checked. `PackageInfo` must retain install-location `/`, exactly the reviewed
`./preinstall` and `./postinstall` execution declarations, and no relocation rules.
Disable/remove must have no payload. Any byte, signature, define,
provenance-source, report, metadata, or bound host-policy change invalidates proof.

Successful load evidence is **not** helper installation, authorization, XPC, TUN,
reboot/recovery, installer acceptance, notarization, or distribution approval.
Package artifacts remain unsigned local candidates. Those later operations need
their own explicit approval and acceptance evidence.

## Pure regression checks

```sh
/usr/bin/python3 -I -S -B -m unittest discover -s macos/packaging/Tests -v
/bin/bash -n macos/packaging/build_managed_packages.sh
```

These tests use mocks and fixtures; they do not qualify a production artifact.
