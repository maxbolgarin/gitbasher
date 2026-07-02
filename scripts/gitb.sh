#!/usr/bin/env bash

### Here is main script for running gitbasher
# https://github.com/maxbolgarin/gitbasher

# Pipe failures must propagate so a broken `cmd1 | cmd2` doesn't silently succeed.
# `set -e` / `set -u` are intentionally not enabled here — many helpers across the
# sourced scripts rely on inspecting non-zero exit codes via `$?` / `||` / `if`,
# and on `${VAR:-}`-style defaults. Enabling them globally would require a full
# per-script audit; tracked in the v4 readiness plan.
set -o pipefail

GITBASHER_VERSION="dev"

if [ "$1" == "init" ] || [ "$1" == "i" ]; then
    git init
fi

### Some subcommands work without a git repository — they only touch the
### user's global gitbasher config, the installed binary, or print help, or
### (clone) create the repo they then operate on. Allow gitb to run from
### anywhere in those cases instead of bailing out; everything else still
### fails fast with a clear message.
GITBASHER_NO_REPO=""
git_check=$(git branch --show-current 2>&1)
if [[ "$git_check" == *"fatal: not a git repository"* ]]; then
    case "${1:-}" in
        ""|help|man|--help|-h|version|--version|-v|\
        config|cf|cfg|conf|\
        update|up|upd|\
        uninstall|uns|uni|\
        clone|cl|clo|\
        init|i)
            GITBASHER_NO_REPO="true"
            export GITBASHER_NO_REPO
            ;;
        *)
            echo "You can use 'gitb $1' only in a git repository."
            echo "Run 'gitb help' to see commands that work anywhere (config, update, uninstall, clone)."
            exit 1
            ;;
    esac
fi


### gitbasher targets bash 3.2+ — the version that ships as /bin/bash on macOS.
### Only genuinely ancient shells (bash < 3.2) lack the features we rely on
### (printf -v, array += append, [[ =~ ]] / BASH_REMATCH, C-style for). For
### those, try to re-exec under a newer bash before giving up.
if ((BASH_VERSINFO[0] < 3 || (BASH_VERSINFO[0] == 3 && BASH_VERSINFO[1] < 2))); then
    # Try to re-exec with a newer bash. Order:
    #   1. PATH-resolved bash that reports >= 3.2 (covers MacPorts, nix, custom prefixes, Linux upgrades)
    #   2. Homebrew-managed bash (handles Apple Silicon vs Intel and custom HOMEBREW_PREFIX)
    #   3. Hardcoded common paths as a final fallback
    _gitb_min='((BASH_VERSINFO[0] > 3 || (BASH_VERSINFO[0] == 3 && BASH_VERSINFO[1] >= 2)))'
    _gitb_candidate=$(command -v bash 2>/dev/null)
    if [ -n "$_gitb_candidate" ] && [ -x "$_gitb_candidate" ] \
       && "$_gitb_candidate" -c "$_gitb_min" >/dev/null 2>&1; then
        exec "$_gitb_candidate" "$0" "$@"
    fi
    if command -v brew >/dev/null 2>&1; then
        _gitb_candidate="$(brew --prefix bash 2>/dev/null)/bin/bash"
        if [ -x "$_gitb_candidate" ]; then
            exec "$_gitb_candidate" "$0" "$@"
        fi
    fi
    for _gitb_candidate in /opt/homebrew/bin/bash /usr/local/bin/bash; do
        [ -x "$_gitb_candidate" ] && exec "$_gitb_candidate" "$0" "$@"
    done
    unset _gitb_candidate _gitb_min

    printf "Sorry, you need at least bash-3.2 to run gitbasher.\n\n"
    printf "Linux (Debian/Ubuntu):\n    sudo apt update && sudo apt install --only-upgrade bash\n\n"
    printf "macOS already ships bash 3.2 as /bin/bash, so this should be rare.\n"
    printf "If you are on an older system, install a newer bash via Homebrew:\n    brew install bash\n\n"
    exit 1;
fi


### Detect a stale .git/index.lock from a previously interrupted git operation
if [ "$GITBASHER_NO_REPO" = "true" ]; then
    git_dir=""
else
    git_dir=$(git rev-parse --git-dir 2>/dev/null)
fi
if [ -n "$git_dir" ] && [ -e "$git_dir/index.lock" ]; then
    printf "\033[33mDetected %s/index.lock from a possibly interrupted git operation.\033[0m\n" "$git_dir"
    printf "Another git process may be running. Remove the lock and continue?\n"
    read -p "(y/N) " _gitb_lock_ans
    case "$_gitb_lock_ans" in
        y|Y|yes|YES) rm -f "$git_dir/index.lock" ;;
        *) exit 1 ;;
    esac
fi
unset git_dir _gitb_lock_ans


### Init gitbasher
# common.sh is sourced first so init.sh can use helpers like is_yes during the
# interactive remote setup prompt.
# The trailing `|| { ...; exit 1; }` only triggers when running scripts/gitb.sh
# directly during development; dist/build.sh inlines each source target so the
# bundled `gitb` binary cannot encounter a missing-file failure.
source scripts/common.sh || { echo "gitbasher: failed to load scripts/common.sh" >&2; exit 1; }
source scripts/init.sh || { echo "gitbasher: failed to load scripts/init.sh" >&2; exit 1; }


### Include all scripts
source scripts/ai.sh || { echo "gitbasher: failed to load scripts/ai.sh" >&2; exit 1; }
source scripts/config.sh || { echo "gitbasher: failed to load scripts/config.sh" >&2; exit 1; }
source scripts/merge.sh || { echo "gitbasher: failed to load scripts/merge.sh" >&2; exit 1; }
source scripts/rebase.sh || { echo "gitbasher: failed to load scripts/rebase.sh" >&2; exit 1; }
source scripts/squash.sh || { echo "gitbasher: failed to load scripts/squash.sh" >&2; exit 1; }
source scripts/pull.sh || { echo "gitbasher: failed to load scripts/pull.sh" >&2; exit 1; }
source scripts/push.sh || { echo "gitbasher: failed to load scripts/push.sh" >&2; exit 1; }
source scripts/commit.sh || { echo "gitbasher: failed to load scripts/commit.sh" >&2; exit 1; }
source scripts/edit.sh || { echo "gitbasher: failed to load scripts/edit.sh" >&2; exit 1; }
source scripts/branch.sh || { echo "gitbasher: failed to load scripts/branch.sh" >&2; exit 1; }
source scripts/tag.sh || { echo "gitbasher: failed to load scripts/tag.sh" >&2; exit 1; }
source scripts/reset.sh || { echo "gitbasher: failed to load scripts/reset.sh" >&2; exit 1; }
source scripts/stash.sh || { echo "gitbasher: failed to load scripts/stash.sh" >&2; exit 1; }
source scripts/cherry.sh || { echo "gitbasher: failed to load scripts/cherry.sh" >&2; exit 1; }
source scripts/sync.sh || { echo "gitbasher: failed to load scripts/sync.sh" >&2; exit 1; }
source scripts/undo.sh || { echo "gitbasher: failed to load scripts/undo.sh" >&2; exit 1; }
source scripts/wip.sh || { echo "gitbasher: failed to load scripts/wip.sh" >&2; exit 1; }
source scripts/gitlog.sh || { echo "gitbasher: failed to load scripts/gitlog.sh" >&2; exit 1; }
source scripts/diff.sh || { echo "gitbasher: failed to load scripts/diff.sh" >&2; exit 1; }
source scripts/worktree.sh || { echo "gitbasher: failed to load scripts/worktree.sh" >&2; exit 1; }
source scripts/hooks.sh || { echo "gitbasher: failed to load scripts/hooks.sh" >&2; exit 1; }
source scripts/origin.sh || { echo "gitbasher: failed to load scripts/origin.sh" >&2; exit 1; }
source scripts/clone.sh || { echo "gitbasher: failed to load scripts/clone.sh" >&2; exit 1; }
source scripts/update.sh || { echo "gitbasher: failed to load scripts/update.sh" >&2; exit 1; }
source scripts/uninstall.sh || { echo "gitbasher: failed to load scripts/uninstall.sh" >&2; exit 1; }
source scripts/completion.sh || { echo "gitbasher: failed to load scripts/completion.sh" >&2; exit 1; }

source scripts/base.sh || { echo "gitbasher: failed to load scripts/base.sh" >&2; exit 1; }
