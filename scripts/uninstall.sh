#!/usr/bin/env bash

### Script for uninstalling gitbasher
# Removes all gitbasher.* git config entries (local + global) and deletes the
# installed gitb binary. Reuses _gitb_install_path / _gitb_is_npm_install from
# update.sh, so this file must be sourced after update.sh.


### List every gitbasher.* config key at a given scope.
# $1: --local or --global
function _gitb_uninstall_list_keys {
    local scope="$1"
    git config "$scope" --get-regexp '^gitbasher\.' 2>/dev/null | awk '{print $1}' | sort -u
}


### Delete a single bin path, escalating to sudo when the user can't write to it.
# $1: absolute path to remove
# Returns: 0 on success, 1 otherwise
function _gitb_uninstall_remove_binary {
    local path="$1"
    [ -z "$path" ] && return 1

    if rm -f "$path" 2>/dev/null && [ ! -e "$path" ]; then
        return 0
    fi

    if [ -e "$path" ] && command -v sudo >/dev/null 2>&1; then
        echo -e "${YELLOW}Removing ${path} requires sudo — you may be prompted for your password.${ENDCOLOR}"
        if sudo rm -f "$path"; then
            return 0
        fi
    fi
    return 1
}


### Main entry point for `gitb uninstall`.
# $1: mode (empty | help)
function uninstall_script {
    case "$1" in
        help|h) help="true" ;;
        "")     ;;
        *)      wrong_mode "uninstall" $1 ;;
    esac

    echo -e "${YELLOW}GITBASHER UNINSTALL${ENDCOLOR}"
    echo

    if [ -n "$help" ]; then
        # kcov-skip-start
        echo -e "usage: ${YELLOW}gitb uninstall${ENDCOLOR}"
        echo
        echo -e "Removes all ${BLUE}gitbasher.*${ENDCOLOR} entries from your local and global"
        echo -e "git config and deletes the installed ${BLUE}gitb${ENDCOLOR} binary."
        echo
        local PAD=10
        print_help_header $PAD
        print_help_row $PAD "<empty>" "" "Remove gitbasher config + binary (asks for confirmation)"
        print_help_row $PAD "help"    "h" "Show this help"
        echo
        echo -e "${YELLOW}Notes${ENDCOLOR}"
        echo -e "  - npm-installed gitb is detected and the npm command is shown instead."
        echo -e "  - Dev runs (from ${BLUE}scripts/gitb.sh${ENDCOLOR}) only clean config; the source tree is left alone."
        exit
        # kcov-skip-end
    fi

    local local_keys global_keys local_count global_count binary_path
    local_keys=$(_gitb_uninstall_list_keys --local)
    global_keys=$(_gitb_uninstall_list_keys --global)
    local_count=0
    global_count=0
    [ -n "$local_keys" ]  && local_count=$(printf '%s\n' "$local_keys" | grep -c .)
    [ -n "$global_keys" ] && global_count=$(printf '%s\n' "$global_keys" | grep -c .)

    binary_path=$(_gitb_install_path 2>/dev/null)
    # Don't delete a dev checkout (./scripts/gitb.sh) — that's the source repo.
    if [ "$GITBASHER_VERSION" = "dev" ]; then
        binary_path=""
    fi

    if [ "$local_count" -eq 0 ] && [ "$global_count" -eq 0 ] && [ -z "$binary_path" ]; then
        echo -e "${GREEN}✓ Nothing to uninstall — no gitbasher config or binary found.${ENDCOLOR}"
        exit
    fi

    echo -e "This will:"
    if [ "$local_count" -gt 0 ]; then
        echo -e "  ${BOLD}•${ENDCOLOR} Remove ${YELLOW}${local_count}${ENDCOLOR} ${BLUE}gitbasher.*${ENDCOLOR} key(s) from this repo's git config"
    fi
    if [ "$global_count" -gt 0 ]; then
        echo -e "  ${BOLD}•${ENDCOLOR} Remove ${YELLOW}${global_count}${ENDCOLOR} ${BLUE}gitbasher.*${ENDCOLOR} key(s) from your global git config"
    fi
    if [ -n "$binary_path" ]; then
        if _gitb_is_npm_install "$binary_path"; then
            echo -e "  ${BOLD}•${ENDCOLOR} ${YELLOW}gitb${ENDCOLOR} is installed via npm at ${BLUE}${binary_path}${ENDCOLOR}"
            echo -e "    ${GRAY}Run ${GREEN}npm uninstall -g gitbasher${GRAY} after this to finish removing it.${ENDCOLOR}"
        else
            echo -e "  ${BOLD}•${ENDCOLOR} Delete the ${YELLOW}gitb${ENDCOLOR} binary at ${BLUE}${binary_path}${ENDCOLOR}"
        fi
    fi
    echo
    echo -e "${RED}⚠  This cannot be undone.${ENDCOLOR}"
    echo -e "Type ${YELLOW}${BOLD}delete${ENDCOLOR} to confirm (anything else cancels)."
    local confirm_input
    read_editable_input confirm_input "Confirm: "
    # Trim leading/trailing whitespace; case-insensitive match against "delete"
    confirm_input="${confirm_input#"${confirm_input%%[![:space:]]*}"}"
    confirm_input="${confirm_input%"${confirm_input##*[![:space:]]}"}"
    if [ "${confirm_input,,}" != "delete" ]; then
        echo
        echo -e "${YELLOW}Cancelled — nothing was changed.${ENDCOLOR}"
        exit 0
    fi
    echo
    echo -e "${YELLOW}Uninstalling...${ENDCOLOR}"

    if [ "$local_count" -gt 0 ]; then
        while IFS= read -r key; do
            [ -n "$key" ] && git config --local --unset-all "$key" 2>/dev/null
        done <<< "$local_keys"
        # `--remove-section` cleans up the now-empty [gitbasher] header.
        git config --local --remove-section gitbasher 2>/dev/null || true
        echo -e "${GREEN}✓ Removed ${BLUE}gitbasher.*${GREEN} from this repo's git config${ENDCOLOR}"
    fi

    if [ "$global_count" -gt 0 ]; then
        while IFS= read -r key; do
            [ -n "$key" ] && git config --global --unset-all "$key" 2>/dev/null
        done <<< "$global_keys"
        git config --global --remove-section gitbasher 2>/dev/null || true
        echo -e "${GREEN}✓ Removed ${BLUE}gitbasher.*${GREEN} from your global git config${ENDCOLOR}"
    fi

    if [ -n "$binary_path" ]; then
        if _gitb_is_npm_install "$binary_path"; then
            echo
            echo -e "${YELLOW}⚠  Finish removing the binary with:${ENDCOLOR}"
            echo -e "  ${GREEN}npm uninstall -g gitbasher${ENDCOLOR}"
        elif _gitb_uninstall_remove_binary "$binary_path"; then
            echo -e "${GREEN}✓ Deleted ${BLUE}${binary_path}${ENDCOLOR}"
        else
            echo -e "${RED}✗ Could not delete ${binary_path}.${ENDCOLOR}"
            echo -e "Remove it manually with: ${GREEN}sudo rm ${binary_path}${ENDCOLOR}"
        fi
    fi

    echo
    echo -e "${GREEN}gitbasher uninstalled. Thanks for trying it!${ENDCOLOR}"
    exit 0
}
