#!/usr/bin/env bats

# Data-safety regressions for the recovery flows: wip down must never
# destroy uncommitted work, wip stash discovery must not match another
# branch's save, and cherry-pick state detection must see single-commit
# conflicts.

load setup_suite

setup() {
    setup_test_repo
    source_gitbasher
    source "$GITBASHER_ROOT/scripts/wip.sh"
    source "$GITBASHER_ROOT/scripts/cherry.sh"
    cd "$TEST_REPO"

    current_branch="main"
    main_branch="main"
    origin_name=""
}

teardown() {
    cleanup_test_repo
}

@test "wip down worktree: failing pre-commit hook does not destroy the WIP" {
    # Save WIP into a worktree without pushing
    echo "precious work" > precious.txt
    run wip_up worktree nopush
    [ "$status" -eq 0 ]
    [ ! -f precious.txt ]

    # Leave NEW uncommitted work inside the wip worktree and install a hook
    # that rejects every commit (a lint hook failing on unfinished code)
    wt_path=$(git worktree list --porcelain | /usr/bin/awk '/^worktree /{p=$2} END{print p}')
    [ -d "$wt_path" ]
    echo "even more precious" > "$wt_path/pending.txt"
    hooks_dir=$(git rev-parse --git-path hooks)
    mkdir -p "$hooks_dir"
    printf '#!/bin/sh\nexit 1\n' > "$hooks_dir/pre-commit"
    chmod +x "$hooks_dir/pre-commit"

    run wip_down
    # Whatever the outcome reported, the pending file must still exist
    # (the old flow force-removed the worktree with the file in it)
    if [ -d "$wt_path" ]; then
        [ -f "$wt_path/pending.txt" ]
    else
        [ -f pending.txt ]
    fi
}

@test "find_wip_stash: does not match a prefix-sibling branch's stash" {
    git switch -qc dev-x
    echo x > wip-x.txt
    current_branch="dev-x"
    run wip_up stash nopush
    [ "$status" -eq 0 ]

    git switch -qc dev
    current_branch="dev"
    run find_wip_stash
    [ "$status" -ne 0 ]
}

@test "cherry_in_progress: detects a single-commit conflict (no sequencer dir)" {
    echo base > c.txt && git add c.txt && git commit -qm base
    git switch -qc side
    echo side > c.txt && git commit -qam side
    git switch -q main
    echo main > c.txt && git commit -qam main

    run git cherry-pick side
    [ "$status" -ne 0 ]
    run cherry_in_progress
    [ "$status" -eq 0 ]
    git cherry-pick --abort
    run cherry_in_progress
    [ "$status" -ne 0 ]
}
