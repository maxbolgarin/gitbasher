#!/usr/bin/env bash

### Script for quick work-in-progress save and restore.
# wip up   — stash all changes as "wip" and push a backup branch to origin
# wip down — pop the wip stash for the current branch (and remove the remote backup)
# Use this script only with gitbasher


### Build the stash message used for the wip stash on the current branch
function wip_stash_message {
    echo "wip: ${current_branch}"
}


### Build the remote backup branch name for the current branch
function wip_remote_branch {
    echo "wip/${current_branch}"
}


### Find the most recent wip stash for the current branch
# Sets:
#     wip_stash_ref - e.g. 'stash@{2}', or empty if not found
function find_wip_stash {
    wip_stash_ref=""
    local target
    target="$(wip_stash_message)"
    while IFS= read -r line; do
        local ref="${line%%:*}"
        local subject="${line#*: }"
        if [ "$subject" = "On ${current_branch}: ${target}" ] || [ "$subject" = "WIP on ${current_branch}: ${target}" ] || [[ "$line" == *"${target}"* ]]; then
            wip_stash_ref="$ref"
            return 0
        fi
    done < <(git stash list)
    [ -n "$wip_stash_ref" ]
}


### Subcommand: stash all changes and (optionally) push a backup to origin
# $1: nopush mode flag (nopush|np|n)
function wip_up {
    local nopush=""
    case "$1" in
        nopush|np|n)    nopush="true";;
        "")             ;;
        *)              wrong_mode "wip up" "$1";;
    esac

    local header_msg="GIT WIP UP"
    if [ -n "$nopush" ]; then
        header_msg="$header_msg (NO PUSH)"
    fi
    echo -e "${YELLOW}${header_msg}${ENDCOLOR}"
    echo

    if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
        echo -e "${GREEN}No changes to save${ENDCOLOR}"
        exit
    fi

    echo -e "${YELLOW}Changes to save:${ENDCOLOR}"
    git_status
    echo

    local message
    message="$(wip_stash_message)"

    local stash_output stash_code
    stash_output=$(git stash push --include-untracked --message "$message" 2>&1)
    stash_code=$?

    if [ $stash_code -ne 0 ]; then
        echo -e "${RED}Cannot stash changes! Error message:${ENDCOLOR}"
        echo "$stash_output"
        exit $stash_code
    fi

    local stash_hash
    stash_hash=$(git rev-parse --short stash@{0} 2>/dev/null)
    echo -e "${GREEN}WIP stashed!${ENDCOLOR} ${BLUE}[${stash_hash}]${ENDCOLOR} $message"
    echo

    if [ -n "$nopush" ]; then
        echo -e "Restore with: ${YELLOW}gitb wip down${ENDCOLOR}"
        return
    fi

    if [ -z "$origin_name" ]; then
        echo -e "${YELLOW}No remote configured, skipping push${ENDCOLOR}"
        echo
        echo -e "Restore with: ${YELLOW}gitb wip down${ENDCOLOR}"
        return
    fi

    local remote_branch
    remote_branch="$(wip_remote_branch)"
    echo -e "${YELLOW}Pushing WIP backup to ${origin_name}/${remote_branch}...${ENDCOLOR}"
    local push_output push_code
    push_output=$(git push --force "${origin_name}" "stash@{0}:refs/heads/${remote_branch}" 2>&1)
    push_code=$?

    if [ $push_code -eq 0 ]; then
        echo -e "${GREEN}WIP pushed to ${origin_name}/${remote_branch}${ENDCOLOR}"
    else
        echo -e "${YELLOW}Could not push WIP backup (you can push manually later)${ENDCOLOR}"
        echo "$push_output"
    fi

    echo
    echo -e "Restore with: ${YELLOW}gitb wip down${ENDCOLOR}"
}


### Subcommand: pop the most recent wip stash for the current branch
function wip_down {
    case "$1" in
        "")     ;;
        *)      wrong_mode "wip down" "$1";;
    esac

    echo -e "${YELLOW}GIT WIP DOWN${ENDCOLOR}"
    echo

    if ! find_wip_stash; then
        echo -e "${RED}No WIP stash found for branch ${current_branch}${ENDCOLOR}"
        echo
        echo -e "Save one first with: ${YELLOW}gitb wip up${ENDCOLOR}"
        exit 1
    fi

    local stash_summary
    stash_summary=$(git stash list --pretty="%gd | %s | ${GREEN_ES}%cr${ENDCOLOR_ES}" "$wip_stash_ref" 2>/dev/null | head -n 1)
    echo -e "${YELLOW}WIP stash to restore:${ENDCOLOR}"
    echo -e "\t${stash_summary}"
    echo

    local pop_output pop_code
    pop_output=$(git stash pop "$wip_stash_ref" 2>&1)
    pop_code=$?

    if [ $pop_code -ne 0 ]; then
        echo -e "${RED}Cannot restore WIP! Error message:${ENDCOLOR}"
        echo "$pop_output"
        exit $pop_code
    fi

    echo -e "${GREEN}WIP restored!${ENDCOLOR}"
    echo
    echo -e "${YELLOW}Restored changes:${ENDCOLOR}"
    git_status

    if [ -z "$origin_name" ]; then
        return
    fi

    local remote_branch
    remote_branch="$(wip_remote_branch)"
    if ! git ls-remote --exit-code --heads "$origin_name" "$remote_branch" >/dev/null 2>&1; then
        return
    fi

    echo
    echo -e "${YELLOW}Removing remote WIP backup ${origin_name}/${remote_branch}...${ENDCOLOR}"
    local delete_output delete_code
    delete_output=$(git push "$origin_name" --delete "$remote_branch" 2>&1)
    delete_code=$?
    if [ $delete_code -eq 0 ]; then
        echo -e "${GREEN}Remote WIP backup removed${ENDCOLOR}"
    else
        echo -e "${YELLOW}Could not remove remote WIP backup (you can delete it manually later)${ENDCOLOR}"
        echo "$delete_output"
    fi
}


### Print help for the wip command
function wip_help {
    echo -e "${YELLOW}GIT WIP${ENDCOLOR}"
    echo
    echo -e "usage: ${YELLOW}gitb wip <up|down>${ENDCOLOR}"
    echo
    msg="${YELLOW}Mode${ENDCOLOR}_${GREEN}Aliases${ENDCOLOR}_\t${BLUE}Description${ENDCOLOR}"
    msg="$msg\n${BOLD}up${ENDCOLOR}_u_Stash all changes as 'wip' and push a backup branch to remote"
    msg="$msg\n${BOLD}up nopush${ENDCOLOR}_u np|n_Stash all changes as 'wip' without pushing"
    msg="$msg\n${BOLD}down${ENDCOLOR}_d_Restore the WIP stash for the current branch and remove the remote backup"
    msg="$msg\n${BOLD}help${ENDCOLOR}_h_Show this help"
    echo -e "$(echo -e "$msg" | column -ts'_')"
    echo
    echo -e "WIP saves work-in-progress as a git stash and pushes a backup to"
    echo -e "${YELLOW}${origin_name:-origin}/wip/<branch>${ENDCOLOR} so you can recover it from anywhere."
}


### Main function for wip
# $1: subcommand (up|down|help)
# $2: subcommand mode (e.g. nopush for up)
function wip_script {
    case "$1" in
        up|u)           wip_up "$2";;
        down|d)         wip_down "$2";;
        help|h|"")      wip_help;;
        *)              wrong_mode "wip" "$1";;
    esac
}
