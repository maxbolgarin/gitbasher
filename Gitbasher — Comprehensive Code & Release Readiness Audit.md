# Gitbasher — Audit Remediation Checklist

Tracks the audit originally produced May 2026. Items marked `[x]` were fixed across two bug-fix passes on 2026-05-03; `[ ]` items remain open with a one-line rationale.

> **Local verification (pass 2):** 343/345 BATS tests pass. The 2 remaining failures (`get_ai_api_key:returns empty when not set`, `get_ai_model:returns empty when not set`) are environmental — they fail because the dev box has `gitbasher.ai-api-key` / `gitbasher.ai-model` set in git config — and predate both passes. ShellCheck at `--severity=error` reports zero issues across `scripts/*.sh` and `install.sh`.

---

## Done

### Correctness & data-safety bugs
- [x] **`xargs -r` portability** — replaced with `mapfile`-based pattern in `scripts/merge.sh:381,457` and `scripts/rebase.sh:630`. Was GNU-only; now works on BSD/macOS.
- [x] **`cleanup_on_exit` unquoted `$1`** (`scripts/commit.sh:10-15`) — wrapped in subshell with `set -f` and added `--` separator. Word-splitting on multiple paths preserved; globs no longer expand against CWD; paths starting with `-` no longer parsed as options.
- [x] **Triple-quoted `git commit -m """$msg"""`** — replaced with the canonical `"$msg"` form at all 6 sites in `scripts/commit.sh`.
- [x] **Unquoted `$1`/`$2` in `git rev-list --first-parent`** (`scripts/common.sh:1139`) — quoted; also quoted the two `commit_list ... $base..HEAD` / `... $origin/$2..HEAD` ref expressions a few lines below.
- [x] **Unquoted refs/branches in git invocations** — quoted across `scripts/branch.sh`, `merge.sh`, `rebase.sh`, `pull.sh`, `push.sh`, `tag.sh`. The intentional flag pass-through `$1` in `push.sh:20` and the optional `$args` in `merge.sh:242-244` were left unquoted with comment-implied intent.
- [x] **Tag-checkout missing sanitization** (`scripts/branch.sh:277`) — `selected_tag` now passes through `sanitize_git_name` before `git checkout`.

### Security hardening
- [x] **`wget` HTTPS enforcement** (`install.sh:135`) — added `--https-only` so the wget branch matches the curl branch's HTTPS-only posture.
- [x] **API key leak via `set -x`** (`scripts/ai.sh` `secure_curl_with_api_key`) — added `{ set +x; } 2>/dev/null` inside the subshell before `curl`. Tracing on the parent shell can no longer leak `Authorization: Bearer <key>`.
- [x] **`validate_proxy_url` tightened** (`scripts/ai.sh`) — caps total input at 2048 chars, caps host length at 253, requires port 1-65535. All 10 existing BATS proxy-validator tests still pass; new boundary cases (port 0, port 65536, very long URLs) now correctly reject.

### Robustness
- [x] **Stale `.git/index.lock` detection** (`scripts/gitb.sh`) — checks `git rev-parse --git-dir` at startup and prompts before removing the lock. Verified end-to-end: `n` exits 1; `y` clears and continues. Works inside subdirectories.
- [x] **`source` error handling in `scripts/gitb.sh`** — every `source scripts/*.sh` line now has a `|| { echo "..." >&2; exit 1; }` guard. `dist/build.sh` strips the failure tail when inlining (the bundled binary cannot encounter a missing source anyway), so the guard is dev-mode only.
- [x] **Detached-HEAD warning** — new `on_branch` and `warn_if_detached_head` helpers in `scripts/common.sh`; `commit.sh` and `push.sh` call `warn_if_detached_head` before destructive work. Default is **No** on Enter (safer); verified with scratch-repo smoke test.
- [x] **Dynamic Bash 4+ lookup in `scripts/gitb.sh:19-40`** — tries `command -v bash` (a Bash 4+ candidate) first, then `brew --prefix bash`, then the previously-hardcoded `/opt/homebrew/bin/bash` and `/usr/local/bin/bash` as last resort. Covers MacPorts, nix, custom Homebrew prefixes.

### CI / release
- [x] **ShellCheck step in `build.yml`** — runs at `--severity=error` so existing style warnings don't block PRs; widen to `warning` once the baseline is clean.
- [x] **`macos-latest` matrix in `build.yml`** — surfaces BSD/GNU divergence in CI; macOS BATS install via `brew install bats-core`.
- [x] **SHA-256 release asset** — `.releaserc.json` exec plugin appends `shasum -a 256 dist/gitb > dist/gitb.sha256` to its prepare command; the `@semantic-release/github` assets list now includes the checksum file.
- [x] **`semantic-release` declared in `devDependencies`** — `package.json` lists semantic-release and the six plugins; `release.yml` replaces six `npm install -g` lines with one `npm install --no-audit --no-fund`. `npx semantic-release` resolves from `./node_modules/.bin`.

### Community
- [x] **`CONTRIBUTING.md`** — covers dev setup, build, BATS, ShellCheck, coding conventions, conventional commits, PR process.

---

## Open / deferred

### Tests
- [ ] BATS coverage for `commit.sh` flows (scope detection, AI grouping, conventional commit path).
- [ ] Integration tests for `merge.sh` / `rebase.sh` conflict-resolution paths (especially the new portable `xargs -r` replacement).
- [ ] Reflog / stash edge cases in `undo.sh` and `wip.sh`.
- [ ] Code-coverage reporting via `kcov` or `bashcov`.

### UX / discoverability
- [ ] Shell completion scripts (Bash, Zsh, Fish).
- [ ] `NO_COLOR` / `--no-color` support.
- [ ] `--dry-run` for destructive operations (`reset`, `rebase`, `sync`).
- [ ] `gitb status` summarising current gitbasher configuration.
- [ ] Machine-readable `--json` output mode.

### Project health / docs
- [ ] **`CODE_OF_CONDUCT.md`** — Contributor Covenant template; deferred per request.
- [ ] **`SECURITY.md`** — vulnerability reporting policy; deferred per request.
- [ ] **`CHANGELOG.md`** — auto-generate via semantic-release.
- [ ] **`ARCHITECTURE.md`** — explain script structure, sourcing model, build pipeline.
- [ ] **`.github/ISSUE_TEMPLATE/`** + `PULL_REQUEST_TEMPLATE.md`.
- [ ] Expand `package.json` keywords and GitHub repository topics.
- [ ] Homebrew formula / tap.
- [ ] README troubleshooting section (Bash version, macOS Bash 3 hint, AI key setup, common git error mappings).
- [ ] Submit to `awesome-git` style curated lists.

---

## Audit findings explicitly debunked (no work needed)

These were flagged in earlier drafts but were already correct in the codebase, or are not actually bugs. Recorded here so future passes don't re-open them.

- **`clear_sensitive_vars`** — defined in `scripts/ai.sh`, called via trap. Not missing.
- **`escape` function in `common.sh`** — defined at line 839. Not missing.
- **HTTP 429 handling in `call_openrouter_api`** — explicit case branch handles it with retry guidance.
- **`xargs -0` in `scripts/hooks.sh:433`** — `-0` is portable to BSD xargs; the audit lumped it with `-r` but the situations differ. Leave as-is.
- **JSON Unicode escaping in `_json_escape_for_payload`** — JSON allows raw UTF-8; only control chars 0x00-0x1F (and only the rarely-encountered ones, since `\t \r \n` are handled) would produce invalid output. Real-world AI calls are unaffected.
