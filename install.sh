#!/usr/bin/env bash

### gitbasher installation script
# https://github.com/maxbolgarin/gitbasher

set -e

# Colors
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
ENDCOLOR="\e[0m"
BOLD="\033[1m"

# Default values
REPO="maxbolgarin/gitbasher"
VERSION="${GITB_VERSION:-latest}"
INSTALL_DIR="${GITB_INSTALL_DIR:-}"
BINARY_NAME="gitb"

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ${ENDCOLOR} $1"
}

print_success() {
    echo -e "${GREEN}✓${ENDCOLOR} $1"
}

print_error() {
    echo -e "${RED}✗${ENDCOLOR} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${ENDCOLOR} $1"
}

# Function to detect OS
detect_os() {
    case "$(uname -s)" in
        Linux*)     OS="linux";;
        Darwin*)    OS="darwin";;
        CYGWIN*|MINGW*|MSYS*) OS="windows";;
        *)          OS="unknown";;
    esac
}

# Function to detect best install location
detect_install_dir() {
    if [ -n "$INSTALL_DIR" ]; then
        echo "$INSTALL_DIR"
        return
    fi

    # Prefer /usr/local/bin if writable
    if [ -w "/usr/local/bin" ]; then
        echo "/usr/local/bin"
        return
    fi

    # Try ~/.local/bin
    if [ ! -d "$HOME/.local/bin" ]; then
        mkdir -p "$HOME/.local/bin"
    fi
    echo "$HOME/.local/bin"
}

# Function to check if directory is in PATH
check_path() {
    local dir="$1"
    if [[ ":$PATH:" == *":$dir:"* ]]; then
        return 0
    else
        return 1
    fi
}

# Function to add directory to PATH
add_to_path() {
    local dir="$1"
    local shell_rc=""

    # Detect shell
    if [ -n "$BASH_VERSION" ]; then
        if [ -f "$HOME/.bashrc" ]; then
            shell_rc="$HOME/.bashrc"
        elif [ -f "$HOME/.bash_profile" ]; then
            shell_rc="$HOME/.bash_profile"
        fi
    elif [ -n "$ZSH_VERSION" ]; then
        shell_rc="$HOME/.zshrc"
    fi

    if [ -z "$shell_rc" ]; then
        print_warning "Could not detect shell configuration file"
        print_info "Please add ${BOLD}$dir${ENDCOLOR} to your PATH manually:"
        echo -e "  ${BLUE}export PATH=\"$dir:\$PATH\"${ENDCOLOR}"
        return
    fi

    # Add to PATH if not already present
    if ! grep -q "export PATH.*$dir" "$shell_rc"; then
        echo "" >> "$shell_rc"
        echo "# gitbasher" >> "$shell_rc"
        echo "export PATH=\"$dir:\$PATH\"" >> "$shell_rc"
        print_success "Added $dir to PATH in $shell_rc"
        print_warning "Please run: ${BOLD}source $shell_rc${ENDCOLOR} or restart your terminal"
    fi
}

# Function to check dependencies
check_dependencies() {
    local missing_deps=()

    # Check bash version
    if ! command -v bash >/dev/null 2>&1; then
        missing_deps+=("bash")
    else
        bash_version=$(bash --version | head -n1 | grep -oE '[0-9]+\.[0-9]+' | head -n1)
        bash_major=$(echo "$bash_version" | cut -d. -f1)
        if [ "$bash_major" -lt 4 ]; then
            print_error "bash 4.0 or higher is required (found: $bash_version)"
            missing_deps+=("bash>=4.0")
        fi
    fi

    # Check git
    if ! command -v git >/dev/null 2>&1; then
        missing_deps+=("git")
    else
        git_version=$(git --version | grep -oE '[0-9]+\.[0-9]+' | head -n1)
        git_major=$(echo "$git_version" | cut -d. -f1)
        git_minor=$(echo "$git_version" | cut -d. -f2)
        if [ "$git_major" -lt 2 ] || ([ "$git_major" -eq 2 ] && [ "$git_minor" -lt 23 ]); then
            print_warning "git 2.23 or higher is recommended (found: $git_version)"
        fi
    fi

    # Check curl (needed for AI features)
    if ! command -v curl >/dev/null 2>&1; then
        print_warning "curl is not installed (needed for AI-powered features)"
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        echo ""
        print_info "Installation instructions:"

        if [ "$OS" = "linux" ]; then
            echo -e "  ${BLUE}# Debian/Ubuntu${ENDCOLOR}"
            echo -e "  sudo apt update && sudo apt install ${missing_deps[*]}"
            echo ""
            echo -e "  ${BLUE}# Fedora/RHEL${ENDCOLOR}"
            echo -e "  sudo dnf install ${missing_deps[*]}"
        elif [ "$OS" = "darwin" ]; then
            echo -e "  ${BLUE}# macOS with Homebrew${ENDCOLOR}"
            echo -e "  brew install ${missing_deps[*]}"
        fi

        return 1
    fi

    return 0
}

# Function to get latest release version
get_latest_version() {
    if command -v curl >/dev/null 2>&1; then
        local latest=$(curl -sSL "https://api.github.com/repos/$REPO/releases/latest" | grep -oP '"tag_name": "\K(.*)(?=")')
        if [ -n "$latest" ]; then
            echo "$latest"
            return
        fi
    fi

    # Fallback to main branch
    echo "main"
}

# Function to download gitb
download_gitb() {
    local version="$1"
    local install_path="$2"
    local url=""

    if [ "$version" = "latest" ] || [ "$version" = "main" ]; then
        # Get actual latest version
        version=$(get_latest_version)
        if [ "$version" = "main" ]; then
            # Fallback to raw main branch
            url="https://raw.githubusercontent.com/$REPO/main/dist/gitb"
            print_warning "Downloading from main branch (no releases found)"
        else
            url="https://github.com/$REPO/releases/download/$version/gitb"
            print_info "Downloading gitbasher $version..."
        fi
    else
        url="https://github.com/$REPO/releases/download/$version/gitb"
        print_info "Downloading gitbasher $version..."
    fi

    # Download
    if command -v curl >/dev/null 2>&1; then
        if ! curl -sSL "$url" -o "$install_path"; then
            print_error "Failed to download from $url"
            return 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        if ! wget -q "$url" -O "$install_path"; then
            print_error "Failed to download from $url"
            return 1
        fi
    else
        print_error "Neither curl nor wget is available"
        return 1
    fi

    chmod +x "$install_path"
    return 0
}

# Function to verify checksum (if available)
verify_checksum() {
    local version="$1"
    local install_path="$2"

    if [ "$version" = "main" ]; then
        return 0
    fi

    local checksum_url="https://github.com/$REPO/releases/download/$version/gitb.sha256"
    local expected_checksum=""

    # Try to download checksum
    if command -v curl >/dev/null 2>&1; then
        expected_checksum=$(curl -sSL "$checksum_url" 2>/dev/null | cut -d' ' -f1)
    fi

    if [ -z "$expected_checksum" ]; then
        print_warning "Checksum verification skipped (not available)"
        return 0
    fi

    # Verify checksum
    local actual_checksum=""
    if command -v sha256sum >/dev/null 2>&1; then
        actual_checksum=$(sha256sum "$install_path" | cut -d' ' -f1)
    elif command -v shasum >/dev/null 2>&1; then
        actual_checksum=$(shasum -a 256 "$install_path" | cut -d' ' -f1)
    else
        print_warning "Checksum verification skipped (no sha256sum or shasum found)"
        return 0
    fi

    if [ "$expected_checksum" != "$actual_checksum" ]; then
        print_error "Checksum verification failed!"
        print_error "Expected: $expected_checksum"
        print_error "Got:      $actual_checksum"
        return 1
    fi

    print_success "Checksum verified"
    return 0
}

# Main installation
main() {
    echo -e "${BOLD}gitbasher installer${ENDCOLOR}"
    echo ""

    # Detect OS
    detect_os

    # Check dependencies
    print_info "Checking dependencies..."
    if ! check_dependencies; then
        exit 1
    fi
    print_success "All dependencies satisfied"
    echo ""

    # Determine install directory
    INSTALL_DIR=$(detect_install_dir)
    INSTALL_PATH="$INSTALL_DIR/$BINARY_NAME"

    print_info "Install directory: ${BOLD}$INSTALL_DIR${ENDCOLOR}"

    # Check if gitb is already installed
    if [ -f "$INSTALL_PATH" ]; then
        if command -v gitb >/dev/null 2>&1; then
            current_version=$(gitb --version 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
            print_warning "gitbasher is already installed (version: $current_version)"
            read -p "Do you want to reinstall/upgrade? [y/N] " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_info "Installation cancelled"
                exit 0
            fi
        fi
    fi

    # Download gitb
    if ! download_gitb "$VERSION" "$INSTALL_PATH"; then
        exit 1
    fi

    # Verify checksum
    if ! verify_checksum "$VERSION" "$INSTALL_PATH"; then
        rm -f "$INSTALL_PATH"
        exit 1
    fi

    print_success "gitbasher installed to: ${BOLD}$INSTALL_PATH${ENDCOLOR}"
    echo ""

    # Check if install directory is in PATH
    if ! check_path "$INSTALL_DIR"; then
        print_warning "$INSTALL_DIR is not in your PATH"
        read -p "Add it to PATH automatically? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            add_to_path "$INSTALL_DIR"
        else
            print_info "Please add ${BOLD}$INSTALL_DIR${ENDCOLOR} to your PATH manually:"
            echo -e "  ${BLUE}export PATH=\"$INSTALL_DIR:\$PATH\"${ENDCOLOR}"
        fi
        echo ""
    fi

    # Verify installation
    if command -v gitb >/dev/null 2>&1 || [ -x "$INSTALL_PATH" ]; then
        installed_version=$("$INSTALL_PATH" --version 2>/dev/null | head -n1 || echo "gitbasher")
        print_success "Installation complete! 🎉"
        echo ""
        print_info "Version: ${BOLD}$installed_version${ENDCOLOR}"
        print_info "Try: ${BOLD}gitb${ENDCOLOR} or ${BOLD}gitb --help${ENDCOLOR}"
        echo ""
        print_info "Quick start:"
        echo -e "  ${BLUE}cd your-project${ENDCOLOR}"
        echo -e "  ${BLUE}gitb${ENDCOLOR}                  # See all commands"
        echo -e "  ${BLUE}gitb doctor${ENDCOLOR}           # Check your setup"
        echo -e "  ${BLUE}gitb commit${ENDCOLOR}           # Make a commit"
    else
        print_error "Installation completed but gitb command not found"
        print_info "Try running: ${BOLD}$INSTALL_PATH${ENDCOLOR}"
    fi
}

# Run main
main "$@"
