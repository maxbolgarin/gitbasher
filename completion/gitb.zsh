#compdef gitb
# Zsh completion for gitb (gitbasher)
#
# Install:
#   - User:        cp gitb.zsh ~/.zsh/completions/_gitb
#                  fpath+=(~/.zsh/completions); autoload -Uz compinit && compinit
#   - System-wide: cp gitb.zsh /usr/local/share/zsh/site-functions/_gitb
#   - Oh-my-zsh:   cp gitb.zsh ~/.oh-my-zsh/completions/_gitb

_gitb() {
    local context state line
    typeset -A opt_args

    _arguments -C \
        '1: :->command' \
        '2: :->subcommand' \
        '3: :->subsubcommand' \
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
                'cherry:Cherry-pick commits (alias: ch, cp)'
                'sync:Sync with remote (alias: sy)'
                'wip:Work-in-progress save/restore (alias: w)'
                'branch:Branch operations (alias: b, br, bran)'
                'tag:Tag operations (alias: t, tg)'
                'config:Configure gitbasher (alias: cf, cfg, conf)'
                'undo:Undo recent operation (alias: un)'
                'reset:Reset HEAD (alias: res)'
                'stash:Stash operations (alias: s, sta)'
                'worktree:Worktree operations (alias: wt, tree)'
                'hook:Manage git hooks (alias: ho, hk)'
                'origin:Manage remote (alias: or, o, remote)'
                'init:Initialize repo (alias: i)'
                'log:Git log utilities (alias: l, lg)'
                'reflog:Show reflog (alias: rl, rlg)'
                'last-commit:Show last commit (alias: lc, lastc)'
                'last-ref:Show last ref (alias: lr, lastr)'
                'status:Project status (alias: st)'
                'prev:Switch to previous branch (alias: -)'
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
                        'splitp[split and push]' 'aisplit[AI-grouped split]' 'aisplitp[AI split and push]' \
                        'last[show last commit]' 'revert[revert a commit]' 'help[show help]'
                    ;;
                push|p|ps|pus)
                    _values 'push mode' \
                        'yes[skip confirmation]' 'force[force push]' 'list[show pending pushes]' 'help[show help]'
                    ;;
                pull|pu|pl|pul)
                    _values 'pull mode' \
                        'fetch[fetch only]' 'all[fetch all]' 'upd[update]' 'ffonly[fast-forward only]' \
                        'merge[merge]' 'rebase[rebase]' 'interactive[interactive rebase]' 'dry[dry run]' 'help[show help]'
                    ;;
                merge|m|me)
                    local -a branches
                    branches=( ${(f)"$(git for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null)"} )
                    _values 'merge target' \
                        'main[merge main into current]' 'to-main[merge current into main]' \
                        'remote[merge a remote branch]' 'help[show help]' \
                        $branches
                    ;;
                rebase|r|re|base)
                    local -a branches
                    branches=( ${(f)"$(git for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null)"} )
                    _values 'rebase mode' \
                        'main[rebase onto main]' 'interactive[interactive]' \
                        'autosquash[autosquash]' 'fastautosquash[fast autosquash]' \
                        'pull[pull commits]' 'help[show help]' \
                        $branches
                    ;;
                cherry|ch|cp)
                    _values 'cherry mode' \
                        'hash[pick by hash]' 'range[pick a range]' \
                        'abort[abort cherry-pick]' 'continue[continue cherry-pick]' 'help[show help]'
                    ;;
                sync|sy)
                    _values 'sync mode' \
                        'push[sync and push]' 'merge[sync via merge]' 'mergep[merge and push]' 'dry[dry run]' 'help[show help]'
                    ;;
                wip|w)
                    _values 'wip action' \
                        'up[save WIP]' 'down[restore WIP]' 'help[show help]'
                    ;;
                branch|b|br|bran)
                    local -a branches
                    branches=( ${(f)"$(git for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null)"} )
                    _values 'branch mode or name' \
                        'list[list branches]' 'remote[remote branches]' \
                        'main[switch to main]' 'delete[delete a branch]' \
                        'prev[previous branch]' 'recent[recent branches]' \
                        'gone[branches with gone upstream]' 'tag[tag operations]' 'help[show help]' \
                        $branches
                    ;;
                tag|t|tg)
                    _values 'tag mode' \
                        'annotated[create annotated tag]' 'commit[tag a commit]' \
                        'all[tag everything]' 'push[push tag]' 'push-all[push all tags]' \
                        'delete[delete tag]' 'delete-all[delete all]' \
                        'list[list tags]' 'remote[remote tags]' 'help[show help]'
                    ;;
                config|cf|cfg|conf)
                    _values 'config key' \
                        'default[default branch]' 'separator[separator char]' \
                        'editor[editor]' 'ticket[ticket prefix]' 'scopes[scope list]' \
                        'ai[AI key]' 'provider[AI provider]' 'model[AI model]' \
                        'proxy[AI proxy]' 'history[AI history]' 'diff[AI diff payload]' \
                        'delete[unset a key]' 'user[user name/email]' 'help[show help]'
                    ;;
                undo|un)
                    _values 'undo target' \
                        'commit[undo last commit]' 'amend[undo amend]' \
                        'merge[undo merge]' 'rebase[undo rebase]' \
                        'stash[undo stash]' 'help[show help]'
                    ;;
                reset|res)
                    _values 'reset mode' \
                        'soft[soft reset]' 'undo[reset to before last action]' \
                        'interactive[interactive reset]' 'help[show help]'
                    ;;
                stash|s|sta)
                    _values 'stash mode' \
                        'select[select a stash]' 'all[stash everything]' \
                        'list[list stashes]' 'pop[pop a stash]' 'show[show stash]' \
                        'drop[drop a stash]' 'apply[apply a stash]' 'help[show help]'
                    ;;
                worktree|wt|tree)
                    _values 'worktree mode' \
                        'list[list worktrees]' 'add[add from current HEAD]' \
                        'addd[add from default branch]' 'addb[add from local branch]' \
                        'addr[add from remote branch]' 'remove[remove a worktree]' \
                        'prune[prune stale records]' 'lock[lock a worktree]' \
                        'unlock[unlock a worktree]' 'move[move a worktree]' \
                        'path[print worktree path]' 'help[show help]'
                    ;;
                origin|or|o|remote)
                    _values 'origin action' \
                        'set[set remote]' 'change[change remote URL]' \
                        'rename[rename remote]' 'remove[remove remote]' 'help[show help]'
                    ;;
                log|l|lg)
                    _values 'log mode' \
                        'branch[log per branch]' 'compare[compare branches]' \
                        'search[search log]' 'help[show help]'
                    ;;
                hook|ho|hk)
                    _values 'hook action' \
                        'list[list hooks]' 'create[create a hook]' 'edit[edit a hook]' \
                        'toggle[toggle hook]' 'test[test a hook]' 'show[show hook]' \
                        'remove[remove a hook]' 'select[select a hook]' \
                        'install[install hooks]' 'help[show help]'
                    ;;
            esac
            ;;
        subsubcommand)
            case "$words[2]" in
                log|l|lg)
                    case "$words[3]" in
                        branch|b)
                            _values 'log branch mode' \
                                'local[local branches]' 'remote[remote branches]' \
                                'all[all branches]' 'help[show help]'
                            ;;
                    esac
                    ;;
                wip|w)
                    case "$words[3]" in
                        up|u|down|d)
                            _values 'wip backend / flag' \
                                'stash[stash backend]' 'branch[branch backend]' \
                                'worktree[worktree backend]' 'nopush[skip push]'
                            ;;
                    esac
                    ;;
            esac
            ;;
    esac
}

compdef _gitb gitb
