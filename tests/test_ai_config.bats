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

# ===== get_ai_model / set_ai_model — one model per provider =====

@test "get_ai_model: returns empty when not set" {
    val=$(get_ai_model)
    [ -z "$val" ]
}

@test "set_ai_model: persists override in the active provider's slot" {
    git config gitbasher.ai-provider openrouter
    set_ai_model "openai/gpt-4o" >/dev/null
    [ "$(get_ai_model)" = "openai/gpt-4o" ]
    [ "$(git config --local --get gitbasher.ai-model-openrouter)" = "openai/gpt-4o" ]
}

@test "get_ai_model: legacy gitbasher.ai-model is honored as a fallback" {
    git config gitbasher.ai-model "legacy-model"
    [ "$(get_ai_model)" = "legacy-model" ]
}

@test "get_ai_model: per-provider slot beats the legacy key" {
    git config gitbasher.ai-provider openrouter
    git config gitbasher.ai-model "legacy-model"
    git config gitbasher.ai-model-openrouter "provider-model"
    [ "$(get_ai_model)" = "provider-model" ]
}

@test "resolve_ai_model: falls back to the provider default when nothing set" {
    git config gitbasher.ai-provider openrouter
    [ "$(resolve_ai_model)" = "$AI_DEFAULT_MODEL_OPENROUTER" ]
    git config gitbasher.ai-provider openai
    [ "$(resolve_ai_model)" = "$AI_DEFAULT_MODEL_OPENAI" ]
    git config gitbasher.ai-provider ollama
    [ "$(resolve_ai_model)" = "$AI_DEFAULT_MODEL_OLLAMA" ]
    git config gitbasher.ai-provider claude
    [ "$(resolve_ai_model)" = "$AI_DEFAULT_MODEL_CLAUDE" ]
}

@test "model per provider: each provider remembers its own model" {
    git config gitbasher.ai-provider openrouter
    set_ai_model "google/gemini-3.5-flash" >/dev/null
    git config gitbasher.ai-provider claude
    set_ai_model "sonnet" >/dev/null
    # Switching back restores each provider's own selection
    git config gitbasher.ai-provider openrouter
    [ "$(resolve_ai_model)" = "google/gemini-3.5-flash" ]
    git config gitbasher.ai-provider claude
    [ "$(resolve_ai_model)" = "sonnet" ]
}

@test "regression: model set under openrouter must not leak into claude" {
    # The exact user-reported break: an OpenRouter model in the legacy key,
    # then a provider switch to claude — every `claude -p --model <slug>`
    # call failed. The switch must attribute the legacy model to the
    # outgoing provider so claude starts on its own default.
    git config gitbasher.ai-provider openrouter
    git config gitbasher.ai-model "anthropic/claude-haiku-4.5"
    migrate_legacy_ai_model_to "openrouter" 2>/dev/null
    git config gitbasher.ai-provider claude
    [ "$(resolve_ai_model)" = "$AI_DEFAULT_MODEL_CLAUDE" ]
    # ... and the OpenRouter selection survives for when the user switches back
    git config gitbasher.ai-provider openrouter
    [ "$(resolve_ai_model)" = "anthropic/claude-haiku-4.5" ]
    [ -z "$(git config --local --get gitbasher.ai-model)" ]
}

@test "migrate_legacy_ai_model_to: never clobbers an explicit per-provider model" {
    git config gitbasher.ai-model "legacy-model"
    git config gitbasher.ai-model-openrouter "explicit-model"
    migrate_legacy_ai_model_to "openrouter" 2>/dev/null
    [ "$(git config --local --get gitbasher.ai-model-openrouter)" = "explicit-model" ]
    # Legacy must still get cleared so it can't shadow other providers later
    [ -z "$(git config --local --get gitbasher.ai-model)" ]
}

@test "list_providers_with_model: ignores stale pre-5.1 per-task keys" {
    git config gitbasher.ai-model-openrouter "m1"
    git config gitbasher.ai-model-full "stale-per-task"
    run list_providers_with_model
    [[ "$output" == *"openrouter"* ]]
    [[ "$output" != *"full"* ]]
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

@test "get_ai_api_url: ollama provider builds URL from default host" {
    set_ai_provider "ollama" >/dev/null
    [ "$(get_ai_api_url)" = "${AI_DEFAULT_OLLAMA_HOST}/v1/chat/completions" ]
}

@test "get_ai_api_url: defaults to OpenRouter when provider unset" {
    [ "$(get_ai_api_url)" = "$OPENROUTER_API_URL" ]
}
