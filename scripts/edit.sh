#!/usr/bin/env bash

### Script for `gitb edit` — rewrite commit messages or the current branch
### name without changing the tree.
### Modes:
###   * default:  amend the last commit's message (`git commit --amend`)
###   * `pick`:   pick any commit from the recent history and reword it via a
###               non-interactive rebase (GIT_SEQUENCE_EDITOR rewrites the
###               chosen `pick` line into `reword`)
###   * `branch`: rename the current branch (`git branch -m`) and optionally
###               update the upstream by pushing the new name + deleting the
###               old one on the remote
### Use this script only with gitbasher.


function edit_script {
    local mode="amend"
    case "$1" in
        help|h|--help|-h)
            echo -e "${YELLOW}GIT EDIT${ENDCOLOR}"
            echo
            echo -e "usage: ${YELLOW}gitb edit [mode] [arg]${ENDCOLOR}"
            echo
            echo -e "Rewrite a commit message or rename the current branch."
            echo
            echo -e "${YELLOW}Modes${ENDCOLOR}"
            echo -e "  ${BOLD}<empty>${NORMAL}                  Reword the ${BOLD}last${NORMAL} commit (${GREEN}git commit --amend${ENDCOLOR})"
            echo -e "  ${BOLD}pick${NORMAL}   (${BOLD}p${NORMAL}, ${BOLD}c${NORMAL})         Choose any recent commit and reword it via rebase"
            echo -e "  ${BOLD}branch${NORMAL} (${BOLD}b${NORMAL}, ${BOLD}br${NORMAL}, ${BOLD}rename${NORMAL})  Rename the current branch (${GREEN}git branch -m${ENDCOLOR})"
            echo -e "  ${BOLD}help${NORMAL}   (${BOLD}h${NORMAL})               Show this help"
            echo
            echo -e "${YELLOW}Notes${ENDCOLOR}"
            echo -e "  ${BLUE}•${ENDCOLOR} ${BOLD}pick${NORMAL} requires a clean working tree (the rebase replays commits)."
            echo -e "  ${BLUE}•${ENDCOLOR} Merge commits and the root commit cannot be reworded this way."
            echo -e "  ${BLUE}•${ENDCOLOR} If a reworded commit was already pushed, run ${YELLOW}gitb push force${ENDCOLOR} afterwards."
            echo -e "  ${BLUE}•${ENDCOLOR} ${BOLD}branch${NORMAL} accepts an optional new name: ${YELLOW}gitb edit branch feat/new-name${ENDCOLOR}."
            echo -e "  ${BLUE}•${ENDCOLOR} To add staged changes into the last commit, use ${YELLOW}gitb commit amend${ENDCOLOR}."
            echo -e "  ${BLUE}•${ENDCOLOR} To undo the amend/rebase, use ${YELLOW}gitb undo amend${ENDCOLOR} / ${YELLOW}gitb undo rebase${ENDCOLOR}."
            exit 0
            ;;
        "")
            ;;
        pick|p|c|choose)
            mode="pick"
            ;;
        branch|b|br|rename|ren)
            mode="branch"
            ;;
        *)
            wrong_mode "edit" "$1"
            ;;
    esac

    echo -e "${YELLOW}GIT EDIT${ENDCOLOR}"
    echo

    ### Refuse in detached-HEAD: amend/rebase/rename all need a branch.
    warn_if_detached_head "edit"

    if [ "$mode" = "branch" ]; then
        edit_branch_name "$2"
        return
    fi

    ### Require at least one commit on the current branch.
    if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
        echo -e "${RED}✗ No commits yet — nothing to edit.${ENDCOLOR}"
        exit 1
    fi

    ### Clean up any cached git-add args from a prior aborted commit flow.
    git config --unset gitbasher.cached-git-add 2>/dev/null

    if [ "$mode" = "amend" ]; then
        git commit --amend
        return
    fi


    ### Pick mode: reword an arbitrary commit via non-interactive rebase.

    # Rebase refuses to run with a dirty tree; surface a friendly error early.
    local dirty
    dirty=$(LC_ALL=C git status --porcelain)
    if [ -n "$dirty" ]; then
        echo -e "${RED}✗ Working tree has uncommitted changes — cannot reword via rebase.${ENDCOLOR}"
        echo -e "Commit, stash, or save them first (try ${YELLOW}gitb wip up${ENDCOLOR})."
        exit 1
    fi

    echo -e "${YELLOW}Step 1.${ENDCOLOR} Select a commit to ${YELLOW}reword${ENDCOLOR}:"
    choose_commit 19

    if [ -z "$commit_hash" ]; then
        exit
    fi

    # If the user picked HEAD, fall back to plain --amend (no rebase needed).
    local head_hash
    head_hash=$(git rev-parse --short HEAD)
    if [ "$commit_hash" = "$head_hash" ]; then
        echo
        git commit --amend
        return
    fi

    # Merge commits can't be reworded with `pick`/`reword` lines.
    if git rev-parse --verify "${commit_hash}^2" >/dev/null 2>&1; then
        echo
        echo -e "${RED}✗ Cannot reword a merge commit via rebase.${ENDCOLOR}"
        exit 1
    fi

    # Need a parent to anchor `git rebase -i <hash>^`.
    if ! git rev-parse --verify "${commit_hash}^" >/dev/null 2>&1; then
        echo
        echo -e "${RED}✗ Cannot reword the root commit this way.${ENDCOLOR}"
        echo -e "Use ${YELLOW}git rebase -i --root${ENDCOLOR} manually."
        exit 1
    fi

    # Sequence editor: rewrite the chosen commit's `pick` line as `reword`.
    # Git evaluates GIT_SEQUENCE_EDITOR as a shell command and appends the
    # rebase-todo path as an argument, so the script gets the path in $1.
    # We invoke as `bash $script` (no shebang needed, survives bundling).
    # Use awk so we don't depend on sed -i (BSD vs GNU quirks). The hash
    # test accepts either prefix direction in case core.abbrev differs
    # between commit_list and the rebase todo.
    local seq_script
    seq_script=$(mktemp "${TMPDIR:-/tmp}/gitb-edit-seq.XXXXXX")
    chmod 600 "$seq_script"
    # Double quotes bake the path in NOW: with single quotes the trap
    # expanded $seq_script at exit time, when the local was already out of
    # scope, so every run leaked a gitb-edit-seq.* file in $TMPDIR.
    trap "rm -f '$seq_script'" EXIT INT TERM
    cat > "$seq_script" <<SEQ_EOF
todo="\$1"
tmpfile="\$(mktemp "\${todo}.XXXXXX")"
awk -v target="${commit_hash}" '
    \$1 == "pick" && (index(\$2, target) == 1 || index(target, \$2) == 1) { \$1 = "reword" }
    { print }
' "\$todo" > "\$tmpfile"
mv "\$tmpfile" "\$todo"
SEQ_EOF

    echo
    echo -e "${YELLOW}Rewording ${commit_hash}...${ENDCOLOR}"
    GIT_SEQUENCE_EDITOR="bash $seq_script" git rebase -i "${commit_hash}^"
}


### Rename the current branch via `git branch -m`, with optional remote sync.
# $1: new branch name (optional — prompts with the current name pre-filled).
function edit_branch_name {
    local new_name="$1"
    local old_name="$current_branch"

    if [ -z "$old_name" ]; then
        echo -e "${RED}✗ Could not determine the current branch.${ENDCOLOR}"
        exit 1
    fi

    if [ -z "$new_name" ]; then
        echo -e "${YELLOW}Renaming branch ${BOLD}${old_name}${NORMAL}${ENDCOLOR}"
        echo -e "Press Enter to keep the current name (no-op), or 0 to cancel"
        read_editable_input new_name "New name: " "$old_name"
        echo
        if [ "$new_name" = "0" ] || [ -z "$new_name" ]; then
            echo -e "${YELLOW}Cancelled.${ENDCOLOR}"
            exit
        fi
    fi

    if ! sanitize_git_name "$new_name"; then
        show_sanitization_error "branch name" "Use only letters, numbers, dots, dashes, underscores, and slashes."
        exit 1
    fi
    # Never rename to a silently DIFFERENT name: sanitizing strips characters
    # (e.g. non-ASCII), and pushing a mutated name publishes the wrong branch.
    if [ "$sanitized_git_name" != "$new_name" ]; then
        echo -e "${RED}✗ '${new_name}' contains characters gitbasher does not manage.${ENDCOLOR}"
        echo -e "Closest supported name: ${YELLOW}${sanitized_git_name}${ENDCOLOR} — rerun with that name to use it."
        exit 1
    fi
    new_name="$sanitized_git_name"

    if [ "$new_name" = "$old_name" ]; then
        echo -e "${YELLOW}New name matches the current name — nothing to do.${ENDCOLOR}"
        exit
    fi

    # Don't silently clobber an existing local branch.
    if git show-ref --verify --quiet "refs/heads/${new_name}"; then
        echo -e "${RED}✗ A local branch named ${BOLD}${new_name}${NORMAL} already exists.${ENDCOLOR}"
        exit 1
    fi

    # Renaming main/master is unusual; require explicit confirmation.
    if [ "$old_name" = "$main_branch" ]; then
        echo -e "${YELLOW}⚠  ${BOLD}${old_name}${NORMAL} is the configured main branch.${ENDCOLOR}"
        echo -e "Renaming it will leave ${YELLOW}gitbasher.branch${ENDCOLOR} pointing at the old name."
        printf "Rename anyway? (y/n) "
        yes_no_choice_strict
        echo
    fi

    local result
    result=$(git branch -m "$old_name" "$new_name" 2>&1)
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Could not rename branch.${ENDCOLOR}"
        echo "$result"
        exit 1
    fi

    # Keep the in-process global in sync for any later output.
    current_branch="$new_name"

    echo -e "${GREEN}✓ Renamed ${BOLD}${old_name}${NORMAL}${GREEN} → ${BOLD}${new_name}${NORMAL}${ENDCOLOR}"

    # Offer to mirror the rename on the remote when there was an upstream.
    if [ -z "$origin_name" ]; then
        return
    fi
    if ! git ls-remote --exit-code --heads "$origin_name" "$old_name" >/dev/null 2>&1; then
        # Old name never existed on the remote — nothing to clean up there.
        # Just hint how to publish the renamed branch.
        echo -e "Push the renamed branch when ready: ${YELLOW}gitb push${ENDCOLOR}"
        return
    fi

    echo
    echo -e "${YELLOW}${BOLD}${old_name}${NORMAL}${YELLOW} also exists on ${origin_name}.${ENDCOLOR}"
    echo -e "Push ${BOLD}${new_name}${NORMAL} and delete the old remote branch?"
    printf "(y/n) "
    yes_no_choice_strict
    echo

    local push_out
    push_out=$(git push -u "$origin_name" "$new_name" 2>&1)
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Could not push ${BOLD}${new_name}${NORMAL}${RED} to ${origin_name}.${ENDCOLOR}"
        echo "$push_out"
        echo -e "Old remote branch ${BOLD}${old_name}${NORMAL} left intact."
        exit 1
    fi
    echo -e "${GREEN}✓ Pushed ${BOLD}${new_name}${NORMAL}${GREEN} to ${origin_name}${ENDCOLOR}"

    local del_out
    del_out=$(git push "$origin_name" --delete "$old_name" 2>&1)
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}⚠  Could not delete ${BOLD}${old_name}${NORMAL}${YELLOW} on ${origin_name}.${ENDCOLOR}"
        echo "$del_out"
        echo -e "Delete it manually with ${YELLOW}git push ${origin_name} --delete ${old_name}${ENDCOLOR} when ready."
        return
    fi
    echo -e "${GREEN}✓ Deleted ${BOLD}${old_name}${NORMAL}${GREEN} on ${origin_name}${ENDCOLOR}"
}
