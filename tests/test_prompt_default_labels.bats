#!/usr/bin/env bats

# Every yes/no prompt must show its Enter default as a capital letter:
# "(Y/n...)" when Enter confirms, "(y/N)" when Enter declines.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "no prompt shows a lowercase y/n choice without a default" {
    # Skip comment lines; only real prompt strings matter.
    local hits
    hits=$(grep -nE '\((y/n|y/e|y/[0-9r])' "$REPO_ROOT"/scripts/*.sh \
        | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' || true)
    echo "$hits"
    [ -z "$hits" ]
}

@test "hooks remove-all asks (y/N) and Enter declines" {
    run grep -n 'absolutely sure (y/N)' "$REPO_ROOT/scripts/hooks.sh"
    [ "$status" -eq 0 ]
    run grep -n 'if \[ -z "\$choice" \] || ! is_yes "\$choice"; then' "$REPO_ROOT/scripts/hooks.sh"
    [ "$status" -eq 0 ]
}

@test "branch tag fetch prompt (Y/n) accepts Enter via is_yes" {
    run grep -n -A3 'Fetch remote? (Y/n)' "$REPO_ROOT/scripts/branch.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *'if is_yes "$choice"; then'* ]]
}
