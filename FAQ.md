# Frequently Asked Questions

Quick answers to questions that come up often. For detailed flow docs, see [README.md](./README.md). For security details, see [SECURITY.md](./SECURITY.md).

## AI features

### Are my commits sent to a third party when I use `gitb commit ai`?

Only if you pick a hosted provider (OpenAI, OpenRouter). Gitbasher sends the staged diff plus a short system prompt to the provider's API; the provider's data-retention policy then applies. Pick `ollama` to keep everything local — the diff never leaves your machine.

### How do I set this up to be fully local?

```bash
brew install ollama          # or follow https://ollama.com for your OS
ollama serve                 # daemon, leave running
ollama pull llama3           # or any model you prefer
gitb cfg ai                  # choose ollama, pick the pulled model
```

After that, `gitb commit ai` runs against `http://localhost:11434` and never makes an outbound call.

### Where is my API key stored, and is that safe?

By default in `git config gitbasher.ai-api-key-<provider>` (per-repo). Repo-local config files are not pushed to remotes, but they are readable by anything with filesystem access to your repo. For shared machines or anything sensitive, prefer environment variables — gitbasher checks them first:

```bash
export GITB_AI_API_KEY_OPENAI=sk-...
export GITB_AI_API_KEY_OPENROUTER=...
```

Bare `gitb cfg` shows which slot each key resolves from; `gitb cfg ai` shows the configured key in masked form. The `mask_api_key` helper masks keys in any diagnostic output gitbasher prints.

### Why does `gitb commit ai` say "API key not configured"?

The active provider has no key in any of the slots gitbasher checks (env var → per-provider config → legacy config, local then global). Run `gitb cfg ai` and pick the right provider, or `export GITB_AI_API_KEY_<PROVIDER>=...`.

## Bash and platform support

### What bash version does gitbasher need?

Bash 3.2 or newer. That's the version macOS still ships as `/bin/bash` (frozen at 3.2 for license reasons), so gitbasher runs out of the box on a stock Mac — no `brew install bash` required.

Bash 4-only features (`mapfile`, associative arrays, `${var,,}` case-folding, `read -i`) were removed in favor of bash 3.2-compatible equivalents: a small portable map/set shim in `scripts/common.sh`, `tr`-based case folding, and a graceful `read` fallback. Installing a newer bash is still nice-to-have — on bash 4+, prompts that come pre-filled with a value (editing an AI-suggested commit message, renaming a branch) let you edit the text in place; on bash 3.2 you retype the line or press Enter to keep the current value.

Only genuinely ancient shells (bash < 3.2) are unsupported; for those, gitbasher tries to re-exec under a newer bash before printing an install hint.

### Does gitbasher work on Windows?

Inside WSL, yes — treat it as Linux. Native Windows (cmd, PowerShell, Git Bash) is not supported.

### Does it work in a CI environment?

Yes for non-interactive subcommands (`gitb status`, `gitb pull dry`, etc.). Anything that prompts (`gitb commit` with no flags, `gitb merge`) will block waiting on stdin. Pipe answers in, or use the explicit modes that accept arguments (`gitb commit fast`, `gitb push yes`).

## Configuration

### Where does gitbasher store its settings?

In `git config` under the `gitbasher.*` namespace. Per-repo by default (in `.git/config`); after the local write, every `gitb cfg` setter asks whether to also set the value globally (`~/.gitconfig`). The keys you'll see most:

| Key | What it controls |
|-----|------------------|
| `gitbasher.scopes` | Conventional-Commit scope list shown by `gitb commit` |
| `gitbasher.ai-provider` | `openai`, `openrouter`, `ollama` |
| `gitbasher.ai-model` | Provider-specific model id |
| `gitbasher.ai-api-key-<provider>` | Per-provider key |
| `gitbasher.ai-proxy` | Outbound proxy for AI calls |
| `gitbasher.worktreebase` | Base directory for worktrees (`gitb worktree`, `gitb wip up worktree`) |

Touch them through `gitb cfg ...` rather than `git config` directly so you get the same precedence rules gitbasher uses internally.

### How do I move my config from one machine to another?

For per-repo settings, copy `.git/config` (or just the `[gitbasher]` section). For global settings, copy `~/.gitconfig`. Don't sync API keys this way — set them via env vars on the new machine.

## Installation, updating, uninstalling

### How do I upgrade?

```bash
# self-update (recommended)
gitb update

# or rerun the installer
curl -fsSL https://raw.githubusercontent.com/maxbolgarin/gitbasher/main/install.sh | bash

# pin a specific version
GITB_VERSION=v5.0.0 curl -fsSL https://raw.githubusercontent.com/maxbolgarin/gitbasher/main/install.sh | bash
```

The installer detects an existing install and replaces it in place; downloads are SHA-256-verified when the release's checksum asset and a sha256 tool are available (otherwise it warns and continues).

### How do I uninstall?

```bash
gitb uninstall              # removes the binary and local + global gitbasher.* config keys
git config --global --remove-section gitbasher 2>/dev/null   # only if you skipped gitb uninstall
```

For npm installs: `npm uninstall -g gitbasher`. For system-wide installs: `sudo rm /usr/local/bin/gitb`.

### What is in the npm package, and do I need Node.js?

The npm package ships the same `dist/gitb` Bash binary plus a `bin` entry. Node.js is only needed to run `npm install` itself, **not** to run `gitb` — gitbasher is pure Bash at runtime. If you don't want Node, use the curl installer.

## Workflow questions

### What is `gitb wip` actually doing?

It saves your in-progress changes so you can switch contexts safely. Three backends:

- **stash (default)** — `git stash push` with metadata gitbasher tracks so `gitb wip down` restores cleanly; by default it also force-pushes a `wip/<branch>` backup branch to the remote (skip with `nopush`).
- **branch** — commits to a sidekick branch named after your current branch with a `wip/` prefix; restored via `git merge --squash --no-commit`.
- **worktree** — moves the dirty tree into a separate `git worktree` so the original branch stays clean. Best when you need to run two contexts side-by-side.

Pick a backend explicitly with `gitb wip up <backend>` (e.g. `gitb wip up worktree`); plain `gitb wip up` prompts for one each time.

### What does `gitb undo` undo?

`gitb undo` reverses your **last** Git operation — you pick which kind, and it targets the most recent action of that type (there is no reflog picker):

- `gitb undo` / `undo commit` — undoes the last commit via `git reset --soft HEAD~1`, keeping its changes staged.
- `undo amend` — restores the pre-amend commit (located via reflog).
- `undo merge` / `undo rebase` — aborts one in progress, or rolls a finished one back to `ORIG_HEAD`.
- `undo stash` — re-stashes changes you just popped or applied.

Everything except `undo rebase` (which is a `--hard` reset) and `undo merge` (a `git reset --merge`, which discards the merge's changes) preserves your changes. And because Git keeps a reflog, even a mistaken undo is recoverable — `gitb reset ref` lets you jump HEAD to any recent state (reflog retention defaults to 90 days for reachable commits, 30 days for unreachable).

### `gitb undo` vs `gitb reset` — which one?

They overlap but answer different questions:

- **`gitb reset`** is *position-based* — "move my branch back to a point." You choose the destination: the last commit (`gitb reset`, or `reset soft` to keep changes staged), any older commit (`reset interactive`), or a reflog entry (`reset ref`). It never uses `--hard`, so your file changes are always preserved.
- **`gitb undo`** is *operation-based* — "reverse the last thing I did" (commit, amend, merge, rebase, or stash), with the right git command picked for you.

They meet in one spot: `gitb undo` and `gitb reset soft` both soft-reset the last commit. Reach for `undo` as the quick one-liner; reach for `reset` when you want to go back further or choose mixed-vs-soft.

**Neither removes a single commit from the middle of history.** Resetting to the 5th of 10 commits moves HEAD there and drops the four *newer* commits too (their changes land back in your working tree). To excise or edit just one older commit, use `gitb rebase interactive` (base = a branch) or `gitb rebase autosquash` (pick a base commit, then set that commit's line to `drop`/`edit` in the todo list). If the commit is already pushed and shared, prefer `gitb commit revert`, which adds a new commit that undoes the target without rewriting history.

### `gitb pull` says "diverged" — what's the right move?

Run `gitb sync`. It shows the divergence and rebases by default (use `gitb sync merge` to merge instead); `gitb sync dry` previews incoming commits before touching your local refs.

### `gitb log` used to dump everything into a pager — where did that go?

Bare `gitb log` is now an interactive browser: a numbered, paginated commit list where picking a commit shows it and offers actions (diff, stat, copy hash, revert, cherry-pick, fixup, restore a file). The old full dump is still there as `gitb log all` (alias `dump`). Piping still works — non-interactive runs print a plain `git log`-style listing and exit. You can also pass an argument directly: a number (`gitb log 20`), a file path, a ref or range, or words to search commit messages. Page size: `git config gitbasher.log-count 30`.

## Contributing and bugs

### How do I report a bug?

Open an issue from the `Bug Report` template at <https://github.com/maxbolgarin/gitbasher/issues>. Include `gitb --version`, the exact command, and the output. For security-sensitive issues, see [SECURITY.md](./SECURITY.md) — there's a private reporting path.

### Where do I learn how the codebase works?

Start with [ARCHITECTURE.md](./ARCHITECTURE.md). It covers the single-process sourcing model, the build pipeline that produces `dist/gitb`, and the test harness conventions. [CONTRIBUTING.md](./CONTRIBUTING.md) has the day-to-day dev setup.
