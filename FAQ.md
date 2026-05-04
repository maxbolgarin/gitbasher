# Frequently Asked Questions

Quick answers to questions that come up often. For detailed flow docs, see [README.md](./README.md). For breaking changes between versions, see [MIGRATION_V3_TO_V4.md](./MIGRATION_V3_TO_V4.md). For security details, see [SECURITY.md](./SECURITY.md).

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

`gitb cfg ai` prints the current resolution order so you can see which slot is active. The `mask_api_key` helper masks keys in any diagnostic output gitbasher prints.

### Why does `gitb commit ai` say "API key not configured"?

The active provider has no key in any of the slots gitbasher checks (env var → per-provider config → legacy config, local then global). Run `gitb cfg ai` and pick the right provider, or `export GITB_AI_API_KEY_<PROVIDER>=...`.

## Bash and platform support

### Why does gitbasher require Bash 4+?

It uses `mapfile`, associative arrays, `${var,,}` (case-folding), and other features that landed in bash 4.0 (2009). macOS still ships bash 3.2 by default for license reasons. Gitbasher detects this at startup and tries to re-exec under a newer bash from `command -v bash`, `brew --prefix bash`, or known Homebrew paths before falling back to a manual install hint.

If you can't install bash 4+, gitbasher won't run — there is no bash 3 fallback codepath.

### Does gitbasher work on Windows?

Inside WSL, yes — treat it as Linux. Native Windows (cmd, PowerShell, Git Bash) is not supported.

### Does it work in a CI environment?

Yes for non-interactive subcommands (`gitb status`, `gitb pull --dry-run`, etc.). Anything that prompts (`gitb commit` with no flags, `gitb merge`) will block waiting on stdin. Pipe answers in, or use the explicit modes that accept arguments (`gitb commit fast`, `gitb push -y`).

## Configuration

### Where does gitbasher store its settings?

In `git config` under the `gitbasher.*` namespace. Per-repo by default (in `.git/config`); pass `g` to `gitb cfg` to edit the global file (`~/.gitconfig`). The keys you'll see most:

| Key | What it controls |
|-----|------------------|
| `gitbasher.scopes` | Conventional-Commit scope list shown by `gitb commit` |
| `gitbasher.ai-provider` | `openai`, `openrouter`, `ollama` |
| `gitbasher.ai-model` | Provider-specific model id |
| `gitbasher.ai-api-key-<provider>` | Per-provider key |
| `gitbasher.ai-proxy` | Outbound proxy for AI calls |
| `gitbasher.worktreebase` | Base directory for `gitb wip --worktree` |

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
GITB_VERSION=v4.0.0 curl -fsSL https://raw.githubusercontent.com/maxbolgarin/gitbasher/main/install.sh | bash
```

The installer detects an existing install and replaces it in place; SHA-256 verification runs on every download.

### How do I uninstall?

```bash
gitb uninstall              # removes the binary
rm -rf ~/.gitbasher          # remove cache (optional)
git config --global --unset-all gitbasher 2>/dev/null   # drop global gitbasher.* keys
```

For npm installs: `npm uninstall -g gitbasher`. For system-wide installs: `sudo rm /usr/local/bin/gitb`.

### What is in the npm package, and do I need Node.js?

The npm package ships the same `dist/gitb` Bash binary plus a `bin` entry. Node.js (≥14) is required to run `npm install`, but **not** to run `gitb` itself — gitbasher is pure Bash at runtime. If you don't want Node, use the curl installer.

## Workflow questions

### What is `gitb wip` actually doing?

It saves your in-progress changes so you can switch contexts safely. Three backends:

- **stash (default)** — `git stash push` with metadata gitbasher tracks so `gitb wip down` restores cleanly.
- **branch** — commits to a sidekick branch named after your current branch with a `wip/` prefix; restored by cherry-picking.
- **worktree** — moves the dirty tree into a separate `git worktree` so the original branch stays clean. Best when you need to run two contexts side-by-side.

Pick a backend with `gitb wip up <backend>` or set the default with `gitb cfg wip-backend`.

### What does `gitb undo` undo?

The most common destructive Git ops, driven by reflog: commits (incl. amend), merges, rebases, stash apply/pop. Run `gitb undo` and pick from the recent reflog entries. Because it's reflog-driven, your previous state is recoverable for as long as the reflog retains it (default 90 days for reachable, 30 days for unreachable).

### `gitb pull` says "diverged" — what's the right move?

Run `gitb sync`. It shows the divergence, lets you pick rebase or merge, and previews incoming commits with `--dry-run` before touching your local refs.

## Contributing and bugs

### How do I report a bug?

Open an issue from the `Bug Report` template at <https://github.com/maxbolgarin/gitbasher/issues>. Include `gitb --version`, the exact command, and the output. For security-sensitive issues, see [SECURITY.md](./SECURITY.md) — there's a private reporting path.

### Where do I learn how the codebase works?

Start with [ARCHITECTURE.md](./ARCHITECTURE.md). It covers the single-process sourcing model, the build pipeline that produces `dist/gitb`, and the test harness conventions. [CONTRIBUTING.md](./CONTRIBUTING.md) has the day-to-day dev setup.
