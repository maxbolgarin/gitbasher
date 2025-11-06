#!/usr/bin/env bats

# Tests for basic git operations and workflows

load setup_suite

setup() {
    setup_test_repo
    source_gitbasher
    cd "$TEST_REPO"

    # Set required global variables
    current_branch=$(git branch --show-current)
    main_branch="main"
    origin_name="origin"
}

teardown() {
    cleanup_test_repo
}

# ===== Commit operations =====

@test "commit: can create a simple commit" {
    create_test_file "test.txt"
    git add test.txt
    git commit -m "test: add test file"

    log=$(git log -1 --oneline)
    [[ "$log" =~ "test: add test file" ]]
}

@test "commit: commit includes staged files" {
    create_test_file "file1.txt"
    create_test_file "file2.txt"
    git add file1.txt file2.txt
    git commit -m "test: add files"

    files=$(git diff-tree --no-commit-id --name-only -r HEAD)
    [[ "$files" =~ "file1.txt" ]]
    [[ "$files" =~ "file2.txt" ]]
}

@test "commit: cannot commit without message" {
    create_test_file "test.txt"
    git add test.txt

    run git commit -m ""
    [ "$status" -ne 0 ]
}

@test "commit: can amend last commit" {
    make_test_commit "file1.txt" "Initial message"

    create_test_file "file2.txt"
    git add file2.txt
    git commit --amend --no-edit

    files=$(git diff-tree --no-commit-id --name-only -r HEAD)
    [[ "$files" =~ "file1.txt" ]]
    [[ "$files" =~ "file2.txt" ]]

    count=$(git rev-list --count HEAD)
    [ "$count" -eq 2 ]  # Initial commit + our commit (not 3)
}

# ===== Push operations =====

@test "push: get_push_list shows unpushed commits" {
    setup_remote_repo

    make_test_commit "file1.txt" "Unpushed commit"

    get_push_list "main" "main" "origin"
    [[ "$push_list" =~ "Unpushed commit" ]]
}

@test "push: get_push_list empty when nothing to push" {
    setup_remote_repo

    get_push_list "main" "main" "origin"
    [ -z "$push_list" ]
}

@test "push: can push to remote" {
    setup_remote_repo

    make_test_commit "file1.txt" "New commit"
    git push origin main

    # Verify commit is in remote
    cd "$REMOTE_REPO"
    log=$(git log --oneline)
    [[ "$log" =~ "New commit" ]]
}

# ===== Pull operations =====

@test "pull: can pull from remote" {
    setup_remote_repo

    # Simulate remote change
    TEMP_CLONE=$(mktemp -d)
    git clone "$REMOTE_REPO" "$TEMP_CLONE"
    cd "$TEMP_CLONE"
    git config user.name "Test User"
    git config user.email "test@example.com"
    make_test_commit "remote.txt" "Remote commit"
    git push origin main

    # Pull in original repo
    cd "$TEST_REPO"
    git pull origin main

    log=$(git log -1 --oneline)
    [[ "$log" =~ "Remote commit" ]]

    rm -rf "$TEMP_CLONE"
}

# ===== Merge operations =====

@test "merge: can merge branch with fast-forward" {
    create_test_branch "feature"
    make_test_commit "feature.txt" "Feature work"
    git checkout main

    git merge feature --ff-only
    log=$(git log -1 --oneline)
    [[ "$log" =~ "Feature work" ]]
}

@test "merge: creates merge commit when needed" {
    # Create divergent branches
    create_test_branch "feature"
    make_test_commit "feature.txt" "Feature work"
    git checkout main
    make_test_commit "main.txt" "Main work"

    git merge feature --no-edit
    log=$(git log -1 --oneline)
    [[ "$log" =~ "Merge" ]]
}

@test "merge: detects conflicts" {
    create_test_branch "feature"
    echo "feature version" > conflict.txt
    git add conflict.txt
    git commit -m "Feature version"

    git checkout main
    echo "main version" > conflict.txt
    git add conflict.txt
    git commit -m "Main version"

    run git merge feature
    [ "$status" -ne 0 ]

    status_output=$(git status)
    [[ "$status_output" =~ "conflict" ]] || [[ "$status_output" =~ "CONFLICT" ]]
}

# ===== Rebase operations =====

@test "rebase: can rebase branch onto main" {
    # Create feature branch
    create_test_branch "feature"
    make_test_commit "feature1.txt" "Feature commit 1"

    git checkout main
    make_test_commit "main.txt" "Main commit"

    git checkout feature
    git rebase main

    # After rebase, Feature commit 1 should be the most recent commit
    # and Main commit should be its parent
    latest_commit=$(git log -1 --pretty=format:"%s")
    [[ "$latest_commit" =~ "Feature commit 1" ]]
    
    # Verify Main commit is in the history
    log=$(git log --oneline)
    [[ "$log" =~ "Main commit" ]]
}

# ===== Reset operations =====

@test "reset: soft reset keeps changes staged" {
    make_test_commit "file1.txt" "Commit to reset"

    git reset --soft HEAD~1

    status=$(git status --short)
    [[ "$status" =~ "A" ]]  # File should be staged (Added)
}

@test "reset: mixed reset keeps changes unstaged" {
    make_test_commit "file1.txt" "Commit to reset"

    git reset --mixed HEAD~1

    status=$(git status --short)
    [[ "$status" =~ "?" ]]  # File should be untracked
}

@test "reset: hard reset removes changes" {
    make_test_commit "file1.txt" "Commit to reset"

    git reset --hard HEAD~1

    [ ! -f "file1.txt" ]
}

# ===== Stash operations =====

@test "stash: can stash changes" {
    create_test_file "work.txt"
    git add work.txt

    git stash push -m "Work in progress"

    status=$(git status --short)
    [ -z "$status" ]
}

@test "stash: can pop stashed changes" {
    create_test_file "work.txt"
    git add work.txt
    git stash push -m "Work in progress"

    git stash pop

    status=$(git status --short)
    [[ "$status" =~ "work.txt" ]]
}

@test "stash: can list stashes" {
    create_test_file "work1.txt"
    git add work1.txt
    git stash push -m "First stash"

    create_test_file "work2.txt"
    git add work2.txt
    git stash push -m "Second stash"

    stash_list=$(git stash list)
    [[ "$stash_list" =~ "First stash" ]]
    [[ "$stash_list" =~ "Second stash" ]]
}

# ===== Tag operations =====

@test "tag: can create lightweight tag" {
    make_test_commit "release.txt" "Release commit"

    git tag v1.0.0

    tags=$(git tag)
    [[ "$tags" =~ "v1.0.0" ]]
}

@test "tag: can create annotated tag" {
    make_test_commit "release.txt" "Release commit"

    git tag -a v1.0.0 -m "Version 1.0.0"

    tag_msg=$(git tag -n v1.0.0)
    [[ "$tag_msg" =~ "Version 1.0.0" ]]
}

@test "tag: can delete tag" {
    make_test_commit "release.txt" "Release commit"
    git tag v1.0.0

    git tag -d v1.0.0

    tags=$(git tag)
    [[ ! "$tags" =~ "v1.0.0" ]]
}

# ===== Reflog operations =====

@test "reflog: tracks branch switching" {
    create_test_branch "feature"
    git checkout main

    reflog=$(git reflog -n 3)
    [[ "$reflog" =~ "checkout" ]]
}

@test "reflog: tracks commits" {
    make_test_commit "file1.txt" "Test commit"

    reflog=$(git reflog -n 2)
    [[ "$reflog" =~ "commit" ]]
}

@test "reflog: tracks resets" {
    make_test_commit "file1.txt" "Commit to reset"
    git reset --hard HEAD~1

    reflog=$(git reflog -n 2)
    [[ "$reflog" =~ "reset" ]]
}

# ===== Cherry-pick operations =====

@test "cherry-pick: can pick commit from another branch" {
    create_test_branch "feature"
    make_test_commit "feature.txt" "Feature commit"
    commit_hash=$(git rev-parse HEAD)

    git checkout main
    git cherry-pick "$commit_hash"

    log=$(git log -1 --oneline)
    [[ "$log" =~ "Feature commit" ]]
    [ -f "feature.txt" ]
}
