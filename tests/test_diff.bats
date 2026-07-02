#!/usr/bin/env bats

# Tests for scripts/diff.sh: the `gitb diff` command.
#
# These exercise the testable surface against a REAL temp repo (setup_test_repo):
# mode dispatch, help, the staged/all scope diffs, the clean-tree message, the
# interactive default's file overview, branch/commit modes (with the interactive
# pickers stubbed), the AI summary mode (with the AI engine stubbed — real API
# calls have no place in a unit test), and the diff-capping helper.

load setup_suite

setup() {
    setup_test_repo
    source_gitbasher_lite
    source "${GITBASHER_ROOT}/scripts/diff.sh"
    cd "$TEST_REPO"
}

teardown() {
    cleanup_test_repo
}

@test "diff: unknown mode shows the wrong_mode error" {
    run diff_script bogus
    assert_output_contains "Unknown mode"
}

@test "diff: help lists the available modes" {
    run diff_script help
    assert_output_contains "staged"
    assert_output_contains "all"
    assert_output_contains "branch"
    assert_output_contains "commit"
    assert_output_contains "ai"
}

@test "diff: help is reachable via the h alias" {
    run diff_script h
    assert_output_contains "staged"
}

@test "diff: staged mode shows staged changes" {
    echo "a staged line" >> README.md
    git add README.md
    run diff_script staged
    assert_success
    assert_output_contains "README.md"
    assert_output_contains "a staged line"
}

@test "diff: the s alias routes to staged" {
    echo "another staged line" >> README.md
    git add README.md
    run diff_script s
    assert_success
    assert_output_contains "README.md"
}

@test "diff: all mode shows uncommitted changes against HEAD" {
    echo "an unstaged line" >> README.md
    run diff_script all
    assert_success
    assert_output_contains "README.md"
    assert_output_contains "an unstaged line"
}

@test "diff: default with a clean tree reports no changes" {
    run diff_script
    assert_success
    assert_output_contains "No changes"
}

@test "diff: default flow prints an overview listing changed files" {
    echo "a picker change" >> README.md
    # Stub the interactive picker so the loop exits without reading stdin.
    choose() { choice_result=""; return 0; }
    run diff_script
    assert_success
    assert_output_contains "README.md"
}

@test "diff: branch mode diffs the current branch against the chosen branch" {
    git checkout -b feature
    echo "a feature line" >> README.md
    git add README.md
    git commit -m "feature commit" --quiet
    # Stub the branch picker to select main.
    choose_branch() { branch_name="main"; to_exit=""; }
    run diff_branch
    assert_success
    assert_output_contains "README.md"
}

@test "diff: commit mode shows the chosen commit's diff" {
    create_test_file "newfile.txt" "brand new content"
    git add newfile.txt
    git commit -m "add newfile" --quiet
    # Stub the commit picker to select HEAD.
    local head_hash
    head_hash=$(git rev-parse HEAD)
    choose_commit() { commit_hash="$head_hash"; }
    run diff_commit
    assert_success
    assert_output_contains "newfile.txt"
}

@test "diff: ai mode is gated when AI is unavailable" {
    echo "some change" >> README.md
    check_ai_available() { return 1; }
    call_ai_api() { echo "CALLED_API"; }
    run diff_script ai
    [[ "$output" != *"CALLED_API"* ]]
}

@test "diff: ai mode calls the AI engine when available" {
    echo "some change" >> README.md
    check_ai_available() { return 0; }
    call_ai_api() { echo "AI_SUMMARY_MARKER"; }
    run diff_script ai
    assert_success
    assert_output_contains "AI_SUMMARY_MARKER"
}

@test "diff: ai mode reports when there is nothing to summarize" {
    check_ai_available() { return 0; }
    call_ai_api() { echo "AI_SUMMARY_MARKER"; }
    run diff_script ai
    [[ "$output" != *"AI_SUMMARY_MARKER"* ]]
    assert_output_contains "No changes"
}

@test "diff: get_limited_diff_for_ai_range caps output by line count" {
    get_ai_diff_limit() { echo 3; }
    get_ai_diff_max_chars() { echo 100000; }
    printf 'l1\nl2\nl3\nl4\nl5\nl6\n' >> README.md
    run get_limited_diff_for_ai_range HEAD
    assert_success
    [ -n "$output" ]
    line_count=$(printf '%s\n' "$output" | wc -l | tr -d ' ')
    [ "$line_count" -le 3 ]
}

@test "diff: print_ai_summary strips markdown heading markers" {
    run print_ai_summary "### Summary of Changes"
    assert_output_contains "Summary of Changes"
    [[ "$output" != *"#"* ]]
}

@test "diff: print_ai_summary converts markdown bullets and bold to terminal styling" {
    run print_ai_summary "* **New command:** adds a thing"
    assert_output_contains "New command:"
    assert_output_contains "adds a thing"
    [[ "$output" != *"**"* ]]
    [[ "$output" == *"•"* ]]
}

@test "diff: print_ai_summary leaves plain prose untouched" {
    run print_ai_summary "The changes add a diff command."
    assert_output_contains "The changes add a diff command."
    [[ "$output" != *"•"* ]]
}

@test "diff: print_ai_summary highlights a standalone section label" {
    run print_ai_summary "Risks & Concerns:"
    assert_output_contains "Risks & Concerns:"
}

@test "diff: print_ai_summary drops inline code backticks" {
    local bt='`'
    run print_ai_summary "Adds the ${bt}gitb diff${bt} command"
    assert_output_contains "gitb diff command"
    [[ "$output" != *"$bt"* ]]
}
