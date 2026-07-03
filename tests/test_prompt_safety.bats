#!/usr/bin/env bats

# EOF/closed-stdin safety for interactive prompts. Two contracts:
#   1. confirm_destructive: only an explicit "y" (or Russian-layout
#      equivalent) proceeds — Enter, EOF, Esc, and other keys decline.
#   2. yes_no_choice / menu loops: a failed read (EOF) aborts with a
#      non-zero status instead of auto-confirming or spinning at 100% CPU.

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

# Guard against regressions back into infinite read loops: run the given
# command with a hard alarm; a timeout turns into exit 142.
with_timeout() {
    perl -e 'alarm 5; exec @ARGV' -- "$@"
}

# ===== confirm_destructive =====

@test "confirm_destructive: explicit y confirms" {
    run confirm_destructive <<< "y"
    [ "$status" -eq 0 ]
}

@test "confirm_destructive: Russian-layout н confirms" {
    run confirm_destructive <<< "н"
    [ "$status" -eq 0 ]
}

@test "confirm_destructive: EOF declines" {
    run confirm_destructive < /dev/null
    [ "$status" -ne 0 ]
}

@test "confirm_destructive: Enter declines" {
    run confirm_destructive <<< ""
    [ "$status" -ne 0 ]
}

@test "confirm_destructive: n declines" {
    run confirm_destructive <<< "n"
    [ "$status" -ne 0 ]
}

@test "confirm_destructive: arbitrary key declines" {
    run confirm_destructive <<< "x"
    [ "$status" -ne 0 ]
}

# ===== yes_no_choice_strict decline semantics =====

@test "yes_no_choice_strict: explicit n is a graceful cancel (exit 0)" {
    run yes_no_choice_strict "confirmed" <<< "n"
    [ "$status" -eq 0 ]
    [[ "$output" != *"confirmed"* ]]
}

@test "yes_no_choice_strict: EOF aborts non-zero" {
    run yes_no_choice_strict "confirmed" < /dev/null
    [ "$status" -ne 0 ]
    [[ "$output" != *"confirmed"* ]]
}

@test "yes_no_choice_strict: explicit y proceeds" {
    run yes_no_choice_strict "confirmed" <<< "y"
    [ "$status" -eq 0 ]
    [[ "$output" == *"confirmed"* ]]
}

# ===== yes_no_choice =====

@test "yes_no_choice: EOF aborts non-zero instead of auto-confirming" {
    run yes_no_choice "confirmed" < /dev/null
    [ "$status" -ne 0 ]
    [[ "$output" != *"confirmed"* ]]
}

@test "yes_no_choice: y still confirms" {
    run yes_no_choice "confirmed" <<< "y"
    [ "$status" -eq 0 ]
    [[ "$output" == *"confirmed"* ]]
}

@test "yes_no_choice: Enter still confirms (benign prompts keep Enter-as-yes)" {
    run yes_no_choice "confirmed" <<< $'\n'
    [ "$status" -eq 0 ]
    [[ "$output" == *"confirmed"* ]]
}

# ===== choose =====

@test "choose: EOF aborts non-zero" {
    run choose "one" "two" "three" < /dev/null
    [ "$status" -ne 0 ]
}

@test "choose: mixed digit-equals input aborts cleanly (no arithmetic error)" {
    read_prefix=""
    run choose "one" "two" "three" "four" "five" "six" "seven" "eight" "nine" "ten" <<< $'5=\n'
    [[ "$output" != *"attempted assignment"* ]]
    [[ "$output" != *"syntax error"* ]]
}

# ===== destructive flows with closed stdin (the L2 matrix) =====

@test "tag delete-all: closed stdin does not delete tags" {
    source "$GITBASHER_ROOT/scripts/tag.sh"
    git tag v-keep-1
    git tag v-keep-2
    run with_timeout bash -c "
        source '$GITBASHER_ROOT/scripts/init.sh' 2>/dev/null
        source '$GITBASHER_ROOT/scripts/common.sh'
        source '$GITBASHER_ROOT/scripts/tag.sh'
        current_branch=main; main_branch=main; origin_name=''
        tag_script delete-all < /dev/null
    "
    [ "$status" -ne 0 ]
    git tag | grep -q "v-keep-1"
    git tag | grep -q "v-keep-2"
}

@test "stash drop: closed stdin does not drop the stash" {
    source "$GITBASHER_ROOT/scripts/stash.sh"
    echo change > stash-me.txt
    git add stash-me.txt
    git stash push -m "precious" -q
    run with_timeout bash -c "
        source '$GITBASHER_ROOT/scripts/init.sh' 2>/dev/null
        source '$GITBASHER_ROOT/scripts/common.sh'
        source '$GITBASHER_ROOT/scripts/stash.sh'
        current_branch=main; main_branch=main; origin_name=''
        printf '1' | stash_script drop
    "
    [ "$status" -ne 0 ]
    git stash list | grep -q "precious"
}

@test "undo commit: closed stdin does not move HEAD" {
    source "$GITBASHER_ROOT/scripts/undo.sh"
    echo x > u.txt && git add u.txt && git commit -qm "keep me"
    local_head_before=$(git rev-parse HEAD)
    run with_timeout bash -c "
        source '$GITBASHER_ROOT/scripts/init.sh' 2>/dev/null
        source '$GITBASHER_ROOT/scripts/common.sh'
        source '$GITBASHER_ROOT/scripts/undo.sh'
        current_branch=main; main_branch=main; origin_name=''
        undo_script commit < /dev/null
    "
    [ "$status" -ne 0 ]
    [ "$(git rev-parse HEAD)" = "$local_head_before" ]
}

# ===== hang-loop regressions =====

@test "config separator menu: EOF exits promptly instead of spinning" {
    source "$GITBASHER_ROOT/scripts/config.sh"
    run with_timeout bash -c "
        source '$GITBASHER_ROOT/scripts/init.sh' 2>/dev/null
        source '$GITBASHER_ROOT/scripts/common.sh'
        source '$GITBASHER_ROOT/scripts/config.sh'
        current_branch=main; main_branch=main; origin_name=''
        set_sep < /dev/null
    "
    # 142 = killed by the alarm = still spinning = regression
    [ "$status" -ne 142 ]
    [ "$status" -ne 0 ]
}
