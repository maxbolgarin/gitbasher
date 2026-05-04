#!/usr/bin/env bats

# Smoke tests: every domain script under scripts/ should source cleanly AND
# its <name>_script entrypoint should accept `help` without error.
#
# Why both:
#   - Sourcing alone only marks function-declaration lines as executed.
#     kcov (and codecov) often omit a file from the report if the count of
#     executed lines is too low, so source-only smoke tests don't lift much.
#   - Calling `<name>_script help` exercises the dispatch case statement at
#     the top of each entry function — that's 5-15 actual code lines per
#     file, which gets the file into the report and accounts for the
#     untestable interactive flows below the dispatch.
#
# The help block itself is wrapped in `# kcov-skip-start/end` markers, so
# the long printf chain doesn't pollute the numerator. Only the dispatch
# (the `case "$1" in help)` line and the `if [ -n "$help" ]` test) gets
# credited as covered.
#
# scripts/gitb.sh and scripts/base.sh are NOT sourced — they contain
# top-level dispatch logic that would `exit` the test process. Both are
# wrapped in file-wide kcov-skip markers since they're integration
# entrypoints, not unit-testable code.

load setup_suite

setup() {
    export GIT_CONFIG_GLOBAL=/dev/null
    setup_test_repo
    source_gitbasher_lite
    cd "$TEST_REPO"
    # Stub globals that some domain scripts read at dispatch time.
    current_branch="main"
    main_branch="main"
    origin_name="origin"
    sep="-"
    project_name="test"
    GITBASHER_VERSION="dev"
}

teardown() {
    cleanup_test_repo
}

# Each script gets its own @test so a single failure tells you which one.
# `run` sandboxes the help-branch `exit` so the bats process keeps going.

@test "smoke: ai.sh sources cleanly" {
    source "${GITBASHER_ROOT}/scripts/ai.sh"
}

@test "smoke: branch.sh: source + dispatch help" {
    source "${GITBASHER_ROOT}/scripts/branch.sh"
    run branch_script help
    [ "$status" -eq 0 ]
}

@test "smoke: cherry.sh: source + dispatch help" {
    source "${GITBASHER_ROOT}/scripts/cherry.sh"
    run cherry_script help
    [ "$status" -eq 0 ]
}

@test "smoke: commit.sh: source + dispatch help" {
    source "${GITBASHER_ROOT}/scripts/commit.sh"
    run commit_script help
    [ "$status" -eq 0 ]
}

@test "smoke: completion.sh: source + dispatch help" {
    source "${GITBASHER_ROOT}/scripts/completion.sh"
    run completion_script help
    [ "$status" -eq 0 ]
}

@test "smoke: config.sh: source + dispatch help" {
    source "${GITBASHER_ROOT}/scripts/config.sh"
    run config_script help
    [ "$status" -eq 0 ]
}

@test "smoke: gitlog.sh: source + dispatch help" {
    source "${GITBASHER_ROOT}/scripts/gitlog.sh"
    run gitlog_script help
    [ "$status" -eq 0 ]
}

@test "smoke: hooks.sh: source + dispatch help" {
    source "${GITBASHER_ROOT}/scripts/hooks.sh"
    run hooks_script help
    [ "$status" -eq 0 ]
}

@test "smoke: merge.sh: source + dispatch help" {
    source "${GITBASHER_ROOT}/scripts/merge.sh"
    run merge_script help
    [ "$status" -eq 0 ]
}

@test "smoke: origin.sh: source + dispatch help" {
    source "${GITBASHER_ROOT}/scripts/origin.sh"
    run origin_script help
    [ "$status" -eq 0 ]
}

@test "smoke: pull.sh: source + dispatch help" {
    source "${GITBASHER_ROOT}/scripts/pull.sh"
    run pull_script help
    [ "$status" -eq 0 ]
}

@test "smoke: push.sh: source + dispatch help" {
    source "${GITBASHER_ROOT}/scripts/push.sh"
    run push_script help
    [ "$status" -eq 0 ]
}

@test "smoke: rebase.sh: source + dispatch help" {
    source "${GITBASHER_ROOT}/scripts/rebase.sh"
    run rebase_script help
    [ "$status" -eq 0 ]
}

@test "smoke: reset.sh: source + dispatch help" {
    source "${GITBASHER_ROOT}/scripts/reset.sh"
    run reset_script help
    [ "$status" -eq 0 ]
}

@test "smoke: squash.sh: source + dispatch help" {
    source "${GITBASHER_ROOT}/scripts/squash.sh"
    run squash_script help
    [ "$status" -eq 0 ]
}

@test "smoke: stash.sh: source + dispatch help" {
    source "${GITBASHER_ROOT}/scripts/stash.sh"
    run stash_script help
    [ "$status" -eq 0 ]
}

@test "smoke: sync.sh: source + dispatch help" {
    source "${GITBASHER_ROOT}/scripts/sync.sh"
    run sync_script help
    [ "$status" -eq 0 ]
}

@test "smoke: tag.sh: source + dispatch help" {
    source "${GITBASHER_ROOT}/scripts/tag.sh"
    run tag_script help
    [ "$status" -eq 0 ]
}

@test "smoke: undo.sh: source + dispatch help" {
    source "${GITBASHER_ROOT}/scripts/undo.sh"
    run undo_script help
    [ "$status" -eq 0 ]
}

@test "smoke: uninstall.sh: source + dispatch help" {
    source "${GITBASHER_ROOT}/scripts/uninstall.sh"
    run uninstall_script help
    [ "$status" -eq 0 ]
}

@test "smoke: update.sh: source + dispatch help" {
    source "${GITBASHER_ROOT}/scripts/update.sh"
    run update_script help
    [ "$status" -eq 0 ]
}

@test "smoke: wip.sh: source + dispatch help" {
    source "${GITBASHER_ROOT}/scripts/wip.sh"
    run wip_script help
    [ "$status" -eq 0 ]
}

@test "smoke: worktree.sh: source + dispatch help" {
    source "${GITBASHER_ROOT}/scripts/worktree.sh"
    run worktree_script help
    [ "$status" -eq 0 ]
}
