#!/usr/bin/env bats

# Tests for URL validation and AI helper functions:
# validate_git_url (init.sh), validate_proxy_url (ai.sh), mask_api_key (ai.sh)

load setup_suite

setup() {
    source_gitbasher_lite
    # Source ai.sh for mask_api_key and validate_proxy_url
    source "${GITBASHER_ROOT}/scripts/ai.sh"
}

# ===== validate_git_url tests =====

@test "validate_git_url: accepts https URL with .git suffix" {
    validate_git_url "https://github.com/user/repo.git"
    [ $? -eq 0 ]
    [ "$validated_url" = "https://github.com/user/repo.git" ]
}

@test "validate_git_url: accepts https URL without .git suffix" {
    validate_git_url "https://github.com/user/repo"
    [ $? -eq 0 ]
    [ "$validated_url" = "https://github.com/user/repo" ]
}

@test "validate_git_url: accepts http URL" {
    validate_git_url "http://internal.local/repo.git"
    [ $? -eq 0 ]
}

@test "validate_git_url: accepts SSH URL with git@" {
    validate_git_url "git@github.com:user/repo.git"
    [ $? -eq 0 ]
    [ "$validated_url" = "git@github.com:user/repo.git" ]
}

@test "validate_git_url: accepts ssh:// URL" {
    validate_git_url "ssh://git@server.com/repo.git"
    [ $? -eq 0 ]
}

@test "validate_git_url: accepts gitlab URL" {
    validate_git_url "git@gitlab.com:group/subgroup/repo.git"
    [ $? -eq 0 ]
}

@test "validate_git_url: accepts self-hosted server" {
    validate_git_url "git@code.example.io:user/repo.git"
    [ $? -eq 0 ]
}

@test "validate_git_url: rejects empty input" {
    ! validate_git_url ""
}

@test "validate_git_url: rejects ftp URL" {
    ! validate_git_url "ftp://example.com/repo.git"
}

@test "validate_git_url: rejects file URL with spaces" {
    ! validate_git_url "https://github.com/user repo.git"
}

@test "validate_git_url: rejects URL with shell metacharacters" {
    ! validate_git_url "https://github.com/user/repo.git;rm -rf /"
    ! validate_git_url 'https://github.com/user/repo.git`whoami`'
    ! validate_git_url 'https://github.com/user/repo.git$(id)'
}

@test "validate_git_url: rejects URL longer than 500 chars" {
    local long
    long="https://example.com/$(printf 'a%.0s' {1..500}).git"
    ! validate_git_url "$long"
}

@test "validate_git_url: removes control characters" {
    validate_git_url "$(printf 'https://example.com/repo\001.git')"
    [ $? -eq 0 ]
    [[ "$validated_url" != *$'\001'* ]]
}

# ===== validate_proxy_url tests =====

@test "validate_proxy_url: accepts http proxy" {
    validate_proxy_url "http://proxy.example.com:8080"
    [ $? -eq 0 ]
    [ "$validated_proxy_url" = "http://proxy.example.com:8080" ]
}

@test "validate_proxy_url: accepts https proxy" {
    validate_proxy_url "https://proxy.example.com:8443"
    [ $? -eq 0 ]
}

@test "validate_proxy_url: accepts socks5 proxy" {
    validate_proxy_url "socks5://proxy.example.com:1080"
    [ $? -eq 0 ]
}

@test "validate_proxy_url: accepts proxy with auth" {
    validate_proxy_url "http://user:pass@proxy.example.com:8080"
    [ $? -eq 0 ]
}

@test "validate_proxy_url: accepts host:port shorthand" {
    validate_proxy_url "proxy.example.com:8080"
    [ $? -eq 0 ]
    [ "$validated_proxy_url" = "proxy.example.com:8080" ]
}

@test "validate_proxy_url: rejects empty input" {
    ! validate_proxy_url ""
}

@test "validate_proxy_url: rejects URL without port" {
    ! validate_proxy_url "http://proxy.example.com"
}

@test "validate_proxy_url: rejects unsupported scheme" {
    ! validate_proxy_url "ftp://proxy.example.com:21"
}

@test "validate_proxy_url: rejects shell metacharacter sequences that break format" {
    ! validate_proxy_url "http://proxy.example.com:8080; rm -rf /"
    ! validate_proxy_url "http://proxy.example.com:8080 && id"
}

@test "validate_proxy_url: strips backticks before validation" {
    # Sanitization removes backticks; result must not leak shell metacharacters
    validate_proxy_url 'http://`whoami`@proxy.com:8080' || true
    [[ "$validated_proxy_url" != *'`'* ]]
}

# ===== mask_api_key tests =====

@test "mask_api_key: masks long key keeping last 4 chars" {
    result=$(mask_api_key "sk-abcdefghij1234")
    [ "$result" = "********1234" ]
}

@test "mask_api_key: returns empty for empty input" {
    result=$(mask_api_key "")
    [ -z "$result" ]
}

@test "mask_api_key: returns short keys unchanged (4 or fewer chars)" {
    result=$(mask_api_key "1234")
    [ "$result" = "1234" ]
    result=$(mask_api_key "abc")
    [ "$result" = "abc" ]
}

@test "mask_api_key: masks 5-character key (boundary)" {
    result=$(mask_api_key "abcde")
    [ "$result" = "********bcde" ]
}

@test "mask_api_key: never reveals key prefix" {
    local key="sk-or-v1-abcdefghijklmnop"  # gitleaks:allow - test fixture, not a real key
    result=$(mask_api_key "$key")
    [[ "$result" != *"sk-or-v1"* ]]
    [[ "$result" == *"mnop" ]]
}
