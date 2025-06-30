#!/usr/bin/env bash

### Script for managing git hooks
# Read README.md to get more information how to use it
# Use this script only with gitbasher


### Function to get hooks directory path
function get_hooks_dir {
    local hooks_dir="$(git rev-parse --git-dir)/hooks"
    echo "$hooks_dir"
}

### Function to list all possible git hooks
function get_all_hook_types {
    echo "pre-commit post-commit pre-push post-update pre-receive post-receive prepare-commit-msg commit-msg post-checkout post-merge pre-rebase pre-auto-gc"
}

### Function to get hook descriptions for display
function get_hook_description {
    local hook_type="$1"
    case "$hook_type" in
        "pre-commit")
            echo "Triggered before a commit is created (validate/lint code)"
        ;;
        "post-commit")
            echo "Triggered after a commit is successfully created"
        ;;
        "pre-push")
            echo "Triggered before pushing to remote (validate commits/branches)"
        ;;
        "post-update")
            echo "Triggered on the remote repository after a successful push"
        ;;
        "pre-receive")
            echo "Triggered on remote repository before accepting a push"
        ;;
        "post-receive")
            echo "Triggered on remote repository after accepting a push"
        ;;
        "prepare-commit-msg")
            echo "Triggered before commit message editor is invoked"
        ;;
        "commit-msg")
            echo "Triggered to validate/modify commit message"
        ;;
        "post-checkout")
            echo "Triggered after a successful checkout"
        ;;
        "post-merge")
            echo "Triggered after a successful merge"
        ;;
        "pre-rebase")
            echo "Triggered before a rebase operation"
        ;;
        "pre-auto-gc")
            echo "Triggered before automatic garbage collection"
        ;;
        *)
            echo "Git hook"
        ;;
    esac
}

### Function to interactively select a hook type
function select_hook_type {
    local action="$1"  # "create", "edit", "toggle", etc.
    local filter_existing="$2"  # "existing" to show only existing hooks
    
    echo -e "${YELLOW}Select git hook type for $action:${ENDCOLOR}" >&2
    echo >&2
    
    local hooks_dir=$(get_hooks_dir)
    local all_hooks=($(get_all_hook_types))
    local available_hooks=()
    local hook_numbers=()
    local counter=1
    
    # Add "all" option for removal action
    if [ "$action" = "removal" ] && [ "$filter_existing" = "existing" ]; then
        available_hooks+=("ALL")
        hook_numbers+=("$counter")
        counter=$((counter + 1))
    fi
    
    # Filter hooks based on action
    for hook_type in "${all_hooks[@]}"; do
        local hook_file="$hooks_dir/$hook_type"
        
        if [ "$filter_existing" = "existing" ]; then
            # Only show existing hooks
            if [ -f "$hook_file" ]; then
                available_hooks+=("$hook_type")
                hook_numbers+=("$counter")
                counter=$((counter + 1))
            fi
        else
            # Show all hooks, mark existing ones
            available_hooks+=("$hook_type")
            hook_numbers+=("$counter")
            counter=$((counter + 1))
        fi
    done
    
    if [ ${#available_hooks[@]} -eq 0 ]; then
        if [ "$filter_existing" = "existing" ]; then
            echo -e "${YELLOW}No git hooks found${ENDCOLOR}" >&2
            echo -e "Use ${GREEN}gitb hook create${ENDCOLOR} to create a hook first" >&2
        else
            echo -e "${RED}No hook types available${ENDCOLOR}" >&2
        fi
        return 1
    fi
    
    # Display hooks with numbers
    for i in "${!available_hooks[@]}"; do
        local hook_type="${available_hooks[$i]}"
        local number="${hook_numbers[$i]}"
        local status=""
        local color=""
        local description=""
        
        if [ "$hook_type" = "ALL" ]; then
            # Special handling for "ALL" option
            local existing_count=0
            for check_hook in $(get_all_hook_types); do
                if [ -f "$hooks_dir/$check_hook" ]; then
                    ((existing_count++))
                fi
            done
            status=" ${RED}(remove all $existing_count hooks)${ENDCOLOR}"
            color="$RED"
            description="Remove all existing git hooks"
        else
            local hook_file="$hooks_dir/$hook_type"
            
            if [ -f "$hook_file" ]; then
                if [ -x "$hook_file" ]; then
                    status=" ${GREEN}(enabled)${ENDCOLOR}"
                    color="$GREEN"
                else
                    status=" ${YELLOW}(disabled)${ENDCOLOR}"
                    color="$YELLOW"
                fi
            else
                if [ "$filter_existing" != "existing" ]; then
                    status=" ${GRAY}(not created)${ENDCOLOR}"
                    color="$GRAY"
                fi
            fi
            
            description=$(get_hook_description "$hook_type")
        fi
        
        if [ -n "$color" ]; then
            echo -e "${color}${number}) ${ENDCOLOR}${hook_type}${status} - ${description}" >&2
        else
            echo "${number}) ${hook_type}${status} - ${description}" >&2
        fi
    done
    
    echo >&2
    if [ ${#available_hooks[@]} -le 9 ]; then
        read -n 1 -p "Enter number (1-${#available_hooks[@]}): " choice < /dev/tty
        echo >&2  # Add newline after single character input
    else
        read -p "Enter number (1-${#available_hooks[@]}): " choice < /dev/tty
    fi
    
    # Validate choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#available_hooks[@]} ]; then
        echo -e "${RED}Invalid selection${ENDCOLOR}" >&2
        return 1
    fi
    
    # Return selected hook type
    selected_hook_type="${available_hooks[$((choice - 1))]}"
    echo "$selected_hook_type"
}

### Function to show interactive action menu
function show_hooks_menu {
    echo -e "${YELLOW}Git Hooks Management${ENDCOLOR}" >&2
    echo >&2
    echo -e "${YELLOW}What would you like to do?${ENDCOLOR}" >&2
    echo >&2
    
    local actions=(
        "list:List all hooks with status" 
        "create:Create a new hook"
        "edit:Edit an existing hook"
        "toggle:Enable/disable a hook"
        "test:Test a hook"
        "show:View hook content"
        "remove:Remove hook(s) - single or all"
        "select:Browse hook types"
        "install:Install sample hooks"
    )
    
    for i in "${!actions[@]}"; do
        local action="${actions[$i]}"
        local action_name="${action%%:*}"
        local description="${action##*:}"
        local number=$((i + 1))
        
        echo "${number}) ${action_name} - ${description}" >&2
    done
    
    echo >&2
    if [ ${#actions[@]} -le 9 ]; then
        read -n 1 -p "Enter number (1-${#actions[@]}): " choice < /dev/tty
        echo >&2  # Add newline after single character input
    else
        read -p "Enter number (1-${#actions[@]}): " choice < /dev/tty
    fi
    
    # Validate choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#actions[@]} ]; then
        exit
    fi
    
    # Get selected action
    local selected_action="${actions[$((choice - 1))]}"
    local action_command="${selected_action%%:*}"
    
    echo >&2
    case "$action_command" in
        "list")
            list_hooks
        ;;
        "create")
            hooks_script "create"
        ;;
        "edit")
            hooks_script "edit"
        ;;
        "toggle")
            hooks_script "toggle"
        ;;
        "test")
            hooks_script "test"
        ;;
        "show")
            hooks_script "show"
        ;;
        "remove")
            hooks_script "remove"
        ;;
        "select")
            hooks_script "select"
        ;;
        "install")
            hooks_script "install"
        ;;
        "help")
            hooks_script "help"
        ;;
    esac
}

### Function to select template for hook creation
function select_hook_template {
    local hook_type="$1"
    
    echo -e "${YELLOW}Select template for $hook_type hook:${ENDCOLOR}" >&2
    echo >&2
    
    local templates=()
    local template_descriptions=()
    
    # Always available
    templates+=("basic")
    template_descriptions+=("Basic hook template with placeholder content")
    
    # Hook-specific templates
    case "$hook_type" in
        "pre-commit")
            templates+=("pre-commit-lint")
            template_descriptions+=("Linting, TODO/FIXME detection, large file prevention")
        ;;
        "commit-msg")
            templates+=("commit-msg-conventional")
            template_descriptions+=("Conventional commit message format validation")
        ;;
        "pre-push")
            templates+=("pre-push-protection")
            template_descriptions+=("Branch protection for main/master branches")
        ;;
    esac
    
    # Display templates
    for i in "${!templates[@]}"; do
        local template="${templates[$i]}"
        local description="${template_descriptions[$i]}"
        local number=$((i + 1))
        
        echo "${number}) ${template} - ${description}" >&2
    done
    
    echo >&2
    if [ ${#templates[@]} -le 9 ]; then
        read -n 1 -p "Enter number (1-${#templates[@]}, default: 1): " choice < /dev/tty
        echo >&2  # Add newline after single character input
    else
        read -p "Enter number (1-${#templates[@]}, default: 1): " choice < /dev/tty
    fi
    
    # Default to basic template
    if [ -z "$choice" ]; then
        choice=1
    fi
    
    # Validate choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#templates[@]} ]; then
        exit
    fi
    
    # Return selected template
    selected_template="${templates[$((choice - 1))]}"
    echo "$selected_template"
}

### Function to list installed hooks
function list_hooks {
    local hooks_dir=$(get_hooks_dir)
    local show_samples="$1"
    
    if [ ! -d "$hooks_dir" ]; then
        echo -e "${RED}Git hooks directory not found: $hooks_dir${ENDCOLOR}"
        return 1
    fi
    
    echo -e "${YELLOW}Git hooks in: $hooks_dir${ENDCOLOR}"
    echo
    
    local found_hooks=false
    local all_hooks=$(get_all_hook_types)
    
    for hook_type in $all_hooks; do
        local hook_file="$hooks_dir/$hook_type"
        local sample_file="$hooks_dir/$hook_type.sample"
        
        if [ -f "$hook_file" ]; then
            found_hooks=true
            if [ -x "$hook_file" ]; then
                echo -e "${GREEN}✓ $hook_type${ENDCOLOR} (executable)"
            else
                echo -e "${YELLOW}! $hook_type${ENDCOLOR} (not executable)"
            fi
        elif [ -f "$sample_file" ] && [ -n "$show_samples" ]; then
            echo -e "${GRAY}○ $hook_type.sample${ENDCOLOR} (sample)"
        fi
    done
    
    if [ "$found_hooks" = false ]; then
        echo -e "${YELLOW}No git hooks found${ENDCOLOR}"
        if [ -z "$show_samples" ]; then
            echo -e "Use ${GREEN}gitb hooks list samples${ENDCOLOR} to see available sample hooks"
        fi
    fi
}

### Function to create a new hook
function create_hook {
    local hook_type="$1"
    local template="$2"
    local hooks_dir=$(get_hooks_dir)
    local hook_file="$hooks_dir/$hook_type"
    
    if [ ! -d "$hooks_dir" ]; then
        echo -e "${RED}Git hooks directory not found: $hooks_dir${ENDCOLOR}"
        return 1
    fi
    
    # Validate hook type
    local all_hooks=$(get_all_hook_types)
    if [[ ! " $all_hooks " =~ " $hook_type " ]]; then
        echo -e "${RED}Invalid hook type: $hook_type${ENDCOLOR}"
        echo -e "${YELLOW}Valid types: $all_hooks${ENDCOLOR}"
        return 1
    fi
    
    # Check if hook already exists
    if [ -f "$hook_file" ]; then
        echo -e "${YELLOW}Hook '$hook_type' already exists${ENDCOLOR}"
        echo -e "Do you want to ${RED}overwrite${ENDCOLOR} it? (y/n)"
        read -n 1 -s choice
        echo
        if [ "$choice" != "y" ] && [ "$choice" != "Y" ]; then
            echo -e "${YELLOW}Hook creation cancelled${ENDCOLOR}"
            return
        fi
    fi
    
    # Create hook content based on template
    local hook_content=""
    case "$template" in
        "basic"|"")
            hook_content="#!/bin/sh
#
# $hook_type hook
# This hook is called by git $hook_type
#

# Add your custom logic here
echo \"Running $hook_type hook...\"

# Exit with 0 for success, non-zero for failure
exit 0"
        ;;
        "pre-commit-lint")
            if [ "$hook_type" != "pre-commit" ]; then
                echo -e "${RED}Template 'pre-commit-lint' is only for pre-commit hooks${ENDCOLOR}"
                return 1
            fi
            hook_content="#!/bin/sh
#
# Pre-commit hook for code linting and formatting
#

echo \"Running pre-commit checks...\"

# Check for staged files
if git diff --cached --name-only --quiet; then
    echo \"No staged files to check\"
    exit 0
fi

# Example: Check for common issues
staged_files=\$(git diff --cached --name-only)

# Check for TODO/FIXME comments in staged files
if echo \"\$staged_files\" | xargs grep -l \"TODO\\|FIXME\" 2>/dev/null; then
    echo \"⚠️  Warning: Found TODO/FIXME comments in staged files\"
    echo \"Continue anyway? (y/n)\"
    read -n 1 answer
    echo
    if [ \"\$answer\" != \"y\" ] && [ \"\$answer\" != \"Y\" ]; then
        echo \"Commit aborted\"
        exit 1
    fi
fi

# Check for large files (>10MB)
for file in \$staged_files; do
    if [ -f \"\$file\" ]; then
        size=\$(stat -c%s \"\$file\" 2>/dev/null || stat -f%z \"\$file\" 2>/dev/null)
        if [ \"\$size\" -gt 10485760 ]; then
            echo \"❌ Error: Large file detected: \$file (\${size} bytes)\"
            echo \"Files larger than 10MB should not be committed\"
            exit 1
        fi
    fi
done

echo \"Pre-commit checks passed\"
exit 0"
        ;;
        "commit-msg-conventional")
            if [ "$hook_type" != "commit-msg" ]; then
                echo -e "${RED}Template 'commit-msg-conventional' is only for commit-msg hooks${ENDCOLOR}"
                return 1
            fi
            hook_content="#!/bin/sh
#
# Commit message hook for conventional commits
#

commit_regex='^(feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert)(\\(.+\\))?: .{1,50}'

error_msg=\"❌ Invalid commit message format!
Commit message should follow conventional commits format:
  <type>[optional scope]: <description>

Examples:
  feat: add new search functionality
  fix(auth): resolve login issue  
  docs: update API documentation
  
Valid types: feat, fix, docs, style, refactor, test, chore, perf, ci, build, revert\"

if ! grep -qE \"\$commit_regex\" \"\$1\"; then
    echo \"\$error_msg\"
    exit 1
fi

echo \"Commit message format is valid\"
exit 0"
        ;;
        "pre-push-protection")
            if [ "$hook_type" != "pre-push" ]; then
                echo -e "${RED}Template 'pre-push-protection' is only for pre-push hooks${ENDCOLOR}"
                return 1
            fi
            hook_content="#!/bin/sh
#
# Pre-push hook for branch protection
#

protected_branch=\"main\"
current_branch=\$(git branch --show-current)
remote=\"\$1\"
url=\"\$2\"

echo \"Running pre-push checks...\"

# Prevent direct push to protected branch
if [ \"\$current_branch\" = \"\$protected_branch\" ]; then
    echo \"❌ Error: Direct push to '\$protected_branch' branch is not allowed\"
    echo \"Please create a feature branch and submit a pull request\"
    exit 1
fi

# Check if pushing to main/master remotely
while read local_ref local_sha remote_ref remote_sha; do
    if [[ \"\$remote_ref\" == *\"/main\" ]] || [[ \"\$remote_ref\" == *\"/master\" ]]; then
        echo \"❌ Error: Direct push to remote main/master branch is not allowed\"
        echo \"Please use pull requests for main/master branch\"
        exit 1
    fi
done

echo \"Pre-push checks passed\"
exit 0"
        ;;
    esac
    
    # Write hook file
    echo "$hook_content" > "$hook_file"
    chmod +x "$hook_file"
    
    echo -e "${GREEN}Created executable hook: $hook_type${ENDCOLOR}"
    echo -e "${YELLOW}Hook file: $hook_file${ENDCOLOR}"
    
    # Offer to edit the hook
    echo
    echo -e "Do you want to ${BLUE}edit${ENDCOLOR} the hook now? (y/n)"
    read -n 1 -s choice
    echo
    if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
        edit_hook "$hook_type"
    fi
}

### Function to edit an existing hook
function edit_hook {
    local hook_type="$1"
    local hooks_dir=$(get_hooks_dir)
    local hook_file="$hooks_dir/$hook_type"
    
    if [ ! -f "$hook_file" ]; then
        echo -e "${RED}Hook '$hook_type' does not exist${ENDCOLOR}"
        echo -e "Use ${GREEN}gitb hooks create $hook_type${ENDCOLOR} to create it first"
        return 1
    fi
    
    echo -e "${YELLOW}Editing hook: $hook_type${ENDCOLOR}"
    echo -e "${GRAY}File: $hook_file${ENDCOLOR}"
    echo
    
    # Use configured editor
    "$editor" "$hook_file"
    
    # Ensure hook remains executable
    chmod +x "$hook_file"
    echo -e "${GREEN}Hook updated and made executable${ENDCOLOR}"
}

### Function to toggle hook executable status
function toggle_hook {
    local hook_type="$1"
    local hooks_dir=$(get_hooks_dir)
    local hook_file="$hooks_dir/$hook_type"
    
    if [ ! -f "$hook_file" ]; then
        echo -e "${RED}Hook '$hook_type' does not exist${ENDCOLOR}"
        return 1
    fi
    
    if [ -x "$hook_file" ]; then
        chmod -x "$hook_file"
        echo -e "${YELLOW}Disabled hook: $hook_type${ENDCOLOR}"
    else
        chmod +x "$hook_file"
        echo -e "${GREEN}Enabled hook: $hook_type${ENDCOLOR}"
    fi
}

### Function to remove a hook
function remove_hook {
    local hook_type="$1"
    local hooks_dir=$(get_hooks_dir)
    local hook_file="$hooks_dir/$hook_type"
    
    if [ ! -f "$hook_file" ]; then
        echo -e "${RED}Hook '$hook_type' does not exist${ENDCOLOR}"
        return 1
    fi
    
    echo -e "${RED}Are you sure you want to delete hook '$hook_type'?${ENDCOLOR}"
    echo -e "${GRAY}File: $hook_file${ENDCOLOR}"
    echo -e "This action cannot be undone. (y/n)"
    read -n 1 -s choice
    echo
    
    if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
        rm "$hook_file"
        echo -e "${GREEN}Removed hook: $hook_type${ENDCOLOR}"
    else
        echo -e "${YELLOW}Hook removal cancelled${ENDCOLOR}"
    fi
}

### Function to remove all hooks
function remove_all_hooks {
    local hooks_dir=$(get_hooks_dir)
    
    if [ ! -d "$hooks_dir" ]; then
        echo -e "${RED}Git hooks directory not found: $hooks_dir${ENDCOLOR}"
        return 1
    fi
    
    echo -e "${RED}Remove All Git Hooks${ENDCOLOR}"
    echo
    echo -e "${YELLOW}Description:${ENDCOLOR}"
    echo "This will remove ALL git hooks from your repository."
    echo -e "${RED}WARNING: This action cannot be undone!${ENDCOLOR}"
    echo
    
    # Find all existing hooks
    local all_hooks=$(get_all_hook_types)
    local existing_hooks=()
    local hook_count=0
    
    echo -e "${YELLOW}Hooks that will be removed:${ENDCOLOR}"
    for hook_type in $all_hooks; do
        local hook_file="$hooks_dir/$hook_type"
        if [ -f "$hook_file" ]; then
            existing_hooks+=("$hook_type")
            if [ -x "$hook_file" ]; then
                echo -e "  ${RED}✗${ENDCOLOR} $hook_type ${GREEN}(enabled)${ENDCOLOR}"
            else
                echo -e "  ${RED}✗${ENDCOLOR} $hook_type ${YELLOW}(disabled)${ENDCOLOR}"
            fi
            ((hook_count++))
        fi
    done
    
    if [ $hook_count -eq 0 ]; then
        echo -e "${YELLOW}No git hooks found to remove${ENDCOLOR}"
        return
    fi
    
    echo
    echo -e "${RED}This will permanently delete $hook_count hooks.${ENDCOLOR}"
    echo -e "${YELLOW}Are you absolutely sure? (y/n)${ENDCOLOR}"
    read -n 1 -p "Your choice: " choice < /dev/tty
    echo
    echo
    
    if [ "$choice" != "y" ] && [ "$choice" != "Y" ]; then
        echo -e "${YELLOW}Hook removal cancelled${ENDCOLOR}"
        return
    fi
    
    # Double confirmation for safety
    echo -e "${RED}FINAL CONFIRMATION${ENDCOLOR}"
    echo -e "${RED}Type 'DELETE' to confirm removal of all hooks:${ENDCOLOR}"
    read -p "Enter confirmation: " confirmation < /dev/tty
    
    if [ "$confirmation" != "DELETE" ]; then
        echo -e "${YELLOW}Hook removal cancelled - confirmation text did not match${ENDCOLOR}"
        return
    fi
    
    echo
    echo -e "${YELLOW}Removing all hooks...${ENDCOLOR}"
    echo
    
    local removed_count=0
    for hook_type in "${existing_hooks[@]}"; do
        local hook_file="$hooks_dir/$hook_type"
        if [ -f "$hook_file" ]; then
            rm "$hook_file"
            echo -e "${RED}✗ Removed: $hook_type${ENDCOLOR}"
            ((removed_count++))
        fi
    done
    
    echo
    echo -e "${GREEN}Successfully removed $removed_count hooks${ENDCOLOR}"

}

### Function to test a hook
function test_hook {
    local hook_type="$1"
    local hooks_dir=$(get_hooks_dir)
    local hook_file="$hooks_dir/$hook_type"
    
    if [ ! -f "$hook_file" ]; then
        echo -e "${RED}Hook '$hook_type' does not exist${ENDCOLOR}"
        return 1
    fi
    
    if [ ! -x "$hook_file" ]; then
        echo -e "${YELLOW}Hook '$hook_type' is not executable${ENDCOLOR}"
        echo -e "Enable it with: ${GREEN}gitb hooks toggle $hook_type${ENDCOLOR}"
        return 1
    fi
    
    echo -e "${YELLOW}Testing hook: $hook_type${ENDCOLOR}"
    echo -e "${GRAY}Running: $hook_file${ENDCOLOR}"
    echo "----------------------------------------"
    
    # Run the hook and capture exit code
    "$hook_file"
    local exit_code=$?
    
    echo "----------------------------------------"
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}Hook test passed (exit code: $exit_code)${ENDCOLOR}"
    else
        echo -e "${RED}❌ Hook test failed (exit code: $exit_code)${ENDCOLOR}"
    fi
}

### Function to show hook content
function show_hook {
    local hook_type="$1"
    local hooks_dir=$(get_hooks_dir)
    local hook_file="$hooks_dir/$hook_type"
    
    if [ ! -f "$hook_file" ]; then
        echo -e "${RED}Hook '$hook_type' does not exist${ENDCOLOR}"
        return 1
    fi
    
    echo -e "${YELLOW}Hook: $hook_type${ENDCOLOR}"
    echo -e "${GRAY}File: $hook_file${ENDCOLOR}"
    if [ -x "$hook_file" ]; then
        echo -e "${GREEN}Status: Enabled (executable)${ENDCOLOR}"
    else
        echo -e "${YELLOW}Status: Disabled (not executable)${ENDCOLOR}"
    fi
    echo "----------------------------------------"
    cat "$hook_file"
    echo "----------------------------------------"
}

### Function to install sample hooks
function install_samples {
    local hooks_dir=$(get_hooks_dir)
    
    if [ ! -d "$hooks_dir" ]; then
        echo -e "${RED}Git hooks directory not found: $hooks_dir${ENDCOLOR}"
        return 1
    fi
    
    echo -e "${YELLOW}Install Git Sample Hooks${ENDCOLOR}"
    echo
    echo -e "${YELLOW}Description:${ENDCOLOR}"
    echo "This will install all available sample hooks from Git into your repository."
    echo "Sample hooks are template scripts provided by Git for common hook scenarios."
    echo
    echo -e "${YELLOW}What will happen:${ENDCOLOR}"
    echo "• Copy all *.sample files to executable hook files"
    echo "• Skip existing hooks (no overwriting)"
    echo "• Make all installed hooks executable"
    echo "• Show summary of installed hooks"
    echo
    
    # Check what sample hooks are available
    echo -e "${YELLOW}Available sample hooks:${ENDCOLOR}"
    local sample_count=0
    for sample_file in "$hooks_dir"/*.sample; do
        if [ -f "$sample_file" ]; then
            local hook_name=$(basename "$sample_file" .sample)
            local hook_file="$hooks_dir/$hook_name"
            
            if [ ! -f "$hook_file" ]; then
                echo -e "  ${GREEN}✓${ENDCOLOR} $hook_name (will be installed)"
                ((sample_count++))
            else
                echo -e "  ${YELLOW}○${ENDCOLOR} $hook_name (already exists - will be skipped)"
            fi
        fi
    done
    
    if [ $sample_count -eq 0 ]; then
        echo -e "${YELLOW}No new sample hooks to install${ENDCOLOR}"
        echo "All sample hooks are already installed or no sample files found."
        return
    fi
    
    echo
    echo -e "${YELLOW}Ready to install $sample_count sample hooks.${ENDCOLOR}"
    echo -e "${YELLOW}Continue? (y/n)${ENDCOLOR}"
    read -n 1 -p "Your choice: " choice < /dev/tty
    echo
    echo
    
    if [ "$choice" != "y" ] && [ "$choice" != "Y" ]; then
        echo -e "${YELLOW}Sample hook installation cancelled${ENDCOLOR}"
        return
    fi
    
    echo -e "${YELLOW}Installing sample hooks...${ENDCOLOR}"
    echo
    
    local installed_count=0
    for sample_file in "$hooks_dir"/*.sample; do
        if [ -f "$sample_file" ]; then
            local hook_name=$(basename "$sample_file" .sample)
            local hook_file="$hooks_dir/$hook_name"
            
            if [ ! -f "$hook_file" ]; then
                cp "$sample_file" "$hook_file"
                chmod +x "$hook_file"
                echo -e "${GREEN}✓ Installed: $hook_name${ENDCOLOR}"
                ((installed_count++))
            else
                echo -e "${YELLOW}⚠ Skipped: $hook_name (already exists)${ENDCOLOR}"
            fi
        fi
    done
    
    echo
    echo -e "${GREEN}Successfully installed $installed_count sample hooks${ENDCOLOR}"
    
    if [ $installed_count -gt 0 ]; then
        echo
        echo -e "${YELLOW}Next steps:${ENDCOLOR}"
        echo "• Use ${GREEN}gitb hook list${ENDCOLOR} to see all installed hooks"
        echo "• Use ${GREEN}gitb hook edit <hook-name>${ENDCOLOR} to customize hooks"
        echo "• Use ${GREEN}gitb hook toggle <hook-name>${ENDCOLOR} to enable/disable hooks"
        echo "• Use ${GREEN}gitb hook test <hook-name>${ENDCOLOR} to test hooks"
    fi
}

### Main function for hooks management
function hooks_script {
    local mode="$1"
    local hook_type="$2"
    local template="$3"
    
    case "$mode" in
        "")
            show_hooks_menu
        ;;
        "list"|"l")
            if [ "$hook_type" = "samples" ]; then
                list_hooks "samples"
            else
                list_hooks
            fi
        ;;
        "create"|"new"|"c")
            if [ -z "$hook_type" ]; then
                if ! hook_type=$(select_hook_type "creation"); then
                    echo -e "${YELLOW}Hook creation cancelled${ENDCOLOR}"
                    return
                fi
                if [ -z "$hook_type" ]; then
                    echo -e "${YELLOW}Hook creation cancelled${ENDCOLOR}"
                    return
                fi
                
                echo
                if ! template=$(select_hook_template "$hook_type"); then
                    template="basic"
                fi
                if [ -z "$template" ]; then
                    template="basic"
                fi
            fi
            
            # Sanitize hook type
            if ! sanitize_git_name "$hook_type"; then
                show_sanitization_error "hook type" "Use only letters, numbers, and hyphens."
                return 1
            fi
            hook_type="$sanitized_git_name"
            
            create_hook "$hook_type" "$template"
        ;;
        "edit"|"e")
            if [ -z "$hook_type" ]; then
                if ! hook_type=$(select_hook_type "editing" "existing"); then
                    return
                fi
                if [ -z "$hook_type" ]; then
                    return
                fi
            fi
            
            # Sanitize hook type
            if ! sanitize_git_name "$hook_type"; then
                show_sanitization_error "hook type" "Use only letters, numbers, and hyphens."
                return 1
            fi
            hook_type="$sanitized_git_name"
            
            edit_hook "$hook_type"
        ;;
        "toggle"|"enable"|"disable"|"t")
            if [ -z "$hook_type" ]; then
                if ! hook_type=$(select_hook_type "toggling" "existing"); then
                    return
                fi
                if [ -z "$hook_type" ]; then
                    return
                fi
            fi
            
            # Sanitize hook type
            if ! sanitize_git_name "$hook_type"; then
                show_sanitization_error "hook type" "Use only letters, numbers, and hyphens."
                return 1
            fi
            hook_type="$sanitized_git_name"
            
            toggle_hook "$hook_type"
        ;;
        "remove"|"delete"|"rm"|"r")
            if [ -z "$hook_type" ]; then
                if ! hook_type=$(select_hook_type "removal" "existing"); then
                    return
                fi
                if [ -z "$hook_type" ]; then
                    return
                fi
            fi
            
            # Handle "ALL" selection for removing all hooks
            if [ "$hook_type" = "ALL" ]; then
                remove_all_hooks
                return
            fi
            
            # Sanitize hook type
            if ! sanitize_git_name "$hook_type"; then
                show_sanitization_error "hook type" "Use only letters, numbers, and hyphens."
                return 1
            fi
            hook_type="$sanitized_git_name"
            
            remove_hook "$hook_type"
        ;;
        "test"|"run"|"check")
            if [ -z "$hook_type" ]; then
                if ! hook_type=$(select_hook_type "testing" "existing"); then
                    return
                fi
                if [ -z "$hook_type" ]; then
                    return
                fi
            fi
            
            # Sanitize hook type
            if ! sanitize_git_name "$hook_type"; then
                show_sanitization_error "hook type" "Use only letters, numbers, and hyphens."
                return 1
            fi
            hook_type="$sanitized_git_name"
            
            test_hook "$hook_type"
        ;;
        "show"|"cat"|"view"|"s")
            if [ -z "$hook_type" ]; then
                if ! hook_type=$(select_hook_type "viewing" "existing"); then
                    return
                fi
                if [ -z "$hook_type" ]; then
                    return
                fi
            fi
            
            # Sanitize hook type
            if ! sanitize_git_name "$hook_type"; then
                show_sanitization_error "hook type" "Use only letters, numbers, and hyphens."
                return 1
            fi
            hook_type="$sanitized_git_name"
            
            show_hook "$hook_type"
        ;;
        "install"|"samples")
            install_samples
        ;;
        "select"|"sel")
            echo -e "${YELLOW}Git Hook Type Selector${ENDCOLOR}"
            echo
            if selected_hook=$(select_hook_type "selection"); then
                if [ -n "$selected_hook" ]; then
                    echo
                    echo -e "${GREEN}Selected hook type: $selected_hook${ENDCOLOR}"
                    echo -e "${YELLOW}Description:${ENDCOLOR} $(get_hook_description "$selected_hook")"
                    echo
                    echo -e "${YELLOW}Available actions:${ENDCOLOR}"
                    echo -e "  gitb hook create $selected_hook"
                    echo -e "  gitb hook edit $selected_hook"
                    echo -e "  gitb hook test $selected_hook"
                    echo -e "  gitb hook show $selected_hook"
                fi
            fi
        ;;
        "help"|"h")
            echo -e "${YELLOW}gitb hook${ENDCOLOR} - Git hooks management"
            echo
            echo -e "${YELLOW}Usage:${ENDCOLOR}"
            echo -e "  gitb hook [command] [hook-type] [options]"
            echo
            echo -e "${YELLOW}Commands:${ENDCOLOR}"
            echo -e "  ${GREEN}<empty>${ENDCOLOR}           Show interactive action menu"
            echo -e "  ${GREEN}list, l${ENDCOLOR}           List installed hooks with status"
            echo -e "  ${GREEN}list samples${ENDCOLOR}      List installed hooks and available samples"
            echo -e "  ${GREEN}create, new, c${ENDCOLOR}    Create a new hook (interactive selector)"
            echo -e "  ${GREEN}edit, e${ENDCOLOR}           Edit an existing hook (interactive selector)"
            echo -e "  ${GREEN}toggle, t${ENDCOLOR}         Enable/disable a hook (interactive selector)"
            echo -e "  ${GREEN}remove, rm, r${ENDCOLOR}     Remove hook(s) - single or all (interactive selector)"
            echo -e "  ${GREEN}test, run${ENDCOLOR}         Test a hook by running it (interactive selector)"
            echo -e "  ${GREEN}show, cat, s${ENDCOLOR}      Show hook content (interactive selector)"
            echo -e "  ${GREEN}select, sel${ENDCOLOR}       Interactive hook type browser"
            echo -e "  ${GREEN}install, samples${ENDCOLOR}  Install all available sample hooks"
            echo -e "  ${GREEN}help, h${ENDCOLOR}           Show this help"
            echo
            echo -e "${YELLOW}Hook Types:${ENDCOLOR}"
            echo "$(get_all_hook_types)" | tr ' ' '\n' | sed 's/^/  /'
            echo
            echo -e "${YELLOW}Templates:${ENDCOLOR}"
            echo -e "  ${GREEN}basic${ENDCOLOR}                   Basic hook template (default)"
            echo -e "  ${GREEN}pre-commit-lint${ENDCOLOR}         Pre-commit linting and file checks"
            echo -e "  ${GREEN}commit-msg-conventional${ENDCOLOR} Conventional commit message validation"
            echo -e "  ${GREEN}pre-push-protection${ENDCOLOR}     Branch protection for main/master"
            echo
            echo -e "${YELLOW}Examples:${ENDCOLOR}"
            echo -e "  gitb hook                      # Show interactive action menu"
            echo -e "  gitb hook list                 # List all hooks"
            echo -e "  gitb hook create               # Interactive hook creation"
            echo -e "  gitb hook create pre-commit    # Create specific hook type"
            echo -e "  gitb hook edit                 # Interactive hook selection"
            echo -e "  gitb hook select               # Browse hook types interactively"
            echo -e "  gitb hook test                 # Interactive hook testing"
            echo -e "  gitb hook remove               # Interactive removal - single or all hooks"
            echo -e "  gitb hook install              # Install sample hooks"
        ;;
        *)
            wrong_mode "hooks" "$mode"
        ;;
    esac
} 