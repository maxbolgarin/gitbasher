#!/usr/bin/env bats

# Smoke test: every domain script under scripts/ should source cleanly into
# a bats subshell without errors. This serves two purposes:
#   1. Catches syntax errors / missing function references at load time.
#   2. Makes kcov see every script (a script that's never sourced doesn't
#      appear in the cobertura report at all, so the codecov "tracked lines"
#      column would silently exclude it).
#
# scripts/gitb.sh and scripts/base.sh are NOT sourced — both contain
# top-level dispatch logic (case "$1") that would exit the test process.
# Both are fully wrapped in kcov-skip markers since they're integration
# entrypoints, not unit-testable code.

load setup_suite

setup() {
    export GIT_CONFIG_GLOBAL=/dev/null
    setup_test_repo
    source_gitbasher_lite
    cd "$TEST_REPO"
    # Stub a few globals that some domain scripts reference at source time.
    current_branch="main"
    main_branch="main"
    origin_name="origin"
    sep="-"
}

teardown() {
    cleanup_test_repo
}

# Each script gets its own @test so a single failure tells you which one.
# Sourcing inside the test (not inside `run`) keeps coverage attributed to
# the bats-instrumented bash that kcov is wrapping.

@test "smoke: ai.sh sources cleanly" {
    source "${GITBASHER_ROOT}/scripts/ai.sh"
}

@test "smoke: branch.sh sources cleanly" {
    source "${GITBASHER_ROOT}/scripts/branch.sh"
}

@test "smoke: cherry.sh sources cleanly" {
    source "${GITBASHER_ROOT}/scripts/cherry.sh"
}

@test "smoke: commit.sh sources cleanly" {
    source "${GITBASHER_ROOT}/scripts/commit.sh"
}

@test "smoke: completion.sh sources cleanly" {
    source "${GITBASHER_ROOT}/scripts/completion.sh"
}

@test "smoke: config.sh sources cleanly" {
    source "${GITBASHER_ROOT}/scripts/config.sh"
}

@test "smoke: gitlog.sh sources cleanly" {
    source "${GITBASHER_ROOT}/scripts/gitlog.sh"
}

@test "smoke: hooks.sh sources cleanly" {
    source "${GITBASHER_ROOT}/scripts/hooks.sh"
}

@test "smoke: merge.sh sources cleanly" {
    source "${GITBASHER_ROOT}/scripts/merge.sh"
}

@test "smoke: origin.sh sources cleanly" {
    source "${GITBASHER_ROOT}/scripts/origin.sh"
}

@test "smoke: pull.sh sources cleanly" {
    source "${GITBASHER_ROOT}/scripts/pull.sh"
}

@test "smoke: push.sh sources cleanly" {
    source "${GITBASHER_ROOT}/scripts/push.sh"
}

@test "smoke: rebase.sh sources cleanly" {
    source "${GITBASHER_ROOT}/scripts/rebase.sh"
}

@test "smoke: reset.sh sources cleanly" {
    source "${GITBASHER_ROOT}/scripts/reset.sh"
}

@test "smoke: squash.sh sources cleanly" {
    source "${GITBASHER_ROOT}/scripts/squash.sh"
}

@test "smoke: stash.sh sources cleanly" {
    source "${GITBASHER_ROOT}/scripts/stash.sh"
}

@test "smoke: sync.sh sources cleanly" {
    source "${GITBASHER_ROOT}/scripts/sync.sh"
}

@test "smoke: tag.sh sources cleanly" {
    source "${GITBASHER_ROOT}/scripts/tag.sh"
}

@test "smoke: undo.sh sources cleanly" {
    source "${GITBASHER_ROOT}/scripts/undo.sh"
}

@test "smoke: uninstall.sh sources cleanly" {
    source "${GITBASHER_ROOT}/scripts/uninstall.sh"
}

@test "smoke: update.sh sources cleanly" {
    source "${GITBASHER_ROOT}/scripts/update.sh"
}

@test "smoke: wip.sh sources cleanly" {
    source "${GITBASHER_ROOT}/scripts/wip.sh"
}

@test "smoke: worktree.sh sources cleanly" {
    source "${GITBASHER_ROOT}/scripts/worktree.sh"
}
