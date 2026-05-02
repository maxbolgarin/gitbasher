#!/usr/bin/env bash

### Script for managing CI/CD workflow files (GitHub Actions, GitLab CI, Bitbucket Pipelines)
# Use this script only with gitbasher


### Function returns the workflows directory for the current repo host
# For github: <repo_root>/.github/workflows
# For gitlab/bitbucket: <repo_root> (file-based, no dedicated directory)
function get_workflows_dir {
    local repo_root
    repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"
    if [ -z "$repo_root" ]; then
        repo_root="$(pwd)"
    fi

    case "$(get_repo_host)" in
        gitlab|bitbucket) echo "$repo_root";;
        *)                echo "$repo_root/.github/workflows";;
    esac
}


### Function lists candidate workflow file paths (one per line) for the current host
function list_workflow_files {
    local dir
    dir="$(get_workflows_dir)"

    case "$(get_repo_host)" in
        gitlab)
            [ -f "$dir/.gitlab-ci.yml" ]  && echo "$dir/.gitlab-ci.yml"
            [ -f "$dir/.gitlab-ci.yaml" ] && echo "$dir/.gitlab-ci.yaml"
            ;;
        bitbucket)
            [ -f "$dir/bitbucket-pipelines.yml" ]  && echo "$dir/bitbucket-pipelines.yml"
            [ -f "$dir/bitbucket-pipelines.yaml" ] && echo "$dir/bitbucket-pipelines.yaml"
            ;;
        *)
            if [ -d "$dir" ]; then
                local f
                for f in "$dir"/*.yml "$dir"/*.yaml; do
                    [ -f "$f" ] && echo "$f"
                done
            fi
            ;;
    esac
}


### Function reads the 'name:' field from a workflow YAML file
# $1: file path
# Echoes: workflow name, or basename without extension if name not set
function get_workflow_name {
    local file="$1"
    local name
    name=$(grep -m 1 -E '^name:[[:space:]]*' "$file" 2>/dev/null | sed -E 's/^name:[[:space:]]*//; s/^"([^"]*)"$/\1/; s/^'"'"'([^'"'"']*)'"'"'$/\1/' | tr -d '\r')
    if [ -z "$name" ]; then
        name="$(basename "$file")"
        name="${name%.yml}"
        name="${name%.yaml}"
    fi
    echo "$name"
}


### Function reads the trigger summary from a workflow file (best effort, no YAML parser)
# $1: file path
# Echoes: comma-separated list of triggers (push, pull_request, schedule, workflow_dispatch, ...)
function get_workflow_triggers {
    local file="$1"
    awk '
        function indent_of(s,    i) {
            for (i=1; i<=length(s); i++) if (substr(s, i, 1) != " ") return i - 1
            return length(s)
        }
        BEGIN { in_on=0; child_indent=-1 }
        /^[[:space:]]*#/ { next }
        /^on:[[:space:]]*$/                 { in_on=1; child_indent=-1; next }
        /^on:[[:space:]]*\[/                { gsub(/^on:[[:space:]]*\[|\][[:space:]]*$/, ""); print; in_on=0; next }
        /^on:[[:space:]]*[A-Za-z_]+/        { sub(/^on:[[:space:]]*/, ""); sub(/[[:space:]]*$/, ""); print; in_on=0; next }
        in_on && /^[A-Za-z]/                { in_on=0; next }
        in_on && /^[[:space:]]+[A-Za-z_-]+/ {
            ind = indent_of($0)
            if (child_indent == -1) child_indent = ind
            if (ind != child_indent) next
            line = $0
            sub(/^[[:space:]]+/, "", line)
            sub(/:.*$/, "", line)
            triggers = triggers ? triggers ", " line : line
        }
        END { if (triggers) print triggers }
    ' "$file" 2>/dev/null
}


### Function resolves a workflow argument (name or filename) to an existing file path
# $1: workflow argument provided by user
# Sets: resolved_workflow_file
# Returns: 0 on match, 1 otherwise
function resolve_workflow_file {
    local query="$1"
    resolved_workflow_file=""
    if [ -z "$query" ]; then
        return 1
    fi

    local dir
    dir="$(get_workflows_dir)"

    # Direct path match (absolute or relative to cwd)
    if [ -f "$query" ]; then
        resolved_workflow_file="$query"
        return 0
    fi

    # Relative to workflows dir, with and without extension
    local candidate
    for candidate in "$dir/$query" "$dir/$query.yml" "$dir/$query.yaml"; do
        if [ -f "$candidate" ]; then
            resolved_workflow_file="$candidate"
            return 0
        fi
    done

    # Match against the YAML 'name:' field
    local file
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        local wf_name
        wf_name="$(get_workflow_name "$file")"
        if [ "$wf_name" = "$query" ]; then
            resolved_workflow_file="$file"
            return 0
        fi
    done < <(list_workflow_files)

    return 1
}


### Function prints all workflow files with metadata
function workflows_list {
    local files
    files="$(list_workflow_files)"

    if [ -z "$files" ]; then
        echo -e "${YELLOW}No workflow files found${ENDCOLOR}"
        echo
        echo -e "Workflows are looked up in: ${GRAY}$(get_workflows_dir)${ENDCOLOR}"
        echo
        echo -e "Create one with: ${GREEN}gitb workflows create${ENDCOLOR}"
        return
    fi

    local count=0
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        count=$((count + 1))
        local name triggers rel
        name="$(get_workflow_name "$file")"
        triggers="$(get_workflow_triggers "$file")"
        rel="${file#$(git rev-parse --show-toplevel 2>/dev/null)/}"

        echo -e "${GREEN}${count})${ENDCOLOR} ${BOLD}${name}${NORMAL}"
        echo -e "    ${GRAY}file:${ENDCOLOR}     ${rel}"
        if [ -n "$triggers" ]; then
            echo -e "    ${GRAY}triggers:${ENDCOLOR} ${BLUE}${triggers}${ENDCOLOR}"
        fi
    done <<< "$files"

    local repo_url
    repo_url="$(get_repo)"
    if [ -n "$repo_url" ]; then
        local ci_url
        ci_url="$(get_ci_url "$current_branch" "$repo_url")"
        if [ -n "$ci_url" ]; then
            echo
            print_link "$(get_ci_label "$repo_url")" "$ci_url"
        fi
    fi
}


### Function prints the contents of a workflow file
# $1: workflow name or path
function workflows_show {
    local query="$1"
    if [ -z "$query" ]; then
        query="$(select_workflow "view")"
        if [ -z "$query" ]; then
            return
        fi
    fi

    if ! resolve_workflow_file "$query"; then
        echo -e "${RED}Workflow '$query' not found${ENDCOLOR}"
        echo -e "Use ${GREEN}gitb workflows list${ENDCOLOR} to see available workflows"
        exit 1
    fi

    local name
    name="$(get_workflow_name "$resolved_workflow_file")"
    echo -e "${YELLOW}Workflow:${ENDCOLOR} ${BOLD}${name}${NORMAL}"
    echo -e "${GRAY}File: ${resolved_workflow_file}${ENDCOLOR}"
    echo "----------------------------------------"
    cat "$resolved_workflow_file"
    echo "----------------------------------------"
}


### Function opens a workflow file in the configured editor
# $1: workflow name or path
function workflows_edit {
    local query="$1"
    if [ -z "$query" ]; then
        query="$(select_workflow "edit")"
        if [ -z "$query" ]; then
            return
        fi
    fi

    if ! resolve_workflow_file "$query"; then
        echo -e "${RED}Workflow '$query' not found${ENDCOLOR}"
        echo -e "Use ${GREEN}gitb workflows list${ENDCOLOR} to see available workflows"
        exit 1
    fi

    echo -e "${YELLOW}Editing workflow:${ENDCOLOR} $(get_workflow_name "$resolved_workflow_file")"
    echo -e "${GRAY}File: ${resolved_workflow_file}${ENDCOLOR}"
    echo

    "$editor" "$resolved_workflow_file"
    echo -e "${GREEN}Workflow updated${ENDCOLOR}"
}


### Function deletes a workflow file after confirmation
# $1: workflow name or path
function workflows_remove {
    local query="$1"
    if [ -z "$query" ]; then
        query="$(select_workflow "remove")"
        if [ -z "$query" ]; then
            return
        fi
    fi

    if ! resolve_workflow_file "$query"; then
        echo -e "${RED}Workflow '$query' not found${ENDCOLOR}"
        exit 1
    fi

    echo -e "${RED}Are you sure you want to delete this workflow?${ENDCOLOR}"
    echo -e "    ${BOLD}$(get_workflow_name "$resolved_workflow_file")${NORMAL}"
    echo -e "    ${GRAY}${resolved_workflow_file}${ENDCOLOR}"
    echo -e "This action cannot be undone. (y/n)"
    yes_no_choice "" "true"

    rm "$resolved_workflow_file"
    echo
    echo -e "${GREEN}Workflow removed${ENDCOLOR}"
}


### Function prompts the user to pick a workflow from the available list
# $1: action label (edit, remove, view)
# Echoes: chosen workflow file path, or empty if cancelled
function select_workflow {
    local action="${1:-select}"
    local files=()
    while IFS= read -r f; do
        [ -n "$f" ] && files+=("$f")
    done < <(list_workflow_files)

    if [ ${#files[@]} -eq 0 ]; then
        echo -e "${YELLOW}No workflow files found${ENDCOLOR}" >&2
        echo -e "Create one with: ${GREEN}gitb workflows create${ENDCOLOR}" >&2
        return 1
    fi

    echo -e "${YELLOW}Select workflow to ${action}:${ENDCOLOR}" >&2
    echo >&2

    local i
    for i in "${!files[@]}"; do
        local n=$((i + 1))
        local name rel
        name="$(get_workflow_name "${files[$i]}")"
        rel="${files[$i]#$(git rev-parse --show-toplevel 2>/dev/null)/}"
        echo -e "${GREEN}${n})${ENDCOLOR} ${name} ${GRAY}(${rel})${ENDCOLOR}" >&2
    done

    echo >&2
    local choice
    if [ ${#files[@]} -le 9 ]; then
        read -n 1 -p "Enter number (1-${#files[@]}): " choice < /dev/tty
        echo >&2
    else
        read -p "Enter number (1-${#files[@]}): " choice < /dev/tty
    fi

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#files[@]} ]; then
        echo -e "${YELLOW}Selection cancelled${ENDCOLOR}" >&2
        return 1
    fi

    echo "${files[$((choice - 1))]}"
}


### Function returns a YAML template body for a given workflow template name
# $1: template name
# $2: workflow display name
function get_workflow_template {
    local template="$1"
    local display_name="$2"

    case "$template" in
        ci-bash)
            cat <<EOF
name: ${display_name}

on:
  push:
    branches: [ "${main_branch}" ]
  pull_request:
    branches: [ "${main_branch}" ]
  workflow_dispatch:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install BATS
        run: sudo apt-get update && sudo apt-get install -y bats
      - name: Run tests
        run: bats tests/*.bats
EOF
            ;;
        ci-node)
            cat <<EOF
name: ${display_name}

on:
  push:
    branches: [ "${main_branch}" ]
  pull_request:
    branches: [ "${main_branch}" ]

jobs:
  build:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        node-version: [18.x, 20.x]
    steps:
      - uses: actions/checkout@v4
      - name: Use Node.js \${{ matrix.node-version }}
        uses: actions/setup-node@v4
        with:
          node-version: \${{ matrix.node-version }}
          cache: 'npm'
      - run: npm ci
      - run: npm test
EOF
            ;;
        ci-go)
            cat <<EOF
name: ${display_name}

on:
  push:
    branches: [ "${main_branch}" ]
  pull_request:
    branches: [ "${main_branch}" ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: stable
      - run: go build ./...
      - run: go test ./...
EOF
            ;;
        release)
            cat <<EOF
name: ${display_name}

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Create Release
        uses: softprops/action-gh-release@v2
        with:
          generate_release_notes: true
EOF
            ;;
        *)
            cat <<EOF
name: ${display_name}

on:
  push:
    branches: [ "${main_branch}" ]
  workflow_dispatch:

jobs:
  run:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run
        run: echo "Hello from ${display_name}"
EOF
            ;;
    esac
}


### Function shows a numbered template menu and echoes the chosen template name
function select_workflow_template {
    local templates=("basic" "ci-bash" "ci-node" "ci-go" "release")
    local descriptions=(
        "Minimal workflow scaffold (push + workflow_dispatch)"
        "Run BATS tests on push/PR (bash projects)"
        "Run npm test on push/PR with a Node.js matrix"
        "Run go build & go test on push/PR"
        "Create a GitHub release when a v* tag is pushed"
    )

    echo -e "${YELLOW}Select workflow template:${ENDCOLOR}" >&2
    echo >&2
    local i
    for i in "${!templates[@]}"; do
        local n=$((i + 1))
        echo -e "${GREEN}${n})${ENDCOLOR} ${templates[$i]} ${GRAY}- ${descriptions[$i]}${ENDCOLOR}" >&2
    done

    echo >&2
    local choice
    read -n 1 -p "Enter number (1-${#templates[@]}): " choice < /dev/tty
    echo >&2

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#templates[@]} ]; then
        echo "basic"
        return
    fi
    echo "${templates[$((choice - 1))]}"
}


### Function creates a new workflow file from a template
# $1: workflow name (file basename without extension)
# $2: template name (basic|ci-bash|ci-node|ci-go|release)
function workflows_create {
    local name="$1"
    local template="$2"

    case "$(get_repo_host)" in
        gitlab)
            echo -e "${YELLOW}GitLab uses a single .gitlab-ci.yml at the repo root${ENDCOLOR}"
            echo -e "Edit it with: ${GREEN}gitb workflows edit${ENDCOLOR}"
            return
        ;;
        bitbucket)
            echo -e "${YELLOW}Bitbucket uses a single bitbucket-pipelines.yml at the repo root${ENDCOLOR}"
            echo -e "Edit it with: ${GREEN}gitb workflows edit${ENDCOLOR}"
            return
        ;;
    esac

    if [ -z "$name" ]; then
        echo -e "Workflow file name (without extension)"
        echo -e "Press Enter to cancel"
        read -p "Name: " -e name < /dev/tty
        if [ -z "$name" ]; then
            exit
        fi
    fi

    if ! sanitize_git_name "$name"; then
        show_sanitization_error "workflow name" "Use letters, numbers, dots, dashes, and underscores."
        exit 1
    fi
    name="$sanitized_git_name"

    local dir
    dir="$(get_workflows_dir)"
    local file="$dir/${name}.yml"

    if [ -f "$file" ] || [ -f "$dir/${name}.yaml" ]; then
        echo -e "${RED}Workflow '${name}' already exists${ENDCOLOR}"
        echo -e "Use ${GREEN}gitb workflows edit ${name}${ENDCOLOR} to modify it"
        exit 1
    fi

    if [ -z "$template" ]; then
        template="$(select_workflow_template)"
        echo
    fi

    mkdir -p "$dir"

    local display_name
    display_name="$(echo "$name" | tr '_-' ' ' | awk '{ for (i=1; i<=NF; i++) $i = toupper(substr($i,1,1)) substr($i,2) } 1')"

    get_workflow_template "$template" "$display_name" > "$file"

    echo -e "${GREEN}Workflow created${ENDCOLOR}"
    echo -e "    ${BOLD}${display_name}${NORMAL}"
    echo -e "    ${GRAY}${file}${ENDCOLOR}"
    echo
    echo -e "Edit it with: ${GREEN}gitb workflows edit ${name}${ENDCOLOR}"
}


### Function prints the URL to the CI/Actions page for the current branch
function workflows_open {
    local repo_url
    repo_url="$(get_repo)"
    if [ -z "$repo_url" ]; then
        echo -e "${YELLOW}No remote configured${ENDCOLOR}"
        echo -e "Add one with: ${GREEN}gitb origin set${ENDCOLOR}"
        return
    fi

    local ci_url
    ci_url="$(get_ci_url "$current_branch" "$repo_url")"
    if [ -z "$ci_url" ]; then
        echo -e "${YELLOW}Don't know how to build a CI link for this host${ENDCOLOR}"
        echo -e "Repo: ${BLUE}${repo_url}${ENDCOLOR}"
        return
    fi

    print_link "$(get_ci_label "$repo_url")" "$ci_url"
    local all_url
    all_url="$(get_ci_url "" "$repo_url")"
    if [ -n "$all_url" ] && [ "$all_url" != "$ci_url" ]; then
        print_link "All runs" "$all_url"
    fi
}


### Function prints help for the workflows command
function workflows_help {
    echo -e "usage: ${YELLOW}gitb workflows <mode> [<name>]${ENDCOLOR}"
    echo
    msg="${YELLOW}Mode${ENDCOLOR}_${GREEN}Aliases${ENDCOLOR}_\t${BLUE}Description${ENDCOLOR}"
    msg="$msg\n${BOLD}<empty>${ENDCOLOR}_list|ls|l_List workflow files with names and triggers"
    msg="$msg\n${BOLD}show${ENDCOLOR}_view|cat|s_Print contents of a workflow file"
    msg="$msg\n${BOLD}edit${ENDCOLOR}_e_Open a workflow file in the configured editor"
    msg="$msg\n${BOLD}create${ENDCOLOR}_new|add|c_Create a new workflow from a template"
    msg="$msg\n${BOLD}remove${ENDCOLOR}_rm|delete|del|d_Delete a workflow file"
    msg="$msg\n${BOLD}open${ENDCOLOR}_o|url_Print the URL to the CI page for the current branch"
    msg="$msg\n${BOLD}help${ENDCOLOR}_h_Show this help"
    echo -e "$(echo -e "$msg" | column -ts '_')"
    echo
    echo -e "Workflow files are read from ${GRAY}$(get_workflows_dir)${ENDCOLOR}"
}


### Main function for workflows
# $1: subcommand
# $2: workflow name (optional)
# $3: template name (optional, only for create)
function workflows_script {
    local mode="$1"

    case "$mode" in
        ""|list|ls|l)        run_mode="list";;
        show|view|cat|s)     run_mode="show";;
        edit|e)              run_mode="edit";;
        create|new|add|c)    run_mode="create";;
        remove|rm|delete|del|d) run_mode="remove";;
        open|o|url)          run_mode="open";;
        help|h)              run_mode="help";;
        *)                   wrong_mode "workflows" "$mode"; exit;;
    esac

    local header="GIT WORKFLOWS"
    case "$run_mode" in
        list)   header="$header LIST";;
        show)   header="$header SHOW";;
        edit)   header="$header EDIT";;
        create) header="$header CREATE";;
        remove) header="$header REMOVE";;
        open)   header="$header OPEN";;
    esac

    echo -e "${YELLOW}${header}${ENDCOLOR}"
    echo

    case "$run_mode" in
        list)   workflows_list;;
        show)   workflows_show "$2";;
        edit)   workflows_edit "$2";;
        create) workflows_create "$2" "$3";;
        remove) workflows_remove "$2";;
        open)   workflows_open;;
        help)   workflows_help;;
    esac
}
