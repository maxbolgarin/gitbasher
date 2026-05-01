#!/usr/bin/env bats

# Tests for sanitization functions not covered by test_sanitization.bats:
# sanitize_text_input, validate_scope_list, additional sanitize_git_name and
# sanitize_file_path edge cases.

load setup_suite

setup() {
    source_gitbasher
}

# ===== sanitize_text_input tests =====

@test "sanitize_text_input: accepts plain text" {
    sanitize_text_input "Hello world"
    [ $? -eq 0 ]
    [ "$sanitized_text" = "Hello world" ]
}

@test "sanitize_text_input: trims surrounding whitespace" {
    sanitize_text_input "  spaced  "
    [ $? -eq 0 ]
    [ "$sanitized_text" = "spaced" ]
}

@test "sanitize_text_input: rejects empty input" {
    ! sanitize_text_input ""
}

@test "sanitize_text_input: rejects whitespace-only input" {
    ! sanitize_text_input "   "
}

@test "sanitize_text_input: enforces default 500 char limit" {
    local long
    long=$(printf 'a%.0s' {1..501})
    ! sanitize_text_input "$long"
}

@test "sanitize_text_input: respects custom max length" {
    sanitize_text_input "abcdef" 10
    [ $? -eq 0 ]
    ! sanitize_text_input "abcdefghijklmn" 10
}

@test "sanitize_text_input: accepts text exactly at max length" {
    sanitize_text_input "abcde" 5
    [ $? -eq 0 ]
    [ "$sanitized_text" = "abcde" ]
}

@test "sanitize_text_input: strips control characters" {
    sanitize_text_input "$(printf 'foo\001bar')"
    [ $? -eq 0 ]
    [[ "$sanitized_text" != *$'\001'* ]]
}

@test "sanitize_text_input: preserves UTF-8 content" {
    sanitize_text_input "Привет мир"
    [ $? -eq 0 ]
    [ "$sanitized_text" = "Привет мир" ]
}

# ===== validate_scope_list tests =====

@test "validate_scope_list: accepts single scope" {
    validate_scope_list "feat"
    [ $? -eq 0 ]
    [ "$validated_scopes" = "feat" ]
}

@test "validate_scope_list: accepts multiple scopes" {
    validate_scope_list "feat fix docs"
    [ $? -eq 0 ]
    [ "$validated_scopes" = "feat fix docs" ]
}

@test "validate_scope_list: accepts up to nine scopes" {
    validate_scope_list "a b c d e f g h i"
    [ $? -eq 0 ]
}

@test "validate_scope_list: rejects more than nine scopes" {
    ! validate_scope_list "a b c d e f g h i j"
}

@test "validate_scope_list: rejects empty input" {
    ! validate_scope_list ""
}

@test "validate_scope_list: rejects scope with digits" {
    ! validate_scope_list "feat1 fix"
}

@test "validate_scope_list: rejects scope with special chars" {
    ! validate_scope_list "feat-fix"
    ! validate_scope_list "feat,fix"
    ! validate_scope_list "feat;fix"
}

@test "validate_scope_list: rejects double-spaced scopes" {
    ! validate_scope_list "feat  fix"
}

# ===== Additional sanitize_git_name tests =====

@test "sanitize_git_name: accepts single character name" {
    sanitize_git_name "a"
    [ $? -eq 0 ]
    [ "$sanitized_git_name" = "a" ]
}

@test "sanitize_git_name: accepts long valid name (255 chars)" {
    local name
    name=$(printf 'a%.0s' {1..255})
    sanitize_git_name "$name"
    [ $? -eq 0 ]
}

@test "sanitize_git_name: rejects name longer than 255 chars" {
    local name
    name=$(printf 'a%.0s' {1..256})
    ! sanitize_git_name "$name"
}

@test "sanitize_git_name: strips leading @ symbol" {
    sanitize_git_name "@feature"
    [ $? -eq 0 ]
    [ "$sanitized_git_name" = "feature" ]
}

@test "sanitize_git_name: removes parentheses from injection attempts" {
    sanitize_git_name 'feat$(rm)'
    [ $? -eq 0 ]
    [[ "$sanitized_git_name" != *'$'* ]]
    [[ "$sanitized_git_name" != *'('* ]]
    [[ "$sanitized_git_name" != *')'* ]]
}

@test "sanitize_git_name: removes backticks" {
    sanitize_git_name 'feat`whoami`'
    [ $? -eq 0 ]
    [[ "$sanitized_git_name" != *'`'* ]]
}

@test "sanitize_git_name: removes pipes and redirects" {
    sanitize_git_name "feat|cat"
    [ $? -eq 0 ]
    [[ "$sanitized_git_name" != *'|'* ]]
    sanitize_git_name "feat>file"
    [ $? -eq 0 ]
    [[ "$sanitized_git_name" != *'>'* ]]
}

@test "sanitize_git_name: rejects name with only forbidden chars" {
    ! sanitize_git_name '$()`'
    ! sanitize_git_name ';;;'
}

# ===== Additional sanitize_file_path tests =====

@test "sanitize_file_path: accepts nested directory paths" {
    sanitize_file_path "src/lib/utils/helper.sh"
    [ $? -eq 0 ]
    [ "$sanitized_file_path" = "src/lib/utils/helper.sh" ]
}

@test "sanitize_file_path: accepts paths with brackets" {
    sanitize_file_path "src/[abc].txt"
    [ $? -eq 0 ]
}

@test "sanitize_file_path: accepts dotfiles" {
    sanitize_file_path ".gitignore"
    [ $? -eq 0 ]
}

@test "sanitize_file_path: removes leading rm command" {
    sanitize_file_path "rm important.txt"
    [ $? -eq 0 ]
    [[ "$sanitized_file_path" != "rm important.txt" ]]
}

@test "sanitize_file_path: removes trailing rm" {
    sanitize_file_path "important.txt rm"
    [ $? -eq 0 ]
    [[ "$sanitized_file_path" != *" rm" ]]
}

@test "sanitize_file_path: removes rm after &&" {
    sanitize_file_path "file && rm trash"
    [ $? -eq 0 ]
    [[ "$sanitized_file_path" != *"rm trash"* ]]
}

@test "sanitize_file_path: removes rm after pipe" {
    sanitize_file_path "file | rm trash"
    [ $? -eq 0 ]
    [[ "$sanitized_file_path" != *"rm trash"* ]]
}

@test "sanitize_file_path: accepts path at exactly 1000 chars" {
    local path
    path=$(printf 'a%.0s' {1..1000})
    sanitize_file_path "$path"
    [ $? -eq 0 ]
}

# ===== Additional sanitize_commit_message tests =====

@test "sanitize_commit_message: accepts message at exactly 2000 chars" {
    local msg
    msg=$(printf 'a%.0s' {1..2000})
    sanitize_commit_message "$msg"
    [ $? -eq 0 ]
}

@test "sanitize_commit_message: preserves tabs" {
    sanitize_commit_message "$(printf 'feat:\tadd feature')"
    [ $? -eq 0 ]
    [[ "$sanitized_commit_message" == *$'\t'* ]]
}

@test "sanitize_commit_message: rejects whitespace-only message" {
    ! sanitize_commit_message "   "
    ! sanitize_commit_message "$(printf '\t\t\t')"
}

@test "sanitize_commit_message: handles emojis" {
    sanitize_commit_message "feat: ✨ add sparkles"
    [ $? -eq 0 ]
    [ "$sanitized_commit_message" = "feat: ✨ add sparkles" ]
}

# ===== Additional sanitize_command tests =====

@test "sanitize_command: accepts editor name" {
    sanitize_command "nano"
    [ $? -eq 0 ]
    [ "$sanitized_command" = "nano" ]
}

@test "sanitize_command: accepts code-with-dash" {
    sanitize_command "code-insiders"
    [ $? -eq 0 ]
    [ "$sanitized_command" = "code-insiders" ]
}

@test "sanitize_command: rejects command starting with dash" {
    ! sanitize_command "-flag"
}

@test "sanitize_command: rejects path traversal in command" {
    ! sanitize_command "../bin/evil"
}

@test "sanitize_command: rejects backticks" {
    ! sanitize_command 'vim`whoami`'
}

@test "sanitize_command: rejects too long command" {
    local cmd
    cmd=$(printf 'a%.0s' {1..101})
    ! sanitize_command "$cmd"
}

# ===== Additional validate_email tests =====

@test "validate_email: rejects email longer than 254 chars" {
    local local_part
    local_part=$(printf 'a%.0s' {1..250})
    local email="${local_part}@x.com"  # 257 chars
    ! validate_email "$email"
}

@test "validate_email: accepts email at boundary (254 chars)" {
    local local_part
    local_part=$(printf 'a%.0s' {1..247})
    local email="${local_part}@x.com"  # 254 chars
    validate_email "$email"
    [ $? -eq 0 ]
}

@test "validate_email: rejects email with multiple @" {
    ! validate_email "a@b@c.com"
}

@test "validate_email: rejects email with spaces" {
    ! validate_email "user name@example.com"
}

@test "validate_email: accepts email with single-letter TLD rejection" {
    ! validate_email "user@example.c"
}

@test "validate_email: rejects email with disallowed local-part chars" {
    ! validate_email "us!er@example.com"
    ! validate_email "us(er@example.com"
}

# ===== Additional validate_numeric_input tests =====

@test "validate_numeric_input: accepts large valid number" {
    validate_numeric_input "999999"
    [ $? -eq 0 ]
    [ "$validated_number" = "999999" ]
}

@test "validate_numeric_input: rejects empty input" {
    ! validate_numeric_input ""
}

@test "validate_numeric_input: rejects number with leading whitespace" {
    ! validate_numeric_input " 5"
}

@test "validate_numeric_input: rejects scientific notation" {
    ! validate_numeric_input "1e5"
}

@test "validate_numeric_input: accepts boundary values" {
    validate_numeric_input "10" "10" "10"
    [ $? -eq 0 ]
    [ "$validated_number" = "10" ]
}
