#!/bin/bash

### Get options
# f: folder with VERSION file
# v: only print VERSION
# p: print VERSION with cutting

MAIN_BRANCH="main"

while getopts f:vp flag; do
    case "${flag}" in
        f) vfolder=${OPTARG};;
        v) print="true";;
        p) print_with_cut="true";;
    esac
done

if [ -z "$vfolder" ]; then
    vfolder=deploy
fi

if [ -n "$print_with_cut" ]; then
    cat $vfolder/VERSION | cut -d'-' -f1 | xargs
    exit
fi

if [ -n "$print" ]; then
    cat $vfolder/VERSION | xargs
    exit
fi


version=$(cat $vfolder/VERSION | cut -d'-' -f1 | xargs)
last_tag=$(git tag | tail -n 1)

if [ "$version" = "$last_tag" ]; then
    nano $vfolder/VERSION
    version=$(cat $vfolder/VERSION | cut -d'-' -f1 | xargs)
fi

branch=$(git branch --show-current)
if [ "${branch}" = "${MAIN_BRANCH}" ]; then
    exit;
fi;

githash=$(git rev-parse HEAD)
echo "${version}-${githash::8}" > $vfolder/VERSION;
