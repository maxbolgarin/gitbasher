#!/usr/bin/env bash

### Script for `gitb edit` — rewrite the last commit message via
### `git commit --amend`. Previously exposed as `gitb commit last`.
### Use this script only with gitbasher.


function edit_script {
    case "$1" in
        help|h|--help|-h)
            echo -e "${YELLOW}GIT EDIT${ENDCOLOR}"
            echo
            echo -e "usage: ${YELLOW}gitb edit${ENDCOLOR}"
            echo
            echo -e "Opens ${GREEN}git commit --amend${ENDCOLOR} so you can rewrite the message of the"
            echo -e "last commit in your editor. The working tree is not touched."
            echo
            echo -e "${YELLOW}Notes${ENDCOLOR}"
            echo -e "  ${BLUE}•${ENDCOLOR} If the commit was already pushed, you'll need ${YELLOW}gitb push force${ENDCOLOR} after."
            echo -e "  ${BLUE}•${ENDCOLOR} To add staged changes into the last commit, use ${YELLOW}gitb commit amend${ENDCOLOR}."
            echo -e "  ${BLUE}•${ENDCOLOR} To undo the amend, use ${YELLOW}gitb undo amend${ENDCOLOR}."
            exit 0
            ;;
        "")
            ;;
        *)
            wrong_mode "edit" "$1"
            ;;
    esac

    echo -e "${YELLOW}GIT EDIT${ENDCOLOR}"
    echo

    ### Refuse in detached-HEAD: amend there creates an unreachable commit.
    warn_if_detached_head "edit"

    ### Require at least one commit on the current branch.
    if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
        echo -e "${RED}✗ No commits yet — nothing to edit.${ENDCOLOR}"
        exit 1
    fi

    ### Clean up any cached git-add args from a prior aborted commit flow.
    git config --unset gitbasher.cached-git-add 2>/dev/null

    git commit --amend
}
