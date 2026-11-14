# HiMorning iOS 1.0 distribution

Status: Subscription candidate 1.0 (2) is Testing in HiMorning Internal.
The tester invitation is pending acceptance on iPhone.
Updated 2026-11-08 (UTC+07:00).

## Purpose

Prepare an iPhone Release candidate for internal TestFlight. Use the build that
passes device, billing and distribution checks for the initial App Store
submission, then release manually after approval.

## Lead brief

The first release is for iPhone users on iOS 26 or later who want an alarm
with a short morning activity. Use the established App ID and the shipped
SwiftUI, AlarmKit, local storage, and StoreKit paths from GitHub main.
An existing development install makes the first TestFlight run practical,
but the actual release must prove alarm delivery and restore purchases.

- Use an internal TestFlight group first. A simulator run covers UI and
  domain behavior, while an iPhone on the distributed build covers the OS
  alarm, microphone, camera, and real StoreKit sandbox paths.
- Keep the existing local-first design and optional Pro scope. A paid
  inference rollout would add a separate operating and privacy burden with
  no dependency from core alarm or challenge flows.
- Use the archived build as an internal candidate. Select a build for App
  Review only after the device matrix, subscription and metadata gates
  pass. Ship manually after Apple approval.

## Acceptance

- [x] L0: A generic iPhone Release archive succeeds and contains the expected
  bundle identifier, version, permissions, and privacy manifest.
- [x] L1 (core): Portable Swift core and integration journeys pass.
- [x] L1 (native): All 83 native XCTest cases pass on the iOS 27.0 simulator.
- [x] L3 (first morning): First-use practice, recent wins, and large
  Vietnamese text pass as UI tests on the iPhone 18 Pro simulator.
- [x] L3 (subscription): StoreKit lifecycle tests and both checkout/recovery
  UI journeys pass on the iOS 27.0 simulator.
- [ ] L4: Verify alarms, permission recovery and on-device challenges on a
  physical iPhone. Record device, OS, build and observations.
- [ ] L5: App Store Connect processes the signed build; install it from internal
  TestFlight and pass device smoke and sandbox subscription checks.
- [ ] App Review: Required metadata, public policy/support pages, privacy
  answers, screenshots, build and first subscriptions are accepted by Apple.
- [ ] Production: Owner releases the approved version and verifies availability.

## Milestones

1. Confirm release scope, app identity, toolchain and enrollment access.
2. Prepare reproducible Release checks, archive and submission materials.
3. Run TestFlight, device alarms and sandbox billing acceptance.
4. Submit the accepted build for App Review and release after approval.

## Progress

- 2026-11-07: Verified GitHub `main` matches the clean base
  `51fba07c31c90e7d932d02ac493b373b801ce4b8`. Work is isolated in the
  `HiMorning-release` checkout. App Store Connect redirected to sign-in.
- 2026-11-08: GitHub main still matches the candidate base. The existing
  Apple Developer App ID is `com.himorning.HiMorning` under
  `3JG2QB4549`. A matching App Store Connect record remains unverified.
- 2026-11-08: `make ios-core-test` exited 0. Portable core tests and journeys
  passed. The coverage report counted 1,351 of 1,394 Swift core lines
  (96.92%). See `.build/artifacts/ios-core-test.log`.
- 2026-11-08: `make ios-archive TEAM_ID=3JG2QB4549 VERSION=1.0 BUILD_NUMBER=1`
  exited 0 on Xcode 27.2. Verified the signed
  `.build/artifacts/HiMorning-1.0-1.xcarchive` as `com.himorning.HiMorning`,
  `1.0 (1)`, team `3JG2QB4549`, with device family `[1]` (iPhone) and
  minimum iOS 26.0. The app contains a valid privacy manifest. The optional
  GoogleService and HiMorningCloud configuration files are absent. macOS
  strict signature verification passed with Apple Development signing.
- 2026-11-08: XcodeGen's default target setting overrode the project-level
  iPhone family. The target now declares the family explicitly. A plist
  inspection command wrote to the first archive, so it was quarantined
  locally and rebuilt from source before signature verification.
- 2026-11-08: iOS 26.2 XCTest compiled but exited 65 after simulator boot
  timed out. The same device failed the explicit boot preflight because
  `launchd_sim` did not respond. See `.build/artifacts/ui.OI07DP/test.log`.
  The separate iPhone 18 Pro simulator on iOS 27.0 booted successfully
  with the preflight.
- 2026-11-08: On iOS 27.0, the combined native run recorded 58 passed tests
  before stalling in `SpokenExampleTests.testExampleBlocksAnotherPlaybackUntilFinish`.
  It was interrupted after more than 2 minutes on that test. StoreKit expiry
  was not reverified. The cause of the speech-test stall is unconfirmed.
- 2026-11-08: `make -o ios-project ios-uitest IOS_SIM=280730DA-FB0B-450F-A41E-4A179EE3800F ONLY=HiMorningUITests/FirstMorningUITests`
  exited 0. All 3 tests passed in 103.157 seconds as reported by XCTest.
  Result bundle: `.build/artifacts/ui.KVDucX/himorning-ui.xcresult`.
- 2026-11-08: On `c3b1a94`, ran `make ios-uitest` on iPhone 18 Pro Max
  simulator iOS 27.0 with `ONLY=HiMorningTests` and
  `ONLY=HiMorningUITests/SubscriptionUITests`. Both exited 0. XCTest reported
  83 native cases and two UI cases passed. Evidence:
  `.build/artifacts/ui.f9slRV/test.log` and `.build/artifacts/ui.GKzU0v/test.log`.
- 2026-11-08: App Store Connect record `6832167976` matches
  `com.himorning.HiMorning`. It already had internal build 1. Created
  `HiMorning Internal` with manual build distribution for build 2.
- 2026-11-08: `make ios-archive TEAM_ID=3JG2QB4549 VERSION=1.0 BUILD_NUMBER=2`
  exited 0. Verified the bundle ID, version, iPhone family, privacy manifest,
  and strict code signature in `.build/artifacts/HiMorning-1.0-2.xcarchive`.
  The archive has no `.storekit` fixture or optional Firebase configuration.
- 2026-11-08: `make ios-testflight TESTFLIGHT_ARCHIVE=<archive-path>` exited
  with Xcode export error 70 (`Failed to Use Accounts`). See
  `.build/artifacts/testflight.oBeqwy/upload.log`. The native Xcode Organizer
  accepted the existing account and confirmed `HiMorning 1.0 (2) uploaded`
  via **TestFlight Internal Only**.
- 2026-11-08: App Store Connect processed build 2 and shows **Missing
  Compliance**. The `HiMorning Internal` group contains the account holder
  as its only tester. Build assignment waits for export compliance.
- 2026-11-08: The owner completed export compliance. App Store Connect shows
  build 2 as **Ready to Test**. The last group check showed one tester and
  zero builds. Chrome tab changes interrupted the assignment.
- 2026-11-08: App Store Connect shows build 2 **Testing** in
  `HiMorning Internal`. **TestFlight → Testers → All** shows the account
  holder as **Invited**, awaiting acceptance before iPhone installation.

## Decision Log

- 2026-11-07: Use the existing `com.himorning.HiMorning` identifier and
  iPhone/iOS 26+ target; verify ownership before registering a new app record.
- 2026-11-07: Use bundled content and local alarm and challenge paths for this
  candidate. Keep experimental cloud configuration out of the archive. This
  uses the documented credential-free setup and needs no backend deployment.
- 2026-11-07: Keep the existing Pro scope; validate both products before
  submitting. The first Pro subscriptions go with version 1.0.
- 2026-11-08: Distribute build 2 as TestFlight Internal Only with manual
  assignment to the owner. Use a separate build for external testing or release.

## NEEDS_HUMAN

- Open Apple's invitation email on iPhone, select **View in TestFlight**,
  accept the invitation, and install build `1.0 (2)` from TestFlight.
- The owner selected `danhvt0109@gmail.com` for public support. Review and
  publish the [bilingual privacy and support copy](../HIMORNING-PRIVACY-AND-SUPPORT.md)
  on a public HTTPS URL. The public GitHub repository can host the Markdown
  through its main branch using the existing GitHub account. Confirm
  localized pricing and initial storefronts before submission.
- Install from TestFlight on an iPhone and verify the physical device checklist.
- Release the approved app in App Store Connect after reviewing the submission.

Use the [submission draft](../HIMORNING-APP-STORE-SUBMISSION.md) for listing
copy, reviewer instructions and first subscription IDs.

## Report

Signed iPhone archive, portable checks, 83 native tests, and both subscription
UI cases passed. L3 covers first-use and subscription flows on iOS 27.0.
Apple processed the internal upload and build 2 is available to the internal
group. L5 and App Review remain open. Accept the invitation and install build 2.
Installing through TestFlight can replace the development install without a
prior uninstall.

## Risks

Development signing and launch evidence does not validate distribution signing or
alarm delivery. The existing StoreKit expiry test has a documented failure.
TestFlight and App Store use Apple processing and review outside this repository.
