# Camera push-ups

Start a push-up challenge on an iPhone without server credentials or a network
connection. The front camera feeds on-device body pose recognition; no video,
JPEG archive or audio recording is created.

**Status:** Implemented pilot; physical movement accuracy is not calibrated.
**Audience:** Pilot users and iOS developers.

## At a glance

| Part | Behavior |
|---|---|
| Start | “Start challenge” / “Bắt đầu thử thách”, then consent to open the camera |
| Input | Live front-camera frames; shoulder, elbow, wrist, hip and ankle landmarks |
| Counting | Straight body near horizontal; extended, lowering, bottom, rising, extended arms |
| Completion | Exact selected target, recorded as `local_completed` |
| Limits | The saved target (1–50 repetitions); five-minute capture; no partial-cycle completion |
| Recovery | Camera denial, interruption, backgrounding and leaving stop capture |

## How it works

Place the phone to the side with the whole body visible and well lit. After
consent, Apple Vision estimates body joints. `CameraCapture` checks the visible
side and body alignment before passing angles to `PushUpCounter`. The counter
requires ordered phases, monotonic timestamps and bounded gaps/duration. Standing
arm bends, lost landmarks and incomplete cycles cannot complete a repetition.

`ChallengeCoordinator.completePushUps` accepts a completed counter for the exact
selected target. It stops the native alarm and cancels the backup rings before recording success. Duplicate
completion, a late result after the user leaves and a failed native stop cannot apply success.
Practice and retry never stop a real alarm or add progress entries.

## Key choices

The former button used synthetic images against a free server and could not check
real movement. Builds missing the ignored staging plist files produced a generic
unavailable message. The product screen now performs real camera recognition on
the phone; the old server remains a separate developer connectivity reference.
No Firebase account, App Check token or cloud inference is needed for this flow.

## Try it

Build with Xcode on an iOS 26+ iPhone and its existing development team. Choose
Explore challenges -> Push-ups -> Start challenge -> Open camera. A simulator can
test presentation and permission denial but cannot validate movement recognition.

```sh
sh scripts/test-swift.sh
swift test --package-path apps/ios/HiMorningCore
xcodegen generate --spec apps/ios/project.yml
```

## What we checked

`PushUpTests` covers ordered cycles, wrong posture, occlusion, stale/fast samples,
exact targets, duplicates, practice, native stop failure and the stop race.
`ChallengeCaptureTests` covers permission denial and cancellation during permission
startup. Bilingual UI journeys check plain-language labels and denial recovery.
These tests do not establish real-world recognition accuracy.

On 16 October 2026, portable checks, 71 SwiftPM tests, 42 native unit tests and
four focused UI tests passed. The signed development build installed and launched
on the connected iPhone 15. Real repetitions remain pending user calibration.

## Limits and next steps

The side-view thresholds are pilot heuristics, not a trained action classifier.
Validate standard push-ups on the real iPhone across lighting, distance, camera
placement and body sizes before relying on automatic completion. Knee push-ups
and other exercises are not supported. Self-confirmation and leaving remain
available without a successful movement check.

## Read next

[Free server reference](FREE-REMOTE-DEMO.md) · [Architecture](ARCHITECTURE.md)
