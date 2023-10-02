##### GITBASHER MAKEFILE ######

.PHONY: default
default: gitbasher

##### TODO: FIELDS TO CHANGE #####
GITBASHER_S ?= ./gitbasher.sh  # Relative path to gitbasher.sh script

GITBASHER_MAIN_BRANCH ?= main  # Name of main branch (usually `main` or `master`)
GITBASHER_BRANCH_SEPARATOR ?= /  # Separator in branch naming (e.g. feat/name)
GITBASHER_TEXTEDITOR ?= vi  # Texteditor for writing commit messages (e.g. nano or vi)

################################################

.PHONY: commit
commit: ##@CommitManager Build conventional commit message in format 'type(scope): message'
	@${GITBASHER_S} -r commit -a "-e ${GITBASHER_TEXTEDITOR}"

.PHONY: commit-ticket
commit-ticket: ##@CommitManager Build conventional commit message with tracker's ticket info (e.g. JIRA)
	@${GITBASHER_S} -r commit -a "-t -e ${GITBASHER_TEXTEDITOR}"

.PHONY: commit-fast
commit-fast: ##@CommitManager Build conventional commit message in fast mode (git add .)
	@${GITBASHER_S} -r commit -a "-f -e ${GITBASHER_TEXTEDITOR}"

.PHONY: commit-fast-push
commit-fast-push: ##@CommitManager Build conventional commit message in fast mode (git add .) and then push changes
	@${GITBASHER_S} -r commit -a "-f -e ${GITBASHER_TEXTEDITOR}"
	@echo
	@${GITBASHER_S} -r push -a "-y"

.PHONY: commit-amend
commit-amend: ##@CommitManager Add files to the last commit (git commit --amend --no-edit)
	@${GITBASHER_S} -r commit -a "-a -e ${GITBASHER_TEXTEDITOR}"

.PHONY: commit-fixup
commit-fixup: ##@CommitManager Make fixup commit (git commit --fixup <commit>)
	@${GITBASHER_S} -r commit -a "-x -e ${GITBASHER_TEXTEDITOR}"

.PHONY: commit-autosquash
commit-autosquash: ##@CommitManager Make autosquash of fixup commits (git rebase --autosquash <commit>)
	@${GITBASHER_S} -r commit -a "-s -e ${GITBASHER_TEXTEDITOR}"

.PHONY: commit-revert
commit-revert: ##@CommitManager Revert selected commit (git revert --no-edit <commit>)
	@${GITBASHER_S} -r commit -a "-r -e ${GITBASHER_TEXTEDITOR}"

################################################

.PHONY: pull
pull: ##@Origin Pull current branch
	@git pull origin $(shell git branch --show-current) --no-rebase

.PHONY: pull-tags
pull-tags: ##@Origin Pull current branch and tags
	@git pull --tags origin $(shell git branch --show-current) --no-rebase

.PHONY: push
push: ##@Origin Run Push Manager to push changes and pull origin if there are unpulled changes
	@${GITBASHER_S} -r push

.PHONY: push-log
push-log: ##@Origin Print a list of unpushed commits
	@${GITBASHER_S} -r push -a "-l"

################################################

.PHONY: branch
branch: ##@BranchManager Checkout to an available local branch
	@${GITBASHER_S} -r branch -a "-b ${GITBASHER_MAIN_BRANCH} -s ${GITBASHER_BRANCH_SEPARATOR}"

.PHONY: branch-remote
branch-remote: ##@BranchManager Checkout to an available remote branch
	@${GITBASHER_S} -r branch -a "-b ${GITBASHER_MAIN_BRANCH} -s ${GITBASHER_BRANCH_SEPARATOR} -r"

.PHONY: branch-new
branch-new: ##@BranchManager Create a new branch from 'main' according to conventional naming
	@${GITBASHER_S} -r branch -a "-b ${GITBASHER_MAIN_BRANCH} -s ${GITBASHER_BRANCH_SEPARATOR} -n"

.PHONY: branch-new-current
branch-new-current: ##@BranchManager Create a new branch from current state according to conventional naming
	@${GITBASHER_S} -r branch -a "-b ${GITBASHER_MAIN_BRANCH} -s ${GITBASHER_BRANCH_SEPARATOR} -n -c"

.PHONY: branch-delete
branch-delete: ##@BranchManager Choose a branch to delete
	@${GITBASHER_S} -r branch -a "-b ${GITBASHER_MAIN_BRANCH} -s ${GITBASHER_BRANCH_SEPARATOR} -d"

.PHONY: branch-prune
branch-prune: ##@BranchManager Remove all not merged branches and run 'git remote prune origin'
	@git branch --merged | egrep -v "(^\*|master|main|develop|${GITBASHER_MAIN_BRANCH})" | xargs git branch -d
	@git remote prune origin

################################################

.PHONY: merge-main
merge-main: ##@Merge Merge main branch to current branch
	@git fetch origin ${GITBASHER_MAIN_BRANCH}
	@git merge ${GITBASHER_MAIN_BRANCH}

.PHONY: merge-to-main
merge-to-main: ##@Merge Merge current branch to main
	@$(eval branch:=$(shell git branch --show-current))
	@git checkout ${GITBASHER_MAIN_BRANCH}
	@git merge ${branch}

.PHONY: merge-request
merge-request: ##@Merge Create merge request (pull request)

.PHONY: merge-finish
merge-finish: ##@Merge Create merge commit and finish merge

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

################################################

merge: t pull-tags ver
	printf " " >> CHANGELOG.md
	git add .
	git commit -m "Ready to merge"
	git push -o merge_request.create -o merge_request.title="Release $(shell $(shell $(MAKE) ver-print-main))" origin $(shell git branch --show-current)

after-merge:
	git checkout ${GITBASHER_MAIN_BRANCH}
	git pull origin ${GITBASHER_MAIN_BRANCH}
	$(MAKE) release

release: t pull-tags
	${GITBASHER_S} -r release -a "-a ${FULL_NAME}"
	echo "${REPO_URL}" > /dev/null

fix-release: t pull-tags
	${GITBASHER_S} -r release -a "-a ${FULL_NAME} -f"
	echo "${REPO_URL}" > /dev/null
