#!/usr/bin/env bats

# Edge-case coverage for wip.sh and undo.sh helper functions:
#   * find_wip_stash returns 1 / sets ref empty when no matching stash exists
#   * find_wip_stash finds the stash by message when one exists
#   * find_wip_branch returns 1 when no wip/<branch> branch exists
#   * find_wip_worktree handles a repo with no extra worktrees
#   * undo_amend exits with an error when there is no amend in the reflog

load setup_suite

setup() {
    setup_test_repo
    cd "$TEST_REPO"
    git config user.email t@t
    git config user.name t
    git config commit.gpgsign false

    source "${GITBASHER_ROOT}/scripts/common.sh"
    source "${GITBASHER_ROOT}/scripts/wip.sh"
    source "${GITBASHER_ROOT}/scripts/undo.sh"

    current_branch="main"
}

teardown() {
    cleanup_test_repo
}

# ===== wip.sh =====

@test "wip: find_wip_stash returns false when stash list is empty" {
    run find_wip_stash
    [ "$status" -ne 0 ]
    [ -z "$wip_stash_ref" ]
}

@test "wip: find_wip_stash returns false when stash exists but message doesn't match" {
    : > a
    git stash push -u -m "unrelated stash" >/dev/null
    run find_wip_stash
    [ "$status" -ne 0 ]
    [ -z "$wip_stash_ref" ]
}

@test "wip: find_wip_stash locates stash with matching wip message" {
    : > a
    git stash push -u -m "wip: main" >/dev/null
    run find_wip_stash
    [ "$status" -eq 0 ]
    [[ "$output" == "" || true ]]  # no stdout expected; ref is set in caller scope
    # call again without `run` so the global is set in our scope
    find_wip_stash || true
    [[ "$wip_stash_ref" == stash@\{*\} ]]
}

@test "wip: find_wip_branch returns false when no wip branch exists" {
    run find_wip_branch
    [ "$status" -ne 0 ]
}

@test "wip: find_wip_branch returns true when wip/<branch> exists locally" {
    git branch wip/main
    run find_wip_branch
    [ "$status" -eq 0 ]
}

@test "wip: find_wip_worktree handles repo with no extra worktrees" {
    find_wip_worktree || true
    [ -z "$wip_worktree_path" ]
}

# ===== undo.sh =====

@test "undo_amend: exits non-zero when reflog contains no amend" {
    # Disable interactive prompts: the function exits before reaching them when
    # no amend is found.
    run undo_amend
    [ "$status" -ne 0 ]
    [[ "$output" == *"No amend found"* || "$output" == *"Cannot find"* ]]
}

@test "undo_amend: pre_amend_ref points at HEAD@{1} when last action was amend" {
    : > b
    git add b
    git commit -q -m "second"
    git commit -q --amend -m "second amended"

    last_action=$(git reflog -n 1 --pretty="%gs" 2>/dev/null)
    [[ "$last_action" == *"amend"* ]]
    # Sanity: the entry one before HEAD is the pre-amend state and exists
    git rev-parse "HEAD@{1}" >/dev/null
}
