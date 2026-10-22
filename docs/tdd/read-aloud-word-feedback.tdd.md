# Read Aloud word feedback

> **Dated evidence.** Commands, approvals, test totals and local paths below
> describe the original run. They are not current setup instructions or release
> status. See [current validation](../VALIDATION.md) for newer results and known gaps.

Record how Read Aloud compares recognized English words with the displayed
sentence, and distinguish automated checks from physical microphone acceptance.

**Status:** Implemented and tested on 15 October 2026. An integration build was
installed on the iPhone; live scoring acceptance by the user remains pending.
**Audience:** iOS maintainers and reviewers.

## At a glance

Read Aloud updates a 0–100 word-match score as recognition results arrive. Matching
words turn green; mismatched or skipped words turn red with an underline. Words
not yet reached stay gray until the attempt ends. The UI also shows the recognized
transcript, words to review and extra words, in English and Vietnamese.

The score compares recognized words. It does not measure pronunciation, accent
or individual speech sounds.

## How it works

Start reading and wait for **Listening…** before reading the English sentence.
Each partial transcript is aligned with the target using the existing normalized
word edit-distance matcher in
[Challenge.swift](../../apps/ios/HiMorningCore/Sources/HiMorningCore/Challenge.swift).
Revised recognition results replace the previous feedback. Insertions, omissions
and substitutions reduce the score; trailing unread words remain pending while
listening.

**Finish reading** waits for recognition to finalize and marks remaining unread
words for review. An 80% score passes. Automatic completion also requires every
target word to have been assessed, so a correct prefix cannot finish early.
Recognition errors, finalization timeouts and genuinely empty transcripts receive
distinct retry feedback. Stop and cancellation invalidate late results.

The reading button stays in the fixed bottom controls above **I’m awake**. Long
feedback and larger text can scroll without hiding **Start reading** or
**Finish reading** behind the bottom controls.

## Key choices

Reuse Apple's on-device recognition and the existing matcher without adding a
dependency or cloud audio upload. Wait for the speech analyzer to start before
publishing the listening state. Keep underlines and accessible word descriptions
alongside colors so feedback does not depend on color alone.

## Try it

On the updated iPhone, open Read Aloud, start reading and wait for **Listening…**.
Read the sentence while deliberately replacing one word. Observe the live score
and word feedback, then choose **Finish reading** to review the final result. No
USB connection is needed to open the installed app.

Core checks can be rerun from the checkout:

```sh
swift test --package-path apps/ios/HiMorningCore
sh scripts/test-swift.sh
```

## What we checked

On 15 October 2026, on the isolated PR branch based on `main` at `885e0f3`:

- All 47 SwiftPM core tests passed, including 13 Read Aloud tests covering matches,
  revisions, omissions, extra words, unread suffixes and unrelated speech.
- The portable core runner passed.
- On iOS 26.2, 16 focused native tests and six UI tests passed. These cover audio
  conversion, transcript handling, cancellation, spoken examples, bilingual
  live/final word feedback and reading controls with larger text. UI feedback
  tests inject transcripts and do not establish microphone recognition accuracy.
- Both localization files passed lint, and `git diff --check` passed.
- Before isolating the PR, the integration build with these Read Aloud changes
  passed its signed device build and signature verification. Installation and
  launch of `com.himorning.HiMorning` succeeded on an iPhone 15 Pro with iOS 27.0.1.
- The visibility regression reproduced the hidden button with long feedback and
  larger text before the control move. It passed after the move, including
  initial visibility, scrolling and stop actions.

## Limits and next steps

The earlier diagnostic device run received partial and final recognition results,
but the user has not yet confirmed live scoring with their voice in this version.
Recognition can transcribe a poorly pronounced word as the expected word; word
matching therefore cannot establish pronunciation accuracy. The next acceptance
check is the deliberate word replacement described above.

## Read next

- [Initial iPhone fixes and verification](ios-device-fixes.tdd.md)
- [Run the app](../RUNNING.md)
