#!/usr/bin/env bash

### Main script for running gitbasher

git_check=$(git branch --show-current 2>&1)
if [[ "$git_check" == *"fatal: not a git repository"* ]]; then
    echo "You can use gitb only from directory with inited git repository"
    exit
fi

### Get common and config first
source scripts/common.sh
source scripts/config.sh

### Include all scripts
source scripts/commit.sh
source scripts/push.sh
source scripts/pull.sh
source scripts/merge.sh
source scripts/branch.sh
source scripts/tag.sh
source scripts/gitlog.sh

project_name="$(get_repo_name)"


function print_help {
    echo -e "usage: ${YELLOW}gitb <command> <argument>${ENDCOLOR}"
    echo
    msg="${YELLOW}Command${ENDCOLOR}_\t${YELLOW}Description${ENDCOLOR}"
    msg="$msg\ncommit_everything about commit creation_commit|c|co|cm|com"
    msg="$msg\npush_pushing changes to a remote repository_push|ps|ph"
    msg="$msg\npull_pulling changes from a remote repository_pull|pl|pll"
    msg="$msg\nmerge_merge changes from different branches_merge"
    msg="$msg\nbranch_managing branches_branch|b|br|bh|bra"
    msg="$msg\ntag_managing tags_tag|t|tg"
    msg="$msg\nconfig_configurate gitbasher_config|cfg|conf"
    echo -e "$(echo -e "$msg" | column -ts '_')"

    echo
    echo -e "${YELLOW}Commands without arguments${ENDCOLOR}"
    echo -e "log\t\topen git log in a pretty format"
    echo -e "reflog\t\topen git reflog in a pretty format"
    echo -e "undo-commit\tundo last commit (record from git log)"
    echo -e "undo-action\tundo last action (record from git reflog)"

    exit
}

### Print usage information
if [ -z $1 ] || [ "$1" == "--help" ] || [ "$1" == "help" ] || [ "$1" == "man" ]; then
    print_help
fi


### Print settings if this is first run
if [ $is_first == "true" ]; then 
    echo -e "${GREEN}Thank for using gitbasher in project '$project_name'${ENDCOLOR}"
    echo -e "Current settings:"
    echo -e "\tmain: '$main_branch'"
    echo -e "\tsep: '$sep'"
    echo -e "\teditor: '$editor'"

    echo -e "You can change these settings by using ${YELLOW}gitb config <name>${ENDCOLOR}"
    echo
fi


### Run script
case "$1" in
    commit|c|co|cm|com)         
        commit_script $2
    ;;
    push|ps|ph)         
        push_script $2
    ;;
    pull|pl|pll)         
        pull_script $2
    ;;
    merge)         
        merge_script $2
    ;;
    branch|b|br|bh|bra)         
        branch_script $2
    ;;
    tag|t|tg)         
        tag_script $2
    ;;
    config|cfg|conf)         
        config_script $2
    ;;
    log|l)
        gitlog
    ;;
    reflog|rl)
        reflog
    ;;
    undo-commit)
        undo_commit
    ;;
    undo-action)
        undo_action
    ;;
    last-commit|lc)
        last_commit
    ;;
    last-action|la)
        last_action
    ;;

    *)
        print_help
    ;;
esac

exit

# if [ "$script_to_run" == "commit" ]; then
#     commit_script $2
# elif [ "$script_to_run" == "push" ]; then
#     push_script $2
# elif [ "$script_to_run" == "pull" ]; then
#     pull_script $2
# elif [ "$script_to_run" == "merge" ]; then
#     merge_script $2
# elif [ "$script_to_run" == "branch" ]; then
#     branch_script $2
# elif [ "$script_to_run" == "tag" ]; then
#     tag_script $2
# elif [ "$script_to_run" == "config" ]; then
#     config_script $2
# else
#     if [ "$1" == "log" ]; then

#     elif [ "$1" == "reflog" ]; then

#     fi

# fi

exit $?
