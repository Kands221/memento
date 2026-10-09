#!/bin/zsh
# Audible speech-to-text check in the simulator: the Mac says a sentence out loud, the simulator's
# microphone (your Mac's mic) hears it, Memento transcribes it on device and Sol answers aloud.
# Usage: scripts/hear-sol.sh ["Simulator name" | device:"iPhone name" TEAM_ID]
#   Keep the Mac's speakers on and the room quiet; for a device, keep it unlocked next to the speakers.
# Note: the iOS Simulator's on-device speech model fails to load ("Failed to initialize recognizer"),
# so dictation can't work there; use a real iPhone.
set -u
DEST=${1:-"iPhone 17 Pro"}
TEAM=${2:-}
if [[ $DEST == device:* ]]; then
  DESTINATION="platform=iOS,name=${DEST#device:}"
  EXTRA=(-derivedDataPath build/DD-device -allowProvisioningUpdates DEVELOPMENT_TEAM=$TEAM)
else
  DESTINATION="platform=iOS Simulator,name=$DEST"
  EXTRA=(-derivedDataPath build/DD)
fi
SENTENCE="Work has been a lot this week, but a long walk at lunch helped me settle."
cd "$(dirname "$0")/.."
LOG=$(mktemp -t hear-sol).log
TEST_RUNNER_MEMENTO_SPEAK=1 xcodebuild -project Memento.xcodeproj -scheme Memento \
  -destination "$DESTINATION" "${EXTRA[@]}" \
  test -only-testing:MementoUITests/RealAITests/testLiveSpeechToSol > "$LOG" 2>&1 &
TEST=$!
echo "Building and launching Memento on $DEST…"
for _ in {1..600}; do
  grep -q "MIC_ON" "$LOG" && break
  kill -0 $TEST 2>/dev/null || break
  sleep 0.5
done
if grep -q "MIC_ON" "$LOG"; then
  sleep 1.5
  echo "Speaking: \"$SENTENCE\""
  say -r 165 "$SENTENCE"
fi
wait $TEST
STATUS=$?
grep -E "HEARD:|SOL:|error: -|Test Case .*(passed|failed|skipped)" "$LOG" | sed 's/^.*\(HEARD:\)/\1/; s/^.*\(SOL:\)/\1/'
echo "Full log: $LOG"
exit $STATUS
