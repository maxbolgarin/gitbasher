#!/usr/bin/env bash

# Entire file is the top-level dispatcher — only reachable when gitb runs
# as an entrypoint. Bats sources individual scripts directly; this file is
# never sourced by any test, so its contents register as 0% covered.
# kcov-skip-start

### Print usage information
function print_help {
    # kcov-skip-start
    echo -e "${BOLD}gitbasher${NORMAL} v${GITBASHER_VERSION} ${GRAY}— git, made fluent${ENDCOLOR}"
    echo
    echo -e "usage: ${YELLOW}gitb <command> [mode]${ENDCOLOR}"
    echo

    local CMD=26
    local hdr="${YELLOW}%s${ENDCOLOR}\n"
    local row="  ${BOLD}%-*s${NORMAL}  %s\n"

    printf "$hdr" "DAILY"
    printf "$row" "$CMD" "status (s)"              "Show repo state and changed files"
    printf "$row" "$CMD" "commit (c, co, com)"     "Create commits — interactive, AI, amend, revert"
    printf "$row" "$CMD" "push (p, ps, pus)"       "Push current branch safely"
    printf "$row" "$CMD" "pull (pu, pl, pul)"      "Pull from remote"
    printf "$row" "$CMD" "sync (sy)"               "Sync current branch with $main_branch"
    echo

    printf "$hdr" "BRANCHES"
    printf "$row" "$CMD" "branch (b, br, bran)"    "Switch, create, clean up branches"
    printf "$row" "$CMD" "merge (m, me)"           "Merge branches"
    printf "$row" "$CMD" "rebase (r, re, base)"    "Rebase, autosquash, pull commits"
    printf "$row" "$CMD" "squash (sq, tidy)"       "AI-group commits into clean history"
    printf "$row" "$CMD" "cherry (ch, cp)"         "Cherry-pick commits from other branches"
    printf "$row" "$CMD" "prev (-)"                "Switch to previous branch (like cd -)"
    echo

    printf "$hdr" "HISTORY"
    printf "$row" "$CMD" "log (l, lg)"             "Pretty git log with branch comparison"
    printf "$row" "$CMD" "reflog (rl, rlg)"        "Pretty git reflog"
    printf "$row" "$CMD" "last-commit (lc, lastc)" "Show last commit info"
    printf "$row" "$CMD" "last-ref (lr, lastr)"    "Show last reference info"
    printf "$row" "$CMD" "tag (t, tg)"             "Create, list, push, fetch, delete tags"
    echo

    printf "$hdr" "RECOVERY"
    printf "$row" "$CMD" "undo (un)"               "Undo commit, amend, merge, rebase, stash"
    printf "$row" "$CMD" "reset (res)"             "Preview and apply git reset flows"
    printf "$row" "$CMD" "stash (st, sta)"         "Manage git stashes"
    printf "$row" "$CMD" "wip (w)"                 "Stash work-in-progress, optionally back up remote"
    echo

    printf "$hdr" "SETUP"
    printf "$row" "$CMD" "origin (or, o, remote)"  "Manage remotes"
    printf "$row" "$CMD" "hook (ho, hk)"           "Manage git hooks"
    printf "$row" "$CMD" "worktree (wt, tree)"     "Manage git worktrees"
    printf "$row" "$CMD" "config (cf, cfg, conf)"  "Configure gitbasher"
    printf "$row" "$CMD" "update (up, upd)"        "Check for and install gitbasher updates"
    printf "$row" "$CMD" "uninstall (uns, uni)"    "Remove gitbasher config and binary"
    echo

    echo -e "Run ${YELLOW}gitb <command> help${ENDCOLOR} for modes and examples"

    exit
    # kcov-skip-end
}

project_name="$(get_repo_name)"
repo_url="$(get_repo)"

### Print settings f this is first run
if [[ $is_first == "true" ]]; then 
    git config --local gitbasher.scopes ""

    echo -e "${GREEN}Thanks for using gitbasher in project '$project_name'${ENDCOLOR}"
    print_configuration
    echo
    echo -e "You can change these settings by using ${YELLOW}gitb cfg <name>${ENDCOLOR}"
    echo
    echo -e "${CYAN}💡 Pro tip:${ENDCOLOR} If zsh tries to autocorrect 'gitb' to 'git', add this to your ~/.zshrc:"
    echo -e "  ${GREEN}alias gitb='nocorrect gitb'${ENDCOLOR}"
    echo
fi

_gitb_first_run_completion_prompt

if [ "$1" == "--version" ] || [ "$1" == "-v" ] || [ "$1" == "version" ]; then
    echo "gitbasher v${GITBASHER_VERSION}"
    exit
fi

### Normalize --help/-h anywhere in args -> 'help' so every subcommand
### handler sees a consistent token. Lets users write `gitb --help`,
### `gitb commit --help`, `gitb branch -h`, etc.
__gitb_args=()
for __gitb_a in "$@"; do
    case "$__gitb_a" in
        --help|-h) __gitb_args+=("help") ;;
        *)         __gitb_args+=("$__gitb_a") ;;
    esac
done
set -- "${__gitb_args[@]}"
unset __gitb_args __gitb_a

if [ -z "$1" ] || [ "$1" == "help" ] || [ "$1" == "man" ]; then
    print_help
fi


### Run script
case "$1" in
    commit|c|co|com)
        commit_script "${@:2}"
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
    squash|sq|tidy)
        squash_script "$2"
    ;;
    cherry|ch|cp)
        cherry_script $2 $3
    ;;
    sync|sy)
        sync_script $2
    ;;
    wip|w)
        wip_script "${@:2}"
    ;;
    branch|b|br|bran)         
        branch_script $2
    ;;
    tag|t|tg)         
        tag_script $2
    ;;
    config|cf|cfg|conf)
        config_script "${@:2}"
    ;;
    undo|un)
        undo_script $2
    ;;
    reset|res)
        reset_script $2
    ;;
    stash|st|sta)
        stash_script $2
    ;;
    worktree|wt|tree)
        worktree_script "$2"
    ;;
    hook|ho|hk)
        hooks_script $2 $3 $4
    ;;
    origin|or|o|remote)
        origin_script "$2" "$3"
    ;;
    update|up|upd)
        update_script "$2"
    ;;
    uninstall|uns|uni)
        uninstall_script "$2"
    ;;
    init|i)
        # git init already ran in gitb.sh; init.sh handles the optional
        # interactive remote setup. Just exit cleanly here.
        exit
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
    status|s)
        project_status
    ;;
    prev|-)
        branch_script prev
    ;;

    *)
        print_help
    ;;
esac

exit $?
# kcov-skip-end
