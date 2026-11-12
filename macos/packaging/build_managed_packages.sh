#!/bin/bash
set -euo pipefail
[[ "$EUID" != 0 && "$#" == 2 ]] || exit 64
[[ "${FC_PACKAGE_CERTIFICATE_SHA1:-}" =~ ^[[:xdigit:]]{40}$ ]] || exit 78
[[ "${FC_ARTIFACT_LOADS_VERIFIED:-0}" == 1 ]] || exit 78
source_dir="$(cd "$(/usr/bin/dirname "$0")" && pwd)"
app="$(cd "$1" && pwd)"
[[ "$app" == */Flash.app && ! -e "$2" ]] || exit 78
/usr/bin/python3 "$source_dir/stage_managed_payload.py" --verify "$app"
verify() {
  local path="$1" identifier="$2"
  local requirement="anchor H\"$FC_PACKAGE_CERTIFICATE_SHA1\" and certificate leaf = H\"$FC_PACKAGE_CERTIFICATE_SHA1\" and identifier \"$identifier\""
  /usr/bin/codesign --verify --strict --all-architectures -R "$requirement" "$path"
  local flags
  flags="$(/usr/bin/codesign -dvvv "$path" 2>&1)"
  [[ "$flags" == *runtime* && "$flags" != *adhoc* ]] || exit 78
}
verify "$app" com.layoute.flash
verify "$app/Contents/MacOS/FlClashCore" com.layoute.flash.core
verify "$app/Contents/Library/HelperTools/FlashHelper" com.layoute.flash.helper
verify "$app/Contents/Library/HelperTools/FlashMaintenance" com.layoute.flash.maintenance
/usr/bin/codesign --verify --deep --strict --all-architectures "$app"
/bin/mkdir -m 0700 "$2"
output="$(cd "$2" && pwd)"
work="$output/payload"
/bin/mkdir -p "$work/Library/Application Support/Flash/.incoming"
/usr/bin/ditto "$app" "$work/Library/Application Support/Flash/.incoming/Flash.app"
components="$output/components.plist"
/usr/bin/pkgbuild --analyze --root "$work" "$components"
/usr/bin/python3 "$source_dir/pin_component_policy.py" "$components"
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
    /usr/bin/pkgbuild --nopayload --scripts "$scripts" \
      --identifier "com.layoute.flash.managed.$operation" \
      "$output/Flash-$operation.pkg"
  fi
done
printf '%s\n' 'Unsigned local packages only. Review and explicitly approve each install/disable/uninstall operation.'
