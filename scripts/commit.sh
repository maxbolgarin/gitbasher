#!/usr/bin/env bash

### Script for creating commits in angular style (conventional commits)
# Read README.md to get more information how to use it
# Use this script only with gitbasher


### Function to cleanup staged files and git add cache
# $1: git_add arguments
function cleanup_on_exit {
    if [ -n "$1" ]; then
        # Word-splitting on $1 is intentional: it may hold multiple space-separated paths
        # from `git add`. Use a subshell with `set -f` so globbing cannot silently expand
        # patterns against CWD, and `--` so paths starting with `-` are not parsed as options.
        ( set -f; git restore --staged -- $1 2>/dev/null )
    fi
}

### Print git warning/hint output through gitbasher colors.
# $1: captured git output
function print_git_warning_output {
    local git_output="$1"
    [ -z "$git_output" ] && return 0

    local line
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        case "$line" in
            warning:*)
                echo -e "${YELLOW}${line}${ENDCOLOR}"
                ;;
            hint:*)
                echo -e "${CYAN}${line}${ENDCOLOR}"
                ;;
            *)
                echo "$line"
                ;;
        esac
    done <<< "$git_output"
}

### Remove embedded repositories picked up by automatic fast-mode staging.
# Manual git add selections are intentionally not filtered.
function unstage_embedded_repositories_from_fast_add {
    local staged_files
    staged_files=$(git -c core.quotePath=false diff --name-only --cached)
    [ -z "$staged_files" ] && return 0

    local file
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        if [ -d "$file" ] && [ -e "$file/.git" ]; then
            git restore --staged -- "$file" >/dev/null 2>&1
            echo -e "${YELLOW}⚠  Skipped embedded git repository in fast mode: ${file}${ENDCOLOR}"
            echo -e "${CYAN}💡 Select it manually if you really want to commit it.${ENDCOLOR}"
        fi
    done <<< "$staged_files"
}

### Stage all changes for fast modes without keeping embedded repositories.
function stage_fast_changes {
    local result
    result=$(git add . 2>&1)
    local code=$?

    print_git_warning_output "$result"
    [ $code -ne 0 ] && return $code

    unstage_embedded_repositories_from_fast_add
    return 0
}

### Function to detect scopes from staged files
# Returns: detected_scopes variable set with space-separated scope names
function detect_scopes_from_staged_files {
    detected_scopes=""
    local staged_files=$(git -c core.quotePath=false diff --name-only --cached)

    # Limit the number of files to process for scope detection (performance)
    local max_files_for_scopes=100
    local total_files=$(echo "$staged_files" | wc -l | tr -d ' ')
    if [ "$total_files" -gt "$max_files_for_scopes" ]; then
        staged_files=$(echo "$staged_files" | head -n "$max_files_for_scopes")
    fi

    if [ -n "$staged_files" ]; then
        # Count occurrences of each path token with depth tracking
        local -A scope_counts
        local -A scope_depths
        
        # Only directory components contribute to scope candidates — filenames
        # are skipped so single root-level files (README.md, package.json, etc.)
        # don't generate noisy one-off scopes. Root files end up in the "misc"
        # group during atomic-split commits.
        while IFS= read -r file; do
            if [ -n "$file" ]; then
                IFS='/' read -r -a path_components <<< "$file"
                local last_idx=$((${#path_components[@]} - 1))

                for i in "${!path_components[@]}"; do
                    [ "$i" -eq "$last_idx" ] && continue
                    component="${path_components[$i]}"
                    [ -z "$component" ] && continue

                    component_lower="${component,,}"
                    # Filter out generic containers and dependency/output dirs
                    # that are rarely meaningful as a per-commit scope.
                    if [[ "$component_lower" =~ ^(src|lib|node_modules|vendor|tmp|temp|cache|logs|log)$ ]]; then
                        continue
                    fi

                    scope_counts["$component_lower"]=$((${scope_counts["$component_lower"]:-0} + 1))
                    current_depth=$((i + 1))
                    if [ -z "${scope_depths["$component_lower"]}" ] || [ $current_depth -lt ${scope_depths["$component_lower"]} ]; then
                        scope_depths["$component_lower"]=$current_depth
                    fi
                done
            fi
        done <<< "$staged_files"
        
        # Find maximum count to determine if we should filter out count=1 tokens
        max_count=0
        for token in "${!scope_counts[@]}"; do
            if [ ${scope_counts["$token"]} -gt $max_count ]; then
                max_count=${scope_counts["$token"]}
            fi
        done
        
        # Count total unique tokens
        total_unique_tokens=${#scope_counts[@]}
        
        # Collect and sort scopes
        detected_scopes_array=()
        for token in "${!scope_counts[@]}"; do
            count=${scope_counts["$token"]}
            depth=${scope_depths["$token"]}
            
            # Apply count filter
            # If we have few unique tokens (≤ 7), include all regardless of count
            # If we have many tokens and max_count > 1, only include tokens with count > 1
            if [ $total_unique_tokens -le 7 ]; then
                # Include all tokens when we have few unique ones
                detected_scopes_array+=("$count:$depth:$token")
            elif [ $max_count -gt 1 ]; then
                if [ $count -gt 1 ]; then
                    # Format: count:depth:token for sorting
                    detected_scopes_array+=("$count:$depth:$token")
                fi
            else
                # If all tokens have count=1, include all
                detected_scopes_array+=("$count:$depth:$token")
            fi
        done
        
        # Sort by count (descending), then by depth (ascending), then by token name
        if [ ${#detected_scopes_array[@]} -gt 0 ]; then
            # Separate filename tokens from directory tokens for better sorting
            filename_entries=()
            directory_entries=()
            
            for entry in "${detected_scopes_array[@]}"; do
                count="${entry%%:*}"  # Extract count (first field)
                rest="${entry#*:}"    # Remove count
                depth="${rest%%:*}"   # Extract depth (second field)
                token="${rest#*:}"    # Extract token (third field)
                
                # Check if this token came from a filename (higher depth usually means filename)
                # We'll put filename tokens first, then directories by ascending depth
                if [ $depth -ge 4 ]; then  # Assume depth 4+ are likely filenames
                    filename_entries+=("$entry")
                else
                    directory_entries+=("$entry")
                fi
            done
            
            # Sort filenames by count (desc), then depth (asc), then name
            IFS=$'\n' filename_sorted=($(printf '%s\n' "${filename_entries[@]}" | sort -t':' -k1,1nr -k2,2n -k3,3))
            unset IFS
            
            # Sort directories by count (desc), then depth (asc), then name  
            IFS=$'\n' directory_sorted=($(printf '%s\n' "${directory_entries[@]}" | sort -t':' -k1,1nr -k2,2n -k3,3))
            unset IFS
            
            # Combine: filenames first, then directories
            detected_scopes_sorted=("${filename_sorted[@]}" "${directory_sorted[@]}")
            
            # Extract just the token names for the final result (limit to 9 scopes)
            final_scopes=()
            count=0
            for entry in "${detected_scopes_sorted[@]}"; do
                if [ $count -ge 9 ]; then
                    break
                fi
                token="${entry##*:}"  # Extract token after last colon
                final_scopes+=("$token")
                count=$((count + 1))
            done
            
            detected_scopes="${final_scopes[*]}"
        fi
    fi
}

### Function to map staged files to detected scopes (for atomic-split commits)
# Each file is assigned to the FIRST detected scope that matches one of its path
# components (top-level wins for changelog clarity). Files matching no detected
# scope land in the "misc" group and will be committed without a scope.
# Sets globals (declared with -gA so callers can iterate after the function returns):
#   - split_groups:     associative array, scope -> newline-separated file list
#   - split_group_keys: ordered array of scope names actually used
# Returns 0 if 2+ groups were produced (split is meaningful), 1 otherwise.
function build_split_groups_from_staged {
    detect_scopes_from_staged_files

    # Re-declare globals fresh on each call
    unset split_groups split_group_keys
    declare -gA split_groups=()
    split_group_keys=()

    if [ -z "$detected_scopes" ]; then
        return 1
    fi

    local -a scopes_arr
    IFS=' ' read -r -a scopes_arr <<< "$detected_scopes"

    local staged_files
    staged_files=$(git -c core.quotePath=false diff --name-only --cached)
    [ -z "$staged_files" ] && return 1

    local file scope comp comp_lower comp_no_ext_lower assigned
    local -a comps

    while IFS= read -r file; do
        [ -z "$file" ] && continue

        assigned=""
        IFS='/' read -r -a comps <<< "$file"

        # Walk detected scopes in priority order; first match wins.
        for scope in "${scopes_arr[@]}"; do
            for comp in "${comps[@]}"; do
                [ -z "$comp" ] && continue
                comp_lower="${comp,,}"
                comp_no_ext_lower="${comp_lower%.*}"
                [ -z "$comp_no_ext_lower" ] && comp_no_ext_lower="$comp_lower"
                if [ "$comp_lower" = "$scope" ] || [ "$comp_no_ext_lower" = "$scope" ]; then
                    assigned="$scope"
                    break 2
                fi
            done
        done

        [ -z "$assigned" ] && assigned="misc"

        if [ -z "${split_groups[$assigned]:-}" ]; then
            split_group_keys+=("$assigned")
            split_groups[$assigned]="$file"
        else
            split_groups[$assigned]+=$'\n'"$file"
        fi
    done <<< "$staged_files"

    # A split is only meaningful with 2+ groups
    if [ ${#split_group_keys[@]} -lt 2 ]; then
        return 1
    fi
    return 0
}

### Check if the heuristic grouping looks unreliable enough to warrant AI refinement.
# Triggers when:
#   - 1 group but staged files span 2+ second-level subdirs (e.g. service/auth, service/api)
#     — the top-level dir won as scope, masking the real per-feature subdivisions
#   - one group dominates with >70% of files (and there are 4+ files total) —
#     suggests the dominant scope is a generic container rather than a real feature
# Returns 0 (true) if weak, 1 (false) if heuristic looks fine.
function is_heuristic_weak {
    local total
    total=$(git -c core.quotePath=false diff --name-only --cached | grep -c .)
    [ "$total" -lt 4 ] && return 1

    if [ ${#split_group_keys[@]} -le 1 ]; then
        # Only consider files at depth ≥ 3 (e.g. service/auth/login.go) — shallow
        # files like auth/file1.go don't have a sub-scope to discover, so
        # counting them would produce false weakness signals.
        local subdir_count
        subdir_count=$(git -c core.quotePath=false diff --name-only --cached | LC_ALL=C awk -F/ 'NF>=3 {print $1"/"$2}' | sort -u | grep -c .)
        [ "$subdir_count" -ge 2 ] && return 0
        return 1
    fi

    local max_size=0 n
    local s
    for s in "${split_group_keys[@]}"; do
        n=$(printf '%s\n' "${split_groups[$s]}" | grep -c .)
        [ "$n" -gt "$max_size" ] && max_size="$n"
    done
    local pct=$((max_size * 100 / total))
    [ "$pct" -gt 70 ] && return 0
    return 1
}

### Use AI to refine the file→scope grouping when the heuristic looks weak.
# Sends the staged file list, diff summary, recent commit messages (for codebase
# scope conventions), and the heuristic's candidate scopes to the model. Expects
# back a TSV "<scope>\t<file>" — one line per staged file. Validates the output:
# every staged file must be assigned exactly once and scope names must be safe.
# On success, overwrites split_groups / split_group_keys with the AI grouping.
# Returns 0 on success, 1 on AI failure or unparseable output (caller falls back).
function refine_groups_with_ai {
    local staged_files
    staged_files=$(git -c core.quotePath=false diff --name-only --cached)
    [ -z "$staged_files" ] && return 1

    local diff_stat recent_commits
    diff_stat=$(get_limited_diff_stat_for_ai)
    recent_commits=$(get_recent_commit_messages_for_ai)

    local heuristic_hint=""
    if [ -n "$detected_scopes" ]; then
        heuristic_hint="$detected_scopes"
    fi

    local system_prompt='You group staged git files into logical scopes for atomic commits.

Input arrives in XML tags: a list of staged files, a diff summary, recent commit messages (for codebase scope conventions), and heuristic-detected candidate scope tokens.

Task: assign EVERY staged file to a single scope. Use 2-5 groups when there is meaningful separation; use exactly 1 group only if all files truly belong together. Use lowercase scope names that match the style of <recent_commits>. Prefer scope names from <heuristic_candidates> when they fit the file path or change; invent new ones only when none of the candidates apply. Use "misc" for files with no clear scope (e.g., README, top-level config).

Output format: TSV only. One line per staged file in the form <scope><TAB><file_path>. No header, no prose, no markdown fences, no surrounding quotes. Every file from <staged_files> MUST appear exactly once. The file paths must be byte-identical to those in <staged_files>.'

    local user_prompt="<recent_commits>
${recent_commits}
</recent_commits>

<staged_files>
${staged_files}
</staged_files>

<diff_summary>
${diff_stat}
</diff_summary>

<heuristic_candidates>
${heuristic_hint}
</heuristic_candidates>

Output TSV (scope<TAB>file) for every staged file. No prose."

    local ai_response
    ai_response=$(call_ai_api "$system_prompt" "$user_prompt" "$AI_MAX_TOKENS_FULL" "$(get_ai_model_for grouping)" 2>/dev/null)
    if [ $? -ne 0 ] || [ -z "$ai_response" ]; then
        return 1
    fi

    # Strip stray markdown fences if the model added them despite instructions
    ai_response=$(printf '%s' "$ai_response" | LC_ALL=C sed -e 's/^```[a-zA-Z]*$//' -e 's/^```$//')

    # Build a set of expected staged files for validation
    local -A staged_set=()
    while IFS= read -r f; do
        [ -n "$f" ] && staged_set["$f"]=1
    done <<< "$staged_files"

    local -A new_groups=()
    local -a new_keys=()
    local line scope file tab_count
    local tab=$'\t'

    while IFS= read -r line; do
        # Trim leading/trailing whitespace
        line=$(printf '%s' "$line" | LC_ALL=C sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        [ -z "$line" ] && continue

        # Require exactly one tab so scope/file are unambiguous
        tab_count=$(printf '%s' "$line" | LC_ALL=C tr -cd "$tab" | wc -c | tr -d ' ')
        [ "$tab_count" -ne 1 ] && continue

        scope="${line%%	*}"
        file="${line#*	}"

        # Validate scope characters (same charset as sanitize_git_name)
        if ! [[ "$scope" =~ ^[a-zA-Z0-9._/-]+$ ]]; then
            continue
        fi
        scope=$(printf '%s' "$scope" | LC_ALL=C tr '[:upper:]' '[:lower:]')

        # Reject files the model invented or paraphrased
        [ -z "${staged_set[$file]:-}" ] && continue

        if [ -z "${new_groups[$scope]:-}" ]; then
            new_keys+=("$scope")
            new_groups[$scope]="$file"
        else
            new_groups[$scope]+=$'\n'"$file"
        fi
    done <<< "$ai_response"

    # Every staged file must be covered — partial output means we fall back
    local total_assigned=0 total_staged
    local key
    for key in "${new_keys[@]}"; do
        total_assigned=$((total_assigned + $(printf '%s\n' "${new_groups[$key]}" | grep -c .)))
    done
    total_staged=$(printf '%s\n' "$staged_files" | grep -c .)
    if [ "$total_assigned" -ne "$total_staged" ] || [ ${#new_keys[@]} -lt 1 ]; then
        return 1
    fi

    # Replace globals with AI grouping
    unset split_groups split_group_keys
    declare -gA split_groups
    split_group_keys=()
    for key in "${new_keys[@]}"; do
        split_groups[$key]="${new_groups[$key]}"
        split_group_keys+=("$key")
    done

    return 0
}

### Restore the original staging snapshot (used when user aborts mid-split).
# Best-effort: re-stages every file that was originally staged. Files that
# were already committed earlier in the split loop are silently skipped by
# `git add` (no diff vs HEAD). Already-made commits are preserved as-is —
# the user can `git reset --soft HEAD~N` if they want to undo them.
# $1: snapshot file path (one filename per line)
function _restore_split_snapshot {
    local snapshot="$1"
    [ -f "$snapshot" ] || return

    # First, unstage anything currently staged so we start from a clean slate
    local currently_staged
    currently_staged=$(git -c core.quotePath=false diff --name-only --cached)
    if [ -n "$currently_staged" ]; then
        while IFS= read -r f; do
            [ -n "$f" ] && git restore --staged -- "$f" >/dev/null 2>&1
        done <<< "$currently_staged"
    fi

    # Re-stage every file from the snapshot that still exists / has changes
    while IFS= read -r f; do
        [ -n "$f" ] && git add -- "$f" >/dev/null 2>&1
    done < "$snapshot"

    rm -f "$snapshot"
}

function print_split_type_menu {
    local scope="$1"
    local ai_available="$2"

    echo -e "${YELLOW}What type of changes for ${BLUE}${BOLD}${scope}${ENDCOLOR}${YELLOW}?${ENDCOLOR}"
    echo -e "Final message will be ${YELLOW}<type>${ENDCOLOR}(${BLUE}<scope>${ENDCOLOR}): ${BLUE}<summary>${ENDCOLOR}"
    echo -e "1. ${BOLD}feat${ENDCOLOR}:\tnew feature, logic change or performance improvement"
    echo -e "2. ${BOLD}fix${ENDCOLOR}:\t\tsmall changes, eg. bug fix"
    echo -e "3. ${BOLD}refactor${ENDCOLOR}:\tcode change that neither fixes a bug nor adds a feature, style changes"
    echo -e "4. ${BOLD}test${ENDCOLOR}:\tadding missing tests or changing existing tests"
    echo -e "5. ${BOLD}build${ENDCOLOR}:\tchanges that affect the build system or external dependencies"
    echo -e "6. ${BOLD}ci${ENDCOLOR}:\t\tchanges to CI configuration files and scripts"
    echo -e "7. ${BOLD}chore${ENDCOLOR}:\tmaintenance and housekeeping"
    echo -e "8. ${BOLD}docs${ENDCOLOR}:\tdocumentation changes"
    echo -e "9. ${BLUE}${BOLD}plain${ENDCOLOR}:\twrite plain commit without type and scope"
    if [ "$ai_available" = "true" ]; then
        echo -e "g. ${GREEN}${BOLD}ai${ENDCOLOR}:\t\tgenerate commit message using AI"
    fi
    echo -e "s. ${YELLOW}${BOLD}skip${ENDCOLOR}:\tSkip this group and leave its files unstaged"
    echo -e "0. ${RED}${BOLD}abort${ENDCOLOR}:\tAbort split and restore original staging"
    echo
}

function print_commit_type_menu {
    local step="$1"
    local ai_available="$2"

    echo -e "${YELLOW}Step ${step}.${ENDCOLOR} What ${YELLOW}type${ENDCOLOR} of changes do you want to commit?"
    echo -e "Final message will be ${YELLOW}<type>${ENDCOLOR}(${BLUE}<scope>${ENDCOLOR}): ${BLUE}<summary>${ENDCOLOR}"
    echo -e "1. ${BOLD}feat${ENDCOLOR}:\tnew feature, logic change or performance improvement"
    echo -e "2. ${BOLD}fix${ENDCOLOR}:\t\tsmall changes, eg. bug fix"
    echo -e "3. ${BOLD}refactor${ENDCOLOR}:\tcode change that neither fixes a bug nor adds a feature, style changes"
    echo -e "4. ${BOLD}test${ENDCOLOR}:\tadding missing tests or changing existing tests"
    echo -e "5. ${BOLD}build${ENDCOLOR}:\tchanges that affect the build system or external dependencies"
    echo -e "6. ${BOLD}ci${ENDCOLOR}:\t\tchanges to CI configuration files and scripts"
    echo -e "7. ${BOLD}chore${ENDCOLOR}:\tmaintenance and housekeeping"
    echo -e "8. ${BOLD}docs${ENDCOLOR}:\tdocumentation changes"
    echo -e "9. ${BLUE}${BOLD}plain${ENDCOLOR}:\twrite plain commit without type and scope"
    if [ "$ai_available" = "true" ]; then
        echo -e "g. ${GREEN}${BOLD}ai${ENDCOLOR}:\t\tgenerate commit message using AI"
    fi
    echo -e "0. ${RED}${BOLD}exit${ENDCOLOR}:\tExit without changes"
}

function print_split_groups_preview {
    local -A staged_status_by_file=()
    local staged_diff status file new_file
    staged_diff=$(git -c core.quotePath=false diff --name-status --cached)
    while IFS=$'\t' read -r status file new_file; do
        [ -z "$file" ] && continue
        if [[ "$status" == R* || "$status" == C* ]]; then
            [ -n "$new_file" ] && file="$new_file"
        fi
        staged_status_by_file["$file"]="${status:0:1}"
    done <<< "$staged_diff"

    echo -e "${YELLOW}Detected changes across ${#split_group_keys[@]} scopes:${ENDCOLOR}"
    local scope file_count file_color staged_status
    for scope in "${split_group_keys[@]}"; do
        file_count=$(printf '%s\n' "${split_groups[$scope]}" | grep -c .)
        echo -e "  ${BLUE}${BOLD}${scope}${ENDCOLOR} ${GRAY}(${file_count} file(s))${ENDCOLOR}:"
        while IFS= read -r file; do
            [ -z "$file" ] && continue
            staged_status="${staged_status_by_file[$file]}"
            case "$staged_status" in
                A) file_color="$GREEN" ;;
                M) file_color="$YELLOW" ;;
                D) file_color="$RED" ;;
                *) file_color="$GRAY" ;;
            esac
            echo -e "    ${file_color}${file}${ENDCOLOR}"
        done <<< "${split_groups[$scope]}"
    done
}

### Run the AI generate / confirm / regenerate / edit loop for one split scope.
# Used both when the user invoked AI mode up-front (llm flag) and when they
# pick 'g' from the per-scope type menu.
# Sets the caller's $msg variable on success (relies on bash dynamic scoping).
# $1: scope label (used in messages), $2: scope_for_msg (empty -> no scope),
# $3: files_str (newline-separated; used to unstage on skip)
# Returns: 0 success, 1 AI failed/declined, 2 skip scope, 3 abort split
function run_split_ai_for_scope {
    local _scope="$1"
    local _scope_for_msg="$2"
    local _files_str="$3"
    local ai_msg choice manual_input
    local rejected_ai_messages=""

    msg=""

    echo -e "${YELLOW}Generating commit message with AI...${ENDCOLOR}"
    ai_msg=$(generate_ai_commit_message "simple" "$_scope_for_msg" "$_scope_for_msg" "")
    if [ $? -ne 0 ] || [ -z "$ai_msg" ]; then
        echo -e "${RED}✗ AI message generation failed.${ENDCOLOR}"
        return 1
    fi
    ai_msg=$(echo "$ai_msg" | LC_ALL=C sed 's/^"//;s/"$//' | LC_ALL=C sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

    if [ -n "$auto_accept" ]; then
        msg="$ai_msg"
        echo -e "${GREEN}AI message:${ENDCOLOR} ${BOLD}$ai_msg${ENDCOLOR}"
        return 0
    fi

    echo
    echo -e "${GREEN}AI suggestion:${ENDCOLOR} ${BOLD}$ai_msg${ENDCOLOR}"
    echo
    read_key choice "Use it? (y/e to edit/r to regenerate/s to skip group/0 to abort) "
    echo
    normalize_key "$choice"

    while [ "$normalized_key" = "r" ]; do
        echo -e "${YELLOW}Regenerating...${ENDCOLOR}"
        if [ -n "$rejected_ai_messages" ]; then
            rejected_ai_messages="${rejected_ai_messages}
${ai_msg}"
        else
            rejected_ai_messages="$ai_msg"
        fi
        ai_msg=$(generate_ai_commit_message "simple" "$_scope_for_msg" "$_scope_for_msg" "" "$rejected_ai_messages")
        if [ $? -ne 0 ] || [ -z "$ai_msg" ]; then
            echo -e "${RED}✗ AI message regeneration failed.${ENDCOLOR}"
            return 1
        fi
        ai_msg=$(echo "$ai_msg" | LC_ALL=C sed 's/^"//;s/"$//' | LC_ALL=C sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        echo
        echo -e "${GREEN}AI suggestion:${ENDCOLOR} ${BOLD}$ai_msg${ENDCOLOR}"
        echo
        read_key choice "Use it? (y/e to edit/r to regenerate/s to skip group/0 to abort) "
        echo
        normalize_key "$choice"
    done

    if [ "$normalized_key" = "y" ] || [ -z "$choice" ]; then
        msg="$ai_msg"
        return 0
    elif [ "$normalized_key" = "e" ]; then
        read_editable_input manual_input "Edit: " "$ai_msg"
        msg="$manual_input"
        return 0
    elif [ "$normalized_key" = "s" ]; then
        echo -e "${YELLOW}Skipping scope '${_scope}' (files left unstaged)${ENDCOLOR}"
        while IFS= read -r f; do
            [ -n "$f" ] && git restore --staged -- "$f" >/dev/null 2>&1
        done <<< "$_files_str"
        return 2
    elif [ "$choice" = "0" ]; then
        return 3
    fi
    return 1
}

### Walk the split groups, generate a message per group (AI when available),
### and create one commit per group. Restores staging on abort.
# Globals consumed: split_groups, split_group_keys, push, current_branch
# Exits the script on success (entire commit flow handled).
# Returns 1 (and restores staging) on failure so caller can fall through.
function perform_commit_split {
    local original_staged
    original_staged=$(git -c core.quotePath=false diff --name-only --cached)
    if [ -z "$original_staged" ]; then
        echo -e "${RED}✗ No staged files to split.${ENDCOLOR}"
        return 1
    fi

    local snapshot_file
    snapshot_file=$(mktemp "${TMPDIR:-/tmp}/gitb-split-snapshot.XXXXXX")
    chmod 600 "$snapshot_file" 2>/dev/null || true
    printf '%s\n' "$original_staged" > "$snapshot_file"
    # Restore staging if the user kills the process mid-split
    trap "_restore_split_snapshot '$snapshot_file'" INT TERM

    local total=${#split_group_keys[@]}
    local idx=0
    local commit_count=0
    local -a commit_hashes=()
    local -a commit_headers=()
    local ai_ok="true"
    if ! check_ai_available 2>/dev/null; then
        ai_ok="false"
    fi

    local scope files_str msg ai_msg choice scope_for_msg prefix manual_input
    local -a files_array

    for scope in "${split_group_keys[@]}"; do
        idx=$((idx + 1))
        echo
        echo -e "${CYAN}──${ENDCOLOR} ${BOLD}Split commit ${idx}/${total}${ENDCOLOR} ${GRAY}·${ENDCOLOR} scope ${BLUE}${BOLD}${scope}${ENDCOLOR} ${CYAN}──${ENDCOLOR}"

        # Reset everything that's currently staged, then stage only this group
        local currently_staged
        currently_staged=$(git -c core.quotePath=false diff --name-only --cached)
        if [ -n "$currently_staged" ]; then
            while IFS= read -r f; do
                [ -n "$f" ] && git restore --staged -- "$f" >/dev/null 2>&1
            done <<< "$currently_staged"
        fi

        files_str="${split_groups[$scope]}"
        files_array=()
        while IFS= read -r f; do
            [ -n "$f" ] && files_array+=("$f")
        done <<< "$files_str"

        if [ ${#files_array[@]} -eq 0 ]; then
            echo -e "${YELLOW}No files in this group, skipping.${ENDCOLOR}"
            continue
        fi

        if ! git add -- "${files_array[@]}"; then
            echo -e "${RED}✗ Cannot stage files for scope '${scope}'.${ENDCOLOR}"
            _restore_split_snapshot "$snapshot_file"
            trap - INT TERM
            return 1
        fi

        echo -e "${YELLOW}Files in this commit:${ENDCOLOR}"
        print_staged_files

        scope_for_msg="$scope"

        msg=""

        # AI path — only when the user explicitly asked for AI (llm flag set
        # by ai/aisplit/aif/ff/etc). Without llm, we go straight to manual.
        if [ -n "$llm" ] && [ "$ai_ok" = "true" ]; then
            echo
            run_split_ai_for_scope "$scope" "$scope_for_msg" "$files_str"
            case $? in
                2) continue ;;
                3)
                    _restore_split_snapshot "$snapshot_file"
                    trap - INT TERM
                    echo
                    echo -e "${YELLOW}Aborted. Created ${commit_count} commit(s); original staging restored.${ENDCOLOR}"
                    exit 0
                    ;;
            esac
        fi

        # Auto-accept can't fall back to a prompt — fail loudly when AI didn't deliver
        if [ -z "$msg" ] && [ -n "$auto_accept" ]; then
            echo -e "${RED}✗ AI message generation failed — auto-accept mode cannot prompt for a manual message.${ENDCOLOR}"
            echo -e "${YELLOW}Configure AI (gitb cfg ai) or use a non-ff mode.${ENDCOLOR}"
            _restore_split_snapshot "$snapshot_file"
            trap - INT TERM
            return 1
        fi

        # Manual path: type selection + summary, mirroring the regular commit flow.
        # Reached when llm wasn't set, or when AI failed/declined in interactive mode.
        if [ -z "$msg" ]; then
            local commit_type=""
            local is_empty_msg=""
            echo
            print_split_type_menu "$scope" "$ai_ok"

            local tchoice
            while true; do
                read_key tchoice
                if ! sanitize_choice_input "$tchoice" "^[0-9sg]$"; then
                    continue
                fi
                tchoice="$sanitized_choice"
                case "$tchoice" in
                    1) commit_type="feat"; break ;;
                    2) commit_type="fix"; break ;;
                    3) commit_type="refactor"; break ;;
                    4) commit_type="test"; break ;;
                    5) commit_type="build"; break ;;
                    6) commit_type="ci"; break ;;
                    7) commit_type="chore"; break ;;
                    8) commit_type="docs"; break ;;
                    9) is_empty_msg="true"; break ;;
                    g)
                        if [ "$ai_ok" != "true" ]; then
                            continue
                        fi
                        run_split_ai_for_scope "$scope" "$scope_for_msg" "$files_str"
                        case $? in
                            0) break ;;
                            2) continue 2 ;;
                            3)
                                _restore_split_snapshot "$snapshot_file"
                                trap - INT TERM
                                echo
                                echo -e "${YELLOW}Aborted. Created ${commit_count} commit(s); original staging restored.${ENDCOLOR}"
                                exit 0
                                ;;
                            *)
                                echo
                                print_split_type_menu "$scope" "$ai_ok"
                                ;;
                        esac
                        ;;
                    s)
                        echo -e "${YELLOW}Skipping scope '${scope}' (files left unstaged)${ENDCOLOR}"
                        while IFS= read -r f; do
                            [ -n "$f" ] && git restore --staged -- "$f" >/dev/null 2>&1
                        done <<< "$files_str"
                        continue 2
                        ;;
                    0)
                        _restore_split_snapshot "$snapshot_file"
                        trap - INT TERM
                        echo
                        echo -e "${YELLOW}Aborted. Created ${commit_count} commit(s); original staging restored.${ENDCOLOR}"
                        exit 0
                        ;;
                esac
            done

            if [ -z "$msg" ]; then
                prefix=""
                if [ -z "$is_empty_msg" ]; then
                    if [ -n "$scope_for_msg" ]; then
                        prefix="${commit_type}(${scope_for_msg}): "
                    else
                        prefix="${commit_type}: "
                    fi
                fi

                echo -e "${YELLOW}Write a summary (Enter to skip group):${ENDCOLOR}"
                read_editable_input manual_input "$prefix"
                if [ -z "$manual_input" ]; then
                    echo -e "${YELLOW}Skipping scope '${scope}'${ENDCOLOR}"
                    while IFS= read -r f; do
                        [ -n "$f" ] && git restore --staged -- "$f" >/dev/null 2>&1
                    done <<< "$files_str"
                    continue
                fi
                if ! sanitize_commit_message "$manual_input"; then
                    show_sanitization_error "commit message" "Use printable characters only, 1-2000 characters."
                    _restore_split_snapshot "$snapshot_file"
                    trap - INT TERM
                    return 1
                fi
                msg="${prefix}${sanitized_commit_message}"
            fi
        fi

        # Make the commit
        local result
        result=$(git commit -m "$msg" 2>&1)
        if [ $? -ne 0 ]; then
            echo -e "${RED}✗ Commit failed:${ENDCOLOR}"
            echo "$result"
            _restore_split_snapshot "$snapshot_file"
            trap - INT TERM
            return 1
        fi

        commit_count=$((commit_count + 1))
        local last_hash
        last_hash=$(git rev-parse --short HEAD)
        commit_hashes+=("$last_hash")
        commit_headers+=("$msg")
        echo -e "${GREEN}✓ Committed${ENDCOLOR} ${BLUE}${last_hash}${ENDCOLOR} ${msg}"
    done

    rm -f "$snapshot_file"
    trap - INT TERM

    # Clean up cached state — split flow handled the entire commit
    git config --unset gitbasher.cached-git-add 2>/dev/null
    git config --unset gitbasher.cached-commit-message 2>/dev/null

    echo
    if [ $commit_count -eq 0 ]; then
        echo -e "${YELLOW}No commits were created.${ENDCOLOR}"
        exit 0
    fi
    echo -e "${GREEN}✓ Created ${commit_count} atomic commit(s) on ${current_branch}:${ENDCOLOR}"
    for i in "${!commit_hashes[@]}"; do
        echo -e "  ${BLUE}${commit_hashes[$i]}${ENDCOLOR} ${commit_headers[$i]}"
    done

    if [ -n "${push}" ]; then
        echo
        push_script y
    fi

    exit 0
}

### Offer to split the staged changes into atomic per-scope commits.
# Skipped silently when:
#   - gitbasher.commit-auto-split = "never"
#   - fewer than 2 distinct scopes are detected (after optional AI refinement)
# Auto-accepts the y/N prompt when:
#   - gitbasher.commit-auto-split = "always"
#   - $1 is non-empty (split mode forced via CLI)
#   - $2 is non-empty (caller is fast/auto-accept and doesn't want to ask)
# When the heuristic grouping looks weak (one dominant group, or a single group
# spanning multiple subdirs), AI refinement is invoked to propose a better
# scope→file mapping. Disable with gitbasher.commit-ai-grouping = "never";
# force always-on with "always".
# Returns to the caller (no exit) when the user declines or the split isn't
# applicable; perform_commit_split exits the script directly on success.
# $1: "true" to force the split flow even when the config says "ask"/"never"
# $2: "true" to skip the y/N prompt and proceed straight to splitting
function try_offer_commit_split {
    local force_split="$1"
    local auto_yes="$2"

    local auto_split
    auto_split=$(get_config_value gitbasher.commit-auto-split "ask")
    if [ "$auto_split" = "never" ] && [ -z "$force_split" ]; then
        return 1
    fi

    # Always run heuristic first — fast and free
    build_split_groups_from_staged
    local heuristic_result=$?

    # Maybe escalate to AI refinement
    local ai_grouping
    ai_grouping=$(get_config_value gitbasher.commit-ai-grouping "auto")
    local should_refine="false"
    case "$ai_grouping" in
        always) should_refine="true" ;;
        never)  should_refine="false" ;;
        *)      # auto: refine only when heuristic is suspect
                if is_heuristic_weak; then
                    should_refine="true"
                fi
                ;;
    esac

    # AI usage is gated on the user's explicit AI intent (llm flag set by
    # ai/aisplit/aif/ff/etc). Non-AI modes (regular commit, fast, split) never
    # call the model — they keep the heuristic grouping as-is.
    if [ -z "$llm" ]; then
        should_refine="false"
    fi

    if [ "$should_refine" = "true" ] && check_ai_available 2>/dev/null; then
        echo
        echo -e "${YELLOW}Refining scope grouping with AI...${ENDCOLOR}"
        if ! refine_groups_with_ai; then
            # AI failed; keep heuristic groups (may be empty)
            echo -e "${YELLOW}AI grouping failed, falling back to heuristic.${ENDCOLOR}"
        fi
    fi

    # After refinement we may finally have ≥2 groups even if heuristic returned 1
    if [ ${#split_group_keys[@]} -lt 2 ]; then
        if [ -n "$force_split" ]; then
            echo -e "${YELLOW}Cannot split: could not identify multiple distinct scopes.${ENDCOLOR}"
        fi
        return 1
    fi

    echo
    print_split_groups_preview
    echo

    local choice
    if [ -n "$force_split" ] || [ -n "$auto_yes" ] || [ "$auto_split" = "always" ]; then
        choice="y"
    else
        read_key choice "Split into ${#split_group_keys[@]} atomic commits for a cleaner changelog? (y/N) "
        echo
    fi

    if ! is_yes "$choice"; then
        return 1
    fi

    perform_commit_split
    return $?
}

### Function to handle AI commit message generation
# $1: step number to display
# $2: ai generation mode ("full", "subject", or "simple")
# $3: commit prefix (for subject mode)
function handle_ai_commit_generation {
    local step="$1"
    local ai_mode="$2"
    local commit_prefix="$3"

    echo
    if [ "$ai_mode" = "full" ]; then
        echo -e "${YELLOW}Step ${step}.${ENDCOLOR} Generating ${YELLOW}multiline commit message${ENDCOLOR} using AI..."
    elif [ "$ai_mode" = "subject" ]; then
        echo -e "${YELLOW}Step ${step}.${ENDCOLOR} Generating ${YELLOW}commit message subject${ENDCOLOR} using AI..."
    else
        echo -e "${YELLOW}Step ${step}.${ENDCOLOR} Generating ${YELLOW}commit message${ENDCOLOR} using AI..."
    fi

    # Check if AI is available
    if ! check_ai_available; then
        cleanup_on_exit "$git_add"
        exit 1
    fi

    # Detect scopes from staged files for AI context
    detect_scopes_from_staged_files

    # Generate / regenerate loop: user can press 'r' to ask the model again with rejected messages included.
    local ai_commit_message choice
    local rejected_ai_messages=""
    while true; do
        ai_commit_message=$(generate_ai_commit_message "$ai_mode" "$detected_scopes" "$scopes" "$commit_prefix" "$rejected_ai_messages")

        if [ $? -ne 0 ] || [ -z "$ai_commit_message" ]; then
            echo
            echo -e "${RED}✗ Cannot generate AI commit message.${ENDCOLOR}"
            cleanup_on_exit "$git_add"
            exit 1
        fi

        # Clean up the AI response (remove quotes, trim)
        # LC_ALL=C avoids "illegal byte sequence" errors from BSD sed when the AI response contains non-ASCII characters.
        ai_commit_message=$(echo "$ai_commit_message" | LC_ALL=C sed 's/^"//;s/"$//' | LC_ALL=C sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

        echo
        echo -e "${GREEN}AI generated commit message:${ENDCOLOR}"
        echo -e "${BOLD}$ai_commit_message${ENDCOLOR}"
        echo

        # Save AI commit message so it can be reused if user exits.
        # It will be cleared only after a successful commit.
        git config gitbasher.cached-commit-message "$ai_commit_message"

        # Auto-accept mode (ff): take the first AI message and skip the prompt
        if [ -n "$auto_accept" ]; then
            choice="y"
            normalized_key="y"
            break
        fi

        read_key choice "Use this commit message? (y/n/r to regenerate/e to edit/0 to exit) "
        echo
        if [ "$ai_mode" != "subject" ] && [ "$choice" != "0" ]; then
            echo
        fi

        normalize_key "$choice"
        if [ "$normalized_key" = "r" ]; then
            echo -e "${YELLOW}Regenerating...${ENDCOLOR}"
            if [ -n "$rejected_ai_messages" ]; then
                rejected_ai_messages="${rejected_ai_messages}
${ai_commit_message}"
            else
                rejected_ai_messages="$ai_commit_message"
            fi
            continue
        fi
        break
    done

    if [ "$normalized_key" = "y" ] || [ -z "$choice" ]; then
        commit="$ai_commit_message"
        # Skip to final commit step
        if [ "$ai_mode" = "subject" ]; then
            echo
        fi
        # Save commit message in case commit fails (e.g. pre-commit hook)
        git config gitbasher.cached-commit-message "$commit"
        result=$(git commit -m "$commit" 2>&1)
        check_code $? "$result" "commit"

        # Clean up cached git add and commit message on successful commit
        git config --unset gitbasher.cached-git-add 2>/dev/null
        git config --unset gitbasher.cached-commit-message 2>/dev/null

        after_commit

        if [ -n "${push}" ]; then
            echo
            push_script y
        fi
        exit

    elif [ "$normalized_key" = "e" ]; then
        if [ "$ai_mode" = "full" ]; then
            echo -e "${YELLOW}Edit the AI generated message:${ENDCOLOR}"
            # Create temp file with AI message
            commitmsg_file=$(mktemp "${TMPDIR:-/tmp}/commitmsg.XXXXXX")
            chmod 600 "$commitmsg_file" 2>/dev/null || true
            trap 'rm -f "$commitmsg_file"' EXIT INT TERM
            echo "$ai_commit_message" > $commitmsg_file

            while [ true ]; do
                $editor $commitmsg_file
                commit_message=$(cat $commitmsg_file | sed '/^#/d')

                if [ -n "$commit_message" ]; then
                    break
                fi
                echo
                echo -e "${YELLOW}⚠  Commit message cannot be empty.${ENDCOLOR}"
                echo
                read -n 1 -p "Try again? (y/n) " -s -e choice
                if ! is_yes "$choice"; then
                    cleanup_on_exit "$git_add"
                    rm -f "$commitmsg_file"
                    exit
                fi
            done

            commit_message=$(cat $commitmsg_file)
            rm -f "$commitmsg_file"
            echo
        else
            if [ "$ai_mode" = "subject" ]; then
                echo
            fi
            echo -e "${YELLOW}Edit the AI generated message:${ENDCOLOR}"
            read_editable_input commit_message "" "$ai_commit_message"
        fi
        
        if [ -z "$commit_message" ]; then
            cleanup_on_exit "$git_add"
            exit
        fi
        
        commit="$commit_message"
        # Skip to final commit step
        echo
        # Save commit message in case commit fails (e.g. pre-commit hook)
        git config gitbasher.cached-commit-message "$commit"
        result=$(git commit -m "$commit" 2>&1)
        check_code $? "$result" "commit"

        # Clean up cached git add and commit message on successful commit
        git config --unset gitbasher.cached-git-add 2>/dev/null
        git config --unset gitbasher.cached-commit-message 2>/dev/null

        after_commit

        if [ -n "${push}" ]; then
            echo
            push_script y
        fi
        exit
    
    elif [ "$choice" = "0" ]; then
        cleanup_on_exit "$git_add"
        exit
        
    else
        if [ "$ai_mode" = "subject" ]; then
            echo
        fi
        echo -e "${YELLOW}Falling back to manual commit message creation...${ENDCOLOR}"
        if [ "$ai_mode" = "subject" ]; then
            echo
        fi
        # Continue with manual flow
    fi
}

### Function prints information about the last commit, use it after `git commit`
# $1: name of operation, e.g. `amend`
# Using of global:
#     * current_branch
#     * commit - message
function after_commit {
    if [ -n "$1" ]; then
        echo -e "${GREEN}✓ Committed ($1)${ENDCOLOR}"
    else
        echo -e "${GREEN}✓ Committed${ENDCOLOR}"
    fi
    
    echo

    # Print commit hash and message
    commit_hash=$(git rev-parse HEAD)
    echo -e "${BLUE}[$current_branch ${commit_hash::7}]${ENDCOLOR}"
    if [ -z "${commit}" ]; then
        echo "$(git log -1 --pretty=%B)"
    else
        printf "%s\n" "$commit"
    fi

    echo

    # Print stat of last commit - updated files and lines
    print_changes_stat "$(git --no-pager show $commit_hash --stat --format="")"

    # Some info to help users
    if [ -z "${fast}" ] && [ -z "${push}" ]; then
        echo
        echo -e "Push your changes: ${YELLOW}gitb push${ENDCOLOR}"
        echo -e "Undo commit: ${YELLOW}gitb reset${ENDCOLOR}"
    fi
}


### Map a single multi-word token to its commit flag(s).
# Returns 1 for unknown tokens so the caller can surface a wrong_mode error.
# Used only when commit_script receives 2+ arguments (multi-word form like
# `gitb commit ai fast push`). Single-token compact forms (aifp, ffp, ...) are
# still handled by the case statement below.
function set_commit_flag_from_token {
    case "$1" in
        ai|llm|i)            llm="true";;
        fast|f)              fast="true";;
        push|pu|p)           push="true";;
        scope|s)             scope="true";;
        msg|m)               msg="true";;
        ticket|jira|j|t)     ticket="true";;
        staged)              staged="true";;
        no-split|nosplit|nsp|nsl) no_split="true";;
        fixup|fix|x)         fixup="true";;
        amend|am|a)          amend="true";;
        split|sp|sl)         split="true";;
        last|l)              last="true";;
        revert|rev)          revert="true";;
        help|h)              help="true";;
        *) return 1;;
    esac
    return 0
}


### Reject combinations the help text already documents as invalid (line 1295-).
# Without this, dispatch silently picks one action and ignores the rest, e.g.
# `commit ai revert` runs revert and silently drops the AI step.
function validate_commit_flag_combo {
    local actions=() invalid=()

    [ -n "$last" ]   && actions+=("last")
    [ -n "$revert" ] && actions+=("revert")
    [ -n "$fixup" ]  && actions+=("fixup")
    [ -n "$amend" ]  && actions+=("amend")
    [ -n "$split" ]  && actions+=("split")

    if [ ${#actions[@]} -gt 1 ]; then
        echo -e "${RED}✗ Cannot combine actions: ${actions[*]}${ENDCOLOR}"
        echo -e "Pick one of: last, revert, fixup, amend, split."
        exit 1
    fi

    local lone=""
    [ -n "$last" ]   && lone="last"
    [ -n "$revert" ] && lone="revert"
    if [ -n "$lone" ]; then
        [ -n "$llm" ]      && invalid+=("ai")
        [ -n "$fast" ]     && invalid+=("fast")
        [ -n "$push" ]     && invalid+=("push")
        [ -n "$scope" ]    && invalid+=("scope")
        [ -n "$msg" ]      && invalid+=("msg")
        [ -n "$ticket" ]   && invalid+=("ticket")
        [ -n "$staged" ]   && invalid+=("staged")
        [ -n "$no_split" ] && invalid+=("no-split")
        if [ ${#invalid[@]} -gt 0 ]; then
            echo -e "${RED}✗ '${lone}' takes no modifiers (got: ${invalid[*]})${ENDCOLOR}"
            exit 1
        fi
    fi

    if [ -n "$amend" ] || [ -n "$fixup" ]; then
        local action_name
        [ -n "$amend" ] && action_name="amend" || action_name="fixup"
        invalid=()
        [ -n "$llm" ]      && invalid+=("ai")
        [ -n "$msg" ]      && invalid+=("msg")
        [ -n "$ticket" ]   && invalid+=("ticket")
        [ -n "$scope" ]    && invalid+=("scope")
        [ -n "$no_split" ] && invalid+=("no-split")
        if [ ${#invalid[@]} -gt 0 ]; then
            echo -e "${RED}✗ '${action_name}' does not use: ${invalid[*]}${ENDCOLOR}"
            echo -e "Only fast, staged, push apply (the message is reused / autosquashed)."
            exit 1
        fi
    fi

    if [ -n "$fast" ] && [ -n "$staged" ]; then
        echo -e "${RED}✗ 'fast' and 'staged' are mutually exclusive${ENDCOLOR}"
        echo -e "fast stages everything; staged commits what's already in the index."
        exit 1
    fi
}


### Print a one-line summary of how the parsed flags will be interpreted.
# Helps users catch typos like `amend fasts` (a typo of `fastfix`) where the
# parser accepts the input but the chosen action wouldn't match intent.
function summarize_commit_intent {
    local action="commit" mods=()

    if [ -n "$auto_accept" ]; then
        action="ultrafast commit (ai + fast + auto-accept)"
    elif [ -n "$last" ]; then
        action="amend last commit (reuse message)"
    elif [ -n "$revert" ]; then
        action="revert a commit"
    elif [ -n "$amend" ]; then
        action="amend last commit"
    elif [ -n "$fixup" ]; then
        action="fixup an earlier commit"
    elif [ -n "$split" ]; then
        action="split staged changes into atomic commits"
    fi

    [ -n "$llm" ] && [ -z "$auto_accept" ] && mods+=("ai message")
    [ -n "$fast" ]     && [ -z "$auto_accept" ] && mods+=("fast")
    [ -n "$staged" ]   && mods+=("staged")
    [ -n "$scope" ]    && mods+=("scope")
    [ -n "$msg" ]      && mods+=("msg")
    [ -n "$ticket" ]   && mods+=("ticket")
    [ -n "$no_split" ] && mods+=("no-split")
    [ -n "$push" ]     && mods+=("push")

    local line="→ ${action}"
    if [ ${#mods[@]} -gt 0 ]; then
        line="${line} (modifiers: ${mods[*]})"
    fi
    echo -e "${YELLOW}${line}${ENDCOLOR}"
}


### Main function
# $1...: mode token(s)
    # <empty> - regular commit mode
    # Single token: compact form like aifp, ffp, llmsfp (see case below)
    # Multiple tokens: any combination of words/aliases in any order, e.g.
    #   `ai fast push`, `push fast ai`, `ai f p` all map to llm+fast+push
    # msg: use editor to write commit message
    # ticket: add ticket info to the end of message header
    # fast: fast commit with git add .
    # fasts: fast commit with scope
    # push: push changes after commit
    # fastp: fast commit with push
    # fastsp: fast commit with scope and push
    # fixup: fixup commit
    # fastfix: fixup commit with git add .
    # fastfixp: fast fixup commit with push
    # amend: add to the last without edit (add to last commit)
    # amendf: add all fiels to the last commit without edit
    # last: change commit message to the last one
    # revert: revert commit
    # help: print help
function commit_script {
    if [ $# -ge 2 ]; then
        for tok in "$@"; do
            set_commit_flag_from_token "$tok" || wrong_mode "commit" "$tok"
        done
    else
    case "$1" in
        scope|s)            ;; # general commit with scope
        split|sp|sl)        split="true";; # force atomic-split flow (heuristic + manual messages)
        splitp|spp|slp)     split="true"; push="true";;
        aisplit|isplit|aispl|ispl)        split="true"; llm="true";; # AI-refined grouping + AI messages
        aisplitp|isplitp|aisplp|isplp)    split="true"; llm="true"; push="true";;
        no-split|nosplit|nsp|nsl) no_split="true";;
        msg|m)              msg="true";;
        ticket|jira|j|t)    ticket="true";;
        fast|f)             fast="true";;
        fasts|fs|sf)        fast="true"; scope="true";;
        ff)                 fast="true"; llm="true"; auto_accept="true";; # ultrafast: no prompts at all
        ffp|ffpush)         fast="true"; llm="true"; auto_accept="true"; push="true";;
        staged|st)          staged="true";;
        push|pu|p)          push="true";;
        fastp|fp|pf)        fast="true"; push="true";;
        fastsp|fsp|fps)     fast="true"; push="true"; scope="true";;
        fixup|fix|x)        fixup="true";;
        fixupp|fixp|xp|px)  fixup="true"; push="true";;
        fixupst|xst|stx)    fixup="true"; staged="true";;
        fastfix|fx|xf)      fixup="true"; fast="true";;
        fastfixp|fxp|xfp)   fixup="true"; fast="true"; push="true";;
        amend|am|a)         amend="true";;
        amendst|ast|sta)    amend="true"; staged="true";;
        amendf|amf|af|fa)   amend="true"; fast="true";;
        last|l)             last="true";;
        revert|rev)         revert="true";;
        llm|ai|i)           llm="true";;
        llmf|aif|if)        llm="true"; fast="true";;
        llmp|aip|ip)        llm="true"; push="true";;
        llmst|aist|ist)     llm="true"; staged="true";;
        llmfp|aifp|ifp|ipf) llm="true"; fast="true"; push="true";;
        llms|ais|is)        llm="true"; scope="true";;
        llmsf|aisf|isf)     llm="true"; scope="true"; fast="true";;
        llmsfp|aisfp|isfp)  llm="true"; scope="true"; fast="true"; push="true";;
        llmm|aim|im)        llm="true"; msg="true";;
        llmmf|aimf|imf)     llm="true"; msg="true"; fast="true";;
        llmmfp|aimfp|imfp)  llm="true"; msg="true"; fast="true"; push="true";;
        help|h)             help="true";;
        *)
            wrong_mode "commit" $1
    esac
    # kcov-skip-start
    fi

    validate_commit_flag_combo


    ### Print header
    header_msg="GIT COMMIT"
    if [ -n "${llm}" ]; then
        header_msg="$header_msg AI"
    fi

    if [ -n "${auto_accept}" ]; then
        if [ -n "${push}" ]; then
            header_msg="$header_msg ULTRAFAST & PUSH"
        else
            header_msg="$header_msg ULTRAFAST"
        fi
    elif [ -n "${split}" ]; then
        if [ -n "${push}" ]; then
            header_msg="$header_msg SPLIT & PUSH"
        else
            header_msg="$header_msg SPLIT"
        fi
    elif [ -n "${staged}" ]; then
        header_msg="$header_msg STAGED"
    elif [ -n "${fast}" ]; then
        if [ -n "${push}" ]; then
            if [ -n "${fixup}" ]; then
                header_msg="$header_msg FAST FIXUP & PUSH"
            else
                header_msg="$header_msg FAST & PUSH"
            fi
        elif [ -n "${fixup}" ]; then
            header_msg="$header_msg FAST FIXUP"
        else
            header_msg="$header_msg FAST"
        fi
    elif [ -n "${fixup}" ]; then
        if [ -n "${push}" ]; then
            header_msg="$header_msg FIXUP & PUSH"
        else
            header_msg="$header_msg FIXUP"
        fi
    elif [ -n "${push}" ]; then
        header_msg="$header_msg & PUSH"
    elif [ -n "${msg}" ]; then
        header_msg="$header_msg MSG"
    elif [ -n "${ticket}" ]; then
        header_msg="$header_msg TICKET"
    elif [ -n "${amend}" ]; then
        header_msg="$header_msg AMEND LAST"
    elif [ -n "${last}" ]; then
        header_msg="$header_msg LAST"
    elif [ -n "${revert}" ]; then
        header_msg="$header_msg REVERT"
    fi

    echo -e "${YELLOW}${header_msg}${ENDCOLOR}"
    echo

    if [ -n "$help" ]; then
        # kcov-skip-start
        echo -e "usage: ${YELLOW}gitb commit [<flag> ...]${ENDCOLOR}     ${BLUE}# space-separated, any order${ENDCOLOR}"
        echo -e "       ${YELLOW}gitb commit <combined>${ENDCOLOR}        ${BLUE}# compact form: ff, aifp, fastsp, ...${ENDCOLOR}"
        echo
        echo -e "A commit invocation is one ${BOLD}action${NORMAL} plus zero or more ${BOLD}modifiers${NORMAL}."
        echo -e "Words can be combined freely (${GREEN}ai fast push${ENDCOLOR}) or written as a single"
        echo -e "compact token (${GREEN}aifp${ENDCOLOR}). Aliases are interchangeable."
        echo
        echo -e "${YELLOW}Actions${ENDCOLOR} ${BLUE}(pick one; default is a regular commit)${ENDCOLOR}"
        local PAD=22
        print_help_header $PAD
        print_help_row $PAD "<empty>" ""               "Interactive commit: choose files, type, scope, and summary"
        print_help_row $PAD "split"   "sp, sl"         "Split staged changes into one commit per detected scope"
        print_help_row $PAD "fixup"   "x, fix"         "Create a ${GREEN}--fixup${ENDCOLOR} commit against an older commit"
        print_help_row $PAD "amend"   "a, am"          "Add changes into the last commit (no message edit)"
        print_help_row $PAD "last"    "l"              "Rewrite the last commit message"
        print_help_row $PAD "revert"  "rev"            "Revert a commit (${GREEN}git revert --no-edit${ENDCOLOR})"
        print_help_row $PAD "ff"      ""               "Ultrafast: ${BOLD}ai + split + fast${NORMAL} with no prompts (use ${BOLD}ffp${NORMAL} to also push)"
        print_help_row $PAD "help"    "h, --help, -h"  "Show this help"
        echo
        echo -e "${YELLOW}Modifiers${ENDCOLOR} ${BLUE}(stack with an action, any order)${ENDCOLOR}"
        local FPAD=20
        printf "  ${YELLOW}%-*s${ENDCOLOR}  ${BLUE}%s${ENDCOLOR}\n" "$FPAD" "Flag" "Description"
        print_help_row $FPAD "fast"     "f"           "Stage all changes (${GREEN}git add .${ENDCOLOR}) before committing"
        print_help_row $FPAD "staged"   "st"          "Use already-staged files (skip the add step)"
        print_help_row $FPAD "push"     "p, pu"       "Push after the commit succeeds"
        print_help_row $FPAD "scope"    "s"           "Force a scope: 'type(scope): message' (useful with fast mode)"
        print_help_row $FPAD "no-split" "nsp, nsl"    "Disable automatic split detection for this commit"
        print_help_row $FPAD "ai"       "i, llm"      "Generate the commit message with AI"
        print_help_row $FPAD "msg"      "m"           "Open \$EDITOR for a multiline message body"
        print_help_row $FPAD "ticket"   "t, j, jira"  "Append ticket info to the header"
        echo
        echo -e "${YELLOW}Examples${ENDCOLOR}"
        echo -e "  ${GREEN}gitb commit${ENDCOLOR}                  Interactive commit"
        echo -e "  ${GREEN}gitb commit fast${ENDCOLOR}             ${BLUE}git add .${ENDCOLOR} then enter a message"
        echo -e "  ${GREEN}gitb commit ai fast push${ENDCOLOR}     AI message + add all + commit + push"
        echo -e "  ${GREEN}gitb commit aifp${ENDCOLOR}             Same as above (compact form)"
        echo -e "  ${GREEN}gitb commit ai split push${ENDCOLOR}    AI groups staged files into commits, then push"
        echo -e "  ${GREEN}gitb commit fixup push${ENDCOLOR}       Pick an older commit, fixup it, then push"
        echo -e "  ${GREEN}gitb commit amend fast${ENDCOLOR}       Add all current changes into the last commit"
        echo -e "  ${GREEN}gitb commit ff${ENDCOLOR}               Full auto: AI splits and writes everything"
        echo
        echo -e "${YELLOW}How modes combine${ENDCOLOR}"
        echo -e "  ${BLUE}•${ENDCOLOR} Word order doesn't matter: ${GREEN}ai fast push${ENDCOLOR} == ${GREEN}push fast ai${ENDCOLOR} == ${GREEN}aifp${ENDCOLOR}"
        echo -e "  ${BLUE}•${ENDCOLOR} Modifiers stack on actions: ${GREEN}ai+fixup${ENDCOLOR}, ${GREEN}fast+amend${ENDCOLOR}, ${GREEN}split+push${ENDCOLOR}, ${GREEN}ai+staged${ENDCOLOR}, ..."
        echo -e "  ${BLUE}•${ENDCOLOR} ${BOLD}fast${NORMAL} and ${BOLD}staged${NORMAL} are mutually exclusive (one stages all, the other uses what's staged)"
        echo -e "  ${BLUE}•${ENDCOLOR} ${BOLD}last${NORMAL} and ${BOLD}revert${NORMAL} take no modifiers; ${BOLD}ff${NORMAL} only accepts ${BOLD}push${NORMAL} (as ${BOLD}ffp${NORMAL})"
        # Clean up cached git add on help exit
        git config --unset gitbasher.cached-git-add 2>/dev/null || true
        exit 0
        # kcov-skip-end
    fi


    ### Print a one-line summary of how flags were interpreted so users can
    ### catch typos before any work runs.
    summarize_commit_intent
    echo


    ### Refuse to silently create unreachable commits in detached-HEAD state
    warn_if_detached_head "commit"


    if [ -n "$last" ]; then
        # Clean up cached git add before amending last commit
        git config --unset gitbasher.cached-git-add 2>/dev/null
        git commit --amend
        exit
    fi


    ### Check if there are unstaged files
    # --porcelain output is locale-stable; empty == clean working tree.
    is_clean=$(LC_ALL=C git status --porcelain)
    if [ -z "$is_clean" ]; then
        if [ -z "${revert}" ]; then
            # Clean up cached git add when working tree is clean
            git config --unset gitbasher.cached-git-add 2>/dev/null
            echo -e "${GREEN}✓ Nothing to commit — working tree clean${ENDCOLOR}"

            # If in push mode, check for unpushed commits
            if [ -n "${push}" ]; then
                echo
                get_push_list ${current_branch} ${main_branch} ${origin_name}

                if [ -n "$push_list" ]; then
                    echo -e "${YELLOW}But there are unpushed commits:${ENDCOLOR}"
                    echo
                    count=$(echo -e "$push_list" | wc -l | sed 's/^ *//;s/ *$//')
                    echo -e "Your branch is ahead ${YELLOW}${history_from}${ENDCOLOR} by ${BOLD}$count${ENDCOLOR} commits"
                    echo -e "$push_list"
                    echo
                    echo -e "Do you want to push these commits to ${YELLOW}${origin_name}/${current_branch}${ENDCOLOR} (y/n)?"
                    yes_no_choice "Pushing..."
                    push_script y
                fi
            fi
            exit
        fi
    elif [ -n "${revert}" ]; then
        echo -e "${RED}✗ Cannot revert — there are uncommitted changes.${ENDCOLOR}"
        exit
    fi


    ### Check for staged files when using staged mode
    if [ -n "${staged}" ]; then
        staged_files_check=$(git -c core.quotePath=false diff --name-only --cached)
        if [ -z "$staged_files_check" ]; then
            echo -e "${RED}✗ No staged files found.${ENDCOLOR}"
            exit 1
        fi
        echo -e "${YELLOW}Using already staged files:${ENDCOLOR}"
        print_staged_files
    fi


    ### Run revert logic
    if [ -n "${revert}" ]; then
        echo -e "${YELLOW}Step 1.${ENDCOLOR} Select a commit to ${YELLOW}revert${ENDCOLOR} it:"
        
        choose_commit 20

        result=$(git revert --no-edit ${commit_hash} 2>&1)
        check_code $? "$result" "revert"

        after_commit "revert"
        exit
    fi


    ### Print status (don't need to print in fast or staged mode)
    if [ -z "${fast}" ] && [ -z "${staged}" ]; then 
        echo -e "${YELLOW}Changed files${ENDCOLOR}"
        git_status
    fi


    ### Check for previously saved git add arguments
    saved_git_add=""
    if [ -z "${fast}" ] && [ -z "${staged}" ]; then
        saved_git_add=$(git config --get gitbasher.cached-git-add 2>/dev/null)
        if [ -n "$saved_git_add" ]; then
            echo
            echo -e "${YELLOW}Found previous git add arguments:${ENDCOLOR} ${BOLD}$saved_git_add${ENDCOLOR}"
            read_key choice "Use them? (y/n) "
            echo
            if is_yes "$choice"; then
                git add $saved_git_add
                if [ $? -eq 0 ]; then
                    git_add="$saved_git_add"
                    use_saved_git_add="true"
                else
                    echo
                    echo -e "${YELLOW}⚠  Could not reuse saved git add arguments — continuing without them.${ENDCOLOR}"
                    git config --unset gitbasher.cached-git-add 2>/dev/null
                fi
                echo
            else
                git config --unset gitbasher.cached-git-add 2>/dev/null
            fi
        fi
    fi


    ### Commit Step 1: add files to commit
    if [ -n "${staged}" ]; then
        # Files are already staged, skip git add step
        git_add=""
        # Clean up any existing cached git add since we're using staged files
        git config --unset gitbasher.cached-git-add 2>/dev/null
    elif [ -n "${fast}" ]; then
        if ! stage_fast_changes; then
            exit 1
        fi
        git_add="."
        # Clean up any existing cached git add since we're using fast mode
        git config --unset gitbasher.cached-git-add 2>/dev/null
    elif [ -n "${use_saved_git_add}" ]; then
        # Files are already staged using saved git add arguments
        echo -e "${YELLOW}Step 1.${ENDCOLOR} Using saved git add arguments: ${BOLD}$git_add${ENDCOLOR}"
        echo
    else
        echo
        printf "${YELLOW}Step 1.${ENDCOLOR} List files for "
        if [ -n "${fixup}" ]; then
            printf "${YELLOW}--fixup${ENDCOLOR} "
        elif [ -n "${squash}" ]; then
            printf "${YELLOW}--squash${ENDCOLOR} "
        elif [ -n "${amend}" ]; then
            printf "${YELLOW}--amend${ENDCOLOR} "
        fi
        if [ -n "${amend}" ]; then
            printf "to the last commit in the ${YELLOW}${current_branch}${ENDCOLOR} branch\n"
        else
            printf "commit to the ${YELLOW}${current_branch}${ENDCOLOR} branch\n"
        fi
        echo "Press Enter if you want to exit"

        while [ true ]; do
            read_editable_input git_add "$(echo -n -e "${BOLD}git add${ENDCOLOR} ")"

            # Sanitize file path input
            if [ "$git_add" == "" ]; then
                exit
            fi
            
            if ! sanitize_file_path "$git_add"; then
                show_sanitization_error "file path" "Invalid file path or pattern. Avoid dangerous characters and sequences."
                continue
            fi
            git_add="$sanitized_file_path"

            result=$(git add $git_add 2>&1)
            code=$?
            staged_files_list="$(git -c core.quotePath=false diff --name-only --cached)"
            if [ $code -eq 0 ] && [ -n "$staged_files_list" ]; then
                # Save git add arguments for potential retry
                git config gitbasher.cached-git-add "$git_add"
                break
            else
                # Check if error is about "did not match any files" and try with * appended
                if [[ "$git_add" != *"*" ]]; then
                    echo

                    git_add_with_star="${git_add}*"
                    echo -e "${YELLOW}No files were staged! Trying with wildcard:${ENDCOLOR} ${BOLD}git add $git_add_with_star${ENDCOLOR}"
                   
                    result_star=$(git add $git_add_with_star 2>&1)
                    code_star=$?
                    staged_files_list_star="$(git -c core.quotePath=false diff --name-only --cached)"
                    if [ $code_star -eq 0 ] && [ -n "$staged_files_list_star" ]; then
                        # Save the successful git add arguments for potential retry
                        git config gitbasher.cached-git-add "$git_add_with_star"
                        git_add="$git_add_with_star"
                        break
                    else
                        echo -e "${RED}✗ Cannot add files with wildcard:${ENDCOLOR} ${BOLD}$result_star${ENDCOLOR}"
                        echo
                    fi
                else
                    echo "$result"
                fi
            fi
        done

        echo
    fi

    ### Print staged files that we add at step 1
    if [ -z "${staged}" ]; then
        echo -e "${YELLOW}Staged files:${ENDCOLOR}"
        staged_files_list="$(sed 's/^/\t/' <<< "$(git -c core.quotePath=false diff --name-only --cached)")"
        print_staged_files
    else
        # Still need to set the staged files list for later use (editor template)
        staged_files_list="$(sed 's/^/\t/' <<< "$(git -c core.quotePath=false diff --name-only --cached)")"
    fi


    ### Offer atomic-split when staged changes span multiple scopes.
    # Split runs the entire commit flow itself (one commit per scope) and exits
    # the script on success. Skipped for modes where it doesn't make sense
    # (amend, fixup, multi-line msg, ticket) or when forced off via config.
    # Fast/auto-accept modes skip the y/N prompt — split silently when applicable.
    if [ -z "${amend}" ] && [ -z "${fixup}" ] && [ -z "${msg}" ] && [ -z "${ticket}" ] && [ -z "${no_split}" ]; then
        _split_auto_yes=""
        if [ -n "$fast" ] || [ -n "$auto_accept" ]; then
            _split_auto_yes="true"
        fi
        try_offer_commit_split "$split" "$_split_auto_yes"
        # If the user explicitly asked for split mode but it wasn't applicable,
        # don't silently fall through to the single-commit flow.
        if [ -n "$split" ]; then
            cleanup_on_exit "$git_add"
            exit 0
        fi
    fi


    ### Check for previously saved commit message (from a failed commit)
    saved_commit_message=$(git config --get gitbasher.cached-commit-message 2>/dev/null)
    if [ -n "$saved_commit_message" ] && [ -z "${fixup}" ] && [ -z "${amend}" ]; then
        echo
        echo -e "${YELLOW}Found previous commit message:${ENDCOLOR} ${BOLD}$saved_commit_message${ENDCOLOR}"
        echo
        read_key choice "Use it? (y/e to edit/n) "
        echo
        normalize_key "$choice"
        if [ "$normalized_key" = "y" ] || [ -z "$choice" ]; then
            commit="$saved_commit_message"
            echo
            result=$(git commit -m "$commit" 2>&1)
            check_code $? "$result" "commit"

            # Clean up cached git add and commit message on successful commit
            git config --unset gitbasher.cached-git-add 2>/dev/null
            git config --unset gitbasher.cached-commit-message 2>/dev/null

            after_commit

            if [ -n "${push}" ]; then
                echo
                push_script y
            fi
            exit
        elif [ "$normalized_key" = "e" ]; then
            echo
            echo -e "${YELLOW}Edit the saved commit message:${ENDCOLOR}"
            read_editable_input edited_commit_message "" "$saved_commit_message"
            if [ -n "$edited_commit_message" ]; then
                commit="$edited_commit_message"
                echo
                # Save edited message in case this commit also fails
                git config gitbasher.cached-commit-message "$commit"
                result=$(git commit -m "$commit" 2>&1)
                check_code $? "$result" "commit"

                # Clean up cached git add and commit message on successful commit
                git config --unset gitbasher.cached-git-add 2>/dev/null
                git config --unset gitbasher.cached-commit-message 2>/dev/null

                after_commit

                if [ -n "${push}" ]; then
                    echo
                    push_script y
                fi
                exit
            else
                git config --unset gitbasher.cached-commit-message 2>/dev/null
            fi
        else
            git config --unset gitbasher.cached-commit-message 2>/dev/null
        fi
    fi


    ### AI Logic: Generate commit message using AI (before manual steps)
    if [ -n "${llm}" ] && [ -z "${scope}" ]; then
        if [ -n "${fast}" ] || [ -n "${staged}" ]; then
            step="1"
        else
            step="2"
        fi
        type="simple"
        if [ -n "${msg}" ]; then
            type="full"
        fi
        
        handle_ai_commit_generation "$step" "$type" ""
    fi


    ### Run fixup logic
    if [ -n "${fixup}" ]; then
        echo
        step="2"
        if [ -n "${fast}" ] || [ -n "${staged}" ]; then
            step="1"
        fi
        echo -e "${YELLOW}Step ${step}.${ENDCOLOR} Select a commit to ${YELLOW}--fixup${ENDCOLOR}:"

        if [ -n "${fast}" ] || [ -n "${staged}" ]; then
            choose_commit 9
        else
            choose_commit 19
        fi
        
        result=$(git commit --fixup $commit_hash 2>&1)
        check_code $? "$result" "create fixup commit"
        
        # Clean up cached git add and commit message on successful fixup
        git config --unset gitbasher.cached-git-add 2>/dev/null
        git config --unset gitbasher.cached-commit-message 2>/dev/null

        after_commit "fixup"

        if [ -n "${push}" ]; then
            echo
            push_script y
        fi

        exit
    fi


    ### Run amend logic - add staged files to the last commit
    if [ -n "${amend}" ]; then
        result=$(git commit --amend --no-edit 2>&1)
        check_code $? "$result" "amend"
        
        # Clean up cached git add and commit message on successful amend
        git config --unset gitbasher.cached-git-add 2>/dev/null
        git config --unset gitbasher.cached-commit-message 2>/dev/null

        echo
        after_commit "amend"
        exit
    fi


    ### Commit Step 2: Select commit type
    echo
    step="2"
    if [ -n "${fast}" ] || [ -n "${staged}" ]; then
        step="1"
    fi
    local _ai_available_for_menu="false"
    if check_ai_available 2>/dev/null; then
        _ai_available_for_menu="true"
    fi
    print_commit_type_menu "$step" "$_ai_available_for_menu"

    declare -A types=(
        [1]="feat"
        [2]="fix"
        [3]="refactor"
        [4]="test"
        [5]="build"
        [6]="ci"
        [7]="chore"
        [8]="docs"
    )

    while [ true ]; do
        read -n 1 -s choice

        if [ "$choice" == "0" ]; then
            cleanup_on_exit "$git_add"
            echo
            echo -e "${YELLOW}Aborted.${ENDCOLOR}"
            exit
        fi

        normalize_key "$choice"
        if [ "$normalized_key" == "g" ]; then
            if [ "$_ai_available_for_menu" != "true" ]; then
                continue
            fi
            local _ai_mode="simple"
            if [ -n "${msg}" ]; then
                _ai_mode="full"
            fi
            handle_ai_commit_generation "$step" "$_ai_mode" ""
            # AI fell back to manual — re-show the type menu and keep reading.
            echo
            print_commit_type_menu "$step" "$_ai_available_for_menu"
            continue
        fi

        re='^[0-9]+$'
        if ! [[ $choice =~ $re ]]; then
            continue
        fi

        if [ "$choice" == "9" ]; then
            is_empty="true"
            break
        fi

        commit_type="${types[$choice]}"
        if [ -n "$commit_type" ]; then
            break
        fi
    done

    commit=""
    if [ -z "$is_empty" ]; then
        commit="$commit_type"
    fi


    ### Commit Step 3: enter a commit scope
    if [ -z "$is_empty" ] && ([ -z "$fast" ] || [ -n "$scope" ]); then
        step="3"
        if [ -n "${fast}" ] || [ -n "${staged}" ]; then
            step="2"
        fi
        echo
        echo -e "${YELLOW}Step ${step}.${ENDCOLOR} Enter a ${YELLOW}scope${ENDCOLOR} for additional context"
        echo -e "Final message will be ${BLUE}${commit_type}${ENDCOLOR}(${YELLOW}<scope>${ENDCOLOR}): ${BLUE}<summary>${ENDCOLOR}"
        echo -e "Press Enter to skip the scope, or 0 to exit without changes"
        
        # Detect possible scopes from staged files
        detect_scopes_from_staged_files
        
        # Use predefined scopes or detected scopes
        all_scopes=""
        if [ -n "$scopes" ]; then
            all_scopes="$scopes"
        elif [ -n "$detected_scopes" ]; then
            all_scopes="$detected_scopes"
        fi
        
        if [ -n "$all_scopes" ]; then
           IFS=' ' read -r -a scopes_array <<< "$all_scopes"

           res=""
           for i in "${!scopes_array[@]}"; do
                scope_display="${scopes_array[$i]}"
                res="$res$((i+1)). ${BOLD}${scope_display}${ENDCOLOR}|"
           done
           echo -e "You can select one of the ${YELLOW}detected scopes${ENDCOLOR}: $(echo $res | column -ts'|')"            
        fi

        while [ true ]; do
            read_editable_input commit_scope "<scope>: "

            if [ "$commit_scope" == "0" ]; then
                cleanup_on_exit "$git_add"
                exit
            fi

            # Check if input is empty - continue without scope
            if [ -z "$commit_scope" ]; then
                commit="$commit: "
                break
            fi

            # Check if input is a number (index selection from scopes_array)
            re_number='^[1-9][0-9]*$'
            if [[ $commit_scope =~ $re_number ]] && [ -n "$all_scopes" ]; then
                # Try to find matching scope by index
                IFS=' ' read -r -a scopes_array <<< "$all_scopes"
                index=$((commit_scope - 1))
                if [ $index -ge 0 ] && [ $index -lt ${#scopes_array[@]} ]; then
                    selected_scope="${scopes_array[$index]}"
                    # Remove the asterisk marker if present
                    commit_scope="${selected_scope#*}"
                    commit="$commit($commit_scope): "
                    break
                else
                    echo -e "${RED}✗ Invalid scope index. Please choose 1-${#scopes_array[@]} or enter a custom scope.${ENDCOLOR}"
                    continue
                fi
            else
                # Sanitize custom scope input
                if ! sanitize_git_name "$commit_scope"; then
                    show_sanitization_error "scope" "Use only letters, numbers, hyphens, underscores, dots, and slashes."
                    continue
                fi
                commit_scope="$sanitized_git_name"
                commit="$commit($commit_scope): "
                break
            fi
        done

    fi

    if [ -z "$is_empty" ] && ([ -n "$fast" ]) && [ -z "$scope" ]; then
        commit="$commit: "
    fi


    ### Commit Step 4: enter commit message, use editor in msg mode
    if [ -n "${fast}" ]; then
        if [ -n "$scope" ]; then
            step="3"
        else
            step="2"
        fi
    elif [ -n "$is_empty" ] || [ -n "${staged}" ]; then
        step="3"
    else
        step="4"
    fi
    
    if [ -n "${llm}" ] && [ -n "${scope}" ]; then
        handle_ai_commit_generation "$step" "subject" "$commit"
    else
        echo
    fi

    echo -e "${YELLOW}Step ${step}.${ENDCOLOR} Write a ${YELLOW}summary${ENDCOLOR} about your changes"
    if [ -n "$is_empty" ]; then
        echo -e "Final message will be ${YELLOW}<summary>${ENDCOLOR}"
    elif [ "$commit_scope" == "" ]; then
        echo -e "Final message will be ${BLUE}${commit_type}${ENDCOLOR}: ${YELLOW}<summary>${ENDCOLOR}"
    else
        echo -e "Final message will be ${BLUE}${commit_type}${ENDCOLOR}(${BLUE}${commit_scope}${ENDCOLOR}): ${YELLOW}<summary>${ENDCOLOR}"
    fi
    echo -e "Press Enter if you want to exit"
    # Use an editor and commitmsg file
    if [ -n "$msg" ]; then
        commitmsg_file=$(mktemp "${TMPDIR:-/tmp}/commitmsg.XXXXXX")
        chmod 600 "$commitmsg_file" 2>/dev/null || true
        trap "rm -f '$commitmsg_file'" EXIT INT TERM
        staged_with_tab="$(sed 's/^/####\t/' <<< "${staged_files_list}")"

        echo """
####
#### Step ${step}. Write only <summary> about your changes without type and scope. 
#### It will be appended to '${commit}'. 
#### Lines starting with '#' will be ignored. 
#### 
#### On branch ${current_branch}
#### Changes to be commited:
${staged_with_tab}
####
#### Here is expected format:
#### ${commit}<summary>
#### <BLANK LINE>
#### <optional body>
#### <BLANK LINE>
#### <optional footer>
####
#### Summary should provide a succinct description of the change:
####     use the imperative, present tense: 'change' not 'changed' nor 'changes'
####     no dot (.) at the end
####     don't capitalize the first letter
####
#### The body is optional and should explain why you are making the change. 
####
#### The footer is optional and should contain any information about 'Breaking Changes'.
#### Breaking Change section should start with the phrase 'BREAKING CHANGE: ' followed by a summary of the breaking change.
####
#### Similarly, a Deprecation section should start with 'DEPRECATED: ' followed by a short description of what is deprecated.
""" >> $commitmsg_file

        while [ true ]; do
            $editor $commitmsg_file
            commit_message=$(cat $commitmsg_file | sed '/^#/d')

            if [ -n "$commit_message" ]; then
                break
            fi
            echo
            echo -e "${YELLOW}⚠  Commit message cannot be empty.${ENDCOLOR}"
            echo
            read -n 1 -p "Try again? (y/n) " -s -e choice
            if ! is_yes "$choice"; then
                cleanup_on_exit "$git_add"
                rm -f "$commitmsg_file"
                exit
            fi
        done

        rm -f "$commitmsg_file"

    # Use read from console
    else
        read_editable_input commit_message "$(echo -n -e "${commit}")"
        if [ -z "$commit_message" ]; then
            cleanup_on_exit "$git_add"
            exit
        fi
        
        # Sanitize commit message
        if ! sanitize_commit_message "$commit_message"; then
            show_sanitization_error "commit message" "Use printable characters only, 1-2000 characters."
            cleanup_on_exit "$git_add"
            exit 1
        fi
        commit_message="$sanitized_commit_message"
    fi


    ### Commit Step 5: enter tracker ticket
    if [ -n "${ticket}" ]; then
        echo
        echo -e "${YELLOW}Step 5.${ENDCOLOR} Enter the number of a resolved issue (e.g. JIRA or YouTrack)"
        echo -e "It will be appended to the summary header"
        echo -e "Press Enter to skip, or 0 to exit without changes"

        if [ -n "$ticket_name" ]; then
            read_editable_input commit_ticket "${ticket_name}${sep}"
        else 
            read_editable_input commit_ticket "<ticket>: "
        fi
        if [ "$commit_ticket" == "0" ]; then
            cleanup_on_exit "$git_add"
            exit
        fi

        if [ "$commit_ticket" != "" ]; then
            # Sanitize ticket input
            if ! sanitize_text_input "$commit_ticket" 50; then
                show_sanitization_error "ticket" "Use printable characters only, max 50 characters."
                cleanup_on_exit "$git_add"
                exit 1
            fi
            commit_ticket="$sanitized_text"

            summary=$(echo "$commit_message" | head -n 1)
            remaining_message=""
            if [ "$summary" != "$commit_message" ]; then
                remaining_message=$(echo "$commit_message" | tail -n +2)
                remaining_message="""
    $remaining_message"
            fi
            if [ -n "$ticket_name" ]; then
                commit_ticket="${ticket_name}${sep}${commit_ticket}"
            fi
            commit_message="$summary ($commit_ticket)$remaining_message"
        fi
    fi

    commit="${commit}${commit_message}"


    ### Finally
    echo

    # Save commit message in case commit fails (e.g. pre-commit hook)
    git config gitbasher.cached-commit-message "$commit"
    result=$(git commit -m "$commit" 2>&1)
    check_code $? "$result" "commit"

    # Clean up cached git add and commit message on successful commit
    git config --unset gitbasher.cached-git-add 2>/dev/null
    git config --unset gitbasher.cached-commit-message 2>/dev/null

    after_commit

    if [ -n "${push}" ]; then
        echo
        push_script y
    fi
    # kcov-skip-end
}
