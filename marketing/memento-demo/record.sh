#!/bin/zsh
# Records the demo scenes from the "Memento Demo" simulator, with live on-device AI, into footage/.
# Usage: marketing/memento-demo/record.sh [Scene1Journal Scene2Write ...]
set -u
cd "$(dirname "$0")/../.."
HERE=marketing/memento-demo
OUT=$HERE/footage
mkdir -p $OUT
UDID=$(xcrun simctl list devices | grep "Memento Demo" | grep -oE "[0-9A-F-]{36}" | head -1)
[ -z "$UDID" ] && { echo "Create the 'Memento Demo' simulator first (iPhone 17 Pro, iOS 26.5)."; exit 1; }
xcrun simctl bootstatus $UDID -b > /dev/null
xcrun simctl status_bar $UDID override --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
xcodebuild build-for-testing -project Memento.xcodeproj -scheme Memento -destination "id=$UDID" \
  -derivedDataPath build/DD-demo -quiet || exit 1
if (( $# )); then SCENES=("$@"); else SCENES=(Scene1Journal Scene2Write Scene3FindAgain Scene4Sol Scene5Summary); fi
TAKE=${TAKE:-}
for test in $SCENES; do
  scene=$test$TAKE
  rm -f $OUT/$scene.mov $OUT/$scene.rec
  xcrun simctl io $UDID recordVideo --codec=h264 --force $OUT/$scene.mov > $OUT/$scene.rec 2>&1 &
  REC=$!
  until grep -q "Recording started" $OUT/$scene.rec 2>/dev/null; do sleep 0.05; done
  python3 -c 'import time; print(time.time())' > $OUT/$scene.start
  TEST_RUNNER_MEMENTO_DEMO=1 xcodebuild test-without-building -project Memento.xcodeproj -scheme Memento \
    -destination "id=$UDID" -derivedDataPath build/DD-demo \
    -only-testing:MementoUITests/DemoRecording/test$test > $OUT/$scene.log 2>&1
  STATUS=$?
  kill -INT $REC; wait $REC 2>/dev/null
  echo "$scene: $([ $STATUS -eq 0 ] && echo ok || echo FAILED) $(grep -E 'SOL_REPLY|SOL_CITED' $OUT/$scene.log | head -2 | tr '\n' ' ')"
done
