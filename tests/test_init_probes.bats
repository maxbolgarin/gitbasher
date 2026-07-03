#!/usr/bin/env bats

# init.sh environment probes: the configured default branch must win over
# the main/master auto-detection, "origin" must be preferred over
# alphabetically-earlier remotes, and config values must round-trip
# without backslash mangling.

load setup_suite

setup() {
    setup_test_repo
    cd "$TEST_REPO"
}

teardown() {
    cleanup_test_repo
}

# Re-run the init probes in the current repo state and echo a probe result.
run_init_probe() {
    bash -c "
        cd '$TEST_REPO'
        source '$GITBASHER_ROOT/scripts/common.sh' 2>/dev/null
        GITBASHER_TEST_MODE=1
        source '$GITBASHER_ROOT/scripts/init.sh' 2>/dev/null
        echo \"main_branch=\$main_branch\"
        echo \"origin_name=\$origin_name\"
    "
}

@test "main_branch: configured gitbasher.branch wins over master fallback" {
    # Classic gitflow: master + develop exist, no branch named main
    git branch -m master
    git switch -qc develop
    git config gitbasher.branch develop

    run run_init_probe
    [[ "$output" == *"main_branch=develop"* ]]
}

@test "main_branch: unset config falls back to master when main is absent" {
    git branch -m master
    git config --unset gitbasher.branch 2>/dev/null || true

    run run_init_probe
    [[ "$output" == *"main_branch=master"* ]]
}

@test "main_branch: unset config keeps main when it exists" {
    run run_init_probe
    [[ "$output" == *"main_branch=main"* ]]
}

@test "origin_name: prefers origin over alphabetically-earlier remotes" {
    git remote add backup /tmp/nonexistent-backup.git
    git remote add origin /tmp/nonexistent-origin.git

    run run_init_probe
    [[ "$output" == *"origin_name=origin"* ]]
}

@test "origin_name: single non-origin remote is used as-is" {
    git remote add upstream /tmp/nonexistent-upstream.git

    run run_init_probe
    [[ "$output" == *"origin_name=upstream"* ]]
}

@test "get_config_value: does not interpret backslash escapes" {
    source_gitbasher_lite
    git config gitbasher.ticket 'a\nb'
    result=$(get_config_value gitbasher.ticket "")
    [ "$result" = 'a\nb' ]
}

@test "no-repo guard: repo commands refuse to run outside a repository" {
    [ -f "$GITBASHER_ROOT/dist/gitb" ] || skip "bundle not built (run make build)"
    NONREPO=$(mktemp -d)
    run bash -c "cd '$NONREPO' && bash '$GITBASHER_ROOT/dist/gitb' status"
    rm -rf "$NONREPO"
    [ "$status" -ne 0 ]
    [[ "$output" == *"only in a git repository"* ]]
}

@test "no-repo guard: help still works outside a repository" {
    [ -f "$GITBASHER_ROOT/dist/gitb" ] || skip "bundle not built (run make build)"
    NONREPO=$(mktemp -d)
    run bash -c "cd '$NONREPO' && bash '$GITBASHER_ROOT/dist/gitb' help"
    rm -rf "$NONREPO"
    [ "$status" -eq 0 ]
    [[ "$output" == *"usage:"* ]]
}
