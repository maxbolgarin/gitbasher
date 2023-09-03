##### GITBASHER MAKEFILE ######

##### TODO: FIELDS TO CHANGE #####

GIT_URL ?= https://github.com/maxbolgarin/gitbasher  # URL of git repository
MAIN_BRANCH ?= main  # Name of main branch (usually `main` or `master`)
S ?= ./s.sh  # Relative path to s.sh script

################################################

.PHONY: default
default: help

.PHONY: commit
commit: ##@CommitManager Build conventional commit message in format 'type(scope): message'
	${S} -r commit -a "-b ${MAIN_BRANCH}"

.PHONY: commit-ticket
commit-ticket: ##@CommitManager Build conventional commit message with tracker's ticket info (e.g. JIRA)
	${S} -r commit -a "-b ${MAIN_BRANCH} -t"

.PHONY: commit-fast
commit-fast: ##@CommitManager Build conventional commit message in fast mode (git add .)
	${S} -r commit -a "-b ${MAIN_BRANCH} -f"

.PHONY: commit-fast-push
commit-fast-push: ##@CommitManager Build conventional commit message in fast mode (git add .) and then push changes
	${S} -r commit -a "-b ${MAIN_BRANCH} -f"
	echo
	${S} -r push -a "-r ${GIT_URL} -y"

.PHONY: commit-amend
commit-amend: ##@CommitManager Add files to the last commit (git commit --amend --no-edit)
	${S} -r commit -a "-b ${MAIN_BRANCH} -a"

################################################

.PHONY: pull
pull: ##@Origin Pull current branch
	git pull origin $(shell git branch --show-current) --no-rebase

.PHONY: pull-tags
pull-tags: ##@Origin Pull current branch and tags
	git pull --tags origin $(shell git branch --show-current) --no-rebase

.PHONY: push
push: ##@Origin Run Push Manager to push changes and pull origin if there are unpulled changes
	${S} -r push -a "-r ${GIT_URL}"

.PHONY: push
push-list: ##@Origin Print a list of unpushed commits
	${S} -r push -a "-r ${GIT_URL} -l"

################################################

.PHONY: main
main: ##@BranchManager Checkout to main branch
	git checkout ${MAIN_BRANCH} 

.PHONY: branch
branch: ##@BranchManager Checkout to an available local branch

.PHONY: branch-origin
branch-origin: ##@BranchManager Checkout to an available origin branch and fetch it

.PHONY: branch-new
branch-new: ##@BranchManager Create a new branch from 'main' according to conventional naming
	${S} -r branch -a "-b ${MAIN_BRANCH} -n"

.PHONY: branch-new-current
branch-new-current: ##@BranchManager Create a new branch from current state according to conventional naming
	${S} -r branch -a "-b ${MAIN_BRANCH} -n -c"

.PHONY: branch-rm
branch-rm: ##@BranchManager Choose a branch to remove

.PHONY: branch-prune
branch-prune-stuck: ##@BranchManager Remove all not merged branches and run 'git remote prune origin'
	git branch --merged | egrep -v "(^\*|master|main|${MAIN_BRANCH})" | xargs git branch -d
	git remote prune origin

################################################

.PHONY: merge-main
merge-main: ##@Merge Merge main branch to current branch
	git fetch origin ${MAIN_BRANCH}
	git merge ${MAIN_BRANCH}

.PHONY: merge-to-main
merge-to-main: ##@Merge Merge current branch to main
	$(eval branch:=$(shell git branch --show-current))
	git checkout ${MAIN_BRANCH}
	git merge ${branch}

.PHONY: merge-request
merge-request: ##@Merge Create merge request (pull request)

.PHONY: merge-finish
merge-finish: ##@Merge Create merge commit and finish merge

################################################

.PHONY: log
log: ##@GitLog Open git log in pretty format
	git log --pretty="%C(Yellow)%h  %C(reset)%ad (%C(Green)%cr%C(reset))%x09 %C(Cyan)%an: %C(reset)%s"

.PHONY: reflog
reflog: ##@GitLog Open git reflog in pretty format
	git reflog --pretty="%C(Yellow)%h  %C(reset)%ad (%C(Green)%cr%C(reset))%x09 %gd %gs"

.PHONY: last-commit
last-commit: ##@GitLog Print last commit message
	git log --pretty="%s | %h | %cd" -1 | cat

.PHONY: undo-commit
undo-commit: ##@GitLog Undo previous commit (move HEAD pointer up for one record, HEAD^)
	printf "$(YELLOW)Commit to undo: $(ENDCOLOR)"
	$(MAKE) last-commit
	git reset HEAD^ > /dev/null
	printf "$(YELLOW)New last commit: $(ENDCOLOR)"
	$(MAKE) last-commit

.PHONY: undo-action
undo-action: ##@GitLog Undo previous action (move HEAD pointer to @{1})
	printf "$(YELLOW)Current last commit: $(ENDCOLOR)"
	$(MAKE) last-commit
	printf "$(YELLOW)Action to undo: $(ENDCOLOR)"
	git reflog --pretty='%gs' -1 | cat
	git reset HEAD@{1} > /dev/null
	printf "$(YELLOW)New last commit: $(ENDCOLOR)"
	$(MAKE) last-commit

################################################

HELP_FUN = \
	%help; while(<>){push@{$$help{$$2//'options'}},[$$1,$$3] \
	if/^([\w-_]+)\s*:.*\#\#(?:@(\w+))?\s(.*)$$/}; \
	print"$$_:\n", map"  $$_->[0]".(" "x(20-length($$_->[0])))."$$_->[1]\n",\
	@{$$help{$$_}},"\n" for keys %help; \

help: ##@Miscellaneous Show this help
	${S} -i -s
	@printf "Usage: $(YELLOW)make [target]$(ENDCOLOR)\n\n"
	@perl -e '$(HELP_FUN)' $(MAKEFILE_LIST)
	@printf "Written by $(SCRIPT_AUTHOR), version $(SCRIPT_VERSION)\n"
	@printf "Please report any bug or error to the author\n" 


MAKEFLAGS += --silent
YELLOW := $(shell tput setaf 184)
ENDCOLOR := $(shell tput sgr0)

SCRIPT_AUTHOR:=maxbolgarin
SCRIPT_VERSION:=1.0.0

################################################

merge: t pull-tags ver
	printf " " >> CHANGELOG.md
	git add .
	git commit -m "Ready to merge"
	git push -o merge_request.create -o merge_request.title="Release $(shell $(shell $(MAKE) ver-print-main))" origin $(shell git branch --show-current)

after-merge:
	git checkout ${MAIN_BRANCH}
	git pull origin ${MAIN_BRANCH}
	$(MAKE) release

release: t pull-tags
	${S} -r release -a "-a ${FULL_NAME}"
	echo "${REPO_URL}" > /dev/null

fix-release: t pull-tags
	${S} -r release -a "-a ${FULL_NAME} -f"
	echo "${REPO_URL}" > /dev/null
