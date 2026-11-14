#!/bin/bash
set -euo pipefail
umask 077
[[ "$EUID" != 0 && ( "$#" == 8 || "$#" == 10 ) ]] || { echo 'usage: build_split_packages.sh gui-only|helper-update SIGNED_GUI RELEASED_SERVICE NEW_OUTPUT GUI_RECEIPT GUI_SHA256 SERVICE_RECEIPT SERVICE_SHA256 [COMPILE_RECEIPT COMPILE_SHA256]' >&2; exit 64; }
mode="$1"
[[ ( "$mode" == gui-only && "$#" == 8 ) || ( "$mode" == helper-update && "$#" == 10 ) ]] || exit 64
source_dir="$(cd "$(/usr/bin/dirname "$0")" && pwd)"
gui="$(cd "$2" && pwd -P)"
service="$(cd "$3" && pwd -P)"
[[ "$gui" == */Flash.app && "$service" == */Flash.app && "$gui" != "$service" ]] || exit 78
[[ ! -e "$4" && ! -L "$4" ]] || exit 78
output_parent="$(cd "$(/usr/bin/dirname "$4")" && pwd -P)"
output="$output_parent/$(/usr/bin/basename "$4")"
for app in "$gui" "$service"; do
  [[ "$output" != "$app/"* && "$app" != "$output/"* ]] || exit 78
done
gui_receipt="$5"
gui_sha256="$6"
service_receipt="$7"
service_sha256="$8"
compile_args=()
if [[ "$mode" == helper-update ]]; then
  compile_args=(--compile-receipt "$9" --compile-sha256 "${10}")
fi
python() {
  /usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C /usr/bin/python3 -I -S -B "$@"
}
split() { python "$source_dir/stage_split_payload.py" "$@"; }
verify_evidence() {
  split verify-release --gui "$gui" --service "$service" \
    --gui-receipt "$gui_receipt" --gui-sha256 "$gui_sha256" \
    --service-receipt "$service_receipt" --service-sha256 "$service_sha256" \
    ${compile_args[@]+"${compile_args[@]}"}
}
raw_package() { python "$source_dir/normalize_package_info.py" "$@"; }
verify_evidence
/bin/mkdir -m 0700 "$output"
/usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C VOLNAME=Flash APPS_NAME=应用程序 \
  /bin/bash "$source_dir/../../tool/macos/make_styled_dmg.sh" \
  "$gui" "$source_dir/dmg/background.png" "$source_dir/dmg/background@2x.png" "$output/Flash.dmg"
verify_evidence
if [[ "$mode" == gui-only ]]; then
  printf '%s\n' 'GUI-only styled DMG created; released service and Core unchanged; functional acceptance UNTESTED.'
  exit 0
fi
work="$output/payload"
/bin/mkdir -p "$work/Library/Application Support/Flash/.incoming"
/usr/bin/ditto "$service" "$work/Library/Application Support/Flash/.incoming/Flash.app"
split verify-copy --kind service --original "$service" --copy "$work/Library/Application Support/Flash/.incoming/Flash.app"
components="$output/components.plist"
/usr/bin/pkgbuild --analyze --root "$work" "$components"
python "$source_dir/pin_component_policy.py" "$components"
for operation in install repair disable remove; do
  scripts="$output/$operation-scripts"
  /bin/mkdir "$scripts"
  /bin/cp "$source_dir/installer/$operation/"* "$scripts/"
  /bin/cp "$service/Contents/Library/HelperTools/FlashMaintenance" "$scripts/FlashMaintenance"
  /bin/chmod 0755 "$scripts/"*
  built="$output/$operation-built.pkg"
  package="$output/Flash-helper-$operation.pkg"
  if [[ "$operation" == install || "$operation" == repair ]]; then
    /usr/bin/pkgbuild --root "$work" --component-plist "$components" --ownership recommended --scripts "$scripts" \
      --identifier "com.layoute.flash.managed.$operation" --install-location / "$built"
  else
    /usr/bin/pkgbuild --nopayload --scripts "$scripts" --install-location / \
      --identifier "com.layoute.flash.managed.$operation" "$built"
  fi
  raw="$output/$operation-raw"
  snapshot="$output/$operation-raw-members.json"
  /bin/mkdir "$raw"
  /usr/bin/xar -xf "$built" -C "$raw"
  raw_package normalize "$raw" "$snapshot" "$operation"
  raw_package verify "$raw" "$snapshot" "$operation"
  (cd "$raw" && /usr/bin/xar -cf "$package" --compression=none *)
  final_raw="$output/$operation-final-raw"
  /bin/mkdir "$final_raw"
  /usr/bin/xar -xf "$package" -C "$final_raw"
  raw_package verify "$final_raw" "$snapshot" "$operation"
  expanded="$output/$operation-expanded"
  /usr/sbin/pkgutil --expand-full "$package" "$expanded"
  split verify-expanded --service "$service" --expanded "$expanded" --operation "$operation"
  verify_evidence
done
printf '%s\n' 'Styled GUI DMG and one-time helper migration packages created; functional acceptance UNTESTED.'
