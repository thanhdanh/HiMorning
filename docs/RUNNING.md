# Run HiMorning

Build and test the local iOS app without server credentials. Cloud references
have separate setup; they are not prerequisites for alarm or camera use.

**Status:** iOS 26+ development pilot. **Audience:** Contributors and pilot maintainers.

## Prerequisites

| Work | Tools |
|---|---|
| TypeScript checks | Node 22 and pnpm 10.34.6 from `package.json` |
| Firestore Emulator | Java 21 in addition to the Node toolchain |
| Swift core | Apple's Swift toolchain; full Xcode for native tests |
| Native app | Xcode with the iOS 26+ SDK, XcodeGen and an available iPhone simulator |
| Physical device | iOS 26+, Developer Mode, a signing team and a connected/unlocked iPhone |

Run commands from your repository root. Generated Xcode project and Info.plist
files are ignored; regenerate them after cloning.

## Local checks

```sh
corepack enable
pnpm install --frozen-lockfile
pnpm run typecheck
pnpm test
pnpm run build
pnpm run build:worker
sh scripts/test-swift.sh
swift test --package-path apps/ios/HiMorningCore
```

`pnpm test` excludes Firestore integration tests. To include real emulator
transactions/rules and coverage, run `pnpm run test:coverage` with Java 21. It
uses the safe `demo-himorning` project and mocked inference, not paid AI.
For Python setup and tests, use the [inference reference](REMOTE-PILOT.md).

The portable Swift runner compiles the same core test bodies with lightweight
assertions; SwiftPM runs XCTest. Neither validates a physical camera feed.
See [Validation](VALIDATION.md) for the latest recorded results and known failure.

## Simulator

```sh
xcodegen generate --spec apps/ios/project.yml
xcrun simctl list devices available
open apps/ios/HiMorning.xcodeproj
```

Choose an available iPhone in Xcode. For an explicit native test run, substitute
its UDID and use a new result-bundle path each time:

```sh
xcodebuild -project apps/ios/HiMorning.xcodeproj -scheme HiMorning   -destination 'platform=iOS Simulator,id=YOUR_SIMULATOR_UDID'   -parallel-testing-enabled NO -collect-test-diagnostics never   CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-   -resultBundlePath /tmp/himorning-native-review.xcresult test
```

Native tests need ad-hoc simulator signing for Keychain preview storage. Do not
use `CODE_SIGNING_ALLOWED=NO` for those tests. CI currently selects iOS 26.2;
this does not eliminate the [known StoreKit expiry failure](VALIDATION.md#known-failure).
Use [the CI guide](SELF-HOSTED-CI.md) for the push/manual test selection.

## Physical iPhone

Select the existing Apple development team in Xcode, enable automatic signing,
and choose the connected device. Build and Run, then unlock the iPhone if launch
is blocked. Basic local features work without Firebase plist files.

An equivalent command uses your actual device ID and team:

```sh
xcodebuild -project apps/ios/HiMorning.xcodeproj -scheme HiMorning   -configuration Debug -destination 'platform=iOS,id=YOUR_DEVICE_UDID'   -derivedDataPath /tmp/himorning-device-build -allowProvisioningUpdates   CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=YES CODE_SIGN_STYLE=Automatic   DEVELOPMENT_TEAM=YOUR_TEAM_ID CODE_SIGN_IDENTITY='Apple Development' build
xcrun devicectl device install app --device YOUR_DEVICE_UDID   /tmp/himorning-device-build/Build/Products/Debug-iphoneos/HiMorning.app
xcrun devicectl device process launch --device YOUR_DEVICE_UDID   --activate --terminate-existing com.himorning.HiMorning
```

Install over the existing app to preserve alarms and local history. If iOS says
“No Longer Available”, inspect development provisioning/signing and rebuild;
the previously observed cause was an expired development profile. Do not assume
that every launch failure has that cause. A locked device needs unlocking before
launch. A clean build can resolve stale sealed-resource state after asset changes.

## Try the experience

Home lets you explore challenges. In an alarm draft, double-tap a challenge and
confirm the trial. Trials do not schedule, stop or save a real alarm, and returning
retains the draft. A camera trial still requires camera consent. Use EN/VI, large
text and reduced motion/transparency while reviewing the interface.

For real alarm acceptance, schedule deliberately and test system Stop, the
+2-minute backup, completion cancellation and the delayed self-confirmation.
The full matrix is in [release readiness](RELEASE-READINESS.md).

## Optional references

- [Content and challenges](MODE-CHALLENGES.md): bundled content works offline;
  a configured Worker origin enables optional pack refresh.
- [Free synthetic demo](FREE-REMOTE-DEMO.md): Auth/App Check and generated images;
  deployment records are historical, not a claim of current service availability.
- [Firebase/Modal](REMOTE-PILOT.md): separate paid evaluation and deployment.
- [Web design study](../design/index.html): `python3 scripts/preview.py` serves it
  at `http://127.0.0.1:4173/design/`. Its simulated controls do not schedule alarms.

## Read next

[Documentation index](README.md) · [Validation](VALIDATION.md) ·
[Subscriptions](SUBSCRIPTIONS.md) · [Resource provenance](../apps/ios/Resources/README.md)
