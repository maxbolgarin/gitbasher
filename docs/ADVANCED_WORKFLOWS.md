# Advanced Workflows Guide

This guide covers advanced use cases and workflows for **gitbasher** in complex development environments.

## Table of Contents
- [Monorepo Workflows](#monorepo-workflows)
- [Team Collaboration](#team-collaboration)
- [CI/CD Integration](#cicd-integration)
- [Advanced Git Operations](#advanced-git-operations)
- [Performance Optimization](#performance-optimization)
- [Troubleshooting Advanced Scenarios](#troubleshooting-advanced-scenarios)

## Monorepo Workflows

Monorepos contain multiple projects or packages in a single repository. **gitbasher** can be effectively used in monorepo environments with proper practices.

### Multi-Package Commit Scoping

#### 1. Configure Package Scopes

Set up scopes for different packages in your monorepo:

```bash
# Configure scopes for your monorepo
gitb cfg scopes

# Example for a full-stack monorepo:
# Enter: frontend,backend,api,mobile,shared,infra,docs
```

#### 2. Selective File Commits

Commit changes from specific packages:

```bash
# Use interactive commit to select specific package files
gitb commit

# Or use patterns with fast commit
# (Note: gitb fast commits all files, so stage files manually first)
git add packages/frontend/**
gitb commit

# AI commit with package-specific changes
git add packages/api/**
gitb c ai
```

#### 3. Monorepo Branching Strategy

```bash
# Create feature branch for specific package
gitb branch new
# Name: feature/frontend-user-auth

# Or for cross-package changes
gitb branch new
# Name: feature/auth-integration

# Keep branches focused on related changes
```

### Workspace Management

#### Directory-Based Workflow

```bash
# Work on specific package
cd packages/frontend
# Make changes...

# Stage only frontend changes
git add .

# Navigate back to root for commit
cd ../../
gitb c ai  # AI will analyze only frontend changes

# Push from root
gitb push
```

#### Path-Based Commit Messages

Use scopes to indicate which package was modified:

```bash
gitb c  # Interactive commit
# Type: feat
# Scope: frontend
# Description: add user authentication modal

# Result: feat(frontend): add user authentication modal
```

### Monorepo-Specific Patterns

#### 1. Multi-Package Changes

When changes span multiple packages:

```bash
# Stage all related changes
git add packages/frontend/src/auth
git add packages/backend/src/auth
git add packages/shared/types/auth

# Use broader scope or multiple commits
gitb c
# Scope: auth
# Description: implement cross-package authentication system

# Or make separate commits per package
git add packages/frontend/src/auth
gitb c  # Commit frontend changes

git add packages/backend/src/auth
gitb c  # Commit backend changes

git add packages/shared/types/auth
gitb c  # Commit shared changes
```

#### 2. Release Management in Monorepos

```bash
# Tag individual package releases
gitb tag annotated
# Tag: frontend-v1.2.0
# Message: Release frontend package version 1.2.0

# Or tag coordinated releases
gitb tag annotated
# Tag: v2024.11.1
# Message: Monorepo release - all packages v2024.11.1

# Push tags
gitb tag push
```

#### 3. Selective Pull/Push

```bash
# Standard pull (all packages)
gitb pull

# Force push after rebase (use with caution)
gitb push force

# Review changes across packages before push
gitb push list  # See all unpushed commits
```

### Monorepo Best Practices

1. **Consistent Scope Naming**
   ```bash
   # Set up project-wide scopes
   gitb cfg scopes
   # Share this configuration with team
   ```

2. **Atomic Commits Per Package**
   - One commit per package when possible
   - Use clear scopes to indicate package

3. **Branch Naming Convention**
   ```bash
   gitb cfg separator
   # Choose consistent separator: - or /

   # Use format: type/package-feature
   # Examples:
   # feature/frontend-auth
   # fix/backend-api-error
   # refactor/shared-types
   ```

4. **Coordinate Breaking Changes**
   - Use conventional commit breaking change syntax
   - Example: `feat(api)!: change authentication endpoint`

## Team Collaboration

Effective team collaboration requires shared conventions and practices.

### Shared Configuration Setup

#### 1. Repository-Level Configuration

Create a setup script for new team members:

```bash
# setup-gitb.sh in your repository
#!/bin/bash

echo "Setting up gitbasher configuration for this project..."

# Set default branch
gitb cfg default
# Enter: main

# Set branch separator
gitb cfg separator
# Enter: -

# Set project scopes
gitb cfg scopes
# Enter: auth,ui,api,db,infra,docs,test

# Set ticket prefix (if using issue tracker)
gitb cfg ticket
# Enter: PROJ-

echo "Configuration complete!"
echo "Team conventions:"
echo "- Use conventional commits"
echo "- Follow branch naming: type-description"
echo "- Always rebase before merging to main"
```

#### 2. Team Conventions Document

Create `.github/GITBASHER_CONVENTIONS.md`:

```markdown
# Team Git Conventions

## Commit Messages
- Use `gitb c ai` for consistent commit messages
- Always include scope from: auth, ui, api, db, infra, docs, test
- Format: `type(scope): description`

## Branches
- Feature: `feature-description`
- Bug fix: `fix-description`
- Hotfix: `hotfix-description`

## Workflow
1. Create branch: `gitb b newd`
2. Make changes
3. Commit: `gitb c ai`
4. Push: `gitb p`
5. Update with main: `gitb r main`
6. Final push: `gitb p force`
```

### Team Workflow Patterns

#### 1. Feature Development with Code Review

```bash
# Developer A: Start feature
gitb b newd
# Name: feature-user-profile

# Make changes...
gitb c ai
gitb p

# Continue working...
gitb c ai
gitb p

# Developer B: Review requested
# Get latest changes
gitb b remote
# Select: origin/feature-user-profile

# Test locally...

# Developer A: Address feedback
gitb c fix  # Create fixup commit
gitb p

# Prepare for merge
gitb r a     # Auto-squash fixups
gitb p f     # Force push clean history

# Merge to main
gitb m to-main
```

#### 2. Concurrent Development

Multiple developers working on same codebase:

```bash
# Developer A:
gitb b newd
# Name: feature-auth

# Developer B:
gitb b newd
# Name: feature-ui

# Both work independently...

# Developer A merges first:
gitb m to-main

# Developer B updates with main:
gitb b feature-ui  # Switch to your branch
gitb r main        # Rebase on main
# Resolve conflicts if any
gitb p f          # Force push after rebase
gitb m to-main    # Merge to main
```

#### 3. Hotfix Workflow

Critical bug fix coordination:

```bash
# Team lead: Create hotfix branch
gitb b main        # Switch to main
gitb pu           # Get latest
gitb b n          # Create new branch
# Name: hotfix-critical-auth-bug

# Make fix...
gitb c aif        # Fast AI commit
gitb p

# Notify team: "Hotfix pushed"

# All team members: Get hotfix
gitb b main
gitb pu

# Merge hotfix into feature branches
gitb b your-feature-branch
gitb m main
```

### Team Conventions Enforcement

#### 1. Pre-Commit Hooks

Set up hooks to enforce team standards:

```bash
# Create commit-msg hook
gitb hook create
# Select: commit-msg
# Select template: conventional-commits

# This validates commit messages follow conventions
```

#### 2. Commit Message Templates

Create shared commit message template:

```bash
# .gitmessage
# type(scope): description
#
# Types: feat, fix, docs, style, refactor, test, chore
# Scopes: auth, ui, api, db, infra, docs, test
#
# Examples:
# feat(auth): add JWT token refresh
# fix(api): resolve timeout issue
# docs: update API documentation

# Configure globally
git config --global commit.template .gitmessage
```

#### 3. Branch Protection

While gitbasher doesn't enforce branch protection, establish team practices:

```bash
# Never force push to main
# Instead, use feature branches and merge

# Update feature branches with rebase
gitb r main    # Rebase on main
gitb p f       # Force push feature branch (OK)

# Merge to main only via PR/MR
gitb m to-main  # After PR approval
```

### Knowledge Sharing

#### Team Training Commands

```bash
# Show team members available commands
gitb help

# Demonstrate common workflows
gitb c        # Interactive commit
gitb c ai     # AI commit
gitb r i      # Interactive rebase
gitb stash    # Stash management

# Share this guide with team
cat docs/ADVANCED_WORKFLOWS.md
```

## CI/CD Integration

Use **gitbasher** in automated pipelines and continuous integration systems.

### Non-Interactive Mode

Many gitbasher commands can be used non-interactively:

```bash
# Non-interactive commands (no user input required)
gitb st        # Status
gitb pu        # Pull
gitb c fast    # Commit all files
gitb p yes     # Push without confirmation
gitb b main    # Switch to main branch
```

### CI/CD Configuration Examples

#### 1. GitHub Actions

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v3
      with:
        fetch-depth: 0  # Full history for gitb

    - name: Install gitbasher
      run: |
        GITB_PATH=/usr/local/bin/gitb
        curl -SL https://raw.githubusercontent.com/maxbolgarin/gitbasher/main/dist/gitb -o $GITB_PATH
        chmod +x $GITB_PATH

    - name: Configure Git
      run: |
        git config --global user.name "CI Bot"
        git config --global user.email "ci@example.com"

    - name: Run Tests
      run: |
        # Your test commands
        npm test

    - name: Check Git Status
      run: |
        gitb st

    - name: Auto-commit Generated Files
      if: github.event_name == 'push'
      run: |
        if [ -n "$(git status --porcelain)" ]; then
          git add dist/
          gitb c fast
          gitb p yes
        fi
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

#### 2. GitLab CI

```yaml
# .gitlab-ci.yml
stages:
  - setup
  - test
  - deploy

variables:
  GITB_PATH: "/usr/local/bin/gitb"

before_script:
  - apt-get update && apt-get install -y git curl
  - curl -SL https://raw.githubusercontent.com/maxbolgarin/gitbasher/main/dist/gitb -o $GITB_PATH
  - chmod +x $GITB_PATH
  - git config --global user.name "GitLab CI"
  - git config --global user.email "ci@gitlab.example.com"

test:
  stage: test
  script:
    - gitb st
    - npm test

deploy:
  stage: deploy
  script:
    - gitb b main
    - gitb pu
    - gitb tag annotated
    - gitb tag push
  only:
    - main
```

#### 3. Jenkins Pipeline

```groovy
pipeline {
    agent any

    environment {
        GITB_PATH = '/usr/local/bin/gitb'
    }

    stages {
        stage('Setup') {
            steps {
                sh '''
                    curl -SL https://raw.githubusercontent.com/maxbolgarin/gitbasher/main/dist/gitb -o $GITB_PATH
                    chmod +x $GITB_PATH
                    git config --global user.name "Jenkins"
                    git config --global user.email "jenkins@example.com"
                '''
            }
        }

        stage('Test') {
            steps {
                sh '''
                    gitb st
                    npm test
                '''
            }
        }

        stage('Deploy') {
            when {
                branch 'main'
            }
            steps {
                sh '''
                    gitb b main
                    gitb pu
                    gitb c fast
                    gitb p yes
                '''
            }
        }
    }
}
```

### CI/CD Best Practices

#### 1. Environment Variables

Configure gitbasher via environment variables:

```bash
# In CI environment
export GITBASHER_AI_KEY="${AI_API_KEY}"  # From secrets
export GITBASHER_PROXY="${HTTP_PROXY}"   # If needed

# Use in pipeline
gitb c ai  # Will use environment variable
```

#### 2. Automated Tagging

```bash
# Automated release tagging
#!/bin/bash
# release.sh

# Get current version
CURRENT_VERSION=$(git describe --tags --abbrev=0)

# Calculate next version
# (use semantic-release or similar)
NEXT_VERSION="v1.2.3"

# Create and push tag
git tag $NEXT_VERSION
gitb t push

echo "Released $NEXT_VERSION"
```

#### 3. Automated Changelog

```bash
# Generate changelog from commits
#!/bin/bash

# Get commits since last tag
LAST_TAG=$(git describe --tags --abbrev=0)
gitb log compare
# Select: main and $LAST_TAG

# Parse conventional commits for changelog
git log $LAST_TAG..HEAD --pretty=format:"%s" | \
    grep -E "^feat|^fix|^BREAKING" > CHANGELOG.md
```

#### 4. Safe CI Operations

```bash
# Always check before destructive operations
if [ "$CI" = "true" ]; then
    # Use non-interactive commands only
    gitb p yes     # Not: gitb p (would wait for input)
    gitb c fast    # Not: gitb c (would prompt)
fi

# Verify clean state
gitb st
if [ -n "$(git status --porcelain)" ]; then
    echo "Working directory not clean!"
    exit 1
fi
```

### Docker Integration

```dockerfile
# Dockerfile
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    bash \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install gitbasher
RUN GITB_PATH=/usr/local/bin/gitb && \
    curl -SL https://raw.githubusercontent.com/maxbolgarin/gitbasher/main/dist/gitb -o $GITB_PATH && \
    chmod +x $GITB_PATH

WORKDIR /workspace

CMD ["/bin/bash"]
```

Use in CI:

```yaml
# GitHub Actions
jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: your-image-with-gitb:latest

    steps:
    - uses: actions/checkout@v3
    - run: gitb st
    - run: gitb c fast
```

## Advanced Git Operations

Complex git operations made simple with **gitbasher**.

### Interactive Rebase Mastery

#### 1. Cleaning Up Commit History

```bash
# Scenario: You have 10 commits with typos and fixes

# Review commits
gitb log

# Interactive rebase from 10 commits ago
gitb r i

# Select starting commit
# In editor, mark commits as:
# - pick: keep commit
# - reword: change message
# - squash: merge with previous
# - fixup: merge without message
# - drop: delete commit

# Save and exit

# Force push cleaned history
gitb p f
```

#### 2. Autosquash Workflow

```bash
# Initial commit
gitb c
# Message: feat(auth): add login form

# Push and get review
gitb p

# Address review feedback
# Make changes...
gitb c fix
# Select commit to fix up

# More changes...
gitb c fix
# Select same commit again

# Ready to merge: auto-squash all fixups
gitb r a

# Result: Single clean commit
# Force push
gitb p f
```

#### 3. Splitting Large Commits

```bash
# Reset last commit but keep changes
gitb reset

# Now you have uncommitted changes
gitb st

# Make multiple focused commits
git add src/auth/login.js
gitb c
# Message: feat(auth): add login component

git add src/auth/logout.js
gitb c
# Message: feat(auth): add logout component

git add tests/
gitb c
# Message: test(auth): add auth component tests
```

### Cherry-Pick Workflows

#### 1. Selective Feature Integration

```bash
# You need specific commits from another branch

gitb cherry
# Select source branch: feature-new-auth
# Select commits to cherry-pick
# Commits are applied to current branch

# Resolve conflicts if any
gitb st
# Fix conflicts
git add .
git cherry-pick --continue

# Push changes
gitb p
```

#### 2. Backporting Fixes

```bash
# Bug fixed in develop, need in release branch

gitb b
# Select: release-v1.0

# Cherry-pick fix from develop
gitb cherry
# Select branch: develop
# Select the bug fix commit

# Push to release branch
gitb p
```

### Advanced Branch Management

#### 1. Branch Synchronization

```bash
# Keep feature branch updated with main

# Rebase on main (creates linear history)
gitb r main

# Or merge main (preserves history)
gitb m main

# After rebase, force push
gitb p f
```

#### 2. Branch Recovery

```bash
# Accidentally deleted branch

# View reflog
gitb reflog

# Find commit hash of deleted branch
# Create new branch at that commit
git checkout -b recovered-branch <commit-hash>

# Or use reset
gitb reset ref
# Select the commit from reflog
```

#### 3. Parallel Development

```bash
# Working on multiple features simultaneously

# Feature 1
gitb b n
# Name: feature-1
# Work...
gitb c ai
gitb p

# Switch to Feature 2
gitb b newd
# Name: feature-2
# Work...
gitb c ai
gitb p

# Back to Feature 1
gitb b
# Select: feature-1
# Continue work...

# Stash changes if needed
gitb stash
gitb b feature-2
# Work on feature-2
gitb b feature-1
gitb stash pop
```

### Advanced Stash Usage

#### 1. Selective Stashing

```bash
# Stash specific files only
gitb stash select
# Choose files to stash

# Or use git directly
git add file1.js file2.js
git stash push -m "WIP: partial feature" file1.js file2.js
```

#### 2. Stash Branching

```bash
# Create branch from stash

# Show stashes
gitb stash list

# Apply stash to new branch
git stash branch new-feature stash@{0}

# This creates branch and applies stash
```

#### 3. Stash Management

```bash
# Interactive stash menu
gitb stash

# Options:
# - List all stashes
# - Show stash contents
# - Apply stash (keep in list)
# - Pop stash (apply and remove)
# - Drop stash (delete)

# Multiple stashes
gitb stash all
# Message: "WIP: feature A"

gitb b other-branch
# Work...

gitb stash all
# Message: "WIP: feature B"

# Later, recover specific stash
gitb stash list
gitb stash pop  # Select which stash
```

### Advanced Merging

#### 1. Merge Strategies

```bash
# Fast-forward only (fails if not possible)
gitb pu ffonly

# Always create merge commit
gitb pu merge

# Rebase instead of merge
gitb pu rebase
```

#### 2. Conflict Resolution

```bash
# When merge conflict occurs

# Check conflicted files
gitb st

# Option 1: Manual resolution
# Edit files, remove conflict markers
git add resolved-file.js

# Option 2: Take theirs/ours
git checkout --theirs conflicted-file.js
# or
git checkout --ours conflicted-file.js

git add conflicted-file.js

# Complete merge
git commit  # or git merge --continue

# Verify and push
gitb p
```

### Git Bisect Integration

```bash
# Find commit that introduced a bug

git bisect start
git bisect bad                    # Current state is bad
git bisect good <commit-hash>    # Known good commit

# Git checks out middle commit
# Test if bug exists
# Mark as good or bad
git bisect good  # or git bisect bad

# Repeat until found
# Git will identify the problematic commit

git bisect reset  # Clean up
```

### Submodule Management

```bash
# Initialize submodules
git submodule update --init --recursive

# Update submodules
git submodule update --remote

# Work in submodule
cd submodule-directory
gitb st
gitb c ai
gitb p

cd ..
gitb c
# Message: chore: update submodule to latest version
gitb p
```

## Performance Optimization

Tips for using **gitbasher** efficiently in large repositories.

### 1. Large Repository Strategies

```bash
# Shallow clone for CI/CD
git clone --depth 1 <repo-url>

# Fetch only needed branches
git config remote.origin.fetch "+refs/heads/main:refs/remotes/origin/main"

# Use git sparse-checkout for monorepos
git sparse-checkout init
git sparse-checkout set packages/frontend
```

### 2. Optimizing Git Operations

```bash
# Pack git objects
git gc --aggressive --prune=now

# Clean up unnecessary files
git clean -fdx

# Optimize repository
git repack -Ad
git prune
```

### 3. Faster Commits

```bash
# Use fast modes for known changes
gitb c fast   # Skip file selection

# Use AI for quick commit messages
gitb c aif    # AI commit all files

# Combine operations
gitb c fastp  # Commit and push in one command
```

### 4. Efficient Branch Operations

```bash
# List remote branches efficiently
git branch -r | head -20

# Delete merged branches in bulk
gitb b del
# Select multiple branches to delete

# Clean up local refs
git remote prune origin
```

## Troubleshooting Advanced Scenarios

### Complex Merge Conflicts

```bash
# Many conflicting files

# Check what's conflicted
gitb st | grep "both modified"

# Strategy 1: Abort and rebase instead
git merge --abort
gitb r main

# Strategy 2: Use merge tool
git mergetool

# Strategy 3: Manual resolution per file
for file in $(git diff --name-only --diff-filter=U); do
    echo "Resolving: $file"
    # Edit file
    git add "$file"
done

git commit
```

### Recovering Lost Commits

```bash
# View all operations
gitb reflog

# Find lost commit hash
# Checkout commit
git checkout <commit-hash>

# Create branch to save it
gitb b n
# Name: recovered-work

# Or cherry-pick specific commits
gitb b your-branch
git cherry-pick <commit-hash>
```

### Large File Issues

```bash
# Remove large file from history
# (Use git-filter-repo or BFG Repo-Cleaner)

# For future large files, use Git LFS
git lfs install
git lfs track "*.psd"
git add .gitattributes
gitb c
# Message: chore: set up Git LFS for large files
```

### Permission Issues in Team Settings

```bash
# Can't push to branch

# Check branch protection
git remote show origin

# Create new branch
gitb b n
# Name: feature-alternative-name

# Push new branch
gitb p

# Create PR instead of direct push
```

### Detached HEAD State

```bash
# Accidentally in detached HEAD

# Check current commit
git log -1

# Create branch to save work
gitb b n
# Name: temp-work

# Or return to previous branch
git checkout -
```

## Best Practices Summary

### Monorepo
- Configure package-specific scopes
- Use atomic commits per package
- Coordinate breaking changes
- Consider selective workspace commits

### Team Collaboration
- Share configuration setup script
- Document team conventions
- Use commit message templates
- Establish branch protection practices
- Regular training on gitb workflows

### CI/CD
- Use non-interactive commands
- Configure via environment variables
- Implement automated tagging
- Safe operation checks before destructive commands
- Docker integration for consistency

### Advanced Operations
- Master interactive rebase for clean history
- Use autosquash workflow for reviews
- Leverage cherry-pick for selective integration
- Manage multiple features with branches and stash
- Regular repository optimization

---

**Remember**: Always test advanced workflows in a safe environment before applying to production repositories!

For more information:
- [Main README](../README.md)
- [Contributing Guide](../CONTRIBUTING.md)
- [Architecture Documentation](../ARCHITECTURE.md)
- [Security Policy](../SECURITY.md)

**Questions?** Open an issue or contact [@maxbolgarin](https://t.me/maxbolgarin)
