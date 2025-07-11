#!/usr/bin/env bash


### Consts for colors to use inside 'sed'
RED_ES="\x1b[31m"
GREEN_ES="\x1b[32m"
YELLOW_ES="\x1b[33m"
BLUE_ES="\x1b[34m"
PURPLE_ES="\x1b[35m"
CYAN_ES="\x1b[36m"
GRAY_ES="\x1b[37m"
ENDCOLOR_ES="\x1b[0m"


### ===== INPUT SANITIZATION FRAMEWORK =====
### These functions provide security validation for all user inputs

### Function to sanitize git-safe names (branches, tags, etc.)
# $1: input string
# Returns: sanitized string safe for git operations
# Sets: sanitized_git_name global variable
function sanitize_git_name {
    local input="$1"
    sanitized_git_name=""
    
    if [ -z "$input" ]; then
        return 1
    fi
    
    # Remove dangerous characters, keep git-safe ones
    # Allow: letters, numbers, dash, underscore, dot, slash
    local cleaned=$(echo "$input" | sed 's/[^a-zA-Z0-9._/-]//g')
    
    # Remove leading/trailing dots and slashes (git restrictions)
    cleaned=$(echo "$cleaned" | sed 's/^[./]*//;s/[./]*$//')
    
    # Prevent git-unsafe patterns
    if [[ "$cleaned" =~ \.\. ]] || [[ "$cleaned" =~ ^- ]] || [[ "$cleaned" =~ -$ ]] || \
       [[ "$cleaned" =~ ^@ ]] || [[ "$cleaned" == "HEAD" ]] || [[ "$cleaned" =~ ^refs/ ]]; then
        return 1
    fi
    
    # Ensure minimum length
    if [ ${#cleaned} -lt 1 ] || [ ${#cleaned} -gt 255 ]; then
        return 1
    fi
    
    sanitized_git_name="$cleaned"
    return 0
}

### Function to sanitize file paths and patterns for git add
# $1: input string
# Returns: sanitized string safe for file operations
# Sets: sanitized_file_path global variable
function sanitize_file_path {
    local input="$1"
    sanitized_file_path=""
    
    if [ -z "$input" ]; then
        return 1
    fi
    
    # Remove null bytes and control characters (except tab and newline for multiline patterns)
    local cleaned=$(echo "$input" | tr -d '\000-\010\013\014\016-\037\177')
    
    # Remove dangerous sequences
    cleaned=$(echo "$cleaned" | sed 's/\.\.\///g')  # Remove ../
    cleaned=$(echo "$cleaned" | sed 's/;\s*rm\s/; /g')  # Remove rm commands
    cleaned=$(echo "$cleaned" | sed 's/&&\s*rm\s/\&\& /g')  # Remove rm commands
    cleaned=$(echo "$cleaned" | sed 's/|\s*rm\s/| /g')  # Remove rm commands
    
    # Limit length
    if [ ${#cleaned} -gt 1000 ]; then
        return 1
    fi
    
    sanitized_file_path="$cleaned"
    return 0
}

### Function to sanitize commit messages
# $1: input string
# Returns: sanitized commit message
# Sets: sanitized_commit_message global variable
function sanitize_commit_message {
    local input="$1"
    sanitized_commit_message=""
    
    if [ -z "$input" ]; then
        return 1
    fi
    
    # Remove null bytes and control characters except newlines and tabs
    local cleaned=$(echo "$input" | tr -d '\000-\010\013\014\016-\037\177')
    
    # Trim leading/trailing whitespace
    cleaned=$(echo "$cleaned" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    
    # Validate length (typical git limit is ~50-72 chars for subject, longer for body)
    if [ ${#cleaned} -lt 1 ] || [ ${#cleaned} -gt 2000 ]; then
        return 1
    fi
    
    sanitized_commit_message="$cleaned"
    return 0
}

### Function to sanitize command names (like editor)
# $1: input string
# Returns: sanitized command name
# Sets: sanitized_command global variable
function sanitize_command {
    local input="$1"
    sanitized_command=""
    
    if [ -z "$input" ]; then
        return 1
    fi
    
    # Only allow alphanumeric, dash, underscore, and slash for paths
    local cleaned=$(echo "$input" | sed 's/[^a-zA-Z0-9._/-]//g')
    
    # Remove dangerous patterns
    if [[ "$cleaned" =~ \.\. ]] || [[ "$cleaned" == *";"* ]] || [[ "$cleaned" == *"|"* ]] || \
       [[ "$cleaned" == *"&"* ]] || [[ "$cleaned" == *"$"* ]] || [[ "$cleaned" == *"\`"* ]]; then
        return 1
    fi
    
    # Validate length and format
    if [ ${#cleaned} -lt 1 ] || [ ${#cleaned} -gt 100 ] || [[ "$cleaned" =~ ^- ]]; then
        return 1
    fi
    
    sanitized_command="$cleaned"
    return 0
}

### Function to sanitize general text input
# $1: input string
# $2: max length (optional, default 500)
# Returns: sanitized text
# Sets: sanitized_text global variable
function sanitize_text_input {
    local input="$1"
    local max_length="${2:-500}"
    sanitized_text=""
    
    if [ -z "$input" ]; then
        return 1
    fi
    
    # Remove null bytes and most control characters, keep printable ones
    local cleaned=$(echo "$input" | tr -d '\000-\010\013\014\016-\037\177')
    
    # Trim whitespace
    cleaned=$(echo "$cleaned" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    
    # Validate length
    if [ ${#cleaned} -lt 1 ] || [ ${#cleaned} -gt "$max_length" ]; then
        return 1
    fi
    
    sanitized_text="$cleaned"
    return 0
}

### Function to validate numeric input
# $1: input string
# $2: min value (optional)
# $3: max value (optional)
# Returns: 0 if valid number, 1 if invalid
# Sets: validated_number global variable
function validate_numeric_input {
    local input="$1"
    local min_val="$2"
    local max_val="$3"
    validated_number=""
    
    if [ -z "$input" ]; then
        return 1
    fi
    
    # Check if it's a valid positive integer
    if ! [[ "$input" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    
    # Convert to number for range checking
    local num=$((input))
    
    # Check minimum value
    if [ -n "$min_val" ] && [ "$num" -lt "$min_val" ]; then
        return 1
    fi
    
    # Check maximum value
    if [ -n "$max_val" ] && [ "$num" -gt "$max_val" ]; then
        return 1
    fi
    
    validated_number="$num"
    return 0
}

### Function to validate email format
# $1: email string
# Returns: 0 if valid email format, 1 if invalid
# Sets: validated_email global variable
function validate_email {
    local input="$1"
    validated_email=""
    
    if [ -z "$input" ]; then
        return 1
    fi
    
    # Basic email regex validation
    if [[ "$input" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        # Additional length check
        if [ ${#input} -le 254 ]; then
            validated_email="$input"
            return 0
        fi
    fi
    
    return 1
}

### Function to validate scope list
# $1: scope list string
# Returns: 0 if valid, 1 if invalid
# Sets: validated_scopes global variable
function validate_scope_list {
    local input="$1"
    validated_scopes=""
    
    if [ -z "$input" ]; then
        return 1
    fi
    
    # Check format: letters and spaces only, max 9 scopes
    if [[ "$input" =~ ^([a-zA-Z]+ ){0,8}([a-zA-Z]+)$ ]]; then
        # Count words
        local word_count=$(echo "$input" | wc -w)
        if [ "$word_count" -le 9 ] && [ "$word_count" -ge 1 ]; then
            validated_scopes="$input"
            return 0
        fi
    fi
    
    return 1
}

### Function to sanitize choice input (y/n/numbers/etc.)
# $1: input string
# $2: allowed pattern (optional, default allows y/n/0-9/=)
# Returns: sanitized choice
# Sets: sanitized_choice global variable
function sanitize_choice_input {
    local input="$1"
    local pattern="${2:-^[yn0-9=]$}"
    sanitized_choice=""
    
    if [ -z "$input" ]; then
        return 1
    fi
    
    # Convert to lowercase for consistency
    local cleaned=$(echo "$input" | tr '[:upper:]' '[:lower:]')
    
    # Validate against pattern
    if [[ "$cleaned" =~ $pattern ]]; then
        sanitized_choice="$cleaned"
        return 0
    fi
    
    return 1
}

### Function to display sanitization error with helpful message
# $1: input type name
# $2: error message
function show_sanitization_error {
    local input_type="$1"
    local error_msg="$2"
    
    echo -e "${RED}Invalid $input_type input!${ENDCOLOR}" >&2
    if [ -n "$error_msg" ]; then
        echo -e "${YELLOW}$error_msg${ENDCOLOR}" >&2
    fi
    echo -e "${YELLOW}Please try again with valid input.${ENDCOLOR}" >&2
}

### ===== END INPUT SANITIZATION FRAMEWORK =====



### Function should be used in default case in script mode selection
# $1: script name
# $2: entered mode
function wrong_mode {
    if [ -n "$2" ]; then
        echo -e "Unknown mode ${YELLOW}$2${ENDCOLOR} for ${YELLOW}gitb $1${ENDCOLOR}"
        echo -e "Use ${GREEN}gitb $1 help${ENDCOLOR} to get usage info"
        exit
    fi
}


### Function echoes (true return) url to current user's repo (remote)
# Return: url to repo
function get_repo {
    local remote_name=${origin_name:-origin}
    repo=$(git config --get "remote.${remote_name}.url")
    repo="${repo/"com:"/"com/"}"
    repo="${repo/"io:"/"io/"}"
    repo="${repo/"org:"/"org/"}"
    repo="${repo/"net:"/"net/"}"
    repo="${repo/"dev:"/"dev/"}"
    repo="${repo/"ru:"/"ru/"}"
    repo="${repo/"git@"/"https://"}"
    repo="${repo/".git"/""}" 
    echo "$repo"
}


### Function echoes (true return) name of current repo
function get_repo_name {
    repo=$(get_repo)
    echo "${repo##*/}"
}


### Function prints current config
function print_configuration {
    echo -e "${YELLOW}Current configuration:${ENDCOLOR}"
    echo -e "\tuser.name:\t${YELLOW}$(get_config_value user.name)${ENDCOLOR}"
    echo -e "\tuser.email:\t${YELLOW}$(get_config_value user.email)${ENDCOLOR}"
    echo -e "\tdefault:\t${YELLOW}$main_branch${ENDCOLOR}"
    echo -e "\tseparator:\t${YELLOW}$sep${ENDCOLOR}"
    echo -e "\teditor:\t\t${YELLOW}$editor${ENDCOLOR}"
    if [ "$ticket_name" != "" ]; then
        echo -e "\tticket:\t\t${YELLOW}$ticket_name${ENDCOLOR}"
    fi
    if [ "$scopes" != "" ]; then
        echo -e "\tscopes:\t\t${YELLOW}$scopes${ENDCOLOR}"
    fi
    local ai_key=$(get_ai_api_key)
    if [ -n "$ai_key" ]; then
        ai_key=$(mask_api_key "$ai_key")
        echo -e "\tAI key:\t\t${GREEN}$ai_key${ENDCOLOR}"
    else
        echo -e "\tAI key:\t\t${RED}not set${ENDCOLOR}"
    fi
    local ai_proxy=$(get_ai_proxy)
    if [ -n "$ai_proxy" ]; then
        echo -e "\tAI proxy:\t${GREEN}$ai_proxy${ENDCOLOR}"
    else
        echo -e "\tAI proxy:\t${YELLOW}not set${ENDCOLOR}"
    fi
    local ai_history_limit=$(get_ai_commit_history_limit)
    echo -e "\tAI history:\t${GREEN}$ai_history_limit commits${ENDCOLOR}"
}



### Function to escape substring in string
# $1: string
# $2: substring to escape
# Returns: provided string with escaped substring
function escape {
    string="$1"
    sub="$2"
    escaped="\\$sub"
    echo "${string//${sub}/${escaped}}"
}


### Function checks code against 0 and show error
# $1: return code
# $2: command output (error message)
# $3: command name
# Using of global:
#     * git_add
function check_code {
    if [ $1 != 0 ]; then
        echo
        echo
        echo -e "${RED}Error during $3!${ENDCOLOR}"
        echo -e "$2"
        if [ -n "$git_add" ]; then
            git restore --staged $git_add
        fi
        exit $1
    fi
}


### Function asks user to enter yes or no, it will exit if user answers 'no'
# $1: what to write in console on success
# $2: flag no echo
function yes_no_choice {
    while [ true ]; do
        read -n 1 -s choice
        if [ "$choice" == "y" ]; then
            if [ -n "$1" ]; then
                echo -e "${YELLOW}$1${ENDCOLOR}"
                if [ -z $2 ]; then
                    echo
                fi
            fi
            return
        fi
        if [ "$choice" == "n" ]; then
            exit
        fi
    done
}


### Function waits a number from user and returns result of choice from a provided list
# $1: list of values
# Returns: 
#     * choice_result
#     * pressed_alt
# Using of global:
#     * git_add
function choose {
    values=("$@")
    number_of_values=${#values[@]}

    while [ true ]; do
        if [ $number_of_values -gt 9 ]; then
            read -p "$read_prefix" -e -n 2 choice
        else
            read -p "$read_prefix" -n 1 -s choice
        fi

        if [ "$choice" == "0" ] || [ "$choice" == "00" ]; then
            if [ -n "$git_add" ]; then
                git restore --staged $git_add
            fi
            if [ $number_of_values -le 9 ]; then
                printf $choice
            fi
            exit
        fi

        re='^[0-9=]+$'
        if ! [[ $choice =~ $re ]]; then
            if [ -n "$git_add" ]; then
                git restore --staged $git_add
            fi
            exit
        fi

        if [ "$choice" == "=" ] || [ "$choice" == "==" ]; then
            pressed_alt="true"
            break
        fi

        index=$(($choice-1))
        choice_result=${values[index]}
        if [ -n "$choice_result" ]; then
            if [ $number_of_values -le 9 ]; then
                printf $choice
            fi
            break
        else
            if [ $number_of_values -gt 9 ]; then
                if [ -n "$git_add" ]; then
                    git restore --staged $git_add
                fi
                exit
            fi
        fi
    done
}


### Function prints fiels from git status in a pretty way
function git_status {
    status_output=$(git status --short)
    status_output=$(echo "$status_output" | sed "s/^ D/${RED_ES}\tDeleted: ${ENDCOLOR_ES}/")
    status_output=$(echo "$status_output" | sed "s/^D /${GREEN_ES}Staged\t${RED_ES}Deleted: ${ENDCOLOR_ES}/")

    status_output=$(echo "$status_output" | sed "s/^ M/${YELLOW_ES}\tModified:${ENDCOLOR_ES}/")
    status_output=$(echo "$status_output" | sed "s/^MM/${GRAY_ES}Old\t${YELLOW_ES}Modified:${ENDCOLOR_ES}/")
    status_output=$(echo "$status_output" | sed "s/^AM/${GRAY_ES}Old\t${YELLOW_ES}Modified:${ENDCOLOR_ES}/")
    status_output=$(echo "$status_output" | sed "s/^M /${GREEN_ES}Staged\t${YELLOW_ES}Modified:${ENDCOLOR_ES}/")

    status_output=$(echo "$status_output" | sed "s/^A/${GREEN_ES}Staged\tAdded:   ${ENDCOLOR_ES}/")
    status_output=$(echo "$status_output" | sed "s/^??/${GREEN_ES}\tAdded:   ${ENDCOLOR_ES}/")
    echo -e "$status_output"
}


### Function prints the list of commits
# $1: number of last commits to show
# $2: what to add before commit line
#     * <empty> - nothing
#     * tab
#     * number
# $3: from which place (commit, branch) show commits (empty for default)
# Returns: 
#     commits_info
#     commits_hash
function commit_list {
    ref=$3
    if [[ "$(git --no-pager log -n 1 2>&1)" == *"does not have any commits yet"* ]]; then
        if [[ "$3" == *"HEAD"* ]]; then
            ref="$(echo "$3" | sed 's/HEAD..//')"
        else
            return 
        fi
    fi

    IFS=$'\n' 
    read -rd '' -a commits_info <<<"$(git --no-pager log -n $1 --pretty="${YELLOW_ES}%h${ENDCOLOR_ES} | %s | ${BLUE_ES}%an${ENDCOLOR_ES} | ${GREEN_ES}%cr${ENDCOLOR_ES}" $ref | column -ts'|')"
    read -rd '' -a commits_hash <<<"$(git --no-pager log -n $1 --pretty="%h" $ref)"

    for index in "${!commits_info[@]}"
    do
        line=${commits_info[index]}
        if [ $2 == "number" ]; then
            line="$(($index+1)). ${line}"
        elif [ $2 == "tab" ]; then
            line="\t${line}"
        fi
        echo -e "$line"
    done
}


### Function prints the list of refs from reflog
# $1: number of last refs to show
# Returns: 
#     refs_info
#     refs_hash
function ref_list {
    IFS=$'\n' 
    read -rd '' -a refs_info <<<"$(git --no-pager reflog -n $1 --pretty="${YELLOW_ES}%h${ENDCOLOR_ES} | ${BLUE_ES}%gd${ENDCOLOR_ES} | %gs | ${GREEN_ES}%cr${ENDCOLOR_ES}" | column -ts'|')"
    read -rd '' -a refs_hash <<<"$(git --no-pager reflog -n $1 --pretty="%gd")"

    # Remove HEAD@{0}
    refs_info=("${refs_info[@]:1}")
    refs_hash=("${refs_hash[@]:1}")

    for index in "${!refs_info[@]}"
    do
        line="$(($index+1)). ${refs_info[index]}"
        echo -e "$line"
    done
}


### Function prints the list of commits and user should choose one
# $1: number of last commits to show
# Returns: 
#     commit_hash - hash of selected commit
# Using of global:
#     * git_add
function choose_commit {
    commit_list $1 "number"
    if [ $1 -gt 9 ]; then
        echo "00. Exit"
    else
        echo "0. Exit"
    fi

    echo "Enter = to show more"
    echo
    
    read_prefix="Enter commit number: "

    choose "${commits_hash[@]}"
    commit_hash=$choice_result

    if [ -n "$pressed_alt" ]; then
        commit_list 50 "number"
        echo "00. Exit"
        echo
        choose "${commits_hash[@]}"
        commit_hash=$choice_result
    fi

    echo
}


### Function prints provided stat in a nice format with colors
# $1: stats after pull or commit like 'README.md | 1 +\n1 file changed, 1 insertion(+)'
function print_changes_stat {
    IFS=$'\n' read -rd '' -a stats <<< "$1"
    result_stat=""
    bottom_line=""
    number_of_stats=${#stats[@]}
    for index in "${!stats[@]}"
    do
        s=$(echo ${stats[index]} | sed -e 's/^[[:space:]]*//')
        s=$(sed "s/+/${GREEN_ES}+${ENDCOLOR_ES}/g" <<< ${s})
        s=$(sed "s/-/${RED_ES}-${ENDCOLOR_ES}/g" <<< ${s})
        if [ $(($index+1)) == $number_of_stats ]; then
            #s=$(sed '1 s/,/|/' <<< ${s})
            bottom_line="${s}"
            break
        fi
        result_stat="${result_stat}\n${s}"
    done
    echo -e "$(echo -e "${result_stat}" | column -ts'|')"
    echo -e "$bottom_line"
}


### Function sets to variables push_list and history_from actual push log information
# $1: current branch
# $2: main branch
# $3: origin name
# Returns: 
#     push_list - unpushed commits
#     history_from - branch or commit from which history was calculated
function get_push_list {
    push_list_check=$(git --no-pager log $3/$1..HEAD 2>&1)
    if [[ $push_list_check != *"unknown revision or path not in the working tree"* ]]; then
        push_list=$(commit_list 999 "tab" $3/$1..HEAD)
        history_from="$3/$1"
        return
    fi

    # Case with new repo without any branch
    if [[ $push_list_check == *"unknown revision or path not in the working tree"* ]]; then
        if [[ $1 == $2 ]]; then
            push_list=$(commit_list 999 "tab")
            history_from="$3/$1"
            return
        fi
    fi
    
    base_commit=$(diff -u <(git rev-list --first-parent $1) <(git rev-list --first-parent $2) | sed -ne 's/^ //p' | head -1)
    if [ -n "$base_commit" ]; then
        push_list=$(commit_list 999 "tab" $base_commit..HEAD)
        history_from="${base_commit::7}"
    else
        push_list=$(commit_list 999 "tab" $3/$2..HEAD)
        history_from="$3/$2"
    fi
}


### Function prints list of branches
# $1: possible values:
#     * no value prints all local branches
#     * 'remote' - all remote
#     * 'delete' - all local without main and current
#     * 'merge' - all local without current
# Using of global:
#     * current_branch
#     * main_branch
# Returns:
#     * number_of_branches
#     * branches_first_main
#     * to_exit
function list_branches {
    args="--sort=-committerdate"
    if [[ "$1" == "remote" ]]; then
        args="--sort=-committerdate -r"
    fi
    branches_str=$(git --no-pager branch $args --format="%(refname:short)")
    branches_info_str=$(git --no-pager branch $args --format="${BLUE_ES}%(refname:short)${ENDCOLOR_ES} | %(contents:subject) | ${YELLOW_ES}%(objectname:short)${ENDCOLOR_ES}  | ${GREEN_ES}%(committerdate:relative)${ENDCOLOR_ES}" | column -ts'|' )

    IFS=$'\n' 
    read -rd '' -a branches <<< "$branches_str"
    read -rd '' -a branches_info <<< "$branches_info_str"

    number_of_branches=${#branches[@]}
    if [[ "$1" == "remote" ]]; then
        # There is origin/HEAD
        ((number_of_branches=number_of_branches-1))
    fi

    if [[ "$number_of_branches" == 0 ]]; then
        echo
        echo -e "${YELLOW}There is no branches${ENDCOLOR}"
        to_exit="true"
        return
    fi

    branch_to_check="${branches[0]}"
    if [[ "$1" == "remote" ]]; then
        # Remove 'origin/'
        branch_to_check="${branches[1]}"
        branch_to_check="$(sed "s/${origin_name}\///g" <<< ${branch_to_check})"
    fi

    if [[ "$number_of_branches" == 1 ]] && [[ "${branch_to_check}" == "${current_branch}" ]]; then
        echo
        echo -e "There is only one branch: ${YELLOW}${current_branch}${ENDCOLOR}"
        to_exit="true"
        return
    fi

    if [[ "$1" == "delete" ]] && [[ "$number_of_branches" == 2 ]] && [[ "${current_branch}" != "${main_branch}" ]]; then
        echo
        echo -e "${YELLOW}There are no branches to delete${ENDCOLOR}"
        to_exit="true"
        return
    fi

    ### Main should be the first
    branches_first_main=(${main_branch})
    branches_info_first_main=("dummy")
    if [[ "$1" == "delete" ]]; then
        branches_first_main=()
        branches_info_first_main=()
    fi
    if [[ "$1" == "merge" ]] && [[ "$current_branch" == "$main_branch" ]]; then
        branches_first_main=()
        branches_info_first_main=()
    fi
    for index in "${!branches[@]}"
    do
        branch_to_check="${branches[index]}"
        if [[ "$1" == "delete" ]]; then
            if [[ "$branch_to_check" == "${current_branch}"* ]] || [[ "$branch_to_check" == "${main_branch}"* ]]; then
                continue    
            fi
        fi
        if [[ "$1" == "merge" ]]; then
            if [[ "$branch_to_check" == "${current_branch}"* ]]; then
                continue
            fi
        fi
        if [[ "$1" == "remote" ]]; then
            branch_to_check="$(sed "s/${origin_name}\///g" <<< ${branch_to_check})"
        fi

        if [[ "$branch_to_check" == "${main_branch}"* ]]; then
            branches_info_first_main[0]="${branches_info[index]}"
        elif [[ "$branch_to_check" != "HEAD->"* ]] && [[ "$branch_to_check" != "$origin_name" ]]; then 
            branches_first_main+=(${branches[index]})
            branches_info_first_main+=("${branches_info[index]}")
        fi
    done

    if [[ "${branches_info_first_main[0]}" == "dummy" ]]; then
        branches_info_first_main=("${branches_info_first_main[@]:1}")
        branches_first_main=("${branches_first_main[@]:1}")
    fi

    for index in "${!branches_info_first_main[@]}"
    do
        branch=$(escape "${branches_first_main[index]}" "/")
        if [[ "$1" == "remote" ]] && [[ "$branch" != "origin"* ]]; then
            branch="$origin_name\/$branch"
        fi

        branch_line="${branches_info_first_main[index]}"
        if [ "${branches_first_main[index]}" == "$current_branch" ]; then
            echo -e "$(($index+1)). * $branch_line"
        else
            echo -e "$(($index+1)).   $branch_line"
        fi
    done
}


### This function prints the list of branches and user should choose one
# $1: possible values:
#     * no value prints all local branches
#     * 'remote' - choose from all remote
#     * 'delete' - choose from all local without main and current
#     * 'merge' - all local without current
# Using of global:
#     * origin_name
#     * current_branch
#     * main_branch
# Returns:
#     * branch_name
function choose_branch {
    list_branches $1

    if [ -n "$to_exit" ]; then
        exit
    fi

    echo
    printf "Enter branch number: "

    choose "${branches_first_main[@]}"
    branch_name=$choice_result

    if [[ "$1" == "remote" ]]; then
        branch_name=$(sed "s/${origin_name}\///g" <<< ${branch_name})
    fi

    echo
}


### Function handles switch result
# $1: name of the branch to switch
# $2: pass it if you want to disable push log and moved changes
function switch {
    switch_output=$(git switch $1 2>&1)
    switch_code=$?

    ## Switch is OK
    if [ "$switch_code" == 0 ]; then
        if [ "$current_branch" == "$1" ]; then
            echo -e "${GREEN}Already on '$1'${ENDCOLOR}"
        else
            echo -e "${GREEN}Switched to branch '$1'${ENDCOLOR}"
            changes=$(git_status)
            if [ -n "$changes" ] && [ -z $2 ]; then
                echo
                echo -e "${YELLOW}Moved changes:${ENDCOLOR}"
                echo -e "$changes"
            fi
        fi

        if [ -z $2 ]; then
            get_push_list $1 ${main_branch} ${origin_name}
            if [ -n "$push_list" ]; then
                echo
                count=$(echo -e "$push_list" | wc -l | sed 's/^ *//;s/ *$//')
                echo -e "Your branch ${YELLOW}$1${ENDCOLOR} is ahead ${YELLOW}${history_from}${ENDCOLOR} by ${BOLD}$count${ENDCOLOR} commits"
                echo -e "$push_list"
            fi
        fi
        return
    fi

    ## There are uncommited files with conflicts
    if [[ $switch_output == *"Your local changes to the following files would be overwritten"* ]]; then
        conflicts="$(echo "$switch_output" | tail -r | tail -n +3 | tail -r | tail -n +2)"
        echo -e "${RED}Changes would be overwritten by switch to '$1':${ENDCOLOR}"       
        echo -e "${conflicts//[[:blank:]]/}"
        echo
        echo -e "${YELLOW}Commit these files and try to switch for one more time${ENDCOLOR}"
        exit
    fi

    if [ $switch_code -ne 0 ]; then
        echo -e "${RED}Cannot switch to '$main_branch'! Error message:${ENDCOLOR}"
        echo -e "$switch_output"
        exit $switch_code
    fi
}
