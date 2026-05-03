#!/usr/bin/env bash
# Install gitb shell completions.
#
# Usage:
#   completion/install.sh                # auto-detect from $SHELL
#   completion/install.sh bash zsh fish  # install specific shells
#   completion/install.sh --uninstall    # remove installed completions

set -eu

DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -t 1 ]; then
    GREEN=$'\033[32m'; YELLOW=$'\033[33m'; CYAN=$'\033[36m'; OFF=$'\033[0m'
else
    GREEN=""; YELLOW=""; CYAN=""; OFF=""
fi

info() { printf "%s==>%s %s\n" "$CYAN" "$OFF" "$*"; }
ok()   { printf "%s✓%s %s\n"   "$GREEN" "$OFF" "$*"; }
warn() { printf "%s!%s %s\n"   "$YELLOW" "$OFF" "$*" >&2; }

UNINSTALL=0
SHELLS=()

for arg in "$@"; do
    case "$arg" in
        --uninstall|-u) UNINSTALL=1 ;;
        bash|zsh|fish)  SHELLS+=("$arg") ;;
        *) printf "Unknown argument: %s\n" "$arg" >&2; exit 2 ;;
    esac
done

if [ ${#SHELLS[@]} -eq 0 ]; then
    case "${SHELL##*/}" in
        bash|zsh|fish) SHELLS=("${SHELL##*/}") ;;
        *) info "Could not detect shell from \$SHELL=$SHELL — defaulting to bash, zsh, fish."
           SHELLS=(bash zsh fish) ;;
    esac
fi

# bash
target_bash() {
    if command -v brew >/dev/null 2>&1; then
        printf "%s/etc/bash_completion.d/gitb" "$(brew --prefix)"
    else
        printf "%s/.local/share/bash-completion/completions/gitb" "$HOME"
    fi
}

# zsh — drop into the first user-writable directory on $fpath
target_zsh() {
    printf "%s/.zsh/completions/_gitb" "$HOME"
}

target_fish() {
    printf "%s/.config/fish/completions/gitb.fish" "$HOME"
}

install_one() {
    local shell="$1" src="$2" dest
    case "$shell" in
        bash) dest="$(target_bash)" ;;
        zsh)  dest="$(target_zsh)"  ;;
        fish) dest="$(target_fish)" ;;
    esac

    if [ "$UNINSTALL" -eq 1 ]; then
        if [ -e "$dest" ]; then
            rm -f "$dest"
            ok "Removed $dest"
        else
            warn "$shell: nothing to remove at $dest"
        fi
        return
    fi

    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    ok "Installed $shell completion to $dest"

    case "$shell" in
        zsh)
            warn "Make sure $(dirname "$dest") is on \$fpath. Add to ~/.zshrc if missing:"
            printf "    fpath=(%s \$fpath)\n    autoload -Uz compinit && compinit\n" "$(dirname "$dest")"
            ;;
    esac
}

for sh in "${SHELLS[@]}"; do
    case "$sh" in
        bash) install_one bash "$DIR/gitb.bash" ;;
        zsh)  install_one zsh  "$DIR/gitb.zsh"  ;;
        fish) install_one fish "$DIR/gitb.fish" ;;
    esac
done

if [ "$UNINSTALL" -ne 1 ]; then
    info "Restart your shell (or 'source' your rc file) to activate completions."
fi
