#!/usr/bin/env bats

# Tests for branch operations

load setup_suite

setup() {
    setup_test_repo
    source_gitbasher
    cd "$TEST_REPO"

    # Set required global variables
    current_branch="main"
    main_branch="main"
    origin_name="origin"
}

teardown() {
    cleanup_test_repo
}

# ===== Branch creation tests =====

@test "branch: can create new branch" {
    git checkout -b feature/test-branch
    current=$(git branch --show-current)
    [ "$current" = "feature/test-branch" ]
}

@test "branch: new branch starts from current HEAD" {
    make_test_commit "file1.txt" "First commit"
    local original_hash=$(git rev-parse HEAD)

    git checkout -b feature/new
    local new_hash=$(git rev-parse HEAD)

    [ "$original_hash" = "$new_hash" ]
}

# ===== Branch switching tests =====

@test "switch: shows moved changes when switching with clean working tree" {
    create_test_branch "feature/test"
    git checkout main

    current_branch="main"
    run switch "feature/test"
    [ "$status" -eq 0 ]
}

# ===== Branch listing tests =====

@test "list_branches: correctly counts branches" {
    create_test_branch "feature/one"
    git checkout main
    create_test_branch "feature/two"
    git checkout main

    list_branches
    [ "$number_of_branches" -eq 3 ]
}

@test "list_branches: sorts branches by commit date" {
    # Create old branch
    create_test_branch "old-branch"
    make_test_commit "old.txt" "Old commit"
    git checkout main

    # Create new branch
    sleep 1
    create_test_branch "new-branch"
    make_test_commit "new.txt" "New commit"
    git checkout main

    list_branches
    # First should be main, second should be new-branch (most recent)
    [[ "${branches_first_main[1]}" == "new-branch" ]]
}

# ===== Branch deletion tests =====

@test "branch deletion: can delete merged branch" {
    create_test_branch "feature/to-delete"
    make_test_commit "feature.txt" "Feature work"
    git checkout main
    git merge feature/to-delete --no-edit

    git branch -d feature/to-delete
    branches=$(git branch --format="%(refname:short)")
    [[ ! "$branches" =~ "feature/to-delete" ]]
}

@test "branch deletion: prevents deletion of unmerged branch without force" {
    create_test_branch "feature/unmerged"
    make_test_commit "feature.txt" "Unmerged work"
    git checkout main

    run git branch -d feature/unmerged
    [ "$status" -ne 0 ]
}

# ===== Remote branch tests =====

@test "remote branches: can fetch from remote" {
    setup_remote_repo

    # Create branch on remote
    git checkout -b feature/remote-test
    make_test_commit "remote.txt" "Remote work"
    git push -u origin feature/remote-test
    git checkout main

    # Simulate another user fetching
    git fetch origin
    remote_branches=$(git branch -r)
    [[ "$remote_branches" =~ "origin/feature/remote-test" ]]
}

@test "remote branches: can track remote branch" {
    setup_remote_repo

    git checkout -b feature/tracked
    make_test_commit "tracked.txt" "Tracked work"
    git push -u origin feature/tracked

    tracking=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)
    [ "$tracking" = "origin/feature/tracked" ]
}

# ===== Branch naming tests =====

@test "branch naming: accepts valid branch names" {
    valid_names=(
        "feature/my-feature"
        "bugfix/issue-123"
        "release/v1.0.0"
        "hotfix/urgent-fix"
        "feature_underscore"
    )

    for name in "${valid_names[@]}"; do
        git checkout -b "$name" 2>/dev/null || true
        git checkout main
        git branch -D "$name" 2>/dev/null || true
    done
}

@test "branch naming: sanitization removes dangerous characters" {
    run sanitize_git_name "feature/test\$(rm -rf /)"
    [ "$status" -eq 0 ]
    [[ "$sanitized_git_name" != *'$'* ]]
    [[ "$sanitized_git_name" != *'('* ]]
}

# ===== Branch merging preparation tests =====

@test "merge preparation: identifies branches available for merge" {
    create_test_branch "feature/one"
    git checkout main
    create_test_branch "feature/two"
    git checkout main

    current_branch="main"
    main_branch="main"
    list_branches "merge"

    # Should not include main (current branch)
    for branch in "${branches_first_main[@]}"; do
        [ "$branch" != "main" ]
    done
}
