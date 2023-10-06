##### GITBASHER MAKEFILE ######

.PHONY: default
default: gitbasher

##### TODO: FIELDS TO CHANGE #####
GITBASHER_S ?= ./gitbasher.sh  # Relative path to gitbasher.sh script

GITBASHER_MAIN_BRANCH ?= main  # Name of main branch (usually `main` or `master`)
GITBASHER_ORIGIN_NAME ?= origin  # Name of remote (in 99% cases it is `origin`)
GITBASHER_BRANCH_SEPARATOR ?= /  # Separator in branch naming (e.g. feat/name)
GITBASHER_TEXTEDITOR ?= vi  # Texteditor for writing commit messages (e.g. nano or vi)

################################################

.PHONY: commit
commit: ##@Commit Build conventional commit message in format 'type(scope): message'
	@${GITBASHER_S} -r commit -a "-e ${GITBASHER_TEXTEDITOR}"

.PHONY: commit-msg
commit-msg: ##@Commit Build conventional commit message in format 'type(scope): message' using editor for multiline message
	@${GITBASHER_S} -r commit -a "-m -e ${GITBASHER_TEXTEDITOR}"

.PHONY: commit-ticket
commit-ticket: ##@Commit Build conventional commit message with tracker's ticket info (e.g. JIRA)
	@${GITBASHER_S} -r commit -a "-m -t -e ${GITBASHER_TEXTEDITOR}"

.PHONY: commit-fast
commit-fast: ##@Commit Build conventional commit message in fast mode (git add .)
	@${GITBASHER_S} -r commit -a "-f -e ${GITBASHER_TEXTEDITOR}"

.PHONY: commit-fast-push
commit-fast-push: ##@Commit Build conventional commit message in fast mode (git add .) and then push changes
	@${GITBASHER_S} -r commit -a "-f -e ${GITBASHER_TEXTEDITOR}"
	@echo
	@${GITBASHER_S} -r push -a "-y"

.PHONY: commit-amend
commit-amend: ##@Commit Add files to the last commit (git commit --amend --no-edit)
	@${GITBASHER_S} -r commit -a "-a -e ${GITBASHER_TEXTEDITOR}"

.PHONY: commit-fixup
commit-fixup: ##@Commit Make fixup commit (git commit --fixup <commit>)
	@${GITBASHER_S} -r commit -a "-x -e ${GITBASHER_TEXTEDITOR}"

.PHONY: commit-autosquash
commit-autosquash: ##@Commit Make autosquash of fixup commits (git rebase --autosquash <commit>)
	@${GITBASHER_S} -r commit -a "-s -e ${GITBASHER_TEXTEDITOR}"

.PHONY: commit-revert
commit-revert: ##@Commit Revert selected commit (git revert --no-edit <commit>)
	@${GITBASHER_S} -r commit -a "-r -e ${GITBASHER_TEXTEDITOR}"

################################################

.PHONY: tag
tag: ##@Tag Create a new tag from a current commit and push it to a remote
	@${GITBASHER_S} -r tag -a "-e ${GITBASHER_TEXTEDITOR} -b ${GITBASHER_MAIN_BRANCH} -o ${GITBASHER_ORIGIN_NAME}"

.PHONY: tag-commit
tag-commit: ##@Tag Create a new tag from a selected commit and push it to a remote
	@${GITBASHER_S} -r tag -a "-s -e ${GITBASHER_TEXTEDITOR} -b ${GITBASHER_MAIN_BRANCH} -o ${GITBASHER_ORIGIN_NAME}"

.PHONY: tag-full
tag-full: ##@Tag Create a new annotated tag from a selected commit and push it to a remote
	@${GITBASHER_S} -r tag -a "-s -a -e ${GITBASHER_TEXTEDITOR} -b ${GITBASHER_MAIN_BRANCH} -o ${GITBASHER_ORIGIN_NAME}"

.PHONY: tag-list
tag-list: ##@Tag Print a list of local tags
	@${GITBASHER_S} -r tag -a "-l -e ${GITBASHER_TEXTEDITOR} -b ${GITBASHER_MAIN_BRANCH} -o ${GITBASHER_ORIGIN_NAME}"

.PHONY: tag-fetch
tag-fetch: ##@Tag Fetch tags from a remote and print it
	@${GITBASHER_S} -r tag -a "-r -l -e ${GITBASHER_TEXTEDITOR} -b ${GITBASHER_MAIN_BRANCH} -o ${GITBASHER_ORIGIN_NAME}"

.PHONY: tag-push
tag-push: ##@Tag Select a tag to push to a remote
	@${GITBASHER_S} -r tag -a "-p -s -e ${GITBASHER_TEXTEDITOR} -b ${GITBASHER_MAIN_BRANCH} -o ${GITBASHER_ORIGIN_NAME}"

.PHONY: tag-push-all
tag-push-all: ##@Tag Push all local tags to a remote
	@${GITBASHER_S} -r tag -a "-p -e ${GITBASHER_TEXTEDITOR} -b ${GITBASHER_MAIN_BRANCH} -o ${GITBASHER_ORIGIN_NAME}"

.PHONY: tag-delete
tag-delete: ##@Tag Select a tag to delete
	@${GITBASHER_S} -r tag -a "-s -d -e ${GITBASHER_TEXTEDITOR} -b ${GITBASHER_MAIN_BRANCH} -o ${GITBASHER_ORIGIN_NAME}"

.PHONY: tag-delete-all
tag-delete-all: ##@Tag Delete all local tags
	@${GITBASHER_S} -r tag -a "-d -e ${GITBASHER_TEXTEDITOR} -b ${GITBASHER_MAIN_BRANCH} -o ${GITBASHER_ORIGIN_NAME}"

################################################

.PHONY: pull
pull: ##@Remote Fetch current branch and then merge changes with conflicts fixing
	@${GITBASHER_S} -r pull -a "-e ${GITBASHER_TEXTEDITOR} -b ${GITBASHER_MAIN_BRANCH} -o ${GITBASHER_ORIGIN_NAME}"

.PHONY: push
push: ##@Remote Push commits to current branch and pull changes if there are new ones in origin
	@${GITBASHER_S} -r push -a "-e ${GITBASHER_TEXTEDITOR} -b ${GITBASHER_MAIN_BRANCH} -o ${GITBASHER_ORIGIN_NAME}"

.PHONY: push-fast
push-fast: ##@Remote `make push` without pressing 'y'
	@${GITBASHER_S} -r push -a "-y -e ${GITBASHER_TEXTEDITOR} -b ${GITBASHER_MAIN_BRANCH} -o ${GITBASHER_ORIGIN_NAME}"

.PHONY: push-list
push-list: ##@Remote Print a list of unpushed local commits without actual pushing it
	@${GITBASHER_S} -r push -a "-l -e ${GITBASHER_TEXTEDITOR} -b ${GITBASHER_MAIN_BRANCH} -o ${GITBASHER_ORIGIN_NAME}"

################################################

.PHONY: branch
branch: ##@Branch Select a local branch to switch
	@${GITBASHER_S} -r branch -a "-b ${GITBASHER_MAIN_BRANCH} -s ${GITBASHER_BRANCH_SEPARATOR} -o ${GITBASHER_ORIGIN_NAME}"

.PHONY: branch-remote
branch-remote: ##@Branch Fetch origin and select a remote branch to switch
	@${GITBASHER_S} -r branch -a "-r -b ${GITBASHER_MAIN_BRANCH} -s ${GITBASHER_BRANCH_SEPARATOR} -o ${GITBASHER_ORIGIN_NAME}"

.PHONY: branch-main
branch-main: ##@Branch Switch to main branch without additional confirmations
	@${GITBASHER_S} -r branch -a "-m -b ${GITBASHER_MAIN_BRANCH} -s ${GITBASHER_BRANCH_SEPARATOR} -o ${GITBASHER_ORIGIN_NAME}"

.PHONY: branch-new
branch-new: ##@Branch Build conventional name for a new branch, switch to main, pull it and create new branch from main
	@${GITBASHER_S} -r branch -a "-n -b ${GITBASHER_MAIN_BRANCH} -s ${GITBASHER_BRANCH_SEPARATOR} -o ${GITBASHER_ORIGIN_NAME}"

.PHONY: branch-new-current
branch-new-current: ##@Branch Build conventional name for a new branch and create it from a current branch
	@${GITBASHER_S} -r branch -a "-n -c -b ${GITBASHER_MAIN_BRANCH} -s ${GITBASHER_BRANCH_SEPARATOR} -o ${GITBASHER_ORIGIN_NAME}"

.PHONY: branch-delete
branch-delete: ##@Branch Select branch to delete
	@${GITBASHER_S} -r branch -a "-d -b ${GITBASHER_MAIN_BRANCH} -s ${GITBASHER_BRANCH_SEPARATOR} -o ${GITBASHER_ORIGIN_NAME}"

.PHONY: branch-prune
branch-prune: ##@Branch Delete all merged branches except `master`, `main` and `develop` and prune remote branches
	@git branch --merged | egrep -v "(^\*|master|main|develop|${GITBASHER_MAIN_BRANCH})" | xargs git branch -d
	@git remote prune ${GITBASHER_ORIGIN_NAME}

################################################

.PHONY: merge
merge: ##@Merge Select branch to merge info current one and fix conflicts
	@${GITBASHER_S} -r pull -a "-m -e ${GITBASHER_TEXTEDITOR} -b ${GITBASHER_MAIN_BRANCH} -o ${GITBASHER_ORIGIN_NAME}"

.PHONY: merge-main
merge-main: ##@Merge Merge `main` to current branch and fix conflicts
	@${GITBASHER_S} -r pull -a "-m -a -e ${GITBASHER_TEXTEDITOR} -b ${GITBASHER_MAIN_BRANCH} -o ${GITBASHER_ORIGIN_NAME}"

.PHONY: merge-to-main
merge-to-main: ##@Merge Switch to `main` and merge current branch into `main`
	@${GITBASHER_S} -r pull -a "-m -t -e ${GITBASHER_TEXTEDITOR} -b ${GITBASHER_MAIN_BRANCH} -o ${GITBASHER_ORIGIN_NAME}"

################################################

.PHONY: log
gitlog: ##@GitLog Open git log in pretty format
	@git log --pretty="%C(Yellow)%h  %C(reset)%ad (%C(Green)%cr%C(reset))%x09 %C(Cyan)%an: %C(reset)%s"

.PHONY: reflog
reflog: ##@GitLog Open git reflog in pretty format
	@git reflog --pretty="%C(Yellow)%h  %C(reset)%ad (%C(Green)%cr%C(reset))%x09 %C(Cyan)%gd%C(reset) %gs"

.PHONY: last-commit
last-commit: ##@GitLog Print last commit info (from git log)
	@git --no-pager log --pretty="$(GITBASHER_YELLOW)%h$(GITBASHER_ENDCOLOR) | %s | $(GITBASHER_BLUE)%an$(GITBASHER_ENDCOLOR) | %cd" -1 | column -ts'|'

.PHONY: last-action
last-action: ##@GitLog Print last action info (from git reflog)
	@git --no-pager reflog --pretty='$(GITBASHER_YELLOW)%gd$(GITBASHER_ENDCOLOR) | %gs | $(GITBASHER_BLUE)%an$(GITBASHER_ENDCOLOR) | %cd' -1 | column -ts'|'

.PHONY: undo-commit
undo-commit: ##@GitLog Undo previous commit (move HEAD pointer up for one record, HEAD^)
	@printf "$(GITBASHER_YELLOW)Commit to undo:\t$(GITBASHER_ENDCOLOR)"
	@$(MAKE) last-commit
	@git reset HEAD^ > /dev/null
	@printf "$(GITBASHER_YELLOW)Last commit:\t$(GITBASHER_ENDCOLOR)"
	@$(MAKE) last-commit

.PHONY: undo-action
undo-action: ##@GitLog Undo previous action (move HEAD pointer to @{1})
	@printf "$(GITBASHER_YELLOW)Old last commit:\t$(GITBASHER_ENDCOLOR)"
	@$(MAKE) last-commit
	@printf "$(GITBASHER_YELLOW)Action to undo:\t\t$(GITBASHER_ENDCOLOR)"
	@$(MAKE) last-action
	@git reset HEAD@{1} > /dev/null
	@printf "$(GITBASHER_YELLOW)New last commit:\t$(GITBASHER_ENDCOLOR)"
	@$(MAKE) last-commit

################################################

GITBASHER_HELP_FUN = \
	%help; while(<>){push@{$$help{$$2//'options'}},[$$1,$$3] \
	if/^([\w-_]+)\s*:.*\#\#(?:@(\w+))?\s(.*)$$/}; \
	print"$$_:\n", map"  $$_->[0]".(" "x(20-length($$_->[0])))."$$_->[1]\n",\
	@{$$help{$$_}},"\n" for keys %help; \

.PHONY: gitbasher
gitbasher: ##@Miscellaneous Show this help
	@${GITBASHER_S} -i -s
	@printf "Welcome to GITBASHER!\n"
	@printf "Usage: $(GITBASHER_YELLOW)make [target]$(GITBASHER_ENDCOLOR)\n\n"
	@perl -e '$(GITBASHER_HELP_FUN)' $(MAKEFILE_LIST)
	@printf "Written by $(GITBASHER_AUTHOR), version $(GITBASHER_VERSION)\n"
	@printf "Please report any bug or error to the author\n" 

# https://unix.stackexchange.com/questions/269077/tput-setaf-color-table-how-to-determine-color-codes
GITBASHER_GREEN := $(shell tput setaf 70)
GITBASHER_YELLOW := $(shell tput setaf 184)
GITBASHER_BLUE := $(shell tput setaf 040)
GITBASHER_ENDCOLOR := $(shell tput sgr0)

GITBASHER_AUTHOR := https://t.me/maxbolgarin
GITBASHER_VERSION := 1.0.0
