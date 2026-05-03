# Gitbasher — Audit Remediation Checklist

Tracks the audit originally produced May 2026. Items marked `[x]` were fixed in the critical-bug pass on 2026-05-03; `[ ]` items remain open with a one-line rationale.

> 342/344 BATS tests pass after the fix pass. The 2 remaining failures (`get_ai_api_key:returns empty when not set`, `get_ai_model:returns empty when not set`) are environmental — they fail because the dev box has `gitbasher.ai-api-key` / `gitbasher.ai-model` set in git config — and predate this work.

---

## Done in this pass

### Correctness & data-safety bugs
- [x] **`xargs -r` portability** — replaced with `mapfile`-based pattern in `scripts/merge.sh:381,457` and `scripts/rebase.sh:630`. Was GNU-only; now works on BSD/macOS.
- [x] **`cleanup_on_exit` unquoted `$1`** (`scripts/commit.sh:10-15`) — wrapped in subshell with `set -f` and added `--` separator. Word-splitting on multiple paths preserved; globs no longer expand against CWD; paths starting with `-` no longer parsed as options.
- [x] **Triple-quoted `git commit -m """$msg"""`** — replaced with the canonical `"$msg"` form at all 6 sites in `scripts/commit.sh` (lines 642, 860, 922, 1419, 1442, 1821).
- [x] **Unquoted `$1`/`$2` in `git rev-list --first-parent`** (`scripts/common.sh:1139`) — quoted; also quoted the two `commit_list ... $base..HEAD` / `... $origin/$2..HEAD` ref expressions a few lines below.
- [x] **Unquoted refs/branches in git invocations** — quoted across `scripts/branch.sh`, `merge.sh`, `rebase.sh`, `pull.sh`, `push.sh`, `tag.sh` (every site flagged in the audit). The intentional flag pass-through `$1` in `push.sh:20` and the optional `$args` in `merge.sh:242-244` were left unquoted with comment-implied intent.

### Security hardening
- [x] **`wget` HTTPS enforcement** (`install.sh:135`) — added `--https-only` so the wget branch matches the curl branch's HTTPS-only posture.
- [x] **API key leak via `set -x`** (`scripts/ai.sh` `secure_curl_with_api_key`) — added `{ set +x; } 2>/dev/null` inside the subshell before `curl`. Tracing on the parent shell can no longer leak `Authorization: Bearer <key>`.

### Robustness
- [x] **Stale `.git/index.lock` detection** (`scripts/gitb.sh`) — checks `git rev-parse --git-dir` at startup and prompts before removing the lock. Verified end-to-end: lock → prompt → exit 1 on `n`; lock cleared and command continues on `y`. Works inside subdirectories.
- [x] **`source` error handling in `scripts/gitb.sh`** — every `source scripts/*.sh` line now has a `|| { echo "..." >&2; exit 1; }` guard. `dist/build.sh` strips the failure tail when inlining (the bundled binary cannot encounter a missing source anyway), so the guard is dev-mode only.

### Community files
- [x] **`CONTRIBUTING.md`** — covers dev setup, build, BATS, ShellCheck, coding conventions, conventional commits, PR process.

---

## Open / deferred

### CI/release
- [ ] **Add ShellCheck step to `build.yml`** — high ROI; would have caught most of the unquoted-variable issues automatically. Deferred from this pass because CI changes can't be validated locally and would block PRs if misconfigured.
- [ ] **Add `macos-latest` job to `build.yml`** — surfaces BSD/GNU divergence (the very class of bugs we just fixed). Same deferral reason as above.
- [ ] **Move `semantic-release` to `devDependencies`** in `package.json`; replace global `npm install -g` in `release.yml` with `npm ci`.
- [ ] **De-duplicate build step** — `release.yml` invokes `dist/build.sh` and `@semantic-release/exec` re-runs it via `.releaserc.json`.
- [ ] **Auto-trigger release on push to `main`** after green CI; today it is `workflow_dispatch` only.
- [ ] **Publish SHA256 checksum for `dist/gitb`** as a release asset.

### Hardening (not yet attempted)
- [ ] **`set -euo pipefail` at the entry point** — too risky to retrofit without comprehensive end-to-end testing of every interactive flow. Many existing branches rely on lax error handling. Should be a focused initiative, not a drive-by fix.
- [ ] **Consistent `sanitize_git_name` use before every git ref expansion** — partial today; an audit pass with grep-driven coverage would close the gap.
- [ ] **Detached HEAD guard** in `commit.sh`, `push.sh`, `merge.sh` (today only `branch.sh` warns).
- [ ] **Network-failure error mapping** — surface friendly messages for auth / DNS / unreachable rather than raw git stderr.

### Cross-platform polish (cosmetic, not bugs)
- [ ] `column -ts'|'` BSD vs GNU divergence — output may misalign on macOS in a few helpers. Functional but ugly.
- [ ] Hardcoded `/opt/homebrew/bin/bash` and `/usr/local/bin/bash` — replace with dynamic `command -v bash` / `brew --prefix bash` lookup.

### AI feature improvements (mostly enhancements, not bugs)
- [ ] **Soft-require `jq`** with installation prompt; current `sed`-based JSON escape fallback is narrow on control chars 0x00-0x1F (other than `\t \r \n`). JSON-spec UTF-8 escaping (`\uXXXX`) is **not** required — raw UTF-8 is valid JSON.
- [ ] **Tighten `validate_proxy_url` per-component regex.**
- [ ] Direct provider support (OpenAI, Anthropic, Gemini) without OpenRouter.
- [ ] Local LLM (Ollama) support.
- [ ] Configurable timeouts via `gitbasher.ai-timeout`.
- [ ] Token/cost estimation prior to large requests.

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

- **`clear_sensitive_vars`** — defined `scripts/ai.sh:927-943`, called via trap. Not missing.
- **`escape` function in `common.sh`** — defined at line 839. Not missing.
- **HTTP 429 handling in `call_openrouter_api`** — `scripts/ai.sh:593` case branch handles it explicitly with retry guidance.
- **`xargs -0` in `scripts/hooks.sh:433`** — `-0` is portable to BSD xargs; the audit lumped it with `-r` but the situations differ. Leave as-is.
- **JSON Unicode escaping in `_json_escape_for_payload`** — JSON allows raw UTF-8; only control chars 0x00-0x1F (and only the rarely-encountered ones, since `\t \r \n` are handled) would produce invalid output. Real-world AI calls are unaffected.
