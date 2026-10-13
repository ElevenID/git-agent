# Installation and recovery

`git-agent` is an external Git command. Git dispatches `git agent ...` to the
executable named `git-agent` on its command search path. No Git alias or global
Git configuration is required. See the official
[Git command documentation](https://git-scm.com/docs/git).

## Prerequisites and supported environments

- Bash **3.2 or newer** and Git **2.31 or newer**.
- Stock Unix utilities from the supported shell environment, including `cat`,
  `chmod`, `cmp`, `ln`, `mkdir`, `mktemp`, `rm`, `rmdir`, and `wc`. Developer checks
  also use ordinary file utilities such as `cp`, `dirname`, and `find`.
- A filesystem supporting regular-file hard links within each destination
  directory.
- A reviewed source revision or standalone executable.

Linux and macOS use their Bash environment. Windows uses **Git Bash supplied by
the full [Git for Windows](https://gitforwindows.org/) distribution**. The
[MinGit distribution](https://gitforwindows.org/mingit) intentionally omits Bash
and is not sufficient on its own. Bare Windows and PowerShell alone do not
supply this command's required shell environment.

No Python, Node.js, Perl, jq, package manager, downloaded language library,
`flock`, or background service is required to run, build, install, or test this
project. Each product retains its own stack requirements.

The VS Code Codex extension is used for the later agent workflow. The initializer
and installer do not invoke it. Its discovery, account, permission, trust, and
model settings must be verified in the adopting environment.

Publication stages complete content privately and uses a native hard link to
create the destination only if absent. Unsupported filesystems fail visibly.
Rerunning on a supported target can resume eligible missing scaffold files.
There is no per-file `fsync` claim or multi-file transaction; sudden machine or
storage loss is covered by retained checkpoints and recovery practices.

See [verification.md](verification.md) for executed validation and the CI matrix.
Actual Codex integration remains an adoption check for each project.

## Install from a source checkout

Use Bash on Linux/macOS, or open **Git Bash** on Windows. From the source root:

```sh
bash tools/build.sh
bash tests/run.sh
bash tools/smoke.sh
bash tools/install.sh
```

The default destination is `~/.local/bin/git-agent` on all supported shells.
Choose another destination with:

```sh
bash tools/install.sh --bin-dir "/your/selected/bin"
```

In Git Bash, use its ordinary path syntax, including paths containing spaces:

```sh
bash tools/install.sh --bin-dir "/c/Tools/git-agent/bin"
```

Exactly **one text executable**, `git-agent`, is installed. It contains the Bash
implementation and all templates. It needs no source checkout, adjacent archive,
environment file, or interpreter path recorded at installation.

Make the selected directory available to Git on `PATH` using normal shell
configuration. A temporary change in the current Bash session is:

```sh
export PATH="$HOME/.local/bin:$PATH"
git agent --version
git agent -h
```

The installer reports its destination and does not edit profiles or `PATH`.
On Windows, use Git Bash; invocation of an extensionless Bash script directly
by PowerShell is not the supported entry point.

Use `git agent -h` or `git agent init --help` for application usage. Git can
interpret `git agent --help` as a request for a manual page and invoke a manual
viewer; this project requires neither a manpage package nor a `man` executable.
Direct `git-agent --help` also prints the command's usage.

## Use the built command without installation

A built command can be inspected as plain text and run directly:

```sh
bash /path/to/git-agent --help
bash /path/to/git-agent init /path/to/product --dry-run
```

For native Git dispatch, install under the name `git-agent` in a directory on
`PATH`. The included installer checks collisions and publishes a complete file.
If installing manually, review the destination and preserve any existing command.

The executable starts with `#!/usr/bin/env bash`; native Git dispatch uses Bash
from that shell's `PATH`. Git Bash supplies this environment on Windows. No claim
is made that every Git-only installation supplies Bash.

## Collisions, repeat installs, and upgrades

Build and install never overwrite differing output. Existing symlinks, including
dangling ones, are refused. Exact repeated output is a no-op preserving bytes and
timestamps. An identical file lacking executable permission requires an explicit
decision; the installer does not silently chmod it.

With the default destination, another `git-agent` found on `PATH` causes a stop.
Select an explicit `--bin-dir` after deciding which command should be used.
Explicit selection does not permit overwriting that directory's content. The
installer does not execute a preexisting command to identify it.

For a reviewed upgrade, install into a new empty directory. Exercise version
reporting and a dry run with that directory on the current session's `PATH`, then
update the usual `PATH` after acceptance. Alternatively, inspect and remove only
the confirmed prior installation, then rerun the installer. There is no force flag.

The 0.1.0 Python distribution used a supporting `git-agent.pyz` on Windows. If
removing a confirmed 0.1.0 Windows installation, both its launcher and that
archive belong to the old installation. Version 0.2.0 leaves unrelated or old
files untouched and installs only its one command.

A new initializer version does not automatically adopt governance in existing
products. Review proposed changes using each project's accepted rules.

## Build from modified source

The checked-in `bin/git-agent` is generated from `src/git-agent.sh` and 15
declared files under `templates/`. Matching output is a no-op. Different content
at the output path is refused.

After editing source or templates, create a candidate at an empty path:

```sh
bash tools/build.sh --output /tmp/git-agent-candidate
bash /tmp/git-agent-candidate --help
```

To refresh the checkout's executable, inspect and remove its confirmed generated
output, then rebuild and validate:

```sh
rm bin/git-agent
bash tools/build.sh
bash tests/run.sh
bash tools/smoke.sh
git diff -- src templates bin tools tests
```

That removal concerns a reproducible build artifact; source and templates remain
the maintained inputs. It is not an upgrade instruction for unknown installed
commands. Packaging does not execute source or template content. It checks the
resulting Bash syntax before publishing.

Quoted heredocs preserve template bodies literally, including shell-looking
text. Templates must be regular, NUL-free text ending with an LF newline. If a
template contains the proposed delimiter as a complete line, the builder chooses
a different delimiter deterministically. Retain the repository's LF checkout
rules when editing from Windows.

Identical inputs produce identical generated bytes. The build reports a Git blob
identity using SHA-1: a comparison record, not a publisher signature or a SHA-256
security claim. Template identity is likewise labelled `git-blob-sha1` and is
independent of the target repository's object format.

## Project reruns and retention

Missing scaffold files without index or `HEAD` ownership may be created on a
rerun. Deliberately deleted tracked content, including aliases and sparse
checkout omissions, remains absent. Copies go to reported proposal paths; the
initializer does not restore deletions or approve proposals.

Untracked scaffold paths covered by ignore rules are reported on initial runs
and reruns, even if unchanged. Resolve retention before claiming a complete
checkpoint. Initialization does not edit ignore rules or stage files to clear
that gap.

The initializer identifies setup files and responsibility gaps. It does not
parse JSON or TOML, execute product manifests, or validate Codex configuration
syntax. Use existing product validation and Codex's configuration handling.

## Uninstall

Inspect the reported installation path and confirm it still belongs to this
installation. Remove that one `git-agent` file. Leave the parent directory if it
contains other commands. Remove a manually added dedicated `PATH` entry through
the same configuration mechanism used to add it.

Uninstallation does not remove adopted guidance or change repositories,
worktrees, GitHub settings, or other development tools.

## Source and workstation recovery

1. Retain the reviewed source commit, origin, and Git/Bash requirements in the
   project's recovery record.
2. Recover account access. Restore Git and the supported Bash environment on the
   replacement machine, then clone the accepted source revision.
3. Verify the revision. Run build, tests, and smoke, install locally, and verify
   native Git dispatch.
4. Restore products from their retained goal and branch checkpoints. Follow each
   product's instructions for runtime inputs, configuration, credentials,
   external evidence, and separate production data.

Adopted product instructions and skills guide normal development after cloning,
even if the global initializer has not been installed.

## Workflow provenance

The workflow uses only the checkout action and tools in this tree. It requires
no language installation, framework download, or lint action. Linux uses Bash;
macOS explicitly uses `/bin/bash` and system command paths; Windows uses Git Bash.

The checkout action remains pinned to the full commit verified from its official
release repository on 2026-10-10:

| Action | Reviewed release | Pinned commit |
| --- | --- | --- |
| `actions/checkout` | [v7.0.1](https://github.com/actions/checkout/releases/tag/v7.0.1) | [3d3c42e5aac5ba805825da76410c181273ba90b1](https://github.com/actions/checkout/commit/3d3c42e5aac5ba805825da76410c181273ba90b1) |

Pinned actions still require review of upstream changes. Hosted images can
change; logs report observed Bash and Git versions. This is not a frozen hosted
build environment.
