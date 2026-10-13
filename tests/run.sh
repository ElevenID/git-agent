#!/usr/bin/env bash
# Real, isolated Git integration tests. Bash 3.2+, Git and stock shell tools only.
# Run: bash tools/build.sh && bash tests/run.sh [test-name-substring]
# No network, Codex client, Python, package manager or external test framework.
set -e

TESTS_DIR=$(CDPATH= cd -P -- "${BASH_SOURCE[0]%/*}" && pwd -P)
SOURCE_ROOT=${TESTS_DIR%/*}
CLI="$SOURCE_ROOT/bin/git-agent"
TEST_SCRIPT="$TESTS_DIR/run.sh"
SKILL_GOAL=.agents/skills/work-goal/SKILL.md
SKILL_TREE=.agents/skills/worktree-flow/SKILL.md
PROVENANCE=docs/agent-init/README.md

# Isolate Git from ambient worktree routing, injected configuration and templates.
# Do not replace HOME or modify the user's Git configuration.
for test_env_name in $(compgen -v GIT_); do unset "$test_env_name"; done
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_TERMINAL_PROMPT=0 GIT_OPTIONAL_LOCKS=0 LC_ALL=C LANG=C
shopt -s nullglob dotglob

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    if [[ -n ${OUT:-} && -f $OUT ]]; then
        printf 'Last stdout:\n' >&2
        cat "$OUT" >&2
        printf 'Last stderr:\n' >&2
        cat "$ERR" >&2
    fi
    exit 1
}

skip() { printf 'SKIP: %s\n' "$*"; exit 77; }

run() {
    local directory=$1
    shift
    LAST_COMMAND=("$@")
    if (CDPATH= cd -- "$directory" && "$@") >"$OUT" 2>"$ERR"; then
        RC=0
    else
        RC=$?
    fi
}

cli() { run "$SPACE" "$CLI" "$@"; }
fixture_git() { git -c core.fsmonitor=false -c submodule.recurse=false "$@"; }

expect_status() {
    [[ $RC -eq $1 ]] || {
        printf 'Command: ' >&2
        printf '%q ' "${LAST_COMMAND[@]}" >&2
        printf '\nExpected status %s, got %s\n' "$1" "$RC" >&2
        fail 'unexpected command status'
    }
}

contains() {
    [[ $(<"$1") == *"$2"* ]] || fail "expected '$2' in $1"
}

contains_ci() {
    local text
    text=$(tr '[:upper:]' '[:lower:]' <"$1")
    [[ $text == *"$2"* ]] || fail "expected '$2' (case insensitive) in $1"
}

same() {
    if ! cmp -s "$1" "$2"; then
        diff -u "$1" "$2" >&2 || :
        fail "files differ: $1 / $2"
    fi
}

metadata() {
    if [[ $STAT_STYLE == gnu ]]; then
        stat -c '%a:%y' -- "$1"
    else
        stat -f '%Lp:%m' "$1"
    fi
}

# NUL-safe glob traversal, with Bash-escaped relative paths. Read-only Git hashing
# fingerprints file bytes without requiring a separate digest implementation.
# GNU stat records nanoseconds; BSD stat records seconds. The dedicated no-op
# fixture ages its tree first so a same-second rewrite cannot escape that check.
snapshot_walk() {
    local path=$1 relative=$2 child info digest
    info=$(metadata "$path")
    if [[ -L $path ]]; then
        digest=$(readlink "$path" | fixture_git hash-object --stdin)
        printf 'L\t%q\t%s\t%s\n' "$relative" "$info" "$digest"
    elif [[ -d $path ]]; then
        printf 'D\t%q\t%s\n' "$relative" "$info"
        for child in "$path"/*; do
            snapshot_walk "$child" "$relative/${child##*/}"
        done
    elif [[ -f $path ]]; then
        digest=$(fixture_git hash-object --no-filters -- "$path")
        printf 'F\t%q\t%s\t%s\n' "$relative" "$info" "$digest"
    else
        printf 'S\t%q\t%s\n' "$relative" "$info"
    fi
}

snapshot() {
    if [[ -e $1 || -L $1 ]]; then snapshot_walk "$1" . >"$2";
    else printf 'ABSENT\n' >"$2"; fi
}

age_tree() {
    local path=$1 child
    if [[ -d $path && ! -L $path ]]; then
        for child in "$path"/*; do age_tree "$child"; done
    fi
    [[ -L $path ]] || touch -t 200001020304.05 "$path"
}

repository() {
    TARGET="$SPACE/${1:-repo}"
    mkdir -p "$TARGET"
    fixture_git -C "$TARGET" init --quiet --initial-branch=main
    if [[ ${2:-} == commit ]]; then
        printf 'baseline product\n' >"$TARGET/product.txt"
        fixture_git -C "$TARGET" add -- product.txt
        commit_fixture "$TARGET" 'Fixture baseline'
    fi
}

commit_fixture() {
    fixture_git -C "$1" -c user.name='Initializer Test' \
        -c user.email=initializer-test@example.invalid commit --quiet -m "$2"
}

committed_scaffold() {
    repository "$1"
    if [[ ${2:-} == alias ]]; then
        mkdir "$TARGET/docs"
        printf '# Accepted development guidance\nUse maintained product commands.\n' >"$TARGET/docs/development.md"
    fi
    cli init "$TARGET"; expect_status 0
    printf 'tracked product\n' >"$TARGET/product.txt"
    fixture_git -C "$TARGET" add --all
    commit_fixture "$TARGET" 'Accept fixture scaffold'
}

assert_scaffold() {
    local target=$1 relative
    for relative in AGENTS.md GOVERNANCE.md DEVELOPMENT.md ARCHITECTURE.md PLANS.md \
        "$PROVENANCE" .codex/config.toml \
        .codex/agents/contract-reviewer.toml .codex/agents/adversarial-reviewer.toml \
        "$SKILL_GOAL" "$SKILL_TREE" \
        .agents/skills/work-goal/references/review-guide.md \
        .agents/skills/work-goal/references/release-lifecycle.md \
        .agents/skills/work-goal/references/state-report.md \
        .agents/skills/worktree-flow/references/isolation-and-recovery.md; do
        [[ -s $target/$relative ]] || fail "missing scaffold: $relative"
    done
    contains "$target/$SKILL_GOAL" 'name: work-goal'
    contains "$target/$SKILL_TREE" 'name: worktree-flow'
    contains "$target/$SKILL_GOAL" 'description:'
    contains "$target/$SKILL_TREE" 'description:'
    contains "$target/$PROVENANCE" "$VERSION"
}

proposal_for() {
    local matches
    matches=("$1/docs/agent-init/proposals/$VERSION-"*/"$2")
    [[ ${#matches[@]} -eq 1 ]] || fail "expected one proposal for $2, got ${#matches[@]}"
    PROPOSAL=${matches[0]}
    [[ -s $PROPOSAL ]] || fail "empty proposal: $PROPOSAL"
}

reject_without_writes() {
    local target=$1 watched=${2:-$SPACE}
    snapshot "$watched" "$CASE_DIR/before"
    cli init "$target"; expect_status 2
    snapshot "$watched" "$CASE_DIR/after"
    same "$CASE_DIR/before" "$CASE_DIR/after"
}

assert_owned_deletion() {
    local target=$1 relative=$2 additional=${3:-}
    snapshot "$target/.git" "$CASE_DIR/admin-before"
    cli init "$target"; expect_status 3
    [[ ! -e $target/$relative ]] || fail "deleted path recreated: $relative"
    [[ -z $additional || ! -e $target/$additional ]] || fail "canonical guidance recreated: $additional"
    proposal_for "$target" "$relative"
    snapshot "$target/.git" "$CASE_DIR/admin-after"
    same "$CASE_DIR/admin-before" "$CASE_DIR/admin-after"
    snapshot "$target" "$CASE_DIR/before"
    cli init "$target"; expect_status 3
    snapshot "$target" "$CASE_DIR/after"
    same "$CASE_DIR/before" "$CASE_DIR/after"
}

test_help_version_and_unknown_commands() {
    local arg
    snapshot "$SPACE" "$CASE_DIR/before"
    for arg in --help --version; do cli "$arg"; expect_status 0; [[ -s $OUT ]]; done
    cli init --help; expect_status 0
    for arg in start test review status restore; do cli "$arg"; expect_status 2; done
    snapshot "$SPACE" "$CASE_DIR/after"; same "$CASE_DIR/before" "$CASE_DIR/after"
}

test_native_git_dispatch() {
    run "$SPACE" env "PATH=$SOURCE_ROOT/bin:$PATH" git agent --version
    expect_status 0; contains "$OUT" "$VERSION"
    run "$SPACE" env "PATH=$SOURCE_ROOT/bin:$PATH" git agent -h
    expect_status 0; contains "$OUT" 'usage: git agent init'
    run "$SPACE" env "PATH=$SOURCE_ROOT/bin:$PATH" git agent init --help
    expect_status 0; contains "$OUT" 'usage: git agent init'
    repository repo
    snapshot "$TARGET/.git" "$CASE_DIR/before"
    run "$SPACE" env "PATH=$SOURCE_ROOT/bin:$PATH" git -C "$TARGET" agent init
    expect_status 0; assert_scaffold "$TARGET"
    snapshot "$TARGET/.git" "$CASE_DIR/after"; same "$CASE_DIR/before" "$CASE_DIR/after"
}

test_new_repository_stays_unstaged_uncommitted() {
    local reported_root
    TARGET="$SPACE/new project with spaces"
    cli init "$TARGET"; expect_status 0; assert_scaffold "$TARGET"
    [[ -d $TARGET/.git ]]
    reported_root=$(fixture_git -C "$TARGET" rev-parse --show-toplevel) ||
        fail 'Git could not report the new repository root'
    # Git for Windows and Bash can spell the same directory differently.
    [[ $TARGET -ef $reported_root ]] ||
        fail "Git reports a different repository root: $reported_root"
    [[ -z $(fixture_git -C "$TARGET" diff --cached --name-only) ]]
    if fixture_git -C "$TARGET" rev-parse --verify HEAD >/dev/null 2>&1; then fail 'unexpected commit'; fi
    [[ -z $(fixture_git -C "$TARGET" remote) ]]
}

test_plain_directory_preserves_product() {
    TARGET="$SPACE/plain project"; mkdir "$TARGET"
    printf '{"name":"fixture","scripts":{"test":"existing-product-test"}}\n' >"$TARGET/package.json"
    snapshot "$TARGET/package.json" "$CASE_DIR/before"
    cli init "$TARGET"; expect_status 0; assert_scaffold "$TARGET"
    snapshot "$TARGET/package.json" "$CASE_DIR/after"; same "$CASE_DIR/before" "$CASE_DIR/after"
}

test_manifest_and_config_inspection_is_explicitly_unverified() {
    repository repo
    mkdir "$TARGET/.codex"
    printf '{"scripts":{"test":"touch COMMAND_EXECUTED"},malformed\n' >"$TARGET/package.json"
    printf 'model = [malformed\n' >"$TARGET/.codex/config.toml"
    snapshot "$TARGET" "$CASE_DIR/before"
    cli init "$TARGET" --dry-run; expect_status 3
    contains_ci "$OUT" 'unverified'
    [[ ! -e $TARGET/COMMAND_EXECUTED ]]
    snapshot "$TARGET" "$CASE_DIR/after"; same "$CASE_DIR/before" "$CASE_DIR/after"
}

test_omitted_directory_uses_current_directory() {
    TARGET="$SPACE/current"; mkdir "$TARGET"
    run "$TARGET" "$CLI" init; expect_status 0; assert_scaffold "$TARGET"
}

test_dry_run_missing_target_writes_nothing() {
    snapshot "$SPACE" "$CASE_DIR/before"
    cli init "$SPACE/missing parent/missing target" --dry-run; expect_status 0
    snapshot "$SPACE" "$CASE_DIR/after"; same "$CASE_DIR/before" "$CASE_DIR/after"
}

test_dry_run_preserves_work_and_git_metadata() {
    repository repo commit
    printf 'staged\n' >"$TARGET/product.txt"; fixture_git -C "$TARGET" add -- product.txt
    printf 'staged plus working edit\n' >"$TARGET/product.txt"
    printf 'untracked\n' >"$TARGET/untracked.txt"
    snapshot "$TARGET" "$CASE_DIR/before"
    cli init "$TARGET" --dry-run; expect_status 0
    snapshot "$TARGET" "$CASE_DIR/after"; same "$CASE_DIR/before" "$CASE_DIR/after"
}

test_dry_run_conflict_creates_no_proposals() {
    repository repo
    printf '# Existing accepted instructions\n' >"$TARGET/AGENTS.md"
    snapshot "$TARGET" "$CASE_DIR/before"
    cli init "$TARGET" --dry-run; expect_status 3
    snapshot "$TARGET" "$CASE_DIR/after"; same "$CASE_DIR/before" "$CASE_DIR/after"
}

test_unusual_product_filenames_are_preserved_without_execution() {
    local names=( $'line\nbreak.txt' $'tab\tname.txt' 'literal\backslash.txt' '$(touch COMMAND_EXECUTED).txt' '--leading.txt' '[glob]*.txt' ) name
    repository repo commit
    mkdir "$TARGET/product files"
    for name in "${names[@]}"; do
        if ! printf 'existing product\n' >"$TARGET/product files/$name"; then
            skip 'host filesystem cannot represent this unusual-filename fixture'
        fi
    done
    fixture_git -C "$TARGET" add -- 'product files'
    printf 'untracked product\n' >"$TARGET/product files/untracked name.txt"
    snapshot "$TARGET/product files" "$CASE_DIR/product-before"
    snapshot "$TARGET/.git" "$CASE_DIR/admin-before"
    cli init "$TARGET"; expect_status 0
    [[ ! -e $TARGET/COMMAND_EXECUTED && ! -e $SPACE/COMMAND_EXECUTED ]]
    snapshot "$TARGET/product files" "$CASE_DIR/product-after"; same "$CASE_DIR/product-before" "$CASE_DIR/product-after"
    snapshot "$TARGET/.git" "$CASE_DIR/admin-after"; same "$CASE_DIR/admin-before" "$CASE_DIR/admin-after"
}

test_shell_metacharacters_in_target_are_literal() {
    TARGET="$SPACE/\$(touch COMMAND_EXECUTED) [*] \\project"
    mkdir "$TARGET" || skip 'host filesystem cannot represent this target-name fixture'
    cli init "$TARGET"; expect_status 0; assert_scaffold "$TARGET"
    [[ ! -e $SPACE/COMMAND_EXECUTED ]]
}

test_control_characters_in_target_are_rejected() {
    local target
    for target in "$SPACE/"$'line\nbreak' "$SPACE/"$'tab\tname'; do
        reject_without_writes "$target"
    done
}

test_subdirectory_resolves_to_worktree_root() {
    repository repo
    mkdir -p "$TARGET/packages/example"
    cli init "$TARGET/packages/example"; expect_status 0; assert_scaffold "$TARGET"
    local entries=("$TARGET/packages/example"/*)
    [[ ${#entries[@]} -eq 0 ]]
}

test_missing_path_inside_repository_is_rejected() {
    repository repo
    reject_without_writes "$TARGET/missing/child" "$TARGET"
}

test_source_index_configuration_and_head_are_preserved() {
    local relative
    repository repo commit
    fixture_git -C "$TARGET" config agent.fixture 'preserve this setting'
    fixture_git -C "$TARGET" remote add origin https://example.invalid/product.git
    printf 'staged\n' >"$TARGET/product.txt"; fixture_git -C "$TARGET" add -- product.txt
    printf 'unstaged\n' >"$TARGET/product.txt"
    printf 'untracked\n' >"$TARGET/scratch.txt"
    for relative in .git/index .git/config .git/HEAD product.txt scratch.txt; do
        snapshot "$TARGET/$relative" "$CASE_DIR/${relative##*/}-before"
    done
    cli init "$TARGET"; expect_status 0
    for relative in .git/index .git/config .git/HEAD product.txt scratch.txt; do
        snapshot "$TARGET/$relative" "$CASE_DIR/${relative##*/}-after"
        same "$CASE_DIR/${relative##*/}-before" "$CASE_DIR/${relative##*/}-after"
    done
    [[ $(fixture_git -C "$TARGET" rev-list --count HEAD) == 1 ]]
}

test_same_version_rerun_is_exact_noop() {
    TARGET="$SPACE/repeat"; cli init "$TARGET"; expect_status 0
    age_tree "$TARGET"
    snapshot "$TARGET" "$CASE_DIR/before"
    cli init "$TARGET"; expect_status 0
    snapshot "$TARGET" "$CASE_DIR/after"; same "$CASE_DIR/before" "$CASE_DIR/after"
}

test_template_identity_is_stable_in_sha256_repository() {
    local baseline="$SPACE/sha1-baseline"
    cli init "$baseline"; expect_status 0
    TARGET="$SPACE/sha256-repo"; mkdir "$TARGET"
    if ! fixture_git -C "$TARGET" init --quiet --initial-branch=main --object-format=sha256; then
        skip 'this Git build does not support SHA-256 repositories'
    fi
    snapshot "$TARGET/.git" "$CASE_DIR/admin-before"
    cli init "$TARGET"; expect_status 0; assert_scaffold "$TARGET"
    same "$baseline/AGENTS.md" "$TARGET/AGENTS.md"
    same "$baseline/$PROVENANCE" "$TARGET/$PROVENANCE"
    snapshot "$TARGET/.git" "$CASE_DIR/admin-after"; same "$CASE_DIR/admin-before" "$CASE_DIR/admin-after"
}

test_linked_worktree_preserves_shared_administration() {
    repository main commit
    local main=$TARGET linked="$SPACE/linked worktree"
    fixture_git -C "$main" worktree add --quiet -b work/linked "$linked"
    [[ -f $linked/.git ]]
    printf 'linked staged\n' >"$linked/product.txt"; fixture_git -C "$linked" add -- product.txt
    printf 'linked working edit\n' >"$linked/product.txt"
    snapshot "$main/.git" "$CASE_DIR/admin-before"
    snapshot "$linked/.git" "$CASE_DIR/marker-before"
    snapshot "$linked/product.txt" "$CASE_DIR/product-before"
    cli init "$linked"; expect_status 0; assert_scaffold "$linked"
    [[ ! -e $main/AGENTS.md ]]
    snapshot "$main/.git" "$CASE_DIR/admin-after"; same "$CASE_DIR/admin-before" "$CASE_DIR/admin-after"
    snapshot "$linked/.git" "$CASE_DIR/marker-after"; same "$CASE_DIR/marker-before" "$CASE_DIR/marker-after"
    snapshot "$linked/product.txt" "$CASE_DIR/product-after"; same "$CASE_DIR/product-before" "$CASE_DIR/product-after"
    snapshot "$linked" "$CASE_DIR/before"
    cli init "$linked"; expect_status 0
    snapshot "$linked" "$CASE_DIR/after"; same "$CASE_DIR/before" "$CASE_DIR/after"
}

test_existing_native_configuration_and_guidance_are_preserved() {
    local relative
    repository repo
    mkdir -p "$TARGET/.codex" "$TARGET/.vscode" "$TARGET/.github/workflows"
    for relative in GOVERNANCE.md DEVELOPMENT.md ARCHITECTURE.md PLANS.md; do
        printf '# Accepted %s\nPreserve the maintained rules.\n' "$relative" >"$TARGET/$relative"
    done
    printf 'model = "existing-model-binding"\n' >"$TARGET/.codex/config.toml"
    printf '{"version":"2.0.0","tasks":[]}\n' >"$TARGET/.vscode/tasks.json"
    printf 'name: Existing product\non: workflow_dispatch\njobs: {}\n' >"$TARGET/.github/workflows/product.yml"
    for relative in GOVERNANCE.md DEVELOPMENT.md ARCHITECTURE.md PLANS.md .codex/config.toml .vscode/tasks.json .github/workflows/product.yml; do
        snapshot "$TARGET/$relative" "$CASE_DIR/${relative##*/}-before"
    done
    cli init "$TARGET"; [[ $RC == 0 || $RC == 3 ]] || fail 'initialization failed'
    for relative in GOVERNANCE.md DEVELOPMENT.md ARCHITECTURE.md PLANS.md .codex/config.toml .vscode/tasks.json .github/workflows/product.yml; do
        snapshot "$TARGET/$relative" "$CASE_DIR/${relative##*/}-after"
        same "$CASE_DIR/${relative##*/}-before" "$CASE_DIR/${relative##*/}-after"
    done
}

test_unstaged_instruction_deletion_is_preserved() {
    committed_scaffold repo
    rm "$TARGET/AGENTS.md"
    assert_owned_deletion "$TARGET" AGENTS.md
}

test_staged_instruction_deletion_is_preserved() {
    committed_scaffold repo
    fixture_git -C "$TARGET" rm --quiet -- AGENTS.md
    assert_owned_deletion "$TARGET" AGENTS.md
}

test_index_only_instruction_deletion_is_preserved() {
    repository repo
    cli init "$TARGET"; expect_status 0
    fixture_git -C "$TARGET" add -- AGENTS.md
    rm "$TARGET/AGENTS.md"
    assert_owned_deletion "$TARGET" AGENTS.md
}

test_general_guidance_deletions_are_preserved() {
    local mode
    for mode in staged unstaged; do
        committed_scaffold "$mode"
        if [[ $mode == staged ]]; then fixture_git -C "$TARGET" rm --quiet -- DEVELOPMENT.md;
        else rm "$TARGET/DEVELOPMENT.md"; fi
        assert_owned_deletion "$TARGET" DEVELOPMENT.md
    done
}

test_deleted_alias_does_not_reactivate_canonical_guidance() {
    local mode
    for mode in staged unstaged; do
        committed_scaffold "$mode" alias
        [[ ! -e $TARGET/DEVELOPMENT.md ]]
        snapshot "$TARGET/AGENTS.md" "$CASE_DIR/instructions-before"
        if [[ $mode == staged ]]; then fixture_git -C "$TARGET" rm --quiet -- docs/development.md;
        else rm "$TARGET/docs/development.md"; fi
        assert_owned_deletion "$TARGET" docs/development.md DEVELOPMENT.md
        snapshot "$TARGET/AGENTS.md" "$CASE_DIR/instructions-after"
        same "$CASE_DIR/instructions-before" "$CASE_DIR/instructions-after"
    done
}

test_sparse_omissions_receive_proposals_and_stay_absent() {
    local relative paths=()
    committed_scaffold repo
    while IFS= read -r -d '' relative; do
        [[ $relative == product.txt ]] || paths[${#paths[@]}]=$relative
    done < <(fixture_git -C "$TARGET" ls-files -z)
    fixture_git -C "$TARGET" sparse-checkout set --no-cone /product.txt
    for relative in "${paths[@]}"; do [[ ! -e $TARGET/$relative ]]; done
    snapshot "$TARGET/.git" "$CASE_DIR/admin-before"
    cli init "$TARGET"; expect_status 3
    for relative in "${paths[@]}"; do
        [[ ! -e $TARGET/$relative ]] || fail "sparse path reactivated: $relative"
        proposal_for "$TARGET" "$relative"
    done
    snapshot "$TARGET/.git" "$CASE_DIR/admin-after"; same "$CASE_DIR/admin-before" "$CASE_DIR/admin-after"
    snapshot "$TARGET" "$CASE_DIR/before"
    cli init "$TARGET"; expect_status 3
    snapshot "$TARGET" "$CASE_DIR/after"; same "$CASE_DIR/before" "$CASE_DIR/after"
}

test_ignored_scaffold_warns_initially_and_on_rerun() {
    local iteration relative line lower found
    TARGET="$SPACE/ignored"; mkdir "$TARGET"
    printf '/.agents/\n/.codex/\n/docs/agent-init/\n' >"$TARGET/.gitignore"
    snapshot "$TARGET/.gitignore" "$CASE_DIR/ignore-before"
    for iteration in initial unchanged; do
        snapshot "$TARGET" "$CASE_DIR/before"
        cli init "$TARGET"; expect_status 0
        for relative in "$SKILL_GOAL" .codex/config.toml "$PROVENANCE"; do
            found=false
            while IFS= read -r line; do
                lower=$(printf '%s' "$line" | tr '[:upper:]' '[:lower:]')
                if [[ $lower == *ignor* && $line == *"$relative"* ]]; then found=true; fi
            done <"$OUT"
            [[ $found == true ]] || fail "missing ignore warning: $relative"
        done
        snapshot "$TARGET/.gitignore" "$CASE_DIR/ignore-after"; same "$CASE_DIR/ignore-before" "$CASE_DIR/ignore-after"
        if [[ $iteration == unchanged ]]; then
            snapshot "$TARGET" "$CASE_DIR/after"; same "$CASE_DIR/before" "$CASE_DIR/after"
        fi
    done
}

test_instruction_conflict_creates_stable_proposal() {
    repository repo
    printf '# Existing accepted instructions\nDo not replace me.\n' >"$TARGET/AGENTS.md"
    snapshot "$TARGET/AGENTS.md" "$CASE_DIR/instructions-before"
    cli init "$TARGET"; expect_status 3
    snapshot "$TARGET/AGENTS.md" "$CASE_DIR/instructions-after"; same "$CASE_DIR/instructions-before" "$CASE_DIR/instructions-after"
    proposal_for "$TARGET" AGENTS.md
    if cmp -s "$TARGET/AGENTS.md" "$PROPOSAL"; then fail 'proposal does not differ'; fi
    snapshot "$TARGET" "$CASE_DIR/before"
    cli init "$TARGET"; expect_status 3
    snapshot "$TARGET" "$CASE_DIR/after"; same "$CASE_DIR/before" "$CASE_DIR/after"
}

test_modified_skill_is_preserved_with_original_proposal() {
    TARGET="$SPACE/modified skill"; cli init "$TARGET"; expect_status 0
    cp "$TARGET/$SKILL_GOAL" "$CASE_DIR/original-skill"
    printf '\nAccepted local policy addition.\n' >>"$TARGET/$SKILL_GOAL"
    snapshot "$TARGET/$SKILL_GOAL" "$CASE_DIR/skill-before"
    cli init "$TARGET"; expect_status 3
    snapshot "$TARGET/$SKILL_GOAL" "$CASE_DIR/skill-after"; same "$CASE_DIR/skill-before" "$CASE_DIR/skill-after"
    proposal_for "$TARGET" "$SKILL_GOAL"; same "$CASE_DIR/original-skill" "$PROPOSAL"
    snapshot "$TARGET" "$CASE_DIR/before"
    cli init "$TARGET"; expect_status 3
    snapshot "$TARGET" "$CASE_DIR/after"; same "$CASE_DIR/before" "$CASE_DIR/after"
}

test_edited_proposal_is_not_overwritten() {
    repository repo
    printf '# Existing accepted instructions\n' >"$TARGET/AGENTS.md"
    cli init "$TARGET"; expect_status 3
    proposal_for "$TARGET" AGENTS.md
    printf '# Human-edited proposal\nPreserve these edits.\n' >"$PROPOSAL"
    reject_without_writes "$TARGET" "$TARGET"
}

test_partial_untracked_scaffold_resumes_without_rewrites() {
    TARGET="$SPACE/partial scaffold"; cli init "$TARGET"; expect_status 0
    cp "$TARGET/$SKILL_TREE" "$CASE_DIR/expected-skill"
    cp "$TARGET/$PROVENANCE" "$CASE_DIR/expected-provenance"
    snapshot "$TARGET/AGENTS.md" "$CASE_DIR/retained-before"
    rm "$TARGET/$SKILL_TREE" "$TARGET/$PROVENANCE"
    cli init "$TARGET"; expect_status 0; assert_scaffold "$TARGET"
    snapshot "$TARGET/AGENTS.md" "$CASE_DIR/retained-after"; same "$CASE_DIR/retained-before" "$CASE_DIR/retained-after"
    same "$TARGET/$SKILL_TREE" "$CASE_DIR/expected-skill"
    same "$TARGET/$PROVENANCE" "$CASE_DIR/expected-provenance"
}

test_atomic_publication_failure_is_recoverable() {
    local real_ln path first= second= published=0 temp_paths=()
    repository repo
    snapshot "$TARGET/.git" "$CASE_DIR/admin-before"
    mkdir "$CASE_DIR/wrappers"
    real_ln=$(command -v ln)
    printf '0\n' >"$CASE_DIR/link-count"
    : >"$CASE_DIR/published"
    cat >"$CASE_DIR/wrappers/ln" <<'WRAPPER'
#!/usr/bin/env bash
set -eu
count=$(<"$AGENT_TEST_COUNTER")
count=$((count + 1))
printf '%s\n' "$count" >"$AGENT_TEST_COUNTER"
# The initializer publishes by running ln with its target parent as cwd.
# Preserve the exact argv and fail the third link without a shipped test flag.
source=
for arg in "$@"; do
    case $arg in -*) ;; *) if [[ -z $source ]]; then source=$arg; fi ;; esac
done
destination="$PWD/${source##*/}"
if [[ $count -eq 3 ]]; then
    printf '%s\n' "$destination" >"$AGENT_TEST_FAILED"
    printf 'Injected publication failure\n' >&2
    exit 1
fi
"$AGENT_TEST_REAL_LN" "$@"
printf '%s\n' "$destination" >>"$AGENT_TEST_PUBLISHED"
WRAPPER
    chmod +x "$CASE_DIR/wrappers/ln"
    run "$SPACE" env "PATH=$CASE_DIR/wrappers:$PATH" \
        "AGENT_TEST_COUNTER=$CASE_DIR/link-count" "AGENT_TEST_REAL_LN=$real_ln" \
        "AGENT_TEST_PUBLISHED=$CASE_DIR/published" "AGENT_TEST_FAILED=$CASE_DIR/failed" \
        "$CLI" init "$TARGET"
    expect_status 2
    while IFS= read -r path; do
        published=$((published + 1))
        [[ -s $path ]] || fail "published path is incomplete: $path"
        snapshot "$path" "$CASE_DIR/published-$published-before"
        if [[ $published == 1 ]]; then first=$path; else second=$path; fi
    done <"$CASE_DIR/published"
    [[ $published == 2 ]] || fail "expected two complete published files, got $published"
    path=$(<"$CASE_DIR/failed")
    [[ ! -e $path ]] || fail 'failed publication created a destination'
    snapshot "$TARGET/.git" "$CASE_DIR/admin-after"; same "$CASE_DIR/admin-before" "$CASE_DIR/admin-after"
    assert_no_publication_temps "$TARGET"
    cli init "$TARGET"; expect_status 0; assert_scaffold "$TARGET"
    [[ -s $path ]] || fail 'rerun did not complete the failed file'
    snapshot "$first" "$CASE_DIR/published-1-after"; same "$CASE_DIR/published-1-before" "$CASE_DIR/published-1-after"
    snapshot "$second" "$CASE_DIR/published-2-after"; same "$CASE_DIR/published-2-before" "$CASE_DIR/published-2-after"
    assert_no_publication_temps "$TARGET"
}

assert_no_publication_temps() {
    local path=$1 child
    for child in "$path"/*; do
        case ${child##*/} in .git-agent-init*) fail "publication temporary remains: $child";; esac
        if [[ -d $child && ! -L $child && ${child##*/} != .git ]]; then assert_no_publication_temps "$child"; fi
    done
}

test_concurrent_directory_at_publication_leaf_is_not_followed() {
    publication_leaf_race directory
}

test_concurrent_symlink_at_publication_leaf_is_not_followed() {
    publication_leaf_race symlink
}

publication_leaf_race() {
    local kind=$1 real_ln destination entries=()
    repository repo
    mkdir "$CASE_DIR/wrappers" "$SPACE/outside"
    if [[ $kind == symlink ]]; then
        ln -s "$SPACE/outside" "$CASE_DIR/symlink-probe" || skip 'host does not permit symbolic links'
        [[ -L $CASE_DIR/symlink-probe ]] || skip 'host does not create native symbolic links'
        rm "$CASE_DIR/symlink-probe"
    fi
    snapshot "$SPACE/outside" "$CASE_DIR/outside-before"
    real_ln=$(command -v ln)
    printf '0\n' >"$CASE_DIR/link-count"
    cat >"$CASE_DIR/wrappers/ln" <<'WRAPPER'
#!/usr/bin/env bash
set -eu
count=$(<"$AGENT_TEST_COUNTER")
count=$((count + 1))
printf '%s\n' "$count" >"$AGENT_TEST_COUNTER"
if [[ $count -eq 3 ]]; then
    source=
    for arg in "$@"; do
        case $arg in -*) ;; *) if [[ -z $source ]]; then source=$arg; fi ;; esac
    done
    destination="$PWD/${source##*/}"
    printf '%s\n' "$destination" >"$AGENT_TEST_RACE_PATH"
    if [[ $AGENT_TEST_RACE_KIND == directory ]]; then mkdir "$destination";
    else "$AGENT_TEST_REAL_LN" -s "$AGENT_TEST_OUTSIDE" "$destination"; fi
fi
exec "$AGENT_TEST_REAL_LN" "$@"
WRAPPER
    chmod +x "$CASE_DIR/wrappers/ln"
    run "$SPACE" env "PATH=$CASE_DIR/wrappers:$PATH" \
        "AGENT_TEST_COUNTER=$CASE_DIR/link-count" "AGENT_TEST_REAL_LN=$real_ln" \
        "AGENT_TEST_RACE_PATH=$CASE_DIR/race-path" "AGENT_TEST_RACE_KIND=$kind" \
        "AGENT_TEST_OUTSIDE=$SPACE/outside" "$CLI" init "$TARGET"
    expect_status 2
    destination=$(<"$CASE_DIR/race-path")
    if [[ $kind == directory ]]; then
        [[ -d $destination && ! -L $destination ]] || fail 'race fixture directory was replaced'
        entries=("$destination"/*)
        [[ ${#entries[@]} -eq 0 ]] || fail 'publisher wrote inside a competing destination directory'
        rmdir "$destination"
    else
        [[ -L $destination ]] || skip 'host does not create native symbolic links'
        snapshot "$SPACE/outside" "$CASE_DIR/outside-after"; same "$CASE_DIR/outside-before" "$CASE_DIR/outside-after"
        rm "$destination"
    fi
    assert_no_publication_temps "$TARGET"
    cli init "$TARGET"; expect_status 0; assert_scaffold "$TARGET"
}

test_incomplete_template_source_fails_build_without_output() {
    local relative broken="$CASE_DIR/broken-source"
    for relative in "$SKILL_GOAL" "$SKILL_TREE" "$PROVENANCE"; do
        mkdir -p "$broken/tools"
        cp -R "$SOURCE_ROOT/src" "$broken/src"
        cp -R "$SOURCE_ROOT/templates" "$broken/templates"
        cp "$SOURCE_ROOT/tools/build.sh" "$broken/tools/build.sh"
        rm "$broken/templates/$relative"
        run "$SPACE" bash "$broken/tools/build.sh"
        [[ $RC -ne 0 ]] || fail "build accepted missing required template: $relative"
        [[ ! -e $broken/bin/git-agent ]] || fail 'incomplete build published a command'
        rm -rf "$broken"
    done
}

test_corrupted_embedded_template_bundle_is_rejected() {
    local missing mode line broken="$CASE_DIR/broken-git-agent" skipping found index=0
    for missing in "$SKILL_GOAL" "$SKILL_TREE" "$PROVENANCE"; do
        for mode in body manifest; do
            index=$((index + 1))
            skipping=false; found=false
            while IFS= read -r line || [[ -n $line ]]; do
                if [[ $mode == manifest && $line == "$missing" ]]; then found=true; continue; fi
                if [[ $mode == body && $line == "        '$missing') cat <<"* ]]; then
                    found=true; skipping=true; continue
                fi
                if [[ $skipping == true ]]; then
                    [[ $line != '            ;;' ]] || skipping=false
                    continue
                fi
                printf '%s\n' "$line"
            done <"$CLI" >"$broken"
            [[ $found == true && $skipping == false ]] || fail "could not construct damaged $mode fixture: $missing"
            "$BASH" -n "$broken" || fail 'damaged fixture must remain syntactically valid Bash'
            chmod +x "$broken"
            snapshot "$SPACE" "$CASE_DIR/before"
            run "$SPACE" "$broken" init "$SPACE/damaged-target-$index"; expect_status 2
            snapshot "$SPACE" "$CASE_DIR/after"; same "$CASE_DIR/before" "$CASE_DIR/after"
        done
    done
}

test_empty_project_has_no_fake_product_workflow() {
    TARGET="$SPACE/no fake CI"; cli init "$TARGET"; expect_status 0
    [[ ! -e $TARGET/.github/workflows ]]
    assert_scaffold "$TARGET"
    # Native client discovery and TOML parsing are intentionally not certified.
    contains_ci "$OUT" 'codex'
    contains_ci "$OUT" 'not yet verified'
}

test_runtime_uses_only_declared_shell_utilities() {
    local utility resolved limited="$CASE_DIR/runtime-path"
    mkdir "$limited"
    for utility in bash env git cat cmp mkdir mktemp ln rm rmdir chmod wc; do
        if [[ $utility == bash ]]; then resolved=$BASH;
        else resolved=$(command -v "$utility"); fi
        [[ -n $resolved ]] || fail "missing stock utility in test environment: $utility"
        # Wrapper scripts avoid requiring symlink privileges in Git for Windows.
        printf '#!/bin/sh\nexec %q "$@"\n' "$resolved" >"$limited/$utility"
        chmod +x "$limited/$utility"
    done
    for utility in python python3 node nodejs perl ruby jq awk sed sort find cksum sha1sum sha256sum shasum timeout; do
        cat >"$limited/$utility" <<'WRAPPER'
#!/bin/sh
printf 'Unexpected runtime dependency: %s\n' "$0" >>"$AGENT_TEST_DEPENDENCY_MARKER"
exit 97
WRAPPER
        chmod +x "$limited/$utility"
    done
    TARGET="$SPACE/limited dependencies"
    run "$SPACE" env "PATH=$limited" "AGENT_TEST_DEPENDENCY_MARKER=$CASE_DIR/unexpected-dependency" "$CLI" init "$TARGET"
    expect_status 0; assert_scaffold "$TARGET"
    snapshot "$TARGET" "$CASE_DIR/before"
    run "$SPACE" env "PATH=$limited" "AGENT_TEST_DEPENDENCY_MARKER=$CASE_DIR/unexpected-dependency" "$CLI" init "$TARGET"
    expect_status 0
    snapshot "$TARGET" "$CASE_DIR/after"; same "$CASE_DIR/before" "$CASE_DIR/after"
    run "$SPACE" env "PATH=$limited" "AGENT_TEST_DEPENDENCY_MARKER=$CASE_DIR/unexpected-dependency" "$CLI" init "$SPACE/not created" --dry-run
    expect_status 0
    [[ ! -e $SPACE/not\ created ]]
    [[ ! -e $CASE_DIR/unexpected-dependency ]] || fail "initializer attempted an undeclared runtime dependency: $(<"$CASE_DIR/unexpected-dependency")"
}

test_submodule_lfs_and_hooks_are_reported_without_execution() {
    local relative
    repository repo
    printf '[submodule "dependency"]\n\tpath = dependency\n\turl = https://example.invalid/dependency.git\n' >"$TARGET/.gitmodules"
    printf '*.large filter=lfs diff=lfs merge=lfs -text\n' >"$TARGET/.gitattributes"
    printf '#!/bin/sh\nprintf executed > HOOK_EXECUTED\nexit 77\n' >"$TARGET/.git/hooks/pre-commit"
    chmod +x "$TARGET/.git/hooks/pre-commit"
    snapshot "$TARGET/.git" "$CASE_DIR/admin-before"
    cli init "$TARGET"; expect_status 0
    for relative in gaps submodule lfs hook; do contains_ci "$OUT" "$relative"; done
    [[ ! -e $TARGET/HOOK_EXECUTED ]]
    snapshot "$TARGET/.git" "$CASE_DIR/admin-after"; same "$CASE_DIR/admin-before" "$CASE_DIR/admin-after"
}

test_fsmonitor_is_disabled_during_inspection() {
    repository repo commit
    cat >"$TARGET/fsmonitor-hook" <<'HOOK'
#!/bin/sh
printf 'executed\n' >> HOOK_EXECUTED
printf '\0'
HOOK
    chmod +x "$TARGET/fsmonitor-hook"
    fixture_git -C "$TARGET" config core.fsmonitor "$TARGET/fsmonitor-hook"
    git -C "$TARGET" status --porcelain >/dev/null
    [[ -f $TARGET/HOOK_EXECUTED ]] || fail 'ordinary Git did not execute the hook fixture'
    rm "$TARGET/HOOK_EXECUTED"
    snapshot "$TARGET/.git" "$CASE_DIR/admin-before"
    cli init "$TARGET"; expect_status 0
    [[ ! -e $TARGET/HOOK_EXECUTED ]] || fail 'initializer executed fsmonitor'
    snapshot "$TARGET/.git" "$CASE_DIR/admin-after"; same "$CASE_DIR/admin-before" "$CASE_DIR/admin-after"
}

test_target_file_is_rejected() {
    printf 'preserve me\n' >"$SPACE/file.txt"
    reject_without_writes "$SPACE/file.txt"
}

test_bare_repository_is_rejected() {
    fixture_git init --quiet --bare "$SPACE/bare.git"
    reject_without_writes "$SPACE/bare.git"
}

test_corrupt_git_markers_are_rejected() {
    local marker
    for marker in file directory; do
        TARGET="$SPACE/$marker"; mkdir "$TARGET"
        if [[ $marker == file ]]; then printf 'invalid marker\n' >"$TARGET/.git";
        else mkdir "$TARGET/.git"; fi
        reject_without_writes "$TARGET"
    done
}

test_administrative_directories_are_rejected() {
    local relative
    repository repo commit
    for relative in .git .git/objects .git/refs; do reject_without_writes "$TARGET/$relative" "$TARGET"; done
}

test_scaffold_parent_occupied_by_file_is_rejected() {
    repository repo
    printf 'existing user file\n' >"$TARGET/.agents"
    reject_without_writes "$TARGET"
}

test_scaffold_parent_inside_recorded_gitlink_is_rejected() {
    local mode head
    for mode in index head; do
        repository "$mode" commit
        head=$(fixture_git -C "$TARGET" rev-parse HEAD)
        fixture_git -C "$TARGET" update-index --add --cacheinfo "160000,$head,.codex"
        mkdir "$TARGET/.codex"
        if [[ $mode == head ]]; then
            commit_fixture "$TARGET" 'Record gitlink boundary'
            fixture_git -C "$TARGET" rm --quiet --cached -- .codex
        fi
        reject_without_writes "$TARGET" "$TARGET"
    done
}

test_deleted_tracked_ancestor_is_not_replaced_with_directory() {
    local mode
    for mode in unstaged staged index_only; do
        repository "$mode"
        printf 'accepted tracked document at an ancestor path\n' >"$TARGET/docs"
        fixture_git -C "$TARGET" add -- docs
        if [[ $mode != index_only ]]; then commit_fixture "$TARGET" 'Record ancestor file'; fi
        if [[ $mode == staged ]]; then fixture_git -C "$TARGET" rm --quiet -- docs;
        else rm "$TARGET/docs"; fi
        reject_without_writes "$TARGET" "$TARGET"
    done
}

test_symlinked_scaffold_file_is_rejected() {
    repository repo
    printf 'accepted outside instructions\n' >"$SPACE/outside.md"
    ln -s "$SPACE/outside.md" "$TARGET/AGENTS.md" || skip 'host does not permit symbolic links'
    [[ -L $TARGET/AGENTS.md ]] || skip 'host does not create native symbolic links'
    reject_without_writes "$TARGET"
}

test_symlinked_scaffold_parent_is_rejected() {
    repository repo
    mkdir "$SPACE/outside-agents"
    ln -s "$SPACE/outside-agents" "$TARGET/.agents" || skip 'host does not permit symbolic links'
    [[ -L $TARGET/.agents ]] || skip 'host does not create native symbolic links'
    reject_without_writes "$TARGET"
}

test_symlinked_proposal_parent_is_rejected() {
    repository repo
    printf '# Existing instructions\n' >"$TARGET/AGENTS.md"
    mkdir -p "$TARGET/docs/agent-init" "$SPACE/outside-proposals"
    ln -s "$SPACE/outside-proposals" "$TARGET/docs/agent-init/proposals" || skip 'host does not permit symbolic links'
    [[ -L $TARGET/docs/agent-init/proposals ]] || skip 'host does not create native symbolic links'
    reject_without_writes "$TARGET"
}

test_git_environment_overrides_are_rejected() {
    local name value
    repository repo
    for name in GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_INDEX_FILE \
        GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_NAMESPACE \
        GIT_CEILING_DIRECTORIES GIT_CONFIG GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS \
        GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0; do
        value=unexpected
        [[ $name != GIT_CONFIG_COUNT ]] || value=1
        [[ $name != GIT_CONFIG_KEY_0 ]] || value=core.bare
        [[ $name != GIT_CONFIG_VALUE_0 ]] || value=true
        snapshot "$SPACE" "$CASE_DIR/before"
        run "$SPACE" env "$name=$value" "$CLI" init "$TARGET"; expect_status 2
        snapshot "$SPACE" "$CASE_DIR/after"; same "$CASE_DIR/before" "$CASE_DIR/after"
    done
}

test_failed_git_inventory_and_ignore_queries_cannot_become_success() {
    local real_git command
    repository repo commit
    mkdir "$CASE_DIR/wrappers"
    real_git=$(command -v git)
    cat >"$CASE_DIR/wrappers/git" <<'WRAPPER'
#!/usr/bin/env bash
set -eu
for arg in "$@"; do
    if [[ $arg == "$AGENT_TEST_FAIL_GIT_COMMAND" ]]; then
        printf 'partial-result\0'
        printf 'Injected Git query failure\n' >&2
        exit 73
    fi
done
exec "$AGENT_TEST_REAL_GIT" "$@"
WRAPPER
    chmod +x "$CASE_DIR/wrappers/git"
    for command in ls-files ls-tree check-ignore; do
        snapshot "$SPACE" "$CASE_DIR/before"
        run "$SPACE" env "PATH=$CASE_DIR/wrappers:$PATH" "AGENT_TEST_REAL_GIT=$real_git" \
            "AGENT_TEST_FAIL_GIT_COMMAND=$command" "$CLI" init "$TARGET"
        expect_status 2
        snapshot "$SPACE" "$CASE_DIR/after"; same "$CASE_DIR/before" "$CASE_DIR/after"
    done
}

test_concurrent_initializers_converge_without_clobbering() {
    local first_pid second_pid first_rc second_rc
    TARGET="$SPACE/baseline"; cli init "$TARGET"; expect_status 0
    cp "$TARGET/$SKILL_GOAL" "$CASE_DIR/expected-goal"
    cp "$TARGET/$SKILL_TREE" "$CASE_DIR/expected-tree"
    repository concurrent
    printf 'concurrent product\n' >"$TARGET/product.txt"
    snapshot "$TARGET/product.txt" "$CASE_DIR/product-before"
    (CDPATH= cd "$SPACE" && "$CLI" init "$TARGET") >"$CASE_DIR/first.out" 2>"$CASE_DIR/first.err" & first_pid=$!
    (CDPATH= cd "$SPACE" && "$CLI" init "$TARGET") >"$CASE_DIR/second.out" 2>"$CASE_DIR/second.err" & second_pid=$!
    if wait "$first_pid"; then first_rc=0; else first_rc=$?; fi
    if wait "$second_pid"; then second_rc=0; else second_rc=$?; fi
    case $first_rc:$second_rc in 0:0|0:2|0:3|2:0|3:0) ;; *)
        cat "$CASE_DIR/first.out" "$CASE_DIR/first.err" "$CASE_DIR/second.out" "$CASE_DIR/second.err" >&2
        fail "unexpected concurrent results: $first_rc / $second_rc";; esac
    cli init "$TARGET"; expect_status 0; assert_scaffold "$TARGET"
    same "$TARGET/$SKILL_GOAL" "$CASE_DIR/expected-goal"
    same "$TARGET/$SKILL_TREE" "$CASE_DIR/expected-tree"
    snapshot "$TARGET/product.txt" "$CASE_DIR/product-after"; same "$CASE_DIR/product-before" "$CASE_DIR/product-after"
    snapshot "$TARGET" "$CASE_DIR/before"
    cli init "$TARGET"; expect_status 0
    snapshot "$TARGET" "$CASE_DIR/after"; same "$CASE_DIR/before" "$CASE_DIR/after"
    assert_no_publication_temps "$TARGET"
}

TESTS=(
    test_help_version_and_unknown_commands
    test_native_git_dispatch
    test_new_repository_stays_unstaged_uncommitted
    test_plain_directory_preserves_product
    test_manifest_and_config_inspection_is_explicitly_unverified
    test_omitted_directory_uses_current_directory
    test_dry_run_missing_target_writes_nothing
    test_dry_run_preserves_work_and_git_metadata
    test_dry_run_conflict_creates_no_proposals
    test_unusual_product_filenames_are_preserved_without_execution
    test_shell_metacharacters_in_target_are_literal
    test_control_characters_in_target_are_rejected
    test_subdirectory_resolves_to_worktree_root
    test_missing_path_inside_repository_is_rejected
    test_source_index_configuration_and_head_are_preserved
    test_same_version_rerun_is_exact_noop
    test_template_identity_is_stable_in_sha256_repository
    test_linked_worktree_preserves_shared_administration
    test_existing_native_configuration_and_guidance_are_preserved
    test_unstaged_instruction_deletion_is_preserved
    test_staged_instruction_deletion_is_preserved
    test_index_only_instruction_deletion_is_preserved
    test_general_guidance_deletions_are_preserved
    test_deleted_alias_does_not_reactivate_canonical_guidance
    test_sparse_omissions_receive_proposals_and_stay_absent
    test_ignored_scaffold_warns_initially_and_on_rerun
    test_instruction_conflict_creates_stable_proposal
    test_modified_skill_is_preserved_with_original_proposal
    test_edited_proposal_is_not_overwritten
    test_partial_untracked_scaffold_resumes_without_rewrites
    test_atomic_publication_failure_is_recoverable
    test_concurrent_directory_at_publication_leaf_is_not_followed
    test_concurrent_symlink_at_publication_leaf_is_not_followed
    test_incomplete_template_source_fails_build_without_output
    test_corrupted_embedded_template_bundle_is_rejected
    test_empty_project_has_no_fake_product_workflow
    test_runtime_uses_only_declared_shell_utilities
    test_submodule_lfs_and_hooks_are_reported_without_execution
    test_fsmonitor_is_disabled_during_inspection
    test_target_file_is_rejected
    test_bare_repository_is_rejected
    test_corrupt_git_markers_are_rejected
    test_administrative_directories_are_rejected
    test_scaffold_parent_occupied_by_file_is_rejected
    test_scaffold_parent_inside_recorded_gitlink_is_rejected
    test_deleted_tracked_ancestor_is_not_replaced_with_directory
    test_symlinked_scaffold_file_is_rejected
    test_symlinked_scaffold_parent_is_rejected
    test_symlinked_proposal_parent_is_rejected
    test_git_environment_overrides_are_rejected
    test_failed_git_inventory_and_ignore_queries_cannot_become_success
    test_concurrent_initializers_converge_without_clobbering
)

[[ -x $CLI ]] || fail "build the executable first: bash $SOURCE_ROOT/tools/build.sh"
VERSION_OUTPUT=$("$CLI" --version)
VERSION=${VERSION_OUTPUT##* }

if [[ ${1:-} == --case ]]; then
    [[ $# -eq 2 ]] || fail 'internal case invocation requires a name'
    found=false
    for test_name in "${TESTS[@]}"; do [[ $test_name != "$2" ]] || found=true; done
    [[ $found == true ]] || fail "unknown test: $2"
    CASE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/git-agent-case.XXXXXX")
    trap 'rm -rf -- "$CASE_DIR"' EXIT
    SPACE="$CASE_DIR/work"; mkdir "$SPACE"
    OUT="$CASE_DIR/stdout"; ERR="$CASE_DIR/stderr"
    if stat -c '%a' "$SPACE" >/dev/null 2>&1; then STAT_STYLE=gnu; else STAT_STYLE=bsd; fi
    "$2"
    exit 0
fi

[[ $# -le 1 ]] || fail 'usage: bash tests/run.sh [test-name-substring]'
FILTER=${1:-}
passed=0 failed=0 skipped=0
for test_name in "${TESTS[@]}"; do
    [[ $test_name == *"$FILTER"* ]] || continue
    printf '%s ... ' "$test_name"
    if "$BASH" "$TEST_SCRIPT" --case "$test_name"; then
        printf 'PASS\n'; passed=$((passed + 1))
    else
        result=$?
        if [[ $result -eq 77 ]]; then skipped=$((skipped + 1));
        else printf 'FAIL (%s)\n' "$result"; failed=$((failed + 1)); fi
    fi
done
[[ $((passed + failed + skipped)) -gt 0 ]] || fail "no tests match '$FILTER'"
printf '\n%s passed; %s failed; %s skipped. Bash %s; %s.\n' "$passed" "$failed" "$skipped" "$BASH_VERSION" "$(git --version)"
[[ $failed -eq 0 ]]
