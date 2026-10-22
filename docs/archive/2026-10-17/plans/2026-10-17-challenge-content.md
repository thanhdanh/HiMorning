# Challenge Content Pool Implementation Plan

> **Historical document.** This is a superseded proposal or implementation
> checkpoint, not current product behavior or instructions to execute. See the
> [current documentation](../../../README.md) and [challenge guide](../../../MODE-CHALLENGES.md).
> Original observations, limits and approvals below apply only to their dated scope.

**Goal:** Read-aloud, read-and-choose and riddle challenges draw from a much larger English and Vietnamese pool. The pool ships in the app, can be refreshed from our Cloudflare Worker, works offline, and avoids recent repeats.

**Architecture:**
- **Format and sources.** One versioned JSON pack format (zod schema plus a shared JSON Schema) is built from curated source files in `shared/content/challenges/` by `scripts/build-challenge-content.mjs`.
- **Delivery.** The build writes the same pack into the iOS bundle and into the Worker, which serves it at `GET /content/v1/challenge-content.json` with an ETag.
- **Selection on device.** `ChallengeContentStore` in HiMorningCore validates the bundled pack and any cached pack, then picks items by kind and language with a 20-item no-repeat history.
- **Language.** Speech recognition, TTS and token matching follow the app language.

**Tech Stack:**
- Node: zod 4, vitest 5 and Miniflare for tests.
- Cloudflare Workers.
- Swift 6: HiMorningCore, URLSession and the Speech framework.

**Spec:** `docs/superpowers/specs/2026-10-17-challenge-content-design.md`

**Plan anchor:** commands run from the worktree root, `/Users/andyvo/Projects/HiMorning/.claude/worktrees/vibe-demo-production-issues-b37818`.

## Global Constraints

- **Item shape:** `{ id, kind, language, text, choices?, answerIndex?, source, license, attribution? }`.
  - `kind ∈ readAloud | readAndChoose | riddle` and `language ∈ en | vi`.
  - Choice kinds have exactly 3 `choices` and `answerIndex ∈ 0...2`.
  - `readAloud` has no choices and 18–30 tokens.
- **Token rule:** tokens are runs of Unicode letters or digits. This is `RecognizedWordMatch.tokens(in:)` (Challenge.swift:212), and the JS validator must use the same rule, `/[\p{L}\p{N}]+/gu`.
- **Minimum bundled counts:**

  | | readAloud | readAndChoose | riddle |
  | --- | --- | --- | --- |
  | en | 200 | 40 | 40 |
  | vi | 100 | 30 | 30 |

- **Authored content:** all of it is original, with `source: "himorning"` and `license: "original"`. No third-party text is imported, so no credits screen is needed (spec §7 applies only when a Tatoeba item is present).
- **Tone:** calm, kind and short, per `docs/LOCALIZATION.md`. No real people's names, no brands, nothing about health, religion or politics.
- **Repeats:** no repeat within the last 20 picks of a kind and language.
- **Refresh:** on foreground, at most once per 24 h, with a 10 s timeout. Never on the alarm path.
- **Endpoint:** `GET /content/v1/challenge-content.json` with no auth. Responses carry `ETag: "v<version>"` and `Cache-Control: public, max-age=3600`. `If-None-Match` returns 304.
- Swift and Xcode commands run **outside the Bash sandbox**. **Do not commit**, because the repo-org commit hook blocks it; each task ends with a `git status --short` checkpoint.
- Comment policy from `~/.claude/CLAUDE.md`.

## Review Focus

1. A cached remote pack that is valid JSON but has an item that breaks a rule, such as a 12-token read-aloud. That item is dropped, every valid item is kept, and an invalid pack never replaces the bundled one (Task 4 `testInvalidRemoteItemsAreDroppedAndBundledStays`).
2. A pool for one kind and language that is smaller than 20. The picker must still return an item; it resets history for that kind instead of returning nil (Task 4 `testSmallPoolStillPicksAfterHistoryFills`).
3. Vietnamese words that differ only by tone mark, for example "ma", "má" and "mà". They must not match each other, while English diacritics still fold (Task 4 `testVietnameseKeepsToneMarksEnglishFolds`).
4. A refresh while offline or slow, or a server 500. The cached pack stays untouched, and the next attempt waits the full 24 h only after a success or a 304 (Task 6 `testFailedFetchDoesNotAdvanceRefreshClock`).
5. An app language of `vi` on a device without `vi-VN` speech recognition. The read-aloud screen must show the fallback note, not an endless spinner (Task 6, manual check line in RELEASE-READINESS).

---

### Task 1: Pack schema, validator, build script and fixture

**Files:**
- Create: `scripts/lib/challenge-content.mjs`
- Create: `scripts/build-challenge-content.mjs`
- Create: `shared/contracts/v1/challenge-content.schema.json` (generated)
- Create: `shared/contracts/v1/fixtures/challenge-content.sample.json`. Hand-written: 2 items per kind per language, 12 in total, all valid.
- Create: `tests/challenge-content.test.ts`
- Modify: `package.json` scripts, adding `"content:build": "node scripts/build-challenge-content.mjs"`

**Interfaces:**
- Produces, from `scripts/lib/challenge-content.mjs`:
  - `export const challengeContentItem` (zod object)
  - `export const challengeContentPack` (zod: `{ version: int ≥ 1, generatedAt: ISO string, items: item[] }`)
  - `export function tokenCount(text): number`
  - `export function validatePack(pack): { valid: Item[], errors: string[] }`. It applies the zod schema plus the rules: unique ids, unique normalised text per language, the read-aloud token range and the choice rules.
  - `export function buildPack(items, { version, generatedAt })`. Items are sorted by `language`, `kind`, `id`, so output is deterministic.
- The CLI reads every `shared/content/challenges/*.json` (each file is an array of items) and fails with exit 1 on any validation error. It then writes:
  - `apps/ios/Resources/challenge-content.json`
  - `backend/worker/content/challenge-content.json`
  - `shared/contracts/v1/challenge-content.schema.json`, from `z.toJSONSchema(challengeContentPack)`
- `version` is read from `shared/content/challenges/VERSION`, a single integer.

- [ ] **Step 1: Write the failing tests** in `tests/challenge-content.test.ts`:
  - `accepts the shared sample fixture`
  - `rejects a 17-token readAloud, a duplicate id, answerIndex 3, 2 choices and language "fr"`. Each case is its own expectation on `errors`.
  - `counts tokens like the Swift tokenizer`: `"Good morning, it's 6:30!"` gives 6, and `"Chào buổi sáng"` gives 3.
  - `published JSON schema matches the zod schema`
  - `buildPack output is sorted and stable`: the same input twice gives deep-equal output.
- [ ] **Step 2: Run** `pnpm vitest run tests/challenge-content.test.ts`. Expected: FAIL, cannot find module `../scripts/lib/challenge-content.mjs`.
- [ ] **Step 3: Implement the library and the CLI.**
- [ ] **Step 4: Run** the same command. Expected: 5 passed.
- [ ] **Step 5: Checkpoint.** Run `git status --short`.

### Task 2: English content sources

**Files:**
- Create: `shared/content/challenges/VERSION`, containing `1`
- Create:
  - `shared/content/challenges/read-aloud.en.json`
  - `shared/content/challenges/read-and-choose.en.json`
  - `shared/content/challenges/riddles.en.json`

- [ ] **Step 1: Migrate the existing English items, keeping their ids:**
  - the 24 `EnglishChallengeContent.readAloud` items (Challenge.swift:104-129)
  - the 3 `EnglishChallengeContent.readAndChoose` items plus the 5 in `ChallengePrompts.reading` (ChallengePrompts.swift:13-19)
  - the 3 riddles (ChallengePrompts.swift:27-31)

  `sentence` becomes `text`, and `correctChoiceIndex` becomes `answerIndex`.
- [ ] **Step 2: Write new original items** up to the minimum counts:
  - Morning-themed, calm, everyday read-aloud sentences.
  - Read-and-choose items where only one choice paraphrases the sentence.
  - Riddles with one unambiguous answer and two plausible distractors.
- [ ] **Step 3: Run** `pnpm content:build`. Expected: exit 0, and `backend/worker/content/challenge-content.json` exists.
- [ ] **Step 4: Add the test** `bundled pack meets minimum counts per kind and language (en)` to `tests/challenge-content.test.ts`. It reads `apps/ios/Resources/challenge-content.json`. Run `pnpm vitest run tests/challenge-content.test.ts`, expecting all to pass.
- [ ] **Step 5: Checkpoint.**

### Task 3: Vietnamese content sources

**Files:**
- Create:
  - `shared/content/challenges/read-aloud.vi.json`
  - `shared/content/challenges/read-and-choose.vi.json`
  - `shared/content/challenges/riddles.vi.json`

- [ ] **Step 1: Write original Vietnamese items** up to the minimum counts.
  - Use natural, everyday Vietnamese with full tone marks, not translations of the English items.
  - Riddles are short câu đố in the folk style, but newly written, not copied from collections.
  - Read-aloud items have 18–30 syllables.
- [ ] **Step 2: Run** `pnpm content:build`. Then extend the minimum-count test to `vi` and run `pnpm vitest run tests/challenge-content.test.ts`. Expected: all pass.
- [ ] **Step 3: Write** `shared/content/challenges/REVIEW.md`. It holds one line, "Vietnamese items need a native-speaker review by the project owner before release.", and a checklist of the three vi files.
- [ ] **Step 4: Checkpoint.**

### Task 4: `ChallengeContentStore` and language-aware matching in HiMorningCore

**Files:**
- Create: `apps/ios/HiMorningCore/Sources/HiMorningCore/ChallengeContent.swift`
- Modify: `apps/ios/HiMorningCore/Sources/HiMorningCore/Challenge.swift`:
  - `ReadAloudAttempt` (:132)
  - `RecognizedWordMatch.feedback/score/passes/tokens` (:150-222)
  - Delete `EnglishChallengeContent` (:97-129)
- Create: `apps/ios/HiMorningCore/Tests/HiMorningCoreTests/ChallengeContentTests.swift`
- Modify:
  - `ReadAloudTests.swift`: :7-18 moves to fixture-based store tests, and :57 uses a fixture item.
  - `CoreTests.swift:255-261`: delete it, since the content rules now live in Task 1 and in this task's tests.
  - `TestsPortable/main.swift`: register the new tests and unregister the deleted ones.

**Interfaces:**
- Produces:
  - `public enum ContentKind: String, Codable, Sendable { case readAloud, readAndChoose, riddle }`
  - `public struct ChallengeContentItem: Codable, Equatable, Identifiable, Sendable { id, kind, language, text: String; choices: [String]?; answerIndex: Int?; source, license: String; attribution: String? }`
    - `var readAndChoosePrompt: ReadAndChoosePrompt?`
    - `var readAloudPrompt: ReadAloudPrompt?`
  - `public struct ChallengeContentPack: Codable, Sendable { version: Int; generatedAt: String; items: [ChallengeContentItem] }`
  - `public struct ContentHistory: Codable, Equatable, Sendable { public static let limit = 20; mutating func record(_ item: ChallengeContentItem); func recent(kind: ContentKind, language: String) -> [String] }`
  - `public struct ChallengeContentStore: Sendable`:
    - `init(bundled: ChallengeContentPack, cached: ChallengeContentPack?)` uses the cached pack's valid items only when `cached.version > bundled.version` and at least one item is valid.
    - `static func validItems(_ pack: ChallengeContentPack) -> [ChallengeContentItem]` applies the same rules as Task 1.
    - `var version: Int`
    - `func items(kind: ContentKind, language: String) -> [ChallengeContentItem]`
    - `func next(kind: ContentKind, language: String, history: inout ContentHistory) -> ChallengeContentItem?` picks randomly among items not in `recent`. If every item is recent, it clears that kind and language from history and picks again.
  - `RecognizedWordMatch.tokens(in: String, language: String = "en") -> [String]`:
    - For `"vi"`, fold `.caseInsensitive` only, with `Locale(identifier: "vi_VN")`.
    - Otherwise use the current `.caseInsensitive` and `.diacriticInsensitive` folding with `en_US_POSIX`.
    - `feedback`, `score` and `passes` gain `language: String = "en"`.
    - `ReadAloudAttempt.init(target: String, language: String = "en")`.

- [ ] **Step 1: Write the failing tests.** They load `challenge-content.sample.json` the same way RemoteDemoTests.swift:13-15 locates `shared/contracts/v1`, by `CommandLine.arguments[1]` under PORTABLE_TESTS and `#filePath` otherwise.
  - `testStoreLoadsFixtureAndFiltersByLanguage`
  - `testInvalidRemoteItemsAreDroppedAndBundledStays`. A cached pack at version 2 with one 12-token read-aloud and one valid item gives the store version 2 and only the valid item for that kind. A cached pack with zero valid items gives the bundled version.
  - `testOlderCachedPackIsIgnored`
  - `testNoRepeatWithinTwentyPicks`: a 25-item synthetic pool, 20 picks, all distinct.
  - `testSmallPoolStillPicksAfterHistoryFills`: a 2-item pool, 5 picks, never nil.
  - `testVietnameseKeepsToneMarksEnglishFolds`:
    - `tokens(in: "Má mà ma", language: "vi") == ["má", "mà", "ma"]`.
    - `passes(target: "má", recognized: "ma", language: "vi") == false`.
    - `tokens(in: "Café", language: "en") == ["cafe"]`.
- [ ] **Step 2: Run** `swift test --package-path apps/ios/HiMorningCore --filter ChallengeContentTests`. Expected: build failure on `ChallengeContentStore`.
- [ ] **Step 3: Implement, and delete `EnglishChallengeContent`.**
- [ ] **Step 4: Run** `swift test --package-path apps/ios/HiMorningCore` and `sh scripts/test-swift.sh`. Expected: 0 failures and the PASS line.
- [ ] **Step 5: Checkpoint.**

### Task 5: Worker content endpoint

**Files:**
- Modify: `backend/worker/src/worker.ts`. Add the route before the `/health` check at :30-32.
- Create: `backend/worker/src/content.ts`
- Modify: `backend/worker/tests/worker.test.ts`. Unit-test `contentResponse`.
- Modify: `backend/worker/tests/runtime.test.ts`. Add one Miniflare round-trip.

**Interfaces:**
- Consumes: `backend/worker/content/challenge-content.json` (Task 2, imported as JSON as the tests import fixtures).
- Produces: `export function contentResponse(request: Request, pack: { version: number }): Response`.
  - It returns 200 with the JSON body, `ETag: "v<version>"`, `Cache-Control: public, max-age=3600` and `Content-Type: application/json`.
  - It returns 304 with an empty body when `If-None-Match` equals the ETag.
  - Any method other than GET or HEAD gets 405.
  - `worker.ts` routes `path === '/content/v1/challenge-content.json'` to it, with no `authorize` call.

- [ ] **Step 1: Write the failing tests:**
  - `serves the content pack with an ETag and caching headers`
  - `returns 304 for a matching If-None-Match`
  - `rejects POST with 405`
  - The runtime test: `GET /content/v1/challenge-content.json` returns 200 and `items.length >= 440`, with no auth headers.
- [ ] **Step 2: Run** `pnpm vitest run backend/worker/tests/worker.test.ts`. Expected: FAIL, missing `../src/content.js`.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `pnpm vitest run backend/worker/tests` and `pnpm run typecheck`. Expected: all pass.
- [ ] **Step 5: Checkpoint.** Do **not** run `pnpm deploy:free`; deploying needs the owner's go-ahead.

### Task 6: App wiring (bundled pack, refresher, picker, speech language)

**Files:**
- Create: `apps/ios/HiMorning/ChallengeContentRefresher.swift`
- Modify: `apps/ios/HiMorning/ChallengePrompts.swift`. Delete the static pools and keep `ChallengePrompt` and its shuffling in `readAndChoose(_:)`, which now takes one `ReadAndChoosePrompt`.
- Modify: `apps/ios/HiMorning/ChallengeView.swift`:
  - `@State` prompts at :44-48
  - `preparePrompt` at :296-305
  - display, TTS and recognition text at :101, :112, :216, :356 and :375
  - the copy at :318
- Modify: `apps/ios/HiMorning/HiMorningApp.swift`:
  - `PilotModel` builds the store at init.
  - Read `WorkerURL` from `HiMorningCloud-Info.plist` independently of the `GoogleService-Info` check at :28-34.
  - Start the refresh on scene-phase active, next to `refresh()` at :323.
- Modify: `apps/ios/HiMorning/SpeechChallengeCapture.swift:130` and `apps/ios/HiMorning/SpokenExample.swift:28-35`
- Modify: `apps/ios/HiMorningTests/ChallengePromptsTests.swift`
- Create: `apps/ios/HiMorningTests/ChallengeContentRefresherTests.swift`
- Modify: both `Localizable.strings` files and `docs/RELEASE-READINESS.md`

**Interfaces:**
- Consumes: `ChallengeContentStore`, `ContentHistory`, `ChallengeContentPack`, `RecognizedWordMatch.tokens(in:language:)` and `ReadAloudAttempt(target:language:)` (Task 4). Also the endpoint path from Task 5.
- Produces:
  - `final class ChallengeContentRefresher: Sendable`:
    - `init(origin: URL?, directory: URL, defaults: UserDefaults = .standard, session: URLSession = .shared, now: @escaping @Sendable () -> Date = Date.init)`
    - `func cachedPack() -> ChallengeContentPack?`
    - `func refreshIfDue() async -> ChallengeContentPack?` returns the new pack only on a 200 with a valid, newer version.
  - Storage:
    - The cache file is `<Application Support>/challenge-content.json`, written with `.atomic`.
    - UserDefaults keys are `contentETag` and `contentLastRefresh`. `contentLastRefresh` is updated only on a 200 or a 304.
    - The request has a 10 s `timeoutInterval` and sends `If-None-Match` when an ETag is stored.
  - `PilotModel`:
    - `@Published var content: ChallengeContentStore`, built from the bundled `challenge-content.json` plus `refresher.cachedPack()`.
    - `var contentHistory: ContentHistory`, persisted as JSON in UserDefaults key `contentHistory`.
    - `func nextPrompt(_ kind: ContentKind) -> ChallengeContentItem?`, using the language from `appLocale().identifier`.

Steps:
- [ ] **Step 1: Write the failing tests** in `ChallengeContentRefresherTests`. Use a `URLProtocol` stub registered on an ephemeral `URLSessionConfiguration`.
  - `testFreshPackIsCachedWithETag`
  - `testNotModifiedKeepsCacheAndAdvancesClock`
  - `testFailedFetchDoesNotAdvanceRefreshClock`, for a 500 and for a timeout error.
  - `testNotDueWithinTwentyFourHoursMakesNoRequest`
  - `testInvalidPayloadIsNotCached`

  Then update `ChallengePromptsTests`: keep the shuffle-mapping test, and replace the count and previous-id tests with `PilotModel`-free checks on `ChallengePrompts.readAndChoose(_:)`.
- [ ] **Step 2: Run** the tests, only if `xcodegen` exists: `xcodegen generate --spec apps/ios/project.yml && xcodebuild test -project apps/ios/HiMorning.xcodeproj -scheme HiMorning -destination "platform=iOS Simulator,name=<first iPhone in xcrun simctl list devices available>" -only-testing:HiMorningTests/ChallengeContentRefresherTests`. Expected: build failure on `ChallengeContentRefresher`. Otherwise report "not run (L8)".
- [ ] **Step 3: Implement the refresher and the `PilotModel` wiring.**
- [ ] **Step 4: Wire the content into `ChallengeView`.**
  - Prompts come from `model.nextPrompt(.readAndChoose / .riddle / .readAloud)`, mapped through `readAndChoosePrompt` and `readAloudPrompt`.
  - Display the item text directly, without `appText(...)`, because the items are already in the user's language.
  - The UI-test overrides at :196-206 keep `appText(...)` for their fixed English keys.
  - Pass `language` to `ReadAloudAttempt`, to `SpeechChallengeCapture` and to `SpokenExample.play`.
- [ ] **Step 5: Speech.**
  - `SpeechChallengeCapture` uses `Locale(identifier: language == "vi" ? "vi-VN" : "en-US")`.
  - `SpokenExample` picks the best voice whose language starts with `vi` or `en` to match.
  - When neither `SpeechTranscriber` nor `DictationTranscriber` supports the locale, publish `appText("Reading aloud is not available in this language on this iPhone. Please choose another challenge.")` and end. vi: `"Đọc to chưa hỗ trợ ngôn ngữ này trên iPhone của bạn. Hãy chọn thử thách khác."`
- [ ] **Step 6: Copy.**
  - Change "Tap Start reading, then read the English sentence aloud…" (ChallengeView.swift:318 and its strings key) to "Tap Start reading, then read the sentence aloud…", keeping the rest of the sentence. Update the vi value to match.
  - Do the same for "Read the English sentence aloud." at HiMorningApp.swift:200.
- [ ] **Step 7: Add the unchecked RELEASE-READINESS lines:**
  - "Vietnamese read-aloud recognizes a vi-VN sentence on device (ledger L7)."
  - "Content refresh fetches from the deployed Worker after `pnpm deploy:free`."
- [ ] **Step 8: Verify.**
  - Run `pnpm test` (all pass), `pnpm run typecheck` (pass), `swift test --package-path apps/ios/HiMorningCore` (0 failures) and `sh scripts/test-swift.sh` (PASS).
  - If xcodegen exists, also run the Step 2 command and `-only-testing:HiMorningTests/ChallengePromptsTests` plus `-only-testing:HiMorningUITests/PilotUITests/testReadingPracticeCompletesOfflineInBothLanguages`, expecting `** TEST SUCCEEDED **`.
- [ ] **Step 9: Checkpoint.**
