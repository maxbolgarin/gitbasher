#!/usr/bin/env bats

# Tests for common utility functions in common.sh

load setup_suite

setup() {
    setup_test_repo
    source_gitbasher
    cd "$TEST_REPO"
}

teardown() {
    cleanup_test_repo
}

# ===== get_repo tests =====

@test "get_repo: returns empty for repo without remote" {
    repo=$(get_repo)
    [ -z "$repo" ]
}

@test "get_repo: returns HTTPS URL for git@ URL" {
    git remote add origin git@github.com:user/repo.git
    repo=$(get_repo)
    [ "$repo" = "https://github.com/user/repo" ]
}

@test "get_repo: returns URL without .git suffix" {
    git remote add origin https://github.com/user/repo.git
    repo=$(get_repo)
    [ "$repo" = "https://github.com/user/repo" ]
}

@test "get_repo: handles different TLDs" {
    git remote add origin git@gitlab.com:user/repo.git
    repo=$(get_repo)
    [ "$repo" = "https://gitlab.com/user/repo" ]
}

# ===== get_repo_name tests =====

@test "get_repo_name: returns repo name from URL" {
    git remote add origin https://github.com/user/myrepo.git
    repo_name=$(get_repo_name)
    [ "$repo_name" = "myrepo" ]
}

@test "get_repo_name: returns empty for repo without remote" {
    repo_name=$(get_repo_name)
    [ -z "$repo_name" ]
}

# ===== git_status tests =====

@test "git_status: shows modified files" {
    echo "modified content" > README.md
    status=$(git_status)
    [[ "$status" =~ "Modified" ]]
}

@test "git_status: shows added files" {
    create_test_file "newfile.txt"
    status=$(git_status)
    [[ "$status" =~ "Added" ]]
}

@test "git_status: shows deleted files" {
    rm README.md
    status=$(git_status)
    [[ "$status" =~ "Deleted" ]]
}

@test "git_status: shows staged files" {
    create_test_file "newfile.txt"
    git add newfile.txt
    status=$(git_status)
    [[ "$status" =~ "Staged" ]]
}

@test "git_status: returns empty for clean repo" {
    status=$(git_status)
    [ -z "$status" ]
}

# ===== commit_list tests =====

@test "commit_list: shows recent commits" {
    make_test_commit "file1.txt" "First commit"
    make_test_commit "file2.txt" "Second commit"

    commit_list 2 ""
    [ "${#commits_info[@]}" -eq 2 ]
    [ "${#commits_hash[@]}" -eq 2 ]
}

@test "commit_list: limits number of commits" {
    for i in {1..10}; do
        make_test_commit "file$i.txt" "Commit $i"
    done

    commit_list 5 ""
    [ "${#commits_info[@]}" -eq 5 ]
}

@test "commit_list: returns commit hashes" {
    make_test_commit "file1.txt" "Test commit"

    commit_list 1 ""
    [ -n "${commits_hash[0]}" ]
    [[ "${commits_hash[0]}" =~ ^[0-9a-f]+$ ]]
}

# ===== escape tests =====

@test "escape: escapes substring in string" {
    result=$(escape "hello/world" "/")
    [ "$result" = "hello\/world" ]
}

@test "escape: handles multiple occurrences" {
    result=$(escape "a/b/c" "/")
    [ "$result" = "a\/b\/c" ]
}

@test "escape: handles empty substring" {
    result=$(escape "hello" "")
    [ "$result" = "hello" ]
}

# ===== check_code tests =====

@test "check_code: exits on non-zero code" {
    run check_code 1 "Error message" "test command"
    [ "$status" -ne 0 ]
}

@test "check_code: continues on zero code" {
    run check_code 0 "" "test command"
    [ "$status" -eq 0 ]
}

@test "check_code: displays error message" {
    run check_code 1 "Test error" "test command"
    [[ "$output" =~ "Test error" ]]
}

# ===== list_branches tests =====

@test "list_branches: lists local branches" {
    create_test_branch "feature1"
    git checkout main
    create_test_branch "feature2"
    git checkout main

    list_branches
    [ "$number_of_branches" -eq 3 ]  # main, feature1, feature2
}

@test "list_branches: main branch is first" {
    create_test_branch "feature1"
    git checkout main

    list_branches
    [ "${branches_first_main[0]}" = "main" ]
}

@test "list_branches: excludes current branch in delete mode" {
    create_test_branch "feature1"
    create_test_branch "feature2"
    git checkout feature1

    main_branch="main"
    current_branch="feature1"
    list_branches "delete"

    # Should only have feature2 (not main, not current)
    for branch in "${branches_first_main[@]}"; do
        [ "$branch" != "feature1" ]
        [ "$branch" != "main" ]
    done
}

@test "list_branches: handles repo with single branch" {
    current_branch="main"
    main_branch="main"
    list_branches

    [ -n "$to_exit" ]
}
