#!/usr/bin/env bats

# Regression tests for automatic fast-mode staging in commit.sh.

load setup_suite

setup() {
    setup_test_repo
    source_gitbasher
    source "${GITBASHER_ROOT}/scripts/commit.sh"
    cd "$TEST_REPO"
}

teardown() {
    cleanup_test_repo
}

make_embedded_repo() {
    local path="$1"
    mkdir -p "$path"
    git -C "$path" init --initial-branch=main >/dev/null
    git -C "$path" config user.name "Nested User"
    git -C "$path" config user.email "nested@example.com"
    printf 'nested\n' > "$path/file.txt"
    git -C "$path" add file.txt
    git -C "$path" commit -m "test: nested repo" >/dev/null
}

@test "fast staging filters embedded git repositories from automatic staging" {
    create_test_file "regular.txt" "regular"
    make_embedded_repo ".worktree/test"

    run stage_fast_changes

    assert_success
    staged_files="$(git -c core.quotePath=false diff --name-only --cached)"
    [[ "$staged_files" == *"regular.txt"* ]]
    [[ "$staged_files" != *".worktree/test"* ]]
}

@test "fast staging colors embedded repository warning yellow and hint cyan" {
    create_test_file "regular.txt" "regular"
    make_embedded_repo ".worktree/test"

    run stage_fast_changes

    assert_success
    yellow=$(printf '%b' "$YELLOW")
    cyan=$(printf '%b' "$CYAN")
    endcolor=$(printf '%b' "$ENDCOLOR")
    [[ "$output" == *"${yellow}warning: adding embedded git repository: .worktree/test${endcolor}"* ]]
    [[ "$output" == *"${cyan}hint: You've added another git repository inside your current repository.${endcolor}"* ]]
}
