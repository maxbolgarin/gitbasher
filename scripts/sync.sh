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
        dry|d|dr)       sync_dry="true";;
        help|h)         help="true";;
        *)
            wrong_mode "sync" $1
    esac
    # kcov-skip-start


    ### Print header
    header_msg="GIT SYNC"
    if [ -n "${sync_dry}" ]; then
        header_msg="$header_msg DRY RUN"
    elif [ -n "${sync_merge}" ]; then
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
        # kcov-skip-start
        echo -e "usage: ${YELLOW}gitb sync <mode>${ENDCOLOR}"
        echo
        local PAD=18
        print_help_header $PAD
        print_help_row $PAD "<empty>" ""       "Fetch $main_branch and rebase the current branch onto it"
        print_help_row $PAD "push"    "p"      "Rebase, then force-push the rebased branch"
        print_help_row $PAD "merge"   "m"      "Fetch $main_branch and merge it into the current branch"
        print_help_row $PAD "mergep"  "mp, pm" "Merge $main_branch into current, then push"
        print_help_row $PAD "dry"     "d, dr"  "Preview incoming commits without modifying local refs"
        print_help_row $PAD "help"    "h"      "Show this help"
        echo
        echo -e "${YELLOW}Examples${ENDCOLOR}"
        echo -e "  ${GREEN}gitb sync${ENDCOLOR}        Rebase current branch on top of ${YELLOW}$main_branch${ENDCOLOR}"
        echo -e "  ${GREEN}gitb sync push${ENDCOLOR}   Rebase, then force-push (use after a clean rebase)"
        echo -e "  ${GREEN}gitb sync merge${ENDCOLOR}  Merge ${YELLOW}$main_branch${ENDCOLOR} into current branch (preserves history)"
        echo -e "  ${GREEN}gitb sync dry${ENDCOLOR}    Preview what sync would change, without touching anything"
        exit
        # kcov-skip-end
    fi


    ### Check if already on default branch
    if [ "$current_branch" == "$main_branch" ]; then
        if [ -n "$sync_dry" ]; then
            echo -e "${YELLOW}Already on ${main_branch} — use ${BOLD}gitb pull dry${NORMAL}${YELLOW} instead.${ENDCOLOR}"
        else
            echo -e "${YELLOW}Already on ${main_branch} — use ${BOLD}gitb pull${NORMAL}${YELLOW} instead.${ENDCOLOR}"
        fi
        exit
    fi


    ### Dry-run mode: preview the sync without modifying any local state
    if [ -n "$sync_dry" ]; then
        if [ -z "$origin_name" ]; then
            echo -e "${RED}✗ No git remote configured.${ENDCOLOR}"
            echo -e "Run ${GREEN}git remote add origin <url>${ENDCOLOR} to set one up."
            exit 1
        fi

        echo -e "${YELLOW}Checking ${origin_name}/${main_branch} for incoming commits...${ENDCOLOR}"
        echo

        ### Snapshot the remote-tracking ref so we can restore it after the fetch.
        ### git fetch always honors the configured refs/heads/*:refs/remotes/origin/* refspec,
        ### so we save the current value and roll it back once we've inspected FETCH_HEAD.
        remote_tracking_ref="refs/remotes/$origin_name/$main_branch"
        saved_ref=$(git rev-parse --verify --quiet "$remote_tracking_ref")

        dry_output=$(git fetch --no-tags "$origin_name" "$main_branch" 2>&1)
        dry_code=$?

        if [ -n "$saved_ref" ]; then
            git update-ref "$remote_tracking_ref" "$saved_ref" 2>/dev/null
        else
            git update-ref -d "$remote_tracking_ref" 2>/dev/null
        fi

        if [ $dry_code != 0 ]; then
            echo -e "${RED}✗ Cannot fetch ${main_branch}.${ENDCOLOR}"
            echo -e "$dry_output"
            exit $dry_code
        fi

        ### Commits on main that current branch doesn't have (would be applied by sync)
        incoming=$(commit_list 999 "tab" "HEAD..FETCH_HEAD")
        ### Commits on current branch not on main (would be replayed during rebase)
        local_only=$(commit_list 999 "tab" "FETCH_HEAD..HEAD")

        if [ -z "$incoming" ]; then
            echo -e "${GREEN}✓ Already up to date with ${main_branch}${ENDCOLOR}"
        else
            incoming_count=$(echo -e "$incoming" | wc -l | sed 's/^ *//;s/ *$//')
            echo -e "${BOLD}$incoming_count${ENDCOLOR} commits on ${YELLOW}${origin_name}/${main_branch}${ENDCOLOR} would be applied to ${YELLOW}${current_branch}${ENDCOLOR}"
            echo -e "$incoming"
        fi

        if [ -n "$local_only" ]; then
            echo
            local_count=$(echo -e "$local_only" | wc -l | sed 's/^ *//;s/ *$//')
            echo -e "${BOLD}$local_count${ENDCOLOR} local commits on ${YELLOW}${current_branch}${ENDCOLOR} would be replayed on top after rebase"
            echo -e "$local_only"
        fi

        echo
        echo -e "${BLUE}Dry run only — no local refs were modified${ENDCOLOR}"
        echo -e "Run ${YELLOW}gitb sync${ENDCOLOR} to apply changes"
        exit
    fi


    ### Check for uncommitted changes
    # --porcelain output is locale-stable; empty == clean working tree.
    is_clean=$(LC_ALL=C git status --porcelain)
    if [ -n "$is_clean" ]; then
        echo -e "${RED}✗ Cannot sync — there are uncommitted changes:${ENDCOLOR}"
        git_status
        echo
        echo -e "${YELLOW}Commit or stash your changes first.${ENDCOLOR}"
        exit 1
    fi


    ### Check remote
    if [ -z "$origin_name" ]; then
        echo -e "${RED}✗ No git remote configured.${ENDCOLOR}"
        echo -e "Run ${GREEN}git remote add origin <url>${ENDCOLOR} to set one up."
        exit 1
    fi


    ### Fetch default branch
    echo -e "${YELLOW}Fetching ${origin_name}/${main_branch}...${ENDCOLOR}"

    fetch $main_branch $origin_name

    if [ $fetch_code != 0 ]; then
        echo -e "${RED}✗ Cannot fetch ${main_branch}.${ENDCOLOR}"
        exit 1
    fi

    echo -e "${GREEN}✓ Fetched ${origin_name}/${main_branch}${ENDCOLOR}"
    echo


    if [ -n "$sync_merge" ]; then
        ### Merge mode
        echo -e "${YELLOW}Merging ${origin_name}/${main_branch} into ${current_branch}...${ENDCOLOR}"
        echo

        merge $main_branch $origin_name $editor "sync" "true"

        if [[ $merge_output == *"Already up to date"* ]]; then
            echo -e "${GREEN}✓ Already up to date with ${main_branch}${ENDCOLOR}"
        else
            # merge() exits on fatal errors, so if we reach here, merge succeeded
            # (merge_code may be non-zero after conflict resolution, but that's ok)
            echo -e "${GREEN}✓ Synced with ${main_branch} using merge${ENDCOLOR}"
            echo -e "${BLUE}[${origin_name}/${main_branch}${ENDCOLOR} -> ${BLUE}${current_branch}]${ENDCOLOR}"
        fi
    else
        ### Rebase mode
        echo -e "${YELLOW}Rebasing ${current_branch} onto ${origin_name}/${main_branch}...${ENDCOLOR}"
        echo

        rebase_branch "$main_branch" "$origin_name" "true"

        if [[ $rebase_output == *"is up to date"* ]]; then
            echo -e "${GREEN}✓ Already up to date with ${main_branch}${ENDCOLOR}"
        elif [ $rebase_code == 0 ]; then
            echo -e "${GREEN}✓ Synced with ${main_branch} using rebase${ENDCOLOR}"
            echo -e "${BLUE}[${origin_name}/${main_branch}${ENDCOLOR} -> ${BLUE}${current_branch}]${ENDCOLOR}"
        else
            echo -e "${RED}✗ Rebase failed — resolve the conflicts and try again.${ENDCOLOR}"
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
            echo -e "${YELLOW}Force-pushing ${current_branch} after rebase...${ENDCOLOR}"
            echo
            push_script f
        fi
    fi
    # kcov-skip-end
}
