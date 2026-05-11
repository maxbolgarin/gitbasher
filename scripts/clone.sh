#!/usr/bin/env bash

### Script for cloning a remote repository
# Clones with progress, cds into the new directory inside the script
# process, and initializes gitbasher local config so the cloned repo is
# ready to use. The user's shell cwd cannot be changed from a child
# process, so the final message prints the `cd` command for the user.


### Function to derive a default destination directory from a git URL
# $1: validated git URL
# Echoes: destination directory name
function _gitb_clone_dest_from_url {
    local url="$1"
    # Strip optional trailing .git
    local stripped="${url%.git}"
    # Take the last path component, regardless of separator (':' for git@host:user/repo, '/' otherwise)
    local last="${stripped##*/}"
    last="${last##*:}"
    echo "$last"
}


### Function to print the clone help block
# $1: column width used by help table formatters
function _gitb_print_clone_help {
    local PAD=14
    echo -e "usage: ${YELLOW}gitb clone <url> [destination]${ENDCOLOR}"
    echo
    echo -e "Clone a remote repository, show progress, and initialize gitbasher in it."
    echo
    print_help_header $PAD
    print_help_row $PAD "<url>"         "" "Git URL to clone (https, ssh, or git@)"
    print_help_row $PAD "[destination]" "" "Optional target directory (default: repo name)"
    print_help_row $PAD "help"          "h" "Show this help"
    echo
    echo -e "${YELLOW}Examples${ENDCOLOR}"
    echo -e "  ${GREEN}gitb clone https://github.com/user/repo.git${ENDCOLOR}"
    echo -e "  ${GREEN}gitb clone git@github.com:user/repo.git my-repo${ENDCOLOR}"
    exit
}


### Main function
# $1: URL to clone (or "help")
# $2: optional destination directory
function clone_script {
    echo -e "${YELLOW}GIT CLONE${ENDCOLOR}"
    echo

    case "$1" in
        ""|help|h) _gitb_print_clone_help ;;
    esac

    local raw_url="$1"
    local dest="$2"

    if ! validate_git_url "$raw_url"; then
        echo -e "${RED}✗ Invalid git URL format: $raw_url${ENDCOLOR}" >&2
        echo -e "${YELLOW}Expected one of:${ENDCOLOR}" >&2
        echo -e "  https://host/user/repo.git" >&2
        echo -e "  git@host:user/repo.git" >&2
        echo -e "  ssh://git@host/repo.git" >&2
        exit 1
    fi
    local url="$validated_url"

    if [ -z "$dest" ]; then
        dest=$(_gitb_clone_dest_from_url "$url")
    fi

    if [ -z "$dest" ]; then
        echo -e "${RED}✗ Could not determine target directory from URL.${ENDCOLOR}" >&2
        echo -e "${YELLOW}Pass a destination explicitly: ${GREEN}gitb clone <url> <dir>${ENDCOLOR}" >&2
        exit 1
    fi

    if ! sanitize_file_path "$dest"; then
        echo -e "${RED}✗ Invalid destination path: $dest${ENDCOLOR}" >&2
        exit 1
    fi
    dest="$sanitized_file_path"

    if [ -e "$dest" ]; then
        echo -e "${RED}✗ Destination '$dest' already exists.${ENDCOLOR}" >&2
        echo -e "${YELLOW}Remove it first or pass a different destination.${ENDCOLOR}" >&2
        exit 1
    fi

    echo -e "Source: ${BLUE}$url${ENDCOLOR}"
    echo -e "Target: ${BLUE}$dest${ENDCOLOR}"
    echo

    # --progress forces a progress bar even when stderr is not a TTY (e.g. piped),
    # matching what users expect from `gitb clone`.
    if ! git clone --progress "$url" "$dest"; then
        echo
        echo -e "${RED}✗ Clone failed.${ENDCOLOR}" >&2
        exit 1
    fi

    echo
    echo -e "${GREEN}✓ Cloned into '$dest'${ENDCOLOR}"

    local target_abs
    target_abs=$(cd "$dest" 2>/dev/null && pwd)
    if [ -z "$target_abs" ]; then
        echo -e "${RED}✗ Failed to enter directory '$dest'.${ENDCOLOR}" >&2
        exit 1
    fi

    if ! cd "$target_abs"; then
        echo -e "${RED}✗ Failed to cd into '$target_abs'.${ENDCOLOR}" >&2
        exit 1
    fi

    # Initialize gitbasher's per-repo config. Mirrors the local config writes
    # in init.sh so the first interactive `gitb` invocation inside the clone
    # treats it as a fresh repo and shows the welcome banner once.
    local cloned_branch
    cloned_branch=$(git branch --show-current 2>/dev/null)
    if [ -z "$cloned_branch" ]; then
        cloned_branch="main"
    fi
    git config --local gitbasher.branch "$cloned_branch" 2>/dev/null
    git config --local gitbasher.scopes "" 2>/dev/null
    git config --local gitbasher.isfirst "true" 2>/dev/null

    echo -e "${GREEN}✓ Initialized gitbasher in '$dest'${ENDCOLOR}"
    echo
    echo -e "${CYAN}💡 Enter the new repo with:${ENDCOLOR}"
    echo -e "  ${GREEN}cd $target_abs${ENDCOLOR}"
}
