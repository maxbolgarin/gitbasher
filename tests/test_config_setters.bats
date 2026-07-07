#!/usr/bin/env bats

# Tests for the config helpers in scripts/init.sh:
#   get_config_value, set_config_value, unset_config_value
#
# These are the only sanctioned entry points for touching gitbasher.* keys
# (CLAUDE.md says so). They sit underneath every per-feature config flow,
# so a regression here breaks every command that reads or writes config.
#
# We isolate global config by pointing GIT_CONFIG_GLOBAL at a temp file —
# never the user's real ~/.gitconfig — and clean up on teardown.

load setup_suite

setup() {
    setup_test_repo

    GLOBAL_CONFIG=$(mktemp)
    export GIT_CONFIG_GLOBAL="$GLOBAL_CONFIG"

    source_gitbasher_lite
    cd "$TEST_REPO"
}

teardown() {
    [ -n "$GLOBAL_CONFIG" ] && rm -f "$GLOBAL_CONFIG"
    cleanup_test_repo
}

# ===== get_config_value =====

@test "get_config_value: returns the local value when set" {
    git config --local gitbasher.testkey "local-val"
    [ "$(get_config_value gitbasher.testkey)" = "local-val" ]
}

@test "get_config_value: falls back to global when local is unset" {
    git config --file="$GLOBAL_CONFIG" gitbasher.testkey "global-val"
    [ "$(get_config_value gitbasher.testkey)" = "global-val" ]
}

@test "get_config_value: prefers local over global when both set" {
    git config --file="$GLOBAL_CONFIG" gitbasher.testkey "global-val"
    git config --local gitbasher.testkey "local-val"
    [ "$(get_config_value gitbasher.testkey)" = "local-val" ]
}

@test "get_config_value: returns default when neither local nor global is set" {
    [ "$(get_config_value gitbasher.absent default-val)" = "default-val" ]
}

@test "get_config_value: returns empty when no default and key absent" {
    result=$(get_config_value gitbasher.absent)
    [ -z "$result" ]
}

# ===== set_config_value =====

@test "set_config_value: writes to local config when third arg is empty" {
    set_config_value gitbasher.localwrite "value-x" "" >/dev/null
    [ "$(git config --local --get gitbasher.localwrite)" = "value-x" ]
    [ -z "$(git config --file="$GLOBAL_CONFIG" --get gitbasher.localwrite 2>/dev/null)" ]
}

@test "set_config_value: writes to global config when third arg is non-empty" {
    set_config_value gitbasher.globalwrite "value-y" "true" >/dev/null
    [ "$(git config --file="$GLOBAL_CONFIG" --get gitbasher.globalwrite)" = "value-y" ]
    [ -z "$(git config --local --get gitbasher.globalwrite 2>/dev/null)" ]
}

@test "set_config_value: echoes the written value" {
    output=$(set_config_value gitbasher.echoback "echoed" "")
    [[ "$output" == *"echoed"* ]]
}

@test "set_config_value: overwrites an existing value" {
    git config --local gitbasher.overwrite "old"
    set_config_value gitbasher.overwrite "new" "" >/dev/null
    [ "$(git config --local --get gitbasher.overwrite)" = "new" ]
}

@test "set_config_value: handles values with spaces" {
    set_config_value gitbasher.withspaces "value with spaces" "" >/dev/null
    [ "$(git config --local --get gitbasher.withspaces)" = "value with spaces" ]
}

# ===== unset_config_value =====

@test "unset_config_value: removes the local key" {
    git config --local gitbasher.toremove "doomed"
    # No global value, so the interactive prompt branch is skipped.
    unset_config_value gitbasher.toremove >/dev/null 2>&1
    run git config --local --get gitbasher.toremove
    [ "$status" -ne 0 ]
}

# ===== round trip =====

@test "round-trip: set then get returns the same value" {
    set_config_value gitbasher.roundtrip "rt-val" "" >/dev/null
    [ "$(get_config_value gitbasher.roundtrip)" = "rt-val" ]
}

@test "round-trip: set local, then global - the global write is promoted" {
    # A later global write replaces the local copy (see "clears the local
    # shadow" below); a raw `git config --local` write afterwards still wins,
    # which is git's normal precedence for values set outside gitbasher.
    set_config_value gitbasher.precedence "local-first" "" >/dev/null
    set_config_value gitbasher.precedence "global-now" "true" >/dev/null
    [ "$(get_config_value gitbasher.precedence)" = "global-now" ]
    git config --local gitbasher.precedence "manual-local"
    [ "$(get_config_value gitbasher.precedence)" = "manual-local" ]
}

@test "set_config_value: global write clears the local shadow" {
    # "Set globally for all projects" must leave ONE copy — the global one.
    # Keeping the earlier local write would shadow the global forever: the
    # config summary keeps saying "(project)" and later global changes
    # silently don't apply to this repo (the user-reported confusion).
    set_config_value gitbasher.promote "local-first" "" >/dev/null
    set_config_value gitbasher.promote "now-global" "true" >/dev/null
    [ -z "$(git config --local --get gitbasher.promote)" ]
    [ "$(git config --global --get gitbasher.promote)" = "now-global" ]
    [ "$(get_config_value gitbasher.promote)" = "now-global" ]
}
