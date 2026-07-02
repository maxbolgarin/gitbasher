#!/usr/bin/env bats

# Push size preview: human_size formats bytes, and get_push_size_report sums the
# size of objects a push would send + flags oversized blobs, so gitbasher can
# warn "you're about to push 500MB, including data/dump.bin — a non-code object?"
# before pushing. Sizes use %(objectsize) (uncompressed content size), which
# matches how users think about file size and safely over-estimates the wire
# transfer (git compresses on the wire).

load setup_suite

# ---- pure helper: human_size (no repo needed) ----

@test "human_size: formats bytes across units" {
    source_gitbasher_lite

    [ "$(human_size 0)" = "0 B" ]
    [ "$(human_size 512)" = "512 B" ]
    [ "$(human_size 1536)" = "1.5 KB" ]
    [ "$(human_size 1572864)" = "1.5 MB" ]
    [ "$(human_size 1073741824)" = "1.0 GB" ]
}

@test "human_size: non-numeric input is treated as zero" {
    source_gitbasher_lite

    [ "$(human_size "")" = "0 B" ]
    [ "$(human_size "abc")" = "0 B" ]
}

# ---- get_push_size_report (needs a repo with an oversized blob) ----

setup_repo_with_big_blob() {
    setup_test_repo
    source_gitbasher
    source "$GITBASHER_ROOT/scripts/common.sh"
    source "$GITBASHER_ROOT/scripts/pull.sh"
    source "$GITBASHER_ROOT/scripts/push.sh"
    cd "$TEST_REPO"
    setup_remote_repo          # pushes main; origin/main == HEAD

    # ~2 MB of incompressible data so %(objectsize) is genuinely large
    head -c 2097152 /dev/urandom > big.bin
    git add big.bin
    git commit -qm "chore: add big blob"

    current_branch="main"; main_branch="main"; origin_name="origin"
}

teardown() {
    cleanup_test_repo
    cleanup_remote_repo
}

@test "get_push_size_report: total is a positive integer over the unpushed range" {
    setup_repo_with_big_blob

    run get_push_size_report 1048576 "origin/main..HEAD"
    [ "$status" -eq 0 ]
    local total="${lines[0]}"
    [[ "$total" =~ ^[0-9]+$ ]]
    [ "$total" -gt 1000000 ]
}

@test "get_push_size_report: flags a blob over the threshold with its path" {
    setup_repo_with_big_blob

    run get_push_size_report 1048576 "origin/main..HEAD"
    [[ "$output" == *"big.bin"* ]]
}

@test "get_push_size_report: does not flag blobs under a high threshold" {
    setup_repo_with_big_blob

    run get_push_size_report 104857600 "origin/main..HEAD"   # 100 MB threshold
    [[ "$output" != *"big.bin"* ]]
}

@test "get_push_size_report: empty range reports zero total" {
    setup_repo_with_big_blob

    run get_push_size_report 1048576 "HEAD..HEAD"
    [ "${lines[0]}" = "0" ]
}

# ---- config getter/setter ----

@test "push warn size: defaults to 50 and round-trips through config" {
    setup_test_repo
    source_gitbasher
    source "$GITBASHER_ROOT/scripts/common.sh"
    cd "$TEST_REPO"

    [ "$(get_push_warn_size)" = "50" ]
    set_push_warn_size 200 >/dev/null
    [ "$(get_push_warn_size)" = "200" ]
}

# ---- push_script integration ----

@test "push list: previews estimated size and the large file" {
    setup_repo_with_big_blob
    set_push_warn_size 1 >/dev/null   # 1 MB threshold

    run push_script list
    [[ "$output" == *"Estimated push size"* ]]
    [[ "$output" == *"big.bin"* ]]
}

@test "push list: no size line when the threshold is disabled (0)" {
    setup_repo_with_big_blob
    set_push_warn_size 0 >/dev/null

    run push_script list
    [[ "$output" != *"Estimated push size"* ]]
}

@test "push yes: warns about a large push but still pushes (warn-and-proceed)" {
    setup_repo_with_big_blob
    set_push_warn_size 1 >/dev/null

    run push_script yes
    [[ "$output" == *"This push is large"* ]]
    [[ "$output" == *"Pushed to origin/main"* ]]
}
