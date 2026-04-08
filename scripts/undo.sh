#!/usr/bin/env bash

### Script for quick undo of recent git operations
# Provides operation-specific undo commands
# Use this script only with gitbasher


### Main function
# $1: mode
    # <empty>|commit: undo last commit (soft reset HEAD~1)
    # amend: undo last amend using reflog
    # merge: undo last merge
    # rebase: undo last rebase using ORIG_HEAD
    # stash: undo last stash pop/apply
function undo_script {
    case "$1" in
        commit|c)       undo_mode="commit";;
        amend|a)        undo_mode="amend";;
        merge|m)        undo_mode="merge";;
        rebase|r)       undo_mode="rebase";;
        stash|s)        undo_mode="stash";;
        help|h)         help="true";;
        *)
            if [ -n "$1" ]; then
                wrong_mode "undo" "$1"
            fi
            undo_mode="commit"
    esac


    ### Print header
    header_msg="GIT UNDO"
    case "$undo_mode" in
        commit) header_msg="$header_msg COMMIT";;
        amend)  header_msg="$header_msg AMEND";;
        merge)  header_msg="$header_msg MERGE";;
        rebase) header_msg="$header_msg REBASE";;
        stash)  header_msg="$header_msg STASH";;
    esac

    echo -e "${YELLOW}${header_msg}${ENDCOLOR}"
    echo


    if [ -n "$help" ]; then
        echo -e "usage: ${YELLOW}gitb undo <mode>${ENDCOLOR}"
        echo
        msg="${YELLOW}Mode${ENDCOLOR}_${GREEN}Aliases${ENDCOLOR}_\t${BLUE}Description${ENDCOLOR}"
        msg="$msg\n${BOLD}<empty>${ENDCOLOR}_commit|c_Undo last commit (git reset --soft HEAD~1), keeps changes staged"
        msg="$msg\n${BOLD}amend${ENDCOLOR}_a_Undo last amend, restoring the previous commit state via reflog"
        msg="$msg\n${BOLD}merge${ENDCOLOR}_m_Undo last merge (git merge --abort or git reset --merge ORIG_HEAD)"
        msg="$msg\n${BOLD}rebase${ENDCOLOR}_r_Undo last rebase (git rebase --abort or git reset --hard ORIG_HEAD)"
        msg="$msg\n${BOLD}stash${ENDCOLOR}_s_Undo last stash pop by re-stashing the popped changes"
        msg="$msg\n${BOLD}help${ENDCOLOR}_h_Show this help"
        echo -e "$(echo -e "$msg" | column -ts'_')"
        exit
    fi


    case "$undo_mode" in
        commit) undo_commit;;
        amend)  undo_amend;;
        merge)  undo_merge;;
        rebase) undo_rebase;;
        stash)  undo_stash;;
    esac
}


### Undo last commit - soft reset to keep changes staged
function undo_commit {
    # Check if there are any commits
    commit_count=$(git rev-list --count HEAD 2>/dev/null)
    if [ -z "$commit_count" ] || [ "$commit_count" -eq 0 ]; then
        echo -e "${RED}No commits to undo${ENDCOLOR}"
        exit 1
    fi

    # Show the commit that will be undone
    cancelled_commit=$(git log -n 1 --pretty="%s | ${YELLOW}%h${ENDCOLOR} | ${CYAN}%cd${ENDCOLOR} (${GREEN}%cr${ENDCOLOR})")
    echo -e "${YELLOW}Commit to undo:${ENDCOLOR}"
    echo -e "\t$cancelled_commit"
    echo

    echo -e "This will undo the last commit but ${GREEN}keep all changes staged${ENDCOLOR}"
    echo -e "Do you want to continue (y/n)?"
    yes_no_choice "Undoing commit..."

    reset_output=$(git reset --soft HEAD~1 2>&1)
    reset_code=$?

    if [ $reset_code -ne 0 ]; then
        echo -e "${RED}Cannot undo commit! Error message:${ENDCOLOR}"
        echo "$reset_output"
        exit $reset_code
    fi

    new_commit=$(git log -n 1 --pretty="%s | ${YELLOW}%h${ENDCOLOR} | ${CYAN}%cd${ENDCOLOR} (${GREEN}%cr${ENDCOLOR})" 2>/dev/null)

    echo -e "${GREEN}Commit undone successfully!${ENDCOLOR}"
    echo
    echo -e "${RED}Undone commit:${ENDCOLOR}\t$cancelled_commit"
    if [ -n "$new_commit" ]; then
        echo -e "${GREEN}New HEAD:${ENDCOLOR}\t$new_commit"
    fi
    echo
    echo -e "${YELLOW}Staged changes:${ENDCOLOR}"
    git_status
}


### Undo last amend - restore pre-amend state from reflog
function undo_amend {
    # Find the reflog entry before the amend
    last_action=$(git reflog -n 1 --pretty="%gs" 2>/dev/null)

    if [[ "$last_action" != *"amend"* ]]; then
        echo -e "${YELLOW}Last action was not an amend:${ENDCOLOR} $last_action"
        echo
        echo -e "Looking for the most recent amend in reflog..."
        echo

        # Search reflog for the most recent amend
        amend_ref=$(git reflog --pretty="%gd %gs" | grep "amend" | head -n 1 | awk '{print $1}')

        if [ -z "$amend_ref" ]; then
            echo -e "${RED}No amend found in reflog${ENDCOLOR}"
            exit 1
        fi

        # The state before the amend is the next entry
        amend_num=${amend_ref#*\{}
        amend_num=${amend_num%\}}
        pre_amend_num=$((amend_num + 1))
        pre_amend_ref="HEAD@{$pre_amend_num}"

        echo -e "${YELLOW}Found amend at ${amend_ref}${ENDCOLOR}"
    else
        pre_amend_ref="HEAD@{1}"
    fi

    # Show what will happen
    current_commit=$(git log -n 1 --pretty="%s | ${YELLOW}%h${ENDCOLOR} | ${CYAN}%cd${ENDCOLOR} (${GREEN}%cr${ENDCOLOR})")
    pre_amend_commit=$(git log -n 1 --pretty="%s | ${YELLOW}%h${ENDCOLOR} | ${CYAN}%cd${ENDCOLOR} (${GREEN}%cr${ENDCOLOR})" "$pre_amend_ref" 2>/dev/null)

    if [ -z "$pre_amend_commit" ]; then
        echo -e "${RED}Cannot find the pre-amend state in reflog${ENDCOLOR}"
        exit 1
    fi

    echo -e "${YELLOW}Current (amended):${ENDCOLOR}\t$current_commit"
    echo -e "${GREEN}Restore to:${ENDCOLOR}\t\t$pre_amend_commit"
    echo

    echo -e "Do you want to undo the amend (y/n)?"
    yes_no_choice "Undoing amend..."

    reset_output=$(git reset --soft "$pre_amend_ref" 2>&1)
    reset_code=$?

    if [ $reset_code -ne 0 ]; then
        echo -e "${RED}Cannot undo amend! Error message:${ENDCOLOR}"
        echo "$reset_output"
        exit $reset_code
    fi

    echo -e "${GREEN}Amend undone successfully!${ENDCOLOR}"
    echo
    echo -e "${GREEN}Restored commit:${ENDCOLOR}"
    echo -e "\t$(git log -n 1 --pretty="%s | ${YELLOW}%h${ENDCOLOR} | ${CYAN}%cd${ENDCOLOR} (${GREEN}%cr${ENDCOLOR})")"
    echo
    echo -e "${YELLOW}Staged changes (from the amend):${ENDCOLOR}"
    git_status
}


### Undo last merge
function undo_merge {
    # Check if a merge is in progress
    if [ -f "$(git rev-parse --git-dir)/MERGE_HEAD" ]; then
        echo -e "${YELLOW}Merge in progress detected${ENDCOLOR}"
        echo -e "Do you want to abort the ongoing merge (y/n)?"
        yes_no_choice "Aborting merge..."

        abort_output=$(git merge --abort 2>&1)
        abort_code=$?

        if [ $abort_code -ne 0 ]; then
            echo -e "${RED}Cannot abort merge! Error message:${ENDCOLOR}"
            echo "$abort_output"
            exit $abort_code
        fi

        echo -e "${GREEN}Merge aborted successfully!${ENDCOLOR}"
        exit
    fi

    # Check if the last action was a merge
    last_action=$(git reflog -n 1 --pretty="%gs" 2>/dev/null)
    if [[ "$last_action" != *"merge"* ]]; then
        echo -e "${YELLOW}Last action was not a merge:${ENDCOLOR} $last_action"
        echo
    fi

    # Check ORIG_HEAD exists
    orig_head=$(git rev-parse ORIG_HEAD 2>/dev/null)
    if [ -z "$orig_head" ]; then
        echo -e "${RED}No ORIG_HEAD found - cannot determine pre-merge state${ENDCOLOR}"
        echo -e "${YELLOW}Try using ${BOLD}gitb reset ref${NORMAL}${YELLOW} to manually select a reflog entry${ENDCOLOR}"
        exit 1
    fi

    # Show what will happen
    current_commit=$(git log -n 1 --pretty="%s | ${YELLOW}%h${ENDCOLOR} | ${CYAN}%cd${ENDCOLOR} (${GREEN}%cr${ENDCOLOR})")
    orig_commit=$(git log -n 1 --pretty="%s | ${YELLOW}%h${ENDCOLOR} | ${CYAN}%cd${ENDCOLOR} (${GREEN}%cr${ENDCOLOR})" ORIG_HEAD)

    echo -e "${YELLOW}Current HEAD:${ENDCOLOR}\t$current_commit"
    echo -e "${GREEN}Restore to:${ENDCOLOR}\t$orig_commit"
    echo

    echo -e "${RED}This will discard the merge commit and all merge changes${ENDCOLOR}"
    echo -e "Do you want to undo the merge (y/n)?"
    yes_no_choice "Undoing merge..."

    reset_output=$(git reset --merge ORIG_HEAD 2>&1)
    reset_code=$?

    if [ $reset_code -ne 0 ]; then
        echo -e "${RED}Cannot undo merge! Error message:${ENDCOLOR}"
        echo "$reset_output"
        exit $reset_code
    fi

    echo -e "${GREEN}Merge undone successfully!${ENDCOLOR}"
    echo
    echo -e "${GREEN}Restored to:${ENDCOLOR}"
    echo -e "\t$(git log -n 1 --pretty="%s | ${YELLOW}%h${ENDCOLOR} | ${CYAN}%cd${ENDCOLOR} (${GREEN}%cr${ENDCOLOR})")"
}


### Undo last rebase
function undo_rebase {
    # Check if a rebase is in progress
    if [ -d "$(git rev-parse --git-dir)/rebase-merge" ] || [ -d "$(git rev-parse --git-dir)/rebase-apply" ]; then
        echo -e "${YELLOW}Rebase in progress detected${ENDCOLOR}"
        echo -e "Do you want to abort the ongoing rebase (y/n)?"
        yes_no_choice "Aborting rebase..."

        abort_output=$(git rebase --abort 2>&1)
        abort_code=$?

        if [ $abort_code -ne 0 ]; then
            echo -e "${RED}Cannot abort rebase! Error message:${ENDCOLOR}"
            echo "$abort_output"
            exit $abort_code
        fi

        echo -e "${GREEN}Rebase aborted successfully!${ENDCOLOR}"
        exit
    fi

    # Check ORIG_HEAD exists
    orig_head=$(git rev-parse ORIG_HEAD 2>/dev/null)
    if [ -z "$orig_head" ]; then
        echo -e "${RED}No ORIG_HEAD found - cannot determine pre-rebase state${ENDCOLOR}"
        echo -e "${YELLOW}Try using ${BOLD}gitb reset ref${NORMAL}${YELLOW} to manually select a reflog entry${ENDCOLOR}"
        exit 1
    fi

    # Show what will happen
    current_commit=$(git log -n 1 --pretty="%s | ${YELLOW}%h${ENDCOLOR} | ${CYAN}%cd${ENDCOLOR} (${GREEN}%cr${ENDCOLOR})")
    orig_commit=$(git log -n 1 --pretty="%s | ${YELLOW}%h${ENDCOLOR} | ${CYAN}%cd${ENDCOLOR} (${GREEN}%cr${ENDCOLOR})" ORIG_HEAD)

    echo -e "${YELLOW}Current HEAD:${ENDCOLOR}\t\t$current_commit"
    echo -e "${GREEN}Pre-rebase state:${ENDCOLOR}\t$orig_commit"
    echo

    echo -e "${RED}This will discard all rebase changes and restore the original branch state${ENDCOLOR}"
    echo -e "Do you want to undo the rebase (y/n)?"
    yes_no_choice "Undoing rebase..."

    reset_output=$(git reset --hard ORIG_HEAD 2>&1)
    reset_code=$?

    if [ $reset_code -ne 0 ]; then
        echo -e "${RED}Cannot undo rebase! Error message:${ENDCOLOR}"
        echo "$reset_output"
        exit $reset_code
    fi

    echo -e "${GREEN}Rebase undone successfully!${ENDCOLOR}"
    echo
    echo -e "${GREEN}Restored to:${ENDCOLOR}"
    echo -e "\t$(git log -n 1 --pretty="%s | ${YELLOW}%h${ENDCOLOR} | ${CYAN}%cd${ENDCOLOR} (${GREEN}%cr${ENDCOLOR})")"
}


### Undo last stash pop/apply
function undo_stash {
    # Check if there are any changes from a recent stash pop (tracked or untracked)
    if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
        echo -e "${YELLOW}No changes detected in working tree${ENDCOLOR}"
        echo -e "If stash pop had conflicts, resolve them first and then use this command"
        echo
        echo -e "Nothing to undo"
        exit
    fi

    echo -e "${YELLOW}Current changes that will be re-stashed:${ENDCOLOR}"
    git_status
    echo

    echo -e "This will stash all current changes to undo the last stash pop/apply"
    echo -e "Do you want to continue (y/n)?"
    yes_no_choice "Re-stashing changes..."

    stash_output=$(git stash push -m "undo: re-stashed changes" --include-untracked 2>&1)
    stash_code=$?

    if [ $stash_code -ne 0 ]; then
        echo -e "${RED}Cannot re-stash changes! Error message:${ENDCOLOR}"
        echo "$stash_output"
        exit $stash_code
    fi

    echo -e "${GREEN}Changes re-stashed successfully!${ENDCOLOR}"
    echo -e "${YELLOW}Your changes are saved in the stash. Use ${BOLD}gitb stash pop${NORMAL}${YELLOW} to restore them.${ENDCOLOR}"
}
