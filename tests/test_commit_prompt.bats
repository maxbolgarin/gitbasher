#!/usr/bin/env bats

# Tests for commit prompt rendering helpers in commit.sh.

load setup_suite

setup() {
    setup_test_repo
    source_gitbasher
    source "${GITBASHER_ROOT}/scripts/commit.sh"
}

teardown() {
    cleanup_test_repo
}

@test "split type menu highlights scope, type labels, and plain option" {
    run print_split_type_menu "makefile"
    assert_success
    local blue endcolor bold yellow red
    blue=$(printf '%b' "$BLUE")
    endcolor=$(printf '%b' "$ENDCOLOR")
    bold=$(printf '%b' "$BOLD")
    yellow=$(printf '%b' "$YELLOW")
    red=$(printf '%b' "$RED")

    [[ "$output" == *"What type of changes for ${blue}makefile${endcolor}?"* ]]
    [[ "$output" == *"1. ${blue}${bold}feat${endcolor}"* ]]
    [[ "$output" == *"9. ${bold}plain${endcolor}"* ]]
    [[ "$output" == *"${yellow}${bold}skip${endcolor}"* ]]
    [[ "$output" == *"${red}${bold}abort${endcolor}"* ]]
}

@test "split groups keep non-ASCII staged paths addable" {
    mkdir -p docs scripts
    create_test_file "docs/Guide — Audit.md"
    create_test_file "scripts/change.sh"
    git add docs scripts

    build_split_groups_from_staged

    git restore --staged -- docs scripts
    local scope file
    for scope in "${split_group_keys[@]}"; do
        while IFS= read -r file; do
            [ -z "$file" ] && continue
            git add -- "$file"
        done <<< "${split_groups[$scope]}"
    done
}
