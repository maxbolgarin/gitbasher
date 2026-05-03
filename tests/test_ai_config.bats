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

@test "set_ai_api_key: persists to git config" {
    set_ai_api_key "my-test-key" >/dev/null
    val=$(git config --local --get gitbasher.ai-api-key)
    [ "$val" = "my-test-key" ]
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
