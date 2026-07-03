#!/usr/bin/env bats

# Tests for top-level command routing and help.

load setup_suite

setup() {
    setup_test_repo
    # A fresh clone has no dist/gitb (it is gitignored and built at release
    # time) — build it here so `make test` works without a prior make build.
    if [ ! -f "${GITBASHER_ROOT}/dist/gitb" ]; then
        (cd "${GITBASHER_ROOT}" && bash dist/build.sh ./scripts/gitb.sh ./dist/gitb dev >/dev/null 2>&1)
    fi
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

@test "main help renders embedded colors instead of literal escape text" {
    # The edit row embeds ${GREEN}...${ENDCOLOR} in its description; with a
    # %s description column the color variables printed as literal \033[32m
    # text in interactive terminals (invisible in piped tests, where colors
    # are blank). Force TTY-style color values and assert real escapes.
    run bash -c "
        source '${GITBASHER_ROOT}/scripts/common.sh' 2>/dev/null
        GITBASHER_SKIP_INIT_QUERIES=1 source '${GITBASHER_ROOT}/scripts/init.sh' 2>/dev/null
        GREEN='\\033[32m'; ENDCOLOR='\\033[0m'; YELLOW='\\033[33m'; BOLD='\\033[1m'; NORMAL='\\033[0m'
        main_branch=main; current_branch=main; origin_name=origin
        set --
        source '${GITBASHER_ROOT}/scripts/base.sh'
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"edit (ed, ee)"* ]]
    [[ "$output" != *'\033'* ]]
    printf '%s' "$output" | grep -q "$(printf '\033')\[32m"
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
