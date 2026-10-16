# Verification and support limits

From a source checkout, run:

```sh
bash tools/build.sh
bash tests/run.sh
bash tools/smoke.sh
```

The build checks that the committed `bin/git-agent` matches the source and all
embedded templates. The test suite uses disposable Git repositories to exercise
initialization, preview, preservation of existing work, conflicts, reruns,
failure recovery, and native Git dispatch. The smoke check installs the command
outside the checkout and exercises it through Git.

## Version 0.2.2 candidate evidence

On 16 October 2026, [PR #1's integrated source head
`cc4478690a75cd991fef54724b4ceae338d0e7e3`](https://github.com/ElevenID/git-agent/commit/cc4478690a75cd991fef54724b4ceae338d0e7e3)
passed the build, full test suite, and packaged smoke check in [CI run
38918998311](https://github.com/ElevenID/git-agent/actions/runs/38918998311).
The generated executable's Git blob identity was
`773c3ebb7080a65368b5860ab2e7bdb6b20a69e6` on all three hosts.

| Host | Tests | Observed toolchain |
| --- | --- | --- |
| Ubuntu | 52 passed, 0 failed, 0 skipped | Bash 5.2.21, Git 2.55.0 |
| macOS | 52 passed, 0 failed, 0 skipped | Bash 3.2.57, Apple Git 2.50.1 |
| Windows | 46 passed, 0 failed, 6 skipped | Bash 5.3.15, Git 2.56.0.windows.2 |

Windows used Git Bash. Its skips cover unsupported filename and native symlink
fixtures. The packaged smoke check passed on all three hosts. This evidence
covers the recorded source head; verify the current PR checks before merge.

## Historical pre-integration PR #1 candidate (version 0.2.1)

On 14 October 2026, [PR #1's exact source head
`fcf34423a9fb95f0759793a81a9df82a6c88d920`](https://github.com/ElevenID/git-agent/commit/fcf34423a9fb95f0759793a81a9df82a6c88d920)
passed the build, test suite, and packaged smoke check in [CI run
38506791466](https://github.com/ElevenID/git-agent/actions/runs/38506791466).
The generated executable's Git blob identity was
`678001d38dda257878f439a362591e613d58b387` on all three hosts.

| Host | Tests | Observed toolchain |
| --- | --- | --- |
| Ubuntu | 52 passed, 0 failed, 0 skipped | Bash 5.2.21, Git 2.55.0 |
| macOS | 52 passed, 0 failed, 0 skipped | Bash 3.2.57, Apple Git 2.50.1 |
| Windows | 46 pass, 0 fail, 6 skip | Bash 5.3.15, Git 2.55.0.windows.5 |

Windows used Git Bash. Its skips cover unsupported filename and native symlink
fixtures. The packaged smoke check passed on all three hosts. This evidence
covers that earlier PR candidate, before the integration with `main` and the
0.2.2 version update.

## Historical version 0.2.0 evidence

On 13 October 2026, the merged 0.2.0 source passed the build, all **52 tests**
with no skips, and the packaged smoke check under Bash 5.2.21 and Git 2.43.0.
That older executable's Git blob identity was
`95e9f893d85ebab6d3157a6ce9f300c775fd9b8c`. These observations cover
that earlier candidate in the tested environment; they do not certify later
versions.

The [CI workflow](../.github/workflows/ci.yml) runs the same checks on standard
Ubuntu, macOS, and Windows runners. macOS explicitly uses system Bash 3.2;
Windows uses Git Bash. The workflow has read-only repository permission and no
deployment or release job. CI status on each pull request and the default branch
is the current hosted result.

## What these checks do not establish

- The initializer does not parse or validate existing JSON or TOML files. Use
  the adopting project's validators and Codex configuration handling.
- It publishes complete files atomically, one at a time, on a filesystem that
  supports hard links. A whole scaffold is not a transaction, and the tests do
  not simulate power loss.
- Native Codex instruction discovery, model behavior, project permissions,
  reviewer quality, deployment, and recovery belong to the adopting project.
- Windows skips fixtures that require unsupported filename or symlink behavior;
  inspect the CI totals rather than treating skips as passes.
