#!/usr/bin/env bash

### Script for streamlined fixup + autosquash workflow
# Creates a fixup commit and optionally autosquashes it immediately
# Use this script only with gitbasher


### Main function
# $1: mode
    # <empty>: select files, pick commit to fixup, create fixup commit, then autosquash
    # fast: add all files, pick commit, fixup, autosquash
    # commit: only create fixup commit (no autosquash) - same as gitb c x
    # push: fixup + autosquash + force push
    # fastp: fast fixup + autosquash + force push
function fixup_script {
    case "$1" in
        fast|f)         fixup_fast="true";;
        commit|c)       fixup_commit_only="true";;
        push|p)         fixup_push="true";;
        fastp|fp|pf)    fixup_fast="true"; fixup_push="true";;
        help|h)         help="true";;
        *)
            wrong_mode "fixup" $1
    esac


    ### Print header
    header_msg="GIT FIXUP"
    if [ -n "${fixup_fast}" ]; then
        if [ -n "${fixup_push}" ]; then
            header_msg="$header_msg FAST & PUSH"
        else
            header_msg="$header_msg FAST"
        fi
    elif [ -n "${fixup_commit_only}" ]; then
        header_msg="$header_msg COMMIT ONLY"
    elif [ -n "${fixup_push}" ]; then
        header_msg="$header_msg & PUSH"
    fi

    echo -e "${YELLOW}${header_msg}${ENDCOLOR}"
    echo


    if [ -n "$help" ]; then
        echo -e "usage: ${YELLOW}gitb fixup <mode>${ENDCOLOR}"
        echo
        msg="${YELLOW}Mode${ENDCOLOR}_${GREEN}Aliases${ENDCOLOR}_\t${BLUE}Description${ENDCOLOR}"
        msg="$msg\n${BOLD}<empty>${ENDCOLOR}_ _Select files, pick a commit to fixup, create fixup commit, then autosquash"
        msg="$msg\n${BOLD}fast${ENDCOLOR}_f_Add all files, pick a commit to fixup, fixup commit, then autosquash"
        msg="$msg\n${BOLD}commit${ENDCOLOR}_c_Only create a fixup commit without autosquash (same as gitb c x)"
        msg="$msg\n${BOLD}push${ENDCOLOR}_p_Select files, fixup + autosquash + force push"
        msg="$msg\n${BOLD}fastp${ENDCOLOR}_fp|pf_Add all files, fixup + autosquash + force push"
        msg="$msg\n${BOLD}help${ENDCOLOR}_h_Show this help"
        echo -e "$(echo -e "$msg" | column -ts'_')"
        exit
    fi


    ### Step 1: Stage files
    if [ -n "$fixup_fast" ]; then
        # Check if there are changes
        if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
            echo -e "${GREEN}No changes to commit${ENDCOLOR}"
            exit
        fi

        echo -e "${YELLOW}Step 1.${ENDCOLOR} Adding all files"
        git add -A
        echo -e "${GREEN}All files staged${ENDCOLOR}"

        echo -e "${YELLOW}Staged files:${ENDCOLOR}"
        print_staged_files
    else
        # Check if there are changes
        changes=$(git_status)
        if [ -z "$changes" ]; then
            echo -e "${GREEN}No changes to commit${ENDCOLOR}"
            exit
        fi

        echo -e "${YELLOW}Step 1.${ENDCOLOR} Select files to commit"
        echo "$changes"
        echo

        echo "Enter file patterns to stage (like git add command)"
        echo "Press Enter if you want to exit"

        while [ true ]; do
            read -p "$(echo -n -e "${BOLD}git add${ENDCOLOR} ")" -e git_add

            if [ "$git_add" == "" ]; then
                exit
            fi

            if ! sanitize_file_path "$git_add"; then
                show_sanitization_error "file pattern" "Invalid file path or pattern."
                continue
            fi
            git_add="$sanitized_file_path"

            add_output=$(git add $git_add 2>&1)
            add_code=$?

            if [ $add_code -eq 0 ]; then
                break
            else
                echo -e "${RED}$add_output${ENDCOLOR}"
                echo
            fi
        done

        echo
        echo -e "${YELLOW}Staged files:${ENDCOLOR}"
        print_staged_files
    fi


    ### Step 2: Select commit to fixup
    echo
    echo -e "${YELLOW}Step 2.${ENDCOLOR} Select a commit to ${YELLOW}--fixup${ENDCOLOR}:"

    choose_commit 9

    ### Step 3: Create fixup commit
    echo
    echo -e "${YELLOW}Creating fixup commit...${ENDCOLOR}"

    result=$(git commit --fixup $commit_hash 2>&1)
    commit_code=$?

    if [ $commit_code -ne 0 ]; then
        echo -e "${RED}Cannot create fixup commit! Error message:${ENDCOLOR}"
        echo "$result"
        if [ -n "$git_add" ]; then
            git restore --staged "$git_add"
        fi
        exit $commit_code
    fi

    after_commit "fixup"

    # If commit-only mode, stop here
    if [ -n "$fixup_commit_only" ]; then
        echo
        echo -e "Run ${YELLOW}gitb rebase a${ENDCOLOR} to autosquash, or ${YELLOW}gitb fixup${ENDCOLOR} next time for auto-squash"
        exit
    fi


    ### Step 3: Autosquash rebase
    echo
    echo -e "${YELLOW}Step 3.${ENDCOLOR} Running autosquash rebase..."
    echo

    # Find merge-base with main branch for the rebase target
    merge_base=$(git merge-base HEAD ${main_branch} 2>/dev/null)
    if [ -z "$merge_base" ] || [ "$merge_base" == "$(git rev-parse HEAD)" ]; then
        # Fallback: use HEAD~50 or root commit
        local_commit_count=$(git rev-list --count HEAD 2>/dev/null || echo "0")
        if [ "$local_commit_count" -gt 50 ]; then
            merge_base="HEAD~50"
        else
            merge_base=$(git rev-list --max-parents=0 HEAD 2>/dev/null | tail -1)
            if [ -z "$merge_base" ]; then
                merge_base="HEAD~10"
            fi
        fi
    fi

    # Run non-interactive autosquash
    rebase_output=$(GIT_SEQUENCE_EDITOR=true git rebase -i --autosquash $merge_base 3>&2 2>&1 1>&3)
    rebase_code=$?

    if [ $rebase_code -eq 0 ]; then
        echo -e "${GREEN}Autosquash rebase successful!${ENDCOLOR}"
    else
        if [[ $rebase_output == *"Resolve all conflicts"* ]]; then
            echo -e "${RED}Rebase has conflicts! Resolve them manually:${ENDCOLOR}"
            echo -e "  ${YELLOW}git rebase --continue${ENDCOLOR} after resolving"
            echo -e "  ${YELLOW}git rebase --abort${ENDCOLOR} to cancel"
        else
            echo -e "${RED}Autosquash rebase failed:${ENDCOLOR}"
            echo "$rebase_output"
        fi
        exit $rebase_code
    fi


    ### Step 4: Force push if requested
    if [ -n "$fixup_push" ]; then
        echo
        echo -e "${YELLOW}Force pushing after autosquash...${ENDCOLOR}"
        echo
        push_script f
    fi
}
