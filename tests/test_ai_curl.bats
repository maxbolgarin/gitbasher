#!/usr/bin/env bats

# Tests for the AI HTTP layer in scripts/ai.sh:
#   - _json_escape_for_payload: pure helper, fully testable.
#   - secure_curl_with_api_key: integration-tested by stubbing `curl` on PATH
#     so the function calls our fake binary; we then assert what arguments,
#     headers, and body it passed.
#
# We never hit the real network. The fake curl writes its argv + the stdin
# (--config -) heredoc to a side file we inspect.

load setup_suite

setup() {
    setup_test_repo
    source_gitbasher_lite
    source "${GITBASHER_ROOT}/scripts/ai.sh"
    cd "$TEST_REPO"

    AI_CURL_LOG=$(mktemp)
    export AI_CURL_LOG

    # Stub `curl` by prepending a fake bin dir to PATH. The fake records argv
    # and stdin to AI_CURL_LOG and prints a canned JSON response.
    AI_FAKE_BIN=$(mktemp -d)
    export AI_FAKE_BIN
    cat > "${AI_FAKE_BIN}/curl" <<'EOF'
#!/usr/bin/env bash
{
    echo "ARGV_BEGIN"
    for a in "$@"; do echo "ARG: $a"; done
    echo "ARGV_END"
    if [ -p /dev/stdin ] || [ ! -t 0 ]; then
        echo "STDIN_BEGIN"
        cat
        echo "STDIN_END"
    fi
} >> "$AI_CURL_LOG"
echo '{"choices":[{"message":{"content":"stub-response"}}]}'
EOF
    chmod +x "${AI_FAKE_BIN}/curl"
    PATH="${AI_FAKE_BIN}:$PATH"
    export PATH
}

teardown() {
    [ -n "$AI_CURL_LOG" ] && rm -f "$AI_CURL_LOG"
    [ -n "$AI_FAKE_BIN" ] && rm -rf "$AI_FAKE_BIN"
    cleanup_test_repo
}

# ===== _json_escape_for_payload =====

@test "_json_escape_for_payload: passes plain text through" {
    [ "$(_json_escape_for_payload 'hello world')" = "hello world" ]
}

@test "_json_escape_for_payload: escapes embedded double quotes" {
    [ "$(_json_escape_for_payload 'say "hi"')" = 'say \"hi\"' ]
}

@test "_json_escape_for_payload: escapes backslashes" {
    [ "$(_json_escape_for_payload 'C:\path\to\thing')" = 'C:\\path\\to\\thing' ]
}

@test "_json_escape_for_payload: escapes tab and carriage-return" {
    out=$(_json_escape_for_payload $'col1\tcol2\rend')
    [ "$out" = 'col1\tcol2\rend' ]
}

@test "_json_escape_for_payload: collapses newlines into \\n" {
    out=$(_json_escape_for_payload $'line1\nline2')
    [ "$out" = 'line1\nline2' ]
}

@test "_json_escape_for_payload: handles empty input" {
    out=$(_json_escape_for_payload "")
    [ -z "$out" ]
}

@test "_json_escape_for_payload: backslash-then-quote escapes both" {
    [ "$(_json_escape_for_payload 'a\"b')" = 'a\\\"b' ]
}

# ===== secure_curl_with_api_key =====

@test "secure_curl_with_api_key: hits the configured URL" {
    secure_curl_with_api_key "" "key123" '{"a":1}' "https://api.test/v1/chat" "openai" >/dev/null
    grep -q "ARG: https://api.test/v1/chat" "$AI_CURL_LOG"
}

@test "secure_curl_with_api_key: sends Content-Type: application/json header" {
    secure_curl_with_api_key "" "key123" '{"a":1}' "https://api.test/v1/chat" "openai" >/dev/null
    grep -q "ARG: Content-Type: application/json" "$AI_CURL_LOG"
}

@test "secure_curl_with_api_key: passes payload via -d" {
    secure_curl_with_api_key "" "key123" '{"hello":"world"}' "https://api.test/v1/chat" "openai" >/dev/null
    # The body comes through as a separate ARG line. Match the start so we
    # don't depend on shell quoting in the log.
    grep -q 'ARG: {"hello":"world"}' "$AI_CURL_LOG"
}

@test "secure_curl_with_api_key: uses --config - to keep bearer out of argv" {
    secure_curl_with_api_key "" "secret-token" '{"a":1}' "https://api.test/v1/chat" "openai" >/dev/null
    # Argv must include --config and -, but never the literal token.
    grep -q "^ARG: --config$" "$AI_CURL_LOG"
    grep -q "^ARG: -$" "$AI_CURL_LOG"
    ! grep -q "ARG: .*secret-token" "$AI_CURL_LOG"
}

@test "secure_curl_with_api_key: sends bearer header via stdin heredoc" {
    secure_curl_with_api_key "" "secret-token" '{"a":1}' "https://api.test/v1/chat" "openai" >/dev/null
    # The token shows up only inside the STDIN_BEGIN/STDIN_END block.
    awk '/STDIN_BEGIN/,/STDIN_END/' "$AI_CURL_LOG" | grep -q 'header = "Authorization: Bearer secret-token"'
}

@test "secure_curl_with_api_key: omits bearer when api_key is empty" {
    secure_curl_with_api_key "" "" '{"a":1}' "http://localhost:11434/api" "ollama" >/dev/null
    ! grep -q "Authorization: Bearer" "$AI_CURL_LOG"
    # And no --config - either, since there's no bearer to hide.
    ! grep -q "^ARG: --config$" "$AI_CURL_LOG"
}

@test "secure_curl_with_api_key: forwards proxy when supplied" {
    secure_curl_with_api_key "http://proxy.example:3128" "k" '{"a":1}' "https://api.test/v1" "openai" >/dev/null
    grep -q "^ARG: --proxy$" "$AI_CURL_LOG"
    grep -q "^ARG: http://proxy.example:3128$" "$AI_CURL_LOG"
}

@test "secure_curl_with_api_key: omits proxy args when empty" {
    secure_curl_with_api_key "" "k" '{"a":1}' "https://api.test/v1" "openai" >/dev/null
    ! grep -q "^ARG: --proxy$" "$AI_CURL_LOG"
}

@test "secure_curl_with_api_key: adds OpenRouter-specific headers for openrouter" {
    secure_curl_with_api_key "" "k" '{"a":1}' "https://openrouter.ai/api/v1/chat/completions" "openrouter" >/dev/null
    grep -q "ARG: HTTP-Referer: https://github.com/maxbolgarin/gitbasher" "$AI_CURL_LOG"
    grep -q "ARG: X-Title: gitbasher" "$AI_CURL_LOG"
}

@test "secure_curl_with_api_key: skips OpenRouter headers for openai" {
    secure_curl_with_api_key "" "k" '{"a":1}' "https://api.openai.com/v1/chat/completions" "openai" >/dev/null
    ! grep -q "X-Title: gitbasher" "$AI_CURL_LOG"
    ! grep -q "HTTP-Referer:" "$AI_CURL_LOG"
}

@test "secure_curl_with_api_key: escapes backslash and quote in api_key" {
    # In practice no real provider issues such a key, but this guards the
    # `escaped_key` substitution inside secure_curl_with_api_key from
    # breaking the heredoc.
    secure_curl_with_api_key "" 'a\b"c' '{"a":1}' "https://api.test/v1" "openai" >/dev/null
    awk '/STDIN_BEGIN/,/STDIN_END/' "$AI_CURL_LOG" | grep -q 'header = "Authorization: Bearer a\\\\b\\"c"'
}

@test "secure_curl_with_api_key: returns the response body printed by curl" {
    out=$(secure_curl_with_api_key "" "k" '{"a":1}' "https://api.test/v1" "openai")
    [[ "$out" == *"stub-response"* ]]
}

@test "secure_curl_with_api_key: uses POST" {
    secure_curl_with_api_key "" "k" '{"a":1}' "https://api.test/v1" "openai" >/dev/null
    grep -q "^ARG: -X$" "$AI_CURL_LOG"
    grep -q "^ARG: POST$" "$AI_CURL_LOG"
}

@test "secure_curl_with_api_key: sets connect-timeout and max-time" {
    secure_curl_with_api_key "" "k" '{"a":1}' "https://api.test/v1" "openai" >/dev/null
    grep -q "^ARG: --connect-timeout$" "$AI_CURL_LOG"
    grep -q "^ARG: --max-time$" "$AI_CURL_LOG"
}
