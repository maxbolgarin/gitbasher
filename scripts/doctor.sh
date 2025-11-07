#!/usr/bin/env bash

### Script for checking gitbasher dependencies and environment
# This helps diagnose potential issues

### Function to check command version
# $1: command name
# $2: min version (optional)
# $3: version extraction pattern (optional)
function check_command {
    local cmd=$1
    local min_version=$2
    local version_pattern=${3:-'[0-9]+\.[0-9]+\.[0-9]+'}

    if ! command -v $cmd >/dev/null 2>&1; then
        echo -e "  ${RED}✗${ENDCOLOR} $cmd ${RED}not found${ENDCOLOR}"
        return 1
    fi

    local version_output=$($cmd --version 2>&1 | head -n1)
    local version=$(echo "$version_output" | grep -oE "$version_pattern" | head -n1)

    if [ -z "$version" ]; then
        echo -e "  ${GREEN}✓${ENDCOLOR} $cmd ${GREEN}installed${ENDCOLOR} (version: ${GRAY}unknown${ENDCOLOR})"
        return 0
    fi

    if [ -n "$min_version" ]; then
        # Compare versions
        local current_major=$(echo "$version" | cut -d. -f1)
        local current_minor=$(echo "$version" | cut -d. -f2 || echo "0")
        local min_major=$(echo "$min_version" | cut -d. -f1)
        local min_minor=$(echo "$min_version" | cut -d. -f2 || echo "0")

        if [ "$current_major" -lt "$min_major" ] || \
           ([ "$current_major" -eq "$min_major" ] && [ "$current_minor" -lt "$min_minor" ]); then
            echo -e "  ${YELLOW}⚠${ENDCOLOR} $cmd ${YELLOW}$version${ENDCOLOR} (>= ${min_version} required)"
            return 2
        fi
    fi

    echo -e "  ${GREEN}✓${ENDCOLOR} $cmd ${GREEN}$version${ENDCOLOR}"
    return 0
}

### Function to check git configuration
function check_git_config {
    echo
    echo -e "${BOLD}Git Configuration:${ENDCOLOR}"

    # Check user.name
    local git_name=$(git config user.name 2>/dev/null)
    if [ -z "$git_name" ]; then
        echo -e "  ${RED}✗${ENDCOLOR} user.name ${RED}not set${ENDCOLOR}"
        echo -e "    ${GRAY}Fix: git config --global user.name \"Your Name\"${ENDCOLOR}"
    else
        echo -e "  ${GREEN}✓${ENDCOLOR} user.name: ${CYAN}$git_name${ENDCOLOR}"
    fi

    # Check user.email
    local git_email=$(git config user.email 2>/dev/null)
    if [ -z "$git_email" ]; then
        echo -e "  ${RED}✗${ENDCOLOR} user.email ${RED}not set${ENDCOLOR}"
        echo -e "    ${GRAY}Fix: git config --global user.email \"your@email.com\"${ENDCOLOR}"
    else
        echo -e "  ${GREEN}✓${ENDCOLOR} user.email: ${CYAN}$git_email${ENDCOLOR}"
    fi

    # Check gitbasher configuration
    local main_branch=$(git config --local gitbasher.branch 2>/dev/null)
    if [ -n "$main_branch" ]; then
        echo -e "  ${GREEN}✓${ENDCOLOR} gitbasher.branch: ${CYAN}$main_branch${ENDCOLOR}"
    fi

    local scopes=$(git config --local gitbasher.scopes 2>/dev/null)
    if [ -n "$scopes" ]; then
        echo -e "  ${GREEN}✓${ENDCOLOR} gitbasher.scopes: ${CYAN}$scopes${ENDCOLOR}"
    fi
}

### Function to check repository status
function check_repo_status {
    echo
    echo -e "${BOLD}Repository Status:${ENDCOLOR}"

    # Check if in git repo
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo -e "  ${RED}✗${ENDCOLOR} ${RED}Not in a git repository${ENDCOLOR}"
        return 1
    fi

    echo -e "  ${GREEN}✓${ENDCOLOR} In git repository"

    # Check current branch
    local current_branch=$(git branch --show-current 2>/dev/null)
    if [ -n "$current_branch" ]; then
        echo -e "  ${GREEN}✓${ENDCOLOR} Current branch: ${CYAN}$current_branch${ENDCOLOR}"
    fi

    # Check remote
    local remote_url=$(git config --get remote.origin.url 2>/dev/null)
    if [ -z "$remote_url" ]; then
        echo -e "  ${YELLOW}⚠${ENDCOLOR} No remote configured"
    else
        echo -e "  ${GREEN}✓${ENDCOLOR} Remote: ${CYAN}$remote_url${ENDCOLOR}"

        # Check if can reach remote
        if git ls-remote --exit-code origin >/dev/null 2>&1; then
            echo -e "  ${GREEN}✓${ENDCOLOR} Remote accessible"
        else
            echo -e "  ${YELLOW}⚠${ENDCOLOR} Cannot reach remote (check network/credentials)"
        fi
    fi

    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        echo -e "  ${YELLOW}⚠${ENDCOLOR} Uncommitted changes detected"
    else
        echo -e "  ${GREEN}✓${ENDCOLOR} Working directory clean"
    fi
}

### Function to check optional features
function check_optional_features {
    echo
    echo -e "${BOLD}Optional Features:${ENDCOLOR}"

    # Check curl for AI features
    if command -v curl >/dev/null 2>&1; then
        local ai_key=$(git config --get gitbasher.ai.key 2>/dev/null)
        local ai_url=$(git config --get gitbasher.ai.url 2>/dev/null)

        if [ -n "$ai_key" ] || [ -n "$ai_url" ]; then
            echo -e "  ${GREEN}✓${ENDCOLOR} AI features configured"
            if [ -n "$ai_url" ]; then
                echo -e "    ${GRAY}AI URL: $ai_url${ENDCOLOR}"
            fi
        else
            echo -e "  ${GRAY}○${ENDCOLOR} AI features not configured (optional)"
            echo -e "    ${GRAY}See: gitb config ai${ENDCOLOR}"
        fi
    else
        echo -e "  ${GRAY}○${ENDCOLOR} curl not found (needed for AI features)"
    fi

    # Check shellcheck (for development)
    if command -v shellcheck >/dev/null 2>&1; then
        local sc_version=$(shellcheck --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
        echo -e "  ${GREEN}✓${ENDCOLOR} shellcheck ${GREEN}$sc_version${ENDCOLOR} (for development)"
    else
        echo -e "  ${GRAY}○${ENDCOLOR} shellcheck not found (optional, for development)"
    fi

    # Check bats (for testing)
    if command -v bats >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${ENDCOLOR} bats installed (for testing)"
    else
        echo -e "  ${GRAY}○${ENDCOLOR} bats not found (optional, for running tests)"
    fi
}

### Function to check system information
function check_system {
    echo
    echo -e "${BOLD}System Information:${ENDCOLOR}"

    # OS
    local os_name=$(uname -s)
    local os_version=$(uname -r)
    echo -e "  ${GREEN}✓${ENDCOLOR} OS: ${CYAN}$os_name $os_version${ENDCOLOR}"

    # Architecture
    local arch=$(uname -m)
    echo -e "  ${GREEN}✓${ENDCOLOR} Architecture: ${CYAN}$arch${ENDCOLOR}"

    # Shell
    echo -e "  ${GREEN}✓${ENDCOLOR} Shell: ${CYAN}$SHELL${ENDCOLOR}"

    # Bash version
    echo -e "  ${GREEN}✓${ENDCOLOR} Bash: ${CYAN}${BASH_VERSION}${ENDCOLOR}"
}

### Function to print summary
function print_summary {
    echo
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${ENDCOLOR}"

    if [ $errors -gt 0 ]; then
        echo -e "${RED}✗ Found $errors error(s)${ENDCOLOR}"
        echo -e "Please fix the errors above before using gitbasher"
        return 1
    elif [ $warnings -gt 0 ]; then
        echo -e "${YELLOW}⚠ Found $warnings warning(s)${ENDCOLOR}"
        echo -e "gitbasher should work, but some features may be limited"
        return 0
    else
        echo -e "${GREEN}✓ All checks passed!${ENDCOLOR}"
        echo -e "gitbasher is ready to use 🎉"
        return 0
    fi
}

### Main doctor function
function doctor_script {
    local errors=0
    local warnings=0

    echo -e "${BOLD}gitbasher doctor${ENDCOLOR} - System diagnostics"
    echo -e "${GRAY}Checking your setup...${ENDCOLOR}"

    # Check system
    check_system

    # Check dependencies
    echo
    echo -e "${BOLD}Required Dependencies:${ENDCOLOR}"
    check_command "bash" "4.0"
    [ $? -eq 1 ] && errors=$((errors + 1))
    [ $? -eq 2 ] && warnings=$((warnings + 1))

    check_command "git" "2.23"
    [ $? -eq 1 ] && errors=$((errors + 1))
    [ $? -eq 2 ] && warnings=$((warnings + 1))

    check_command "sed"
    [ $? -eq 1 ] && errors=$((errors + 1))

    check_command "grep"
    [ $? -eq 1 ] && errors=$((errors + 1))

    # Check git configuration
    check_git_config

    # Check repository status
    check_repo_status

    # Check optional features
    check_optional_features

    # Print summary
    print_summary
    return $?
}
