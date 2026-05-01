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
gitb wip               # snapshot WIP, push, keep moving
gitb undo              # roll back your last commit / amend / merge / rebase / stash
```

---

## Install in 10 seconds

**npm (easiest):**
```bash
npm install -g gitbasher
```

**Standalone binary (no Node required):**
```bash
GITB_PATH=/usr/local/bin/gitb && \
sudo mkdir -p $(dirname $GITB_PATH) && \
curl -fSL https://github.com/maxbolgarin/gitbasher/releases/latest/download/gitb | sudo tee $GITB_PATH > /dev/null && \
sudo chmod +x $GITB_PATH
```

> Windows users: run inside [WSL](https://learn.microsoft.com/en-us/windows/wsl/setup/environment).
> No `sudo`? Install to `~/.local/bin` and add it to `PATH`.

**Requirements:** `bash` 4.0+, `git` 2.23+ (macOS: `brew install bash git`).

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
  - [cherry](#gitb-cherry) · [sync](#gitb-sync) · [wip / unwip](#gitb-wip--unwip) · [fixup](#gitb-fixup) · [undo](#gitb-undo) · [reset](#gitb-reset) · [stash](#gitb-stash)
  - [hook](#gitb-hook) · [config](#gitb-config) · [log](#gitb-log) · [info commands](#info-commands)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

---

## Why gitbasher

- **Zero memorization** — no flags to remember, no man pages to grep. Interactive menus where it matters, short aliases where it doesn't.
- **Conventional commits, free** — type/scope/summary picker built-in, with optional ticket prefixes and multiline editor mode.
- **AI commit messages** — `gitb c ai` writes the message for you (Gemini / Claude via OpenRouter, fully configurable).
- **Atomic split** — `gitb c split` (or `aisplit`) breaks a messy working tree into one commit per logical scope.
- **Safer git** — push/pull detect conflicts up front, `undo` rolls back commit/amend/merge/rebase/stash, `reset` is interactive.
- **Whole workflows, not just commands** — `sync`, `wip`, `fixup`, `branch newd`, `merge to-main` chain the steps you'd otherwise do by hand.
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
| **Save & rollback** | `wip` / `unwip`, `undo` (`un`), `reset` (`res`), `stash` (`s`), `fixup` (`fx`) | One-command WIP snapshot/restore · undo last commit/amend/merge/rebase/stash · interactive reset · full stash menu · fixup + autosquash in a single step |
| **Inspect** | `status` (`st`), `log` (`l`), `reflog` (`rl`), `last-commit` (`lc`), `last-ref` (`lr`) | Pretty repo status, multi-mode log + search, reflog viewer, quick last-commit / last-ref summary |
| **Hooks** | `hook` (`ho`) | List / create from templates / edit / toggle / remove / test / show — for every git hook |
| **Repo setup** | `init` (`i`), `origin` (`or`, `o`, `remote`) | `git init` from gitbasher · add/change/rename/remove the remote origin |
| **Config** | `config` (`cfg`) | User, default branch, separator, editor, ticket prefix, scopes, AI key, AI model, proxy |

Total: **23 top-level commands**, **60+ aliases**, **100+ modes**.

---

## AI-powered commits

Drop in an API key once, then let Claude / Gemini write conventional commit messages from your diff.

### Setup

```bash
# 1. Get a key (free tier available) at https://aistudio.google.com/app/apikey
#    or use your OpenRouter key for Claude / multi-provider access.
gitb cfg ai          # paste key — choose local repo or global

# 2. Optional: HTTP proxy (for restricted regions)
gitb cfg proxy
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

Each task uses a model tuned for speed/cost/quality. Defaults (May 2026):

| Task | Default model | Why |
|------|---------------|-----|
| `simple` (one-line message) | `google/gemini-3.1-flash-lite-preview` | Cheapest fast tier |
| `subject` (after manual type/scope) | `google/gemini-3.1-flash-lite-preview` | Short structured output |
| `full` (header + body) | `google/gemini-3-flash-preview` | Better prose |
| `grouping` (atomic-split mapping) | `anthropic/claude-haiku-4.5` | Strict instruction following |

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
# — or in one step —
gitb fx fastp        # add all + fixup + autosquash + force-push
```

### Sync with main mid-feature
```bash
gitb sync            # fetch main + rebase your branch
gitb sync push       # …and force-push
gitb sync merge      # use merge instead of rebase
```

### Save WIP across machines / branches
```bash
gitb wip             # add . + WIP commit + push
# … on another machine …
gitb pu && gitb unwip   # restore changes, drop the WIP commit
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
| [`wip`](#gitb-wip--unwip) | `w` | Stage all + WIP commit + push (one keystroke save) |
| [`unwip`](#gitb-wip--unwip) | `uw` | Undo a WIP commit and restore the changes |
| [`fixup`](#gitb-fixup) | `fx` | Create fixup commit and autosquash in one step |
| [`undo`](#gitb-undo) | `un` | Undo last commit / amend / merge / rebase / stash |
| [`reset`](#gitb-reset) | `res` | Friendly `git reset` with undo support |
| [`stash`](#gitb-stash) | `s` `sta` | Full stash menu: select, all, list, pop, apply, show, drop |
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

### `gitb wip` / `unwip`

Snapshot work-in-progress in one keystroke; restore it later.

| Command | Mode | Description |
|---------|------|-------------|
| `gitb wip` | `<empty>` | Stage all, WIP commit, push |
| `gitb wip` | `nopush` (`np` `n`) | Stage all + WIP commit, no push |
| `gitb unwip` | | Undo the WIP commit, restore the changes to the working tree |

### `gitb fixup`

End-to-end fixup-and-autosquash so you don't have to chain `gitb c fix` + `gitb r a`.

| Mode | Aliases | Description |
|------|---------|-------------|
| `<empty>` | | Select files, pick commit, fixup, autosquash |
| `fast` | `f` | Add all, pick commit, fixup, autosquash |
| `commit` | `c` | Create fixup commit only (= `gitb c x`) |
| `push` | `p` | Fixup + autosquash + force-push |
| `fastp` | `fp` `pf` | Fast variant + force-push |

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
| `<empty>` | | Reset last commit (mixed) |
| `soft` | `s` | Soft reset last commit |
| `undo` | `u` | Undo last reset |
| `interactive` | `i` | Pick commit to reset to |
| `ref` | `r` | Reset to a `HEAD` reference (reflog recovery) |

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
| `model` | | Default AI model |
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
| `gitbasher.ai-model[-task]` | `gitb cfg model` | AI model overrides |
| `gitbasher.proxy` | `gitb cfg proxy` | HTTP proxy for AI calls |

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

Use `sudo`, or install to `~/.local/bin` and add it to `PATH`.
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
sudo rm /usr/local/bin/gitb          # if installed via curl
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
