#!/usr/bin/env bats

# Tests for the pure helpers in scripts/update.sh.
# Network-touching functions (_fetch_latest_release, _download_latest_gitb)
# are excluded from coverage and not exercised here.

load setup_suite

setup() {
    export GIT_CONFIG_GLOBAL=/dev/null
    setup_test_repo
    source_gitbasher
    source "${GITBASHER_ROOT}/scripts/update.sh"
    cd "$TEST_REPO"
}

teardown() {
    cleanup_test_repo
}

# ===== _normalize_version =====

@test "_normalize_version: strips leading lowercase v" {
    [ "$(_normalize_version "v3.10.2")" = "3.10.2" ]
}

@test "_normalize_version: strips leading uppercase V" {
    [ "$(_normalize_version "V1.0.0")" = "1.0.0" ]
}

@test "_normalize_version: leaves bare version untouched" {
    [ "$(_normalize_version "2.5.1")" = "2.5.1" ]
}

@test "_normalize_version: preserves pre-release suffix" {
    [ "$(_normalize_version "v1.2.3-rc.4")" = "1.2.3-rc.4" ]
}

# ===== _compare_versions =====

@test "_compare_versions: equal versions return 0" {
    run _compare_versions "3.10.2" "3.10.2"
    [ "$status" -eq 0 ]
}

@test "_compare_versions: A>B returns 1 (numeric, not lexical)" {
    # 3.10.2 > 3.9.9 numerically; lexically the opposite
    run _compare_versions "3.10.2" "3.9.9"
    [ "$status" -eq 1 ]
}

@test "_compare_versions: A<B returns 2" {
    run _compare_versions "1.2.3" "1.2.4"
    [ "$status" -eq 2 ]
}

@test "_compare_versions: pre-release suffix is stripped before comparison" {
    run _compare_versions "3.10.2-rc.1" "3.10.2"
    [ "$status" -eq 0 ]
}

@test "_compare_versions: tolerates v-prefix on either side" {
    run _compare_versions "v3.10.2" "3.10.2"
    [ "$status" -eq 0 ]
}

@test "_compare_versions: missing trailing components default to 0" {
    # 3.10 == 3.10.0
    run _compare_versions "3.10" "3.10.0"
    [ "$status" -eq 0 ]
}

# ===== _extract_release_field =====

@test "_extract_release_field: pulls tag_name from JSON" {
    local body='{"tag_name":"v3.10.2","html_url":"https://github.com/x/y/releases/tag/v3.10.2","published_at":"2026-01-15T10:00:00Z"}'
    [ "$(_extract_release_field "$body" "tag_name")" = "v3.10.2" ]
}

@test "_extract_release_field: pulls html_url from JSON" {
    local body='{"tag_name":"v3.10.2","html_url":"https://github.com/x/y/releases/tag/v3.10.2"}'
    [ "$(_extract_release_field "$body" "html_url")" = "https://github.com/x/y/releases/tag/v3.10.2" ]
}

@test "_extract_release_field: missing field returns empty" {
    local body='{"tag_name":"v3.10.2"}'
    [ "$(_extract_release_field "$body" "nonexistent")" = "" ]
}

@test "_extract_release_date: returns just the date portion" {
    local body='{"published_at":"2026-01-15T10:23:45Z"}'
    [ "$(_extract_release_date "$body")" = "2026-01-15" ]
}

# ===== _gitb_is_npm_install =====

@test "_gitb_is_npm_install: returns 0 for path under node_modules" {
    run _gitb_is_npm_install "/usr/local/lib/node_modules/gitbasher/dist/gitb"
    [ "$status" -eq 0 ]
}

@test "_gitb_is_npm_install: returns 1 for plain ~/.local/bin path" {
    # No npm in PATH for this branch — simulate with a sandboxed PATH
    PATH="/usr/bin:/bin" run _gitb_is_npm_install "/Users/me/.local/bin/gitb"
    [ "$status" -eq 1 ]
}

@test "_gitb_is_npm_install: returns 1 for /usr/local/bin path" {
    PATH="/usr/bin:/bin" run _gitb_is_npm_install "/usr/local/bin/gitb"
    [ "$status" -eq 1 ]
}

@test "_gitb_is_npm_install: returns 1 for empty input" {
    run _gitb_is_npm_install ""
    [ "$status" -eq 1 ]
}
