# Runtime core for the standalone Bash bundle. tools/build.sh appends literal
# template functions and the single main dispatch. Bash 3.2 syntax only.

GA_VERSION=0.2.1
GA_TEMPLATE_VERSION=0.2.1
GA_MAX_FILES=5000
GA_MAX_BYTES=2097152

ga_error() {
    printf 'git agent init: %s\n' "$*" >&2
    printf 'Existing files are preserved. Inspect partial results and rerun to complete eligible missing files.\n' >&2
    exit 2
}

ga_has() {
    local needle=$1 item
    shift
    for item in "$@"; do [[ $item == "$needle" ]] && return 0; done
    return 1
}

ga_gap() {
    ga_has "$1" "${GA_GAPS[@]}" || GA_GAPS[${#GA_GAPS[@]}]=$1
    return 0
}

ga_git() {
    GIT_OPTIONAL_LOCKS=0 GIT_TERMINAL_PROMPT=0 LC_ALL=C \
        command git -c core.fsmonitor=false -c submodule.recurse=false "$@"
}

ga_check_environment() {
    local name bad=() version major minor
    for name in GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_INDEX_FILE \
        GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_NAMESPACE \
        GIT_CEILING_DIRECTORIES GIT_CONFIG GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS \
        ${!GIT_CONFIG_KEY_@} ${!GIT_CONFIG_VALUE_@}; do
        [[ -n ${!name} ]] && bad[${#bad[@]}]=$name
    done
    ((${#bad[@]} == 0)) || ga_error "Unset Git routing/configuration overrides: ${bad[*]}. Use the directory argument or git -C."
    for name in git cat cmp mkdir mktemp ln rm rmdir chmod wc; do
        command -v "$name" >/dev/null 2>&1 || ga_error "Required stock command is unavailable: $name. Use a supported Bash/Git shell environment."
    done
    GA_GIT_VERSION=$(ga_git --version) || ga_error 'Git could not report its version.'
    version=${GA_GIT_VERSION#git version }
    major=${version%%.*}; version=${version#*.}; minor=${version%%.*}
    [[ $major =~ ^[0-9]+$ && $minor =~ ^[0-9]+$ ]] || ga_error "Cannot identify Git version: $GA_GIT_VERSION"
    ((major > 2 || (major == 2 && minor >= 31))) || ga_error 'Git 2.31 or newer is required.'
}

# Resolve physical existing ancestors without realpath/readlink, including a
# missing final directory. Git Bash accepts its own paths and drive:/ paths.
ga_resolve() {
    local path=$1 part current base rest
    local parts=()
    [[ -n $path ]] || ga_error 'An empty target directory is unsupported.'
    [[ ! $path =~ [[:cntrl:]] ]] || ga_error 'Target paths containing control characters are unsupported.'
    case $path in
        '~') path=$HOME ;;
        '~/'*) path=$HOME/${path#\~/} ;;
    esac
    if [[ -d $path ]]; then
        GA_RESOLVED=$(CDPATH= cd -P -- "$path" && pwd -P) || ga_error "Cannot resolve directory: $path"
        return 0
    fi
    case $path in
        [A-Za-z]:/*)
            base=${path:0:3}; rest=${path:3}
            current=$(CDPATH= cd -P -- "$base" && pwd -P) || ga_error "Cannot resolve drive: $base"
            ;;
        //*) ga_error 'A missing UNC target is unsupported; select an existing directory or a local Git Bash path.' ;;
        /*) current=/; rest=${path#/} ;;
        *) current=$(pwd -P) || ga_error 'Cannot identify current directory.'; rest=$path ;;
    esac
    IFS=/ read -r -a parts <<< "$rest"
    for part in "${parts[@]}"; do
        case $part in
            ''|.) continue ;;
            ..) current=${current%/*}; [[ -n $current ]] || current=/; continue ;;
        esac
        [[ $current == / ]] && path=/$part || path=$current/$part
        if [[ -d $path ]]; then
            current=$(CDPATH= cd -P -- "$path" && pwd -P) || ga_error "Cannot resolve directory: $path"
        elif [[ -e $path || -L $path ]]; then
            ga_error "Target or parent is not a usable directory: $path"
        else
            current=$path
        fi
    done
    GA_RESOLVED=$current
}

ga_discover() {
    local input=$1 ancestor probe status parent gitdir common value ref
    ga_resolve "$input"
    GA_REQUESTED=$GA_RESOLVED; ancestor=$GA_REQUESTED
    while [[ ! -e $ancestor && ! -L $ancestor ]]; do
        ancestor=${ancestor%/*}; [[ -n $ancestor ]] || ancestor=/
    done
    [[ -d $ancestor ]] || ga_error "Target parent is not a directory: $ancestor"
    probe=$(ga_git -C "$ancestor" rev-parse --is-inside-work-tree 2>&1); status=$?
    if ((status != 0)); then
        [[ $probe == *'not a git repository'* ]] || ga_error "Repository discovery failed: $probe"
        parent=$ancestor
        while :; do
            if [[ -e $parent/.git || -L $parent/.git ]]; then
                ga_error "An existing .git marker is unusable at $parent; repair it explicitly."
            fi
            [[ $parent == / ]] && break
            parent=${parent%/*}; [[ -n $parent ]] || parent=/
        done
        if [[ -e $ancestor/HEAD && -e $ancestor/objects && -e $ancestor/refs && -e $ancestor/config ]]; then
            ga_error 'Target resembles Git administration data; initialization is refused.'
        fi
        GA_ROOT=$GA_REQUESTED; GA_NEW=1; GA_LINKED=0; GA_HAS_HEAD=0
        return 0
    fi
    value=$(ga_git -C "$ancestor" rev-parse --is-bare-repository) || ga_error 'Cannot inspect repository type.'
    [[ $value != true ]] || ga_error 'A bare repository has no working tree to scaffold.'
    value=$(ga_git -C "$ancestor" rev-parse --is-inside-git-dir) || ga_error 'Cannot inspect Git administration location.'
    [[ $value != true ]] || ga_error 'Target is inside Git administration data, not a working tree.'
    [[ $probe == true ]] || ga_error 'Target is not inside a usable Git working tree.'
    value=$(ga_git -C "$ancestor" rev-parse --show-toplevel) || ga_error 'Cannot discover worktree root.'
    ga_resolve "$value"; GA_ROOT=$GA_RESOLVED; GA_NEW=0
    [[ -d $GA_REQUESTED ]] || ga_error "The missing target is inside existing repository $GA_ROOT. Initialize that repository explicitly, or choose a location outside it."
    gitdir=$(ga_git -C "$GA_ROOT" rev-parse --absolute-git-dir) || ga_error 'Cannot inspect Git directory.'
    ga_resolve "$gitdir"; gitdir=$GA_RESOLVED
    common=$(ga_git -C "$GA_ROOT" rev-parse --git-common-dir) || ga_error 'Cannot inspect shared Git directory.'
    case $common in /*|[A-Za-z]:/*) ;; *) common=$GA_ROOT/$common ;; esac
    ga_resolve "$common"; common=$GA_RESOLVED
    GA_LINKED=0; [[ $gitdir == "$common" ]] || GA_LINKED=1
    ga_read_head
}

ga_read_head() {
    local ref status
    if ga_git -C "$GA_ROOT" rev-parse --verify -q HEAD >/dev/null; then
        ga_git -C "$GA_ROOT" cat-file -e 'HEAD^{commit}' || ga_error 'HEAD does not identify an available commit.'
        GA_HAS_HEAD=1
    else
        ref=$(ga_git -C "$GA_ROOT" symbolic-ref -q HEAD) || ga_error 'HEAD is unusable; repair it explicitly.'
        ga_git -C "$GA_ROOT" show-ref --verify --quiet "$ref"; status=$?
        ((status == 1)) || ga_error 'Cannot establish an intentional unborn HEAD.'
        GA_HAS_HEAD=0
    fi
}

# Git emits NUL-terminated records. An additional empty record carries the
# producer's exit status, which process substitution alone would otherwise hide.
ga_records() {
    local record status=255 complete=0 count=0 parents_only=0 path
    if [[ $1 == --parent-entries ]]; then parents_only=1; shift; fi
    GA_RECORDS=(); GA_TRUNCATED=0
    while IFS= read -r -d '' record; do
        if [[ -z $record ]]; then
            IFS= read -r -d '' status || status=255
            complete=1
            break
        fi
        # Parent pathspecs can include many ordinary descendants. Retain only
        # exact parent entries while still checking the entire producer stream.
        if ((parents_only)); then
            [[ $record == *$'\t'* ]] || ga_error 'Malformed Git parent metadata.'
            path=${record#*$'\t'}
            ga_has "$path" "${GA_PARENTS[@]}" || continue
        fi
        count=$((count + 1))
        if ((count <= GA_MAX_FILES)); then
            GA_RECORDS[${#GA_RECORDS[@]}]=$record
        else
            GA_TRUNCATED=1
        fi
    done < <(ga_git "$@"; printf '\0%d\0' "$?")
    [[ $complete == 1 && $status == 0 ]] || ga_error 'A Git inventory command failed; no plan can be accepted from partial output.'
}

ga_safe_path() {
    local relative=$1 current=$GA_ROOT part i prefix=''
    local parts=()
    [[ -n $relative && $relative != /* && ! $relative =~ [[:cntrl:]] ]] || ga_error "Unsafe scaffold path: $relative"
    ga_resolve "$GA_ROOT"
    [[ $GA_RESOLVED == "$GA_ROOT" && ! -L $GA_ROOT ]] || ga_error "Repository location changed: $GA_ROOT"
    IFS=/ read -r -a parts <<< "$relative"
    for ((i=0; i<${#parts[@]}; i++)); do
        part=${parts[i]}
        [[ -n $part && $part != . && $part != .. ]] || ga_error "Unsafe scaffold path: $relative"
        current=$current/$part
        [[ -n $prefix ]] && prefix=$prefix/$part || prefix=$part
        if ((i + 1 < ${#parts[@]})); then
            ga_has "$prefix" "${GA_PARENT_OWNED[@]}" && ga_error "Scaffold parent is recorded as a file, symlink or gitlink in HEAD/index: $prefix. Resolve its ownership explicitly."
        fi
        [[ ! -L $current ]] || ga_error "Scaffold path is a symlink; resolve it explicitly: $current"
        if [[ -e $current ]]; then
            if ((i + 1 == ${#parts[@]})); then
                [[ -f $current ]] || ga_error "Scaffold path has an incompatible file type: $current"
            else
                [[ -d $current ]] || ga_error "Scaffold parent has an incompatible file type: $current"
                [[ ! -e $current/.git && ! -L $current/.git ]] || ga_error "Scaffold path enters a nested repository: $current"
            fi
        fi
    done
    GA_SAFE=$current
}

ga_load_templates() {
    local path body found='' item i
    GA_REQUIRED=(
        AGENTS.md GOVERNANCE.md DEVELOPMENT.md ARCHITECTURE.md PLANS.md
        docs/agent-init/README.md .codex/config.toml
        .codex/agents/contract-reviewer.toml .codex/agents/adversarial-reviewer.toml
        .agents/skills/work-goal/SKILL.md
        .agents/skills/work-goal/references/review-guide.md
        .agents/skills/work-goal/references/release-lifecycle.md
        .agents/skills/work-goal/references/state-report.md
        .agents/skills/worktree-flow/SKILL.md
        .agents/skills/worktree-flow/references/isolation-and-recovery.md
    )
    GA_ALIASES=(GOVERNANCE.md docs/GOVERNANCE.md docs/governance.md
        DEVELOPMENT.md docs/DEVELOPMENT.md docs/development.md CONTRIBUTING.md
        ARCHITECTURE.md docs/ARCHITECTURE.md docs/architecture.md
        PLANS.md docs/PLANS.md docs/plans.md)
    declare -F ga_template_paths >/dev/null && declare -F ga_template_body >/dev/null || ga_error 'The installed template bundle is missing; rebuild or reinstall git-agent.'
    found=$(ga_template_paths) || ga_error 'The template manifest is unreadable.'
    GA_FOUND=()
    while IFS= read -r item; do
        [[ -n $item ]] || ga_error 'The template manifest contains an empty path.'
        ga_has "$item" "${GA_REQUIRED[@]}" || ga_error "Unexpected bundled template: $item"
        ga_has "$item" "${GA_FOUND[@]}" && ga_error "Duplicate bundled template: $item"
        GA_FOUND[${#GA_FOUND[@]}]=$item
    done <<< "$found"
    ((${#GA_FOUND[@]} == ${#GA_REQUIRED[@]})) || ga_error 'The installed template bundle is incomplete; rebuild or reinstall git-agent.'
    GA_RAW=()
    for path in "${GA_REQUIRED[@]}"; do
        ga_has "$path" "${GA_FOUND[@]}" || ga_error "Missing bundled template: $path"
        body=$(ga_template_body "$path" && printf '\037') || ga_error "Cannot read bundled template: $path"
        body=${body%$'\037'}
        [[ -n $body && $body == *$'\n' ]] || ga_error "Incomplete bundled template: $path"
        ((${#body} <= GA_MAX_BYTES)) || ga_error "Bundled template exceeds inspection bound: $path"
        GA_RAW[${#GA_RAW[@]}]=$body
    done
    GA_DIGEST=$(
        for ((i=0; i<${#GA_REQUIRED[@]}; i++)); do
            printf '%s\0%s\0' "${GA_REQUIRED[i]}" "${GA_RAW[i]}"
        done | GIT_DEFAULT_HASH=sha1 GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
            command git --git-dir=/dev/null -c core.fsmonitor=false hash-object --stdin
    ) || ga_error 'Cannot establish bundled-template content identity.'
    [[ ${#GA_DIGEST} == 40 && $GA_DIGEST != *[!0-9a-f]* ]] || ga_error 'Unexpected Git blob identity format.'
}

ga_same() {
    local path=$1 data=$2 status
    [[ -f $path && ! -L $path ]] || return 1
    cmp -s "$path" <(printf '%s' "$data"); status=$?
    ((status < 2)) || ga_error "Cannot compare existing file: $path"
    return "$status"
}

ga_action() {
    local n=${#GA_PATHS[@]}
    GA_KINDS[n]=$1; GA_PATHS[n]=$2; GA_DATA[n]=$3
    GA_WRITE[n]=$4; GA_SOURCES[n]=$5
}

ga_propose() {
    local name=$1 data=$2 absent=${3:-0} proposed kind=preserved
    proposed=docs/agent-init/proposals/$GA_TEMPLATE_VERSION-${GA_DIGEST:0:12}/$name
    ga_safe_path "$proposed"
    GA_REVIEW=1
    if ((absent)); then
        kind='preserved deletion'
        ga_gap "Preserved absent path recorded in HEAD/index: $name. Review deletion or sparse-checkout intent before adopting a replacement."
    fi
    ga_action "$kind" "$name" '' 0 "$proposed"
    if [[ -e $GA_SAFE ]]; then
        ga_same "$GA_SAFE" "$data" || ga_error "An existing proposal was modified: $GA_SAFE. Preserve/reconcile it before rerunning."
        ga_action 'proposal unchanged' "$proposed" '' 0 "$name"
    else
        ga_action proposed "$proposed" "$data" 1 "$name"
    fi
}

ga_select_guidance() {
    local canonical=$1 choice
    shift
    GA_SELECTED=$canonical
    for choice in "$@"; do
        if [[ -e $GA_ROOT/$choice ]] || ga_has "$choice" "${GA_OWNED[@]}"; then
            GA_SELECTED=$choice
            return 0
        fi
    done
}

# HEAD and the index retain path ownership even if the working-tree entry is
# absent. A recorded blob/symlink/gitlink must never become a scaffold directory.
ga_check_parent_ownership() {
    local path candidate parent record mode
    GA_PARENTS=(); GA_PARENT_OWNED=()
    for path in "${GA_REQUIRED[@]}" "${GA_ALIASES[@]}"; do
        for candidate in "$path" "docs/agent-init/proposals/$GA_TEMPLATE_VERSION-${GA_DIGEST:0:12}/$path"; do
            parent=$candidate
            while [[ $parent == */* ]]; do
                parent=${parent%/*}
                ga_has "$parent" "${GA_PARENTS[@]}" || GA_PARENTS[${#GA_PARENTS[@]}]=$parent
            done
        done
    done
    ((GA_NEW)) && return 0
    ga_records --parent-entries -C "$GA_ROOT" ls-files --stage -z -- "${GA_PARENTS[@]}"
    ((GA_TRUNCATED == 0)) || ga_error 'Managed parent index inventory exceeded its bound.'
    for record in "${GA_RECORDS[@]}"; do
        path=${record#*$'\t'}; mode=${record%% *}
        [[ $mode == 040000 ]] || ga_has "$path" "${GA_PARENT_OWNED[@]}" || GA_PARENT_OWNED[${#GA_PARENT_OWNED[@]}]=$path
    done
    if ((GA_HAS_HEAD)); then
        ga_records --parent-entries -C "$GA_ROOT" ls-tree -r -z HEAD -- "${GA_PARENTS[@]}"
        ((GA_TRUNCATED == 0)) || ga_error 'Managed parent HEAD inventory exceeded its bound.'
        for record in "${GA_RECORDS[@]}"; do
            path=${record#*$'\t'}; mode=${record%% *}
            [[ $mode == 040000 ]] || ga_has "$path" "${GA_PARENT_OWNED[@]}" || GA_PARENT_OWNED[${#GA_PARENT_OWNED[@]}]=$path
        done
    fi
    return 0
}

ga_plan() {
    local path body choice i
    GA_INDEX=(); GA_OWNED=(); GA_RENDERED=()
    GA_KINDS=(); GA_PATHS=(); GA_DATA=(); GA_WRITE=(); GA_SOURCES=(); GA_REVIEW=0
    ga_check_parent_ownership
    for path in "${GA_REQUIRED[@]}" "${GA_ALIASES[@]}"; do ga_safe_path "$path"; done
    if ((!GA_NEW)); then
        ga_records -C "$GA_ROOT" ls-files --cached -z -- "${GA_REQUIRED[@]}" "${GA_ALIASES[@]}"
        ((GA_TRUNCATED == 0)) || ga_error 'Managed index inventory exceeded its bound.'
        GA_INDEX=("${GA_RECORDS[@]}"); GA_OWNED=("${GA_INDEX[@]}")
        if ((GA_HAS_HEAD)); then
            ga_records -C "$GA_ROOT" ls-tree -r --name-only -z HEAD -- "${GA_REQUIRED[@]}" "${GA_ALIASES[@]}"
            ((GA_TRUNCATED == 0)) || ga_error 'Managed HEAD inventory exceeded its bound.'
            for path in "${GA_RECORDS[@]}"; do
                ga_has "$path" "${GA_OWNED[@]}" || GA_OWNED[${#GA_OWNED[@]}]=$path
            done
        fi
    fi
    ga_select_guidance GOVERNANCE.md GOVERNANCE.md docs/GOVERNANCE.md docs/governance.md; GA_GOVERNANCE=$GA_SELECTED
    ga_select_guidance DEVELOPMENT.md DEVELOPMENT.md docs/DEVELOPMENT.md docs/development.md CONTRIBUTING.md; GA_DEVELOPMENT=$GA_SELECTED
    ga_select_guidance ARCHITECTURE.md ARCHITECTURE.md docs/ARCHITECTURE.md docs/architecture.md; GA_ARCHITECTURE=$GA_SELECTED
    ga_select_guidance PLANS.md PLANS.md docs/PLANS.md docs/plans.md; GA_PLANS=$GA_SELECTED
    for ((i=0; i<${#GA_REQUIRED[@]}; i++)); do
        path=${GA_REQUIRED[i]}; body=${GA_RAW[i]}
        body=${body//\{\{TEMPLATE_VERSION\}\}/$GA_TEMPLATE_VERSION}
        body=${body//\{\{TEMPLATE_DIGEST\}\}/git-blob-sha1:$GA_DIGEST}
        body=${body//\{\{GOVERNANCE_PATH\}\}/$GA_GOVERNANCE}
        body=${body//\{\{DEVELOPMENT_PATH\}\}/$GA_DEVELOPMENT}
        body=${body//\{\{ARCHITECTURE_PATH\}\}/$GA_ARCHITECTURE}
        body=${body//\{\{PLANS_PATH\}\}/$GA_PLANS}
        [[ $body != *'{{'* && $body != *'}}'* ]] || ga_error "Unresolved template placeholder in $path."
        choice=$path
        case $path in
            GOVERNANCE.md) choice=$GA_GOVERNANCE ;;
            DEVELOPMENT.md) choice=$GA_DEVELOPMENT ;;
            ARCHITECTURE.md) choice=$GA_ARCHITECTURE ;;
            PLANS.md) choice=$GA_PLANS ;;
        esac
        ga_safe_path "$choice"
        if [[ ! -e $GA_SAFE ]]; then
            if ga_has "$choice" "${GA_OWNED[@]}"; then
                ga_propose "$choice" "$body" 1
            else
                ga_action created "$choice" "$body" 1 ''
            fi
        elif ga_same "$GA_SAFE" "$body"; then
            ga_action unchanged "$choice" '' 0 ''
        else
            case $path in
                GOVERNANCE.md|DEVELOPMENT.md|ARCHITECTURE.md|PLANS.md)
                    ga_action adopted "$choice" '' 0 "$path"
                    ga_gap "Review $choice for $path responsibilities; existing guidance was preserved, not certified."
                    ;;
                *) ga_propose "$choice" "$body" ;;
            esac
        fi
    done
    ((GA_NEW)) || ga_retention
}

ga_retention() {
    local path status checked=()
    for path in "${GA_PATHS[@]}"; do
        ga_has "$path" "${GA_INDEX[@]}" && continue
        ga_has "$path" "${checked[@]}" && continue
        checked[${#checked[@]}]=$path
        ga_git -C "$GA_ROOT" check-ignore --no-index -q -- "$path"; status=$?
        case $status in
            0) ga_gap "Git ignore rules cover $path; resolve tracking/retention explicitly before claiming a checkpoint." ;;
            1) ;;
            *) ga_error "Could not inspect ignore rules for $path." ;;
        esac
    done
}

ga_inspect_path() {
    local name=$1 base=${1##*/} current=$GA_ROOT part bytes text relevant=0
    local parts=()
    case /$name/ in
        /docs/agent-init/proposals/*|*/.git/*|*/node_modules/*|*/.venv/*|*/venv/*|*/__pycache__/*|*/.cache/*|*/target/*|*/dist/*|*/build/*|*/vendor/*|*/.tox/*|*/.mypy_cache/*) return 0 ;;
    esac
    case $base in
        AGENTS.md|AGENTS.override.md|GOVERNANCE.md|DEVELOPMENT.md|ARCHITECTURE.md|PLANS.md|CONTRIBUTING.md|governance.md|development.md|architecture.md|plans.md|package.json|pyproject.toml|Cargo.toml|go.mod|Makefile|justfile|Dockerfile|compose.yml|compose.yaml|docker-compose.yml|requirements.txt|.gitattributes|.gitmodules) relevant=1 ;;
    esac
    case $name in .codex/*|.agents/skills/*|.github/workflows/*) relevant=1 ;; esac
    ((relevant)) || return 0
    [[ ! $name =~ [[:cntrl:]] ]] || { ga_gap 'A setup filename contains control characters; inspect it separately.'; return 0; }
    IFS=/ read -r -a parts <<< "$name"
    for part in "${parts[@]}"; do
        current=$current/$part
        if [[ -L $current ]]; then ga_gap "Inspect linked setup separately: $name (symlink not followed)."; return 0; fi
    done
    [[ -e $current ]] || return 0
    if [[ ! -f $current ]]; then ga_gap "Setup file is not bounded regular text: $name."; return 0; fi
    bytes=$(wc -c < "$current") || ga_error "Cannot measure setup file: $name"
    bytes=${bytes//[[:space:]]/}
    [[ $bytes =~ ^[0-9]+$ ]] || ga_error "Cannot measure setup file: $name"
    if ((bytes > GA_MAX_BYTES)); then ga_gap "Setup file exceeds the $GA_MAX_BYTES-byte inspection bound: $name."; return 0; fi
    ga_has "$name" "${GA_INSPECTED[@]}" || GA_INSPECTED[${#GA_INSPECTED[@]}]=$name
    case $name in .gitmodules) GA_SUBMODULE=1 ;; esac
    case $base in
        package.json|pyproject.toml|Cargo.toml)
            ga_gap "Syntax and command declarations in $name are unverified. Bash does not parse JSON/TOML; use the maintained product validators."
            ;;
    esac
    if [[ $name == .codex/config.toml ]]; then
        ga_gap 'Codex TOML syntax and effective configuration are unverified; validate with the installed Codex client.'
    fi
    if [[ $base == .gitattributes ]]; then
        text=$(cat "$current") || ga_error "Cannot read attributes: $name"
        [[ $text =~ filter[[:space:]]*=[[:space:]]*lfs ]] && GA_LFS=1
    fi
    return 0
}

ga_walk() {
    local parent=$1 relative=$2 depth=$3 entry name child
    ((depth <= 12)) || { GA_SCAN_TRUNCATED=1; return 0; }
    for entry in "$parent"/*; do
        GA_VISITED=$((GA_VISITED + 1))
        ((GA_VISITED <= GA_MAX_FILES)) || { GA_SCAN_TRUNCATED=1; return 0; }
        name=${entry##*/}; [[ -n $relative ]] && child=$relative/$name || child=$name
        case $name in .git|node_modules|.venv|venv|__pycache__|.cache|target|dist|build|vendor|.tox|.mypy_cache) continue ;; esac
        if [[ -d $entry && ! -L $entry ]]; then
            ga_walk "$entry" "$child" "$((depth + 1))"
        else
            ga_inspect_path "$child"
        fi
    done
}

ga_inspect_metadata() {
    local result status hooks entry record
    result=$(ga_git -C "$GA_ROOT" config --get-regexp '^filter\.lfs\.' 2>/dev/null); status=$?
    case $status in 0) GA_LFS=1 ;; 1) ;; *) ga_error 'Cannot inspect LFS configuration.' ;; esac
    hooks=$(ga_git -C "$GA_ROOT" config --get core.hooksPath); status=$?
    case $status in
        0) ga_gap 'Configured hooks path detected; review and restore its hooks explicitly (none were executed).' ;;
        1)
            hooks=$(ga_git -C "$GA_ROOT" rev-parse --git-path hooks) || ga_error 'Cannot locate native hooks.'
            case $hooks in /*|[A-Za-z]:/*) ;; *) hooks=$GA_ROOT/$hooks ;; esac
            if [[ -d $hooks && ! -L $hooks ]]; then
                for entry in "$hooks"/*; do
                    [[ -f $entry && $entry != *.sample ]] && ga_gap 'Local Git hooks detected; record origin/setup/recovery (none were executed).'
                done
            fi
            ;;
        *) ga_error 'Cannot inspect hooks configuration.' ;;
    esac
    result=$(ga_git -C "$GA_ROOT" config --bool --get core.sparseCheckout); status=$?
    case $status in
        0) [[ $result != true ]] || ga_gap 'Sparse checkout detected; verify intended scaffold paths and retention.' ;;
        1) ;;
        *) ga_error 'Cannot inspect sparse-checkout configuration.' ;;
    esac
    ga_records -C "$GA_ROOT" ls-files --stage -z
    ((GA_TRUNCATED == 0)) || ga_gap 'Git index metadata inspection reached its entry bound; review remaining special entries.'
    for record in "${GA_RECORDS[@]}"; do
        [[ $record == '160000 '* ]] && GA_SUBMODULE=1
    done
    ((GA_HAS_HEAD)) || ga_gap 'No baseline commit yet; create an intentional reviewed baseline before normal worktree flows.'
}

ga_inspect() {
    local name
    GA_INSPECTED=(); GA_SUBMODULE=0; GA_LFS=0; GA_VISITED=0; GA_SCAN_TRUNCATED=0
    if ((GA_NEW)); then
        [[ ! -d $GA_ROOT ]] || ga_walk "$GA_ROOT" '' 0
        ga_gap 'Create an intentional reviewed baseline commit before normal worktree flows.'
    else
        ga_records -C "$GA_ROOT" ls-files --cached --others --exclude-standard -z
        ((GA_TRUNCATED == 0)) || GA_SCAN_TRUNCATED=1
        for name in "${GA_RECORDS[@]}"; do ga_inspect_path "$name"; done
        ga_inspect_metadata
    fi
    for name in AGENTS.md AGENTS.override.md .codex/config.toml .gitmodules .gitattributes; do ga_inspect_path "$name"; done
    ((GA_SCAN_TRUNCATED == 0)) || ga_gap "Inspection reached its $GA_MAX_FILES-entry or 12-level directory bound; review remaining setup."
}

ga_final_gaps() {
    ((GA_SUBMODULE == 0)) || ga_gap 'Submodules or gitlinks detected: prove the supported worktree/setup/recovery path before use.'
    ((GA_LFS == 0)) || ga_gap 'Git LFS detected: source refs alone do not retain LFS objects; prove retrieval and retention.'
    ga_gap 'Accept/adapt governing guidance and ownership before goal execution; presence does not prove coverage.'
    ga_gap 'Verify the installed Codex client, effective instruction chain, models, reviewer roles and actual permissions.'
    ga_gap 'Record real product commands, isolated ports/data/effects, runtime limits and applicable local/CI differences.'
    ga_gap 'Verify GitHub required checks, eligible human premerge approval and release/tag identities in GitHub.'
    ga_gap 'Set recovery objectives, push source checkpoints, keep generated evidence ignored, clean it after merge or terminal cancellation/supersession, and perform a clean restore drill.'
    ga_gap 'Run applicable upgrade/health/support and acceptance demonstrations; scaffold creation is not product evidence.'
}

ga_cleanup() {
    # Only the one private staging directory and its known leaf belong to us.
    if [[ -n $GA_TEMP_DIR && -d $GA_TEMP_DIR && ! -L $GA_TEMP_DIR ]]; then
        if [[ -n $GA_TEMP_FILE ]]; then
            rm -f -- "$GA_TEMP_DIR/$GA_TEMP_FILE" || printf 'git agent: could not remove staged file %s\n' "$GA_TEMP_DIR/$GA_TEMP_FILE" >&2
        fi
        rmdir -- "$GA_TEMP_DIR" || printf 'git agent: inspect remaining staging directory %s\n' "$GA_TEMP_DIR" >&2
    fi
    GA_TEMP_DIR=''; GA_TEMP_FILE=''
}

ga_publish() {
    local path=$1 data=$2 target parent leaf component current part temp_name
    local parts=()
    ga_safe_path "$path"; target=$GA_SAFE
    if [[ -e $target ]]; then
        ga_same "$target" "$data" || ga_error "File changed after planning; preserved: $target. Rerun to review it."
        GA_PUBLISHED=0
        return 0
    fi
    parent=${target%/*}; leaf=${target##*/}; current=$GA_ROOT
    IFS=/ read -r -a parts <<< "${path%/*}"
    if [[ $path == */* ]]; then
        for part in "${parts[@]}"; do
            current=$current/$part
            if [[ -L $current || ( -e $current && ! -d $current ) ]]; then ga_error "Scaffold parent changed: $current"; fi
            if [[ ! -d $current ]]; then
                mkdir -- "$current" 2>/dev/null || [[ -d $current && ! -L $current ]] || ga_error "Cannot create scaffold directory: $current"
            fi
        done
    fi
    ga_safe_path "$path"
    GA_TEMP_DIR=$(mktemp -d "$parent/.git-agent-init.XXXXXXXX") || ga_error "Cannot create private staging directory in $parent."
    GA_TEMP_FILE=$leaf; temp_name=${GA_TEMP_DIR##*/}
    printf '%s' "$data" > "$GA_TEMP_DIR/$leaf" || ga_error "Cannot stage complete file: $path"
    chmod 0644 "$GA_TEMP_DIR/$leaf" || ga_error "Cannot set staged file mode: $path"
    ga_safe_path "$path"
    # Both GNU and BSD ln append the source basename exactly once when the
    # destination operand is '.'. An existing leaf directory is a collision,
    # not a directory into which ln may place a random temporary filename.
    if (CDPATH= cd -P -- "$parent" && ln "./$temp_name/$leaf" .); then
        GA_PUBLISHED=1
    else
        ga_safe_path "$path"
        if ga_same "$target" "$data"; then
            GA_PUBLISHED=0
        else
            ga_error "Cannot atomically create $target. Existing content is preserved; the filesystem must support hard links."
        fi
    fi
    ga_cleanup
}

ga_apply() {
    local i
    if ((GA_NEW)); then
        ga_git init --quiet -- "$GA_ROOT" || ga_error 'Native git init failed; inspect partial results.'
        ga_retention
        ga_read_head
        ga_inspect_metadata
    fi
    for ((i=0; i<${#GA_PATHS[@]}; i++)); do
        if [[ ${GA_WRITE[i]} == 1 ]]; then
            ga_publish "${GA_PATHS[i]}" "${GA_DATA[i]}"
            if ((GA_PUBLISHED == 0)); then
                [[ ${GA_KINDS[i]} == proposed ]] && GA_KINDS[i]='proposal unchanged' || GA_KINDS[i]=unchanged
            fi
        fi
    done
}

ga_help() {
    cat <<'GIT_AGENT_HELP'
usage: git agent init [directory] [--dry-run]
       git agent init --help
       git agent -h
       git agent --version

Initialize governed goal/artifact development using Git and two Codex skills.
The directory may be a new project, existing repository or linked worktree.
Omit it to use the current directory. Existing project files are preserved.

  --dry-run    Inspect and show the plan without writing the target or Git metadata.
  -h, --help   Show this help.
  --version    Show the initializer version.

Use git agent -h or git agent init --help for direct command help.
Git may send git agent --help to its separate manual-page viewer.

Requirements: Bash 3.2+, Git 2.31+, and stock shell utilities.
Daily work uses the generated skills and existing product/OS/VS Code commands.
GIT_AGENT_HELP
}

main() {
    local argument directory=. have_directory=0 stop_options=0 dry=0 mode kind i text
    set +e
    set +u
    set -o pipefail
    export LC_ALL=C
    shopt -s nullglob dotglob
    if ((BASH_VERSINFO[0] < 3 || (BASH_VERSINFO[0] == 3 && BASH_VERSINFO[1] < 2))); then
        printf 'git agent: Bash 3.2 or newer is required.\n' >&2
        return 2
    fi
    case ${1:-} in
        --help|-h) (($# == 1)) || ga_error 'Help takes no extra arguments.'; ga_help; return 0 ;;
        --version) (($# == 1)) || ga_error 'Version takes no extra arguments.'; printf 'git-agent %s\n' "$GA_VERSION"; return 0 ;;
        init) shift ;;
        '') ga_help >&2; return 2 ;;
        *) ga_error "Unsupported subcommand: $1. Use git agent -h." ;;
    esac
    for argument in "$@"; do
        if ((stop_options == 0)); then
            case $argument in
                --dry-run) dry=1; continue ;;
                --help|-h) ga_help; return 0 ;;
                --) stop_options=1; continue ;;
                -*) ga_error "Unknown init option: $argument" ;;
            esac
        fi
        ((have_directory == 0)) || ga_error 'Specify at most one directory.'
        directory=$argument; have_directory=1
    done
    GA_TEMP_DIR=''; GA_TEMP_FILE=''; GA_GAPS=()
    trap ga_cleanup EXIT
    trap 'printf "git agent init: interrupted; inspect partial results and rerun.\n" >&2; exit 130' INT
    trap 'printf "git agent init: terminated; inspect partial results and rerun.\n" >&2; exit 143' TERM
    ga_check_environment
    ga_discover "$directory"
    ga_load_templates
    ga_inspect
    ga_plan
    if ((dry)); then
        ((GA_NEW == 0)) || ga_gap 'Git ignore retention and native init-template/hooks inspection remain unverified until the repository exists; dry-run creates nothing.'
    else
        ga_apply
    fi
    ga_final_gaps
    mode=INITIALIZED; ((dry == 0)) || mode='DRY RUN'
    kind='existing repository'; ((GA_NEW == 0)) || kind='new repository'; ((GA_LINKED == 0)) || kind='linked worktree'
    printf 'git agent init - %s\nTarget: %s\nKind: %s\n' "$mode" "$GA_ROOT" "$kind"
    printf 'Template: %s / git-blob-sha1:%s\nRuntime: %s; Bash %s\n' "$GA_TEMPLATE_VERSION" "$GA_DIGEST" "$GA_GIT_VERSION" "$BASH_VERSION"
    [[ $GA_REQUESTED == "$GA_ROOT" ]] || printf 'Resolved from: %s\n' "$GA_REQUESTED"
    if ((${#GA_INSPECTED[@]})); then
        printf '\nInspected project guidance/setup (bounded, no execution):\n'
        for text in "${GA_INSPECTED[@]}"; do printf '  %s\n' "$text"; done
    fi
    ((GA_LINKED == 0)) || printf '\nLinked worktree: shared refs/configuration remain under the repository administration owner.\n'
    ((dry)) && printf '\nFile plan:\n' || printf '\nFile results:\n'
    for ((i=0; i<${#GA_PATHS[@]}; i++)); do
        printf '  %s: %s' "${GA_KINDS[i]}" "${GA_PATHS[i]}"
        case ${GA_KINDS[i]} in preserved*) printf ' -> %s' "${GA_SOURCES[i]}" ;; esac
        printf '\n'
    done
    printf '\nGaps / not yet verified:\n'
    for text in "${GA_GAPS[@]}"; do printf '  - %s\n' "$text"; done
    ((GA_REVIEW == 0)) || printf '\nReview required: compare proposed files under accepted guidance. Rerunning does not approve proposals.\n'
    if ((dry)); then
        printf '\nNo target directories, Git metadata, files, refs or settings were changed.\n'
    else
        printf '\nNext: inspect git diff and git status, settle gaps, and intentionally commit adopted guidance. No files were staged, committed or pushed.\n'
    fi
    ((GA_REVIEW == 0)) || return 3
    return 0
}
