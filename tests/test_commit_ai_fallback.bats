#!/usr/bin/env bats

# When AI commit-message generation fails, the commit flow must not blindly
# abort: interactively it offers to continue with a manual message (staging
# preserved); on decline or EOF it keeps the old cleanup+exit behavior so
# non-interactive runs are unchanged.

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

with_timeout() {
    perl -e 'alarm 10; exec @ARGV' -- "$@"
}

# Child-shell script that sources the production chain, stubs a failing
# generator, and calls handle_ai_commit_generation directly. $1: extra
# statements injected before the call (e.g. auto_accept="true").
fallback_script() {
    printf '%s' "
        source '$GITBASHER_ROOT/scripts/common.sh' 2>/dev/null
        GITBASHER_SKIP_INIT_QUERIES=1 source '$GITBASHER_ROOT/scripts/init.sh' 2>/dev/null
        source '$GITBASHER_ROOT/scripts/ai.sh'
        source '$GITBASHER_ROOT/scripts/commit.sh'
        cd '$TEST_REPO'
        check_ai_available() { return 0; }
        detect_scopes_from_staged_files() { :; }
        generate_ai_commit_message() { return 1; }
        git_add='.'
        _gitb_prestaged=''
        ${1:-}
        handle_ai_commit_generation 2 simple ''
        echo AFTER_CALL
    "
}

@test "AI failure + y falls back to manual and keeps staging" {
    echo change > f.txt
    git add f.txt
    run with_timeout bash -c "$(fallback_script)" <<< "y"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Cannot generate AI commit message"* ]]
    [[ "$output" == *"Falling back to manual"* ]]
    [[ "$output" == *"AFTER_CALL"* ]]
    git diff --cached --name-only | grep -q "f.txt"
}

@test "AI failure + Enter counts as yes (benign prompt)" {
    echo change > f.txt
    git add f.txt
    run with_timeout bash -c "$(fallback_script)" <<< $'\n'
    [ "$status" -eq 0 ]
    [[ "$output" == *"Falling back to manual"* ]]
    git diff --cached --name-only | grep -q "f.txt"
}

@test "AI failure + n aborts non-zero and restores staging" {
    echo change > f.txt
    git add f.txt
    run with_timeout bash -c "$(fallback_script)" <<< "n"
    [ "$status" -eq 1 ]
    [[ "$output" != *"AFTER_CALL"* ]]
    [ -z "$(git diff --cached --name-only)" ]
}

@test "AI failure + EOF aborts non-zero without hanging" {
    echo change > f.txt
    git add f.txt
    run with_timeout bash -c "$(fallback_script)" < /dev/null
    # 142 = killed by the alarm = hang = regression
    [ "$status" -ne 142 ]
    [ "$status" -eq 1 ]
    [[ "$output" != *"AFTER_CALL"* ]]
    [ -z "$(git diff --cached --name-only)" ]
}

@test "ff mode: AI failure with closed stdin still aborts non-zero" {
    echo change > f.txt
    git add f.txt
    run with_timeout bash -c "$(fallback_script 'auto_accept="true"')" < /dev/null
    [ "$status" -ne 142 ]
    [ "$status" -eq 1 ]
    [ -z "$(git diff --cached --name-only)" ]
}

@test "commit flow continues into the manual type menu after fallback" {
    echo change > f.txt
    run with_timeout bash -c "
        source '$GITBASHER_ROOT/scripts/common.sh' 2>/dev/null
        GITBASHER_SKIP_INIT_QUERIES=1 source '$GITBASHER_ROOT/scripts/init.sh' 2>/dev/null
        source '$GITBASHER_ROOT/scripts/ai.sh'
        source '$GITBASHER_ROOT/scripts/commit.sh'
        cd '$TEST_REPO'
        current_branch=main; main_branch=main; origin_name=''
        check_ai_available() { return 0; }
        detect_scopes_from_staged_files() { :; }
        generate_ai_commit_message() { return 1; }
        commit_script ai fast
    " <<< "y0"
    [[ "$output" == *"Falling back to manual"* ]]
    # The Step-2 manual type menu must render after the fallback
    [[ "$output" == *"feat"* ]]
    [[ "$output" == *"fix"* ]]
}
