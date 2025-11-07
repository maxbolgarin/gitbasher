# Architecture Documentation

## Overview

**gitbasher** is a bash-based git workflow automation tool that provides a user-friendly interface for common git operations. This document describes the technical architecture, design decisions, and implementation details.

## Table of Contents
- [Core Design Principles](#core-design-principles)
- [System Architecture](#system-architecture)
- [Module Structure](#module-structure)
- [Data Flow](#data-flow)
- [Configuration System](#configuration-system)
- [Security Architecture](#security-architecture)
- [Extension Points](#extension-points)
- [Performance Considerations](#performance-considerations)

## Core Design Principles

### 1. Simplicity
- **Single executable**: All scripts compiled into one file (`dist/gitb`)
- **Zero dependencies**: Only requires bash 4.0+ and git 2.23+
- **No installation complexity**: Simple curl + chmod installation

### 2. Safety
- **Input sanitization**: All user inputs are validated and sanitized
- **Error handling**: Comprehensive error checking and user feedback
- **Confirmation prompts**: Destructive operations require confirmation

### 3. Flexibility
- **Configuration system**: Per-repository and global settings
- **Multiple modes**: Different command modes for different workflows
- **Extensibility**: Support for custom hooks and AI integration

### 4. User Experience
- **Interactive menus**: Easy-to-use selection interfaces
- **Colored output**: Visual feedback using ANSI colors
- **Clear messaging**: Informative error and success messages

## System Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     User Input                          │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│                  gitb.sh (Entry Point)                  │
│  - Version check (bash 4.0+)                            │
│  - Git repository validation                            │
│  - Script sourcing and initialization                   │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│              init.sh (Initialization)                   │
│  - Load configuration                                   │
│  - Set up environment                                   │
│  - Detect main branch                                   │
│  - Validate remote                                      │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│             base.sh (Command Router)                    │
│  - Parse command and mode                               │
│  - Route to appropriate script                          │
│  - Handle help and status                               │
└────────────────────┬────────────────────────────────────┘
                     │
        ┌────────────┼────────────┐
        │            │            │
┌───────▼──────┐ ┌──▼──────┐ ┌──▼──────────┐
│   Workflow   │ │ Utility │ │Configuration│
│   Scripts    │ │ Scripts │ │   Scripts   │
│              │ │         │ │             │
│ • commit.sh  │ │common.sh│ │  config.sh  │
│ • push.sh    │ │gitlog.sh│ │   ai.sh     │
│ • pull.sh    │ │hooks.sh │ │             │
│ • branch.sh  │ │         │ │             │
│ • merge.sh   │ │         │ │             │
│ • rebase.sh  │ │         │ │             │
│ • tag.sh     │ │         │ │             │
│ • reset.sh   │ │         │ │             │
│ • stash.sh   │ │         │ │             │
│ • cherry.sh  │ │         │ │             │
└──────────────┘ └─────────┘ └─────────────┘
        │            │            │
        └────────────┼────────────┘
                     │
        ┌────────────▼────────────┐
        │    Git Command Layer    │
        │  - Execute git commands │
        │  - Handle git errors    │
        └────────────┬────────────┘
                     │
        ┌────────────▼────────────┐
        │   Git Repository        │
        └─────────────────────────┘
```

## Module Structure

### Core Modules

#### 1. **gitb.sh** - Entry Point
**Purpose**: Main entry point that bootstraps the application

**Responsibilities**:
- Validate bash version (4.0+ required)
- Check git repository
- Source all module scripts
- Handle initialization mode

**Key Code**:
```bash
if ((BASH_VERSINFO[0] < 4)); then
    # Try to find newer bash
    exec /opt/homebrew/bin/bash "$0" "$@"
fi

git_check=$(git branch --show-current 2>&1)
if [[ "$git_check" == *"fatal: not a git repository"* ]]; then
    echo "You can use gitb only in a git repository"
    exit
fi

source scripts/init.sh
source scripts/common.sh
# ... source other scripts
source scripts/base.sh
```

#### 2. **init.sh** - Initialization
**Purpose**: Set up environment and load configuration

**Responsibilities**:
- Define color constants
- Load git configuration (local and global)
- Detect current and main branch
- Validate remote repository
- Set up first-run experience

**Configuration Loading**:
```bash
function get_config_value {
    value=$(git config --local --get "$1")
    if [ "$value" == "" ]; then
        value=$(git config --global --get "$1")
        if [ "$value" == "" ]; then
            value=$2  # Default value
        fi
    fi
    echo -e "$value"
}
```

**Configuration Hierarchy**:
1. Local repository config (`.git/config`)
2. Global user config (`~/.gitconfig`)
3. Default values

#### 3. **base.sh** - Command Router
**Purpose**: Route commands to appropriate handlers

**Responsibilities**:
- Parse command and mode arguments
- Display help information
- Route to script functions
- Handle unknown commands

**Routing Logic**:
```bash
case "$1" in
    commit|c|co|com)
        commit_script $2
    ;;
    push|p|ps|pus)
        push_script $2
    ;;
    # ... other commands
esac
```

#### 4. **common.sh** - Shared Utilities
**Purpose**: Provide reusable functions and security utilities

**Key Components**:
- **Input Sanitization Framework**
- **Helper Functions**
- **Validation Functions**

**Input Sanitization Functions**:

```bash
# Git name sanitization (branches, tags)
function sanitize_git_name {
    # Remove dangerous characters
    # Allow: letters, numbers, dash, underscore, dot, slash
    # Prevent: .., leading dash, @, HEAD, refs/
}

# File path sanitization
function sanitize_file_path {
    # Remove null bytes and control characters
    # Remove ../ sequences
    # Remove dangerous commands (rm, etc.)
}

# Commit message sanitization
function sanitize_commit_message {
    # Remove control characters
    # Trim whitespace
    # Enforce length limits
}

# Command sanitization (for editor, etc.)
function sanitize_command {
    # Check for dangerous patterns
    # Only allow safe characters
    # Validate format
}
```

### Workflow Modules

#### 5. **commit.sh** - Commit Operations
**Modes**:
- `<empty>`: Interactive file selection + conventional message
- `msg`: Multiline message via editor
- `fast`: Commit all files quickly
- `ai`: AI-generated commit message
- `fixup`: Create fixup commits
- `amend`: Amend last commit

**Key Features**:
- Conventional commit format support
- File selection interface
- Integration with AI module
- Fixup commit workflow

#### 6. **push.sh** - Push Operations
**Modes**:
- `<empty>`: Show commits and push with confirmation
- `yes`: Push without confirmation
- `force`: Force push (with warnings)
- `list`: Show unpushed commits

**Key Features**:
- Conflict detection and handling
- Force push safety checks
- Commit preview before push

#### 7. **pull.sh** - Pull Operations
**Modes**:
- `<empty>`: Smart pull with strategy selection
- `fetch`: Fetch without merge
- `rebase`: Pull with rebase
- `ffonly`: Fast-forward only

**Key Features**:
- Multiple merge strategies
- Interactive strategy selection
- Conflict resolution guidance

#### 8. **branch.sh** - Branch Management
**Modes**:
- `<empty>`: Interactive branch selection
- `new`: Create new branch
- `newd`: Create branch from updated main
- `delete`: Delete branches

**Key Features**:
- Branch listing and filtering
- Safe branch creation
- Remote branch tracking

#### 9. **merge.sh** - Merge Operations
**Modes**:
- `<empty>`: Select branch to merge
- `main`: Merge main into current
- `to-main`: Merge current into main

**Key Features**:
- Conflict detection
- Merge commit generation
- Branch switching

#### 10. **rebase.sh** - Rebase Operations
**Modes**:
- `<empty>`: Interactive base selection
- `main`: Rebase on main
- `interactive`: Interactive rebase
- `autosquash`: Auto-squash fixups

**Key Features**:
- Fixup commit handling
- Interactive rebase interface
- Conflict resolution support

#### 11. **tag.sh** - Tag Management
**Modes**:
- `<empty>`: Create simple tag
- `annotated`: Create annotated tag
- `push`: Push tags to remote
- `delete`: Delete tags

**Key Features**:
- Semantic versioning support
- Tag listing and filtering
- Remote tag synchronization

#### 12. **reset.sh** - Reset Operations
**Modes**:
- `<empty>`: Reset last commit (mixed)
- `soft`: Soft reset
- `undo`: Undo last reset
- `interactive`: Select commit to reset to

**Key Features**:
- Safety confirmations
- Reflog integration
- State preservation

#### 13. **stash.sh** - Stash Management
**Modes**:
- `<empty>`: Interactive stash menu
- `select`: Stash specific files
- `pop`: Apply and remove stash
- `list`: View all stashes

**Key Features**:
- Selective stashing
- Stash preview
- Multiple stash handling

#### 14. **cherry.sh** - Cherry-pick Operations
**Modes**:
- Select commits from branches
- Apply commits to current branch

**Key Features**:
- Commit selection interface
- Conflict handling
- Multiple commit cherry-pick

#### 15. **gitlog.sh** - Log and History
**Modes**:
- `<empty>`: Pretty log for current branch
- `branch`: Log for selected branch
- `compare`: Compare branch logs
- `search`: Search commits

**Search Options**:
- By message
- By author
- By file
- By content (pickaxe)
- By date
- By hash

**Key Features**:
- Colorized output
- Multiple formats
- Advanced search capabilities

### Configuration Modules

#### 16. **config.sh** - Configuration Management
**Settings**:
- `user`: User name and email
- `default`: Default branch name
- `separator`: Branch name separator
- `editor`: Commit message editor
- `ticket`: Ticket prefix
- `scopes`: Common commit scopes
- `ai`: AI API configuration
- `proxy`: HTTP proxy for AI

**Key Features**:
- Interactive configuration
- Local and global settings
- Validation and sanitization

#### 17. **ai.sh** - AI Integration
**API Provider**: Google Gemini (gemini-1.5-flash)

**Features**:
- Automatic commit message generation
- Diff analysis
- Multiline message support
- Proxy support for restricted regions

**Flow**:
```
1. Get staged changes (git diff)
2. Format diff for AI
3. Send to API with prompt
4. Parse and validate response
5. Present to user for approval
```

**Key Functions**:
```bash
# Generate commit message from staged changes
function generate_ai_commit_message {
    diff=$(git diff --cached)
    response=$(call_ai_api "$diff")
    parse_conventional_commit "$response"
}
```

#### 18. **hooks.sh** - Git Hooks Management
**Operations**:
- List all hooks with status
- Create hooks from templates
- Edit existing hooks
- Toggle hooks (enable/disable)
- Remove hooks
- Test hook execution
- View hook contents

**Templates**:
- Pre-commit hooks
- Commit-msg hooks
- Pre-push hooks
- Custom hooks

## Data Flow

### Typical Command Flow

```
User Input: gitb commit ai
         │
         ▼
    [gitb.sh]
         │
         ├─ Version Check
         ├─ Git Repo Check
         └─ Source Scripts
         │
         ▼
    [init.sh]
         │
         ├─ Load Config
         ├─ Detect Branches
         └─ Validate Remote
         │
         ▼
    [base.sh]
         │
         └─ Route to commit_script("ai")
         │
         ▼
    [commit.sh]
         │
         ├─ Check staged files
         ├─ Get diff
         └─ Call AI module
         │
         ▼
     [ai.sh]
         │
         ├─ Format diff
         ├─ Call API
         ├─ Parse response
         └─ Return message
         │
         ▼
    [commit.sh]
         │
         ├─ Show preview
         ├─ Get user confirmation
         └─ Execute: git commit -m "message"
         │
         ▼
    [Git Layer]
         │
         └─ Create commit
```

### Configuration Flow

```
git config --local gitbasher.setting
         │
         ▼
    [init.sh: get_config_value]
         │
         ├─ Try local config
         ├─ Try global config
         └─ Use default value
         │
         ▼
    Variable available to all scripts
```

## Configuration System

### Configuration Storage

**Local Configuration** (`.git/config`):
```ini
[gitbasher]
    branch = main
    sep = -
    isfirst = false
    scopes = auth,ui,api,db
    ticket = JIRA-123
    ai = your-api-key
```

**Global Configuration** (`~/.gitconfig`):
```ini
[gitbasher]
    sep = /
    ai = global-api-key
    proxy = http://proxy.example.com:8080
```

### Configuration Priority

1. **Local** (repository-specific) - Highest priority
2. **Global** (user-wide)
3. **Default** (hardcoded) - Lowest priority

### Key Configurations

| **Setting** | **Key** | **Default** | **Description** |
|-------------|---------|-------------|-----------------|
| Main Branch | `gitbasher.branch` | `main` | Default branch name |
| Separator | `gitbasher.sep` | `-` | Branch name separator |
| Editor | `core.editor` | `vi` | Commit message editor |
| Ticket | `gitbasher.ticket` | `""` | Ticket prefix |
| Scopes | `gitbasher.scopes` | `""` | Comma-separated scopes |
| AI Key | `gitbasher.ai` | `""` | Google AI API key |
| Proxy | `gitbasher.proxy` | `""` | HTTP proxy URL |

## Security Architecture

### Input Sanitization Framework

**Multi-Layer Security Model**:

```
User Input
    │
    ▼
┌─────────────────────┐
│ Input Validation    │  ← Check format and type
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Sanitization        │  ← Remove dangerous characters
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Context-Specific    │  ← Apply context rules
│ Validation          │    (git names, paths, etc.)
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Length & Pattern    │  ← Final checks
│ Checks              │
└──────┬──────────────┘
       │
       ▼
  Safe to Use
```

### Security Functions

1. **sanitize_git_name**: Branch and tag names
2. **sanitize_file_path**: File paths for git operations
3. **sanitize_commit_message**: Commit messages
4. **sanitize_command**: Command names (editor, etc.)
5. **sanitize_text_input**: General text input
6. **validate_git_url**: Remote repository URLs

### Threat Model

**Protected Against**:
- Command injection via user input
- Path traversal attacks
- Control character injection
- Null byte injection
- Malicious git references

**Example Attack Prevention**:
```bash
# Attack attempt
user_input='main; rm -rf /'

# Sanitization
sanitize_git_name "$user_input"
# Result: "mainrm-rf" (semicolon and spaces removed)

# Safe usage
git checkout "$sanitized_git_name"  # Safe
```

## Extension Points

### 1. Custom Git Hooks
Users can create custom hooks via the hook management system:
```bash
gitb hook create
# Select hook type and template
```

### 2. AI Provider Integration
Current: Google Gemini
Future: Pluggable AI providers

**Extension Point**:
```bash
function call_ai_api {
    local diff="$1"
    # Call configured AI provider
    # Return formatted response
}
```

### 3. Custom Commit Scopes
Per-project commit scopes:
```bash
gitb cfg scopes
# Enter: auth,ui,api,db,infra
```

### 4. Custom Branch Naming
Configurable separators and patterns:
```bash
gitb cfg separator
# Choose: - or / or _
```

## Performance Considerations

### 1. Single-File Distribution
**Benefit**: Fast loading, single process
**Trade-off**: Larger file size (~300KB)

### 2. Lazy Evaluation
- Functions defined but not executed until needed
- Git operations only when required

### 3. Minimal External Calls
- Use bash built-ins where possible
- Batch git operations
- Cache configuration values

### 4. Efficient Parsing
```bash
# Fast branch parsing
current_branch=$(git branch --show-current)

# Efficient remote detection
origin_name=$(git remote -v | head -n 1 | sed 's/\t.*//')
```

### 5. Interactive Performance
- Use `read -n 1` for single key input
- Limit output with `head`/`tail`
- Use color escapes efficiently

## Build System

### Build Process
```bash
# dist/build.sh
# Concatenates all scripts into single file
# Removes duplicate sourcing
# Adds version header
```

### Build Output
```
dist/gitb
    ├─ Header (version, license)
    ├─ init.sh (initialization)
    ├─ common.sh (utilities)
    ├─ ai.sh (AI integration)
    ├─ config.sh (configuration)
    ├─ [all other scripts]
    └─ base.sh (command router)
```

## Testing Architecture

### Test Framework
**BATS** (Bash Automated Testing System)

### Test Structure
```
tests/
├── run_tests.sh              # Test runner
├── test_sanitization.bats    # Security tests
├── test_common.bats          # Utility tests
├── test_commit.bats          # Commit tests
├── test_branch.bats          # Branch tests
└── ...
```

### Test Categories

1. **Unit Tests**: Individual function testing
2. **Integration Tests**: Multi-function workflows
3. **Security Tests**: Input sanitization
4. **Edge Cases**: Boundary conditions

### Test Example
```bash
@test "sanitize_git_name removes dangerous characters" {
    source scripts/common.sh

    sanitize_git_name 'test$(rm -rf /)'
    [[ "$sanitized_git_name" == "testrm-rf" ]]
}
```

## Future Architecture Considerations

### Planned Improvements (v4)

1. **Multi-Mode Support**
   ```bash
   gitb c fast push  # Instead of: gitb c fastp
   ```

2. **Enhanced Modularity**
   - Plugin system for extensions
   - Dynamic script loading

3. **Improved Error Handling**
   - Structured error codes
   - Detailed error context
   - Recovery suggestions

4. **Multiple AI Providers**
   - Provider abstraction layer
   - Configurable provider selection
   - Fallback mechanisms

5. **Performance Optimization**
   - Cached git status
   - Parallel operations where safe
   - Reduced subprocess calls

## Dependencies

### Required
- **bash**: 4.0+ (for associative arrays, etc.)
- **git**: 2.23+ (for `git switch`, modern features)

### Optional
- **curl**: For AI features and updates
- **editor**: For multiline commits (vi/nano/etc.)

### No External Dependencies
- No Python, Ruby, Node.js required
- No package managers needed
- Purely bash + git

## Conclusion

**gitbasher** is architected for:
- **Simplicity**: Easy to understand and modify
- **Security**: Multiple layers of input validation
- **Flexibility**: Configurable and extensible
- **Performance**: Fast and efficient
- **Maintainability**: Modular and well-organized

The architecture supports the core mission: making git operations simple, safe, and efficient for developers.

---

**Version**: 3.x
**Last Updated**: 2025-11-07
