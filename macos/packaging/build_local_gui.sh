#!/bin/bash
set -euo pipefail
umask 077
[[ "$#" == 4 && "$EUID" != 0 ]] || { echo 'usage: build_local_gui.sh SDK NEW_OUTPUT VERSION BUILD' >&2; exit 64; }
root="$(cd "$(dirname "$0")/../.." && pwd -P)"
sdk="$(cd "$1" && pwd -P)"
out="$2"
version="$3"
number="$4"
[[ ! -e "$out" && ! -L "$out" && "$out" == "$root/.airbuild/"* ]] || exit 78
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$number" =~ ^[0-9]+$ ]] || exit 64
dart="$sdk/bin/cache/dart-sdk/bin/dart"
snapshot="$sdk/bin/cache/flutter_tools.snapshot"
[[ -x "$dart" && -f "$snapshot" && -x /usr/bin/sandbox-exec ]] || exit 69
cd "$root"
[[ -f .dart_tool/package_config.json ]] || { echo 'Resolve dependencies with the configured SDK before release.' >&2; exit 69; }
mkdir -p "$out/kept-caches" "$out/sdk-launchers/bin" "$out/sdk-launchers/packages/flutter_tools/bin" "$out/xcrun-bin"
exec > >(tee "$out/build.log") 2>&1
/usr/bin/git rev-parse HEAD > "$out/source-head.txt"
/usr/bin/git --no-optional-locks status --porcelain > "$out/source-status.txt"
cat > "$out/sdk-launchers/bin/flutter" <<EOF
#!/bin/bash
export FLUTTER_ROOT=$(printf '%q' "$sdk")
exec $(printf '%q' "$dart") $(printf '%q' "$snapshot") --no-version-check --suppress-analytics "\$@"
EOF
cat > "$out/sdk-launchers/packages/flutter_tools/bin/macos_assemble.sh" <<EOF
#!/bin/bash
if [[ \$# == 0 ]]; then set -- build; fi
exec $(printf '%q' "$dart") $(printf '%q' "$sdk/packages/flutter_tools/bin/xcode_backend.dart") "\$@" macos
EOF
cat > "$out/xcrun-bin/xcrun" <<'EOF'
#!/bin/bash
set -euo pipefail
if [[ "${1-}" == xcodebuild ]]; then
  for argument in "$@"; do
    case "$argument" in
      -project|-workspace|-resolvePackageDependencies)
        shift
        exec /usr/bin/xcrun xcodebuild "$@" -disableAutomaticPackageResolution \
          -onlyUsePackageVersionsFromResolvedFile -skipPackageUpdates \
          -IDEPackageSupportDisableManifestSandbox=YES ;;
    esac
  done
fi
exec /usr/bin/xcrun "$@"
EOF
chmod 755 "$out/sdk-launchers/bin/flutter" "$out/sdk-launchers/packages/flutter_tools/bin/macos_assemble.sh" "$out/xcrun-bin/xcrun"
for cache in flutter_build setup_build_cache; do
  if [[ -e ".dart_tool/$cache" ]]; then mv ".dart_tool/$cache" "$out/kept-caches/$cache"; fi
done
for package in setup rust_api objective_c sqlite3; do
  if [[ -e ".dart_tool/hooks_runner/$package" ]]; then mv ".dart_tool/hooks_runner/$package" "$out/kept-caches/hooks-$package"; fi
done
if [[ -e libclash/macos ]]; then mv libclash/macos "$out/kept-caches/libclash-macos"; fi
if [[ -e build/macos ]]; then mv build/macos "$out/kept-caches/xcode-macos"; fi
export PATH="$out/xcrun-bin:$sdk/bin/cache/dart-sdk/bin:$PATH"
export FLUTTER_ROOT="$sdk" FLUTTER_SUPPRESS_ANALYTICS=true CI=true FLUTTER_XCODE_PATH="$PATH"
export GOENV=off GOTOOLCHAIN=local RUSTUP_AUTO_INSTALL=0 CARGO_NET_OFFLINE=true GOPROXY=off GOSUMDB=off
export CARGO_TARGET_DIR="$out/cargo-target" GOCACHE="$out/go-build-cache"
export FLUTTER_XCODE_ARCHS=arm64 FLUTTER_XCODE_ONLY_ACTIVE_ARCH=YES
export FLUTTER_XCODE_FLUTTER_ROOT="$out/sdk-launchers" FLUTTER_XCODE_FLUTTER_APPLICATION_PATH="$root"
export FLUTTER_XCODE_FLUTTER_BUILD_NAME="$version" FLUTTER_XCODE_FLUTTER_BUILD_NUMBER="$number"
export FLUTTER_XCODE_FC_MANAGED_CANDIDATE_ENABLED=1 FLUTTER_XCODE_FC_MACOS_PACKAGE_MODE=gui-only
export FC_MACOS_PACKAGE_MODE=gui-only
export FLUTTER_XCODE_GCC_PREPROCESSOR_DEFINITIONS='$(inherited) FC_MANAGED_CANDIDATE_ENABLED=1'
export FLUTTER_XCODE_CODE_SIGNING_ALLOWED=NO FLUTTER_XCODE_CODE_SIGNING_REQUIRED=NO
export FLUTTER_XCODE_CODE_SIGN_IDENTITY='' FLUTTER_XCODE_EXPANDED_CODE_SIGN_IDENTITY=''
export FLUTTER_XCODE_DEVELOPMENT_TEAM='' FLUTTER_XCODE_CODE_SIGN_STYLE=Manual
cat > "$out/unsigned.xcconfig" <<EOF
CODE_SIGNING_ALLOWED = NO
CODE_SIGNING_REQUIRED = NO
CODE_SIGN_IDENTITY =
EXPANDED_CODE_SIGN_IDENTITY =
DEVELOPMENT_TEAM =
CODE_SIGN_STYLE = Manual
ARCHS = arm64
ONLY_ACTIVE_ARCH = YES
FC_MACOS_PACKAGE_MODE = gui-only
EOF
export XCODE_XCCONFIG_FILE="$out/unsigned.xcconfig"
guard='(version 1)(allow default)(deny process-exec (literal "/usr/bin/codesign") (literal "/usr/bin/security"))(deny network*)(allow network* (local unix-socket) (remote unix-socket))'
/usr/bin/sandbox-exec -p "$guard" "$dart" "$snapshot" --no-version-check --suppress-analytics \
  build macos --release --no-pub "--build-name=$version" "--build-number=$number" \
  --dart-define=APP_ENV=stable --dart-define=MACOS_MANAGED_HELPER=true
app="$root/build/macos/Build/Products/Release/Flash.app"
[[ -d "$app" && ! -e "$app/Contents/Library/HelperTools" ]] || exit 78
mv build/macos "$out/new-xcode-macos"
printf '%s\n' 'Fresh unsigned GUI built; generated Core is not the released Core. No output executed.'
