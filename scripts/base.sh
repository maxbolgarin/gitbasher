#!/usr/bin/env bash


### Print usage information
function print_help {
    echo -e "${BOLD}gitbasher${NORMAL} v${GITBASHER_VERSION}"
    echo
    echo -e "usage: ${YELLOW}gitb <command> [mode]${ENDCOLOR}"
    echo

    local CMD=19 ALIAS=11
    local hdr3="${YELLOW}%-*s${ENDCOLOR}  ${GREEN}%-*s${ENDCOLOR}  ${BLUE}%s${ENDCOLOR}\n"
    local hdr2="${YELLOW}%-*s${ENDCOLOR}  %-*s  ${BLUE}%s${ENDCOLOR}\n"
    local row="%-*s  %-*s  %s\n"
    local rowb="${BOLD}%-*s${NORMAL}  %-*s  %s\n"

    printf "$hdr2" "$CMD" "Common flows"  "$ALIAS" "" "What it does"
    printf "$rowb" "$CMD" "gitb status"   "$ALIAS" "" "Show repo status and changed files"
    printf "$rowb" "$CMD" "gitb commit"   "$ALIAS" "" "Create an interactive conventional commit"
    printf "$rowb" "$CMD" "gitb c ai"     "$ALIAS" "" "Generate an AI commit message from staged changes"
    printf "$rowb" "$CMD" "gitb c ai push" "$ALIAS" "" "Generate an AI commit message, commit, and push"
    printf "$rowb" "$CMD" "gitb sync"       "$ALIAS" "" "Sync current branch with $main_branch"
    printf "$rowb" "$CMD" "gitb branch new"  "$ALIAS" "" "Create a conventionally named branch"
    echo

    printf "$hdr3" "$CMD" "Workflow commands" "$ALIAS" "Aliases"     "Description"
    printf "$row"  "$CMD" "commit"            "$ALIAS" "c|co|com"    "Create commits: interactive, AI, split, amend, revert"
    printf "$row"  "$CMD" "push"              "$ALIAS" "p|ps|pus"    "Push changes safely to a remote repository"
    printf "$row"  "$CMD" "pull"              "$ALIAS" "pu|pl|pul"   "Pull changes from a remote repository"
    printf "$row"  "$CMD" "branch"            "$ALIAS" "b|br|bran"   "List, switch, create, and clean up branches"
    printf "$row"  "$CMD" "tag"               "$ALIAS" "t|tg"        "Create, push, list, fetch, and delete tags"
    printf "$row"  "$CMD" "merge"             "$ALIAS" "m|me"        "Merge branches into the current branch or $main_branch"
    printf "$row"  "$CMD" "rebase"            "$ALIAS" "r|re|base"   "Rebase current branch, autosquash, or pull commits"
    printf "$row"  "$CMD" "cherry"            "$ALIAS" "ch|cp"       "Cherry-pick commits from other branches"
    printf "$row"  "$CMD" "sync"              "$ALIAS" "sy"          "Sync current branch with $main_branch (fetch + rebase/merge)"
    printf "$row"  "$CMD" "wip"               "$ALIAS" "w"           "Stash work-in-progress and optionally back it up remotely"
    printf "$row"  "$CMD" "undo"              "$ALIAS" "un"          "Undo commit, amend, merge, rebase, or stash actions"
    printf "$row"  "$CMD" "reset"             "$ALIAS" "res"         "Preview and apply common git reset flows"
    printf "$row"  "$CMD" "stash"             "$ALIAS" "s|sta"       "Manage git stashes"
    printf "$row"  "$CMD" "worktree"          "$ALIAS" "wt|tree"     "List, add, remove, lock, move, and prune git worktrees"
    printf "$row"  "$CMD" "hook"              "$ALIAS" "ho|hk"       "List, create, edit, toggle, and test git hooks"
    printf "$row"  "$CMD" "origin"            "$ALIAS" "or|o|remote" "Init, set, change, rename, or remove remotes"
    printf "$row"  "$CMD" "config"            "$ALIAS" "cf|cfg|conf" "Configure gitbasher settings"
    echo
    printf "$row"  "$CMD" "prev"              "$ALIAS" "-"           "Switch to the previous branch (like cd -)"
    echo

    printf "$hdr3" "$CMD" "Info commands" "$ALIAS" "Aliases"  "Description"
    printf "$row"  "$CMD" "status"        "$ALIAS" "st"       "Show repo status and changed files"
    printf "$row"  "$CMD" "log"           "$ALIAS" "l|lg"     "View git log with branch selection and comparison"
    printf "$row"  "$CMD" "reflog"        "$ALIAS" "rl|rlg"   "Open git reflog in a pretty format"
    printf "$row"  "$CMD" "last-commit"   "$ALIAS" "lc|lastc" "Show info about the last commit"
    printf "$row"  "$CMD" "last-ref"      "$ALIAS" "lr|lastr" "Show info about the last reference"
    echo

    printf "$hdr2" "$CMD" "Tips"                "$ALIAS" "" "Details"
    printf "$rowb" "$CMD" "gitb <command> help" "$ALIAS" "" "Show command-specific modes and aliases"
    printf "$rowb" "$CMD" "gitb --help"         "$ALIAS" "" "Show this help"
    printf "$rowb" "$CMD" "gitb -"              "$ALIAS" "" "Switch to the previous branch"

    exit
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
    stash|s|sta)
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
    status|st)
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
