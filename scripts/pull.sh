#!/usr/bin/env bash

### Script for pulling commits from remote git repository
# Read README.md to get more information how to use it
# Use this script only with gitbasher


### Main function
# $1: mode
    # <empty>: fetch current branch and ask about strategy
    # fetch: just fetch current branch
    # all: fetch all
    # upd: run git remote update to fetch all branches
    # ffonly: fast forward only
    # merge: pull current branch using default merge strategy
    # rebase: pull current branch using rebase or fast forward if it is possible
    # interactive: pull current branch using interactive rebase with --autosquash
function pull_script {
    case "$1" in
        fetch|fe)           fetch="true";;
        all|fa)             fetch="true"; all="true";;
        upd|u)              update="true";;
        ffonly|ff)          ffonly="true";;
        merge|m)            merge="true";;
        rebase|r)           rebase="true";;
        interactive|ri|rs)  rebase="true"; interactive="true";;
        dry|d|dr)           dry="true";;
        help|h)             help="true";;
        *)
            wrong_mode "pull" $1
    esac


    ### Print header
    header_msg="GIT PULL"
    if [ -n "${dry}" ]; then
        header_msg="$header_msg DRY RUN"
    elif [ -n "${fetch}" ]; then
        if [ -n "${all}" ]; then
            header_msg="$header_msg FETCH ALL"
        else
            header_msg="$header_msg FETCH"
        fi
    elif [ -n "${rebase}" ]; then
        if [ -n "${interactive}" ]; then
            header_msg="$header_msg INTERACTIVE REBASE"
        else
            header_msg="$header_msg REBASE"
        fi
    elif [ -n "${ffonly}" ]; then
        header_msg="$header_msg FAST FORWARD ONLY"
    elif [ -n "${merge}" ]; then
        header_msg="$header_msg MERGE"
    elif [ -n "${update}" ]; then
        header_msg="$header_msg REMOTE UPDATE"
    fi

    echo -e "${YELLOW}${header_msg}${ENDCOLOR}"
    echo


    if [ -n "$help" ]; then
        # kcov-skip-start
        echo -e "usage: ${YELLOW}gitb pull <mode>${ENDCOLOR}"
        echo
        local PAD=22
        print_help_header $PAD
        print_help_row $PAD "<empty>"      ""       "Fetch current branch, fast-forward if possible, otherwise ask"
        print_help_row $PAD "fetch"        "fe"     "Fetch current branch without merging"
        print_help_row $PAD "all"          "fa"     "Fetch every branch without merging"
        print_help_row $PAD "upd"          "u"      "Run ${BLUE}git remote update${ENDCOLOR} to fetch all branches"
        print_help_row $PAD "ffonly"       "ff"     "Fetch and merge only if a fast-forward is possible"
        print_help_row $PAD "merge"        "m"      "Fetch and merge the current branch"
        print_help_row $PAD "rebase"       "r"      "Fetch and rebase the current branch"
        print_help_row $PAD "interactive"  "ri, rs" "Fetch and interactively rebase with ${BLUE}--autosquash${ENDCOLOR}"
        print_help_row $PAD "dry"          "d, dr"  "Preview incoming commits without modifying local refs"
        print_help_row $PAD "help"         "h"      "Show this help"
        echo
        echo -e "${YELLOW}Examples${ENDCOLOR}"
        echo -e "  ${GREEN}gitb pull${ENDCOLOR}          Fetch + fast-forward, ask if a merge or rebase is needed"
        echo -e "  ${GREEN}gitb pull dry${ENDCOLOR}      See what would arrive, without touching local refs"
        echo -e "  ${GREEN}gitb pull rebase${ENDCOLOR}   Fetch and rebase local commits on top of the remote"
        echo -e "  ${GREEN}gitb pull ffonly${ENDCOLOR}   Refuse to pull unless a clean fast-forward is possible"
        exit
        # kcov-skip-end
    fi


    if [ -n "$rebase" ]; then
        mode="rebase"
    elif [ -n "$merge" ]; then
        mode="merge"
    fi

    if [ -z "$origin_name" ]; then
        echo -e "${RED}✗ No git remote configured.${ENDCOLOR}"
        echo -e "Run ${GREEN}git remote add origin <url>${ENDCOLOR} to set one up."
        exit 1
    fi

    if [ -n "$dry" ]; then
        echo -e "${YELLOW}Checking '$origin_name/$current_branch' for incoming commits...${ENDCOLOR}"
        echo

        ### Snapshot the remote-tracking ref so we can restore it after the fetch.
        ### git fetch always honors the configured refs/heads/*:refs/remotes/origin/* refspec,
        ### even when an explicit refspec is also passed, so we have to roll back manually.
        remote_tracking_ref="refs/remotes/$origin_name/$current_branch"
        saved_ref=$(git rev-parse --verify --quiet "$remote_tracking_ref")

        dry_output=$(git fetch --no-tags "$origin_name" "$current_branch" 2>&1)
        dry_code=$?

        ### Restore the remote-tracking ref to its pre-dry-run value
        if [ -n "$saved_ref" ]; then
            git update-ref "$remote_tracking_ref" "$saved_ref" 2>/dev/null
        else
            git update-ref -d "$remote_tracking_ref" 2>/dev/null
        fi

        if [ $dry_code != 0 ]; then
            if [[ "$dry_output" == *"couldn't find remote ref"* ]]; then
                echo -e "${YELLOW}Branch '$current_branch' does not exist on $origin_name.${ENDCOLOR}"
                exit
            fi
            echo -e "${RED}✗ Cannot fetch.${ENDCOLOR}"
            echo -e "$dry_output"
            exit $dry_code
        fi

        ### FETCH_HEAD now points at the just-fetched tip — diff against HEAD
        behind_commits=$(commit_list 999 "tab" "HEAD..FETCH_HEAD")
        ahead_commits=$(commit_list 999 "tab" "FETCH_HEAD..HEAD")

        if [ -z "$behind_commits" ] && [ -z "$ahead_commits" ]; then
            echo -e "${GREEN}✓ Already up to date${ENDCOLOR}"
            echo
            echo -e "${BLUE}Dry run only — no local refs were modified${ENDCOLOR}"
            exit
        fi

        if [ -n "$behind_commits" ]; then
            behind_count=$(echo -e "$behind_commits" | wc -l | sed 's/^ *//;s/ *$//')
            echo -e "Your branch is behind ${YELLOW}$origin_name/$current_branch${ENDCOLOR} by ${BOLD}$behind_count${ENDCOLOR} commits"
            echo -e "$behind_commits"
        fi

        if [ -n "$ahead_commits" ]; then
            if [ -n "$behind_commits" ]; then
                echo
            fi
            ahead_count=$(echo -e "$ahead_commits" | wc -l | sed 's/^ *//;s/ *$//')
            echo -e "Your branch is ahead of ${YELLOW}$origin_name/$current_branch${ENDCOLOR} by ${BOLD}$ahead_count${ENDCOLOR} commits"
            echo -e "$ahead_commits"
        fi

        echo
        echo -e "${BLUE}Dry run only — no local refs were modified${ENDCOLOR}"
        echo -e "Run ${YELLOW}gitb pull${ENDCOLOR} to apply changes"
        exit
    fi

    if [ -n "$fetch" ]; then
        if [ -n "$all" ]; then
            echo -e "${YELLOW}Fetching all...${ENDCOLOR}"
        else
            echo -e "${YELLOW}Fetching '$origin_name/$current_branch'...${ENDCOLOR}"
        fi
        echo

        fetch "$current_branch" "$origin_name" "$all"

        if [ $fetch_code == 0 ] ; then
            commits=$(commit_list 999 "tab" "HEAD..$origin_name/$current_branch")
            if [ "$commits" != "" ]; then
                if [ -n "$all" ]; then
                    echo -e "${GREEN}✓ Fetched all remotes${ENDCOLOR}"
                else
                    echo -e "${GREEN}✓ Fetched '$origin_name/$current_branch'${ENDCOLOR}"
                fi
                if [ "$fetch_output" != "" ]; then
                    echo
                    echo -e "$fetch_output"
                fi
                echo
                count=$(echo -e "$commits" | wc -l | sed 's/^ *//;s/ *$//')
                echo -e "Your branch is behind ${YELLOW}$origin_name/$current_branch${ENDCOLOR} by ${BOLD}$count${ENDCOLOR} commits"
                echo -e "$commits"
            else
                echo -e "${GREEN}✓ Already up to date${ENDCOLOR}"
            fi
        fi

        exit
    fi

    if [ -n "$update" ]; then
        echo -e "${YELLOW}Updating from remote...${ENDCOLOR}"
        echo
        update_output=$(git remote update 2>&1)
        update_code=$?
        
        if [ $update_code == 0 ] ; then
            commits=$(commit_list 999 "tab" "HEAD..$origin_name/$current_branch")
            if [ "$commits" != "" ]; then
                echo -e "${GREEN}✓ Updated all remotes${ENDCOLOR}"
                if [ "$update_output" != "" ]; then
                    echo
                    echo -e "$update_output"
                fi
                echo
                count=$(echo -e "$commits" | wc -l | sed 's/^ *//;s/ *$//')
                echo -e "Your branch is behind ${YELLOW}$origin_name/$current_branch${ENDCOLOR} by ${BOLD}$count${ENDCOLOR} commits"
                echo -e "$commits"
            else
                echo -e "${GREEN}✓ Already up to date${ENDCOLOR}"
            fi
            exit
        fi

        echo -e "${RED}✗ Cannot update from remote.${ENDCOLOR}"
        echo -e "${update_output}"
        exit $update_code
    fi
    
    echo -e "${YELLOW}Pulling '$origin_name/$current_branch'...${ENDCOLOR}"
    echo
    pull $current_branch $origin_name $editor $mode $ffonly 
    exit
}


### Function fetchs provided branch and handles errors
# $1: branch name
# $2: origin name
# $3: is all
# Returns:
#      * fetch_code - if it is not zero - there is no such branch in origin
function fetch {
    if [ -n "$3" ]; then
        fetch_output=$(git fetch --all 2>&1)
        fetch_code=$?
    else
        fetch_output=$(git fetch "$2" "$1" 2>&1)
        fetch_code=$?
    fi

    if [ $fetch_code == 0 ] ; then
        return
    fi

    if [[ ${fetch_output} != *"couldn't find remote ref"* ]]; then
        echo -e "${RED}✗ Cannot fetch '$1'.${ENDCOLOR}"
        echo -e "${fetch_output}"
        exit $fetch_code
    fi

    echo -e "${YELLOW}Branch '$1' does not exist on $2.${ENDCOLOR}"
}


### Function pulls provided branch and handles errors
# $1: branch name
# $2: origin name
# $3: editor
# $4: mode - merge or rebase
# $5: ffonly
function pull {
    ### Fetch, it will exit if critical error and return if branch doesn't exists in origin
    fetch $1 $2

    if [ $fetch_code != 0 ] ; then
        return
    fi

    merge_output=$(git merge --ff-only $2/$1 2>&1)
    merge_code=$?
    mode="fast-forward"

    if [[ $merge_output == *"Already up to date"* ]]; then
        echo -e "${GREEN}✓ Already up to date${ENDCOLOR}"
        return
    fi

    if [ $merge_code != 0 ] ; then
        if [[ $merge_output != *"possible to fast-forward"* ]]; then
            echo -e "${RED}✗ Cannot pull.${ENDCOLOR}"
            echo "$merge_output"
            exit $merge_code
        fi

        if [ -n "$5" ]; then
            echo -e "${RED}✗ Cannot fast-forward — fast-forward-only mode is enabled, aborting pull.${ENDCOLOR}"
            exit 1
        fi

        commits=$(commit_list 999 "tab" HEAD..$origin_name/$current_branch)
        count=$(echo -e "$commits" | wc -l | sed 's/^ *//;s/ *$//')

        echo -e "Your branch is behind ${YELLOW}$origin_name/$current_branch${ENDCOLOR} by ${BOLD}$count${ENDCOLOR} commits"
        echo -e "$commits"
        echo

        mode=$4
        if [ "$4" == "merge" ]; then
            echo -e "${YELLOW}Merging...${ENDCOLOR}"
            choice="1"
        elif [ "$4" == "rebase" ]; then
            echo -e "${YELLOW}Rebasing...${ENDCOLOR}"
            choice="2"
        else
            echo -e "${YELLOW}⚠  Cannot fast-forward.${ENDCOLOR} Choose an option:"
            echo -e "1. ${BLUE}Merge${ENDCOLOR} — preserves commit timeline; creates a merge commit:"
            echo -e "\t\t${YELLOW}Merge remote-tracking branch '$origin_name/$current_branch' into $current_branch${ENDCOLOR}"
            echo -e "2. ${BLUE}Rebase${ENDCOLOR} — replays your local commits on top of the remote branch"
            echo -e "0. ${BLUE}Exit${ENDCOLOR} — leave the branch unchanged"

            read -n 1 -s choice
            re='^[120]+$'
            if ! [[ $choice =~ $re ]]; then
                exit 0
            fi
        fi

        echo

        if [ "$choice" == "1" ]; then
            merge $1 $2 $3 "pull" "true" $5
            mode="merge"
            if [ $merge_code != 0 ] ; then
                echo
           fi
        elif [ "$choice" == "2" ]; then
           rebase_branch $1 $2 "true" $interactive $interactive
           mode="rebase"
           if [ $rebase_code != 0 ] ; then
                echo
           fi
        else
            echo -e "${YELLOW}Exiting...${ENDCOLOR}"
            exit 0
        fi
    fi

    echo -e "${GREEN}✓ Pulled using $mode${ENDCOLOR}"

    if [ "$mode" == "merge" ] || [ "$mode" == "fast-forward" ]; then 
        ### Merge without conflicts
        if [ $merge_code == 0 ] ; then
            if [[ $merge_output == *"made by the"* ]]; then
                changes=$(echo "$merge_output" | tail -n +3)
            else
                changes=$(echo "$merge_output" | tail -n +2)
            fi
            if [[ -n "$changes" ]]; then
                echo
                print_changes_stat "$changes"
            fi

        ### Merge with conflicts, but they were resolved
        else
            commit_hash="$(git --no-pager log --pretty="%h" -1)"
            changes=$(git --no-pager show $commit_hash --stat --format="")
            if [[ -n "$changes" ]]; then
                print_changes_stat "$changes"
            fi
        fi
    fi
}
