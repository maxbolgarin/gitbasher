#!/usr/bin/env bash

### Script for initializing gitbasher
# Run it before using gitbasher

### Consts for colors
# Use octal \033 (not \e): both `echo -e` and `printf '%b'` interpret \033 on
# every bash, whereas \e is a bash extension that bash 3.2's `printf %b` leaves
# literal — which would emit raw "\e[31m" to the terminal there.
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
PURPLE="\033[35m"
CYAN="\033[36m"
GRAY="\033[37m"
ENDCOLOR="\033[0m"
BOLD="\033[1m"
NORMAL="\033[0m"


### Function tries to get config from local, then from global, then returns default
# $1: config name
# $2: default value
# Returns: config value
function get_config_value {
    # Outside a repo (gitb config / update / uninstall / clone, or the early
    # phase of gitb clone before it has cd'd in) --local prints "fatal:
    # --local can only be used inside a git repository" to stderr. Quiet both
    # --local and --global so non-repo help / config prints aren't spammed.
    value=$(git config --local --get "$1" 2>/dev/null)
    if [ "$value" == "" ]; then
        value=$(git config --global --get "$1" 2>/dev/null)
        if [ "$value" == "" ]; then
            value=$2
        fi
    fi
    # printf, not echo -e: config values must round-trip verbatim (echo -e
    # would expand backslash sequences and swallow values like "-n").
    printf '%s\n' "$value"
}


### Function sets git config value
# $1: name
# $2: value
# $3: global flag
# Returns: value
# When running outside a git repository (GITBASHER_NO_REPO=true) every write
# is routed to --global, since --local would fail with no .git/config to write.
function set_config_value {
    if [ -z "$3" ] && [ "$GITBASHER_NO_REPO" != "true" ]; then
        git config --local "$1" "$2"
    else
        git config --global "$1" "$2"
    fi
    printf '%s\n' "$2"
}


### Function to unset git config value
# $1: config name
# Returns: value
function unset_config_value {
    if [ "$GITBASHER_NO_REPO" = "true" ]; then
        git config --global --unset "$1" 2>/dev/null
        return
    fi

    git config --unset "$1"

    # Check if global config exists and ask user if they want to clear it
    # too. This must not exit on decline — callers still print their own
    # local-clear confirmation afterwards.
    local global_config=$(git config --global --get "$1" 2>/dev/null)
    if [ -n "$global_config" ]; then
        echo
        echo -e "${YELLOW}Global $1 is also configured: ${BLUE}$global_config${ENDCOLOR}"
        echo -e "Do you want to clear it ${YELLOW}globally${ENDCOLOR} for all projects (y/n)?"
        local _unset_key=""
        read_key _unset_key || _unset_key="n"
        if is_yes "$_unset_key"; then
            git config --global --unset "$1" 2>/dev/null
            echo -e "${GREEN}✓ Cleared $1 globally${ENDCOLOR}"
        fi
    fi
}


### Function to validate git remote URL
# $1: URL string
# Returns: 0 if valid URL format, 1 if invalid
# Sets: validated_url global variable
function validate_git_url {
    local input="$1"
    validated_url=""
    
    if [ -z "$input" ]; then
        return 1
    fi
    
    # Remove dangerous characters first
    local cleaned=$(echo "$input" | tr -d '\000-\037\177')
    
    # Basic validation for common git URL formats:
    # https://github.com/user/repo.git
    # git@github.com:user/repo.git
    # ssh://git@server.com/repo.git
    # /path/to/repo.git (local)
    if [[ "$cleaned" =~ ^https?://[a-zA-Z0-9.-]+/[a-zA-Z0-9._/-]+(\.git)?$ ]] || \
       [[ "$cleaned" =~ ^git@[a-zA-Z0-9.-]+:[a-zA-Z0-9._/-]+(\.git)?$ ]] || \
       [[ "$cleaned" =~ ^ssh://[a-zA-Z0-9@.-]+/[a-zA-Z0-9._/-]+(\.git)?$ ]] || \
       [[ "$cleaned" =~ ^[a-zA-Z0-9._/-]+(\.git)?$ ]]; then
        
        # Length check
        if [ ${#cleaned} -le 500 ]; then
            validated_url="$cleaned"
            return 0
        fi
    fi
    
    return 1
}


# GITBASHER_SKIP_INIT_QUERIES — internal, test-only. Set by the bats helper
# `source_gitbasher_lite` (tests/setup_suite.bash) so that pure string-helper
# tests (sanitization, URL validation, keyboard handling) can source the
# helper functions above without paying the ~150ms tax of probing git config
# / remotes / branches. Not a user-facing knob; values other than empty are
# treated as "skip", but no public guarantee is made about specific values.
#
# `gitb clone` also lands here from outside any git repo so that clone_script
# can reuse helpers like validate_git_url, so additionally bail when there is
# no enclosing repo to query. `return 0` only works because this file is
# `source`d in tests; in the built `gitb` binary all sources are inlined so a
# bare top-level `return` would fail — the per-repo block below is therefore
# also wrapped in an explicit guard.
_gitb_init_run_queries="true"
if [ -n "$GITBASHER_SKIP_INIT_QUERIES" ]; then
    _gitb_init_run_queries=""
    return 0
fi
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    _gitb_init_run_queries=""
fi


if [ -n "$_gitb_init_run_queries" ]; then

### Branches
current_branch=$(git branch --show-current)

### The main/master auto-detection only applies when the user has not set
### a default branch — an explicit gitbasher.branch must never be
### overridden (a repo with master but no main used to force "master"
### even after `gitb cfg default`). The "+" in the bracket class covers
### branches checked out in linked worktrees.
main_branch=$(get_config_value gitbasher.branch "")
if [ "$main_branch" == "" ]; then
    main_branch="main"
    if [[ "$( git branch | grep -E "^[[:space:]*+]*main[[:space:]]*$" )" == "" ]] && [[ "$( git branch | grep -E "^[[:space:]*+]*master[[:space:]]*$" )" != "" ]]; then
        main_branch="master"
    elif [[ "$(git branch | cat)" == "" ]]; then
        main_branch=$current_branch
    fi
    git config --local gitbasher.branch "$main_branch"
fi


### Remote — prefer "origin" when it exists. `git remote | head -1` is
### alphabetical, so a remote named e.g. "backup" would otherwise hijack
### every push/pull/URL target.
if git remote | grep -qx "origin"; then
    origin_name="origin"
else
    origin_name=$(git remote | head -n 1)
fi
if [ "$origin_name" == "" ]; then
    # Skip interactive prompt if in test mode or stdin is not a TTY (e.g., in tests or scripts)
    if [ -z "$GITBASHER_TEST_MODE" ] && [ -t 0 ]; then
        # Interactive mode: prompt user for remote setup
        echo -e "${YELLOW}⚠  No remote is configured in this repo.${ENDCOLOR}"
        echo
        echo -e "Add one with: ${GREEN}git remote add origin <url>${ENDCOLOR}"
        echo -e "Press ${BOLD}y${NORMAL} to add one now, or any other key to exit"

        read -n 1 -s choice
        if ! is_yes "$choice"; then
            exit
        fi

        echo

        read_editable_input remote_url "Remote repo URL: "

        if [ "$remote_url" == "" ]; then
            exit
        fi

        # Validate remote URL format
        if ! validate_git_url "$remote_url"; then
            echo
            echo -e "${RED}✗ Invalid git URL format.${ENDCOLOR}"
            echo -e "${YELLOW}Expected one of:${ENDCOLOR}"
            echo -e "  • https://github.com/user/repo.git"
            echo -e "  • git@github.com:user/repo.git"
            echo -e "  • ssh://git@server.com/repo.git"
            exit 1
        fi
        remote_url="$validated_url"

        remote_check=$(git ls-remote "$remote_url" 2>&1)
        if [[ "$remote_check" == *"does not appear to be a git"* ]]; then
            echo
            echo -e "${RED}✗ '$remote_url' is not a git repository.${ENDCOLOR}"
            echo "Make sure you have the correct access rights and that the repo exists."
            exit 1
        fi

        git remote add origin "$remote_url"
        echo -e "${GREEN}✓ Added remote origin${ENDCOLOR}"
        if [ "$remote_check" == "" ]; then
            echo -e "${YELLOW}⚠  Repository '$remote_url' appears to be empty.${ENDCOLOR}"
        fi
        echo

        origin_name="origin"
    else
        # Non-interactive mode: skip remote setup, leave origin_name empty
        origin_name=""
    fi
fi


### Get configuration from git config
sep=$(get_config_value gitbasher.sep "-")
editor=$(get_config_value core.editor "vi")
ticket_name=$(get_config_value gitbasher.ticket "")
scopes=$(get_config_value gitbasher.scopes "")

# Re-validate scopes at the read boundary. `gitb cfg scopes` validates inputs
# at write time, but a user can also `git config gitbasher.scopes "..."`
# directly and bypass that. Anything that ends up here flows into AI prompts,
# so we silently drop invalid values rather than risk prompt injection or
# corrupted scope tags in commit messages.
if [ -n "$scopes" ]; then
    if ! validate_scope_list "$scopes" >/dev/null 2>&1; then
        scopes=""
    else
        scopes="$validated_scopes"
    fi
fi


### Is this is a first run of gitbasher in this project?
is_first=$(get_config_value gitbasher.isfirst "true")
git config --local gitbasher.isfirst "false"

else
    # No-repo mode (gitb config / update / uninstall / clone): downstream
    # readers like print_configuration still consume these globals, so seed
    # sensible defaults pulled from --global config. is_first stays false so
    # the first-run welcome (which writes to .git/config) doesn't fire.
    current_branch=""
    main_branch=$(get_config_value gitbasher.branch "main")
    origin_name=""
    sep=$(get_config_value gitbasher.sep "-")
    editor=$(get_config_value core.editor "vi")
    ticket_name=$(get_config_value gitbasher.ticket "")
    scopes=$(get_config_value gitbasher.scopes "")
    if [ -n "$scopes" ]; then
        if ! validate_scope_list "$scopes" >/dev/null 2>&1; then
            scopes=""
        else
            scopes="$validated_scopes"
        fi
    fi
    is_first="false"
fi
unset _gitb_init_run_queries
