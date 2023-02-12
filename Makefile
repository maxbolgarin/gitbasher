### HERE IS MAKEFILE EXAMPLE FOR GOLANG PROJECTS

### TODO FIELDS BELOW ###
NS_NAME=TODO
APP_NAME=gitbasher
#FULL_NAME=${NS_NAME}-${APP_NAME}
FULL_NAME=${APP_NAME}

SFOLDER=scripts
URL_PREFIX="https://github.com/maxbolgarin"
MAIN_BRANCH=main

### TODO FIELDS ABOVE ###

REPO_URL=${URL_PREFIX}/${APP_NAME}

### Running
all: 
	go run -ldflags="-X 'main.Version=$(shell $(shell $(MAKE) ver-print))' -X 'main.Time=$(shell LANG=en_us_88591; date)'" cmd/main/main.go


### Testing
t:
	go clean -testcache
	go test -race -cover ./...
	if [ $$? -eq 0 ] ; then echo "TESTS IS DONE" ; fi

tv:
	go clean -testcache
	go test -race -cover -v ./...
	if [ $$? -eq 0 ] ; then echo "TESTS IS DONE" ; fi

integration:
	go test --tags=integration ./...


### Building
build: ver
	env GOOS=linux GOARCH=amd64 go build \
		-ldflags="-X 'main.Version=$(shell $(shell $(MAKE) ver-print))' -X 'main.Time=$(shell LANG=en_us_88591; date)'" \
		-o dist/${FULL_NAME} cmd/main/main.go 

build-windows: ver
	env GOOS=windows GOARCH=amd64 go build \
		-ldflags="-X 'main.Version=$(shell $(shell $(MAKE) ver-print))' -X 'main.Time=$(shell LANG=en_us_88591; date)'" \
		-o dist/${FULL_NAME} cmd/main/main.go 

protoc:
	protoc --go_out=. --go-grpc_out=. pb/${APP_NAME}v1.proto


### Git things
pull-tags:
	git pull --tags origin $(shell git branch --show-current)

ver-print:
	${SFOLDER}/s.sh -r ver -a "-f ${SFOLDER} -v"

ver-print-main:
	${SFOLDER}/s.sh -r ver -a "-f ${SFOLDER} -p"

ver:
	${SFOLDER}/s.sh -r ver -a "-f ${SFOLDER}"

commit: ver
	${SFOLDER}/s.sh -r commit

ez-commit: ver
	${SFOLDER}/s.sh -r ezcommit

ez-commit-push: ez-commit
	${SFOLDER}/s.sh -r push -a '-f'
	echo "${REPO_URL}" > /dev/null

undo-commit:
	git reset HEAD^

changelog:
	${SFOLDER}/s.sh -r changelog

last-commit:
	git add . 
	git commit --amend --no-edit

push:
	${SFOLDER}/s.sh -r push
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

### Add something project specific
