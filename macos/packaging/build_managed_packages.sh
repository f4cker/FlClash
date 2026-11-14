#!/bin/bash
set -euo pipefail
[[ "$EUID" != 0 && "$#" == 4 ]] || exit 64
# Native-load evidence is artifact-bound, never an environment assertion.
source_dir="$(cd "$(/usr/bin/dirname "$0")" && pwd)"
app="$(cd "$1" && pwd -P)"
[[ "$app" == */Flash.app && ! -e "$2" && ! -L "$2" ]] || exit 78
output_parent="$(cd "$(/usr/bin/dirname "$2")" && pwd -P)"
output="$output_parent/$(/usr/bin/basename "$2")"
[[ "$output" != "$app/"* && "$app" != "$output/"* ]] || exit 78
evidence="$3"
metadata="$4"
[[ "$evidence" == /* && "$metadata" == /* ]] || exit 78
verify_evidence() {
  /usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C /usr/bin/python3 -I -S -B \
    "$source_dir/qualify_native_loads.py" --verify-evidence --app "$app" \
    --evidence "$evidence" --build-metadata "$metadata" "$@"
}
raw_package() {
  /usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C /usr/bin/python3 -I -S -B \
    "$source_dir/normalize_package_info.py" "$@"
}
verify_evidence
umask 077
/bin/mkdir -m 0700 "$output"
work="$output/payload"
/bin/mkdir -p "$work/Library/Application Support/Flash/.incoming"
/usr/bin/ditto "$app" "$work/Library/Application Support/Flash/.incoming/Flash.app"
verify_evidence --verify-copy "$work/Library/Application Support/Flash/.incoming/Flash.app"
components="$output/components.plist"
/usr/bin/pkgbuild --analyze --root "$work" "$components"
/usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C /usr/bin/python3 "$source_dir/pin_component_policy.py" "$components"
for operation in install repair disable remove; do
  scripts="$output/$operation-scripts"
  /bin/mkdir "$scripts"
  /bin/cp "$source_dir/installer/$operation/"* "$scripts/"
  /bin/cp "$app/Contents/Library/HelperTools/FlashMaintenance" "$scripts/FlashMaintenance"
  /bin/chmod 0755 "$scripts/"*
  built="$output/$operation-built.pkg"
  package="$output/Flash-$operation.pkg"
  if [[ "$operation" == install || "$operation" == repair ]]; then
    /usr/bin/pkgbuild --root "$work" --component-plist "$components" --ownership recommended --scripts "$scripts" \
      --identifier "com.layoute.flash.managed.$operation" --install-location / \
      "$built"
  else
    /usr/bin/pkgbuild --nopayload --scripts "$scripts" --install-location / \
      --identifier "com.layoute.flash.managed.$operation" \
      "$built"
  fi
  raw="$output/$operation-raw"
  snapshot="$output/$operation-raw-members.json"
  /bin/mkdir "$raw"
  /usr/bin/xar -xf "$built" -C "$raw"
  raw_package normalize "$raw" "$snapshot" "$operation"
  raw_package verify "$raw" "$snapshot" "$operation"
  # pkgutil --expand decompresses Scripts; preserve every member via the outer XAR instead.
  (cd "$raw" && /usr/bin/xar -cf "$package" --compression=none *)
  raw_package verify "$raw" "$snapshot" "$operation"
  final_raw="$output/$operation-final-raw"
  /bin/mkdir "$final_raw"
  /usr/bin/xar -xf "$package" -C "$final_raw"
  raw_package verify "$final_raw" "$snapshot" "$operation"
  expanded="$output/$operation-expanded"
  /usr/sbin/pkgutil --expand-full "$package" "$expanded"
  verify_evidence --verify-expanded-package "$expanded" --package-operation "$operation"
done
verify_evidence
printf '%s\n' 'Unsigned local packages match qualified signed input. Helper/installer operations remain unverified and unapproved.'
