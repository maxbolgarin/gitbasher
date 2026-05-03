#!/usr/bin/env bash

### Script for AI-driven commit squashing
# Asks the model to group related commits in the current branch's range
# (main..HEAD on a feature branch, last-tag..HEAD on the main branch) into
# clean, changelog-ready commits, then rebuilds history via interactive rebase.
# Use this script only with gitbasher.


# Per-commit max chars for the diff body sent to the AI grouping prompt.
# Sized so a typical squash range (10-30 commits) fits comfortably alongside
# the diff stats and subjects without blowing the context window.
readonly SQUASH_AI_DIFF_PER_COMMIT_CHARS=2000

# Hard cap on commits we will hand to the AI in one call. Beyond this the
# range is almost certainly the wrong one (e.g. a stale tag), so we ask the
# user to narrow it instead of silently truncating.
readonly SQUASH_MAX_COMMITS=80


### Resolve the base ref the squash range should start from.
# Echoes "<base_ref>|<source_label>" (pipe-separated) or empty on failure.
# Source label is shown to the user so they understand WHY we picked this base.
function squash_resolve_base_ref {
    local explicit_ref="$1"

    if [ -n "$explicit_ref" ]; then
        if ! git rev-parse --verify "$explicit_ref" >/dev/null 2>&1; then
            echo ""
            return 1
        fi
        echo "${explicit_ref}|explicit"
        return 0
    fi

    if [ "$current_branch" = "$main_branch" ]; then
        local last_tag
        last_tag=$(git describe --tags --abbrev=0 HEAD 2>/dev/null)
        if [ -n "$last_tag" ]; then
            echo "${last_tag}|last tag"
            return 0
        fi
        # No tag yet — fall back to the root commit so users on a fresh repo
        # still get a usable range.
        local root_commit
        root_commit=$(git rev-list --max-parents=0 HEAD 2>/dev/null | tail -n 1)
        if [ -n "$root_commit" ]; then
            echo "${root_commit}|root commit (no tags found)"
            return 0
        fi
        echo ""
        return 1
    fi

    # Feature branch: prefer the merge-base with the configured main branch.
    if git show-ref --verify --quiet "refs/heads/$main_branch"; then
        local merge_base
        merge_base=$(git merge-base HEAD "$main_branch" 2>/dev/null)
        if [ -n "$merge_base" ]; then
            echo "${merge_base}|merge-base with ${main_branch}"
            return 0
        fi
    fi

    echo ""
    return 1
}


### Build the data block describing each commit for the AI prompt.
# Per commit: full hash, short hash, subject, body, --stat, name-status, and a
# truncated diff. Truncation is per-commit so one huge change cannot starve the
# rest of the range.
# $1: base ref
function squash_build_commits_block {
    local base_ref="$1"
    local block=""
    local sep=""

    while IFS= read -r full_hash; do
        [ -z "$full_hash" ] && continue
        local short_hash subject body stat names diff
        short_hash=$(git log -n 1 --format='%h' "$full_hash" 2>/dev/null)
        subject=$(git log -n 1 --format='%s' "$full_hash" 2>/dev/null)
        body=$(git log -n 1 --format='%b' "$full_hash" 2>/dev/null)
        stat=$(git show --stat --format='' "$full_hash" 2>/dev/null | sed '/^$/d')
        names=$(git show --name-status --format='' "$full_hash" 2>/dev/null | sed '/^$/d')
        diff=$(git show --no-color --format='' "$full_hash" 2>/dev/null | head -c "$SQUASH_AI_DIFF_PER_COMMIT_CHARS")
        if [ ${#diff} -ge "$SQUASH_AI_DIFF_PER_COMMIT_CHARS" ]; then
            diff="${diff}
... [truncated]"
        fi

        block+="${sep}<commit hash=\"${short_hash}\">
<subject>${subject}</subject>"
        if [ -n "$body" ]; then
            block+="
<body>
${body}
</body>"
        fi
        if [ -n "$stat" ]; then
            block+="
<stat>
${stat}
</stat>"
        fi
        if [ -n "$names" ]; then
            block+="
<files>
${names}
</files>"
        fi
        if [ -n "$diff" ]; then
            block+="
<diff>
${diff}
</diff>"
        fi
        block+="
</commit>"
        sep=$'\n'
    done < <(git rev-list --reverse "${base_ref}..HEAD" 2>/dev/null)

    printf '%s' "$block"
}


### Ask the AI to group commits in the range into clean, changelog-ready
### commits. Streams the model's plan into stdout for the caller to parse.
# $1: base ref
# $2: total commit count (for context)
function squash_call_ai_grouping {
    local base_ref="$1"
    local commit_count="$2"

    local commits_block recent_commits
    commits_block=$(squash_build_commits_block "$base_ref")
    recent_commits=$(get_recent_commit_messages_for_ai)

    local system_prompt='You are a git history editor. You receive a chronological list of commits (oldest first) inside <commits> and must propose how to consolidate them into a clean, changelog-ready history.

Goals (in priority order):
1. Each output group represents ONE logical change a reader would want to see in a CHANGELOG. Merge "fix typo", "address review", "wip", "fixup!", "lint", "rebase fix", and follow-up tweaks INTO the commit they belong to.
2. Preserve every code change. Never drop a commit just because its message is poor — squash it into a meaningful neighbour instead.
3. Keep unrelated changes in separate groups. A bug fix and a new feature should not share a group even if they are adjacent.
4. Order groups by the FIRST commit in each group (the original chronological order of group leaders MUST be preserved). Within a group, commits also stay in their original order.

Output format (STRICT — any deviation will be rejected):
- Output ONLY blocks like the example below, separated by blank lines. No prose before, between, or after the blocks. No markdown fences.
- Each block has exactly these fields, in this order, one per line:
    GROUP: <1-based index>
    COMMITS: <space-separated short hashes from the input, in original order>
    MESSAGE: <conventional commit header, lowercase subject, <=100 chars total>
    BODY: <single line, or the literal string NONE>
- The MESSAGE follows Conventional Commits: type(scope): subject. Allowed types: feat, fix, refactor, perf, test, build, ci, chore, docs, style. Scope is optional. Subject is imperative, lowercase, no trailing period.
- BODY is one line of prose explaining WHY (1-2 short sentences). If no body is needed, write the literal word NONE.
- Every input hash MUST appear in exactly one COMMITS line. The union of all COMMITS lines MUST equal the input set, with the original order preserved within each group.
- Prefer keeping the existing message of the leader commit when it is already clean and accurate; only rewrite when consolidation actually changes the meaning.

Example output for three input commits abc1111 def2222 ghi3333 where the second is a fix to the first and the third is unrelated:

GROUP: 1
COMMITS: abc1111 def2222
MESSAGE: feat(auth): add backup codes for MFA recovery
BODY: Folds the follow-up null-check fix into the original feature so the changelog shows one self-contained change.

GROUP: 2
COMMITS: ghi3333
MESSAGE: docs: update contributing guide
BODY: NONE'

    local user_prompt="<recent_commits>
${recent_commits}
</recent_commits>

<range>
base=${base_ref}
total_commits=${commit_count}
</range>

<commits>
${commits_block}
</commits>

Group these ${commit_count} commits as instructed. Output GROUP/COMMITS/MESSAGE/BODY blocks only."

    call_ai_api "$system_prompt" "$user_prompt" 4096 "$(get_ai_model_for grouping)"
}


### Parse the AI grouping response.
# Populates these globals:
#   squash_group_count       — number of groups
#   squash_group_commits[i]  — space-separated short hashes for group i (1-based)
#   squash_group_message[i]  — conventional commit header for group i
#   squash_group_body[i]     — body line for group i (empty if NONE)
# Returns 0 on success, 1 on parse / validation failure.
# $1: AI response text
# $2: expected ordered short hashes (space-separated; chronological)
function squash_parse_ai_plan {
    local response="$1"
    local expected_hashes_str="$2"

    # Reset globals
    unset squash_group_commits squash_group_message squash_group_body
    declare -gA squash_group_commits
    declare -gA squash_group_message
    declare -gA squash_group_body
    squash_group_count=0

    # Strip stray markdown fences
    response=$(printf '%s' "$response" | LC_ALL=C sed -e 's/^```[a-zA-Z]*$//' -e 's/^```$//')

    # Build a set of expected hashes for membership checks
    local -A expected_set=()
    local -a expected_order=()
    local h
    for h in $expected_hashes_str; do
        expected_set["$h"]=1
        expected_order+=("$h")
    done

    local current_group=0
    local current_commits="" current_message="" current_body=""
    local in_block=0
    local seen=()
    declare -A seen_set=()

    # Helper: flush the in-progress block to the globals.
    _squash_flush_block() {
        if [ "$in_block" = "1" ]; then
            if [ -z "$current_commits" ] || [ -z "$current_message" ]; then
                in_block=0
                return 1
            fi
            current_group=$((current_group + 1))
            squash_group_commits["$current_group"]="$current_commits"
            squash_group_message["$current_group"]="$current_message"
            if [ "$current_body" = "NONE" ]; then
                squash_group_body["$current_group"]=""
            else
                squash_group_body["$current_group"]="$current_body"
            fi
            current_commits=""
            current_message=""
            current_body=""
            in_block=0
        fi
        return 0
    }

    while IFS= read -r line; do
        # Trim trailing CR / spaces
        line=$(printf '%s' "$line" | LC_ALL=C sed -e 's/[[:space:]]*$//')

        case "$line" in
            GROUP:*|"GROUP "*)
                _squash_flush_block || return 1
                in_block=1
                ;;
            COMMITS:*)
                local commits_value="${line#COMMITS:}"
                commits_value=$(printf '%s' "$commits_value" | LC_ALL=C sed -e 's/^[[:space:]]*//')
                local validated=""
                local c
                for c in $commits_value; do
                    if [ -z "${expected_set[$c]:-}" ]; then
                        return 1
                    fi
                    if [ -n "${seen_set[$c]:-}" ]; then
                        return 1
                    fi
                    seen_set["$c"]=1
                    seen+=("$c")
                    validated+="${validated:+ }$c"
                done
                current_commits="$validated"
                ;;
            MESSAGE:*)
                local msg_value="${line#MESSAGE:}"
                msg_value=$(printf '%s' "$msg_value" | LC_ALL=C sed -e 's/^[[:space:]]*//')
                if [ -z "$msg_value" ] || [ ${#msg_value} -gt 200 ]; then
                    return 1
                fi
                # Reject newlines / control chars
                if printf '%s' "$msg_value" | LC_ALL=C grep -q '[[:cntrl:]]'; then
                    return 1
                fi
                current_message="$msg_value"
                ;;
            BODY:*)
                local body_value="${line#BODY:}"
                body_value=$(printf '%s' "$body_value" | LC_ALL=C sed -e 's/^[[:space:]]*//')
                if [ ${#body_value} -gt 500 ]; then
                    body_value="${body_value:0:500}"
                fi
                current_body="$body_value"
                ;;
            "")
                : # blank line is fine inside or between blocks
                ;;
            *)
                # Unknown line — ignore, the model sometimes adds stray narration
                # despite instructions. We still validate the final coverage.
                ;;
        esac
    done <<< "$response"

    _squash_flush_block || return 1

    # Coverage check: every expected hash must appear exactly once
    if [ "${#seen[@]}" -ne "${#expected_order[@]}" ]; then
        return 1
    fi
    for h in "${expected_order[@]}"; do
        if [ -z "${seen_set[$h]:-}" ]; then
            return 1
        fi
    done

    # Group leader order check: leaders must appear in the same chronological
    # order as the input. We look up each leader's index in expected_order and
    # require strictly increasing indices.
    local last_idx=-1
    local g
    for ((g = 1; g <= current_group; g++)); do
        local first_hash="${squash_group_commits[$g]%% *}"
        local i idx=-1
        for i in "${!expected_order[@]}"; do
            if [ "${expected_order[$i]}" = "$first_hash" ]; then
                idx="$i"
                break
            fi
        done
        if [ "$idx" -le "$last_idx" ]; then
            return 1
        fi
        last_idx="$idx"
    done

    squash_group_count="$current_group"
    if [ "$squash_group_count" -lt 1 ]; then
        return 1
    fi
    return 0
}


### Print the AI plan in a human-readable form.
function squash_print_plan {
    echo -e "${YELLOW}Proposed history:${ENDCOLOR}"
    echo
    local g
    for ((g = 1; g <= squash_group_count; g++)); do
        local commits="${squash_group_commits[$g]}"
        local message="${squash_group_message[$g]}"
        local body="${squash_group_body[$g]}"
        local count=$(printf '%s\n' $commits | grep -c .)
        echo -e "${GREEN}Commit $g${ENDCOLOR} ${GRAY}(from ${count} commit$([ "$count" -gt 1 ] && echo s))${ENDCOLOR}"
        echo -e "  ${BOLD}${message}${ENDCOLOR}"
        if [ -n "$body" ]; then
            echo -e "  ${GRAY}${body}${ENDCOLOR}"
        fi
        local c
        for c in $commits; do
            local subject
            subject=$(git log -n 1 --format='%s' "$c" 2>/dev/null)
            echo -e "    ${YELLOW}${c}${ENDCOLOR} ${subject}"
        done
        echo
    done
}


### Build the rebase todo + per-group message files for the AI plan.
# Writes the todo to $1 and message files into directory $2 (msg-1, msg-2, …).
# The todo uses pick + fixup to consolidate each group, then an `exec git
# commit --amend -F <msg-file>` so we can rewrite the leader's message with
# the AI-proposed text without dropping into an editor.
function squash_write_rebase_todo {
    local todo_file="$1"
    local msg_dir="$2"

    : > "$todo_file"
    local g
    for ((g = 1; g <= squash_group_count; g++)); do
        local commits="${squash_group_commits[$g]}"
        local message="${squash_group_message[$g]}"
        local body="${squash_group_body[$g]}"
        local first=1
        local c
        for c in $commits; do
            local subject
            subject=$(git log -n 1 --format='%s' "$c" 2>/dev/null)
            if [ "$first" = "1" ]; then
                printf 'pick %s %s\n' "$c" "$subject" >> "$todo_file"
                first=0
            else
                printf 'fixup %s %s\n' "$c" "$subject" >> "$todo_file"
            fi
        done

        local msg_file="${msg_dir}/msg-${g}"
        {
            printf '%s\n' "$message"
            if [ -n "$body" ]; then
                printf '\n%s\n' "$body"
            fi
        } > "$msg_file"

        # `exec` runs in the rebased working tree; --amend updates HEAD's message
        # for the leader of this group. Quote the path defensively (msg_dir is
        # mktemp output, but there is no harm in being explicit).
        printf 'exec git commit --amend -F %q\n' "$msg_file" >> "$todo_file"
    done
}


### Run the rebase using the prepared todo file.
# $1: base ref
# $2: todo file path
# Returns 0 on clean rebase; non-zero on failure (rebase already aborted/handled).
function squash_run_rebase {
    local base_ref="$1"
    local todo_file="$2"
    local rebase_output rebase_code

    # GIT_SEQUENCE_EDITOR copies our prepared todo over the one git generated.
    # `cp` is portable across GNU/BSD coreutils, unlike `cat <<<` redirection
    # which would need a shell.
    rebase_output=$(GIT_SEQUENCE_EDITOR="cp '${todo_file}'" git rebase -i "$base_ref" 2>&1)
    rebase_code=$?

    echo "$rebase_output"

    if [ "$rebase_code" -ne 0 ]; then
        # On any failure, leave the user with a clean tree by aborting if a
        # rebase is still in progress.
        if [ -d "$(git rev-parse --git-dir)/rebase-merge" ] || [ -d "$(git rev-parse --git-dir)/rebase-apply" ]; then
            echo
            echo -e "${YELLOW}Aborting rebase to restore your branch...${ENDCOLOR}"
            git rebase --abort >/dev/null 2>&1
        fi
        return "$rebase_code"
    fi
    return 0
}


### Print help for `gitb squash`.
function squash_print_help {
    echo -e "usage: ${YELLOW}gitb squash <mode>${ENDCOLOR}"
    echo
    msg="${YELLOW}Mode${ENDCOLOR}_${GREEN}Aliases${ENDCOLOR}_\t${BLUE}Description${ENDCOLOR}"
    msg="$msg\n${BOLD}<empty>${ENDCOLOR}_ _Ask AI to group commits in range and rebase interactively"
    msg="$msg\n${BOLD}preview${ENDCOLOR}_p|dry|show_Show the AI plan without rewriting history"
    msg="$msg\n${BOLD}yes${ENDCOLOR}_y|fast_Skip the confirmation prompt and apply the plan"
    msg="$msg\n${BOLD}push${ENDCOLOR}_ps_After rebase, force-push with --force-with-lease"
    msg="$msg\n${BOLD}help${ENDCOLOR}_h_Show this help"
    echo -e "$(echo -e "$msg" | column -ts '_')"
    echo
    echo -e "${YELLOW}Range:${ENDCOLOR}"
    echo -e "  • On ${BOLD}${main_branch}${NORMAL}: commits since the last tag (or root if none)"
    echo -e "  • On any other branch: commits since the merge-base with ${BOLD}${main_branch}${NORMAL}"
    echo
    echo -e "${YELLOW}Recovery:${ENDCOLOR}"
    echo -e "  • If the result is wrong, run ${BOLD}gitb undo rebase${NORMAL} to restore the original branch"
}


### Main entry point.
# $1: mode  ("" | preview | yes | push | help)
function squash_script {
    local mode_preview="" mode_yes="" mode_push="" help=""

    case "$1" in
        ""|"")               ;;
        preview|p|dry|show)  mode_preview="true";;
        yes|y|fast)          mode_yes="true";;
        push|ps)             mode_push="true";;
        help|h)              help="true";;
        *)
            wrong_mode "squash" "$1"
            ;;
    esac

    local header="GIT SQUASH AI"
    if [ -n "$mode_preview" ]; then
        header="$header PREVIEW"
    elif [ -n "$mode_yes" ]; then
        header="$header FAST"
    elif [ -n "$mode_push" ]; then
        header="$header PUSH"
    fi
    echo -e "${YELLOW}${header}${ENDCOLOR}"
    echo

    if [ -n "$help" ]; then
        squash_print_help
        exit
    fi

    ### Preconditions
    warn_if_detached_head "squash"

    if ! check_ai_available; then
        exit 1
    fi

    local clean_status
    clean_status=$(git status | tail -n 1)
    if [ "$clean_status" != "nothing to commit, working tree clean" ]; then
        echo -e "${RED}Cannot squash! There are uncommitted changes:${ENDCOLOR}"
        git_status
        exit 1
    fi

    if [ -d "$(git rev-parse --git-dir)/rebase-merge" ] || [ -d "$(git rev-parse --git-dir)/rebase-apply" ]; then
        echo -e "${RED}A rebase is already in progress.${ENDCOLOR}"
        echo -e "Resolve it first with ${YELLOW}git rebase --abort${ENDCOLOR} or ${YELLOW}gitb undo rebase${ENDCOLOR}."
        exit 1
    fi

    ### Resolve range
    local resolved
    resolved=$(squash_resolve_base_ref "")
    if [ -z "$resolved" ]; then
        echo -e "${RED}Cannot determine a base for the squash range.${ENDCOLOR}"
        if [ "$current_branch" = "$main_branch" ]; then
            echo -e "Tag a release first (${YELLOW}gitb tag${ENDCOLOR}) or use a feature branch."
        else
            echo -e "Make sure ${YELLOW}${main_branch}${ENDCOLOR} exists locally."
        fi
        exit 1
    fi
    local base_ref="${resolved%%|*}"
    local source_label="${resolved##*|}"

    local commit_hashes_full
    commit_hashes_full=$(git rev-list --reverse "${base_ref}..HEAD" 2>/dev/null)

    if [ -z "$commit_hashes_full" ]; then
        echo -e "${GREEN}Nothing to squash — no commits between ${source_label} (${base_ref::12}) and HEAD${ENDCOLOR}"
        exit 0
    fi

    local commit_count
    commit_count=$(printf '%s\n' "$commit_hashes_full" | grep -c .)

    if [ "$commit_count" -lt 2 ]; then
        echo -e "${GREEN}Nothing to squash — only ${commit_count} commit in range${ENDCOLOR}"
        exit 0
    fi

    if [ "$commit_count" -gt "$SQUASH_MAX_COMMITS" ]; then
        echo -e "${RED}Range is too large: ${commit_count} commits (cap: ${SQUASH_MAX_COMMITS}).${ENDCOLOR}"
        echo -e "Tag a recent release or rebase onto a closer base before retrying."
        exit 1
    fi

    local expected_short_hashes=""
    local h
    while IFS= read -r h; do
        [ -z "$h" ] && continue
        local short
        short=$(git rev-parse --short "$h" 2>/dev/null)
        expected_short_hashes+="${expected_short_hashes:+ }${short}"
    done <<< "$commit_hashes_full"

    echo -e "${YELLOW}Range:${ENDCOLOR} ${BLUE}${base_ref::12}${ENDCOLOR}..HEAD ${GRAY}(${source_label})${ENDCOLOR}"
    echo -e "${YELLOW}Commits:${ENDCOLOR} ${commit_count}"
    echo
    echo -e "${YELLOW}Original history:${ENDCOLOR}"
    git log --reverse --format="  ${YELLOW}%h${ENDCOLOR} (${BLUE}%cr${ENDCOLOR}) %s" "${base_ref}..HEAD"
    echo

    ### Ask the AI
    echo -e "${YELLOW}Asking AI to group these commits...${ENDCOLOR}"
    local ai_response
    ai_response=$(squash_call_ai_grouping "$base_ref" "$commit_count")
    local ai_status=$?
    if [ "$ai_status" -ne 0 ] || [ -z "$ai_response" ]; then
        echo -e "${RED}AI grouping failed${ENDCOLOR}"
        exit 1
    fi

    if ! squash_parse_ai_plan "$ai_response" "$expected_short_hashes"; then
        echo -e "${RED}Could not parse the AI plan.${ENDCOLOR}"
        echo -e "${YELLOW}Raw response (first 30 lines):${ENDCOLOR}"
        printf '%s\n' "$ai_response" | head -n 30
        exit 1
    fi

    echo
    if [ "$squash_group_count" -ge "$commit_count" ]; then
        echo -e "${GREEN}AI didn't find groups to merge — every commit stays as its own change.${ENDCOLOR}"
        echo
    fi
    squash_print_plan

    ### Preview-only mode stops here
    if [ -n "$mode_preview" ]; then
        echo -e "${GRAY}(preview only — no changes made)${ENDCOLOR}"
        exit 0
    fi

    ### Refuse to apply when nothing would actually change
    if [ "$squash_group_count" -ge "$commit_count" ]; then
        echo -e "Nothing to consolidate — leaving history untouched."
        exit 0
    fi

    if [ -z "$mode_yes" ]; then
        echo -e "Apply this plan? Original commits will be rewritten."
        echo -e "${GRAY}You can recover the original branch with ${BOLD}gitb undo rebase${NORMAL}${GRAY} afterwards.${ENDCOLOR}"
        echo -e "Proceed (y/n)?"
        local choice
        read -n 1 -s choice
        if ! is_yes "$choice"; then
            echo
            echo -e "${YELLOW}Cancelled${ENDCOLOR}"
            exit 0
        fi
        echo
    fi

    ### Build todo + message files in a temp dir, then rebase
    local work_dir
    work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gitbasher-squash.XXXXXX") || {
        echo -e "${RED}Failed to create temp directory${ENDCOLOR}"
        exit 1
    }
    # Always clean up the temp dir, even on failure
    trap 'rm -rf "$work_dir"' EXIT

    local todo_file="${work_dir}/todo"
    squash_write_rebase_todo "$todo_file" "$work_dir"

    echo -e "${YELLOW}Rebasing...${ENDCOLOR}"
    if ! squash_run_rebase "$base_ref" "$todo_file"; then
        echo -e "${RED}Squash failed — your branch was restored.${ENDCOLOR}"
        exit 1
    fi

    echo
    echo -e "${GREEN}Successful squash!${ENDCOLOR}"
    echo -e "${YELLOW}New history:${ENDCOLOR}"
    git log --reverse --format="  ${YELLOW}%h${ENDCOLOR} (${BLUE}%cr${ENDCOLOR}) %s" "${base_ref}..HEAD"
    echo

    ### Optional force-push
    if [ -n "$mode_push" ]; then
        echo -e "${YELLOW}Force-pushing with --force-with-lease...${ENDCOLOR}"
        local push_output push_code
        push_output=$(git push --force-with-lease -u "$origin_name" "$current_branch" 2>&1)
        push_code=$?
        if [ "$push_code" -eq 0 ]; then
            echo -e "${GREEN}Pushed!${ENDCOLOR}"
            echo "$push_output" | tail -n 5
        else
            echo -e "${RED}Push failed:${ENDCOLOR}"
            echo "$push_output"
            exit "$push_code"
        fi
    else
        echo -e "${GRAY}History is rewritten locally.${ENDCOLOR} Push it with ${YELLOW}gitb push force${ENDCOLOR} (or ${YELLOW}gitb squash push${ENDCOLOR} next time to chain)."
    fi
}
