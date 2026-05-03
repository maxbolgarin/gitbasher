#!/usr/bin/env bats

# Tests for the detached-HEAD helpers added to common.sh:
#   * on_branch — returns 0 when HEAD points at a branch, 1 when detached
#   * warn_if_detached_head — no-op (return 0) when on a branch; we do NOT
#     test the interactive prompt path here because it depends on stdin
#     handling that is out of scope for unit tests.

load setup_suite

setup() {
    setup_test_repo
    cd "$TEST_REPO"
    git config user.email t@t
    git config user.name t
    git config commit.gpgsign false
    : > a
    git add a
    git commit -q -m "first"
    : > b
    git add b
    git commit -q -m "second"

    source "${GITBASHER_ROOT}/scripts/common.sh"
}

teardown() {
    cleanup_test_repo
}

@test "on_branch: returns 0 on a normal branch" {
    run on_branch
    [ "$status" -eq 0 ]
}

@test "on_branch: returns 1 in detached HEAD state" {
    git checkout -q HEAD~1
    run on_branch
    [ "$status" -ne 0 ]
}

@test "warn_if_detached_head: no-op (returns 0, no output) on a branch" {
    run warn_if_detached_head "commit"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "warn_if_detached_head: prompts and exits 1 when detached and user declines" {
    git checkout -q HEAD~1
    # The function reads a single character; pipe 'n' to decline
    run bash -c "
        source '${GITBASHER_ROOT}/scripts/common.sh'
        printf 'n' | warn_if_detached_head 'commit'
    "
    [ "$status" -ne 0 ]
    [[ "$output" == *"detached HEAD"* ]]
}

@test "warn_if_detached_head: proceeds (returns 0) when detached and user accepts" {
    git checkout -q HEAD~1
    run bash -c "
        source '${GITBASHER_ROOT}/scripts/common.sh'
        printf 'y' | warn_if_detached_head 'commit'
    "
    [ "$status" -eq 0 ]
}
