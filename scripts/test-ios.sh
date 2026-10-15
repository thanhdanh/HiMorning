#!/bin/sh
set -eu
TASK_SIMULATOR=${1:?Pass an iPhone simulator UDID}
case "${2:-push}" in
  push)
    set -- -only-testing:HiMorningTests \
      -only-testing:HiMorningUITests/PilotUITests/testEnglishGentleDefaultAndCancelWithoutPermissions \
      -only-testing:HiMorningUITests/PilotUITests/testVietnameseGentleDefaultAndCancelWithoutPermissions \
      -only-testing:HiMorningUITests/PilotUITests/testReadingPracticeCompletesOfflineInBothLanguages \
      -only-testing:HiMorningUITests/DeviceFixesUITests/testSaveWaitsAndRetainsEditorOnFailure \
      -only-testing:HiMorningUITests/DeviceFixesUITests/testEnabledAlarmChallengeEditClosesAndKeepsTheNewChoiceInBothLanguages \
      -only-testing:HiMorningUITests/DeviceFixesUITests/testDisabledAlarmIsCompactAndCanBeEditedAndDeletedInBothLanguages \
      -only-testing:HiMorningUITests/DeviceFixesUITests/testActiveAlarmShowsChallengeModeAndKeepsDeleteInTheFooter \
      -only-testing:HiMorningUITests/PilotUITests/testProgressDayModesAndChallengeDetailsInBothLanguages \
      -only-testing:HiMorningUITests/ChallengeCelebrationUITests/testRealAlarmCompletionReturnsHomeAndMarksOnlyThatAlarmInBothLanguages \
      -only-testing:HiMorningUITests/ChallengeCelebrationUITests/testReadingSuccessCelebratesAndReturnsHomeInBothLanguages \
      -only-testing:HiMorningUITests/ChallengeCelebrationUITests/testReadAloudRetryKeepsTheSentenceAndClearsThePreviousScore \
      -only-testing:HiMorningUITests/ChallengeCelebrationUITests/testAwakeConfirmationCountsDownBeforeEnabling
    ;;
  workflow_dispatch) set -- ;;
  *) echo 'Expected push or workflow_dispatch' >&2; exit 64 ;;
esac
TASK_DERIVED="${RUNNER_WORKSPACE:?}/himorning-derived"
TASK_PACKAGES="$TASK_DERIVED/SourcePackages"
TASK_RESOLVE_LOG="${RUNNER_TEMP:?}/himorning-packages.log"
resolve_packages() {
  xcodebuild -resolvePackageDependencies -project apps/ios/HiMorning.xcodeproj \
    -scheme HiMorning -derivedDataPath "$TASK_DERIVED"
}
TASK_RESOLVE_EXIT=0
resolve_packages > "$TASK_RESOLVE_LOG" 2>&1 || TASK_RESOLVE_EXIT=$?
cat "$TASK_RESOLVE_LOG"
if [ "$TASK_RESOLVE_EXIT" -ne 0 ]; then
  case "$(cat "$TASK_RESOLVE_LOG")" in
    *"file not found at path: $TASK_PACKAGES/artifacts/firebase-ios-sdk/"*".zip"*)
      rm -f "$TASK_PACKAGES/workspace-state.json"
      rm -rf "$TASK_PACKAGES/artifacts/firebase-ios-sdk"
      resolve_packages
      ;;
    *) exit "$TASK_RESOLVE_EXIT" ;;
  esac
fi
exec xcodebuild -project apps/ios/HiMorning.xcodeproj -scheme HiMorning \
  -destination "platform=iOS Simulator,id=$TASK_SIMULATOR" \
  -derivedDataPath "$TASK_DERIVED" \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- \
  -collect-test-diagnostics never -showBuildTimingSummary \
  -resultBundlePath "${RUNNER_TEMP:?}/himorning-ui.xcresult" "$@" test
