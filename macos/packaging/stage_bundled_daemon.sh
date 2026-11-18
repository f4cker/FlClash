#!/bin/bash
# Xcode build phase: embed the SMAppService daemon inside Flash.app.
#   Contents/Library/HelperTools/FlashHelper                       (BundleProgram)
#   Contents/Library/LaunchDaemons/com.layoute.flash.helperd.plist (SMAppService.daemon plist)
#   Contents/Library/LaunchDaemons/com.layoute.flash.daemon.plist  (retired name; only so the app can
#                                                                   unregister it, never registered)
# The Core stays at Contents/MacOS/FlClashCore (Copy Core phase). Nothing is signed,
# installed, registered or launched here; signing is the separate inside-out route.
set -euo pipefail
managed=false
for encoded in ${DART_DEFINES//,/ }; do
  define="$(printf '%s' "$encoded" | /usr/bin/base64 --decode)"
  if [[ "$define" == MACOS_MANAGED_HELPER=true ]]; then managed=true; fi
done
if [[ "$managed" != true ]]; then exit 0; fi
candidate="${FC_MANAGED_CANDIDATE_ENABLED-0}"
case "$candidate" in
  0|1) ;;
  *) echo 'FC_MANAGED_CANDIDATE_ENABLED must be 0 or 1' >&2; exit 1 ;;
esac
if [[ "$CONFIGURATION" != Release ]]; then echo 'Bundled daemon requires Release' >&2; exit 1; fi
library="$TARGET_BUILD_DIR/$CONTENTS_FOLDER_PATH/Library"
resources="$TARGET_BUILD_DIR/$CONTENTS_FOLDER_PATH/Resources"
# Legacy split/pkg artifacts must never ride along in a bundled-daemon app.
for stale in "$library/HelperTools/FlashMaintenance" \
             "$library/LaunchDaemons/com.layoute.flash.helper.plist" \
             "$resources/HelperInstaller"; do
  if [[ -e "$stale" || -L "$stale" ]]; then
    echo "Stale legacy helper artifact in a fresh build: $stale (clean the build directory)" >&2
    exit 1
  fi
done
architectures=()
for architecture in $ARCHS; do architectures+=(-arch "$architecture"); done
/bin/mkdir -p "$library/HelperTools" "$library/LaunchDaemons"
/usr/bin/xcrun clang "${architectures[@]}" -mmacosx-version-min=13.0 -fobjc-arc -fblocks \
  "-DFC_MANAGED_CANDIDATE_ENABLED=$candidate" -Wno-deprecated-declarations \
  -framework Foundation -framework Security \
  -sectcreate __TEXT __info_plist "$SRCROOT/PrivilegedHelper/Info.plist" \
  "$SRCROOT/Shared/HelperTrust.m" "$SRCROOT/PrivilegedHelper/Supervisor.m" \
  "$SRCROOT/PrivilegedHelper/Spawn.c" -o "$library/HelperTools/FlashHelper"
for plist in com.layoute.flash.helperd.plist com.layoute.flash.daemon.plist; do
  /usr/bin/plutil -lint "$SRCROOT/PrivilegedHelper/$plist"
  /bin/cp "$SRCROOT/PrivilegedHelper/$plist" "$library/LaunchDaemons/"
  /bin/chmod 0644 "$library/LaunchDaemons/$plist"
done
