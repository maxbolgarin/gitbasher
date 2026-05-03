# Bash completion for gitb (gitbasher)
#
# Install:
#   - System-wide:  cp gitb.bash /etc/bash_completion.d/gitb
#   - User:         source <path-to>/gitb.bash   (in ~/.bashrc)
#   - macOS+Brew:   cp gitb.bash "$(brew --prefix)/etc/bash_completion.d/gitb"

# All top-level commands and their aliases. One subcommand per line; the
# canonical name comes first so completions show the full word.
_gitb_commands="
commit c co com
push p ps pus
pull pu pl pul
merge m me
rebase r re base
cherry ch cp
sync sy
wip w
branch b br bran
tag t tg
config cf cfg conf
undo un
reset res
stash s sta
worktree wt tree
hook ho hk
origin or o remote
init i
log l lg
reflog rl rlg
last-commit lc lastc
last-ref lr lastr
status st
prev -
help man
"

# Second-level subcommands keyed by canonical command. Empty means: no specific
# subcommands, fall through to branch-name / no-completion.
_gitb_sub_commit="ai llm i fast f fasts fs sf ff push pu p scope s msg m ticket jira j t staged no-split nosplit nsp nsl fixup fix x amend am a split sp sl splitp spp slp aisplit isplit aispl ispl aisplitp isplitp aisplp isplp last l revert rev help h"
_gitb_sub_push="yes y force f list log l help h"
_gitb_sub_pull="fetch fe all fa upd u ffonly ff merge m rebase r interactive ri rs dry d dr help h"
_gitb_sub_merge="main master m to-main to-master tm remote r help h"
_gitb_sub_rebase="main master m interactive i autosquash a s ia fastautosquash fast sf f pull p help h"
_gitb_sub_cherry="hash hs range r abort a continue cont c help h"
_gitb_sub_sync="push p merge m mergep mp pm dry d dr help h"
_gitb_sub_wip="up u down d help h"
_gitb_sub_branch="list l remote r re main def m delete del d prev p - recent rc gone g tag t help h"
_gitb_sub_tag="annotated a an commit c co cm all al push ps ph p push-all pa delete del d delete-all da list log l remote re r fetch help h"
_gitb_sub_config="default def d b main separator sep editor ed e ticket jira ti t scopes scope sc s ai llm key provider prov model m proxy prx p history hist diff payload delete unset del user name email u help h"
_gitb_sub_undo="commit c amend a merge m rebase r stash s help h"
_gitb_sub_reset="soft s undo u interactive i help h"
_gitb_sub_stash="select sel all list l pop p show s drop d apply a help h"
_gitb_sub_worktree="list l ls add a new n c addd ad nd cd addb ab from b addr ar remote r remove rm del d prune pr p lock unlock ul move mv path cd switch sw help h"
_gitb_sub_origin="set add new a change update c u set-url rename mv ren remove delete rm del d help h"
_gitb_sub_log="branch b compare comp c search s help h"
_gitb_sub_hook="list create edit toggle test show remove select install help"
_gitb_sub_log_branch="local l remote r all a help h"

# Map alias -> canonical command name.
_gitb_canonical() {
    case "$1" in
        commit|c|co|com)              echo commit ;;
        push|p|ps|pus)                echo push ;;
        pull|pu|pl|pul)               echo pull ;;
        merge|m|me)                   echo merge ;;
        rebase|r|re|base)             echo rebase ;;
        cherry|ch|cp)                 echo cherry ;;
        sync|sy)                      echo sync ;;
        wip|w)                        echo wip ;;
        branch|b|br|bran)             echo branch ;;
        tag|t|tg)                     echo tag ;;
        config|cf|cfg|conf)           echo config ;;
        undo|un)                      echo undo ;;
        reset|res)                    echo reset ;;
        stash|s|sta)                  echo stash ;;
        worktree|wt|tree)             echo worktree ;;
        hook|ho|hk)                   echo hook ;;
        origin|or|o|remote)           echo origin ;;
        log|l|lg)                     echo log ;;
        *)                            echo "" ;;
    esac
}

_gitb() {
    local cur prev cmd canonical
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"

    # Top-level command
    if [ "$COMP_CWORD" -eq 1 ]; then
        COMPREPLY=( $(compgen -W "$_gitb_commands" -- "$cur") )
        return 0
    fi

    cmd="${COMP_WORDS[1]}"
    canonical="$(_gitb_canonical "$cmd")"

    # Second-level subcommand
    if [ "$COMP_CWORD" -eq 2 ]; then
        local subs_var="_gitb_sub_${canonical}"
        local subs="${!subs_var}"
        if [ -n "$subs" ]; then
            COMPREPLY=( $(compgen -W "$subs" -- "$cur") )
            return 0
        fi
        # branch / merge / rebase / pull / cherry / log can take a branch name
        case "$canonical" in
            branch|merge|rebase|pull|cherry|log)
                local branches
                branches=$(git for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null)
                COMPREPLY=( $(compgen -W "$branches" -- "$cur") )
                return 0
                ;;
        esac
        return 0
    fi

    # Third-level — only a couple of nested subcommands
    if [ "$COMP_CWORD" -eq 3 ]; then
        local sub="${COMP_WORDS[2]}"
        if [ "$canonical" = "log" ] && { [ "$sub" = "branch" ] || [ "$sub" = "b" ]; }; then
            COMPREPLY=( $(compgen -W "$_gitb_sub_log_branch" -- "$cur") )
            return 0
        fi
        if [ "$canonical" = "wip" ]; then
            COMPREPLY=( $(compgen -W "stash branch worktree nopush np n" -- "$cur") )
            return 0
        fi
    fi

    return 0
}

complete -F _gitb gitb
