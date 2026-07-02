#!/usr/bin/env bats

# Tests for `gitb clone` (scripts/clone.sh)
#
# Focus:
#  - Issue #1: clone must *actually* initialize gitbasher so the first real
#    `gitb` command in the cloned repo does NOT re-run first-time init. That
#    means gitbasher.isfirst must be left "false", not "true".
#  - Issue #2: the interactive "enter the new repo" prompt / subshell must be
#    guarded so it never fires (or hangs) in non-interactive / test mode; the
#    printed `cd` hint stays as the fallback.

load 'setup_suite'

setup() {
    source_gitbasher_lite
    source "${GITBASHER_ROOT}/scripts/clone.sh"

    ORIG_DIR="$PWD"
    WORK=$(mktemp -d)
    WORK=$(cd "$WORK" && pwd -P)

    # A tiny source repo to clone from (local path is a valid git URL).
    SRC="$WORK/src"
    mkdir -p "$SRC"
    (
        cd "$SRC"
        git init --initial-branch=main -q
        git config user.name "Test User"
        git config user.email "test@example.com"
        git config commit.gpgsign false
        echo "hello" > README.md
        git add README.md
        git commit -q -m "init"
    )
}

teardown() {
    cd "$ORIG_DIR" 2>/dev/null || true
    [ -n "$WORK" ] && rm -rf "$WORK"
}

@test "clone leaves gitbasher.isfirst=false so first command does not re-init" {
    cd "$WORK"
    run clone_script "$SRC" cloned
    assert_success

    # The cloned repo must be treated as already-initialized.
    run git -C "$WORK/cloned" config --local --get gitbasher.isfirst
    assert_success
    assert_output_equals "false"
}

@test "clone writes a complete gitbasher config (branch + scopes)" {
    cd "$WORK"
    run clone_script "$SRC" cloned
    assert_success

    run git -C "$WORK/cloned" config --local --get gitbasher.branch
    assert_success
    assert_output_equals "main"

    # scopes is written (empty value) so the config is fully seeded.
    run git -C "$WORK/cloned" config --local gitbasher.scopes
    assert_success
}

@test "clone does not prompt or hang in non-interactive mode, prints cd hint" {
    cd "$WORK"
    # GITBASHER_TEST_MODE is exported by setup_suite, so the interactive
    # cd prompt/subshell must be skipped and the cd hint printed instead.
    run clone_script "$SRC" cloned
    assert_success
    assert_output_contains "cd "
    assert_output_contains "cloned"
}
