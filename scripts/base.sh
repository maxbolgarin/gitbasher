#!/usr/bin/env bash


### Print usage information
function print_help {
    echo -e "usage: ${YELLOW}gitb <command> <mode>${ENDCOLOR}"
    echo
    msg="${YELLOW}Command${ENDCOLOR}_\t${GREEN}Aliases${ENDCOLOR}_\t${BLUE}Description of ${BOLD}workflow${NORMAL}${BLUE} commands${ENDCOLOR}"
    msg="$msg\ncommit_c|co|com_Everything about commit creation"
    msg="$msg\npush_p|ps|pus_Pushing changes to a remote repository"
    msg="$msg\npull_pu|pl|pul_Pulling changes from a remote repository"
    msg="$msg\nbranch_b|br|bran_Managing branches"
    msg="$msg\ntag_t|tg_Managing tags"
    msg="$msg\nmerge_m|me_Merge changes to the current branch"
    msg="$msg\nrebase_r|re|base_Rebase current branch"
    msg="$msg\ncherry_ch|cp_Cherry-pick commits from other branches"
    msg="$msg\nreset_res_Easy to use git reset"
    msg="$msg\nstash_s|sta_Manage git stashes"
    msg="$msg\nconfig_cf|cfg|conf_Configurate gitbasher"

    msg="$msg\n_ _ _"
    msg="$msg\n${YELLOW}Command${ENDCOLOR}_\t${GREEN}Aliases${ENDCOLOR}_\t${BLUE}Description of ${BOLD}informational${NORMAL}${BLUE} commands${ENDCOLOR}"
    msg="$msg\nstatus_st_Info about repo and changed files"
    msg="$msg\nlog_l|lg_Git log with branch selection and comparison"
    msg="$msg\nreflog_rl|rlg_Open git reflog in a pretty format"
    msg="$msg\nlast-commit_lc|lastc_Show info about the last commit"
    msg="$msg\nlast-ref_lr|lastr_Show info about the last reference"
    echo -e "$(echo -e "$msg" | column -ts '_')"

    exit
}

project_name="$(get_repo_name)"
repo_url="$(get_repo)"

### Print settings f this is first run
if [ $is_first == "true" ]; then 
    git config --local gitbasher.scopes ""

    echo -e "${GREEN}Thanks for using gitbasher in project '$project_name'${ENDCOLOR}"
    print_configuration
    echo
    echo -e "You can change these settings by using ${YELLOW}gitb cfg <name>${ENDCOLOR}"
    echo
fi

if [ -z $1 ] || [ "$1" == "--help" ] || [ "$1" == "help" ] || [ "$1" == "man" ]; then
    print_help
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
    cherry|ch|cp)         
        cherry_script $2 $3
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
    stash|s|sta)
        stash_script $2
    ;;
    log|l|lg)
        gitlog_script $2 $3
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
    status|st)
        project_status
    ;;

    *)
        print_help
    ;;
esac

exit $?
