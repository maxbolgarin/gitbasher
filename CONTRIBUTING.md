# Contributing to gitbasher

Thank you for considering contributing to **gitbasher**! This document provides guidelines and instructions for contributing to the project.

## Table of Contents
- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Development Workflow](#development-workflow)
- [Code Standards](#code-standards)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Reporting Bugs](#reporting-bugs)
- [Suggesting Enhancements](#suggesting-enhancements)

## Code of Conduct

This project adheres to a code of conduct that all contributors are expected to follow:

- **Be respectful**: Treat everyone with respect and courtesy
- **Be collaborative**: Work together to improve the project
- **Be patient**: Remember that everyone has different skill levels
- **Be constructive**: Provide helpful feedback and suggestions

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/gitbasher.git
   cd gitbasher
   ```
3. **Add upstream remote**:
   ```bash
   git remote add upstream https://github.com/maxbolgarin/gitbasher.git
   ```

## Development Setup

### Prerequisites

- **Bash 4.0+** (check with `bash --version`)
- **Git 2.23+** (check with `git --version`)
- **BATS** for testing (installed automatically via `make test`)
- **curl** for API requests

### Installing Dependencies

```bash
# macOS
brew install bash git

# Ubuntu/Debian
sudo apt update
sudo apt install bash git

# Windows (WSL)
wsl --install
# Then use Ubuntu/Debian commands
```

### Project Structure

```
gitbasher/
├── scripts/          # Core functionality modules
│   ├── gitb.sh      # Main entry point
│   ├── base.sh      # Command routing
│   ├── init.sh      # Initialization
│   ├── common.sh    # Shared utilities
│   ├── commit.sh    # Commit operations
│   ├── push.sh      # Push operations
│   ├── pull.sh      # Pull operations
│   ├── branch.sh    # Branch management
│   ├── merge.sh     # Merge operations
│   ├── rebase.sh    # Rebase operations
│   ├── tag.sh       # Tag management
│   ├── reset.sh     # Reset operations
│   ├── stash.sh     # Stash management
│   ├── cherry.sh    # Cherry-pick operations
│   ├── gitlog.sh    # Log and history
│   ├── hooks.sh     # Git hooks management
│   ├── ai.sh        # AI integration
│   └── config.sh    # Configuration management
├── dist/            # Distribution files
│   ├── gitb         # Compiled single-file script
│   └── build.sh     # Build script
├── tests/           # BATS test suite
├── docs/            # Additional documentation
├── README.md        # Main documentation
├── CONTRIBUTING.md  # This file
├── SECURITY.md      # Security policies
├── ARCHITECTURE.md  # Technical architecture
├── LICENSE          # MIT License
└── Makefile         # Build and test automation
```

## Development Workflow

### 1. Create a Feature Branch

```bash
# Update your local main
git checkout main
git pull upstream main

# Create a feature branch
git checkout -b feature/your-feature-name
```

### 2. Test-Driven Development

**Always write tests first!** This ensures:
- Your code is testable
- You understand the requirements
- Prevents regressions

```bash
# Create test file
cat > tests/test_your_feature.bats << 'EOF'
#!/usr/bin/env bats

@test "your feature does what it should" {
    # Your test here
}
EOF

# Run tests (they should fail initially)
make test
```

### 3. Implement Your Changes

- Follow the [code standards](#code-standards)
- Keep changes focused and atomic
- Update documentation as needed

### 4. Run Tests

```bash
# Run all tests
make test

# Run specific test file
make test-file FILE=test_your_feature.bats

# Run with verbose output
cd tests && ./run_tests.sh --verbose
```

### 5. Test Manually

```bash
# Build the distribution file
make build

# Test with your changes
./dist/gitb <command>

# Test in a real repository
cp dist/gitb /tmp/gitb-test
cd /path/to/test/repo
/tmp/gitb-test <command>
```

## Code Standards

### Shell Script Best Practices

#### 1. Script Headers
```bash
#!/usr/bin/env bash
# Brief description of what this script does
```

#### 2. Function Documentation
```bash
# Function description
# Arguments:
#   $1 - Description of first argument
#   $2 - Description of second argument
# Returns:
#   Description of return value
function my_function {
    local arg1=$1
    local arg2=$2
    # Implementation
}
```

#### 3. Variable Naming
- Use `snake_case` for variables and functions
- Use descriptive names: `current_branch` not `cb`
- Use `readonly` for constants
- Use `local` for function variables

```bash
readonly DEFAULT_BRANCH="main"
local current_branch=$(git branch --show-current)
```

#### 4. Error Handling
```bash
# Check command success
if ! git fetch origin; then
    echo "Failed to fetch from origin"
    return 1
fi

# Use || for simple error handling
git pull origin main || { echo "Pull failed"; return 1; }
```

#### 5. Input Sanitization

**CRITICAL**: Always sanitize user input to prevent command injection

```bash
# Use sanitize function from common.sh
sanitized_input=$(sanitize "$user_input")

# Never use eval with user input
# BAD: eval "git commit -m '$message'"

# Use parameter expansion for safe string manipulation
message="${user_input//\"/\\\"}"
```

#### 6. Code Style
- Use 4 spaces for indentation (no tabs)
- Line length: aim for 100 characters, max 120
- Use `[[` instead of `[` for conditionals
- Quote variables: `"$var"` not `$var`
- Use `$()` instead of backticks

```bash
# Good
if [[ "$branch" == "main" ]]; then
    echo "On main branch"
fi

# Bad
if [ $branch = "main" ]; then
    echo "On main branch"
fi
```

#### 7. Comments
- Comment **why**, not **what**
- Keep comments up to date
- Use `###` for section headers
- Use `#` for line comments

```bash
### Initialize git repository check
# This check must happen early to provide clear error messages
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Not a git repository"
    exit 1
fi
```

### Commit Message Standards

We follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `test`: Adding or updating tests
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `chore`: Maintenance tasks
- `ci`: CI/CD changes

**Examples:**
```
feat(commit): add support for multiline messages
fix(branch): handle spaces in branch names correctly
docs: update installation instructions for WSL
test: add tests for input sanitization
refactor(common): extract validation logic to separate function
```

## Testing

### Test Structure

```bash
#!/usr/bin/env bats

# Test setup
setup() {
    # Run before each test
    export GITB_TEST=true
}

# Test teardown
teardown() {
    # Run after each test
    unset GITB_TEST
}

@test "descriptive test name" {
    # Arrange
    local input="test input"

    # Act
    result=$(function_to_test "$input")

    # Assert
    [[ "$result" == "expected output" ]]
}
```

### Test Categories

1. **Unit Tests**: Test individual functions
2. **Integration Tests**: Test script interactions
3. **Security Tests**: Test input sanitization
4. **Edge Cases**: Test boundary conditions

### Writing Good Tests

```bash
@test "sanitize removes dangerous characters" {
    # Test command injection prevention
    input='$(rm -rf /)'
    result=$(sanitize "$input")
    [[ "$result" != *'$('* ]]
}

@test "commit handles empty message" {
    run commit_message ""
    [ "$status" -eq 1 ]
    [[ "$output" == *"empty"* ]]
}
```

## Submitting Changes

### Pull Request Process

1. **Ensure tests pass**:
   ```bash
   make test
   ```

2. **Build and test manually**:
   ```bash
   make build
   ./dist/gitb <test commands>
   ```

3. **Update documentation** if needed:
   - README.md for user-facing changes
   - ARCHITECTURE.md for technical changes
   - Inline code comments

4. **Commit your changes**:
   ```bash
   git add .
   git commit -m "feat(scope): description"
   ```

5. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

6. **Create Pull Request**:
   - Go to GitHub
   - Click "New Pull Request"
   - Fill out the PR template
   - Link related issues

### Pull Request Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] All tests pass
- [ ] New tests added
- [ ] Manually tested

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex logic
- [ ] Documentation updated
- [ ] No new warnings introduced
```

## Reporting Bugs

### Before Submitting

1. **Check existing issues**: Search for similar problems
2. **Update to latest version**: `curl -SL https://raw.githubusercontent.com/maxbolgarin/gitbasher/main/dist/gitb -o /usr/local/bin/gitb`
3. **Test in clean environment**: Verify it's not a local configuration issue

### Bug Report Template

```markdown
**Describe the bug**
Clear description of the issue

**To Reproduce**
Steps to reproduce:
1. Run command '...'
2. Enter input '...'
3. See error

**Expected behavior**
What should happen

**Environment:**
- OS: [e.g., macOS 13.0, Ubuntu 22.04]
- Bash version: [from `bash --version`]
- Git version: [from `git --version`]
- gitbasher version: [from first line of `gitb`]

**Additional context**
Any other relevant information
```

## Suggesting Enhancements

### Enhancement Request Template

```markdown
**Is your feature request related to a problem?**
Description of the problem

**Describe the solution you'd like**
Clear description of the desired functionality

**Describe alternatives you've considered**
Other approaches you've thought about

**Additional context**
Mockups, examples, or use cases
```

## Development Tips

### Debugging

```bash
# Enable bash debugging
bash -x ./dist/gitb <command>

# Debug specific function
set -x  # Enable debugging
your_function
set +x  # Disable debugging

# Print variable values
echo "DEBUG: variable=$variable" >&2
```

### Common Issues

1. **Tests fail locally**: Ensure BATS is installed and up to date
2. **Permission errors**: Check file permissions with `ls -la`
3. **Bash version issues**: Use bash 4.0+ (`bash --version`)

### Getting Help

- **Questions**: Open a [Discussion](https://github.com/maxbolgarin/gitbasher/discussions)
- **Bugs**: Open an [Issue](https://github.com/maxbolgarin/gitbasher/issues)
- **Chat**: Contact [@maxbolgarin](https://t.me/maxbolgarin) on Telegram

## Recognition

Contributors are recognized in:
- GitHub contributors page
- Release notes
- Project documentation (for significant contributions)

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

**Thank you for contributing to gitbasher! 🎉**
