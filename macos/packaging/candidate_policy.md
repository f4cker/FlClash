# Managed candidate capability

`FC_MANAGED_CANDIDATE_ENABLED` defaults to `0`. Opting in with `1` enables
only an unqualified, nondistributed candidate capability. It is not a statement
that any executable was tested or that an artifact is safe to distribute.
The existing exact certificate pin, empty Apple Team ID, daemon self-check,
audit-message authentication, and other entitlement restrictions still apply.
The library-validation exception remains limited to the protected GUI identity.

## One per-build setting

Supply a local, ignored xcconfig through `XCODE_XCCONFIG_FILE`:

```xcconfig
FC_MANAGED_CANDIDATE_ENABLED = 1
GCC_PREPROCESSOR_DEFINITIONS = $(inherited) FC_MANAGED_CANDIDATE_ENABLED=$(FC_MANAGED_CANDIDATE_ENABLED)
```

Xcode exports this user-defined setting to the staging build phase. Runner
receives the macro through `GCC_PREPROCESSOR_DEFINITIONS`;
`stage_bundled_daemon.sh` validates the same setting as exactly `0` or `1`
(default `0` when absent) and passes it explicitly to the bundled daemon's clang
invocation. An empty or other value is an error. Do not inject a different
candidate definition through compiler flags or supply a conflicting setting.

## Qualification is external

The package qualification guard must require successful runtime proof for the
exact signed artifact, recorded outside its sealed bundle. Neither this compile
bit nor an environment assertion is qualification evidence. Missing, stale,
partial, failed, or wrong-artifact proof must block delivery; copied and expanded
package payloads must match the qualified input. Any byte, signature, or define
change requires requalification. Candidate build/staging alone authorizes no
execution, installation, publication, or fallback to an unmanaged package.
Load-only proof does not establish helper installation, XPC, TUN, or reboot
acceptance; those remain separately authorized checks.

## Pure policy fixture

Compile `Shared/HelperTrust.m` with
`PrivilegedHelper/Tests/TrustPolicyTests.m`, Foundation and Security, ARC and
blocks. The fixture's independent expected candidate value defaults to `0`.
Run it with no candidate definition, with an obsolete verification definition
alone (still expected `0`), and with both
`-DFC_MANAGED_CANDIDATE_ENABLED=1` and
`-DFC_TRUST_TEST_EXPECT_CANDIDATE_ENABLED=1`.
These are pure entitlement/requirement fixtures, not signed-artifact runtime
proof or an exercise of live XPC authentication.
