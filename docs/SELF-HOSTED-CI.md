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

The backend and iOS jobs keep their existing checks and run one at a time on this
runner. Node 22, pnpm and Java 21 are selected by the setup actions. Xcode and
XcodeGen come from the Mac. Native tests require an available iPhone simulator
using iOS 26.2 because of the documented StoreKitTest regression on newer runtimes.

Builds, result bundles and exported screenshots use `runner.temp`, which GitHub's
runner clears between jobs. Repository credentials remain in the private runner
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
