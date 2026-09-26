#!/bin/zsh
# Records the extra app clips for the curiosity ads (curious_ad.py) into recordings/.
# owed.mov and slide.mov come from record.sh. Needs a Debug build (the --store and --demo-*
# hooks exist only there):
#   ./record_curious.sh <dir>/Build/Products/Debug-iphonesimulator/Pesolita.app
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

rec insights  9 --tab=insights
rec safe      8
rec coffee   10 --sheet=coffee
rec swipe    10 --demo-swipe
rec detail    7 --route=detail
rec templates 13 --route=editor --demo-templates
rec theme    11 --demo-theme
rec people    8 --route=people
xcrun simctl status_bar "$U" clear
# The simulator stops writing frames once the screen is still, so the static clips (insights,
# safe, detail, people) are only ~3 s long; curious_ad.py holds their last frame.
