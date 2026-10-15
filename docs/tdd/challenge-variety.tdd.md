# Challenge variety — TDD evidence

Date: 2026-10-15

## Purpose and status

Record the approved challenge-variety behavior and its verification. Core and
native implementation are complete. All 13 native capture/UI regression tests
passed on the isolated simulator. The user approved Gate 2 and the feature-only
commit on `codex/challenge-variety`.

## Changed behavior

- `ChallengeSelection` is independent of `WakeMode` and supports no challenge, push-ups, read-and-choose, guided rhythm, and read-aloud.
- Existing alarms without a `challenge` field migrate deterministically: Gentle → none, Balanced → 3 push-ups, Focused → 5 push-ups. The ordinary initializer uses the same defaults, while an explicit challenge can differ from the mode.
- Push-up repetitions are bounded to the backend contract of 1...5.
- Local challenge completion produces `WakeOutcome.localCompleted` and invalidates a pending cloud generation.
- Read-aloud success uses normalized recognized-word token edit distance with a passing score of `>= 0.80`. It intentionally does **not** claim to measure accent or phoneme quality.
- Guided rhythm supports standing and seated sequences. It resets for occlusion, interruption, non-increasing timestamps, an expired sequence window, or a wrong pose. Its domain API accepts pose labels and timestamps only; it does not accept or store images.
- English challenge choices are localization keys. No Vietnamese display copy is embedded in the Swift domain model.

## RED

Tests were changed before implementation in `CoreTests.swift` and `TestsPortable/main.swift`.

Exact command:

Working directory: `apps/ios/HiMorningCore`.

```sh
env CLANG_MODULE_CACHE_PATH=/private/tmp/himorning-challenges-clang-cache SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/himorning-challenges-clang-cache SWIFTPM_CUSTOM_CACHE_PATH=/private/tmp/himorning-challenges-swiftpm-cache swift test --scratch-path /private/tmp/himorning-challenges-swiftpm
```

Result: exit 1. The test target failed to compile for the new specification, including these expected errors:

```text
value of type 'SavedAlarm' has no member 'challenge'
extra argument 'challenge' in call
value of type 'WakeSession' has no member 'completeLocally'
type 'WakeOutcome?' has no member 'localCompleted'
cannot find 'RecognizedWordMatch' in scope
cannot find 'GuidedRhythmSession' in scope
```

An earlier sandboxed attempt failed before compiling the package because SwiftPM could not write its default module cache. It was not counted as the behavioral RED; the command above was rerun with writable caches and outside that sandbox to capture the real compile-time RED.

## GREEN

Latest XCTest command (repository root):

```sh
env CLANG_MODULE_CACHE_PATH=/private/tmp/himorning-challenges-clang-cache SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/himorning-challenges-clang-cache SWIFTPM_CUSTOM_CACHE_PATH=/private/tmp/himorning-challenges-swiftpm-cache swift test --package-path apps/ios/HiMorningCore --scratch-path /private/tmp/himorning-challenges-swiftpm
```

Result: exit 0; 17 tests executed, 0 failures, 0 unexpected failures.

Exact portable/coverage command:

```sh
env CLANG_MODULE_CACHE_PATH=/private/tmp/himorning-challenges-clang-cache sh scripts/test-swift.sh
```

Result: exit 0; after the local/cloud privacy-boundary integration journey was added, the executable printed `PASS: 27 portable Swift domain and integration journeys`. Source coverage was 87.28% by region and 98.05% by line. Relevant file region coverage: `Challenge.swift` 87.84%, `Cloud.swift` 71.43%, `Module.swift` 100%, and `Pilot.swift` 82.58%.

The guided-rhythm runtime follow-up was also test-first. Its RED used the XCTest command above and failed because `GuidedRhythmPose` had no `armsUp`/`armsDown` cases. GREEN passed all 17 XCTest cases after seated rhythm became arms-down → arms-up → arms-down and repeated same-pose camera frames were debounced.

## Tests added

- `testChallengeDefaultsPreserveLegacyModeBehaviorButRemainIndependent`
- `testSavedAlarmDecodesLegacyPayloadAndRoundTripsExplicitChallenge`
- `testLocalCompletionInvalidatesPendingCloudResult`
- `testRecognizedWordScoreUsesNormalizedTokenEditDistanceAndPassesAtEightyPercent`
- `testCuratedEnglishChallengesAreValidAndStable`
- `testGuidedRhythmSupportsStandingAndSeatedWithoutImageEvidence`
- `testGuidedRhythmResetsOnOcclusionOutOfOrderAndExpiredWindow`
- Portable equivalents for defaults/bounds, persistence migration, local completion, word matching, and rhythm state transitions

## Native implementation and regression

- The editor persists the selected challenge independently of the mode. Changing
  a mode updates its legacy default only until a challenge is explicitly chosen.
- Home rehearsal offers every challenge without scheduling an alarm or recording
  progress. Saved alarm cards display the selected challenge.
- Read & Choose localizes answer meanings and keeps the learning sentence in
  English. Each curated prompt has its own correct answer index.
- Read Aloud requires on-device English speech recognition, requests speech and
  microphone access, and never falls back to server recognition. Its transient
  audio buffers are not saved. Final/error/timeout/interruption paths stop audio
  and allow another attempt.
- Guided Rhythm uses local Vision observations without JPEG generation, image
  buffering, or cloud calls. Standing uses side-view knee bends; the seated option
  uses bilateral arm movements. Image aspect ratio is applied when measuring
  joint angles. Occlusion and capture interruptions reset the pending sequence.
- Stop and self-confirm remain available. Generation checks reject stale capture
  callbacks and cloud-start continuations after stopping or backgrounding.
- Native capture tests cover image aspect ratio and stopped-before-start behavior.

`pnpm check` passed: TypeScript, all 53 non-emulator tests, and the backend build.
The localization suite passed all four tests, including permission declarations
and curated prompt-resource coverage. The installed Node runtime is v24.21.0;
the backend declares Node 22 and emitted an engine warning.

UI runs on shared simulator `280730DA-FB0B-450F-A41E-4A179EE3800F` were not accepted
as final regression evidence: another Xcode process concurrently installed the
same application/test runner on that simulator. A result even included
`testExpiredPreviewKeepsBasicAlarmChoicesInBothLanguages`, which is absent from
this worktree. Final testing uses dedicated simulator
`7584A161-6635-46AC-B779-4680318A4FA7` (HiMorning Challenges, iPhone 18 Pro/iOS 27).

```sh
xcodegen generate --spec apps/ios/project.yml
xcodebuild test \
  -project apps/ios/HiMorning.xcodeproj -scheme HiMorning \
  -destination 'platform=iOS Simulator,id=7584A161-6635-46AC-B779-4680318A4FA7' \
  -derivedDataPath .build/xcode \
  -only-testing:HiMorningUITests -only-testing:HiMorningTests/ChallengeCaptureTests \
  -parallel-testing-enabled NO -collect-test-diagnostics never -quiet
```

Final result: exit 0, 13 tests passed, 0 failed, 0 skipped, and no reported runtime
warnings. The result bundle is
`.build/xcode/Logs/Test/Test-HiMorning-2026.10.15_09-17-26-+0700.xcresult`.
This integration run includes the 11-case UI suite (including the pre-existing,
user-owned sound-preview test) plus both native capture unit tests.
The UI suite covers EN/VI rehearsal completion and recovery, all five editor
choices, mode/default target consistency, preserving an explicitly selected
challenge, and Stop availability before requesting permissions.

After selective staging, an independent checkout of the Git index was generated
with `git checkout-index --all --prefix=...` and built with XcodeGen/Xcode. The
feature-only app build passed (exit 0), with the original AVAudioPlayer preview
and alert binding unchanged and without a SoundPreview.swift dependency. Xcode 27
emitted linker warnings about an ambiguous target atom; it did not report a link
or build failure. No challenge source changed after the passing integration run.

## Review and remaining device checks

Code and security reviews found no unresolved actionable findings. Review fixes
include synchronizing displayed/default push-up targets, disabling starts while
stopping, retaining capture teardown until it finishes, invalidating pending
permission startup, and guarding a suspended cloud startup before camera creation.

Live on-device speech availability, recognition behavior with different speakers,
and camera movement thresholds still need a physical-iPhone smoke test. Simulator
and deterministic domain tests do not establish recognition accuracy or motion
calibration on real hardware. Sit-ups, ball juggling, and singing remain deferred.

The original repository remains on `codex/pro-monthly`. This feature was developed
in the separate `HiMorning-challenges` worktree from `8b84d88`, initially detached
and then placed on `codex/challenge-variety` after Gate 2 approval.
Pre-existing sound-preview/runtime-warning edits were copied for integration and
remain user-owned. Selective staging excludes the sound-preview refactor and its
test, the unrelated alert-binding change, and the two runtime-warning documents.
The working files retain those edits.

Approved feature commit: `feat(ios): add selectable wake-up challenges`.

## PR #5 integration with main

Merged `origin/main` at `8ad1b72` into the approved feature in a clean,
detached `HiMorning-pr5-integration` worktree. The original feature worktree and
its user-owned edits were left untouched. Conflicts in the editor, challenge
view, app model, portable runner and UI tests retain both feature sets.

- Preview/Pro retain all choices. Free access retains local challenges and caps
  explicit push-ups at three; Focused and premium sound use the existing basic
  fallbacks. Effective-alarm normalization preserves identity, schedule state,
  and the saved choice without rewriting existing persistence.
- The active challenge snapshots its effective alarm once, so expiry cannot
  change the target midway through capture or discard an explicit local choice.
- Editor saves still start preview only after a confirmed schedule. SoundPreview,
  Pro discovery, expired-preview tests and all new challenge tests are retained.
- Two access regression tests were added first. RED failed for the missing
  normalization methods; GREEN passed all 24 core XCTest cases.
- The portable runner passed all 28 journeys with 86.61% region and 95.54% line
  coverage. `pnpm check` passed typechecking, 53 JavaScript tests and backend build.
- Independent bounded code and security reviews found no actionable integration
  regressions. No backend contract, fixture or dependency changes were needed.

The installed Node 24 runtime emits the existing Node 22 engine warning.
Physical-iPhone speech and movement calibration remain unverified.

The initial full native/UI run on iOS 27 executed 30 tests: 19 passed and 11
failed. Ten failing subscription tests could not load StoreKit products, matching
the existing CLI limitation documented in `docs/SUBSCRIPTIONS.md`; CI already
pins iOS 26.2. Only iOS 27 is installed locally, so subscription verification is
not claimed for this integration. The other failure was the new UI test looking
up `Increment` instead of the actual `pushUpTarget-Increment` accessibility ID;
the captured disabled control confirmed that the app already capped free access
at three. The test selector was corrected without changing application code.
The initial result bundle is
`/private/tmp/himorning-pr5-build/Logs/Test/Test-HiMorning-2026.10.15_09-54-53-+0700.xcresult`.

A second run on the previously dedicated simulator was rejected as regression
evidence: it contained `testExpandedSoundCatalogSelectsANewSoundInBothLanguages`,
which is absent from this checkout, and runner processes were terminated. Source
and build-product timestamps remained correct, indicating concurrent simulator
installation/interference rather than a source failure. Final affected-journey
validation uses a newly created simulator `148D3923-73C0-4D3E-BB87-FBD7BA94EA2B`.

The final targeted run exited 0. It reran both native capture tests, all four
PreviewStore tests, the corrected free-limit/local-choice UI test, bilingual
progress/Pro discovery and language persistence. Together with the initial
run's other passing UI cases, all 19 unique challenge/preview/UI cases are
covered by passing results; this is not a claim that the StoreKit suite passed.
The final result reports 9 passed, 0 failed, 0 skipped and no runtime warnings:
`/private/tmp/himorning-pr5-build/Logs/Test/Test-HiMorning-2026.10.15_10-10-05-+0700.xcresult`.
Xcode may prune older bundles from its test log directory automatically.

### Concurrent sounds/speech update

The first safe push was rejected because `d06418c` advanced the same remote
branch while validation ran. That commit was merged, not overwritten or rebased.
It adds the grouped 15-sound catalog, SpeechAnalyzer pipeline and spoken examples.
The follow-up resolution retains the access-aware challenge snapshot and gates
both selection and per-row previews of premium sounds. Duplicate UI methods from
the automatic merge were consolidated, keeping the newer preview identifiers.

Core XCTest now passes 27 cases; the portable harness passes 29 journeys with
86.61% region and 95.54% line coverage. Free sound normalization is asserted for
every premium catalog entry. `pnpm check` again passes all 53 JavaScript tests,
typechecking and backend build. Code/security re-review found no actionable
integration regressions. The incoming speech/audio implementation is preserved;
physical-device validation and the documented StoreKit runtime limitation remain.

The follow-up Xcode run on `148D3923-73C0-4D3E-BB87-FBD7BA94EA2B` exited 0:
29 passed, 0 failed, 0 skipped, and no runtime warnings.
It includes all native tests except the known-incompatible SubscriptionTests,
plus eight affected UI cases: EN/VI editor defaults, the expanded sound catalog,
preview controls, spoken-example privacy/recovery, expired-preview sound gates,
free challenge bounds and offline reading. The result bundle is
`/private/tmp/himorning-pr5-build/Logs/Test/Test-HiMorning-2026.10.15_10-15-56-+0700.xcresult`.
