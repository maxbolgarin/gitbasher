#!/usr/bin/env bats

# Tests for pure URL/host helper functions in common.sh.
# These functions take a URL string and return a transformed URL or label —
# no git repo or init.sh globals are needed, so we use the lightweight setup
# to avoid per-test repo creation overhead.

load setup_suite

setup() {
    source_gitbasher_lite
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
