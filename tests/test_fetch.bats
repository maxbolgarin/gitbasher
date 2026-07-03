#!/usr/bin/env bats

# `gitb fetch` is a top-level fetch-without-merge command. It reuses the fetch()
# helper from pull.sh and commit_list from common.sh, and adds a `prune` mode
# (not exposed at top level elsewhere). These tests cover the pure prune-output
# parser plus the observable behavior of fetch_script against a real remote.

load setup_suite

setup() {
    setup_test_repo
    source_gitbasher
    source "$GITBASHER_ROOT/scripts/pull.sh"
    source "$GITBASHER_ROOT/scripts/fetch.sh"
    cd "$TEST_REPO"

    current_branch="main"
    main_branch="main"
    origin_name="origin"
}

teardown() {
    [ -n "$CLONE2" ] && [ -d "$CLONE2" ] && rm -rf "$CLONE2"
    cleanup_test_repo
    cleanup_remote_repo
}

# Push a commit to the remote from a throwaway second clone, so this repo's
# origin/* refs go stale until it fetches.
push_from_second_clone() {
    CLONE2=$(mktemp -d)
    git clone -q "$REMOTE_REPO" "$CLONE2"
    (
        cd "$CLONE2"
        git config user.email t@t
        git config user.name t
        git config commit.gpgsign false
        echo incoming > incoming.txt
        git add incoming.txt
        git commit -qm "Incoming commit from remote"
        git push -q origin main
    )
}

# ===== unit: prune-output parsing =====

@test "fetch: pruned_branch_names extracts deleted remote-tracking refs" {
    local out=" - [deleted]         (none)     -> origin/feature/gone
 - [deleted]         (none)     -> origin/old"

    run pruned_branch_names "$out"
    [ "${lines[0]}" = "origin/feature/gone" ]
    [ "${lines[1]}" = "origin/old" ]
}

@test "fetch: pruned_branch_names is empty when nothing was deleted" {
    local out="From /tmp/remote
 * [new branch]      main       -> origin/main"

    run pruned_branch_names "$out"
    [ -z "$output" ]
}

# ===== integration: current-branch fetch =====

@test "fetch: reports already up to date when nothing incoming" {
    setup_remote_repo

    run fetch_script
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Already up to date" ]]
}

@test "fetch: reports incoming commits when remote is ahead" {
    setup_remote_repo
    push_from_second_clone

    run fetch_script
    [ "$status" -eq 0 ]
    [[ "$output" =~ "behind" ]]
    [[ "$output" =~ "Incoming commit from remote" ]]
}

@test "fetch: does not echo git's raw transfer summary on success" {
    setup_remote_repo
    push_from_second_clone

    # The flow prints its own structured summary; git's "From <url> ..
    # main -> origin/main" block is noise and must stay captured-only.
    run fetch_script
    [ "$status" -eq 0 ]
    [[ ! "$output" =~ "From " ]]
    [[ ! "$output" =~ "-> origin/main" ]]
}

# ===== integration: prune =====

@test "fetch prune: reports a branch deleted on the remote" {
    setup_remote_repo

    git checkout -q -b feature/gone
    make_test_commit "gone.txt" "work on feature"
    git push -q -u origin feature/gone
    git checkout -q main

    # Delete the branch on the remote via a second clone so our origin/* ref
    # stays stale until we prune.
    CLONE2=$(mktemp -d)
    git clone -q "$REMOTE_REPO" "$CLONE2"
    ( cd "$CLONE2" && git push -q origin --delete feature/gone )

    run fetch_script prune
    [ "$status" -eq 0 ]
    [[ "$output" =~ "feature/gone" ]]
}

# ===== integration: no remote configured =====

@test "fetch: errors clearly when no remote is configured" {
    origin_name=""

    run fetch_script
    [ "$status" -ne 0 ]
    [[ "$output" =~ "No git remote configured" ]]
}
