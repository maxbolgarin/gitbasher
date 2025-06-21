#!/usr/bin/env bash

### Here is main script for running gitbasher
# https://github.com/maxbolgarin/gitbasher


if [ "$1" == "init" ]; then
    git init
fi

git_check=$(git branch --show-current 2>&1)
if [[ "$git_check" == *"fatal: not a git repository"* ]]; then
    echo "You can use gitb only in a git repository"
    exit
fi


### Cannot use bash version less than 4 because of many features that was added to language in that version
if ((BASH_VERSINFO[0] < 4)); then 
    printf "Sorry, you need at least ${YELLOW}bash-4.0${ENDCOLOR} to run gitbasher.\n
If your OS is debian-based, use:
    ${GREEN}apt install --only-upgrade bash${ENDCOLOR}\n
If your OS is Mac, use:
    ${GREEN}brew install bash${ENDCOLOR}\n\n" 
    exit 1; 
fi


### Init gitbasher
source scripts/init.sh
source scripts/common.sh


### Include all scripts
source scripts/ai.sh
source scripts/config.sh
source scripts/merge.sh
source scripts/rebase.sh
source scripts/pull.sh
source scripts/push.sh
source scripts/commit.sh
source scripts/branch.sh
source scripts/tag.sh
source scripts/reset.sh
source scripts/stash.sh
source scripts/gitlog.sh

source scripts/base.sh
