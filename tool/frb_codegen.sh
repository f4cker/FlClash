#!/usr/bin/env bash
# Regenerates the flutter_rust_bridge bindings of plugins/rust_api.
#
# The codegen reads the default loader stem from `cargo metadata` and silently
# writes 'UNKNOWN' when cargo cannot run (9867150c). So this pins cargo to the
# channel in rust/rust-toolchain.toml, generates into a scratch copy, checks
# every output, and only then swaps the changed outputs in.
#
# The swap backs the originals up to $root/.frb_codegen_backup first. A failing
# command or INT/TERM/HUP during it restores every file and checks each against
# its backup sha256; the backup goes only once a swap or restore is complete
# and verified. If the restore fails, the backup stays, recover.sh in it holds
# the exact commands, and the exit is 3. Not covered: SIGKILL, power loss, a
# kernel panic, or a disk filling up in a way cp and sha256 cannot see. Those
# leave the backup behind, so every run first refuses (exit 4) while one exists
# and prints its recovery steps.
#
# Exit: 0 done; 1 refused or failed, tracked files as they were; 3 restore
# failed, recover by hand; 4 earlier backup left; 129/130/143 signal, restored.
# FRB_CODEGEN overrides the codegen binary, GIT the git one. FRB_CODEGEN_FAULT
# (stage:n,...) injects failures, and only with FRB_CODEGEN_TEST_MODE=1.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
package="$root/plugins/rust_api"
crate="$package/rust"
toolchain_file="$crate/rust-toolchain.toml"
codegen="${FRB_CODEGEN:-flutter_rust_bridge_codegen}"
backup="$root/.frb_codegen_backup"

die() {
  echo "frb_codegen: $*" >&2
  exit 1
}

if [[ -e "$backup" ]]; then
  {
    echo "frb_codegen: an earlier run left $backup; refusing to run until it is resolved."
    left_phase="$(cat "$backup/phase" 2>/dev/null || true)"
    if [[ "$left_phase" == backup || "$left_phase" == done ]]; then
      if [[ "$left_phase" == backup ]]; then
        echo "It stopped before replacing anything, so the tracked files were not touched. Remove it:"
      else
        echo "It finished replacing the bindings but could not remove it. Remove it:"
      fi
      printf '  rm -rf %q\n' "$backup"
    elif [[ -f "$backup/recover.sh" ]]; then
      echo "It stopped while replacing the bindings. Restore them with:"
      printf '  bash %q\n' "$backup/recover.sh"
      echo "which runs:"
      sed 's/^/    /' "$backup/recover.sh"
    else
      echo "It has no recover.sh; copy $backup/files/* back over $package by hand, then remove it."
    fi
    find "$package" -name '*.frb_codegen.*' -type f -exec printf '  leftover staged file (delete it): %s\n' {} \;
  } >&2
  exit 4
fi

fault_stages=()
fault_counts=()
fault_seen=()
if [[ -n "${FRB_CODEGEN_FAULT:-}" ]]; then
  [[ "${FRB_CODEGEN_TEST_MODE:-}" == 1 ]] || die "FRB_CODEGEN_FAULT is only honoured with FRB_CODEGEN_TEST_MODE=1"
  IFS=, read -r -a faults <<<"$FRB_CODEGEN_FAULT"
  for spec in "${faults[@]}"; do
    [[ "$spec" =~ ^(backup|mv|restore|verify):([0-9]+)$ ]] || die "bad FRB_CODEGEN_FAULT entry '$spec'"
    fault_stages+=("${BASH_REMATCH[1]}")
    fault_counts+=("${BASH_REMATCH[2]}")
    fault_seen+=(0)
  done
fi
# True when the next attempt at this stage is the one FRB_CODEGEN_FAULT names.
inject() {
  local index hit=1
  for index in ${fault_stages[@]+"${!fault_stages[@]}"}; do
    [[ "${fault_stages[$index]}" == "$1" ]] || continue
    fault_seen[$index]=$((fault_seen[index] + 1))
    if [[ "${fault_seen[$index]}" == "${fault_counts[$index]}" ]]; then hit=0; fi
  done
  return $hit
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
if command -v sha256sum >/dev/null 2>&1; then sha_tool=(sha256sum); else sha_tool=(shasum -a 256); fi
command -v "${sha_tool[0]}" >/dev/null 2>&1 || die "neither sha256sum nor shasum is on PATH"
sha256() { "${sha_tool[@]}" <"$1" | awk '{ print $1 }'; }

# What the codegen writes (flutter_rust_bridge.yaml dart_output, plus the Rust
# glue). Nothing else is copied back, so .dart_tool, Cargo.lock and the like stay.
output_dirs=(lib/src/rust)
output_files=(rust/src/frb_generated.rs)
tracked=()
while IFS= read -r -d '' file; do tracked+=("$file"); done < <(
  "$git_bin" -C "$package" ls-files -z -- "${output_dirs[@]}" "${output_files[@]}"
)
[[ ${#tracked[@]} -gt 0 ]] || die "git lists no tracked bindings under $package/{${output_dirs[*]},${output_files[*]}}"

# phase: none, then backup (originals untouched), replace (swap running), and
# done/restored/failed once settled. The EXIT trap acts on it.
phase=none
scratch="$(mktemp -d "${TMPDIR:-/tmp}/frb_codegen.XXXXXX")"
staged=()
cleanup() {
  local file
  set +e
  if [[ "$phase" == replace ]]; then restore_and_exit 'unexpected exit during the replacement' 1; fi
  for file in ${staged[@]+"${staged[@]}"}; do rm -f "$file"; done
  if [[ "$phase" == backup ]]; then rm -rf "$backup"; fi
  rm -rf "$scratch"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

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

# Backup: files/<path> per original, SHA256SUMS of the originals, and
# recover.sh, all written before the first mv.
mkdir "$backup" || die "could not create $backup; tracked files are unchanged"
phase=backup
echo backup >"$backup/phase"
hashes=()
for relative in "${changed[@]}"; do
  if [[ -f "$package/$relative" ]]; then
    mkdir -p "$(dirname "$backup/files/$relative")"
    if inject backup || ! cp -p "$package/$relative" "$backup/files/$relative"; then
      die "could not back up $relative; tracked files are unchanged"
    fi
    hash="$(sha256 "$package/$relative")"
    [[ "$(sha256 "$backup/files/$relative")" == "$hash" ]] ||
      die "the backup of $relative does not match it; tracked files are unchanged"
    printf '%s  %s\n' "$hash" "$relative" >>"$backup/SHA256SUMS"
  else
    hash=''
  fi
  hashes+=("$hash")
  staged+=("$package/$relative.frb_codegen.$$")
done
{
  echo '#!/usr/bin/env bash'
  echo "# Written by tool/frb_codegen.sh: puts $package back as it was before the run."
  echo 'set -euo pipefail'
  for index in "${!changed[@]}"; do
    if [[ -n "${hashes[$index]}" ]]; then
      printf 'cp -p %q %q\n' "$backup/files/${changed[$index]}" "$package/${changed[$index]}"
    else
      printf 'rm -f %q\n' "$package/${changed[$index]}"
    fi
    printf 'rm -f %q\n' "${staged[$index]}"
  done
  if [[ -f "$backup/SHA256SUMS" ]]; then
    printf 'cd %q && %s -c %q\n' "$package" "${sha_tool[*]}" "$backup/SHA256SUMS"
  fi
  for index in "${!changed[@]}"; do
    if [[ -z "${hashes[$index]}" ]]; then printf 'test ! -e %q\n' "$package/${changed[$index]}"; fi
  done
  printf 'rm -rf %q\n' "$backup"
  echo "echo 'frb_codegen: restored and verified the bindings'"
} >"$backup/recover.sh"

for index in "${!changed[@]}"; do
  mkdir -p "$(dirname "$package/${changed[$index]}")"
  cp -p "$copy/${changed[$index]}" "${staged[$index]}"
done

# Puts every changed file back (or removes it, if new), whether or not its mv
# ran, tries all of them, then checks each by sha256. Runs with errexit off.
restore_and_exit() {
  local reason="$1" code="$2" index relative failures=()
  trap '' INT TERM HUP
  set +e
  for index in "${!changed[@]}"; do
    relative="${changed[$index]}"
    if [[ -z "${hashes[$index]}" ]]; then
      rm -f "$package/$relative" || failures+=("could not remove new file $relative")
    elif inject restore || ! cp -p "$backup/files/$relative" "$package/$relative"; then
      failures+=("could not copy $relative back")
    fi
  done
  for index in "${!changed[@]}"; do
    relative="${changed[$index]}"
    if [[ -z "${hashes[$index]}" ]]; then
      [[ ! -e "$package/$relative" ]] || failures+=("new file $relative is still there")
    elif inject verify || [[ "$(sha256 "$package/$relative")" != "${hashes[$index]}" ]]; then
      failures+=("$relative does not match its backup")
    fi
  done
  for relative in ${staged[@]+"${staged[@]}"}; do rm -f "$relative"; done
  staged=()
  if [[ ${#failures[@]} -eq 0 ]]; then
    phase=restored
    rm -rf "$backup"
    echo "frb_codegen: $reason; restored the tracked files and verified them" >&2
    exit "$code"
  fi
  phase=failed
  {
    echo "frb_codegen: $reason, and the restore FAILED; the bindings may be a mix of old and new:"
    printf '  - %s\n' "${failures[@]}"
    echo "The originals are kept in $backup (files/, checked by SHA256SUMS). Restore them with:"
    printf '  bash %q\n' "$backup/recover.sh"
    echo "which runs:"
    sed 's/^/    /' "$backup/recover.sh"
  } >&2
  exit 3
}

echo replace >"$backup/phase"
phase=replace
trap 'restore_and_exit interrupted 130' INT
trap 'restore_and_exit interrupted 143' TERM
trap 'restore_and_exit interrupted 129' HUP
for index in "${!changed[@]}"; do
  if inject mv || ! mv -f "${staged[$index]}" "$package/${changed[$index]}"; then
    restore_and_exit "could not replace ${changed[$index]}" 1
  fi
done
phase=done
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP
staged=()
echo done >"$backup/phase" || true
rm -rf "$backup" || echo "frb_codegen: warning: could not remove $backup after a complete swap; remove it by hand" >&2

printf 'frb_codegen: updated %s\n' "${changed[@]}"
echo "frb_codegen: stem '$lib_name', toolchain $channel"
