#!/bin/bash
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
architectures=()
for architecture in $ARCHS; do architectures+=(-arch "$architecture"); done
if [[ "$CONFIGURATION" != Release ]]; then echo 'Managed helper requires Release' >&2; exit 1; fi
output="$TARGET_BUILD_DIR/$CONTENTS_FOLDER_PATH/Library"
/bin/mkdir -p "$output/HelperTools" "$output/LaunchDaemons"
/usr/bin/xcrun clang "${architectures[@]}" -mmacosx-version-min=13.0 -fobjc-arc -fblocks \
  "-DFC_MANAGED_CANDIDATE_ENABLED=$candidate" -Wno-deprecated-declarations -framework Foundation -framework Security \
  "$SRCROOT/Shared/HelperTrust.m" "$SRCROOT/PrivilegedHelper/Supervisor.m" \
  "$SRCROOT/PrivilegedHelper/Spawn.c" -o "$output/HelperTools/FlashHelper"
/bin/cp "$SRCROOT/PrivilegedHelper/com.layoute.flash.helper.plist" "$output/LaunchDaemons/"
/usr/bin/xcrun clang "${architectures[@]}" -mmacosx-version-min=13.0 -fobjc-arc -fblocks \
  "-DFC_MANAGED_CANDIDATE_ENABLED=$candidate" -Wno-deprecated-declarations -framework Foundation -framework Security -framework ServiceManagement \
  "$SRCROOT/Shared/HelperTrust.m" "$SRCROOT/PrivilegedHelper/Maintenance.m" \
  -o "$output/HelperTools/FlashMaintenance"
