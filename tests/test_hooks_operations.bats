#!/usr/bin/env bats

# Functional coverage for hooks.sh (previously smoke-only): git-compatible
# hooks-dir resolution, honest enable/disable, working templates, and a
# test mode that cannot hang and propagates failure.

load setup_suite

setup() {
    setup_test_repo
    source_gitbasher
    source "$GITBASHER_ROOT/scripts/hooks.sh"
    cd "$TEST_REPO"

    current_branch="main"
    main_branch="main"
    origin_name=""
}

teardown() {
    cleanup_test_repo
}

@test "get_hooks_dir: respects core.hooksPath (husky-style setups)" {
    mkdir -p .husky
    git config core.hooksPath .husky
    result=$(get_hooks_dir)
    [[ "$result" == *".husky" ]]
}

@test "get_hooks_dir: resolves the shared hooks dir inside a linked worktree" {
    # Unique, auto-cleaned destination: a fixed ../ path leaked between
    # runs and made the second run fail on "already exists"
    wt_dest="$BATS_TEST_TMPDIR/hooks-wt-test"
    git worktree add -q -b wt-branch "$wt_dest"
    pushd "$wt_dest" >/dev/null
    result=$(get_hooks_dir)
    popd >/dev/null
    git worktree remove --force "$wt_dest" 2>/dev/null || true
    [[ "$result" == *"/hooks" ]]
    # Must NOT point into the per-worktree admin dir
    [[ "$result" != *"worktrees"* ]]
}

@test "toggle_hook: enable and disable are idempotent, not blind flips" {
    hooks_dir=$(get_hooks_dir)
    mkdir -p "$hooks_dir"
    printf '#!/bin/sh\nexit 0\n' > "$hooks_dir/pre-commit"
    chmod -x "$hooks_dir/pre-commit"

    # disable on an already-disabled hook must NOT enable it
    run toggle_hook "pre-commit" "disable"
    [ ! -x "$hooks_dir/pre-commit" ]

    run toggle_hook "pre-commit" "enable"
    [ -x "$hooks_dir/pre-commit" ]

    run toggle_hook "pre-commit" "enable"
    [ -x "$hooks_dir/pre-commit" ]
}

@test "create_hook: unknown template is rejected instead of writing an empty hook" {
    run create_hook "pre-commit" "no-such-template"
    [ "$status" -ne 0 ]
    hooks_dir=$(get_hooks_dir)
    [ ! -f "$hooks_dir/pre-commit" ]
}

@test "pre-commit-lint template: large staged file actually blocks the commit" {
    run create_hook "pre-commit" "pre-commit-lint"
    hooks_dir=$(get_hooks_dir)
    [ -f "$hooks_dir/pre-commit" ]

    # Stage an 11MB file; the template must reject it (the old NUL-stripped
    # plumbing made this check dead code)
    /usr/bin/mkfile -n 11m big.bin 2>/dev/null || dd if=/dev/zero of=big.bin bs=1048576 count=11 2>/dev/null
    git add big.bin
    run "$hooks_dir/pre-commit" < /dev/null
    [ "$status" -ne 0 ]
    [[ "$output" == *"Large file"* ]]
}

@test "test_hook: propagates the hook's failure exit code" {
    hooks_dir=$(get_hooks_dir)
    mkdir -p "$hooks_dir"
    printf '#!/bin/sh\nexit 3\n' > "$hooks_dir/pre-commit"
    chmod +x "$hooks_dir/pre-commit"
    run test_hook "pre-commit"
    [ "$status" -ne 0 ]
    [[ "$output" == *"failed"* ]]
}

@test "test_hook: commit-msg template passes with a sample message file" {
    run create_hook "commit-msg" "commit-msg-conventional"
    run test_hook "commit-msg"
    [ "$status" -eq 0 ]
    [[ "$output" == *"passed"* ]]
}

@test "test_hook: stdin-reading hook cannot hang" {
    hooks_dir=$(get_hooks_dir)
    mkdir -p "$hooks_dir"
    printf '#!/bin/sh\nwhile read line; do :; done\nexit 0\n' > "$hooks_dir/pre-push"
    chmod +x "$hooks_dir/pre-push"
    run perl -e 'alarm 5; exec @ARGV' -- bash -c "
        source '$GITBASHER_ROOT/scripts/common.sh' 2>/dev/null
        GITBASHER_SKIP_INIT_QUERIES=1 source '$GITBASHER_ROOT/scripts/init.sh' 2>/dev/null
        source '$GITBASHER_ROOT/scripts/hooks.sh'
        cd '$TEST_REPO'
        test_hook pre-push
    "
    [ "$status" -ne 142 ]
    [ "$status" -eq 0 ]
}
