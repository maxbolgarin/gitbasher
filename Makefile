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

.PHONY: commit-ticket
commit-ticket: ##@Commit Build conventional commit message with tracker's ticket info (e.g. JIRA)
	@${GITBASHER_S} -r commit -a "-t -e ${GITBASHER_TEXTEDITOR}"

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

.PHONY: commit-revertb
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

.PHONY: tag-delete
tag-delete: ##@Commit Select a tag to delete
	@${GITBASHER_S} -r tag -a "-d -e ${GITBASHER_TEXTEDITOR} -b ${GITBASHER_MAIN_BRANCH} -o ${GITBASHER_ORIGIN_NAME}"

.PHONY: tag-remote
tag-pull: ##@Commit Pull tags from a remote and print it
	@${GITBASHER_S} -r tag -a "-r -l -e ${GITBASHER_TEXTEDITOR} -b ${GITBASHER_MAIN_BRANCH} -o ${GITBASHER_ORIGIN_NAME}"

.PHONY: tag-push
tag-push: ##@Commit Select a tag to push to a remote
	@${GITBASHER_S} -r tag -a "-p -s -e ${GITBASHER_TEXTEDITOR} -b ${GITBASHER_MAIN_BRANCH} -o ${GITBASHER_ORIGIN_NAME}"

.PHONY: tag-push-all
tag-push-all: ##@Commit Push all local tags to a remote
	@${GITBASHER_S} -r tag -a "-p -e ${GITBASHER_TEXTEDITOR} -b ${GITBASHER_MAIN_BRANCH} -o ${GITBASHER_ORIGIN_NAME}"

################################################

.PHONY: pull
pull: ##@Remote Pull current branch from remote
	@git pull ${GITBASHER_ORIGIN_NAME} $(shell git branch --show-current) --no-rebase

.PHONY: pull-tags
pull-tags: ##@Remote Pull current branch and tags from remote
	@git pull --tags ${GITBASHER_ORIGIN_NAME} $(shell git branch --show-current) --no-rebase

.PHONY: push
push: ##@Remote Run Push Manager to push changes and pull origin if there are unpulled changes
	@${GITBASHER_S} -r push -a "-e ${GITBASHER_TEXTEDITOR} -b ${GITBASHER_MAIN_BRANCH} -o ${GITBASHER_ORIGIN_NAME}"

.PHONY: push-list
push-list: ##@Remote Print a list of unpushed commits
	@${GITBASHER_S} -r push -a "-l -e ${GITBASHER_TEXTEDITOR} -b ${GITBASHER_MAIN_BRANCH} -o ${GITBASHER_ORIGIN_NAME}"

################################################

.PHONY: branch
branch: ##@Branch Switch to an available local branch
	@${GITBASHER_S} -r branch -a "-b ${GITBASHER_MAIN_BRANCH} -s ${GITBASHER_BRANCH_SEPARATOR} -o ${GITBASHER_ORIGIN_NAME}"

.PHONY: branch-remote
branch-remote: ##@Branch Switch to an available remote branch
	@${GITBASHER_S} -r branch -a "-r -b ${GITBASHER_MAIN_BRANCH} -s ${GITBASHER_BRANCH_SEPARATOR} -o ${GITBASHER_ORIGIN_NAME}"

.PHONY: branch-main
branch-main: ##@Branch Switch to main branch
	@${GITBASHER_S} -r branch -a "-m -b ${GITBASHER_MAIN_BRANCH} -s ${GITBASHER_BRANCH_SEPARATOR} -o ${GITBASHER_ORIGIN_NAME}"

.PHONY: branch-new
branch-new: ##@Branch Create a new branch from 'main' according to conventional naming
	@${GITBASHER_S} -r branch -a "-n -b ${GITBASHER_MAIN_BRANCH} -s ${GITBASHER_BRANCH_SEPARATOR} -o ${GITBASHER_ORIGIN_NAME}"

.PHONY: branch-new-current
branch-new-current: ##@Branch Create a new branch from current state according to conventional naming
	@${GITBASHER_S} -r branch -a "-n -c -b ${GITBASHER_MAIN_BRANCH} -s ${GITBASHER_BRANCH_SEPARATOR} -o ${GITBASHER_ORIGIN_NAME}"

.PHONY: branch-delete
branch-delete: ##@Branch Choose a branch to delete
	@${GITBASHER_S} -r branch -a "-d -b ${GITBASHER_MAIN_BRANCH} -s ${GITBASHER_BRANCH_SEPARATOR} -o ${GITBASHER_ORIGIN_NAME}"

.PHONY: branch-prune
branch-prune: ##@Branch Remove all not merged branches and run 'git remote prune origin'
	@git branch --merged | egrep -v "(^\*|master|main|develop|${GITBASHER_MAIN_BRANCH})" | xargs git branch -d
	@git remote prune ${GITBASHER_ORIGIN_NAME}

################################################

.PHONY: merge-main
merge-main: ##@Merge Merge main branch to current branch
	@git fetch ${GITBASHER_ORIGIN_NAME} ${GITBASHER_MAIN_BRANCH}
	@git merge ${GITBASHER_MAIN_BRANCH}

.PHONY: merge-to-main
merge-to-main: ##@Merge Merge current branch to main
	@$(eval branch:=$(shell git branch --show-current))
	@git switch ${GITBASHER_MAIN_BRANCH}
	@git merge ${branch}

################################################

.PHONY: log
gitlog: ##@GitLog Open git log in pretty format
	@git log --pretty="%C(Yellow)%h  %C(reset)%ad (%C(Green)%cr%C(reset))%x09 %C(Cyan)%an: %C(reset)%s"

.PHONY: reflog
reflog: ##@GitLog Open git reflog in pretty format
	@git reflog --pretty="%C(Yellow)%h  %C(reset)%ad (%C(Green)%cr%C(reset))%x09 %gd %gs"

.PHONY: last-commit
last-commit: ##@GitLog Print last commit message
	@git log --pretty="%s | %h | %cd" -1 | cat

.PHONY: undo-commit
undo-commit: ##@GitLog Undo previous commit (move HEAD pointer up for one record, HEAD^)
	@printf "$(GITBASHER_YELLOW)Commit to undo: $(GITBASHER_ENDCOLOR)"
	@$(MAKE) last-commit
	@git reset HEAD^ > /dev/null
	@printf "$(GITBASHER_YELLOW)New last commit: $(GITBASHER_ENDCOLOR)"
	@$(MAKE) last-commit

.PHONY: undo-action
undo-action: ##@GitLog Undo previous action (move HEAD pointer to @{1})
	@printf "$(GITBASHER_YELLOW)Current last commit: $(GITBASHER_ENDCOLOR)"
	@$(MAKE) last-commit
	@printf "$(GITBASHER_YELLOW)Action to undo: $(GITBASHER_ENDCOLOR)"
	@git reflog --pretty='%gs' -1 | cat
	@git reset HEAD@{1} > /dev/null
	@printf "$(GITBASHER_YELLOW)New last commit: $(GITBASHER_ENDCOLOR)"
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

GITBASHER_YELLOW := $(shell tput setaf 184)
GITBASHER_ENDCOLOR := $(shell tput sgr0)

GITBASHER_AUTHOR := https://t.me/maxbolgarin
GITBASHER_VERSION := 1.0.0
