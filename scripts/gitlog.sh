#!/usr/bin/env bash

### Script for providing info from git log
# Read README.md to get more information how to use it
# Use this script only with gitbasher


### Helper: human-readable description for an unmerged (conflict) XY code
function _status_conflict_desc {
    case "$1" in
        DD) echo "both deleted" ;;
        AU) echo "added by us" ;;
        UD) echo "deleted by them" ;;
        UA) echo "added by them" ;;
        DU) echo "deleted by us" ;;
        AA) echo "both added" ;;
        UU) echo "both modified" ;;
        *)  echo "unmerged" ;;
    esac
}


### Helper: print one indented change row "<glyph> <path>" colored by change code
function _status_row {
    local code="$1"
    local path="$2"
    local glyph color
    case "$code" in
        A|C) glyph="✚"; color="$GREEN" ;;
        M|T) glyph="✎"; color="$YELLOW" ;;
        R)   glyph="✎"; color="$YELLOW" ;;
        D)   glyph="✖"; color="$RED" ;;
        *)   glyph="•"; color="$GRAY" ;;
    esac
    echo -e "  ${color}${glyph} ${path}${ENDCOLOR}"
}


### Function prints working-tree changes grouped into
### Unmerged / Staged / Not staged / Untracked, or a clean message
function status_changes {
    local line x y path
    local staged=()
    local unstaged=()
    local untracked=()
    local unmerged=()

    while IFS= read -r line; do
        [ -z "$line" ] && continue
        x="${line:0:1}"
        y="${line:1:1}"
        path="${line:3}"
        if [ "$x$y" = "??" ]; then
            untracked+=("$path")
        elif [ "$x$y" = "DD" ] || [ "$x$y" = "AA" ] || [ "$x" = "U" ] || [ "$y" = "U" ]; then
            unmerged+=("$x$y|$path")
        else
            if [ "$x" != " " ] && [ "$x" != "?" ]; then
                staged+=("$x|$path")
            fi
            if [ "$y" != " " ] && [ "$y" != "?" ]; then
                unstaged+=("$y|$path")
            fi
        fi
    done < <(LC_ALL=C git -c core.quotePath=false status --porcelain 2>/dev/null)

    local total=$(( ${#staged[@]} + ${#unstaged[@]} + ${#untracked[@]} + ${#unmerged[@]} ))
    if [ "$total" -eq 0 ]; then
        echo -e "${GREEN}✓ Working tree clean${ENDCOLOR}"
        return
    fi

    local e code p

    if [ ${#unmerged[@]} -gt 0 ]; then
        echo -e "${RED}${BOLD}Unmerged${ENDCOLOR} ${GRAY}(${#unmerged[@]})${ENDCOLOR}"
        for e in "${unmerged[@]}"; do
            code="${e%%|*}"
            p="${e#*|}"
            echo -e "  ${RED}✖ $(_status_conflict_desc "$code"): ${p}${ENDCOLOR}"
        done
    fi

    if [ ${#staged[@]} -gt 0 ]; then
        echo -e "${BOLD}Staged${ENDCOLOR} ${GRAY}(${#staged[@]})${ENDCOLOR}"
        for e in "${staged[@]}"; do
            _status_row "${e%%|*}" "${e#*|}"
        done
    fi

    if [ ${#unstaged[@]} -gt 0 ]; then
        echo -e "${BOLD}Not staged${ENDCOLOR} ${GRAY}(${#unstaged[@]})${ENDCOLOR}"
        for e in "${unstaged[@]}"; do
            _status_row "${e%%|*}" "${e#*|}"
        done
    fi

    if [ ${#untracked[@]} -gt 0 ]; then
        echo -e "${BOLD}Untracked${ENDCOLOR} ${GRAY}(${#untracked[@]})${ENDCOLOR}"
        for e in "${untracked[@]}"; do
            echo -e "  ${GRAY}• ${e}${ENDCOLOR}"
        done
    fi
}


### Function prints the branch + upstream line with ahead/behind counts
function status_upstream_line {
    if [ -z "$current_branch" ]; then
        echo -e "${YELLOW}detached${ENDCOLOR} @ ${YELLOW}$(git rev-parse --short HEAD 2>/dev/null)${ENDCOLOR}"
        return
    fi

    local upstream
    upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)
    if [ -z "$upstream" ]; then
        echo -e "${YELLOW}$current_branch${ENDCOLOR}    ${GRAY}⚠ no upstream${ENDCOLOR}"
        return
    fi

    local counts behind ahead
    counts=$(git rev-list --left-right --count "@{u}...HEAD" 2>/dev/null)
    read -r behind ahead <<< "$counts"
    behind="${behind:-0}"
    ahead="${ahead:-0}"

    if [ "$ahead" = "0" ] && [ "$behind" = "0" ]; then
        echo -e "${YELLOW}$current_branch${ENDCOLOR} → ${YELLOW}$upstream${ENDCOLOR}    ${GREEN}✓ up to date${ENDCOLOR}"
        return
    fi

    local updown=""
    if [ "$ahead" != "0" ]; then
        updown="${BOLD}↑${ahead}${ENDCOLOR}"
    fi
    if [ "$behind" != "0" ]; then
        if [ -n "$updown" ]; then updown="$updown "; fi
        updown="${updown}${BOLD}↓${behind}${ENDCOLOR}"
    fi
    echo -e "${YELLOW}$current_branch${ENDCOLOR} → ${YELLOW}$upstream${ENDCOLOR}    ${updown}"
}


### Function prints a stash count line, or nothing when there are no stashes
function status_stash_line {
    local n
    n=$(git stash list 2>/dev/null | wc -l | sed 's/^ *//;s/ *$//')
    if [ -z "$n" ] || [ "$n" -eq 0 ] 2>/dev/null; then
        return
    fi
    local noun="stashes"
    if [ "$n" -eq 1 ] 2>/dev/null; then
        noun="stash"
    fi
    echo -e "${YELLOW}⚑ $n $noun${ENDCOLOR}"
}


### Function prints an in-progress operation banner (merge/rebase/etc.), or nothing
function status_inprogress_line {
    local d
    d=$(git rev-parse --git-dir 2>/dev/null) || return
    local op=""
    if [ -f "$d/MERGE_HEAD" ]; then
        op="Merge"
    elif [ -d "$d/rebase-merge" ] || [ -d "$d/rebase-apply" ]; then
        op="Rebase"
    elif [ -f "$d/CHERRY_PICK_HEAD" ]; then
        op="Cherry-pick"
    elif [ -f "$d/REVERT_HEAD" ]; then
        op="Revert"
    elif [ -f "$d/BISECT_LOG" ]; then
        op="Bisect"
    fi
    if [ -n "$op" ]; then
        echo -e "${YELLOW}⚠  $op in progress${ENDCOLOR}"
    fi
}


### Function prints a single next-step hint based on repo state, or nothing
function status_hint {
    local d
    d=$(git rev-parse --git-dir 2>/dev/null) || return

    if [ -n "$(git ls-files --unmerged 2>/dev/null)" ]; then
        echo -e "${BLUE}→ fix conflicts, then continue${ENDCOLOR}"
        return
    fi
    if [ -f "$d/MERGE_HEAD" ] || [ -d "$d/rebase-merge" ] || [ -d "$d/rebase-apply" ] || [ -f "$d/CHERRY_PICK_HEAD" ]; then
        return
    fi

    local upstream
    upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)
    [ -z "$upstream" ] && return

    local counts behind ahead
    counts=$(git rev-list --left-right --count "@{u}...HEAD" 2>/dev/null)
    read -r behind ahead <<< "$counts"
    behind="${behind:-0}"
    ahead="${ahead:-0}"

    if [ "$ahead" != "0" ] && [ "$behind" != "0" ]; then
        # Diverged: a plain push would be rejected — integrate first
        echo -e "${BLUE}→ diverged (↑$ahead ↓$behind) — run ${GREEN}gitb pull${BLUE} first${ENDCOLOR}"
    elif [ "$ahead" != "0" ]; then
        echo -e "${BLUE}→ ahead $ahead — run ${GREEN}gitb push${ENDCOLOR}"
    elif [ "$behind" != "0" ]; then
        echo -e "${BLUE}→ behind $behind — run ${GREEN}gitb pull${ENDCOLOR}"
    fi
}


### Function prints repo state and changed files (gitb status / s)
# $1: optional "help"
function project_status {
    if [ "$1" = "help" ] || [ "$1" = "h" ]; then
        echo -e "${YELLOW}gitb status${ENDCOLOR} - Show repo state and changed files"
        echo
        echo -e "${YELLOW}Usage:${ENDCOLOR}"
        echo -e "  gitb status"
        echo -e "  gitb s"
        echo
        echo -e "${YELLOW}Shows:${ENDCOLOR}"
        echo -e "  ${GREEN}•${ENDCOLOR} current branch, upstream, and ahead/behind counts"
        echo -e "  ${GREEN}•${ENDCOLOR} in-progress merge/rebase and stashed changes"
        echo -e "  ${GREEN}•${ENDCOLOR} changes grouped into staged / not staged / untracked / unmerged"
        return
    fi

    status_inprogress_line

    local repo_name="$project_name"
    if [ -z "$repo_name" ]; then
        repo_name=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)
    fi
    if [ -n "$repo_url" ]; then
        echo -e "${YELLOW}$repo_name${ENDCOLOR} ${GRAY}·${ENDCOLOR} ${CYAN}$repo_url${ENDCOLOR}"
    elif [ -n "$repo_name" ]; then
        echo -e "${YELLOW}$repo_name${ENDCOLOR}"
    fi

    if git rev-parse --verify HEAD >/dev/null 2>&1; then
        status_upstream_line
        echo -e "${GRAY}●${ENDCOLOR} $(git --no-pager log -n 1 --pretty="%C(Yellow)%h%C(reset)  %s")"
    else
        echo -e "${YELLOW}$current_branch${ENDCOLOR}    ${GRAY}⚠ no upstream${ENDCOLOR}"
        echo -e "${GRAY}No commits yet${ENDCOLOR}"
    fi

    echo
    status_changes

    local stash
    stash=$(status_stash_line)
    if [ -n "$stash" ]; then
        echo
        echo -e "$stash"
    fi

    local hint
    hint=$(status_hint)
    if [ -n "$hint" ]; then
        echo -e "$hint"
    fi
}


### Function opens git log in pretty format
# $1: optional branch name
function gitlog {
    local branch="$1"
    local format="%C(yellow)%h%C(reset)%C(auto)%d%C(reset) | %s | %C(blue)%an%C(reset) | %C(green)%cr%C(reset)"
    if [ -n "$branch" ]; then
        echo -e "${YELLOW}Git log for branch: ${BLUE}$branch${ENDCOLOR}"
        git log "$branch" --pretty="$format"
    else
        git log --pretty="$format"
    fi
}


### Function collects commit hashes for the log browser
# $1: kind of selection
#     * head - current HEAD history
#     * count - last $2 commits
#     * path - history of file $2 (follows renames)
#     * ref - history of ref or range $2
#     * grep - commits with $2 in the message
# $2: value for the kind (count / path / ref / search term)
# Returns:
#     log_browse_hashes - array of short hashes, newest first
#     log_browse_total - number of collected hashes
function log_collect_hashes {
    local kind="$1"
    local value="$2"
    local cap=1000

    log_browse_hashes=()
    log_browse_total=0

    local output
    case "$kind" in
        "head")
            output=$(git --no-pager log -n "$cap" --pretty="%h" 2>/dev/null)
        ;;
        "count")
            if [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -gt "$cap" ]; then
                value="$cap"
            fi
            output=$(git --no-pager log -n "$value" --pretty="%h" 2>/dev/null)
        ;;
        "path")
            output=$(git --no-pager log --follow -n "$cap" --pretty="%h" -- "$value" 2>/dev/null)
        ;;
        "ref")
            output=$(git --no-pager log -n "$cap" --pretty="%h" "$value" 2>/dev/null)
        ;;
        "grep")
            output=$(git --no-pager log -n "$cap" --pretty="%h" -i --grep="$value" 2>/dev/null)
        ;;
    esac

    if [ -z "$output" ]; then
        return
    fi

    local line
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            log_browse_hashes+=("$line")
        fi
    done <<< "$output"
    log_browse_total=${#log_browse_hashes[@]}
}


### Function renders one page of the collected commits as a numbered list
# $1: zero-based index into log_browse_hashes to start from
# $2: how many commits to render
# $3: non-empty to mark commits missing from the upstream with ↑
# Uses log_browse_hashes filled by log_collect_hashes
function log_commit_list {
    local start="$1"
    local count="$2"
    local mark_unpushed="$3"

    local total=${#log_browse_hashes[@]}
    if [ "$total" -eq 0 ]; then
        return
    fi

    local end=$((start + count))
    if [ "$end" -gt "$total" ]; then
        end=$total
    fi

    local page_hashes=()
    local i
    for ((i = start; i < end; i++)); do
        page_hashes+=("${log_browse_hashes[i]}")
    done
    if [ ${#page_hashes[@]} -eq 0 ]; then
        return
    fi

    local unpushed=""
    if [ -n "$mark_unpushed" ] && git rev-parse --verify --quiet "@{u}" >/dev/null 2>&1; then
        unpushed=$(git --no-pager rev-list --abbrev-commit "@{u}..HEAD" 2>/dev/null | tr '\n' ' ')
    fi

    # Colors as real escape bytes: awk -v mangles the backslash in the *_ES
    # vars and printf below does not interpret \x1b like echo -e would.
    local hash_color deco_color author_color time_color end_color
    hash_color=$(printf '%b' "$YELLOW_ES")
    deco_color="$hash_color"
    author_color=$(printf '%b' "$BLUE_ES")
    time_color=$(printf '%b' "$GREEN_ES")
    end_color=$(printf '%b' "$ENDCOLOR_ES")

    # %x1f field separators keep subjects containing '|' from breaking the
    # columns; awk re-emits '|' only as the column separator.
    local rows
    # ctrl strips ANSI/OSC bytes a fetched commit subject could inject into
    # the terminal; torn repairs a trailing UTF-8 sequence cut mid-character
    # (length/substr are byte-based on macOS awk, and one torn byte makes
    # BSD column silently drop that row and every row after it).
    rows=$(git --no-pager log --no-walk=unsorted --pretty="%h%x1f%s%x1f%d%x1f%an%x1f%cr" "${page_hashes[@]}" 2>/dev/null | \
        LC_ALL=C awk -v hash_c="$hash_color" -v deco_c="$deco_color" -v author_c="$author_color" -v time_c="$time_color" -v end_c="$end_color" \
            -v ctrl='[\001-\010\013-\037\177]' -v torn='[\300-\367][\200-\277]*$' '
        BEGIN { FS = "\037" }
        {
            subj = $2
            gsub(ctrl, "", subj)
            gsub(/\|/, "¦", subj)
            if (length(subj) > 60) {
                subj = substr(subj, 1, 57)
                sub(torn, "", subj)
                subj = subj "..."
            }
            deco = $3
            gsub(ctrl, "", deco)
            gsub(/^[ \t]+|[ \t]+$/, "", deco)
            if (deco != "") subj = subj " " deco_c deco end_c
            an = $4
            gsub(ctrl, "", an)
            print hash_c $1 end_c "|" subj "|" author_c an end_c "|" time_c $5 end_c
        }' | column -ts'|')

    local index=$start
    local row_index=0
    local line mark hash
    while IFS= read -r line; do
        if [ -z "$line" ]; then
            continue
        fi
        hash="${page_hashes[row_index]}"
        mark=" "
        if [ -n "$unpushed" ]; then
            case " $unpushed " in
                *" $hash "*) mark="↑" ;;
            esac
        fi
        index=$((index + 1))
        row_index=$((row_index + 1))
        printf "%2d. %s %s\n" "$index" "$mark" "$line"
    done <<< "$rows"
}


### Function copies a commit hash to the clipboard (prints it as a fallback)
# $1: commit hash (short or full) - the full hash is what gets copied
function log_copy_hash {
    local full_hash
    full_hash=$(git rev-parse "$1" 2>/dev/null)
    if [ -z "$full_hash" ]; then
        full_hash="$1"
    fi

    local tool=""
    if command -v pbcopy >/dev/null 2>&1; then
        tool="pbcopy"
    elif command -v wl-copy >/dev/null 2>&1; then
        tool="wl-copy"
    elif command -v xclip >/dev/null 2>&1; then
        tool="xclip -selection clipboard"
    elif command -v clip.exe >/dev/null 2>&1; then
        tool="clip.exe"
    fi

    if [ -n "$tool" ]; then
        # $tool is unquoted on purpose: it can carry arguments (xclip)
        printf '%s' "$full_hash" | $tool
        echo -e "${GREEN}✓ Copied ${YELLOW}${full_hash}${ENDCOLOR}${GREEN} to clipboard${ENDCOLOR}"
    else
        echo -e "${YELLOW}No clipboard tool found - copy it manually:${ENDCOLOR}"
        echo "$full_hash"
    fi
}


### Function shows one commit and offers actions on it
# $1: commit hash
function log_commit_actions {
    local hash="$1"
    local choice result

    git show "$hash"

    while true; do
        echo
        echo -e "${YELLOW}Commit ${hash}${ENDCOLOR} - choose an action:"
        echo -e "1. Show diff again"
        echo -e "2. Show stat"
        echo -e "3. Copy hash"
        echo -e "4. Revert this commit"
        echo -e "5. Cherry-pick into the current branch"
        echo -e "6. Fixup: commit staged changes into it"
        echo -e "7. Restore a file from this commit"
        echo -e "0. Back to the commit list"
        echo

        # read_key: a single arrow-key press arrives as one token instead of
        # three keystrokes (Esc, [, letter) triggering three error rounds
        if ! read_key choice; then
            return
        fi
        normalize_key "$choice"
        choice="$normalized_key"

        case "$choice" in
            "1")
                git show "$hash"
            ;;
            "2")
                echo
                print_changes_stat "$(git --no-pager show --stat --format="" "$hash")"
            ;;
            "3")
                echo
                log_copy_hash "$hash"
            ;;
            "4")
                echo
                if [ -n "$(LC_ALL=C git status --porcelain 2>/dev/null)" ]; then
                    echo -e "${RED}✗ Cannot revert - there are uncommitted changes.${ENDCOLOR}"
                    echo -e "Commit or stash them first."
                    continue
                fi
                result=$(git revert --no-edit "$hash" 2>&1)
                check_code $? "$result" "revert"
                after_commit "revert"
                return
            ;;
            "5")
                echo
                perform_cherry_pick "$hash"
                return
            ;;
            "6")
                echo
                if [ -z "$(git -c core.quotePath=false diff --name-only --cached 2>/dev/null)" ]; then
                    echo -e "${RED}✗ No staged changes - stage the files to fix up first.${ENDCOLOR}"
                    continue
                fi
                result=$(git commit --fixup "$hash" 2>&1)
                check_code $? "$result" "fixup"
                echo -e "${GREEN}✓ Created $(git log -1 --pretty=%s)${ENDCOLOR}"
                echo -e "Squash it into place: ${YELLOW}gitb rebase autosquash${ENDCOLOR}"
                return
            ;;
            "7")
                echo
                local files=()
                local file_line
                while IFS= read -r file_line; do
                    if [ -n "$file_line" ]; then
                        files+=("$file_line")
                    fi
                done < <(git -c core.quotePath=false --no-pager show --name-only --format="" "$hash" 2>/dev/null)
                if [ ${#files[@]} -eq 0 ]; then
                    echo -e "${YELLOW}This commit does not touch any files${ENDCOLOR}"
                    continue
                fi

                echo -e "${YELLOW}Select a file to restore from ${hash}:${ENDCOLOR}"
                local file_index
                for ((file_index = 0; file_index < ${#files[@]}; file_index++)); do
                    printf "%2d. %s\n" "$((file_index + 1))" "${files[file_index]}"
                done
                echo " 0. Cancel"
                echo

                if ! read -r -p "Enter file number: " choice; then
                    echo
                    continue
                fi
                if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#files[@]} ]; then
                    continue
                fi
                # 10# so "09" is decimal, not an invalid-octal bash error
                choice=$((10#$choice))

                local file="${files[choice - 1]}"
                echo -e "${RED}This will overwrite '${file}' in your working tree with its state from ${hash}.${ENDCOLOR}"
                printf "Restore it (y/N)? "
                # Overwrites working-tree content: require an explicit "y"
                if confirm_destructive; then
                    result=$(git checkout "$hash" -- "$file" 2>&1)
                    check_code $? "$result" "restore"
                    echo -e "${GREEN}✓ Restored ${file} from ${hash}${ENDCOLOR}"
                fi
            ;;
            ""|"0"|"q")
                return
            ;;
            *)
                echo -e "${RED}✗ Unknown action: $choice${ENDCOLOR}"
            ;;
        esac
    done
}


### Function resolves a free-form log argument into a browser mode
# Precedence: commit count, then file path, then ref/range, then message search
# $1: the argument to resolve
# $@: with several words everything is searched as one message phrase
function log_smart_dispatch {
    local arg="$1"

    # Multiple words are always one search phrase. Probing only the first
    # word used to silently drop the rest: "gitb log docs update" opened
    # the docs/ file history and discarded "update".
    if [ $# -eq 1 ]; then

    if [[ "$arg" =~ ^[0-9]+$ ]]; then
        if [ "$arg" -eq 0 ]; then
            echo -e "${RED}✗ '0' is not a valid number of commits${ENDCOLOR}"
            return
        fi
        gitlog_browse "LAST $arg COMMITS" "count" "$arg"
        return
    fi

    # A path that exists now, or one that only past commits know about
    if [ -e "$arg" ] || [ -n "$(git --no-pager log --oneline -1 -- "$arg" 2>/dev/null)" ]; then
        gitlog_browse "FILE HISTORY: $arg" "path" "$arg"
        return
    fi

    # One plumbing call validates plain refs, a..b, a...b and HEAD~N alike
    if git rev-list -n 1 "$arg" -- >/dev/null 2>&1; then
        gitlog_browse "LOG: $arg" "ref" "$arg"
        return
    fi

    fi

    local term="$*"
    if ! sanitize_text_input "$term" 200; then
        show_sanitization_error "search term" "Use printable characters only, max 200 characters."
        return
    fi
    term="$sanitized_text"

    log_collect_hashes "grep" "$term"
    if [ "$log_browse_total" -eq 0 ]; then
        echo -e "${YELLOW}No commits found matching '${term}'${ENDCOLOR}"
        return
    fi
    gitlog_browse "COMMITS MATCHING '$term'" "grep" "$term"
}


### Function runs the interactive commit browser: a paginated numbered list
### where picking a commit opens it with an action menu
# $1: title to print above the list
# $2: kind of selection for log_collect_hashes
# $3: optional value for the kind
function gitlog_browse {
    local title="$1"
    local kind="$2"
    local value="$3"

    local page_size
    page_size=$(get_config_value gitbasher.log-count "20")
    if ! [[ "$page_size" =~ ^[1-9][0-9]*$ ]]; then
        page_size=20
    fi

    local mark=""
    if [ "$kind" == "head" ] || [ "$kind" == "count" ]; then
        mark="mark_unpushed"
    fi

    log_collect_hashes "$kind" "$value"
    if [ "$log_browse_total" -eq 0 ]; then
        echo -e "${YELLOW}No commits to show${ENDCOLOR}"
        return
    fi

    local total_pages=$(((log_browse_total + page_size - 1) / page_size))
    local page=0
    local choice

    while true; do
        echo -e "${YELLOW}${title}${ENDCOLOR} ${GRAY}|${ENDCOLOR} ${BLUE}${current_branch}${ENDCOLOR} ${GRAY}|${ENDCOLOR} ${log_browse_total} commits"
        echo
        log_commit_list "$((page * page_size))" "$page_size" "$mark"
        echo
        if [ "$total_pages" -gt 1 ]; then
            echo -e "${GRAY}Page $((page + 1))/${total_pages}${ENDCOLOR} - enter a commit number to open it, ${BLUE}n${ENDCOLOR} next page, ${BLUE}p${ENDCOLOR} previous page, ${BLUE}0${ENDCOLOR} exit"
        else
            echo -e "Enter a commit number to open it, ${BLUE}0${ENDCOLOR} to exit"
        fi

        if ! read -r -e -p "Commit number: " choice; then
            echo
            return
        fi
        normalize_key "$choice"
        choice="$normalized_key"

        case "$choice" in
            ""|"0"|"00"|"q")
                return
            ;;
            "n")
                if [ "$((page + 1))" -lt "$total_pages" ]; then
                    page=$((page + 1))
                fi
                echo
                continue
            ;;
            "p")
                if [ "$page" -gt 0 ]; then
                    page=$((page - 1))
                fi
                echo
                continue
            ;;
        esac

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$log_browse_total" ]; then
            echo
            # 10# so "09" is decimal, not an invalid-octal bash error
            choice=$((10#$choice))
            log_commit_actions "${log_browse_hashes[choice - 1]}"
            # An action could have rewritten history (revert, fixup) - refresh
            log_collect_hashes "$kind" "$value"
            if [ "$log_browse_total" -eq 0 ]; then
                return
            fi
            total_pages=$(((log_browse_total + page_size - 1) / page_size))
            if [ "$page" -ge "$total_pages" ]; then
                page=$((total_pages - 1))
            fi
            echo
        else
            echo -e "${RED}✗ No commit with number '$choice'${ENDCOLOR}"
            echo
        fi
    done
}


### Function to show git log from a specific branch with interactive selection
function gitlog_branch {
    local mode="$1"
    
    case "$mode" in
        "local"|"l")
            echo -e "${YELLOW}GIT LOG BRANCH LOCAL${ENDCOLOR}"
            echo
            echo -e "${YELLOW}Select a local branch to view git log:${ENDCOLOR}"
            choose_branch
        ;;
        "remote"|"r")
            echo -e "${YELLOW}GIT LOG BRANCH REMOTE${ENDCOLOR}"
            echo
            echo -e "${YELLOW}Select a remote branch to view git log:${ENDCOLOR}"
            choose_branch "remote"
        ;;
        "all"|"a"|"")
            echo -e "${YELLOW}GIT LOG BRANCH${ENDCOLOR}"
            echo
            echo -e "${YELLOW}Select a branch to view git log:${ENDCOLOR}"
            choose_branch
        ;;
        "help"|"h")
            echo -e "${YELLOW}gitb log branch${ENDCOLOR} - View git log from different branches"
            echo
            echo -e "${YELLOW}Usage:${ENDCOLOR}"
            echo -e "  gitb log branch [mode]"
            echo
            echo -e "${YELLOW}Modes:${ENDCOLOR}"
            echo -e "  ${GREEN}local, l${ENDCOLOR}     Show log from local branches"
            echo -e "  ${GREEN}remote, r${ENDCOLOR}    Show log from remote branches"
            echo -e "  ${GREEN}all, a${ENDCOLOR}       Show log from all branches (default)"
            echo -e "  ${GREEN}help, h${ENDCOLOR}      Show this help"
            return
        ;;
        *)
            echo -e "${RED}✗ Unknown mode: $mode${ENDCOLOR}"
            echo -e "Run ${GREEN}gitb log branch help${ENDCOLOR} to see available modes."
            return
        ;;
    esac

    # If to_exit is set by choose_branch, exit gracefully
    if [ -n "$to_exit" ]; then
        return
    fi

    if [ -n "$branch_name" ]; then
        echo
        gitlog "$branch_name"
    fi
}


### Function to compare git log between two branches
function gitlog_compare {
    echo -e "${YELLOW}GIT LOG COMPARE${ENDCOLOR}"
    echo
    echo -e "${YELLOW}Select first branch:${ENDCOLOR}"
    choose_branch
    
    # If to_exit is set by choose_branch, exit gracefully
    if [ -n "$to_exit" ]; then
        return
    fi
    
    if [ -z "$branch_name" ]; then
        return
    fi
    
    local first_branch="$branch_name"
    
    echo
    echo -e "${YELLOW}Select second branch:${ENDCOLOR}"
    choose_branch
    
    # If to_exit is set by choose_branch, exit gracefully
    if [ -n "$to_exit" ]; then
        return
    fi
    
    if [ -n "$branch_name" ]; then
        local second_branch="$branch_name"
        echo
        echo -e "${YELLOW}Commits in '$first_branch' but not in '$second_branch':${ENDCOLOR}"
        echo
        git log "$second_branch..$first_branch" --pretty="%C(Yellow)%h%C(reset) | %C(Cyan)%ad%C(reset) | %C(Blue)%an%C(reset) | %s (%C(Green)%cr%C(reset))" --oneline
        echo
        echo -e "${YELLOW}Commits in '$second_branch' but not in '$first_branch':${ENDCOLOR}"
        echo
        git log "$first_branch..$second_branch" --pretty="%C(Yellow)%h%C(reset) | %C(Cyan)%ad%C(reset) | %C(Blue)%an%C(reset) | %s (%C(Green)%cr%C(reset))" --oneline
    fi
}


### Function opens git reflog in pretty format
function reflog {
    git reflog --pretty="%C(Yellow)%h%C(reset) | %C(Blue)%gd%C(reset) | %C(Cyan)%ad%C(reset) | %gs (%C(Green)%cr%C(reset))"
}


### Function prints last commit info (from git log)
function last_commit {
    git --no-pager log -n 1 --pretty="%C(Yellow)%h%C(reset) | %s | %C(Blue)%an%C(reset) | %C(Green)%cr%C(reset) | %C(Cyan)%ad%C(reset)" 
}


### Function prints last action info (from git reflog)
function last_ref {
    git --no-pager reflog -n 1 --pretty="%C(Yellow)%h%C(reset) | %C(Cyan)%gd%C(reset) | %gs | %C(Green)%cr%C(reset) | %C(Cyan)%ad%C(reset)"
}


### Function resolves an AI summary argument into a git revision range
# $1: optional argument:
#     * empty or "tag" - commits since the last tag (entire history if none)
#     * a number - the last N commits
#     * "unpushed" - commits missing from the upstream
#     * a..b range or a single ref (meaning <ref>..HEAD)
# Returns:
#     log_ai_range - the resolved revision range
#     log_ai_range_label - human-readable description of the range
function log_resolve_ai_range {
    local arg="$1"
    log_ai_range=""
    log_ai_range_label=""

    if [ -z "$arg" ] || [ "$arg" == "tag" ]; then
        local last_tag
        last_tag=$(git describe --tags --abbrev=0 HEAD 2>/dev/null)
        if [ -n "$last_tag" ]; then
            log_ai_range="${last_tag}..HEAD"
            log_ai_range_label="since tag $last_tag"
        else
            log_ai_range="HEAD"
            log_ai_range_label="entire history (no tags found)"
        fi
        return 0
    fi

    if [[ "$arg" =~ ^[0-9]+$ ]] && [ "$arg" -gt 0 ]; then
        if git rev-parse --verify --quiet "HEAD~$arg" >/dev/null 2>&1; then
            log_ai_range="HEAD~$arg..HEAD"
        else
            log_ai_range="HEAD"
        fi
        log_ai_range_label="last $arg commits"
        return 0
    fi

    if [ "$arg" == "unpushed" ]; then
        if ! git rev-parse --verify --quiet "@{u}" >/dev/null 2>&1; then
            echo -e "${RED}✗ No upstream configured for this branch${ENDCOLOR}"
            return 1
        fi
        log_ai_range="@{u}..HEAD"
        log_ai_range_label="unpushed commits"
        return 0
    fi

    if git rev-list -n 1 "$arg" -- >/dev/null 2>&1; then
        if [[ "$arg" == *".."* ]]; then
            log_ai_range="$arg"
            log_ai_range_label="range $arg"
        else
            log_ai_range="${arg}..HEAD"
            log_ai_range_label="since $arg"
        fi
        return 0
    fi

    echo -e "${RED}✗ Cannot resolve '$arg' as a commit range${ENDCOLOR}"
    return 1
}


### Function summarizes a range of commits in plain text using the AI engine
# $1: optional range argument (see log_resolve_ai_range); prompts when empty
function gitlog_ai {
    local arg="$1"

    if [ -z "$arg" ]; then
        echo -e "${YELLOW}AI LOG SUMMARY${ENDCOLOR}"
        echo
        echo -e "${YELLOW}What should be summarized?${ENDCOLOR}"
        echo "1. Commits since the last tag (default)"
        echo "2. Unpushed commits"
        echo "3. Last N commits"
        echo "4. Commits in one branch but not in another"
        echo "0. Exit"
        echo

        local menu_choice
        read_key menu_choice || prompt_aborted
        normalize_key "$menu_choice"
        menu_choice="$normalized_key"

        case "$menu_choice" in
            ""|"1")
                arg=""
            ;;
            "2")
                arg="unpushed"
            ;;
            "3")
                local n
                read_editable_input n "How many commits? "
                if ! [[ "$n" =~ ^[1-9][0-9]*$ ]]; then
                    echo -e "${RED}✗ Not a valid number of commits${ENDCOLOR}"
                    return
                fi
                arg="$n"
            ;;
            "4")
                echo -e "${YELLOW}Select the branch with the commits to summarize:${ENDCOLOR}"
                choose_branch
                if [ -n "$to_exit" ] || [ -z "$branch_name" ]; then
                    return
                fi
                local first_branch="$branch_name"
                echo
                echo -e "${YELLOW}Select the branch to compare against:${ENDCOLOR}"
                choose_branch
                if [ -n "$to_exit" ] || [ -z "$branch_name" ]; then
                    return
                fi
                arg="${branch_name}..${first_branch}"
            ;;
            "0")
                return
            ;;
            *)
                echo -e "${RED}✗ Invalid choice${ENDCOLOR}"
                return
            ;;
        esac
        echo
    fi

    if ! log_resolve_ai_range "$arg"; then
        return 1
    fi

    local commits_summary
    commits_summary=$(get_commit_messages_for_ai_range "$log_ai_range")
    if [ -z "$commits_summary" ]; then
        echo -e "${GREEN}No commits to summarize (${log_ai_range_label})${ENDCOLOR}"
        return
    fi

    # check_ai_available prints its own "configure with gitb cfg ai" hint.
    if ! check_ai_available; then
        return 1
    fi

    echo -e "${YELLOW}AI LOG SUMMARY${ENDCOLOR} ${GRAY}|${ENDCOLOR} ${BLUE}${log_ai_range_label}${ENDCOLOR}"
    echo

    local system_prompt="You are a senior engineer summarizing a series of git commits for a teammate. You will receive commit subjects prefixed with their hashes, newest first, and possibly an overall change-size line. Group related commits into themes, state what changed and why it matters, and call out anything that looks risky or breaking. This is a commit history - never call it a 'PR', 'pull request' or 'release notes'. Write for a plain-text terminal: do NOT use Markdown (no '#' headings, no '*' or '**' for bold or bullets, no backticks, no tables); put short section labels on their own line ending with a colon, and start each list item on its own line with '- '. Keep it concise."

    local response
    response=$(call_ai_api "$system_prompt" "$commits_summary")
    if [ -z "$response" ]; then
        echo -e "${RED}✗ Failed to generate an AI summary${ENDCOLOR}"
        echo -e "Check your AI configuration with ${GREEN}gitb cfg ai${ENDCOLOR}."
        return 1
    fi

    print_ai_summary "$response"
}


### Function to search git log with various criteria
function gitlog_search {
    local search_mode="$1"
    
    case "$search_mode" in
        "message"|"msg"|"m")
            echo -e "${YELLOW}GIT LOG SEARCH BY MESSAGE${ENDCOLOR}"
            echo
            echo -e "${YELLOW}Search commits by message content:${ENDCOLOR}"
            echo -e "Press Enter to exit without changes"
            
            read_editable_input search_term "Enter search term: "
            if [ -z "$search_term" ]; then
                return
            fi
            
            # Sanitize search term
            if ! sanitize_text_input "$search_term" 200; then
                show_sanitization_error "search term" "Use printable characters only, max 200 characters."
                return
            fi
            search_term="$sanitized_text"
            
            echo
            echo -e "${YELLOW}Commits matching message: '$search_term'${ENDCOLOR}"
            echo
            git log --grep="$search_term" --pretty="%C(Yellow)%h%C(reset) | %C(Cyan)%ad%C(reset) | %C(Blue)%an%C(reset) | %s (%C(Green)%cr%C(reset))" -i
        ;;
        "author"|"a")
            echo -e "${YELLOW}GIT LOG SEARCH BY AUTHOR${ENDCOLOR}"
            echo
            echo -e "${YELLOW}Search commits by author name or email:${ENDCOLOR}"
            echo -e "Press Enter to exit without changes"
            
            read_editable_input author_term "Enter author name or email: "
            if [ -z "$author_term" ]; then
                return
            fi
            
            # Sanitize author term
            if ! sanitize_text_input "$author_term" 100; then
                show_sanitization_error "author name" "Use printable characters only, max 100 characters."
                return
            fi
            author_term="$sanitized_text"
            
            echo
            echo -e "${YELLOW}Commits by author: '$author_term'${ENDCOLOR}"
            echo
            git log --author="$author_term" --pretty="%C(Yellow)%h%C(reset) | %C(Cyan)%ad%C(reset) | %C(Blue)%an%C(reset) | %s (%C(Green)%cr%C(reset))" -i
        ;;
        "file"|"f")
            echo -e "${YELLOW}GIT LOG SEARCH BY FILE${ENDCOLOR}"
            echo
            echo -e "${YELLOW}Search commits that modified specific file(s):${ENDCOLOR}"
            echo -e "Press Enter to exit without changes"
            
            read_editable_input file_path "Enter file path or pattern: "
            if [ -z "$file_path" ]; then
                return
            fi
            
            # Sanitize file path
            if ! sanitize_file_path "$file_path"; then
                show_sanitization_error "file path" "Invalid file path or pattern."
                return
            fi
            file_path="$sanitized_file_path"
            
            echo
            echo -e "${YELLOW}Commits that modified: '$file_path'${ENDCOLOR}"
            echo
            git log --follow --pretty="%C(Yellow)%h%C(reset) | %C(Cyan)%ad%C(reset) | %C(Blue)%an%C(reset) | %s (%C(Green)%cr%C(reset))" -- "$file_path"
        ;;
        "content"|"pickaxe"|"p")
            echo -e "${YELLOW}GIT LOG SEARCH BY CONTENT CHANGES${ENDCOLOR}"
            echo
            echo -e "${YELLOW}Search commits that added or removed specific content:${ENDCOLOR}"
            echo -e "Press Enter to exit without changes"
            
            read_editable_input content_term "Enter content to search for: "
            if [ -z "$content_term" ]; then
                return
            fi
            
            # Sanitize content term
            if ! sanitize_text_input "$content_term" 200; then
                show_sanitization_error "content term" "Use printable characters only, max 200 characters."
                return
            fi
            content_term="$sanitized_text"
            
            echo
            echo -e "${YELLOW}Commits that added/removed: '$content_term'${ENDCOLOR}"
            echo
            git log -S"$content_term" --pretty="%C(Yellow)%h%C(reset) | %C(Cyan)%ad%C(reset) | %C(Blue)%an%C(reset) | %s (%C(Green)%cr%C(reset))"
        ;;
        "date"|"d")
            echo -e "${YELLOW}GIT LOG SEARCH BY DATE RANGE${ENDCOLOR}"
            echo
            echo -e "${YELLOW}Search commits within a date range:${ENDCOLOR}"
            echo -e "Date formats: YYYY-MM-DD, '2 weeks ago', 'yesterday', etc."
            echo -e "Press Enter to skip a field"
            
            read_editable_input since_date "Since (start date): "
            read_editable_input until_date "Until (end date): "
            
            if [ -z "$since_date" ] && [ -z "$until_date" ]; then
                echo -e "${YELLOW}No date range specified${ENDCOLOR}"
                return
            fi
            
            local date_args=()
            if [ -n "$since_date" ]; then
                # Sanitize date input
                if ! sanitize_text_input "$since_date" 50; then
                    show_sanitization_error "date" "Invalid date format."
                    return
                fi
                date_args+=("--since=$sanitized_text")
            fi

            if [ -n "$until_date" ]; then
                # Sanitize date input
                if ! sanitize_text_input "$until_date" 50; then
                    show_sanitization_error "date" "Invalid date format."
                    return
                fi
                date_args+=("--until=$sanitized_text")
            fi

            echo
            echo -e "${YELLOW}Commits in date range:${ENDCOLOR}"
            echo
            git log "${date_args[@]}" --pretty="%C(Yellow)%h%C(reset) | %C(Cyan)%ad%C(reset) | %C(Blue)%an%C(reset) | %s (%C(Green)%cr%C(reset))"
        ;;
        "hash"|"commit"|"h")
            echo -e "${YELLOW}GIT LOG SEARCH BY COMMIT HASH${ENDCOLOR}"
            echo
            echo -e "${YELLOW}Search for commits by hash pattern:${ENDCOLOR}"
            echo -e "Press Enter to exit without changes"
            
            read_editable_input hash_term "Enter commit hash (full or partial): "
            if [ -z "$hash_term" ]; then
                return
            fi
            
            # Sanitize hash input (only allow hex characters)
            if [[ ! "$hash_term" =~ ^[a-fA-F0-9]+$ ]]; then
                echo -e "${RED}✗ Invalid commit hash format. Use only hexadecimal characters.${ENDCOLOR}"
                return
            fi
            
            if [ ${#hash_term} -lt 4 ]; then
                echo -e "${RED}✗ Hash too short — use at least 4 characters.${ENDCOLOR}"
                return
            fi
            
            echo
            echo -e "${YELLOW}Commit matching hash: '$hash_term'${ENDCOLOR}"
            echo
            if ! git --no-pager log -1 "$hash_term" --pretty="%C(yellow)%h%C(reset)%C(auto)%d%C(reset) | %s | %C(blue)%an%C(reset) | %C(green)%cr%C(reset)" -- 2>/dev/null; then
                echo -e "${RED}✗ No commit found for hash '$hash_term'${ENDCOLOR}"
            fi
        ;;
        "interactive"|"i"|"")
            echo -e "${YELLOW}GIT LOG INTERACTIVE SEARCH${ENDCOLOR}"
            echo
            echo -e "${YELLOW}Select search type:${ENDCOLOR}"
            echo
            echo "1. Search by commit message"
            echo "2. Search by author"
            echo "3. Search by file changes"
            echo "4. Search by content changes (pickaxe)"
            echo "5. Search by date range"
            echo "6. Search by commit hash"
            echo "0. Exit"
            echo
            
            read -n 1 -p "Enter your choice: " choice
            echo
            echo
            
            case "$choice" in
                "1") gitlog_search "message" ;;
                "2") gitlog_search "author" ;;
                "3") gitlog_search "file" ;;
                "4") gitlog_search "content" ;;
                "5") gitlog_search "date" ;;
                "6") gitlog_search "hash" ;;
                "0") return ;;
                *) 
                    echo -e "${RED}✗ Invalid choice.${ENDCOLOR}"
                    return
                ;;
            esac
        ;;
        "help")
            echo -e "${YELLOW}gitb log search${ENDCOLOR} - Search git log with various criteria"
            echo
            echo -e "${YELLOW}Usage:${ENDCOLOR}"
            echo -e "  gitb log search [mode]"
            echo
            echo -e "${YELLOW}Search Modes:${ENDCOLOR}"
            echo -e "  ${GREEN}interactive, i${ENDCOLOR}   Interactive search menu (default)"
            echo -e "  ${GREEN}message, msg, m${ENDCOLOR}  Search by commit message content"
            echo -e "  ${GREEN}author, a${ENDCOLOR}        Search by author name or email"
            echo -e "  ${GREEN}file, f${ENDCOLOR}          Search by file changes"
            echo -e "  ${GREEN}content, p${ENDCOLOR}       Search by content changes (pickaxe search)"
            echo -e "  ${GREEN}date, d${ENDCOLOR}          Search by date range"
            echo -e "  ${GREEN}hash, h${ENDCOLOR}          Search by commit hash pattern"
            echo -e "  ${GREEN}help${ENDCOLOR}             Show this help"
            echo
            echo -e "${YELLOW}Examples:${ENDCOLOR}"
            echo -e "  gitb log search"
            echo -e "  gitb log search message"
            echo -e "  gitb log search author"
            echo -e "  gitb log search file"
        ;;
        *)
            echo -e "${RED}✗ Unknown search mode: $search_mode${ENDCOLOR}"
            echo -e "Use ${GREEN}gitb log search help${ENDCOLOR} to see available modes"
        ;;
    esac
}


### Main script dispatcher for gitlog commands
function gitlog_script {
    local mode="$1"
    
    case "$mode" in
        "branch"|"b")
            gitlog_branch "$2"
        ;;
        "compare"|"comp"|"c")
            gitlog_compare
        ;;
        "search"|"s")
            gitlog_search "$2"
        ;;
        "all"|"dump")
            gitlog "$2"
        ;;
        "ai")
            gitlog_ai "$2"
        ;;
        "help"|"h")
            echo -e "${YELLOW}gitb log${ENDCOLOR} - Git log utilities"
            echo
            echo -e "${YELLOW}Usage:${ENDCOLOR}"
            echo -e "  gitb log [command]"
            echo
            echo -e "${YELLOW}Commands:${ENDCOLOR}"
            echo -e "  ${GREEN}(no command)${ENDCOLOR}   Interactive commit browser: pick a commit to view and act on it"
            echo -e "  ${GREEN}all, dump${ENDCOLOR}      Print the full log for the current branch"
            echo -e "  ${GREEN}branch, b${ENDCOLOR}      View log from different branches"
            echo -e "  ${GREEN}compare, c${ENDCOLOR}     Compare log between two branches"
            echo -e "  ${GREEN}search, s${ENDCOLOR}      Search git log with various criteria"
            echo -e "  ${GREEN}ai${ENDCOLOR}             Summarize a range of commits with AI (since last tag, unpushed, ...)"
            echo -e "  ${GREEN}help, h${ENDCOLOR}        Show this help"
            echo
            echo -e "${YELLOW}Anything else is resolved automatically:${ENDCOLOR}"
            echo -e "  ${GREEN}a number${ENDCOLOR}       Browse the last N commits (gitb log 20)"
            echo -e "  ${GREEN}a path${ENDCOLOR}         Browse the file's history across renames (gitb log scripts/gitb.sh)"
            echo -e "  ${GREEN}a ref/range${ENDCOLOR}    Browse that branch or range (gitb log main..feature)"
            echo -e "  ${GREEN}other words${ENDCOLOR}    Search commit messages (gitb log fix teapot)"
            echo
            echo -e "${YELLOW}Examples:${ENDCOLOR}"
            echo -e "  gitb log"
            echo -e "  gitb log 20"
            echo -e "  gitb log scripts/common.sh"
            echo -e "  gitb log main..feature"
            echo -e "  gitb log all"
            echo -e "  gitb log branch local"
            echo -e "  gitb log compare"
            echo -e "  gitb log search message"
        ;;
        "")
            # The browser needs a terminal on both ends: with piped stdout it
            # would render pages into the pipe and block on an invisible
            # prompt; with piped stdin it can't be driven. Fall back to the
            # plain log so `gitb log | grep ...` behaves like git log.
            if [ ! -t 0 ] || [ ! -t 1 ]; then
                gitlog
            else
                gitlog_browse "GIT LOG" "head"
            fi
        ;;
        *)
            log_smart_dispatch "$@"
        ;;
    esac
}
