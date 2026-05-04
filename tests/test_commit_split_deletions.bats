#!/usr/bin/env bats

# Regression: `gitb commit split` (and the AI auto-accept variants like `ffp`)
# would lose staged deletions when one scope group contained only deleted
# files. Repro: `git rm --cached <path>` plus a per-scope split. The original
# code re-staged each scope with plain `git add <file>`, which on a deleted
# file whose worktree copy still exists silently re-adds the worktree blob.
# That left zero staged changes for the deletion-only scope and the AI
# message generator failed with "No staged files found".
#
# These tests exercise the helpers directly because the full split flow
# requires a configured AI provider.

load setup_suite

setup() {
    setup_test_repo
    source_gitbasher
    source "${GITBASHER_ROOT}/scripts/ai.sh"
    source "${GITBASHER_ROOT}/scripts/commit.sh"
    cd "$TEST_REPO"

    # Seed three files in HEAD so we have a meaningful index state to mutate.
    mkdir -p mod del .github
    echo "modify-me" > mod/a.txt
    echo "delete-me" > del/b.txt
    echo "untouched" > .github/c.txt
    git add .
    git commit -q -m "seed"

    # Stage three different change types: M, D, A.
    echo "modified-content" > mod/a.txt
    git add mod/a.txt
    git rm --cached del/b.txt >/dev/null   # D — worktree file remains
    echo "new-file" > .github/d.txt
    git add .github/d.txt
}

teardown() {
    cleanup_test_repo
}

@test "_capture_split_statuses: maps each staged file to its change type" {
    _capture_split_statuses
    [ "${_split_status_by_file[mod/a.txt]}" = "M" ]
    [ "${_split_status_by_file[del/b.txt]}" = "D" ]
    [ "${_split_status_by_file[.github/d.txt]}" = "A" ]
}

@test "_stage_file_by_status D: re-stages the deletion via git rm --cached" {
    _capture_split_statuses
    # Unstage everything to simulate the per-scope reset.
    git restore --staged . 2>/dev/null
    # The deleted file's worktree copy is intentionally still on disk.
    [ -f del/b.txt ]

    _stage_file_by_status "del/b.txt" "D"

    # Index must show the deletion staged.
    status=$(git diff --cached --name-status -- del/b.txt | awk '{print $1}')
    [ "$status" = "D" ]
    # And the worktree copy must NOT have been removed.
    [ -f del/b.txt ]
}

@test "_stage_file_by_status M: stages a modification via git add" {
    _capture_split_statuses
    git restore --staged . 2>/dev/null

    _stage_file_by_status "mod/a.txt" "M"

    status=$(git diff --cached --name-status -- mod/a.txt | awk '{print $1}')
    [ "$status" = "M" ]
}

@test "_stage_file_by_status A: stages a new file via git add" {
    _capture_split_statuses
    git restore --staged . 2>/dev/null

    _stage_file_by_status ".github/d.txt" "A"

    status=$(git diff --cached --name-status -- .github/d.txt | awk '{print $1}')
    [ "$status" = "A" ]
}

@test "_stage_file_by_status with empty status: defaults to git add (M behavior)" {
    git restore --staged . 2>/dev/null
    _stage_file_by_status "mod/a.txt" ""
    [ -n "$(git diff --cached --name-only -- mod/a.txt)" ]
}

@test "regression: a deletion-only scope gets a non-empty index after restage" {
    # This is the exact failure mode from `gitb c ffp` against a tree where
    # one scope (e.g. dist/) only contained `git rm --cached <path>`.
    _capture_split_statuses

    # Simulate the per-scope flow: unstage everything, then restage just the
    # deletion-only "scope".
    git restore --staged . 2>/dev/null
    _stage_file_by_status "del/b.txt" "D"

    # Before the fix this assertion failed (index was empty for the dist scope).
    [ -n "$(git diff --cached --name-only)" ]
}

@test "_restore_split_snapshot: replays deletions from a status-aware snapshot" {
    _capture_split_statuses

    # Build a snapshot file in the new STATUS<TAB>FILE format.
    snap=$(mktemp)
    while IFS= read -r f; do
        printf '%s\t%s\n' "${_split_status_by_file[$f]:-M}" "$f"
    done < <(git diff --name-only --cached) > "$snap"

    # Tear staging down and ask the helper to restore it from the snapshot.
    git restore --staged . 2>/dev/null
    _restore_split_snapshot "$snap"

    # All three original change types must be present again.
    [ "$(git diff --cached --name-status -- mod/a.txt | awk '{print $1}')" = "M" ]
    [ "$(git diff --cached --name-status -- del/b.txt | awk '{print $1}')" = "D" ]
    [ "$(git diff --cached --name-status -- .github/d.txt | awk '{print $1}')" = "A" ]

    # Snapshot file is consumed.
    [ ! -f "$snap" ]
}
