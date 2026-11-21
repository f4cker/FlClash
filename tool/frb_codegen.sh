#!/usr/bin/env bash
# Regenerates the flutter_rust_bridge bindings of plugins/rust_api.
#
# The codegen reads the default loader stem from `cargo metadata` and silently
# writes 'UNKNOWN' when cargo cannot run (9867150c). So this pins cargo to the
# channel in rust/rust-toolchain.toml, generates into a scratch copy, checks the
# stem against the Cargo [lib] name, and only then swaps the changed files in.
#
# FRB_CODEGEN overrides the flutter_rust_bridge_codegen binary, GIT the git one.
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
git_bin="${GIT:-git}"
command -v "$git_bin" >/dev/null 2>&1 || die "$git_bin is not on PATH; set GIT"

# What the codegen writes (flutter_rust_bridge.yaml dart_output, plus the Rust
# glue). Nothing else is copied back, so .dart_tool, Cargo.lock and the like stay.
output_dirs=(lib/src/rust)
output_files=(rust/src/frb_generated.rs)
tracked=()
while IFS= read -r -d '' file; do tracked+=("$file"); done < <(
  "$git_bin" -C "$package" ls-files -z -- "${output_dirs[@]}" "${output_files[@]}"
)
[[ ${#tracked[@]} -gt 0 ]] || die "git lists no tracked bindings under $package/{${output_dirs[*]},${output_files[*]}}"

scratch="$(mktemp -d "${TMPDIR:-/tmp}/frb_codegen.XXXXXX")"
staged=()
cleanup() {
  local file
  for file in ${staged[@]+"${staged[@]}"}; do rm -f "$file"; done
  rm -rf "$scratch"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

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

missing=()
for relative in "${tracked[@]}"; do
  if [[ ! -f "$copy/$relative" ]]; then missing+=("$relative"); fi
done
[[ ${#missing[@]} -eq 0 ]] ||
  die "codegen did not produce tracked output ${missing[*]} (git rm it first if that is intended); tracked files are unchanged"

outputs=("${tracked[@]}")
is_listed() {
  local needle="$1" item
  shift
  for item in "$@"; do [[ "$item" == "$needle" ]] && return 0; done
  return 1
}
while IFS= read -r -d '' file; do
  relative="${file#"$copy"/}"
  is_listed "$relative" "${tracked[@]}" || outputs+=("$relative")
done < <(
  for dir in "${output_dirs[@]}"; do [[ ! -d "$copy/$dir" ]] || find "$copy/$dir" -type f -print0; done
  for file in "${output_files[@]}"; do [[ ! -f "$copy/$file" ]] || printf '%s\0' "$copy/$file"; done
)

for relative in "${outputs[@]}"; do
  [[ -s "$copy/$relative" ]] || die "codegen wrote an empty $relative; tracked files are unchanged"
  if [[ "$relative" == *.dart ]] && grep -qE "(stem|ioDirectory): *'UNKNOWN'" "$copy/$relative"; then
    die "$relative has an UNKNOWN loader config (cargo metadata failed inside the codegen); tracked files are unchanged"
  fi
done
generated="$copy/lib/src/rust/frb_generated.dart"
[[ -f "$generated" ]] || die "codegen wrote no lib/src/rust/frb_generated.dart"
stems="$(sed -nE "s/^[[:space:]]*stem: '([^']*)',?[[:space:]]*$/\1/p" "$generated")"
[[ "$stems" == "$lib_name" ]] ||
  die "generated stem '${stems//$'\n'/,}' is not the Cargo [lib] name '$lib_name'; tracked files are unchanged"

while IFS= read -r -d '' relative; do
  if ! is_listed "$relative" "${outputs[@]}" && [[ -f "$copy/$relative" ]] && ! cmp -s "$copy/$relative" "$package/$relative"; then
    echo "frb_codegen: warning: codegen also changed $relative, which is not an output; left as is" >&2
  fi
done < <("$git_bin" -C "$package" ls-files -z)

changed=()
for relative in "${outputs[@]}"; do
  if ! cmp -s "$copy/$relative" "$package/$relative"; then changed+=("$relative"); fi
done
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

# Every changed file goes back to its backup (or away, if it is new), whether
# or not its mv ran yet, so a failure or INT/TERM mid-loop leaves no mix.
restore() {
  local relative
  for relative in "${changed[@]}"; do
    if [[ -f "$backup/$relative" ]]; then
      cp -p "$backup/$relative" "$package/$relative"
    else
      rm -f "$package/$relative"
    fi
  done
}
interrupted() {
  trap '' INT TERM
  restore
  echo "frb_codegen: interrupted; restored the tracked files" >&2
  exit "$1"
}
trap 'interrupted 130' INT
trap 'interrupted 143' TERM
for index in "${!changed[@]}"; do
  if ! mv -f "${staged[$index]}" "$package/${changed[$index]}"; then
    trap '' INT TERM
    restore
    die "could not replace ${changed[$index]}; restored the tracked files"
  fi
done
trap 'exit 130' INT
trap 'exit 143' TERM
staged=()

printf 'frb_codegen: updated %s\n' "${changed[@]}"
echo "frb_codegen: stem '$lib_name', toolchain $channel"
