#!/usr/bin/env bash


### Print usage information
function print_help {
    echo -e "usage: ${YELLOW}gitb <command> <mode>${ENDCOLOR}"
    echo
    msg="${YELLOW}Command${ENDCOLOR}_\t${YELLOW}Description${ENDCOLOR}"
    msg="$msg\ncommit_Everything about commit creation_commit|c|co|cm|com"
    msg="$msg\npush_Pushing changes to a remote repository_push|ps|ph"
    msg="$msg\npull_Pulling changes from a remote repository_pull|pl|pll"
    msg="$msg\nmerge_Merge changes from different branches_merge"
    msg="$msg\nbranch_Managing branches_branch|b|br|bh|bra"
    msg="$msg\ntag_Managing tags_tag|t|tg"
    msg="$msg\nconfig_Configurate gitbasher_config|cfg|conf"
    echo -e "$(echo -e "$msg" | column -ts '_')"

    echo
    echo -e "${YELLOW}Commands without modes${ENDCOLOR}"
    echo -e "log\t\tOpen git log in a pretty format"
    echo -e "reflog\t\tOpen git reflog in a pretty format"
    echo -e "last-commit\tShow info about last commit (last record from 'git log')"
    echo -e "last-action\tShow info about last commit (last record from 'git reflog')"
    echo -e "undo-commit\tUndo last commit (record from git log)"
    echo -e "undo-action\tUndo last action (record from git reflog)"

    exit
}

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

exit $?
