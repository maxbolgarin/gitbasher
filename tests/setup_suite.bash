#!/usr/bin/env bash

# BATS test setup and teardown helpers
# This file provides utilities for creating test git repositories

export BATS_TEST_DIRNAME="${BATS_TEST_DIRNAME:-$(dirname "${BASH_SOURCE[0]}")}"
export GITBASHER_ROOT="${BATS_TEST_DIRNAME}/.."
# Set flag to indicate we're running in test mode
export GITBASHER_TEST_MODE="true"

# BATS suite-level setup function
# This runs once before all tests in the suite
setup_suite() {
    # Verify git is available
    if ! command -v git &> /dev/null; then
        echo "Error: git is not installed or not in PATH"
        exit 1
    fi
    
    # Verify bash version (4.0+)
    if ((BASH_VERSINFO[0] < 4)); then
        echo "Error: Bash 4.0+ required. Current version: $BASH_VERSION"
        exit 1
    fi
}

# Setup a clean test git repository
# Returns the path to the test repo in TEST_REPO variable
setup_test_repo() {
    TEST_REPO=$(mktemp -d)
    export TEST_REPO

    cd "$TEST_REPO"
    git init --initial-branch=main
    git config user.name "Test User"
    git config user.email "test@example.com"
    git config commit.gpgsign false

    # Create initial commit
    echo "# Test Repo" > README.md
    git add README.md
    git commit -m "Initial commit"
}

# Cleanup test repository
cleanup_test_repo() {
    if [ -n "$TEST_REPO" ] && [ -d "$TEST_REPO" ]; then
        rm -rf "$TEST_REPO"
    fi
}

# Source gitbasher scripts for testing
source_gitbasher() {
    source "${GITBASHER_ROOT}/scripts/init.sh"
    source "${GITBASHER_ROOT}/scripts/common.sh"
}

# Create a test file with content
create_test_file() {
    local filename="$1"
    local content="${2:-Test content}"
    echo "$content" > "$filename"
}

# Make a commit with a file
make_test_commit() {
    local filename="${1:-testfile.txt}"
    local message="${2:-Test commit}"

    create_test_file "$filename" "Content for $filename"
    git add "$filename"
    git commit -m "$message"
}

# Create a test branch
create_test_branch() {
    local branch_name="$1"
    git checkout -b "$branch_name"
}

# Setup a remote repository
setup_remote_repo() {
    REMOTE_REPO=$(mktemp -d)
    export REMOTE_REPO

    cd "$REMOTE_REPO"
    git init --bare --initial-branch=main

    cd "$TEST_REPO"
    git remote add origin "$REMOTE_REPO"
    git push -u origin main
    
    # Set HEAD in bare repository to point to main branch
    cd "$REMOTE_REPO"
    git symbolic-ref HEAD refs/heads/main
    
    # Return to test repository directory
    cd "$TEST_REPO"
}

# Cleanup remote repository
cleanup_remote_repo() {
    if [ -n "$REMOTE_REPO" ] && [ -d "$REMOTE_REPO" ]; then
        rm -rf "$REMOTE_REPO"
    fi
}

# Assert that a command succeeds
assert_success() {
    if [ "$status" -ne 0 ]; then
        echo "Command failed with status $status"
        echo "Output: $output"
        return 1
    fi
}

# Assert that a command fails
assert_failure() {
    if [ "$status" -eq 0 ]; then
        echo "Command succeeded but was expected to fail"
        echo "Output: $output"
        return 1
    fi
}

# Assert output contains string
assert_output_contains() {
    local expected="$1"
    if [[ ! "$output" =~ $expected ]]; then
        echo "Expected output to contain: $expected"
        echo "Actual output: $output"
        return 1
    fi
}

# Assert output equals string
assert_output_equals() {
    local expected="$1"
    if [ "$output" != "$expected" ]; then
        echo "Expected: $expected"
        echo "Actual: $output"
        return 1
    fi
}
