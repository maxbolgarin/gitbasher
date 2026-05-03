# gitbasher — make `git` fast, friendly, and forgettable

[![Latest Release](https://img.shields.io/github/v/release/maxbolgarin/gitbasher.svg?style=flat-square)](https://github.com/maxbolgarin/gitbasher/releases/latest)
[![GitHub license](https://img.shields.io/github/license/maxbolgarin/gitbasher.svg)](https://github.com/maxbolgarin/gitbasher/blob/master/LICENSE)
[![Build Status](https://github.com/maxbolgarin/gitbasher/actions/workflows/build.yml/badge.svg)](https://github.com/maxbolgarin/gitbasher/actions)

<picture>
    <img src=".github/commit.gif" width="600" alt="commit example">
</picture>

**gitbasher** is a single-binary `bash` wrapper that turns the most common git operations into one short, interactive command. Stop memorizing flags. Stop pasting the same five commands in a row. Just type `gitb`.

```bash
gitb commit push       # stage, write a conventional commit, push — in one flow
gitb c ai              # AI-generated commit message
gitb sync              # fetch main + rebase your branch
gitb wip up            # stash WIP, push backup branch, clean working tree
gitb undo              # roll back your last commit / amend / merge / rebase / stash
```

---

## Install in 10 seconds

**One-liner (no Node required):**
```bash
curl -fsSL https://raw.githubusercontent.com/maxbolgarin/gitbasher/main/install.sh | bash
```

By default the installer drops `gitb` into `~/.local/bin` — no `sudo`, no password prompt. It downloads the latest release and prints a PATH hint if needed. Opt into a system-wide install or override the location:

```bash
curl -fsSL https://raw.githubusercontent.com/maxbolgarin/gitbasher/main/install.sh | bash -s -- --sudo   # /usr/local/bin (sudo)
GITB_DIR=/opt/bin       curl ... | bash    # custom location
GITB_VERSION=v3.10.2    curl ... | bash    # pin a release
```

**npm:**
```bash
npm install -g gitbasher
```

> Windows users: run inside [WSL](https://learn.microsoft.com/en-us/windows/wsl/setup/environment).
> Prefer to inspect first? `curl -fsSL https://raw.githubusercontent.com/maxbolgarin/gitbasher/main/install.sh -o install.sh && less install.sh && bash install.sh`

**Requirements:** `bash` 4.0+, `git` 2.23+ (macOS: `brew install bash git`).

**Uninstall:**
```bash
npm uninstall -g gitbasher          # if installed via npm
rm -f ~/.local/bin/gitb             # if installed via curl (default location)
sudo rm -f /usr/local/bin/gitb      # if installed via curl with --sudo
```

Per-repo gitbasher settings live in `git config` under the `gitbasher.*` namespace and are removed with the repo. To clear global settings (AI key, default branch, scopes, etc.):
```bash
git config --global --remove-section gitbasher 2>/dev/null
git config --global --unset core.editor 2>/dev/null   # only if you set it via gitb cfg editor
```

---

## 60-second quick start

```bash
cd your-project
gitb              # see all commands
gitb cfg user     # set your name/email once
gitb cfg ai       # (optional) plug in an AI key for smart commits

gitb status       # what's changed?
gitb commit       # interactive conventional commit
gitb push         # safe push with conflict handling
gitb pull         # smart pull (rebase / merge / ff)
gitb branch new   # create a new conventionally-named branch
```

Every command has a short alias (`gitb c`, `gitb p`, `gitb pu`, `gitb b`, `gitb st`, …) and a `help` mode (`gitb commit help`).

---

## Table of contents
- [Why gitbasher](#why-gitbasher)
- [All features at a glance](#all-features-at-a-glance)
- [AI-powered commits](#ai-powered-commits)
- [Common workflows](#common-workflows)
- [Command reference](#command-reference)
  - [commit](#gitb-commit) · [push](#gitb-push) · [pull](#gitb-pull) · [branch](#gitb-branch) · [tag](#gitb-tag) · [merge](#gitb-merge) · [rebase](#gitb-rebase)
  - [cherry](#gitb-cherry) · [sync](#gitb-sync) · [wip](#gitb-wip) · [undo](#gitb-undo) · [reset](#gitb-reset) · [stash](#gitb-stash)
  - [worktree](#gitb-worktree) · [hook](#gitb-hook) · [config](#gitb-config) · [log](#gitb-log) · [info commands](#info-commands)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

---

## Why gitbasher

- **Zero memorization** — no flags to remember, no man pages to grep. Interactive menus where it matters, short aliases where it doesn't.
- **Conventional commits, free** — type/scope/summary picker built-in, with optional ticket prefixes and multiline editor mode.
- **AI commit messages** — `gitb c ai` writes the message for you. Pick your provider: OpenRouter (Gemini / Claude / many), OpenAI direct (GPT-5.4 nano/mini), or **fully local via Ollama** — no key, no network, no data leaves your machine.
- **Atomic split** — `gitb c split` (or `aisplit`) breaks a messy working tree into one commit per logical scope.
- **Safer git** — push/pull detect conflicts up front, `undo` rolls back commit/amend/merge/rebase/stash, `reset` is interactive.
- **Whole workflows, not just commands** — `sync`, `wip`, `branch newd`, `merge to-main` chain the steps you'd otherwise do by hand.
- **One file, no deps** — pure bash. Drop the binary anywhere on `PATH` and go.
- **115+ tests** — BATS test suite covers sanitization, git ops, branch logic.

<picture>
    <img src=".github/push.gif" width="600" alt="push example">
</picture>

---

## All features at a glance

| Group | Commands | What you get |
|-------|----------|--------------|
| **Commit** | `commit` (`c`) | Interactive conventional commits, fast-mode, AI messages, atomic split, fixup, amend, last-message edit, revert |
| **Sync remote** | `push` (`p`), `pull` (`pu`), `sync` (`sy`) | Safe push (with force/list), smart pull (rebase / merge / ff), one-shot rebase-on-main with optional force-push |
| **Branches** | `branch` (`b`), `prev` (`-`) | List / switch / create-from-current / create-from-updated-main / delete (orphaned, merged, gone) / recent / previous / checkout-tag |
| **Integration** | `merge` (`m`), `rebase` (`r`), `cherry` (`ch`) | Merge into current / into main / from remote · rebase onto main / interactive / autosquash / fastautosquash / pull-commits · cherry-pick by hash, range, or interactive |
| **Tags & releases** | `tag` (`t`) | Lightweight, annotated, from-commit, push, push-all, delete, delete-all, list, fetch-remote |
| **Save & rollback** | `wip` (`up`/`down`), `undo` (`un`), `reset` (`res`), `stash` (`s`) | Save WIP via stash / branch / worktree (auto-detected on restore) · undo last commit/amend/merge/rebase/stash · interactive reset · full stash menu |
| **Worktrees** | `worktree` (`wt`) | Add / list / remove / move / lock / prune git worktrees, with new branch from current/main or from existing/remote branches |
| **Inspect** | `status` (`st`), `log` (`l`), `reflog` (`rl`), `last-commit` (`lc`), `last-ref` (`lr`) | Pretty repo status, multi-mode log + search, reflog viewer, quick last-commit / last-ref summary |
| **Hooks** | `hook` (`ho`) | List / create from templates / edit / toggle / remove / test / show — for every git hook |
| **Repo setup** | `init` (`i`), `origin` (`or`, `o`, `remote`) | `git init` from gitbasher · add/change/rename/remove the remote origin |
| **Config** | `config` (`cfg`) | User, default branch, separator, editor, ticket prefix, scopes, AI provider/key/model, proxy |

Total: **23 top-level commands**, **60+ aliases**, **100+ modes**.

---

## AI-powered commits

Drop in an API key once (or run a local model with no key at all), then let an LLM write conventional commit messages from your diff.

### Providers

gitbasher supports three providers behind the same OpenAI-style chat-completions API. Default is `openrouter` — existing setups keep working unchanged.

| Provider | Best for | Needs key? |
|----------|----------|-----------|
| `openrouter` (default) | Trying many models behind one key (Gemini, Claude, GPT, DeepSeek…) | Yes — [openrouter.ai/keys](https://openrouter.ai/keys) |
| `openai` | Direct access to GPT-5.4 family at OpenAI's own pricing | Yes — [platform.openai.com/api-keys](https://platform.openai.com/api-keys) |
| `ollama` | **Fully local, fully private** — no key, no network, runs on your machine | No |

### Setup

```bash
# 1. Pick a provider (skip to use the OpenRouter default)
gitb cfg provider     # interactive — choose openrouter, openai, or ollama

# 2. For openrouter / openai: paste your key (local repo or global)
gitb cfg ai

#    For ollama: just make sure the daemon is running and the default model is pulled
ollama serve &
ollama pull qwen3:8b

# 3. Optional: HTTP proxy (for restricted regions, openrouter/openai only)
gitb cfg proxy
```

For the security-conscious, prefer the env var to avoid the key landing in `~/.gitconfig`:
```bash
export GITB_AI_API_KEY='sk-...'
```

### Custom OpenAI-compatible endpoints

Self-hosted gateways (LiteLLM, vLLM, LM Studio) and remote Ollama hosts work via a base-URL override:
```bash
gitb cfg provider                                                  # pick openai or ollama as the closest match
git config gitbasher.ai-base-url http://my-gateway:4000/v1/chat/completions
```

### Commands

| Goal | Command | What it does |
|------|---------|--------------|
| Staged files ready | `gitb c ai` | AI message from staged diff |
| Quick fix | `gitb c aif` | `git add .` + AI message |
| Ship now | `gitb c aip` | AI message + push |
| Full workflow | `gitb c aifp` | `add .` + AI + push |
| Manual type/scope | `gitb c ais` | You pick type/scope, AI writes summary |
| Detailed message | `gitb c aim` | Multiline subject + body |
| Atomic split (AI) | `gitb c aisplit` | AI groups your diff into one commit per scope, writes each message |
| Hands-free | `gitb c ff` / `ffp` | `add .` + AI-grouped split + AI messages, no prompts |

Modes are composable: `gitb c ai fast push` is identical to `gitb c aifp`.

### Models

Each task uses a model tuned for speed/cost/quality, picked per provider. Defaults (May 2026):

**OpenRouter** (default provider)

| Task | Default model | Why |
|------|---------------|-----|
| `simple` (one-line message) | `google/gemini-3.1-flash-lite-preview` | Cheapest fast tier |
| `subject` (after manual type/scope) | `google/gemini-3.1-flash-lite-preview` | Short structured output |
| `full` (header + body) | `google/gemini-3-flash-preview` | Better prose |
| `grouping` (atomic-split mapping) | `anthropic/claude-haiku-4.5` | Strict instruction following |

**OpenAI** — GPT-5.4 family (released March 2026)

| Task | Default model | Why |
|------|---------------|-----|
| `simple` / `subject` | `gpt-5.4-nano` | Built for classification/short well-defined output, ~$0.20 / $1.25 per M tokens |
| `full` | `gpt-5.4-mini` | Stronger multi-condition instruction following for header + body, ~$0.75 / $4.50 per M |
| `grouping` | `gpt-5.4-mini` | Holds the strict TSV format under validation, far cheaper than the flagship |

**Ollama** — fully local

| Task | Default model | Why |
|------|---------------|-----|
| All tasks | `qwen3:8b` | Best small instruction-follower among 7/8B models; most stable structured output (rarely drops fields in TSV); ~5 GB on disk, ~25 tok/s on a consumer laptop with GPU |

Other strong local picks: `llama3.3:8b` (general-purpose), `qwen2.5-coder:7b` (code-heavy diffs).

Override per task or globally:
```bash
gitb cfg model                                          # interactive
git config gitbasher.ai-model            <model_id>     # global
git config gitbasher.ai-model-simple     <model_id>     # per-task
git config gitbasher.ai-model-subject    <model_id>
git config gitbasher.ai-model-full       <model_id>
git config gitbasher.ai-model-grouping   <model_id>
```

---

## Common workflows

### Daily development
```bash
gitb st              # status
gitb pu              # pull
gitb b n             # new feature branch
# ... code ...
gitb c ai            # AI commit
gitb p               # push
```

### Start a new feature
```bash
gitb b nd            # branch newd: switch to main, pull, branch off
# ... code ...
gitb c push          # commit + push
```

### Code-review cycle
```bash
gitb c fix           # fixup commit for review feedback
gitb r a             # autosquash fixups
gitb p f             # force-push cleaned history
```

### Sync with main mid-feature
```bash
gitb sync            # fetch main + rebase your branch
gitb sync push       # …and force-push
gitb sync merge      # use merge instead of rebase
```

### Save WIP across machines / branches
```bash
gitb wip up          # stash changes + push backup to origin/wip/<branch>
# … on another machine …
gitb pull            # fetch the wip/<branch>
gitb wip down        # pop the wip stash and remove the remote backup
```

### Hotfix
```bash
gitb b m             # switch to main
gitb pu              # latest changes
gitb b n             # hotfix branch
gitb c aifp          # fast AI commit + push
gitb m tm            # merge to main
```

### Release
```bash
gitb b m
gitb pu
gitb l               # review log
gitb t a             # annotated tag
gitb t p             # push tag
```

### Roll back a mistake
```bash
gitb undo            # undo last commit (keeps changes staged)
gitb undo amend      # restore pre-amend state via reflog
gitb undo merge      # abort or undo last merge
gitb undo rebase     # abort or undo last rebase
gitb undo stash      # re-stash a popped stash
```

### Branch hygiene
```bash
gitb b rc            # pick from recently used branches
gitb b g             # delete local branches whose remote is gone
gitb b del           # interactive delete (orphaned / merged / pick)
gitb b -             # back to previous branch (like cd -)
```

---

## Command reference

> **Tip:** every command accepts `help` (`h`) for inline help: `gitb commit help`, `gitb sync h`.

### Top-level commands

| Command | Aliases | Description |
|---------|---------|-------------|
| [`commit`](#gitb-commit) | `c` `co` `com` | Create commits (interactive, fast, AI, split, fixup, amend, revert, …) |
| [`push`](#gitb-push) | `p` `ps` `pus` | Push with conflict handling, force, or list-only |
| [`pull`](#gitb-pull) | `pu` `pl` `pul` | Smart pull: rebase / merge / ff / fetch-only / interactive |
| [`branch`](#gitb-branch) | `b` `br` `bran` | Switch / list / create / delete / recent / gone / checkout-tag |
| [`tag`](#gitb-tag) | `t` `tg` | Create, push, list, delete tags (lightweight & annotated) |
| [`merge`](#gitb-merge) | `m` `me` | Merge into current, into main, or from remote |
| [`rebase`](#gitb-rebase) | `r` `re` `base` | Rebase onto main / interactive / autosquash / pull-commits |
| [`cherry`](#gitb-cherry) | `ch` `cp` | Cherry-pick by hash, range, or interactive picker |
| [`sync`](#gitb-sync) | `sy` | Fetch main + rebase (or merge) current branch, optional push |
| [`wip`](#gitb-wip) | `w` | Stash all + backup to remote (`up`) / restore (`down`) |
| [`undo`](#gitb-undo) | `un` | Undo last commit / amend / merge / rebase / stash |
| [`reset`](#gitb-reset) | `res` | Friendly `git reset` with preview, approval, and undo support |
| [`stash`](#gitb-stash) | `s` `sta` | Full stash menu: select, all, list, pop, apply, show, drop |
| [`worktree`](#gitb-worktree) | `wt` `tree` | Manage git worktrees: add, list, remove, move, lock, prune |
| [`hook`](#gitb-hook) | `ho` `hk` | Manage git hooks: list, create, edit, toggle, remove, test, show |
| [`origin`](#gitb-origin) | `or` `o` `remote` | Add, change, rename, or remove the remote origin |
| [`init`](#gitb-init) | `i` | `git init` + optional origin setup prompt |
| [`config`](#gitb-config) | `cf` `cfg` `conf` | Configure user, branch, AI, scopes, ticket prefix, etc. |
| [`log`](#gitb-log) | `l` `lg` | Pretty log: current, branch, compare, search |
| [`status`](#info-commands) | `st` | Repo status and changed files |
| [`reflog`](#info-commands) | `rl` `rlg` | Pretty reflog |
| [`last-commit`](#info-commands) | `lc` `lastc` | Show the last commit |
| [`last-ref`](#info-commands) | `lr` `lastr` | Show the last reference |
| [`prev`](#gitb-branch) | `-` | Switch to previous branch (`cd -`) |

---

### `gitb commit`

> **Multi-word modes.** Modifiers can be written as separate words in any order — `gitb commit ai fast push`, `gitb c ai f p`, and `gitb c aifp` are all equivalent. Modifier words: `ai`/`llm`/`i`, `fast`/`f`, `push`/`pu`/`p`, `scope`/`s`, `msg`/`m`, `staged`, `fixup`/`fix`/`x`, `amend`/`am`/`a`, `split`/`sp`/`sl`, `ticket`/`jira`/`j`/`t`, `last`/`l`, `revert`/`rev`. The `ff`/`ffp` ultrafast modes remain compact-only.

| Mode | Aliases | Description |
|------|---------|-------------|
| `<empty>` | | Select files, build conventional message |
| `msg` | `m` | Multiline message in `$EDITOR` |
| `ticket` | `t` `jira` `j` | Prepend tracker ticket to header |
| `fast` | `f` | `git add .` + commit without scope |
| `fasts` | `fs` | `git add .` + commit with scope |
| `push` | `p` `pu` | Commit + push |
| `fastp` | `fp` | Fast commit + push |
| `fastsp` | `fsp` `fps` | Fast commit with scope + push |
| `split` | `sp` `sl` | One commit per detected scope (heuristic, manual messages) |
| `splitp` | `spp` `slp` | `split` + push |
| `aisplit` | `isplit` `aispl` `ispl` | AI refines grouping and writes each message |
| `aisplitp` | `isplitp` `aisplp` `islp` | `aisplit` + push |
| `ff` | | Ultrafast: add all, AI-grouped split, AI messages, no prompts |
| `ffp` | `ffpush` | `ff` + push |
| `ai` | `llm` `i` | AI-generated commit message |
| `aif` | `llmf` `if` | Fast AI commit, no confirmation |
| `aip` | `llmp` `ip` | AI commit + push |
| `aifp` | `llmfp` `ifp` | Fast AI commit + push |
| `ais` | `llms` `is` | AI summary, manual type/scope |
| `aim` | `llmm` `im` | AI multiline message |
| `fixup` | `fix` `x` | Fixup commit (for autosquash) |
| `fixupp` | `fixp` `xp` | Fixup commit + push |
| `fastfix` | `fx` | Fast fixup (all files) |
| `fastfixp` | `fxp` | Fast fixup + push |
| `amend` | `am` `a` | Amend selected files into last commit |
| `amendf` | `amf` `af` | Amend all files |
| `last` | `l` | Edit last commit's message |
| `revert` | `rev` | Revert a selected commit |

### `gitb push`

| Mode | Aliases | Description |
|------|---------|-------------|
| `<empty>` | | Show commits, push with conflict handling |
| `yes` | `y` | Push without confirmation |
| `force` | `f` | Force push (use after rebase/amend) |
| `list` | `log` `l` | List unpushed commits only |

### `gitb pull`

| Mode | Aliases | Description |
|------|---------|-------------|
| `<empty>` | | Smart pull (strategy picker) |
| `fetch` | `fe` | Fetch only |
| `all` | `fa` | Fetch all branches |
| `upd` | `u` | Update remote refs / prune |
| `ffonly` | `ff` | Fast-forward only |
| `merge` | `m` | Always create merge commit |
| `rebase` | `r` | Rebase current onto remote |
| `interactive` | `ri` `rs` | Interactive rebase + autosquash |

### `gitb branch`

| Mode | Aliases | Description |
|------|---------|-------------|
| `<empty>` | | Pick a local branch to switch |
| `list` | `l` | List local branches |
| `remote` | `re` `r` | Fetch and switch to a remote branch |
| `main` | `def` `m` | Quick-switch to default branch |
| `tag` | `t` | Checkout to a specific tag |
| `new` | `n` `c` | Create branch from current |
| `newd` | `nd` `cd` | Switch to main, pull, branch off |
| `delete` | `del` `d` | Delete branches (orphaned, merged, or selected) |
| `prev` | `p` `-` | Switch to previous branch (`cd -`) |
| `recent` | `rc` | Pick from recently checked-out branches |
| `gone` | `g` | Delete locals whose remote tracking branch is gone |

### `gitb tag`

| Mode | Aliases | Description |
|------|---------|-------------|
| `<empty>` | | Lightweight tag from `HEAD` |
| `annotated` | `a` `an` | Annotated tag with message |
| `commit` | `c` `co` `cm` | Tag from a selected commit |
| `all` | `al` | Annotated tag from selected commit |
| `push` | `p` `ps` `ph` | Push a tag |
| `push-all` | `pa` | Push all tags |
| `delete` | `del` `d` | Delete a local tag |
| `delete-all` | `da` | Delete all local tags |
| `list` | `log` `l` | List local tags |
| `remote` | `fetch` `r` | Fetch and list remote tags |

### `gitb merge`

| Mode | Aliases | Description |
|------|---------|-------------|
| `<empty>` | | Pick a branch to merge into current |
| `main` | `master` `m` | Merge default branch into current |
| `to-main` | `to-master` `tm` | Switch to main, merge current branch in |
| `remote` | `r` | Fetch + select a remote branch to merge |

### `gitb rebase`

| Mode | Aliases | Description |
|------|---------|-------------|
| `<empty>` | | Pick a base branch |
| `main` | `master` `m` | Rebase current onto default |
| `interactive` | `i` | Interactive rebase from picked commit |
| `autosquash` | `a` `s` `ia` | Interactive rebase with `--autosquash` |
| `fastautosquash` | `fast` `sf` `f` | Autosquash without interaction |
| `pull` | `p` | Take commits from selected branch into current |

### `gitb cherry`

| Mode | Aliases | Description |
|------|---------|-------------|
| `<empty>` | | Pick commits from a branch interactively |
| `<commit-hash>` | | Shorthand for cherry-pick by hash |
| `hash` | `hs` | Cherry-pick a specific hash |
| `range` | `r` | Cherry-pick a range (`A..B`) |
| `abort` | `a` | Abort current cherry-pick |
| `continue` | `cont` `c` | Continue after resolving conflicts |

### `gitb sync`

Fetch the default branch and update your current branch. Useful mid-feature.

| Mode | Aliases | Description |
|------|---------|-------------|
| `<empty>` | | Fetch main + rebase current onto it |
| `push` | `p` | …then force-push |
| `merge` | `m` | Use merge instead of rebase |
| `mergep` | `mp` `pm` | Merge + push |

### `gitb wip`

Save work-in-progress through one of three backends and restore it later. Pick
the one that fits the situation — `wip up` prompts when the backend isn't
specified, and `wip down` auto-detects which backend was used.

| Backend | What it does | When to use |
|---------|--------------|-------------|
| `stash` | `git stash --include-untracked` + force-push `wip/<branch>` to remote as backup | Quick context switch, default |
| `branch` | Commits all changes onto a `wip/<branch>` branch, leaves current branch clean, optionally pushes | Want history / share work / open a draft PR |
| `worktree` | Same as branch, but the WIP lives in a sibling worktree so you can keep working on it side-by-side | Long-running parallel work |

| Command | Aliases | Description |
|---------|---------|-------------|
| `gitb wip up` | `u` | Save WIP — prompts which backend to use |
| `gitb wip up stash` | `u s` | Stash + push backup branch |
| `gitb wip up branch` | `u b` | Commit onto `wip/<branch>` + push |
| `gitb wip up worktree` | `u w` `u wt` | Move WIP into a sibling worktree |
| `gitb wip up <mode> nopush` | `np` `n` | Skip the push step (works with any backend) |
| `gitb wip up nopush` | `u np` `u n` | Legacy: stash + no push (same as `up stash nopush`) |
| `gitb wip down` | `d` | Restore — auto-detects backend, prompts if ambiguous |
| `gitb wip down stash` | `d s` | Restore from the stash |
| `gitb wip down branch` | `d b` | Restore from `wip/<branch>` (squash-merge into working tree) |
| `gitb wip down worktree` | `d w` `d wt` | Restore from the wip worktree, then remove it |

For `branch` and `worktree`, `wip down` brings everything (committed + uncommitted) back as plain modifications and deletes the wip branch / worktree (and remote `wip/<branch>` if present).

### `gitb undo`

| Mode | Aliases | Description |
|------|---------|-------------|
| `<empty>` / `commit` | `c` | Undo last commit (`reset --soft HEAD~1`) — keeps changes staged |
| `amend` | `a` | Restore pre-amend state via reflog |
| `merge` | `m` | Abort or undo last merge |
| `rebase` | `r` | Abort or undo last rebase (`ORIG_HEAD`) |
| `stash` | `s` | Re-stash a popped/applied stash |

### `gitb reset`

| Mode | Aliases | Description |
|------|---------|-------------|
| `<empty>` | | Preview and reset last commit (mixed) |
| `soft` | `s` | Preview and soft reset last commit |
| `undo` | `u` | Preview and undo last reset |
| `interactive` | `i` | Pick commit to reset to, then approve |
| `ref` | `r` | Reset to a `HEAD` reference with approval (reflog recovery) |

### `gitb stash`

| Mode | Aliases | Description |
|------|---------|-------------|
| `<empty>` | | Interactive stash menu |
| `select` | `sel` | Stash specific files |
| `all` | | Stash everything including untracked |
| `list` | `l` | List all stashes |
| `pop` | `p` | Apply and remove |
| `show` | `s` | Preview stash |
| `apply` | `a` | Apply without removing |
| `drop` | `d` | Delete stash |

### `gitb worktree`

Run multiple branches in parallel without stashing or switching: each worktree
is a real working directory linked to the same `.git`. Great for hotfixes,
long-running reviews, or comparing branches side-by-side.

| Mode | Aliases | Description |
|------|---------|-------------|
| `<empty>` | | Show existing worktrees + interactive menu |
| `list` | `l` `ls` | List all worktrees with branch and lock state |
| `add` | `a` `new` `n` `c` | Create worktree with a new branch from current `HEAD` |
| `addd` | `ad` `nd` `cd` | Fetch, then create worktree with new branch from default branch |
| `addb` | `ab` `from` `b` | Create worktree from an existing local branch |
| `addr` | `ar` `remote` `r` | Fetch + create worktree tracking a remote branch |
| `remove` | `rm` `del` `d` | Pick a worktree to remove (force-prompt on dirty trees) |
| `move` | `mv` | Move a worktree to a new path |
| `lock` | | Lock a worktree (with optional reason) |
| `unlock` | `ul` | Unlock a worktree |
| `prune` | `pr` `p` | Clean up stale worktree records (dry-run preview first) |
| `path` | `cd` `switch` `sw` | Print the path to a chosen worktree (use with `cd $(...)`) |

```bash
gitb wt add                # new branch + new worktree from current HEAD
gitb wt addd               # new branch + new worktree from updated main
gitb wt addr               # check out a remote branch into a fresh worktree
gitb wt remove             # interactive removal (with force prompt if dirty)
cd "$(gitb wt path)"       # cd into a chosen worktree
```

By default new worktrees are created at `../<repo>-<branch>`. Override the
parent directory globally or per-repo:

```bash
git config --global gitbasher.worktreebase ~/code/worktrees
```

### `gitb hook`

| Mode | Aliases | Description |
|------|---------|-------------|
| `<empty>` | | Interactive action menu |
| `list` | `l` | All hooks with status |
| `create` | `new` `c` | New hook from templates |
| `edit` | `e` | Edit existing hook |
| `toggle` | `t` | Enable/disable hook |
| `remove` | `rm` `r` | Delete hook(s) |
| `test` | `run` `check` | Test hook execution |
| `show` | `cat` `view` `s` | Display hook contents |

### `gitb init`

Initialize a new git repository and (optionally) add a remote origin.

```bash
gitb init             # git init + interactive remote prompt
gitb origin set <url> # add origin without prompts
```

`gitb init` runs `git init` in the current directory. If the repo has no
configured remote, gitbasher offers to add one interactively. Use
[`gitb origin`](#gitb-origin) for non-interactive remote management.

### `gitb origin`

Add, change, rename, or remove the remote origin. Useful when you create a repo
without a remote, rename the repo on GitHub/GitLab, or move it to a new host.

| Mode | Aliases | Description |
|------|---------|-------------|
| `<empty>` | `show` `info` | List configured remotes and their URLs |
| `set` | `add` `new` `a` | Add a new origin (errors if origin already set) |
| `change` | `update` `c` `u` `set-url` | Change the existing origin URL (after rename/move) |
| `rename` | `mv` `ren` | Rename a remote (e.g. `origin` → `upstream`) |
| `remove` | `rm` `del` `d` | Remove the remote |
| `help` | `h` | Show help |

Each mutating mode accepts an optional URL/name as a second argument to skip
the interactive prompt:

```bash
gitb origin                                      # show remotes
gitb origin set git@github.com:me/proj.git       # add origin
gitb origin change https://github.com/me/new.git # update URL after rename
gitb origin rename upstream                      # origin → upstream
gitb origin remove                               # delete the remote
```

### `gitb config`

| Mode | Aliases | Description |
|------|---------|-------------|
| `<empty>` | | Show current configuration |
| `user` | `u` `name` `email` | Set name and email |
| `default` | `def` `d` `b` `main` | Set default branch |
| `separator` | `sep` `s` | Branch-name separator |
| `editor` | `ed` `e` | Commit-message editor |
| `ticket` | `ti` `t` `jira` | Ticket prefix for commits/branches |
| `scopes` | `sc` `s` | Common scopes |
| `ai` | `llm` `key` | AI API key |
| `provider` | `prov` | AI provider (openrouter, openai, ollama) |
| `model` | `m` | Default AI model |
| `proxy` | `prx` `p` | HTTP proxy for AI calls |
| `delete` | `unset` `del` | Remove global config |

### `gitb log`

| Mode | Aliases | Description |
|------|---------|-------------|
| `<empty>` | | Pretty log for current branch |
| `branch` | `b` | Pick a branch to log |
| `compare` | `comp` `c` | Compare two branches |
| `search` | `s` | Search commits |

**Search sub-modes:** `message`/`msg`/`m`, `author`/`a`, `file`/`f`, `content`/`pickaxe`/`p`, `date`/`d`, `hash`/`commit`/`h`.

### Info commands

| Command | Aliases | Description |
|---------|---------|-------------|
| `status` | `st` | Repo info and changed files |
| `reflog` | `rl` `rlg` | Pretty reflog |
| `last-commit` | `lc` `lastc` | Show the last commit |
| `last-ref` | `lr` `lastr` | Show the last reference |

---

## Configuration

`gitb cfg` (no args) prints the active configuration. Settings live in standard `git config`, so they're per-repo by default — use `--global` for everywhere.

| Key | Set via | Purpose |
|-----|---------|---------|
| `user.name` / `user.email` | `gitb cfg user` | Your identity |
| `gitbasher.branch` | `gitb cfg default` | Default branch (`main`, `master`, …) |
| `gitbasher.sep` | `gitb cfg separator` | Branch-name separator (`/`, `-`, …) |
| `gitbasher.editor` | `gitb cfg editor` | Editor for messages |
| `gitbasher.ticket` | `gitb cfg ticket` | Ticket prefix (`PROJ-`) |
| `gitbasher.scopes` | `gitb cfg scopes` | Suggested commit scopes |
| `gitbasher.ai-api-key` | `gitb cfg ai` | AI provider API key (or `GITB_AI_API_KEY` env) |
| `gitbasher.ai-provider` | `gitb cfg provider` | `openrouter` (default), `openai`, or `ollama` |
| `gitbasher.ai-base-url` | `git config` | Custom OpenAI-compatible endpoint (LiteLLM, vLLM, remote Ollama) |
| `gitbasher.ai-model[-task]` | `gitb cfg model` | AI model overrides (per provider) |
| `gitbasher.proxy` | `gitb cfg proxy` | HTTP proxy for AI calls |
| `gitbasher.worktreebase` | `git config gitbasher.worktreebase <dir>` | Parent directory for new worktrees (defaults to `..`) |

**Aliases for shell users:**
```bash
echo 'alias gc="gitb c"'   >> ~/.bashrc
echo 'alias gp="gitb p"'   >> ~/.bashrc
echo 'alias gpu="gitb pu"' >> ~/.bashrc
echo 'alias gb="gitb b"'   >> ~/.bashrc
```

**zsh tip:** if zsh autocorrects `gitb` → `git`, add `alias gitb='nocorrect gitb'` to `~/.zshrc`.

---

## Troubleshooting

<details>
<summary><b>Command not found: gitb</b></summary>

```bash
which gitb                    # check install location
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc   # if installed to ~/.local/bin
```
Reinstall via npm (`npm install -g gitbasher`) or curl (see [install](#install-in-10-seconds)).
</details>

<details>
<summary><b>Permission denied during install</b></summary>

The default install goes to `~/.local/bin` (no sudo). For a system-wide install pass `--sudo`:
```bash
curl -fsSL https://raw.githubusercontent.com/maxbolgarin/gitbasher/main/install.sh | bash -s -- --sudo
```
</details>

<details>
<summary><b>AI features not working</b></summary>

```bash
gitb cfg              # check config
gitb cfg ai           # set API key
gitb cfg proxy        # in restricted regions
```
</details>

<details>
<summary><b>"Bad substitution" or bash errors</b></summary>

`bash --version` must be 4.0+.

- macOS: `brew install bash` (and optionally make it default: `sudo sh -c 'echo /opt/homebrew/bin/bash >> /etc/shells' && chsh -s /opt/homebrew/bin/bash`)
- Ubuntu/Debian: `sudo apt update && sudo apt install --only-upgrade bash`
</details>

<details>
<summary><b>System requirements</b></summary>

| OS | Bash | Git | Install |
|----|------|-----|---------|
| Linux | 4.0+ | 2.23+ | `apt install bash git` |
| macOS | 4.0+ | 2.23+ | `brew install bash git` |
| Windows | WSL | WSL | `wsl --install` then Linux steps |
</details>

<details>
<summary><b>Uninstall</b></summary>

```bash
npm uninstall -g gitbasher           # if installed via npm
sudo rm /usr/local/bin/gitb          # if installed system-wide
rm -f ~/.local/bin/gitb              # if installed per-user
rm -rf ~/.gitbasher                  # remove config (optional)
```
</details>

**Still stuck?** [Open an issue](https://github.com/maxbolgarin/gitbasher/issues) or ping [@maxbolgarin](https://t.me/maxbolgarin) on Telegram.

---

## Contributing

PRs welcome. Workflow:

1. Fork and create a feature branch
2. **Write tests first** (BATS, see [tests/README.md](tests/README.md))
3. Implement
4. `make test` — all tests must pass
5. Open a PR

```bash
make build               # rebuild dist/gitb
make test                # run all 115+ tests
make test-file FILE=test_sanitization.bats
```

**Maintainer:** [@maxbolgarin](https://github.com/maxbolgarin)

**License:** MIT — see [LICENSE](./LICENSE).
