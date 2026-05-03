#!/usr/bin/env bash

### Script for moving git pointers
# Read README.md to get more information how to use it
# Use this script only with gitbasher


### Main function
# $1: mode
    # empty: preview and reset last commit (git reset HEAD^ --mixed)
    # soft: preview and reset last commit, but keep all files staged (git reset HEAD^ --soft)
    # undo: preview and undo last reset (git reset HEAD@{1})
    # interactive: select a commit to reset
    # ref: select a HEAD reference to reset
function reset_script {
    case "$1" in
        soft|s)         soft="true";;
        undo|u)         undo="true";;
        interactive|i)  interactive="true";;
        ref|r)          
            ref="true"
            interactive="true"
        ;;
        help|h) help="true";;
        *)
            wrong_mode "reset" $1
    esac


    header="GIT RESET"
    if [ -n "${ref}" ]; then
        header="$header REFERENCE"
    elif [ -n "${undo}" ]; then
        header="$header UNDO"
    elif [ -n "${soft}" ]; then
        header="$header --soft"
    elif [ -n "${help}" ]; then
        header="$header"
    else
        header="$header --mixed"
    fi
    echo -e "${YELLOW}${header}${ENDCOLOR}"
    echo


    if [ -n "$help" ]; then
        echo -e "usage: ${YELLOW}gitb reset <mode>${ENDCOLOR}"
        echo
        msg="${YELLOW}Mode${ENDCOLOR}_${GREEN}Aliases${ENDCOLOR}_\t${BLUE}Description${ENDCOLOR}"
        msg="$msg\n${BOLD}<empty>${ENDCOLOR}_ _Reset the last commit ${BLUE}(${YELLOW}git reset --mixed HEAD^${BLUE})${ENDCOLOR} — leaves changes unstaged"
        msg="$msg\n${BOLD}soft${ENDCOLOR}_s_Reset the last commit ${BLUE}(${YELLOW}git reset --soft HEAD^${BLUE})${ENDCOLOR} — keeps changes staged"
        msg="$msg\n${BOLD}undo${ENDCOLOR}_u_Undo the last reset ${BLUE}(${YELLOW}git reset --mixed HEAD@{1}${BLUE})${ENDCOLOR}"
        msg="$msg\n${BOLD}interactive${ENDCOLOR}_i_Pick a commit to reset to, then preview before applying"
        msg="$msg\n${BOLD}ref${ENDCOLOR}_r_Pick a reflog ref to reset to, then preview before applying"
        msg="$msg\n${BOLD}help${ENDCOLOR}_h_Show this help"
        echo -e "$(echo -e "$msg" | column -ts'_')"
        echo
        echo -e "${YELLOW}Examples${ENDCOLOR}"
        echo -e "  ${GREEN}gitb reset${ENDCOLOR}        Drop the last commit, keep its changes unstaged"
        echo -e "  ${GREEN}gitb reset soft${ENDCOLOR}   Drop the last commit, keep its changes staged"
        echo -e "  ${GREEN}gitb reset undo${ENDCOLOR}   Bring back the commit you just reset"
        echo -e "  ${GREEN}gitb reset i${ENDCOLOR}      Pick any commit to reset to, with a preview"
        exit
    fi

    cancelled_commit=$(git log -n 1 --pretty="%s | ${YELLOW}%h${ENDCOLOR} | ${CYAN}%cd${ENDCOLOR} (${GREEN}%cr${ENDCOLOR})")
    cancelled_action=$(git reflog -n 1 --pretty="%gs | ${YELLOW}%h${ENDCOLOR} |  ${CYAN}%cd${ENDCOLOR} (${GREEN}%cr${ENDCOLOR})")

    if [ -n "$interactive" ]; then
        if [ -n "$ref" ]; then
            echo -e "${YELLOW}Select a ref to move HEAD to:${ENDCOLOR}"
            ref_list 31
            echo "0. Exit"
            echo
            printf "Enter ref number: "
            choose "${refs_hash[@]}"
            commit_hash=$choice_result
            echo
        else
            echo -e "${YELLOW}Select a commit to reset:${ENDCOLOR}"
            choose_commit 9
        fi
    fi

    move_ref="HEAD^"
    if [ -n "$undo" ]; then
        move_ref="HEAD@{1}"
    elif [ -n "$commit_hash" ]; then
        move_ref=$commit_hash
    fi

    args="--mixed"
    if [ -n "$soft" ]; then
        args="--soft"
    fi
    
    target_commit=$(git log -n 1 --pretty="%s | ${YELLOW}%h${ENDCOLOR} | ${CYAN}%cd${ENDCOLOR} (${GREEN}%cr${ENDCOLOR})" "$move_ref" 2>/dev/null)
    if [ -z "$target_commit" ]; then
        echo -e "${RED}✗ Cannot resolve reset target: $move_ref${ENDCOLOR}"
        exit 1
    fi

    echo -e "${YELLOW}Current HEAD:${ENDCOLOR}\t$cancelled_commit"
    if [ -n "$ref" ] || [ -n "$undo" ]; then
        echo -e "${YELLOW}Current action:${ENDCOLOR}\t$cancelled_action"
    fi
    echo -e "${GREEN}Reset target:${ENDCOLOR}\t$move_ref -> $target_commit"
    echo -e "${BLUE}Reset type:${ENDCOLOR}\t$args"
    echo

    if [ "$args" = "--soft" ]; then
        echo -e "This will move HEAD and ${GREEN}keep reset changes staged${ENDCOLOR}."
    else
        echo -e "${YELLOW}⚠  This will move HEAD; reset changes will be left unstaged.${ENDCOLOR}"
    fi
    echo -e "Are you sure you want to continue (y/n)?"
    yes_no_choice "Resetting..."

    reset_output=$(git reset "$args" "$move_ref" 2>&1)
    check_code $? "$reset_output" "reset"

    new_commit=$(git log -n 1 --pretty="%s | ${YELLOW}%h${ENDCOLOR} | ${CYAN}%cd${ENDCOLOR} (${GREEN}%cr${ENDCOLOR})")
    new_action=$(git reflog -n 1 --pretty="%gs | ${YELLOW}%h${ENDCOLOR} | ${CYAN}%cd${ENDCOLOR} (${GREEN}%cr${ENDCOLOR})")

    echo -e "${GREEN}✓ Reset complete${ENDCOLOR}"
    echo

    msg="${GREEN}New last commit:${ENDCOLOR}|${new_commit}"
    if [ -n "$ref" ] || [ -n "$undo" ]; then
        msg="${msg}\n${GREEN}New last action:${ENDCOLOR}|${new_action}"
    fi
    msg="${msg}\n${RED}Cancelled commit:${ENDCOLOR}|${cancelled_commit}"
    if [ -n "$ref" ] || [ -n "$undo" ]; then
        msg="${msg}\n${RED}Cancelled action:${ENDCOLOR}|${cancelled_action}"
    fi
    msg=$(echo -e "$msg" | column -ts'|')
    echo -e "$msg"
    echo

    echo -e "${YELLOW}Status after reset${ENDCOLOR}"
    git_status
    exit
}