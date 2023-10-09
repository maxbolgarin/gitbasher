#!/usr/bin/env bash
### Here is main script for running gitbasher
# https://github.com/maxbolgarin/gitbasher


git_check=$(git branch --show-current 2>&1)
if [[ "$git_check" == *"fatal: not a git repository"* ]]; then
    echo "You can use gitb only from directory with inited git repository"
    exit
fi

### Get common and config first
source scripts/common.sh
source scripts/config.sh

### Include all scripts
source scripts/commit.sh
source scripts/push.sh
source scripts/pull.sh
source scripts/merge.sh
source scripts/branch.sh
source scripts/tag.sh
source scripts/gitlog.sh

source scripts/base.sh
