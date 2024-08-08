#!/usr/bin/env bash

### Script for pulling commits from remote git repository
# Read README.md to get more information how to use it
# Use this script only with gitbasher


### Main function
# $1: mode
    # <empty> - pull current branch using default merge strategy
    # rebase: pull current branch using rebase or fast forward if it is possible
    # interactive: pull current branch using interactive rebase
function pull_script {
    case "$1" in
        rebase|r) rebase="true";;
        interactive|i|ri)
            rebase="true"
            interactive="true"
        ;;
        help|h) help="true";;
        *)
            wrong_mode "pull" $1
    esac

    if [ -n "$help" ]; then
        echo -e "usage: ${YELLOW}gitb pull${ENDCOLOR}"
        echo
        echo -e "${YELLOW}Available modes${ENDCOLOR}"
        echo -e "<empty>\t\t\tFetch current branch and then merge changes with conflicts fixing"
        echo -e "rebase|r\t\tFetch current branch and then rebase"
        echo -e "interactive|ri|i\tFetch current branch and then rebase in interactive mode"
        echo -e "help|h\t\t\tShow this help"
        exit
    fi

    mode="merge"
    if [ -n "$rebase" ]; then
        mode="rebase"
    fi

    if [ -n "$interactive" ]; then
        args="--interactive"
    fi

    ### Print header
    header_msg="GIT PULL"
    if [ -n "${rebase}" ]; then
        header_msg="$header_msg REBASE"
    elif [ -n "${interactive}" ]; then
        header_msg="$header_msg INTERACTIVE REBASE"
    fi
    echo -e "${YELLOW}${header_msg}${ENDCOLOR}"
    echo
    
    echo -e "${YELLOW}Pulling '$origin_name/$current_branch'...${ENDCOLOR}"
    echo
    pull $current_branch $origin_name $editor $mode $args
    exit
}
