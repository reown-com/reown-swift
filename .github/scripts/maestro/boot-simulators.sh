#!/bin/bash
# Creates and boots the iOS simulators for the Maestro Pay suite. Ported from
# react-native-examples' walletkit-build-and-maestro "Boot iOS Simulator" step.
# Each fresh simulator is slimmed with simslim before its first boot (~2.3 GB
# vs ~5.5 GB stock).
#
# Env:
#   SIMULATORS       number of simulators (1-9, default 2); the suite is split
#                    across them (maestro-suite.sh, --shard-split)
#   SIMSLIM_PROFILE  simslim profile (default: simslim-ci.json next to this file)
# Exports DEVICE_IDS (comma-separated) and DEVICE_ID (first device) to
# $GITHUB_ENV.

set -euo pipefail

SIMULATORS="${SIMULATORS:-2}"
SIMSLIM_PROFILE="${SIMSLIM_PROFILE:-$(cd "$(dirname "$0")" && pwd)/simslim-ci.json}"
GITHUB_ENV="${GITHUB_ENV:-/dev/null}"
ERR_FILE="$(mktemp)"
trap 'rm -f "$ERR_FILE"' EXIT

if ! [[ "$SIMULATORS" =~ ^[1-9]$ ]]; then
  echo "::error::SIMULATORS must be 1-9, got '$SIMULATORS'"
  exit 1
fi

# Don't hardcode a model: Xcode/runner image bumps drop old devices. Create
# fresh devices from the newest iPhone device type, falling back to one
# already-available iPhone simulator. `simctl list devicetypes` is
# newest-first, so take the first match. Filter by name too: the iPod touch
# also has productFamily "iPhone" (and current runtimes can't create it).
DEVICE_TYPE=$(xcrun simctl list devicetypes -j |
  jq -r 'first(.devicetypes[] | select(.productFamily == "iPhone" and (.name | startswith("iPhone"))) | .identifier) // empty')
DEVICE_IDS=()
for i in $(seq 1 "$SIMULATORS"); do
  if [ -n "$DEVICE_TYPE" ] && ID=$(xcrun simctl create "E2E-iPhone-$i" "$DEVICE_TYPE" 2>"$ERR_FILE"); then
    DEVICE_IDS+=("$ID")
  else
    break
  fi
done
FRESH=true
if [ "${#DEVICE_IDS[@]}" -eq 0 ]; then
  echo "::warning::Could not create a simulator from '${DEVICE_TYPE:-<none>}' ($(cat "$ERR_FILE")); falling back to an existing iPhone simulator"
  DEVICE_TYPE=""
  FRESH=false
  ID=$(xcrun simctl list devices available -j |
    jq -r '.devices | to_entries[] | select(.key | contains("iOS")) | .value[] | select(.name | startswith("iPhone")) | .udid' | head -1)
  [ -n "$ID" ] && DEVICE_IDS=("$ID")
fi
if [ "${#DEVICE_IDS[@]}" -eq 0 ]; then
  echo "ERROR: no available iPhone simulator found"
  xcrun simctl list devices available
  exit 1
fi
if [ "${#DEVICE_IDS[@]}" -lt "$SIMULATORS" ]; then
  echo "::warning::Only ${#DEVICE_IDS[@]} of $SIMULATORS simulators available; running on ${#DEVICE_IDS[@]}"
fi
echo "Using simulator device type: ${DEVICE_TYPE:-<fallback>}, ids: ${DEVICE_IDS[*]}"

# Slim and boot all devices in parallel. simslim writes its overrides while
# the device is still off, so the existing-simulator fallback boots stock.
PIDS=()
for ID in "${DEVICE_IDS[@]}"; do
  if [ "$FRESH" = "true" ]; then
    # Boots the device slim; fails on drift rather than silently testing on a
    # stock simulator.
    ( simslim on "$ID" --profile "$SIMSLIM_PROFILE" &&
        simslim verify "$ID" --profile "$SIMSLIM_PROFILE" ) &
  else
    ( xcrun simctl boot "$ID" 2>/dev/null || true ) &
  fi
  PIDS+=($!)
done
for PID in "${PIDS[@]}"; do wait "$PID"; done

for ID in "${DEVICE_IDS[@]}"; do
  # Wait for full boot so the steps below don't race a not-ready simulator.
  xcrun simctl bootstatus "$ID" -b
  # Disable UIKit animations to reduce Maestro timing flakiness.
  xcrun simctl spawn "$ID" defaults write com.apple.UIKit UIAnimationDragCoefficient 0 || true
  # A never-booted device posts a one-time "Ready for Apple Intelligence"
  # follow-up notification a few minutes after its first boot, which can cover
  # the button Maestro is about to tap. The workflow boots before the build so
  # it fires and auto-dismisses then; as a backstop, stamp the key iOS sets when
  # it posts the follow-up (verified against a sim's CoreFollowUp items.db) so it
  # counts as already shown. Best-effort: not every runner image allows it.
  xcrun simctl spawn "$ID" defaults write \
    com.apple.generativeexperiences.corefollowup \
    DateOfLastAppleIntelligenceReadinessCFU -date "$(date -u '+%Y-%m-%d %H:%M:%S +0000')" ||
    echo "WARNING: could not pre-seed Apple Intelligence CFU timestamp on $ID (non-fatal)"
done

echo "DEVICE_ID=${DEVICE_IDS[0]}" >> "$GITHUB_ENV"
echo "DEVICE_IDS=$(IFS=,; echo "${DEVICE_IDS[*]}")" >> "$GITHUB_ENV"
