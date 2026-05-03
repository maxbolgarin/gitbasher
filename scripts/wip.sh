#!/usr/bin/env bash

### Script for quick work-in-progress save and restore.
# Backends:
#   stash     - git stash --include-untracked, with optional remote backup branch
#   branch    - commits all changes onto a wip/<branch> branch, with optional push
#   worktree  - moves the WIP into a separate worktree on a wip/<branch> branch
# Use this script only with gitbasher


### Build the stash message used for the wip stash on the current branch
function wip_stash_message {
    echo "wip: ${current_branch}"
}


### Build the wip branch / remote backup name for the current branch
function wip_remote_branch {
    echo "wip/${current_branch}"
}


### Find the most recent wip stash for the current branch
# Sets:
#     wip_stash_ref - e.g. 'stash@{2}', or empty if not found
function find_wip_stash {
    wip_stash_ref=""
    local target
    target="$(wip_stash_message)"
    while IFS= read -r line; do
        local ref="${line%%:*}"
        local subject="${line#*: }"
        if [ "$subject" = "On ${current_branch}: ${target}" ] || [ "$subject" = "WIP on ${current_branch}: ${target}" ] || [[ "$line" == *"${target}"* ]]; then
            wip_stash_ref="$ref"
            return 0
        fi
    done < <(git stash list)
    [ -n "$wip_stash_ref" ]
}


### Check if the wip branch exists locally
# Returns: 0 if exists, 1 if not
function find_wip_branch {
    local wip_branch
    wip_branch="$(wip_remote_branch)"
    git show-ref --verify --quiet "refs/heads/${wip_branch}"
}


### Find a worktree that has the wip branch checked out
# Sets:
#     wip_worktree_path - path to the wip worktree, empty if not found
function find_wip_worktree {
    wip_worktree_path=""
    local wip_branch
    wip_branch="$(wip_remote_branch)"

    local cur_path="" cur_branch=""
    while IFS= read -r line; do
        case "$line" in
            "worktree "*) cur_path="${line#worktree }"; cur_branch="" ;;
            "branch "*)   cur_branch="${line#branch }"
                          if [ "${cur_branch}" = "refs/heads/${wip_branch}" ]; then
                              wip_worktree_path="$cur_path"
                              return 0
                          fi ;;
            "")           cur_path=""; cur_branch="" ;;
        esac
    done < <(git worktree list --porcelain 2>/dev/null)

    [ -n "$wip_worktree_path" ]
}


### Compute a default path for the wip worktree
# Same rules as worktree's default_worktree_path:
#   - default:                          <repo_root>/.worktree/wip-<branch>
#   - gitbasher.worktreebase = absolute <base>/wip-<branch>
#   - gitbasher.worktreebase = relative <repo_root>/<base>/wip-<branch>
function wip_worktree_default_path {
    local base
    base=$(get_config_value gitbasher.worktreebase "")
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
    local safe_branch
    safe_branch=$(echo "wip-${current_branch}" | tr '/' '-')

    if [ -z "$base" ]; then
        base=".worktree"
    fi

    if [[ "$base" == /* ]]; then
        echo "${base%/}/${safe_branch}"
    else
        echo "${repo_root}/${base%/}/${safe_branch}"
    fi
}


### Ask user to pick a wip backend
# Sets: wip_backend
function prompt_wip_backend {
    wip_backend=""
    echo -e "${YELLOW}Where do you want to save the WIP?${ENDCOLOR}"
    echo
    echo -e "1. ${BOLD}Stash${NORMAL}    - quick & local (with optional remote backup branch)"
    echo -e "2. ${BOLD}Branch${NORMAL}   - commit changes onto a ${BLUE}wip/${current_branch}${ENDCOLOR} branch (with optional push)"
    echo -e "3. ${BOLD}Worktree${NORMAL} - move WIP into a sibling worktree on ${BLUE}wip/${current_branch}${ENDCOLOR}"
    echo "0. Exit"
    echo

    local choice
    read -n 1 -s choice
    echo

    case "$choice" in
        1) wip_backend="stash";;
        2) wip_backend="branch";;
        3) wip_backend="worktree";;
        0) exit;;
        *) echo -e "${RED}✗ Invalid choice.${ENDCOLOR}"; exit 1;;
    esac
}


### Refuse to operate when working tree is empty
function require_changes {
    if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
        echo -e "${GREEN}✓ No changes to save${ENDCOLOR}"
        exit
    fi
}


### Refuse to run when working tree is dirty (used by branch/worktree restore)
function require_clean {
    if ! git diff --quiet || ! git diff --cached --quiet; then
        echo -e "${RED}✗ Working tree has uncommitted changes.${ENDCOLOR}"
        echo -e "Commit or stash them before restoring the WIP."
        exit 1
    fi
}


### Push the wip stash as a remote backup branch
function wip_push_stash_backup {
    if [ -z "$origin_name" ]; then
        echo -e "${YELLOW}No remote configured — skipping push.${ENDCOLOR}"
        return
    fi
    local remote_branch
    remote_branch="$(wip_remote_branch)"
    echo -e "${YELLOW}Pushing WIP backup to ${origin_name}/${remote_branch}...${ENDCOLOR}"
    local push_output push_code
    # --force-with-lease refuses to clobber a backup branch someone else may
    # have pushed; falls back to creating it on first run. Strictly safer than
    # bare --force without changing the wip flow's intent.
    push_output=$(git push --force-with-lease "${origin_name}" "stash@{0}:refs/heads/${remote_branch}" 2>&1)
    push_code=$?
    if [ $push_code -eq 0 ]; then
        echo -e "${GREEN}✓ Pushed WIP backup to ${origin_name}/${remote_branch}${ENDCOLOR}"
    else
        echo -e "${YELLOW}⚠  Could not push WIP backup (you can push manually later).${ENDCOLOR}"
        echo "$push_output"
    fi
}


### Push a local branch to remote (used by branch/worktree backends)
function wip_push_branch {
    local branch="$1"
    if [ -z "$origin_name" ]; then
        echo -e "${YELLOW}No remote configured — skipping push.${ENDCOLOR}"
        return
    fi
    echo -e "${YELLOW}Pushing ${branch} to ${origin_name}...${ENDCOLOR}"
    local push_output push_code
    # See note in wip_push_stash_backup — prefer --force-with-lease so we
    # don't silently overwrite a wip branch updated from another machine.
    push_output=$(git push --force-with-lease --set-upstream "${origin_name}" "${branch}" 2>&1)
    push_code=$?
    if [ $push_code -eq 0 ]; then
        echo -e "${GREEN}✓ Pushed to ${origin_name}/${branch}${ENDCOLOR}"
    else
        echo -e "${YELLOW}⚠  Could not push ${branch} (you can push manually later).${ENDCOLOR}"
        echo "$push_output"
    fi
}


### Delete the remote wip branch (best-effort)
function wip_delete_remote_branch {
    local branch="$1"
    if [ -z "$origin_name" ]; then
        return
    fi
    if ! git ls-remote --exit-code --heads "$origin_name" "$branch" >/dev/null 2>&1; then
        return
    fi
    echo -e "${YELLOW}Removing remote WIP backup ${origin_name}/${branch}...${ENDCOLOR}"
    local out code
    out=$(git push "$origin_name" --delete "$branch" 2>&1)
    code=$?
    if [ $code -eq 0 ]; then
        echo -e "${GREEN}✓ Removed remote WIP backup${ENDCOLOR}"
    else
        echo -e "${YELLOW}⚠  Could not remove remote WIP backup (delete it manually later).${ENDCOLOR}"
        echo "$out"
    fi
}


### Stash backend: save changes as a stash, optionally push backup branch
function wip_up_stash {
    local nopush="$1"

    require_changes

    echo -e "${YELLOW}Changes to save:${ENDCOLOR}"
    git_status
    echo

    local message
    message="$(wip_stash_message)"
    local stash_output stash_code
    stash_output=$(git stash push --include-untracked --message "$message" 2>&1)
    stash_code=$?

    if [ $stash_code -ne 0 ]; then
        echo -e "${RED}✗ Cannot stash changes.${ENDCOLOR}"
        echo "$stash_output"
        exit $stash_code
    fi

    local stash_hash
    stash_hash=$(git rev-parse --short stash@{0} 2>/dev/null)
    echo -e "${GREEN}✓ Stashed WIP${ENDCOLOR} ${BLUE}[${stash_hash}]${ENDCOLOR} $message"
    echo

    if [ -z "$nopush" ]; then
        wip_push_stash_backup
        echo
    fi
    echo -e "Restore with: ${YELLOW}gitb wip down${ENDCOLOR}"
}


### Branch backend: commit all changes onto wip/<branch>, then return clean
function wip_up_branch {
    local nopush="$1"

    require_changes

    if find_wip_branch; then
        echo -e "${RED}✗ Branch ${BOLD}$(wip_remote_branch)${NORMAL}${RED} already exists.${ENDCOLOR}"
        echo -e "Restore or delete it first: ${YELLOW}gitb wip down branch${ENDCOLOR}"
        exit 1
    fi

    echo -e "${YELLOW}Changes to save:${ENDCOLOR}"
    git_status
    echo

    local original_branch="$current_branch"
    local wip_branch
    wip_branch="$(wip_remote_branch)"

    # Stash everything (including untracked) so we can apply onto the wip branch
    local stash_output
    stash_output=$(git stash push --include-untracked --message "wip-transfer: ${original_branch}" 2>&1)
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Cannot stash changes for transfer.${ENDCOLOR}"
        echo "$stash_output"
        exit 1
    fi

    # Create the wip branch from the original HEAD and switch to it
    local create_output
    create_output=$(git switch -c "$wip_branch" 2>&1)
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Cannot create branch ${wip_branch}.${ENDCOLOR}"
        echo "$create_output"
        # Restore the stash so the user does not lose work
        git stash pop >/dev/null 2>&1
        exit 1
    fi

    # Apply the stash on top of the new branch
    local pop_output
    pop_output=$(git stash pop 2>&1)
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Cannot apply WIP onto ${wip_branch}.${ENDCOLOR}"
        echo "$pop_output"
        echo
        echo -e "${YELLOW}You are now on ${wip_branch} — resolve conflicts and finish manually.${ENDCOLOR}"
        exit 1
    fi

    # Stage everything and create a single wip commit
    git add -A >/dev/null 2>&1
    local ts
    ts=$(date +"%Y-%m-%d %H:%M:%S")
    local commit_output
    commit_output=$(git -c commit.gpgsign=false commit -m "wip: ${original_branch} @ ${ts}" 2>&1)
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Cannot create WIP commit.${ENDCOLOR}"
        echo "$commit_output"
        exit 1
    fi

    local wip_hash
    wip_hash=$(git rev-parse --short HEAD 2>/dev/null)

    # Switch back to the original branch with a clean working tree
    local switch_output
    switch_output=$(git switch "$original_branch" 2>&1)
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Cannot switch back to ${original_branch}.${ENDCOLOR}"
        echo "$switch_output"
        echo
        echo -e "${YELLOW}WIP committed on ${wip_branch} (${wip_hash}) — switch back manually.${ENDCOLOR}"
        exit 1
    fi
    current_branch="$original_branch"

    echo -e "${GREEN}✓ Committed WIP${ENDCOLOR} ${BLUE}[${wip_hash}]${ENDCOLOR} on ${BLUE}${wip_branch}${ENDCOLOR}"
    echo -e "${GREEN}✓ Switched back to ${original_branch} with a clean working tree${ENDCOLOR}"
    echo

    if [ -z "$nopush" ]; then
        wip_push_branch "$wip_branch"
        echo
    fi
    echo -e "Restore with: ${YELLOW}gitb wip down${ENDCOLOR}"
}


### Worktree backend: move WIP into a sibling worktree on wip/<branch>
function wip_up_worktree {
    local nopush="$1"

    require_changes

    if find_wip_branch; then
        echo -e "${RED}✗ Branch ${BOLD}$(wip_remote_branch)${NORMAL}${RED} already exists.${ENDCOLOR}"
        echo -e "Restore or delete it first: ${YELLOW}gitb wip down worktree${ENDCOLOR}"
        exit 1
    fi

    local wip_branch wip_path
    wip_branch="$(wip_remote_branch)"
    wip_path="$(wip_worktree_default_path)"

    if [ -e "$wip_path" ]; then
        echo -e "${RED}✗ Path ${wip_path} already exists.${ENDCOLOR}"
        exit 1
    fi

    echo -e "${YELLOW}Changes to save:${ENDCOLOR}"
    git_status
    echo

    # Stash so the worktree-add starts from a clean state
    local stash_output
    stash_output=$(git stash push --include-untracked --message "wip-transfer: ${current_branch}" 2>&1)
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Cannot stash changes for transfer.${ENDCOLOR}"
        echo "$stash_output"
        exit 1
    fi

    echo -e "${YELLOW}Creating worktree at ${BOLD}${wip_path}${NORMAL}${YELLOW} on branch ${BOLD}${wip_branch}${NORMAL}...${ENDCOLOR}"
    local add_output
    add_output=$(git worktree add -b "$wip_branch" "$wip_path" HEAD 2>&1)
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Cannot create worktree.${ENDCOLOR}"
        echo "$add_output"
        # Restore the stash so the user does not lose work
        git stash pop >/dev/null 2>&1
        exit 1
    fi

    # Apply the stash inside the new worktree (stashes are repo-wide so this works)
    local pop_output
    pop_output=$(git -C "$wip_path" stash pop 2>&1)
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Cannot apply WIP onto worktree.${ENDCOLOR}"
        echo "$pop_output"
        echo
        echo -e "${YELLOW}Stash kept — resolve manually in ${wip_path}.${ENDCOLOR}"
        exit 1
    fi

    echo -e "${GREEN}✓ Moved WIP into worktree${ENDCOLOR}"
    echo -e "  branch: ${BLUE}${wip_branch}${ENDCOLOR}"
    echo -e "  path:   ${wip_path}"
    echo

    if [ -z "$nopush" ] && [ -n "$origin_name" ]; then
        # Commit the WIP inside the worktree first so we have something to push
        git -C "$wip_path" add -A >/dev/null 2>&1
        if ! git -C "$wip_path" diff --cached --quiet; then
            local ts
            ts=$(date +"%Y-%m-%d %H:%M:%S")
            git -C "$wip_path" -c commit.gpgsign=false commit -m "wip: ${current_branch} @ ${ts}" >/dev/null 2>&1
            wip_push_branch "$wip_branch"
            echo
        fi
    fi

    echo -e "Continue working: ${YELLOW}cd ${wip_path}${ENDCOLOR}"
    echo -e "Restore with:     ${YELLOW}gitb wip down${ENDCOLOR} (run from the original worktree)"
}


### Stash backend restore
function wip_down_stash {
    if ! find_wip_stash; then
        echo -e "${YELLOW}No WIP stash found for branch ${current_branch}.${ENDCOLOR}"
        echo -e "Save one first with: ${YELLOW}gitb wip up${ENDCOLOR}"
        exit 1
    fi

    local stash_summary
    stash_summary=$(git stash list --pretty="%gd | %s | ${GREEN_ES}%cr${ENDCOLOR_ES}" "$wip_stash_ref" 2>/dev/null | head -n 1)
    echo -e "${YELLOW}WIP stash to restore:${ENDCOLOR}"
    echo -e "\t${stash_summary}"
    echo

    local pop_output pop_code
    pop_output=$(git stash pop "$wip_stash_ref" 2>&1)
    pop_code=$?

    if [ $pop_code -ne 0 ]; then
        echo -e "${RED}✗ Cannot restore WIP.${ENDCOLOR}"
        echo "$pop_output"
        exit $pop_code
    fi

    echo -e "${GREEN}✓ Restored WIP${ENDCOLOR}"
    echo
    echo -e "${YELLOW}Restored changes:${ENDCOLOR}"
    git_status

    wip_delete_remote_branch "$(wip_remote_branch)"
}


### Branch backend restore: squash-merge wip/<branch> into current as uncommitted changes
function wip_down_branch {
    local wip_branch
    wip_branch="$(wip_remote_branch)"

    if ! find_wip_branch; then
        echo -e "${YELLOW}No WIP branch ${wip_branch} found.${ENDCOLOR}"
        echo -e "Save one first with: ${YELLOW}gitb wip up branch${ENDCOLOR}"
        exit 1
    fi

    require_clean

    echo -e "${YELLOW}Restoring WIP from ${BOLD}${wip_branch}${NORMAL}...${ENDCOLOR}"
    echo

    local merge_output merge_code
    merge_output=$(git merge --squash --no-commit "$wip_branch" 2>&1)
    merge_code=$?

    if [ $merge_code -ne 0 ]; then
        echo -e "${RED}✗ Cannot restore WIP — squash-merge failed.${ENDCOLOR}"
        echo "$merge_output"
        echo
        echo -e "${YELLOW}Resolve conflicts manually, then ${BOLD}git reset HEAD${NORMAL}${YELLOW} to leave them unstaged.${ENDCOLOR}"
        exit $merge_code
    fi

    # Un-stage so the user sees them as plain modifications, matching wip-up state
    git reset HEAD >/dev/null 2>&1
    rm -f "$(git rev-parse --git-path MERGE_MSG 2>/dev/null)" 2>/dev/null

    echo -e "${GREEN}✓ Restored WIP${ENDCOLOR}"
    echo
    echo -e "${YELLOW}Restored changes:${ENDCOLOR}"
    git_status
    echo

    echo -e "${YELLOW}Removing local branch ${wip_branch}...${ENDCOLOR}"
    local del_out
    del_out=$(git branch -D "$wip_branch" 2>&1)
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Deleted local branch ${wip_branch}${ENDCOLOR}"
    else
        echo -e "${YELLOW}⚠  Could not delete local branch (delete manually).${ENDCOLOR}"
        echo "$del_out"
    fi

    wip_delete_remote_branch "$wip_branch"
}


### Worktree backend restore: bring everything from the wip worktree back, then remove it
function wip_down_worktree {
    local wip_branch
    wip_branch="$(wip_remote_branch)"

    if ! find_wip_worktree; then
        echo -e "${YELLOW}No WIP worktree found for ${wip_branch}.${ENDCOLOR}"
        echo -e "Save one first with: ${YELLOW}gitb wip up worktree${ENDCOLOR}"
        exit 1
    fi

    local current_path
    current_path=$(git rev-parse --show-toplevel 2>/dev/null)
    if [ "$wip_worktree_path" = "$current_path" ]; then
        echo -e "${RED}✗ You are inside the WIP worktree (${wip_worktree_path}).${ENDCOLOR}"
        echo -e "Switch back to the original worktree first"
        exit 1
    fi

    require_clean

    echo -e "${YELLOW}Restoring WIP from worktree ${BOLD}${wip_worktree_path}${NORMAL}...${ENDCOLOR}"
    echo

    # Move any uncommitted changes in the wip worktree onto the wip branch as a tip commit
    local has_pending="false"
    if ! git -C "$wip_worktree_path" diff --quiet || \
       ! git -C "$wip_worktree_path" diff --cached --quiet || \
       [ -n "$(git -C "$wip_worktree_path" ls-files --others --exclude-standard)" ]; then
        has_pending="true"
        git -C "$wip_worktree_path" add -A >/dev/null 2>&1
        git -C "$wip_worktree_path" -c commit.gpgsign=false commit -m "wip-pending: ${current_branch}" >/dev/null 2>&1
    fi

    # Squash-merge the wip branch into the current branch as uncommitted changes
    local merge_output merge_code
    merge_output=$(git merge --squash --no-commit "$wip_branch" 2>&1)
    merge_code=$?
    if [ $merge_code -ne 0 ]; then
        echo -e "${RED}✗ Cannot restore WIP — squash-merge failed.${ENDCOLOR}"
        echo "$merge_output"
        echo
        echo -e "${YELLOW}Resolve conflicts manually; the wip worktree is still at ${wip_worktree_path}.${ENDCOLOR}"
        exit $merge_code
    fi

    git reset HEAD >/dev/null 2>&1
    rm -f "$(git rev-parse --git-path MERGE_MSG 2>/dev/null)" 2>/dev/null

    echo -e "${GREEN}WIP restored!${ENDCOLOR}"
    if [ "$has_pending" = "true" ]; then
        echo -e "(including uncommitted changes from the wip worktree)"
    fi
    echo
    echo -e "${YELLOW}Restored changes:${ENDCOLOR}"
    git_status
    echo

    echo -e "${YELLOW}Removing worktree ${wip_worktree_path}...${ENDCOLOR}"
    local rm_out rm_code
    rm_out=$(git worktree remove --force "$wip_worktree_path" 2>&1)
    rm_code=$?
    if [ $rm_code -eq 0 ]; then
        echo -e "${GREEN}Worktree removed${ENDCOLOR}"
    else
        echo -e "${YELLOW}Could not remove worktree (remove manually):${ENDCOLOR}"
        echo "$rm_out"
    fi

    local del_out del_code
    del_out=$(git branch -D "$wip_branch" 2>&1)
    del_code=$?
    if [ $del_code -eq 0 ]; then
        echo -e "${GREEN}Local branch ${wip_branch} deleted${ENDCOLOR}"
    else
        echo -e "${YELLOW}Could not delete local branch (delete manually):${ENDCOLOR}"
        echo "$del_out"
    fi

    wip_delete_remote_branch "$wip_branch"
}


### Subcommand: save WIP using the chosen backend
# Args may include backend (stash|branch|worktree) and nopush flag in any order
function wip_up {
    local backend="" nopush=""
    for arg in "$@"; do
        case "$arg" in
            stash|s)             backend="stash";;
            branch|b)            backend="branch";;
            worktree|w|wt|tree)  backend="worktree";;
            nopush|np|n)         nopush="true";;
            "")                  ;;
            *)                   wrong_mode "wip up" "$arg";;
        esac
    done

    local header_msg="GIT WIP UP"
    if [ -n "$backend" ]; then
        header_msg="${header_msg} ($(echo "$backend" | tr 'a-z' 'A-Z'))"
    fi
    if [ -n "$nopush" ]; then
        header_msg="${header_msg} (NO PUSH)"
    fi
    echo -e "${YELLOW}${header_msg}${ENDCOLOR}"
    echo

    if [ -z "$backend" ]; then
        # Legacy back-compat: `wip up nopush` always meant stash + nopush
        if [ -n "$nopush" ]; then
            backend="stash"
        else
            prompt_wip_backend
            backend="$wip_backend"
        fi
    fi

    case "$backend" in
        stash)    wip_up_stash    "$nopush";;
        branch)   wip_up_branch   "$nopush";;
        worktree) wip_up_worktree "$nopush";;
    esac
}


### Subcommand: restore WIP using the chosen backend (auto-detect when ambiguous)
function wip_down {
    local backend=""
    case "$1" in
        stash|s)             backend="stash";;
        branch|b)            backend="branch";;
        worktree|w|wt|tree)  backend="worktree";;
        "")                  ;;
        *)                   wrong_mode "wip down" "$1";;
    esac

    local header_msg="GIT WIP DOWN"
    if [ -n "$backend" ]; then
        header_msg="${header_msg} ($(echo "$backend" | tr 'a-z' 'A-Z'))"
    fi
    echo -e "${YELLOW}${header_msg}${ENDCOLOR}"
    echo

    if [ -z "$backend" ]; then
        # Auto-detect available backends
        local available=()
        if find_wip_stash; then
            available+=("stash")
        fi
        if find_wip_worktree; then
            available+=("worktree")
        elif find_wip_branch; then
            available+=("branch")
        fi

        if [ ${#available[@]} -eq 0 ]; then
            echo -e "${YELLOW}No WIP found for branch ${current_branch}.${ENDCOLOR}"
            echo -e "Save one first with: ${YELLOW}gitb wip up${ENDCOLOR}"
            exit 1
        fi

        if [ ${#available[@]} -eq 1 ]; then
            backend="${available[0]}"
            echo -e "${YELLOW}Restoring from ${backend}${ENDCOLOR}"
            echo
        else
            echo -e "${YELLOW}Multiple WIP saves found. Pick one:${ENDCOLOR}"
            echo
            for index in "${!available[@]}"; do
                echo -e "$(($index+1)). ${BOLD}${available[$index]}${ENDCOLOR}"
            done
            echo "0. Exit"
            echo

            local choice
            read -n 1 -s choice
            echo
            local idx=$((choice-1))
            if [ "$choice" = "0" ] || [ -z "${available[$idx]}" ]; then
                exit
            fi
            backend="${available[$idx]}"
            echo
        fi
    fi

    case "$backend" in
        stash)    wip_down_stash;;
        branch)   wip_down_branch;;
        worktree) wip_down_worktree;;
    esac
}


### Print help for the wip command
function wip_help {
    echo -e "${YELLOW}GIT WIP${ENDCOLOR}"
    echo
    echo -e "usage: ${YELLOW}gitb wip <up|down> [stash|branch|worktree] [nopush]${ENDCOLOR}"
    echo
    local PAD=26
    print_help_header $PAD
    print_help_row $PAD "up"                "u"      "Save WIP (prompts for backend)"
    print_help_row $PAD "up stash"           "u s"    "Save as a stash with optional remote backup branch"
    print_help_row $PAD "up branch"          "u b"    "Commit changes onto a wip/<branch> branch (with optional push)"
    print_help_row $PAD "up worktree"        "u w, wt" "Move WIP into a sibling worktree on wip/<branch>"
    print_help_row $PAD "up <mode> nopush"   "np, n"  "Skip the push step (works with any backend)"
    print_help_row $PAD "down"               "d"      "Restore WIP (auto-detects backend, prompts if ambiguous)"
    print_help_row $PAD "down stash"         "d s"    "Restore from the stash"
    print_help_row $PAD "down branch"        "d b"    "Restore from the wip/<branch> branch"
    print_help_row $PAD "down worktree"      "d w, wt" "Restore from the wip/<branch> worktree"
    print_help_row $PAD "help"               "h"      "Show this help"
    echo
    echo -e "${YELLOW}Backends${ENDCOLOR}"
    printf "  ${BOLD}%-10s${NORMAL}  %b\n" "stash"    "Quick & local; pushes ${YELLOW}${origin_name:-origin}/wip/<branch>${ENDCOLOR} as a backup"
    printf "  ${BOLD}%-10s${NORMAL}  %b\n" "branch"   "Commits changes onto a ${YELLOW}wip/<branch>${ENDCOLOR} branch; current branch becomes clean"
    printf "  ${BOLD}%-10s${NORMAL}  %b\n" "worktree" "Like branch, but WIP lives in a ${YELLOW}sibling worktree${ENDCOLOR} so you can keep working on it"
    echo
    echo -e "${YELLOW}Examples${ENDCOLOR}"
    echo -e "  ${GREEN}gitb wip up${ENDCOLOR}              Pick a backend and save current changes"
    echo -e "  ${GREEN}gitb wip up stash${ENDCOLOR}        Stash + push backup to ${BLUE}${origin_name:-origin}/wip/<branch>${ENDCOLOR}"
    echo -e "  ${GREEN}gitb wip up branch np${ENDCOLOR}    Commit to ${BLUE}wip/<branch>${ENDCOLOR}, skip push"
    echo -e "  ${GREEN}gitb wip down${ENDCOLOR}            Restore the saved WIP back into the current branch"
}


### Main function for wip
# $1: subcommand (up|down|help)
# $2..: subcommand args (backend / nopush)
function wip_script {
    case "$1" in
        up|u)           shift; wip_up "$@";;
        down|d)         shift; wip_down "$@";;
        help|h|"")      wip_help;;
        *)              wrong_mode "wip" "$1";;
    esac
}
