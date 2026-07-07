#!/usr/bin/env bats

# Tests for the Ollama-specific settings in ai.sh:
#   - configurable host (gitbasher.ai-ollama-host) and chat-URL construction
#   - model-id validation that accepts Ollama's name:tag colon
#   - live model listing from GET {host}/api/tags
#   - the provider smoke check (ollama reachability + cloud key auth)
#
# No real network: curl is stubbed on PATH. The fake prints a status code when
# curl is asked for one (-w %{http_code}) and canned JSON otherwise, both driven
# by env vars so each test controls the response.

load setup_suite

# Canned /api/tags payload with two models, one carrying a colon tag.
TAGS_JSON='{"models":[{"name":"qwen3:8b","model":"qwen3:8b"},{"name":"llama3.3:8b","model":"llama3.3:8b"}]}'

setup() {
    export GIT_CONFIG_GLOBAL=/dev/null
    setup_test_repo
    source_gitbasher
    source "${GITBASHER_ROOT}/scripts/ai.sh"
    cd "$TEST_REPO"
    # Clear inherited env that would otherwise leak into get_ai_api_key.
    unset GITB_AI_API_KEY GITB_AI_API_KEY_OPENAI GITB_AI_API_KEY_OPENROUTER GITB_AI_API_KEY_OLLAMA

    FAKE_BIN=$(mktemp -d)
    export FAKE_BIN
    cat > "${FAKE_BIN}/curl" <<'EOF'
#!/usr/bin/env bash
# When the caller wants only the HTTP status code (-w %{http_code}), return the
# canned code. Otherwise emit canned JSON (empty simulates an unreachable host).
for a in "$@"; do
    case "$a" in
        *'%{http_code}'*) printf '%s' "${FAKE_HTTP_CODE:-200}"; exit 0 ;;
    esac
done
printf '%s' "${FAKE_TAGS_JSON:-}"
exit 0
EOF
    chmod +x "${FAKE_BIN}/curl"
    # Default DEAD ollama CLI: ollama_list_models falls back to `ollama list`
    # when HTTP fails, and a real ollama on the dev machine would make the
    # unreachable-host tests flaky. Tests that want a live CLI overwrite this.
    printf '#!/usr/bin/env bash\nexit 1\n' > "${FAKE_BIN}/ollama"
    chmod +x "${FAKE_BIN}/ollama"
    PATH="${FAKE_BIN}:$PATH"
    export PATH
}

teardown() {
    [ -n "$FAKE_BIN" ] && rm -rf "$FAKE_BIN"
    cleanup_test_repo
}

# ===== is_valid_model_id =====

@test "is_valid_model_id: accepts ollama name:tag (the colon bug)" {
    run is_valid_model_id "qwen3:8b"
    [ "$status" -eq 0 ]
}

@test "is_valid_model_id: accepts gpt-oss:20b" {
    run is_valid_model_id "gpt-oss:20b"
    [ "$status" -eq 0 ]
}

@test "is_valid_model_id: accepts provider/model slugs" {
    run is_valid_model_id "anthropic/claude-haiku-4.5"
    [ "$status" -eq 0 ]
}

@test "is_valid_model_id: rejects spaces" {
    run is_valid_model_id "bad model"
    [ "$status" -ne 0 ]
}

@test "is_valid_model_id: rejects empty input" {
    run is_valid_model_id ""
    [ "$status" -ne 0 ]
}

# ===== get/set_ai_ollama_host + ollama_api_base =====

@test "get_ai_ollama_host: defaults to localhost:11434" {
    [ "$(get_ai_ollama_host)" = "http://localhost:11434" ]
}

@test "set_ai_ollama_host: persists a custom host" {
    set_ai_ollama_host "http://10.0.0.5:11434" >/dev/null
    [ "$(get_ai_ollama_host)" = "http://10.0.0.5:11434" ]
}

@test "ollama_api_base: strips a trailing slash" {
    set_ai_ollama_host "http://localhost:11434/" >/dev/null
    [ "$(ollama_api_base)" = "http://localhost:11434" ]
}

# ===== get_ai_api_url with configurable host =====

@test "get_ai_api_url: ollama builds chat URL from default host" {
    set_ai_provider "ollama" >/dev/null
    [ "$(get_ai_api_url)" = "http://localhost:11434/v1/chat/completions" ]
}

@test "get_ai_api_url: ollama honors a custom host" {
    set_ai_provider "ollama" >/dev/null
    set_ai_ollama_host "http://10.0.0.5:11434" >/dev/null
    [ "$(get_ai_api_url)" = "http://10.0.0.5:11434/v1/chat/completions" ]
}

@test "get_ai_api_url: custom base-url still overrides ollama host" {
    set_ai_provider "ollama" >/dev/null
    set_ai_ollama_host "http://10.0.0.5:11434" >/dev/null
    set_ai_base_url "http://gateway.test/v1/chat/completions" >/dev/null
    [ "$(get_ai_api_url)" = "http://gateway.test/v1/chat/completions" ]
}

# ===== _parse_ollama_model_names =====

@test "_parse_ollama_model_names: extracts names from /api/tags JSON" {
    out=$(printf '%s' "$TAGS_JSON" | _parse_ollama_model_names)
    [[ "$out" == *"qwen3:8b"* ]]
    [[ "$out" == *"llama3.3:8b"* ]]
}

# ===== ollama_list_models =====

@test "ollama_list_models: returns installed model names" {
    export FAKE_TAGS_JSON="$TAGS_JSON"
    run ollama_list_models
    [ "$status" -eq 0 ]
    [[ "$output" == *"qwen3:8b"* ]]
    [[ "$output" == *"llama3.3:8b"* ]]
}

@test "ollama_list_models: fails when the host is unreachable (empty response)" {
    export FAKE_TAGS_JSON=""
    run ollama_list_models
    [ "$status" -ne 0 ]
}

@test "ollama_list_models: fails when no models are pulled" {
    export FAKE_TAGS_JSON='{"models":[]}'
    run ollama_list_models
    [ "$status" -ne 0 ]
}

# ===== ai_smoke_check =====

@test "ai_smoke_check: ollama reachable reports success" {
    set_ai_provider "ollama" >/dev/null
    export FAKE_TAGS_JSON="$TAGS_JSON"
    run ai_smoke_check
    [ "$status" -eq 0 ]
    [[ "$output" == *"reachable"* ]]
}

@test "ai_smoke_check: ollama unreachable fails with a hint" {
    set_ai_provider "ollama" >/dev/null
    export FAKE_TAGS_JSON=""
    run ai_smoke_check
    [ "$status" -ne 0 ]
    [[ "$output" == *"ollama serve"* ]]
}

@test "ai_smoke_check: cloud provider with 200 reports a valid key" {
    set_ai_provider "openai" >/dev/null
    set_ai_api_key "sk-testkey1234567890" >/dev/null
    export FAKE_HTTP_CODE="200"
    run ai_smoke_check
    [ "$status" -eq 0 ]
    [[ "$output" == *"valid"* ]]
}

@test "ai_smoke_check: cloud provider with 401 reports a rejected key" {
    set_ai_provider "openai" >/dev/null
    set_ai_api_key "sk-badkey1234567890" >/dev/null
    export FAKE_HTTP_CODE="401"
    run ai_smoke_check
    [ "$status" -ne 0 ]
    [[ "$output" == *"401"* ]]
}

@test "ai_smoke_check: cloud provider without a key is skipped" {
    set_ai_provider "openai" >/dev/null
    run ai_smoke_check
    [ "$status" -ne 0 ]
    [[ "$output" == *"key"* ]]
}

# ===== ollama_list_models CLI fallback =====

@test "ollama_list_models: falls back to the ollama CLI when HTTP fails" {
    # Empty HTTP response + a working `ollama list` CLI — the second
    # liveness channel must supply the model names (header row skipped).
    cat > "${FAKE_BIN}/ollama" <<'EOS'
#!/usr/bin/env bash
printf 'NAME              ID          SIZE    MODIFIED\n'
printf 'qwen3:8b          abc123      5.2 GB  2 days ago\n'
printf 'llama3.3:8b       def456      4.9 GB  3 weeks ago\n'
EOS
    chmod +x "${FAKE_BIN}/ollama"
    FAKE_TAGS_JSON="" run ollama_list_models
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "qwen3:8b" ]
    [ "${lines[1]}" = "llama3.3:8b" ]
}

@test "ollama_list_models: fails when both HTTP and CLI channels are dead" {
    cat > "${FAKE_BIN}/ollama" <<'EOS'
#!/usr/bin/env bash
exit 1
EOS
    chmod +x "${FAKE_BIN}/ollama"
    FAKE_TAGS_JSON="" run ollama_list_models
    [ "$status" -ne 0 ]
    [ -z "$output" ]
}
