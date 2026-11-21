#!/usr/bin/env bash
# Regenerates the flutter_rust_bridge bindings of plugins/rust_api.
#
# The codegen reads the default loader stem from `cargo metadata` and silently
# writes 'UNKNOWN' when cargo cannot run (9867150c). So this pins cargo to the
# channel in rust/rust-toolchain.toml, generates into a scratch copy, checks the
# stem against the Cargo [lib] name, and only then swaps the changed files in.
#
# FRB_CODEGEN overrides the flutter_rust_bridge_codegen binary.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
package="$root/plugins/rust_api"
crate="$package/rust"
toolchain_file="$crate/rust-toolchain.toml"
codegen="${FRB_CODEGEN:-flutter_rust_bridge_codegen}"

die() {
  echo "frb_codegen: $*" >&2
  exit 1
}

[[ -f "$toolchain_file" ]] || die "missing $toolchain_file"
channel="$(sed -nE 's/^[[:space:]]*channel[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' "$toolchain_file" | head -n 1)"
[[ -n "$channel" ]] || die "no channel in $toolchain_file"

lib_name="$(awk '
  /^\[/ { in_lib = ($0 ~ /^\[lib\][[:space:]]*$/) }
  in_lib && match($0, /^[[:space:]]*name[[:space:]]*=[[:space:]]*"[^"]+"/) {
    value = substr($0, RSTART, RLENGTH); sub(/^[^"]*"/, "", value); sub(/"$/, "", value)
    print value; exit
  }' "$crate/Cargo.toml")"
[[ -n "$lib_name" ]] || die "no [lib] name in $crate/Cargo.toml"
lib_name="${lib_name//-/_}"

command -v rustup >/dev/null 2>&1 ||
  die "rustup is not on PATH; install rustup, then: rustup toolchain install $channel"
installed="$(env -u RUSTUP_TOOLCHAIN rustup toolchain list 2>/dev/null || true)"
if ! awk -v c="$channel" '$1 == c || index($1, c "-") == 1 { found = 1 } END { exit !found }' <<<"$installed"; then
  die "Rust toolchain $channel (from $toolchain_file) is not installed; run: rustup toolchain install $channel"
fi

command -v "$codegen" >/dev/null 2>&1 ||
  die "$codegen not found; install flutter_rust_bridge_codegen or set FRB_CODEGEN"
want_version="$(sed -nE 's/^flutter_rust_bridge[[:space:]]*=[[:space:]]*"=?([^"]+)".*/\1/p' "$crate/Cargo.toml" | head -n 1)"
have_version="$("$codegen" --version 2>/dev/null | awk '{ print $NF }')"
[[ -z "$want_version" || "$have_version" == "$want_version" ]] ||
  die "$codegen is $have_version but rust/Cargo.toml pins flutter_rust_bridge $want_version"

[[ -f "$root/.dart_tool/package_config.json" ]] ||
  die "run 'flutter pub get' first: dart fix in the codegen needs $root/.dart_tool/package_config.json"

export RUSTUP_TOOLCHAIN="$channel"
export RUSTUP_AUTO_INSTALL=0
export CARGO_NET_OFFLINE="${CARGO_NET_OFFLINE:-true}"

metadata="$(cd "$package" && cargo metadata --format-version 1 --no-deps --manifest-path "$crate/Cargo.toml" 2>&1)" ||
  die "cargo metadata failed with RUSTUP_TOOLCHAIN=$channel:"$'\n'"$metadata"
grep -q "\"name\":\"$lib_name\"" <<<"$metadata" ||
  die "cargo metadata does not list the [lib] target $lib_name"

command -v rsync >/dev/null 2>&1 || die "rsync is not on PATH"
scratch="$(mktemp -d "${TMPDIR:-/tmp}/frb_codegen.XXXXXX")"
staged=()
cleanup() {
  local file
  for file in ${staged[@]+"${staged[@]}"}; do rm -f "$file"; done
  rm -rf "$scratch"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

mirror="$scratch/repo"
mkdir -p "$mirror/.dart_tool" "$mirror/plugins"
cp "$root/.dart_tool/package_config.json" "$mirror/.dart_tool/"
for file in pubspec.yaml pubspec.lock analysis_options.yaml lint_options.yaml; do
  if [[ -f "$root/$file" ]]; then cp "$root/$file" "$mirror/"; fi
done
rsync -a --exclude '/rust/target/' --exclude '/.dart_tool/' --exclude '/build/' "$package/" "$mirror/plugins/rust_api/"
copy="$mirror/plugins/rust_api"

(cd "$copy" && CARGO_TARGET_DIR="$scratch/target" "$codegen" generate) ||
  die "$codegen generate failed; tracked files are unchanged"

generated="$copy/lib/src/rust/frb_generated.dart"
[[ -f "$generated" ]] || die "codegen wrote no lib/src/rust/frb_generated.dart"
stems="$(sed -nE "s/^[[:space:]]*stem: '([^']*)',?[[:space:]]*$/\1/p" "$generated")"
if grep -q "UNKNOWN" <<<"$stems" || grep -qE "ioDirectory: 'UNKNOWN'" "$generated"; then
  die "generated loader config is UNKNOWN (cargo metadata failed inside the codegen); tracked files are unchanged"
fi
[[ "$stems" == "$lib_name" ]] ||
  die "generated stem '${stems//$'\n'/,}' is not the Cargo [lib] name '$lib_name'; tracked files are unchanged"

changed=()
while IFS= read -r -d '' file; do
  relative="${file#"$copy"/}"
  if ! cmp -s "$file" "$package/$relative"; then changed+=("$relative"); fi
done < <(find "$copy" -type f -not -path "$copy/rust/target/*" -print0)

if [[ ${#changed[@]} -eq 0 ]]; then
  echo "frb_codegen: bindings are up to date (stem '$lib_name', toolchain $channel)"
  exit 0
fi

backup="$scratch/backup"
for relative in "${changed[@]}"; do
  if [[ -f "$package/$relative" ]]; then
    mkdir -p "$(dirname "$backup/$relative")"
    cp -p "$package/$relative" "$backup/$relative"
  fi
done
for relative in "${changed[@]}"; do
  mkdir -p "$(dirname "$package/$relative")"
  stage="$package/$relative.frb_codegen.$$"
  staged+=("$stage")
  cp -p "$copy/$relative" "$stage"
done

moved=()
restore() {
  local relative
  for relative in ${moved[@]+"${moved[@]}"}; do
    if [[ -f "$backup/$relative" ]]; then
      cp -p "$backup/$relative" "$package/$relative"
    else
      rm -f "$package/$relative"
    fi
  done
}
for index in "${!changed[@]}"; do
  if ! mv -f "${staged[$index]}" "$package/${changed[$index]}"; then
    restore
    die "could not replace ${changed[$index]}; restored the tracked files"
  fi
  moved+=("${changed[$index]}")
done
staged=()

printf 'frb_codegen: updated %s\n' "${changed[@]}"
echo "frb_codegen: stem '$lib_name', toolchain $channel"
