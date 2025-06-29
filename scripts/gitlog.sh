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
            echo -e "  ${GREEN}help, h${ENDCOLOR}        Show this help"
            echo
            echo -e "${YELLOW}Examples:${ENDCOLOR}"
            echo -e "  gitb log"
            echo -e "  gitb log branch"
            echo -e "  gitb log branch local"
            echo -e "  gitb log compare"
        ;;
        "")
            gitlog
        ;;
        *)
            wrong_mode "log" "$mode"
        ;;
    esac
}
