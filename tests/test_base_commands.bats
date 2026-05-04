#!/usr/bin/env bats

# Tests for top-level command routing and help.

load setup_suite

setup() {
    setup_test_repo
}

teardown() {
    cleanup_test_repo
}

@test "top-level help does not advertise removed fixup command" {
    run bash "${GITBASHER_ROOT}/dist/gitb" help
    assert_success
    [[ "$output" != *"fixup_fx"* ]]
    [[ "$output" != *"gitb fixup"* ]]
    ! grep -q "fixup_fx" "${GITBASHER_ROOT}/scripts/base.sh"
    ! grep -q "source scripts/fixup.sh" "${GITBASHER_ROOT}/scripts/gitb.sh"
    ! grep -q "#gitb-fixup" "${GITBASHER_ROOT}/README.md"
}

@test "top-level help groups commands by intent and points to per-command help" {
    run bash "${GITBASHER_ROOT}/dist/gitb" help
    assert_success
    # Intent-based section headers
    [[ "$output" == *"DAILY"* ]]
    [[ "$output" == *"BRANCHES"* ]]
    [[ "$output" == *"HISTORY"* ]]
    [[ "$output" == *"RECOVERY"* ]]
    [[ "$output" == *"SETUP"* ]]
    # Each command listed with its inline aliases
    [[ "$output" == *"status (s)"* ]]
    [[ "$output" == *"commit (c, co, com)"* ]]
    [[ "$output" == *"branch (b, br, bran)"* ]]
    # Footer hint pointing at per-command help
    [[ "$output" == *"gitb <command> help"* ]]
}
