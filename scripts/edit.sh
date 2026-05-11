#!/usr/bin/env bash

### Script for `gitb edit` — rewrite commit messages without changing the tree.
### Two modes:
###   * default: amend the last commit's message (`git commit --amend`)
###   * `pick`:  pick any commit from the recent history and reword it via a
###              non-interactive rebase (GIT_SEQUENCE_EDITOR rewrites the
###              chosen `pick` line into `reword`)
### Use this script only with gitbasher.


function edit_script {
    local mode="amend"
    case "$1" in
        help|h|--help|-h)
            echo -e "${YELLOW}GIT EDIT${ENDCOLOR}"
            echo
            echo -e "usage: ${YELLOW}gitb edit [mode]${ENDCOLOR}"
            echo
            echo -e "Rewrite a commit message without touching the tree."
            echo
            echo -e "${YELLOW}Modes${ENDCOLOR}"
            echo -e "  ${BOLD}<empty>${NORMAL}            Reword the ${BOLD}last${NORMAL} commit (${GREEN}git commit --amend${ENDCOLOR})"
            echo -e "  ${BOLD}pick${NORMAL} (${BOLD}p${NORMAL}, ${BOLD}c${NORMAL})    Choose any recent commit and reword it via rebase"
            echo -e "  ${BOLD}help${NORMAL} (${BOLD}h${NORMAL})         Show this help"
            echo
            echo -e "${YELLOW}Notes${ENDCOLOR}"
            echo -e "  ${BLUE}•${ENDCOLOR} ${BOLD}pick${NORMAL} requires a clean working tree (the rebase replays commits)."
            echo -e "  ${BLUE}•${ENDCOLOR} Merge commits and the root commit cannot be reworded this way."
            echo -e "  ${BLUE}•${ENDCOLOR} If the commit was already pushed, run ${YELLOW}gitb push force${ENDCOLOR} afterwards."
            echo -e "  ${BLUE}•${ENDCOLOR} To add staged changes into the last commit, use ${YELLOW}gitb commit amend${ENDCOLOR}."
            echo -e "  ${BLUE}•${ENDCOLOR} To undo the amend/rebase, use ${YELLOW}gitb undo amend${ENDCOLOR} / ${YELLOW}gitb undo rebase${ENDCOLOR}."
            exit 0
            ;;
        "")
            ;;
        pick|p|c|choose)
            mode="pick"
            ;;
        *)
            wrong_mode "edit" "$1"
            ;;
    esac

    echo -e "${YELLOW}GIT EDIT${ENDCOLOR}"
    echo

    ### Refuse in detached-HEAD: amend/rebase there creates unreachable commits.
    warn_if_detached_head "edit"

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
    trap 'rm -f "$seq_script"' EXIT INT TERM
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
