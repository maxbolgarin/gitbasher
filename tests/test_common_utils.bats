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

# ===== get_repo_host tests =====

@test "get_repo_host: detects github" {
    [ "$(get_repo_host "https://github.com/user/repo")" = "github" ]
}

@test "get_repo_host: detects gitlab" {
    [ "$(get_repo_host "https://gitlab.com/user/repo")" = "gitlab" ]
}

@test "get_repo_host: detects bitbucket" {
    [ "$(get_repo_host "https://bitbucket.org/user/repo")" = "bitbucket" ]
}

@test "get_repo_host: returns empty for unknown host" {
    [ -z "$(get_repo_host "https://example.com/user/repo")" ]
}

# ===== URL builder tests =====

@test "get_branch_url: github" {
    [ "$(get_branch_url "feat" "https://github.com/u/r")" = "https://github.com/u/r/tree/feat" ]
}

@test "get_branch_url: gitlab" {
    [ "$(get_branch_url "feat" "https://gitlab.com/u/r")" = "https://gitlab.com/u/r/-/tree/feat" ]
}

@test "get_branch_url: bitbucket" {
    [ "$(get_branch_url "feat" "https://bitbucket.org/u/r")" = "https://bitbucket.org/u/r/branch/feat" ]
}

@test "get_commit_url: github" {
    [ "$(get_commit_url "abc123" "https://github.com/u/r")" = "https://github.com/u/r/commit/abc123" ]
}

@test "get_commit_url: gitlab" {
    [ "$(get_commit_url "abc123" "https://gitlab.com/u/r")" = "https://gitlab.com/u/r/-/commit/abc123" ]
}

@test "get_commit_url: bitbucket" {
    [ "$(get_commit_url "abc123" "https://bitbucket.org/u/r")" = "https://bitbucket.org/u/r/commits/abc123" ]
}

@test "get_new_pr_url: github builds compare URL" {
    result=$(get_new_pr_url "main" "feat" "https://github.com/u/r")
    [ "$result" = "https://github.com/u/r/compare/main...feat?expand=1" ]
}

@test "get_new_pr_url: gitlab builds new MR URL with source and target" {
    result=$(get_new_pr_url "main" "feat" "https://gitlab.com/u/r")
    [[ "$result" =~ "merge_requests/new" ]]
    [[ "$result" =~ "source_branch%5D=feat" ]]
    [[ "$result" =~ "target_branch%5D=main" ]]
}

@test "get_new_pr_url: bitbucket" {
    result=$(get_new_pr_url "main" "feat" "https://bitbucket.org/u/r")
    [ "$result" = "https://bitbucket.org/u/r/pull-requests/new?source=feat&dest=main" ]
}

@test "get_ci_url: github with branch" {
    [ "$(get_ci_url "feat" "https://github.com/u/r")" = "https://github.com/u/r/actions?query=branch%3Afeat" ]
}

@test "get_ci_url: github without branch" {
    [ "$(get_ci_url "" "https://github.com/u/r")" = "https://github.com/u/r/actions" ]
}

@test "get_ci_url: gitlab with branch" {
    [ "$(get_ci_url "feat" "https://gitlab.com/u/r")" = "https://gitlab.com/u/r/-/pipelines?ref=feat" ]
}

@test "get_ci_url: bitbucket" {
    [ "$(get_ci_url "feat" "https://bitbucket.org/u/r")" = "https://bitbucket.org/u/r/pipelines" ]
}

@test "get_ci_label: github" {
    [ "$(get_ci_label "https://github.com/u/r")" = "Actions" ]
}

@test "get_ci_label: gitlab" {
    [ "$(get_ci_label "https://gitlab.com/u/r")" = "Pipeline" ]
}

@test "get_ci_label: bitbucket" {
    [ "$(get_ci_label "https://bitbucket.org/u/r")" = "Pipelines" ]
}

@test "get_ci_label: unknown host falls back to CI" {
    [ "$(get_ci_label "https://example.com/u/r")" = "CI" ]
}

@test "get_tag_url: github" {
    [ "$(get_tag_url "v1.0.0" "https://github.com/u/r")" = "https://github.com/u/r/releases/tag/v1.0.0" ]
}

@test "get_tag_url: gitlab" {
    [ "$(get_tag_url "v1.0.0" "https://gitlab.com/u/r")" = "https://gitlab.com/u/r/-/tags/v1.0.0" ]
}

@test "get_tag_url: bitbucket" {
    [ "$(get_tag_url "v1.0.0" "https://bitbucket.org/u/r")" = "https://bitbucket.org/u/r/src/v1.0.0" ]
}

@test "get_new_release_url: github" {
    [ "$(get_new_release_url "v1.0.0" "https://github.com/u/r")" = "https://github.com/u/r/releases/new?tag=v1.0.0" ]
}

@test "get_new_release_url: gitlab" {
    [ "$(get_new_release_url "v1.0.0" "https://gitlab.com/u/r")" = "https://gitlab.com/u/r/-/releases/new?tag_name=v1.0.0" ]
}

@test "get_releases_url: github" {
    [ "$(get_releases_url "https://github.com/u/r")" = "https://github.com/u/r/releases" ]
}

@test "get_releases_url: gitlab" {
    [ "$(get_releases_url "https://gitlab.com/u/r")" = "https://gitlab.com/u/r/-/releases" ]
}

@test "get_tag_ci_url: github" {
    [ "$(get_tag_ci_url "v1.0.0" "https://github.com/u/r")" = "https://github.com/u/r/actions?query=ref%3Arefs%2Ftags%2Fv1.0.0" ]
}

@test "get_tag_ci_url: gitlab" {
    [ "$(get_tag_ci_url "v1.0.0" "https://gitlab.com/u/r")" = "https://gitlab.com/u/r/-/pipelines?ref=v1.0.0" ]
}

@test "get_issues_url: github" {
    [ "$(get_issues_url "https://github.com/u/r")" = "https://github.com/u/r/issues" ]
}

@test "get_issues_url: gitlab" {
    [ "$(get_issues_url "https://gitlab.com/u/r")" = "https://gitlab.com/u/r/-/issues" ]
}

@test "get_issues_url: bitbucket" {
    [ "$(get_issues_url "https://bitbucket.org/u/r")" = "https://bitbucket.org/u/r/issues" ]
}

@test "get_branches_url: github" {
    [ "$(get_branches_url "https://github.com/u/r")" = "https://github.com/u/r/branches" ]
}

@test "get_branches_url: gitlab" {
    [ "$(get_branches_url "https://gitlab.com/u/r")" = "https://gitlab.com/u/r/-/branches" ]
}

@test "get_branches_url: bitbucket" {
    [ "$(get_branches_url "https://bitbucket.org/u/r")" = "https://bitbucket.org/u/r/branches" ]
}

@test "get_tags_url: github" {
    [ "$(get_tags_url "https://github.com/u/r")" = "https://github.com/u/r/tags" ]
}

@test "get_tags_url: gitlab" {
    [ "$(get_tags_url "https://gitlab.com/u/r")" = "https://gitlab.com/u/r/-/tags" ]
}

@test "get_tags_url: bitbucket" {
    [ "$(get_tags_url "https://bitbucket.org/u/r")" = "https://bitbucket.org/u/r/branches/?tab=tags" ]
}

@test "get_commits_url: github" {
    [ "$(get_commits_url "https://github.com/u/r")" = "https://github.com/u/r/commits" ]
}

@test "get_commits_url: gitlab" {
    [ "$(get_commits_url "https://gitlab.com/u/r")" = "https://gitlab.com/u/r/-/commits" ]
}

@test "get_commits_url: bitbucket" {
    [ "$(get_commits_url "https://bitbucket.org/u/r")" = "https://bitbucket.org/u/r/commits" ]
}

@test "get_wiki_url: github" {
    [ "$(get_wiki_url "https://github.com/u/r")" = "https://github.com/u/r/wiki" ]
}

@test "get_wiki_url: gitlab" {
    [ "$(get_wiki_url "https://gitlab.com/u/r")" = "https://gitlab.com/u/r/-/wikis/home" ]
}

@test "get_wiki_url: bitbucket returns empty" {
    [ -z "$(get_wiki_url "https://bitbucket.org/u/r")" ]
}

@test "get_settings_url: github" {
    [ "$(get_settings_url "https://github.com/u/r")" = "https://github.com/u/r/settings" ]
}

@test "get_settings_url: gitlab" {
    [ "$(get_settings_url "https://gitlab.com/u/r")" = "https://gitlab.com/u/r/edit" ]
}

@test "get_settings_url: bitbucket" {
    [ "$(get_settings_url "https://bitbucket.org/u/r")" = "https://bitbucket.org/u/r/admin" ]
}

@test "get_insights_url: github" {
    [ "$(get_insights_url "https://github.com/u/r")" = "https://github.com/u/r/pulse" ]
}

@test "get_insights_url: gitlab" {
    [ "$(get_insights_url "https://gitlab.com/u/r")" = "https://gitlab.com/u/r/activity" ]
}

@test "get_insights_url: bitbucket returns empty" {
    [ -z "$(get_insights_url "https://bitbucket.org/u/r")" ]
}

@test "get_contributors_url: github" {
    [ "$(get_contributors_url "https://github.com/u/r")" = "https://github.com/u/r/graphs/contributors" ]
}

@test "get_contributors_url: gitlab" {
    [ "$(get_contributors_url "https://gitlab.com/u/r")" = "https://gitlab.com/u/r/-/graphs/master" ]
}

@test "get_forks_url: github" {
    [ "$(get_forks_url "https://github.com/u/r")" = "https://github.com/u/r/network/members" ]
}

@test "get_forks_url: gitlab" {
    [ "$(get_forks_url "https://gitlab.com/u/r")" = "https://gitlab.com/u/r/-/forks" ]
}

@test "get_forks_url: bitbucket" {
    [ "$(get_forks_url "https://bitbucket.org/u/r")" = "https://bitbucket.org/u/r/forks" ]
}

@test "get_pr_label: github" {
    [ "$(get_pr_label "https://github.com/u/r")" = "Pulls" ]
}

@test "get_pr_label: gitlab" {
    [ "$(get_pr_label "https://gitlab.com/u/r")" = "MRs" ]
}

@test "get_pr_label: bitbucket" {
    [ "$(get_pr_label "https://bitbucket.org/u/r")" = "Pulls" ]
}

@test "get_pr_label: unknown host falls back to PRs" {
    [ "$(get_pr_label "https://example.com/u/r")" = "PRs" ]
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
