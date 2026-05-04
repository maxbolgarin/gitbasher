#!/usr/bin/env bash

### Shell completion content + installer for gitb.
### Used by `gitb cfg auto <up|down|status|print> [shell]` and the first-run prompt.
### NOTE: heredoc bodies below must not contain leading-`#` comment lines or blank
### lines, because dist/build.sh strips both during binary assembly.


### Print bash completion script content
function _gitb_bash_completion_content {
# kcov-skip-start
cat <<'GITB_BASH_EOF'
_gitb_commands="
commit c co com
push p ps pus
pull pu pl pul
merge m me
rebase r re base
squash sq tidy
cherry ch cp
sync sy
wip w
branch b br bran
tag t tg
config cf cfg conf
undo un
reset res
stash st sta
worktree wt tree
hook ho hk
origin or o remote
init i
log l lg
reflog rl rlg
last-commit lc lastc
last-ref lr lastr
status s
prev -
update up upd
uninstall uns uni
help man
"
_gitb_sub_commit="ai llm i fast f fasts fs sf ff ffp ffpush push pu p fastp fp pf fastsp fsp fps scope s msg m ticket jira j t staged st no-split nosplit nsp nsl fixup fix x fixupp fixp xp px fixupst xst stx fastfix fx xf fastfixp fxp xfp amend am a amendst ast sta amendf amf af fa split sp sl splitp spp slp aisplit isplit aispl ispl aisplitp isplitp aisplp isplp llmf aif if llmp aip ip llmst aist ist llmfp aifp ifp ipf llms ais is llmsf aisf isf llmsfp aisfp isfp llmm aim im llmmf aimf imf llmmfp aimfp imfp last l revert rev help h"
_gitb_sub_commit_simple="ai llm i fast f push pu p scope s msg m ticket jira j t staged no-split nosplit nsp nsl fixup fix x amend am a split sp sl last l revert rev help h"
_gitb_sub_wip_backend="stash s branch b worktree w wt tree nopush np n"
_gitb_sub_push="yes y force f list log l help h"
_gitb_sub_pull="fetch fe all fa upd u ffonly ff merge m rebase r interactive ri rs dry d dr help h"
_gitb_sub_merge="main master m to-main to-master tm remote r help h"
_gitb_sub_rebase="main master m interactive i autosquash a s ia fastautosquash fast sf f pull p help h"
_gitb_sub_squash="preview p dry show yes y fast push ps help h"
_gitb_sub_cherry="hash hs range r abort a continue cont c help h"
_gitb_sub_sync="push p merge m mergep mp pm dry d dr help h"
_gitb_sub_wip="up u down d help h"
_gitb_sub_branch="list l remote r re main def m delete del d prev p - recent rc gone g tag t help h"
_gitb_sub_tag="annotated a an commit c co cm all al push ps ph p push-all pa delete del d delete-all da list log l remote re r fetch help h"
_gitb_sub_config="default def d b main separator sep editor ed e ticket jira ti t scopes scope sc s ai llm key provider prov model m proxy prx p history hist diff payload delete unset del user name email u auto completion comp help h"
_gitb_sub_undo="commit c amend a merge m rebase r stash s help h"
_gitb_sub_reset="soft s undo u interactive i help h"
_gitb_sub_stash="select sel all list l pop p show s drop d apply a help h"
_gitb_sub_worktree="list l ls add a new n c addd ad nd cd addb ab from b addr ar remote r remove rm del d prune pr p lock unlock ul move mv path cd switch sw help h"
_gitb_sub_origin="set add new a change update c u set-url rename mv ren remove delete rm del d help h"
_gitb_sub_log="branch b compare comp c search s help h"
_gitb_sub_hook="list create edit toggle test show remove select install help"
_gitb_sub_log_branch="local l remote r all a help h"
_gitb_sub_config_auto="up u on install enable down d off uninstall disable remove status st print cat p help h"
_gitb_canonical() {
    case "$1" in
        commit|c|co|com)              echo commit ;;
        push|p|ps|pus)                echo push ;;
        pull|pu|pl|pul)               echo pull ;;
        merge|m|me)                   echo merge ;;
        rebase|r|re|base)             echo rebase ;;
        squash|sq|tidy)               echo squash ;;
        cherry|ch|cp)                 echo cherry ;;
        sync|sy)                      echo sync ;;
        wip|w)                        echo wip ;;
        branch|b|br|bran)             echo branch ;;
        tag|t|tg)                     echo tag ;;
        config|cf|cfg|conf)           echo config ;;
        undo|un)                      echo undo ;;
        reset|res)                    echo reset ;;
        stash|st|sta)                 echo stash ;;
        worktree|wt|tree)             echo worktree ;;
        hook|ho|hk)                   echo hook ;;
        origin|or|o|remote)           echo origin ;;
        log|l|lg)                     echo log ;;
        *)                            echo "" ;;
    esac
}
_gitb_commit_state_aware() {
    local cur="$1"
    local has_action=""
    local has_ai="" has_fast="" has_staged="" has_push=""
    local has_scope="" has_msg="" has_ticket="" has_no_split=""
    local i tok
    for ((i=2; i<COMP_CWORD; i++)); do
        tok="${COMP_WORDS[$i]}"
        case "$tok" in
            last|l)                   has_action="last" ;;
            revert|rev)               has_action="revert" ;;
            fixup|fix|x)              has_action="fixup" ;;
            amend|am|a)               has_action="amend" ;;
            split|sp|sl)              has_action="split" ;;
            ai|llm|i)                 has_ai="true" ;;
            fast|f)                   has_fast="true" ;;
            staged|st)                has_staged="true" ;;
            push|pu|p)                has_push="true" ;;
            scope|s)                  has_scope="true" ;;
            msg|m)                    has_msg="true" ;;
            ticket|jira|j|t)          has_ticket="true" ;;
            no-split|nosplit|nsp|nsl) has_no_split="true" ;;
        esac
    done
    local candidates=()
    case "$has_action" in
        last|revert)
            :
            ;;
        amend|fixup)
            [ -z "${has_fast}${has_staged}" ] && candidates+=("fast" "staged")
            [ -z "$has_push" ] && candidates+=("push")
            ;;
        split|"")
            local has_strict_mod="${has_ai}${has_msg}${has_ticket}${has_scope}${has_no_split}"
            local has_any_mod="${has_ai}${has_fast}${has_staged}${has_push}${has_scope}${has_msg}${has_ticket}${has_no_split}"
            if [ -z "$has_action" ]; then
                candidates+=("split")
                [ -z "$has_strict_mod" ] && candidates+=("amend" "fixup")
                [ -z "$has_any_mod" ] && candidates+=("last" "revert")
            fi
            [ -z "$has_ai" ]                  && candidates+=("ai")
            [ -z "${has_fast}${has_staged}" ] && candidates+=("fast" "staged")
            [ -z "$has_push" ]                && candidates+=("push")
            [ -z "$has_scope" ]               && candidates+=("scope")
            [ -z "$has_msg" ]                 && candidates+=("msg")
            [ -z "$has_ticket" ]              && candidates+=("ticket")
            [ -z "$has_no_split" ]            && candidates+=("no-split")
            ;;
    esac
    candidates+=("help")
    COMPREPLY=( $(compgen -W "${candidates[*]}" -- "$cur") )
}
_gitb() {
    local cur cmd canonical sub
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    if [ "$COMP_CWORD" -eq 1 ]; then
        COMPREPLY=( $(compgen -W "$_gitb_commands" -- "$cur") )
        return 0
    fi
    cmd="${COMP_WORDS[1]}"
    canonical="$(_gitb_canonical "$cmd")"
    sub="${COMP_WORDS[2]}"
    if [ "$canonical" = "commit" ]; then
        if [ "$COMP_CWORD" -eq 2 ]; then
            COMPREPLY=( $(compgen -W "$_gitb_sub_commit" -- "$cur") )
        else
            _gitb_commit_state_aware "$cur"
        fi
        return 0
    fi
    if [ "$canonical" = "wip" ] && [ "$COMP_CWORD" -ge 3 ]; then
        if [ "$sub" = "up" ] || [ "$sub" = "u" ] || [ "$sub" = "down" ] || [ "$sub" = "d" ]; then
            COMPREPLY=( $(compgen -W "$_gitb_sub_wip_backend" -- "$cur") )
            return 0
        fi
    fi
    if [ "$COMP_CWORD" -eq 2 ]; then
        local subs_var="_gitb_sub_${canonical}"
        local subs="${!subs_var}"
        if [ -n "$subs" ]; then
            COMPREPLY=( $(compgen -W "$subs" -- "$cur") )
            return 0
        fi
        case "$canonical" in
            branch|merge|rebase|pull|cherry|log)
                local branches
                # Filter for "tab-friendly" branch names — git permits some
                # shell-special characters (e.g. `$`, backticks) inside refs,
                # and feeding them into `compgen -W` then through unquoted
                # COMPREPLY=( $(...) ) opens a small pathological window. The
                # user can still complete weird names by typing them out.
                branches=$(git for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null | grep -E '^[A-Za-z0-9._/-]+$')
                COMPREPLY=( $(compgen -W "$branches" -- "$cur") )
                return 0
                ;;
        esac
        return 0
    fi
    if [ "$COMP_CWORD" -eq 3 ]; then
        if [ "$canonical" = "log" ] && { [ "$sub" = "branch" ] || [ "$sub" = "b" ]; }; then
            COMPREPLY=( $(compgen -W "$_gitb_sub_log_branch" -- "$cur") )
            return 0
        fi
        if [ "$canonical" = "config" ] && { [ "$sub" = "auto" ] || [ "$sub" = "completion" ] || [ "$sub" = "comp" ]; }; then
            COMPREPLY=( $(compgen -W "$_gitb_sub_config_auto" -- "$cur") )
            return 0
        fi
    fi
    if [ "$COMP_CWORD" -eq 4 ]; then
        if [ "$canonical" = "config" ] && { [ "$sub" = "auto" ] || [ "$sub" = "completion" ] || [ "$sub" = "comp" ]; }; then
            COMPREPLY=( $(compgen -W "bash zsh fish" -- "$cur") )
            return 0
        fi
    fi
    return 0
}
complete -F _gitb gitb
GITB_BASH_EOF
# kcov-skip-end
}


### Print zsh completion script content
function _gitb_zsh_completion_content {
# kcov-skip-start
cat <<'GITB_ZSH_EOF'
#compdef gitb
_gitb() {
    local context state line
    typeset -A opt_args
    if (( CURRENT >= 3 )); then
        case "$words[2]" in
            commit|c|co|com)
                local -a flags
                if (( CURRENT == 3 )); then
                    flags=(
                        'ai[AI-generated message]' 'fast[fast commit]'
                        'ff[ultrafast AI commit]' 'ffp[ultrafast AI commit and push]'
                        'push[commit and push]'
                        'scope[with scope prompt]' 'msg[manual message]' 'ticket[with ticket prefix]'
                        'staged[only staged files]' 'no-split[disable split]'
                        'fixup[create fixup commit]' 'amend[amend last commit]'
                        'split[split into atomic commits]'
                        'last[show last commit]' 'revert[revert a commit]' 'help[show help]'
                    )
                    _values 'commit flag' $flags
                    return
                fi
                local has_action=""
                local has_ai="" has_fast="" has_staged="" has_push=""
                local has_scope="" has_msg="" has_ticket="" has_no_split=""
                local i tok
                for ((i=3; i<CURRENT; i++)); do
                    tok="${words[$i]}"
                    case "$tok" in
                        last|l)                   has_action="last" ;;
                        revert|rev)               has_action="revert" ;;
                        fixup|fix|x)              has_action="fixup" ;;
                        amend|am|a)               has_action="amend" ;;
                        split|sp|sl)              has_action="split" ;;
                        ai|llm|i)                 has_ai="true" ;;
                        fast|f)                   has_fast="true" ;;
                        staged|st)                has_staged="true" ;;
                        push|pu|p)                has_push="true" ;;
                        scope|s)                  has_scope="true" ;;
                        msg|m)                    has_msg="true" ;;
                        ticket|jira|j|t)          has_ticket="true" ;;
                        no-split|nosplit|nsp|nsl) has_no_split="true" ;;
                    esac
                done
                flags=()
                case "$has_action" in
                    last|revert)
                        ;;
                    amend|fixup)
                        [ -z "${has_fast}${has_staged}" ] && flags+=('fast[fast commit (git add .)]' 'staged[only staged files]')
                        [ -z "$has_push" ] && flags+=('push[commit and push]')
                        ;;
                    split|"")
                        local has_strict_mod="${has_ai}${has_msg}${has_ticket}${has_scope}${has_no_split}"
                        local has_any_mod="${has_ai}${has_fast}${has_staged}${has_push}${has_scope}${has_msg}${has_ticket}${has_no_split}"
                        if [ -z "$has_action" ]; then
                            flags+=('split[split into atomic commits]')
                            [ -z "$has_strict_mod" ] && flags+=('amend[amend last commit]' 'fixup[create fixup commit]')
                            [ -z "$has_any_mod" ] && flags+=('last[reuse last message]' 'revert[revert a commit]')
                        fi
                        [ -z "$has_ai" ]                  && flags+=('ai[AI-generated message]')
                        [ -z "${has_fast}${has_staged}" ] && flags+=('fast[fast commit (git add .)]' 'staged[only staged files]')
                        [ -z "$has_push" ]                && flags+=('push[commit and push]')
                        [ -z "$has_scope" ]               && flags+=('scope[with scope prompt]')
                        [ -z "$has_msg" ]                 && flags+=('msg[manual message]')
                        [ -z "$has_ticket" ]              && flags+=('ticket[with ticket prefix]')
                        [ -z "$has_no_split" ]            && flags+=('no-split[disable split]')
                        ;;
                esac
                _values 'commit flag' $flags
                return
                ;;
            wip|w)
                if (( CURRENT >= 4 )); then
                    case "$words[3]" in
                        up|u|down|d)
                            _values 'wip backend / flag' \
                                'stash[stash backend]' 'branch[branch backend]' \
                                'worktree[worktree backend]' 'nopush[skip push]'
                            return
                            ;;
                    esac
                fi
                ;;
        esac
    fi
    _arguments -C \
        '1: :->command' \
        '2: :->subcommand' \
        '3: :->subsubcommand' \
        '4: :->fourth' \
        '*::arg:->args'
    case "$state" in
        command)
            local -a cmds
            cmds=(
                'commit:Interactive commit (alias: c, co, com)'
                'push:Push current branch (alias: p, ps, pus)'
                'pull:Pull updates (alias: pu, pl, pul)'
                'merge:Merge a branch (alias: m, me)'
                'rebase:Rebase a branch (alias: r, re, base)'
                'squash:AI-group branch commits (alias: sq, tidy)'
                'cherry:Cherry-pick commits (alias: ch, cp)'
                'sync:Sync with remote (alias: sy)'
                'wip:Work-in-progress save/restore (alias: w)'
                'branch:Branch operations (alias: b, br, bran)'
                'tag:Tag operations (alias: t, tg)'
                'config:Configure gitbasher (alias: cf, cfg, conf)'
                'undo:Undo recent operation (alias: un)'
                'reset:Reset HEAD (alias: res)'
                'stash:Stash operations (alias: st, sta)'
                'worktree:Worktree operations (alias: wt, tree)'
                'hook:Manage git hooks (alias: ho, hk)'
                'origin:Manage remote (alias: or, o, remote)'
                'init:Initialize repo (alias: i)'
                'log:Git log utilities (alias: l, lg)'
                'reflog:Show reflog (alias: rl, rlg)'
                'last-commit:Show last commit'
                'last-ref:Show last ref'
                'status:Project status (alias: s)'
                'prev:Switch to previous branch (alias: -)'
                'update:Self-update gitbasher (alias: up, upd)'
                'uninstall:Remove gitbasher config and binary (alias: uns, uni)'
                'help:Show help'
            )
            _describe -t commands 'gitb command' cmds
            ;;
        subcommand)
            case "$words[2]" in
                commit|c|co|com)
                    _values 'commit mode' \
                        'ai[AI-generated message]' 'fast[fast commit]' 'fasts[fast with scope]' 'ff[ultrafast AI commit]' \
                        'push[commit and push]' 'scope[with scope prompt]' 'msg[manual message]' \
                        'ticket[with ticket prefix]' 'staged[only staged files]' \
                        'no-split[disable split]' 'fixup[create fixup commit]' \
                        'amend[amend last commit]' 'split[split into atomic commits]' \
                        'splitp[split and push]'  \
                        'last[show last commit]' 'revert[revert a commit]' 'help[show help]'
                    ;;
                push|p|ps|pus)
                    _values 'push mode' 'yes[skip confirmation]' 'force[force push]' 'list[show pending pushes]' 'help[show help]'
                    ;;
                pull|pu|pl|pul)
                    _values 'pull mode' 'fetch[fetch only]' 'all[fetch all]' 'upd[update]' 'ffonly[fast-forward only]' 'merge[merge]' 'rebase[rebase]' 'interactive[interactive rebase]' 'dry[dry run]' 'help[show help]'
                    ;;
                merge|m|me)
                    local -a branches
                    branches=( ${(f)"$(git for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null)"} )
                    _values 'merge target' 'main[merge main into current]' 'to-main[merge current into main]' 'remote[merge a remote branch]' 'help[show help]' $branches
                    ;;
                rebase|r|re|base)
                    local -a branches
                    branches=( ${(f)"$(git for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null)"} )
                    _values 'rebase mode' 'main[rebase onto main]' 'interactive[interactive]' 'autosquash[autosquash]' 'fastautosquash[fast autosquash]' 'pull[pull commits]' 'help[show help]' $branches
                    ;;
                squash|sq|tidy)
                    _values 'squash mode' 'preview[show plan only]' 'yes[skip confirmation]' 'push[force-push after squash]' 'help[show help]'
                    ;;
                cherry|ch|cp)
                    _values 'cherry mode' 'hash[pick by hash]' 'range[pick a range]' 'abort[abort cherry-pick]' 'continue[continue cherry-pick]' 'help[show help]'
                    ;;
                sync|sy)
                    _values 'sync mode' 'push[sync and push]' 'merge[sync via merge]' 'mergep[merge and push]' 'dry[dry run]' 'help[show help]'
                    ;;
                wip|w)
                    _values 'wip action' 'up[save WIP]' 'down[restore WIP]' 'help[show help]'
                    ;;
                branch|b|br|bran)
                    local -a branches
                    branches=( ${(f)"$(git for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null)"} )
                    _values 'branch mode or name' 'list[list branches]' 'remote[remote branches]' 'main[switch to main]' 'delete[delete a branch]' 'prev[previous branch]' 'recent[recent branches]' 'gone[branches with gone upstream]' 'tag[tag operations]' 'help[show help]' $branches
                    ;;
                tag|t|tg)
                    _values 'tag mode' 'annotated[create annotated tag]' 'commit[tag a commit]' 'all[tag everything]' 'push[push tag]' 'push-all[push all tags]' 'delete[delete tag]' 'delete-all[delete all]' 'list[list tags]' 'remote[remote tags]' 'help[show help]'
                    ;;
                config|cf|cfg|conf)
                    _values 'config key' 'default[default branch]' 'separator[separator char]' 'editor[editor]' 'ticket[ticket prefix]' 'scopes[scope list]' 'ai[AI key]' 'provider[AI provider]' 'model[AI model]' 'proxy[AI proxy]' 'history[AI history]' 'diff[AI diff payload]' 'delete[unset a key]' 'user[user name/email]' 'auto[manage tab completion]' 'help[show help]'
                    ;;
                undo|un)
                    _values 'undo target' 'commit[undo last commit]' 'amend[undo amend]' 'merge[undo merge]' 'rebase[undo rebase]' 'stash[undo stash]' 'help[show help]'
                    ;;
                reset|res)
                    _values 'reset mode' 'soft[soft reset]' 'undo[reset to before last action]' 'interactive[interactive reset]' 'help[show help]'
                    ;;
                stash|st|sta)
                    _values 'stash mode' 'select[select a stash]' 'all[stash everything]' 'list[list stashes]' 'pop[pop a stash]' 'show[show stash]' 'drop[drop a stash]' 'apply[apply a stash]' 'help[show help]'
                    ;;
                worktree|wt|tree)
                    _values 'worktree mode' 'list[list worktrees]' 'add[add from current HEAD]' 'addd[add from default branch]' 'addb[add from local branch]' 'addr[add from remote branch]' 'remove[remove a worktree]' 'prune[prune stale records]' 'lock[lock a worktree]' 'unlock[unlock a worktree]' 'move[move a worktree]' 'path[print worktree path]' 'help[show help]'
                    ;;
                origin|or|o|remote)
                    _values 'origin action' 'set[set remote]' 'change[change remote URL]' 'rename[rename remote]' 'remove[remove remote]' 'help[show help]'
                    ;;
                log|l|lg)
                    _values 'log mode' 'branch[log per branch]' 'compare[compare branches]' 'search[search log]' 'help[show help]'
                    ;;
                hook|ho|hk)
                    _values 'hook action' 'list[list hooks]' 'create[create a hook]' 'edit[edit a hook]' 'toggle[toggle hook]' 'test[test a hook]' 'show[show hook]' 'remove[remove a hook]' 'select[select a hook]' 'install[install hooks]' 'help[show help]'
                    ;;
            esac
            ;;
        subsubcommand)
            case "$words[2]" in
                log|l|lg)
                    case "$words[3]" in
                        branch|b)
                            _values 'log branch mode' 'local[local branches]' 'remote[remote branches]' 'all[all branches]' 'help[show help]'
                            ;;
                    esac
                    ;;
                wip|w)
                    case "$words[3]" in
                        up|u|down|d)
                            _values 'wip backend / flag' 'stash[stash backend]' 'branch[branch backend]' 'worktree[worktree backend]' 'nopush[skip push]'
                            ;;
                    esac
                    ;;
                config|cf|cfg|conf)
                    case "$words[3]" in
                        auto|completion|comp)
                            _values 'auto action' 'up[install]' 'down[uninstall]' 'status[show state]' 'print[print to stdout]' 'help[show help]'
                            ;;
                    esac
                    ;;
            esac
            ;;
        fourth)
            case "$words[2]" in
                config|cf|cfg|conf)
                    case "$words[3]" in
                        auto|completion|comp)
                            _values 'shell' 'bash' 'zsh' 'fish'
                            ;;
                    esac
                    ;;
            esac
            ;;
    esac
}
compdef _gitb gitb
GITB_ZSH_EOF
# kcov-skip-end
}


### Print fish completion script content
function _gitb_fish_completion_content {
# kcov-skip-start
cat <<'GITB_FISH_EOF'
function __gitb_no_subcmd
    set -l tokens (commandline -opc)
    test (count $tokens) -eq 1
end
function __gitb_using_cmd
    set -l tokens (commandline -opc)
    test (count $tokens) -ge 2; or return 1
    set -l cmd $tokens[2]
    for arg in $argv
        if test "$cmd" = "$arg"
            return 0
        end
    end
    return 1
end
function __gitb_at_position
    set -l tokens (commandline -opc)
    test (count $tokens) -eq (math $argv[1] + 0)
end
function __gitb_local_branches
    git for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null
end
complete -c gitb -f
complete -c gitb -n __gitb_no_subcmd -a commit       -d 'Interactive commit'
complete -c gitb -n __gitb_no_subcmd -a c            -d 'Alias of commit'
complete -c gitb -n __gitb_no_subcmd -a co           -d 'Alias of commit'
complete -c gitb -n __gitb_no_subcmd -a com          -d 'Alias of commit'
complete -c gitb -n __gitb_no_subcmd -a push         -d 'Push current branch'
complete -c gitb -n __gitb_no_subcmd -a p            -d 'Alias of push'
complete -c gitb -n __gitb_no_subcmd -a pull         -d 'Pull updates'
complete -c gitb -n __gitb_no_subcmd -a pu           -d 'Alias of pull'
complete -c gitb -n __gitb_no_subcmd -a merge        -d 'Merge a branch'
complete -c gitb -n __gitb_no_subcmd -a m            -d 'Alias of merge'
complete -c gitb -n __gitb_no_subcmd -a rebase       -d 'Rebase'
complete -c gitb -n __gitb_no_subcmd -a r            -d 'Alias of rebase'
complete -c gitb -n __gitb_no_subcmd -a squash       -d 'AI-group branch commits'
complete -c gitb -n __gitb_no_subcmd -a sq           -d 'Alias of squash'
complete -c gitb -n __gitb_no_subcmd -a tidy         -d 'Alias of squash'
complete -c gitb -n __gitb_no_subcmd -a cherry       -d 'Cherry-pick commits'
complete -c gitb -n __gitb_no_subcmd -a ch           -d 'Alias of cherry'
complete -c gitb -n __gitb_no_subcmd -a sync         -d 'Sync with remote'
complete -c gitb -n __gitb_no_subcmd -a sy           -d 'Alias of sync'
complete -c gitb -n __gitb_no_subcmd -a wip          -d 'Save / restore WIP'
complete -c gitb -n __gitb_no_subcmd -a w            -d 'Alias of wip'
complete -c gitb -n __gitb_no_subcmd -a branch       -d 'Branch operations'
complete -c gitb -n __gitb_no_subcmd -a b            -d 'Alias of branch'
complete -c gitb -n __gitb_no_subcmd -a tag          -d 'Tag operations'
complete -c gitb -n __gitb_no_subcmd -a t            -d 'Alias of tag'
complete -c gitb -n __gitb_no_subcmd -a config       -d 'Configure gitbasher'
complete -c gitb -n __gitb_no_subcmd -a cfg          -d 'Alias of config'
complete -c gitb -n __gitb_no_subcmd -a undo         -d 'Undo recent operation'
complete -c gitb -n __gitb_no_subcmd -a un           -d 'Alias of undo'
complete -c gitb -n __gitb_no_subcmd -a reset        -d 'Reset HEAD'
complete -c gitb -n __gitb_no_subcmd -a res          -d 'Alias of reset'
complete -c gitb -n __gitb_no_subcmd -a stash        -d 'Stash operations'
complete -c gitb -n __gitb_no_subcmd -a st           -d 'Alias of stash'
complete -c gitb -n __gitb_no_subcmd -a worktree     -d 'Worktree operations'
complete -c gitb -n __gitb_no_subcmd -a wt           -d 'Alias of worktree'
complete -c gitb -n __gitb_no_subcmd -a hook         -d 'Manage git hooks'
complete -c gitb -n __gitb_no_subcmd -a ho           -d 'Alias of hook'
complete -c gitb -n __gitb_no_subcmd -a origin       -d 'Manage remote'
complete -c gitb -n __gitb_no_subcmd -a o            -d 'Alias of origin'
complete -c gitb -n __gitb_no_subcmd -a remote       -d 'Alias of origin'
complete -c gitb -n __gitb_no_subcmd -a init         -d 'Initialize repo'
complete -c gitb -n __gitb_no_subcmd -a i            -d 'Alias of init'
complete -c gitb -n __gitb_no_subcmd -a log          -d 'Git log utilities'
complete -c gitb -n __gitb_no_subcmd -a l            -d 'Alias of log'
complete -c gitb -n __gitb_no_subcmd -a reflog       -d 'Show reflog'
complete -c gitb -n __gitb_no_subcmd -a last-commit  -d 'Show last commit'
complete -c gitb -n __gitb_no_subcmd -a last-ref     -d 'Show last ref'
complete -c gitb -n __gitb_no_subcmd -a status       -d 'Project status'
complete -c gitb -n __gitb_no_subcmd -a s            -d 'Alias of status'
complete -c gitb -n __gitb_no_subcmd -a prev         -d 'Switch to previous branch'
complete -c gitb -n __gitb_no_subcmd -a update       -d 'Self-update gitbasher'
complete -c gitb -n __gitb_no_subcmd -a uninstall    -d 'Remove gitbasher config and binary'
complete -c gitb -n __gitb_no_subcmd -a uns          -d 'Alias of uninstall'
complete -c gitb -n __gitb_no_subcmd -a help         -d 'Show help'
function __gitb_at_commit_pos2
    set -l tokens (commandline -opc)
    test (count $tokens) -eq 2; or return 1
    contains -- $tokens[2] commit c co com
end
function __gitb_at_commit_extra
    set -l tokens (commandline -opc)
    test (count $tokens) -ge 3; or return 1
    contains -- $tokens[2] commit c co com
end
complete -c gitb -n __gitb_at_commit_pos2 -a "ai fast fasts ff ffp push fastp scope msg ticket staged no-split fixup amend split splitp aisplit aisplitp aip aif aifp last revert help"
complete -c gitb -n __gitb_at_commit_extra -a "ai fast push scope msg ticket staged no-split fixup amend split last revert help"
set -l __gitb_push "__gitb_using_cmd push p ps pus; and __gitb_at_position 2"
complete -c gitb -n "$__gitb_push" -a "yes force list help"
set -l __gitb_pull "__gitb_using_cmd pull pu pl pul; and __gitb_at_position 2"
complete -c gitb -n "$__gitb_pull" -a "fetch all upd ffonly merge rebase interactive dry help"
set -l __gitb_merge "__gitb_using_cmd merge m me; and __gitb_at_position 2"
complete -c gitb -n "$__gitb_merge" -a "main to-main remote help"
complete -c gitb -n "$__gitb_merge" -a "(__gitb_local_branches)" -d branch
set -l __gitb_rebase "__gitb_using_cmd rebase r re base; and __gitb_at_position 2"
complete -c gitb -n "$__gitb_rebase" -a "main interactive autosquash fastautosquash pull help"
complete -c gitb -n "$__gitb_rebase" -a "(__gitb_local_branches)" -d branch
set -l __gitb_squash "__gitb_using_cmd squash sq tidy; and __gitb_at_position 2"
complete -c gitb -n "$__gitb_squash" -a "preview yes push help"
set -l __gitb_cherry "__gitb_using_cmd cherry ch cp; and __gitb_at_position 2"
complete -c gitb -n "$__gitb_cherry" -a "hash range abort continue help"
set -l __gitb_sync "__gitb_using_cmd sync sy; and __gitb_at_position 2"
complete -c gitb -n "$__gitb_sync" -a "push merge mergep dry help"
set -l __gitb_wip "__gitb_using_cmd wip w; and __gitb_at_position 2"
complete -c gitb -n "$__gitb_wip" -a "up down help"
set -l __gitb_branch "__gitb_using_cmd branch b br bran; and __gitb_at_position 2"
complete -c gitb -n "$__gitb_branch" -a "list remote main delete prev recent gone tag help"
complete -c gitb -n "$__gitb_branch" -a "(__gitb_local_branches)" -d branch
set -l __gitb_tag "__gitb_using_cmd tag t tg; and __gitb_at_position 2"
complete -c gitb -n "$__gitb_tag" -a "annotated commit all push push-all delete delete-all list remote help"
set -l __gitb_config "__gitb_using_cmd config cf cfg conf; and __gitb_at_position 2"
complete -c gitb -n "$__gitb_config" -a "default separator editor ticket scopes ai provider model proxy history diff delete user auto help"
set -l __gitb_undo "__gitb_using_cmd undo un; and __gitb_at_position 2"
complete -c gitb -n "$__gitb_undo" -a "commit amend merge rebase stash help"
set -l __gitb_reset "__gitb_using_cmd reset res; and __gitb_at_position 2"
complete -c gitb -n "$__gitb_reset" -a "soft undo interactive help"
set -l __gitb_stash "__gitb_using_cmd stash st sta; and __gitb_at_position 2"
complete -c gitb -n "$__gitb_stash" -a "select all list pop show drop apply help"
set -l __gitb_worktree "__gitb_using_cmd worktree wt tree; and __gitb_at_position 2"
complete -c gitb -n "$__gitb_worktree" -a "list add addd addb addr remove prune lock unlock move path help"
set -l __gitb_origin "__gitb_using_cmd origin or o remote; and __gitb_at_position 2"
complete -c gitb -n "$__gitb_origin" -a "set change rename remove help"
set -l __gitb_log "__gitb_using_cmd log l lg; and __gitb_at_position 2"
complete -c gitb -n "$__gitb_log" -a "branch compare search help"
set -l __gitb_hook "__gitb_using_cmd hook ho hk; and __gitb_at_position 2"
complete -c gitb -n "$__gitb_hook" -a "list create edit toggle test show remove select install help"
function __gitb_at_log_branch
    set -l tokens (commandline -opc)
    test (count $tokens) -eq 3; or return 1
    contains -- $tokens[2] log l lg; or return 1
    contains -- $tokens[3] branch b
end
complete -c gitb -n __gitb_at_log_branch -a "local remote all help"
function __gitb_at_wip_backend
    set -l tokens (commandline -opc)
    test (count $tokens) -ge 3; or return 1
    contains -- $tokens[2] wip w; or return 1
    contains -- $tokens[3] up u down d
end
complete -c gitb -n __gitb_at_wip_backend -a "stash branch worktree nopush"
function __gitb_at_config_auto
    set -l tokens (commandline -opc)
    test (count $tokens) -eq 3; or return 1
    contains -- $tokens[2] config cf cfg conf; or return 1
    contains -- $tokens[3] auto completion comp
end
complete -c gitb -n __gitb_at_config_auto -a "up down status print help"
function __gitb_at_config_auto_shell
    set -l tokens (commandline -opc)
    test (count $tokens) -eq 4; or return 1
    contains -- $tokens[2] config cf cfg conf; or return 1
    contains -- $tokens[3] auto completion comp
end
complete -c gitb -n __gitb_at_config_auto_shell -a "bash zsh fish"
GITB_FISH_EOF
# kcov-skip-end
}


### Where to install completion for a given shell.
### For zsh we prefer directories that are already on the default $fpath so
### the completion loads without the user having to edit ~/.zshrc.
function _gitb_completion_path {
    local p
    case "$1" in
        bash)
            if command -v brew >/dev/null 2>&1; then
                echo "$(brew --prefix)/etc/bash_completion.d/gitb"
            else
                echo "$HOME/.local/share/bash-completion/completions/gitb"
            fi
            ;;
        zsh)
            local candidates=()
            if command -v brew >/dev/null 2>&1; then
                candidates+=("$(brew --prefix)/share/zsh/site-functions")
            fi
            candidates+=("/usr/local/share/zsh/site-functions" "/usr/share/zsh/site-functions")
            for p in "${candidates[@]}"; do
                if [ -d "$p" ] && [ -w "$p" ]; then
                    echo "$p/_gitb"
                    return
                fi
            done
            echo "$HOME/.zsh/completions/_gitb"
            ;;
        fish) echo "$HOME/.config/fish/completions/gitb.fish" ;;
    esac
}


### Whether a directory is on the user's interactive zsh $fpath.
### Spawns zsh -ic so we see the user's real environment (.zshrc edits).
function _gitb_dir_on_zsh_fpath {
    local dir="$1"
    local fp
    fp=$(zsh -ic 'echo $fpath' 2>/dev/null) || return 1
    case " $fp " in
        *" $dir "*) return 0 ;;
        *) return 1 ;;
    esac
}


### All locations gitb completion may have been installed to in the past or
### could plausibly be picked up from. Used to avoid leaving stale duplicates
### when the install path changes between gitb versions.
function _gitb_completion_known_locations {
    case "$1" in
        bash)
            echo "$HOME/.local/share/bash-completion/completions/gitb"
            echo "/etc/bash_completion.d/gitb"
            echo "/usr/share/bash-completion/completions/gitb"
            command -v brew >/dev/null 2>&1 && echo "$(brew --prefix)/etc/bash_completion.d/gitb"
            ;;
        zsh)
            echo "$HOME/.zsh/completions/_gitb"
            echo "$HOME/.oh-my-zsh/completions/_gitb"
            echo "$HOME/.oh-my-zsh/custom/plugins/gitb/_gitb"
            echo "/usr/local/share/zsh/site-functions/_gitb"
            echo "/usr/share/zsh/site-functions/_gitb"
            command -v brew >/dev/null 2>&1 && echo "$(brew --prefix)/share/zsh/site-functions/_gitb"
            ;;
        fish)
            echo "$HOME/.config/fish/completions/gitb.fish"
            echo "/usr/share/fish/vendor_completions.d/gitb.fish"
            ;;
    esac
}


### Detect the user's interactive shell from $SHELL
function _gitb_detect_shell {
    case "${SHELL##*/}" in
        bash|zsh|fish) echo "${SHELL##*/}" ;;
        *) echo "" ;;
    esac
}


### Whether the completion file is already on disk for a shell
function _gitb_is_completion_installed {
    [ -f "$(_gitb_completion_path "$1")" ]
}


function _gitb_install_completion {
    local shell="$1"
    local path
    path=$(_gitb_completion_path "$shell")
    mkdir -p "$(dirname "$path")"
    case "$shell" in
        bash) _gitb_bash_completion_content > "$path" ;;
        zsh)  _gitb_zsh_completion_content  > "$path" ;;
        fish) _gitb_fish_completion_content > "$path" ;;
    esac
    echo -e "${GREEN}Installed${ENDCOLOR} ${shell} completion to ${BOLD}${path}${NORMAL}"

    # Sweep stale copies left over from earlier installs at other known paths.
    local stale
    while IFS= read -r stale; do
        [ -z "$stale" ] && continue
        [ "$stale" = "$path" ] && continue
        if [ -f "$stale" ]; then
            rm -f "$stale" && echo -e "${YELLOW}Removed stale${ENDCOLOR} ${stale}"
        fi
    done < <(_gitb_completion_known_locations "$shell")
    echo
    case "$shell" in
        bash)
            echo -e "Activate now: ${BOLD}source ${path}${NORMAL}"
            echo -e "Or restart your shell."
            ;;
        zsh)
            local dir
            dir=$(dirname "$path")
            if _gitb_dir_on_zsh_fpath "$dir"; then
                echo -e "Activate now: ${BOLD}autoload -Uz compinit && compinit${NORMAL}"
                echo -e "Or restart your shell. ${BOLD}${dir}${NORMAL} is already on \$fpath."
            else
                echo -e "${YELLOW}Note:${ENDCOLOR} ${BOLD}${dir}${NORMAL} is not on your \$fpath."
                echo -e "Add to ~/.zshrc:"
                echo -e "  ${BOLD}fpath=(${dir} \$fpath)${NORMAL}"
                echo -e "  ${BOLD}autoload -Uz compinit && compinit${NORMAL}"
                echo -e "Then ${BOLD}source ~/.zshrc${NORMAL} or restart your shell."
            fi
            ;;
        fish)
            echo -e "Fish picks it up automatically — start a new shell or open a new tab."
            ;;
    esac
}


function _gitb_uninstall_completion {
    local shell="$1"
    local found=""
    local p
    while IFS= read -r p; do
        [ -z "$p" ] && continue
        if [ -f "$p" ]; then
            rm -f "$p" && echo -e "${GREEN}Removed${ENDCOLOR} ${p}"
            found="true"
        fi
    done < <(_gitb_completion_known_locations "$shell")
    if [ -z "$found" ]; then
        echo -e "${YELLOW}No ${shell} completion installed${ENDCOLOR}"
    fi
}


function _gitb_completion_status {
    local detected
    detected=$(_gitb_detect_shell)
    if [ -n "$detected" ]; then
        echo -e "Current shell: ${BOLD}${detected}${NORMAL}"
        echo
    fi
    local s p installed
    for s in bash zsh fish; do
        installed=""
        while IFS= read -r p; do
            [ -z "$p" ] && continue
            if [ -f "$p" ]; then
                if [ -z "$installed" ]; then
                    echo -e "  ${s}: ${GREEN}installed${ENDCOLOR} (${p})"
                    installed="true"
                else
                    echo -e "       ${YELLOW}also at${ENDCOLOR} ${p}"
                fi
            fi
        done < <(_gitb_completion_known_locations "$s")
        if [ -z "$installed" ]; then
            echo -e "  ${s}: ${YELLOW}not installed${ENDCOLOR}"
        fi
    done
}


### Top-level dispatcher for `gitb cfg auto <action> [shell]`
function completion_script {
    local action="${1:-up}"
    local shell="$2"

    if [ "$action" = "help" ] || [ "$action" = "h" ]; then
        echo -e "usage: ${YELLOW}gitb config auto <action> [shell]${ENDCOLOR}"
        echo
        local PAD=14
        printf "  ${YELLOW}%-*s${ENDCOLOR}  ${BLUE}%s${ENDCOLOR}\n" "$PAD" "Action" "Description"
        print_help_row $PAD "up"     ""    "Install tab completion (default; auto-detects shell)"
        print_help_row $PAD "down"   ""    "Remove installed tab completion"
        print_help_row $PAD "status" "st"  "Show installation state for bash, zsh, and fish"
        print_help_row $PAD "print"  ""    "Print the completion script to stdout"
        print_help_row $PAD "help"   "h"   "Show this help"
        echo
        echo -e "${YELLOW}Shells${ENDCOLOR}  ${BOLD}bash${NORMAL}, ${BOLD}zsh${NORMAL}, ${BOLD}fish${NORMAL} (defaults to your \$SHELL)"
        echo
        echo -e "${YELLOW}Examples${ENDCOLOR}"
        echo -e "  ${GREEN}gitb cfg auto${ENDCOLOR}              Install completion for the current shell"
        echo -e "  ${GREEN}gitb cfg auto up zsh${ENDCOLOR}       Install zsh completion explicitly"
        echo -e "  ${GREEN}gitb cfg auto down${ENDCOLOR}         Remove the installed completion"
        echo -e "  ${GREEN}gitb cfg auto status${ENDCOLOR}       Check what's installed for each shell"
        return 0
    fi

    if [ "$action" = "status" ] || [ "$action" = "st" ]; then
        _gitb_completion_status
        return 0
    fi

    if [ -z "$shell" ]; then
        shell=$(_gitb_detect_shell)
        if [ -z "$shell" ]; then
            echo -e "${RED}✗ Cannot detect shell from \$SHELL='${SHELL}'.${ENDCOLOR}"
            echo -e "Specify it explicitly: ${GREEN}gitb cfg auto ${action} <bash|zsh|fish>${ENDCOLOR}"
            return 1
        fi
    fi

    case "$shell" in
        bash|zsh|fish) ;;
        *)
            echo -e "${RED}✗ Unknown shell '${shell}'.${ENDCOLOR}"
            echo -e "Supported: bash, zsh, fish"
            return 1
            ;;
    esac

    case "$action" in
        up|u|on|install|enable)
            _gitb_install_completion "$shell"
            ;;
        down|d|off|uninstall|disable|remove)
            _gitb_uninstall_completion "$shell"
            ;;
        print|cat|p)
            "_gitb_${shell}_completion_content"
            ;;
        *)
            echo -e "${RED}✗ Unknown action '${action}'.${ENDCOLOR}"
            echo -e "Run ${GREEN}gitb cfg auto help${ENDCOLOR} to see available actions."
            return 1
            ;;
    esac
}


### One-shot prompt on first global gitbasher run.
### Stays silent if already prompted, completion already installed,
### shell can't be detected, or stdin isn't a tty.
function _gitb_first_run_completion_prompt {
    local prompted
    prompted=$(get_config_value gitbasher.completion.prompted "")
    [ "$prompted" = "true" ] && return 0

    if [ ! -t 0 ]; then
        git config --global gitbasher.completion.prompted "true" 2>/dev/null
        return 0
    fi

    local shell
    shell=$(_gitb_detect_shell)
    if [ -z "$shell" ]; then
        git config --global gitbasher.completion.prompted "true" 2>/dev/null
        return 0
    fi

    if _gitb_is_completion_installed "$shell"; then
        git config --global gitbasher.completion.prompted "true" 2>/dev/null
        return 0
    fi

    echo
    echo -e "${YELLOW}Tip:${ENDCOLOR} tab completion for ${BOLD}gitb${NORMAL} is not installed for ${BOLD}${shell}${NORMAL}."
    echo -e "Install it now? (y/N)"

    local choice
    read -n 1 -s choice
    echo

    git config --global gitbasher.completion.prompted "true" 2>/dev/null

    case "$choice" in
        y|Y)
            _gitb_install_completion "$shell"
            echo
            echo -e "Restart your shell or source the file above to activate."
            echo
            ;;
        *)
            echo -e "Skipped. Run ${BOLD}gitb cfg auto up${NORMAL} later if you change your mind."
            echo
            ;;
    esac
}
