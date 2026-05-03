#!/usr/bin/env bash

### AI Functions for commit message generation

# Built-in providers. Each speaks the OpenAI /chat/completions schema, so only
# the base URL and auth handling differ. Custom base URLs override these via
# gitbasher.ai-base-url.
readonly OPENROUTER_API_URL="https://openrouter.ai/api/v1/chat/completions"
readonly OPENAI_API_URL="https://api.openai.com/v1/chat/completions"
readonly OLLAMA_API_URL="http://localhost:11434/v1/chat/completions"

# Default provider when gitbasher.ai-provider is unset — keeps existing setups working.
readonly AI_DEFAULT_PROVIDER="openrouter"

# Sampling temperature for commit-message generation. Low enough to keep the
# conventional-commit format consistent, high enough that pressing 'r' to
# regenerate produces a meaningfully different phrasing.
readonly AI_TEMPERATURE="0.3"

# Per-mode max_tokens caps. These bound runaway output if the model loops or
# misreads the format; they are NOT a target — the model stops at EOS and only
# bills for tokens it actually generates. Sized generously so legitimate output
# never gets truncated mid-message, including code-heavy or non-English content
# that tokenizes 2-4x worse than plain English.
readonly AI_MAX_TOKENS_SUBJECT=256
readonly AI_MAX_TOKENS_SIMPLE=512
readonly AI_MAX_TOKENS_FULL=1024

### Function to get AI API key from environment variable or git config
# Checks environment variable GITB_AI_API_KEY first, then falls back to git config
# Returns: AI API key or empty if not set
function get_ai_api_key {
    # First check environment variable (more secure)
    if [ -n "$GITB_AI_API_KEY" ]; then
        echo "$GITB_AI_API_KEY"
        return
    fi

    # Fall back to git config
    get_config_value gitbasher.ai-api-key ""
}

### Function to set AI API key in git config
# $1: API key
function set_ai_api_key {
    set_config_value gitbasher.ai-api-key "$1"
}

### Function to get the configured AI provider (openrouter | openai | ollama).
# Falls back to AI_DEFAULT_PROVIDER so existing setups keep targeting OpenRouter.
function get_ai_provider {
    local provider
    provider=$(get_config_value gitbasher.ai-provider "$AI_DEFAULT_PROVIDER")
    # Normalize to lowercase to make case-insensitive matches downstream
    echo "$provider" | tr '[:upper:]' '[:lower:]'
}

function set_ai_provider {
    set_config_value gitbasher.ai-provider "$1"
}

### Function to get/set a custom AI base URL (overrides the provider's default).
# Useful for self-hosted OpenAI-compatible gateways (LiteLLM, vLLM, LM Studio, …)
# or a non-default Ollama host.
function get_ai_base_url {
    get_config_value gitbasher.ai-base-url ""
}

function set_ai_base_url {
    set_config_value gitbasher.ai-base-url "$1"
}

### Resolve the chat-completions URL for the active provider.
# Custom base URL wins; otherwise pick the built-in for the provider.
function get_ai_api_url {
    local custom_url
    custom_url=$(get_ai_base_url)
    if [ -n "$custom_url" ]; then
        echo "$custom_url"
        return
    fi

    case "$(get_ai_provider)" in
        openai)  echo "$OPENAI_API_URL" ;;
        ollama)  echo "$OLLAMA_API_URL" ;;
        *)       echo "$OPENROUTER_API_URL" ;;
    esac
}

### Whether the active provider needs an API key.
# Local Ollama servers don't authenticate by default.
function ai_provider_requires_api_key {
    case "$(get_ai_provider)" in
        ollama) return 1 ;;
        *)      return 0 ;;
    esac
}

### Function to get/set AI model — global override.
# When set, it wins over the per-task defaults below for every task. When unset
# (the typical case for new users), each task uses its own per-task default.
# Returns: explicit user override or empty when nothing has been set.
function get_ai_model {
    get_config_value gitbasher.ai-model ""
}

function set_ai_model {
    set_config_value gitbasher.ai-model "$1"
}

### Per-task default model IDs (OpenRouter).
# Picked May 2026 for the speed / cost / quality balance that fits each task:
#   - simple/subject (short structured output, runs interactively): the cheapest
#     fast tier with strong format compliance.
#   - full (header + body): a small step up — body prose quality matters more.
#   - grouping (TSV scope→file mapping, validated downstream): strict instruction
#     following matters; this only fires when the heuristic is weak so the higher
#     per-call cost is bounded.
# Update these when newer GA models supersede the current preview slugs.
readonly AI_DEFAULT_MODEL_SIMPLE="google/gemini-3.1-flash-lite-preview"
readonly AI_DEFAULT_MODEL_SUBJECT="google/gemini-3.1-flash-lite-preview"
readonly AI_DEFAULT_MODEL_FULL="google/gemini-3-flash-preview"
readonly AI_DEFAULT_MODEL_GROUPING="anthropic/claude-haiku-4.5"

# OpenAI per-task defaults (May 2026, GPT-5.4 family).
#   - nano ($0.20 / $1.25 per M tokens): tuned for classification, data
#     extraction, ranking, and short well-defined interactions — exactly
#     matches the simple/subject one-line output. Use here.
#   - mini ($0.75 / $4.50 per M): handles multi-condition instructions and
#     formatting requirements applied simultaneously — right tier for full-mode
#     prose and the validated TSV grouping output, both far cheaper than the
#     gpt-5.4 flagship without losing format compliance.
readonly AI_DEFAULT_MODEL_SIMPLE_OPENAI="gpt-5.4-nano"
readonly AI_DEFAULT_MODEL_SUBJECT_OPENAI="gpt-5.4-nano"
readonly AI_DEFAULT_MODEL_FULL_OPENAI="gpt-5.4-mini"
readonly AI_DEFAULT_MODEL_GROUPING_OPENAI="gpt-5.4-mini"

# Ollama per-task default (May 2026): qwen3:8b leads the 7/8B class on
# instruction-following benchmarks and produces the most stable structured
# output among locally-runnable models (it stays in the conventional-commit
# format and rarely drops fields in TSV output). ~5 GB on disk, ~25 tok/s on a
# consumer laptop with GPU acceleration. Override with `gitb cfg model` to
# match what `ollama list` shows on your machine.
readonly AI_DEFAULT_MODEL_SIMPLE_OLLAMA="qwen3:8b"
readonly AI_DEFAULT_MODEL_SUBJECT_OLLAMA="qwen3:8b"
readonly AI_DEFAULT_MODEL_FULL_OLLAMA="qwen3:8b"
readonly AI_DEFAULT_MODEL_GROUPING_OLLAMA="qwen3:8b"

### Resolve the model to use for a specific task.
# Resolution order:
#   1. gitbasher.ai-model-<task>  (per-task override, e.g. gitbasher.ai-model-simple)
#   2. gitbasher.ai-model         (global override, set by `gitb cfg model`)
#   3. AI_DEFAULT_MODEL_<TASK>    (the recommended default above)
# $1: task name — one of "simple", "subject", "full", "grouping"
function get_ai_model_for {
    local task="$1"

    local task_model
    task_model=$(get_config_value "gitbasher.ai-model-$task" "")
    if [ -n "$task_model" ]; then
        echo "$task_model"
        return
    fi

    local global_model
    global_model=$(get_ai_model)
    if [ -n "$global_model" ]; then
        echo "$global_model"
        return
    fi

    case "$(get_ai_provider)" in
        openai)
            case "$task" in
                simple)   echo "$AI_DEFAULT_MODEL_SIMPLE_OPENAI" ;;
                subject)  echo "$AI_DEFAULT_MODEL_SUBJECT_OPENAI" ;;
                full)     echo "$AI_DEFAULT_MODEL_FULL_OPENAI" ;;
                grouping) echo "$AI_DEFAULT_MODEL_GROUPING_OPENAI" ;;
                *)        echo "$AI_DEFAULT_MODEL_SIMPLE_OPENAI" ;;
            esac
            ;;
        ollama)
            case "$task" in
                simple)   echo "$AI_DEFAULT_MODEL_SIMPLE_OLLAMA" ;;
                subject)  echo "$AI_DEFAULT_MODEL_SUBJECT_OLLAMA" ;;
                full)     echo "$AI_DEFAULT_MODEL_FULL_OLLAMA" ;;
                grouping) echo "$AI_DEFAULT_MODEL_GROUPING_OLLAMA" ;;
                *)        echo "$AI_DEFAULT_MODEL_SIMPLE_OLLAMA" ;;
            esac
            ;;
        *)
            case "$task" in
                simple)   echo "$AI_DEFAULT_MODEL_SIMPLE" ;;
                subject)  echo "$AI_DEFAULT_MODEL_SUBJECT" ;;
                full)     echo "$AI_DEFAULT_MODEL_FULL" ;;
                grouping) echo "$AI_DEFAULT_MODEL_GROUPING" ;;
                *)        echo "$AI_DEFAULT_MODEL_SIMPLE" ;;
            esac
            ;;
    esac
}

### Set the model for a specific task (per-task override).
# $1: task name; $2: model id (empty string clears the override)
function set_ai_model_for {
    set_config_value "gitbasher.ai-model-$1" "$2"
}

### Function to get AI proxy URL from git config
# Returns: Proxy URL or empty if not set
function get_ai_proxy {
    get_config_value gitbasher.ai-proxy ""
}

### Function to set AI proxy URL in git config
# $1: Proxy URL (e.g., http://proxy.example.com:8080 or http://user:pass@proxy.example.com:8080)
function set_ai_proxy {
    set_config_value gitbasher.ai-proxy "$1"
}

### Function to get AI diff limit from git config
# Returns: Maximum number of diff lines to include in AI prompts (default: 300)
function get_ai_diff_limit {
    get_config_value gitbasher.ai-diff-limit "300"
}

### Function to set AI diff limit in git config
# $1: Maximum number of diff lines (recommended: 100-1000)
function set_ai_diff_limit {
    set_config_value gitbasher.ai-diff-limit "$1"
}

### Function to get AI diff max chars from git config
# Returns: Maximum diff payload size in characters; secondary cap that prevents
# pathological single-line diffs from blowing up the prompt (default: 20000,
# roughly 5000 tokens)
function get_ai_diff_max_chars {
    get_config_value gitbasher.ai-diff-max-chars "20000"
}

### Function to set AI diff max chars in git config
# $1: Maximum diff payload size in characters (recommended: 8000-40000)
function set_ai_diff_max_chars {
    set_config_value gitbasher.ai-diff-max-chars "$1"
}

### Function to get AI commit history limit from git config
# Returns: Maximum number of recent commits to include in AI prompts (default: 10)
function get_ai_commit_history_limit {
    get_config_value gitbasher.ai-commit-history-limit "10"
}

### Function to set AI commit history limit in git config
# $1: Maximum number of recent commits to include (recommended: 5-15)
function set_ai_commit_history_limit {
    set_config_value gitbasher.ai-commit-history-limit "$1"
}

### Function to mask API key for display, showing only last 4 characters
# $1: API key to mask
# Returns: Masked API key string with asterisks
function mask_api_key {
    local api_key="$1"
    if [ -z "$api_key" ]; then
        echo ""
        return
    fi
    
    local length=${#api_key}
    if [ $length -le 4 ]; then
        echo "$api_key"
        return
    fi
    
    local visible_chars="${api_key:(-4)}"
    echo "********${visible_chars}"
}

### Function to get limited diff content for AI prompts
# Returns: Diff content limited by configurable line and character caps
function get_limited_diff_for_ai {
    local diff_limit=$(get_ai_diff_limit)
    local max_chars=$(get_ai_diff_max_chars)

    # Get diff limited by lines
    local diff_content=$(git diff --cached | head -n "$diff_limit")

    # Further limit by character count to ensure we don't exceed token limits
    local char_count=${#diff_content}
    if [ "$char_count" -gt "$max_chars" ]; then
        diff_content=$(echo "$diff_content" | head -c "$max_chars")
        diff_content="${diff_content}... [truncated for token limit]"
    fi

    echo "$diff_content"
}

### Function to get limited staged files list for AI prompts
# Each entry includes the per-file action (added/modified/deleted/renamed/copied)
# so the model knows the full scope of the commit even when the actual diff is
# truncated. File-list output is cheap (one line per file) so the safety caps
# are generous compared to the diff caps — the goal is to almost never truncate
# this section on real commits.
function get_limited_staged_files_for_ai {
    local max_files=1000
    local max_chars=50000

    # --name-status emits one line per file: <CODE><TAB><path> for A/M/D/T,
    # or <CODE><sim><TAB><old><TAB><new> for renames (R) and copies (C).
    local raw=$(git diff --cached --name-status)
    if [ -z "$raw" ]; then
        echo ""
        return
    fi

    # Translate single-letter action codes into human-readable labels and
    # left-align them so the column is easy to scan. Unknown codes pass
    # through verbatim as a fallback.
    local formatted=$(echo "$raw" | LC_ALL=C awk -F'\t' '
        {
            code = substr($1, 1, 1)
            label = code
            if      (code == "A") label = "added"
            else if (code == "M") label = "modified"
            else if (code == "D") label = "deleted"
            else if (code == "R") label = "renamed"
            else if (code == "C") label = "copied"
            else if (code == "T") label = "type changed"

            if ((code == "R" || code == "C") && NF >= 3) {
                printf "%-13s %s -> %s\n", label ":", $2, $3
            } else {
                printf "%-13s %s\n", label ":", $2
            }
        }
    ')

    local total_files=$(echo "$formatted" | wc -l | tr -d ' ')

    if [ "$total_files" -gt "$max_files" ]; then
        formatted=$(echo "$formatted" | head -n "$max_files")
        formatted="${formatted}
... and $((total_files - max_files)) more files (${total_files} total)"
    fi

    # Char-cap as a final safety net for pathological cases (e.g. very long paths)
    local char_count=${#formatted}
    if [ "$char_count" -gt "$max_chars" ]; then
        formatted=$(echo "$formatted" | head -c "$max_chars")
        formatted="${formatted}... [truncated, ${total_files} files total]"
    fi

    echo "$formatted"
}

### Function to get limited diff stat for AI prompts
# Returns: Diff stat output limited to prevent token overflow on large commits
function get_limited_diff_stat_for_ai {
    local max_lines=50
    local max_chars=2000

    local diff_stat=$(git diff --cached --stat)
    local total_lines=$(echo "$diff_stat" | wc -l | tr -d ' ')

    if [ "$total_lines" -gt "$max_lines" ]; then
        # Keep the summary line (last line of --stat) and first N-1 file lines
        local summary_line=$(echo "$diff_stat" | tail -n 1)
        diff_stat=$(echo "$diff_stat" | head -n "$((max_lines - 1))")
        diff_stat="${diff_stat}
... ($((total_lines - max_lines)) more files not shown)
${summary_line}"
    fi

    # Further limit by character count
    local char_count=${#diff_stat}
    if [ "$char_count" -gt "$max_chars" ]; then
        diff_stat=$(echo "$diff_stat" | head -c "$max_chars")
        diff_stat="${diff_stat}... [truncated]"
    fi

    echo "$diff_stat"
}

### Function to get recent commit messages for AI context
# Returns: Recent commit messages formatted for AI prompt
function get_recent_commit_messages_for_ai {
    local limit=$(get_ai_commit_history_limit)  # Use configurable limit
    local max_chars=1000  # Character limit to save tokens
    
    # Get recent commit messages (excluding merge commits)
    local recent_commits=$(git log --no-merges --pretty=format:"%s" -n "$limit" 2>/dev/null | head -c "$max_chars")
    
    if [ -z "$recent_commits" ]; then
        echo "No commit history available."
        return
    fi
    
    echo "$recent_commits"
}

### Function to validate and sanitize proxy URL to prevent command injection
# $1: proxy URL to validate
# Returns: 0 if valid, 1 if invalid
# Sets: validated_proxy_url variable with sanitized URL
function validate_proxy_url {
    local proxy_url="$1"
    validated_proxy_url=""

    if [ -z "$proxy_url" ]; then
        return 1
    fi

    # Reject pathological lengths up front — real proxy URLs are well under 2 KB
    if [ ${#proxy_url} -gt 2048 ]; then
        return 1
    fi

    # Defense in depth: curl receives the URL as a single arg (no shell injection),
    # but a clean string makes downstream auditing and logs less noisy.
    local cleaned_url=$(echo "$proxy_url" | sed 's/[^a-zA-Z0-9.:/@_%?&=-]//g')

    local port=""
    # http(s) | socks5 with optional userinfo, capped host length, mandatory port, optional path
    if [[ "$cleaned_url" =~ ^(https?|socks5)://([a-zA-Z0-9._%-]+(:[a-zA-Z0-9._%-]+)?@)?([a-zA-Z0-9.-]{1,253}):([0-9]{1,5})(/.*)?$ ]]; then
        port="${BASH_REMATCH[5]}"
    elif [[ "$cleaned_url" =~ ^([a-zA-Z0-9.-]{1,253}):([0-9]{1,5})$ ]]; then
        # Bare host:port shorthand — curl treats it as http://
        port="${BASH_REMATCH[2]}"
    else
        return 1
    fi

    # Port must be in the valid TCP range
    if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        return 1
    fi

    validated_proxy_url="$cleaned_url"
    return 0
}

### Function to securely call curl with API key
# This prevents API key exposure in process lists by using a subshell.
# $1: proxy_url (can be empty)
# $2: api_key value (empty for unauthenticated providers like local Ollama)
# $3: json_payload
# $4: target API URL (full /chat/completions endpoint)
# $5: provider name — controls which provider-specific headers are sent
function secure_curl_with_api_key {
    local proxy_url="$1"
    local api_key="$2"
    local json_payload="$3"
    local api_url="$4"
    local provider="$5"

    # Execute curl in a subshell to minimize API key exposure
    (
        # Disable shell tracing inside the subshell so the API key cannot leak via `set -x` output
        { set +x; } 2>/dev/null
        # Unset any potentially exported variables
        unset HISTFILE

        # Build curl command with proper array handling
        local curl_cmd=(
            curl -s -X POST
            --connect-timeout 30
            --max-time 60
        )

        # Add proxy if specified
        if [ -n "$proxy_url" ]; then
            curl_cmd+=(--proxy "$proxy_url")
        fi

        curl_cmd+=(
            "$api_url"
            -H "Content-Type: application/json"
        )

        # Auth header is only sent when we actually have a key. Local Ollama
        # rejects nothing if it's present, but skipping it keeps the request
        # clean and avoids leaking unrelated keys to a misconfigured endpoint.
        if [ -n "$api_key" ]; then
            curl_cmd+=(-H "Authorization: Bearer $api_key")
        fi

        # OpenRouter uses these headers for attribution / leaderboards. Other
        # providers ignore them, but there's no reason to send them either.
        if [ "$provider" = "openrouter" ]; then
            curl_cmd+=(
                -H "HTTP-Referer: https://github.com/maxbolgarin/gitbasher"
                -H "X-Title: gitbasher"
            )
        fi

        curl_cmd+=(-d "$json_payload")

        # Execute the curl command
        "${curl_cmd[@]}" 2>&1
    )
}

### Escape a string for embedding inside JSON double quotes (fallback when jq is unavailable).
# Returns the escaped body WITHOUT the surrounding quotes.
# LC_ALL=C avoids "illegal byte sequence" errors from BSD sed on macOS when the
# input contains non-UTF-8-validatable bytes (e.g. Russian or other non-ASCII content in diffs).
function _json_escape_for_payload {
    printf '%s' "$1" \
        | LC_ALL=C sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e $'s/\t/\\\\t/g' -e $'s/\r/\\\\r/g' \
        | LC_ALL=C awk 'BEGIN{ORS=""} NR>1{print "\\n"} {print}'
}

### Function to make a chat-completions request against the configured AI provider.
# $1: system prompt (instructions: role, task, types, rules, examples, output format)
# $2: user prompt (data: recent commits, staged files, diff, scopes)
# $3: max_tokens cap on the response (default: AI_MAX_TOKENS_FULL)
# $4: model id (default: get_ai_model_for "simple" — keeps single-arg legacy callers working)
# Returns: AI response text
function call_ai_api {
    # Set trap to clear sensitive variables on exit/interrupt
    trap 'clear_sensitive_vars' EXIT INT TERM

    local system_prompt="$1"
    local user_prompt="$2"
    local max_tokens="${3:-$AI_MAX_TOKENS_FULL}"
    local model="${4:-$(get_ai_model_for simple)}"
    local provider=$(get_ai_provider)
    local api_url=$(get_ai_api_url)
    local api_key=$(get_ai_api_key)
    local max_retries=2
    local retry_delay=2

    # Local providers (Ollama) don't require a key; everyone else does.
    if [ -z "$api_key" ] && ai_provider_requires_api_key; then
        echo -e "${RED}AI API key not configured for provider '${provider}'. Set it with: gitb config${ENDCOLOR}" >&2
        clear_sensitive_vars
        return 1
    fi

    # Build OpenAI-style payload for OpenRouter.
    # Prefer jq for robust JSON encoding; fall back to sed/awk that preserves newlines as JSON \n.
    local json_payload
    if command -v jq &>/dev/null; then
        json_payload=$(jq -nc \
            --arg model "$model" \
            --arg system "$system_prompt" \
            --arg user "$user_prompt" \
            --argjson temperature "$AI_TEMPERATURE" \
            --argjson max_tokens "$max_tokens" \
            '{model: $model, messages: [{role: "system", content: $system}, {role: "user", content: $user}], temperature: $temperature, max_tokens: $max_tokens}')
    else
        local system_escaped=$(_json_escape_for_payload "$system_prompt")
        local user_escaped=$(_json_escape_for_payload "$user_prompt")
        json_payload="{\"model\":\"$model\",\"messages\":[{\"role\":\"system\",\"content\":\"$system_escaped\"},{\"role\":\"user\",\"content\":\"$user_escaped\"}],\"temperature\":$AI_TEMPERATURE,\"max_tokens\":$max_tokens}"
    fi

    # Make API request with optional proxy and retry logic
    local proxy_url=$(get_ai_proxy)
    local safe_proxy_url=""
    local response=""
    local curl_exit_code=0
    local retry_count=0
    
    if [ -n "$proxy_url" ]; then
        # Validate and sanitize proxy URL to prevent command injection
        if ! validate_proxy_url "$proxy_url"; then
            echo -e "${RED}✗ Invalid proxy URL format: $proxy_url${ENDCOLOR}" >&2
            echo -e "${YELLOW}Expected format: protocol://host:port (e.g., http://proxy.example.com:8080)${ENDCOLOR}" >&2
            echo -e "${YELLOW}Or: host:port (e.g., proxy.example.com:8080)${ENDCOLOR}" >&2
            clear_sensitive_vars
            return 1
        fi
        
        # Use the validated proxy URL
        safe_proxy_url="$validated_proxy_url"
    fi
    
    # Retry logic for server errors
    while [ $retry_count -le $max_retries ]; do
        if [ -n "$safe_proxy_url" ]; then
            response=$(secure_curl_with_api_key "$safe_proxy_url" "$api_key" "$json_payload" "$api_url" "$provider")
        else
            response=$(secure_curl_with_api_key "" "$api_key" "$json_payload" "$api_url" "$provider")
        fi
        
        curl_exit_code=$?
        
        # If successful or non-retryable error, break
        if [ $curl_exit_code -eq 0 ] && [ -n "$response" ]; then
            # Check if it's a server error that we should retry
            local has_error=$(echo "$response" | grep -q '"error"' && echo "true" || echo "false")
            if [ "$has_error" = "true" ]; then
                local error_code=$(echo "$response" | grep -o '"code"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*')
                # Only retry on 500/502/503 errors
                if [[ "$error_code" =~ ^(500|502|503)$ ]]; then
                    if [ $retry_count -lt $max_retries ]; then
                        echo -e "${YELLOW}Server error $error_code, retrying in ${retry_delay}s... (attempt $((retry_count + 1))/$((max_retries + 1)))${ENDCOLOR}" >&2
                        sleep $retry_delay
                        retry_count=$((retry_count + 1))
                        continue
                    fi
                fi
            fi
        fi
        
        # Break if successful or max retries reached
        break
    done
    
    if [ $curl_exit_code -ne 0 ] || [ -z "$response" ]; then
        echo
        echo -e "${RED}✗ Cannot connect to AI service.${ENDCOLOR}" >&2
        echo -e "${YELLOW}Debug Information:${ENDCOLOR}" >&2
        echo -e "  • Curl exit code: $curl_exit_code" >&2
        echo -e "  • Response length: ${#response}" >&2
        
        if [ -n "$safe_proxy_url" ]; then
            echo -e "  • Using proxy: $safe_proxy_url" >&2
            echo -e "${YELLOW}Proxy troubleshooting:${ENDCOLOR}" >&2
            echo -e "  • Test proxy: ${BOLD}curl --proxy '$safe_proxy_url' --connect-timeout 10 https://ifconfig.me${ENDCOLOR}" >&2
            echo -e "  • Test direct: ${BOLD}curl --connect-timeout 10 https://ifconfig.me${ENDCOLOR}" >&2
            echo -e "  • Configure different proxy: gitb cfg proxy" >&2
            
            # Test proxy connectivity
            echo -e "${YELLOW}Testing proxy connectivity...${ENDCOLOR}" >&2
            local proxy_test=$(curl --proxy "$safe_proxy_url" --connect-timeout 5 --max-time 10 -s https://ifconfig.me 2>&1)
            local proxy_test_code=$?
            if [ $proxy_test_code -eq 0 ]; then
                echo -e "  ${GREEN}✓ Proxy connection working${ENDCOLOR}" >&2
                echo -e "  Your IP via proxy: $(echo "$proxy_test" | head -1)" >&2
            else
                echo -e "  ${RED}✗ Proxy connection failed (exit code: $proxy_test_code)${ENDCOLOR}" >&2
                echo -e "  Error: $proxy_test" >&2
            fi
        else
            # Pull just the scheme+host out of the full chat-completions URL so
            # the connectivity probe targets the right endpoint per provider.
            local probe_host=$(echo "$api_url" | sed -E 's#^(https?://[^/]+).*#\1#')
            echo -e "  • No proxy configured" >&2
            echo -e "  • Provider: ${provider}" >&2
            echo -e "${YELLOW}Direct connection troubleshooting:${ENDCOLOR}" >&2
            echo -e "  • Test connection: ${BOLD}curl --connect-timeout 10 ${probe_host}${ENDCOLOR}" >&2

            echo -e "${YELLOW}Testing direct connectivity to ${probe_host}...${ENDCOLOR}" >&2
            local direct_test=$(curl --connect-timeout 5 --max-time 10 -s -I "$probe_host" 2>&1)
            local direct_test_code=$?
            if [ $direct_test_code -eq 0 ]; then
                echo -e "  ${GREEN}✓ ${provider} endpoint reachable${ENDCOLOR}" >&2
            else
                echo -e "  ${RED}✗ ${provider} endpoint failed (exit code: $direct_test_code)${ENDCOLOR}" >&2
                echo -e "  Error: $(echo "$direct_test" | head -1)" >&2
                if [ "$provider" = "ollama" ]; then
                    echo -e "  ${CYAN}💡 Make sure the Ollama daemon is running: ${BOLD}ollama serve${ENDCOLOR}" >&2
                else
                    echo -e "  ${CYAN}💡 Consider configuring a proxy: ${GREEN}gitb cfg proxy${ENDCOLOR}" >&2
                fi
            fi
        fi
        
        # Show partial response if any
        if [ -n "$response" ]; then
            echo -e "${YELLOW}Partial response received:${ENDCOLOR}" >&2
            echo "$response" | head -3 >&2
            echo -e "${YELLOW}...${ENDCOLOR}" >&2
        fi
        
        clear_sensitive_vars
        return 1
    fi
    
    # Debug: show raw response (uncomment for debugging)
    # echo "DEBUG: Raw response: $response" >&2
    
    # Check for API error - handle multi-line JSON properly
    local has_error=$(echo "$response" | grep -q '"error"' && echo "true" || echo "false")
    
    if [ "$has_error" = "true" ]; then
        # Extract error details
        local error_code=""
        local error_message=""
        if command -v jq &>/dev/null; then
            error_code=$(echo "$response" | jq -r '.error.code // empty' 2>/dev/null)
            error_message=$(echo "$response" | jq -r '.error.message // empty' 2>/dev/null)
        else
            error_code=$(echo "$response" | LC_ALL=C grep -o '"code"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*')
            error_message=$(echo "$response" | LC_ALL=C grep -o '"message"[[:space:]]*:[[:space:]]*"[^"]*"' | LC_ALL=C sed 's/"message"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/')
        fi
        
        echo >&2
        echo -e "${RED}AI API Error${ENDCOLOR}" >&2
        if [ -n "$error_code" ]; then
            echo -e "${RED}✗ Error code: $error_code${ENDCOLOR}" >&2
        fi
        if [ -n "$error_message" ]; then
            echo -e "${RED}✗ Error message: $error_message${ENDCOLOR}" >&2
        fi
        
        # Show full API response for debugging
        echo >&2
        echo -e "${YELLOW}📋 Full API Response:${ENDCOLOR}"
        echo "$response" >&2
        echo >&2
        
        # Provide helpful suggestions based on error type
        case "$error_code" in
            400)
                if [[ "$error_message" == *"context"* ]] || [[ "$error_message" == *"token"* ]] || [[ "$error_message" == *"too long"* ]] || [[ "$error_message" == *"length"* ]]; then
                    echo -e "${YELLOW}📏 Prompt too large: Too many staged files or changes for the AI model.${ENDCOLOR}" >&2
                    echo -e "${YELLOW}Solutions:${ENDCOLOR}" >&2
                    echo -e "${YELLOW}  • Reduce the diff limit: gitb cfg history${ENDCOLOR}" >&2
                    echo -e "${YELLOW}  • Try a model with larger context: gitb cfg model${ENDCOLOR}" >&2
                    echo -e "${YELLOW}  • Use manual commit message for now: gitb c${ENDCOLOR}" >&2
                else
                    echo -e "${YELLOW}⚠️  Bad request: Check your API configuration or prompt format.${ENDCOLOR}" >&2
                    echo -e "${YELLOW}Solutions:${ENDCOLOR}" >&2
                    echo -e "${YELLOW}  • Verify your API key is correct${ENDCOLOR}" >&2
                    echo -e "${YELLOW}  • Try again with a smaller commit diff${ENDCOLOR}" >&2
                fi
                ;;
            413)
                echo -e "${YELLOW}📏 Payload too large: Too many staged files or changes for the AI model.${ENDCOLOR}" >&2
                echo -e "${YELLOW}Solutions:${ENDCOLOR}" >&2
                echo -e "${YELLOW}  • Reduce the diff limit: gitb cfg history${ENDCOLOR}" >&2
                echo -e "${YELLOW}  • Try a model with larger context: gitb cfg model${ENDCOLOR}" >&2
                echo -e "${YELLOW}  • Use manual commit message for now: gitb c${ENDCOLOR}" >&2
                ;;
            401|403)
                echo -e "${YELLOW}🔐 Authentication error: Invalid or expired API key.${ENDCOLOR}" >&2
                echo -e "${YELLOW}Solutions:${ENDCOLOR}" >&2
                echo -e "${YELLOW}  • Check your API key with: gitb cfg ai${ENDCOLOR}" >&2
                case "$provider" in
                    openai)     echo -e "${YELLOW}  • Get an OpenAI key at: https://platform.openai.com/api-keys${ENDCOLOR}" >&2 ;;
                    openrouter) echo -e "${YELLOW}  • Get an OpenRouter key at: https://openrouter.ai/keys${ENDCOLOR}" >&2 ;;
                esac
                echo -e "${YELLOW}  • Ensure your key has proper permissions${ENDCOLOR}" >&2
                ;;
            429)
                echo -e "${YELLOW}⏱️  Rate limit exceeded: Too many requests.${ENDCOLOR}" >&2
                echo -e "${YELLOW}Solutions:${ENDCOLOR}" >&2
                echo -e "${YELLOW}  • Wait a few minutes and try again${ENDCOLOR}" >&2
                echo -e "${YELLOW}  • Consider upgrading your API plan for higher limits${ENDCOLOR}" >&2
                ;;
            500|502)
                echo -e "${YELLOW}🔧 Server error: AI service is experiencing issues.${ENDCOLOR}" >&2
                echo -e "${YELLOW}Solutions:${ENDCOLOR}" >&2
                echo -e "${YELLOW}  • Try again in a few minutes${ENDCOLOR}" >&2
                echo -e "${YELLOW}  • Check OpenRouter status: https://status.openrouter.ai${ENDCOLOR}" >&2
                echo -e "${YELLOW}  • Use manual commit message for now: gitb c${ENDCOLOR}" >&2
                echo -e "${YELLOW}  • Try a different model: gitb cfg model${ENDCOLOR}" >&2
                echo -e "${YELLOW}  • Check your API key balance: https://openrouter.ai/keys${ENDCOLOR}" >&2
                ;;
            503)
                echo -e "${YELLOW}📊 Service overloaded: Provider servers are busy.${ENDCOLOR}" >&2
                echo -e "${YELLOW}Solutions:${ENDCOLOR}" >&2
                echo -e "${YELLOW}  • Try again in a few minutes${ENDCOLOR}" >&2
                echo -e "${YELLOW}  • Retry during off-peak hours${ENDCOLOR}" >&2
                ;;
            *)
                # Check for specific error message patterns when code is unclear
                if [[ "$error_message" == *"suspended"* ]]; then
                    echo -e "${YELLOW}🚫 Account suspended: Your API access has been suspended.${ENDCOLOR}" >&2
                    echo -e "${YELLOW}Solutions:${ENDCOLOR}" >&2
                    echo -e "${YELLOW}  • Contact OpenRouter Support to resolve account issues${ENDCOLOR}" >&2
                elif [[ "$error_message" == *"location is not supported"* ]]; then
                    echo -e "${YELLOW}⚠️  Geographic restriction: Service may be unavailable in your region.${ENDCOLOR}" >&2
                    echo -e "${YELLOW}Solutions:${ENDCOLOR}" >&2
                    echo -e "${YELLOW}  • Configure proxy with: gitb cfg proxy${ENDCOLOR}" >&2
                    echo -e "${YELLOW}  • Use a VPN to connect from a supported region${ENDCOLOR}" >&2
                    echo -e "${YELLOW}  • Use manual commit messages for now${ENDCOLOR}" >&2
                elif [[ "$error_message" == *"context"* ]] || [[ "$error_message" == *"token"* ]] || [[ "$error_message" == *"too long"* ]] || [[ "$error_message" == *"length"* ]]; then
                    echo -e "${YELLOW}📏 Prompt too large: Too many staged files or changes for the AI model.${ENDCOLOR}" >&2
                    echo -e "${YELLOW}Solutions:${ENDCOLOR}" >&2
                    echo -e "${YELLOW}  • Reduce the diff limit: gitb cfg history${ENDCOLOR}" >&2
                    echo -e "${YELLOW}  • Try a model with larger context: gitb cfg model${ENDCOLOR}" >&2
                    echo -e "${YELLOW}  • Use manual commit message for now: gitb c${ENDCOLOR}" >&2
                else
                    echo -e "${YELLOW}❓ Unknown error occurred.${ENDCOLOR}" >&2
                    echo -e "${YELLOW}Solutions:${ENDCOLOR}" >&2
                    echo -e "${YELLOW}  • Check OpenAI-compatible API documentation${ENDCOLOR}" >&2
                    echo -e "${YELLOW}  • Try again later${ENDCOLOR}" >&2
                fi
                ;;
        esac
        
        clear_sensitive_vars
        return 1
    fi
    
    # Parse OpenAI-style response from OpenRouter
    local ai_response=""
    if command -v jq &>/dev/null; then
        ai_response=$(echo "$response" | jq -r '.choices[0].message.content // empty' 2>/dev/null)
    else
        # Fallback: sed-based parsing with LC_ALL=C to avoid illegal byte sequence errors
        ai_response=$(echo "$response" | LC_ALL=C sed -n 's/.*"choices"[[:space:]]*:[[:space:]]*\[.*"message"[[:space:]]*:[[:space:]]*{[[:space:]]*"role"[[:space:]]*:[[:space:]]*"assistant"[[:space:]]*,[[:space:]]*"content"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
        # Clean up escaped characters
        if [ -n "$ai_response" ]; then
            ai_response=$(echo "$ai_response" | LC_ALL=C sed 's/\\n/\n/g' | LC_ALL=C sed 's/\\"/"/g' | LC_ALL=C sed 's/\\\\/\\/g')
        fi
    fi
    
    if [ -z "$ai_response" ]; then
        echo -e "${RED}✗ Cannot parse AI response.${ENDCOLOR}" >&2
        echo -e "${YELLOW}Raw API response:${ENDCOLOR}" >&2
        echo "$response" | head -5 >&2
        echo -e "${YELLOW}...${ENDCOLOR}" >&2
        echo -e "${YELLOW}To see full response, enable debug mode in ai.sh${ENDCOLOR}" >&2
        # Clear sensitive variables before returning
        clear_sensitive_vars
        return 1
    fi
    
    # Clear sensitive variables before returning success
    clear_sensitive_vars
    echo "$ai_response"
}


### Function to check if AI tools are available
# Returns: 0 if available, 1 if not
function check_ai_available {
    # Check if curl is available
    if ! command -v curl >/dev/null 2>&1; then
        echo -e "${RED}curl is required for AI functionality but not installed${ENDCOLOR}" >&2
        return 1
    fi

    # Local providers (Ollama) don't need a key, so skip the key check for them.
    if ai_provider_requires_api_key; then
        local api_key=$(get_ai_api_key)
        if [ -z "$api_key" ]; then
            echo -e "${RED}AI API key not configured${ENDCOLOR}" >&2
            echo -e "${YELLOW}Configure it with: gitb cfg ai${ENDCOLOR}" >&2
            return 1
        fi
    fi

    return 0
}

### Build the SYSTEM message for commit-message generation
# Static instructions: role, task, types, rules, examples, output format.
# $1: mode ("simple" | "subject" | "full")
# $2: commit prefix (only used in "subject" mode, e.g. "feat(auth): ")
function build_ai_commit_system_prompt {
    local mode="$1"
    local commit_prefix="$2"

    # Mode-specific task and output-format wording
    local task_text output_format_text length_rule
    case "$mode" in
        subject)
            task_text="Generate the SUBJECT TEXT only. The user has already chosen the prefix '${commit_prefix}'. The final commit header will be the literal concatenation: '${commit_prefix}<your output>'. Write only the suffix that comes after the prefix — do NOT include the prefix, type, scope, colon, or leading space. The subject must summarize ALL distinct changes in the diff, not just the first one you read."
            output_format_text="Output ONLY the subject text. No prose before or after. No markdown fences. No surrounding quotes. No leading or trailing whitespace."
            length_rule="The complete header (the prefix '${commit_prefix}' concatenated with your output) must be 100 characters or fewer."
            ;;
        full)
            task_text="Generate a conventional commit in the format 'type(scope): subject', followed by a blank line, then a 1-3 sentence body explaining WHY. The header must summarize ALL distinct changes in the diff (not just the first one); the body must list every distinct change when there are 2 or more."
            output_format_text="Output ONLY the commit message (header line, blank line, body). No prose before or after. No markdown fences. No surrounding quotes."
            length_rule="The header line (type + scope + colon + space + subject) must be 100 characters or fewer."
            ;;
        *)
            task_text="Generate a single-line conventional commit message in the format 'type(scope): subject'. No body. The subject must cover ALL distinct changes in the diff, not just the first one you read."
            output_format_text="Output ONLY the commit message on one line. No prose before or after. No markdown fences. No surrounding quotes."
            length_rule="The full message (type + scope + colon + space + subject) must be 100 characters or fewer."
            ;;
    esac

    local prompt="You are a conventional commit message generator. You will receive git change data from the user wrapped in XML tags. Produce a commit message that follows the rules below and matches the style of <recent_commits>.

These commit messages feed an automatically generated CHANGELOG. A reader skimming the changelog later should understand what changed (and in full mode, why) without opening the diff. Be specific, name the affected areas, and never hide multiple changes behind a vague summary.

<task>
${task_text}
</task>"

    # Types are only relevant when the model picks the type itself
    if [ "$mode" != "subject" ]; then
        prompt+="

<types>
- feat: new feature, logic change, or performance improvement
- fix: bug fix or small correction to existing behaviour
- refactor: code change that neither fixes a bug nor adds a feature; style changes; NO NEW BEHAVIOUR
- test: adding missing tests or changing existing tests
- build: changes that affect the build system or external dependencies
- ci: changes to CI configuration files and scripts
- chore: maintenance and housekeeping
- docs: documentation changes
</types>"
    fi

    prompt+="

<rules>
- COVERAGE (most important): Your message MUST account for every distinct change visible across <staged_files>, <diff_summary>, and <diff>. <staged_files> is your authoritative checklist — every file is listed with its action (added/modified/deleted/renamed/copied) and this section is preserved in full even when <diff> gets truncated. If <diff> is truncated, infer the missing changes from <staged_files> and <diff_summary>. Never describe only the first change you read. The mix of actions also hints at the type: many 'added' files often signal feat, mostly 'modified' files signal fix or refactor, 'renamed'/'deleted' often signal refactor or chore
- For 2-3 distinct changes, combine them with 'and' (e.g., 'add auth module and user profile page')
- For 4+ distinct changes, summarize with a count and name the most important ones (e.g., 'add 5 endpoints including auth, profile, settings, dashboard, and notifications')
- For mixed change types (e.g., a feature and a fix), use the dominant type and mention the mix (e.g., 'feat: add caching layer and fix the related cache-key bug')
- Never use vague placeholders like 'multiple changes', 'various updates', or 'misc fixes'
- ${length_rule}
- Subject text must be lowercase and must not end with a period
- Use the imperative mood (e.g. 'add', 'fix', 'remove') — NOT past tense ('added', 'fixed') or progressive ('adding', 'fixing')
- Be specific about WHAT changed. Avoid vague phrases like 'improve existing feature', 'update code', or 'fix bug'
- Match the typical length, level of detail, and verb style of <recent_commits>. Generate fresh content for the actual diff — do not copy a recent message verbatim"

    if [ "$mode" != "subject" ]; then
        prompt+="
- SCOPE: Use exactly ONE scope per commit, or omit the scope entirely (plain 'type: subject') when the changes don't fit a single scope. Never put multiple scopes in the parens (e.g. 'feat(auth,api):' is forbidden). When one scope clearly dominates the diff (most files / most logical weight), use that scope; when no single scope dominates, omit it and name the affected areas in the subject text instead. Prefer scope names from <provided_scopes> over <detected_scopes>; treat <staged_files> as the source of truth when both are silent"
    fi

    if [ "$mode" = "full" ]; then
        prompt+="
- Body length: 1-3 sentences explaining WHY the change is being made (motivation, context, trade-off). If there are multiple distinct changes, list them in the body"
    fi

    prompt+="
</rules>

<examples>"

    case "$mode" in
        subject)
            prompt+="
<example>add backup codes for MFA recovery</example>
<example>handle null userData in user lookup</example>
<example>extract diff truncation into shared helper</example>
<example>bump axios to 1.7.4 to address CVE-2024-39338</example>
<example>unify prompt builders and switch to XML-tagged sections</example>
<example>add 4 endpoints including profile, settings, dashboard, and notifications</example>"
            ;;
        full)
            prompt+="
<example>
feat(auth): add backup codes for MFA recovery

Required for SOC2 compliance — users need a recovery path when their TOTP device is unavailable. Replaces the old email-only fallback flow.
</example>
<example>
fix(api): handle null userData in user lookup

The upstream service started returning null for deleted users instead of a 404. Treat null as 'not found' to preserve the client-facing 404 contract.
</example>
<example>
feat(api): add rate limiting, structured request logs, and CORS preflight handling

Three middleware additions for the public API release: token-bucket limiter (60 req/min/IP), structured request logs feeding the new audit pipeline, and explicit CORS preflight responses for the browser SDK.
</example>
<example>
feat: add SSO login and metered usage reporting

Two product-level additions for the Q3 release that span unrelated areas: SAML/OIDC SSO replacing the legacy email-link auth flow, and per-tenant metered usage events emitted from the billing service to feed the new invoicing pipeline.
</example>
<example>
refactor(commit): unify prompt builders, switch to XML-tagged sections, and add regenerate option

Three closely related changes: collapse the three near-duplicate generate_* functions into one mode-dispatched entry point, restructure prompts as XML-tagged sections so the model can separate instructions from data, and add an 'r' option so users can ask for a different message without re-running the whole command.
</example>"
            ;;
        *)
            prompt+="
<example>feat(auth): add backup codes for MFA recovery</example>
<example>fix(api): handle null userData in user lookup</example>
<example>refactor(commit): extract diff truncation into shared helper</example>
<example>feat(auth): add login endpoints and matching auth middleware</example>
<example>fix(parser): handle nested generics and trailing commas in the AST builder</example>
<example>docs: add v1 to v2 migration guide</example>
<example>chore: bump axios to 1.7.4 to address CVE-2024-39338</example>
<example>refactor: unify prompt builders across commit and ai modules and switch to XML-tagged sections</example>
<example>feat: add 4 endpoints including profile, settings, dashboard, and notifications</example>"
            ;;
    esac

    prompt+="
</examples>

<output_format>
${output_format_text}
</output_format>"

    printf '%s' "$prompt"
}

### Build the USER message for commit-message generation
# Per-call data: recent commits, staged files, diff, scopes.
# $1: mode ("simple" | "subject" | "full")
# $2: detected scopes (optional, space-separated)
# $3: provided scopes (optional, space-separated; ignored in "subject" mode)
# $4: rejected commit messages from this prompt session (optional)
function build_ai_commit_user_prompt {
    local mode="$1"
    local detected_scopes="$2"
    local provided_scopes="$3"
    local rejected_messages="${4:-}"

    local staged_files_limited=$(get_limited_staged_files_for_ai)
    local diff_stat=$(get_limited_diff_stat_for_ai)
    local diff_details=$(get_limited_diff_for_ai)
    local recent_commits=$(get_recent_commit_messages_for_ai)

    local prompt="<recent_commits>
${recent_commits}
</recent_commits>

<staged_files>
${staged_files_limited}
</staged_files>

<diff_summary>
${diff_stat}
</diff_summary>

<diff>
${diff_details}
</diff>"

    if [ "$mode" != "subject" ]; then
        if [ -n "$provided_scopes" ]; then
            prompt+="

<provided_scopes>
${provided_scopes}
</provided_scopes>"
        fi
        if [ -n "$detected_scopes" ]; then
            prompt+="

<detected_scopes>
${detected_scopes}
</detected_scopes>"
        fi
    fi

    if [ -n "$rejected_messages" ]; then
        prompt+="

<rejected_commit_messages>
${rejected_messages}
</rejected_commit_messages>

The user rejected the message(s) in <rejected_commit_messages>. Do not repeat them. Generate a meaningfully different commit message while still following the staged changes and output format."
    fi

    prompt+="

Before writing, scan <staged_files> and <diff_summary> end-to-end and identify every distinct change (group related files together). Then write a single commit message that covers them all, following every rule and matching the example style."

    printf '%s' "$prompt"
}

### Generate a commit message using AI (unified entry point)
# $1: mode ("simple" | "subject" | "full"); defaults to "simple"
# $2: detected scopes (optional, space-separated)
# $3: provided scopes (optional, space-separated; ignored in "subject" mode)
# $4: commit prefix (only used in "subject" mode, e.g. "feat(auth): ")
# $5: rejected commit messages from this prompt session (optional)
# Returns: AI-generated commit message text on stdout, non-zero on failure
function generate_ai_commit_message {
    local mode="${1:-simple}"
    local detected_scopes="$2"
    local provided_scopes="$3"
    local commit_prefix="$4"
    local rejected_messages="${5:-}"

    local staged_files=$(git -c core.quotePath=false diff --name-only --cached)
    if [ -z "$staged_files" ]; then
        echo -e "${RED}✗ No staged files found.${ENDCOLOR}" >&2
        return 1
    fi

    local system_prompt user_prompt
    system_prompt=$(build_ai_commit_system_prompt "$mode" "$commit_prefix")
    user_prompt=$(build_ai_commit_user_prompt "$mode" "$detected_scopes" "$provided_scopes" "$rejected_messages")

    local max_tokens model
    case "$mode" in
        subject) max_tokens="$AI_MAX_TOKENS_SUBJECT"; model=$(get_ai_model_for subject) ;;
        full)    max_tokens="$AI_MAX_TOKENS_FULL";    model=$(get_ai_model_for full) ;;
        *)       max_tokens="$AI_MAX_TOKENS_SIMPLE";  model=$(get_ai_model_for simple) ;;
    esac

    call_ai_api "$system_prompt" "$user_prompt" "$max_tokens" "$model"
}

### Function to securely clear sensitive variables
# This helps prevent API key exposure via memory dumps or env vars
function clear_sensitive_vars {
    # Clear local API key variables
    api_key=""
    ai_key_input=""
    validated_proxy_url=""
    
    # Clear from environment if accidentally exported
    unset api_key 2>/dev/null
    unset ai_key_input 2>/dev/null
    unset AI_API_KEY 2>/dev/null
    unset OPENROUTER_API_KEY 2>/dev/null
    
    # Force garbage collection of shell variables (bash-specific)
    if [ -n "$BASH_VERSION" ]; then
        hash -r 2>/dev/null
    fi
}
