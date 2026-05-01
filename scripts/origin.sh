#!/usr/bin/env bash

### Script for managing the remote origin
# Add, change, rename, or remove the remote origin
# Useful when the repo was created without an origin, was renamed, or moved
# to another host. Use this script only with gitbasher.


### Function reads a URL from the user, validates it and sets new_url on success
# $1: prompt text (e.g. "Origin URL")
# Returns: 0 if a valid URL was entered, exits otherwise
# Sets: new_url - the validated URL
function read_remote_url {
    local prompt_text="${1:-Remote URL}"

    echo -e "Examples:"
    echo -e "  ${GRAY}https://github.com/user/repo.git${ENDCOLOR}"
    echo -e "  ${GRAY}git@github.com:user/repo.git${ENDCOLOR}"
    echo -e "  ${GRAY}ssh://git@server.com/repo.git${ENDCOLOR}"
    echo
    echo -e "Press Enter to cancel"
    read -p "${prompt_text}: " -e raw_url

    if [ -z "$raw_url" ]; then
        exit
    fi

    if ! validate_git_url "$raw_url"; then
        echo
        echo -e "${RED}Invalid git URL format!${ENDCOLOR}" >&2
        echo -e "${YELLOW}Expected one of:${ENDCOLOR}" >&2
        echo -e "  https://host/user/repo.git" >&2
        echo -e "  git@host:user/repo.git" >&2
        echo -e "  ssh://git@host/repo.git" >&2
        exit 1
    fi

    new_url="$validated_url"
}


### Function checks that a remote URL is reachable as a git repository
# $1: URL to check
# Returns: 0 if reachable (even if empty), 1 if not a git repo
# Echoes a warning when repo is empty
function check_remote_reachable {
    local url="$1"
    local check
    check=$(git ls-remote "$url" 2>&1)

    if [[ "$check" == *"does not appear to be a git"* ]]; then
        echo -e "${RED}'$url' is not a git repository!${ENDCOLOR}" >&2
        echo -e "${YELLOW}Check the URL and that you have access to it.${ENDCOLOR}" >&2
        return 1
    fi

    if [ -z "$check" ]; then
        echo -e "${YELLOW}Note: repository '$url' appears to be empty${ENDCOLOR}"
    fi
    return 0
}


### Show all configured remotes
function origin_show {
    local remotes
    remotes=$(git remote)

    if [ -z "$remotes" ]; then
        echo -e "${YELLOW}No remotes configured in this repo${ENDCOLOR}"
        echo
        echo -e "Add one with: ${GREEN}gitb origin set${ENDCOLOR}"
        return
    fi

    echo -e "${YELLOW}Configured remotes:${ENDCOLOR}"
    while IFS= read -r name; do
        local url
        url=$(git config --get "remote.${name}.url")
        echo -e "  ${BLUE}${name}${ENDCOLOR}\t${url}"
    done <<< "$remotes"

    local repo_url
    repo_url=$(get_repo)
    if [ -n "$repo_url" ]; then
        echo
        echo -e "${YELLOW}Web URL:${ENDCOLOR}\t${repo_url}"
    fi
}


### Add a new origin (errors out if origin already exists)
# $1: optional URL to use without prompting
function origin_set {
    local existing
    existing=$(git remote get-url origin 2>/dev/null)
    if [ -n "$existing" ]; then
        echo -e "${YELLOW}Origin already configured:${ENDCOLOR} ${BLUE}$existing${ENDCOLOR}"
        echo
        echo -e "Use ${GREEN}gitb origin change${ENDCOLOR} to update the URL"
        echo -e "Use ${GREEN}gitb origin remove${ENDCOLOR} to delete it first"
        exit 1
    fi

    if [ -n "$1" ]; then
        if ! validate_git_url "$1"; then
            echo -e "${RED}Invalid git URL format: $1${ENDCOLOR}" >&2
            exit 1
        fi
        new_url="$validated_url"
    else
        echo -e "Add a remote origin"
        echo
        read_remote_url "Origin URL"
    fi

    echo
    echo -e "${YELLOW}Verifying remote...${ENDCOLOR}"
    if ! check_remote_reachable "$new_url"; then
        exit 1
    fi

    git remote add origin "$new_url"
    echo
    echo -e "${GREEN}Origin added:${ENDCOLOR} ${BLUE}$new_url${ENDCOLOR}"
}


### Change the URL of an existing remote
# $1: optional URL to use without prompting
function origin_change {
    local target_remote="${origin_name:-origin}"
    local existing
    existing=$(git remote get-url "$target_remote" 2>/dev/null)

    if [ -z "$existing" ]; then
        # Fall back to the first available remote
        target_remote=$(git remote | head -n 1)
        if [ -n "$target_remote" ]; then
            existing=$(git remote get-url "$target_remote" 2>/dev/null)
        fi
    fi

    if [ -z "$existing" ]; then
        echo -e "${YELLOW}No remote configured${ENDCOLOR}"
        echo
        echo -e "Use ${GREEN}gitb origin set${ENDCOLOR} to add one"
        exit 1
    fi

    echo -e "Remote: ${BLUE}$target_remote${ENDCOLOR}"
    echo -e "Current URL: ${GRAY}$existing${ENDCOLOR}"
    echo

    if [ -n "$1" ]; then
        if ! validate_git_url "$1"; then
            echo -e "${RED}Invalid git URL format: $1${ENDCOLOR}" >&2
            exit 1
        fi
        new_url="$validated_url"
    else
        read_remote_url "New URL"
    fi

    if [ "$new_url" == "$existing" ]; then
        echo
        echo -e "${YELLOW}URL unchanged${ENDCOLOR}"
        exit
    fi

    echo
    echo -e "${YELLOW}Verifying remote...${ENDCOLOR}"
    if ! check_remote_reachable "$new_url"; then
        exit 1
    fi

    git remote set-url "$target_remote" "$new_url"
    echo
    echo -e "${GREEN}Remote URL updated${ENDCOLOR}"
    echo -e "  ${GRAY}$existing${ENDCOLOR}"
    echo -e "  ${GREEN}->${ENDCOLOR} ${BLUE}$new_url${ENDCOLOR}"
}


### Rename a remote (e.g. origin -> upstream)
# $1: optional new name to use without prompting
function origin_rename {
    local current_name="${origin_name:-origin}"
    if [ -z "$(git remote get-url "$current_name" 2>/dev/null)" ]; then
        current_name=$(git remote | head -n 1)
    fi

    if [ -z "$current_name" ]; then
        echo -e "${YELLOW}No remote configured${ENDCOLOR}"
        exit 1
    fi

    local current_url
    current_url=$(git remote get-url "$current_name")

    echo -e "Current name: ${BLUE}$current_name${ENDCOLOR}"
    echo -e "URL: ${GRAY}$current_url${ENDCOLOR}"
    echo

    local raw_name="$1"
    if [ -z "$raw_name" ]; then
        echo -e "Press Enter to cancel"
        read -p "New name: " -e raw_name
        if [ -z "$raw_name" ]; then
            exit
        fi
    fi

    if ! sanitize_git_name "$raw_name"; then
        show_sanitization_error "remote name" "Use letters, numbers, dots, dashes, and underscores."
        exit 1
    fi
    local new_name="$sanitized_git_name"

    if [ "$new_name" == "$current_name" ]; then
        echo
        echo -e "${YELLOW}Name unchanged${ENDCOLOR}"
        exit
    fi

    if [ -n "$(git remote get-url "$new_name" 2>/dev/null)" ]; then
        echo
        echo -e "${RED}Remote '$new_name' already exists${ENDCOLOR}" >&2
        exit 1
    fi

    git remote rename "$current_name" "$new_name"
    echo
    echo -e "${GREEN}Remote renamed:${ENDCOLOR} ${GRAY}$current_name${ENDCOLOR} ${GREEN}->${ENDCOLOR} ${BLUE}$new_name${ENDCOLOR}"
}


### Remove an existing remote
function origin_remove {
    local target="${origin_name:-origin}"
    local existing
    existing=$(git remote get-url "$target" 2>/dev/null)

    if [ -z "$existing" ]; then
        target=$(git remote | head -n 1)
        if [ -z "$target" ]; then
            echo -e "${YELLOW}No remotes to remove${ENDCOLOR}"
            exit
        fi
        existing=$(git remote get-url "$target")
    fi

    echo -e "Remote: ${BLUE}$target${ENDCOLOR}"
    echo -e "URL: ${GRAY}$existing${ENDCOLOR}"
    echo
    echo -e "Are you sure you want to remove this remote (y/n)?"
    yes_no_choice "" "true"

    git remote remove "$target"
    echo
    echo -e "${GREEN}Remote '$target' removed${ENDCOLOR}"
}


### Main function
# $1: mode
    # <empty>|show: show configured remotes
    # set: add a new origin (errors if one already exists)
    # change: change the URL of the existing origin
    # rename: rename a remote
    # remove: delete a remote
# $2: optional URL/name (skips interactive prompt)
function origin_script {
    case "$1" in
        ""|show|info)             show_origin="true";;
        set|add|new|a)            set_origin="true";;
        change|update|c|u|set-url) change_origin="true";;
        rename|mv|ren)            rename_origin="true";;
        remove|delete|rm|del|d)   remove_origin="true";;
        help|h)                   help="true";;
        *)
            wrong_mode "origin" $1
    esac

    ### Print header
    header="GIT ORIGIN"
    if [ -n "${set_origin}" ]; then
        header="$header SET"
    elif [ -n "${change_origin}" ]; then
        header="$header CHANGE"
    elif [ -n "${rename_origin}" ]; then
        header="$header RENAME"
    elif [ -n "${remove_origin}" ]; then
        header="$header REMOVE"
    fi

    echo -e "${YELLOW}${header}${ENDCOLOR}"
    echo

    if [ -n "$help" ]; then
        echo -e "usage: ${YELLOW}gitb origin <mode> [<url>|<name>]${ENDCOLOR}"
        echo
        msg="${YELLOW}Mode${ENDCOLOR}_${GREEN}Aliases${ENDCOLOR}_\t${BLUE}Description${ENDCOLOR}"
        msg="$msg\n${BOLD}<empty>${ENDCOLOR}_show|info_Show configured remotes"
        msg="$msg\n${BOLD}set${ENDCOLOR}_add|new|a_Add a new origin (fails if origin already set)"
        msg="$msg\n${BOLD}change${ENDCOLOR}_update|c|u|set-url_Change existing origin URL (after repo rename or move)"
        msg="$msg\n${BOLD}rename${ENDCOLOR}_mv|ren_Rename a remote (e.g. origin -> upstream)"
        msg="$msg\n${BOLD}remove${ENDCOLOR}_rm|del|d_Remove the remote"
        msg="$msg\n${BOLD}help${ENDCOLOR}_h_Show this help"
        echo -e "$(echo -e "$msg" | column -ts '_')"
        exit
    fi

    if [ -n "$show_origin" ]; then
        origin_show
        exit
    fi

    if [ -n "$set_origin" ]; then
        origin_set "$2"
        exit
    fi

    if [ -n "$change_origin" ]; then
        origin_change "$2"
        exit
    fi

    if [ -n "$rename_origin" ]; then
        origin_rename "$2"
        exit
    fi

    if [ -n "$remove_origin" ]; then
        origin_remove
        exit
    fi
}
