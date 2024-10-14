#!/usr/bin/env bash

### Script for working with branches: create, switch, delete
# Use a separate branch for writing new code, then merge it to default branch
# Read README.md to get more information how to use it
# Use this script only with gitbasher


### Main function
# $1: mode
    # <empty>: switch to a local branch
    # remote: switch to a remote branch
    # main: switch to the default branch
    # new: create a new branch from the current one 
    # newd: create a new branch from the default branch
    # delete: delete a local branch
function branch_script {
    case "$1" in
        remote|r|re) remote="true";;
        main|def|m)  main="true";;
        new|n|c)          
            new="true"
            current="true"    
        ;;
        newd|nd)        
            new="true"
        ;;
        delete|del|d) delete="true";;
        help|h)       help="true";;
        *)
            wrong_mode "branch" $1
    esac
    

    if [ -n "$help" ]; then
        echo -e "usage: ${YELLOW}gitb branch <mode>${ENDCOLOR}"
        echo
        echo -e "${YELLOW}Available modes${ENDCOLOR}"
        echo -e "<empty>\t\tSelect a local branch to switch"
        echo -e "remote|re|r\tFetch $origin_name and select a remote branch to switch"
        echo -e "main|def|m\tSwitch to $main_branch without additional confirmations"
        echo -e "new|n|c\t\tBuild a conventional name and create a new branch from $main_branch"
        echo -e "newd|nd\tBuild a conventional name, switch to $main_branch, pull it and create new branch"
        echo -e "delete|del|d\tSelect a branch to delete"
        echo -e "help|h\t\tShow this help"
        exit
    fi
        
    ### Print header
    header="GIT BRANCH"
    if [ -n "${remote}" ]; then
        header="$header REMOTE"
    elif [ -n "${main}" ]; then
        header="$header DEFAULT"
    elif [ -n "${current}" ]; then
        header="$header NEW"
    elif [ -n "${new}" ]; then
        header="$header NEW FROM DEFAULT"
    elif [ -n "${delete}" ]; then
        header="$header DELETE"
    fi

    echo -e "${YELLOW}${header}${ENDCOLOR}"
    echo


    ### Run switch to main logic
    if [[ -n "${main}" ]]; then
        switch ${main_branch}
        exit
    fi


    ### Run switch to local logic
    if [[ -z "$new" ]] && [[ -z "$remote" ]] && [[ -z "$delete" ]]; then
        echo -e "${YELLOW}Select a branch to switch from '${current_branch}'${ENDCOLOR}:"

        choose_branch

        echo

        switch ${branch_name}
        exit


    ### Run switch to remote logic
    elif [[ -z "$new" ]] && [[ -n "$remote" ]] && [[ -z "$delete" ]]; then
        echo -e "${YELLOW}Fetching remote...${ENDCOLOR}"
        echo

        fetch_output=$(git fetch 2>&1)
        check_code $? "$fetch_output" "fetch remote"

        ## TODO: should I ask?
        prune_output=$(git remote prune $origin_name 2>&1)

        echo -e "${YELLOW}Switch from '${current_branch}' to the remote branch${ENDCOLOR}"
        
        choose_branch "remote"

        echo

        switch ${branch_name}
        exit


    ### Run delete local logic
    elif [[ -z "$new" ]] && [[ -n "$delete" ]]; then

        # Try to delete all merged branches
        IFS=$'\n' read -rd '' -a merged_branches <<<"$(git branch -v --sort=-committerdate --merged | cat 2>&1)"

        merged_branches_without_main=()
        for index in "${!merged_branches[@]}"
        do
            branch_with_info="$(echo "${merged_branches[index]}" | sed -e 's/^[[:space:]]*//')"
            if [[ ${branch_with_info} != "${main_branch}"* ]] && [[ ${branch_with_info} != "*"* ]] ; then
                merged_branches_without_main+=("$branch_with_info")
            fi
        done
        number_of_branches=${#merged_branches_without_main[@]}

        if [ $number_of_branches != 0 ]; then
            echo -e "${YELLOW}Do you want to delete merged local branches?${ENDCOLOR}"
            echo -e "These are branches without new changes regarding ${YELLOW}${main_branch}${ENDCOLOR}"
            for index in "${!merged_branches_without_main[@]}"
            do
                printf "\t${merged_branches_without_main[index]}\n"
            done

            printf "\nAnswer (y/n): "
            
            while [ true ]; do
                read -n 1 -s choice
                if [ "$choice" == "y" ]; then
                    printf "y\n\n"
                    branches_to_delete="$(git branch --merged | egrep -v "(^\*|master|main|develop|${main_branch})" | xargs)"
                    IFS=$' ' read -rd '' -a branches <<<"$branches_to_delete"
                    for index in "${!branches[@]}"
                    do
                        branch_to_delete="$(echo "${branches[index]}" | xargs)"
                        delete_output=$(git branch -d $branch_to_delete 2>&1)
                        delete_code=$?
                        if [ $delete_code == 0 ]; then
                            echo -e "${GREEN}Branch '$branch_to_delete' is deleted!${ENDCOLOR}"
                        else
                            echo -e "${RED}Cannot delete branch '$branch_to_delete'!${ENDCOLOR}"
                            echo -e "${delete_output}"
                            break
                        fi
                    done
                    echo
                    break

                else
                    printf "n\n\n"
                    break
                fi
            done
        fi

        # Delete in normal way
        echo -e "${YELLOW}Delete a local branch${ENDCOLOR}"

        choose_branch "delete"

        echo

        delete_output=$(git branch -d $branch_name 2>&1)
        delete_code=$?

        if [ "$delete_code" == 0 ]; then
            echo -e "${GREEN}Branch '$branch_name' is deleted!${ENDCOLOR}"

        elif [[ ${delete_output} == *"is not fully merged"* ]]; then
            echo -e "${RED}The branch '$branch_name' is not fully merged${ENDCOLOR}"
            echo "Do you want to force delete (-D flag) this branch?"

            printf "Answer (y/n): "
            
            while [ true ]; do
                read -n 1 -s choice
                if [ "$choice" == "y" ]; then
                    printf "y\n\n"
                    delete_output=$(git branch -D $branch_name 2>&1)
                    delete_code=$?
                    if [ "$delete_code" != 0 ]; then
                        echo -e "${RED}Cannot delete branch '$branch_name'! Error message:${ENDCOLOR}"
                        echo -e "${delete_output}"
                        exit
                    fi
                    echo -e "${GREEN}Branch '$branch_name' is deleted!${ENDCOLOR}"
                    break

                elif [ "$choice" == "n" ]; then
                    printf "n\n"
                    exit
                fi
            done

        else
            echo -e "${RED}Cannot delete branch '$branch_name'! Error message:${ENDCOLOR}"
            echo -e "${delete_output}"
            exit
        fi

        remote_check=$(git --no-pager log $origin_name/$branch_name..HEAD 2>&1)
        if [[ $remote_check != *"unknown revision or path not in the working tree"* ]]; then
            echo
            echo -e "${YELLOW}Do you want to delete this branch in the remote?${ENDCOLOR}"

            printf "Answer (y/n): "
            
            while [ true ]; do
                read -n 1 -s choice
                if [ "$choice" == "y" ]; then
                    printf "y\n\n"
                    echo -e "${YELLOW}Deleting...${YELLOW}"

                    push_output=$(git push $origin_name -d $branch_name 2>&1)
                    push_code=$?

                    echo
                    if [ "$push_code" != 0 ]; then
                        echo -e "${RED}Cannot delete branch '$branch_name'! Error message:${ENDCOLOR}"
                        echo -e "${delete_output}"
                        exit
                    fi
                    echo -e "${GREEN}Branch '$branch_name' is deleted in the remote!${ENDCOLOR}"
                    break

                elif [ "$choice" == "n" ]; then
                    printf "n\n"
                    exit
                fi
            done
        fi
    
        exit
    fi


    ### Run create new branch logic
    ### Step 1. Select branch type
    echo -e "${YELLOW}Step 1.${ENDCOLOR} What type of branch do you want to create?"
    echo -e "1. feat:\tnew feature or logic changes, 'feat' commits"
    echo -e "2. fix:\t\tsmall changes, eg. not critical bug fix"
    echo -e "3. hotfix:\tfix, that should be merged as fast as possible"
    echo -e "4. wip:\t\t'work in progress', for changes not ready for merging in the near future"
    echo -e "5. misc:\tnon-code changes, e.g. 'ci', 'docs', 'build' commits"
    echo -e "6. test:\testing changes that probably won't be merged to the main branch"
    echo -e "7. chore:\tnon important style or docs changes"
    if [ "$ticket_name" != "" ]; then
        printf "8. $ticket_name:"
        if [ $ticket_name = "" ]; then
            printf "\t"
        else
            printf "\t\t"
        fi
        printf "use ticket name as prefix\n"
    fi
    echo -e "9.  \t\tdon't use prefix for branch naming"
    echo -e "0. Exit without changes"

    declare -A types=(
        [1]="feat"
        [2]="fix"
        [3]="hotfix"
        [4]="wip"
        [5]="misc"
        [6]="test"
        [7]="chore"
        [8]=""
        [9]="$ticket_name"
    )

    branch_type=""
    while [ true ]; do
        read -n 1 -s choice

        re='^[1-9]+$'
        if ! [[ $choice =~ $re ]]; then
            exit
        fi
        
        branch_type="${types[$choice]}"
        if [ -n "$branch_type" ]; then
            branch_type_and_sep="${branch_type}${sep}"
        fi
        break
    done


    ### Step 2. Enter branch name
    echo
    echo -e "${YELLOW}Step 2.${ENDCOLOR} Enter the name of the branch"
    echo "Leave it blank if you want to exit"

    printf "${BOLD}git branch${ENDCOLOR}"
    read -p " ${branch_type_and_sep}" -e branch_name

    if [ -z $branch_name ]; then
        exit
    fi

    branch_name="${branch_type_and_sep}${branch_name##*( )}"

    if [[ "$branch_name" == "HEAD" ]] || [[ "$branch_name" == "$origin_name" ]]; then
        echo
        echo -e "${RED}This name is forbidden${ENDCOLOR}"
        exit
    fi

    ### Step 3. Switch to main and pull it
    from_branch=$current_branch
    if [ -z "${current}" ]; then
        echo
        switch $main_branch "true"

        echo -e "${YELLOW}Pulling '$origin_name/$main_branch'...${ENDCOLOR}"
        echo
        pull $main_branch $origin_name $editor

        from_branch=$main_branch
    fi


    ### Step 4. Create a new branch and switch to it
    create_output=$(git switch -c $branch_name 2>&1)
    create_code=$?

    echo

    if [ $create_code -eq 0 ]; then
        echo -e "${GREEN}${create_output} from '$from_branch'${ENDCOLOR}"
        changes=$(git_status)
        if [ -n "$changes" ]; then
            echo
            echo -e "${YELLOW}Moved changes:${ENDCOLOR}"
            echo -e "${changes}"
        fi
        exit
    fi

    if [[ $create_output == *"already exists"* ]]; then
        echo -e "${RED}Branch with name '${branch_name}' already exists!${ENDCOLOR}"
        exit $create_code
    fi

    echo -e "${RED}Cannot create '${branch_name}'! Error message:${ENDCOLOR}"
    echo "${create_output}"
    exit $create_code
}