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

# Tests for pure URL/host helpers (get_repo_host, get_branch_url, etc.) live in
# test_url_builders.bats — they don't need a git repo and use the lite setup.

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

# ===== is_network_error tests =====

@test "is_network_error: detects SSH connect timeout" {
    run is_network_error "ssh: connect to host gitlab.example.net port 22: Operation timed out"
    [ "$status" -eq 0 ]
}

@test "is_network_error: detects could not read from remote" {
    run is_network_error "fatal: Could not read from remote repository."
    [ "$status" -eq 0 ]
}

@test "is_network_error: detects could not resolve host" {
    run is_network_error "ssh: Could not resolve hostname github.com: Name or service not known"
    [ "$status" -eq 0 ]
}

@test "is_network_error: detects connection refused" {
    run is_network_error "fatal: unable to access 'https://...': Failed to connect to host: Connection refused"
    [ "$status" -eq 0 ]
}

@test "is_network_error: detects kex_exchange_identification" {
    run is_network_error "kex_exchange_identification: Connection closed by remote host"
    [ "$status" -eq 0 ]
}

@test "is_network_error: does NOT match rejected (unpulled changes)" {
    run is_network_error "! [rejected]        main -> main (fetch first)"
    [ "$status" -ne 0 ]
}

@test "is_network_error: does NOT match permission denied" {
    run is_network_error "remote: Permission to user/repo.git denied to someone."
    [ "$status" -ne 0 ]
}

@test "is_network_error: does NOT match generic push failure" {
    run is_network_error "error: failed to push some refs to 'origin'"
    [ "$status" -ne 0 ]
}

# ===== print_changes_stat =====

@test "print_changes_stat: prints file rows and summary" {
    run print_changes_stat " a.txt | 3 ++-
 b-c.txt | 1 -
 2 files changed, 2 insertions(+), 2 deletions(-)"
    [ "$status" -eq 0 ]
    [[ "$output" == *"a.txt"* ]]
    [[ "$output" == *"b-c.txt"* ]]
    [[ "${lines[${#lines[@]}-1]}" == "2 files changed, 2 insertions(+), 2 deletions(-)" ]]
}

@test "print_changes_stat: limit collapses extra rows into a count" {
    stat=""
    for i in 1 2 3 4 5; do stat="${stat} f$i.txt | 1 +"$'\n'; done
    stat="${stat} 5 files changed, 5 insertions(+)"
    run print_changes_stat "$stat" 2
    [ "$status" -eq 0 ]
    [[ "$output" == *"f2.txt"* ]]
    [[ "$output" != *"f3.txt"* ]]
    [[ "$output" == *"... and 3 more files"* ]]
    [[ "$output" == *"5 files changed"* ]]
}

@test "print_changes_stat: create mode rows stay after the summary" {
    run print_changes_stat " new.txt | 1 +
 1 file changed, 1 insertion(+)
 create mode 100644 new.txt"
    [ "$status" -eq 0 ]
    [[ "${lines[1]}" == "1 file changed, 1 insertion(+)" ]]
    [[ "${lines[2]}" == *"create mode 100644 new.txt"* ]]
}

@test "print_changes_stat: does not color hyphens in file names" {
    GREEN_ES="<G>" RED_ES="<R>" ENDCOLOR_ES="<E>" run print_changes_stat " my-file.txt | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)"
    [[ "$output" == *"my-file.txt"* ]]
    [[ "$output" == *"<G>+<E><R>-<E>"* ]]
}

@test "print_changes_stat: empty input prints nothing" {
    run print_changes_stat ""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
