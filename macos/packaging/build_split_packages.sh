#!/bin/bash
set -euo pipefail
umask 077
[[ "$EUID" != 0 && "$#" == 11 ]] || { echo 'usage: build_split_packages.sh SIGNED_GUI SIGNED_SERVICE NEW_OUTPUT NEW_EVIDENCE NEW_BUILD_METADATA COMPILE_RECEIPT COMPILE_SHA256 SIGNING_RECEIPT SIGNING_SHA256 TOOLING_DELTA TOOLING_SHA256' >&2; exit 64; }
source_dir="$(cd "$(/usr/bin/dirname "$0")" && pwd)"
gui="$(cd "$1" && pwd -P)"
service="$(cd "$2" && pwd -P)"
[[ "$gui" == */Flash.app && "$service" == */Flash.app && "$gui" != "$service" ]] || exit 78
[[ ! -e "$3" && ! -L "$3" && "$4" == /* && "$5" == /* ]] || exit 78
output_parent="$(cd "$(/usr/bin/dirname "$3")" && pwd -P)"
output="$output_parent/$(/usr/bin/basename "$3")"
for app in "$gui" "$service"; do
  [[ "$output" != "$app/"* && "$app" != "$output/"* ]] || exit 78
done
evidence="$4"
metadata="$5"
compile_receipt="$6"
compile_sha256="$7"
signing_receipt="$8"
signing_sha256="$9"
tooling_delta="${10}"
tooling_sha256="${11}"
[[ "$compile_receipt" == /* && "$signing_receipt" == /* && "$tooling_delta" == /* ]] || exit 78
python() {
  /usr/bin/env -i PATH=/usr/bin:/bin LANG=C LC_ALL=C /usr/bin/python3 -I -S -B "$@"
}
split() { python "$source_dir/stage_split_payload.py" "$@"; }
verify_evidence() {
  split verify-qualification --gui "$gui" --service "$service" \
    --evidence "$evidence" --build-metadata "$metadata" \
    --service-compile-receipt "$compile_receipt" --service-compile-sha256 "$compile_sha256" \
    --service-signing-receipt "$signing_receipt" --service-signing-sha256 "$signing_sha256" \
    --tooling-delta "$tooling_delta" --tooling-delta-sha256 "$tooling_sha256"
}
raw_package() { python "$source_dir/normalize_package_info.py" "$@"; }
# Every gate rechecks unchanged GUI qualification and separate static service provenance.
verify_evidence
/bin/mkdir -m 0700 "$output"
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
dmg_root="$output/dmg-root"
/bin/mkdir "$dmg_root"
/usr/bin/ditto "$gui" "$dmg_root/Flash.app"
/bin/ln -s /Applications "$dmg_root/Applications"
split verify-copy --kind gui --original "$gui" --copy "$dmg_root/Flash.app"
verify_evidence
/usr/bin/hdiutil create -srcfolder "$dmg_root" -volname Flash -format UDZO "$output/Flash.dmg"
verify_evidence
printf '%s\n' 'Separate GUI drag-to-Applications DMG and helper-only packages created; installation remains unverified.'
