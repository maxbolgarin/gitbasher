#!/usr/bin/env bats

# Pure-unit tests for should_attempt_ai_grouping — the gate that decides whether
# a commit split is worth an AI feature-grouping call. AI is spent only when the
# folder heuristic found 3+ distinct scopes (non-obvious grouping); 1-2 scopes are
# trusted as-is. commit-ai-grouping=always/never override the scope count.

load setup_suite

setup() {
    source "${GITBASHER_ROOT}/scripts/common.sh"
    source "${GITBASHER_ROOT}/scripts/commit.sh"
}

@test "gate: auto skips AI for 1 scope (single feature)" {
    run should_attempt_ai_grouping 1 auto
    [ "$status" -ne 0 ]
}

@test "gate: auto skips AI for 2 scopes (obvious folder split)" {
    run should_attempt_ai_grouping 2 auto
    [ "$status" -ne 0 ]
}

@test "gate: auto attempts AI for 3 scopes" {
    run should_attempt_ai_grouping 3 auto
    [ "$status" -eq 0 ]
}

@test "gate: auto attempts AI for 4+ scopes" {
    run should_attempt_ai_grouping 4 auto
    [ "$status" -eq 0 ]
}

@test "gate: always attempts AI even for 1 scope" {
    run should_attempt_ai_grouping 1 always
    [ "$status" -eq 0 ]
}

@test "gate: never skips AI even for many scopes" {
    run should_attempt_ai_grouping 9 never
    [ "$status" -ne 0 ]
}

@test "gate: non-numeric or empty scope count skips AI (auto)" {
    run should_attempt_ai_grouping "" auto
    [ "$status" -ne 0 ]
    run should_attempt_ai_grouping "abc" auto
    [ "$status" -ne 0 ]
}
