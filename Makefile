##### GITBASHER MAKEFILE v1.0 ######

##### HERE ARE FIELDS TO CHANGE #####

# URL of git repository
GIT_URL ?= https://github.com/maxbolgarin/gitbasher
# Name of main branch (usually `main` or `master`)
MAIN_BRANCH ?= main
# Relative path to folder with s.sh script
SFOLDER ?= .
# Relative path to file with version
VERSION_FILE ?= scripts/VERSION

##### END OF FIELDS TO CHANGE #####

MAKEFLAGS += --silent
YELLOW := $(shell tput setaf 184)
END := $(shell tput sgr0)

### Git things
# Pull current brancha
pull:
	git pull origin $(shell git branch --show-current) --no-rebase

# Pull taags
pull-tags:
	git pull --tags origin $(shell git branch --show-current)

# Run Commit Manager to build conventional commit message
commit:
	${SFOLDER}/s.sh -r commit -a "-b ${MAIN_BRANCH}"

# Run Commit Manager to build conventional commit message with tracker's ticket info
commit-ticket:
	${SFOLDER}/s.sh -r commit -a "-b ${MAIN_BRANCH} -t"

# Run Commit Manager to build conventional commit message in fast mode (git add .)
commit-fast:
	${SFOLDER}/s.sh -r commit -a "-b ${MAIN_BRANCH} -f"

# Run Commit Manager to add files to the last commit (git commit --amend --no-edit)
commit-amend:
	${SFOLDER}/s.sh -r commit -a "-b ${MAIN_BRANCH} -a"

# Undo previous commit (move HEAD pointer up for one record)
undo-commit:
	printf "$(YELLOW)Commit to undo: $(END)"
	$(MAKE) last-commit
	git reset HEAD^ > /dev/null
	printf "$(YELLOW)New last commit: $(END)"
	$(MAKE) last-commit

# Undo previous action (move HEAD pointer to @{1})
undo-action:
	printf "$(YELLOW)Current last commit: $(END)"
	$(MAKE) last-commit
	printf "$(YELLOW)Action to undo: $(END)"
	git reflog --pretty='%gs' -1 | cat
	git reset HEAD@{1} > /dev/null
	printf "$(YELLOW)New last commit: $(END)"
	$(MAKE) last-commit

# Print last commit
last-commit:
	git log --pretty="%s | %h | %cd" -1 | cat

# Just print git reflog
reflog:
	git reflog

# Push all your comits to current branch
push:
	${SFOLDER}/s.sh -r push -a "-r ${GIT_URL}"


# Get version from VERSION file
ver:
	${SFOLDER}/s.sh -r ver -a "-b ${MAIN_BRANCH} -f ${VERSION_FILE}"

# Get versions from VERSION file and add last commit hash if branch is not main
ver-dev:
	${SFOLDER}/s.sh -r ver -a "-b ${MAIN_BRANCH} -f ${VERSION_FILE} -d"

# Get version from VERSION file and add last commit hash
ver-full:
	${SFOLDER}/s.sh -r ver -a "-b ${MAIN_BRANCH} -f ${VERSION_FILE} -v"

# Edit VERSION file and return version in development mode
ver-edit:
	${SFOLDER}/s.sh -r ver -a "-b ${MAIN_BRANCH} -f ${VERSION_FILE} -d -e"

fast-commit-push: fast-commit
	${SFOLDER}/s.sh -r push -a '-f'
	echo "${REPO_URL}" > /dev/null

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
	${SFOLDER}/s.sh -r release -a "-a ${FULL_NAME}"
	echo "${REPO_URL}" > /dev/null

fix-release: t pull-tags
	${SFOLDER}/s.sh -r release -a "-a ${FULL_NAME} -f"
	echo "${REPO_URL}" > /dev/null
