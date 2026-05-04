#!/usr/bin/env bash
# gitbasher installer
#
# Usage (install or upgrade):
#   curl -fsSL https://raw.githubusercontent.com/maxbolgarin/gitbasher/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/maxbolgarin/gitbasher/main/install.sh | bash -s -- --sudo
#
# Re-running this installer is the supported upgrade path: it replaces the
# existing binary in place. Pin a specific tag with GITB_VERSION=v4.0.0 (or
# any released tag); leave it unset to grab the latest release. Once installed,
# `gitb update` does the same thing without needing the curl one-liner.
#
# Flags:
#   --sudo         Install system-wide to /usr/local/bin (uses sudo if needed)
#
# Environment:
#   GITB_VERSION   Tag to install (default: latest). Use 'latest' to upgrade
#                  to the newest release, or 'v3.10.2' to roll back.
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
            sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'
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
    SHA_URL="https://github.com/$REPO/releases/latest/download/gitb.sha256"
else
    # accept "v1.2.3" or "1.2.3"
    case "$VERSION" in v*) ;; *) VERSION="v$VERSION" ;; esac
    URL="https://github.com/$REPO/releases/download/$VERSION/gitb"
    SHA_URL="https://github.com/$REPO/releases/download/$VERSION/gitb.sha256"
fi

# Detect an existing install so we can show the user what they're upgrading from
# (or rolling back to). This runs whichever `gitb` is on PATH, not specifically
# the one in $TARGET_DIR — the user might be reinstalling to a different path.
existing_version=""
if command -v gitb >/dev/null 2>&1; then
    existing_version=$(gitb --version 2>/dev/null | awk 'NR==1 {for (i=1; i<=NF; i++) if ($i ~ /^v?[0-9]/) { print $i; exit }}')
fi

if [ -n "$existing_version" ]; then
    requested="$VERSION"
    [ "$requested" = "latest" ] && requested="latest release"
    info "Upgrading gitbasher: ${BOLD}$existing_version${OFF} → ${BOLD}$requested${OFF} (target: $TARGET_DIR/gitb)"
else
    info "Installing gitbasher ($VERSION) to ${BOLD}$TARGET_DIR/gitb${OFF}"
fi
[ -n "$SUDO" ] && warn "Requires sudo for $TARGET_DIR — you may be prompted for your password."

### --- download ---

tmp=$(mktemp 2>/dev/null || mktemp -t gitb)
tmp_sha=$(mktemp 2>/dev/null || mktemp -t gitb.sha256)
trap 'rm -f "$tmp" "$tmp_sha"' EXIT

# `--max-time 60` keeps a stalled download from hanging the install indefinitely;
# `--proto '=https' --tlsv1.2` is already there to refuse plaintext downgrades.
case "$DOWNLOADER" in
    curl) curl -fSL --proto '=https' --tlsv1.2 --max-time 60 -o "$tmp" "$URL" \
              || die "Download failed: $URL" ;;
    wget) wget --https-only --timeout=60 -qO "$tmp" "$URL" \
              || die "Download failed: $URL" ;;
esac

# Sanity check: the file should look like a bash script, not an HTML 404 page.
head -c 64 "$tmp" | grep -q '^#!.*bash' \
    || die "Downloaded file is not a bash script. Check that release '$VERSION' exists."

### --- verify checksum ---
# The release pipeline (.releaserc.json) ships a `gitb.sha256` asset alongside
# `gitb`, formatted as `<sha256>  gitb`. We verify against it; if the asset is
# missing (e.g. someone published manually) we fall back to a loud warning
# rather than silently trusting the download — a balance between security and
# not breaking installs from older or hand-rolled releases.

# Pick whichever sha256 tool the platform has. macOS ships `shasum`; most
# Linux distros ship `sha256sum`; either works.
if command -v shasum >/dev/null 2>&1; then
    SHA_CMD="shasum -a 256"
elif command -v sha256sum >/dev/null 2>&1; then
    SHA_CMD="sha256sum"
else
    SHA_CMD=""
fi

if [ -n "$SHA_CMD" ]; then
    sha_fetch_ok=0
    case "$DOWNLOADER" in
        curl) curl -fSL --proto '=https' --tlsv1.2 --max-time 30 -o "$tmp_sha" "$SHA_URL" 2>/dev/null \
                  && sha_fetch_ok=1 ;;
        wget) wget --https-only --timeout=30 -qO "$tmp_sha" "$SHA_URL" 2>/dev/null \
                  && sha_fetch_ok=1 ;;
    esac
    if [ "$sha_fetch_ok" = "1" ] && [ -s "$tmp_sha" ]; then
        expected=$(awk 'NR==1 {print $1}' "$tmp_sha")
        actual=$($SHA_CMD "$tmp" | awk '{print $1}')
        if [ -z "$expected" ] || [ "$expected" != "$actual" ]; then
            die "Checksum mismatch for $URL (expected $expected, got $actual). Refusing to install."
        fi
        ok "Verified SHA-256 checksum"
    else
        warn "Could not fetch checksum from $SHA_URL — proceeding without verification."
    fi
else
    warn "Neither shasum nor sha256sum is available — proceeding without verification."
fi

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
            # Use %q so $TARGET_DIR / $shell_rc with whitespace or shell metacharacters
            # render as a safely-quoted snippet the user can paste verbatim.
            printf "  Add it with: ${BOLD}echo %q >> %q${OFF}\n" \
                "export PATH=\"$TARGET_DIR:\$PATH\"" \
                "$shell_rc"
        else
            printf "  Add ${BOLD}%q${OFF} to your PATH.\n" "$TARGET_DIR"
        fi
        ;;
esac

printf "\n${GREEN}${BOLD}Done.${OFF} Run ${BOLD}gitb${OFF} in any git repo to get started.\n"
