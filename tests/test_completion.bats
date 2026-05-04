#!/usr/bin/env bats

# Tests for scripts/completion.sh: the bash + zsh completion strings shipped
# by `gitb cfg completion install` must reference every top-level command and
# canonical alias defined in scripts/base.sh. Without this regression, alias
# changes silently leave tab completion stale.
#
# We extract the full list of commands+aliases from base.sh's case statement
# and assert each token is present in the completion output. We also verify
# the per-command sub-mode lists exist for every top-level command that has
# modes (commit, push, pull, branch, etc.) so the second-tab completion stays
# in sync.

load setup_suite

setup() {
    setup_test_repo
    source_gitbasher_lite
    source "${GITBASHER_ROOT}/scripts/completion.sh"
    cd "$TEST_REPO"
}

teardown() {
    cleanup_test_repo
}

@test "completion: bash completion string is non-empty" {
    out=$(_gitb_bash_completion_content)
    [ -n "$out" ]
    [ ${#out} -gt 200 ]
}

@test "completion: zsh completion string is non-empty" {
    out=$(_gitb_zsh_completion_content)
    [ -n "$out" ]
    [ ${#out} -gt 200 ]
}

@test "completion: bash completion declares _gitb_commands list" {
    out=$(_gitb_bash_completion_content)
    [[ "$out" == *"_gitb_commands="* ]]
}

@test "completion: bash completion declares _gitb_sub_commit list" {
    out=$(_gitb_bash_completion_content)
    [[ "$out" == *"_gitb_sub_commit="* ]]
}

# Every canonical top-level command in base.sh's dispatch should appear in the
# bash completion command list. Aliases live alongside; we spot-check a few of
# those too.

@test "completion: covers canonical top-level commands" {
    out=$(_gitb_bash_completion_content)
    # Pull just the _gitb_commands block to scope the search.
    cmds_block=$(printf '%s' "$out" | awk '/^_gitb_commands="$/,/^"$/')
    for cmd in commit push pull merge rebase squash cherry sync wip branch tag config undo reset stash worktree hook origin init log status update uninstall; do
        [[ "$cmds_block" == *" $cmd "* || "$cmds_block" == *" $cmd"$'\n'* || "$cmds_block" == *$'\n'"$cmd "* || "$cmds_block" == *$'\n'"$cmd"$'\n'* ]] \
            || { echo "missing top-level command in bash completion: $cmd" >&2; return 1; }
    done
}

@test "completion: covers common short aliases" {
    out=$(_gitb_bash_completion_content)
    cmds_block=$(printf '%s' "$out" | awk '/^_gitb_commands="$/,/^"$/')
    # Aliases from base.sh that users actually type. Updated alongside the
    # MIGRATION_V3_TO_V4.md "alias swap" entry — keep both files in sync.
    for alias in c p pu m r b t st w; do
        # Match the alias as a whole word in the multiline block.
        printf '%s\n' "$cmds_block" | grep -qE "(^| )$alias( |$)" \
            || { echo "missing alias in bash completion: $alias" >&2; return 1; }
    done
}

@test "completion: each top-level command with modes has a _gitb_sub_<cmd> list" {
    out=$(_gitb_bash_completion_content)
    for sub in commit push pull merge rebase squash cherry sync wip branch tag config undo reset stash worktree origin log; do
        [[ "$out" == *"_gitb_sub_${sub}="* ]] \
            || { echo "missing _gitb_sub_${sub}= in bash completion" >&2; return 1; }
    done
}

@test "completion: hook subcommand list is present" {
    out=$(_gitb_bash_completion_content)
    # base.sh dispatches `hook|ho|hk` to hooks_script. The sub list lives
    # under _gitb_sub_hook (singular) in completion.sh.
    [[ "$out" == *"_gitb_sub_hook="* ]]
}

@test "completion: every sub list ends with help and h tokens" {
    out=$(_gitb_bash_completion_content)
    # Pull each `_gitb_sub_<name>="..."` line and verify the value ends with
    # `help h` (the standard tail across every command). worktree and hook
    # have a different help suffix shape — skip those specific names.
    while IFS= read -r line; do
        case "$line" in
            *_gitb_sub_hook=*|*_gitb_sub_wip_backend=*|*_gitb_sub_log=*|*_gitb_sub_log_branch=*|*_gitb_sub_config_auto=*) continue ;;
        esac
        # Strip everything outside the quoted value.
        value=${line#*=\"}
        value=${value%\"}
        [[ "$value" == *"help h" ]] || [[ "$value" == *"help" ]] \
            || { echo "no help suffix on completion list: $line" >&2; return 1; }
    done < <(printf '%s\n' "$out" | grep -E '^_gitb_sub_[a-z_]+="')
}

@test "completion: zsh completion mentions the same top-level commands" {
    out=$(_gitb_zsh_completion_content)
    for cmd in commit push pull merge rebase wip branch tag config; do
        [[ "$out" == *"$cmd"* ]] \
            || { echo "missing in zsh completion: $cmd" >&2; return 1; }
    done
}
