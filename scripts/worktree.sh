#!/usr/bin/env bash

### Script for managing git worktrees: list, add, remove, prune, lock, move
# Worktrees let you check out multiple branches at once into separate directories
# linked to the same repository. Useful for switching contexts without stashing.
# Use this script only with gitbasher


### Function lists worktrees and stores them in arrays
# Returns:
#     worktrees_path   - array of worktree paths
#     worktrees_head   - array of HEAD/branch labels (one per worktree)
#     worktrees_info   - array of pretty-formatted display lines
#     worktrees_locked - parallel array; non-empty string when entry is locked
function list_worktrees_data {
    worktrees_path=()
    worktrees_head=()
    worktrees_info=()
    worktrees_locked=()

    local raw
    raw=$(git worktree list --porcelain 2>&1)
    if [ $? -ne 0 ]; then
        return 1
    fi

    local cur_path="" cur_head="" cur_branch="" cur_bare="" cur_detached="" cur_locked="" cur_prunable=""
    local main_path
    main_path=$(git rev-parse --show-toplevel 2>/dev/null)

    flush_worktree() {
        if [ -z "$cur_path" ]; then
            return
        fi
        local label
        if [ -n "$cur_bare" ]; then
            label="(bare)"
        elif [ -n "$cur_branch" ]; then
            label="${cur_branch#refs/heads/}"
        elif [ -n "$cur_detached" ]; then
            label="(detached @ ${cur_head:0:7})"
        else
            label="${cur_head:0:7}"
        fi

        worktrees_path+=("$cur_path")
        worktrees_head+=("$label")
        worktrees_locked+=("$cur_locked")

        local marker="  "
        if [ "$cur_path" == "$main_path" ]; then
            marker="* "
        fi

        local extras=""
        if [ -n "$cur_locked" ]; then
            extras="${extras} ${YELLOW_ES}[locked]${ENDCOLOR_ES}"
        fi
        if [ -n "$cur_prunable" ]; then
            extras="${extras} ${RED_ES}[prunable]${ENDCOLOR_ES}"
        fi

        worktrees_info+=("${marker}${BLUE_ES}${label}${ENDCOLOR_ES} | ${cur_path}${extras}")

        cur_path=""; cur_head=""; cur_branch=""; cur_bare=""; cur_detached=""; cur_locked=""; cur_prunable=""
    }

    while IFS= read -r line; do
        case "$line" in
            "worktree "*)  flush_worktree; cur_path="${line#worktree }" ;;
            "HEAD "*)      cur_head="${line#HEAD }" ;;
            "branch "*)    cur_branch="${line#branch }" ;;
            "bare")        cur_bare="true" ;;
            "detached")    cur_detached="true" ;;
            "locked"*)     cur_locked="true" ;;
            "prunable"*)   cur_prunable="true" ;;
            "")            flush_worktree ;;
        esac
    done <<< "$raw"
    flush_worktree
    unset -f flush_worktree

    return 0
}


### Function prints a numbered list of worktrees and lets user pick one
# $1: filter mode
#     * "" - all worktrees
#     * "removable" - exclude the main / current worktree
# Returns:
#     selected_worktree_path
#     selected_worktree_head
#     selected_worktree_locked - non-empty string when the picked worktree is locked
function choose_worktree {
    local filter="$1"
    if ! list_worktrees_data; then
        echo -e "${RED}Failed to list worktrees${ENDCOLOR}"
        return 1
    fi

    if [ ${#worktrees_path[@]} -eq 0 ]; then
        echo -e "${YELLOW}No worktrees found${ENDCOLOR}"
        return 1
    fi

    local current_path
    current_path=$(git rev-parse --show-toplevel 2>/dev/null)
    local main_path
    main_path=$(git worktree list --porcelain 2>/dev/null | awk 'NR==1 && /^worktree /{print substr($0,10); exit}')

    local display_paths=() display_heads=() display_lines=() display_locked=()
    for index in "${!worktrees_path[@]}"; do
        local p="${worktrees_path[$index]}"
        if [ "$filter" == "removable" ]; then
            if [ "$p" == "$main_path" ] || [ "$p" == "$current_path" ]; then
                continue
            fi
        fi
        display_paths+=("$p")
        display_heads+=("${worktrees_head[$index]}")
        display_lines+=("${worktrees_info[$index]}")
        display_locked+=("${worktrees_locked[$index]}")
    done

    if [ ${#display_paths[@]} -eq 0 ]; then
        if [ "$filter" == "removable" ]; then
            echo -e "${YELLOW}No removable worktrees found${ENDCOLOR}"
            echo -e "(the main worktree and the current one are excluded)"
        else
            echo -e "${YELLOW}No worktrees found${ENDCOLOR}"
        fi
        return 1
    fi

    local lines_str
    lines_str=$(printf '%s\n' "${display_lines[@]}" | column -ts'|')
    local IFS_OLD="$IFS"
    IFS=$'\n' read -rd '' -a aligned_lines <<< "$lines_str" || true
    IFS="$IFS_OLD"

    for index in "${!display_paths[@]}"; do
        echo -e "$(($index+1)). ${aligned_lines[$index]}"
    done

    if [ ${#display_paths[@]} -gt 9 ]; then
        echo "00. Exit"
    else
        echo "0. Exit"
    fi
    echo

    read_prefix="Select worktree number: "
    choose "${display_paths[@]}"
    selected_worktree_path="$choice_result"
    selected_worktree_locked=""

    for index in "${!display_paths[@]}"; do
        if [ "${display_paths[$index]}" == "$selected_worktree_path" ]; then
            selected_worktree_head="${display_heads[$index]}"
            selected_worktree_locked="${display_locked[$index]}"
            break
        fi
    done

    return 0
}


### Function returns a sensible default path for a new worktree
# $1: branch name (must be sanitized already)
# Returns: prints the path
#
# Layout:
#   - default:                          <repo_root>/.worktree/<safe_branch>
#   - gitbasher.worktreebase = absolute <base>/<safe_branch>
#   - gitbasher.worktreebase = relative <repo_root>/<base>/<safe_branch>
function default_worktree_path {
    local branch="$1"
    local base
    base=$(get_config_value gitbasher.worktreebase "")

    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null)

    # Replace path-unfriendly slashes in branch name with dashes for the dir name
    local safe_branch
    safe_branch=$(echo "$branch" | tr '/' '-')

    if [ -z "$base" ]; then
        base=".worktree"
    fi

    if [[ "$base" == /* ]]; then
        echo "${base%/}/${safe_branch}"
    else
        echo "${repo_root}/${base%/}/${safe_branch}"
    fi
}


### Function prompts for a branch name with optional prefix detection
# Mirrors the flow used by `gitb branch new` so users get a familiar UX
# Returns:
#     wt_branch_name - sanitized, fully qualified branch name
function prompt_worktree_branch {
    local from_label="${1:-$current_branch}"

    detected_prefixes=""
    all_branches=$(git branch -a --format='%(refname:short)' 2>/dev/null | sed 's|origin/||g' | sort -u)
    if [ -n "$all_branches" ]; then
        declare -A prefix_candidates
        while IFS= read -r branch; do
            if [ -n "$branch" ] && [[ "$branch" != "$main_branch" ]] && [[ "$branch" != "HEAD" ]]; then
                if [[ "$branch" =~ ^([a-zA-Z0-9]+)[-_/](.+)$ ]]; then
                    prefix="${BASH_REMATCH[1]}"
                    if [[ ${#prefix} -ge 2 ]] && [[ ! "$prefix" =~ ^(dev|tmp|old|new|test)$ ]]; then
                        prefix_candidates["$prefix"]=1
                    fi
                fi
            fi
        done <<< "$all_branches"

        detected_prefixes_array=()
        for prefix in "${!prefix_candidates[@]}"; do
            detected_prefixes_array+=("$prefix")
        done

        if [ ${#detected_prefixes_array[@]} -gt 0 ]; then
            IFS=$'\n' detected_prefixes_sorted=($(sort <<<"${detected_prefixes_array[*]}"))
            unset IFS
            detected_prefixes="${detected_prefixes_sorted[*]}"
        fi
    fi

    all_prefixes=""
    if [ -n "$ticket_name" ]; then
        if [ -n "$detected_prefixes" ]; then
            all_prefixes="$ticket_name $detected_prefixes"
        else
            all_prefixes="$ticket_name"
        fi
    elif [ -n "$detected_prefixes" ]; then
        all_prefixes="$detected_prefixes"
    fi

    local branch_type="" branch_type_and_sep=""

    if [ -z "$all_prefixes" ]; then
        echo -e "${YELLOW}Step 1.${ENDCOLOR} Enter the full name of the branch (worktree from ${BOLD}${BLUE}${from_label}${ENDCOLOR})"
        echo "Press Enter if you want to exit"

        printf "${BOLD}git branch${ENDCOLOR} "
        read -e branch_name

        if [ -z "$branch_name" ]; then
            return 1
        fi

        if ! sanitize_git_name "$branch_name"; then
            show_sanitization_error "branch name" "Use only letters, numbers, dots, dashes, underscores, and slashes."
            return 1
        fi
        wt_branch_name="$sanitized_git_name"
    else
        echo -e "${YELLOW}Step 1.${ENDCOLOR} Enter a ${YELLOW}prefix${ENDCOLOR} for the new branch (worktree from ${BOLD}${BLUE}${from_label}${ENDCOLOR})"
        echo -e "A branch will be created with '${YELLOW}${sep}${ENDCOLOR}' as a separator (e.g., ${YELLOW}prefix${sep}name${ENDCOLOR})"
        echo -e "Press Enter to continue without prefix or enter 0 to exit without changes"

        IFS=' ' read -r -a prefixes_array <<< "$all_prefixes"
        declare -A prefixes_map

        local res=""
        for i in "${!prefixes_array[@]}"; do
            local option=$((i+1))
            prefixes_map["$option"]="${prefixes_array[$i]}"
            res="$res$option. ${BOLD}${prefixes_array[$i]}${ENDCOLOR}|"
        done

        local no_prefix_option=$((${#prefixes_array[@]}+1))
        prefixes_map["$no_prefix_option"]=""

        echo -e "You can select one of the ${YELLOW}detected prefixes${ENDCOLOR}: $(echo $res | column -ts'|')"

        while [ true ]; do
            read -p "<prefix>: " choice

            if [ "$choice" == "0" ]; then
                return 1
            fi

            if [ "$choice" == "" ]; then
                branch_type=""
                branch_type_and_sep=""
                break
            fi

            local re='^[1-9][0-9]*$'
            if [[ $choice =~ $re ]] && [ -n "${prefixes_map[$choice]+isset}" ]; then
                branch_type="${prefixes_map[$choice]}"
                if [ -n "$branch_type" ]; then
                    branch_type_and_sep="${branch_type}${sep}"
                fi
                break
            else
                if [ -n "$choice" ]; then
                    if ! sanitize_git_name "$choice"; then
                        show_sanitization_error "branch prefix" "Use only letters, numbers, dots, dashes, underscores, and slashes."
                        echo
                        continue
                    fi
                    branch_type="$sanitized_git_name"
                    branch_type_and_sep="${branch_type}${sep}"
                    break
                else
                    echo -e "${RED}Please enter a valid option number or custom prefix.${ENDCOLOR}"
                    echo
                    continue
                fi
            fi
        done

        echo
        echo -e "${YELLOW}Step 2.${ENDCOLOR} Enter the ${YELLOW}name${ENDCOLOR} of the branch"
        echo "Press Enter if you want to exit"

        printf "${BOLD}git branch${ENDCOLOR}"
        read -p " ${branch_type_and_sep}" -e branch_name

        if [ -z "$branch_name" ]; then
            return 1
        fi

        if ! sanitize_git_name "$branch_name"; then
            show_sanitization_error "branch name" "Use only letters, numbers, dots, dashes, underscores, and slashes."
            return 1
        fi
        wt_branch_name="${branch_type_and_sep}${sanitized_git_name}"
    fi

    if [[ "$wt_branch_name" == "HEAD" ]] || [[ "$wt_branch_name" == "$origin_name" ]]; then
        echo
        echo -e "${RED}This name is forbidden${ENDCOLOR}"
        return 1
    fi

    return 0
}


### Function prompts the user for a worktree path with a sensible default
# $1: default path (already calculated)
# Returns:
#     wt_path - sanitized path
function prompt_worktree_path {
    local default_path="$1"

    echo
    echo -e "${YELLOW}Where should the worktree live?${ENDCOLOR}"
    echo -e "Press Enter to accept the default, or type a different path"
    echo -e "Default: ${BOLD}${default_path}${ENDCOLOR}"

    read -p "Worktree path: " -e custom_path

    if [ -z "$custom_path" ]; then
        wt_path="$default_path"
    else
        if ! sanitize_file_path "$custom_path"; then
            show_sanitization_error "worktree path" "Path contains invalid characters."
            return 1
        fi
        wt_path="$sanitized_file_path"
    fi

    if [ -e "$wt_path" ]; then
        echo
        echo -e "${RED}Path '${wt_path}' already exists${ENDCOLOR}"
        return 1
    fi

    return 0
}


### Function adds a new worktree
# $1: source mode
#     * "current" - create a new branch from current HEAD
#     * "default" - fetch + create a new branch from default branch
#     * "branch"  - check out an existing local branch
#     * "remote"  - check out a remote branch
function worktree_add {
    local source_mode="$1"

    if [ "$source_mode" == "default" ]; then
        if [ -n "$origin_name" ]; then
            echo -e "${YELLOW}Fetching ${origin_name}/${main_branch}...${ENDCOLOR}"
            local fetch_output
            fetch_output=$(git fetch "$origin_name" "$main_branch" 2>&1)
            if [ $? -ne 0 ]; then
                echo -e "${RED}Failed to fetch ${main_branch}${ENDCOLOR}"
                echo "$fetch_output"
                return 1
            fi
            echo
        fi
    fi

    if [ "$source_mode" == "current" ] || [ "$source_mode" == "default" ]; then
        local from_label="$current_branch"
        local from_ref="HEAD"
        if [ "$source_mode" == "default" ]; then
            from_label="$main_branch"
            if [ -n "$origin_name" ] && git rev-parse --verify --quiet "$origin_name/$main_branch" >/dev/null 2>&1; then
                from_ref="$origin_name/$main_branch"
            else
                from_ref="$main_branch"
            fi
        fi

        if ! prompt_worktree_branch "$from_label"; then
            return 1
        fi

        if git show-ref --verify --quiet "refs/heads/$wt_branch_name" 2>/dev/null; then
            echo
            echo -e "${RED}Branch '${wt_branch_name}' already exists${ENDCOLOR}"
            echo -e "Use ${BOLD}gitb worktree addb${NORMAL} to attach an existing branch to a new worktree"
            return 1
        fi

        local default_path
        default_path=$(default_worktree_path "$wt_branch_name")
        if ! prompt_worktree_path "$default_path"; then
            return 1
        fi

        echo
        echo -e "${YELLOW}Creating worktree at ${BOLD}${wt_path}${NORMAL}${YELLOW} with new branch ${BOLD}${wt_branch_name}${NORMAL}${YELLOW} from ${BOLD}${from_label}${NORMAL}${YELLOW}...${ENDCOLOR}"

        local add_output
        add_output=$(git worktree add -b "$wt_branch_name" "$wt_path" "$from_ref" 2>&1)
        local add_code=$?

        echo
        if [ $add_code -eq 0 ]; then
            echo -e "${GREEN}Worktree created${ENDCOLOR}"
            echo -e "  branch: ${BLUE}${wt_branch_name}${ENDCOLOR}"
            echo -e "  path:   ${wt_path}"
            echo
            echo -e "Switch into it: ${YELLOW}cd ${wt_path}${ENDCOLOR}"
        else
            echo -e "${RED}Failed to create worktree${ENDCOLOR}"
            echo "$add_output"
            return $add_code
        fi
        return 0
    fi

    if [ "$source_mode" == "branch" ]; then
        echo -e "${YELLOW}Pick a local branch to check out into a new worktree${ENDCOLOR}"
        echo

        choose_branch
        echo

        if [ "$branch_name" == "$current_branch" ]; then
            echo -e "${RED}Branch '${branch_name}' is already checked out in this worktree${ENDCOLOR}"
            return 1
        fi

        local default_path
        default_path=$(default_worktree_path "$branch_name")
        if ! prompt_worktree_path "$default_path"; then
            return 1
        fi

        echo
        echo -e "${YELLOW}Creating worktree at ${BOLD}${wt_path}${NORMAL}${YELLOW} for ${BOLD}${branch_name}${NORMAL}${YELLOW}...${ENDCOLOR}"

        local add_output
        add_output=$(git worktree add "$wt_path" "$branch_name" 2>&1)
        local add_code=$?

        echo
        if [ $add_code -eq 0 ]; then
            echo -e "${GREEN}Worktree created${ENDCOLOR}"
            echo -e "  branch: ${BLUE}${branch_name}${ENDCOLOR}"
            echo -e "  path:   ${wt_path}"
            echo
            echo -e "Switch into it: ${YELLOW}cd ${wt_path}${ENDCOLOR}"
        else
            if [[ "$add_output" == *"already used by worktree"* ]]; then
                echo -e "${RED}Branch '${branch_name}' is already checked out in another worktree${ENDCOLOR}"
            else
                echo -e "${RED}Failed to create worktree${ENDCOLOR}"
            fi
            echo "$add_output"
            return $add_code
        fi
        return 0
    fi

    if [ "$source_mode" == "remote" ]; then
        if [ -z "$origin_name" ]; then
            echo -e "${RED}No git remote configured${ENDCOLOR}"
            return 1
        fi

        echo -e "${YELLOW}Fetching ${origin_name}...${ENDCOLOR}"
        echo
        local fetch_output
        fetch_output=$(git fetch "$origin_name" 2>&1)
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to fetch remote${ENDCOLOR}"
            echo "$fetch_output"
            return 1
        fi
        git remote prune "$origin_name" >/dev/null 2>&1

        echo -e "${YELLOW}Pick a remote branch to check out into a new worktree${ENDCOLOR}"
        choose_branch "remote"
        echo

        local default_path
        default_path=$(default_worktree_path "$branch_name")
        if ! prompt_worktree_path "$default_path"; then
            return 1
        fi

        echo
        echo -e "${YELLOW}Creating worktree at ${BOLD}${wt_path}${NORMAL}${YELLOW} tracking ${BOLD}${origin_name}/${branch_name}${NORMAL}${YELLOW}...${ENDCOLOR}"

        local add_output
        if git show-ref --verify --quiet "refs/heads/$branch_name" 2>/dev/null; then
            add_output=$(git worktree add "$wt_path" "$branch_name" 2>&1)
        else
            add_output=$(git worktree add --track -b "$branch_name" "$wt_path" "$origin_name/$branch_name" 2>&1)
        fi
        local add_code=$?

        echo
        if [ $add_code -eq 0 ]; then
            echo -e "${GREEN}Worktree created${ENDCOLOR}"
            echo -e "  branch: ${BLUE}${branch_name}${ENDCOLOR}"
            echo -e "  path:   ${wt_path}"
            echo
            echo -e "Switch into it: ${YELLOW}cd ${wt_path}${ENDCOLOR}"
        else
            echo -e "${RED}Failed to create worktree${ENDCOLOR}"
            echo "$add_output"
            return $add_code
        fi
        return 0
    fi
}


### Action: remove the already-selected worktree
# Assumes selected_worktree_path / selected_worktree_head are set.
function _do_worktree_remove {
    echo
    echo -e "${YELLOW}Removing worktree at ${BOLD}${selected_worktree_path}${NORMAL}${YELLOW} (${selected_worktree_head})...${ENDCOLOR}"

    local rm_output
    rm_output=$(git worktree remove "$selected_worktree_path" 2>&1)
    local rm_code=$?

    if [ $rm_code -eq 0 ]; then
        echo -e "${GREEN}Worktree removed${ENDCOLOR}"
        return 0
    fi

    if [[ "$rm_output" == *"contains modified or untracked files"* ]] || \
       [[ "$rm_output" == *"is dirty"* ]] || \
       [[ "$rm_output" == *"locked working tree"* ]] || \
       [[ "$rm_output" == *"is locked"* ]]; then
        echo -e "${RED}${rm_output}${ENDCOLOR}"
        echo
        echo -e "${YELLOW}Force remove this worktree? (uncommitted changes will be lost)${ENDCOLOR}"
        echo -e "Do you want to continue (y/n)?"
        yes_no_choice "Force removing worktree..."

        rm_output=$(git worktree remove --force "$selected_worktree_path" 2>&1)
        rm_code=$?

        if [ $rm_code -eq 0 ]; then
            echo -e "${GREEN}Worktree removed${ENDCOLOR}"
            return 0
        fi
    fi

    echo -e "${RED}Failed to remove worktree${ENDCOLOR}"
    echo "$rm_output"
    return $rm_code
}


### Function removes a worktree (interactive)
function worktree_remove {
    echo -e "${YELLOW}Pick a worktree to remove${ENDCOLOR}"
    echo

    if ! choose_worktree "removable"; then
        return 1
    fi

    _do_worktree_remove
}


### Function prunes stale worktree records (admin entries left after manual deletion)
function worktree_prune {
    echo -e "${YELLOW}Pruning stale worktree records...${ENDCOLOR}"
    echo

    local dry_run
    dry_run=$(git worktree prune --dry-run --verbose 2>&1)
    if [ -z "$dry_run" ]; then
        echo -e "${GREEN}Nothing to prune${ENDCOLOR}"
        return 0
    fi

    echo -e "${YELLOW}Records that would be removed:${ENDCOLOR}"
    echo "$dry_run"
    echo

    echo -e "${YELLOW}Continue? (y/n)${ENDCOLOR}"
    yes_no_choice "Pruning..."

    local prune_output
    prune_output=$(git worktree prune --verbose 2>&1)
    local prune_code=$?

    if [ $prune_code -eq 0 ]; then
        if [ -n "$prune_output" ]; then
            echo "$prune_output"
        fi
        echo -e "${GREEN}Done${ENDCOLOR}"
        return 0
    fi

    echo -e "${RED}Failed to prune worktrees${ENDCOLOR}"
    echo "$prune_output"
    return $prune_code
}


### Action: lock or unlock the already-selected worktree
# $1: action - "lock" or "unlock"
# Assumes selected_worktree_path is set.
function _do_worktree_lock_unlock {
    local action="$1"

    local reason=""
    if [ "$action" == "lock" ]; then
        echo
        read -p "Reason for the lock (optional, press Enter to skip): " -e reason
        if [ -n "$reason" ]; then
            if ! sanitize_text_input "$reason" 200; then
                show_sanitization_error "lock reason" "Use printable characters only, max 200 characters."
                return 1
            fi
            reason="$sanitized_text"
        fi
    fi

    echo
    local out
    if [ "$action" == "lock" ]; then
        if [ -n "$reason" ]; then
            out=$(git worktree lock --reason "$reason" "$selected_worktree_path" 2>&1)
        else
            out=$(git worktree lock "$selected_worktree_path" 2>&1)
        fi
    else
        out=$(git worktree unlock "$selected_worktree_path" 2>&1)
    fi
    local code=$?

    if [ $code -eq 0 ]; then
        echo -e "${GREEN}Worktree ${action}ed${ENDCOLOR}: ${selected_worktree_path}"
        return 0
    fi

    echo -e "${RED}Failed to ${action} worktree${ENDCOLOR}"
    echo "$out"
    return $code
}


### Function locks or unlocks a worktree
# $1: action - "lock" or "unlock"
function worktree_lock_unlock {
    local action="$1"

    echo -e "${YELLOW}Pick a worktree to ${action}${ENDCOLOR}"
    echo

    if ! choose_worktree; then
        return 1
    fi

    _do_worktree_lock_unlock "$action"
}


### Action: move the already-selected worktree
# Assumes selected_worktree_path is set.
function _do_worktree_move {
    echo
    echo -e "${YELLOW}New path for the worktree${ENDCOLOR}"
    echo -e "Current path: ${BOLD}${selected_worktree_path}${NORMAL}"
    read -p "New path: " -e new_path

    if [ -z "$new_path" ]; then
        echo -e "${YELLOW}Cancelled${ENDCOLOR}"
        return 1
    fi

    if ! sanitize_file_path "$new_path"; then
        show_sanitization_error "worktree path" "Path contains invalid characters."
        return 1
    fi
    new_path="$sanitized_file_path"

    if [ -e "$new_path" ]; then
        echo
        echo -e "${RED}Path '${new_path}' already exists${ENDCOLOR}"
        return 1
    fi

    echo
    echo -e "${YELLOW}Moving worktree to ${BOLD}${new_path}${NORMAL}${YELLOW}...${ENDCOLOR}"

    local mv_output
    mv_output=$(git worktree move "$selected_worktree_path" "$new_path" 2>&1)
    local mv_code=$?

    if [ $mv_code -eq 0 ]; then
        echo -e "${GREEN}Worktree moved${ENDCOLOR}"
        return 0
    fi

    echo -e "${RED}Failed to move worktree${ENDCOLOR}"
    echo "$mv_output"
    return $mv_code
}


### Function moves an existing worktree to a new path
function worktree_move {
    echo -e "${YELLOW}Pick a worktree to move${ENDCOLOR}"
    echo

    if ! choose_worktree "removable"; then
        return 1
    fi

    _do_worktree_move
}


### Function picks a worktree, then offers Move / Lock-or-Unlock / Delete
function worktree_manage {
    echo -e "${YELLOW}Pick a worktree to manage${ENDCOLOR}"
    echo

    if ! choose_worktree "removable"; then
        return 1
    fi

    echo
    echo -e "${YELLOW}What do you want to do with ${BOLD}${BLUE}${selected_worktree_head}${NORMAL}${YELLOW}?${ENDCOLOR}"
    echo
    echo "1. Move it"
    if [ -n "$selected_worktree_locked" ]; then
        echo "2. Unlock it"
    else
        echo "2. Lock it"
    fi
    echo "3. Delete it"
    echo "0. Exit"
    echo

    local choice
    read -n 1 -s choice
    read -t 0.01 -s _wt_drain 2>/dev/null

    case "$choice" in
        1) _do_worktree_move ;;
        2)
            if [ -n "$selected_worktree_locked" ]; then
                _do_worktree_lock_unlock "unlock"
            else
                _do_worktree_lock_unlock "lock"
            fi
            ;;
        3) _do_worktree_remove ;;
        0) exit ;;
        *) echo -e "${RED}Invalid option${ENDCOLOR}"; return 1 ;;
    esac
}


### Function prints the path of a chosen worktree (so the user can `cd $(...)`)
function worktree_path {
    echo -e "${YELLOW}Pick a worktree${ENDCOLOR}"
    echo

    if ! choose_worktree; then
        return 1
    fi

    echo
    echo -e "${GREEN}Path:${ENDCOLOR} ${selected_worktree_path}"
    echo
    echo -e "Open it with: ${YELLOW}cd ${selected_worktree_path}${ENDCOLOR}"
    return 0
}


### Function spawns a subshell inside a chosen worktree
# A child process can't change its parent shell's CWD, so we exec a fresh
# interactive shell at the worktree path. `exit` / Ctrl-D returns to the
# original shell at the original CWD.
function worktree_goto {
    echo -e "${YELLOW}Pick a worktree to go to${ENDCOLOR}"
    echo

    if ! choose_worktree; then
        return 1
    fi

    local current_path
    current_path=$(git rev-parse --show-toplevel 2>/dev/null)
    if [ "$selected_worktree_path" == "$current_path" ]; then
        echo
        echo -e "${YELLOW}Already inside ${selected_worktree_path}${ENDCOLOR}"
        return 0
    fi

    if [ ! -d "$selected_worktree_path" ]; then
        echo
        echo -e "${RED}Path '${selected_worktree_path}' does not exist on disk${ENDCOLOR}"
        echo -e "Try ${BOLD}gitb worktree prune${NORMAL} to clean up stale records"
        return 1
    fi

    echo
    echo -e "${GREEN}Entering ${ENDCOLOR}${selected_worktree_path}"
    echo -e "Type ${YELLOW}exit${ENDCOLOR} or press ${YELLOW}Ctrl-D${ENDCOLOR} to return"
    echo

    cd "$selected_worktree_path" || return 1
    exec "${SHELL:-/bin/bash}"
}


### Main function
# $1: mode
function worktree_script {
    case "$1" in
        list|l|ls)              list_mode="true";;
        add|a|new|n|c)          add_mode="true"; add_source="current";;
        addd|ad|nd)             add_mode="true"; add_source="default";;
        addb|ab|from|b)         add_mode="true"; add_source="branch";;
        addr|ar|remote|r)       add_mode="true"; add_source="remote";;
        remove|rm|del|d)        remove_mode="true";;
        prune|pr|p)             prune_mode="true";;
        lock)                   lock_mode="true";;
        unlock|ul)              unlock_mode="true";;
        move|mv)                move_mode="true";;
        manage|m)               manage_mode="true";;
        path|sw)                path_mode="true";;
        goto|go|g|cd|switch)    goto_mode="true";;
        help|h)                 help="true";;
        "")                     interactive="true";;
        *)                      wrong_mode "worktree" "$1";;
    esac

    ### Print header
    local header="GIT WORKTREE"
    if [ -n "$list_mode" ]; then
        header="$header LIST"
    elif [ -n "$add_mode" ]; then
        case "$add_source" in
            current) header="$header ADD" ;;
            default) header="$header ADD FROM DEFAULT" ;;
            branch)  header="$header ADD FROM BRANCH" ;;
            remote)  header="$header ADD FROM REMOTE" ;;
        esac
    elif [ -n "$remove_mode" ]; then
        header="$header REMOVE"
    elif [ -n "$prune_mode" ]; then
        header="$header PRUNE"
    elif [ -n "$lock_mode" ]; then
        header="$header LOCK"
    elif [ -n "$unlock_mode" ]; then
        header="$header UNLOCK"
    elif [ -n "$move_mode" ]; then
        header="$header MOVE"
    elif [ -n "$manage_mode" ]; then
        header="$header MANAGE"
    elif [ -n "$path_mode" ]; then
        header="$header PATH"
    elif [ -n "$goto_mode" ]; then
        header="$header GO TO"
    fi

    echo -e "${YELLOW}${header}${ENDCOLOR}"
    echo

    if [ -n "$help" ]; then
        echo -e "usage: ${YELLOW}gitb worktree <mode>${ENDCOLOR}"
        echo
        msg="${YELLOW}Mode${ENDCOLOR}_${GREEN}Aliases${ENDCOLOR}_\t${BLUE}Description${ENDCOLOR}"
        msg="$msg\n${BOLD}<empty>${ENDCOLOR}_ _Show interactive worktree menu"
        msg="$msg\n${BOLD}list${ENDCOLOR}_l|ls_List all worktrees"
        msg="$msg\n${BOLD}add${ENDCOLOR}_a|new|n|c_Create a worktree with a new branch from current HEAD"
        msg="$msg\n${BOLD}addd${ENDCOLOR}_ad|nd_Fetch + create worktree with new branch from $main_branch"
        msg="$msg\n${BOLD}addb${ENDCOLOR}_ab|from|b_Create a worktree from an existing local branch"
        msg="$msg\n${BOLD}addr${ENDCOLOR}_ar|remote|r_Fetch + create worktree tracking a remote branch"
        msg="$msg\n${BOLD}manage${ENDCOLOR}_m_Pick a worktree, then move / lock / unlock / delete"
        msg="$msg\n${BOLD}move${ENDCOLOR}_mv_Move a worktree to a new path"
        msg="$msg\n${BOLD}lock${ENDCOLOR}_ _Lock a worktree (with optional reason)"
        msg="$msg\n${BOLD}unlock${ENDCOLOR}_ul_Unlock a worktree"
        msg="$msg\n${BOLD}remove${ENDCOLOR}_rm|del|d_Remove a worktree (interactive picker)"
        msg="$msg\n${BOLD}prune${ENDCOLOR}_pr|p_Remove stale worktree records"
        msg="$msg\n${BOLD}path${ENDCOLOR}_sw_Print the path to a chosen worktree"
        msg="$msg\n${BOLD}goto${ENDCOLOR}_go|g|cd|switch_Open a subshell inside a chosen worktree"
        msg="$msg\n${BOLD}help${ENDCOLOR}_h_Show this help"
        echo -e "$(echo -e "$msg" | column -ts'_')"
        echo
        echo -e "${YELLOW}Tips${ENDCOLOR}"
        echo -e "  - Default worktree path: ${BOLD}<repo>/.worktree/<branch>${NORMAL} (add ${BOLD}.worktree/${NORMAL} to .gitignore)"
        echo -e "  - Override the base directory with ${BOLD}git config gitbasher.worktreebase <dir>${NORMAL} (relative paths resolve against repo root)"
        echo -e "  - Use ${BOLD}cd \$(gitb worktree path)${NORMAL} to jump into a worktree"
        exit
    fi

    ### Interactive menu when no mode is given
    if [ -n "$interactive" ]; then
        if list_worktrees_data; then
            if [ ${#worktrees_path[@]} -gt 0 ]; then
                echo -e "${YELLOW}Existing worktrees:${ENDCOLOR}"
                echo
                local lines_str
                lines_str=$(printf '%s\n' "${worktrees_info[@]}" | column -ts'|')
                echo -e "$lines_str"
                echo
            fi
        fi

        echo -e "${YELLOW}What do you want to do?${ENDCOLOR}"
        echo
        echo "1. Add a worktree"
        echo "2. Go to a worktree"
        echo "3. Manage a worktree"
        echo "4. Prune stale records"
        echo "0. Exit"
        echo

        local choice
        read -n 1 -s choice
        read -t 0.01 -s _wt_drain 2>/dev/null

        case "$choice" in
            1) add_mode="true";;
            2) goto_mode="true";;
            3) manage_mode="true";;
            4) prune_mode="true";;
            0) exit;;
            *) echo -e "${RED}Invalid option${ENDCOLOR}"; exit 1;;
        esac

        if [ -n "$add_mode" ]; then
            echo -e "${YELLOW}How should the worktree's branch be created?${ENDCOLOR}"
            echo
            echo "1. New branch from current"
            echo "2. New branch from $main_branch"
            echo "3. From existing local branch"
            echo "4. From remote branch"
            echo "0. Exit"
            echo

            local source_choice
            read -n 1 -s source_choice
            read -t 0.01 -s _wt_drain 2>/dev/null

            case "$source_choice" in
                1) add_source="current";;
                2) add_source="default";;
                3) add_source="branch";;
                4) add_source="remote";;
                0) exit;;
                *) echo -e "${RED}Invalid option${ENDCOLOR}"; exit 1;;
            esac
        fi
    fi

    if [ -n "$list_mode" ]; then
        if ! list_worktrees_data; then
            echo -e "${RED}Failed to list worktrees${ENDCOLOR}"
            exit 1
        fi
        if [ ${#worktrees_path[@]} -eq 0 ]; then
            echo -e "${YELLOW}No worktrees found${ENDCOLOR}"
            exit
        fi
        local lines_str
        lines_str=$(printf '%s\n' "${worktrees_info[@]}" | column -ts'|')
        echo -e "$lines_str"
        exit
    fi

    if [ -n "$add_mode" ]; then
        worktree_add "$add_source"
        exit
    fi

    if [ -n "$remove_mode" ]; then
        worktree_remove
        exit
    fi

    if [ -n "$prune_mode" ]; then
        worktree_prune
        exit
    fi

    if [ -n "$lock_mode" ]; then
        worktree_lock_unlock "lock"
        exit
    fi

    if [ -n "$unlock_mode" ]; then
        worktree_lock_unlock "unlock"
        exit
    fi

    if [ -n "$move_mode" ]; then
        worktree_move
        exit
    fi

    if [ -n "$manage_mode" ]; then
        worktree_manage
        exit
    fi

    if [ -n "$path_mode" ]; then
        worktree_path
        exit
    fi

    if [ -n "$goto_mode" ]; then
        worktree_goto
        exit
    fi
}
