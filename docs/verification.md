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

On 13 October 2026, the merged source passed the build, all **52 tests** with no
skips, and the packaged smoke check under Bash 5.2.21 and Git 2.43.0. The
executable's Git blob identity was
`95e9f893d85ebab6d3157a6ce9f300c775fd9b8c`. These observations cover that
candidate in the tested environment; they do not certify every supported host.

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
