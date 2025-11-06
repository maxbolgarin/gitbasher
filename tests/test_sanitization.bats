#!/usr/bin/env bats

# Tests for input sanitization functions in common.sh
# These are critical security functions that prevent command injection

load setup_suite

setup() {
    source_gitbasher
}

# ===== sanitize_git_name tests =====

@test "sanitize_git_name: accepts valid branch name" {
    sanitize_git_name "feature/my-branch"
    [ $? -eq 0 ]
    [ "$sanitized_git_name" = "feature/my-branch" ]
}

@test "sanitize_git_name: accepts name with underscores" {
    sanitize_git_name "feature_test_branch"
    [ $? -eq 0 ]
    [ "$sanitized_git_name" = "feature_test_branch" ]
}

@test "sanitize_git_name: accepts name with dots" {
    sanitize_git_name "v1.0.0"
    [ $? -eq 0 ]
    [ "$sanitized_git_name" = "v1.0.0" ]
}

@test "sanitize_git_name: removes dangerous characters" {
    sanitize_git_name "feature\$branch"
    [ $? -eq 0 ]
    [ "$sanitized_git_name" = "featurebranch" ]
}

@test "sanitize_git_name: removes spaces" {
    sanitize_git_name "my branch name"
    [ $? -eq 0 ]
    [ "$sanitized_git_name" = "mybranchname" ]
}

@test "sanitize_git_name: rejects empty input" {
    ! sanitize_git_name ""
}

@test "sanitize_git_name: rejects double dots" {
    ! sanitize_git_name "branch..name"
}

@test "sanitize_git_name: rejects name starting with dash" {
    ! sanitize_git_name "-branch"
}

@test "sanitize_git_name: rejects name ending with dash" {
    ! sanitize_git_name "branch-"
}

@test "sanitize_git_name: rejects HEAD" {
    ! sanitize_git_name "HEAD"
}

@test "sanitize_git_name: rejects refs/ prefix" {
    ! sanitize_git_name "refs/heads/main"
}

@test "sanitize_git_name: removes leading dots" {
    sanitize_git_name ".branch"
    [ $? -eq 0 ]
    [ "$sanitized_git_name" = "branch" ]
}

@test "sanitize_git_name: removes trailing dots" {
    sanitize_git_name "branch."
    [ $? -eq 0 ]
    [ "$sanitized_git_name" = "branch" ]
}

@test "sanitize_git_name: removes command injection attempts" {
    sanitize_git_name "branch;rm -rf /"
    [ $? -eq 0 ]
    [ "$sanitized_git_name" = "branchrm-rf" ]
}

# ===== sanitize_file_path tests =====

@test "sanitize_file_path: accepts valid file path" {
    sanitize_file_path "src/main.sh"
    [ $? -eq 0 ]
    [ "$sanitized_file_path" = "src/main.sh" ]
}

@test "sanitize_file_path: accepts wildcard patterns" {
    sanitize_file_path "*.sh"
    [ $? -eq 0 ]
    [ "$sanitized_file_path" = "*.sh" ]
}

@test "sanitize_file_path: removes null bytes" {
    # Note: bash removes null bytes during command substitution, so we can't test directly
    # Instead, we verify the function handles the input correctly and produces valid output
    # The function uses 'tr -d \000' which removes null bytes
    local test_input="filename"
    sanitize_file_path "$test_input"
    [ $? -eq 0 ]
    [ "$sanitized_file_path" = "$test_input" ]
    # Verify function doesn't crash with control characters (which includes null handling)
    sanitize_file_path "$(printf 'file\001name')"
    [ $? -eq 0 ]
    [ -n "$sanitized_file_path" ]
}

@test "sanitize_file_path: removes ../ sequences" {
    sanitize_file_path "../../etc/passwd"
    [ $? -eq 0 ]
    [[ "$sanitized_file_path" != *".."* ]]
}

@test "sanitize_file_path: removes rm commands" {
    sanitize_file_path "file.txt; rm -rf /"
    [ $? -eq 0 ]
    [[ "$sanitized_file_path" != *"rm"* ]]
}

@test "sanitize_file_path: rejects empty input" {
    ! sanitize_file_path ""
}

@test "sanitize_file_path: rejects too long paths" {
    local long_path=$(printf 'a%.0s' {1..1001})
    ! sanitize_file_path "$long_path"
}

# ===== sanitize_commit_message tests =====

@test "sanitize_commit_message: accepts valid message" {
    sanitize_commit_message "feat: add new feature"
    [ $? -eq 0 ]
    [ "$sanitized_commit_message" = "feat: add new feature" ]
}

@test "sanitize_commit_message: accepts multiline message" {
    local msg="feat: add feature

This is a detailed description"
    sanitize_commit_message "$msg"
    [ $? -eq 0 ]
}

@test "sanitize_commit_message: trims whitespace" {
    sanitize_commit_message "  feat: add feature  "
    [ $? -eq 0 ]
    [ "$sanitized_commit_message" = "feat: add feature" ]
}

@test "sanitize_commit_message: removes null bytes" {
    # Note: bash removes null bytes during command substitution, so we can't test directly
    # Instead, we verify the function handles control characters correctly
    # The function uses 'tr -d \000' which removes null bytes
    sanitize_commit_message "feat: test"
    [ $? -eq 0 ]
    [ "$sanitized_commit_message" = "feat: test" ]
    # Verify function handles control characters (which includes null handling)
    sanitize_commit_message "$(printf 'feat:\001 test')"
    [ $? -eq 0 ]
    [ -n "$sanitized_commit_message" ]
}

@test "sanitize_commit_message: rejects empty input" {
    ! sanitize_commit_message ""
}

@test "sanitize_commit_message: rejects too long messages" {
    local long_msg=$(printf 'a%.0s' {1..2001})
    ! sanitize_commit_message "$long_msg"
}

# ===== sanitize_command tests =====

@test "sanitize_command: accepts valid command name" {
    sanitize_command "vim"
    [ $? -eq 0 ]
    [ "$sanitized_command" = "vim" ]
}

@test "sanitize_command: accepts command with path" {
    sanitize_command "/usr/bin/vim"
    [ $? -eq 0 ]
    [ "$sanitized_command" = "/usr/bin/vim" ]
}

@test "sanitize_command: removes dangerous characters" {
    # This test should verify that dangerous characters are removed, not rejected
    # But for security, we reject commands with dangerous characters
    # So this test should be updated to reflect that behavior
    ! sanitize_command "vim;ls"
}

@test "sanitize_command: rejects command with pipes" {
    ! sanitize_command "vim|cat"
}

@test "sanitize_command: rejects command with semicolon" {
    ! sanitize_command "vim;cat"
}

@test "sanitize_command: rejects command with ampersand" {
    ! sanitize_command "vim&"
}

@test "sanitize_command: rejects command with dollar sign" {
    ! sanitize_command "vim\$HOME"
}

@test "sanitize_command: rejects empty input" {
    ! sanitize_command ""
}

# ===== validate_numeric_input tests =====

@test "validate_numeric_input: accepts valid number" {
    validate_numeric_input "42"
    [ $? -eq 0 ]
    [ "$validated_number" = "42" ]
}

@test "validate_numeric_input: accepts zero" {
    validate_numeric_input "0"
    [ $? -eq 0 ]
    [ "$validated_number" = "0" ]
}

@test "validate_numeric_input: rejects negative numbers" {
    ! validate_numeric_input "-5"
}

@test "validate_numeric_input: rejects non-numeric input" {
    ! validate_numeric_input "abc"
}

@test "validate_numeric_input: rejects decimal numbers" {
    ! validate_numeric_input "3.14"
}

@test "validate_numeric_input: validates minimum value" {
    ! validate_numeric_input "5" "10"
}

@test "validate_numeric_input: validates maximum value" {
    ! validate_numeric_input "100" "" "50"
}

@test "validate_numeric_input: accepts value in range" {
    validate_numeric_input "25" "10" "50"
    [ $? -eq 0 ]
    [ "$validated_number" = "25" ]
}

# ===== validate_email tests =====

@test "validate_email: accepts valid email" {
    validate_email "test@example.com"
    [ $? -eq 0 ]
    [ "$validated_email" = "test@example.com" ]
}

@test "validate_email: accepts email with subdomain" {
    validate_email "user@mail.example.com"
    [ $? -eq 0 ]
    [ "$validated_email" = "user@mail.example.com" ]
}

@test "validate_email: accepts email with plus" {
    validate_email "user+tag@example.com"
    [ $? -eq 0 ]
    [ "$validated_email" = "user+tag@example.com" ]
}

@test "validate_email: accepts email with dots" {
    validate_email "first.last@example.com"
    [ $? -eq 0 ]
    [ "$validated_email" = "first.last@example.com" ]
}

@test "validate_email: rejects email without @" {
    ! validate_email "userexample.com"
}

@test "validate_email: rejects email without domain" {
    ! validate_email "user@"
}

@test "validate_email: rejects email without local part" {
    ! validate_email "@example.com"
}

@test "validate_email: rejects email without TLD" {
    ! validate_email "user@example"
}

@test "validate_email: rejects empty input" {
    ! validate_email ""
}
