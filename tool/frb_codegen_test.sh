#!/usr/bin/env bash
# Tests tool/frb_codegen.sh in scratch git copies of the committed rust_api package.
# Stub rustup, cargo and codegen cover the refusals and the copy-back without a
# toolchain. The real-codegen cases need rustup and flutter_rust_bridge_codegen
# (PATH or FRB_CODEGEN); when they cannot run the script exits 77 (SKIP) unless
# FRB_TEST_ALLOW_SKIP=1.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
root="$(cd "$script_dir/.." && pwd -P)"
git_bin="${GIT:-git}"
git_path="$(command -v "$git_bin")" || { echo "frb_codegen_test: $git_bin is not on PATH; set GIT" >&2; exit 1; }
scratch="$(mktemp -d "${TMPDIR:-/tmp}/frb_codegen_test.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT

failures=0
skipped=0
package_rel='plugins/rust_api'
generated_rel="$package_rel/lib/src/rust/frb_generated.dart"
pinned="$(sed -nE 's/^flutter_rust_bridge[[:space:]]*=[[:space:]]*"=?([^"]+)".*/\1/p' "$root/$package_rel/rust/Cargo.toml")"
channel="$(sed -nE 's/^[[:space:]]*channel[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' "$root/$package_rel/rust/rust-toolchain.toml" | head -n 1)"

fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

skip() {
  echo "SKIP: $*"
  skipped=$((skipped + 1))
}

new_sandbox() {
  local sandbox="$scratch/$1"
  mkdir -p "$sandbox/tool" "$sandbox/.dart_tool"
  "$git_bin" -C "$root" archive HEAD -- "$package_rel" pubspec.yaml analysis_options.yaml lint_options.yaml |
    tar -x -C "$sandbox"
  cp "$script_dir/frb_codegen.sh" "$sandbox/tool/"
  cp "$root/.dart_tool/package_config.json" "$sandbox/.dart_tool/"
  "$git_bin" -C "$sandbox" init -q
  "$git_bin" -C "$sandbox" add -A
  echo "$sandbox"
}

manifest() {
  (cd "$1/$package_rel" && find . -type f -print0 | sort -z | xargs -0 shasum -a 256)
}

run_script() {
  local sandbox="$1"
  shift
  set +e
  (cd / && env "$@" bash "$sandbox/tool/frb_codegen.sh") >"$scratch/out" 2>"$scratch/err"
  status=$?
  set -e
  return $status
}

expect_refused() {
  local name="$1" needle="$2" sandbox="$3"
  shift 3
  local before
  before="$(manifest "$sandbox")"
  if run_script "$sandbox" "$@"; then
    fail "$name: should exit non-zero"
  elif ! grep -q -- "$needle" "$scratch/err"; then
    fail "$name: stderr does not say '$needle'"
    cat "$scratch/err" >&2
  fi
  [[ "$(manifest "$sandbox")" == "$before" ]] || fail "$name: tracked files changed"
  if grep -q "UNKNOWN" "$sandbox/$generated_rel"; then fail "$name: UNKNOWN was written"; fi
  if [[ -n "$(find "$sandbox" -name '*.frb_codegen.*')" ]]; then fail "$name: left staged files"; fi
}

# Stubs. stub/rustup lists the pinned channel, stub/cargo answers the metadata
# preflight, and the stub codegen edits the copy as FAKE_MODE says.
fake="$scratch/fake"
mkdir -p "$fake/no-rustup" "$fake/no-toolchain" "$fake/stub" "$fake/kill-mv"
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
# Moves for real, then sends TERM to the script after the second move.
cat >"$fake/kill-mv/mv" <<'STUB'
#!/bin/sh
/bin/mv "$@" || exit
n=$(($(cat "$MV_COUNT" 2>/dev/null || echo 0) + 1))
echo "$n" >"$MV_COUNT"
[ "$n" -eq 2 ] && kill -TERM "$PPID"
exit 0
STUB
chmod +x "$fake"/*/* "$fake/codegen"
base_path="$(dirname "$git_path"):/usr/bin:/bin"
stub_path="$fake/stub:$base_path"

sandbox="$(new_sandbox refused)"
expect_refused 'rustup missing' 'rustup is not on PATH' "$sandbox" \
  PATH="$fake/no-rustup:$base_path" FRB_CODEGEN="$fake/codegen"
expect_refused 'toolchain missing' 'is not installed' "$sandbox" \
  PATH="$fake/no-toolchain:$base_path" FRB_CODEGEN="$fake/codegen"
for mode in unknown unknown-io; do
  expect_refused "codegen wrote UNKNOWN ($mode)" 'UNKNOWN loader config' "$sandbox" \
    PATH="$stub_path" FRB_CODEGEN="$fake/codegen" FAKE_MODE="$mode"
done
expect_refused 'codegen deleted an output' 'did not produce tracked output lib/src/rust/api/wifi.dart' "$sandbox" \
  PATH="$stub_path" FRB_CODEGEN="$fake/codegen" FAKE_MODE=deleted
expect_refused 'codegen wrote an empty output' 'empty lib/src/rust/api/tray.dart' "$sandbox" \
  PATH="$stub_path" FRB_CODEGEN="$fake/codegen" FAKE_MODE=empty
expect_refused 'TERM during the replacement' 'interrupted; restored' "$sandbox" \
  PATH="$fake/kill-mv:$stub_path" FRB_CODEGEN="$fake/codegen" FAKE_MODE=update MV_COUNT="$scratch/mv-count"
[[ "${status:-0}" -eq 143 ]] || fail "TERM during the replacement: exit $status, not 143"
[[ "$(cat "$scratch/mv-count" 2>/dev/null)" == 2 ]] || fail 'TERM during the replacement: the kill did not land mid-loop'
sed -i.orig 's/^channel = .*/channel = "0.0.0-frb-codegen-test"/' "$sandbox/$package_rel/rust/rust-toolchain.toml"
rm "$sandbox/$package_rel/rust/rust-toolchain.toml.orig"
expect_refused 'pinned channel missing' '0.0.0-frb-codegen-test' "$sandbox" \
  PATH="$stub_path" FRB_CODEGEN="$fake/codegen"

sandbox="$(new_sandbox copy-back)"
if ! run_script "$sandbox" PATH="$stub_path" FRB_CODEGEN="$fake/codegen" FAKE_MODE=update; then
  fail 'copy-back: exited non-zero'
  cat "$scratch/err" >&2
fi
{
  "$git_bin" -C "$sandbox" diff --name-only -- "$package_rel"
  "$git_bin" -C "$sandbox" ls-files --others --exclude-standard -- "$package_rel"
} >"$scratch/status"
printf '%s\n' \
  "$package_rel/lib/src/rust/api/charset.dart" \
  "$package_rel/lib/src/rust/frb_generated.dart" \
  "$package_rel/rust/src/frb_generated.rs" \
  "$package_rel/lib/src/rust/api/extra.dart" >"$scratch/want-status"
cmp -s "$scratch/want-status" "$scratch/status" || {
  fail 'copy-back: did not copy exactly the changed and new outputs'
  diff "$scratch/want-status" "$scratch/status" >&2 || true
}
grep -q 'rust/src/lib.rs, which is not an output' "$scratch/err" || fail 'copy-back: no warning for a changed non-output'

codegen="${FRB_CODEGEN:-$(command -v flutter_rust_bridge_codegen || true)}"
if [[ -z "$codegen" ]]; then
  skip 'no flutter_rust_bridge_codegen (set FRB_CODEGEN), so the real generation cases do not run'
elif ! command -v rustup >/dev/null 2>&1; then
  skip 'rustup is not installed, so the real generation cases do not run'
else
  sandbox="$(new_sandbox generate)"
  before="$(manifest "$sandbox")"
  if ! run_script "$sandbox" FRB_CODEGEN="$codegen"; then
    fail 'generation: exited non-zero'
    cat "$scratch/err" >&2
  fi
  [[ "$(manifest "$sandbox")" == "$before" ]] || fail 'generation: output differs from the committed bindings'
  "$git_bin" -C "$root" show "HEAD:$generated_rel" | cmp -s - "$sandbox/$generated_rel" ||
    fail 'generation: frb_generated.dart differs from HEAD'
  grep -q "stem: 'rust_api'," "$sandbox/$generated_rel" || fail "generation: stem is not 'rust_api'"

  sed "s/stem: 'rust_api'/stem: 'UNKNOWN'/" "$sandbox/$generated_rel" >"$scratch/broken"
  cp "$scratch/broken" "$sandbox/$generated_rel"
  if ! run_script "$sandbox" FRB_CODEGEN="$codegen"; then
    fail 'repair: exited non-zero'
    cat "$scratch/err" >&2
  fi
  [[ "$(manifest "$sandbox")" == "$before" ]] || fail 'repair: did not restore the committed bindings'
  if [[ -n "$(find "$sandbox" -name '*.frb_codegen.*')" ]]; then fail 'repair: left staged files'; fi
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
