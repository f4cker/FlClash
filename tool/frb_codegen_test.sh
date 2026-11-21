#!/usr/bin/env bash
# Tests tool/frb_codegen.sh in scratch git copies of the committed rust_api package.
# The stubbed cases (refusals, copy-back, injected faults at every stage,
# signals, leftover backups and tombstones, recover.sh, make) run under env -i with a PATH of symlinks to the few tools the
# script needs and temp HOME/CARGO_HOME/RUSTUP_HOME, so no machine rustup leaks
# in. The real-codegen cases need rustup and flutter_rust_bridge_codegen (PATH
# or FRB_CODEGEN); when they cannot run the script exits 77 (SKIP) unless
# FRB_TEST_ALLOW_SKIP=1.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
root="$(cd "$script_dir/.." && pwd -P)"
git_bin="${GIT:-git}"
command -v "$git_bin" >/dev/null 2>&1 || { echo "frb_codegen_test: $git_bin is not on PATH; set GIT" >&2; exit 1; }
scratch="$(mktemp -d "${TMPDIR:-/tmp}/frb_codegen_test.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT

failures=0
skipped=0
status=0
package_rel='plugins/rust_api'
generated_rel="$package_rel/lib/src/rust/frb_generated.dart"
pinned="$(sed -nE 's/^flutter_rust_bridge[[:space:]]*=[[:space:]]*"=?([^"]+)".*/\1/p' "$root/$package_rel/rust/Cargo.toml")"
channel="$(sed -nE 's/^[[:space:]]*channel[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' "$root/$package_rel/rust/rust-toolchain.toml" | head -n 1)"
# The outputs the update stub changes, in the script's order; extra.dart is new.
updated=(lib/src/rust/api/charset.dart lib/src/rust/frb_generated.dart rust/src/frb_generated.rs)

fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

skip() {
  echo "SKIP: $*"
  skipped=$((skipped + 1))
}

# Isolated tools: the real git binary (not a wrapper that searches PATH) and
# exactly the utilities frb_codegen.sh, its stubs and make use.
iso="$scratch/iso"
mkdir -p "$iso/bin" "$iso/home" "$iso/cargo" "$iso/rustup" "$iso/tmp"
real_git="$("$git_bin" --exec-path 2>/dev/null)/git"
[[ -x "$real_git" ]] || real_git="$(command -v "$git_bin")"
ln -s "$real_git" "$iso/bin/git"
# The same sha256 tool frb_codegen.sh picks.
if command -v sha256sum >/dev/null 2>&1; then sha_tool=(sha256sum); else sha_tool=(shasum -a 256); fi
sha_name="${sha_tool[0]}"
for tool in bash sh env sed awk head grep mkdir mktemp cp mv rm cmp find dirname cat printf rsync make "$sha_name"; do
  path="$(command -v "$tool")" || { echo "frb_codegen_test: $tool is not on PATH" >&2; exit 1; }
  [[ "$path" == /* ]] || path="$(type -P "$tool")"
  ln -s "$path" "$iso/bin/$tool"
done

new_sandbox() {
  local sandbox="$scratch/$1"
  mkdir -p "$sandbox/tool" "$sandbox/.dart_tool"
  "$git_bin" -C "$root" archive HEAD -- "$package_rel" pubspec.yaml analysis_options.yaml lint_options.yaml |
    tar -x -C "$sandbox"
  cp "$script_dir/frb_codegen.sh" "$sandbox/tool/"
  cp "$root/Makefile" "$sandbox/"
  cp "$root/.dart_tool/package_config.json" "$sandbox/.dart_tool/"
  "$git_bin" -C "$sandbox" init -q
  "$git_bin" -C "$sandbox" add -A
  echo "$sandbox"
}

manifest() {
  (cd "$1/$package_rel" && find . -type f -print0 | sort -z | xargs -0 "${sha_tool[@]}")
}

# run_iso SANDBOX PATH-PREFIX [VAR=value...]: frb_codegen.sh in the isolated env.
run_iso() {
  local sandbox="$1" prefix="$2"
  shift 2
  set +e
  (cd / && env -i PATH="$prefix$iso/bin" HOME="$iso/home" CARGO_HOME="$iso/cargo" RUSTUP_HOME="$iso/rustup" \
    TMPDIR="$iso/tmp" FRB_CODEGEN="$fake/codegen" "$@" "$iso/bin/bash" "$sandbox/tool/frb_codegen.sh") \
    >"$scratch/out" 2>"$scratch/err"
  status=$?
  set -e
}

run_real() {
  local sandbox="$1"
  shift
  set +e
  (cd / && env "$@" bash "$sandbox/tool/frb_codegen.sh") >"$scratch/out" 2>"$scratch/err"
  status=$?
  set -e
}

no_leftovers() {
  local name="$1" sandbox="$2"
  [[ ! -e "$sandbox/.frb_codegen_backup" ]] || fail "$name: left the backup directory"
  if [[ -n "$(find "$sandbox" -name '*.frb_codegen.*')" ]]; then fail "$name: left staged files"; fi
}

# expect STATUS NAME NEEDLE SANDBOX PREFIX [VAR=value...]: that exit, that
# stderr, and the package byte-identical to before with nothing left behind.
expect() {
  local want="$1" name="$2" needle="$3" sandbox="$4" prefix="$5" before
  shift 5
  before="$(manifest "$sandbox")"
  run_iso "$sandbox" "$prefix" "$@"
  [[ "$status" == "$want" ]] || fail "$name: exit $status, not $want"
  if ! grep -q -- "$needle" "$scratch/err"; then
    fail "$name: stderr does not say '$needle'"
    cat "$scratch/err" >&2
  fi
  [[ "$(manifest "$sandbox")" == "$before" ]] || fail "$name: tracked files changed"
  if grep -q "UNKNOWN" "$sandbox/$generated_rel"; then fail "$name: UNKNOWN was written"; fi
  no_leftovers "$name" "$sandbox"
}

# expect_recoverable NAME SANDBOX BEFORE [PATH]: the restore failed, so exit 3,
# every other file still restored (only PATH, if given, differs), a complete and
# intact backup, recovery steps printed, later runs refused, and the printed
# recover.sh brings back exactly the original package.
expect_recoverable() {
  local name="$1" sandbox="$2" before="$3" left="${4:+$package_rel/$4}" kept="$2/.frb_codegen_backup" relative
  [[ "$status" == 3 ]] || fail "$name: exit $status, not 3"
  [[ "$({
    "$git_bin" -C "$sandbox" diff --name-only -- "$package_rel"
    "$git_bin" -C "$sandbox" ls-files --others --exclude-standard -- "$package_rel"
  })" == "$left" ]] || fail "$name: the restore did not put back every file it could"
  grep -q 'restore FAILED' "$scratch/err" || fail "$name: stderr does not report the failed restore"
  grep -q "bash .*recover.sh" "$scratch/err" || fail "$name: no recovery command printed"
  grep -q "cp -p .*files/lib/src/rust/frb_generated.dart" "$scratch/err" || fail "$name: recovery steps not listed"
  for relative in "${updated[@]}"; do
    "$git_bin" -C "$sandbox" show ":$package_rel/$relative" | cmp -s - "$kept/files/$relative" ||
      fail "$name: backup of $relative is missing or altered"
  done
  [[ "$(wc -l <"$kept/SHA256SUMS" | tr -d ' ')" == "${#updated[@]}" ]] || fail "$name: SHA256SUMS is incomplete"
  (cd "$kept/files" && "${sha_tool[@]}" -c ../SHA256SUMS >/dev/null) || fail "$name: backup fails its SHA256SUMS"
  run_iso "$sandbox" "$fake/stub:" FAKE_MODE=update
  [[ "$status" == 4 ]] || fail "$name: a later run exited $status, not 4"
  grep -q 'stopped while replacing' "$scratch/err" || fail "$name: a later run did not explain the leftover backup"
  if ! bash "$kept/recover.sh" >"$scratch/recover.out" 2>&1; then
    fail "$name: recover.sh failed"
    cat "$scratch/recover.out" >&2
  fi
  [[ "$(manifest "$sandbox")" == "$before" ]] || fail "$name: recover.sh did not restore the original package"
  no_leftovers "$name (after recover.sh)" "$sandbox"
}

# Stubs. stub/rustup lists the pinned channel, stub/cargo answers the metadata
# preflight, and the stub codegen edits the copy as FAKE_MODE says.
fake="$scratch/fake"
mkdir -p "$fake/no-toolchain" "$fake/stub" "$fake/kill-mv"
cat >"$fake/no-toolchain/rustup" <<'STUB'
#!/bin/sh
[ "$1" = toolchain ] && { echo 'no installed toolchains'; exit 0; }
echo 'error: toolchain is not installed' >&2
exit 1
STUB
cat >"$fake/stub/rustup" <<STUB
#!/bin/sh
[ "\$1" = toolchain ] && { echo '$channel-aarch64-apple-darwin (default)'; exit 0; }
exit 0
STUB
cat >"$fake/stub/cargo" <<'STUB'
#!/bin/sh
[ "$1" = metadata ] || exit 1
echo '{"packages":[{"name":"rust_api","targets":[{"kind":["staticlib","cdylib"],"name":"rust_api"}]}]}'
STUB
cat >"$fake/codegen" <<STUB
#!/bin/sh
if [ "\$1" = --version ]; then echo 'flutter_rust_bridge_codegen $pinned'; exit 0; fi
dart=lib/src/rust
case "\$FAKE_MODE" in
  unknown) sed "s/stem: '[^']*'/stem: 'UNKNOWN'/" \$dart/frb_generated.dart >x && mv x \$dart/frb_generated.dart ;;
  unknown-io) printf "const c = ExternalLibraryLoaderConfig(stem: 'UNKNOWN');\n" >>\$dart/frb_generated.io.dart ;;
  deleted) rm \$dart/api/wifi.dart ;;
  empty) : >\$dart/api/tray.dart ;;
  update)
    echo '// regenerated' >>\$dart/frb_generated.dart
    echo '// regenerated' >>\$dart/api/charset.dart
    echo '// regenerated' >>rust/src/frb_generated.rs
    echo '// new module' >\$dart/api/extra.dart
    echo 'leftover' >rust/Cargo.lock
    mkdir -p .dart_tool && echo 'leftover' >.dart_tool/junk
    echo '// touched' >>rust/src/lib.rs ;;
esac
STUB
# Moves for real, then sends KILL_SIG to the script after the second swap mv
# (a staged file onto its output; the phase and MANIFEST renames do not count).
cat >"$fake/kill-mv/mv" <<STUB
#!/bin/sh
$(command -v mv) "\$@" || exit
case "\$*" in *.frb_codegen.[0-9]*) ;; *) exit 0 ;; esac
n=\$((\$(cat "\$MV_COUNT" 2>/dev/null || echo 0) + 1))
echo "\$n" >"\$MV_COUNT"
[ "\$n" -eq 2 ] && kill -"\$KILL_SIG" "\$PPID"
exit 0
STUB
# An rm -rf of a backup or tombstone that dies after deleting only phase.
mkdir -p "$fake/partial-rm"
cat >"$fake/partial-rm/rm" <<STUB
#!/bin/sh
for arg; do
  case "\$arg" in *.frb_codegen_backup | *.frb-backup.discard-*) $(command -v rm) -f "\$arg/phase"; exit 1 ;; esac
done
exec $(command -v rm) "\$@"
STUB
chmod +x "$fake"/*/* "$fake/codegen"
stub="$fake/stub:"

sandbox="$(new_sandbox refused)"
expect 1 'rustup missing' 'rustup is not on PATH' "$sandbox" ''
expect 1 'toolchain missing' 'is not installed' "$sandbox" "$fake/no-toolchain:"
for mode in unknown unknown-io; do
  expect 1 "codegen wrote UNKNOWN ($mode)" 'UNKNOWN loader config' "$sandbox" "$stub" FAKE_MODE="$mode"
done
expect 1 'codegen deleted an output' 'did not produce tracked output lib/src/rust/api/wifi.dart' "$sandbox" "$stub" \
  FAKE_MODE=deleted
expect 1 'codegen wrote an empty output' 'empty lib/src/rust/api/tray.dart' "$sandbox" "$stub" FAKE_MODE=empty
expect 1 'fault hook outside test mode' 'only honoured with FRB_CODEGEN_TEST_MODE=1' "$sandbox" "$stub" \
  FAKE_MODE=update FRB_CODEGEN_FAULT=mv:1

# Faults before or during the swap whose restore succeeds: original, exit 1.
for fault in backup:1 backup:2 stage:1 stage:3 stage-verify:2 mv:1 mv:2 mv:4 mv:4,restore-signal:1 \
  mv:2,restore-signal:3; do
  case "$fault" in
    backup:*) needle='could not back up' ;;
    stage:*) needle='could not stage' ;;
    stage-verify:*) needle='does not match the generated one' ;;
    *) needle='restored the tracked files and verified' ;;
  esac
  expect 1 "fault $fault" "$needle" "$sandbox" "$stub" FAKE_MODE=update FRB_CODEGEN_TEST_MODE=1 FRB_CODEGEN_FAULT="$fault"
done
# Signals mid-swap, sent right after the second mv.
for signal in TERM:143 HUP:129 INT:130; do
  rm -f "$scratch/mv-count"
  expect "${signal#*:}" "SIG${signal%:*} during the swap" 'interrupted; restored the tracked files' "$sandbox" \
    "$fake/kill-mv:$stub" FAKE_MODE=update MV_COUNT="$scratch/mv-count" KILL_SIG="${signal%:*}"
  [[ "$(cat "$scratch/mv-count" 2>/dev/null)" == 2 ]] || fail "SIG${signal%:*} during the swap: did not land mid-loop"
done
# A second signal while the first one's restore runs is ignored until it ends.
rm -f "$scratch/mv-count"
expect 143 'SIGTERM during the restore' 'interrupted; restored the tracked files' "$sandbox" "$fake/kill-mv:$stub" \
  FAKE_MODE=update MV_COUNT="$scratch/mv-count" KILL_SIG=TERM FRB_CODEGEN_TEST_MODE=1 FRB_CODEGEN_FAULT=restore-signal:2
# Faults in the restore itself: the backup must survive for recover.sh.
for fault in mv:4,restore:1:"${updated[0]}" mv:4,restore:2:"${updated[1]}" mv:2,verify:1:; do
  before="$(manifest "$sandbox")"
  run_iso "$sandbox" "$stub" FAKE_MODE=update FRB_CODEGEN_TEST_MODE=1 FRB_CODEGEN_FAULT="${fault%:*}"
  expect_recoverable "fault ${fault%:*}" "$sandbox" "$before" "${fault##*:}"
done
# recover.sh checks the whole backup before copying anything.
before="$(manifest "$sandbox")"
run_iso "$sandbox" "$stub" FAKE_MODE=update FRB_CODEGEN_TEST_MODE=1 FRB_CODEGEN_FAULT=mv:4,restore:1
[[ "$status" == 3 ]] || fail "damaged backup: setup exited $status, not 3"
kept="$sandbox/.frb_codegen_backup"
echo 'damage' >>"$kept/files/${updated[1]}"
mixed="$(manifest "$sandbox")"
if bash "$kept/recover.sh" >"$scratch/recover.out" 2>&1; then fail 'damaged backup: recover.sh exited 0'; fi
grep -q 'nothing was copied' "$scratch/recover.out" || fail 'damaged backup: recover.sh did not say it copied nothing'
[[ "$(manifest "$sandbox")" == "$mixed" ]] || fail 'damaged backup: recover.sh copied files anyway'
run_iso "$sandbox" "$stub" FAKE_MODE=update
[[ "$status" == 4 ]] || fail "damaged backup: the next run exited $status, not 4"
grep -q "NOT a usable recovery source" "$scratch/err" || fail 'damaged backup: the next run did not call it unusable'
grep -q "files/${updated[1]} does not match its sha256" "$scratch/err" || fail 'damaged backup: the damage is not named'
if grep -q "bash .*recover.sh" "$scratch/err"; then fail 'damaged backup: the next run still advised recover.sh'; fi
"$git_bin" -C "$sandbox" show ":$package_rel/${updated[1]}" >"$kept/files/${updated[1]}"
bash "$kept/recover.sh" >/dev/null 2>&1 || fail 'damaged backup: recover.sh failed once repaired'
[[ "$(manifest "$sandbox")" == "$before" ]] || fail 'damaged backup: recover.sh did not restore the package'
no_leftovers 'damaged backup (after recover.sh)' "$sandbox"
# A half-deleted backup (recover.sh left, phase gone) is not offered for recovery.
mkdir "$kept" && echo 'exit 1' >"$kept/recover.sh"
run_iso "$sandbox" "$stub" FAKE_MODE=update
[[ "$status" == 4 ]] || fail "backup without phase: exit $status, not 4"
grep -q 'it has no phase file' "$scratch/err" || fail 'backup without phase: not called unusable'
if grep -q "bash .*recover.sh" "$scratch/err"; then fail 'backup without phase: recover.sh still advised'; fi
rm -rf "$kept"
# Tombstones are never recovery sources: the next run deletes them and goes on.
mkdir -p "$sandbox/.frb-backup.discard-12345/files" && echo replace >"$sandbox/.frb-backup.discard-12345/phase"
cp "$sandbox/$generated_rel" "$sandbox/.frb-backup.discard-12345/recover.sh"
expect 1 'leftover tombstone' 'UNKNOWN loader config' "$sandbox" "$stub" FAKE_MODE=unknown
[[ ! -e "$sandbox/.frb-backup.discard-12345" ]] || fail 'leftover tombstone: not removed'
# SIGKILL cannot be trapped: the backup stays, the next run refuses, recover.sh works.
before="$(manifest "$sandbox")"
rm -f "$scratch/mv-count"
run_iso "$sandbox" "$fake/kill-mv:$stub" FAKE_MODE=update MV_COUNT="$scratch/mv-count" KILL_SIG=KILL
[[ "$status" != 0 && -f "$sandbox/.frb_codegen_backup/recover.sh" ]] || fail 'SIGKILL during the swap: no backup left'
run_iso "$sandbox" "$stub" FAKE_MODE=update
[[ "$status" == 4 ]] || fail "SIGKILL during the swap: the next run exited $status, not 4"
grep -q "bash .*recover.sh" "$scratch/err" || fail 'SIGKILL during the swap: the next run printed no recovery'
grep -q 'leftover staged file' "$scratch/err" || fail 'SIGKILL during the swap: staged leftovers not listed'
bash "$sandbox/.frb_codegen_backup/recover.sh" >/dev/null 2>&1 || fail 'SIGKILL during the swap: recover.sh failed'
[[ "$(manifest "$sandbox")" == "$before" ]] || fail 'SIGKILL during the swap: recover.sh did not restore the package'
no_leftovers 'SIGKILL during the swap (after recover.sh)' "$sandbox"
# A backup left before the swap began means the originals were never touched.
mkdir "$sandbox/.frb_codegen_backup" && echo backup >"$sandbox/.frb_codegen_backup/phase"
run_iso "$sandbox" "$stub" FAKE_MODE=update
[[ "$status" == 4 ]] || fail "leftover pre-swap backup: exit $status, not 4"
grep -q 'were not touched' "$scratch/err" || fail 'leftover pre-swap backup: not explained'
# make stops at the failing frb: neither a dependent target nor a later goal runs.
printf 'after: frb\n\ttouch %s/after-ran\nlater:\n\ttouch %s/later-ran\n' "$scratch" "$scratch" >"$scratch/extra.mk"
set +e
env -i PATH="$stub$iso/bin" HOME="$iso/home" CARGO_HOME="$iso/cargo" RUSTUP_HOME="$iso/rustup" TMPDIR="$iso/tmp" \
  FRB_CODEGEN="$fake/codegen" FAKE_MODE=update make -C "$sandbox" -f Makefile -f "$scratch/extra.mk" after later \
  >"$scratch/make.out" 2>&1
make_status=$?
set -e
[[ "$make_status" != 0 ]] || fail 'make: exited 0 although frb failed'
[[ ! -e "$scratch/after-ran" && ! -e "$scratch/later-ran" ]] || fail 'make: went on after frb failed'
grep -q 'make frb: tool/frb_codegen.sh exited 4 (an earlier backup is left' "$scratch/make.out" ||
  fail 'make: did not report exit 4'
rm -rf "$sandbox/.frb_codegen_backup"
before="$(manifest "$sandbox")"
set +e
env -i PATH="$stub$iso/bin" HOME="$iso/home" CARGO_HOME="$iso/cargo" RUSTUP_HOME="$iso/rustup" TMPDIR="$iso/tmp" \
  FRB_CODEGEN="$fake/codegen" FAKE_MODE=update FRB_CODEGEN_TEST_MODE=1 FRB_CODEGEN_FAULT=mv:4,restore:1 \
  make -C "$sandbox" -f Makefile -f "$scratch/extra.mk" after later >"$scratch/make.out" 2>&1
make_status=$?
set -e
[[ "$make_status" != 0 && ! -e "$scratch/after-ran" && ! -e "$scratch/later-ran" ]] || fail 'make: went on after exit 3'
grep -q 'make frb: tool/frb_codegen.sh exited 3 (restore failed' "$scratch/make.out" || fail 'make: did not report exit 3'
bash "$sandbox/.frb_codegen_backup/recover.sh" >/dev/null 2>&1 || fail 'make: recover.sh after exit 3 failed'
[[ "$(manifest "$sandbox")" == "$before" ]] || fail 'make: recover.sh after exit 3 did not restore the package'
sed -i.orig 's/^channel = .*/channel = "0.0.0-frb-codegen-test"/' "$sandbox/$package_rel/rust/rust-toolchain.toml"
rm "$sandbox/$package_rel/rust/rust-toolchain.toml.orig"
expect 1 'pinned channel missing' '0.0.0-frb-codegen-test' "$sandbox" "$stub"

sandbox="$(new_sandbox copy-back)"
run_iso "$sandbox" "$stub" FAKE_MODE=update
if [[ "$status" != 0 ]]; then
  fail "copy-back: exit $status"
  cat "$scratch/err" >&2
fi
{
  "$git_bin" -C "$sandbox" diff --name-only -- "$package_rel"
  "$git_bin" -C "$sandbox" ls-files --others --exclude-standard -- "$package_rel"
} >"$scratch/status"
{
  for relative in "${updated[@]}"; do echo "$package_rel/$relative"; done
  echo "$package_rel/lib/src/rust/api/extra.dart"
} | sort >"$scratch/want-status"
sort -o "$scratch/status" "$scratch/status"
cmp -s "$scratch/want-status" "$scratch/status" || {
  fail 'copy-back: did not copy exactly the changed and new outputs'
  diff "$scratch/want-status" "$scratch/status" >&2 || true
}
grep -q 'rust/src/lib.rs, which is not an output' "$scratch/err" || fail 'copy-back: no warning for a changed non-output'
no_leftovers 'copy-back' "$sandbox"

# A delete that dies partway only ever hits the tombstone, so the next run
# neither finds a backup nor offers a recovery, and clears the tombstone.
sandbox="$(new_sandbox partial-delete)"
run_iso "$sandbox" "$fake/partial-rm:$stub" FAKE_MODE=update
[[ "$status" == 0 ]] || fail "partial delete: exit $status, not 0"
[[ ! -e "$sandbox/.frb_codegen_backup" ]] || fail 'partial delete: the backup itself was half-deleted'
run_iso "$sandbox" "$stub" FAKE_MODE=unknown
[[ "$status" == 1 ]] || fail "partial delete: the next run exited $status, not 1"
if grep -q 'recover.sh' "$scratch/err"; then fail 'partial delete: the next run offered a recovery'; fi
[[ -z "$(find "$sandbox" -maxdepth 1 -name '.frb-backup.discard-*')" ]] || fail 'partial delete: tombstone not cleared'

codegen="${FRB_CODEGEN:-$(command -v flutter_rust_bridge_codegen || true)}"
if [[ -z "$codegen" ]]; then
  skip 'no flutter_rust_bridge_codegen (set FRB_CODEGEN), so the real generation cases do not run'
elif ! command -v rustup >/dev/null 2>&1; then
  skip 'rustup is not installed, so the real generation cases do not run'
else
  sandbox="$(new_sandbox generate)"
  before="$(manifest "$sandbox")"
  run_real "$sandbox" FRB_CODEGEN="$codegen"
  if [[ "$status" != 0 ]]; then
    fail "generation: exit $status"
    cat "$scratch/err" >&2
  fi
  [[ "$(manifest "$sandbox")" == "$before" ]] || fail 'generation: output differs from the committed bindings'
  "$git_bin" -C "$root" show "HEAD:$generated_rel" | cmp -s - "$sandbox/$generated_rel" ||
    fail 'generation: frb_generated.dart differs from HEAD'
  grep -q "stem: 'rust_api'," "$sandbox/$generated_rel" || fail "generation: stem is not 'rust_api'"

  sed "s/stem: 'rust_api'/stem: 'UNKNOWN'/" "$sandbox/$generated_rel" >"$scratch/broken"
  cp "$scratch/broken" "$sandbox/$generated_rel"
  run_real "$sandbox" FRB_CODEGEN="$codegen"
  if [[ "$status" != 0 ]]; then
    fail "repair: exit $status"
    cat "$scratch/err" >&2
  fi
  [[ "$(manifest "$sandbox")" == "$before" ]] || fail 'repair: did not restore the committed bindings'
  no_leftovers 'repair' "$sandbox"
fi

if ((failures > 0)); then
  echo "$failures frb_codegen check(s) failed" >&2
  exit 1
fi
if ((skipped > 0)) && [[ "${FRB_TEST_ALLOW_SKIP:-}" != 1 ]]; then
  echo "frb_codegen tests: $skipped case(s) skipped, not passed (exit 77; FRB_TEST_ALLOW_SKIP=1 accepts skips)" >&2
  exit 77
fi
if ((skipped > 0)); then
  echo "frb_codegen tests passed with $skipped skip(s) (FRB_TEST_ALLOW_SKIP=1)"
else
  echo 'frb_codegen tests passed'
fi
