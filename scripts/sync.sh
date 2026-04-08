#!/usr/bin/env bash

### Script for syncing current branch with the default branch
# Fetches latest default branch and rebases current branch onto it
# Optionally force pushes after rebase
# Use this script only with gitbasher


### Main function
# $1: mode
    # <empty>: fetch default branch, rebase current onto it
    # push: same + force push after rebase
    # merge: use merge instead of rebase
    # mergep: use merge + push
function sync_script {
    case "$1" in
        push|p)         sync_push="true";;
        merge|m)        sync_merge="true";;
        mergep|mp|pm)   sync_merge="true"; sync_push="true";;
        help|h)         help="true";;
        *)
            wrong_mode "sync" $1
    esac


    ### Print header
    header_msg="GIT SYNC"
    if [ -n "${sync_merge}" ]; then
        if [ -n "${sync_push}" ]; then
            header_msg="$header_msg MERGE & PUSH"
        else
            header_msg="$header_msg MERGE"
        fi
    elif [ -n "${sync_push}" ]; then
        header_msg="$header_msg & PUSH"
    fi

    echo -e "${YELLOW}${header_msg}${ENDCOLOR}"
    echo


    if [ -n "$help" ]; then
        echo -e "usage: ${YELLOW}gitb sync <mode>${ENDCOLOR}"
        echo
        msg="${YELLOW}Mode${ENDCOLOR}_${GREEN}Aliases${ENDCOLOR}_\t${BLUE}Description${ENDCOLOR}"
        msg="$msg\n${BOLD}<empty>${ENDCOLOR}_ _Fetch $main_branch and rebase current branch onto it"
        msg="$msg\n${BOLD}push${ENDCOLOR}_p_Fetch $main_branch, rebase current branch onto it, and force push"
        msg="$msg\n${BOLD}merge${ENDCOLOR}_m_Fetch $main_branch and merge it into current branch"
        msg="$msg\n${BOLD}mergep${ENDCOLOR}_mp|pm_Fetch $main_branch, merge it into current branch, and push"
        msg="$msg\n${BOLD}help${ENDCOLOR}_h_Show this help"
        echo -e "$(echo -e "$msg" | column -ts'_')"
        exit
    fi


    ### Check if already on default branch
    if [ "$current_branch" == "$main_branch" ]; then
        echo -e "${YELLOW}Already on ${main_branch}, use ${BOLD}gitb pull${NORMAL}${YELLOW} instead${ENDCOLOR}"
        exit
    fi


    ### Check for uncommitted changes
    is_clean=$(git status | tail -n 1)
    if [ "$is_clean" != "nothing to commit, working tree clean" ]; then
        echo -e "${RED}Cannot sync! There are uncommitted changes:${ENDCOLOR}"
        git_status
        echo
        echo -e "${YELLOW}Commit or stash your changes first${ENDCOLOR}"
        exit 1
    fi


    ### Check remote
    if [ -z "$origin_name" ]; then
        echo -e "${RED}No git remote configured.${ENDCOLOR}"
        echo -e "Use ${BLUE}git remote add origin <url>${ENDCOLOR} to set it up first."
        exit 1
    fi


    ### Fetch default branch
    echo -e "${YELLOW}Fetching ${origin_name}/${main_branch}...${ENDCOLOR}"

    fetch $main_branch $origin_name

    if [ $fetch_code != 0 ]; then
        echo -e "${RED}Cannot fetch ${main_branch}!${ENDCOLOR}"
        exit 1
    fi

    echo -e "${GREEN}Fetched ${origin_name}/${main_branch}${ENDCOLOR}"
    echo


    if [ -n "$sync_merge" ]; then
        ### Merge mode
        echo -e "${YELLOW}Merging ${origin_name}/${main_branch} into ${current_branch}...${ENDCOLOR}"
        echo

        merge $main_branch $origin_name $editor "sync" "true"

        if [[ $merge_output == *"Already up to date"* ]]; then
            echo -e "${GREEN}Already up to date with ${main_branch}${ENDCOLOR}"
        else
            # merge() exits on fatal errors, so if we reach here, merge succeeded
            # (merge_code may be non-zero after conflict resolution, but that's ok)
            echo -e "${GREEN}Successfully synced with ${main_branch} using merge!${ENDCOLOR}"
            echo -e "${BLUE}[${origin_name}/${main_branch}${ENDCOLOR} -> ${BLUE}${current_branch}]${ENDCOLOR}"
        fi
    else
        ### Rebase mode
        echo -e "${YELLOW}Rebasing ${current_branch} onto ${origin_name}/${main_branch}...${ENDCOLOR}"
        echo

        rebase_branch "$main_branch" "$origin_name" "true"

        if [[ $rebase_output == *"is up to date"* ]]; then
            echo -e "${GREEN}Already up to date with ${main_branch}${ENDCOLOR}"
        elif [ $rebase_code == 0 ]; then
            echo -e "${GREEN}Successfully synced with ${main_branch} using rebase!${ENDCOLOR}"
            echo -e "${BLUE}[${origin_name}/${main_branch}${ENDCOLOR} -> ${BLUE}${current_branch}]${ENDCOLOR}"
        else
            echo -e "${RED}Rebase failed! Resolve conflicts and try again.${ENDCOLOR}"
            exit $rebase_code
        fi
    fi


    ### Push if requested
    if [ -n "$sync_push" ]; then
        echo
        if [ -n "$sync_merge" ]; then
            echo -e "${YELLOW}Pushing ${current_branch}...${ENDCOLOR}"
            echo
            push_script y
        else
            echo -e "${YELLOW}Force pushing ${current_branch} after rebase...${ENDCOLOR}"
            echo
            push_script f
        fi
    fi
}
