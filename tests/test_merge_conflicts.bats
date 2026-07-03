#!/usr/bin/env bats

# Conflict-resolution flows: the documented "resolve the content, then
# press 1" path must succeed without a manual `git add`, multi-file
# conflicts must not shift positional args, and aborting a pull-commits
# run must restore the exact pre-pull HEAD (not a commit-count guess).

load setup_suite

setup() {
    setup_test_repo
    source_gitbasher
    source "$GITBASHER_ROOT/scripts/pull.sh"
    source "$GITBASHER_ROOT/scripts/merge.sh"
    source "$GITBASHER_ROOT/scripts/rebase.sh"
    source "$GITBASHER_ROOT/scripts/push.sh"
    cd "$TEST_REPO"

    current_branch="main"
    main_branch="main"
    origin_name=""
    editor="true"
}

teardown() {
    cleanup_test_repo
}

# Build a two-file conflict between main and branch "feature"
make_conflict() {
    printf 'base\n' > alpha.txt
    printf 'base\n' > beta.txt
    git add alpha.txt beta.txt
    git commit -qm "base files"
    git switch -qc feature
    printf 'feature\n' > alpha.txt
    printf 'feature\n' > beta.txt
    git commit -qam "feature change"
    git switch -q main
    printf 'main\n' > alpha.txt
    printf 'main\n' > beta.txt
    git commit -qam "main change"
}

@test "resolve_conflicts: resolving content then pressing 1 commits (no manual git add)" {
    make_conflict
    git merge feature >/dev/null 2>&1 || true
    [ -f "$(git rev-parse --git-dir)/MERGE_HEAD" ]

    # Resolve BOTH files by content only — the flow must stage them itself
    printf 'resolved\n' > alpha.txt
    printf 'resolved\n' > beta.txt

    run bash -c "
        cd '$TEST_REPO'
        source '$GITBASHER_ROOT/scripts/common.sh' 2>/dev/null
        GITBASHER_SKIP_INIT_QUERIES=1 source '$GITBASHER_ROOT/scripts/init.sh' 2>/dev/null
        source '$GITBASHER_ROOT/scripts/merge.sh'
        current_branch=main; main_branch=main; origin_name=''
        printf '1' | resolve_conflicts feature '' true
    "
    [ ! -f "$(git rev-parse --git-dir)/MERGE_HEAD" ]
    # The default message names the LOCAL branch (no bogus origin prefix),
    # not a conflicted file name (the old array splat shifted args)
    subject=$(git log -1 --pretty=%s)
    [[ "$subject" == "Merge branch 'feature' into 'main'" ]]
}

@test "resolve_conflicts: unresolved markers keep the merge open" {
    make_conflict
    git merge feature >/dev/null 2>&1 || true

    # Leave beta.txt with markers; resolve only alpha.txt
    printf 'resolved\n' > alpha.txt

    run bash -c "
        cd '$TEST_REPO'
        source '$GITBASHER_ROOT/scripts/common.sh' 2>/dev/null
        GITBASHER_SKIP_INIT_QUERIES=1 source '$GITBASHER_ROOT/scripts/init.sh' 2>/dev/null
        source '$GITBASHER_ROOT/scripts/merge.sh'
        current_branch=main; main_branch=main; origin_name=''
        printf '10' | resolve_conflicts feature '' true
    "
    [[ "$output" == *"files with conflicts"* ]]
    [[ "$output" == *"beta.txt"* ]]
    [ -f "$(git rev-parse --git-dir)/MERGE_HEAD" ]
}

@test "pull-commits abort: HEAD returns to the exact pre-pull commit" {
    # main gets an IMPORTANT commit; source has an empty commit (skipped)
    # then a conflicting one — the old HEAD~N math rewound past the
    # important commit and destroyed it.
    printf 'base\n' > f.txt
    git add f.txt && git commit -qm "base"
    git switch -qc source
    git commit --allow-empty -qm "empty commit"
    printf 'source\n' > f.txt
    git commit -qam "conflicting change"
    git switch -q main
    printf 'main\n' > f.txt
    git commit -qam "M2 important main commit"
    start_hash=$(git rev-parse HEAD)

    run bash -c "
        cd '$TEST_REPO'
        source '$GITBASHER_ROOT/scripts/common.sh' 2>/dev/null
        GITBASHER_SKIP_INIT_QUERIES=1 source '$GITBASHER_ROOT/scripts/init.sh' 2>/dev/null
        source '$GITBASHER_ROOT/scripts/pull.sh'
        source '$GITBASHER_ROOT/scripts/merge.sh'
        source '$GITBASHER_ROOT/scripts/rebase.sh'
        current_branch=main; main_branch=main; origin_name=''; editor=true
        # picker: choose branch 1 (source); then conflict menu: 5=abort, y=confirm
        printf '15y' | rebase_script pull
    "
    [ "$(git rev-parse HEAD)" = "$start_hash" ]
    git log --oneline | /usr/bin/grep -q "M2 important main commit"
}
