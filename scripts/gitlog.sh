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
function gitlog {
    git log --pretty="%C(Yellow)%h%C(reset) | %C(Cyan)%ad%C(reset) | %C(Blue)%an%C(reset) | %s (%C(Green)%cr%C(reset))"
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
