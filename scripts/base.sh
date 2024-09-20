#!/usr/bin/env bash


### Print usage information
function print_help {
    echo -e "usage: ${YELLOW}gitb <command> <mode>${ENDCOLOR}"
    echo
    msg="${YELLOW}Command${ENDCOLOR}_\t${GREEN}Aliases${ENDCOLOR}_\t${BLUE}Description of ${BOLD}workflow${NORMAL}${BLUE} commands${ENDCOLOR}"
    msg="$msg\ncommit_c|co|com_Everything about commit creation"
    msg="$msg\npush_p|ps|pus_Pushing changes to a remote repository"
    msg="$msg\npull_pu|pl|pul_Pulling changes from a remote repository"
    msg="$msg\nmerge_m|me_Merge changes to the current branch"
    msg="$msg\nrebase_r|re|base_Rebase current branch"
    msg="$msg\nbranch_b|br|bran_Managing branches"
    msg="$msg\ntag_t|tg_Managing tags"
    msg="$msg\nreset_res_Utils for git reset"
    msg="$msg\nconfig_cf|cfg|conf_Configurate gitbasher"

    msg="$msg\n_ _ _"
    msg="$msg\n${YELLOW}Command${ENDCOLOR}_\t${GREEN}Aliases${ENDCOLOR}_\t${BLUE}Description of ${BOLD}informational${NORMAL}${BLUE} commands${ENDCOLOR}"
    msg="$msg\nstatus_s|st_Show info about repo and changed files"
    msg="$msg\nlog_l|lg_Open git log in a pretty format"
    msg="$msg\nreflog_rl|rlg_Open git reflog in a pretty format"
    msg="$msg\nlast-commit_lc|lastc_Show info about the last commit"
    msg="$msg\nlast-ref_lr|lastr_Show info about the last reference"
    echo -e "$(echo -e "$msg" | column -ts '_')"

    exit
}

if [ -z $1 ] || [ "$1" == "--help" ] || [ "$1" == "help" ] || [ "$1" == "man" ]; then
    print_help
fi


### Print settings if this is first run
if [ $is_first == "true" ]; then 
    echo -e "${GREEN}Thanks for using gitbasher in project '$project_name'${ENDCOLOR}"
    print_configuration
    echo
    echo -e "You can change these settings by using ${YELLOW}gitb cfg <name>${ENDCOLOR}"
fi


### Run script
case "$1" in
    commit|c|co|com)         
        commit_script $2
    ;;
    push|p|ps|pus)         
        push_script $2
    ;;
    pull|pu|pl|pul)         
        pull_script $2
    ;;
    merge|m|me)         
        merge_script $2
    ;;
    rebase|r|re|base)         
        rebase_script $2
    ;;
    branch|b|br|bran)         
        branch_script $2
    ;;
    tag|t|tg)         
        tag_script $2
    ;;
    config|cf|cfg|conf)         
        config_script $2
    ;;
    reset|res)
        reset_script $2
    ;;
    log|l|lg)
        gitlog
    ;;
    reflog|rl|rlg)
        reflog
    ;;
    last-commit|lc|lastc)
        last_commit
    ;;
    last-ref|lr|lastr)
        last_ref
    ;;
    status|s|st)
        project_status
    ;;

    *)
        print_help
    ;;
esac

exit $?
