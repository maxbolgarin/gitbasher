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
