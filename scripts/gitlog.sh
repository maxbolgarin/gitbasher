#!/usr/bin/env bash

### Script for providing some info from git log and movind HEAD
# Read README.md to get more information how to use it
# Use this script only with gitbasher


function status {
    echo -e "${YELLOW}Project:${ENDCOLOR}\t${GREEN}$project_name${ENDCOLOR}"
    echo -e "${YELLOW}Repo URL:${ENDCOLOR}\t${GREEN}$repo_url${ENDCOLOR}"
    echo -e "${YELLOW}Branch:${ENDCOLOR}\t\t${GREEN}$current_branch${ENDCOLOR}"
    echo -e "${YELLOW}Last commit:${ENDCOLOR}\t$(git --no-pager log --pretty="%s | ${BLUE}%an${ENDCOLOR} | %cd" -1 | column -ts'|')"
    echo -e "Git status"
    git status -s
}


### Function opens git log in pretty format
function gitlog {
    git log --pretty="%C(Yellow)%h  %C(reset)%ad (%C(Green)%cr%C(reset))%x09 %C(Cyan)%an: %C(reset)%s"
}


### Function opens git reflog in pretty format
function reflog {
    git reflog --pretty="%C(Yellow)%h  %C(reset)%ad (%C(Green)%cr%C(reset))%x09 %C(Cyan)%gd%C(reset) %gs"
}


### Function prints last commit info (from git log)
function last_commit {
    echo -e "$(git --no-pager log --pretty="${YELLOW}%h${ENDCOLOR} | %s | ${BLUE}%an${ENDCOLOR} | %cd" -1 | column -ts'|')"
}


### Function prints last action info (from git reflog)
function last_action {
    echo -e "$(git --no-pager reflog --pretty="${YELLOW}%gd${ENDCOLOR} | %gs | ${BLUE}%an${ENDCOLOR} | %cd" -1 | column -ts'|')"
}


### Function undoes previous commit (move HEAD pointer up for one record, HEAD^)
function undo_commit {
    cancelled_commit=$(git --no-pager log --pretty="${YELLOW}%h${ENDCOLOR} | %s | ${BLUE}%an${ENDCOLOR} | %cd" -1)
    git reset HEAD^ > /dev/null
    new_commit=$(git --no-pager log --pretty="${YELLOW}%h${ENDCOLOR} | %s | ${BLUE}%an${ENDCOLOR} | %cd" -1)

    msg=$(echo -e "${GREEN}New last commit:${ENDCOLOR}|${new_commit}\n${GREEN}Cancelled commit:${ENDCOLOR}|${cancelled_commit}" | column -ts'|')
    echo -e "$msg"
}


### Function undoes previous action (reset HEAD{1})
function undo_action {
    cancelled_commit=$(git --no-pager log --pretty="${YELLOW}%h${ENDCOLOR} | %s | ${BLUE}%an${ENDCOLOR} | %cd" -1)
    cancelled_action=$(git --no-pager reflog --pretty="${YELLOW}%gd${ENDCOLOR} | %gs | ${BLUE}%an${ENDCOLOR} | %cd" -1)
    git reset HEAD@{1} > /dev/null
    new_commit=$(git --no-pager log --pretty="${YELLOW}%h${ENDCOLOR} | %s | ${BLUE}%an${ENDCOLOR} | %cd" -1)

    msg=$(echo -e "${GREEN}New last commit:${ENDCOLOR}|${new_commit}\n${GREEN}Cancelled commit:${ENDCOLOR}|${cancelled_commit}\n${GREEN}Cancelled action:${ENDCOLOR}|${cancelled_action}" | column -ts'|')
    echo -e "$msg"
}
