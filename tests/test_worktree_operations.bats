#!/usr/bin/env bats

# Tests for git worktree operations

load setup_suite

setup() {
    setup_test_repo
    source_gitbasher
    source "${GITBASHER_ROOT}/scripts/worktree.sh"
    cd "$TEST_REPO"

    # Ensure we have something committed
    make_test_commit "wt-base.txt" "Base for worktree tests"

    current_branch="main"
    main_branch="main"
    origin_name=""
    sep="-"
    ticket_name=""
}

teardown() {
    # git worktrees may live outside TEST_REPO; clean them up before nuking it
    if [ -n "$TEST_REPO" ] && [ -d "$TEST_REPO" ]; then
        cd "$TEST_REPO" 2>/dev/null && {
            git worktree list --porcelain 2>/dev/null \
                | awk '/^worktree /{print substr($0,10)}' \
                | while read -r path; do
                    if [ "$path" != "$TEST_REPO" ] && [ -d "$path" ]; then
                        rm -rf "$path"
                    fi
                done
            git worktree prune 2>/dev/null || true
        }
    fi
    cleanup_test_repo
}

# ===== list_worktrees_data =====

@test "list_worktrees_data: returns at least the main worktree" {
    run list_worktrees_data
    [ "$status" -eq 0 ]

    list_worktrees_data
    [ "${#worktrees_path[@]}" -ge 1 ]
    [ "${worktrees_path[0]}" = "$TEST_REPO" ]
}

@test "list_worktrees_data: detects an added worktree" {
    local extra="$(mktemp -d)/wt-feature"
    git worktree add -b feature/wt-test "$extra" >/dev/null 2>&1

    list_worktrees_data
    [ "${#worktrees_path[@]}" -eq 2 ]

    local found=""
    for index in "${!worktrees_path[@]}"; do
        if [ "${worktrees_path[$index]}" = "$extra" ]; then
            found="true"
            [[ "${worktrees_head[$index]}" == "feature/wt-test" ]]
        fi
    done
    [ "$found" = "true" ]

    rm -rf "$extra"
}

@test "list_worktrees_data: marks prunable worktrees" {
    local extra="$(mktemp -d)/wt-prune"
    git worktree add -b feature/prune-me "$extra" >/dev/null 2>&1
    rm -rf "$extra"

    list_worktrees_data

    local marked=""
    for line in "${worktrees_info[@]}"; do
        if [[ "$line" == *"prunable"* ]] && [[ "$line" == *"prune-me"* ]]; then
            marked="true"
        fi
    done
    [ "$marked" = "true" ]

    git worktree prune >/dev/null 2>&1 || true
}

# ===== default_worktree_path =====

@test "default_worktree_path: uses sibling directory by default" {
    local result
    result=$(default_worktree_path "feature/branch")
    local repo_dir
    repo_dir=$(basename "$TEST_REPO")
    local parent
    parent=$(dirname "$TEST_REPO")
    [ "$result" = "${parent}/${repo_dir}-feature-branch" ]
}

@test "default_worktree_path: respects gitbasher.worktreebase config" {
    git config --local gitbasher.worktreebase "/tmp/wt-custom"
    local result
    result=$(default_worktree_path "feat/x")
    [ "$result" = "/tmp/wt-custom/feat-x" ]
}

@test "default_worktree_path: replaces slashes in branch with dashes" {
    local result
    result=$(default_worktree_path "feature/nested/name")
    [[ "$result" == *"-feature-nested-name" ]]
}

# ===== git worktree integration =====

@test "git worktree add: creates a worktree with a new branch" {
    local target="$(mktemp -d)/wt-new"
    run git worktree add -b feature/wt-new "$target" HEAD
    [ "$status" -eq 0 ]
    [ -d "$target" ]
    [ -f "$target/wt-base.txt" ]

    rm -rf "$target"
    git worktree prune >/dev/null 2>&1 || true
}

@test "git worktree add: refuses to check out a branch already in use" {
    local target="$(mktemp -d)/wt-dup"
    run git worktree add "$target" main
    [ "$status" -ne 0 ]
    [[ "$output" == *"already used"* || "$output" == *"already checked out"* ]]
}

@test "git worktree remove: removes an added worktree" {
    local target="$(mktemp -d)/wt-rm"
    git worktree add -b feature/wt-rm "$target" HEAD >/dev/null 2>&1

    run git worktree remove "$target"
    [ "$status" -eq 0 ]
    [ ! -d "$target" ]
}

@test "git worktree remove: refuses dirty worktree without --force" {
    local target="$(mktemp -d)/wt-dirty"
    git worktree add -b feature/wt-dirty "$target" HEAD >/dev/null 2>&1
    echo "uncommitted" > "$target/dirty.txt"

    run git worktree remove "$target"
    [ "$status" -ne 0 ]

    git worktree remove --force "$target" >/dev/null 2>&1
}

@test "git worktree lock + unlock: round-trips" {
    local target="$(mktemp -d)/wt-lock"
    git worktree add -b feature/wt-lock "$target" HEAD >/dev/null 2>&1

    run git worktree lock "$target"
    [ "$status" -eq 0 ]

    run git worktree unlock "$target"
    [ "$status" -eq 0 ]

    git worktree remove "$target" >/dev/null 2>&1
}

@test "git worktree prune: cleans up admin entries for deleted dirs" {
    local target="$(mktemp -d)/wt-stale"
    git worktree add -b feature/wt-stale "$target" HEAD >/dev/null 2>&1
    rm -rf "$target"

    run git worktree prune --dry-run --verbose
    [ "$status" -eq 0 ]
    [[ "$output" == *"$target"* ]] || [[ "$output" == *"feature/wt-stale"* ]] || [ -n "$output" ]

    git worktree prune >/dev/null 2>&1
}

# ===== mode dispatch =====

@test "worktree_script: rejects unknown mode" {
    run worktree_script "definitely-not-a-mode"
    [ "$status" -ne 0 ] || [[ "$output" == *"Unknown mode"* ]]
}

@test "worktree_script: help mode prints usage" {
    run worktree_script "help"
    [ "$status" -eq 0 ]
    [[ "$output" == *"gitb worktree"* ]]
    [[ "$output" == *"prune"* ]]
    [[ "$output" == *"add"* ]]
}

@test "worktree_script: list mode prints worktrees" {
    local target="$(mktemp -d)/wt-list-mode"
    git worktree add -b feature/wt-list "$target" HEAD >/dev/null 2>&1

    run worktree_script "list"
    [ "$status" -eq 0 ]
    [[ "$output" == *"feature/wt-list"* ]]

    rm -rf "$target"
    git worktree prune >/dev/null 2>&1
}
