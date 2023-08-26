#!/usr/bin/env bash

### Script for versioning of your application
# In VERSION file store only actual semver version

### Options
# f: path to VERSION file (default "scripts/VERSION")
# d: development mode, print VERSION with last commit hash is current branch is not main branch
# v: full version mode, print VERSION with last commit hash
# e: edit VERSION file

EDIT_HINT="""\n
### Write current semver version of the project, e.g. 1.0.0, then press ^X, Y and Enter\n
### Version number satisfies format MAJOR.MINOR.PATCH
###    MAJOR version when you make incompatible API changes
###    MINOR version when you add functionality in a backward compatible manner
###    PATCH version when you make backward compatible bug fixes \n
### For more information: https://semver.org/
"""

function edit_version {
    printf "${EDIT_HINT}" >> $1
    nano $1
    VERSION=$(cat $1 | sed '/^#/d')
    if [ -z "${VERSION}" ]; then
        VERSION="1.0.0"
    fi
    echo $VERSION > $1
}

while getopts f:dveb:u: flag; do
    case "${flag}" in
        f) version_file=${OPTARG};;
        d) dev="true";;
        v) full_version="true";;
        e) edit="true";;

        b) main_branch=${OPTARG};;
        u) utils=${OPTARG};;
    esac
done

if [ -z "$main_branch" ]; then
    main_branch="main"
fi

if [ -z "$version_file" ]; then
    version_file="scripts/VERSION"
fi

source $utils

version_file=$(prepare_path $version_file)


### Script logic below

# No version file
if [ ! -f "${version_file}" ]; then
    touch ${version_file}
    edit_version $version_file
fi

# Edit version file
if [ -n "$edit" ]; then
    edit_version $version_file
fi

VERSION=$( cat $version_file | xargs )

# Print version
if [ -n "$dev" ] || [ -n "$full_version" ]; then
    if [ $(git branch --show-current) = "$main_branch" ] && [ -z "$full_version" ]; then
        echo $VERSION
        exit
    fi
    githash=$(git rev-parse HEAD)
    echo "${VERSION}-${githash::8}"
    exit
fi

echo $VERSION
