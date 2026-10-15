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
      -only-testing:HiMorningUITests/ChallengeCelebrationUITests/testReadingSuccessCelebratesAndReturnsHomeInBothLanguages \
      -only-testing:HiMorningUITests/ChallengeCelebrationUITests/testAwakeConfirmationCountsDownBeforeEnabling
    ;;
  workflow_dispatch) set -- ;;
  *) echo 'Expected push or workflow_dispatch' >&2; exit 64 ;;
esac
exec xcodebuild -project apps/ios/HiMorning.xcodeproj -scheme HiMorning \
  -destination "platform=iOS Simulator,id=$TASK_SIMULATOR" \
  -derivedDataPath "${RUNNER_WORKSPACE:?}/himorning-derived" \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- \
  -collect-test-diagnostics never -showBuildTimingSummary \
  -resultBundlePath "${RUNNER_TEMP:?}/himorning-ui.xcresult" "$@" test
