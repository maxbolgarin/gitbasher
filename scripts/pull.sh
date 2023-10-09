#!/usr/bin/env bash

### Script for pulling commits from remote git repository
# Read README.md to get more information how to use it
# Use this script only with gitbasher


### Main function - pull current branch and exit (empty flags mode)
function pull_script {
    case "$1" in
        help|h) help="true";;
        *)
            wrong_mode "pull" $1
    esac

    if [ -n "$help" ]; then
        echo -e "usage: ${YELLOW}gitb pull${ENDCOLOR}"
        echo
        echo -e "${YELLOW}Available modes${ENDCOLOR}"
        echo -e "<empty>\t\tFetch current branch and then merge changes with conflicts fixing"
        echo -e "help|h\t\tShow this help"
        exit
    fi


    ### Print header
    header_msg="GIT PULL"
    echo -e "${YELLOW}${header_msg}${ENDCOLOR}"
    echo
    
    echo -e "${YELLOW}Pulling '$origin_name/$current_branch'...${ENDCOLOR}"
    echo
    pull $current_branch $origin_name $editor
    exit
}
