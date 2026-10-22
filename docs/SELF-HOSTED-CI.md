# CI on the local Mac

Run repository checks on the configured Apple silicon runner. Workflow source,
runner availability and a passing run are different kinds of evidence.

**Status:** Repository-scoped self-hosted workflow configured. Live runner status
was not checked in this documentation review, dated 22 October 2026.
**Audience:** Repository and Mac maintainers.

## At a glance

| Setting | Source configuration |
|---|---|
| Repository | `thanhdanh/HiMorning` |
| Runner labels | `self-hosted`, `macOS`, `ARM64`, `himorning` |
| Local runner installation | `~/.local/share/actions-runner-himorning` |
| Toolchains | Node 22, pnpm 10.34.6, Java 21; Homebrew Python 3.11; installed Xcode/XcodeGen |
| Native runtime | Available iPhone on iOS 26.2, selected explicitly |
| Jobs | Backend, inference and iOS; iOS waits for backend |

The [workflow](../.github/workflows/ci.yml) and
[`test-ios.sh`](../scripts/test-ios.sh) are authoritative for job/test selection.
The single runner serializes accepted jobs while it is available; the Mac must
be awake, logged in and online. A runner registration observed in an older run
does not prove that it is online now.

## What each event runs

| Event | Checks |
|---|---|
| Push to `main` or `codex/**` | Backend/emulator checks, inference checks, both Swift core runners, all native unit tests and 15 selected UI tests |
| Manual `workflow_dispatch` | Same non-UI checks, with the full native UI suite |
| Merged same-repository PR closure | Cancels the head branch's concurrency group; closure jobs are skipped |

The 15 UI selectors cover the bilingual editor, reading, save/edit recovery,
cards, swipe-delete confirmation, double-tap trial, draft preservation, progress
and completion. `tests/ios-ci.test.ts` checks selection and selector existence;
it does not itself execute those UI journeys.

CI's iOS 26.2 pin originated as a workaround for StoreKitTest behavior on newer
runtimes. The latest local expired-purchase assertion also fails on 26.2; see
[known failure](VALIDATION.md#known-failure). Do not claim that pin makes the
whole native suite green.

## Build state and artifacts

The native script resolves packages and performs one `xcodebuild test`. Derived
data and Swift packages live under `runner.workspace/himorning-derived` for reuse.
Result bundles and exported screenshots use `runner.temp`; uploaded
`ios-ui-evidence` artifacts have seven-day retention. Save durable release evidence
separately with its revision and environment.

If package resolution reports a missing Firebase artifact ZIP, the script clears
only Firebase artifacts and SwiftPM workspace state, then resolves once more.
Other resolution errors and test failures propagate. The script disables automatic
test diagnostics collection to avoid lengthy failure cleanup. It does not hide
failed assertions or retry them to make CI green.

The inference job uses Homebrew's explicit Python 3.11 path. Runner setup and
credentials stay private. Do not copy registration/removal tokens into docs.

## Start or stop the service

After runner registration, from its local installation:

```sh
cd "$HOME/.local/share/actions-runner-himorning"
./svc.sh status
./svc.sh start
./svc.sh stop
```

`./svc.sh install` registers the user login service; `./svc.sh uninstall` removes
it. Retiring the runner also requires removing its repository registration through
GitHub's runner settings. Verify service and repository status rather than
assuming either from the other.

Workflows execute with this Mac user's permissions. Keep the runner scoped to
trusted repository code; stop the service when it should not receive work.

## What we checked

Current event labels, job selection, package recovery and artifact retention were
read from source. Tests cover smoke/full selection, failure propagation and
concurrency-group handling. Historical runner timings and probe runs are not
current performance or availability measurements.

## Read next

[Running](RUNNING.md) · [Validation](VALIDATION.md) ·
[Workflow](../.github/workflows/ci.yml)
