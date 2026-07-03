#!/usr/bin/env bash

### Script for fetching from a remote without merging
# Read README.md to get more information how to use it
# Use this script only with gitbasher


### Prints the names of remote-tracking refs that `git fetch --prune` removed,
### one per line (parsed from its "- [deleted] ... -> origin/x" lines).
# $1: git fetch output
function pruned_branch_names {
    grep '\[deleted\]' <<< "$1" | sed -e 's#.*-> ##'
}


### Shows how far the current branch is behind its remote-tracking ref, or that
### it is already up to date. Relies on origin_name/current_branch globals and
### a freshly-updated remote-tracking ref (i.e. call after a successful fetch).
function fetch_report_incoming {
    local commits count
    commits=$(commit_list 999 "tab" "HEAD..$origin_name/$current_branch")
    if [ "$commits" != "" ]; then
        count=$(echo -e "$commits" | wc -l | sed 's/^ *//;s/ *$//')
        echo -e "Your branch is behind ${YELLOW}$origin_name/$current_branch${ENDCOLOR} by ${BOLD}$count${ENDCOLOR} commits"
        echo -e "$commits"
    else
        echo -e "${GREEN}✓ Already up to date${ENDCOLOR}"
    fi
}


### Main function
# $1: mode
    # <empty>: fetch the current branch without merging
    # all: fetch every remote branch without merging
    # prune: fetch and drop remote-tracking branches deleted on the remote
function fetch_script {
    case "$1" in
        all|a|fa)       all="true";;
        prune|p|pr)     prune="true";;
        help|h)         help="true";;
        "")             ;;
        *)
            wrong_mode "fetch" $1
    esac


    ### Print header
    header_msg="GIT FETCH"
    if [ -n "${all}" ]; then
        header_msg="$header_msg ALL"
    elif [ -n "${prune}" ]; then
        header_msg="$header_msg PRUNE"
    fi

    echo -e "${YELLOW}${header_msg}${ENDCOLOR}"
    echo


    if [ -n "$help" ]; then
        echo -e "usage: ${YELLOW}gitb fetch <mode>${ENDCOLOR}"
        echo
        local PAD=22
        print_help_header $PAD
        print_help_row $PAD "<empty>"   ""        "Fetch the current branch without merging"
        print_help_row $PAD "all"       "a, fa"   "Fetch every remote branch without merging"
        print_help_row $PAD "prune"     "p, pr"   "Fetch and drop branches deleted on the remote"
        print_help_row $PAD "help"      "h"       "Show this help"
        echo
        echo -e "${YELLOW}Examples${ENDCOLOR}"
        echo -e "  ${GREEN}gitb fetch${ENDCOLOR}         Fetch the current branch and show what's incoming"
        echo -e "  ${GREEN}gitb fetch all${ENDCOLOR}     Refresh every remote-tracking branch"
        echo -e "  ${GREEN}gitb fetch prune${ENDCOLOR}   Fetch and remove branches deleted on the remote"
        exit
    fi


    if [ -z "$origin_name" ]; then
        echo -e "${RED}✗ No git remote configured.${ENDCOLOR}"
        echo -e "Run ${GREEN}git remote add origin <url>${ENDCOLOR} to set one up."
        exit 1
    fi


    ### Fetch and prune deleted remote branches
    if [ -n "$prune" ]; then
        echo -e "${YELLOW}Fetching and pruning '$origin_name'...${ENDCOLOR}"
        echo

        fetch_output=$(git fetch --prune "$origin_name" 2>&1)
        check_code $? "$fetch_output" "fetch and prune remote"

        pruned=$(pruned_branch_names "$fetch_output")
        if [ -n "$pruned" ]; then
            echo -e "${GREEN}✓ Pruned branches deleted on the remote:${ENDCOLOR}"
            while IFS= read -r pruned_ref; do
                echo -e "\t${YELLOW}${pruned_ref}${ENDCOLOR}"
            done <<< "$pruned"
        else
            echo -e "${GREEN}✓ Nothing to prune${ENDCOLOR}"
        fi
        echo

        fetch_report_incoming
        exit
    fi


    ### Fetch the current branch (or every branch with `all`) without merging.
    ### Reuses the shared fetch() helper from pull.sh (same bash process).
    if [ -n "$all" ]; then
        echo -e "${YELLOW}Fetching all...${ENDCOLOR}"
    else
        echo -e "${YELLOW}Fetching '$origin_name/$current_branch'...${ENDCOLOR}"
    fi
    echo

    fetch "$current_branch" "$origin_name" "$all"

    if [ $fetch_code == 0 ] ; then
        ### Skip re-echo when progress (and the summary) was already streamed live
        if [ "$fetch_output" != "" ] && [ -z "$fetch_progress_shown" ]; then
            echo -e "$fetch_output"
            echo
        fi
        fetch_report_incoming
    fi

    exit $fetch_code
}
