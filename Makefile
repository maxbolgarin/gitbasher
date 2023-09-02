##### GITBASHER MAKEFILE v1.0 ######

##### HERE ARE FIELDS TO CHANGE #####

# Name of the application
APP_NAME ?= gitbasher
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

### Git things
# Pull current branch
pull:
	git pull origin $(shell git branch --show-current)

# Pull taaaaags
pull-tags:
	git pull --tags origin $(shell git branch --show-current)

# Get version from VERSION file
ver:
	${SFOLDER}/s.sh -r ver -a "-b ${MAIN_BRANCH} -f ${VERSION_FILE}"

# Get version from VERSION file and add last commit hash if branch is not main
ver-dev:
	${SFOLDER}/s.sh -r ver -a "-b ${MAIN_BRANCH} -f ${VERSION_FILE} -d"

# Get version from VERSION file and add last commit hash
ver-full:
	${SFOLDER}/s.sh -r ver -a "-b ${MAIN_BRANCH} -f ${VERSION_FILE} -v"

# Edit VERSION file and return version in development mode
ver-edit:
	${SFOLDER}/s.sh -r ver -a "-b ${MAIN_BRANCH} -f ${VERSION_FILE} -d -e"

# Run Commit Manager to build conventional commit message
commit:
	${SFOLDER}/s.sh -r commit -a "-b ${MAIN_BRANCH}"

# Run Commit Manager to build conventional commit message in fast mode (git add .)
fast-commit:
	${SFOLDER}/s.sh -r commit -a "-b ${MAIN_BRANCH} -f"

# Undo previous commit (move HEAD pointer up for one record)
undo-commit:
	git reset HEAD^

# Add all staged files to the last commit
last-commit:
	git add . 
	git commit --amend --no-edit

# Push all your comits to current branch
push:
	${SFOLDER}/s.sh -r push -a "-r ${GIT_URL}"

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


### Golang running
LDFLAGS += -X 'main.Version=\"${VERSION}\"'
LDFLAGS += -X 'main.Time=\"$(shell LANG=en_us_88591; date)\"'

all: 
	go run -ldflags="-X 'main.Version=$(shell $(shell $(MAKE) ver-dev))' -X 'main.Time=$(shell LANG=en_us_88591; date)'" cmd/main/main.go


### Golang testing
t:
	go clean -testcache
	go test -race -cover ./...
	if [ $$? -eq 0 ] ; then echo "TESTS IS DONE" ; fi

tv:
	go clean -testcache
	go test -race -cover -v ./...
	if [ $$? -eq 0 ] ; then echo "TESTS IS DONE" ; fi

integration:
	go clean -testcache
	go test --tags=integration -cover ./...
	if [ $$? -eq 0 ] ; then echo "TESTS IS DONE" ; fi


### Golang building
build: ver
	go build \
		-ldflags="-X 'main.Version=$(shell $(shell $(MAKE) ver-dev))' -X 'main.Time=$(shell LANG=en_us_88591; date)'" \
		-o dist/${FULL_NAME} cmd/main/main.go 

build-linux: ver
	env GOOS=linux GOARCH=amd64 go build \
		-ldflags="-X 'main.Version=$(shell $(shell $(MAKE) ver-dev))' -X 'main.Time=$(shell LANG=en_us_88591; date)'" \
		-o dist/${FULL_NAME} cmd/main/main.go 

build-windows: ver
	env GOOS=windows GOARCH=amd64 go build \
		-ldflags="-X 'main.Version=$(shell $(shell $(MAKE) ver-dev))' -X 'main.Time=$(shell LANG=en_us_88591; date)'" \
		-o dist/${FULL_NAME} cmd/main/main.go

build-mac: ver
	env GOOS=darwin GOARCH=amd64 go build \
		-ldflags="-X 'main.Version=$(shell $(shell $(MAKE) ver-dev))' -X 'main.Time=$(shell LANG=en_us_88591; date)'" \
		-o dist/${FULL_NAME} cmd/main/main.go

build-arm-mac: ver
	env GOOS=darwin GOARCH=arm64 go build \
		-ldflags="-X 'main.Version=$(shell $(shell $(MAKE) ver-dev))' -X 'main.Time=$(shell LANG=en_us_88591; date)'" \
		-o dist/${FULL_NAME} cmd/main/main.go 

protoc:
	protoc --go_out=. --go-grpc_out=. pb/${APP_NAME}v1.proto


### Add something project specific
