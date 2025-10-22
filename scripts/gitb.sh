#!/usr/bin/env bash

### Here is main script for running gitbasher
# https://github.com/maxbolgarin/gitbasher


if [ "$1" == "init" ]; then
    git init
fi

git_check=$(git branch --show-current 2>&1)
if [[ "$git_check" == *"fatal: not a git repository"* ]]; then
    echo "You can use gitb only in a git repository"
    exit
fi


### Cannot use bash version less than 4 because of many features that was added to language in that version
if ((BASH_VERSINFO[0] < 4)); then 
    # Try to re-exec with a newer bash if available (common on macOS/Homebrew)
    if [ -x "/opt/homebrew/bin/bash" ]; then
        exec /opt/homebrew/bin/bash "$0" "$@"
        exit $?
    elif [ -x "/usr/local/bin/bash" ]; then
        exec /usr/local/bin/bash "$0" "$@"
        exit $?
    fi

    printf "Sorry, you need at least bash-4.0 to run gitbasher.\n\n"
    printf "Linux (Debian/Ubuntu):\n    sudo apt update && sudo apt install --only-upgrade bash\n\n"
    printf "macOS:\n    1) Install Homebrew (if missing):\n       /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"\n    2) Install newer bash:\n       brew install bash\n    3) Optional: make it your default shell (then restart Terminal):\n       sudo sh -c 'echo /opt/homebrew/bin/bash >> /etc/shells' && chsh -s /opt/homebrew/bin/bash\n\n"
    printf "Or run gitb explicitly with the newer bash when installed:\n    /opt/homebrew/bin/bash $0 \"\$@\"\n\n"
    exit 1; 
fi


### Init gitbasher
source scripts/init.sh
source scripts/common.sh


### Include all scripts
source scripts/ai.sh
source scripts/config.sh
source scripts/merge.sh
source scripts/rebase.sh
source scripts/pull.sh
source scripts/push.sh
source scripts/commit.sh
source scripts/branch.sh
source scripts/tag.sh
source scripts/reset.sh
source scripts/stash.sh
source scripts/cherry.sh
source scripts/gitlog.sh
source scripts/hooks.sh

source scripts/base.sh
