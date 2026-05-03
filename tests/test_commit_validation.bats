#!/usr/bin/env bats

# Tests for validate_commit_flag_combo + summarize_commit_intent helpers
# in commit.sh. These guard against silent wrong-behavior on conflicting
# flag combinations (the parser used to accept anything; dispatch then
# silently picked one action and ignored the rest).

load setup_suite

setup() {
    setup_test_repo
    source_gitbasher
    source "${GITBASHER_ROOT}/scripts/commit.sh"

    # Reset all flags between tests.
    llm=""; fast=""; push=""; scope=""; msg=""; ticket=""
    staged=""; no_split=""; fixup=""; amend=""; split=""
    last=""; revert=""; auto_accept=""; help=""
}

teardown() {
    cleanup_test_repo
}


# ===== validate_commit_flag_combo: rejections =====

@test "rejects two action flags: fixup + amend" {
    fixup="true"; amend="true"
    run validate_commit_flag_combo
    [ "$status" -eq 1 ]
    [[ "$output" == *"Cannot combine actions"* ]]
    [[ "$output" == *"fixup"* ]]
    [[ "$output" == *"amend"* ]]
}

@test "rejects two action flags: last + revert" {
    last="true"; revert="true"
    run validate_commit_flag_combo
    [ "$status" -eq 1 ]
    [[ "$output" == *"Cannot combine actions"* ]]
}

@test "rejects three action flags: split + amend + revert" {
    split="true"; amend="true"; revert="true"
    run validate_commit_flag_combo
    [ "$status" -eq 1 ]
    [[ "$output" == *"Cannot combine actions"* ]]
}

@test "rejects last + ai" {
    last="true"; llm="true"
    run validate_commit_flag_combo
    [ "$status" -eq 1 ]
    [[ "$output" == *"'last' takes no modifiers"* ]]
    [[ "$output" == *"ai"* ]]
}

@test "rejects last + push" {
    last="true"; push="true"
    run validate_commit_flag_combo
    [ "$status" -eq 1 ]
    [[ "$output" == *"'last' takes no modifiers"* ]]
}

@test "rejects revert + ai" {
    revert="true"; llm="true"
    run validate_commit_flag_combo
    [ "$status" -eq 1 ]
    [[ "$output" == *"'revert' takes no modifiers"* ]]
}

@test "rejects revert + ticket" {
    revert="true"; ticket="true"
    run validate_commit_flag_combo
    [ "$status" -eq 1 ]
    [[ "$output" == *"'revert' takes no modifiers"* ]]
}

@test "rejects amend + ai" {
    amend="true"; llm="true"
    run validate_commit_flag_combo
    [ "$status" -eq 1 ]
    [[ "$output" == *"'amend' does not use"* ]]
    [[ "$output" == *"ai"* ]]
}

@test "rejects amend + msg" {
    amend="true"; msg="true"
    run validate_commit_flag_combo
    [ "$status" -eq 1 ]
    [[ "$output" == *"'amend' does not use"* ]]
}

@test "rejects amend + scope" {
    amend="true"; scope="true"
    run validate_commit_flag_combo
    [ "$status" -eq 1 ]
    [[ "$output" == *"'amend' does not use"* ]]
}

@test "rejects fixup + ai" {
    fixup="true"; llm="true"
    run validate_commit_flag_combo
    [ "$status" -eq 1 ]
    [[ "$output" == *"'fixup' does not use"* ]]
}

@test "rejects fixup + ticket" {
    fixup="true"; ticket="true"
    run validate_commit_flag_combo
    [ "$status" -eq 1 ]
    [[ "$output" == *"'fixup' does not use"* ]]
}

@test "rejects fast + staged" {
    fast="true"; staged="true"
    run validate_commit_flag_combo
    [ "$status" -eq 1 ]
    [[ "$output" == *"'fast' and 'staged' are mutually exclusive"* ]]
}


# ===== validate_commit_flag_combo: accepts =====

@test "accepts no flags (regular commit)" {
    run validate_commit_flag_combo
    [ "$status" -eq 0 ]
}

@test "accepts ai + fast + push" {
    llm="true"; fast="true"; push="true"
    run validate_commit_flag_combo
    [ "$status" -eq 0 ]
}

@test "accepts amend + fast" {
    amend="true"; fast="true"
    run validate_commit_flag_combo
    [ "$status" -eq 0 ]
}

@test "accepts amend + staged + push" {
    amend="true"; staged="true"; push="true"
    run validate_commit_flag_combo
    [ "$status" -eq 0 ]
}

@test "accepts fixup + fast + push" {
    fixup="true"; fast="true"; push="true"
    run validate_commit_flag_combo
    [ "$status" -eq 0 ]
}

@test "accepts fixup + staged" {
    fixup="true"; staged="true"
    run validate_commit_flag_combo
    [ "$status" -eq 0 ]
}

@test "accepts split + push + ai" {
    split="true"; push="true"; llm="true"
    run validate_commit_flag_combo
    [ "$status" -eq 0 ]
}

@test "accepts ff (auto_accept + fast + ai)" {
    auto_accept="true"; fast="true"; llm="true"
    run validate_commit_flag_combo
    [ "$status" -eq 0 ]
}

@test "accepts last alone" {
    last="true"
    run validate_commit_flag_combo
    [ "$status" -eq 0 ]
}

@test "accepts revert alone" {
    revert="true"
    run validate_commit_flag_combo
    [ "$status" -eq 0 ]
}


# ===== summarize_commit_intent =====

@test "summary: bare commit" {
    run summarize_commit_intent
    [ "$status" -eq 0 ]
    [[ "$output" == *"→ commit"* ]]
}

@test "summary: ai + fast + push" {
    llm="true"; fast="true"; push="true"
    run summarize_commit_intent
    [[ "$output" == *"→ commit"* ]]
    [[ "$output" == *"ai message"* ]]
    [[ "$output" == *"fast"* ]]
    [[ "$output" == *"push"* ]]
}

@test "summary: amend + fast" {
    amend="true"; fast="true"
    run summarize_commit_intent
    [[ "$output" == *"amend last commit"* ]]
    [[ "$output" == *"fast"* ]]
}

@test "summary: fixup + push" {
    fixup="true"; push="true"
    run summarize_commit_intent
    [[ "$output" == *"fixup an earlier commit"* ]]
    [[ "$output" == *"push"* ]]
}

@test "summary: split + push" {
    split="true"; push="true"
    run summarize_commit_intent
    [[ "$output" == *"split staged changes"* ]]
    [[ "$output" == *"push"* ]]
}

@test "summary: ff (ultrafast)" {
    auto_accept="true"; fast="true"; llm="true"
    run summarize_commit_intent
    [[ "$output" == *"ultrafast"* ]]
    # ai/fast not duplicated as modifiers when auto_accept is set
    [[ "$output" != *"modifiers: ai"* ]]
    [[ "$output" != *"modifiers: fast"* ]]
}

@test "summary: ffp (ultrafast + push)" {
    auto_accept="true"; fast="true"; llm="true"; push="true"
    run summarize_commit_intent
    [[ "$output" == *"ultrafast"* ]]
    [[ "$output" == *"push"* ]]
}

@test "summary: last" {
    last="true"
    run summarize_commit_intent
    [[ "$output" == *"amend last commit"* ]]
    [[ "$output" == *"reuse message"* ]]
}

@test "summary: revert" {
    revert="true"
    run summarize_commit_intent
    [[ "$output" == *"revert a commit"* ]]
}
