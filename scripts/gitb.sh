#!/usr/bin/env bash

### Main script for running gitbasher

source "scripts/common.sh"

source "scripts/commit.sh"
source "scripts/push.sh"
source "scripts/pull.sh"
source "scripts/merge.sh"
source "scripts/branch.sh"
source "scripts/tag.sh"


### Cannot use bash version less than 4 because of many features that was added to language in that version
if ((BASH_VERSINFO[0] < 4)); then 
    printf "Sorry, you need at least ${YELLOW}bash-4.0${ENDCOLOR} to run this script.\n
If your OS is debian-based, use:
    ${GREEN}apt install --only-upgrade bash${ENDCOLOR}\n
If your OS is mac, use:
    ${GREEN}brew install bash${ENDCOLOR}\n\n" 
    exit 1; 
fi


declare -a commit=("commit" "c" "co" "cm" "com")
declare -a push=("push" "ps" "ph")
declare -a pull=("pull" "pl" "pll")
declare -a merge=("merge")
declare -a branch=("branch" "b" "br" "bh" "bch" "bra")
declare -a tag=("tag" "t" "tg" "release")

declare -a scripts=("commit" "push" "pull" "merge" "branch" "tag")

function get_script_name {
    for script in "${scripts[@]}"; do
        commands="$script[@]"
        for name in "${!commands}"; do
            if [ $name == $1 ]; then
                echo ${script}
                return
            fi
        done
    done
}


script_to_run=$(get_script_name $1)
if [ $script_to_run == "commit" ]; then
    commit_script $2
elif [ $script_to_run == "push" ]; then
    push_script $2
elif [ $script_to_run == "pull" ]; then
    pull_script $2
elif [ $script_to_run == "merge" ]; then
    merge_script $2
elif [ $script_to_run == "branch" ]; then
    branch_script $2
elif [ $script_to_run == "tag" ]; then
    tag_script $2
fi

exit $?
