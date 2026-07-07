#!/usr/bin/env bash

### Script for configurate gitbasher
# Read README.md to get more information how to use it
# Use this script only with gitbasher because it is using global variables


### Function asks user to select default gitbasher branch
function set_default_branch {
    if [ "$GITBASHER_NO_REPO" = "true" ]; then
        echo -e "${RED}✗ Cannot pick a default branch outside a git repository.${ENDCOLOR}" >&2
        echo -e "Run this inside a repo, or set one directly with ${GREEN}git config --global gitbasher.branch <name>${ENDCOLOR}." >&2
        exit 1
    fi

    echo -e "${YELLOW}Fetching remote branches...${ENDCOLOR}"
    echo

    fetch_output=$(git fetch 2>&1)
    check_code $? "$fetch_output" "fetch remote"

    prune_output=$(git remote prune $origin_name 2>&1)

    echo -e "Current gitbasher default branch: ${YELLOW}$main_branch${ENDCOLOR}"
    echo
    
    echo -e "${YELLOW}Select a branch to make it default in gitbasher${ENDCOLOR}"
    choose_branch "remote"

    echo 

    main_branch=$(set_config_value gitbasher.branch $branch_name)
    echo -e "${GREEN}✓ Set '${branch_name}' as the default gitbasher branch in '${project_name}'${ENDCOLOR}"
    echo

    [ "$GITBASHER_NO_REPO" = "true" ] && exit
    echo -e "Do you want to set it ${YELLOW}globally${ENDCOLOR} for all projects (Y/n)?"
    yes_no_choice "\nSet '${branch_name}' globally" "true"
    main_branch=$(set_config_value gitbasher.branch $branch_name "true")
}


### Function asks user to select branch name separator
function set_sep {
    echo -e "${YELLOW}Select a branch name separator${ENDCOLOR}"
    echo
    echo -e "Separator is a symbol between type and name, e.g. ${YELLOW}name${sep}name${ENDCOLOR}"
    echo -e "Current separator: ${YELLOW}$sep${ENDCOLOR}"
    echo -e "1. type${YELLOW}/${ENDCOLOR}name"
    echo -e "2. type${YELLOW}_${ENDCOLOR}name"
    echo -e "3. type${YELLOW}-${ENDCOLOR}name"
    echo -e "4. type${YELLOW}.${ENDCOLOR}name"
    echo -e "5. type${YELLOW},${ENDCOLOR}name"
    echo -e "6. type${YELLOW}+${ENDCOLOR}name"
    echo -e "7. type${YELLOW}=${ENDCOLOR}name"
    echo -e "8. type${YELLOW}@${ENDCOLOR}name"
    echo "0. Exit"
    
    # Index 0 is an unused placeholder so menu numbers (1-8) map directly to
    # array indices; a plain indexed array keeps this bash 3.2 compatible.
    local -a seps=("" "/" "_" "-" "." "," "+" "=" "@")

    while [ true ]; do
        read -n 1 -s choice || prompt_aborted

        if [ "$choice" == "0" ]; then
            exit
        fi

        re='^[0-9]+$'
        if ! [[ $choice =~ $re ]]; then
            continue
        fi

        new_sep="${seps[$choice]}"
        if [ -n "$new_sep" ]; then
            break
        fi
    done

    echo

    sep=$(set_config_value gitbasher.sep $new_sep)
    echo -e "${GREEN}✓ Set '${sep}' as the branch name separator in '${project_name}'${ENDCOLOR}"
    echo

    [ "$GITBASHER_NO_REPO" = "true" ] && exit
    echo -e "Do you want to set it ${YELLOW}globally${ENDCOLOR} for all projects (Y/n)?"
    yes_no_choice "\nSet '${sep}' globally" "true"
    sep=$(set_config_value gitbasher.sep "$new_sep" "true")
}


### Function asks user to enter editor for commit messages
function set_editor {
    echo -e "${YELLOW}Enter an editor for commit messages${ENDCOLOR}"
    echo
    echo -e "Enter the binary name (e.g. ${BLUE}vi${ENDCOLOR} or ${BLUE}nano${ENDCOLOR}) — overrides ${YELLOW}core.editor${ENDCOLOR}"
    echo -e "Press Enter to exit without changes"
    echo -e "Current editor: ${YELLOW}${editor}${ENDCOLOR}"
    read_editable_input choice "Editor: "

    if [ "$choice" == "" ]; then
        exit
    fi

    # Sanitize editor command input
    if ! sanitize_command "$choice"; then
        show_sanitization_error "editor" "Use letters, numbers, dots, dashes, underscores, slashes, and spaces for flags."
        exit 1
    fi
    choice="$sanitized_command"

    echo

    # Probe only the BINARY (first word): editors are routinely configured
    # with flags ("code --wait", "emacs -nw") and the whole string never
    # resolves as a command.
    editor_binary="${choice%% *}"
    which_output=$(which "$editor_binary")
    if [[ "${which_output}" == *"not found"* ]] || [[ "${which_output}" == "" ]]; then
        echo -e "${RED}✗ Binary '${editor_binary}' not found.${ENDCOLOR}" >&2
        exit 1
    fi

    editor=$(set_config_value core.editor "$choice")
    echo -e "${GREEN}✓ Using editor '$editor' (${which_output})${ENDCOLOR}"
    echo

    [ "$GITBASHER_NO_REPO" = "true" ] && exit
    echo -e "Do you want to set it ${YELLOW}globally${ENDCOLOR} for all projects (Y/n)?"
    yes_no_choice "\nSet '${editor}' globally" "true"
    editor=$(set_config_value core.editor "$choice" "true")
}


### Function asks user to enter ticket name
function set_ticket {
    echo -e "${YELLOW}Enter a ticket prefix${ENDCOLOR}"
    echo

    if [ -z "$ticket_name" ]; then
        echo -e "${YELLOW}No ticket prefix is set.${ENDCOLOR}"
    else
        echo -e "Current ticket prefix: ${YELLOW}$ticket_name${ENDCOLOR}"
        echo -e "Press Enter to exit without changes, or 0 to remove the existing prefix"
    fi

    read_editable_input ticket_name "Ticket prefix: "

    if [ "$ticket_name" == "0" ]; then
        unset_config_value gitbasher.ticket
        echo
        echo -e "${GREEN}✓ Removed ticket prefix from '${project_name}'${ENDCOLOR}"
        exit
    fi

    if [ -z "$ticket_name" ]; then
        exit
    fi

    # Sanitize ticket prefix input
    if ! sanitize_text_input "$ticket_name" 50; then
        show_sanitization_error "ticket prefix" "Use printable characters only, max 50 characters."
        exit 1
    fi
    ticket_name="$sanitized_text"

    echo 

    # Quoted: an unquoted value containing a space word-split, landing the
    # second word in set_config_value's GLOBAL flag slot — the value was
    # truncated AND silently written to ~/.gitconfig instead of the repo.
    ticket_name=$(set_config_value gitbasher.ticket "$ticket_name")
    echo -e "${GREEN}✓ Set '${ticket_name}' as the ticket prefix in '${project_name}'${ENDCOLOR}"
    echo

    [ "$GITBASHER_NO_REPO" = "true" ] && exit
    echo -e "Do you want to set it ${YELLOW}globally${ENDCOLOR} for all projects (Y/n)?"
    yes_no_choice "\nSet '${ticket_name}' globally" "true"
    ticket_name=$(set_config_value gitbasher.ticket "$ticket_name" "true")
}


### Function asks user to set AI API key
# $1: optional "--chained" — wizard mode: every exit becomes a return so the
#     next wizard step still runs (0 = done/skipped, 1 = validation failure,
#     130 = EOF/closed stdin, which the wizard treats as abort).
function configure_ai_key {
    local _chained=""
    [ "$1" = "--chained" ] && _chained="true"

    # Walk the user through provider selection first when no provider is set.
    # Otherwise we'd silently default to openrouter and ask for the wrong key.
    # configure_ai_provider chains into key entry on its own when applicable.
    # In wizard mode the provider step has just run — skip the redirect.
    if [ -z "$_chained" ] \
       && [ -z "$(git config --get gitbasher.ai-provider 2>/dev/null)" ] \
       && [ -z "$(git config --global --get gitbasher.ai-provider 2>/dev/null)" ]; then
        configure_ai_provider
        return
    fi

    local provider=$(get_ai_provider)
    local provider_upper
    provider_upper=$(echo "$provider" | tr '[:lower:]' '[:upper:]')

    echo -e "${YELLOW}Enter AI API key for provider '${provider}'${ENDCOLOR}"
    echo

    # Local providers don't take a key — short-circuit instead of prompting for nothing.
    if ! ai_provider_requires_api_key; then
        echo -e "${YELLOW}Provider '${provider}' does not require an API key.${ENDCOLOR}"
        echo -e "Switch providers with ${GREEN}gitb cfg provider${ENDCOLOR} to set one."
        if [ -n "$_chained" ]; then return 0; fi
        exit
    fi

    ai_api_key=$(get_ai_api_key)
    if [ -z "$ai_api_key" ]; then
        echo -e "${YELLOW}No AI API key is set for '${provider}'.${ENDCOLOR}"
    else
        echo -e "AI API key for '${provider}' is ${GREEN}configured${ENDCOLOR}: ${BLUE}$(mask_api_key "$ai_api_key")${ENDCOLOR}"
        echo
        # Fast path: keeping a working key should be one keystroke, not a
        # walk through the storage options and a hidden input.
        echo -e "Press ${YELLOW}Enter${ENDCOLOR} to keep it, ${YELLOW}r${ENDCOLOR} to replace, or ${YELLOW}0${ENDCOLOR} to remove"
        local _key_action=""
        read_key _key_action || { if [ -n "$_chained" ]; then return 130; fi; exit; }
        if [ "$_key_action" = "0" ]; then
            unset_ai_api_key
            echo
            echo -e "${GREEN}✓ Removed AI API key for '${provider}' from '${project_name}'${ENDCOLOR}"
            if [ -n "$_chained" ]; then return 0; fi
            exit
        fi
        normalize_key "$_key_action"
        if [ "$normalized_key" != "r" ]; then
            echo -e "Keeping the existing key."
            if [ -n "$_chained" ]; then return 0; fi
            exit
        fi
        echo
    fi
    case "$provider" in
        openai)
            local provider_label="OpenAI"
            local key_url="https://platform.openai.com/api-keys"
            ;;
        *)
            local provider_label="OpenRouter"
            local key_url="https://openrouter.ai/keys"
            ;;
    esac
    echo -e "Enter your ${YELLOW}${provider_label} API key${ENDCOLOR} to enable AI commit message generation"
    echo -e "Get your API key from: ${BLUE}${key_url}${ENDCOLOR}"
    echo

    # Storage choice: environment variable is the safer default and what
    # SECURITY.md recommends — keys never land on disk where a leaked repo
    # config could carry them. Offer it explicitly before falling back to
    # the git-config path. See SECURITY.md ("AI keys") for the rationale.
    local rc_file="${HOME}/.zshrc"
    case "${SHELL##*/}" in
        bash) rc_file="${HOME}/.bashrc" ;;
        zsh)  rc_file="${HOME}/.zshrc" ;;
        fish) rc_file="${HOME}/.config/fish/config.fish" ;;
    esac

    echo -e "${YELLOW}Storage options:${ENDCOLOR}"
    echo -e "  ${GREEN}env var${ENDCOLOR}    — recommended; the key never touches disk via gitbasher"
    echo -e "  ${BLUE}git config${ENDCOLOR} — convenient, but stored in plaintext under .git/config (or ~/.gitconfig if global)"
    echo
    read -n 1 -p "Use environment variable (recommended)? (Y/n) " ai_storage_choice \
        || { if [ -n "$_chained" ]; then echo; return 130; fi; ai_storage_choice="n"; }
    echo
    if is_yes "$ai_storage_choice"; then
        echo
        echo -e "Add this to ${BLUE}${rc_file}${ENDCOLOR} (or paste in your current shell):"
        echo -e "  ${GREEN}export GITB_AI_API_KEY_${provider_upper}='your-${provider}-key'${ENDCOLOR}"
        echo
        echo -e "${CYAN}gitbasher checks env vars before git config every run, so this takes precedence.${ENDCOLOR}"
        echo -e "Append it now with:"
        echo -e "  ${GREEN}echo \"export GITB_AI_API_KEY_${provider_upper}='your-${provider}-key'\" >> $(printf '%q' "$rc_file")${ENDCOLOR}"
        if [ -n "$_chained" ]; then return 0; fi
        exit
    fi

    # Falling through to the git-config path. Make the security trade-off
    # explicit one more time so the user is not surprised if their config
    # leaks via a shared repo or a misconfigured backup.
    echo
    echo -e "${YELLOW}⚠  Storing in git config writes the key in plaintext.${ENDCOLOR}"
    echo -e "Press Enter or Esc to exit without changes, or 0 to remove the existing key"

    echo
    echo -e "${YELLOW}Input is hidden — type the key and press Enter.${ENDCOLOR}"

    read_silent_input ai_key_input "API Key: "

    if [ "$ai_key_input" == "" ]; then
        if [ -n "$_chained" ]; then return 0; fi
        exit
    fi

    if [ "$ai_key_input" == "0" ]; then
        unset_ai_api_key
        echo
        echo -e "${GREEN}✓ Removed AI API key for '${provider}' from '${project_name}'${ENDCOLOR}"
        if [ -n "$_chained" ]; then return 0; fi
        exit
    fi

    echo

    # Basic validation - check for reasonable API key format
    if [[ ! "$ai_key_input" =~ ^[a-zA-Z0-9._-]{20,}$ ]]; then
        echo -e "${YELLOW}⚠  API key format does not look like a valid ${provider} key.${ENDCOLOR}" >&2
        read -n 1 -p "Continue anyway? (Y/n) " -s choice \
            || { if [ -n "$_chained" ]; then echo; return 130; fi; choice="n"; }
        echo
        if ! is_yes "$choice"; then
            if [ -n "$_chained" ]; then return 1; fi
            exit 1
        fi
    fi

    ai_api_key=$(set_ai_api_key "$ai_key_input")
    echo -e "${GREEN}✓ Configured AI API key for '${provider}' in '${project_name}':${ENDCOLOR} ${BLUE}$(mask_api_key "$ai_api_key")${ENDCOLOR}"
    echo

    # Validate the freshly stored key against the provider so a typo surfaces
    # now instead of on the first AI commit.
    ai_smoke_check || true
    echo

    if [ "$GITBASHER_NO_REPO" = "true" ]; then
        if [ -n "$_chained" ]; then return 0; fi
        exit
    fi
    echo -e "Do you want to set it ${YELLOW}globally${ENDCOLOR} for all projects (Y/n)?"
    echo -e "${RED}⚠  Global API keys are stored in plaintext in ~/.gitconfig.${ENDCOLOR}"
    echo -e "${CYAN}💡 For better security, set ${BLUE}GITB_AI_API_KEY_${provider_upper}${CYAN} as an environment variable instead.${ENDCOLOR}"
    # Non-exiting confirm (yes_no_choice exits the process on "no", which
    # would kill the wizard's remaining steps). Decline just ends the step.
    local _key_global=""
    read_key _key_global || { if [ -n "$_chained" ]; then return 130; fi; _key_global="n"; }
    if is_yes "$_key_global"; then
        echo -e "${YELLOW}Set AI API key globally${ENDCOLOR}"
        ai_api_key=$(set_ai_api_key "$ai_key_input" "true")
    fi
    return 0
}


### Function asks user to choose the AI provider.
# Provider determines which API endpoint, auth scheme, and default
# models are used. Custom OpenAI-compatible gateways can be reached by leaving
# the provider as openai/openrouter and overriding gitbasher.ai-base-url.
# $1: optional "--chained" — wizard mode: exits become returns
#     (0 = done/skipped, 1 = validation failure, 3 = user declined to keep a
#     provider that failed its reachability probe — the wizard must STOP,
#     the remaining steps were opted out of, 130 = EOF).
function configure_ai_provider {
    local _chained=""
    [ "$1" = "--chained" ] && _chained="true"

    echo -e "${YELLOW}Choose AI Provider${ENDCOLOR}"
    echo

    local current_provider=$(get_ai_provider)
    local current_base_url=$(get_ai_base_url)

    echo -e "Current provider: ${GREEN}${current_provider}${ENDCOLOR}"
    if [ -n "$current_base_url" ]; then
        echo -e "Custom base URL: ${GREEN}${current_base_url}${ENDCOLOR}"
    fi
    echo

    echo -e "Options:"
    echo -e "  1. ${BOLD}openrouter${ENDCOLOR}  Aggregator with hundreds of models — needs an API key"
    echo -e "  2. ${BOLD}openai${ENDCOLOR}      OpenAI direct (GPT-5 family) — needs an API key"
    echo -e "  3. ${BOLD}ollama${ENDCOLOR}      Local or remote models (you'll set the host) — no API key required"
    echo -e "  4. ${BOLD}claude${ENDCOLOR}      Local Claude Code CLI (claude -p) — uses your Claude account, no API key"
    echo
    echo -e "Press Enter to keep the current provider, or enter 0 to reset to default (${AI_DEFAULT_PROVIDER})"

    if ! read_editable_input choice "Choice (1-4): "; then
        if [ -n "$_chained" ]; then return 130; fi
        exit
    fi

    if [ "$choice" == "" ]; then
        if [ -n "$_chained" ]; then return 0; fi
        exit
    fi

    if [ "$choice" == "0" ]; then
        git config --unset gitbasher.ai-provider 2>/dev/null
        git config --global --unset gitbasher.ai-provider 2>/dev/null
        echo
        echo -e "${GREEN}✓ Reset provider to default (${AI_DEFAULT_PROVIDER})${ENDCOLOR}"
        if [ -n "$_chained" ]; then return 0; fi
        exit
    fi

    local new_provider
    local host_input=""
    case "$choice" in
        1) new_provider="openrouter" ;;
        2) new_provider="openai" ;;
        3) new_provider="ollama" ;;
        4) new_provider="claude" ;;
        *)
            echo -e "${RED}✗ Invalid choice.${ENDCOLOR}" >&2
            if [ -n "$_chained" ]; then return 1; fi
            exit 1
            ;;
    esac

    # Before switching, attribute any legacy `gitbasher.ai-api-key` and
    # `gitbasher.ai-model` to the outgoing provider. Otherwise the next AI
    # call would happily send (e.g.) an OpenRouter key — or an OpenRouter
    # model slug — to another provider and fail on every request.
    migrate_legacy_ai_api_key_to "$current_provider"
    migrate_legacy_ai_model_to "$current_provider"

    # Remember the previous local value so a failed reachability probe below
    # can revert this write exactly (the previous provider may have lived in
    # global config or the built-in default — both mean "no local value").
    local prev_local_provider
    prev_local_provider=$(git config --local --get gitbasher.ai-provider 2>/dev/null)

    set_ai_provider "$new_provider"
    echo -e "${GREEN}✓ Set AI provider to '${new_provider}' for '${project_name}'${ENDCOLOR}"

    # Provider-specific follow-up. Ollama asks where the server lives and probes
    # it; a cloud provider that already has a key gets its key validated. Both
    # run before the "set globally?" prompt because that prompt exits on "no".
    # A failed CLOUD check does not gate anything — the wizard's key step comes
    # right after and fixes a bad key. A failed LOCAL check (Ollama down,
    # claude CLI missing) has no such next step, so it asks before moving on.
    local local_smoke_failed=""
    case "$new_provider" in
        ollama)
            local current_host
            current_host=$(get_ai_ollama_host)
            echo
            echo -e "${YELLOW}Where is your Ollama server?${ENDCOLOR}"
            echo -e "Enter a host URL, or press Enter to keep ${GREEN}${current_host}${ENDCOLOR}."
            read_editable_input host_input "Ollama host: " "$current_host"
            if [ -n "$host_input" ]; then
                # Accept a bare host:port by defaulting the scheme to http://.
                case "$host_input" in
                    http://*|https://*) : ;;
                    *) host_input="http://${host_input}" ;;
                esac
                host_input="${host_input%/}"
                # Validate before storing: this value is interpolated into
                # every AI request URL, and garbage (spaces, quotes) used to
                # be stored unchecked and fail later with opaque curl errors.
                if ! validate_proxy_url "$host_input"; then
                    echo -e "${RED}✗ '$host_input' does not look like a valid host URL (expected http://host[:port]).${ENDCOLOR}"
                    if [ -n "$_chained" ]; then return 1; fi
                    exit 1
                fi
                set_ai_ollama_host "$host_input" >/dev/null
                echo -e "${GREEN}✓ Ollama host set to ${host_input}${ENDCOLOR}"
            fi
            echo
            echo -e "${CYAN}💡 Make sure the Ollama daemon is running (${BLUE}ollama serve${CYAN}) and a model is pulled (${BLUE}ollama pull qwen3:8b${CYAN}).${ENDCOLOR}"
            # The wizard's own step 3 is the model picker — the standalone
            # command is the only place this pointer adds anything.
            if [ -z "$_chained" ]; then
                echo -e "${CYAN}💡 Pick a model with ${GREEN}gitb cfg model${CYAN}.${ENDCOLOR}"
            fi
            echo
            ai_smoke_check || local_smoke_failed="true"
            ;;
        claude)
            echo
            if command -v claude >/dev/null 2>&1; then
                ai_smoke_check || local_smoke_failed="true"
            else
                echo -e "${RED}✗ claude CLI not found on PATH.${ENDCOLOR}"
                echo -e "${CYAN}💡 Install it with ${BLUE}npm install -g @anthropic-ai/claude-code${CYAN}, then sign in once.${ENDCOLOR}"
                local_smoke_failed="true"
            fi
            if [ -z "$_chained" ]; then
                echo -e "${CYAN}💡 Pick a model with ${GREEN}gitb cfg model${CYAN} (haiku, sonnet, opus).${ENDCOLOR}"
            fi
            ;;
        *)
            # Cloud provider: if a key is already configured for it, validate now.
            if [ -n "$(get_ai_api_key)" ]; then
                echo
                ai_smoke_check || true
            fi
            ;;
    esac
    echo

    # A local provider that failed its probe would only produce more broken
    # steps (a global write of a dead provider, a model menu with no models,
    # failing commits). Offer to revert instead of marching on — keeping it
    # is still one keystroke away for setup-before-daemon workflows.
    if [ -n "$local_smoke_failed" ]; then
        echo -e "Keep '${new_provider}' as the AI provider anyway (y/N)?"
        # (y/N): only an explicit y keeps the dead provider — Enter/EOF revert
        # (is_yes would treat Enter as yes; that's for (Y/n) prompts).
        local _keep_rc=0
        confirm_destructive || _keep_rc=$?
        if [ "$_keep_rc" -ne 0 ]; then
            if [ -n "$prev_local_provider" ]; then
                git config --local gitbasher.ai-provider "$prev_local_provider"
            else
                git config --local --unset gitbasher.ai-provider 2>/dev/null || true
            fi
            echo -e "${YELLOW}Provider unchanged — still '$(get_ai_provider)'.${ENDCOLOR}"
            if [ -n "$_chained" ]; then
                # EOF aborts the wizard like any other prompt; an explicit
                # decline returns 3 so the wizard STOPS instead of walking
                # the remaining steps the user just opted out of.
                if [ "$_keep_rc" -eq 2 ]; then return 130; fi
                return 3
            fi
            exit 1
        fi
        echo
    fi

    if [ "$GITBASHER_NO_REPO" != "true" ]; then
        echo -e "Do you want to set this provider ${YELLOW}globally${ENDCOLOR} for all projects (Y/n)?"
        # Non-exiting confirm: yes_no_choice exits the process on "no",
        # which skipped the missing-key follow-up below — the exact
        # surprise that block exists to prevent.
        local _prov_key=""
        read_key _prov_key || { if [ -n "$_chained" ]; then return 130; fi; _prov_key="n"; }
        if is_yes "$_prov_key"; then
            echo -e "${YELLOW}Set AI provider globally${ENDCOLOR}"
            set_config_value gitbasher.ai-provider "$new_provider" "true"
            # Keep the Ollama host at the same scope as the provider it belongs to.
            if [ "$new_provider" = "ollama" ] && [ -n "$host_input" ]; then
                set_config_value gitbasher.ai-ollama-host "$host_input" "true" >/dev/null
            fi
        fi
    fi

    # If the new provider needs an API key but none is configured for it,
    # walk the user through setting one now — this is the surprise the user
    # hit when switching from openrouter to openai with a stale legacy key.
    # Skipped in wizard mode: the wizard runs its own key step next.
    if [ -z "$_chained" ] && ai_provider_requires_api_key && [ -z "$(get_ai_api_key)" ]; then
        echo
        echo -e "${YELLOW}No API key is set for '${new_provider}'.${ENDCOLOR}"
        echo -e "${CYAN}AI commands will be blocked until a key is configured.${ENDCOLOR}"
        echo
        echo -e "Set one now? (Y/n)"
        if read -n 1 -s key_choice && is_yes "$key_choice"; then
            echo
            configure_ai_key
        else
            echo
            echo -e "${YELLOW}Skipped. Run ${GREEN}gitb cfg ai${YELLOW} when you're ready.${ENDCOLOR}"
        fi
    fi
}


### Print one numbered model-menu entry, marking the active model.
# BOLD for the selectable id, matching the commit-type menu — plain BLUE is
# near-invisible on dark terminals and is reserved for secondary context.
# $1: model id, $2: menu index, $3: the model gitb would use right now
# $4: optional description, printed dimmed after the id
function _print_model_menu_entry {
    local _desc=""
    [ -n "$4" ] && _desc=" ${GRAY}- ${4}${ENDCOLOR}"
    if [ "$1" = "$3" ]; then
        echo -e "  ${GREEN}${2}. ${1}${ENDCOLOR}  (current)${_desc}"
    else
        echo -e "  ${2}. ${BOLD}${1}${ENDCOLOR}${_desc}"
    fi
}

### Function asks user to configure AI model
# $1: optional "--chained" — wizard mode: exits become returns
#     (0 = done/skipped, 1 = validation failure, 130 = EOF).
function configure_ai_model {
    local _chained=""
    [ "$1" = "--chained" ] && _chained="true"

    echo -e "${YELLOW}Configure AI Model${ENDCOLOR}"
    echo

    # One model per provider: the override (if any) or the recommended
    # default. The stored value is scoped to the active provider, so a model
    # picked here never leaks into another provider.
    current_model=$(get_ai_model)
    if [ -n "$current_model" ]; then
        echo -e "Current model for provider '${GREEN}$(get_ai_provider)${ENDCOLOR}': ${GREEN}$current_model${ENDCOLOR}"
    else
        echo -e "Provider '${GREEN}$(get_ai_provider)${ENDCOLOR}' uses its default model: ${GREEN}$(get_ai_default_model)${ENDCOLOR}"
    fi
    echo

    # Live model menu per provider:
    #   ollama     — models installed on the host (GET /api/tags);
    #   openrouter — the week's most-used text models + the newest ones
    #                (public /models endpoint, server-side sort);
    #   openai     — newest chat models visible to the account's key.
    # model_catalog keeps the FULL fetched id list for free-text validation.
    # Any fetch failure just means no menu and no validation — the static
    # suggestions below and free-text entry still work (same graceful
    # degradation the Ollama path always had).
    local -a model_menu=()
    local model_catalog=""
    local _m _i
    local _resolved_model
    _resolved_model=$(resolve_ai_model)

    case "$(get_ai_provider)" in
        ollama)
            while IFS= read -r _m; do
                [ -n "$_m" ] && model_menu+=("$_m")
            done < <(ollama_list_models)
            if [ ${#model_menu[@]} -gt 0 ]; then
                echo -e "Installed models on ${BLUE}$(ollama_api_base)${ENDCOLOR}:"
                _i=1
                for _m in "${model_menu[@]}"; do
                    _print_model_menu_entry "$_m" "$_i" "$_resolved_model"
                    _i=$((_i + 1))
                done
            else
                echo -e "${YELLOW}No models found on $(ollama_api_base) — is the daemon running?${ENDCOLOR}"
            fi
            ;;
        openrouter)
            # One fetch of the popularity-sorted full list doubles as the
            # validation catalog; a second small fetch adds the newest models.
            model_catalog=$(openrouter_list_models top-weekly 2>/dev/null)
            if [ -n "$model_catalog" ]; then
                _i=1
                echo -e "Most used on OpenRouter this week:"
                while IFS= read -r _m; do
                    model_menu+=("$_m")
                    _print_model_menu_entry "$_m" "$_i" "$_resolved_model"
                    _i=$((_i + 1))
                done < <(printf '%s\n' "$model_catalog" | head -8)
                local _newest
                _newest=$(openrouter_list_models newest 2>/dev/null | head -5)
                if [ -n "$_newest" ]; then
                    echo -e "Newest:"
                    while IFS= read -r _m; do
                        [ -z "$_m" ] && continue
                        # Skip ids already shown in the popular section
                        case " ${model_menu[*]} " in *" $_m "*) continue ;; esac
                        model_menu+=("$_m")
                        _print_model_menu_entry "$_m" "$_i" "$_resolved_model"
                        _i=$((_i + 1))
                    done <<< "$_newest"
                fi
            fi
            ;;
        openai)
            model_catalog=$(openai_list_models 2>/dev/null)
            if [ -n "$model_catalog" ]; then
                echo -e "Newest chat models on your OpenAI account:"
                _i=1
                # Dated snapshots (gpt-5.4-mini-2026-03-17) are aliases of
                # their base model — noise in a menu. They stay in the
                # catalog, so typing one by hand still validates.
                while IFS= read -r _m; do
                    model_menu+=("$_m")
                    _print_model_menu_entry "$_m" "$_i" "$_resolved_model"
                    _i=$((_i + 1))
                done < <(printf '%s\n' "$model_catalog" \
                    | LC_ALL=C grep -vE -- '-[0-9]{4}-[0-9]{2}-[0-9]{2}$' | head -12)
            fi
            ;;
    esac

    # No live list (or a provider that never has one, like claude) — the
    # static suggestions become the numbered menu, selectable the same way.
    if [ ${#model_menu[@]} -eq 0 ]; then
        local -a _menu_desc=()
        case "$(get_ai_provider)" in
            openai)
                echo -e "Popular OpenAI models:"
                model_menu=("gpt-5.4-mini" "gpt-5.4-nano" "gpt-5.5")
                _menu_desc=("Default: as fast as nano with better quality (~\$0.75/\$4.50 per M)"
                            "Budget option for high volume (~\$0.20/\$1.25 per M)"
                            "Flagship, only worth it for the hardest grouping cases")
                ;;
            ollama)
                echo -e "Suggested models (pull first: ${BLUE}ollama pull <id>${ENDCOLOR}):"
                model_menu=("qwen3:8b" "llama3.3:8b" "qwen2.5-coder:7b")
                _menu_desc=("Default: best small instruction-follower; most stable structured output"
                            "Solid general-purpose alternative"
                            "Code-focused; good when most diffs are code")
                ;;
            claude)
                echo -e "Model aliases (resolve to the current generation; full ids like ${BLUE}claude-haiku-4-5${ENDCOLOR} also work):"
                model_menu=("haiku" "sonnet" "opus")
                _menu_desc=("Default: fastest and cheapest"
                            "Better prose, noticeably slower"
                            "Strongest, for the hardest cases")
                ;;
            *)
                echo -e "Popular OpenRouter models:"
                model_menu=("google/gemini-3.5-flash" "google/gemini-3.1-flash-lite" "openrouter/auto" "anthropic/claude-haiku-4.5" "anthropic/claude-sonnet-5")
                _menu_desc=("Default: current flash generation, fast with good prose"
                            "Fastest, cheapest (~\$0.25/\$1.50 per M)"
                            "Auto-select best available model"
                            "Strict instruction following"
                            "Premium quality for the hardest cases")
                ;;
        esac
        _i=0
        for _m in "${model_menu[@]}"; do
            _print_model_menu_entry "$_m" "$((_i + 1))" "$_resolved_model" "${_menu_desc[$_i]}"
            _i=$((_i + 1))
        done
    fi
    echo -e "Enter a number to select, or type a model id."
    echo

    echo -e "Press Enter to keep the current model, or 0 to reset to the default (${GREEN}$(get_ai_default_model)${ENDCOLOR})"

    if ! read_editable_input model_input "Model ID: "; then
        if [ -n "$_chained" ]; then return 130; fi
        exit
    fi

    if [ "$model_input" == "" ]; then
        if [ -n "$_chained" ]; then return 0; fi
        exit
    fi

    if [ "$model_input" == "0" ]; then
        # Clear the provider's slot and the legacy key, local and global —
        # leaving the legacy key would silently keep the "cleared" model alive.
        git config --unset "gitbasher.ai-model-$(get_ai_provider)" 2>/dev/null
        git config --global --unset "gitbasher.ai-model-$(get_ai_provider)" 2>/dev/null
        git config --unset gitbasher.ai-model 2>/dev/null
        git config --global --unset gitbasher.ai-model 2>/dev/null
        echo
        echo -e "${GREEN}✓ Cleared model override — provider '$(get_ai_provider)' now uses its default ($(get_ai_default_model))${ENDCOLOR}"
        if [ -n "$_chained" ]; then return 0; fi
        exit
    fi

    echo

    # A bare number picks from the live menu shown above.
    local picked_from_menu=""
    if [ ${#model_menu[@]} -gt 0 ] && [[ "$model_input" =~ ^[0-9]+$ ]]; then
        if [ "$model_input" -ge 1 ] && [ "$model_input" -le ${#model_menu[@]} ]; then
            model_input="${model_menu[$((model_input - 1))]}"
            picked_from_menu="true"
        else
            echo -e "${RED}✗ Invalid selection: ${model_input}${ENDCOLOR}" >&2
            if [ -n "$_chained" ]; then return 1; fi
            exit 1
        fi
    fi

    # Basic validation - check for a reasonable model ID format. Allows the ':'
    # in Ollama tags (qwen3:8b) that the old inline check wrongly rejected.
    if ! is_valid_model_id "$model_input"; then
        echo -e "${RED}✗ Invalid model ID format.${ENDCOLOR}" >&2
        echo -e "${YELLOW}Use only letters, numbers, dots, dashes, underscores, colons, and slashes.${ENDCOLOR}" >&2
        if [ -n "$_chained" ]; then return 1; fi
        exit 1
    fi

    # A typed id gets checked against the fetched catalog (typos die here,
    # not on the first commit). The catalog can lag behind brand-new models,
    # so an unknown id is a warning with an escape hatch, never a hard block.
    if [ -z "$picked_from_menu" ] && [ -n "$model_catalog" ]; then
        if ! printf '%s\n' "$model_catalog" | LC_ALL=C grep -qxF "$model_input"; then
            echo -e "${YELLOW}⚠ '$model_input' is not in $(get_ai_provider)'s current model list.${ENDCOLOR}"
            echo -e "Save it anyway (y/N)?"
            # (y/N): saving an unknown id needs an explicit y — Enter declines
            if ! confirm_destructive; then
                echo -e "${YELLOW}Not saved. Pick a number from the list or re-check the id.${ENDCOLOR}"
                if [ -n "$_chained" ]; then return 1; fi
                exit 1
            fi
        fi
    fi

    # Remember the previous value so a failing live check can restore it.
    local prev_model
    prev_model=$(git config --local --get "gitbasher.ai-model-$(get_ai_provider)" 2>/dev/null)

    # Set the model for the active provider only
    set_ai_model "$model_input"
    echo -e "${GREEN}✓ Set AI model to '$model_input' for provider '$(get_ai_provider)' in '${project_name}'${ENDCOLOR}"
    echo

    # Prove the model actually completes a request before the global prompt —
    # a wrong id should die here, and never be propagated to all projects.
    # Ollama is already covered by the installed-models menu; claude aliases
    # always resolve. Cloud typo'd/unavailable models are the failure mode.
    case "$(get_ai_provider)" in
        openrouter|openai)
            if ! ai_model_smoke_check; then
                echo -e "Keep '$model_input' anyway (y/N)?"
                # (y/N): only an explicit y keeps a model that failed the live
                # check — Enter/EOF restore the previous one.
                if ! confirm_destructive; then
                    if [ -n "$prev_model" ]; then
                        git config "gitbasher.ai-model-$(get_ai_provider)" "$prev_model"
                        echo -e "${YELLOW}Restored previous model '${prev_model}'.${ENDCOLOR}"
                    else
                        git config --unset "gitbasher.ai-model-$(get_ai_provider)" 2>/dev/null
                        echo -e "${YELLOW}Removed it — provider '$(get_ai_provider)' uses its default ($(get_ai_default_model)).${ENDCOLOR}"
                    fi
                    if [ -n "$_chained" ]; then return 1; fi
                    exit 1
                fi
            fi
            echo
            ;;
    esac

    if [ "$GITBASHER_NO_REPO" = "true" ]; then
        if [ -n "$_chained" ]; then return 0; fi
        exit
    fi
    echo -e "Do you want to set it ${YELLOW}globally${ENDCOLOR} for all projects (Y/n)?"
    # Non-exiting confirm (yes_no_choice exits the process on "no", which
    # would kill the wizard's remaining steps). Decline just ends the step.
    local _model_global=""
    read_key _model_global || { if [ -n "$_chained" ]; then return 130; fi; _model_global="n"; }
    if is_yes "$_model_global"; then
        echo -e "${YELLOW}Set AI model globally${ENDCOLOR}"
        set_ai_model "$model_input" "true"
    fi
    return 0
}


### Multi-step AI setup: provider → API key → model → summary.
# Chains the standalone configure_* steps in wizard mode (--chained turns
# their exits into returns): Enter skips a step, a validation failure moves
# on to the next step without losing earlier answers, EOF aborts the wizard.
function configure_ai_wizard {
    local _rc

    echo -e "${YELLOW}Step 1/3 — Provider${ENDCOLOR}"
    echo
    configure_ai_provider --chained
    _rc=$?
    if [ "$_rc" -eq 130 ]; then prompt_aborted; fi
    if [ "$_rc" -eq 3 ]; then
        # The user declined to keep a provider that failed its probe —
        # configuring keys and models for the restored provider was not
        # what they asked for. Stop here; nothing has changed.
        echo
        echo -e "${YELLOW}AI setup stopped — nothing changed.${ENDCOLOR}"
        return 0
    fi

    echo
    echo -e "${YELLOW}Step 2/3 — API key${ENDCOLOR}"
    echo
    if ai_provider_requires_api_key; then
        configure_ai_key --chained
        _rc=$?
        if [ "$_rc" -eq 130 ]; then prompt_aborted; fi
    else
        echo -e "Provider '$(get_ai_provider)' does not require an API key — skipping."
    fi

    echo
    echo -e "${YELLOW}Step 3/3 — Model${ENDCOLOR}"
    echo
    configure_ai_model --chained
    _rc=$?
    if [ "$_rc" -eq 130 ]; then prompt_aborted; fi

    echo
    echo -e "${GREEN}✓ AI setup complete${ENDCOLOR}"
    echo
    print_ai_configuration
}


### Function asks user to set AI proxy
function configure_ai_proxy {
    echo -e "${YELLOW}Configure AI HTTP/SOCKS Proxy${ENDCOLOR}"
    echo
    
    ai_proxy=$(get_ai_proxy)
    if [ -z "$ai_proxy" ]; then
        echo -e "${YELLOW}No AI proxy is configured.${ENDCOLOR}"
    else
        echo -e "Current AI proxy: ${GREEN}$ai_proxy${ENDCOLOR}"
    fi
    
    echo -e "Enter proxy URL to route AI requests through (useful for bypassing geo-restrictions)"
    echo -e ""
    echo -e "${BLUE}HTTP proxy formats:${ENDCOLOR}"
    echo -e "  • ${BOLD}http://proxy.example.com:8080${ENDCOLOR}"
    echo -e "  • ${BOLD}http://username:password@proxy.example.com:8080${ENDCOLOR}"
    echo -e "  • ${BOLD}http://[2001:db8::1]:8080${ENDCOLOR} (IPv6)"
    echo -e ""
    echo -e "Press Enter to exit without changes, or 0 to remove the existing proxy"

    read_editable_input ai_proxy_input "Proxy URL: "

    if [ "$ai_proxy_input" == "" ]; then
        exit
    fi

    if [ "$ai_proxy_input" == "0" ]; then
        unset_config_value gitbasher.ai-proxy
        echo
        echo -e "${GREEN}✓ Removed AI proxy from '${project_name}'${ENDCOLOR}"
        exit
    fi

    echo

    # Validate and sanitize proxy URL to prevent command injection
    if ! validate_proxy_url "$ai_proxy_input"; then
        echo -e "${RED}✗ Invalid proxy URL format: $ai_proxy_input${ENDCOLOR}" >&2
        echo -e "${YELLOW}Expected format: protocol://host:port (e.g., http://proxy.example.com:8080)${ENDCOLOR}" >&2
        echo -e "${YELLOW}Or: host:port (e.g., proxy.example.com:8080)${ENDCOLOR}" >&2
        echo -e "${YELLOW}Supported protocols: http, https, socks5${ENDCOLOR}" >&2
        exit 1
    fi
    
    # Use the validated proxy URL
    ai_proxy_input="$validated_proxy_url"

    set_ai_proxy "$ai_proxy_input"
    echo -e "${GREEN}✓ Configured AI proxy for '${project_name}':${ENDCOLOR} ${BLUE}$ai_proxy_input${ENDCOLOR}"
    echo
    echo -e "${YELLOW}Example usage:${ENDCOLOR}"
    echo -e "  ${BLUE}gitb commit ai${ENDCOLOR}    - Generate commit with AI through proxy"
    echo -e "  ${BLUE}gitb commit aif${ENDCOLOR}   - Fast AI commit through proxy"
    echo
   
    [ "$GITBASHER_NO_REPO" = "true" ] && exit
    echo -e "Do you want to set it ${YELLOW}globally${ENDCOLOR} for all projects (Y/n)?"
    yes_no_choice "\nSet AI proxy globally" "true"
    set_ai_proxy "$ai_proxy_input"
    git config --global gitbasher.ai-proxy "$ai_proxy_input"
}


### Function asks user to configure AI commit history limit
function configure_ai_history {
    echo -e "${YELLOW}Configure AI Commit History Limit${ENDCOLOR}"
    echo
    
    current_limit=$(get_ai_commit_history_limit)
    echo -e "Current limit: ${GREEN}$current_limit${ENDCOLOR} recent commits"
    echo
    echo -e "This setting controls how many recent commit messages are included in AI prompts"
    echo -e "to help the AI learn from your commit message patterns and style."
    echo -e ""
    echo -e "Recommended range: ${BLUE}5-15${ENDCOLOR} commits"
    echo -e "• Lower values (5-8): Faster, uses fewer tokens, focuses on recent patterns"
    echo -e "• Higher values (10-15): Better style learning, uses more tokens"
    echo
    echo -e "Press Enter to exit without changes"

    read_editable_input limit_input "Number of recent commits to include: "

    if [ "$limit_input" == "" ]; then
        exit
    fi

    echo

    # Validate numeric input
    if ! validate_numeric_input "$limit_input" 1 100; then
        show_sanitization_error "commit history limit" "Please enter a positive number between 1 and 100."
        exit 1
    fi
    limit_input="$validated_number"

    # Warn if value is outside recommended range
    if [ "$limit_input" -lt 5 ] || [ "$limit_input" -gt 20 ]; then
        echo -e "${YELLOW}⚠  Value is outside the recommended range (5-20).${ENDCOLOR}"
        if [ "$limit_input" -gt 20 ]; then
            echo -e "${YELLOW}High values may exceed token limits and slow down AI responses.${ENDCOLOR}"
        fi
        read -n 1 -p "Continue anyway? (Y/n) " -s choice || choice="n"
        echo
        if ! is_yes "$choice"; then
            exit
        fi
    fi

    set_ai_commit_history_limit "$limit_input"
    echo -e "${GREEN}✓ Set AI commit history limit to ${limit_input} for '${project_name}'${ENDCOLOR}"
    echo

    [ "$GITBASHER_NO_REPO" = "true" ] && exit
    echo -e "Do you want to set it ${YELLOW}globally${ENDCOLOR} for all projects (Y/n)?"
    yes_no_choice "\nSet AI commit history limit globally" "true"
    git config --global gitbasher.ai-commit-history-limit "$limit_input"
}


### Function asks user to configure the push size warning threshold
function configure_push_warn_size {
    echo -e "${YELLOW}Configure Push Size Warning${ENDCOLOR}"
    echo

    current_limit=$(get_push_warn_size)
    if [ "$current_limit" = "0" ]; then
        echo -e "Current threshold: ${YELLOW}disabled${ENDCOLOR}"
    else
        echo -e "Current threshold: ${GREEN}$current_limit MB${ENDCOLOR}"
    fi
    echo
    echo -e "Before pushing, gitbasher estimates how much data will be transferred"
    echo -e "and warns you when a push exceeds this size or includes a large file —"
    echo -e "handy for catching a stray non-code object (a build artifact, dataset, etc.)."
    echo
    echo -e "Enter a size in ${BLUE}MB${ENDCOLOR}, or ${BLUE}0${ENDCOLOR} to disable the check."
    echo -e "Press Enter to exit without changes"

    read_editable_input limit_input "Warn above (MB): "

    if [ "$limit_input" == "" ]; then
        exit
    fi

    echo

    if ! validate_numeric_input "$limit_input" 0 1000000; then
        show_sanitization_error "push size threshold" "Please enter a number of MB (0 disables)."
        exit 1
    fi
    limit_input="$validated_number"

    set_push_warn_size "$limit_input"
    if [ "$limit_input" = "0" ]; then
        echo -e "${GREEN}✓ Disabled the push size warning for '${project_name}'${ENDCOLOR}"
    else
        echo -e "${GREEN}✓ Set the push size warning to ${limit_input} MB for '${project_name}'${ENDCOLOR}"
    fi
    echo

    [ "$GITBASHER_NO_REPO" = "true" ] && exit
    echo -e "Do you want to set it ${YELLOW}globally${ENDCOLOR} for all projects (Y/n)?"
    yes_no_choice "\nSet push size warning globally" "true"
    git config --global gitbasher.push-warn-size "$limit_input"
}


### Function asks user to configure AI diff payload size
# Controls how much of the staged diff is sent to the model. Two knobs:
#   - lines: head -n N applied to the diff (primary cap, intuitive for users)
#   - max chars: hard ceiling on the payload, protects against pathological
#     single-line diffs (e.g. a generated bundle line)
function configure_ai_diff {
    echo -e "${YELLOW}Configure AI Diff Payload Size${ENDCOLOR}"
    echo

    current_lines=$(get_ai_diff_limit)
    current_chars=$(get_ai_diff_max_chars)
    echo -e "Current diff line limit: ${GREEN}${current_lines}${ENDCOLOR} lines"
    echo -e "Current diff char cap:   ${GREEN}${current_chars}${ENDCOLOR} characters"
    echo
    echo -e "These settings control how much of the staged diff is sent to the AI."
    echo -e "Larger values give the model more context but use more tokens (cost more)."
    echo
    echo -e "Recommended ranges:"
    echo -e "• Line limit: ${BLUE}100-1000${ENDCOLOR} lines (default 300)"
    echo -e "• Char cap:   ${BLUE}8000-40000${ENDCOLOR} characters (default 20000, ~5000 tokens)"
    echo
    echo -e "Press Enter on either prompt to keep the current value"

    read_editable_input lines_input "New diff line limit: "
    if [ -n "$lines_input" ]; then
        if ! validate_numeric_input "$lines_input" 10 5000; then
            show_sanitization_error "diff line limit" "Please enter a positive number between 10 and 5000."
            exit 1
        fi
        lines_input="$validated_number"
        if [ "$lines_input" -lt 50 ] || [ "$lines_input" -gt 2000 ]; then
            echo -e "${YELLOW}⚠  Value is outside the recommended range (50-2000).${ENDCOLOR}"
            read -n 1 -p "Continue anyway? (Y/n) " -s choice || choice="n"
            echo
            if ! is_yes "$choice"; then
                exit
            fi
        fi
        set_ai_diff_limit "$lines_input"
        echo -e "${GREEN}✓ Set AI diff line limit to ${lines_input}${ENDCOLOR}"
    fi

    read_editable_input chars_input "New diff char cap: "
    if [ -n "$chars_input" ]; then
        if ! validate_numeric_input "$chars_input" 1000 200000; then
            show_sanitization_error "diff char cap" "Please enter a positive number between 1000 and 200000."
            exit 1
        fi
        chars_input="$validated_number"
        if [ "$chars_input" -lt 4000 ] || [ "$chars_input" -gt 100000 ]; then
            echo -e "${YELLOW}⚠  Value is outside the recommended range (4000-100000).${ENDCOLOR}"
            read -n 1 -p "Continue anyway? (Y/n) " -s choice || choice="n"
            echo
            if ! is_yes "$choice"; then
                exit
            fi
        fi
        set_ai_diff_max_chars "$chars_input"
        echo -e "${GREEN}✓ Set AI diff char cap to ${chars_input}${ENDCOLOR}"
    fi

    if [ -z "$lines_input" ] && [ -z "$chars_input" ]; then
        echo -e "${YELLOW}No changes.${ENDCOLOR}"
        exit
    fi

    echo
    [ "$GITBASHER_NO_REPO" = "true" ] && exit
    echo -e "Do you want to apply ${YELLOW}globally${ENDCOLOR} for all projects (Y/n)?"
    yes_no_choice "\nApply AI diff settings globally" "true"
    if [ -n "$lines_input" ]; then
        git config --global gitbasher.ai-diff-limit "$lines_input"
    fi
    if [ -n "$chars_input" ]; then
        git config --global gitbasher.ai-diff-max-chars "$chars_input"
    fi
}


### Function asks user to set scope
function set_scopes {
    echo -e "${YELLOW}Enter a list of predefined scopes${ENDCOLOR}"
    echo
    if [ "$scopes" == "" ]; then
        echo -e "${YELLOW}No scopes list is set.${ENDCOLOR}"
    else
        echo -e "Current scopes: ${YELLOW}$scopes${ENDCOLOR}"
    fi
    echo -e "Use English letters separated by spaces (max 9 scopes)."
    if [ "$scopes" != "" ]; then
        echo -e "Press Enter to exit without changes, or 0 to remove existing scopes"
    fi

    read_editable_input scopes_raw "Scopes: "

    if [ "$scopes_raw" == "" ]; then
        exit
    fi

    if [ "$scopes_raw" == "0" ]; then
        unset_config_value gitbasher.scopes

        echo
        echo -e "${GREEN}✓ Removed scopes list from '${project_name}'${ENDCOLOR}"
        exit
    fi

    echo

    # Validate scope list format
    if ! validate_scope_list "$scopes_raw"; then
        show_sanitization_error "scopes" "Use only letters and spaces, maximum 9 scopes (e.g., 'feat docs test')."
        exit 1
    fi
    scopes_raw="$validated_scopes"

    if [ "$GITBASHER_NO_REPO" = "true" ]; then
        git config --global --replace-all gitbasher.scopes "$scopes_raw"
        scopes="$scopes_raw"
        echo -e "${GREEN}✓ Set '${scopes}' as the global scopes list${ENDCOLOR}"
        return
    fi

    git config --local --replace-all gitbasher.scopes "$scopes_raw"

    scopes="$scopes_raw"

    echo -e "${GREEN}✓ Set '${scopes}' as the scopes list in '${project_name}'${ENDCOLOR}"
    echo

    [ "$GITBASHER_NO_REPO" = "true" ] && exit
    echo -e "Do you want to set it ${YELLOW}globally${ENDCOLOR} for all projects (Y/n)?"
    yes_no_choice "\nSet '${scopes}' globally" "true"

    git config --global --replace-all gitbasher.scopes "$scopes_raw"
}


### Function asks user to unset global
# Built dynamically because per-provider AI keys add a variable number of rows;
# each visible menu entry carries its own label and a "key:label" action that
# describes which git config key(s) to unset and what to call it in the
# success message.
function delete_global {
    echo -e "${YELLOW}Unset global config${ENDCOLOR}"
    echo
    echo -e "Select a cfg to unset from global settings"

    local -a labels=()
    local -a actions=()

    _delete_global_add() {
        # The RAW value gates the row; colors are applied here. Passing a
        # pre-colored string made the emptiness test always true (the color
        # codes alone are 15 chars), so every row showed even when unset and
        # picking one printed a success message for a no-op unset.
        local key="$1" label="$2" value="$3" color="${4:-$YELLOW}"
        if [ -n "$value" ]; then
            labels+=("${label}: ${color}${value}${ENDCOLOR}")
            actions+=("$key|$label")
        fi
    }

    local global_default=$(git config --global --get gitbasher.branch)
    _delete_global_add "gitbasher.branch" "Default branch" "$global_default"

    local global_sep=$(git config --global --get gitbasher.sep)
    _delete_global_add "gitbasher.sep" "Branch separator" "$global_sep"

    local global_editor=$(git config --global --get core.editor)
    _delete_global_add "core.editor" "Commit message editor" "$global_editor"

    local global_ticket=$(git config --global --get gitbasher.ticket)
    _delete_global_add "gitbasher.ticket" "Ticket prefix" "$global_ticket"

    local global_scopes=$(git config --global --get gitbasher.scopes)
    _delete_global_add "gitbasher.scopes" "Scopes list" "$global_scopes"

    # Keys gitbasher itself writes globally but previously offered no way
    # to remove (the Ollama host had NO removal path at all)
    local global_provider=$(git config --global --get gitbasher.ai-provider)
    _delete_global_add "gitbasher.ai-provider" "AI provider" "$global_provider" "$GREEN"

    local global_ollama_host=$(git config --global --get gitbasher.ai-ollama-host)
    _delete_global_add "gitbasher.ai-ollama-host" "Ollama host" "$global_ollama_host" "$GREEN"

    local global_base_url=$(git config --global --get gitbasher.ai-base-url)
    _delete_global_add "gitbasher.ai-base-url" "AI base URL" "$global_base_url" "$GREEN"

    # Covers the per-provider model slots and any stale pre-5.1 per-task keys.
    local _provider_models
    _provider_models=$(git config --global --get-regexp '^gitbasher\.ai-model-' 2>/dev/null | awk '{print $1}' | tr '\n' '+' | sed 's/+$//')
    if [ -n "$_provider_models" ]; then
        labels+=("AI models (per provider): ${GREEN}configured${ENDCOLOR}")
        actions+=("${_provider_models}|AI models (per provider)")
    fi

    # Per-provider AI keys; one row per provider that has a global key.
    while IFS=$'\t' read -r key_name; do
        [ -z "$key_name" ] && continue
        local prov="${key_name#gitbasher.ai-api-key-}"
        labels+=("AI API key (${prov}): ${GREEN}configured${ENDCOLOR}")
        actions+=("$key_name|AI API key (${prov})")
    done < <(git config --global --get-regexp '^gitbasher\.ai-api-key-' 2>/dev/null | awk '{print $1}')

    local global_legacy_key=$(git config --global --get gitbasher.ai-api-key)
    _delete_global_add "gitbasher.ai-api-key" "AI API key (legacy)" "${global_legacy_key:+configured}" "$GREEN"

    local global_ai_model=$(git config --global --get gitbasher.ai-model)
    _delete_global_add "gitbasher.ai-model" "AI model" "$global_ai_model" "$GREEN"

    local global_ai_proxy=$(git config --global --get gitbasher.ai-proxy)
    _delete_global_add "gitbasher.ai-proxy" "AI proxy" "$global_ai_proxy" "$GREEN"

    local global_ai_history=$(git config --global --get gitbasher.ai-commit-history-limit)
    _delete_global_add "gitbasher.ai-commit-history-limit" "AI commit history limit" "$global_ai_history" "$GREEN"

    local global_push_warn=$(git config --global --get gitbasher.push-warn-size)
    _delete_global_add "gitbasher.push-warn-size" "Push size warning" "${global_push_warn:+${global_push_warn} MB}" "$GREEN"

    local global_ai_diff_lines=$(git config --global --get gitbasher.ai-diff-limit)
    local global_ai_diff_chars=$(git config --global --get gitbasher.ai-diff-max-chars)
    if [ -n "$global_ai_diff_lines" ] || [ -n "$global_ai_diff_chars" ]; then
        local diff_summary=""
        [ -n "$global_ai_diff_lines" ] && diff_summary="${global_ai_diff_lines} lines"
        if [ -n "$global_ai_diff_chars" ]; then
            [ -n "$diff_summary" ] && diff_summary="${diff_summary}, "
            diff_summary="${diff_summary}${global_ai_diff_chars} chars"
        fi
        labels+=("AI diff payload: ${GREEN}${diff_summary}${ENDCOLOR}")
        # Two keys, one action — encode both, separator '+' inside the key field.
        actions+=("gitbasher.ai-diff-limit+gitbasher.ai-diff-max-chars|AI diff payload")
    fi

    if [ ${#labels[@]} -eq 0 ]; then
        echo -e "${GRAY}Nothing to unset — no global gitbasher settings are configured.${ENDCOLOR}"
        exit
    fi

    local i
    for i in "${!labels[@]}"; do
        echo -e "$((i + 1)). ${labels[$i]}"
    done
    echo -e "0. Exit"
    echo

    read_editable_input choice "Choice: "

    if [ "$choice" == "" ] || [ "$choice" == "0" ]; then
        exit
    fi

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#labels[@]}" ]; then
        echo -e "${RED}✗ Invalid choice.${ENDCOLOR}" >&2
        return 1
    fi

    echo

    local action="${actions[$((choice - 1))]}"
    local keys="${action%%|*}"
    local label="${action#*|}"
    local k
    IFS='+' read -ra _keys <<< "$keys"
    for k in "${_keys[@]}"; do
        git config --global --unset "$k" 2>/dev/null
    done
    echo -e "${GREEN}✓ Unset ${label} from global settings${ENDCOLOR}"
}


### Function asks user to set name and email
function set_user {
    echo -e "${YELLOW}Set user name and email${ENDCOLOR}"
    echo
    echo -e "Current name: ${YELLOW}$(get_config_value user.name)${ENDCOLOR}"
    echo -e "Enter new name or press Enter if you don't want to change it"
    read_editable_input user_name "Name: "

    echo
    echo -e "Current email: ${YELLOW}$(get_config_value user.email)${ENDCOLOR}"
    echo -e "Enter new email or press Enter if you don't want to change it"
    read_editable_input user_email "Email: "

    if [ "$user_name" == "" ] && [ "$user_email" == "" ]; then
        exit
    fi

    # Validate user inputs
    if [ "$user_name" != "" ]; then
        if ! sanitize_text_input "$user_name" 100; then
            show_sanitization_error "user name" "Use printable characters only, max 100 characters."
            exit 1
        fi
        user_name="$sanitized_text"
    fi

    if [ "$user_email" != "" ]; then
        if ! validate_email "$user_email"; then
            show_sanitization_error "email" "Please enter a valid email address."
            exit 1
        fi
        user_email="$validated_email"
    fi

    echo

    local _user_scope="--local"
    if [ "$GITBASHER_NO_REPO" = "true" ]; then
        _user_scope="--global"
    fi

    if [ "$user_name" != "" ]; then
        echo -e "${GREEN}✓ Set user name to '${user_name}'${ENDCOLOR}"
        git config "$_user_scope" --replace-all user.name "$user_name"
    fi
    if [ "$user_email" != "" ]; then
        echo -e "${GREEN}✓ Set user email to '${user_email}'${ENDCOLOR}"
        git config "$_user_scope" --replace-all user.email "$user_email"
    fi
}

### Main function
# $1: mode
    # empty: show current config
    # default: set main branch
    # sep: set branch separator
    # editor: set commit message editor
    # ticket: set prefix for tickets
    # scope: add list of scopes
    # delete: delete global config
    # user: set user name and email
function config_script {
    case "$1" in
        default|def|d|b|main) set_default_cfg="true";;
        separator|sep)        set_sep_cfg="true";;
        editor|ed|e)          set_editor_cfg="true";;
        ticket|jira|ti|t)     set_ticket_cfg="true";;
        scopes|scope|sc|s)    set_scopes_cfg="true";;
        ai|llm)               set_ai_cfg="true";;
        key)                  set_ai_key_cfg="true";;
        provider|prov)        set_ai_provider_cfg="true";;
        model|m)              set_ai_model_cfg="true";;
        proxy|prx|p)          set_proxy_cfg="true";;
        history|hist)         set_ai_history_cfg="true";;
        diff|payload)         set_ai_diff_cfg="true";;
        push-size|pushsize|ps) set_push_warn_cfg="true";;
        delete|unset|del)     delete_cfg="true";;
        user|name|email|u)    set_user_cfg="true";;
        auto|completion|comp) auto_cfg="true";;
        help|h)               help="true";;
        *)                    wrong_mode "config" $1
    esac

    ### Merge mode - print header
    header="GIT CONFIG"
    if [ -n "${set_default_cfg}" ]; then
        header="$header DEFAULT BRANCH"
    elif [ -n "${set_sep_cfg}" ]; then
        header="$header BRANCH SEPARATOR"
    elif [ -n "${set_editor_cfg}" ]; then
        header="$header COMMIT MESSAGE EDITOR"
    elif [ -n "${set_ticket_cfg}" ]; then
        header="$header TICKET PREFIX"
    elif [ -n "${set_scopes_cfg}" ]; then
        header="$header SCOPES LIST"
    elif [ -n "${set_ai_cfg}" ]; then
        header="$header AI SETUP"
    elif [ -n "${set_ai_key_cfg}" ]; then
        header="$header AI API KEY"
    elif [ -n "${set_ai_provider_cfg}" ]; then
        header="$header AI PROVIDER"
    elif [ -n "${set_ai_model_cfg}" ]; then
        header="$header AI MODEL"
    elif [ -n "${set_proxy_cfg}" ]; then
        header="$header AI PROXY"
    elif [ -n "${set_ai_history_cfg}" ]; then
        header="$header AI COMMIT HISTORY"
    elif [ -n "${set_ai_diff_cfg}" ]; then
        header="$header AI DIFF PAYLOAD"
    elif [ -n "${set_push_warn_cfg}" ]; then
        header="$header PUSH SIZE WARNING"
    elif [ -n "${delete_cfg}" ]; then
        header="$header UNSET GLOBAL CONFIG"
    elif [ -n "${set_user_cfg}" ]; then
        header="$header USER NAME & EMAIL"
    elif [ -n "${auto_cfg}" ]; then
        header="$header TAB COMPLETION"
    fi

    # `cfg auto print` writes the completion script to stdout for piping;
    # decorations would corrupt the output, so skip the header in that case.
    local _suppress_header=""
    if [ -n "${auto_cfg}" ]; then
        case "$2" in
            print|cat|p) _suppress_header="true" ;;
        esac
    fi
    if [ -z "$_suppress_header" ]; then
        echo -e "${YELLOW}${header}${ENDCOLOR}"
        echo
    fi

    if [ "$set_user_cfg" == "true" ]; then
        set_user
        exit
    fi

    if [ "$set_default_cfg" == "true" ]; then
        set_default_branch
        exit
    fi

    if [ "$set_sep_cfg" == "true" ]; then
        set_sep
        exit
    fi

    if [ "$set_editor_cfg" == "true" ]; then
        set_editor
        exit
    fi

    if [ "$set_ticket_cfg" == "true" ]; then
        set_ticket
        exit
    fi

    if [ "$set_scopes_cfg" == "true" ]; then
        set_scopes
        exit
    fi

    if [ "$set_ai_cfg" == "true" ]; then
        configure_ai_wizard
        exit
    fi

    if [ "$set_ai_key_cfg" == "true" ]; then
        configure_ai_key
        exit
    fi

    if [ "$set_ai_provider_cfg" == "true" ]; then
        configure_ai_provider
        exit
    fi

    if [ "$set_ai_model_cfg" == "true" ]; then
        configure_ai_model
        exit
    fi

    if [ "$set_proxy_cfg" == "true" ]; then
        configure_ai_proxy
        exit
    fi

    if [ "$set_ai_history_cfg" == "true" ]; then
        configure_ai_history
        exit
    fi

    if [ "$set_ai_diff_cfg" == "true" ]; then
        configure_ai_diff
        exit
    fi

    if [ "$set_push_warn_cfg" == "true" ]; then
        configure_push_warn_size
        exit
    fi

    if [ "$delete_cfg" == "true" ]; then
        delete_global
        exit
    fi

    if [ "$auto_cfg" == "true" ]; then
        completion_script "$2" "$3"
        exit
    fi

    if [ -n "$help" ]; then
        echo -e "usage: ${YELLOW}gitb config <mode>${ENDCOLOR}"
        echo
        local PAD=26
        print_help_header $PAD
        print_help_row $PAD "<empty>"   ""                  "Print current gitbasher configuration"
        print_help_row $PAD "user"      "name, email, u"    "Set user name and email"
        print_help_row $PAD "default"   "def, d, b, main"   "Set gitbasher's default branch (local only — does not change the remote)"
        print_help_row $PAD "separator" "sep, s"            "Set the separator between type and name in branches"
        print_help_row $PAD "editor"    "ed, e"             "Set the editor for commit messages"
        print_help_row $PAD "ticket"    "ti, t, jira"       "Set the ticket prefix used in commits and branches"
        print_help_row $PAD "scopes"    "sc"                "Set the list of suggested commit scopes"
        print_help_row $PAD "ai"        "llm"               "Set up AI: provider, API key, and model (wizard)"
        print_help_row $PAD "key"       ""                  "Set the AI API key only"
        print_help_row $PAD "provider"  "prov"              "Choose the AI provider (openrouter, openai, ollama, claude)"
        print_help_row $PAD "model"     "m"                 "Set the AI model override"
        print_help_row $PAD "proxy"     "prx, p"            "Set an HTTP/SOCKS proxy for AI requests"
        print_help_row $PAD "history"   "hist"              "Set how many recent commits to include in AI prompts"
        print_help_row $PAD "diff"      "payload"           "Set the diff payload size (lines and char cap) sent to AI"
        print_help_row $PAD "push-size" "ps, pushsize"      "Warn before pushing more than N MB (0 disables)"
        print_help_row $PAD "auto"      "completion, comp"  "Install/remove tab completion for bash, zsh, or fish"
        print_help_row $PAD "delete"    "unset, del"        "Unset a global gitbasher configuration value"
        print_help_row $PAD "help"      "h"                 "Show this help"
        echo
        echo -e "${YELLOW}Examples${ENDCOLOR}"
        echo -e "  ${GREEN}gitb cfg${ENDCOLOR}            Show current configuration"
        echo -e "  ${GREEN}gitb cfg user${ENDCOLOR}       Set user.name and user.email"
        echo -e "  ${GREEN}gitb cfg default${ENDCOLOR}    Choose the default gitbasher branch"
        echo -e "  ${GREEN}gitb cfg ai${ENDCOLOR}         Interactive AI setup (provider, key, model)"
        exit
    fi

    print_configuration
}
