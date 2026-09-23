#!/bin/zsh
# Records the five app scenes for the video ad into recordings/.
# Needs a Debug build (the --store and --demo-* hooks exist only there):
#   xcodebuild build -project ../../Pesolita.xcodeproj -scheme Pesolita \
#     -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath <dir>
#   ./record.sh <dir>/Build/Products/Debug-iphonesimulator/Pesolita.app
set -e
APP="$1"
BUNDLE="com.pesolita.app"
OUT="$(cd "$(dirname "$0")" && pwd)/recordings"
mkdir -p "$OUT"
U=$(xcrun simctl list devices available | grep "iPhone 17 Pro Max (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
xcrun simctl boot "$U" 2>/dev/null || true
xcrun simctl bootstatus "$U" -b >/dev/null
xcrun simctl install "$U" "$APP"
xcrun simctl status_bar "$U" override --time "9:41" --dataNetwork wifi --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
xcrun simctl ui "$U" appearance dark

rec() {  # name, seconds, launch args...
  local name=$1 secs=$2; shift 2
  xcrun simctl terminate "$U" "$BUNDLE" 2>/dev/null || true; sleep 1
  xcrun simctl io "$U" recordVideo --codec=h264 --force "$OUT/$name.mov" >/dev/null 2>&1 &
  local rp=$!; sleep 1.2
  xcrun simctl launch "$U" "$BUNDLE" --demo-wallet --store --theme=dark "$@" >/dev/null
  sleep "$secs"; kill -INT $rp; wait $rp 2>/dev/null || true
  echo "recorded $name"
}

rec home  10
rec split 10 --sheet=split --demo-type
rec event  8 --route=event
rec owed   9 --demo-expand
rec slide  8 --settle --demo-slide
xcrun simctl status_bar "$U" clear
# The in-points in compose.py assume the app appears ~3 s into each clip; check a frame if
# the simulator is slower or faster than usual.
