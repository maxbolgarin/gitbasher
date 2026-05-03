#!/usr/bin/env bats

# Tests for the portable replacement for `git ls-files --deleted | xargs -r git rm`
# used in merge.sh and rebase.sh after a "force accept" conflict choice.
#
# The pattern (verbatim from those scripts) must:
#   * be a no-op when no files are deleted (no spurious `git rm` invocation)
#   * remove every deleted path when one or more exist
#   * work on BSD/macOS (this dev box) — not just GNU userland

load setup_suite

setup() {
    setup_test_repo
    cd "$TEST_REPO"
    git config user.email t@t
    git config user.name t
    git config commit.gpgsign false
    : > a
    : > b
    : > c
    git add a b c
    git commit -q -m "initial"
}

teardown() {
    cleanup_test_repo
}

# Run the portable cleanup snippet — copied verbatim from merge.sh / rebase.sh.
run_portable_cleanup() {
    mapfile -t _deleted < <(git ls-files --deleted)
    [ ${#_deleted[@]} -gt 0 ] && git rm -- "${_deleted[@]}" 2>/dev/null
    return 0
}

@test "portable: empty deleted list does not invoke git rm" {
    # No files deleted on disk
    run run_portable_cleanup
    [ "$status" -eq 0 ]
    # Index is still clean
    [ -z "$(git status --porcelain)" ]
}

@test "portable: removes a single deleted file from the index" {
    rm a
    run_portable_cleanup
    # 'a' should now be staged for deletion
    [[ "$(git status --porcelain a)" == "D "* ]]
}

@test "portable: removes multiple deleted files in one git rm call" {
    rm a b
    run_portable_cleanup
    [[ "$(git status --porcelain a)" == "D "* ]]
    [[ "$(git status --porcelain b)" == "D "* ]]
    # 'c' is still tracked normally
    [ -z "$(git status --porcelain c)" ]
}

@test "portable: filenames with spaces survive mapfile word boundaries" {
    : > "with space.txt"
    git add "with space.txt"
    git commit -q -m "add spaced"
    rm "with space.txt"
    run_portable_cleanup
    [[ "$(git status --porcelain "with space.txt")" == "D "* ]]
}
