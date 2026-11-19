#!/bin/bash
# Xcode build phase: embed the SMAppService daemon inside Flash.app.
#   Contents/Library/HelperTools/FlashHelperLauncher               (BundleProgram: the fixed launcher, the signed
#                                                                   master copied byte for byte, never rebuilt)
#   Contents/Library/HelperTools/FlashHelper                       (started by the launcher from a verified copy;
#                                                                   CFBundleVersion = the release build number)
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
# The launcher refuses a helper whose CFBundleVersion is below the highest it has run, so the helper carries the
# release build number (pubspec +N, strictly increasing per release). Never the literal placeholder.
build="${FLUTTER_BUILD_NUMBER-}"
if [[ ! "$build" =~ ^[1-9][0-9]{0,18}$ ]]; then
  echo "FLUTTER_BUILD_NUMBER must be the release build number (decimal, no leading zero, <= 19 digits): '$build'" >&2
  exit 1
fi
launcher="$SRCROOT/PrivilegedHelper/Launcher/FlashHelperLauncher"
pin="$SRCROOT/PrivilegedHelper/Launcher/FlashHelperLauncher.pin.json"
launcher_sha256="$(/usr/bin/plutil -extract sha256 raw -o - "$pin")"
if [[ ! "$launcher_sha256" =~ ^[0-9a-f]{64}$ ]]; then
  echo "FlashHelperLauncher is not pinned yet: sign the master once and record it in $pin" >&2
  exit 1
fi
if [[ ! -f "$launcher" || -L "$launcher" ]]; then
  echo "Missing signed launcher master: $launcher" >&2
  exit 1
fi
if [[ "$(/usr/bin/shasum -a 256 "$launcher" | /usr/bin/cut -d ' ' -f 1)" != "$launcher_sha256" ]]; then
  echo "Launcher master differs from its pinned sha256: $launcher" >&2
  exit 1
fi
architectures=()
for architecture in $ARCHS; do architectures+=(-arch "$architecture"); done
/bin/mkdir -p "$library/HelperTools" "$library/LaunchDaemons"
info="$DERIVED_FILE_DIR/FlashHelper-Info.plist"
/bin/mkdir -p "$DERIVED_FILE_DIR"
/bin/rm -f "$info"
/bin/cp "$SRCROOT/PrivilegedHelper/Info.plist" "$info"
/usr/bin/plutil -replace CFBundleVersion -string "$build" "$info"
if [[ "$(/usr/bin/plutil -extract CFBundleVersion raw -o - "$info")" != "$build" ]]; then
  echo 'Helper CFBundleVersion was not written' >&2
  exit 1
fi
/usr/bin/xcrun clang "${architectures[@]}" -mmacosx-version-min=14.0 -fobjc-arc -fblocks \
  "-DFC_MANAGED_CANDIDATE_ENABLED=$candidate" -Wno-deprecated-declarations \
  -framework Foundation -framework Security \
  -sectcreate __TEXT __info_plist "$info" \
  "$SRCROOT/Shared/HelperTrust.m" "$SRCROOT/PrivilegedHelper/Supervisor.m" \
  "$SRCROOT/PrivilegedHelper/Spawn.c" -o "$library/HelperTools/FlashHelper"
for plist in com.layoute.flash.helperd.plist com.layoute.flash.daemon.plist; do
  /usr/bin/plutil -lint "$SRCROOT/PrivilegedHelper/$plist"
  /bin/cp "$SRCROOT/PrivilegedHelper/$plist" "$library/LaunchDaemons/"
  /bin/chmod 0644 "$library/LaunchDaemons/$plist"
done
# Byte-for-byte copy of the signed master (its signature is embedded); verified again after the copy.
/bin/rm -f "$library/HelperTools/FlashHelperLauncher"
/bin/cp -X "$launcher" "$library/HelperTools/FlashHelperLauncher"
/bin/chmod 0755 "$library/HelperTools/FlashHelperLauncher"
if [[ "$(/usr/bin/shasum -a 256 "$library/HelperTools/FlashHelperLauncher" | /usr/bin/cut -d ' ' -f 1)" != "$launcher_sha256" ]]; then
  echo 'Copied launcher differs from the pinned master' >&2
  exit 1
fi
