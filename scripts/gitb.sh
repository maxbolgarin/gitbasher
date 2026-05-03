#!/usr/bin/env bash

### Here is main script for running gitbasher
# https://github.com/maxbolgarin/gitbasher

GITBASHER_VERSION="dev"

if [ "$1" == "init" ] || [ "$1" == "i" ]; then
    git init
fi

git_check=$(git branch --show-current 2>&1)
if [[ "$git_check" == *"fatal: not a git repository"* ]]; then
    echo "You can use gitb only in a git repository"
    exit
fi


### Cannot use bash version less than 4 because of many features that was added to language in that version
if ((BASH_VERSINFO[0] < 4)); then
    # Try to re-exec with a newer bash. Order:
    #   1. PATH-resolved bash that reports >= 4 (covers MacPorts, nix, custom prefixes, Linux upgrades)
    #   2. Homebrew-managed bash (handles Apple Silicon vs Intel and custom HOMEBREW_PREFIX)
    #   3. Hardcoded common paths as a final fallback
    _gitb_candidate=$(command -v bash 2>/dev/null)
    if [ -n "$_gitb_candidate" ] && [ -x "$_gitb_candidate" ] \
       && "$_gitb_candidate" -c '((BASH_VERSINFO[0] >= 4))' >/dev/null 2>&1; then
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
    unset _gitb_candidate

    printf "Sorry, you need at least bash-4.0 to run gitbasher.\n\n"
    printf "Linux (Debian/Ubuntu):\n    sudo apt update && sudo apt install --only-upgrade bash\n\n"
    printf "macOS:\n    1) Install Homebrew (if missing):\n       /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"\n    2) Install newer bash:\n       brew install bash\n    3) Optional: make it your default shell (then restart Terminal):\n       sudo sh -c 'echo /opt/homebrew/bin/bash >> /etc/shells' && chsh -s /opt/homebrew/bin/bash\n\n"
    printf "Or run gitb explicitly with the newer bash when installed:\n    /opt/homebrew/bin/bash $0 \"\$@\"\n\n"
    exit 1; 
fi


### Detect a stale .git/index.lock from a previously interrupted git operation
git_dir=$(git rev-parse --git-dir 2>/dev/null)
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
source scripts/branch.sh || { echo "gitbasher: failed to load scripts/branch.sh" >&2; exit 1; }
source scripts/tag.sh || { echo "gitbasher: failed to load scripts/tag.sh" >&2; exit 1; }
source scripts/reset.sh || { echo "gitbasher: failed to load scripts/reset.sh" >&2; exit 1; }
source scripts/stash.sh || { echo "gitbasher: failed to load scripts/stash.sh" >&2; exit 1; }
source scripts/cherry.sh || { echo "gitbasher: failed to load scripts/cherry.sh" >&2; exit 1; }
source scripts/sync.sh || { echo "gitbasher: failed to load scripts/sync.sh" >&2; exit 1; }
source scripts/undo.sh || { echo "gitbasher: failed to load scripts/undo.sh" >&2; exit 1; }
source scripts/wip.sh || { echo "gitbasher: failed to load scripts/wip.sh" >&2; exit 1; }
source scripts/gitlog.sh || { echo "gitbasher: failed to load scripts/gitlog.sh" >&2; exit 1; }
source scripts/hooks.sh || { echo "gitbasher: failed to load scripts/hooks.sh" >&2; exit 1; }
source scripts/origin.sh || { echo "gitbasher: failed to load scripts/origin.sh" >&2; exit 1; }

source scripts/base.sh || { echo "gitbasher: failed to load scripts/base.sh" >&2; exit 1; }
