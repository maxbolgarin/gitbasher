#!/usr/bin/env bats

# Tests for AI config getters/setters and helpers in ai.sh.
# These verify config persistence and default-value handling without
# making any real API calls.

load setup_suite

setup() {
    export GIT_CONFIG_GLOBAL=/dev/null
    setup_test_repo
    source_gitbasher
    source "${GITBASHER_ROOT}/scripts/ai.sh"
    cd "$TEST_REPO"
    # Clear any inherited env that would leak into get_ai_api_key
    unset GITB_AI_API_KEY
}

teardown() {
    cleanup_test_repo
}

# ===== get_ai_api_key / set_ai_api_key =====

@test "get_ai_api_key: returns empty when not set" {
    val=$(get_ai_api_key)
    [ -z "$val" ]
}

@test "get_ai_api_key: prefers env var over git config" {
    set_ai_api_key "config-key" >/dev/null
    GITB_AI_API_KEY="env-key"
    val=$(GITB_AI_API_KEY="env-key" get_ai_api_key)
    [ "$val" = "env-key" ]
}

@test "get_ai_api_key: reads from git config when env not set" {
    set_ai_api_key "stored-key" >/dev/null
    val=$(get_ai_api_key)
    [ "$val" = "stored-key" ]
}

@test "set_ai_api_key: persists to per-provider git config slot" {
    set_ai_api_key "my-test-key" >/dev/null
    # Default provider when nothing is set is openrouter — set_ai_api_key
    # writes to the per-provider slot so switching providers doesn't reuse
    # a key meant for another one.
    val=$(git config --local --get gitbasher.ai-api-key-openrouter)
    [ "$val" = "my-test-key" ]
    # Legacy slot must remain untouched
    [ -z "$(git config --local --get gitbasher.ai-api-key)" ]
}

@test "get_ai_api_key: per-provider config wins over legacy config" {
    git config --local gitbasher.ai-api-key "legacy-key"
    git config --local gitbasher.ai-api-key-openrouter "provider-key"
    val=$(get_ai_api_key)
    [ "$val" = "provider-key" ]
}

@test "get_ai_api_key: switching provider isolates per-provider keys" {
    git config --local gitbasher.ai-api-key-openrouter "or-key"
    git config --local gitbasher.ai-api-key-openai "oa-key"
    git config --local gitbasher.ai-provider "openrouter"
    [ "$(get_ai_api_key)" = "or-key" ]
    git config --local gitbasher.ai-provider "openai"
    [ "$(get_ai_api_key)" = "oa-key" ]
}

@test "get_ai_api_key: per-provider env var beats legacy env var" {
    GITB_AI_API_KEY="legacy-env"
    GITB_AI_API_KEY_OPENROUTER="prov-env"
    val=$(GITB_AI_API_KEY="legacy-env" GITB_AI_API_KEY_OPENROUTER="prov-env" get_ai_api_key)
    [ "$val" = "prov-env" ]
}

@test "migrate_legacy_ai_api_key_to: moves legacy local key to per-provider slot" {
    git config --local gitbasher.ai-api-key "stale-or-key"
    migrate_legacy_ai_api_key_to "openrouter" 2>/dev/null
    [ "$(git config --local --get gitbasher.ai-api-key-openrouter)" = "stale-or-key" ]
    [ -z "$(git config --local --get gitbasher.ai-api-key)" ]
}

@test "migrate_legacy_ai_api_key_to: does not clobber an existing per-provider key" {
    git config --local gitbasher.ai-api-key "legacy-key"
    git config --local gitbasher.ai-api-key-openrouter "explicit-key"
    migrate_legacy_ai_api_key_to "openrouter" 2>/dev/null
    [ "$(git config --local --get gitbasher.ai-api-key-openrouter)" = "explicit-key" ]
    # Legacy must still get cleared so it can't shadow other providers later
    [ -z "$(git config --local --get gitbasher.ai-api-key)" ]
}

# ===== get_ai_model / set_ai_model =====

@test "get_ai_model: returns empty when not set" {
    val=$(get_ai_model)
    [ -z "$val" ]
}

@test "set_ai_model: persists override" {
    set_ai_model "openai/gpt-4o" >/dev/null
    val=$(get_ai_model)
    [ "$val" = "openai/gpt-4o" ]
}

# ===== get_ai_model_for =====

@test "get_ai_model_for: returns simple default when nothing set" {
    val=$(get_ai_model_for "simple")
    [ -n "$val" ]
}

@test "get_ai_model_for: returns full default when nothing set" {
    val=$(get_ai_model_for "full")
    [ -n "$val" ]
}

@test "get_ai_model_for: returns grouping default when nothing set" {
    val=$(get_ai_model_for "grouping")
    [ -n "$val" ]
}

@test "get_ai_model_for: per-task override beats global" {
    set_ai_model "global-model" >/dev/null
    set_ai_model_for "simple" "task-model" >/dev/null
    val=$(get_ai_model_for "simple")
    [ "$val" = "task-model" ]
}

@test "get_ai_model_for: global override applies when no per-task override" {
    set_ai_model "global-model" >/dev/null
    val=$(get_ai_model_for "subject")
    [ "$val" = "global-model" ]
}

@test "get_ai_model_for: unknown task falls back to simple default" {
    val=$(get_ai_model_for "unknown")
    simple_val=$(get_ai_model_for "simple")
    [ "$val" = "$simple_val" ]
}

# ===== get_ai_proxy / set_ai_proxy =====

@test "get_ai_proxy: returns empty by default" {
    val=$(get_ai_proxy)
    [ -z "$val" ]
}

@test "set_ai_proxy: persists value" {
    set_ai_proxy "http://proxy.example.com:8080" >/dev/null
    val=$(get_ai_proxy)
    [ "$val" = "http://proxy.example.com:8080" ]
}

# ===== Diff limits =====

@test "get_ai_diff_limit: returns default of 300" {
    val=$(get_ai_diff_limit)
    [ "$val" = "300" ]
}

@test "set_ai_diff_limit: persists custom value" {
    set_ai_diff_limit "500" >/dev/null
    val=$(get_ai_diff_limit)
    [ "$val" = "500" ]
}

@test "get_ai_diff_max_chars: returns default of 20000" {
    val=$(get_ai_diff_max_chars)
    [ "$val" = "20000" ]
}

@test "set_ai_diff_max_chars: persists custom value" {
    set_ai_diff_max_chars "30000" >/dev/null
    val=$(get_ai_diff_max_chars)
    [ "$val" = "30000" ]
}

@test "generate_ai_commit_message includes rejected messages when regenerating" {
    create_test_file "feature.txt" "new feature"
    git add feature.txt

    call_ai_api() {
        printf '%s' "$2"
    }

    run generate_ai_commit_message "simple" "" "" "" "refactor: reuse previous subject"

    assert_success
    [[ "$output" == *"<rejected_commit_messages>"* ]]
    [[ "$output" == *"refactor: reuse previous subject"* ]]
    [[ "$output" == *"Do not repeat"* ]]
}

@test "get_ai_commit_history_limit: returns default of 10" {
    val=$(get_ai_commit_history_limit)
    [ "$val" = "10" ]
}

@test "set_ai_commit_history_limit: persists custom value" {
    set_ai_commit_history_limit "20" >/dev/null
    val=$(get_ai_commit_history_limit)
    [ "$val" = "20" ]
}

# ===== ai_provider_requires_api_key =====

@test "ai_provider_requires_api_key: returns 1 for ollama" {
    set_ai_provider "ollama" >/dev/null
    run ai_provider_requires_api_key
    [ "$status" -eq 1 ]
}

@test "ai_provider_requires_api_key: returns 0 for openai" {
    set_ai_provider "openai" >/dev/null
    run ai_provider_requires_api_key
    [ "$status" -eq 0 ]
}

@test "ai_provider_requires_api_key: returns 0 for openrouter (default)" {
    run ai_provider_requires_api_key
    [ "$status" -eq 0 ]
}

# ===== get_ai_api_url =====

@test "get_ai_api_url: custom base URL wins over provider default" {
    set_ai_provider "openai" >/dev/null
    set_ai_base_url "https://example.test/v1/chat/completions" >/dev/null
    [ "$(get_ai_api_url)" = "https://example.test/v1/chat/completions" ]
}

@test "get_ai_api_url: openai provider returns OpenAI URL" {
    set_ai_provider "openai" >/dev/null
    [ "$(get_ai_api_url)" = "$OPENAI_API_URL" ]
}

@test "get_ai_api_url: ollama provider returns Ollama URL" {
    set_ai_provider "ollama" >/dev/null
    [ "$(get_ai_api_url)" = "$OLLAMA_API_URL" ]
}

@test "get_ai_api_url: defaults to OpenRouter when provider unset" {
    [ "$(get_ai_api_url)" = "$OPENROUTER_API_URL" ]
}
