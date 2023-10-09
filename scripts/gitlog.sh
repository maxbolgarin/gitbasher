#!/usr/bin/env bash

### Script for providing some info from git log and movind HEAD
# Read README.md to get more information how to use it
# Use this script only with gitbasher


### Function opens git log in pretty format
function gitlog {
    git log --pretty="%C(Yellow)%h  %C(reset)%ad (%C(Green)%cr%C(reset))%x09 %C(Cyan)%an: %C(reset)%s"
}


### Function opens git reflog in pretty format
function reflog {
    git reflog --pretty="%C(Yellow)%h  %C(reset)%ad (%C(Green)%cr%C(reset))%x09 %C(Cyan)%gd%C(reset) %gs"
}


### Function undoes previous commit (move HEAD pointer up for one record, HEAD^)
function undo_commit {
    commit_to_undo=$(last-commit)
    git reset HEAD^ > /dev/null

    echo -e "${YELLOW}New last commit:\t${ENDCOLOR}$(last-commit)"
    echo -e "${YELLOW}Cancelled commit:\t${ENDCOLOR}${commit_to_undo}"
}


### Function undoes previous action (reset HEAD{1})
function undo_action {
    @printf "$(GITBASHER_YELLOW)Old last commit:\t$(GITBASHER_ENDCOLOR)"
	@$(MAKE) last-commit
	@printf "$(GITBASHER_YELLOW)Action to undo:\t\t$(GITBASHER_ENDCOLOR)"
	@$(MAKE) last-action
	@git reset HEAD@{1} > /dev/null
	@printf "$(GITBASHER_YELLOW)New last commit:\t$(GITBASHER_ENDCOLOR)"
	@$(MAKE) last-commit
}


### Function prints last commit info (from git log)
function last_commit {
    echo -e "$(git --no-pager log --pretty="${YELLOW}%h${ENDCOLOR} | %s | ${BLUE}%an${ENDCOLOR} | %cd" -1 | column -ts'|')"
}


### Function prints last action info (from git reflog)
function last_action {
    echo -e "$(git --no-pager reflog --pretty="${YELLOW}%gd${ENDCOLOR} | %gs | ${BLUE}%an${ENDCOLOR} | %cd" -1 | column -ts'|')"
}
