# HiMorning for Android

Native Kotlin/Compose alarm app with local challenges, bilingual content and morning
progress. Android owns AlarmManager, foreground audio, CameraX and on-device speech.

**Status:** Development implementation. **Audience:** Android developers and testers.
Release signing, physical-device reliability and Google Play purchases are separate
validation/configuration gates. See [implementation evidence](../../docs/ANDROID-IMPLEMENTATION.md).

## At a glance

- Android 12/API 31 or later; compile/target API 36; JDK 17.
- Gradle 8.13 wrapper, AGP 8.13.2 and Kotlin 2.3.21 are pinned.
- One application module; local JSON state uses atomic writes.
- Custom iOS-aligned yellow cards, inline wheel composer and home-to-sheet navigation.
- The reviewed English/Vietnamese content and 14 sounds match iOS bundled assets.
- Local alarms/challenges work without Firebase credentials or a network request.

## Try it

Install Android SDK 36, then set `ANDROID_HOME` or an ignored `local.properties`:

```properties
sdk.dir=/absolute/path/to/Android/sdk
```

From this directory:

```sh
./gradlew :app:assembleDebug :app:testDebugUnitTest :app:lintDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb shell am start -n com.himorning.android/.MainActivity
```

Allow exact alarms, notifications and full-screen alarm access on the setup card.
The app requests camera/microphone access only when the matching challenge starts.
Speech requires an installed on-device recognizer; Read and Choose is available as
an offline fallback. Never depend on this development build as your only alarm.

## How it works

Compose edits durable alarm intent before AlarmManager schedules it. A receiver
checks the saved identity/occurrence before starting foreground audio. Reboot and
time changes rebuild enabled schedules. Local challenges produce local completion;
practice does not write progress. Reading content comes from the reviewed iOS pack.

## Limits and next steps

Play Billing products and verified purchases are not configured. Firebase/Play
Integrity Android registration and a server-side allowed Android app ID are required
before cloud verification can be enabled; the existing server accepts the iOS app
ID only. No code bypasses App Check or treats an unverified purchase as Pro.
Camera calibration, physical-device alarm delivery, OEM battery behavior and a
signed Play release remain required. Build/test evidence is maintained in the
[implementation guide](../../docs/ANDROID-IMPLEMENTATION.md).

## Read next

[Android architecture](../../docs/ANDROID.md) · [Shared contracts](../../shared/contracts/README.md)
