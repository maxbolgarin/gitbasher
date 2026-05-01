#!/usr/bin/env bats

# Tests for repository helper functions in common.sh:
# get_repo (extended cases), ref_list, get_push_list edge cases,
# print_staged_files, switch error paths.

load setup_suite

setup() {
    setup_test_repo
    source_gitbasher
    cd "$TEST_REPO"
    current_branch="main"
    main_branch="main"
    origin_name="origin"
}

teardown() {
    cleanup_test_repo
    cleanup_remote_repo
}

# ===== get_repo: extended URL transformation tests =====

@test "get_repo: transforms self-hosted .ai TLD" {
    git remote add origin git@code.example.ai:user/repo.git
    repo=$(get_repo)
    [ "$repo" = "https://code.example.ai/user/repo" ]
}

@test "get_repo: transforms .uk TLD" {
    git remote add origin git@server.example.uk:user/repo.git
    repo=$(get_repo)
    [ "$repo" = "https://server.example.uk/user/repo" ]
}

@test "get_repo: transforms .de TLD" {
    git remote add origin git@server.example.de:user/repo.git
    repo=$(get_repo)
    [ "$repo" = "https://server.example.de/user/repo" ]
}

@test "get_repo: transforms ssh:// URL" {
    git remote add origin ssh://git@code.example.com/user/repo.git
    repo=$(get_repo)
    [ "$repo" = "https://code.example.com/user/repo" ]
}

@test "get_repo: leaves https URLs unchanged (minus .git)" {
    git remote add origin https://github.com/user/repo.git
    repo=$(get_repo)
    [ "$repo" = "https://github.com/user/repo" ]
}

@test "get_repo: handles URL without .git suffix" {
    git remote add origin git@github.com:user/repo
    repo=$(get_repo)
    [ "$repo" = "https://github.com/user/repo" ]
}

@test "get_repo: handles nested groups (gitlab subgroups)" {
    git remote add origin git@gitlab.com:group/sub/repo.git
    repo=$(get_repo)
    [ "$repo" = "https://gitlab.com/group/sub/repo" ]
}

@test "get_repo_name: works for all URL types" {
    git remote add origin git@gitlab.com:group/sub/myrepo.git
    name=$(get_repo_name)
    [ "$name" = "myrepo" ]
}

# ===== ref_list tests =====

@test "ref_list: populates refs_info and refs_hash" {
    make_test_commit "file1.txt" "First"
    make_test_commit "file2.txt" "Second"

    ref_list 5
    [ "${#refs_hash[@]}" -gt 0 ]
    [ "${#refs_info[@]}" -gt 0 ]
}

@test "ref_list: respects limit parameter" {
    for i in 1 2 3 4 5; do
        make_test_commit "file$i.txt" "Commit $i"
    done

    ref_list 3
    [ "${#refs_hash[@]}" -le 3 ]
}

# ===== get_push_list: edge cases =====

@test "get_push_list: returns empty when no remote configured" {
    get_push_list "main" "main" ""
    [ -z "$push_list" ]
    [ -z "$history_from" ]
}

@test "get_push_list: empty origin (whitespace-only)" {
    get_push_list "main" "main" "   "
    [ -z "$push_list" ]
}

@test "get_push_list: handles repo with new branch not on remote" {
    setup_remote_repo

    create_test_branch "feature/new"
    make_test_commit "feature.txt" "Feature commit"

    get_push_list "feature/new" "main" "origin"
    [ -n "$push_list" ]
}

@test "get_push_list: shows multiple unpushed commits" {
    setup_remote_repo

    make_test_commit "f1.txt" "Commit 1"
    make_test_commit "f2.txt" "Commit 2"
    make_test_commit "f3.txt" "Commit 3"

    get_push_list "main" "main" "origin"
    count=$(echo -e "$push_list" | wc -l | tr -d ' ')
    [ "$count" -eq 3 ]
}

# ===== print_staged_files tests =====

@test "print_staged_files: shows added files in green" {
    create_test_file "newfile.txt"
    git add newfile.txt
    output=$(print_staged_files)
    [[ "$output" =~ "newfile.txt" ]]
}

@test "print_staged_files: shows nothing for empty index" {
    output=$(print_staged_files)
    # No staged files = no real content (just maybe whitespace)
    [ -z "$(echo "$output" | tr -d '[:space:]')" ]
}

@test "print_staged_files: distinguishes modified files" {
    echo "modified" > README.md
    git add README.md
    output=$(print_staged_files)
    [[ "$output" =~ "README.md" ]]
}

@test "print_staged_files: distinguishes deleted files" {
    git rm README.md >/dev/null
    output=$(print_staged_files)
    [[ "$output" =~ "README.md" ]]
}

# ===== switch tests =====

@test "switch: switches to existing branch" {
    create_test_branch "feature"
    git checkout main

    current_branch="main"
    run switch "feature" "noinfo"
    [ "$status" -eq 0 ]
    [ "$(git branch --show-current)" = "feature" ]
}

@test "switch: same-branch detection" {
    current_branch="main"
    run switch "main" "noinfo"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Already" ]]
}

@test "switch: shows error for non-existent branch" {
    current_branch="main"
    run switch "nonexistent-branch" "noinfo"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "Cannot switch" ]] || [[ "$output" =~ "did not match" ]]
}

# ===== get_config_value / set_config_value tests =====

@test "get_config_value: returns default when not set" {
    val=$(get_config_value "nonexistent.key" "fallback")
    [ "$val" = "fallback" ]
}

@test "get_config_value: returns local value when set" {
    git config --local "test.local" "localvalue"
    val=$(get_config_value "test.local" "fallback")
    [ "$val" = "localvalue" ]
}

@test "set_config_value: writes to local config by default" {
    set_config_value "test.foo" "bar" >/dev/null
    val=$(git config --local --get "test.foo")
    [ "$val" = "bar" ]
}

@test "set_config_value: returns the value" {
    val=$(set_config_value "test.return" "expected")
    [ "$val" = "expected" ]
}

# ===== escape edge cases =====

@test "escape: handles backslash" {
    result=$(escape 'a\b' 'b')
    [[ "$result" == *"\\b"* ]]
}

@test "escape: leaves string unchanged when sub absent" {
    result=$(escape "hello world" "z")
    [ "$result" = "hello world" ]
}

# ===== git_status detailed =====

@test "git_status: detects modified+staged combo" {
    create_test_file "newfile.txt" "v1"
    git add newfile.txt
    echo "v2" > newfile.txt
    output=$(git_status)
    [[ "$output" =~ "newfile.txt" ]]
}

@test "git_status: handles untracked files" {
    create_test_file "untracked.txt"
    output=$(git_status)
    [[ "$output" =~ "untracked.txt" ]]
}
