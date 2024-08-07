#!/usr/bin/env bash

### Script for pushing commits to a remote git repository
# It will pull current branch if there are unpulled changes
# Read README.md to get more information how to use it
# Use this script only with gitbasher


### Use this function to push changes to origin
### It will exit if everyrhing is ok or there is a critical error, return if there is unpulled changes
# $1: arguments
# Using of global:
#     * current_branch
#     * main_branch
#     * origin_name
# Returns:
#     * push_output
#     * push_code
function push {
    push_output=$(git push $1 ${origin_name} ${current_branch} 2>&1)
    push_code=$?

    if [ $push_code -eq 0 ] ; then 
        echo -e "${GREEN}Successful push!${ENDCOLOR}"

        repo=$(get_repo)
        echo -e "${YELLOW}Repo:${ENDCOLOR}\t${repo}"
        if [[ ${current_branch} != ${main_branch} ]]; then
            ### TODO: check if PR have been created
            if [[ $repo == *"github"* ]]; then
                echo -e "${YELLOW}PR:${ENDCOLOR}\t${repo}/pull/new/${current_branch}"
            elif [[ $repo == *"gitlab"* ]]; then
                echo -e "${YELLOW}MR:${ENDCOLOR}\t${repo}/merge_requests/new?merge_request%5Bsource_branch%5D=${current_branch}"
            fi
        fi
        exit
    fi

    if [[ $push_output != *"[rejected]"* ]]; then
        echo -e "${RED}Cannot push! Here is the error${ENDCOLOR}"
        echo "$push_output"
        exit $push_code
    fi
}


### Main function
# $1: mode
    # <empty> - regular commit mode
    # yes: fast push (answer 'yes')
    # force: force push
    # list: print list of commits to push and exit
function push_script {
    case "$1" in
        yes|y)      fast="true";;
        force|f)    force="true";;
        list|log|l) list="true";;
        help|h)     help="true";;
        *)
            wrong_mode "push" $1
    esac

    if [ -n "$help" ]; then
        echo -e "usage: ${YELLOW}gitb push <mode>${ENDCOLOR}"
        echo
        echo -e "${YELLOW}Available modes${ENDCOLOR}"
        echo -e "<empty>\t\tPrint list of commits, push them to current branch or pull changes first"
        echo -e "yes|y\tSame as previous but without pressing 'y'"
        echo -e "force|f\tSame as previous but with --force"
        echo -e "list|log|l\tPrint a list of unpushed local commits without actual pushing it"
        echo -e "help|h\t\tShow this help"
        exit
    fi


    ### Print header
    header_msg="GIT PUSH"
    if [ -n "${fast}" ]; then
        header_msg="$header_msg FAST"
    elif [ -n "${force}" ]; then
        header_msg="$header_msg ${RED}FORCE${ENDCOLOR}"
    elif [ -n "${list}" ]; then
        header_msg="$header_msg LIST"
    fi

    echo -e "${YELLOW}${header_msg}${ENDCOLOR}"
    echo

    ### Check if there are commits to push
    get_push_list ${current_branch} ${main_branch} ${origin_name}

    if [ -z "$push_list" ]; then
        echo -e "${GREEN}Nothing to push${ENDCOLOR}"
        exit
    fi

    if [ "${history_from}" != "${origin_name}/${current_branch}" ]; then
        echo -e "Branch ${YELLOW}${current_branch}${ENDCOLOR} doesn't exist in ${origin_name}, get commits diff from the base commit"
    fi

    ### Print list of unpushed commits
    echo -e "${YELLOW}Commit history from '${history_from}'${ENDCOLOR}"
    echo -e "$push_list"


    ### List mode - print only unpushed commits
    if [ -n "$list" ]; then
        exit
    fi

    echo

    if [ -n "${force}" ]; then
        force_arg=" --force"
    fi

    ### If not in fast mode - ask if user wants to push
    if [ -z "${fast}" ]; then
        echo -e "Do you want to push${RED}${force_arg}${ENDCOLOR} this commits to ${YELLOW}${origin_name}/${current_branch}${ENDCOLOR} (y/n)?"
        if [ "${current_branch}" == "${main_branch}" ]; then
            echo -e "${RED}Warning!${ENDCOLOR} You are going to push right in the default ${YELLOW}${main_branch}${ENDCOLOR} branch"
        fi
        yes_no_choice "Pushing..."
    else
        echo -e "${YELLOW}Pushing...${ENDCOLOR}"
        echo
    fi


    ### Pushing
    push $force_arg


    ### Get push error - there is unpulled changes
    echo -e "${RED}Cannot push!${ENDCOLOR} There are unpulled changes in ${YELLOW}${origin_name}/${current_branch}${ENDCOLOR}"
    echo
    echo -e "Do you want to pull ${YELLOW}${origin_name}/${current_branch}${ENDCOLOR} with rebase (y/n)?"
    yes_no_choice "Pulling..."

    pull $current_branch $origin_name $editor


    ### Push after pull
    echo
    echo -e "${YELLOW}Pushing...${ENDCOLOR}"
    echo
    push $force_arg
}