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
    source "${GITBASHER_ROOT}/scripts/ai.sh"
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

### smart positional arguments

@test "log: numeric arg limits the list to that many commits" {
    make_test_commit one.txt "feat: one"
    make_test_commit two.txt "feat: two"
    current_branch="main"
    run gitlog_script 2 < /dev/null
    assert_success
    assert_output_contains "LAST 2 COMMITS"
    local numbered_lines
    numbered_lines=$(echo "$output" | grep -c '^ *[0-9]*\. ')
    [ "$numbered_lines" -eq 2 ]
}

@test "log: zero is rejected as a commit count" {
    run gitlog_script 0
    assert_output_contains "not a valid"
}

@test "log: numeric arg beats a file of the same name" {
    create_test_file "5" "a file named five"
    git add 5 && git commit -m "feat: add file named 5"
    current_branch="main"
    run gitlog_script 5 < /dev/null
    assert_success
    assert_output_contains "LAST 5 COMMITS"
}

@test "log: path arg shows file history and follows renames" {
    make_test_commit a.txt "feat: original file"
    git mv a.txt b.txt
    git commit -m "refactor: rename a to b"
    current_branch="main"
    run gitlog_script b.txt < /dev/null
    assert_success
    assert_output_contains "FILE HISTORY"
    assert_output_contains "original file"
    assert_output_contains "rename a to b"
}

@test "log: deleted but tracked path still resolves to file history" {
    make_test_commit gone.txt "feat: short lived file"
    git rm -q gone.txt
    git commit -m "chore: remove short lived file"
    current_branch="main"
    run gitlog_script gone.txt < /dev/null
    assert_success
    assert_output_contains "FILE HISTORY"
    assert_output_contains "short lived file"
}

@test "log: branch arg shows that ref's history" {
    create_test_branch feature
    make_test_commit feat.txt "feat: only on feature"
    git checkout -q main
    current_branch="main"
    run gitlog_script feature < /dev/null
    assert_success
    assert_output_contains "only on feature"
}

@test "log: range arg shows only the commits in the range" {
    create_test_branch feature
    make_test_commit feat.txt "feat: only on feature"
    git checkout -q main
    current_branch="main"
    run gitlog_script main..feature < /dev/null
    assert_success
    assert_output_contains "only on feature"
    local numbered_lines
    numbered_lines=$(echo "$output" | grep -c '^ *[0-9]*\. ')
    [ "$numbered_lines" -eq 1 ]
}

@test "log: reserved word all wins over a branch named all" {
    git branch all
    make_test_commit one.txt "feat: reserved winner"
    run gitlog_script all
    assert_success
    assert_output_contains "reserved winner"
    if [[ "$output" == *"commit number"* ]]; then
        echo "Reserved word 'all' opened the browser instead of the dump: $output"
        return 1
    fi
}

@test "log: unknown word falls back to message search" {
    make_test_commit one.txt "fix: teapot handling"
    make_test_commit two.txt "feat: unrelated"
    current_branch="main"
    run gitlog_script teapot < /dev/null
    assert_success
    assert_output_contains "COMMITS MATCHING"
    assert_output_contains "teapot handling"
    local numbered_lines
    numbered_lines=$(echo "$output" | grep -c '^ *[0-9]*\. ')
    [ "$numbered_lines" -eq 1 ]
}

@test "log: multi-word args are searched as one phrase" {
    make_test_commit one.txt "fix: teapot handling"
    current_branch="main"
    run gitlog_script teapot handling < /dev/null
    assert_success
    assert_output_contains "COMMITS MATCHING"
    assert_output_contains "teapot handling"
}

@test "log: search with no matches reports it" {
    run gitlog_script zzznothingzzz < /dev/null
    assert_output_contains "No commits found"
}

@test "log: search by hash finds the commit itself" {
    make_test_commit one.txt "feat: findable by hash"
    local short_hash
    short_hash=$(git rev-parse --short HEAD)
    run gitlog_search hash <<< "$short_hash"
    assert_success
    assert_output_contains "findable by hash"
}


### AI summary

@test "log: ai mode is gated when AI is unavailable" {
    make_test_commit one.txt "feat: one"
    check_ai_available() { return 1; }
    call_ai_api() { echo "AI_WAS_CALLED"; }
    run gitlog_ai 5
    if [[ "$output" == *"AI_WAS_CALLED"* ]]; then
        echo "AI must not be called when unavailable: $output"
        return 1
    fi
}

@test "log: ai default summarizes commits since the last tag" {
    git tag v1.0
    make_test_commit one.txt "feat: after tag one"
    make_test_commit two.txt "feat: after tag two"
    check_ai_available() { return 0; }
    call_ai_api() { printf '%s' "$2" > "$TEST_REPO/prompt.txt"; echo "AI SUMMARY OUTPUT"; }
    run gitlog_ai <<< ""
    assert_success
    assert_output_contains "AI SUMMARY OUTPUT"
    assert_output_contains "v1.0"
    local prompt
    prompt=$(< "$TEST_REPO/prompt.txt")
    [[ "$prompt" == *"after tag one"* ]]
    [[ "$prompt" == *"after tag two"* ]]
    [[ "$prompt" != *"Initial commit"* ]]
}

@test "log: ai numeric arg summarizes only the last N commits" {
    make_test_commit one.txt "feat: older change"
    make_test_commit two.txt "feat: newest change"
    check_ai_available() { return 0; }
    call_ai_api() { printf '%s' "$2" > "$TEST_REPO/prompt.txt"; echo "SUMMARY"; }
    run gitlog_ai 1
    assert_success
    local prompt
    prompt=$(< "$TEST_REPO/prompt.txt")
    [[ "$prompt" == *"newest change"* ]]
    [[ "$prompt" != *"older change"* ]]
}

@test "log: ai range arg summarizes exactly that range" {
    create_test_branch feature
    make_test_commit feat.txt "feat: only on feature"
    git checkout -q main
    check_ai_available() { return 0; }
    call_ai_api() { printf '%s' "$2" > "$TEST_REPO/prompt.txt"; echo "SUMMARY"; }
    run gitlog_ai main..feature
    assert_success
    local prompt
    prompt=$(< "$TEST_REPO/prompt.txt")
    [[ "$prompt" == *"only on feature"* ]]
    [[ "$prompt" != *"Initial commit"* ]]
}

@test "log: ai unpushed arg summarizes commits missing from upstream" {
    setup_remote_repo
    make_test_commit local.txt "feat: not pushed"
    check_ai_available() { return 0; }
    call_ai_api() { printf '%s' "$2" > "$TEST_REPO/prompt.txt"; echo "SUMMARY"; }
    run gitlog_ai unpushed
    assert_success
    local prompt
    prompt=$(< "$TEST_REPO/prompt.txt")
    [[ "$prompt" == *"not pushed"* ]]
    [[ "$prompt" != *"Initial commit"* ]]
}

@test "log: ai rejects an unresolvable range" {
    run gitlog_ai "bogus..nope"
    assert_output_contains "Cannot resolve"
}

@test "log: ai range builder caps the commit line count" {
    make_test_commit one.txt "feat: one"
    make_test_commit two.txt "feat: two"
    make_test_commit three.txt "feat: three"
    run get_commit_messages_for_ai_range HEAD 2
    assert_success
    assert_output_contains "feat: three"
    assert_output_contains "feat: two"
    assert_output_contains "more commits"
    if [[ "$output" == *"feat: one"* ]]; then
        echo "Line cap was not applied: $output"
        return 1
    fi
}


### clipboard

@test "log: copy action pipes the full hash into the clipboard tool" {
    make_test_commit one.txt "feat: copied"
    mkdir -p "$TEST_REPO/fakebin"
    printf '#!/usr/bin/env bash\ncat > "%s/clip.txt"\n' "$TEST_REPO" > "$TEST_REPO/fakebin/pbcopy"
    chmod +x "$TEST_REPO/fakebin/pbcopy"
    PATH="$TEST_REPO/fakebin:$PATH" run log_copy_hash "$(git rev-parse --short HEAD)"
    assert_success
    [ "$(cat "$TEST_REPO/clip.txt")" = "$(git rev-parse HEAD)" ]
}
