#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
pilot_build_dir="${PILOT_BUILD_DIR:-$HOME/Library/Caches/PilotProOwnBuild}"
app_path="$pilot_build_dir/Pilot Pro Own.app"
pilot_target_arch="${PILOT_TARGET_ARCH:-$(uname -m)}"
pilot_signing_identity="${PILOT_CODESIGN_IDENTITY:--}"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
xcrun swiftc -swift-version 5 -target "$pilot_target_arch-apple-macos14.0" -O -parse-as-library App/Core/*.swift App/*.swift -o "$app_path/Contents/MacOS/PilotProOwn" -framework SwiftUI -framework AppKit -framework IOKit -framework ApplicationServices
cp Assets/Pilot-Pro-white.png Assets/Pilot-Pro-white.svg "$app_path/Contents/Resources/"
cp App/Info.plist "$app_path/Contents/Info.plist"
xattr -cr "$app_path"
codesign --force --sign "$pilot_signing_identity" --identifier com.mibstudio.PilotProOwn "$app_path"
codesign --verify --strict "$app_path"
mkdir -p build
ditto --noextattr "$app_path" "$PWD/build/Pilot Pro Own.app"
printf '%s\n' "$app_path"
