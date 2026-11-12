#!/usr/bin/env bash
# Usage: tool/macos/make_styled_dmg.sh [--volicon <icon.png|icon.icns>] <Flash.app> [<background.png> [<background@2x.png>]] <out.dmg>
# Packages the app into a UDZO DMG laid out by Finder (660x400 window, /Applications link named $APPS_NAME).
# Env: VOLNAME (Flash), APPS_NAME (应用程序), ICONSET_DIR, WIN_X/WIN_Y, TITLEBAR_H, KEEP_TMP=1. Needs Finder automation.

set -euo pipefail

VOLNAME="${VOLNAME:-Flash}"
APPS_NAME="${APPS_NAME:-应用程序}"
WIN_W=660
WIN_H=400
WIN_X="${WIN_X:-200}"
WIN_Y="${WIN_Y:-120}"
if [[ -z "${TITLEBAR_H:-}" ]]; then
  _osmaj="$(sw_vers -productVersion 2>/dev/null | cut -d. -f1)"; _osmaj="${_osmaj:-0}"
  if   (( _osmaj >= 26 )); then TITLEBAR_H=32
  elif (( _osmaj >= 11 )); then TITLEBAR_H=28
  else TITLEBAR_H=22; fi
fi
ICON_SIZE=128
TEXT_SIZE=13
APP_POS_X=170;  APP_POS_Y=190
LINK_POS_X=490; LINK_POS_Y=190
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ICONSET_DIR="${ICONSET_DIR:-$REPO_ROOT/macos/Runner/Assets.xcassets/AppIcon.appiconset}"
DEFAULT_BG="$REPO_ROOT/macos/packaging/dmg/background.png"
DEFAULT_BG2X="$REPO_ROOT/macos/packaging/dmg/background@2x.png"

log() { printf '[make_styled_dmg] %s\n' "$*" >&2; }
die() { printf '[make_styled_dmg] ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  sed -n '2,4p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
}

VOLICON=""
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --volicon)   [[ $# -ge 2 ]] || usage; VOLICON="$2"; shift 2 ;;
    --volicon=*) VOLICON="${1#--volicon=}"; shift ;;
    -h|--help)   usage ;;
    --)          shift; ARGS+=("$@"); break ;;
    -*)          die "unknown option: $1" ;;
    *)           ARGS+=("$1"); shift ;;
  esac
done
set -- ${ARGS[@]+"${ARGS[@]}"}

case $# in
  2) APP="$1"; BG1X="$DEFAULT_BG"; BG2X="$DEFAULT_BG2X"; OUT="$2" ;;
  3) APP="$1"; BG1X="$2"; BG2X="";   OUT="$3" ;;
  4) APP="$1"; BG1X="$2"; BG2X="$3"; OUT="$4" ;;
  *) usage ;;
esac

[[ "$(uname -s)" == "Darwin" ]] || die "macOS only"
APP="${APP%/}"
[[ -d "$APP" && "$APP" == *.app ]]          || die "not an .app bundle: $APP"
[[ -f "$APP/Contents/Info.plist" ]]        || die "missing Info.plist in $APP"
[[ -f "$BG1X" ]]                           || die "background not found: $BG1X"
[[ -z "$BG2X" || -f "$BG2X" ]]             || die "@2x background not found: $BG2X"
[[ "$OUT" == *.dmg ]]                      || die "output must end in .dmg: $OUT"
[[ -z "$VOLICON" || -f "$VOLICON" ]]       || die "--volicon file not found: $VOLICON"
for t in hdiutil ditto osascript iconutil tiffutil sips; do
  command -v "$t" >/dev/null 2>&1 || die "required tool missing: $t"
done

APP_NAME="$(basename "$APP")"
OUT_DIR="$(cd "$(dirname "$OUT")" 2>/dev/null && pwd)" || die "output directory does not exist: $(dirname "$OUT")"
OUT="$OUT_DIR/$(basename "$OUT")"

check_size() { # file expected_w expected_h
  local w h
  w=$(sips -g pixelWidth  "$1" 2>/dev/null | awk '/pixelWidth/{print $2}')
  h=$(sips -g pixelHeight "$1" 2>/dev/null | awk '/pixelHeight/{print $2}')
  if [[ "$w" != "$2" || "$h" != "$3" ]]; then
    log "WARNING: $1 is ${w}x${h}, expected ${2}x${3}"
  fi
}
check_size "$BG1X" "$WIN_W" "$WIN_H"
[[ -n "$BG2X" ]] && check_size "$BG2X" $((WIN_W*2)) $((WIN_H*2))

if [[ -e "/Volumes/$VOLNAME" ]]; then
  die "/Volumes/$VOLNAME already exists (a volume named '$VOLNAME' is mounted). Eject it first; refusing to touch it."
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/make_styled_dmg.XXXXXX")"
DEV=""
MNT=""
cleanup() {
  local rc=$?
  if [[ -n "$DEV" ]]; then
    hdiutil detach "$DEV" -quiet >/dev/null 2>&1 || hdiutil detach "$DEV" -force -quiet >/dev/null 2>&1 || true
  fi
  if [[ "${KEEP_TMP:-0}" == "1" ]]; then
    log "temp kept at $TMP"
  else
    rm -rf "$TMP"
  fi
  exit $rc
}
trap cleanup EXIT
trap 'exit 130' INT TERM HUP

ICNS=""
build_icns_from_png() { # src.png out.icns
  local src="$1" out="$2" is="$TMP/VolIcon.iconset" px name
  local w h
  w=$(sips -g pixelWidth  "$src" | awk '/pixelWidth/{print $2}')
  h=$(sips -g pixelHeight "$src" | awk '/pixelHeight/{print $2}')
  [[ "$w" == "$h" ]] || die "volume icon PNG must be square (got ${w}x${h}): $src"
  [[ "$w" -ge 512 ]] || die "volume icon PNG too small (${w}px, need >=512, ideally 1024): $src"
  [[ "$w" -ge 1024 ]] || log "WARNING: $src is ${w}px; 512@2x slot will be upscaled"
  rm -rf "$is"; mkdir -p "$is"
  for pair in \
    "16:icon_16x16.png" "32:icon_16x16@2x.png" \
    "32:icon_32x32.png" "64:icon_32x32@2x.png" \
    "128:icon_128x128.png" "256:icon_128x128@2x.png" \
    "256:icon_256x256.png" "512:icon_256x256@2x.png" \
    "512:icon_512x512.png" "1024:icon_512x512@2x.png"; do
    px="${pair%%:*}"; name="${pair#*:}"
    sips -s format png -z "$px" "$px" "$src" --out "$is/$name" >/dev/null || die "sips failed on $src"
  done
  iconutil -c icns "$is" -o "$out" || die "iconutil failed for $src"
}
if [[ -n "$VOLICON" ]]; then
  case "$(printf '%s' "$VOLICON" | tr '[:upper:]' '[:lower:]')" in
    *.icns) ICNS="$VOLICON" ;;
    *.png)  build_icns_from_png "$VOLICON" "$TMP/VolumeIcon.icns"; ICNS="$TMP/VolumeIcon.icns" ;;
    *)      die "--volicon must be a .png or .icns: $VOLICON" ;;
  esac
fi
[[ -z "$ICNS" ]] && icon_file="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$APP/Contents/Info.plist" 2>/dev/null || true)"
if [[ -z "$ICNS" && -n "${icon_file:-}" ]]; then
  [[ "$icon_file" == *.icns ]] || icon_file="$icon_file.icns"
  [[ -f "$APP/Contents/Resources/$icon_file" ]] && ICNS="$APP/Contents/Resources/$icon_file"
fi
if [[ -z "$ICNS" && -f "$APP/Contents/Resources/AppIcon.icns" ]]; then
  ICNS="$APP/Contents/Resources/AppIcon.icns"
fi
if [[ -z "$ICNS" ]]; then
  [[ -d "$ICONSET_DIR" ]] || die "app has no .icns and ICONSET_DIR not found: $ICONSET_DIR"
  log "app has no .icns; building one from $ICONSET_DIR"
  IS="$TMP/AppIcon.iconset"
  mkdir -p "$IS"
  for pair in \
    "16:icon_16x16.png" "32:icon_16x16@2x.png" \
    "32:icon_32x32.png" "64:icon_32x32@2x.png" \
    "128:icon_128x128.png" "256:icon_128x128@2x.png" \
    "256:icon_256x256.png" "512:icon_256x256@2x.png" \
    "512:icon_512x512.png" "1024:icon_512x512@2x.png"; do
    px="${pair%%:*}"; name="${pair#*:}"
    src="$ICONSET_DIR/app_icon_${px}.png"
    if [[ -f "$src" ]]; then
      cp "$src" "$IS/$name"
    elif [[ -f "$ICONSET_DIR/app_icon_1024.png" ]]; then
      sips -z "$px" "$px" "$ICONSET_DIR/app_icon_1024.png" --out "$IS/$name" >/dev/null
    else
      die "missing $src"
    fi
  done
  iconutil -c icns "$IS" -o "$TMP/AppIcon.icns" || die "iconutil failed"
  ICNS="$TMP/AppIcon.icns"
fi
log "volume icon source: $ICNS"

if [[ -n "$BG2X" ]]; then
  BG_NAME="background.tiff"
  tiffutil -cathidpicheck "$BG1X" "$BG2X" -out "$TMP/$BG_NAME" >/dev/null 2>"$TMP/tiffutil.err" \
    || die "tiffutil -cathidpicheck failed (is the @2x exactly double the 1x size?)"
else
  BG_NAME="background.png"
  cp "$BG1X" "$TMP/$BG_NAME"
fi

app_mb=$(du -sm "$APP" | awk '{print $1}')
size_mb=$(( app_mb + app_mb / 5 + 32 ))
RW="$TMP/rw.dmg"
log "creating ${size_mb}MB read-write HFS+ image"
hdiutil create -quiet -size "${size_mb}m" -fs HFS+ -volname "$VOLNAME" -type UDIF -ov "$RW"

[[ -e "/Volumes/$VOLNAME" ]] && die "/Volumes/$VOLNAME appeared meanwhile; refusing to continue"

attach_out="$(hdiutil attach "$RW" -readwrite -noverify -noautoopen 2>"$TMP/attach.err")" \
  || die "hdiutil attach failed: $(cat "$TMP/attach.err")"
DEV="$(printf '%s\n' "$attach_out" | awk '/Apple_HFS/{print $1; exit}')"
MNT="$(printf '%s\n' "$attach_out" | awk -F'\t' '/Apple_HFS/{print $NF; exit}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
[[ -n "$DEV" && -n "$MNT" ]] || die "could not parse hdiutil attach output:\n$attach_out"
DEV="${DEV%s[0-9]*}"   # detach the whole disk, not just the slice
log "attached $DEV at $MNT"
[[ "$MNT" == "/Volumes/$VOLNAME" ]] || die "volume mounted at '$MNT' instead of /Volumes/$VOLNAME (name clash?)"

ditto "$APP" "$MNT/$APP_NAME"
[[ "$APPS_NAME" != */* && "$APPS_NAME" != "$APP_NAME" ]] || die "invalid APPS_NAME: $APPS_NAME"
ln -s /Applications "$MNT/$APPS_NAME"
mkdir "$MNT/.background"
cp "$TMP/$BG_NAME" "$MNT/.background/$BG_NAME"
chmod -R a+rX "$MNT/$APP_NAME" "$MNT/.background"
SetFile -a V "$MNT/.background" 2>/dev/null || true

log "styling Finder window via AppleScript"
X1=$WIN_X; Y1=$WIN_Y; X2=$((WIN_X + WIN_W)); Y2=$((WIN_Y + WIN_H + TITLEBAR_H))
set +e
# Names travel as argv so non-ASCII names such as 应用程序 survive intact.
osa_out="$(osascript - "$VOLNAME" "$APP_NAME" "$APPS_NAME" "$BG_NAME" 2>&1 <<OSA
on run argv
  set volName to item 1 of argv
  set appName to item 2 of argv
  set appsName to item 3 of argv
  set bgName to item 4 of argv
  tell application "Finder"
    tell disk volName
      open
      set current view of container window to icon view
      set toolbar visible of container window to false
      set statusbar visible of container window to false
      try
        set sidebar width of container window to 0
      end try
      set the bounds of container window to {$X1, $Y1, $X2, $Y2}
      set viewOptions to the icon view options of container window
      set arrangement of viewOptions to not arranged
      set icon size of viewOptions to $ICON_SIZE
      set text size of viewOptions to $TEXT_SIZE
      set label position of viewOptions to bottom
      set shows item info of viewOptions to false
      set shows icon preview of viewOptions to false
      set background picture of viewOptions to file (".background:" & bgName)
      set position of item appName of container window to {$APP_POS_X, $APP_POS_Y}
      set position of item appsName of container window to {$LINK_POS_X, $LINK_POS_Y}
      close
      open
      set the bounds of container window to {$X1, $Y1, $X2, $Y2}
      update without registering applications
      delay 1
    end tell
    -- A saved selection would show a grey highlight on first open.
    try
      select {}
    end try
    try
      set selection to {}
    end try
    try
      set selection of container window of disk volName to {}
    end try
    delay 1
    tell disk volName to close
  end tell
end run
OSA
)"
osa_rc=$?
set -e
if [[ $osa_rc -ne 0 ]]; then
  if [[ "$osa_out" == *"-1743"* ]]; then
    die "Finder automation not permitted (osascript error -1743). Approve the macOS prompt / enable it in System Settings > Privacy & Security > Automation (allow this terminal to control Finder), then re-run. Details: $osa_out"
  fi
  die "osascript failed ($osa_rc): $osa_out"
fi

sync
ds="$MNT/.DS_Store"
prev=-1; stable=0
for _ in $(seq 1 60); do
  if [[ -s "$ds" ]]; then
    cur=$(stat -f %z "$ds")
    if [[ "$cur" == "$prev" ]]; then stable=$((stable + 1)); else stable=0; fi
    prev=$cur
    [[ $stable -ge 2 ]] && break
  fi
  sleep 0.5
done
[[ -s "$ds" ]] || die ".DS_Store was not written by Finder (layout would be lost)"
log ".DS_Store written ($(stat -f %z "$ds") bytes)"

# Finder drops .VolumeIcon.icns and the custom-icon flag while styling, so this runs after it.
cp "$ICNS" "$MNT/.VolumeIcon.icns"
chmod a+r "$MNT/.VolumeIcon.icns"
if command -v SetFile >/dev/null 2>&1 && SetFile -a C "$MNT" 2>/dev/null; then
  SetFile -a V "$MNT/.VolumeIcon.icns" 2>/dev/null || true
  log "custom icon flag set via SetFile"
else
  xattr -wx com.apple.FinderInfo \
    "00 00 00 00 00 00 00 00 04 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00" \
    "$MNT" || die "failed to set custom icon flag on volume root"
  log "custom icon flag set via xattr com.apple.FinderInfo"
fi

rm -rf "$MNT/.fseventsd" "$MNT/.Trashes" 2>/dev/null || true
chmod -R a+rX "$MNT/$APP_NAME" || true
sync
sleep 1
[[ -s "$MNT/.DS_Store" ]]       || die ".DS_Store disappeared before detach"
[[ -s "$MNT/.VolumeIcon.icns" ]] || die ".VolumeIcon.icns disappeared before detach"
fi_hex="$(xattr -px com.apple.FinderInfo "$MNT" 2>/dev/null | tr -d ' \n' || true)"
flag_byte="${fi_hex:16:2}"
if [[ ! "$flag_byte" =~ ^[0-9a-fA-F]{2}$ ]] || (( (16#$flag_byte & 0x04) == 0 )); then
  die "custom-icon flag missing on volume root (FinderInfo=$fi_hex)"
fi

detached=0
for i in 1 2 3 4 5; do
  if hdiutil detach "$DEV" -quiet 2>/dev/null; then detached=1; break; fi
  sleep $i
done
if [[ $detached -eq 0 ]]; then
  log "normal detach failed; forcing"
  hdiutil detach "$DEV" -force -quiet
fi
DEV=""; MNT=""

log "converting to UDZO"
rm -f "$OUT"
hdiutil convert "$RW" -quiet -format UDZO -imagekey zlib-level=9 -o "$OUT"
hdiutil verify -quiet "$OUT" || die "hdiutil verify failed for $OUT"
log "done: $OUT ($(du -h "$OUT" | awk '{print $1}'))"
