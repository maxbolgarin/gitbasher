# gitbasher — Architecture

This document explains how gitbasher is organized: the script layout, how files are sourced, how the bundled `dist/gitb` is built, and how an invocation flows from `gitb <command>` to the underlying git calls.

It targets contributors. If you only want to use gitbasher, the [README](./README.md) is a better starting point.

---

## Layout at a glance

```
.
├── scripts/                # development source — every .sh file is sourced into one process
│   ├── gitb.sh             # entry point, sources all the others, dispatches subcommands
│   ├── common.sh           # shared helpers (colors, prompts, git wrappers, validators)
│   ├── base.sh             # `print_help`, first-run banner, top-level dispatch
│   ├── ai.sh               # AI client (OpenRouter / OpenAI / Ollama) + key/proxy handling
│   ├── config.sh           # `gitb config` — stores prefs in git config (gitbasher.*)
│   ├── init.sh             # interactive remote setup on first run
│   ├── commit.sh           # `gitb commit` — interactive, AI, split, amend, revert
│   ├── push.sh / pull.sh   # `gitb push`, `gitb pull`
│   ├── branch.sh           # `gitb branch`, `gitb prev`
│   ├── tag.sh / cherry.sh  # `gitb tag`, `gitb cherry`
│   ├── merge.sh / rebase.sh / squash.sh / sync.sh   # history / integration commands
│   ├── stash.sh / wip.sh   # quick save & restore (stash / branch / worktree backends)
│   ├── undo.sh / reset.sh  # reflog-driven undo, common reset flows
│   ├── worktree.sh         # `gitb worktree` — list/add/remove/lock/move/prune
│   ├── hooks.sh            # `gitb hook` — manage `.git/hooks/*`
│   ├── origin.sh           # remote management
│   └── gitlog.sh           # `gitb log`, `gitb reflog`, `gitb last-commit`, `gitb last-ref`
├── dist/
│   ├── build.sh            # bundler — inlines every `source` line into one file
│   └── gitb                # generated bundle (committed; rebuilt by build.sh)
├── tests/
│   ├── run_tests.sh        # BATS runner
│   └── test_*.bats         # one file per concern (commit, wip, worktree, …)
├── install.sh              # curl/wget bootstrap installer
├── package.json            # npm metadata + semantic-release devDependencies
├── .releaserc.json         # semantic-release pipeline (build, sha256, GitHub, npm, git)
└── .github/workflows/      # build.yml (CI), release.yml (manual trigger)
```

---

## The sourcing model

There is no per-command process exec — `scripts/gitb.sh` `source`s every other script into the **same** bash process and then dispatches with a `case "$1"` block. That has two consequences worth knowing:

1. **All functions share one namespace.** Helper names in `common.sh` (`yes_no_choice`, `git_status`, `sanitize_git_name`, `get_config_value`, `wrong_mode`, …) are visible from every other file. Don't define a private helper with a name another file might already use.
2. **No new global variables in `common.sh`.** Use `local` inside functions. Globals leak across commands and silently break the next subcommand the user runs.

Source order is deterministic and lives at `scripts/gitb.sh:69-95`. `common.sh` and `init.sh` come first, then domain scripts, then `base.sh` last (so `print_help` sees everything). When a `source` line fails it dies with `exit 1` — see `gitb.sh:69-95` for the guard pattern.

### Top-level dispatch

`scripts/base.sh` is the dispatcher: a `case "$1"` block (`base.sh:102-181`) maps each command name and its aliases to the corresponding `*_script` function. The convention: `commit_script`, `push_script`, `branch_script`, etc. — defined in their respective files.

Aliases are colocated with the canonical name in the case pattern (`commit|c|co|com)`), and the same aliases are mirrored in `print_help` so `gitb --help` stays in sync.

### `--help` / `-h` normalization

`scripts/base.sh:86-93` rewrites every occurrence of `--help` / `-h` in `$@` to the literal token `help` before dispatch. This means each subcommand handler only has to look for `help`, not three spellings. `gitb commit --help`, `gitb commit -h`, and `gitb commit help` all hit the same branch.

### Re-exec to Bash 4+

If `gitb` runs under Bash 3 (the macOS system bash), `scripts/gitb.sh:18-46` tries to `exec` a newer bash — first via `command -v bash`, then `brew --prefix bash`, then hardcoded Homebrew prefixes. Only when none works does it print the install hint. The bundle inherits this logic; the bash 3 path only ever produces the upgrade message, never tries to run the rest of the script.

### Stale lock detection

`scripts/gitb.sh:50-64` checks `git rev-parse --git-dir` at startup and prompts before removing a stale `index.lock`. This catches the common "another git process is running" sequel to a Ctrl+C'd git command.

---

## The build pipeline

`dist/build.sh` is a 20-line bundler. It reads `scripts/gitb.sh` line by line and, every time a line matches `^[[:space:]]*(source|\.)[[:space:]]+([^[:space:]]+)`, replaces it with the contents of the referenced file. Everything else passes through. The result is piped through `sed` to strip:

- Lines whose first non-whitespace is `#`, `##`, or `###` followed by a space or `!` (comments and shebangs from inlined files)
- Empty/whitespace-only lines

Then the bundle is written to `dist/gitb` and the version placeholder `GITBASHER_VERSION="dev"` is rewritten to the real version (BSD/GNU `sed -i` is detected at runtime).

Properties of the bundle that matter:

- **No `source` lines remain** — the bundle is a single self-contained file. The `|| { echo "..."; exit 1; }` guards on the original `source` lines are stripped along with their `source` line (the bundle can't encounter a missing file anyway).
- **Comments are stripped** — don't put load-bearing logic in a comment. This includes per-line `# disable shellcheck` directives; those need to live as `# shellcheck` blocks (which are NOT stripped — they're 2 hashes only when combined with `shellcheck`, single-`#` comments are removed).
- **Shebang stays** — `build.sh` re-adds `#!/usr/bin/env bash` as the first line of the output explicitly.
- **The bundle is committed.** `dist/gitb` is checked into the repo so `npm install -g gitbasher` and the curl installer can ship a single file. semantic-release rebuilds it on every release via the `@semantic-release/exec` plugin.

To rebuild locally:

```bash
bash dist/build.sh ./scripts/gitb.sh ./dist/gitb dev
chmod +x ./dist/gitb
./dist/gitb --version    # → gitbasher vdev
```

---

## How a command flows

End-to-end, `gitb wip up worktree` does this:

1. Shell finds `gitb` on `PATH` (installed by npm or the install script). It is the bundled `dist/gitb`.
2. The bash 4+ check passes (or re-execs).
3. The stale-lock check passes.
4. `case "$1"` in the dispatch matches `wip|w` → calls `wip_script "${@:2}"` (`base.sh:124-126`).
5. `wip_script` is the entry function defined in `scripts/wip.sh`. It parses subcommand args (`up`, `down`, …) and dispatches to `wip_up` / `wip_down`.
6. `wip_up` parses backend arguments, optionally calls `prompt_wip_backend` (interactive picker), then calls one of `wip_up_stash` / `wip_up_branch` / `wip_up_worktree`.
7. The backend functions call `git` directly with carefully-quoted arguments and use the helpers in `common.sh` for prompts, status display, and color output.

Each script broadly follows that pattern: a `<name>_script` entry function, a few subcommand dispatch helpers, and the heavy lifting in command-specific functions that ultimately call `git`.

---

## Configuration storage

User-visible settings live in `git config` under the `gitbasher.*` namespace, set via `gitb config`:

- `gitbasher.scopes` — comma-separated commit scopes for the picker
- `gitbasher.ai-provider`, `gitbasher.ai-api-key`, `gitbasher.ai-model` — AI client
- `gitbasher.ai-proxy` — optional HTTPS proxy for restricted regions
- `gitbasher.worktreebase` — base path for `gitb worktree add` and `wip up worktree`
- a handful of feature toggles (`gitbasher.confirm-push`, `gitbasher.color`, …)

`get_config_value` and `set_config_value` in `common.sh` are the only paths that should touch these. Per-repo by default; `--global` is supported by passing the `g` mode to `gitb cfg`.

---

## Testing

BATS, run via `bash tests/run_tests.sh`. The runner sets up a temporary git repo per test file via the standard `setup`/`teardown` hooks. Tests typically:

- Source the function under test from `scripts/<name>.sh` directly (avoids the bundle's strip step).
- Stub external commands (`git`, `curl`) by prepending a fake binary to `PATH`, not by mocking inside Bash.
- Assert against captured stdout/stderr and the exit code.

The `xargs -r` portability fix (replaced with `mapfile`-driven loops) is the canonical example of a behavior change that lives or dies by its BATS coverage.

---

## Releasing

`@semantic-release/commit-analyzer` reads conventional commits on `main` and computes the next version. The `prepareCmd` in `.releaserc.json` rebuilds `dist/gitb`, recomputes the SHA-256 sidecar, and the GitHub asset list publishes both. `@semantic-release/git` commits the regenerated `dist/gitb` and the bumped `package.json` back to `main` with `[skip ci]`.

There is no manual changelog edit — release notes are derived from commit history.
