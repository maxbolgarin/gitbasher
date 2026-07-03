#!/usr/bin/env bats

# Split-flow index plumbing: staging/unstaging by name must treat names as
# literal repo-root-relative paths (glob metacharacters like Next.js's
# app/[id]/page.tsx must not match siblings; running from a subdirectory
# must not break restaging), and the token parsers must agree.

load setup_suite

setup() {
    setup_test_repo
    source_gitbasher
    source "$GITBASHER_ROOT/scripts/ai.sh"
    source "$GITBASHER_ROOT/scripts/commit.sh"
    cd "$TEST_REPO"

    current_branch="main"
    main_branch="main"
    origin_name=""
}

teardown() {
    cleanup_test_repo
}

@test "_stage_file_by_status: glob-metachar filename stages only itself" {
    mkdir -p "app/[id]" "app/i"
    echo a > "app/[id]/page.tsx"
    echo b > "app/i/page.tsx"

    _stage_file_by_status "app/[id]/page.tsx" "M"

    staged=$(git diff --name-only --cached)
    [[ "$staged" == *"app/[id]/page.tsx"* ]]
    if [[ "$staged" == *"app/i/page.tsx"* ]]; then
        echo "glob expansion staged the sibling file" >&2
        return 1
    fi
}

@test "_stage_file_by_status: works from a repo subdirectory" {
    mkdir -p docs sub
    echo x > docs/a.md
    cd sub
    _stage_file_by_status "docs/a.md" "M"
    cd ..
    staged=$(git diff --name-only --cached)
    [[ "$staged" == *"docs/a.md"* ]]
}

@test "_restore_split_snapshot: restores staging from a subdirectory" {
    mkdir -p docs sub
    echo x > docs/a.md
    git add docs/a.md
    snapshot=$(mktemp)
    printf 'M\tdocs/a.md\n' > "$snapshot"
    git restore --staged docs/a.md

    cd sub
    _restore_split_snapshot "$snapshot"
    cd ..
    rm -f "$snapshot"

    staged=$(git diff --name-only --cached)
    [[ "$staged" == *"docs/a.md"* ]]
}

@test "split flow: staged rename appears as independent delete + add" {
    echo content > old-name.md
    git add old-name.md
    git commit -qm "add old-name"
    git mv old-name.md new-name.md

    files=$(git -c core.quotePath=false diff --no-renames --name-only --cached)
    [[ "$files" == *"old-name.md"* ]]
    [[ "$files" == *"new-name.md"* ]]
}

# ===== token parser parity =====

@test "set_commit_flag_from_token: accepts st as staged alias" {
    set_commit_flag_from_token "st"
    [ "$staged" = "true" ]
}

@test "set_commit_flag_from_token: accepts ff (ultrafast) in multi-token form" {
    set_commit_flag_from_token "ff"
    [ "$fast" = "true" ]
    [ "$llm" = "true" ]
    [ "$auto_accept" = "true" ]
}

@test "set_commit_flag_from_token: accepts sff in multi-token form" {
    set_commit_flag_from_token "sff"
    [ "$staged" = "true" ]
    [ "$auto_accept" = "true" ]
}

@test "validate_commit_flag_combo: rejects split with msg" {
    split="true"
    msg="true"
    run validate_commit_flag_combo
    [ "$status" -ne 0 ]
    [[ "$output" == *"split"* ]]
}

@test "commit_script: 'last push' is rejected instead of dropping push" {
    run commit_script last push
    [ "$status" -ne 0 ]
}
