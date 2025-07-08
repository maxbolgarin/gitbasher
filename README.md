# gitbasher – simple **bash** utility that makes **git** easy to use


[![Latest Release](https://img.shields.io/github/v/release/maxbolgarin/gitbasher.svg?style=flat-square)](https://github.com/maxbolgarin/gitbasher/releases/latest)
[![GitHub license](https://img.shields.io/github/license/maxbolgarin/gitbasher.svg)](https://github.com/maxbolgarin/gitbasher/blob/master/LICENSE)
[![Build Status](https://github.com/maxbolgarin/gitbasher/actions/workflows/build.yml/badge.svg)](https://github.com/maxbolgarin/gitbasher/actions)

<picture>
    <img src=".github/commit.gif" width="600" alt="commit example">
</picture>

---

With **gitbasher** usage of `git` becomes more simple and intuitive. It helps speeding up the development process, making it more consistent reducing mistakes. This is a wrapper around the most used git commands with a cleaner interface. It uses `bash` `git` `sed` `grep`, `curl` and some built-in utilities.


### Quick Installation

```bash
GITB_PATH=/usr/local/bin/gitb && \
curl -SL https://raw.githubusercontent.com/maxbolgarin/gitbasher/main/dist/gitb -o $GITB_PATH && \
chmod +x $GITB_PATH
```

In Windows use `wsl` (enter `wsl` in terminal, [read more](https://learn.microsoft.com/en-us/windows/wsl/setup/environment)) to enable Linux environment. Directory `/usr/local/bin/` is not mandatory. If you get `Permission denied`, use `sudo` or put it to `~/.local/bin` with adding it to `PATH` ([how](https://discussions.apple.com/thread/254226896)).


## Table of Contents
- [Quick Start Guide](#quick-start-guide)
- [Why You Should Try This](#why-you-should-try-this)
- [Real-World Examples](#real-world-examples)
- [AI-Powered Commits](#ai-powered-commits)
- [Common Workflows](#common-workflows)
- [Complete Documentation](#complete-documentation)
- [Troubleshooting & FAQ](#troubleshooting--faq)
- [Contributing](#contributing)


## Quick Start Guide

### 1. First Steps
```bash
# Navigate to any git repository
cd your-project

# See all available commands
gitb
```

### 2. Your First Commit
```bash
# Smart commit - select files and create conventional message
gitb commit

# Fast commit - add all files with quick message
gitb commit fast

# AI-powered commit (after setting up API key)
gitb commit ai
```

### 3. Essential Daily Commands
```bash
gitb status        # Check status
gitb commit        # Make a commit
gitb push          # Push changes
gitb pull          # Pull changes
gitb branch        # Switch branches
```

### 4. Set Up Your Environment
```bash
# Configure your identity
gitb cfg user

# Set default branch (usually 'main' or 'master')
gitb cfg default

# Set up AI features (optional but recommended)
gitb cfg ai
```


## Why You Should Try This

**gitbasher** is essential if you use `git` on the daily basis. Benefits you will get:

* **⚡ Faster Development**: Spend almost no time on git commands
* **🧠 No More Memorizing**: No need to remember/google exact command names and parameters
* **📝 Better Commit Messages**: Conventional commits with manual or **AI-generated** messages
* **🔧 Advanced Commands Made Easy**: Use `git rebase`, `git stash`, and hooks without complexity
* **🌊 GitHub Flow**: Simplified branch management following best practices
* **🎯 Consistent Workflow**: Standardized processes across your team

<picture>
    <img src=".github/push.gif" width="600" alt="push example">
</picture>


## Real-World Examples

### 🚀 Scenario 1: Starting a New Feature

**Traditional Git:**
```bash
git switch main                   # Switch to main
git pull origin main                # Get latest changes
git switch -c feature/user-auth   # Create new branch
# ... make changes ...
git add src/auth.js src/login.js    # Stage files
git commit -m "feat(auth): add user authentication system"
git push -u origin feature/user-auth
```

**With gitbasher:**
```bash
gitb branch newd                   # Create new branch from updated main
# ... make changes ...
gitb commit push                    # Smart commit + push
```

### 🐛 Scenario 2: Quick Bug Fix

**Traditional Git:**
```bash
git status                          # Check what's changed
git add .                          # Add all files
git commit -m "fix: resolve login issue"
git push
```

**With gitbasher:**
```bash
gitb commit push                   # Fast commit + push (one command!)
```

### 🔀 Scenario 3: Merging Feature Branch

**Traditional Git:**
```bash
git switch main
git pull origin main
git merge feature/user-auth
git push origin main
git branch -d feature/user-auth
```

**With gitbasher:**
```bash
gitb merge to-main             # Switch to main and merge current branch
gitb branch delete                 # Select and delete the merged branch
```

### 🤖 Scenario 4: AI-Powered Development

**After making changes to multiple files:**
```bash
gitb commit ai                   # AI analyzes changes and generates:
                           # "feat(auth): implement JWT authentication with refresh tokens"
```

**For quick fixes:**
```bash
gitb commit aif                  # AI commit all files with smart message
```

### 🎯 Scenario 5: Code Review Preparation

**Clean up commits before PR:**
```bash
gitb rebase i                    # Interactive rebase to squash/reorder commits
gitb commit fix                  # Create fixup commits for review feedback
gitb rebase s                    # Auto-squash fixup commits
```

### 📦 Scenario 6: Release Management

**Creating and managing releases:**
```bash
gitb tag                      # Create version tag
gitb tag push                 # Push tag to remote
gitb log                      # Review commit history
```


## AI-Powered Commits

Transform your commit workflow with AI-generated messages that follow conventional commit standards.

### Setup (One-time)

#### 1. Get Your API Key
- Visit [Google AI Studio](https://aistudio.google.com/app/apikey)
- Create a new API key
- Copy it for the next step

#### 2. Configure gitbasher
```bash
gitb cfg ai
# Enter your API key when prompted
# Choose local (current repo) or global (all repos)
```

#### 3. Optional: Proxy Setup
For regions with API restrictions:
```bash
gitb cfg proxy
# Examples:
# http://proxy.example.com:8080
# http://username:password@proxy.example.com:8080
```

### AI Command Examples

| **Scenario** | **Command** | **What It Does** |
|--------------|-------------|------------------|
| **Staged files ready** | `gitb c ai` | Analyzes staged changes, generates message |
| **Quick fix needed** | `gitb c aif` | Adds all files + AI message |
| **Ready to ship** | `gitb c aip` | AI commit + automatic push |
| **Full workflow** | `gitb c aifp` | Add all + AI commit + push |
| **Need control** | `gitb c ais` | AI message + manual type/scope |
| **Detailed commit** | `gitb c aim` | Generates multiline commit message |

## Common Workflows

### 🔄 Daily Development Workflow

```bash
# Start your day
gitb st                     # Check repository status
gitb pu                     # Pull latest changes

# Work on features
gitb b n                    # Create new feature branch
# ... code changes ...
gitb c ai                   # AI-powered commit
gitb p                      # Push changes

# Code review cycle
gitb c fix                  # Create fixup commits
gitb r a                    # Clean up with autosquash
gitb p f                    # Force push cleaned history
```

### 🚨 Hotfix Workflow

```bash
gitb b main                 # Switch to main branch
gitb pu                     # Get latest changes
gitb b n                    # Create hotfix branch
# ... fix the issue ...
gitb c aif                  # Fast AI commit
gitb p                      # Push hotfix
gitb m to-main             # Merge to main
```

### 🔀 Feature Integration

```bash
# Prepare feature for merge
gitb pu                     # Update current branch
gitb r main                 # Rebase on main
gitb l                      # Review commit history
gitb c fix                  # Address review feedback
gitb r a                    # Squash fixups

# Integrate
gitb m to-main             # Merge to main
gitb b del                 # Clean up feature branch
```

### 🎯 Release Workflow

```bash
gitb b main                 # Switch to main
gitb pu                     # Get latest changes
gitb l                      # Review changes since last release
gitb t a                    # Create annotated release tag
gitb t push                 # Push tag to trigger CI/CD
```

### 🛠️ Maintenance Workflow

```bash
# Clean up old branches
gitb b del                  # Interactive branch deletion

# Manage stashes
gitb stash                  # Interactive stash management

# Check hooks
gitb hook list              # See all git hooks status
gitb hook create            # Set up project hooks
```


## Complete Documentation

### Available Commands

| Command                         | Short aliases       | Description                              |
|---------------------------------|---------------------|------------------------------------------|
| [**commit**](#gitb-commit-mode) | `c` `co` `com`    | Everything about commit creation         |
| [**push**](#gitb-push-mode)     | `p` `ps` `ph`     | Pushing changes to a remote repository   |
| [**pull**](#gitb-pull-mode)     | `pu` `pl` `pul`   | Pulling changes from a remote repository |
| [**branch**](#gitb-branch-mode) | `b` `br` `bran`   | Managing branches                        |
| [**tag**](#gitb-tag-mode)       | `t` `tg`           | Managing tags                            |
| [**merge**](#gitb-merge-mode)   | `m` `me`           | Merge changes to the current branch      |
| [**rebase**](#gitb-rebase-mode) | `r` `re` `base`   | Rebase current branch                    |
| [**reset**](#gitb-reset-mode)   | `res`               | Easy to use git reset                    |
| [**stash**](#gitb-stash-mode)   | `s` `sta`          | Manage git stashes                       |
| [**hook**](#gitb-hook-mode)     | `ho` `hk`          | Comprehensive git hooks management with interactive menus |
| [**config**](#gitb-config-mode) | `cf` `cfg` `conf` | Configurate gitbasher                    |
| **status**                      | `st`                | Info about repo and changed files        |
| [**log**](#gitb-log-mode)       | `l` `lg`           | Git log utilities and search functions   |
| **reflog**                      | `rl` `rlg`         | Open git reflog in a pretty format       |
| **help**                        | `h` `man`          | Show help                                |


### `gitb commit <mode>`

| **Mode**   | **Short**    | **Description** | **Example Use Case** |
|------------|--------------|-----------------|---------------------|
| `<empty>`  |              | Select files to commit and create conventional message | Regular feature development |
| `msg`      | `m`          | Create multiline commit message using text editor | Detailed commit descriptions |
| `ticket`   | `t`          | Add tracker's ticket info to commit header | JIRA/GitHub issue integration |
| `fast`     | `f`          | Add all files and create commit without scope | Quick bug fixes |
| `fasts`    | `fs`         | Add all files and create commit with scope | Feature additions |
| `push`     | `pu` `p`    | Create commit and push changes | Deploy-ready commits |
| `fastp`    | `fp`         | Fast commit and push | One-command workflow |
| `fastsp`   | `fsp` `fps` | Fast commit with scope and push | Complete feature deployment |
| `ai`       | `llm` `i`   | AI-generated commit message | Smart commit automation |
| `aif`      | `llmf` `if` | Fast AI commit without confirmation | Rapid development |
| `aip`      | `llmp` `ip` | AI commit and push | AI-powered deployment |
| `aifp`     | `llmfp` `ifp` | Fast AI commit with push | Complete AI workflow |
| `ais`      | `llms` `is` | AI summary with manual type/scope | Controlled AI assistance |
| `aim`      | `llmm` `im` | AI multiline commit message | Detailed AI documentation |
| `fixup`    | `fix` `x`   | Create fixup commit for rebase | Code review fixes |
| `fixupp`   | `fixp` `xp` | Fixup commit and push | Remote fixup commits |
| `fastfix`  | `fx`         | Fast fixup all files | Quick fixup workflow |
| `fastfixp` | `fxp`        | Fast fixup and push | Complete fixup deployment |
| `amend`    | `am` `a`    | Add files to last commit | Forgot to include files |
| `amendf`   | `amf` `af`  | Amend with all files | Complete last commit |
| `last`     | `l`          | Change last commit message | Fix commit message typos |
| `revert`   | `rev`        | Revert selected commit | Undo problematic changes |

### `gitb push <mode>`

| **Mode**  | **Short** | **Description** | **When to Use** |
|-----------|-----------|-----------------|-----------------|
| `<empty>` |           | Show commits and push with conflict handling | Regular push workflow |
| `yes`     | `y`       | Push without confirmation | Automated scripts |
| `force`   | `f`       | Force push (use with caution) | After rebase/amend |
| `list`    | `log` `l` | Show unpushed commits only | Review before push |

### `gitb pull <mode>`

| **Mode**      | **Short**  | **Description** | **Best For** |
|---------------|------------|-----------------|--------------|
| `<empty>`     |            | Smart pull with strategy selection | Daily workflow |
| `fetch`       | `fe`       | Fetch only, no merge | Review changes first |
| `all`         | `fa`       | Fetch all branches | Sync repository |
| `upd`         | `u`        | Update all remote references | Branch cleanup |
| `ffonly`      | `ff`       | Fast-forward only merge | Linear history |
| `merge`       | `m`        | Always create merge commit | Feature branches |
| `rebase`      | `r`        | Rebase current branch | Clean history |
| `interactive` | `ri` `rs` | Interactive rebase with autosquash | Commit cleanup |

### `gitb branch <mode>`

| **Mode**  | **Short**  | **Description** | **Use Case** |
|-----------|------------|-----------------|--------------|
| `<empty>` |            | Interactive branch selection | Switch branches |
| `list`    | `l`        | Show local branches | Branch overview |
| `remote`  | `re` `r`  | Switch to remote branch | Work on others' branches |
| `main`    | `def` `m` | Quick switch to main | Back to main branch |
| `new`     | `n` `c`   | Create branch from current | Feature from current state |
| `newd`    | `nd`       | Create branch from updated main | New feature branch |
| `delete`  | `del` `d` | Delete local branch | Cleanup merged branches |

### `gitb tag <mode>`

| **Mode**     | **Short**       | **Description** | **Perfect For** |
|--------------|-----------------|---------------------------------------------------------|-----------------|
| `<empty>`    |                 | Create new tag from last commit | Quick releases |
| `annotated`  | `a` `an`       | Create annotated tag with message | Official releases |
| `commit`     | `c` `co` `cm` | Create tag from selected commit | Retrospective tagging |
| `all`        | `al`            | Create annotated tag from selected commit | Complex releases |
| `push`       | `ps` `ph` `p` | Push local tag to remote | Deploy releases |
| `push-all`   | `pa`            | Push all tags to remote | Sync all releases |
| `delete`     | `del` `d`      | Delete local tag | Fix tag mistakes |
| `delete-all` | `da`            | Delete all local tags | Clean slate |
| `list`       | `log` `l`      | Show local tags | Review releases |
| `remote`     | `fetch` `r`    | Fetch and show remote tags | Check remote releases |

### `gitb merge <mode>`

| **Mode**  | **Short** | **Description** | **When to Use** |
|-----------|-----------|-----------------------------------------------------------------|--------------|
| `<empty>` |           | Select branch to merge with conflict resolution | Feature integration |
| `main`    | `m`       | Merge main into current branch | Update feature branch |
| `to-main` | `tm`      | Switch to main and merge current branch | Complete feature |

### `gitb rebase <mode>`

| **Mode**      | **Short**           | **Description** | **Best For** |
|---------------|---------------------|-------------------------------------------------------------------------------|--------------|
| `<empty>`     |                     | Select base branch for rebase | Branch updates |
| `main`        | `m`                 | Rebase current branch onto main | Linear history |
| `interactive` | `i`                 | Interactive rebase from selected commit | History editing |
| `autosquash`  | `a` `s` `f` `ia` | Interactive rebase with fixup commits | Clean commit history |

### `gitb reset <mode>`

| **Mode**      | **Short** | **Description** | **Use Case** |
|---------------|-----------|-------------------------------------------------------------------------|--------------|
| `<empty>`     |           | Reset last commit (mixed mode) | Undo last commit, keep changes |
| `soft`        | `s`       | Soft reset last commit | Redo commit message |
| `undo`        | `u`       | Undo last reset operation | Recover from mistake |
| `interactive` | `i`       | Select commit to reset to | Go back multiple commits |
| `ref`         | `r`       | Reset to selected HEAD reference | Use reflog recovery |

### `gitb stash <mode>`

| **Mode**     | **Short** | **Description** | **Perfect For** |
|--------------|-----------|-----------------|-----------------|
| `<empty>`    |           | Interactive stash menu | Explore all options |
| `select`     | `sel`     | Stash specific files | Partial work saving |
| `all`        |           | Stash everything including untracked | Complete state save |
| `list`       | `l`       | View all stashes | Find specific stash |
| `pop`        | `p`       | Apply and remove stash | Continue work |
| `show`       | `s`       | Preview stash contents | Check before apply |
| `apply`      | `a`       | Apply without removing | Keep stash backup |
| `drop`       | `d`       | Delete stash | Cleanup unused stashes |

### `gitb hook <mode>`

| **Mode**     | **Short**       | **Description** | **Use Case** |
|--------------|-----------------|-----------------|--------------|
| `<empty>`    |                 | Interactive action menu | Explore all operations |
| `list`       | `l`             | Show all hooks with status | Audit current setup |
| `create`     | `new` `c`       | Create new hook with templates | Set up automation |
| `edit`       | `e`             | Edit existing hook | Modify behavior |
| `toggle`     | `t`             | Enable/disable hook | Temporary control |
| `remove`     | `rm` `r`        | Delete hook(s) | Cleanup |
| `test`       | `run` `check`   | Test hook execution | Verify functionality |
| `show`       | `cat` `view` `s`| Display hook contents | Review implementation |

### `gitb config <mode>`

| **Mode**    | **Short**               | **Description** | **Example** |
|-------------|-------------------------|-------------------------------------------------------------|-------------|
| `<empty>`   |                         | Show current gitbasher configuration | Check setup |
| `user`      | `u` `name` `email`    | Set user name and email | Initial setup |
| `default`   | `def` `d` `b` `main` | Set default branch name | Project standards |
| `separator` | `sep` `s`              | Set branch name separator | Naming conventions |
| `editor`    | `ed` `e`               | Set commit message editor | Personal preference |
| `ticket`    | `ti` `t` `jira`       | Set ticket prefix for commits/branches | Issue tracking |
| `scopes`    | `sc` `s`               | Set common scopes for commits | Project structure |
| `ai`        | `llm` `key`            | Configure AI API key | Smart commits |
| `proxy`     | `prx` `p`              | Set HTTP proxy for AI requests | Geographic restrictions |
| `delete`    | `unset` `del`          | Remove global configuration | Reset settings |

### `gitb log <mode>`

| **Mode**      | **Short**     | **Description** | **Great For** |
|---------------|---------------|-----------------------------------------------------------------------|--------------|
| `<empty>`     |               | Pretty git log for current branch | Review recent work |
| `branch`      | `b`           | Select branch to view log | Compare branches |
| `compare`     | `comp` `c`    | Compare logs between two branches | Merge preparation |
| `search`      | `s`           | Search commits with various criteria | Find specific changes |

#### Log Search Options

| **Search Mode** | **Short** | **Description** | **Example Use** |
|-----------------|-----------|-----------------------------------------------------------------------|--------------|
| `message`       | `msg` `m` | Search by commit message | Find feature commits |
| `author`        | `a`       | Search by author name/email | Team member contributions |
| `file`          | `f`       | Search commits affecting specific files | File history |
| `content`       | `pickaxe` `p` | Search by added/removed content | Code archaeology |
| `date`          | `d`       | Search within date range | Release timeframes |
| `hash`          | `commit` `h` | Search by commit hash pattern | Specific commit lookup |


## Troubleshooting & FAQ

### 📋 Common Issues & Solutions

#### ❓ "Command not found: gitb"
```bash
# Check if gitb is installed
which gitb

# If not found, reinstall
GITB_PATH=/usr/local/bin/gitb && \
curl -SL https://raw.githubusercontent.com/maxbolgarin/gitbasher/main/dist/gitb -o $GITB_PATH && \
chmod +x $GITB_PATH

# Alternative: Install to user directory
mkdir -p ~/.local/bin
GITB_PATH=~/.local/bin/gitb && \
curl -SL https://raw.githubusercontent.com/maxbolgarin/gitbasher/main/dist/gitb -o $GITB_PATH && \
chmod +x $GITB_PATH
# Add to PATH: echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

#### ❓ "Permission denied" when installing
```bash
# Use sudo for system-wide installation
sudo curl -SL https://raw.githubusercontent.com/maxbolgarin/gitbasher/main/dist/gitb -o /usr/local/bin/gitb
sudo chmod +x /usr/local/bin/gitb

# Or install to user directory (no sudo needed)
mkdir -p ~/.local/bin
curl -SL https://raw.githubusercontent.com/maxbolgarin/gitbasher/main/dist/gitb -o ~/.local/bin/gitb
chmod +x ~/.local/bin/gitb
```

#### ❓ AI features not working
```bash
# Check if API key is configured
gitb cfg

# Set up API key
gitb cfg ai

# Test with a simple commit
echo "test" >> test.txt
git add test.txt
gitb c ai

# If in restricted region, set up proxy
gitb cfg proxy
# Example: http://proxy.example.com:8080
```

#### ❓ "Bad substitution" or bash errors
```bash
# Check bash version (needs 4.0+)
bash --version

# On macOS, install newer bash
brew install bash

# On Ubuntu/Debian
sudo apt update && sudo apt install --only-upgrade bash
```

#### ❓ Git operations fail
```bash
# Check git version (needs 2.23+)
git --version

# Update git
# macOS: brew install git
# Ubuntu: sudo apt install git
# Or download from: https://git-scm.com/downloads
```

### 🔧 System Requirements

| **System** | **Bash** | **Git** | **Installation Method** |
|------------|----------|---------|------------------------|
| **Linux** | 4.0+ | 2.23+ | `apt install bash git` |
| **macOS** | 4.0+ | 2.23+ | `brew install bash git` |
| **Windows** | WSL | WSL | `wsl --install` then Linux steps |

### 💡 Pro Tips

#### 🎯 **Workflow Optimization**
```bash
# Set up aliases for even faster usage
echo 'alias gc="gitb c"' >> ~/.bashrc
echo 'alias gp="gitb p"' >> ~/.bashrc
echo 'alias gpu="gitb pu"' >> ~/.bashrc
echo 'alias gb="gitb b"' >> ~/.bashrc
```

### 🆘 **Still Having Issues?**

**Ask for help**: [Open an issue](https://github.com/maxbolgarin/gitbasher/issues) or contact [@maxbolgarin](https://t.me/maxbolgarin)

### 🗑️ **Uninstall**

```bash
# Remove gitbasher
sudo rm /usr/local/bin/gitb
# or
rm ~/.local/bin/gitb

# Remove configuration (optional)
rm -rf ~/.gitbasher
```


## Roadmap for v4

1. Add support of multi modes, e.g. `gitb c fastp` -> `gitb c fast push` to prevent from a lot of modes to support all combinations
2. Add more interactive menus, because it is difficult to remember all commands and modes
3. Add better error messages and settings for verbosity
4. Add more AI APIs providers

## Contributing

If you'd like to contribute to **gitbasher**, make a fork and submit a pull request. You also can open an issue or text me on Telegram: https://t.me/maxbolgarin

#### Maintainers

* [maxbolgarin](https://github.com/maxbolgarin)

#### License

The source code license is MIT, as described in the [LICENSE](./LICENSE) file.
