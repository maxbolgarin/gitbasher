#!/usr/bin/env bash

### AI Functions for commit message generation

# OpenRouter API endpoint (OpenAI-compatible)
readonly OPENROUTER_API_URL="https://openrouter.ai/api/v1/chat/completions"

# Sampling temperature for commit-message generation. Low enough to keep the
# conventional-commit format consistent, high enough that pressing 'r' to
# regenerate produces a meaningfully different phrasing.
readonly AI_TEMPERATURE="0.3"

# Per-mode max_tokens caps. These cap the response size to control cost and
# prevent runaway output if the model misinterprets the format. Values are
# generous enough to fit the longest reasonable message in each mode.
readonly AI_MAX_TOKENS_SUBJECT=100
readonly AI_MAX_TOKENS_SIMPLE=150
readonly AI_MAX_TOKENS_FULL=500

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

### Function to get/set AI model (OpenRouter)
# Returns: model id or default if not set
function get_ai_model {
    get_config_value gitbasher.ai-model "openrouter/auto"
}

function set_ai_model {
    set_config_value gitbasher.ai-model "$1"
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
# Returns: Staged file names limited to prevent token overflow on large commits
function get_limited_staged_files_for_ai {
    local max_files=50
    local max_chars=2000

    local staged_files=$(git diff --name-only --cached)
    local total_files=$(echo "$staged_files" | wc -l | tr -d ' ')

    if [ "$total_files" -gt "$max_files" ]; then
        staged_files=$(echo "$staged_files" | head -n "$max_files")
        staged_files="${staged_files}
... and $((total_files - max_files)) more files (${total_files} total)"
    fi

    # Further limit by character count
    local char_count=${#staged_files}
    if [ "$char_count" -gt "$max_chars" ]; then
        staged_files=$(echo "$staged_files" | head -c "$max_chars")
        staged_files="${staged_files}... [truncated, ${total_files} files total]"
    fi

    echo "$staged_files"
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
    
    # Remove any potential shell metacharacters and validate format
    # Allow only safe characters: alphanumeric, dots, hyphens, underscores, colons, slashes, @, %
    local cleaned_url=$(echo "$proxy_url" | sed 's/[^a-zA-Z0-9.:/@_%?&=-]//g')
    
    # Basic URL format validation for common proxy formats
    # http://[user:pass@]host:port
    # https://[user:pass@]host:port  
    # socks5://[user:pass@]host:port
    if [[ "$cleaned_url" =~ ^(https?|socks5)://([a-zA-Z0-9._%-]+(:([a-zA-Z0-9._%-]+))?@)?[a-zA-Z0-9.-]+:[0-9]+(/.*)?$ ]]; then
        validated_proxy_url="$cleaned_url"
        return 0
    elif [[ "$cleaned_url" =~ ^[a-zA-Z0-9.-]+:[0-9]+$ ]]; then
        # Allow simple host:port format (curl will assume http://)
        validated_proxy_url="$cleaned_url"
        return 0
    else
        return 1
    fi
}

### Function to securely call curl with API key
# This prevents API key exposure in process lists by using a subshell
# $1: proxy_url (can be empty)
# $2: api_key value
# $3: json_payload
function secure_curl_with_api_key {
    local proxy_url="$1"
    local api_key="$2"
    local json_payload="$3"
    
    # Execute curl in a subshell to minimize API key exposure
    (
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
        
        # Add remaining options for OpenRouter
        curl_cmd+=(
            "$OPENROUTER_API_URL"
            -H "Content-Type: application/json"
            -H "Authorization: Bearer $api_key"
            -H "HTTP-Referer: https://github.com/maxbolgarin/gitbasher"
            -H "X-Title: gitbasher"
            -d "$json_payload"
        )
        
        # Execute the curl command
        "${curl_cmd[@]}" 2>&1
    )
}

### Function to make request to OpenRouter API
# $1: prompt text
# $2: max_tokens cap on the response (default: AI_MAX_TOKENS_FULL)
# Returns: AI response text
function call_openrouter_api {
    # Set trap to clear sensitive variables on exit/interrupt
    trap 'clear_sensitive_vars' EXIT INT TERM

    local prompt="$1"
    local max_tokens="${2:-$AI_MAX_TOKENS_FULL}"
    local api_key=$(get_ai_api_key)
    local max_retries=2
    local retry_delay=2

    if [ -z "$api_key" ]; then
        echo -e "${RED}AI API key not configured. Set it with: gitb config${ENDCOLOR}" >&2
        clear_sensitive_vars
        return 1
    fi

    # Select OpenRouter model (OpenAI-compatible)
    local model=$(get_ai_model)

    # Build OpenAI-style payload for OpenRouter.
    # Prefer jq for robust JSON encoding; fall back to sed/awk that preserves newlines as JSON \n
    # (the previous implementation collapsed newlines to spaces, destroying prompt structure).
    # LC_ALL=C avoids "illegal byte sequence" errors from BSD sed on macOS when the
    # prompt contains non-UTF-8-validatable bytes (e.g. Russian or other non-ASCII content in diffs).
    local json_payload
    if command -v jq &>/dev/null; then
        json_payload=$(jq -nc \
            --arg model "$model" \
            --arg content "$prompt" \
            --argjson temperature "$AI_TEMPERATURE" \
            --argjson max_tokens "$max_tokens" \
            '{model: $model, messages: [{role: "user", content: $content}], temperature: $temperature, max_tokens: $max_tokens}')
    else
        local escaped_prompt=$(printf '%s' "$prompt" \
            | LC_ALL=C sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e $'s/\t/\\\\t/g' -e $'s/\r/\\\\r/g' \
            | LC_ALL=C awk 'BEGIN{ORS=""} NR>1{print "\\n"} {print}')
        json_payload="{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":\"$escaped_prompt\"}],\"temperature\":$AI_TEMPERATURE,\"max_tokens\":$max_tokens}"
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
            echo -e "${RED}Invalid proxy URL format: $proxy_url${ENDCOLOR}" >&2
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
            response=$(secure_curl_with_api_key "$safe_proxy_url" "$api_key" "$json_payload")
        else
            response=$(secure_curl_with_api_key "" "$api_key" "$json_payload")
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
        echo -e "${RED}Failed to connect to AI service${ENDCOLOR}" >&2
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
                echo -e "  ✅ Proxy connection: Working" >&2
                echo -e "  📍 Your IP via proxy: $(echo "$proxy_test" | head -1)" >&2
            else
                echo -e "  ❌ Proxy connection: Failed (exit code: $proxy_test_code)" >&2
                echo -e "  📝 Error: $proxy_test" >&2
            fi
        else
            echo -e "  • No proxy configured" >&2
            echo -e "${YELLOW}Direct connection troubleshooting:${ENDCOLOR}" >&2
            echo -e "  • Test connection: ${BOLD}curl --connect-timeout 10 https://openrouter.ai${ENDCOLOR}" >&2
            
            # Test direct connectivity to OpenRouter API
            echo -e "${YELLOW}Testing direct connectivity to OpenRouter...${ENDCOLOR}" >&2
            local direct_test=$(curl --connect-timeout 5 --max-time 10 -s -I https://openrouter.ai 2>&1)
            local direct_test_code=$?
            if [ $direct_test_code -eq 0 ]; then
                echo -e "  ✅ OpenRouter endpoint: Reachable" >&2
            else
                echo -e "  ❌ OpenRouter endpoint: Failed (exit code: $direct_test_code)" >&2
                echo -e "  📝 Error: $(echo "$direct_test" | head -1)" >&2
                echo -e "  💡 Consider configuring a proxy: gitb cfg proxy" >&2
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
            echo -e "${RED}Error Code: $error_code${ENDCOLOR}" >&2
        fi
        if [ -n "$error_message" ]; then
            echo -e "${RED}Error Message: $error_message${ENDCOLOR}" >&2
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
                echo -e "${YELLOW}  • Get an OpenRouter key at: https://openrouter.ai/keys${ENDCOLOR}" >&2
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
        echo -e "${RED}Failed to parse AI response${ENDCOLOR}" >&2
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
    
    # Check if API key is configured
    local api_key=$(get_ai_api_key)
    if [ -z "$api_key" ]; then
        echo -e "${RED}AI API key not configured${ENDCOLOR}" >&2
        echo -e "${YELLOW}Configure it with: gitb cfg ai${ENDCOLOR}" >&2
        return 1
    fi
    
    return 0
}

### Build the AI prompt for commit-message generation
# $1: mode ("simple" | "subject" | "full")
# $2: detected scopes (optional, space-separated)
# $3: provided scopes (optional, space-separated; ignored in "subject" mode)
# $4: commit prefix (only used in "subject" mode, e.g. "feat(auth): ")
# Echoes the assembled prompt
function build_ai_commit_prompt {
    local mode="$1"
    local detected_scopes="$2"
    local provided_scopes="$3"
    local commit_prefix="$4"

    local staged_files_limited=$(get_limited_staged_files_for_ai)
    local diff_stat=$(get_limited_diff_stat_for_ai)
    local diff_details=$(get_limited_diff_for_ai)
    local recent_commits=$(get_recent_commit_messages_for_ai)

    # Mode-specific task statement
    local task_line
    case "$mode" in
        subject)
            task_line="Generate the SUBJECT TEXT only. The user has already chosen the prefix '${commit_prefix}'; do NOT include that prefix in your output — write only what comes after it."
            ;;
        full)
            task_line="Generate a conventional commit in the format 'type(scope): subject', followed by a blank line, then a 1-3 sentence body explaining WHY."
            ;;
        *)
            task_line="Generate a conventional commit message in the format 'type(scope): subject' (single line, no body)."
            ;;
    esac

    local prompt="You are a conventional commit message generator. Analyze the git change data inside the XML tags below and produce a commit message that matches this repository's style.

${task_line}"

    # Types are only relevant when the model picks the type itself
    if [ "$mode" != "subject" ]; then
        prompt+="

<types>
- feat: new feature, logic change or performance improvement
- fix: small changes, bug fix, fixes of features
- refactor: code change that neither fixes a bug nor adds a feature, style changes, NO NEW BEHAVIOUR
- test: adding missing tests or changing existing tests
- build: changes that affect the build system or external dependencies
- ci: changes to CI configuration files and scripts
- chore: maintenance and housekeeping
- docs: documentation changes
</types>"
    fi

    prompt+="

<recent_commits>
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

    prompt+="

<rules>
- Subject must be lowercase and must not end with a period
- Subject must be 100 characters or fewer
- Be specific about WHAT changed; avoid vague phrases like 'improve existing feature' or 'fix bug'
- Use <recent_commits> as style guidance, not as a template — do not copy them verbatim
- For 2-3 distinct changes, combine them with 'and' (e.g., 'feat: add auth module and user profile page')
- For 4+ distinct changes, summarize with a count and list the most important ones (e.g., 'feat: add 5 features including auth, profiles, settings, dashboard, and notifications')
- For mixed change types, use the dominant type and mention the mix (e.g., 'feat: add auth module and fix login validation')
- Never write vague messages like 'multiple changes' or 'various updates'"

    if [ "$mode" != "subject" ]; then
        prompt+="
- If a meaningful scope is clear from the diff, include it. Prefer one from <provided_scopes> when present, otherwise pick from <detected_scopes>, otherwise omit the scope entirely"
    fi

    if [ "$mode" = "full" ]; then
        prompt+="
- Body length: 1-3 sentences explaining the WHY. If there are multiple distinct changes, list them in the body"
    fi

    prompt+="
</rules>

Output ONLY the commit message — no prose, no markdown fences, no surrounding quotes."

    printf '%s' "$prompt"
}

### Generate a commit message using AI (unified entry point)
# $1: mode ("simple" | "subject" | "full"); defaults to "simple"
# $2: detected scopes (optional, space-separated)
# $3: provided scopes (optional, space-separated; ignored in "subject" mode)
# $4: commit prefix (only used in "subject" mode, e.g. "feat(auth): ")
# Returns: AI-generated commit message text on stdout, non-zero on failure
function generate_ai_commit_message {
    local mode="${1:-simple}"
    local detected_scopes="$2"
    local provided_scopes="$3"
    local commit_prefix="$4"

    local staged_files=$(git diff --name-only --cached)
    if [ -z "$staged_files" ]; then
        echo -e "${RED}No staged files found${ENDCOLOR}" >&2
        return 1
    fi

    local prompt
    prompt=$(build_ai_commit_prompt "$mode" "$detected_scopes" "$provided_scopes" "$commit_prefix")

    local max_tokens
    case "$mode" in
        subject) max_tokens="$AI_MAX_TOKENS_SUBJECT" ;;
        full)    max_tokens="$AI_MAX_TOKENS_FULL" ;;
        *)       max_tokens="$AI_MAX_TOKENS_SIMPLE" ;;
    esac

    call_openrouter_api "$prompt" "$max_tokens"
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
