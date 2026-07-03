#!/usr/bin/env bats

# Error paths must exit non-zero so scripts and CI chaining on gitb can
# detect failures. Historically several error messages ended in a bare
# `exit` (status 0): unknown modes, unknown top-level commands, and the
# switch overwrite-conflict error. These tests pin the contract.

load setup_suite

setup() {
    setup_test_repo
    source_gitbasher
    cd "$TEST_REPO"

    current_branch="main"
    main_branch="main"
    origin_name=""
}

teardown() {
    cleanup_test_repo
}

@test "wrong_mode: unknown mode exits non-zero with guidance" {
    run wrong_mode "commit" "bogus"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown mode"* ]]
    [[ "$output" == *"gitb commit help"* ]]
}

@test "wrong_mode: empty mode is a no-op (default flows continue)" {
    run wrong_mode "commit" ""
    [ "$status" -eq 0 ]
}

@test "fetch_script: unknown mode exits non-zero" {
    source "$GITBASHER_ROOT/scripts/pull.sh"
    source "$GITBASHER_ROOT/scripts/fetch.sh"
    run fetch_script "bogus"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown mode"* ]]
}

@test "wip_script: unknown subcommand exits non-zero" {
    source "$GITBASHER_ROOT/scripts/wip.sh"
    run wip_script "bogus"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown mode"* ]]
}

@test "switch: overwrite conflict exits non-zero" {
    git switch -qc feature
    echo "tracked on feature" > f.txt
    git add f.txt
    git commit -qm "feature adds f.txt"
    git switch -q main
    echo "local uncommitted" > f.txt
    run switch "feature" "no-log"
    [ "$status" -ne 0 ]
    [[ "$output" == *"overwritten"* ]]
}

@test "gitb bundle: unknown top-level command exits non-zero" {
    [ -f "$GITBASHER_ROOT/dist/gitb" ] || skip "bundle not built (run make build)"
    run bash "$GITBASHER_ROOT/dist/gitb" no-such-command
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown command"* ]]
}

@test "gitb bundle: help still exits zero" {
    [ -f "$GITBASHER_ROOT/dist/gitb" ] || skip "bundle not built (run make build)"
    run bash "$GITBASHER_ROOT/dist/gitb" help
    [ "$status" -eq 0 ]
}
