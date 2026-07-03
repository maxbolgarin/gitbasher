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
# config, then runs the given statements.
wizard_script() {
    printf '%s' "
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
    # consumed by the hidden key read = skip key) | model id | 'n' to global.
    run with_timeout bash -c "$(wizard_script 'configure_ai_wizard')" <<< $'\nn\nsome/model-id\nn'
    [ "$status" -eq 0 ]
    [[ "$output" == *"AI setup complete"* ]]
    [ "$(git config --get gitbasher.ai-model)" = "some/model-id" ]
    [ ! -f "$BATS_TEST_TMPDIR/gitconfig-global" ] || \
        [ -z "$(GIT_CONFIG_GLOBAL="$BATS_TEST_TMPDIR/gitconfig-global" git config --global --get gitbasher.ai-model)" ]
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
