# CI on the local Mac

Run HiMorning's existing checks on a repository-scoped Apple silicon runner when
GitHub-hosted jobs cannot start because of the account's Actions billing limit.

**Status:** Runner registered and online with the machine owner's approval.
CI results appear in the pull request checks. **Audience:** The repository and Mac owner.

## At a glance

| Setting | Value |
|---|---|
| Repository | `thanhdanh/HiMorning` only |
| Runner name | `himorning-mac-arm64` |
| Workflow labels | `self-hosted`, `macOS`, `ARM64`, `himorning` |
| Installation | `~/.local/share/actions-runner-himorning` |
| Checkout directory | `_work` inside the runner installation |
| Service | User LaunchAgent; starts after login |

## How it works

The backend, inference and iOS jobs run one at a time on this runner. Node 22,
pnpm and Java 21 are selected by the setup actions. The inference job uses
Homebrew's `python@3.11` and its explicit interpreter path to create the virtual
environment. `setup-python` macOS distributions require the fixed
`/Users/runner/hostedtoolcache` directory, which this runner user cannot create;
changing the tool-cache environment variable does not relocate those binaries.
See [GitHub's macOS self-hosted Python requirements](https://github.com/actions/setup-python/blob/main/docs/advanced-usage.md#macos).
Xcode and XcodeGen come from the Mac. Native tests require an available iPhone simulator
using iOS 26.2 because of the documented StoreKitTest regression on newer runtimes.

Each push runs both Swift core test paths, all native unit tests and four UI smoke
tests: the English and Vietnamese alarm editor journeys, offline reading in both
languages, and alarm-save failure recovery. Run **HiMorning checks → Run workflow**
in GitHub Actions to run the complete UI suite before a release or when changing
flows outside the smoke set. Manual runs keep the same unit tests and coverage.

Merging a same-repository PR cancels running or pending checks for its head branch.
The `pull_request: closed` event acquires that branch's existing concurrency group
while every runner job is skipped, so cleanup does not wait for the Mac or use
hosted-runner minutes. Push checks on `main` use a separate group. Unmerged closes,
fork PRs and PRs whose head is the default branch use an isolated group instead.
The mechanism applies after this workflow reaches the PR's base branch. See
[GitHub's concurrency rules](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency).

`xcodebuild test` builds the app and test bundles once. Derived data, including
resolved Swift packages, stays in `runner.workspace/himorning-derived` so Xcode can
reuse it between jobs on this runner. Remove that directory when troubleshooting
stale build state or reclaiming disk space. Result bundles and exported screenshots
use `runner.temp`, which GitHub's runner clears between jobs.
Before testing, the script resolves packages. If resolution reports a missing ZIP
under Firebase's cached artifacts, it discards only Firebase artifacts and the
SwiftPM workspace-state file, then resolves once more. Other package caches and
compiled derived data remain reusable. Unrelated resolution errors and native
test failures still fail CI without retries.
Repository credentials remain in the private runner
directory and must never be committed or copied into documentation.

## Start and stop

From the runner installation directory, after registration:

```sh
cd "$HOME/.local/share/actions-runner-himorning"
./svc.sh install
./svc.sh start
./svc.sh status
./svc.sh stop
```

`./svc.sh uninstall` removes the login service. To retire the runner completely,
also remove it from the repository's **Settings → Actions → Runners** page and
follow GitHub's removal instructions. Do not publish registration or removal tokens.

## What we checked

The official macOS ARM64 runner archive was downloaded and its SHA-256 checked
against GitHub's repository runner-download API. Registration and login-service
startup succeeded, and GitHub reports the runner online with the required labels.
See [PR #7 checks](https://github.com/thanhdanh/HiMorning/pull/7/checks) for end-to-end
workflow results; runner availability alone does not prove those checks passed.

Before the smoke change, [run 38750657831](https://github.com/thanhdanh/HiMorning/actions/runs/38750657831)
took about 14 minutes for iOS: 88 seconds for the separate build and 679 seconds for
native testing. The four selected UI tests took 85 seconds combined in that run;
this excludes build, simulator startup and unit-test overhead. The new duration
must be measured on the runner. `tests/ios-ci.test.ts` checks smoke/full selection,
that smoke selectors exist, and that build/test failures still fail CI.

`tests/ci-cancellation.test.ts` checks the workflow's concurrency expression for
pushes, manual runs, merged PRs, unmerged closes, forks and default-branch heads.
A [temporary GitHub probe](https://github.com/thanhdanh/HiMorning/actions/runs/38770937528)
confirmed that a replacement run with all jobs skipped cancels the old group
without using a runner; both the running and pending probe runs were cancelled.
The actual PR-merge event remains to be observed after this workflow is merged.
Package-recovery tests cover one retry, preservation of unrelated caches and
propagation of resolution/test failures.

## Limits and next steps

The Mac must be awake, logged in and online to receive jobs. Workflows execute
with the local user's permissions and can access that user's files. Keep this
runner scoped to the private repository and allow only trusted code; do not enable
untrusted pull-request jobs on it. Stop the service whenever it should not accept
work.

After startup, verify the runner is online in GitHub, push the workflow update,
and require the backend and iOS checks to pass before merging the pull request.

## Read next

- [Workflow](../.github/workflows/ci.yml)
- [Adding a runner](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/add-runners)
- [Managing its service](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/configure-the-application?platform=mac)
