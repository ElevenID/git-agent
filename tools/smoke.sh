#!/usr/bin/env bash
# Exercise only the installed single-file command in disposable directories.
set -euo pipefail

ga_smoke_fail() { printf 'Smoke failed: %s\n' "$*" >&2; exit 2; }
if (( BASH_VERSINFO[0] < 3 || (BASH_VERSINFO[0] == 3 && BASH_VERSINFO[1] < 2) )); then
    ga_smoke_fail 'Bash 3.2 or newer is required.'
fi
GA_SMOKE_ROOT=$(CDPATH= cd -P -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
for ga_utility in bash cat cmp cp dirname find git ln mkdir mktemp rm; do
    command -v "$ga_utility" >/dev/null 2>&1 || ga_smoke_fail "Required standard utility is missing: $ga_utility"
done
[[ -f "$GA_SMOKE_ROOT/bin/git-agent" && ! -L "$GA_SMOKE_ROOT/bin/git-agent" ]] || ga_smoke_fail 'Build bin/git-agent first with bash tools/build.sh.'
GA_SMOKE_WORK=$(mktemp -d "${TMPDIR:-/tmp}/git-agent-smoke.XXXXXX") || ga_smoke_fail 'Could not create disposable workspace.'
GA_SMOKE_WORK=$(CDPATH= cd -P -- "$GA_SMOKE_WORK" && pwd -P)
ga_smoke_cleanup() {
    if [[ -n "$GA_SMOKE_WORK" && -d "$GA_SMOKE_WORK" && ! -L "$GA_SMOKE_WORK" ]]; then
        rm -rf "$GA_SMOKE_WORK"
    fi
}
trap ga_smoke_cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# The tests must not inherit caller routing, alternate indexes, hooks, or global
# configuration. Variable names are inspected; their values are never executed.
for ga_variable in ${!GIT_@}; do unset "$ga_variable"; done
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL="$GA_SMOKE_WORK/empty-config"
export GIT_OPTIONAL_LOCKS=0
export GIT_TERMINAL_PROMPT=0
: > "$GIT_CONFIG_GLOBAL"
mkdir "$GA_SMOKE_WORK/outside" "$GA_SMOKE_WORK/expectations"
CDPATH= cd -P -- "$GA_SMOKE_WORK/outside"

ga_smoke_run() {
    ga_expected=$1; shift
    ga_code=0
    "$@" > "$GA_SMOKE_WORK/last.stdout" 2> "$GA_SMOKE_WORK/last.stderr" || ga_code=$?
    if [[ "$ga_code" != "$ga_expected" ]]; then
        cat "$GA_SMOKE_WORK/last.stdout" "$GA_SMOKE_WORK/last.stderr" >&2
        ga_smoke_fail "Expected exit $ga_expected, got $ga_code for: $*"
    fi
}

ga_bin="$GA_SMOKE_WORK/bin with spaces"
ga_smoke_run 0 "$BASH" "$GA_SMOKE_ROOT/tools/install.sh" --bin-dir "$ga_bin"
cp -p "$ga_bin/git-agent" "$GA_SMOKE_WORK/expectations/installed"
ga_smoke_run 0 "$BASH" "$GA_SMOKE_ROOT/tools/install.sh" --bin-dir "$ga_bin"
cmp -s "$ga_bin/git-agent" "$GA_SMOKE_WORK/expectations/installed" || ga_smoke_fail 'Identical reinstall changed executable bytes.'
[[ ! "$ga_bin/git-agent" -nt "$GA_SMOKE_WORK/expectations/installed" && ! "$ga_bin/git-agent" -ot "$GA_SMOKE_WORK/expectations/installed" ]] || ga_smoke_fail 'Identical reinstall changed its timestamp.'
export PATH="$ga_bin:$PATH"
ga_smoke_run 0 git agent --version
ga_smoke_run 0 git agent -h
[[ $(<"$GA_SMOKE_WORK/last.stdout") = *'usage: git agent init [directory] [--dry-run]'* ]] || ga_smoke_fail 'Native Git dispatch did not return initializer usage.'
ga_smoke_run 0 git agent init --help
[[ $(<"$GA_SMOKE_WORK/last.stdout") = *'usage: git agent init [directory] [--dry-run]'* ]] || ga_smoke_fail 'Initializer help did not return the expected usage.'

ga_candidate="$GA_SMOKE_WORK/candidate with spaces"
ga_smoke_run 0 git agent init "$ga_candidate" --dry-run
[[ ! -e "$ga_candidate" && ! -L "$ga_candidate" ]] || ga_smoke_fail 'Dry run created its target.'
ga_smoke_run 0 git agent init "$ga_candidate"
for ga_relative in AGENTS.md .agents/skills/work-goal/SKILL.md .agents/skills/worktree-flow/SKILL.md .codex/config.toml; do
    [[ -f "$ga_candidate/$ga_relative" ]] || ga_smoke_fail "Installed executable did not render $ga_relative"
done
cp -R -p "$ga_candidate" "$GA_SMOKE_WORK/expectations/candidate"
ga_smoke_run 0 git -C "$ga_candidate" status --porcelain=v1
cp "$GA_SMOKE_WORK/last.stdout" "$GA_SMOKE_WORK/expectations/status"
ga_smoke_run 0 git -C "$ga_candidate" agent init
ga_smoke_run 0 git -C "$ga_candidate" status --porcelain=v1
cmp -s "$GA_SMOKE_WORK/last.stdout" "$GA_SMOKE_WORK/expectations/status" || ga_smoke_fail 'Initializer rerun changed Git status.'

# Fixture names are controlled and contain no newlines. Include Git metadata so
# this exercises preservation of repository state as well as rendered templates.
(CDPATH= cd -P -- "$ga_candidate" && find . -type f -print) > "$GA_SMOKE_WORK/actual-files"
(CDPATH= cd -P -- "$GA_SMOKE_WORK/expectations/candidate" && find . -type f -print) > "$GA_SMOKE_WORK/expected-files"
# Filesystem traversal order may differ after copying; compare both sets through
# membership and content instead of depending on GNU sort extensions.
ga_actual_count=0
while IFS= read -r ga_relative; do
    ga_actual_count=$((ga_actual_count + 1))
    ga_actual="$ga_candidate/$ga_relative"
    ga_expected_file="$GA_SMOKE_WORK/expectations/candidate/$ga_relative"
    [[ -f "$ga_expected_file" ]] || ga_smoke_fail "Rerun created an unexpected file: $ga_relative"
    cmp -s "$ga_actual" "$ga_expected_file" || ga_smoke_fail "Rerun changed bytes: $ga_relative"
    [[ ! "$ga_actual" -nt "$ga_expected_file" && ! "$ga_actual" -ot "$ga_expected_file" ]] || ga_smoke_fail "Rerun changed timestamp: $ga_relative"
    if [[ -x "$ga_actual" ]]; then
        [[ -x "$ga_expected_file" ]] || ga_smoke_fail "Rerun changed executable mode: $ga_relative"
    else
        [[ ! -x "$ga_expected_file" ]] || ga_smoke_fail "Rerun changed executable mode: $ga_relative"
    fi
done < "$GA_SMOKE_WORK/actual-files"
ga_expected_count=0
while IFS= read -r ga_relative; do ga_expected_count=$((ga_expected_count + 1)); done < "$GA_SMOKE_WORK/expected-files"
[[ "$ga_actual_count" = "$ga_expected_count" ]] || ga_smoke_fail 'Rerun removed a file.'

ga_collision="$GA_SMOKE_WORK/collision bin"
mkdir "$ga_collision"
printf '%s\n' 'foreign command; preserve me' > "$ga_collision/git-agent"
cp -p "$ga_collision/git-agent" "$GA_SMOKE_WORK/expectations/foreign"
ga_smoke_run 2 "$BASH" "$GA_SMOKE_ROOT/tools/install.sh" --bin-dir "$ga_collision"
cmp -s "$ga_collision/git-agent" "$GA_SMOKE_WORK/expectations/foreign" || ga_smoke_fail 'Installer replaced foreign content.'
[[ ! "$ga_collision/git-agent" -nt "$GA_SMOKE_WORK/expectations/foreign" && ! "$ga_collision/git-agent" -ot "$GA_SMOKE_WORK/expectations/foreign" ]] || ga_smoke_fail 'Installer changed a foreign timestamp.'

ga_symlink_dir="$GA_SMOKE_WORK/symlink bin"
mkdir "$ga_symlink_dir"
ga_symlink_result='skipped: host does not create native symbolic links'
if ln -s "$GA_SMOKE_WORK/expectations/foreign" "$ga_symlink_dir/git-agent" > "$GA_SMOKE_WORK/symlink.stdout" 2> "$GA_SMOKE_WORK/symlink.stderr" && [[ -L "$ga_symlink_dir/git-agent" ]]; then
    ga_smoke_run 2 "$BASH" "$GA_SMOKE_ROOT/tools/install.sh" --bin-dir "$ga_symlink_dir"
    [[ -L "$ga_symlink_dir/git-agent" ]] || ga_smoke_fail 'Installer replaced a symlink.'
    cmp -s "$ga_collision/git-agent" "$GA_SMOKE_WORK/expectations/foreign" || ga_smoke_fail 'Installer modified the symlink target.'
    ga_symlink_result=passed
fi

printf '%s\n' 'Packaged smoke passed: isolated Git dispatch, embedded resources, dry-run, reruns, and installer collisions.'
printf 'Native symlink preservation: %s\n' "$ga_symlink_result"
printf 'Observed Bash: %s\n' "$BASH_VERSION"
git --version
