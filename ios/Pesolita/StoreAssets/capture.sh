#!/bin/zsh
# Captures the raw app screens for the App Store screenshots into StoreAssets/raw/.
# Needs a Debug build of Pesolita (the launch-argument hooks only exist in Debug):
#   xcodebuild build -project ../Pesolita.xcodeproj -scheme Pesolita \
#     -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath <dir>
#   ./capture.sh <dir>/Build/Products/Debug-iphonesimulator/Pesolita.app
# Then compose them with `swift render-v2.swift`.
set -e
APP="$1"
DEVICE="iPhone 17 Pro Max"
BUNDLE="com.pesolita.app"
OUT="$(cd "$(dirname "$0")" && pwd)/raw"
mkdir -p "$OUT"

UDID=$(xcrun simctl list devices available | grep "$DEVICE (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl install "$UDID" "$APP"
# Apple's own marketing status bar: 9:41, full signal, full battery.
xcrun simctl status_bar "$UDID" override --time "9:41" --dataNetwork wifi --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100

shot() {  # name, appearance, wait, launch args...
  local name=$1 look=$2 wait=$3; shift 3
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  xcrun simctl ui "$UDID" appearance "$look"
  xcrun simctl launch "$UDID" "$BUNDLE" --demo-wallet --store "$@" >/dev/null
  sleep "$wait"
  xcrun simctl io "$UDID" screenshot "$OUT/$name.png" >/dev/null 2>&1
  echo "captured $name"
}

shot home-dark        dark  5 --theme=dark
shot home-light       light 5 --theme=light
shot friends-open     dark  5 --theme=dark --owed-expanded
shot split-sheet      dark  6 --theme=dark --sheet=split --split-open
shot event            dark  5 --theme=dark --route=event
shot people           light 5 --theme=light --route=people
shot settle           dark  6 --theme=dark --settle
shot pro              dark  6 --theme=dark --open-pro
shot insights         dark  5 --theme=dark --tab=insights
shot editor           dark  5 --theme=dark --route=editor

xcrun simctl status_bar "$UDID" clear
