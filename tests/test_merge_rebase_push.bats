#!/usr/bin/env bats

# Tests for the `push` modifier on merge and rebase.
#   gitb merge <mode> push  -> merge, then normal push  (push_script y)
#   gitb rebase <mode> push -> rebase, then force-push   (push_script f)
#
# base.sh forwards "${@:2}" so the trailing `push` token reaches the handler,
# and merge_script/rebase_script parse all tokens order-independently.

load setup_suite

setup() {
    setup_test_repo
    source_gitbasher
    source "${GITBASHER_ROOT}/scripts/merge.sh"
    source "${GITBASHER_ROOT}/scripts/rebase.sh"
    source "${GITBASHER_ROOT}/scripts/pull.sh"
    source "${GITBASHER_ROOT}/scripts/push.sh"
    setup_remote_repo

    # init.sh resolved these before the remote existed; re-seed them.
    current_branch="main"
    main_branch="main"
    origin_name="origin"
    editor="vi"
}

teardown() {
    cleanup_remote_repo
    cleanup_test_repo
}

# --- parsing / dispatch -----------------------------------------------------

@test "merge rejects an unknown trailing token" {
    run merge_script tm bogus
    [[ "$output" == *"Unknown mode"* ]]
    [[ "$output" == *"bogus"* ]]
}

@test "rebase rejects an unknown trailing token" {
    run rebase_script main bogus
    [[ "$output" == *"Unknown mode"* ]]
    [[ "$output" == *"bogus"* ]]
}

@test "merge help documents the push modifier" {
    run merge_script help
    [ "$status" -eq 0 ]
    [[ "$output" == *"gitb merge tm push"* ]]
}

@test "rebase help documents the push modifier" {
    run rebase_script help
    [ "$status" -eq 0 ]
    [[ "$output" == *"gitb rebase main push"* ]]
}

# --- merge integration ------------------------------------------------------

@test "merge tm push merges into main and pushes it" {
    git checkout -b feature >/dev/null 2>&1
    create_test_file "feature.txt" "feature work"
    git add feature.txt
    git commit -m "feat: feature work" >/dev/null
    current_branch="feature"

    run merge_script tm push

    [ "$status" -eq 0 ]
    [[ "$output" == *"GIT MERGE TO MAIN & PUSH"* ]]
    [[ "$output" == *"Pushed to origin/main"* ]]
}

# --- rebase integration -----------------------------------------------------

@test "rebase main push rebases then force-pushes the branch" {
    # feature is on the remote, then main advances (also pushed) so the two
    # remote-change checks stay quiet and the only prompt is the force-push.
    git checkout -b feature >/dev/null 2>&1
    create_test_file "f1.txt" "feature commit"
    git add f1.txt
    git commit -m "feat: feature commit" >/dev/null
    git push -u origin feature >/dev/null 2>&1

    git checkout main >/dev/null 2>&1
    create_test_file "m1.txt" "main commit"
    git add m1.txt
    git commit -m "feat: main commit" >/dev/null
    git push origin main >/dev/null 2>&1

    git checkout feature >/dev/null 2>&1
    current_branch="feature"

    run rebase_script main push <<< "y"

    [ "$status" -eq 0 ]
    [[ "$output" == *"GIT REBASE MAIN & PUSH"* ]]
    [[ "$output" == *"Pushed to origin/feature"* ]]
}
