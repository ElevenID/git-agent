# git agent init

Initialize a Git project for governed, goal-driven development with the VS Code
Codex extension. The command places reviewable guidance and two instruction-only
skills beside the code, identifies adoption gaps, and preserves existing project
content.

**Version 0.2.1 is one Bash executable with embedded templates.** Running,
building, installing, and testing it uses Bash, Git, and the ordinary Unix
utilities supplied by the supported shell environment. It requires no Python,
Node.js, jq, package manager, language libraries, agent service, or custom daemon.

The initializer supplies a starting point, not a completed project policy. Each
adopting project must review the generated guidance, configure its own commands
and owners, and validate its development and release process.

## Command surface

```text
git agent init [directory] [--dry-run]
git agent init --help
git agent -h
git agent --version
```

`init` is the only operational subcommand. Ordinary work uses the project's
native commands and the `work-goal` and `worktree-flow` skills. There is no
scheduler, task database, required MCP service, or extra worktree command layer.

Use `git agent -h` or `git agent init --help` for the command's usage text.
Git itself can route `git agent --help` to its manual viewer; no manpage package
is needed for the supported help commands. Direct `git-agent --help` also works.

## Requirements and installation

- Bash **3.2 or newer**, Git **2.31 or newer**, and stock Unix command utilities.
- On Linux and macOS, use the normal Bash environment.
- On Windows, use **Git Bash from the full Git for Windows distribution**.
  Bare Windows, MinGit, and PowerShell alone are outside the supported shell
  environment.
- Initialization and installation need a filesystem supporting regular-file
  hard links within the destination directory.

These dependencies are supplied by the supported host environment, not downloaded
by this project. The initializer does not require Codex to be running.

From a reviewed source checkout, in Bash:

```sh
bash tools/build.sh
bash tests/run.sh
bash tools/smoke.sh
bash tools/install.sh --bin-dir "$HOME/.local/bin"
```

Make that directory available on the current shell's `PATH`, then verify:

```sh
export PATH="$HOME/.local/bin:$PATH"
git agent --version
git agent -h
```

The default installation is the single file `~/.local/bin/git-agent`, including
on Git Bash. The installer reports its actual destination. It does not modify
`PATH`, shell profiles, Git configuration, or other installed commands. Identical
reinstallation preserves bytes and timestamps; different files and symlinks
are refused.

The checked-in `bin/git-agent` is already a standalone text executable. Run it
directly without installation if preferred:

```sh
bash bin/git-agent init /path/to/product --dry-run
```

See [installation.md](docs/installation.md) for upgrades, Windows use, collisions,
source changes, and recovery.

This project is available under the [MIT License](LICENSE). Contributions are
welcome; see [CONTRIBUTING.md](CONTRIBUTING.md). Report security concerns using
the process in [SECURITY.md](SECURITY.md).

## Use it in a project

Preview and initialize an existing or new project:

```sh
git agent init /path/to/product --dry-run
git agent init /path/to/product
```

Omitting the directory uses the current directory. Existing subdirectories
resolve to their worktree root. Linked worktrees are discovered through Git.
Missing paths inside an existing repository are rejected to avoid unexpectedly
initializing or modifying a different root.

A real run initializes Git when needed and creates eligible missing guidance.
A dry run describes the plan and gaps without creating the target directory,
initializing Git, or writing repository files.

Read the generated adoption record in `docs/agent-init/README.md`, review the
result with Git, fill in unresolved product choices, and adopt instructions
under the project's accepted authority. Then verify that the VS Code Codex
extension discovers the intended instructions, skills, and roles.

The command does not stage, commit, push, run product scripts or hooks, start
services, or configure GitHub rules. It does not change global Codex settings or
credentials.

## What the structure provides

| Responsibility | Repository material |
| --- | --- |
| Instruction entry point | A short `AGENTS.md` linking to applicable guidance |
| Accepted planned work | `PLANS.md`, goals, multiple branches, and progress/evidence guidance |
| Decision authority | Governance, bounded exceptions, accepted rule changes, and human review requirements |
| Architecture and development | Product/module boundaries, shared commands, compatibility, and isolated worktree execution |
| Goal development | `.agents/skills/work-goal/SKILL.md` |
| Worktree flow | `.agents/skills/worktree-flow/SKILL.md` |
| Review setup | Review guides and native Codex roles/configuration with adoption choices exposed |
| Release and recovery | Release identity, operational ownership, checkpoint ordering, retention, and restore demonstrations |
| Adoption record | Initializer provenance and choices requiring product decisions |

The proposed review baseline uses two independent reviewers and at most three
rounds. Counts and guides are project policy and can be changed through accepted
governance. Model selection uses supported native Codex settings. Human review
remains required before a version-producing merge.

Generated evidence, logs, screenshots and build artifacts belong in ignored
local paths while work is under review. Keep concise outcomes and PR/CI links in
Git; remove local generated copies after feature code merges. Source comments
should be sparse; use PR discussion and Git blame for change history.
The initializer preserves an existing `.gitignore`; adoption includes adding
evidence and artifact ignore rules in the product repository.

## Preservation, reruns, and concurrent initialization

Existing guidance is project content. Recognized governance, development,
architecture, and planning documents are preserved and linked, with an explicit
responsibility-review gap. Existing instructions, native configuration, skills,
and adoption records are preserved. Conflicting template content goes outside
native discovery paths at
`docs/agent-init/proposals/<version>-<digest>/<original-relative-path>`.

Review proposals under the project's existing authority. Rerunning does not
approve them. A same-version rerun preserves unchanged bytes, modes, and
timestamps. Edited proposals are preserved and require reconciliation.

Deliberately deleted files still owned by Git's index or `HEAD` remain absent.
This includes adopted guidance aliases and sparse-checkout omissions. Template
copies are proposed separately. Missing scaffold files with no index or `HEAD`
ownership can be created, allowing interrupted initialization to resume.

Ignored untracked scaffold paths produce retention gaps on initial runs and
reruns, even when content is unchanged. A successful initializer exit does not
establish a complete retained checkpoint.

Each new file is fully staged before atomic, create-only hard-link publication.
Cooperating initializers can converge on identical content without a persistent
semaphore. Existing differing content is never replaced. This is complete-file
publication per file on a supported filesystem; it is not a transaction across
all scaffold files, a power-loss durability guarantee, or a security boundary
against another process actively changing ancestor paths.

## Exit codes

| Code | Meaning |
| --- | --- |
| `0` | Initialization or preview completed; adoption gaps may remain. |
| `2` | Invalid invocation or fatal prerequisite, path, collision, or initialization error. |
| `3` | Reviewable proposals require an adoption decision. |
| `130` | Interrupted; inspect the result and rerun to complete eligible missing files. |
| `143` | Terminated by SIGTERM; inspect partial results before resuming. |

Zero does not establish production readiness, configured release controls, or
demonstrated recovery objectives.

## Configuration and inspection boundaries

The generated repository uses documented Codex instruction, skill, configuration,
and role mechanisms. Goals, reviewer counts, rounds, evidence, and governance are
explicit project conventions, not invented native Codex configuration keys.

The Bash initializer discovers relevant files and reports setup gaps. It does
not embed a JSON or TOML parser, infer commands by executing manifests, or claim
that existing configuration syntax was validated. Use existing product validation
commands and Codex's own configuration handling for those checks. Product-specific
commands remain visibly `UNCONFIGURED` until adopted.

A model change requires applicable calibration evidence; it does not establish
equivalent behavior automatically. The source map distinguishes platform
documentation, standards, and project conventions. The scaffold does not confer
standards compliance.

## Build and verification

`src/git-agent.sh` is the implementation; `templates/` contains reviewed
instruction and configuration source. `tools/build.sh` embeds all 15 declared
templates in quoted, literal heredocs and appends command dispatch. Template
contents are never evaluated as shell code. The same inputs produce identical
`bin/git-agent` bytes.

Build and install preserve identical output and refuse differing output. After
editing source or templates, use an empty `--output` path for a candidate, or
inspect and remove the confirmed generated `bin/git-agent` before rebuilding.
There is no force-overwrite flag.

See [verification.md](docs/verification.md) for actual executed checks, review
findings, and remaining platform/product validation. Local checks are:

```sh
bash tools/build.sh
bash tests/run.sh
bash tools/smoke.sh
```

The smoke exercise installs into a disposable path containing spaces, invokes
the command through Git outside the source tree, and checks embedded resources,
dry-run and rerun preservation, and installer collisions. The GitHub workflow
declares Linux, macOS, and Git Bash checks, with macOS explicitly using its
`/bin/bash`. It has read-only repository permissions and no deployment steps.
The reproducible checks, observed results, and support limits are recorded in
[verification.md](docs/verification.md). Current hosted results appear in the
repository's Actions tab and on each pull request.

## Recovery

The source repository is [ElevenID/git-agent](https://github.com/ElevenID/git-agent).
Retain accepted source revisions there.
After a workstation loss, restore Git and the supported Bash environment, clone
that revision, run the checks, and install the single command. No language
package environment needs reconstructing for this tool.

Product recovery starts from retained goal and source-branch checkpoints. Adopted
instructions and skills remain usable after cloning, even if the global
initializer is absent. Account access, credentials, transient review evidence, runtime
inputs, and production data need their own recorded recovery paths.
