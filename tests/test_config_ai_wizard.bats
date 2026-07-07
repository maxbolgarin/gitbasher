#!/usr/bin/env bats

# `gitb cfg ai` is a multi-step wizard: provider → API key → model → summary.
# The standalone configure_* steps gained a --chained mode that turns their
# exits into returns so the wizard can keep going; these tests pin both the
# chaining behavior and the untouched standalone semantics.

load setup_suite

setup() {
    setup_test_repo
    source_gitbasher
    cd "$TEST_REPO"

    current_branch="main"
    main_branch="main"
    origin_name=""
}

teardown() {
    cleanup_test_repo
}

with_timeout() {
    perl -e 'alarm 10; exec @ARGV' -- "$@"
}

# Child-shell wrapper: sources the production chain with an isolated global
# config, then runs the given statements. curl is stubbed to fail fast so no
# test ever hits the real network — the model step's live catalog fetch (and
# any smoke check) degrades gracefully, exactly like running offline. Tests
# that WANT a live-looking endpoint prepend their own richer curl stub in the
# extra statements (a later PATH prepend wins), see model_menu_script.
wizard_script() {
    local nonet_bin="$BATS_TEST_TMPDIR/nonet-bin"
    mkdir -p "$nonet_bin"
    printf '#!/usr/bin/env bash\nexit 7\n' > "$nonet_bin/curl"
    chmod +x "$nonet_bin/curl"
    printf '%s' "
        export PATH='$nonet_bin':\$PATH
        export GIT_CONFIG_GLOBAL='$BATS_TEST_TMPDIR/gitconfig-global'
        source '$GITBASHER_ROOT/scripts/common.sh' 2>/dev/null
        GITBASHER_SKIP_INIT_QUERIES=1 source '$GITBASHER_ROOT/scripts/init.sh' 2>/dev/null
        source '$GITBASHER_ROOT/scripts/ai.sh'
        source '$GITBASHER_ROOT/scripts/config.sh'
        cd '$TEST_REPO'
        project_name=test
        ${1:-}
    "
}

# ===== the wizard =====

@test "wizard: Enter skips every step and prints the summary" {
    run with_timeout bash -c "$(wizard_script 'configure_ai_wizard')" <<< $'\n\n\n'
    [ "$status" -eq 0 ]
    [[ "$output" == *"Step 1/3"* ]]
    [[ "$output" == *"Step 2/3"* ]]
    [[ "$output" == *"Step 3/3"* ]]
    [[ "$output" == *"AI setup complete"* ]]
    [[ "$output" == *"AI provider:"* ]]
    [ -z "$(git config --get gitbasher.ai-provider)" ]
    [ -z "$(git config --get gitbasher.ai-model)" ]
}

@test "wizard: provider choice proceeds into the key step (core chaining)" {
    # 2 = openai, n = not global, then Enter skips key and model steps
    run with_timeout bash -c "$(wizard_script 'configure_ai_wizard')" <<< $'2\nn\n\n\n'
    [ "$status" -eq 0 ]
    [ "$(git config --get gitbasher.ai-provider)" = "openai" ]
    [[ "$output" == *"Enter AI API key for provider 'openai'"* ]]
    [[ "$output" == *"AI setup complete"* ]]
}

@test "wizard: keyless provider skips the key step with a message" {
    git config gitbasher.ai-provider ollama
    # Enter keeps ollama, then Enter skips the model step
    run with_timeout bash -c "$(wizard_script 'configure_ai_wizard')" <<< $'\n\n'
    [ "$status" -eq 0 ]
    [[ "$output" == *"does not require an API key — skipping"* ]]
    [[ "$output" != *"Storage options"* ]]
    [[ "$output" == *"AI setup complete"* ]]
}

@test "wizard: EOF aborts non-zero without writing anything" {
    run with_timeout bash -c "$(wizard_script 'configure_ai_wizard')" < /dev/null
    [ "$status" -ne 142 ]
    [ "$status" -ne 0 ]
    [[ "$output" != *"AI setup complete"* ]]
    [ -z "$(git config --get gitbasher.ai-provider)" ]
}

@test "wizard: declining the global prompt does not kill the wizard" {
    # Step 1: Enter (keep provider). Step 2: Enter (skip key — default
    # provider needs one, storage prompt: n -> git config path, Enter skips).
    # Step 3: type a model, n to the global prompt — summary must still print.
    # Feed: Enter (keep provider) | 'n' to env-var storage (its newline is
    # consumed by the hidden key read = skip key) | model id | 'y' to keep it
    # despite the smoke test failing (curl is stubbed dead in wizard_script,
    # so the live model check cannot pass) | 'n' to global.
    run with_timeout bash -c "$(wizard_script 'configure_ai_wizard')" <<< $'\nn\nsome/model-id\nyn'
    [ "$status" -eq 0 ]
    [[ "$output" == *"AI setup complete"* ]]
    # Stored in the active provider's slot (default provider = openrouter)
    [ "$(git config --get gitbasher.ai-model-openrouter)" = "some/model-id" ]
    [ ! -f "$BATS_TEST_TMPDIR/gitconfig-global" ] || \
        [ -z "$(GIT_CONFIG_GLOBAL="$BATS_TEST_TMPDIR/gitconfig-global" git config --global --get gitbasher.ai-model-openrouter)" ]
}

@test "wizard: switching provider keeps the old provider's model (no leak)" {
    # The user-reported break: a model chosen under openrouter leaked into
    # the claude provider after a switch and every AI call failed. The
    # switch must move the legacy model to the outgoing provider's slot.
    git config gitbasher.ai-provider openrouter
    git config gitbasher.ai-model "google/gemini-3.5-flash"
    # A working fake claude CLI so the provider smoke check passes on
    # machines without the real one (a failed check would prompt to revert).
    mkdir -p "$BATS_TEST_TMPDIR/fakeclaude"
    printf '#!/usr/bin/env bash\necho "9.9.9 (Claude Code)"\n' > "$BATS_TEST_TMPDIR/fakeclaude/claude"
    chmod +x "$BATS_TEST_TMPDIR/fakeclaude/claude"
    # 4 = claude | n = not global | Enter keeps the model default
    run with_timeout bash -c "$(wizard_script "export PATH='$BATS_TEST_TMPDIR/fakeclaude':\$PATH
        configure_ai_wizard")" <<< $'4\nn\n\n'
    [ "$status" -eq 0 ]
    [[ "$output" == *"AI setup complete"* ]]
    [ "$(git config --get gitbasher.ai-provider)" = "claude" ]
    [ -z "$(git config --get gitbasher.ai-model)" ]
    [ -z "$(git config --get gitbasher.ai-model-claude)" ]
    [ "$(git config --get gitbasher.ai-model-openrouter)" = "google/gemini-3.5-flash" ]
}

@test "wizard: existing key offers one-keystroke keep and proceeds" {
    git config gitbasher.ai-provider openrouter
    git config gitbasher.ai-api-key-openrouter "sk-test-key-1234567890abcdef"
    # Enter (keep provider) | Enter (keep key) | Enter (skip model)
    run with_timeout bash -c "$(wizard_script 'configure_ai_wizard')" <<< $'\n\n\n'
    [ "$status" -eq 0 ]
    [[ "$output" == *"keep it"* ]]
    [[ "$output" == *"Keeping the existing key."* ]]
    [[ "$output" != *"Storage options"* ]]
    [[ "$output" == *"AI setup complete"* ]]
    [ "$(git config --get gitbasher.ai-api-key-openrouter)" = "sk-test-key-1234567890abcdef" ]
}

@test "cfg key: 0 at the keep prompt removes the existing key" {
    git config gitbasher.ai-provider openrouter
    git config gitbasher.ai-api-key-openrouter "sk-test-key-1234567890abcdef"
    run with_timeout bash -c "$(wizard_script 'config_script key')" <<< "0"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Removed AI API key"* ]]
    [ -z "$(git config --get gitbasher.ai-api-key-openrouter)" ]
}

@test "cfg key: r at the keep prompt continues into key entry" {
    git config gitbasher.ai-provider openrouter
    git config gitbasher.ai-api-key-openrouter "sk-test-key-1234567890abcdef"
    # r (replace) | n (env-var question, its newline feeds the hidden
    # input = keep silently) — key must survive since entry was skipped
    run with_timeout bash -c "$(wizard_script 'config_script key')" <<< $'rn\n'
    [ "$status" -eq 0 ]
    [[ "$output" == *"Storage options"* ]]
    [ "$(git config --get gitbasher.ai-api-key-openrouter)" = "sk-test-key-1234567890abcdef" ]
}

# ===== standalone behavior is unchanged =====

@test "standalone cfg provider: Enter exits without running other steps" {
    run with_timeout bash -c "$(wizard_script 'configure_ai_provider')" <<< $'\n'
    [ "$status" -eq 0 ]
    [[ "$output" != *"Step 2/3"* ]]
    [[ "$output" != *"Configure AI Model"* ]]
}

@test "standalone cfg model: Enter exits without changes" {
    run with_timeout bash -c "$(wizard_script 'configure_ai_model')" <<< $'\n'
    [ "$status" -eq 0 ]
    [ -z "$(git config --get gitbasher.ai-model)" ]
    [ -z "$(git config --get gitbasher.ai-model-openrouter)" ]
}

# ===== dispatch routing =====

@test "config_script ai routes to the wizard" {
    run with_timeout bash -c "$(wizard_script 'config_script ai')" <<< $'\n\n\n'
    [ "$status" -eq 0 ]
    [[ "$output" == *"AI SETUP"* ]]
    [[ "$output" == *"Step 1/3"* ]]
}

@test "config_script key routes to the key-only flow" {
    git config gitbasher.ai-provider openrouter
    run with_timeout bash -c "$(wizard_script 'config_script key')" <<< $'n\n\n'
    [ "$status" -eq 0 ]
    [[ "$output" == *"AI API KEY"* ]]
    [[ "$output" != *"Step 1/3"* ]]
}

# ===== summary extraction =====

@test "print_ai_configuration renders the AI rows of print_configuration" {
    run bash -c "$(wizard_script 'print_ai_configuration')"
    [ "$status" -eq 0 ]
    [[ "$output" == *"AI provider:"* ]]
    [[ "$output" == *"AI key:"* ]]
    [[ "$output" == *"AI model"* ]]
    # And the full table still contains the same rows after the extraction
    run bash -c "$(wizard_script 'print_configuration')"
    [[ "$output" == *"AI provider:"* ]]
    [[ "$output" == *"AI proxy:"* ]]
}

# ===== cfg model: live menu, validation, and the post-set smoke test =====
# curl is stubbed inside the child shell: GET /models?sort=… returns a canned
# id list, the smoke-check POST returns a completion (or dies with
# FAKE_AI_FAIL=1). The stub only ever reads stdin on the POST branch.

# $1: statements to run (default configure_ai_model); $2: provider (default openrouter)
model_menu_script() {
    local fake_bin="$BATS_TEST_TMPDIR/fakebin"
    mkdir -p "$fake_bin"
    cat > "$fake_bin/curl" <<'EOF'
#!/usr/bin/env bash
args="$*"
case "$args" in
    *"models?sort=top-weekly"*)
        printf '{"data":[{"id":"google/gemini-3.5-flash"},{"id":"openai/gpt-5.4-mini"},{"id":"anthropic/claude-haiku-4.5"}]}' ;;
    *"models?sort=newest"*)
        printf '{"data":[{"id":"newvendor/brand-new-model"}]}' ;;
    *"api.openai.com/v1/models"*)
        cat >/dev/null
        printf '{"data":[{"id":"gpt-5.5","created":300},{"id":"gpt-5.5-2026-04-23","created":300},{"id":"gpt-5.4-mini","created":250},{"id":"gpt-5.4-mini-2026-03-17","created":250}]}' ;;
    *)
        cat >/dev/null
        if [ -n "$FAKE_AI_FAIL" ]; then exit 7; fi
        printf '{"choices":[{"message":{"content":"OK"}}]}' ;;
esac
EOF
    chmod +x "$fake_bin/curl"
    local provider="${2:-openrouter}"
    wizard_script "export PATH='$fake_bin':\$PATH
        git config gitbasher.ai-provider $provider
        git config gitbasher.ai-api-key-$provider sk-test-1234
        ${1:-configure_ai_model}"
}

@test "cfg model: openrouter live menu pick by number stores and smoke-passes" {
    # 2 = openai/gpt-5.4-mini from the popular section | n = not global
    run with_timeout bash -c "$(model_menu_script)" <<< $'2\nn'
    [ "$status" -eq 0 ]
    [[ "$output" == *"Most used on OpenRouter this week"* ]]
    [[ "$output" == *"Newest"* ]]
    [[ "$output" == *"✓ Model 'openai/gpt-5.4-mini' responded"* ]]
    [ "$(git config --get gitbasher.ai-model-openrouter)" = "openai/gpt-5.4-mini" ]
}

@test "cfg model: typed id not in the live catalog warns and n aborts" {
    run with_timeout bash -c "$(model_menu_script)" <<< $'not/in-list\nn'
    [ "$status" -ne 0 ]
    [[ "$output" == *"not in openrouter's current model list"* ]]
    [ -z "$(git config --get gitbasher.ai-model-openrouter)" ]
}

@test "cfg model: typed id not in catalog saves anyway on y" {
    FAKE_AI_FAIL="" run with_timeout bash -c "$(model_menu_script)" <<< $'not/in-list\nyn'
    [ "$status" -eq 0 ]
    [ "$(git config --get gitbasher.ai-model-openrouter)" = "not/in-list" ]
}

@test "cfg model: failing smoke test with n restores the previous model" {
    git config gitbasher.ai-model-openrouter "old/model"
    FAKE_AI_FAIL=1 run with_timeout bash -c "$(model_menu_script)" <<< $'google/gemini-3.5-flash\nn'
    [ "$status" -ne 0 ]
    [[ "$output" == *"did not respond"* ]]
    [[ "$output" == *"Restored previous model 'old/model'"* ]]
    [ "$(git config --get gitbasher.ai-model-openrouter)" = "old/model" ]
}

@test "cfg model: openai menu hides dated snapshots but they stay typeable" {
    # Dated snapshot ids (gpt-5.4-mini-2026-03-17) are aliases of the base
    # model — hidden from the menu as noise, but still in the validation
    # catalog so pinning one by hand works without a warning.
    run with_timeout bash -c "$(model_menu_script '' openai)" <<< $'gpt-5.4-mini-2026-03-17\nn'
    [ "$status" -eq 0 ]
    [[ "$output" == *"Newest chat models on your OpenAI account"* ]]
    [[ "$output" == *"gpt-5.5"* ]]
    [[ "$output" != *"2026-04-23"* ]]
    [[ "$output" != *"not in openai's current model list"* ]]
    [ "$(git config --get gitbasher.ai-model-openai)" = "gpt-5.4-mini-2026-03-17" ]
}

# ===== cfg provider: failed local-provider probe asks before moving on =====
# curl is dead in wizard_script, so the Ollama reachability check always
# fails — exactly the "chose ollama but the daemon isn't running" situation.

@test "cfg provider: unreachable ollama with n reverts the provider" {
    # 3 = ollama | Enter keeps default host | n = don't keep a dead provider
    run with_timeout bash -c "$(wizard_script 'configure_ai_provider')" <<< $'3\n\nn'
    [ "$status" -ne 0 ]
    [[ "$output" == *"not reachable"* ]]
    [[ "$output" == *"Keep 'ollama' as the AI provider anyway"* ]]
    [[ "$output" == *"Provider unchanged"* ]]
    [ -z "$(git config --local --get gitbasher.ai-provider)" ]
}

@test "cfg provider: unreachable ollama with y keeps it (setup-before-daemon)" {
    # 3 = ollama | Enter keeps default host | y = keep anyway | n = not global
    run with_timeout bash -c "$(wizard_script 'configure_ai_provider')" <<< $'3\n\nyn'
    [ "$status" -eq 0 ]
    [[ "$output" == *"Keep 'ollama' as the AI provider anyway"* ]]
    [ "$(git config --local --get gitbasher.ai-provider)" = "ollama" ]
}

@test "cfg provider: Enter at the keep prompt declines (y/N default is No)" {
    # The reported bug: Enter fell through as YES (is_yes treats empty as
    # yes for (Y/n) prompts) and a dead provider marched on to the global
    # question. (y/N) must require an explicit y.
    run with_timeout bash -c "$(wizard_script 'configure_ai_provider')" <<< $'3\n\n\n'
    [ "$status" -ne 0 ]
    [[ "$output" == *"Provider unchanged"* ]]
    [[ "$output" != *"globally"* ]]
    [ -z "$(git config --local --get gitbasher.ai-provider)" ]
}

@test "cfg model: Enter at save-anyway declines (y/N default is No)" {
    run with_timeout bash -c "$(model_menu_script)" <<< $'not/in-list\n\n'
    [ "$status" -ne 0 ]
    [[ "$output" == *"Not saved"* ]]
    [ -z "$(git config --get gitbasher.ai-model-openrouter)" ]
}

@test "wizard: declining a dead provider stops the wizard entirely" {
    # The user-reported flow: choose unreachable ollama, answer n at the
    # keep prompt — the wizard must NOT continue into the key and model
    # steps for the restored provider; it stops with nothing changed.
    git config gitbasher.ai-provider openai
    git config gitbasher.ai-api-key-openai "sk-test-1234"
    run with_timeout bash -c "$(wizard_script 'configure_ai_wizard')" <<< $'3\n\nn'
    [ "$status" -eq 0 ]
    [[ "$output" == *"Provider unchanged"* ]]
    [[ "$output" == *"AI setup stopped"* ]]
    [[ "$output" != *"Step 2/3"* ]]
    [[ "$output" != *"AI setup complete"* ]]
    [ "$(git config --get gitbasher.ai-provider)" = "openai" ]
}

@test "cfg model: claude aliases are a numbered menu, pick by number" {
    run with_timeout bash -c "$(wizard_script "git config gitbasher.ai-provider claude
        configure_ai_model")" <<< $'2\nn'
    [ "$status" -eq 0 ]
    [[ "$output" == *"1. haiku"* ]]
    [[ "$output" == *"2. sonnet"* ]]
    [[ "$output" == *"3. opus"* ]]
    [ "$(git config --get gitbasher.ai-model-claude)" = "sonnet" ]
}

@test "cfg model: offline ollama falls back to a numbered suggestion menu" {
    # curl and the ollama CLI are both dead in wizard_script — the static
    # suggestions must still be selectable by number.
    run with_timeout bash -c "$(wizard_script "printf '#!/usr/bin/env bash\nexit 1\n' > '$BATS_TEST_TMPDIR/nonet-bin/ollama'
        chmod +x '$BATS_TEST_TMPDIR/nonet-bin/ollama'
        git config gitbasher.ai-provider ollama
        configure_ai_model")" <<< $'1\nn'
    [ "$status" -eq 0 ]
    [[ "$output" == *"No models found"* ]]
    [[ "$output" == *"1. qwen3:8b"* ]]
    [ "$(git config --get gitbasher.ai-model-ollama)" = "qwen3:8b" ]
}
