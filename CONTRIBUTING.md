# Contributing to gitbasher

Thanks for taking the time to contribute! This document describes how to set up a dev environment, the conventions the project follows, and what to expect from the review process.

## Quick start

```bash
git clone https://github.com/maxbolgarin/gitbasher.git
cd gitbasher
# Run the dev version directly (Bash 4+ required)
bash scripts/gitb.sh --version
```

The shipped binary is a single bundled file produced by `dist/build.sh`. Source code lives in `scripts/`.

```bash
# Build the bundled binary into ./dist/gitb
bash dist/build.sh ./scripts/gitb.sh ./dist/gitb dev
./dist/gitb --version
```
  
## Running tests

Tests use [BATS](https://github.com/bats-core/bats-core).

```bash
# Install BATS (one of):
brew install bats-core           # macOS
sudo apt-get install -y bats     # Debian/Ubuntu
npm install -g bats              # any platform

# Run the suite
bash tests/run_tests.sh
```

A BATS test is required for any non-trivial fix or new behavior. Place it in `tests/` and follow the patterns of the existing `test_*.bats` files.

## Linting

ShellCheck runs in CI (`.github/workflows/build.yml`, `shellcheck` job, `severity: error`) and blocks the build on findings. Run it locally before pushing to fail fast:

```bash
shellcheck scripts/*.sh install.sh
```

Aim for **no new** warnings. The CI bar is `severity: error`; widening to `severity: warning` is a goal once the existing baseline is clean. Pre-existing warnings outside the area you touched are not your responsibility — note them in the PR if you spot something risky.

## Coding conventions

- **Bash 4+ features are allowed** (`mapfile`, associative arrays, `${var,,}` etc.). The bundled binary re-execs to a newer Bash on macOS, so older Bash 3 paths only need to display the upgrade hint.
- **Quote variables** in `git` invocations and any path/branch/ref handling, except where word-splitting is intentional (and document why with a comment).
- **Prefer portable constructs** over GNU-only extensions. Tested examples:
  - `mapfile -t arr < <(cmd) ; [ ${#arr[@]} -gt 0 ] && cmd2 "${arr[@]}"` instead of `cmd | xargs -r cmd2`
  - `sed` with explicit GNU/BSD detection (see `dist/build.sh` for the pattern)
- **Trap cleanup** — interactive scripts that touch the staging area should register an `EXIT`/`INT`/`TERM` trap that restores state. See `cleanup_on_exit` in `scripts/commit.sh`.
- **No new global variables** in `scripts/common.sh` — declare with `local` inside functions.

## Commit messages

This project uses [Conventional Commits](https://www.conventionalcommits.org/). Recent commits demonstrate the style:

```
fix(merge): replace GNU-only xargs -r with portable mapfile pattern
feat(ai): support OpenRouter request timeouts
docs(readme): clarify wget HTTPS hardening
test(branch): cover delete-with-spaces edge case
```

Allowed types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `build`, `ci`, `perf`, `style`, `revert`.

`semantic-release` consumes these on the release branch to compute the next version, generate the changelog, and publish. A breaking change should include `BREAKING CHANGE:` in the commit footer.

## Pull request process

1. **Fork** and create a feature branch (`git checkout -b feat/short-description`).
2. **Make focused commits** — each commit should leave the tree green.
3. **Add or update tests** for any behavior change.
4. **Run the suite locally** (`bash tests/run_tests.sh`) and confirm `dist/build.sh` still produces a runnable bundle.
5. **Open the PR** with a description that explains the *why*, not just the *what*. Link any related issue.
6. **Respond to review** — squash fixups before merge unless asked otherwise.

We aim to leave first-look feedback within a few days. Larger changes (new subcommands, AI provider integrations, build/release pipeline changes) are best discussed in an issue first to avoid wasted work.

## Releasing

Maintainers cut releases via `release.yml` (manual `workflow_dispatch`). `semantic-release` derives the version from commits and publishes the bundled `dist/gitb` to GitHub Releases and the npm package.

## Reporting bugs / requesting features

Use the GitHub [issues](https://github.com/maxbolgarin/gitbasher/issues) page. For security-sensitive reports, see [SECURITY.md](./SECURITY.md) instead — please **do not** open a public issue for a vulnerability.
