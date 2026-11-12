#!/bin/bash
set -euo pipefail
managed=false
for encoded in ${DART_DEFINES//,/ }; do
  define="$(printf '%s' "$encoded" | /usr/bin/base64 --decode)"
  if [[ "$define" == MACOS_MANAGED_HELPER=true ]]; then managed=true; fi
done
if [[ "$managed" != true ]]; then exit 0; fi
architectures=()
for architecture in $ARCHS; do architectures+=(-arch "$architecture"); done
if [[ "$CONFIGURATION" != Release ]]; then echo 'Managed helper requires Release' >&2; exit 1; fi
output="$TARGET_BUILD_DIR/$CONTENTS_FOLDER_PATH/Library"
/bin/mkdir -p "$output/HelperTools" "$output/LaunchDaemons"
/usr/bin/xcrun clang "${architectures[@]}" -mmacosx-version-min=13.0 -fobjc-arc -fblocks \
  -Wno-deprecated-declarations -framework Foundation -framework Security \
  "$SRCROOT/Shared/HelperTrust.m" "$SRCROOT/PrivilegedHelper/Supervisor.m" \
  "$SRCROOT/PrivilegedHelper/Spawn.c" -o "$output/HelperTools/FlashHelper"
/bin/cp "$SRCROOT/PrivilegedHelper/com.layoute.flash.helper.plist" "$output/LaunchDaemons/"
/usr/bin/xcrun clang "${architectures[@]}" -mmacosx-version-min=13.0 -fobjc-arc -fblocks \
  -Wno-deprecated-declarations -framework Foundation -framework Security -framework ServiceManagement \
  "$SRCROOT/Shared/HelperTrust.m" "$SRCROOT/PrivilegedHelper/Maintenance.m" \
  -o "$output/HelperTools/FlashMaintenance"
