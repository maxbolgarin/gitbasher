#!/usr/bin/env bash


nano CHANGELOG.md
git add CHANGELOG.md

branch=$(git branch --show-current)

unpushed_log=$(git log origin/${branch}..HEAD)
if [ -n "${unpushed_log}" ]; then
    git commit --amend --no-edit
else
    git commit -m "[DOCS]: update CHANGELOG.md according to the last update"
fi
