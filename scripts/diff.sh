#!/usr/bin/env bash

### Script for showing diffs the gitbasher way
# Read README.md to get more information how to use it
# Use this script only with gitbasher


### Print a titled scope diff: header, colorized stat overview, then the full
### patch through git's own pager.
# $1: uppercase section title
# $@ (rest): arguments passed to `git diff` (e.g. --cached, HEAD, main...HEAD)
function diff_scope {
    local title="$1"
    shift

    echo -e "${YELLOW}${title}${ENDCOLOR}"
    echo

    local stat
    stat=$(git --no-pager diff --stat "$@" 2>/dev/null)
    if [ -z "$stat" ]; then
        echo -e "${GREEN}No changes to show${ENDCOLOR}"
        return
    fi

    print_changes_stat "$stat"
    echo

    git diff "$@"
}


### Default flow: overview of uncommitted changes, then an interactive picker to
### view one file's full patch at a time.
function diff_worktree_interactive {
    # Compare against HEAD (staged + unstaged). Fall back to the index on a
    # repo with no commits yet, where HEAD does not resolve.
    local dtarget="HEAD"
    if ! git rev-parse --verify -q HEAD >/dev/null 2>&1; then
        dtarget="--cached"
    fi

    local stat
    stat=$(git --no-pager diff --stat "$dtarget" 2>/dev/null)
    if [ -z "$stat" ]; then
        echo -e "${GREEN}No changes to show${ENDCOLOR}"
        return
    fi

    echo -e "${YELLOW}GIT DIFF${ENDCOLOR}"
    echo
    print_changes_stat "$stat"
    echo

    # Build the list of changed files (bash 3.2: read-loop, not mapfile).
    local files=()
    local f
    while IFS= read -r f; do
        [ -n "$f" ] && files+=("$f")
    done < <(git --no-pager diff --name-only "$dtarget" 2>/dev/null)

    if [ ${#files[@]} -eq 0 ]; then
        return
    fi

    # Interactive picker: show a file's full patch, then return to the list.
    # `choose` exits the process on 0 / invalid input; the empty-result break
    # is a safety net (and keeps the loop testable).
    while true; do
        local idx=1
        for f in "${files[@]}"; do
            echo -e "${idx}. ${f}"
            idx=$((idx + 1))
        done
        echo "0. Exit"
        echo

        read_prefix="Enter file number: "
        choice_result=""
        choose "${files[@]}"
        if [ -z "$choice_result" ]; then
            break
        fi

        echo
        git diff "$dtarget" -- "$choice_result"
        echo
    done
}


### Compare the current branch against another, chosen interactively.
function diff_branch {
    echo -e "${YELLOW}DIFF AGAINST BRANCH${ENDCOLOR}"
    echo
    echo -e "${YELLOW}Select a branch to compare with the current branch:${ENDCOLOR}"
    choose_branch

    # choose_branch sets to_exit / branch_name.
    if [ -n "$to_exit" ]; then
        return
    fi
    if [ -z "$branch_name" ]; then
        return
    fi

    echo
    # Three-dot: what the current branch introduced since it diverged from the
    # chosen branch — the same set you would review in a pull request.
    diff_scope "Changes on the current branch since ${branch_name}" "${branch_name}...HEAD"
}


### Show the diff of a single commit, chosen interactively.
function diff_commit {
    echo -e "${YELLOW}DIFF OF A COMMIT${ENDCOLOR}"
    echo

    choose_commit 10
    if [ -z "$commit_hash" ]; then
        return
    fi

    echo
    git show "$commit_hash"
}


### Return a line- and char-capped diff for AI prompts, for an arbitrary range.
# $@: arguments passed to `git diff` (e.g. HEAD, --cached, main...HEAD)
# Mirrors the caps used by the AI commit generator (get_limited_diff_for_ai),
# but works on any range and degrades to sane defaults when the AI config
# getters are not loaded (e.g. isolated unit tests).
function get_limited_diff_for_ai_range {
    local diff_limit max_chars
    if command -v get_ai_diff_limit >/dev/null 2>&1; then
        diff_limit=$(get_ai_diff_limit)
    else
        diff_limit=300
    fi
    if command -v get_ai_diff_max_chars >/dev/null 2>&1; then
        max_chars=$(get_ai_diff_max_chars)
    else
        max_chars=20000
    fi

    local diff_content
    diff_content=$(git --no-pager diff "$@" 2>/dev/null | head -n "$diff_limit")

    local char_count=${#diff_content}
    if [ "$char_count" -gt "$max_chars" ]; then
        diff_content=$(echo "$diff_content" | head -c "$max_chars")
        diff_content="${diff_content}... [truncated for token limit]"
    fi

    echo "$diff_content"
}


### Render an AI summary for the terminal: strip the Markdown that models emit
### (headings, bold, bullets) and re-style it in gitbasher's colors. Defensive —
### the prompt asks for plain text, but models slip, so raw markup never leaks.
function print_ai_summary {
    local text="$1"
    local esc c_bold c_bullet c_head c_reset
    esc=$(printf '\033')
    c_bold="${esc}[1m"
    c_bullet="${esc}[36m"
    c_head="${esc}[33m"
    c_reset="${esc}[0m"

    local label_re='^[[:space:]]*[A-Za-z][A-Za-z0-9 &/_-]*:[[:space:]]*$'
    local backtick='`'
    local line
    while IFS= read -r line; do
        # Drop inline-code backticks the model emits despite the prompt.
        line=${line//$backtick/}
        # Markdown heading (#, ##, ###) -> plain colored header.
        if [[ "$line" =~ ^[[:space:]]*#+[[:space:]] ]]; then
            line=$(printf '%s' "$line" | sed -E 's/^[[:space:]]*#+[[:space:]]*//; s/[[:space:]]*#+[[:space:]]*$//')
            printf '%s%s%s\n' "$c_head" "$line" "$c_reset"
            continue
        fi
        # A standalone label line ("Risks & Concerns:") -> colored header.
        if [[ "$line" =~ $label_re ]]; then
            printf '%s%s%s\n' "$c_head" "$line" "$c_reset"
            continue
        fi
        # Leading bullet (*, +, -) -> colored bullet.
        line=$(printf '%s' "$line" | sed -E "s/^([[:space:]]*)[*+-][[:space:]]+/\\1${c_bullet}•${c_reset} /")
        # Inline bold (**text** or __text__) -> terminal bold.
        line=$(printf '%s' "$line" | sed -E "s/(\\*\\*|__)([^*_]+)(\\*\\*|__)/${c_bold}\\2${c_reset}/g")
        printf '%s\n' "$line"
    done <<< "$text"
}


### Summarize the current changes in plain English using the AI engine.
function diff_ai {
    # Summarize uncommitted changes by default; fall back to the index when
    # there is no HEAD yet.
    local dtarget="HEAD"
    if ! git rev-parse --verify -q HEAD >/dev/null 2>&1; then
        dtarget="--cached"
    fi

    local diff_content
    diff_content=$(get_limited_diff_for_ai_range "$dtarget")
    if [ -z "$diff_content" ]; then
        echo -e "${GREEN}No changes to summarize${ENDCOLOR}"
        return
    fi

    # check_ai_available prints its own "configure with gitb cfg ai" hint.
    if ! check_ai_available; then
        return 1
    fi

    echo -e "${YELLOW}AI SUMMARY${ENDCOLOR}"
    echo

    local system_prompt="You are a senior engineer explaining a set of local, uncommitted code changes to the person who just wrote them. These are working-tree changes from 'git diff' — they are NOT a pull request, so never call them a 'PR' or 'pull request'. Describe what the changes do and their likely intent, then note any risks, bugs, or concerns; refer to 'the changes', not 'you'. Write for a plain-text terminal: do NOT use Markdown (no '#' headings, no '*' or '**' for bold or bullets, no backticks, no tables); put short section labels on their own line ending with a colon, and start each list item on its own line with '- '. Keep it concise."

    local response
    response=$(call_ai_api "$system_prompt" "$diff_content" 2>/dev/null)
    if [ -z "$response" ]; then
        echo -e "${RED}✗ Failed to generate an AI summary${ENDCOLOR}"
        echo -e "Check your AI configuration with ${GREEN}gitb cfg ai${ENDCOLOR}."
        return 1
    fi

    print_ai_summary "$response"
}


### Main script dispatcher for diff commands
function diff_script {
    local mode="$1"

    case "$mode" in
        "staged"|"s"|"cached")
            diff_scope "STAGED CHANGES" --cached
        ;;
        "all"|"a")
            diff_scope "ALL UNCOMMITTED CHANGES" HEAD
        ;;
        "branch"|"b")
            diff_branch
        ;;
        "commit"|"c")
            diff_commit
        ;;
        "ai")
            diff_ai
        ;;
        "help"|"h")
            echo -e "${YELLOW}gitb diff${ENDCOLOR} - Show diffs the gitbasher way"
            echo
            echo -e "${YELLOW}Usage:${ENDCOLOR}"
            echo -e "  gitb diff [mode]"
            echo
            echo -e "${YELLOW}Modes:${ENDCOLOR}"
            echo -e "  ${GREEN}(no mode)${ENDCOLOR}       Overview of uncommitted changes, then pick a file to view"
            echo -e "  ${GREEN}staged, s${ENDCOLOR}       Show staged changes (git diff --cached)"
            echo -e "  ${GREEN}all, a${ENDCOLOR}          Show all uncommitted changes (git diff HEAD)"
            echo -e "  ${GREEN}branch, b${ENDCOLOR}       Compare the current branch with another (interactive)"
            echo -e "  ${GREEN}commit, c${ENDCOLOR}       Show a chosen commit's diff (interactive)"
            echo -e "  ${GREEN}ai${ENDCOLOR}              Summarize uncommitted changes in plain English (AI)"
            echo -e "  ${GREEN}help, h${ENDCOLOR}         Show this help"
            echo
            echo -e "${YELLOW}Examples:${ENDCOLOR}"
            echo -e "  gitb diff"
            echo -e "  gitb diff staged"
            echo -e "  gitb diff all"
            echo -e "  gitb diff branch"
            echo -e "  gitb diff ai"
        ;;
        "")
            diff_worktree_interactive
        ;;
        *)
            wrong_mode "diff" "$mode"
        ;;
    esac
}
