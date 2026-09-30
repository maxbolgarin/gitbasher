#!/usr/bin/env bats

# `gitb cfg fast-split` toggles gitbasher.commit-fast-split, which decides
# whether fast commit modes (fast, ff, ...) split without asking.

load setup_suite

setup() {
    setup_test_repo
    cd "$TEST_REPO"
}

teardown() {
    cleanup_test_repo
}

fast_split_script() {
    printf '%s' "
        export GIT_CONFIG_GLOBAL='$BATS_TEST_TMPDIR/gitconfig-global'
        source '$GITBASHER_ROOT/scripts/common.sh' 2>/dev/null
        GITBASHER_SKIP_INIT_QUERIES=1 source '$GITBASHER_ROOT/scripts/init.sh' 2>/dev/null
        source '$GITBASHER_ROOT/scripts/config.sh'
        cd '$TEST_REPO'
        project_name=test
        $1
    "
}

@test "get_fast_split: defaults to true and normalizes unknown values" {
    run perl -e 'alarm 10; exec @ARGV' -- bash -c "$(fast_split_script 'get_fast_split
        git config gitbasher.commit-fast-split false; get_fast_split
        git config gitbasher.commit-fast-split junk; get_fast_split')"
    assert_success
    [ "$output" = $'true\nfalse\ntrue' ]
}

@test "cfg fast-split: choice 2 turns it off locally, n skips global" {
    run perl -e 'alarm 10; exec @ARGV' -- bash -c "$(fast_split_script 'configure_fast_split')" <<< "2n"
    [[ "$output" == *"Set fast mode split to off"* ]]
    [ "$(git config --local --get gitbasher.commit-fast-split)" = "false" ]
    [ -z "$(git config --file "$BATS_TEST_TMPDIR/gitconfig-global" --get gitbasher.commit-fast-split)" ]
}

@test "cfg fast-split: y moves the value to global config" {
    run perl -e 'alarm 10; exec @ARGV' -- bash -c "$(fast_split_script 'configure_fast_split')" <<< "2y"
    [ "$(git config --file "$BATS_TEST_TMPDIR/gitconfig-global" --get gitbasher.commit-fast-split)" = "false" ]
    [ -z "$(git config --local --get gitbasher.commit-fast-split)" ]
}

@test "cfg fast-split: 0 exits without changes" {
    run perl -e 'alarm 10; exec @ARGV' -- bash -c "$(fast_split_script 'configure_fast_split')" <<< "0"
    [ -z "$(git config --local --get gitbasher.commit-fast-split)" ]
}
