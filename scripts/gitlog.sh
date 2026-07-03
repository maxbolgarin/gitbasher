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

    if [ "$ahead" != "0" ]; then
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
    if [ -n "$branch" ]; then
        echo -e "${YELLOW}Git log for branch: ${BLUE}$branch${ENDCOLOR}"
        git log "$branch" --pretty="%C(Yellow)%h%C(reset) | %C(Cyan)%ad%C(reset) | %C(Blue)%an%C(reset) | %s (%C(Green)%cr%C(reset))"
    else
        git log --pretty="%C(Yellow)%h%C(reset) | %C(Cyan)%ad%C(reset) | %C(Blue)%an%C(reset) | %s (%C(Green)%cr%C(reset))"
    fi
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
            echo -e "${YELLOW}Commits matching hash pattern: '$hash_term'${ENDCOLOR}"
            echo
            git log --grep="$hash_term" --pretty="%C(Yellow)%h%C(reset) | %C(Cyan)%ad%C(reset) | %C(Blue)%an%C(reset) | %s (%C(Green)%cr%C(reset))" --all || \
            git log --oneline --all | grep -i "$hash_term" | head -20 | while read line; do
                hash=$(echo "$line" | cut -d' ' -f1)
                git log --pretty="%C(Yellow)%h%C(reset) | %C(Cyan)%ad%C(reset) | %C(Blue)%an%C(reset) | %s (%C(Green)%cr%C(reset))" -1 "$hash"
            done
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
        "help"|"help")
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
        "help"|"h")
            echo -e "${YELLOW}gitb log${ENDCOLOR} - Git log utilities"
            echo
            echo -e "${YELLOW}Usage:${ENDCOLOR}"
            echo -e "  gitb log [command]"
            echo
            echo -e "${YELLOW}Commands:${ENDCOLOR}"
            echo -e "  ${GREEN}(no command)${ENDCOLOR}   Show log for current branch"
            echo -e "  ${GREEN}branch, b${ENDCOLOR}      View log from different branches"
            echo -e "  ${GREEN}compare, c${ENDCOLOR}     Compare log between two branches"
            echo -e "  ${GREEN}search, s${ENDCOLOR}      Search git log with various criteria"
            echo -e "  ${GREEN}help, h${ENDCOLOR}        Show this help"
            echo
            echo -e "${YELLOW}Examples:${ENDCOLOR}"
            echo -e "  gitb log"
            echo -e "  gitb log branch"
            echo -e "  gitb log branch local"
            echo -e "  gitb log compare"
            echo -e "  gitb log search"
            echo -e "  gitb log search message"
        ;;
        "")
            gitlog
        ;;
        *)
            wrong_mode "log" "$mode"
        ;;
    esac
}
