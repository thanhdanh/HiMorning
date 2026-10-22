# Challenge content pool

Grow the read-aloud, read-and-choose and riddle pools in English and Vietnamese, refresh them from our Cloudflare Worker, and keep every challenge working offline.

**Status:** planned (design approved 2026-10-17). **Audience:** iOS and Worker developers.

## At a glance

| | Today | After this change |
| --- | --- | --- |
| Read aloud | 24 English sentences in Swift (`Challenge.swift:104-129`) | ~200 EN + ~100 VI |
| Read and choose | 8 English items | ~40 EN + ~30 VI |
| Riddles | 3 English items (`ChallengePrompts.swift:27-31`) | ~40 EN + ~30 VI original riddles |
| Source | Compiled in | Bundled JSON, refreshed from the Worker, cached on disk |
| Speech | `en-US` recognizer and voice only | Follows app language (`en-US` / `vi-VN`) |
| Repeats | Only an immediate repeat is avoided | No repeat within the last 20 of a kind |

## How it works

1. **Contract.** `shared/contracts/v1/challenge-content.schema.json` defines `{ version, generatedAt, items: [{ id, kind, language, text, choices?, answerIndex?, source, license, attribution? }] }`. `kind` is `readAloud | readAndChoose | riddle` and `language` is `en | vi`. The fixture `shared/contracts/v1/fixtures/challenge-content.sample.json` is used by both the Swift and the TypeScript tests.
2. **Sources.** `shared/content/challenges/` holds curated source files: `riddles.en.json`, `riddles.vi.json`, `read-and-choose.{en,vi}.json` and `read-aloud.{en,vi}.json`. The riddles are original and written for HiMorning. Vietnamese items need a native-speaker review by the project owner. In this first version every item is original. A Tatoeba export filtered to CC BY 2.0 FR or CC0 (ledger L5) can be added later, keeping an attribution per item.
3. **Build.** `scripts/build-challenge-content.mjs` validates the sources against the schema and the existing rules: read-aloud is 18–30 tokens, ids are unique, normalized text is unique, and `answerIndex` is in range. It writes `apps/ios/Resources/challenge-content.json` (bundled) and `backend/worker/content/challenge-content.json` (imported by the Worker).
4. **Worker.** `GET /content/v1/challenge-content.json` is served by the Worker from the bundled pack JSON with an ETag of `"v<version>"` and `Cache-Control: public, max-age=3600`. It needs no auth, since the content is public and holds no user data. The existing POST routes are unchanged.
5. **App.**
   - `ChallengeContentStore` (HiMorningCore, pure) loads the bundled pool and merges in a cached remote pool when that pool is valid and newer. It picks an item by kind and language, and avoids the last 20 ids of that kind; that history is persisted in UserDefaults.
   - `ChallengeContentRefresher` (app target) runs on foreground at most once every 24 h. It uses `URLSession` with `If-None-Match`, 10 s timeouts, and writes atomically to Application Support. It never runs on the alarm path.
   - The Worker URL comes from the existing `HiMorningCloud-Info.plist` `WorkerURL`. With no plist, only the bundled pool is used.
6. **Speech.** `SpeechChallengeCapture`, `SpokenExample` and `ReadAloudAttempt` take the language from the app setting. For `vi`, the tokenizer folds case but keeps diacritics, because Vietnamese tone marks change meaning. Recognizer support for `vi-VN` is unverified (ledger L7). If it is missing, Vietnamese users get read-and-choose or riddles instead of read-aloud, with a short bilingual note.
7. **Credits.** Settings shows "Sentences from Tatoeba (tatoeba.org), CC BY 2.0 FR" whenever any item with that license is in use.

## Key choices

- **No device calls to third-party APIs.** Free riddle and quote APIs either forbid commercial use or have unclear licenses, and an alarm at 6 am must work offline.
- **Cloudflare Worker.** It is the org-recommended platform and it is already deployed. Content updates need no app release.
- **Original riddles.** These avoid copyright on riddle collections. Folk riddle reuse is unverified, so folk sources are not imported.

## What we will check

- Swift tests: `ChallengeContentStore` loads the fixture, rejects invalid remote items and keeps the bundled ones, avoids repeats over 20 picks, and filters by language. Vietnamese token matching keeps tone marks.
- The existing `ReadAloudTests` and `ChallengePromptsTests` run against the bundled JSON, with counts updated to minimums.
- Vitest: the build script fails on an invalid source, and the Worker returns 200 with an ETag, then 304 on `If-None-Match`.
- `tests/localization.test.ts` still passes for new UI copy.

## Limits and next steps

- Ledger L5 (Tatoeba licence for the chosen subset) and L7 (`vi-VN` recognizer).
- Deploying the Worker change uses the existing `pnpm deploy:free` and needs the owner's go-ahead.
