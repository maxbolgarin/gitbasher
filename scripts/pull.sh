#!/usr/bin/env bash

### Script for pulling commits from remote git repository
# Read README.md to get more information how to use it
# Use this script only with gitbasher


### Main function
# $1: mode
    # <empty> - pull current branch using default merge strategy
    # fetch: just fetch current branch
    # all: fetch all
    # upd: run git remote update to fetch all branches
    # ffonly: fast forward only
    # merge: pull current branch using default merge strategy
    # rebase: pull current branch using rebase or fast forward if it is possible
    # interactive: pull current branch using interactive rebase
function pull_script {
    case "$1" in
        fetch|fe)           fetch="true";;
        all|fa)             fetch="true"; all="true";;
        upd|u)              update="true";;
        ffonly|ff)          ffonly="true";;
        merge|m)            ;; # default mode
        rebase|r)           rebase="true";;
        interactive|i|ri)   rebase="true"; interactive="true";;
        help|h)             help="true";;
        *)
            wrong_mode "pull" $1
    esac

    if [ -n "$help" ]; then
        echo -e "usage: ${YELLOW}gitb pull${ENDCOLOR}"
        echo
        echo -e "${YELLOW}Available modes${ENDCOLOR}"
        echo -e "<empty>\t\t\tFetch current branch and then merge changes with conflicts fixing"
        echo -e "fetch|fe\t\tFetch current branch without merge"    
        echo -e "all|fa\t\t\tFetch all without merge"
        echo -e "upd|u\t\t\tRun git remote update to fetch all branches"
        echo -e "ffonly|ff\t\tFetch and then merge in fast forward only mode"
        echo -e "merge|m\t\t\tFetch current branch and then merge it (default mode)"
        echo -e "rebase|r\t\tFetch current branch and then rebase"
        echo -e "interactive|ri|i\tFetch current branch and then rebase in interactive mode"
        echo -e "help|h\t\t\tShow this help"
        exit
    fi

    mode="merge"
    if [ -n "$rebase" ]; then
        mode="rebase"
    fi

    ### Print header
    header_msg="GIT PULL"
    if [ -n "${fetch}" ]; then
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
    elif [ -n "${update}" ]; then
        header_msg="$header_msg REMOTE UPDATE"
    fi

    echo -e "${YELLOW}${header_msg}${ENDCOLOR}"
    echo

    if [ -n "$fetch" ]; then
        if [ -n "$all" ]; then
            echo -e "${YELLOW}Fetching all...${ENDCOLOR}"
        else
            echo -e "${YELLOW}Fetching '$origin_name/$current_branch'...${ENDCOLOR}"
        fi
        echo

        fetch $current_branch $origin_name $all

        if [ $fetch_code == 0 ] ; then
            if [ -n "$all" ]; then
                echo -e "${GREEN}Successfully fetched all!${ENDCOLOR}"
            else
                echo -e "${GREEN}Successfully fetched '$origin_name/$current_branch'!${ENDCOLOR}"
            fi
            if [ "$fetch_output" != "" ]; then
                echo
                echo -e "$fetch_output"
            fi
            commits=$(commit_list 999 "tab" HEAD..$origin_name/$current_branch)
            if [ "$commits" != "" ]; then
                echo
                count=$(echo $commits | wc -l | sed 's/^ *//;s/ *$//')
                echo -e "Your branch is behind ${YELLOW}$origin_name/$current_branch${ENDCOLOR} by ${BOLD}$count${ENDCOLOR} commits:"
                echo -e "$commits"
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
            echo -e "${GREEN}Successfully updated from remote!${ENDCOLOR}"
            if [ "$update_output" != "" ]; then
                echo
                echo -e "$update_output"
            fi
            exit
        fi

        echo -e "${RED}Cannot update! Error message:${ENDCOLOR}"
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
        fetch_output=$(git fetch $2 $1 2>&1)
        fetch_code=$?
    fi

    if [ $fetch_code == 0 ] ; then
        return
    fi

    if [[ ${fetch_output} != *"couldn't find remote ref"* ]]; then
        echo -e "${RED}Cannot fetch '$1'! Error message:${ENDCOLOR}"
        echo -e "${fetch_output}"
        exit $fetch_code
    fi

    echo -e "${YELLOW}There is no '$1' in $2${ENDCOLOR}"
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

    if [ "$4" == "rebase" ]; then
        rebase_branch $1 $2 "true" $interactive
    else 
        merge $1 $2 $3 "pull" "true" $5
    fi 

    ### Nothing to pull
    if ([[ "$4" == "rebase" ]] && [[ "$rebase_output" == "" ]]) || [[ $merge_output == *"Already up to date"* ]]; then
        if [ "$4" == "rebase" ]; then
            echo
        fi       
        echo -e "${GREEN}Already up to date${ENDCOLOR}"
        return
    fi

    ### It will exit if critical error or resolve conflicts, so here we can get only in case of success
    echo -e "${GREEN}Successful pull!${ENDCOLOR}"
    echo

    if [ "$fetch_output" != "" ]; then
        echo -e "$fetch_output"
        echo -e "Origin is ahead of local by this commits:"
        echo -e $(commit_list 999 "tab" HEAD..$2/$1)
        echo
    fi

    commit_hash=$(git rev-parse HEAD)
    echo -e "${BLUE}[$current_branch ${commit_hash::7}]${ENDCOLOR}"
    echo -e "${YELLOW}$(git log -1 --pretty=%B | cat)${ENDCOLOR}"
    echo

    if [ "$4" == "rebase" ] ; then 
        echo "$rebase_output"
    else
        ### Merge without conflicts
        if [ $merge_code == 0 ] ; then
            changes=$(echo "$merge_output" | tail -n +2)
            if [[ -n "$changes" ]]; then
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
