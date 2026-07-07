#!/usr/bin/env bats

# Tests for the live model-listing helpers in ai.sh:
#   - _parse_model_ids_json (jq and grep/sed fallback paths)
#   - openrouter_list_models (public /models endpoint, server-side sort)
#   - openai_list_models (authenticated /v1/models, chat filter, created sort)
# No real network: curl is stubbed on PATH; canned bodies come via env vars.

load setup_suite

OPENROUTER_MODELS_JSON='{"data":[{"id":"google/gemini-3.5-flash","created":100},{"id":"openai/gpt-5.4-mini","created":90},{"id":"anthropic/claude-haiku-4.5","created":80}]}'
OPENAI_MODELS_JSON='{"data":[{"id":"gpt-4o","created":100},{"id":"text-embedding-3-small","created":300},{"id":"gpt-5.4-mini","created":250},{"id":"whisper-1","created":260},{"id":"o4-mini","created":240},{"id":"dall-e-3","created":230},{"id":"gpt-5.5","created":270}]}'

setup() {
    export GIT_CONFIG_GLOBAL=/dev/null
    setup_test_repo
    source_gitbasher_lite
    source "${GITBASHER_ROOT}/scripts/ai.sh"
    cd "$TEST_REPO"
    unset GITB_AI_API_KEY GITB_AI_API_KEY_OPENAI GITB_AI_API_KEY_OPENROUTER

    FAKE_BIN=$(mktemp -d)
    export FAKE_BIN
    cat > "${FAKE_BIN}/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s' "${FAKE_MODELS_JSON:-}"
exit 0
EOF
    chmod +x "${FAKE_BIN}/curl"
    PATH="${FAKE_BIN}:$PATH"
    export PATH
}

teardown() {
    [ -n "$FAKE_BIN" ] && rm -rf "$FAKE_BIN"
    cleanup_test_repo
}

# ===== _parse_model_ids_json =====

@test "_parse_model_ids_json: extracts ids preserving server order (jq path)" {
    run bash -c "printf '%s' '$OPENROUTER_MODELS_JSON' | { source '$GITBASHER_ROOT/scripts/common.sh' 2>/dev/null; GITBASHER_SKIP_INIT_QUERIES=1 source '$GITBASHER_ROOT/scripts/init.sh' 2>/dev/null; source '$GITBASHER_ROOT/scripts/ai.sh'; _parse_model_ids_json; }"
    [ "${lines[0]}" = "google/gemini-3.5-flash" ]
    [ "${lines[1]}" = "openai/gpt-5.4-mini" ]
    [ "${lines[2]}" = "anthropic/claude-haiku-4.5" ]
}

@test "_parse_model_ids_json: grep/sed fallback works without jq" {
    # /usr/bin:/bin carries grep/sed but no jq (jq lives in the package
    # manager prefix), forcing the fallback branch.
    run bash -c "PATH=/usr/bin:/bin; printf '%s' '$OPENROUTER_MODELS_JSON' | { source '$GITBASHER_ROOT/scripts/common.sh' 2>/dev/null; GITBASHER_SKIP_INIT_QUERIES=1 source '$GITBASHER_ROOT/scripts/init.sh' 2>/dev/null; source '$GITBASHER_ROOT/scripts/ai.sh'; _parse_model_ids_json; }"
    [ "${lines[0]}" = "google/gemini-3.5-flash" ]
    [ "${lines[1]}" = "openai/gpt-5.4-mini" ]
    [ "${lines[2]}" = "anthropic/claude-haiku-4.5" ]
}

# ===== openrouter_list_models =====

@test "openrouter_list_models: prints server-sorted ids" {
    FAKE_MODELS_JSON="$OPENROUTER_MODELS_JSON" run openrouter_list_models top-weekly
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "google/gemini-3.5-flash" ]
    [ "${#lines[@]}" -eq 3 ]
}

@test "openrouter_list_models: unreachable endpoint returns 1 silently" {
    FAKE_MODELS_JSON="" run openrouter_list_models top-weekly
    [ "$status" -ne 0 ]
    [ -z "$output" ]
}

# ===== openai_list_models =====

@test "openai_list_models: requires a key" {
    FAKE_MODELS_JSON="$OPENAI_MODELS_JSON" run openai_list_models
    [ "$status" -ne 0 ]
    [ -z "$output" ]
}

@test "openai_list_models: filters to chat models sorted newest first" {
    git config gitbasher.ai-provider openai
    git config gitbasher.ai-api-key-openai "sk-test-1234"
    FAKE_MODELS_JSON="$OPENAI_MODELS_JSON" run openai_list_models
    [ "$status" -eq 0 ]
    # Newest chat model first (created 270 > 250 > 240 > 100); embeddings,
    # whisper, and dall-e ids are gone.
    [ "${lines[0]}" = "gpt-5.5" ]
    [ "${lines[1]}" = "gpt-5.4-mini" ]
    [ "${lines[2]}" = "o4-mini" ]
    [ "${lines[3]}" = "gpt-4o" ]
    [ "${#lines[@]}" -eq 4 ]
}
