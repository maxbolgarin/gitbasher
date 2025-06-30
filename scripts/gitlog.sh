#!/usr/bin/env bash

### Script for providing info from git log
# Read README.md to get more information how to use it
# Use this script only with gitbasher


function project_status {
    echo -e "${YELLOW}$project_name${ENDCOLOR} | ${CYAN}$repo_url${ENDCOLOR}"
    echo
    echo -e "${YELLOW}[$current_branch $(git log -n 1 --pretty="%h")]${ENDCOLOR}"
    echo -e "$(git --no-pager log -n 1 --pretty="%s")"
    echo -e "=============================="

    status=$(git_status)
    if [ -n "$status" ]; then
        
        echo -e "$status"
    else
        echo -e "${GREEN}There are no unstaged files${ENDCOLOR}"
    fi
}


### Function opens git log in pretty format
# $1: optional branch name
function gitlog {
    local branch="$1"
    if [ -n "$branch" ]; then
        echo -e "${YELLOW}Git log for branch: ${BLUD}$branch${ENDCOLOR}"
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
            echo -e "${RED}Unknown mode: $mode${ENDCOLOR}"
            echo -e "Use ${GREEN}gitb log branch help${ENDCOLOR} to see available modes"
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
            echo -e "Press Enter to exit"
            
            read -p "Enter search term: " -e search_term
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
            echo -e "Press Enter to exit"
            
            read -p "Enter author name or email: " -e author_term
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
            echo -e "Press Enter to exit"
            
            read -p "Enter file path or pattern: " -e file_path
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
            echo -e "Press Enter to exit"
            
            read -p "Enter content to search for: " -e content_term
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
            
            read -p "Since (start date): " -e since_date
            read -p "Until (end date): " -e until_date
            
            if [ -z "$since_date" ] && [ -z "$until_date" ]; then
                echo -e "${YELLOW}No date range specified${ENDCOLOR}"
                return
            fi
            
            local date_args=""
            if [ -n "$since_date" ]; then
                # Sanitize date input
                if ! sanitize_text_input "$since_date" 50; then
                    show_sanitization_error "date" "Invalid date format."
                    return
                fi
                date_args="$date_args --since=\"$sanitized_text\""
            fi
            
            if [ -n "$until_date" ]; then
                # Sanitize date input
                if ! sanitize_text_input "$until_date" 50; then
                    show_sanitization_error "date" "Invalid date format."
                    return
                fi
                date_args="$date_args --until=\"$sanitized_text\""
            fi
            
            echo
            echo -e "${YELLOW}Commits in date range:${ENDCOLOR}"
            echo
            eval "git log $date_args --pretty=\"%C(Yellow)%h%C(reset) | %C(Cyan)%ad%C(reset) | %C(Blue)%an%C(reset) | %s (%C(Green)%cr%C(reset))\""
        ;;
        "hash"|"commit"|"h")
            echo -e "${YELLOW}GIT LOG SEARCH BY COMMIT HASH${ENDCOLOR}"
            echo
            echo -e "${YELLOW}Search for commits by hash pattern:${ENDCOLOR}"
            echo -e "Press Enter to exit"
            
            read -p "Enter commit hash (full or partial): " -e hash_term
            if [ -z "$hash_term" ]; then
                return
            fi
            
            # Sanitize hash input (only allow hex characters)
            if [[ ! "$hash_term" =~ ^[a-fA-F0-9]+$ ]]; then
                echo -e "${RED}Invalid commit hash format! Use only hexadecimal characters.${ENDCOLOR}"
                return
            fi
            
            if [ ${#hash_term} -lt 4 ]; then
                echo -e "${RED}Hash too short! Use at least 4 characters.${ENDCOLOR}"
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
                    echo -e "${RED}Invalid choice!${ENDCOLOR}"
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
            echo -e "${RED}Unknown search mode: $search_mode${ENDCOLOR}"
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
