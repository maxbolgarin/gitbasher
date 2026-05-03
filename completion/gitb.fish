# Fish completion for gitb (gitbasher)
#
# Install:
#   - User:   cp gitb.fish ~/.config/fish/completions/gitb.fish
#   - System: cp gitb.fish /usr/share/fish/vendor_completions.d/gitb.fish

# --- helpers ----------------------------------------------------------------

# True when the current command line has no subcommand yet (i.e. user is
# completing the first argument after `gitb`).
function __gitb_no_subcmd
    set -l tokens (commandline -opc)
    test (count $tokens) -eq 1
end

# True when the first argument matches one of the supplied aliases.
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

# True when the user is at position N (1-based offset of the next argument
# being typed; 1 == first argument after `gitb`).
function __gitb_at_position
    set -l tokens (commandline -opc)
    test (count $tokens) -eq (math $argv[1] + 0)
end

# Branch name list (used for `branch <name>` style completions).
function __gitb_local_branches
    git for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null
end

# --- top-level commands ------------------------------------------------------
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
complete -c gitb -n __gitb_no_subcmd -a s            -d 'Alias of stash'
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
complete -c gitb -n __gitb_no_subcmd -a st           -d 'Alias of status'
complete -c gitb -n __gitb_no_subcmd -a prev         -d 'Switch to previous branch'
complete -c gitb -n __gitb_no_subcmd -a help         -d 'Show help'

# --- second-level subcommands ------------------------------------------------

# commit
set -l __gitb_commit "__gitb_using_cmd commit c co com; and __gitb_at_position 2"
complete -c gitb -n "$__gitb_commit" -a "ai fast fasts ff push scope msg ticket staged no-split fixup amend split splitp aisplit aisplitp last revert help"

# push
set -l __gitb_push "__gitb_using_cmd push p ps pus; and __gitb_at_position 2"
complete -c gitb -n "$__gitb_push" -a "yes force list help"

# pull
set -l __gitb_pull "__gitb_using_cmd pull pu pl pul; and __gitb_at_position 2"
complete -c gitb -n "$__gitb_pull" -a "fetch all upd ffonly merge rebase interactive dry help"

# merge
set -l __gitb_merge "__gitb_using_cmd merge m me; and __gitb_at_position 2"
complete -c gitb -n "$__gitb_merge" -a "main to-main remote help"
complete -c gitb -n "$__gitb_merge" -a "(__gitb_local_branches)" -d branch

# rebase
set -l __gitb_rebase "__gitb_using_cmd rebase r re base; and __gitb_at_position 2"
complete -c gitb -n "$__gitb_rebase" -a "main interactive autosquash fastautosquash pull help"
complete -c gitb -n "$__gitb_rebase" -a "(__gitb_local_branches)" -d branch

# cherry
set -l __gitb_cherry "__gitb_using_cmd cherry ch cp; and __gitb_at_position 2"
complete -c gitb -n "$__gitb_cherry" -a "hash range abort continue help"

# sync
set -l __gitb_sync "__gitb_using_cmd sync sy; and __gitb_at_position 2"
complete -c gitb -n "$__gitb_sync" -a "push merge mergep dry help"

# wip
set -l __gitb_wip "__gitb_using_cmd wip w; and __gitb_at_position 2"
complete -c gitb -n "$__gitb_wip" -a "up down help"

# branch
set -l __gitb_branch "__gitb_using_cmd branch b br bran; and __gitb_at_position 2"
complete -c gitb -n "$__gitb_branch" -a "list remote main delete prev recent gone tag help"
complete -c gitb -n "$__gitb_branch" -a "(__gitb_local_branches)" -d branch

# tag
set -l __gitb_tag "__gitb_using_cmd tag t tg; and __gitb_at_position 2"
complete -c gitb -n "$__gitb_tag" -a "annotated commit all push push-all delete delete-all list remote help"

# config
set -l __gitb_config "__gitb_using_cmd config cf cfg conf; and __gitb_at_position 2"
complete -c gitb -n "$__gitb_config" -a "default separator editor ticket scopes ai provider model proxy history diff delete user help"

# undo
set -l __gitb_undo "__gitb_using_cmd undo un; and __gitb_at_position 2"
complete -c gitb -n "$__gitb_undo" -a "commit amend merge rebase stash help"

# reset
set -l __gitb_reset "__gitb_using_cmd reset res; and __gitb_at_position 2"
complete -c gitb -n "$__gitb_reset" -a "soft undo interactive help"

# stash
set -l __gitb_stash "__gitb_using_cmd stash s sta; and __gitb_at_position 2"
complete -c gitb -n "$__gitb_stash" -a "select all list pop show drop apply help"

# worktree
set -l __gitb_worktree "__gitb_using_cmd worktree wt tree; and __gitb_at_position 2"
complete -c gitb -n "$__gitb_worktree" -a "list add addd addb addr remove prune lock unlock move path help"

# origin
set -l __gitb_origin "__gitb_using_cmd origin or o remote; and __gitb_at_position 2"
complete -c gitb -n "$__gitb_origin" -a "set change rename remove help"

# log
set -l __gitb_log "__gitb_using_cmd log l lg; and __gitb_at_position 2"
complete -c gitb -n "$__gitb_log" -a "branch compare search help"

# hook
set -l __gitb_hook "__gitb_using_cmd hook ho hk; and __gitb_at_position 2"
complete -c gitb -n "$__gitb_hook" -a "list create edit toggle test show remove select install help"

# --- third-level subcommands -------------------------------------------------

# log branch <mode>
function __gitb_at_log_branch
    set -l tokens (commandline -opc)
    test (count $tokens) -eq 3; or return 1
    contains -- $tokens[2] log l lg; or return 1
    contains -- $tokens[3] branch b
end
complete -c gitb -n __gitb_at_log_branch -a "local remote all help"

# wip up|down <backend>
function __gitb_at_wip_backend
    set -l tokens (commandline -opc)
    test (count $tokens) -eq 3; or return 1
    contains -- $tokens[2] wip w; or return 1
    contains -- $tokens[3] up u down d
end
complete -c gitb -n __gitb_at_wip_backend -a "stash branch worktree nopush"
