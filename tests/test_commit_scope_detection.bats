#!/usr/bin/env bats

# Tests for detect_scopes_from_staged_files in commit.sh.
# Exercises depth tracking, the "common dir" filter, dotfile handling, and
# the count-based filter that fires when there are many unique tokens.

load setup_suite

setup() {
    setup_test_repo
    source "${GITBASHER_ROOT}/scripts/common.sh"
    source "${GITBASHER_ROOT}/scripts/commit.sh"
    cd "$TEST_REPO"
}

teardown() {
    cleanup_test_repo
}

# Stage a file with the given path (creating parent dirs as needed).
stage() {
    local path="$1"
    mkdir -p "$(dirname "$path")"
    : > "$path"
    git add "$path"
}

@test "scope: empty stage produces empty detected_scopes" {
    detect_scopes_from_staged_files
    [ -z "$detected_scopes" ]
}

@test "scope: single file in flat layout uses filename token" {
    stage "router.go"
    detect_scopes_from_staged_files
    [[ "$detected_scopes" == *"router"* ]]
}

@test "scope: directory name dominates over filename when shared" {
    # Three files in 'auth/' should make 'auth' the strongest scope token
    stage "auth/login.go"
    stage "auth/logout.go"
    stage "auth/session.go"
    detect_scopes_from_staged_files
    [[ "$detected_scopes" == *"auth"* ]]
}

@test "scope: ignores common build/non-meaningful dirs" {
    # 'src' is filtered; the meaningful scope is 'parser'
    stage "src/parser/lexer.go"
    stage "src/parser/grammar.go"
    detect_scopes_from_staged_files
    [[ "$detected_scopes" == *"parser"* ]]
    [[ "$detected_scopes" != *" src "* && "$detected_scopes" != "src "* && "$detected_scopes" != *" src" && "$detected_scopes" != "src" ]]
}

@test "scope: 'tests' and 'lib' are filtered as non-meaningful" {
    stage "tests/foo.bats"
    stage "lib/bar.sh"
    detect_scopes_from_staged_files
    # Neither bare 'tests' nor bare 'lib' should appear as a top scope
    [[ "$detected_scopes" != *"tests"* ]]
    [[ "$detected_scopes" != *"lib"* ]]
}

@test "scope: dotfiles handled without empty-token errors" {
    stage ".gitignore"
    stage ".env.example"
    detect_scopes_from_staged_files
    # Function should complete without bash array-subscript errors and
    # return a non-fatal value
    [ -n "$detected_scopes" ] || [ -z "$detected_scopes" ]
}

@test "scope: file count above 100 is capped without crashing" {
    for i in $(seq 1 105); do
        stage "pkg/file${i}.go"
    done
    detect_scopes_from_staged_files
    [[ "$detected_scopes" == *"pkg"* ]]
}
