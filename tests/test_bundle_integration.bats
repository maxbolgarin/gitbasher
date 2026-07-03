#!/usr/bin/env bats

# Integration tests against the bundled dist/gitb binary. Most tests in this
# suite source individual scripts directly; this file proves the bundle —
# produced by dist/build.sh, with comments and source lines stripped — still
# dispatches commands correctly.
#
# We rebuild dist/gitb fresh in setup_suite-equivalent so the bundle tracks
# the current scripts/ tree. Tests cover only non-interactive paths (`help`,
# `status`-style read-only) because the bundle launches a real bash process
# we can't drive an interactive prompt against.

load setup_suite

setup() {
    setup_test_repo
    cd "$TEST_REPO"

    # Build a fresh bundle into a tmp file. We intentionally do NOT touch the
    # repo's checked-in dist/gitb — keep the test side-effect-free so it can
    # run during release and on developer machines.
    #
    # build.sh resolves `source scripts/foo.sh` lines relative to the CWD,
    # so we run it from GITBASHER_ROOT and pass relative paths.
    BUNDLE_PATH=$(mktemp)
    export BUNDLE_PATH
    (cd "$GITBASHER_ROOT" && bash ./dist/build.sh ./scripts/gitb.sh "$BUNDLE_PATH" dev) >/dev/null
    chmod +x "$BUNDLE_PATH"
}

teardown() {
    [ -n "$BUNDLE_PATH" ] && rm -f "$BUNDLE_PATH"
    cleanup_test_repo
}

@test "bundle: shebang on line 1 is bash" {
    head -1 "$BUNDLE_PATH" | grep -q '^#!/usr/bin/env bash$'
}

@test "bundle: contains no source lines after build" {
    ! grep -E '^[[:space:]]*(source|\.)[[:space:]]+[^[:space:]]+' "$BUNDLE_PATH"
}

@test "bundle: GITBASHER_VERSION line is present" {
    grep -q '^GITBASHER_VERSION="' "$BUNDLE_PATH"
}

@test "bundle: gitb help prints the top-level usage" {
    run bash "$BUNDLE_PATH" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"usage:"* ]]
    [[ "$output" == *"gitb"* ]]
}

@test "bundle: gitb --help works (normalized to help)" {
    run bash "$BUNDLE_PATH" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"usage:"* ]]
}

@test "bundle: gitb -h works (normalized to help)" {
    run bash "$BUNDLE_PATH" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"usage:"* ]]
}

@test "bundle: every top-level command's help dispatches" {
    for cmd in commit push pull branch merge rebase wip worktree stash undo reset tag cherry squash hook config update uninstall sync origin log; do
        run bash "$BUNDLE_PATH" "$cmd" help
        [ "$status" -eq 0 ] || { echo "$cmd help failed: $output" >&2; return 1; }
        [ ${#output} -gt 20 ] || { echo "$cmd help suspiciously short: $output" >&2; return 1; }
    done
}

@test "bundle: every top-level command's --help dispatches" {
    for cmd in commit push pull branch merge rebase wip stash undo reset tag cherry update; do
        run bash "$BUNDLE_PATH" "$cmd" --help
        [ "$status" -eq 0 ] || { echo "$cmd --help failed: $output" >&2; return 1; }
    done
}

@test "bundle: short aliases dispatch (c=commit, p=push, st=stash, s=status)" {
    run bash "$BUNDLE_PATH" c help
    [ "$status" -eq 0 ]
    [[ "$output" == *"GIT COMMIT"* ]] || [[ "$output" == *"commit"* ]]

    run bash "$BUNDLE_PATH" p help
    [ "$status" -eq 0 ]
    [[ "$output" == *"GIT PUSH"* ]] || [[ "$output" == *"push"* ]]

    run bash "$BUNDLE_PATH" st help
    [ "$status" -eq 0 ]
    [[ "$output" == *"STASH"* ]] || [[ "$output" == *"stash"* ]]
}

@test "bundle: unknown subcommand errors with a non-zero status" {
    # An unknown first arg must be a detectable failure for scripts chaining
    # on gitb, with a short pointer to `gitb help` instead of a silent
    # exit-0 usage dump.
    run bash "$BUNDLE_PATH" definitely-not-a-command
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown command"* ]]
    [[ "$output" == *"gitb help"* ]]
}

@test "bundle: --version reports a version string" {
    run bash "$BUNDLE_PATH" --version
    [ "$status" -eq 0 ]
    [[ "$output" == *"dev"* ]] || [[ "$output" == *"v"* ]]
}

@test "bundle: works in a git repo (basic dispatch)" {
    cd "$TEST_REPO"
    run bash "$BUNDLE_PATH" branch help
    [ "$status" -eq 0 ]
}
