#!/usr/bin/env bats

# The `claude` provider shells out to the local Claude Code CLI instead of
# HTTP: call_ai_api pipes system+user prompts via stdin to
# `claude -p --model <m> --output-format text`. These tests stub `claude`
# on PATH (never touching the real CLI) and assert routing, model
# resolution, timeout handling, and availability checks.

load setup_suite

setup() {
    setup_test_repo
    source_gitbasher_lite
    source "${GITBASHER_ROOT}/scripts/ai.sh"
    cd "$TEST_REPO"

    git config gitbasher.ai-provider claude

    CLAUDE_LOG=$(mktemp)
    export CLAUDE_LOG

    CLAUDE_FAKE_BIN=$(mktemp -d)
    export CLAUDE_FAKE_BIN
    cat > "${CLAUDE_FAKE_BIN}/claude" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "--version" ]; then echo "9.9.9 (Claude Code)"; exit 0; fi
{
    echo "ARGV_BEGIN"
    for a in "$@"; do echo "ARG: $a"; done
    echo "ARGV_END"
    echo "STDIN_BEGIN"
    cat
    echo "STDIN_END"
} >> "$CLAUDE_LOG"
if [ -n "$FAKE_CLAUDE_SLEEP" ]; then sleep "$FAKE_CLAUDE_SLEEP"; fi
printf '%s' "${FAKE_CLAUDE_RESPONSE-feat: stub message}"
exit "${FAKE_CLAUDE_EXIT:-0}"
EOF
    chmod +x "${CLAUDE_FAKE_BIN}/claude"
    PATH="${CLAUDE_FAKE_BIN}:$PATH"
    export PATH
}

teardown() {
    [ -n "$CLAUDE_LOG" ] && rm -f "$CLAUDE_LOG"
    [ -n "$CLAUDE_FAKE_BIN" ] && rm -rf "$CLAUDE_FAKE_BIN"
    cleanup_test_repo
}

# ===== provider predicates and defaults =====

@test "claude: provider does not require an API key" {
    ! ai_provider_requires_api_key
}

@test "claude: per-task model defaults are alias slugs" {
    [ "$(get_ai_model_for simple)" = "haiku" ]
    [ "$(get_ai_model_for subject)" = "haiku" ]
    [ "$(get_ai_model_for full)" = "sonnet" ]
    [ "$(get_ai_model_for grouping)" = "sonnet" ]
}

@test "claude: default timeout is 300 seconds" {
    [ "$(get_ai_timeout)" = "300" ]
}

# ===== call_ai_api transport routing =====

@test "call_ai_api: routes to the claude CLI with model and stdin prompt" {
    run call_ai_api "SYSTEM-INSTRUCTIONS" "USER-DATA" 100 "haiku"
    [ "$status" -eq 0 ]
    [ "$output" = "feat: stub message" ]
    grep -q "ARG: -p" "$CLAUDE_LOG"
    grep -q "ARG: --model" "$CLAUDE_LOG"
    grep -q "ARG: haiku" "$CLAUDE_LOG"
    # Prompt arrives on stdin: system, blank line, user
    grep -q "SYSTEM-INSTRUCTIONS" "$CLAUDE_LOG"
    grep -q "USER-DATA" "$CLAUDE_LOG"
    # No API key configured anywhere — proves the key guard was skipped
}

@test "call_ai_api: claude ignores the response_format argument" {
    run call_ai_api "sys" "user" 100 "sonnet" '{"type":"json_object"}'
    [ "$status" -eq 0 ]
    ! grep -q "response_format" "$CLAUDE_LOG"
    ! grep -q "json_object" "$CLAUDE_LOG"
}

@test "call_ai_api: claude CLI failure returns non-zero" {
    FAKE_CLAUDE_EXIT=1 run call_ai_api "sys" "user"
    [ "$status" -ne 0 ]
}

@test "call_ai_api: empty claude output is a failure" {
    FAKE_CLAUDE_RESPONSE="" FAKE_CLAUDE_EXIT=0 run call_ai_api "sys" "user"
    [ "$status" -ne 0 ]
}

@test "call_ai_api: claude timeout is enforced via gitbasher.ai-timeout" {
    git config gitbasher.ai-timeout 1
    FAKE_CLAUDE_SLEEP=5 run perl -e 'alarm 15; exec @ARGV' -- bash -c "
        source '$GITBASHER_ROOT/scripts/common.sh' 2>/dev/null
        GITBASHER_SKIP_INIT_QUERIES=1 source '$GITBASHER_ROOT/scripts/init.sh' 2>/dev/null
        source '$GITBASHER_ROOT/scripts/ai.sh'
        cd '$TEST_REPO'
        call_ai_api 'sys' 'user'
    "
    [ "$status" -ne 0 ]
    [[ "$output" == *"timed out"* ]]
}

# ===== availability and smoke checks =====

@test "check_ai_available: claude provider needs the claude binary, not curl" {
    run check_ai_available
    [ "$status" -eq 0 ]
}

@test "check_ai_available: fails with install hint when claude is missing" {
    # Keep git visible (provider lookup) but hide any real claude install:
    # npm globals never live in the base system dirs.
    saved_path="$PATH"
    PATH="/usr/bin:/bin"
    run check_ai_available
    PATH="$saved_path"
    [ "$status" -ne 0 ]
    [[ "$output" == *"claude CLI not found"* ]]
    [[ "$output" == *"npm install -g @anthropic-ai/claude-code"* ]]
}

@test "ai_smoke_check: reports the claude CLI version" {
    run ai_smoke_check
    [ "$status" -eq 0 ]
    [[ "$output" == *"claude CLI available"* ]]
    [[ "$output" == *"9.9.9"* ]]
}

@test "ai_smoke_check: fails when the claude binary is missing" {
    saved_path="$PATH"
    PATH="/usr/bin:/bin"
    run ai_smoke_check
    PATH="$saved_path"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

# ===== config UI =====

@test "configure_ai_provider: choice 4 selects claude" {
    run perl -e 'alarm 10; exec @ARGV' -- bash -c "
        source '$GITBASHER_ROOT/scripts/common.sh' 2>/dev/null
        GITBASHER_SKIP_INIT_QUERIES=1 source '$GITBASHER_ROOT/scripts/init.sh' 2>/dev/null
        source '$GITBASHER_ROOT/scripts/ai.sh'
        source '$GITBASHER_ROOT/scripts/config.sh'
        cd '$TEST_REPO'
        project_name=test
        git config --unset gitbasher.ai-provider
        configure_ai_provider
    " <<< $'4\nnn'
    [[ "$output" == *"claude"* ]]
    [ "$(git config --get gitbasher.ai-provider)" = "claude" ]
}
