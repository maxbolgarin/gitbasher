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

@test "regular type menu uses split menu styling" {
    run print_commit_type_menu "2"
    assert_success
    local blue endcolor bold yellow red
    blue=$(printf '%b' "$BLUE")
    endcolor=$(printf '%b' "$ENDCOLOR")
    bold=$(printf '%b' "$BOLD")
    yellow=$(printf '%b' "$YELLOW")
    red=$(printf '%b' "$RED")

    [[ "$output" == *"${yellow}Step 2.${endcolor} What ${yellow}type${endcolor} of changes do you want to commit?"* ]]
    [[ "$output" == *"Final message will be ${yellow}<type>${endcolor}(${blue}<scope>${endcolor}): ${blue}<summary>${endcolor}"* ]]
    [[ "$output" == *"1. ${blue}${bold}feat${endcolor}"* ]]
    [[ "$output" == *"9. ${bold}plain${endcolor}"* ]]
    [[ "$output" == *"${red}${bold}exit${endcolor}"* ]]
}

@test "declining saved commit message leaves one blank line before type menu" {
    create_test_file "change.txt" "changed"
    git add change.txt
    git config gitbasher.cached-commit-message "refactor: cached subject"

    run commit_script staged <<< "n0"

    assert_success
    local use_prompt before_type
    yellow=$(printf '%b' "$YELLOW")
    use_prompt="Use it? (y/e to edit/n) "
    before_type="${output#*"$use_prompt"}"
    [[ "$before_type" != "$output" ]]
    before_type="${before_type%%What ${yellow}type*}"
    [[ "$before_type" == $'\n\n'* ]]
    [[ "$before_type" != $'\n\n\n'* ]]
}

@test "declining split AI suggestion goes directly to type menu on next line" {
    create_test_file "gitb" "changed"
    git add gitb
    declare -gA split_groups=([gitb]="gitb")
    split_group_keys=(gitb)
    current_branch="main"
    push=""
    llm="true"
    auto_accept=""

    check_ai_available() { return 0; }
    generate_ai_commit_message() { printf 'build(gitb): generated subject'; }

    run perform_commit_split <<< "n0"

    assert_success
    local use_prompt before_type yellow
    yellow=$(printf '%b' "$YELLOW")
    use_prompt="Use it? (y/e to edit/r to regenerate/s to skip group/0 to abort) "
    before_type="${output#*"$use_prompt"}"
    [[ "$before_type" != "$output" ]]
    before_type="${before_type%%What ${yellow}type*}"
    [[ "$before_type" == $'\n'* ]]
    [[ "$before_type" != $'\n\n'* ]]
}

@test "normal type menu abort prints aborted message" {
    create_test_file "change.txt" "changed"
    git add change.txt

    run commit_script staged <<< "0"

    assert_success
    [[ "$output" == *"Aborted."* ]]
}

@test "no-split modifier skips split offer in fast mode" {
    create_test_file "docs.md" "docs"
    mkdir -p scripts
    create_test_file "scripts/change.sh" "script"

    try_offer_commit_split() {
        echo "split-offer-called"
        return 1
    }

    run commit_script fast no-split <<< "0"

    assert_success
    [[ "$output" != *"split-offer-called"* ]]
    [[ "$output" == *"Aborted."* ]]
}

@test "no-split short aliases are accepted" {
    no_split=""
    set_commit_flag_from_token nsp
    [ "$no_split" = "true" ]

    no_split=""
    set_commit_flag_from_token nsl
    [ "$no_split" = "true" ]
}

@test "commit help separates actions from modifiers" {
    run commit_script help

    assert_success
    [[ "$output" == *"Actions"* ]]
    [[ "$output" == *"Modifiers"* ]]
    local before_modifiers actions_section modifiers_section
    before_modifiers="${output%%Modifiers*}"
    [[ "$before_modifiers" == *"Actions"* ]]

    actions_section="${output#*Actions}"
    actions_section="${actions_section%%Modifiers*}"
    [[ "$actions_section" == *"split"* ]]
    [[ "$actions_section" == *"fixup"* ]]
    [[ "$actions_section" != *"no-split"* ]]

    modifiers_section="${output#*Modifiers}"
    modifiers_section="${modifiers_section%%Examples*}"
    [[ "$modifiers_section" == *"no-split"* ]]
    [[ "$modifiers_section" == *"push"* ]]
    [[ "$modifiers_section" == *"scope"* ]]
}

@test "split group preview colors scopes and files by staged status" {
    mkdir -p docs scripts
    create_test_file "scripts/change.sh" "old"
    create_test_file "old.txt" "old"
    git add scripts/change.sh old.txt
    git commit -m "test: prepare tracked files"

    create_test_file "docs/new.md" "new"
    create_test_file "scripts/change.sh" "modified"
    git rm old.txt >/dev/null
    git add docs/new.md scripts/change.sh

    declare -gA split_groups=(
        [docs]="docs/new.md"
        [scripts]="scripts/change.sh"
        [misc]="old.txt"
    )
    split_group_keys=(docs scripts misc)

    run print_split_groups_preview

    assert_success
    local blue bold endcolor green yellow red
    blue=$(printf '%b' "$BLUE")
    bold=$(printf '%b' "$BOLD")
    endcolor=$(printf '%b' "$ENDCOLOR")
    green=$(printf '%b' "$GREEN")
    yellow=$(printf '%b' "$YELLOW")
    red=$(printf '%b' "$RED")

    [[ "$output" == *"${blue}${bold}docs${endcolor}"* ]]
    [[ "$output" == *"${green}docs/new.md${endcolor}"* ]]
    [[ "$output" == *"${yellow}scripts/change.sh${endcolor}"* ]]
    [[ "$output" == *"${red}old.txt${endcolor}"* ]]
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

@test "split summary lists commit hashes with commit headers" {
    mkdir -p docs scripts
    create_test_file "docs/guide.md"
    create_test_file "scripts/change.sh"
    git add docs scripts

    declare -gA split_groups=(
        [docs]="docs/guide.md"
        [scripts]="scripts/change.sh"
    )
    split_group_keys=(docs scripts)
    current_branch="main"
    push=""
    llm=""
    auto_accept=""

    run perform_commit_split <<< "$(printf '8update docs\n7update scripts\n')"

    assert_success
    [[ "$output" == *"Created 2 atomic commit(s) on main:"* ]]
    local blue endcolor hash subject
    blue=$(printf '%b' "$BLUE")
    endcolor=$(printf '%b' "$ENDCOLOR")
    while IFS=' ' read -r hash subject; do
        [[ "$output" == *"  ${blue}${hash}${endcolor} ${subject}"* ]]
    done < <(git log -2 --reverse --format='%h %s')
}
