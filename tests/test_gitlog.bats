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
    # Colors must be real escape bytes, not a mangled literal "x1b[33m"
    if [[ "$output" == *"x1b["* ]]; then
        echo "Escape sequences leaked as literal text: $output"
        return 1
    fi
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


### interactive browser

@test "log: browser prints one page and exits cleanly on EOF" {
    git config gitbasher.log-count 2
    make_test_commit one.txt "feat: one"
    make_test_commit two.txt "feat: two"
    current_branch="main"
    run gitlog_browse "GIT LOG" head < /dev/null
    assert_success
    assert_output_contains "GIT LOG"
    assert_output_contains "Page 1/2"
    local numbered_lines
    numbered_lines=$(echo "$output" | grep -c '^ *[0-9]*\. ')
    [ "$numbered_lines" -eq 2 ]
}

@test "log: browser n key moves to the next page" {
    git config gitbasher.log-count 2
    make_test_commit one.txt "feat: one"
    make_test_commit two.txt "feat: two"
    current_branch="main"
    run gitlog_browse "GIT LOG" head <<< "n"
    assert_success
    assert_output_contains "Page 2/2"
    assert_output_contains "Initial commit"
}

@test "log: browser rejects an out-of-range commit number" {
    make_test_commit one.txt "feat: one"
    current_branch="main"
    run gitlog_browse "GIT LOG" head <<< "99"
    assert_success
    assert_output_contains "No commit with number"
}

@test "log: bare dispatch opens the browser instead of the dump" {
    make_test_commit one.txt "feat: browsed subject"
    current_branch="main"
    run gitlog_script < /dev/null
    assert_success
    assert_output_contains "1\. "
    assert_output_contains "browsed subject"
    assert_output_contains "commit number"
}


### commit action menu

@test "log: action menu shows the commit and returns on enter" {
    make_test_commit one.txt "feat: inspected commit"
    run log_commit_actions "$(git rev-parse --short HEAD)" <<< ""
    assert_success
    assert_output_contains "inspected commit"
    assert_output_contains "Revert"
}

@test "log: revert action refuses on a dirty tree" {
    make_test_commit one.txt "feat: bad commit"
    echo "dirt" >> one.txt
    run log_commit_actions "$(git rev-parse --short HEAD)" <<< "4"
    assert_output_contains "Cannot revert"
    [ "$(git log -1 --pretty=%s)" = "feat: bad commit" ]
}

@test "log: revert action reverts the commit on a clean tree" {
    make_test_commit one.txt "feat: bad commit"
    after_commit() { echo "committed ($1)"; }
    run log_commit_actions "$(git rev-parse --short HEAD)" <<< "4"
    assert_success
    [ "$(git log -1 --pretty=%s)" = "Revert \"feat: bad commit\"" ]
}

@test "log: fixup action requires staged changes" {
    make_test_commit one.txt "feat: target"
    run log_commit_actions "$(git rev-parse --short HEAD)" <<< "6"
    assert_output_contains "No staged changes"
}

@test "log: fixup action creates a fixup commit from staged changes" {
    make_test_commit one.txt "feat: target"
    local target_hash
    target_hash=$(git rev-parse --short HEAD)
    echo "fix" >> one.txt
    git add one.txt
    run log_commit_actions "$target_hash" <<< "6"
    assert_success
    [ "$(git log -1 --pretty=%s)" = "fixup! feat: target" ]
}

@test "log: copy action pipes the full hash into the clipboard tool" {
    make_test_commit one.txt "feat: copied"
    mkdir -p "$TEST_REPO/fakebin"
    printf '#!/usr/bin/env bash\ncat > "%s/clip.txt"\n' "$TEST_REPO" > "$TEST_REPO/fakebin/pbcopy"
    chmod +x "$TEST_REPO/fakebin/pbcopy"
    PATH="$TEST_REPO/fakebin:$PATH" run log_copy_hash "$(git rev-parse --short HEAD)"
    assert_success
    [ "$(cat "$TEST_REPO/clip.txt")" = "$(git rev-parse HEAD)" ]
}
