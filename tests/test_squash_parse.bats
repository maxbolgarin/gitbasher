#!/usr/bin/env bats

# Regression: squash_parse_ai_plan's coverage check used direct associative
# access `${seen_set[$h]}` on a value that is actually a gset shim. Bash
# evaluated the commit hash `$h` as an ARITHMETIC array subscript, so any range
# whose commit short-hash starts with a digit (e.g. "0d61206") aborted
# `gitb squash` with:
#     value too great for base (error token is "0d61206")
# The fix uses the shim's `gset_has` membership check instead.

load setup_suite

setup() {
    source_gitbasher_lite
    source "${GITBASHER_ROOT}/scripts/squash.sh"
}

@test "squash: parsing a plan with a digit-leading hash does not hit arithmetic error" {
    command -v jq >/dev/null || skip "jq not installed"
    local json='{"groups":[{"commits":["0d61206","e86bd0b"],"message":"fix: keep it together","body":""}]}'

    run squash_parse_ai_plan "$json" "0d61206 e86bd0b"

    [[ "$output" != *"value too great for base"* ]] \
        || { echo "arithmetic crash on digit-leading hash:"; echo "$output"; return 1; }
    [ "$status" -eq 0 ] \
        || { echo "parse unexpectedly failed:"; echo "$output"; return 1; }
}

@test "squash: parsed plan globals cover a digit-leading hash range" {
    command -v jq >/dev/null || skip "jq not installed"
    local json='{"groups":[{"commits":["0d61206","e86bd0b"],"message":"fix: keep it together","body":""}]}'

    squash_parse_ai_plan "$json" "0d61206 e86bd0b" || true

    [ "$squash_group_count" -eq 1 ]
    [ "${squash_group_commits[1]}" = "0d61206 e86bd0b" ]
}

@test "squash: multi-group plan with digit-leading leaders parses in order" {
    command -v jq >/dev/null || skip "jq not installed"
    local json='{"groups":[{"commits":["0d61206"],"message":"fix: one","body":""},{"commits":["9abcd00","e86bd0b"],"message":"feat: two","body":"details"}]}'

    run squash_parse_ai_plan "$json" "0d61206 9abcd00 e86bd0b"

    [[ "$output" != *"value too great for base"* ]] \
        || { echo "arithmetic crash:"; echo "$output"; return 1; }
    [ "$status" -eq 0 ] \
        || { echo "parse unexpectedly failed:"; echo "$output"; return 1; }
}
