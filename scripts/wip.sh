#!/usr/bin/env bash

### Script for quick work-in-progress save and restore
# Saves all changes as a WIP commit, optionally pushes
# Use this script only with gitbasher


### Main function for wip
# $1: mode
    # <empty>: stage all, WIP commit, push
    # nopush: stage all, WIP commit, skip push
function wip_script {
    case "$1" in
        nopush|np|n)    nopush="true";;
        help|h)         help="true";;
        *)
            wrong_mode "wip" $1
    esac

    ### Print header
    header_msg="GIT WIP"
    if [ -n "${nopush}" ]; then
        header_msg="$header_msg (NO PUSH)"
    fi

    echo -e "${YELLOW}${header_msg}${ENDCOLOR}"
    echo


    if [ -n "$help" ]; then
        echo -e "usage: ${YELLOW}gitb wip <mode>${ENDCOLOR}"
        echo
        msg="${YELLOW}Mode${ENDCOLOR}_${GREEN}Aliases${ENDCOLOR}_\t${BLUE}Description${ENDCOLOR}"
        msg="$msg\n${BOLD}<empty>${ENDCOLOR}_ _Stage all changes, create WIP commit, and push"
        msg="$msg\n${BOLD}nopush${ENDCOLOR}_np|n_Stage all changes and create WIP commit without pushing"
        msg="$msg\n${BOLD}help${ENDCOLOR}_h_Show this help"
        echo -e "$(echo -e "$msg" | column -ts'_')"
        echo
        echo -e "Use ${YELLOW}gitb unwip${ENDCOLOR} to undo the WIP commit and restore your changes"
        exit
    fi


    ### Check if there are changes to save
    if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
        echo -e "${GREEN}No changes to save${ENDCOLOR}"
        exit
    fi

    ### Show what will be saved
    echo -e "${YELLOW}Changes to save:${ENDCOLOR}"
    git_status
    echo

    ### Stage all changes
    git add -A

    ### Create WIP commit with branch context
    wip_message="wip: ${current_branch} work in progress"

    result=$(git commit -m "$wip_message" 2>&1)
    commit_code=$?

    if [ $commit_code -ne 0 ]; then
        echo -e "${RED}Cannot create WIP commit! Error message:${ENDCOLOR}"
        echo "$result"
        git reset HEAD 2>/dev/null
        exit $commit_code
    fi

    commit_hash=$(git rev-parse HEAD)
    echo -e "${GREEN}WIP saved!${ENDCOLOR}"
    echo -e "${BLUE}[$current_branch ${commit_hash::7}]${ENDCOLOR} $wip_message"
    echo

    ### Push if not in nopush mode
    if [ -z "$nopush" ] && [ -n "$origin_name" ]; then
        echo -e "${YELLOW}Pushing WIP...${ENDCOLOR}"
        echo
        push_output=$(git push ${origin_name} ${current_branch} 2>&1)
        push_code=$?

        if [ $push_code -eq 0 ]; then
            echo -e "${GREEN}WIP pushed to ${origin_name}/${current_branch}${ENDCOLOR}"
        else
            echo -e "${YELLOW}Could not push WIP (you can push manually later)${ENDCOLOR}"
            echo "$push_output"
        fi
    elif [ -z "$nopush" ] && [ -z "$origin_name" ]; then
        echo -e "${YELLOW}No remote configured, skipping push${ENDCOLOR}"
    fi

    echo
    echo -e "Restore with: ${YELLOW}gitb unwip${ENDCOLOR}"
}


### Main function for unwip
function unwip_script {
    if [ "$1" == "help" ] || [ "$1" == "h" ]; then
        echo -e "${YELLOW}GIT UNWIP${ENDCOLOR}"
        echo
        echo -e "usage: ${YELLOW}gitb unwip${ENDCOLOR}"
        echo
        echo -e "Undoes the last WIP commit, restoring your changes to the working tree."
        echo -e "Changes will be unstaged so you can re-organize them before committing."
        exit
    fi

    echo -e "${YELLOW}GIT UNWIP${ENDCOLOR}"
    echo

    ### Check if the last commit is a WIP commit
    last_message=$(git log -n 1 --pretty="%s" 2>/dev/null)

    if [[ "$last_message" != wip:* ]]; then
        echo -e "${RED}Last commit is not a WIP commit${ENDCOLOR}"
        echo -e "Last commit: ${YELLOW}$last_message${ENDCOLOR}"
        echo
        echo -e "Use ${YELLOW}gitb undo${ENDCOLOR} to undo a regular commit"
        exit 1
    fi

    ### Show the WIP commit
    wip_commit=$(git log -n 1 --pretty="%s | ${YELLOW}%h${ENDCOLOR} | ${GREEN}%cr${ENDCOLOR}")
    echo -e "${YELLOW}WIP commit to undo:${ENDCOLOR}"
    echo -e "\t$wip_commit"
    echo

    ### Reset the WIP commit (mixed to unstage everything)
    reset_output=$(git reset HEAD~1 2>&1)
    reset_code=$?

    if [ $reset_code -ne 0 ]; then
        echo -e "${RED}Cannot undo WIP commit! Error message:${ENDCOLOR}"
        echo "$reset_output"
        exit $reset_code
    fi

    echo -e "${GREEN}WIP commit undone!${ENDCOLOR}"
    echo
    echo -e "${YELLOW}Restored changes:${ENDCOLOR}"
    git_status
}
