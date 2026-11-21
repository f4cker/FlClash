#!/usr/bin/env bash
# Tests tool/frb_codegen.sh in a scratch copy of the committed rust_api package.
# The real-codegen cases need flutter_rust_bridge_codegen on PATH or FRB_CODEGEN.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
root="$(cd "$script_dir/.." && pwd -P)"
scratch="$(mktemp -d "${TMPDIR:-/tmp}/frb_codegen_test.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT

failures=0
generated_rel='plugins/rust_api/lib/src/rust/frb_generated.dart'
pinned="$(sed -nE 's/^flutter_rust_bridge[[:space:]]*=[[:space:]]*"=?([^"]+)".*/\1/p' "$root/plugins/rust_api/rust/Cargo.toml")"

fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

new_sandbox() {
  local sandbox="$scratch/$1"
  mkdir -p "$sandbox/tool" "$sandbox/.dart_tool"
  /usr/bin/git -C "$root" archive HEAD -- plugins/rust_api pubspec.yaml analysis_options.yaml lint_options.yaml |
    tar -x -C "$sandbox"
  cp "$script_dir/frb_codegen.sh" "$sandbox/tool/"
  cp "$root/.dart_tool/package_config.json" "$sandbox/.dart_tool/"
  echo "$sandbox"
}

manifest() {
  (cd "$1/plugins/rust_api" && find . -type f -print0 | sort -z | xargs -0 shasum -a 256)
}

run_script() {
  local sandbox="$1"
  shift
  set +e
  (cd / && env "$@" bash "$sandbox/tool/frb_codegen.sh") >"$scratch/out" 2>"$scratch/err"
  local status=$?
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
  elif ! grep -q "$needle" "$scratch/err"; then
    fail "$name: stderr does not say '$needle'"
    cat "$scratch/err" >&2
  fi
  [[ "$(manifest "$sandbox")" == "$before" ]] || fail "$name: tracked files changed"
  if grep -q "UNKNOWN" "$sandbox/$generated_rel"; then fail "$name: UNKNOWN was written"; fi
  if [[ -n "$(find "$sandbox" -name '*.frb_codegen.*')" ]]; then fail "$name: left staged files"; fi
}

fake_bin="$scratch/fake-bin"
mkdir -p "$fake_bin/no-rustup" "$fake_bin/no-toolchain"
cat >"$fake_bin/no-toolchain/rustup" <<'EOF'
#!/bin/sh
[ "$1" = toolchain ] && { echo 'no installed toolchains'; exit 0; }
echo 'error: toolchain is not installed' >&2
exit 1
EOF
cat >"$fake_bin/unknown-codegen" <<EOF
#!/bin/sh
if [ "\$1" = --version ]; then echo 'flutter_rust_bridge_codegen $pinned'; exit 0; fi
file=lib/src/rust/frb_generated.dart
sed "s/stem: '[^']*'/stem: 'UNKNOWN'/" "\$file" >"\$file.tmp" && mv "\$file.tmp" "\$file"
EOF
chmod +x "$fake_bin/no-toolchain/rustup" "$fake_bin/unknown-codegen"

sandbox="$(new_sandbox refused)"
expect_refused 'rustup missing' 'rustup is not on PATH' "$sandbox" \
  PATH="$fake_bin/no-rustup:/usr/bin:/bin" FRB_CODEGEN="$fake_bin/unknown-codegen"
expect_refused 'toolchain missing' 'is not installed' "$sandbox" \
  PATH="$fake_bin/no-toolchain:/usr/bin:/bin" FRB_CODEGEN="$fake_bin/unknown-codegen"
if command -v rustup >/dev/null 2>&1; then
  expect_refused 'codegen wrote UNKNOWN' 'UNKNOWN' "$sandbox" \
    FRB_CODEGEN="$fake_bin/unknown-codegen" RUSTUP_TOOLCHAIN=none
  sed -i.orig 's/^channel = .*/channel = "0.0.0-frb-codegen-test"/' "$sandbox/plugins/rust_api/rust/rust-toolchain.toml"
  rm "$sandbox/plugins/rust_api/rust/rust-toolchain.toml.orig"
  expect_refused 'pinned channel missing' '0.0.0-frb-codegen-test' "$sandbox" \
    FRB_CODEGEN="$fake_bin/unknown-codegen"
else
  echo 'SKIP: rustup is not installed, so the real-toolchain refusals do not run'
fi

codegen="${FRB_CODEGEN:-$(command -v flutter_rust_bridge_codegen || true)}"
if [[ -z "$codegen" ]]; then
  echo 'SKIP: no flutter_rust_bridge_codegen (set FRB_CODEGEN), so the generation cases do not run'
else
  sandbox="$(new_sandbox generate)"
  before="$(manifest "$sandbox")"
  if ! run_script "$sandbox" FRB_CODEGEN="$codegen"; then
    fail 'generation: exited non-zero'
    cat "$scratch/err" >&2
  fi
  [[ "$(manifest "$sandbox")" == "$before" ]] || fail 'generation: output differs from the committed bindings'
  /usr/bin/git -C "$root" show "HEAD:$generated_rel" | cmp -s - "$sandbox/$generated_rel" ||
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
echo 'frb_codegen tests passed'
