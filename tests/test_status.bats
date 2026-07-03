#!/usr/bin/env bats

# Tests for the enriched `status` command and its helpers in gitlog.sh:
# status_changes (grouped porcelain), status_upstream_line (ahead/behind),
# status_stash_line, status_inprogress_line, status_hint, and the
# project_status orchestrator (empty-repo / clean / grouped / help).

load setup_suite

setup() {
    setup_test_repo
    source_gitbasher
    source "${GITBASHER_ROOT}/scripts/gitlog.sh"
    cd "$TEST_REPO"
    current_branch="main"
    main_branch="main"
    origin_name="origin"
    project_name="testrepo"
    repo_url=""
}

teardown() {
    cleanup_test_repo
    cleanup_remote_repo
}

# ===== status_changes: grouping =====

@test "status_changes: clean repo shows working tree clean" {
    run status_changes
    assert_output_contains "Working tree clean"
}

@test "status_changes: staged file appears under Staged" {
    create_test_file "new.txt"
    git add new.txt
    run status_changes
    assert_output_contains "Staged"
    assert_output_contains "new.txt"
}

@test "status_changes: modified file appears under Not staged" {
    echo "change" >> README.md
    run status_changes
    assert_output_contains "Not staged"
    assert_output_contains "README.md"
}

@test "status_changes: untracked file appears under Untracked" {
    create_test_file "notes.md"
    run status_changes
    assert_output_contains "Untracked"
    assert_output_contains "notes.md"
}

@test "status_changes: deleted file is shown" {
    rm README.md
    run status_changes
    assert_output_contains "README.md"
}

@test "status_changes: rename shows the new name" {
    git mv README.md READTHIS.md
    run status_changes
    assert_output_contains "READTHIS.md"
}

@test "status_changes: merge conflict appears under Unmerged" {
    git checkout -b feature
    echo "feature change" > README.md
    git commit -am "feature edit"
    git checkout main
    echo "main change" > README.md
    git commit -am "main edit"
    run git merge feature
    run status_changes
    assert_output_contains "Unmerged"
    assert_output_contains "README.md"
}

# ===== status_upstream_line: ahead / behind / detached =====

@test "status_upstream_line: reports no upstream when untracked" {
    run status_upstream_line
    assert_output_contains "no upstream"
}

@test "status_upstream_line: up to date with origin" {
    setup_remote_repo
    run status_upstream_line
    assert_output_contains "up to date"
}

@test "status_upstream_line: shows ahead count" {
    setup_remote_repo
    make_test_commit "a.txt" "a"
    make_test_commit "b.txt" "b"
    run status_upstream_line
    assert_output_contains "↑2"
}

@test "status_upstream_line: shows behind indicator" {
    setup_remote_repo
    make_test_commit "a.txt" "a"
    make_test_commit "b.txt" "b"
    git push origin main
    git reset --hard HEAD~1
    run status_upstream_line
    assert_output_contains "↓"
}

@test "status_upstream_line: detached HEAD shows detached" {
    make_test_commit "x.txt" "x"
    git checkout --detach HEAD~1 2>/dev/null
    current_branch=""
    run status_upstream_line
    assert_output_contains "detached"
}

# ===== status_stash_line =====

@test "status_stash_line: shows count when stashes exist" {
    echo "wip1" >> README.md
    git stash
    echo "wip2" >> README.md
    git stash
    run status_stash_line
    assert_output_contains "⚑"
    assert_output_contains "2 stashes"
}

@test "status_stash_line: empty when no stashes" {
    run status_stash_line
    [ -z "$output" ]
}

# ===== status_inprogress_line =====

@test "status_inprogress_line: detects merge in progress" {
    git checkout -b feature
    echo "f" > README.md
    git commit -am "f"
    git checkout main
    echo "m" > README.md
    git commit -am "m"
    run git merge feature
    run status_inprogress_line
    assert_output_contains "Merge in progress"
}

@test "status_inprogress_line: detects rebase in progress" {
    git checkout -b feature
    echo "f" > README.md
    git commit -am "f"
    git checkout main
    echo "m" > README.md
    git commit -am "m"
    git checkout feature
    run git rebase main
    run status_inprogress_line
    assert_output_contains "Rebase in progress"
}

@test "status_inprogress_line: empty when nothing in progress" {
    run status_inprogress_line
    [ -z "$output" ]
}

# ===== status_hint =====

@test "status_hint: suggests push when ahead of upstream" {
    setup_remote_repo
    make_test_commit "a.txt" "a"
    run status_hint
    assert_output_contains "gitb push"
}

# ===== project_status: orchestration & edge cases =====

@test "project_status: empty repo shows no commits and no fatal error" {
    local empty
    empty=$(mktemp -d)
    empty=$(cd "$empty" && pwd -P)
    cd "$empty"
    git init --initial-branch=main >/dev/null 2>&1
    git config user.name "t"
    git config user.email "t@t"
    current_branch="main"
    main_branch="main"
    origin_name="origin"
    project_name="empty"
    repo_url=""
    run project_status
    assert_success
    assert_output_contains "No commits yet"
    if [[ "$output" =~ fatal ]]; then
        echo "unexpected git fatal in output: $output"
        rm -rf "$empty"
        return 1
    fi
    rm -rf "$empty"
}

@test "project_status: clean repo shows branch and clean tree" {
    run project_status
    assert_output_contains "main"
    assert_output_contains "Working tree clean"
}

@test "project_status: groups an unstaged modification under Not staged" {
    echo "x" >> README.md
    run project_status
    assert_output_contains "Not staged"
    assert_output_contains "README.md"
}

@test "project_status: falls back to directory name when project_name is empty" {
    project_name=""
    repo_url=""
    run project_status
    local dirname
    dirname=$(basename "$TEST_REPO")
    assert_output_contains "$dirname"
}

@test "project_status: help prints usage" {
    run project_status help
    assert_output_contains "Usage"
    assert_output_contains "status"
}
