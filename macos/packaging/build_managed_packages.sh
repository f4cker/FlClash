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
  if [[ "$operation" == install || "$operation" == repair ]]; then
    /usr/bin/pkgbuild --root "$work" --component-plist "$components" --ownership recommended --scripts "$scripts" \
      --identifier "com.layoute.flash.managed.$operation" --install-location / \
      "$output/Flash-$operation.pkg"
  else
    /usr/bin/pkgbuild --nopayload --scripts "$scripts" --install-location / \
      --identifier "com.layoute.flash.managed.$operation" \
      "$output/Flash-$operation.pkg"
  fi
  expanded="$output/$operation-expanded"
  /usr/sbin/pkgutil --expand-full "$output/Flash-$operation.pkg" "$expanded"
  verify_evidence --verify-expanded-package "$expanded" --package-operation "$operation"
done
verify_evidence
printf '%s\n' 'Unsigned local packages match qualified signed input. Helper/installer operations remain unverified and unapproved.'
