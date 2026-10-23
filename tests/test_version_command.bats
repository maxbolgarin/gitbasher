#!/usr/bin/env bats

# `gitb -v` / `--version` stay one machine-readable line; `gitb version`
# (and its v / ver aliases) also shows where the running binary lives and
# how it was installed. Exercised against a real versioned bundle, laid out
# like a Homebrew Cellar, because the dev entry point always reports "dev".

load setup_suite

setup() {
    setup_test_repo
    cd "$TEST_REPO"

    # pwd -P: macOS mktemp lives under /var -> /private/var, and gitb prints
    # the symlink-resolved path.
    BIN_ROOT=$(cd "$(mktemp -d)" && pwd -P)
    export BIN_ROOT
    mkdir -p "$BIN_ROOT/Cellar/gitbasher/9.9.9/bin" "$BIN_ROOT/brewbin" "$BIN_ROOT/localbin"
    CELLAR_GITB="$BIN_ROOT/Cellar/gitbasher/9.9.9/bin/gitb"
    export CELLAR_GITB
    (cd "$GITBASHER_ROOT" && bash ./dist/build.sh ./scripts/gitb.sh "$CELLAR_GITB" 9.9.9) >/dev/null
    chmod +x "$CELLAR_GITB"
    ln -s "$CELLAR_GITB" "$BIN_ROOT/brewbin/gitb"
}

teardown() {
    [ -n "$BIN_ROOT" ] && rm -rf "$BIN_ROOT"
    cleanup_test_repo
}

@test "version: -v prints exactly one line" {
    PATH="$BIN_ROOT/brewbin:$PATH" run gitb -v
    [ "$status" -eq 0 ]
    [ "$output" = "gitbasher v9.9.9" ]
}

@test "version: --version prints exactly one line" {
    PATH="$BIN_ROOT/brewbin:$PATH" run gitb --version
    [ "$status" -eq 0 ]
    [ "$output" = "gitbasher v9.9.9" ]
}

@test "version: v, ver and version print the same details" {
    PATH="$BIN_ROOT/brewbin:$PATH" run gitb version
    [ "$status" -eq 0 ]
    local full="$output"
    PATH="$BIN_ROOT/brewbin:$PATH" run gitb ver
    [ "$output" = "$full" ]
    PATH="$BIN_ROOT/brewbin:$PATH" run gitb v
    [ "$output" = "$full" ]
}

@test "version: shows resolved binary path and Homebrew install method" {
    PATH="$BIN_ROOT/brewbin:$PATH" run gitb version
    [ "$status" -eq 0 ]
    [[ "$output" == *"gitbasher v9.9.9"* ]]
    [[ "$output" == *"$CELLAR_GITB"* ]]
    [[ "$output" == *"Homebrew"* ]]
    [[ "$output" == *"brew upgrade gitbasher"* ]]
    [[ "$output" != *"different copy"* ]]
}

@test "version: standalone install points at gitb update" {
    cp "$CELLAR_GITB" "$BIN_ROOT/localbin/gitb"
    PATH="$BIN_ROOT/localbin:$PATH" run gitb version
    [ "$status" -eq 0 ]
    [[ "$output" == *"standalone"* ]]
    [[ "$output" == *"gitb update"* ]]
}

@test "version: warns when another gitb shadows the running one on PATH" {
    cp "$CELLAR_GITB" "$BIN_ROOT/localbin/gitb"
    PATH="$BIN_ROOT/localbin:$BIN_ROOT/brewbin:$PATH" run "$BIN_ROOT/brewbin/gitb" version
    [ "$status" -eq 0 ]
    [[ "$output" == *"different copy"* ]]
    [[ "$output" == *"$BIN_ROOT/localbin/gitb"* ]]
}

@test "version: works outside a git repository" {
    cd "$BIN_ROOT"
    PATH="$BIN_ROOT/brewbin:$PATH" run gitb ver
    [ "$status" -eq 0 ]
    [[ "$output" == *"gitbasher v9.9.9"* ]]
}
