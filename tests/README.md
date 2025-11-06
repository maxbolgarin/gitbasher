# Gitbasher Test Suite

This directory contains the test suite for gitbasher, using [BATS (Bash Automated Testing System)](https://github.com/bats-core/bats-core).

## Why Tests?

The test suite provides:

- **Safety for Refactoring**: Change code with confidence knowing tests will catch breakages
- **Security Validation**: Ensure input sanitization functions work correctly
- **Regression Prevention**: Catch bugs before they reach users
- **Documentation**: Tests serve as executable documentation of expected behavior

## Test Coverage

### Current Test Files

1. **test_sanitization.bats** (173 tests)
   - Input sanitization for git names, file paths, commit messages
   - Email validation
   - Numeric input validation
   - Command sanitization
   - **Critical for security** - prevents command injection attacks

2. **test_common_utils.bats**
   - Repository URL handling
   - Git status formatting
   - Commit listing
   - Branch listing and filtering
   - Common utility functions

3. **test_branch_operations.bats**
   - Branch creation and deletion
   - Branch switching
   - Remote branch operations
   - Branch naming validation
   - Merge preparation

4. **test_git_operations.bats**
   - Commit operations
   - Push/pull operations
   - Merge and rebase
   - Reset operations
   - Stash operations
   - Tag operations
   - Cherry-pick operations

## Running Tests

### Quick Start

Run all tests:
```bash
cd tests
./run_tests.sh
```

Run a specific test file:
```bash
cd tests
./run_tests.sh test_sanitization.bats
```

Run a specific test:
```bash
cd tests
bats test_sanitization.bats --filter "sanitize_git_name: accepts valid branch name"
```

### Prerequisites

- Bash 4.0 or higher
- Git 2.23 or higher
- BATS (will be installed automatically by run_tests.sh)

### Manual BATS Installation

If you prefer to install BATS manually:

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install bats
```

**macOS (Homebrew):**
```bash
brew install bats-core
```

**From source:**
```bash
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local
```

## Writing Tests

### Test File Structure

```bash
#!/usr/bin/env bats

# Load common test helpers
load setup_suite

# Setup function runs before each test
setup() {
    setup_test_repo
    source_gitbasher
    cd "$TEST_REPO"
}

# Teardown runs after each test
teardown() {
    cleanup_test_repo
}

# Test case
@test "description of what is being tested" {
    # Arrange - set up test conditions
    create_test_file "test.txt"

    # Act - perform the action
    run some_function "input"

    # Assert - verify the result
    [ "$status" -eq 0 ]
    [ "$output" = "expected output" ]
}
```

### Helper Functions

The `setup_suite.bash` file provides these helpers:

**Repository Management:**
- `setup_test_repo` - Create a temporary git repository
- `cleanup_test_repo` - Remove the test repository
- `setup_remote_repo` - Create a remote repository
- `cleanup_remote_repo` - Remove the remote repository

**File Operations:**
- `create_test_file <name> [content]` - Create a file with content
- `make_test_commit <file> [message]` - Create a commit with a file
- `create_test_branch <name>` - Create and checkout a branch

**Assertions:**
- `assert_success` - Assert command succeeded ($status = 0)
- `assert_failure` - Assert command failed ($status ≠ 0)
- `assert_output_contains <string>` - Assert output contains string
- `assert_output_equals <string>` - Assert output exactly equals string

### Example Test

```bash
@test "sanitize_git_name: removes dangerous characters" {
    run sanitize_git_name "feature\$branch"
    [ "$status" -eq 0 ]
    [ "$sanitized_git_name" = "featurebranch" ]
}
```

## Test Categories

### Security Tests (CRITICAL)

Tests in `test_sanitization.bats` are critical for security:
- Prevent command injection
- Validate all user inputs
- Ensure dangerous characters are removed
- **Never skip these tests**

### Functional Tests

Tests that verify core functionality:
- Git operations work correctly
- Branch management functions properly
- Commit, push, pull, merge operations
- State changes are handled correctly

### Integration Tests

Tests that verify multiple components work together:
- Complete workflows (create branch, commit, push)
- Remote repository interactions
- Conflict resolution

## CI/CD Integration

Tests run automatically on:
- Every push to main branch
- Pull requests
- Manual workflow dispatch

See `.github/workflows/build.yml` for CI configuration.

## Debugging Failed Tests

### Run with verbose output:
```bash
bats -t test_sanitization.bats
```

### Run a single test:
```bash
bats test_sanitization.bats --filter "test name"
```

### Debug test environment:
```bash
# Add to your test:
@test "debug test" {
    setup_test_repo
    echo "Test repo: $TEST_REPO" >&3
    ls -la >&3
}
```

### Common Issues

1. **Test repo not cleaned up**: Make sure `teardown()` runs
2. **Git config missing**: Check `setup_test_repo()` sets user.name/email
3. **Working directory wrong**: Use `cd "$TEST_REPO"` in setup
4. **Bash version**: Requires Bash 4.0+

## Coverage Goals

Current coverage focus:
- ✅ Input sanitization (100% coverage goal)
- ✅ Core git operations (80%+ coverage)
- ✅ Branch operations (80%+ coverage)
- ⏳ Commit workflows (in progress)
- ⏳ AI integration (planned)
- ⏳ Hook management (planned)

## Contributing

When adding new features to gitbasher:

1. **Write tests first** (TDD approach recommended)
2. **Test both success and failure cases**
3. **Test edge cases** (empty input, special characters, etc.)
4. **Test security implications** (especially for user input)
5. **Run all tests** before submitting PR

### Test Checklist

- [ ] Tests pass locally
- [ ] Added tests for new functionality
- [ ] Added tests for bug fixes (regression tests)
- [ ] Security functions have comprehensive tests
- [ ] Edge cases are covered
- [ ] Tests are documented

## Performance

Test suite should run quickly to encourage frequent use:
- Target: < 30 seconds for full suite
- Use temporary directories (cleaned up after each test)
- Avoid unnecessary sleeps/waits
- Mock external dependencies when possible

## References

- [BATS Documentation](https://bats-core.readthedocs.io/)
- [BATS Tutorial](https://github.com/bats-core/bats-core#writing-tests)
- [Gitbasher Contributing Guide](../README.md#contributing)
