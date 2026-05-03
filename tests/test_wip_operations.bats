#!/usr/bin/env bats

# Tests for the multi-backend wip command (stash / branch / worktree)

load setup_suite

setup() {
    setup_test_repo
    source_gitbasher
    source "${GITBASHER_ROOT}/scripts/wip.sh"
    cd "$TEST_REPO"

    make_test_commit "wip-base.txt" "Base for wip tests"

    current_branch="main"
    main_branch="main"
    origin_name=""
    sep="-"
    ticket_name=""
}

teardown() {
    if [ -n "$TEST_REPO" ] && [ -d "$TEST_REPO" ]; then
        cd "$TEST_REPO" 2>/dev/null && {
            git worktree list --porcelain 2>/dev/null \
                | awk '/^worktree /{print substr($0,10)}' \
                | while read -r path; do
                    if [ "$path" != "$TEST_REPO" ] && [ -d "$path" ]; then
                        rm -rf "$path"
                    fi
                done
            git worktree prune 2>/dev/null || true
        }
    fi
    cleanup_test_repo
}

# ===== Helpers =====

@test "wip_stash_message: uses current branch" {
    current_branch="feature/x"
    [ "$(wip_stash_message)" = "wip: feature/x" ]
}

@test "wip_remote_branch: prefixes with wip/" {
    current_branch="feature/x"
    [ "$(wip_remote_branch)" = "wip/feature/x" ]
}

@test "find_wip_branch: returns 0 when wip branch exists" {
    git branch "wip/main"
    run find_wip_branch
    [ "$status" -eq 0 ]
    git branch -D "wip/main"
}

@test "find_wip_branch: returns 1 when wip branch missing" {
    run find_wip_branch
    [ "$status" -ne 0 ]
}

@test "find_wip_worktree: locates worktree on the wip branch" {
    local target="$(mktemp -d)/wip-wt"
    git worktree add -b "wip/main" "$target" HEAD >/dev/null 2>&1

    find_wip_worktree
    [ "$wip_worktree_path" = "$target" ]

    git worktree remove --force "$target" >/dev/null 2>&1
    git branch -D "wip/main" >/dev/null 2>&1
}

@test "wip_worktree_default_path: respects gitbasher.worktreebase" {
    git config --local gitbasher.worktreebase "/tmp/wip-base"
    local result
    result=$(wip_worktree_default_path)
    local repo_dir
    repo_dir=$(basename "$TEST_REPO")
    [ "$result" = "/tmp/wip-base/${repo_dir}-wip-main" ]
}

# ===== Branch backend round-trip =====

@test "wip up branch + down branch: round-trips uncommitted changes" {
    echo "modified" >> wip-base.txt
    echo "new file" > new-file.txt

    run wip_up_branch "true"   # nopush=true
    [ "$status" -eq 0 ]

    [ -z "$(git status --porcelain)" ]
    git show-ref --verify --quiet refs/heads/wip/main

    current_branch=$(git branch --show-current)
    run wip_down_branch
    [ "$status" -eq 0 ]

    grep -q "modified" wip-base.txt
    [ -f "new-file.txt" ]
    run git show-ref --verify --quiet refs/heads/wip/main
    [ "$status" -ne 0 ]
}

@test "wip up branch: refuses when wip branch already exists" {
    git branch "wip/main"

    echo "modified" >> wip-base.txt
    run wip_up_branch "true"
    [ "$status" -ne 0 ]
    [[ "$output" == *"already exists"* ]]

    git branch -D "wip/main"
    git checkout -- wip-base.txt
}

@test "wip up branch: refuses when there are no changes" {
    run wip_up_branch "true"
    [ "$status" -eq 0 ]
    [[ "$output" == *"No changes to save"* ]]
}

# ===== Worktree backend round-trip =====

@test "wip up worktree + down worktree: round-trips uncommitted changes" {
    git config --local gitbasher.worktreebase "$(mktemp -d)"

    echo "wt-mod" >> wip-base.txt
    echo "wt-new" > wt-new.txt

    run wip_up_worktree "true"
    [ "$status" -eq 0 ]

    [ -z "$(git status --porcelain)" ]

    find_wip_worktree
    [ -n "$wip_worktree_path" ]
    [ -d "$wip_worktree_path" ]
    grep -q "wt-mod" "$wip_worktree_path/wip-base.txt"

    current_branch=$(git branch --show-current)
    run wip_down_worktree
    [ "$status" -eq 0 ]

    grep -q "wt-mod" wip-base.txt
    [ -f "wt-new.txt" ]
    run find_wip_branch
    [ "$status" -ne 0 ]
}

@test "wip down worktree: refuses to run from inside the wip worktree" {
    git config --local gitbasher.worktreebase "$(mktemp -d)"

    echo "wt-mod" >> wip-base.txt
    wip_up_worktree "true" >/dev/null 2>&1

    find_wip_worktree
    cd "$wip_worktree_path"

    # current_branch still reflects the original branch we want to restore;
    # the safety check compares the working dir path, not the branch name.
    run wip_down_worktree
    [ "$status" -ne 0 ]
    [[ "$output" == *"inside the WIP worktree"* ]]

    cd "$TEST_REPO"
    wip_down_worktree >/dev/null 2>&1 || true
}

# ===== Dispatcher =====

@test "wip_script: help prints all three backends" {
    run wip_script "help"
    [ "$status" -eq 0 ]
    [[ "$output" == *"stash"* ]]
    [[ "$output" == *"branch"* ]]
    [[ "$output" == *"worktree"* ]]
}

@test "wip_script: rejects unknown subcommand" {
    run wip_script "bogus"
    [[ "$output" == *"Unknown mode"* ]]
}

@test "wip up: legacy 'nopush' alone defaults to stash backend" {
    echo "legacy" >> wip-base.txt

    run wip_up "nopush"
    [ "$status" -eq 0 ]
    [[ "$output" == *"NO PUSH"* ]]

    # A stash entry should have been created
    git stash list | grep -q "wip: main"

    git stash drop >/dev/null 2>&1
    git checkout -- wip-base.txt
}

@test "wip down: error when no wip exists" {
    run wip_down ""
    [ "$status" -ne 0 ]
    [[ "$output" == *"No WIP found"* ]]
}
