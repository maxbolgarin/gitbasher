#!/usr/bin/env bash
# gitbasher installer
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/maxbolgarin/gitbasher/master/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/maxbolgarin/gitbasher/master/install.sh | bash -s -- --sudo
#
# Flags:
#   --sudo         Install system-wide to /usr/local/bin (uses sudo if needed)
#
# Environment:
#   GITB_VERSION   Tag to install (default: latest)
#   GITB_DIR       Target directory (default: ~/.local/bin, or /usr/local/bin with --sudo)
#   GITB_SUDO      Set to 1 for system-wide install (same as --sudo)
#   GITB_NO_SUDO   Set to 1 to forbid sudo even when needed (kept for back-compat)

set -eu

REPO="maxbolgarin/gitbasher"
VERSION="${GITB_VERSION:-latest}"
TARGET_DIR="${GITB_DIR:-}"
USE_SUDO="${GITB_SUDO:-0}"
NO_SUDO="${GITB_NO_SUDO:-0}"

for arg in "$@"; do
    case "$arg" in
        --sudo)    USE_SUDO=1 ;;
        --no-sudo) NO_SUDO=1 ;;
        -h|--help)
            sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) printf "Unknown argument: %s\n" "$arg" >&2; exit 2 ;;
    esac
done

if [ "$USE_SUDO" = "1" ] && [ "$NO_SUDO" = "1" ]; then
    printf "Conflicting options: --sudo and --no-sudo (or GITB_SUDO/GITB_NO_SUDO).\n" >&2
    exit 2
fi

if [ -t 1 ]; then
    RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'
    CYAN=$'\033[36m'; BOLD=$'\033[1m'; OFF=$'\033[0m'
else
    RED=""; GREEN=""; YELLOW=""; CYAN=""; BOLD=""; OFF=""
fi

info()  { printf "%s==>%s %s\n" "$CYAN" "$OFF" "$*"; }
ok()    { printf "%s✓%s %s\n"   "$GREEN" "$OFF" "$*"; }
warn()  { printf "%s!%s %s\n"   "$YELLOW" "$OFF" "$*" >&2; }
die()   { printf "%s✗%s %s\n"   "$RED" "$OFF" "$*" >&2; exit 1; }

### --- preflight ---

case "$(uname -s)" in
    Linux|Darwin) ;;
    *) die "Unsupported OS: $(uname -s). On Windows use WSL." ;;
esac

command -v git >/dev/null 2>&1 || die "git is required but not installed."

git_version=$(git --version 2>/dev/null | awk '{print $3}')
git_major=$(printf '%s' "$git_version" | cut -d. -f1)
git_minor=$(printf '%s' "$git_version" | cut -d. -f2)
if [ "${git_major:-0}" -lt 2 ] || { [ "${git_major:-0}" -eq 2 ] && [ "${git_minor:-0}" -lt 23 ]; }; then
    warn "git ${git_version} detected; gitbasher requires git 2.23+."
fi

bash_major=${BASH_VERSINFO[0]:-0}
if [ "$bash_major" -lt 4 ]; then
    warn "bash ${BASH_VERSION} detected; gitbasher requires bash 4.0+."
    case "$(uname -s)" in
        Darwin) warn "On macOS run: brew install bash" ;;
        Linux)  warn "Update via your package manager (e.g. apt install --only-upgrade bash)" ;;
    esac
fi

if command -v curl >/dev/null 2>&1; then
    DOWNLOADER="curl"
elif command -v wget >/dev/null 2>&1; then
    DOWNLOADER="wget"
else
    die "Need curl or wget to download the binary."
fi

### --- pick target dir ---

# Use sudo only when really needed and available non-interactively or with a tty.
SUDO=""
needs_sudo() {
    [ -d "$1" ] && [ ! -w "$1" ] && return 0
    [ ! -d "$1" ] && parent=$(dirname "$1") && [ -d "$parent" ] && [ ! -w "$parent" ] && return 0
    return 1
}

if [ -z "$TARGET_DIR" ]; then
    if [ "$USE_SUDO" = "1" ] || [ "$(id -u)" -eq 0 ]; then
        TARGET_DIR="/usr/local/bin"
    else
        TARGET_DIR="$HOME/.local/bin"
    fi
fi

if needs_sudo "$TARGET_DIR"; then
    if [ "$NO_SUDO" = "1" ]; then
        die "Cannot write to $TARGET_DIR without sudo. Drop --no-sudo or pick a writable GITB_DIR (e.g. \$HOME/.local/bin)."
    fi
    if ! command -v sudo >/dev/null 2>&1; then
        die "Cannot write to $TARGET_DIR and sudo is not available. Set GITB_DIR=\$HOME/.local/bin and rerun."
    fi
    SUDO="sudo"
fi

### --- resolve URL ---

if [ "$VERSION" = "latest" ]; then
    URL="https://github.com/$REPO/releases/latest/download/gitb"
else
    # accept "v1.2.3" or "1.2.3"
    case "$VERSION" in v*) ;; *) VERSION="v$VERSION" ;; esac
    URL="https://github.com/$REPO/releases/download/$VERSION/gitb"
fi

info "Installing gitbasher ($VERSION) to ${BOLD}$TARGET_DIR/gitb${OFF}"
[ -n "$SUDO" ] && warn "Requires sudo for $TARGET_DIR — you may be prompted for your password."

### --- download ---

tmp=$(mktemp 2>/dev/null || mktemp -t gitb)
trap 'rm -f "$tmp"' EXIT

case "$DOWNLOADER" in
    curl) curl -fSL --proto '=https' --tlsv1.2 -o "$tmp" "$URL" \
              || die "Download failed: $URL" ;;
    wget) wget --https-only -qO "$tmp" "$URL" \
              || die "Download failed: $URL" ;;
esac

# Sanity check: the file should look like a bash script, not an HTML 404 page.
head -c 64 "$tmp" | grep -q '^#!.*bash' \
    || die "Downloaded file is not a bash script. Check that release '$VERSION' exists."

### --- install ---

$SUDO mkdir -p "$TARGET_DIR"
$SUDO install -m 0755 "$tmp" "$TARGET_DIR/gitb"

### --- verify & PATH hint ---

if ! "$TARGET_DIR/gitb" --version >/dev/null 2>&1; then
    die "Installed binary failed to run. See $TARGET_DIR/gitb"
fi

installed=$("$TARGET_DIR/gitb" --version 2>/dev/null | head -1)
ok "Installed: $installed"

case ":$PATH:" in
    *":$TARGET_DIR:"*) ;;
    *)
        warn "$TARGET_DIR is not in your PATH."
        shell_rc=""
        case "${SHELL##*/}" in
            zsh)  shell_rc="$HOME/.zshrc" ;;
            bash) shell_rc="$HOME/.bashrc" ;;
            fish) shell_rc="$HOME/.config/fish/config.fish" ;;
        esac
        if [ -n "$shell_rc" ]; then
            printf "  Add it with: ${BOLD}echo 'export PATH=\"%s:\$PATH\"' >> %s${OFF}\n" "$TARGET_DIR" "$shell_rc"
        else
            printf "  Add ${BOLD}%s${OFF} to your PATH.\n" "$TARGET_DIR"
        fi
        ;;
esac

printf "\n${GREEN}${BOLD}Done.${OFF} Run ${BOLD}gitb${OFF} in any git repo to get started.\n"
