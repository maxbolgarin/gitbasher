#!/bin/bash

RED="\e[31m"
YELLOW="\e[33m"
ENDCOLOR="\e[0m"
MAIN_BRANCH="main"


### Get options
# a: application name
# f: fix-release / force tagging

while getopts a:f flag; do
    case "${flag}" in
        a) app_name=${OPTARG};;
        f) force="true";;
    esac
done

echo "********************************"
echo "RELEASE MANAGER v1.0"

if [ -n "$app_name" ]; then
    echo -e "Application: ${YELLOW}${app_name}${ENDCOLOR}"
fi
echo

### Exit if there is unstaged files
unstaged=$(git diff --name-only)
if [ -n "$unstaged" ]; then
    echo "There is unstaged files! Commit them first:"
    echo -e "${RED}${unstaged}${ENDCOLOR}"
    exit 1
fi

### Go to main and pull origin to preent from conflicts
branch=$(git branch --show-current)
if [ "${branch}" != "${MAIN_BRANCH}" ]; then
    echo -e "${YELLOW}You should checkout to ${MAIN_BRANCH} and merge your changes manually before releasing${ENDCOLOR}"
    exit 1
fi

git pull origin $MAIN_BRANCH

### Force update VERSION to make dummy commit for force tagging
if [ -n "$force" ]; then
    printf "-remove-me" >> deploy/VERSION
    git add deploy/VERSION
    git commit -m "[OTHER] Technical commit for release fixing"
fi

### Check VERSION before releasing
nano deploy/VERSION
diff=$(git diff deploy/VERSION)
if [ -z "$diff" ]; then
    printf " " >> deploy/VERSION
fi
git add deploy/VERSION
version=$(cat deploy/VERSION | cut -d'-' -f1 | xargs)

### Use last version CHANGELOG.md to make tag message
changelog=$(cat CHANGELOG.md)
if echo ${changelog} | grep ${version} -q ; then 
    changelog="${version}${changelog#*${version}}"
    changelog=${changelog%%## v*}
else
    changelog=""
fi

### Commit VERSION to make RELEASE commit
if [ -n "${app_name}" ]; then
    git commit -m "[RELEASE] ${app_name} version ${version}"
else
    git commit -m "[RELEASE] version ${version}"
fi

### Remove old tag if we want to force release
if [ -n "$force" ]; then
    git tag -d $version
    git push --delete origin $version
fi

### Create and push new tag
git tag -a "${version}" -m """${changelog}"""
git push origin $MAIN_BRANCH
git push --tags
