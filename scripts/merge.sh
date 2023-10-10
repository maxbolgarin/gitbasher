#!/usr/bin/env bash

### Script for merging changes between branches
# Read README.md to get more information how to use it
# Use this script only with gitbasher


### Main function - pull current branch and exit (empty flags mode)
# $1: mode
    # empty: merge selected branch to current one (ask to fetch before merge)
    # main: merge main to current one (ask to fetch before merge)
    # to-main: merge current branch to main
function merge_script {
    case "$1" in
        main|master|m)          main="true";;
        to-main|to-master|tm)   to_main="true";;
        help|h)                 help="true";;
        *)
            wrong_mode "merge" $1
    esac

    if [ -n "$help" ]; then
        echo -e "usage: ${YELLOW}gitb merge <mode>${ENDCOLOR}"
        echo
        echo -e "${YELLOW}Available modes${ENDCOLOR}"
        echo -e "<empty>\t\t\tSelect branch to merge info current one and fix conflicts"
        echo -e "main|master|m\t\tMerge $main_branch to current branch and fix conflicts"
        echo -e "to-main|to-master|tm\tSwitch to $main_branch and merge current branch into $main_branch"
        echo -e "help|h\t\t\tShow this help"
        exit
    fi


    ### Merge mode - print header
    header="GIT MERGE"
    if [ -n "${to_main}" ]; then
        header="$header MAIN"
    elif [ -n "${to_main}" ]; then
        header="$header TO MAIN"
    fi

    echo -e "${YELLOW}${header}${ENDCOLOR}"
    echo


    ### Select branch which will be merged
    if [ -n "$main" ]; then
        if [ "$current_branch" == "${main_branch}" ]; then
            echo -e "${YELLOW}Already on ${main_branch}${ENDCOLOR}"
            exit
        fi
        merge_branch=${main_branch}

    elif [ -n "$to_main" ]; then
        if [ "$current_branch" == "${main_branch}" ]; then
            echo -e "${YELLOW}Already on ${main_branch}${ENDCOLOR}"
            exit
        fi
        merge_branch=${current_branch}

    else
        echo -e "${YELLOW}Which branch merge into '${current_branch}'?${ENDCOLOR}"
        choose_branch "merge"
        merge_branch=${branch_name}
        echo
    fi


    ### Fetch before merge
    echo -e "Do you want to merge ${YELLOW}${origin_name}/${merge_branch}${ENDCOLOR} instead of local ${YELLOW}${merge_branch}${ENDCOLOR} (y/n)?"
    read -n 1 -s choice
    if [ "$choice" == "y" ]; then
        echo
        echo -e "${YELLOW}Fetching...${ENDCOLOR}"

        fetch $merge_branch $origin_name
        merge_from_origin=true
    fi
    echo


    ### Run merge-to-main logic - switch to main and merge
    if [ -n "$to_main" ]; then
        switch $main_branch "true"
        echo
        current_branch=$main_branch
    fi


    ### Run merge and handle conflicts
    merge $merge_branch $origin_name $editor $merge_from_origin


    ### Nothing to merge
    if [[ $merge_output == *"Already up to date"* ]]; then
        echo -e "${GREEN}Nothing to merge - already up to date${ENDCOLOR}"
        exit
    fi


    ### If we get here - it is success
    #echo -e "${GREEN}Successful merge!${ENDCOLOR}"
    #echo -e "${BLUE}[${merge_branch}${ENDCOLOR} -> ${BLUE}${current_branch}]${ENDCOLOR}"
    #echo


    ### Merged without conflicts
    if [ $merge_code == 0 ] ; then
        print_changes_stat "$(echo "$merge_output" | tail -n +3)" 

    ### Merged with conflicts, but they were resolved
    else
        commit_hash="$(git --no-pager log --pretty="%h" -1)"
        print_changes_stat "$(git --no-pager show $commit_hash --stat --format="")" 
    fi

}