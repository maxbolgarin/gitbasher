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

# Soft warning threshold. Above this count the pre-AI confirmation flags the
# range as "large" because the model's accuracy at partitioning hashes drops
# noticeably past ~80 commits. The user can still proceed.
readonly SQUASH_MAX_COMMITS=80

# Maximum commits handed to the model in a single AI call. Above this we split
# the range into windows of ≤ SQUASH_CHUNK_SIZE commits, group each chunk
# independently, then concatenate. Tuned so each chunk fits comfortably in the
# model's working memory; smaller is more reliable but produces more chunks.
readonly SQUASH_CHUNK_SIZE=25


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
# $1: newline-separated full hashes (chronological, oldest first)
function squash_build_commits_block {
    local hashes_input="$1"
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
    done <<< "$hashes_input"

    printf '%s' "$block"
}


### Ask the AI to group commits in the range into clean, changelog-ready
### commits. Streams the model's plan as a JSON object into stdout for the
### caller to parse. JSON mode (response_format) eliminates whole classes of
### parse failure that the previous free-text format used to suffer.
# $1: newline-separated full hashes for THIS chunk (chronological, oldest first)
# $2: chunk context label (e.g. "1/3" or empty for single-call)
# $3: optional correction note appended to the user prompt (used on retry
#     after a parse failure to point the model at its specific mistake)
function squash_call_ai_grouping {
    local hashes_input="$1"
    local chunk_label="${2:-}"
    local correction_note="${3:-}"

    local commit_count
    commit_count=$(printf '%s\n' "$hashes_input" | grep -c .)

    local commits_block recent_commits
    commits_block=$(squash_build_commits_block "$hashes_input")
    recent_commits=$(get_recent_commit_messages_for_ai)

    local chunk_note=""
    if [ -n "$chunk_label" ]; then
        chunk_note="
This is chunk ${chunk_label} of a larger range — group ONLY the commits shown
inside <commits>. Do not invent hashes from outside this chunk."
    fi

    local system_prompt='You are a git history editor. You receive a chronological list of commits (oldest first) inside <commits> and must propose how to consolidate them into a clean, changelog-ready history.

Goals (in priority order):
1. Each output group represents ONE logical change a reader would want to see in a CHANGELOG. Merge "fix typo", "address review", "wip", "fixup!", "lint", "rebase fix", and follow-up tweaks INTO the commit they belong to.
2. Preserve every code change. Never drop a commit just because its message is poor — squash it into a meaningful neighbour instead.
3. Keep unrelated changes in separate groups. A bug fix and a new feature should not share a group even if they are adjacent.
4. Order groups by the FIRST commit in each group (the original chronological order of group leaders MUST be preserved). Within a group, commits also stay in their original order.

Output format: a single JSON object matching this schema (no prose, no markdown fences):

{
  "groups": [
    {
      "commits": ["<short hash>", "<short hash>", ...],
      "message": "<conventional commit header, lowercase subject, <=100 chars>",
      "body": "<one-line body explaining WHY, or empty string for no body>"
    }
  ]
}

Rules (any violation will be rejected):
- The "message" field follows Conventional Commits: type(scope): subject. Allowed types: feat, fix, refactor, perf, test, build, ci, chore, docs, style. Scope is optional. Subject is imperative, lowercase, no trailing period.
- The "body" field is a SINGLE line (no newlines) explaining WHY in 1-2 short sentences. Use the empty string "" if no body is needed.
- Each "commits" array contains the EXACT short hashes from the input, in their original chronological order.
- Every input hash MUST appear in exactly one "commits" array across the response. No duplicates, no omissions, no hashes outside the input set.
- Prefer keeping the existing leader-commit message verbatim when it is already clean and accurate.

Example response for three input commits abc1111 def2222 ghi3333 where the second is a fix to the first and the third is unrelated:

{"groups":[{"commits":["abc1111","def2222"],"message":"feat(auth): add backup codes for MFA recovery","body":"Folds the follow-up null-check fix into the original feature so the changelog shows one self-contained change."},{"commits":["ghi3333"],"message":"docs: update contributing guide","body":""}]}'

    local user_prompt="<recent_commits>
${recent_commits}
</recent_commits>

<commits>
${commits_block}
</commits>
${chunk_note}

Group these ${commit_count} commits as instructed. Output a single JSON object only."

    if [ -n "$correction_note" ]; then
        user_prompt="${user_prompt}

CORRECTION (your previous attempt was rejected):
${correction_note}

Re-do the grouping. Every input hash MUST appear in EXACTLY ONE \"commits\" array — no duplicates, no omissions, no hashes outside the input set. Output a single JSON object only."
    fi

    # Size max_tokens to the commit count: ~120 tokens per commit covers a
    # full group entry with room for a verbose body. Floor at 2048 (small
    # chunks) and cap at 16384 (model-wide ceiling).
    local max_out=$(( commit_count * 120 ))
    [ "$max_out" -lt 2048 ] && max_out=2048
    [ "$max_out" -gt 16384 ] && max_out=16384

    call_ai_api "$system_prompt" "$user_prompt" "$max_out" "$(get_ai_model_for grouping)" '{"type":"json_object"}'
}


### Parse the AI grouping JSON response.
# Populates these globals:
#   squash_group_count       — number of groups
#   squash_group_commits[i]  — space-separated short hashes for group i (1-based)
#   squash_group_message[i]  — conventional commit header for group i
#   squash_group_body[i]     — body line for group i (empty when omitted)
# Returns 0 on success, 1 on parse / validation failure.
# $1: AI response text (a JSON object with a "groups" array)
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
    squash_parse_error=""

    if ! command -v jq &>/dev/null; then
        squash_parse_error="jq is required to parse the AI plan but is not installed"
        return 1
    fi

    # The model sometimes prepends/appends prose or markdown fences despite
    # response_format=json_object. Extract the outermost {...} block to be safe.
    local json_only
    json_only=$(printf '%s' "$response" | LC_ALL=C awk '
        BEGIN{depth=0; started=0; out=""}
        {
            for (i=1; i<=length($0); i++) {
                c=substr($0,i,1)
                if (c=="{") { depth++; started=1 }
                if (started) out=out c
                if (c=="}") { depth--; if (depth==0 && started) { print out; exit } }
            }
            if (started) out=out "\n"
        }')

    if [ -z "$json_only" ]; then
        squash_parse_error="response is not JSON (no { } block found)"
        return 1
    fi

    if ! printf '%s' "$json_only" | jq -e . >/dev/null 2>&1; then
        squash_parse_error="response is not valid JSON — likely truncated by max_tokens"
        return 1
    fi

    # Extract groups count and shape
    local groups_count
    groups_count=$(printf '%s' "$json_only" | jq -r '.groups | length' 2>/dev/null)
    if [ -z "$groups_count" ] || [ "$groups_count" = "null" ]; then
        squash_parse_error="response is missing the \"groups\" array"
        return 1
    fi
    if [ "$groups_count" -lt 1 ]; then
        squash_parse_error="response contains zero groups"
        return 1
    fi

    # Build expected-hash sets
    local -A expected_set=()
    local -a expected_order=()
    local h
    for h in $expected_hashes_str; do
        expected_set["$h"]=1
        expected_order+=("$h")
    done

    local seen=()
    declare -A seen_set=()
    local current_group=0
    local g
    for ((g = 0; g < groups_count; g++)); do
        local one_idx=$((g + 1))
        local commits_arr message body
        commits_arr=$(printf '%s' "$json_only" | jq -r ".groups[$g].commits | if type==\"array\" then .[] else empty end" 2>/dev/null)
        message=$(printf '%s' "$json_only" | jq -r ".groups[$g].message // \"\"" 2>/dev/null)
        body=$(printf '%s' "$json_only" | jq -r ".groups[$g].body // \"\"" 2>/dev/null)

        if [ -z "$commits_arr" ]; then
            squash_parse_error="group $one_idx has empty or missing \"commits\" array — likely truncated by max_tokens"
            return 1
        fi
        if [ -z "$message" ]; then
            squash_parse_error="group $one_idx has empty or missing \"message\""
            return 1
        fi
        if [ ${#message} -gt 200 ]; then
            squash_parse_error="group $one_idx \"message\" is ${#message} chars (max 200)"
            return 1
        fi
        # Strip newlines from message; the rebase squash header must be one line.
        message=$(printf '%s' "$message" | tr -d '\r\n')
        # Body may be multi-line in some models; squash to one line.
        body=$(printf '%s' "$body" | tr '\r\n' '  ' | LC_ALL=C sed -e 's/  */ /g' -e 's/^ //' -e 's/ $//')
        if [ ${#body} -gt 500 ]; then
            body="${body:0:500}"
        fi

        local validated="" c
        while IFS= read -r c; do
            [ -z "$c" ] && continue
            if [ -z "${expected_set[$c]:-}" ]; then
                squash_parse_error="group $one_idx references unknown commit '$c' (not in input range)"
                return 1
            fi
            if [ -n "${seen_set[$c]:-}" ]; then
                squash_parse_error="group $one_idx reuses commit '$c' already assigned to an earlier group"
                return 1
            fi
            seen_set["$c"]=1
            seen+=("$c")
            validated+="${validated:+ }$c"
        done <<< "$commits_arr"

        current_group=$((current_group + 1))
        squash_group_commits["$current_group"]="$validated"
        squash_group_message["$current_group"]="$message"
        squash_group_body["$current_group"]="$body"
    done

    # Coverage check: every expected hash must appear exactly once
    if [ "${#seen[@]}" -ne "${#expected_order[@]}" ]; then
        squash_parse_error="coverage: AI returned ${#seen[@]} commits but range has ${#expected_order[@]} — response likely truncated by max_tokens"
        return 1
    fi
    for h in "${expected_order[@]}"; do
        if [ -z "${seen_set[$h]:-}" ]; then
            squash_parse_error="coverage: commit '$h' is missing from the AI plan"
            return 1
        fi
    done

    # Leader order check: group leaders must appear in chronological order.
    local last_idx=-1
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
            squash_parse_error="group $g leader '$first_hash' appears out of chronological order"
            return 1
        fi
        last_idx="$idx"
    done

    squash_group_count="$current_group"
    return 0
}


### Run a single AI grouping call with up to N attempts and corrective retries.
# On success, the parsed plan is in the squash_group_* globals.
# $1: newline-separated full hashes for the chunk (chronological)
# $2: chunk's expected short hashes (space-separated, chronological)
# $3: chunk label (e.g. "1/3" or empty for single-call)
# Returns 0 on success. On failure, sets squash_parse_error and stores the
# last raw response in squash_last_ai_response for the caller to dump.
function squash_run_ai_attempt {
    local hashes_input="$1"
    local expected_short="$2"
    local chunk_label="${3:-}"

    local correction="" attempt
    local max_attempts=3
    local response=""
    for ((attempt = 1; attempt <= max_attempts; attempt++)); do
        response=$(squash_call_ai_grouping "$hashes_input" "$chunk_label" "$correction")
        local rc=$?
        squash_last_ai_response="$response"
        if [ "$rc" -ne 0 ] || [ -z "$response" ]; then
            squash_parse_error="AI request failed (rc=$rc, empty=$([ -z "$response" ] && echo yes || echo no))"
            return 1
        fi

        if squash_parse_ai_plan "$response" "$expected_short"; then
            return 0
        fi

        if [ "$attempt" -lt "$max_attempts" ]; then
            local prefix=""
            [ -n "$chunk_label" ] && prefix="chunk ${chunk_label} "
            echo -e "${YELLOW}AI plan rejected (${prefix}${squash_parse_error}). Retry ${attempt}/${max_attempts}...${ENDCOLOR}"
            correction="${squash_parse_error}"
        fi
    done
    return 1
}


### Run the AI grouping over the full range, splitting into chunks if the
### range exceeds SQUASH_CHUNK_SIZE. Each chunk is grouped independently and
### the resulting groups are concatenated in chronological order. Cross-chunk
### consolidation (e.g. a typo fix in chunk 2 belonging to a feature in chunk
### 1) is sacrificed for reliability — the model partitions far more accurately
### on small windows.
# $1: newline-separated full hashes for the entire range (chronological)
# $2: expected short hashes for the entire range (space-separated)
# Populates squash_group_* globals on success.
function squash_run_ai_grouping {
    local all_hashes="$1"
    local expected_all="$2"

    local total=0
    local h
    local -a all_hashes_arr=()
    while IFS= read -r h; do
        [ -z "$h" ] && continue
        all_hashes_arr+=("$h")
    done <<< "$all_hashes"
    total=${#all_hashes_arr[@]}

    local -a expected_all_arr=()
    for h in $expected_all; do expected_all_arr+=("$h"); done

    if [ "$total" -le "$SQUASH_CHUNK_SIZE" ]; then
        echo -e "${YELLOW}Asking AI to group ${total} commits...${ENDCOLOR}"
        if squash_run_ai_attempt "$all_hashes" "$expected_all" ""; then
            return 0
        fi
        return 1
    fi

    # Multi-chunk path. Distribute commits roughly evenly across chunks so the
    # last chunk isn't a tiny straggler.
    local num_chunks=$(( (total + SQUASH_CHUNK_SIZE - 1) / SQUASH_CHUNK_SIZE ))
    local avg=$(( (total + num_chunks - 1) / num_chunks ))

    echo -e "${YELLOW}Range is large (${total} commits) — splitting into ${num_chunks} chunks of ~${avg} commits each.${ENDCOLOR}"

    # Final accumulators across all chunks
    local -a final_commits=() final_message=() final_body=()

    local i=0 chunk_idx=1
    while [ "$i" -lt "$total" ]; do
        local end=$(( i + avg ))
        [ "$end" -gt "$total" ] && end="$total"

        local chunk_hashes_input="" chunk_expected="" k
        for ((k = i; k < end; k++)); do
            chunk_hashes_input+="${chunk_hashes_input:+
}${all_hashes_arr[$k]}"
            chunk_expected+="${chunk_expected:+ }${expected_all_arr[$k]}"
        done
        local chunk_count=$((end - i))
        local label="${chunk_idx}/${num_chunks}"

        echo -e "${YELLOW}Asking AI to group chunk ${BOLD}${label}${NORMAL}${YELLOW} (${chunk_count} commits)...${ENDCOLOR}"
        if ! squash_run_ai_attempt "$chunk_hashes_input" "$chunk_expected" "$label"; then
            squash_parse_error="chunk ${label}: ${squash_parse_error}"
            return 1
        fi

        local g
        for ((g = 1; g <= squash_group_count; g++)); do
            final_commits+=("${squash_group_commits[$g]}")
            final_message+=("${squash_group_message[$g]}")
            final_body+=("${squash_group_body[$g]}")
        done

        i="$end"
        chunk_idx=$((chunk_idx + 1))
    done

    # Copy accumulators back into the per-group globals.
    unset squash_group_commits squash_group_message squash_group_body
    declare -gA squash_group_commits
    declare -gA squash_group_message
    declare -gA squash_group_body
    squash_group_count=${#final_commits[@]}

    local g_idx
    for g_idx in "${!final_commits[@]}"; do
        local target=$((g_idx + 1))
        squash_group_commits[$target]="${final_commits[$g_idx]}"
        squash_group_message[$target]="${final_message[$g_idx]}"
        squash_group_body[$target]="${final_body[$g_idx]}"
    done

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
    local PAD=24
    print_help_header $PAD
    print_help_row $PAD "<empty>" ""              "Ask AI to group commits in range and rebase interactively"
    print_help_row $PAD "preview" "p, dry, show"  "Show the AI plan without rewriting history"
    print_help_row $PAD "yes"     "y, fast"       "Skip the confirmation prompt and apply the plan"
    print_help_row $PAD "push"    "ps"            "After rebase, force-push with ${BLUE}--force-with-lease${ENDCOLOR}"
    print_help_row $PAD "help"    "h"             "Show this help"
    echo
    echo -e "${YELLOW}Range${ENDCOLOR}"
    echo -e "  ${BLUE}•${ENDCOLOR} On ${BOLD}${main_branch}${NORMAL}: commits since the last tag (or root if none)"
    echo -e "  ${BLUE}•${ENDCOLOR} On any other branch: commits since the merge-base with ${BOLD}${main_branch}${NORMAL}"
    echo
    echo -e "${YELLOW}Recovery${ENDCOLOR}"
    echo -e "  ${BLUE}•${ENDCOLOR} If the result is wrong, run ${BOLD}gitb undo rebase${NORMAL} to restore the original branch"
    echo
    echo -e "${YELLOW}Examples${ENDCOLOR}"
    echo -e "  ${GREEN}gitb squash${ENDCOLOR}           Group commits with AI and rebase interactively"
    echo -e "  ${GREEN}gitb squash preview${ENDCOLOR}   See the AI plan without rewriting history"
    echo -e "  ${GREEN}gitb squash yes${ENDCOLOR}       Apply the plan without confirming"
    echo -e "  ${GREEN}gitb squash push${ENDCOLOR}      Apply, then force-push the rewritten branch"
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

    # Use --porcelain (locale-stable, machine-readable) rather than parsing
    # the human-readable last line of `git status`, which depends on the
    # user's git locale and on git's exact wording (which has changed across
    # versions).
    if [ -n "$(git status --porcelain)" ]; then
        echo -e "${RED}✗ Cannot squash — there are uncommitted changes:${ENDCOLOR}"
        git status --short | sed 's/^/  /'
        echo
        echo -e "${CYAN}💡 Stash with ${BOLD}gitb wip${NORMAL}${CYAN} (or ${BOLD}git stash${NORMAL}${CYAN}), or commit, then re-run ${BOLD}gitb tidy${NORMAL}${CYAN}.${ENDCOLOR}"
        exit 1
    fi

    if [ -d "$(git rev-parse --git-dir)/rebase-merge" ] || [ -d "$(git rev-parse --git-dir)/rebase-apply" ]; then
        echo -e "${RED}✗ A rebase is already in progress.${ENDCOLOR}"
        echo -e "Resolve it first with ${GREEN}git rebase --abort${ENDCOLOR} or ${GREEN}gitb undo rebase${ENDCOLOR}."
        exit 1
    fi

    ### Resolve range
    local resolved
    resolved=$(squash_resolve_base_ref "")
    if [ -z "$resolved" ]; then
        echo -e "${RED}✗ Cannot determine a base for the squash range.${ENDCOLOR}"
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
        echo -e "${GREEN}✓ Nothing to squash — no commits between ${source_label} (${base_ref::12}) and HEAD${ENDCOLOR}"
        exit 0
    fi

    local commit_count
    commit_count=$(printf '%s\n' "$commit_hashes_full" | grep -c .)

    if [ "$commit_count" -lt 2 ]; then
        echo -e "${GREEN}✓ Nothing to squash — only ${commit_count} commit in range${ENDCOLOR}"
        exit 0
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
    git --no-pager log --color=always --reverse --format='  %C(yellow)%h%C(reset) (%C(blue)%cr%C(reset)) %s' "${base_ref}..HEAD"
    echo

    ### Confirm before paying for the AI call (skip in --yes mode)
    if [ -z "$mode_yes" ]; then
        local size_warning=""
        if [ "$commit_count" -gt "$SQUASH_MAX_COMMITS" ]; then
            size_warning=" ${RED}(large — model accuracy may degrade above ~${SQUASH_MAX_COMMITS} commits)${ENDCOLOR}"
        fi
        echo -e "${YELLOW}Will analyze ${BOLD}${commit_count}${NORMAL}${YELLOW} commits with AI.${ENDCOLOR}${size_warning}"
        echo -e "Continue (y/n)?"
        local pre_choice
        read -n 1 -s pre_choice
        if ! is_yes "$pre_choice"; then
            echo
            echo -e "${YELLOW}Cancelled.${ENDCOLOR}"
            exit 0
        fi
        echo
    fi

    ### Ask the AI — chunked for large ranges, single-call otherwise.
    if ! squash_run_ai_grouping "$commit_hashes_full" "$expected_short_hashes"; then
        echo -e "${RED}✗ Cannot parse the AI plan.${ENDCOLOR}"
        if [ -n "${squash_parse_error:-}" ]; then
            echo -e "${YELLOW}Reason:${ENDCOLOR} ${squash_parse_error}"
        fi
        if [ -n "${squash_last_ai_response:-}" ]; then
            local dump_file
            # Explicit `${TMPDIR:-/tmp}/...XXXXXX` form so mktemp behaves the
            # same on BSD (macOS) and GNU; `mktemp -t prefix` differs across
            # those two and produced odd filenames on macOS.
            dump_file=$(mktemp "${TMPDIR:-/tmp}/gitb-tidy-response.XXXXXX" 2>/dev/null) || dump_file="${TMPDIR:-/tmp}/gitb-tidy-response.$$"
            chmod 600 "$dump_file" 2>/dev/null || true
            printf '%s\n' "$squash_last_ai_response" > "$dump_file"
            local total_lines
            total_lines=$(printf '%s\n' "$squash_last_ai_response" | wc -l | tr -d ' ')
            echo -e "${YELLOW}Last response (${total_lines} lines) saved to:${ENDCOLOR} ${dump_file}"
            echo -e "${YELLOW}Response preview (first 20 lines):${ENDCOLOR}"
            printf '%s\n' "$squash_last_ai_response" | head -n 20
            if [ "$total_lines" -gt 20 ]; then
                echo -e "${GRAY}...${ENDCOLOR}"
                echo -e "${YELLOW}Response tail (last 10 lines):${ENDCOLOR}"
                printf '%s\n' "$squash_last_ai_response" | tail -n 10
            fi
        fi
        exit 1
    fi

    echo
    if [ "$squash_group_count" -ge "$commit_count" ]; then
        echo -e "${GREEN}✓ AI found no groups to merge — every commit stays as its own change.${ENDCOLOR}"
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
        echo -e "${RED}⚠  Applying this plan rewrites your commit history.${ENDCOLOR}"
        echo -e "${CYAN}💡 Recover the original branch with ${BOLD}gitb undo rebase${NORMAL}${CYAN} if needed.${ENDCOLOR}"
        echo -e "Are you sure you want to proceed (y/n)?"
        local choice
        read -n 1 -s choice
        if ! is_yes "$choice"; then
            echo
            echo -e "${YELLOW}Cancelled.${ENDCOLOR}"
            exit 0
        fi
        echo
    fi

    ### Build todo + message files in a temp dir, then rebase
    local work_dir
    work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gitbasher-squash.XXXXXX") || {
        echo -e "${RED}✗ Cannot create temp directory.${ENDCOLOR}"
        exit 1
    }
    # Always clean up the temp dir, even on failure
    trap 'rm -rf "$work_dir"' EXIT

    local todo_file="${work_dir}/todo"
    squash_write_rebase_todo "$todo_file" "$work_dir"

    # Re-check the working tree right before rebase. The AI calls can take long
    # enough that an editor save or background tool may have dirtied the tree
    # since the initial check at the top of squash_script. git rebase's own
    # error is correct but terse — surface it actionably.
    if [ -n "$(git status --porcelain)" ]; then
        echo -e "${RED}✗ Working tree became dirty during the AI step:${ENDCOLOR}"
        git status --short | sed 's/^/  /'
        echo
        echo -e "${CYAN}💡 Stash with ${BOLD}gitb wip${NORMAL}${CYAN} (or ${BOLD}git stash${NORMAL}${CYAN}), or commit, then re-run ${BOLD}gitb tidy${NORMAL}${CYAN}.${ENDCOLOR}"
        exit 1
    fi

    echo -e "${YELLOW}Rebasing...${ENDCOLOR}"
    if ! squash_run_rebase "$base_ref" "$todo_file"; then
        echo -e "${RED}✗ Squash failed — your branch was restored.${ENDCOLOR}"
        exit 1
    fi

    echo
    echo -e "${GREEN}✓ Squashed${ENDCOLOR}"
    echo -e "${YELLOW}New history:${ENDCOLOR}"
    git --no-pager log --color=always --reverse --format='  %C(yellow)%h%C(reset) (%C(blue)%cr%C(reset)) %s' "${base_ref}..HEAD"
    echo

    ### Optional force-push
    if [ -n "$mode_push" ]; then
        echo -e "${YELLOW}Force-pushing with --force-with-lease...${ENDCOLOR}"
        local push_output push_code
        push_output=$(git push --force-with-lease -u "$origin_name" "$current_branch" 2>&1)
        push_code=$?
        if [ "$push_code" -eq 0 ]; then
            echo -e "${GREEN}✓ Pushed${ENDCOLOR}"
            echo "$push_output" | tail -n 5
        else
            echo -e "${RED}✗ Push failed.${ENDCOLOR}"
            echo "$push_output"
            exit "$push_code"
        fi
    else
        echo -e "${GRAY}History is rewritten locally.${ENDCOLOR} Push it with ${YELLOW}gitb push force${ENDCOLOR} (or ${YELLOW}gitb squash push${ENDCOLOR} next time to chain)."
    fi
}
