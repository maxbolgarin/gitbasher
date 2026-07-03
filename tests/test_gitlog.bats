#!/usr/bin/env bats

# Tests for scripts/gitlog.sh: the `gitb log` command.
#
# These exercise the log list renderer, the interactive browser plumbing, the
# smart positional-argument dispatch and the AI summary mode against a REAL
# temp repo (setup_test_repo). Interactive collaborators and the AI engine are
# stubbed as bash functions — real prompts and API calls have no place here.

load setup_suite

setup() {
    setup_test_repo
    source_gitbasher_lite
    source "${GITBASHER_ROOT}/scripts/gitlog.sh"
    cd "$TEST_REPO"
}

teardown() {
    cleanup_test_repo
    cleanup_remote_repo
}


### log_collect_hashes

@test "log: log_collect_hashes head collects every commit hash" {
    make_test_commit one.txt "feat: one"
    make_test_commit two.txt "feat: two"
    log_collect_hashes head
    [ "$log_browse_total" -eq 3 ]
    [ "${#log_browse_hashes[@]}" -eq 3 ]
}

@test "log: log_collect_hashes count limits the number of hashes" {
    make_test_commit one.txt "feat: one"
    make_test_commit two.txt "feat: two"
    log_collect_hashes count 2
    [ "$log_browse_total" -eq 2 ]
}

@test "log: log_collect_hashes grep filters by message" {
    make_test_commit one.txt "feat: teapot handling"
    make_test_commit two.txt "fix: unrelated"
    log_collect_hashes grep "teapot"
    [ "$log_browse_total" -eq 1 ]
}

@test "log: log_collect_hashes path follows a single file" {
    make_test_commit one.txt "feat: one"
    make_test_commit two.txt "feat: two"
    log_collect_hashes path one.txt
    [ "$log_browse_total" -eq 1 ]
}


### log_commit_list rendering

@test "log: log_commit_list renders numbered rows with hash, author and age" {
    make_test_commit one.txt "feat: renderer subject"
    log_collect_hashes head
    run log_commit_list 0 10
    assert_success
    assert_output_contains "1\. "
    assert_output_contains "renderer subject"
    assert_output_contains "Test User"
    assert_output_contains "ago"
}

@test "log: log_commit_list truncates subjects longer than 60 chars" {
    local long_subject="feat: this subject is deliberately made very long so that it exceeds the sixty character budget"
    make_test_commit one.txt "$long_subject"
    log_collect_hashes head
    run log_commit_list 0 10
    assert_success
    assert_output_contains "deliberately"
    assert_output_contains '\.\.\.'
    if [[ "$output" == *"character budget"* ]]; then
        echo "Subject was not truncated: $output"
        return 1
    fi
}

@test "log: log_commit_list shows tag and branch decorations" {
    make_test_commit one.txt "feat: tagged commit"
    git tag v9.9.9
    log_collect_hashes head
    run log_commit_list 0 10
    assert_success
    assert_output_contains "v9.9.9"
}

@test "log: log_commit_list keeps a subject containing a pipe on one line" {
    make_test_commit one.txt "feat: handle a | b split"
    log_collect_hashes head
    run log_commit_list 0 10
    assert_success
    local numbered_lines
    numbered_lines=$(echo "$output" | grep -c '^ *[0-9]*\. ')
    [ "$numbered_lines" -eq 2 ]
    assert_output_contains "b split"
}

@test "log: log_commit_list paginates from the start index" {
    make_test_commit one.txt "feat: newest"
    make_test_commit two.txt "feat: even newer"
    log_collect_hashes head
    run log_commit_list 2 10
    assert_success
    assert_output_contains "Initial commit"
    if [[ "$output" == *"even newer"* ]]; then
        echo "Page should not include commits before the start index: $output"
        return 1
    fi
}

@test "log: log_commit_list marks only unpushed commits with an arrow" {
    setup_remote_repo
    make_test_commit local.txt "feat: not pushed yet"
    log_collect_hashes head
    run log_commit_list 0 10 mark_unpushed
    assert_success
    local marked unmarked
    marked=$(echo "$output" | grep "not pushed yet")
    unmarked=$(echo "$output" | grep "Initial commit")
    if [[ "$marked" != *"↑"* ]]; then
        echo "Unpushed commit is missing the ↑ marker: $marked"
        return 1
    fi
    if [[ "$unmarked" == *"↑"* ]]; then
        echo "Pushed commit must not carry the ↑ marker: $unmarked"
        return 1
    fi
}


### classic dump mode

@test "log: all mode prints the classic decorated dump" {
    make_test_commit one.txt "feat: dumped subject"
    git tag v1.2.3
    run gitlog_script all
    assert_success
    assert_output_contains "dumped subject"
    assert_output_contains "tag: v1.2.3"
}

@test "log: dump alias routes to the classic dump" {
    make_test_commit one.txt "feat: dumped subject"
    run gitlog_script dump
    assert_success
    assert_output_contains "dumped subject"
}

@test "log: help lists the all mode" {
    run gitlog_script help
    assert_output_contains "all"
    assert_output_contains "branch"
    assert_output_contains "search"
}
