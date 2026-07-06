#!/usr/bin/env bash

### Script for creating commits in angular style (conventional commits)
# Read README.md to get more information how to use it
# Use this script only with gitbasher


### Function to cleanup staged files and git add cache
# $1: git_add arguments
function cleanup_on_exit {
    if [ -n "$1" ]; then
        # Word-splitting on $1 is intentional: it may hold multiple space-separated paths
        # from `git add`. Use a subshell with `set -f` so globbing cannot silently expand
        # patterns against CWD, and `--` so paths starting with `-` are not parsed as options.
        ( set -f; git restore --staged -- $1 2>/dev/null )
    fi
    # Fast mode stages everything ("."), so the restore above also unstaged
    # whatever the user had carefully staged BEFORE running gitb — put that
    # back (recorded by stage_fast_changes).
    if [ -n "$_gitb_prestaged" ]; then
        local _pf
        while IFS= read -r _pf; do
            [ -n "$_pf" ] && git add -- ":(top,literal)$_pf" >/dev/null 2>&1
        done <<< "$_gitb_prestaged"
    fi
}

### Print git warning/hint output through gitbasher colors.
# $1: captured git output
function print_git_warning_output {
    local git_output="$1"
    [ -z "$git_output" ] && return 0

    local line
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        case "$line" in
            warning:*)
                echo -e "${YELLOW}${line}${ENDCOLOR}"
                ;;
            hint:*)
                echo -e "${CYAN}${line}${ENDCOLOR}"
                ;;
            *)
                echo "$line"
                ;;
        esac
    done <<< "$git_output"
}

### Remove embedded repositories picked up by automatic fast-mode staging.
# Manual git add selections are intentionally not filtered.
function unstage_embedded_repositories_from_fast_add {
    local staged_files
    staged_files=$(git -c core.quotePath=false diff --no-renames --name-only --cached)
    [ -z "$staged_files" ] && return 0

    local file
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        if [ -d "$file" ] && [ -e "$file/.git" ]; then
            git restore --staged -- ":(top,literal)$file" >/dev/null 2>&1
            echo -e "${YELLOW}⚠  Skipped embedded git repository in fast mode: ${file}${ENDCOLOR}"
            echo -e "${CYAN}💡 Select it manually if you really want to commit it.${ENDCOLOR}"
        fi
    done <<< "$staged_files"
}

### Stage all changes for fast modes without keeping embedded repositories.
function stage_fast_changes {
    local result
    # Remember what was staged BEFORE gitb stages everything, so an abort
    # restores exactly the user's pre-existing staging (see cleanup_on_exit).
    _gitb_prestaged=$(git -c core.quotePath=false diff --no-renames --name-only --cached)
    result=$(git add . 2>&1)
    local code=$?

    print_git_warning_output "$result"
    [ $code -ne 0 ] && return $code

    unstage_embedded_repositories_from_fast_add
    return 0
}

### Returns 0 (true) when the given scope adds no information beyond the
### Conventional Commit type. The type already encodes the change kind, so
### `test(tests):`, `docs(docs):`, `build(build):` are pure noise — drop
### the scope and emit `type:` instead. Covers each Conventional Commit type
### (feat, fix, refactor, test, docs, chore, build, ci, perf, style, revert)
### with its singular/plural/synonym forms.
function is_redundant_scope {
    local type_lower; type_lower=$(to_lower "$1")
    local scope_lower; scope_lower=$(to_lower "$2")
    [ -z "$scope_lower" ] && return 1
    case "$type_lower" in
        feat)     [[ "$scope_lower" =~ ^(feat|feats|feature|features)$ ]] && return 0 ;;
        fix)      [[ "$scope_lower" =~ ^(fix|fixes|bugfix|bugfixes)$ ]] && return 0 ;;
        refactor) [[ "$scope_lower" =~ ^(refactor|refactors|refactoring)$ ]] && return 0 ;;
        test)     [[ "$scope_lower" =~ ^(test|tests|testing)$ ]] && return 0 ;;
        docs)     [[ "$scope_lower" =~ ^(doc|docs|documentation)$ ]] && return 0 ;;
        chore)    [[ "$scope_lower" =~ ^(chore|chores)$ ]] && return 0 ;;
        build)    [[ "$scope_lower" =~ ^(build|builds|building)$ ]] && return 0 ;;
        ci)       [[ "$scope_lower" =~ ^(ci|cicd|ci-cd)$ ]] && return 0 ;;
        perf)     [[ "$scope_lower" =~ ^(perf|performance|perfs)$ ]] && return 0 ;;
        style)    [[ "$scope_lower" =~ ^(style|styles|styling)$ ]] && return 0 ;;
        revert)   [[ "$scope_lower" =~ ^(revert|reverts)$ ]] && return 0 ;;
    esac
    return 1
}

### Drop any reasoning preamble a model emits before the actual commit
### message. Some providers/models ignore the "output ONLY the commit
### message" instruction and prepend an analysis ("Looking at the staged
### files I can identify the following changes: 1. ... feat(x): ...");
### without this, the whole analysis becomes the commit subject and the real
### `type(scope): subject` header is buried in the body. We locate the first
### line that is a Conventional Commit header (lowercase type, optional scope,
### optional breaking-change `!`) and discard everything before it, keeping the
### header plus any following body. If no header is found we return the input
### unchanged so non-conventional output is left for the caller to handle.
### LC_ALL=C avoids "illegal byte sequence" errors from BSD awk/sed on
### non-ASCII AI responses.
function strip_ai_reasoning_preamble {
    local input="$1"
    local stripped
    # Drop standalone markdown fence lines, then keep from the first
    # Conventional Commit header onward.
    stripped=$(printf '%s' "$input" | LC_ALL=C awk '
        /^[[:space:]]*```[a-zA-Z]*[[:space:]]*$/ { next }
        found { print; next }
        /^[[:space:]]*(feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert)(\([^)]+\))?!?:[[:space:]].+/ { found=1; print }
    ')
    if [ -n "$stripped" ]; then
        printf '%s' "$stripped"
    else
        printf '%s' "$input"
    fi
}

### Trim quoting/whitespace and drop a redundant scope from an AI-generated
### commit message. Use this at every site that captures AI output so a new
### call site can't forget the strip step (the bug that produced
### `test(tests): ...` despite is_redundant_scope being wired up elsewhere).
### LC_ALL=C avoids "illegal byte sequence" errors from BSD sed when the AI
### response contains non-ASCII characters.
function clean_ai_commit_message {
    local cleaned
    cleaned=$(strip_ai_reasoning_preamble "$1")
    # Strip control bytes: jq fully decodes  escapes in the response,
    # and auto-accept (ff) mode would commit them into history unreviewed.
    cleaned=$(printf '%s' "$cleaned" | LC_ALL=C tr -d '\000-\010\013-\037\177')
    # Trim wrapping quotes and whitespace at the MESSAGE edges only — the
    # old per-line pass flattened body indentation and ate quotes at the
    # start/end of every body line.
    cleaned="${cleaned#\"}"
    cleaned="${cleaned%\"}"
    cleaned=$(printf '%s' "$cleaned" | LC_ALL=C sed -e '1s/^[[:space:]]*//' -e '$s/[[:space:]]*$//')
    strip_redundant_scope "$cleaned"
}

### Strip a redundant scope from a commit message subject. If the subject
### matches `type(scope): ...` (or `type(scope)!: ...`) and the scope is
### redundant per is_redundant_scope, emit `type: ...` (or `type!: ...`).
### Body and footer lines are preserved unchanged.
function strip_redundant_scope {
    local msg="$1"
    local subject="${msg%%$'\n'*}"
    local body=""
    [[ "$msg" == *$'\n'* ]] && body=$'\n'"${msg#*$'\n'}"

    # Bash's [[ =~ ]] parser stumbles on unbalanced parens in a literal
    # regex (even in 5.x); store the pattern in a variable to dodge it.
    local conv_pattern='^([a-z]+)\(([^)]+)\)(!?:.*)$'
    if [[ "$subject" =~ $conv_pattern ]]; then
        local type_str="${BASH_REMATCH[1]}"
        local scope_str="${BASH_REMATCH[2]}"
        local rest="${BASH_REMATCH[3]}"
        if is_redundant_scope "$type_str" "$scope_str"; then
            printf '%s%s\n' "${type_str}${rest}" "$body"
            return 0
        fi
    fi
    printf '%s\n' "$msg"
}

### Function to detect scopes from staged files
# Returns: detected_scopes variable set with space-separated scope names
function detect_scopes_from_staged_files {
    detected_scopes=""
    local staged_files=$(git -c core.quotePath=false diff --no-renames --name-only --cached)

    # Limit the number of files to process for scope detection (performance)
    local max_files_for_scopes=100
    local total_files=$(echo "$staged_files" | wc -l | tr -d ' ')
    if [ "$total_files" -gt "$max_files_for_scopes" ]; then
        staged_files=$(echo "$staged_files" | head -n "$max_files_for_scopes")
    fi

    if [ -n "$staged_files" ]; then
        # Count occurrences of each path token with depth tracking
        gmap_clear scope_counts
        gmap_clear scope_depths

        # Only directory components contribute to scope candidates — filenames
        # are skipped so single root-level files (README.md, package.json, etc.)
        # don't generate noisy one-off scopes. Root files end up in the "misc"
        # group during atomic-split commits.
        while IFS= read -r file; do
            if [ -n "$file" ]; then
                IFS='/' read -r -a path_components <<< "$file"
                local last_idx=$((${#path_components[@]} - 1))

                for i in "${!path_components[@]}"; do
                    [ "$i" -eq "$last_idx" ] && continue
                    component="${path_components[$i]}"
                    [ -z "$component" ] && continue

                    component_lower=$(to_lower "$component")
                    # Filter out generic containers and dependency/output dirs
                    # that are rarely meaningful as a per-commit scope. In a
                    # monorepo, the container dir (`services/`, `apps/`,
                    # `packages/`) and Go-idiom containers (`cmd/`,
                    # `internal/`) wrap the actual scope — the service or
                    # package name lives one level deeper. Generic source
                    # roots (`src`, `lib`, `scripts`, `bin`) are also peeled:
                    # `scripts/foo.sh` becomes `foo` via the stem fallback in
                    # build_split_groups_from_staged, while
                    # `scripts/llm_comparison/x.py` becomes `llm_comparison`.
                    # Tests/docs/build dirs are intentionally left in:
                    # they're meaningful scopes in some projects
                    # (test(integration), pkg/foo).
                    if [[ "$component_lower" =~ ^(src|lib|libs|scripts|bin|node_modules|vendor|tmp|temp|cache|logs|log|services|apps|packages|modules|components|cmd|internal)$ ]]; then
                        continue
                    fi

                    gmap_inc scope_counts "$component_lower"
                    current_depth=$((i + 1))
                    existing_depth=$(gmap_get scope_depths "$component_lower")
                    if [ -z "$existing_depth" ] || [ $current_depth -lt "$existing_depth" ]; then
                        gmap_set scope_depths "$component_lower" "$current_depth"
                    fi
                done
            fi
        done <<< "$staged_files"
        
        # Find maximum count to determine if we should filter out count=1 tokens
        max_count=0
        while IFS= read -r token; do
            [ -z "$token" ] && continue
            token_count=$(gmap_get scope_counts "$token")
            if [ "$token_count" -gt $max_count ]; then
                max_count=$token_count
            fi
        done < <(gmap_keys scope_counts)

        # Count total unique tokens
        total_unique_tokens=$(gmap_size scope_counts)

        # Collect and sort scopes
        detected_scopes_array=()
        while IFS= read -r token; do
            [ -z "$token" ] && continue
            count=$(gmap_get scope_counts "$token")
            depth=$(gmap_get scope_depths "$token")

            # Apply count filter
            # If we have few unique tokens (≤ 7), include all regardless of count
            # If we have many tokens and max_count > 1, only include tokens with count > 1
            if [ $total_unique_tokens -le 7 ]; then
                # Include all tokens when we have few unique ones
                detected_scopes_array+=("$count:$depth:$token")
            elif [ $max_count -gt 1 ]; then
                if [ $count -gt 1 ]; then
                    # Format: count:depth:token for sorting
                    detected_scopes_array+=("$count:$depth:$token")
                fi
            else
                # If all tokens have count=1, include all
                detected_scopes_array+=("$count:$depth:$token")
            fi
        done < <(gmap_keys scope_counts)

        # Sort by count (descending), then by depth (ascending), then by token name
        if [ ${#detected_scopes_array[@]} -gt 0 ]; then
            # Separate filename tokens from directory tokens for better sorting
            filename_entries=()
            directory_entries=()
            
            for entry in "${detected_scopes_array[@]}"; do
                count="${entry%%:*}"  # Extract count (first field)
                rest="${entry#*:}"    # Remove count
                depth="${rest%%:*}"   # Extract depth (second field)
                token="${rest#*:}"    # Extract token (third field)
                
                # Check if this token came from a filename (higher depth usually means filename)
                # We'll put filename tokens first, then directories by ascending depth
                if [ $depth -ge 4 ]; then  # Assume depth 4+ are likely filenames
                    filename_entries+=("$entry")
                else
                    directory_entries+=("$entry")
                fi
            done
            
            # Sort filenames by count (desc), then depth (asc), then name
            IFS=$'\n' filename_sorted=($(printf '%s\n' "${filename_entries[@]}" | sort -t':' -k1,1nr -k2,2n -k3,3))
            unset IFS
            
            # Sort directories by count (desc), then depth (asc), then name  
            IFS=$'\n' directory_sorted=($(printf '%s\n' "${directory_entries[@]}" | sort -t':' -k1,1nr -k2,2n -k3,3))
            unset IFS
            
            # Combine: filenames first, then directories
            detected_scopes_sorted=("${filename_sorted[@]}" "${directory_sorted[@]}")
            
            # Extract just the token names for the final result (limit to 9 scopes).
            # Strip leading/trailing separators (.github -> github) and drop
            # duplicates that collapse to the same clean name.
            final_scopes=()
            count=0
            gmap_clear seen_norm
            for entry in "${detected_scopes_sorted[@]}"; do
                if [ $count -ge 9 ]; then
                    break
                fi
                token="${entry##*:}"  # Extract token after last colon
                token=$(normalize_scope_name "$token")
                [ -z "$token" ] && continue
                gset_has seen_norm "$token" && continue
                gset_add seen_norm "$token"
                final_scopes+=("$token")
                count=$((count + 1))
            done

            detected_scopes="${final_scopes[*]}"
        fi
    fi
}

### Strip leading/trailing separators from a scope name so it reads cleanly
### as `type(scope):` — e.g. ".superpowers" -> "superpowers", "_deploy" ->
### "deploy", "build-" -> "build". Dotfile dirs and underscore-prefixed
### filenames are common and shouldn't leak their punctuation into commit
### scopes. Returns the trimmed name (may be empty if it was all separators).
# $1: raw scope name
function normalize_scope_name {
    local s="$1"
    while [[ "$s" == [._-]* ]]; do s="${s#?}"; done
    while [[ "$s" == *[._-] ]]; do s="${s%?}"; done
    printf '%s' "$s"
}

### Function to map staged files to detected scopes (for atomic-split commits)
# Each file is assigned to the FIRST detected scope that matches one of its path
# components (top-level wins for changelog clarity). Files matching no detected
# scope land in the "misc" group and will be committed without a scope.
# Sets globals (declared with -gA so callers can iterate after the function returns):
#   - split_groups:     associative array, scope -> newline-separated file list
#   - split_group_keys: ordered array of scope names actually used
# Returns 0 if 2+ groups were produced (split is meaningful), 1 otherwise.
function build_split_groups_from_staged {
    detect_scopes_from_staged_files

    # Re-declare globals fresh on each call
    gmap_clear split_groups
    split_group_keys=()

    if [ -z "$detected_scopes" ]; then
        return 1
    fi

    local -a scopes_arr
    IFS=' ' read -r -a scopes_arr <<< "$detected_scopes"

    local staged_files
    staged_files=$(git -c core.quotePath=false diff --no-renames --name-only --cached)
    [ -z "$staged_files" ] && return 1

    local file scope comp comp_lower comp_no_ext_lower assigned
    local -a comps

    while IFS= read -r file; do
        [ -z "$file" ] && continue

        assigned=""
        IFS='/' read -r -a comps <<< "$file"

        # Walk this file's path from root → leaf and pick the SHALLOWEST
        # component that matches a detected scope. This keeps per-feature
        # scopes like `bff` from losing to deep generic dirs like `handler`
        # in monorepo layouts (services/bff/internal/handler/foo.go → bff,
        # not handler). Skip the last component — that's the filename.
        local last_idx_inner=$((${#comps[@]} - 1))
        local i_inner
        for i_inner in "${!comps[@]}"; do
            [ "$i_inner" -eq "$last_idx_inner" ] && continue
            comp="${comps[$i_inner]}"
            [ -z "$comp" ] && continue
            comp_lower=$(to_lower "$comp")
            comp_no_ext_lower="${comp_lower%.*}"
            [ -z "$comp_no_ext_lower" ] && comp_no_ext_lower="$comp_lower"
            # detected scopes are normalized (.github -> github), so normalize
            # the component too before comparing.
            comp_lower=$(normalize_scope_name "$comp_lower")
            comp_no_ext_lower=$(normalize_scope_name "$comp_no_ext_lower")
            for scope in "${scopes_arr[@]}"; do
                if [ "$comp_lower" = "$scope" ] || [ "$comp_no_ext_lower" = "$scope" ]; then
                    assigned="$scope"
                    break 2
                fi
            done
        done

        # Filename-stem fallback. When the file lives under one or more
        # directories but none matched a detected scope (typical when every
        # parent dir is a generic container like `scripts/`, `lib/`, `src/`),
        # use the filename's stem so a one-off `scripts/commit.sh` becomes
        # the `commit` scope instead of getting bucketed into misc. Root
        # files (no parent dirs) still fall through to misc.
        if [ -z "$assigned" ] && [ "$last_idx_inner" -gt 0 ]; then
            local stem="${comps[$last_idx_inner]}"
            stem="${stem%.*}"          # drop the extension
            stem=$(to_lower "$stem")   # lowercase
            # Strip leading/trailing separators (_deploy-production ->
            # deploy-production) so they don't leak into the scope and so the
            # generic-name check below sees the clean stem.
            stem=$(normalize_scope_name "$stem")
            # Skip stems that are generic across many languages and rarely
            # carry semantic meaning (the per-feature scope is the parent
            # dir, which we've already filtered for being too generic).
            if [ -n "$stem" ] && [[ ! "$stem" =~ ^(index|main|mod|init|app|__init__|setup|config|types|utils|util|helpers|helper|common|shared)$ ]]; then
                assigned="$stem"
            fi
        fi

        [ -z "$assigned" ] && assigned="misc"

        if ! gmap_has split_groups "$assigned"; then
            split_group_keys+=("$assigned")
            gmap_set split_groups "$assigned" "$file"
        else
            gmap_set split_groups "$assigned" "$(gmap_get split_groups "$assigned")"$'\n'"$file"
        fi
    done <<< "$staged_files"

    # Keep the split between atomic and broad: a huge changeset (e.g. a dir
    # full of one-off files, each producing its own stem scope) must not
    # explode into dozens of micro-commits.
    consolidate_split_groups "$(get_max_split_groups)"

    # A split is only meaningful with 2+ groups
    if [ ${#split_group_keys[@]} -lt 2 ]; then
        return 1
    fi
    return 0
}

### Resolve the maximum number of split groups (scopes) allowed in one run.
# Configurable via gitbasher.commit-max-split-groups; defaults to 7. Clamped
# to a sane range (2..20) so a typo can't disable or over-fragment splitting.
function get_max_split_groups {
    local v
    v=$(get_config_value gitbasher.commit-max-split-groups "7")
    case "$v" in
        ''|*[!0-9]*) v=7 ;;
    esac
    [ "$v" -lt 2 ] && v=2
    [ "$v" -gt 20 ] && v=20
    printf '%s' "$v"
}

### Reorder split_group_keys so foundational scopes commit first.
#
# Git hands files back alphabetically by path, so the split commits would
# otherwise run in alphabetical order — which often inverts the real
# dependency order. In the motivating case `network/` defines the types that
# `grpcconn/`, `grpcsrv/` and `httpsrv/` all consume, yet `network` sorts last
# and lands in the final commit, leaving every earlier commit referencing code
# that doesn't exist yet in history.
#
# Heuristic: a scope that OTHER scopes reference is probably a dependency, so
# it should be committed first. For each scope S we count how many *sibling*
# groups mention S's name as a whole word in their staged additions (e.g.
# `network.GRPCOptions`, `import ".../network"`). Scopes referenced by more
# siblings sort earlier. The `misc` grab-bag always sinks last, and ties keep
# the original (alphabetical) order so the result stays deterministic. When no
# cross-references exist the order is unchanged.
#
# Controlled by gitbasher.commit-split-order:
#   auto  (default) - apply this dependency heuristic
#   alpha           - keep git's alphabetical-by-path order (legacy behaviour)
#
# Operates in place on split_group_keys. Safe to call with the index already
# staged; it only reads diffs.
function order_split_groups_by_dependency {
    local mode
    mode=$(get_config_value gitbasher.commit-split-order "auto")
    [ "$mode" = "alpha" ] && return 0
    [ ${#split_group_keys[@]} -lt 2 ] && return 0

    # Precompute each group's staged additions once (added lines only, minus
    # the +++ file header). Used as the haystack for whole-word name matches.
    gmap_clear added_text
    local scope f
    local -a farr
    for scope in "${split_group_keys[@]}"; do
        farr=()
        # :(top,literal): the names come from a repo-root-relative diff, so
        # they must not be re-resolved against CWD nor treated as globs
        # (e.g. Next.js's app/[id]/page.tsx).
        while IFS= read -r f; do [ -n "$f" ] && farr+=(":(top,literal)$f"); done <<< "$(gmap_get split_groups "$scope")"
        [ ${#farr[@]} -eq 0 ] && { gmap_set added_text "$scope" ""; continue; }
        gmap_set added_text "$scope" "$(git -c core.quotePath=false diff --cached -- "${farr[@]}" 2>/dev/null \
            | grep '^+' | grep -v '^+++' || true)"
    done

    # dep_score[S] = number of OTHER groups that reference S by name.
    gmap_clear dep_score
    local s o
    for s in "${split_group_keys[@]}"; do
        gmap_set dep_score "$s" 0
        [ "$s" = "misc" ] && continue
        for o in "${split_group_keys[@]}"; do
            [ "$o" = "$s" ] && continue
            # -F: scope names can contain regex-special chars (dots, dashes).
            # -w: match the whole token so `net` doesn't match `network`.
            if printf '%s' "$(gmap_get added_text "$o")" | grep -qwF -- "$s"; then
                gmap_inc dep_score "$s"
            fi
        done
    done

    # Stable sort: score descending, original index ascending. `misc` is
    # forced below every real scope so the catch-all never leads.
    local -a decorated=()
    local i=0 key sc
    for key in "${split_group_keys[@]}"; do
        sc="$(gmap_get dep_score "$key")"
        [ "$key" = "misc" ] && sc=-1
        decorated+=("$(printf '%d\t%05d\t%s' "$sc" "$i" "$key")")
        i=$((i + 1))
    done
    local entry
    IFS=$'\n' decorated=($(printf '%s\n' "${decorated[@]}" | sort -t$'\t' -k1,1nr -k2,2n))
    unset IFS

    local -a reordered=()
    for entry in "${decorated[@]}"; do
        reordered+=("${entry##*$'\t'}")
    done
    split_group_keys=("${reordered[@]}")
}

### Cap the number of split groups so a large changeset stays reviewable.
# When the grouping exceeds the cap, collapse it in two stages:
#   1. Re-bucket every file by its first meaningful (non-generic) path
#      component, stripping a leading dot (.github -> github). This folds a
#      sprawl of per-file stem scopes into a handful of location scopes.
#   2. If still over the cap, keep the largest (cap-1) groups and fold the
#      long tail into "misc".
# Operates in place on the globals split_groups / split_group_keys.
# $1: maximum number of groups to allow (>=2)
function consolidate_split_groups {
    local max="$1"
    case "$max" in ''|*[!0-9]*) max=7 ;; esac
    [ "$max" -lt 2 ] && max=2
    [ ${#split_group_keys[@]} -le "$max" ] && return 0

    # --- Stage 1: re-bucket by first non-generic path component ---
    gmap_clear rebucket
    local -a rebucket_keys=()
    local key file bucket comp_lower i last_idx
    local -a comps
    for key in "${split_group_keys[@]}"; do
        while IFS= read -r file; do
            [ -z "$file" ] && continue
            IFS='/' read -r -a comps <<< "$file"
            last_idx=$((${#comps[@]} - 1))
            bucket=""
            for i in "${!comps[@]}"; do
                [ "$i" -eq "$last_idx" ] && continue   # skip the filename
                comp_lower=$(to_lower "${comps[$i]}")
                [ -z "$comp_lower" ] && continue
                if [[ "$comp_lower" =~ ^(src|lib|libs|scripts|bin|node_modules|vendor|tmp|temp|cache|logs|log|services|apps|packages|modules|components|cmd|internal)$ ]]; then
                    continue
                fi
                bucket=$(normalize_scope_name "$comp_lower")   # .github -> github
                [ -z "$bucket" ] && continue
                break
            done
            [ -z "$bucket" ] && bucket="misc"
            if ! gmap_has rebucket "$bucket"; then
                rebucket_keys+=("$bucket")
                gmap_set rebucket "$bucket" "$file"
            else
                gmap_set rebucket "$bucket" "$(gmap_get rebucket "$bucket")"$'\n'"$file"
            fi
        done <<< "$(gmap_get split_groups "$key")"
    done

    gmap_clear split_groups
    split_group_keys=()
    for key in "${rebucket_keys[@]}"; do
        gmap_set split_groups "$key" "$(gmap_get rebucket "$key")"
        split_group_keys+=("$key")
    done

    [ ${#split_group_keys[@]} -le "$max" ] && return 0

    # --- Stage 2: keep the largest (max-1) groups, fold the rest into misc ---
    local -a sized=()
    local n
    for key in "${split_group_keys[@]}"; do
        n=$(printf '%s\n' "$(gmap_get split_groups "$key")" | grep -c .)
        sized+=("${n}"$'\t'"${key}")
    done
    IFS=$'\n' sized=($(printf '%s\n' "${sized[@]}" | sort -t$'\t' -k1,1nr -k2,2))
    unset IFS

    gmap_clear kept
    local -a kept_keys=()
    local keep_limit=$((max - 1))
    local misc_files="" idx=0 entry
    for entry in "${sized[@]}"; do
        key="${entry#*$'\t'}"
        if [ "$idx" -lt "$keep_limit" ] && [ "$key" != "misc" ]; then
            kept_keys+=("$key")
            gmap_set kept "$key" "$(gmap_get split_groups "$key")"
            idx=$((idx + 1))
        elif [ -z "$misc_files" ]; then
            misc_files="$(gmap_get split_groups "$key")"
        else
            misc_files+=$'\n'"$(gmap_get split_groups "$key")"
        fi
    done

    gmap_clear split_groups
    split_group_keys=()
    for key in "${kept_keys[@]}"; do
        gmap_set split_groups "$key" "$(gmap_get kept "$key")"
        split_group_keys+=("$key")
    done
    if [ -n "$misc_files" ]; then
        split_group_keys+=("misc")
        gmap_set split_groups "misc" "$misc_files"
    fi
    return 0
}

### Use AI to group staged files by FEATURE — the primary path for AI splits.
# A feature is a logical unit of work (a capability, a fix, a refactor) that may
# span multiple folders; it is decided from the actual code in the diff, not from
# file paths. Sends the staged file list, the real (truncated) diff, a diff
# summary, recent commit messages (for scope-naming conventions), and the folder
# heuristic's candidate scopes as hints. Expects back a TSV "<scope>\t<file>" —
# one line per staged file. Validates the output: every staged file must be
# assigned exactly once and scope names must be safe. On success, overwrites
# split_groups / split_group_keys with the feature grouping. Returns 0 on success,
# 1 on AI failure or unparseable output (caller falls back to the folder heuristic).
function group_files_by_feature_with_ai {
    local staged_files
    staged_files=$(git -c core.quotePath=false diff --no-renames --name-only --cached)
    [ -z "$staged_files" ] && return 1

    local diff_stat diff_details recent_commits
    diff_stat=$(get_limited_diff_stat_for_ai)
    diff_details=$(get_limited_diff_for_ai)
    recent_commits=$(get_recent_commit_messages_for_ai)

    local heuristic_hint=""
    if [ -n "$detected_scopes" ]; then
        heuristic_hint="$detected_scopes"
    fi

    local max_groups
    max_groups=$(get_max_split_groups)

    #### bundler-keep-begin (emitted content: bundler must not strip inside)
    local system_prompt="You group staged git files into commits by FEATURE — a single logical unit of work (a new capability, a bug fix, a refactor).

A feature is defined by WHAT the change accomplishes, read from the actual code in <diff> — NOT by which directory the files live in. Files in DIFFERENT folders that implement the same feature belong in the SAME group; files in the SAME folder that implement unrelated changes belong in DIFFERENT groups.

Input arrives in XML tags: a list of staged files, the actual diff, a diff summary, recent commit messages (for scope-naming conventions), and folder-derived candidate scope tokens.

Task: assign EVERY staged file to exactly one feature group. Use 1 group only if all changes truly form a single feature; otherwise use 2 to ${max_groups} groups. Never exceed ${max_groups} groups — prefer a broader feature over several tiny ones. Name each group with a short lowercase conventional-commit scope describing the FEATURE — the bare scope token only (e.g. \"auth\", never a full prefix like \"feat(auth)\" or a type like \"docs:\"), matching the scope-naming style of <recent_commits>. <heuristic_candidates> are folder-derived hints — use one only if it happens to match a feature's purpose. Use \"misc\" only for unrelated incidental files with no feature (e.g., README, top-level config).

Output format: TSV only. One line per staged file in the form <scope><TAB><file_path>. No header, no prose, no markdown fences, no surrounding quotes. Every file from <staged_files> MUST appear exactly once. The file paths must be byte-identical to those in <staged_files>."

    local user_prompt="<recent_commits>
${recent_commits}
</recent_commits>

<staged_files>
${staged_files}
</staged_files>

<diff_summary>
${diff_stat}
</diff_summary>

<diff>
${diff_details}
</diff>

<heuristic_candidates>
${heuristic_hint}
</heuristic_candidates>

Read <diff> to decide which files implement the same feature. Output TSV (scope<TAB>file) for every staged file. No prose."
    #### bundler-keep-end

    local ai_response
    ai_response=$(call_ai_api "$system_prompt" "$user_prompt" "$AI_MAX_TOKENS_FULL" "$(get_ai_model_for grouping)" 2>/dev/null)
    if [ $? -ne 0 ] || [ -z "$ai_response" ]; then
        return 1
    fi

    # Strip stray markdown fences if the model added them despite instructions
    ai_response=$(printf '%s' "$ai_response" | LC_ALL=C sed -e 's/^```[a-zA-Z]*$//' -e 's/^```$//')

    # Build a set of expected staged files for validation
    gmap_clear staged_set
    while IFS= read -r f; do
        [ -n "$f" ] && gset_add staged_set "$f"
    done <<< "$staged_files"

    gmap_clear new_groups
    local -a new_keys=()
    local line scope file tab_count
    local tab=$'\t'

    while IFS= read -r line; do
        # Trim leading/trailing whitespace
        line=$(printf '%s' "$line" | LC_ALL=C sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        [ -z "$line" ] && continue

        # Require exactly one tab so scope/file are unambiguous
        tab_count=$(printf '%s' "$line" | LC_ALL=C tr -cd "$tab" | wc -c | tr -d ' ')
        [ "$tab_count" -ne 1 ] && continue

        scope="${line%%	*}"
        file="${line#*	}"

        # Some models answer with a full conventional-commit prefix instead of
        # the bare scope the prompt asks for — observed with gemini-3.5-flash
        # emitting "docs(reflection)" when every recent commit looks like
        # "docs(reflection): ...". Extract the scope token (and drop a stray
        # trailing colon) rather than reject the line and lose the grouping.
        scope="${scope%:}"
        local type_scope_re='^[a-zA-Z0-9._/-]+\(([a-zA-Z0-9._/-]+)\)$'
        if [[ "$scope" =~ $type_scope_re ]]; then
            scope="${BASH_REMATCH[1]}"
        fi

        # Validate scope characters (same charset as sanitize_git_name)
        if ! [[ "$scope" =~ ^[a-zA-Z0-9._/-]+$ ]]; then
            continue
        fi
        scope=$(printf '%s' "$scope" | LC_ALL=C tr '[:upper:]' '[:lower:]')

        # Reject files the model invented or paraphrased
        gset_has staged_set "$file" || continue

        if ! gmap_has new_groups "$scope"; then
            new_keys+=("$scope")
            gmap_set new_groups "$scope" "$file"
        else
            gmap_set new_groups "$scope" "$(gmap_get new_groups "$scope")"$'\n'"$file"
        fi
    done <<< "$ai_response"

    # Every staged file must be covered — partial output means we fall back
    local total_assigned=0 total_staged
    local key
    for key in "${new_keys[@]}"; do
        total_assigned=$((total_assigned + $(printf '%s\n' "$(gmap_get new_groups "$key")" | grep -c .)))
    done
    total_staged=$(printf '%s\n' "$staged_files" | grep -c .)
    if [ "$total_assigned" -ne "$total_staged" ] || [ ${#new_keys[@]} -lt 1 ]; then
        return 1
    fi

    # Replace globals with AI grouping
    gmap_clear split_groups
    split_group_keys=()
    for key in "${new_keys[@]}"; do
        gmap_set split_groups "$key" "$(gmap_get new_groups "$key")"
        split_group_keys+=("$key")
    done

    return 0
}

### Stage a single file with the correct git operation based on its original
### staged change type. Plain `git add <path>` cannot replay a staged deletion
### when the working-tree file still exists (it would re-add the file from the
### worktree, undoing the delete). For deletions we use `git rm --cached`,
### which preserves the worktree copy while staging the index removal.
# $1: file path
# $2: change type (M, A, D, R, C, T, U). Empty = treat as add.
function _stage_file_by_status {
    local file="$1" status="$2"
    [ -z "$file" ] && return 0
    case "$status" in
        D)
            # Index deletion that the user intends to commit. Worktree file may
            # exist or not; --cached --ignore-unmatch handles either case
            # without touching the worktree copy.
            git rm --cached --ignore-unmatch -- ":(top,literal)$file" >/dev/null 2>&1
            ;;
        *)
            git add -- ":(top,literal)$file" >/dev/null 2>&1
            ;;
    esac
}

### Capture the change type for each currently-staged file into a map.
# Sets the global associative array `_split_status_by_file` (file → A/M/D/...).
# For renames/copies (R, C), git emits the new path as the second field — we
# key the map by that new path and treat it as an add. The old path is
# recorded as a deletion so it gets removed from the index when restaged.
function _capture_split_statuses {
    gmap_clear _split_status_by_file
    local line status old new
    while IFS=$'\t' read -r status old new; do
        [ -z "$status" ] && continue
        case "$status" in
            R*|C*)
                gmap_set _split_status_by_file "$old" "D"
                gmap_set _split_status_by_file "$new" "M"
                ;;
            *)
                gmap_set _split_status_by_file "$old" "${status:0:1}"
                ;;
        esac
    done < <(git -c core.quotePath=false diff --no-renames --name-status --cached)
}

### Restore the original staging snapshot (used when user aborts mid-split).
# Best-effort: re-stages every file that was originally staged, replaying
# the original change type so deletions stay deletions and modifications stay
# modifications. Files that were already committed earlier in the split loop
# are silently skipped (no diff vs HEAD). Already-made commits are preserved
# as-is — the user can `git reset --soft HEAD~N` if they want to undo them.
# $1: snapshot file path (one "STATUS<TAB>FILE" entry per line)
function _restore_split_snapshot {
    local snapshot="$1"
    [ -f "$snapshot" ] || return

    # First, unstage anything currently staged so we start from a clean slate
    local currently_staged
    currently_staged=$(git -c core.quotePath=false diff --no-renames --name-only --cached)
    if [ -n "$currently_staged" ]; then
        while IFS= read -r f; do
            [ -n "$f" ] && git restore --staged -- ":(top,literal)$f" >/dev/null 2>&1
        done <<< "$currently_staged"
    fi

    # Re-stage every file from the snapshot, honoring the original change
    # type so a staged deletion stays a deletion (not a fresh add).
    local status file
    while IFS=$'\t' read -r status file; do
        [ -z "$file" ] && continue
        _stage_file_by_status "$file" "$status"
    done < "$snapshot"

    rm -f "$snapshot"
}

function print_split_type_menu {
    local scope="$1"
    local ai_available="$2"

    echo -e "${YELLOW}What type of changes for ${BLUE}${BOLD}${scope}${ENDCOLOR}${YELLOW}?${ENDCOLOR}"
    echo -e "Final message will be ${YELLOW}<type>${ENDCOLOR}(${BLUE}<scope>${ENDCOLOR}): ${BLUE}<summary>${ENDCOLOR}"
    echo -e "1. ${BOLD}feat${ENDCOLOR}:\tnew feature, logic change or performance improvement"
    echo -e "2. ${BOLD}fix${ENDCOLOR}:\t\tsmall changes, eg. bug fix"
    echo -e "3. ${BOLD}refactor${ENDCOLOR}:\tcode change that neither fixes a bug nor adds a feature, style changes"
    echo -e "4. ${BOLD}test${ENDCOLOR}:\tadding missing tests or changing existing tests"
    echo -e "5. ${BOLD}build${ENDCOLOR}:\tchanges that affect the build system or external dependencies"
    echo -e "6. ${BOLD}ci${ENDCOLOR}:\t\tchanges to CI configuration files and scripts"
    echo -e "7. ${BOLD}chore${ENDCOLOR}:\tmaintenance and housekeeping"
    echo -e "8. ${BOLD}docs${ENDCOLOR}:\tdocumentation changes"
    echo -e "9. ${BLUE}${BOLD}plain${ENDCOLOR}:\twrite plain commit without type and scope"
    if [ "$ai_available" = "true" ]; then
        echo -e "g. ${GREEN}${BOLD}ai${ENDCOLOR}:\t\tgenerate commit message using AI"
    fi
    echo -e "s. ${YELLOW}${BOLD}skip${ENDCOLOR}:\tSkip this group and leave its files unstaged"
    echo -e "0. ${RED}${BOLD}abort${ENDCOLOR}:\tAbort split and restore original staging"
    echo
}

function print_commit_type_menu {
    local step="$1"
    local ai_available="$2"

    echo -e "${YELLOW}Step ${step}.${ENDCOLOR} What ${YELLOW}type${ENDCOLOR} of changes do you want to commit?"
    echo -e "Final message will be ${YELLOW}<type>${ENDCOLOR}(${BLUE}<scope>${ENDCOLOR}): ${BLUE}<summary>${ENDCOLOR}"
    echo -e "1. ${BOLD}feat${ENDCOLOR}:\tnew feature, logic change or performance improvement"
    echo -e "2. ${BOLD}fix${ENDCOLOR}:\t\tsmall changes, eg. bug fix"
    echo -e "3. ${BOLD}refactor${ENDCOLOR}:\tcode change that neither fixes a bug nor adds a feature, style changes"
    echo -e "4. ${BOLD}test${ENDCOLOR}:\tadding missing tests or changing existing tests"
    echo -e "5. ${BOLD}build${ENDCOLOR}:\tchanges that affect the build system or external dependencies"
    echo -e "6. ${BOLD}ci${ENDCOLOR}:\t\tchanges to CI configuration files and scripts"
    echo -e "7. ${BOLD}chore${ENDCOLOR}:\tmaintenance and housekeeping"
    echo -e "8. ${BOLD}docs${ENDCOLOR}:\tdocumentation changes"
    echo -e "9. ${BLUE}${BOLD}plain${ENDCOLOR}:\twrite plain commit without type and scope"
    if [ "$ai_available" = "true" ]; then
        echo -e "g. ${GREEN}${BOLD}ai${ENDCOLOR}:\t\tgenerate commit message using AI"
    fi
    echo -e "0. ${RED}${BOLD}exit${ENDCOLOR}:\tExit without changes"
}

function print_split_groups_preview {
    gmap_clear staged_status_by_file
    local staged_diff status file new_file
    staged_diff=$(git -c core.quotePath=false diff --no-renames --name-status --cached)
    while IFS=$'\t' read -r status file new_file; do
        [ -z "$file" ] && continue
        if [[ "$status" == R* || "$status" == C* ]]; then
            [ -n "$new_file" ] && file="$new_file"
        fi
        gmap_set staged_status_by_file "$file" "${status:0:1}"
    done <<< "$staged_diff"

    echo -e "${YELLOW}Detected changes across ${#split_group_keys[@]} scopes:${ENDCOLOR}"
    local scope file_count file_color staged_status
    for scope in "${split_group_keys[@]}"; do
        file_count=$(printf '%s\n' "$(gmap_get split_groups "$scope")" | grep -c .)
        echo -e "  ${BLUE}${BOLD}${scope}${ENDCOLOR} ${GRAY}(${file_count} file(s))${ENDCOLOR}:"
        while IFS= read -r file; do
            [ -z "$file" ] && continue
            staged_status=$(gmap_get staged_status_by_file "$file")
            case "$staged_status" in
                A) file_color="$GREEN" ;;
                M) file_color="$YELLOW" ;;
                D) file_color="$RED" ;;
                *) file_color="$GRAY" ;;
            esac
            echo -e "    ${file_color}${file}${ENDCOLOR}"
        done <<< "$(gmap_get split_groups "$scope")"
    done
}

### Run the AI generate / confirm / regenerate / edit loop for one split scope.
# Used both when the user invoked AI mode up-front (llm flag) and when they
# pick 'g' from the per-scope type menu.
# Sets the caller's $msg variable on success (relies on bash dynamic scoping).
# $1: scope label (used in messages), $2: scope_for_msg (empty -> no scope),
# $3: files_str (newline-separated; used to unstage on skip)
# Returns: 0 success, 1 AI failed/declined, 2 skip scope, 3 abort split
function run_split_ai_for_scope {
    local _scope="$1"
    local _scope_for_msg="$2"
    local _files_str="$3"
    local ai_msg choice manual_input
    local rejected_ai_messages=""

    msg=""

    echo -e "${YELLOW}Generating commit message with AI...${ENDCOLOR}"
    ai_msg=$(generate_ai_commit_message "simple" "$_scope_for_msg" "$_scope_for_msg" "")
    if [ $? -ne 0 ] || [ -z "$ai_msg" ]; then
        echo -e "${RED}✗ AI message generation failed.${ENDCOLOR}"
        return 1
    fi
    ai_msg=$(clean_ai_commit_message "$ai_msg")

    if [ -n "$auto_accept" ]; then
        msg="$ai_msg"
        echo -e "${GREEN}AI message:${ENDCOLOR} ${BOLD}$ai_msg${ENDCOLOR}"
        return 0
    fi

    echo
    echo -e "${GREEN}AI suggestion:${ENDCOLOR} ${BOLD}$ai_msg${ENDCOLOR}"
    echo
    read_key choice "Use it? (y/e to edit/r to regenerate/s to skip group/0 to abort) " || choice="0"
    echo
    normalize_key "$choice"

    while [ "$normalized_key" = "r" ]; do
        echo -e "${YELLOW}Regenerating...${ENDCOLOR}"
        if [ -n "$rejected_ai_messages" ]; then
            rejected_ai_messages="${rejected_ai_messages}
${ai_msg}"
        else
            rejected_ai_messages="$ai_msg"
        fi
        ai_msg=$(generate_ai_commit_message "simple" "$_scope_for_msg" "$_scope_for_msg" "" "$rejected_ai_messages")
        if [ $? -ne 0 ] || [ -z "$ai_msg" ]; then
            echo -e "${RED}✗ AI message regeneration failed.${ENDCOLOR}"
            return 1
        fi
        ai_msg=$(clean_ai_commit_message "$ai_msg")
        echo
        echo -e "${GREEN}AI suggestion:${ENDCOLOR} ${BOLD}$ai_msg${ENDCOLOR}"
        echo
        read_key choice "Use it? (y/e to edit/r to regenerate/s to skip group/0 to abort) " || choice="0"
        echo
        normalize_key "$choice"
    done

    if [ "$normalized_key" = "y" ] || [ -z "$choice" ]; then
        msg="$ai_msg"
        return 0
    elif [ "$normalized_key" = "e" ]; then
        read_editable_input manual_input "Edit: " "$ai_msg"
        msg="$manual_input"
        return 0
    elif [ "$normalized_key" = "s" ]; then
        echo -e "${YELLOW}Skipping scope '${_scope}' (files left unstaged)${ENDCOLOR}"
        while IFS= read -r f; do
            [ -n "$f" ] && git restore --staged -- ":(top,literal)$f" >/dev/null 2>&1
        done <<< "$_files_str"
        return 2
    elif [ "$choice" = "0" ]; then
        return 3
    fi
    return 1
}

### Walk the split groups, generate a message per group (AI when available),
### and create one commit per group. Restores staging on abort.
# Globals consumed: split_groups, split_group_keys, push, current_branch
# Exits the script on success (entire commit flow handled).
# Returns 1 (and restores staging) on failure so caller can fall through.
function perform_commit_split {
    local original_staged
    original_staged=$(git -c core.quotePath=false diff --no-renames --name-only --cached)
    if [ -z "$original_staged" ]; then
        echo -e "${RED}✗ No staged files to split.${ENDCOLOR}"
        return 1
    fi

    # Build a status map (file → A/M/D/...) so per-scope staging can replay
    # the right git operation. Without this, deletions get silently turned
    # into "no change" because plain `git add <path>` re-adds the worktree
    # copy when the file still exists on disk.
    _capture_split_statuses

    local snapshot_file
    snapshot_file=$(mktemp "${TMPDIR:-/tmp}/gitb-split-snapshot.XXXXXX")
    chmod 600 "$snapshot_file" 2>/dev/null || true
    # Snapshot stores STATUS<TAB>FILE per line so abort-restore can also
    # replay deletions correctly.
    : > "$snapshot_file"
    local _snap_status
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        _snap_status=$(gmap_get _split_status_by_file "$f"); [ -z "$_snap_status" ] && _snap_status="M"
        printf '%s\t%s\n' "$_snap_status" "$f" >> "$snapshot_file"
    done <<< "$original_staged"
    # Restore staging if the user kills the process mid-split. The trap must
    # EXIT: a non-exiting handler made Ctrl-C unkillable and let the loop
    # continue against the restored (full) staging, producing a mislabeled
    # mega-commit — with the snapshot already deleted.
    # shellcheck disable=SC2064  # bake the snapshot path now, by design
    trap "_restore_split_snapshot '$snapshot_file'; trap - INT TERM; echo; exit 130" INT TERM

    local total=${#split_group_keys[@]}
    local idx=0
    local commit_count=0
    local -a commit_hashes=()
    local -a commit_headers=()
    local ai_ok="true"
    if ! check_ai_available 2>/dev/null; then
        ai_ok="false"
    fi

    local scope files_str msg ai_msg choice scope_for_msg prefix manual_input
    local -a files_array

    for scope in "${split_group_keys[@]}"; do
        idx=$((idx + 1))
        echo
        echo -e "${CYAN}──${ENDCOLOR} ${BOLD}Split commit ${idx}/${total}${ENDCOLOR} ${GRAY}·${ENDCOLOR} scope ${BLUE}${BOLD}${scope}${ENDCOLOR} ${CYAN}──${ENDCOLOR}"

        # Reset everything that's currently staged, then stage only this group
        local currently_staged
        currently_staged=$(git -c core.quotePath=false diff --no-renames --name-only --cached)
        if [ -n "$currently_staged" ]; then
            while IFS= read -r f; do
                [ -n "$f" ] && git restore --staged -- ":(top,literal)$f" >/dev/null 2>&1
            done <<< "$currently_staged"
        fi

        files_str="$(gmap_get split_groups "$scope")"
        files_array=()
        while IFS= read -r f; do
            [ -n "$f" ] && files_array+=("$f")
        done <<< "$files_str"

        if [ ${#files_array[@]} -eq 0 ]; then
            echo -e "${YELLOW}No files in this group, skipping.${ENDCOLOR}"
            continue
        fi

        # Stage each file using the original change type so deletions stay
        # deletions (otherwise `git add` would re-add the worktree copy and
        # the index ends up empty for that scope, breaking AI generation).
        local stage_failed=0
        local _stage_status
        for f in "${files_array[@]}"; do
            _stage_status=$(gmap_get _split_status_by_file "$f"); [ -z "$_stage_status" ] && _stage_status="M"
            if ! _stage_file_by_status "$f" "$_stage_status"; then
                stage_failed=1
                break
            fi
        done
        if [ "$stage_failed" = "1" ]; then
            echo -e "${RED}✗ Cannot stage files for scope '${scope}'.${ENDCOLOR}"
            _restore_split_snapshot "$snapshot_file"
            trap - INT TERM
            return 1
        fi

        # If the working tree matches HEAD for every file in this group
        # (e.g. the user `git add`-ed identical content, or restage replayed
        # a no-op), bail out gracefully instead of feeding an empty diff to
        # the AI message generator.
        if [ -z "$(git diff --name-only --cached)" ]; then
            echo -e "${YELLOW}No staged changes for scope '${scope}', skipping.${ENDCOLOR}"
            continue
        fi

        echo -e "${YELLOW}Files in this commit:${ENDCOLOR}"
        print_staged_files

        scope_for_msg="$scope"

        msg=""

        # AI path — only when the user explicitly asked for AI (llm flag set
        # by ai/aisplit/aif/ff/etc). Without llm, we go straight to manual.
        if [ -n "$llm" ] && [ "$ai_ok" = "true" ]; then
            echo
            run_split_ai_for_scope "$scope" "$scope_for_msg" "$files_str"
            case $? in
                2) continue ;;
                3)
                    _restore_split_snapshot "$snapshot_file"
                    trap - INT TERM
                    echo
                    echo -e "${YELLOW}Aborted. Created ${commit_count} commit(s); original staging restored.${ENDCOLOR}"
                    exit 0
                    ;;
            esac
        fi

        # Auto-accept can't fall back to a prompt — fail loudly when AI didn't deliver
        if [ -z "$msg" ] && [ -n "$auto_accept" ]; then
            echo -e "${RED}✗ AI message generation failed — auto-accept mode cannot prompt for a manual message.${ENDCOLOR}"
            echo -e "${YELLOW}Configure AI (gitb cfg ai) or use a non-ff mode.${ENDCOLOR}"
            _restore_split_snapshot "$snapshot_file"
            trap - INT TERM
            return 1
        fi

        # Manual path: type selection + summary, mirroring the regular commit flow.
        # Reached when llm wasn't set, or when AI failed/declined in interactive mode.
        if [ -z "$msg" ]; then
            local commit_type=""
            local is_empty_msg=""
            echo
            print_split_type_menu "$scope" "$ai_ok"

            local tchoice
            while true; do
                read_key tchoice || tchoice="0"
                if ! sanitize_choice_input "$tchoice" "^[0-9sg]$"; then
                    continue
                fi
                tchoice="$sanitized_choice"
                case "$tchoice" in
                    1) commit_type="feat"; break ;;
                    2) commit_type="fix"; break ;;
                    3) commit_type="refactor"; break ;;
                    4) commit_type="test"; break ;;
                    5) commit_type="build"; break ;;
                    6) commit_type="ci"; break ;;
                    7) commit_type="chore"; break ;;
                    8) commit_type="docs"; break ;;
                    9) is_empty_msg="true"; break ;;
                    g)
                        if [ "$ai_ok" != "true" ]; then
                            continue
                        fi
                        run_split_ai_for_scope "$scope" "$scope_for_msg" "$files_str"
                        case $? in
                            0) break ;;
                            2) continue 2 ;;
                            3)
                                _restore_split_snapshot "$snapshot_file"
                                trap - INT TERM
                                echo
                                echo -e "${YELLOW}Aborted. Created ${commit_count} commit(s); original staging restored.${ENDCOLOR}"
                                exit 0
                                ;;
                            *)
                                echo
                                print_split_type_menu "$scope" "$ai_ok"
                                ;;
                        esac
                        ;;
                    s)
                        echo -e "${YELLOW}Skipping scope '${scope}' (files left unstaged)${ENDCOLOR}"
                        while IFS= read -r f; do
                            [ -n "$f" ] && git restore --staged -- ":(top,literal)$f" >/dev/null 2>&1
                        done <<< "$files_str"
                        continue 2
                        ;;
                    0)
                        _restore_split_snapshot "$snapshot_file"
                        trap - INT TERM
                        echo
                        echo -e "${YELLOW}Aborted. Created ${commit_count} commit(s); original staging restored.${ENDCOLOR}"
                        exit 0
                        ;;
                esac
            done

            if [ -z "$msg" ]; then
                prefix=""
                if [ -z "$is_empty_msg" ]; then
                    if [ -n "$scope_for_msg" ] && is_redundant_scope "$commit_type" "$scope_for_msg"; then
                        scope_for_msg=""
                    fi
                    if [ -n "$scope_for_msg" ]; then
                        prefix="${commit_type}(${scope_for_msg}): "
                    else
                        prefix="${commit_type}: "
                    fi
                fi

                echo -e "${YELLOW}Write a summary (Enter to skip group):${ENDCOLOR}"
                read_editable_input manual_input "$prefix"
                if [ -z "$manual_input" ]; then
                    echo -e "${YELLOW}Skipping scope '${scope}'${ENDCOLOR}"
                    while IFS= read -r f; do
                        [ -n "$f" ] && git restore --staged -- ":(top,literal)$f" >/dev/null 2>&1
                    done <<< "$files_str"
                    continue
                fi
                if ! sanitize_commit_message "$manual_input"; then
                    show_sanitization_error "commit message" "Use printable characters only, 1-2000 characters."
                    _restore_split_snapshot "$snapshot_file"
                    trap - INT TERM
                    return 1
                fi
                msg="${prefix}${sanitized_commit_message}"
            fi
        fi

        # Make the commit
        local result
        result=$(git commit -m "$msg" 2>&1)
        if [ $? -ne 0 ]; then
            echo -e "${RED}✗ Commit failed:${ENDCOLOR}"
            echo "$result"
            _restore_split_snapshot "$snapshot_file"
            trap - INT TERM
            return 1
        fi

        commit_count=$((commit_count + 1))
        local last_hash
        last_hash=$(git rev-parse --short HEAD)
        commit_hashes+=("$last_hash")
        commit_headers+=("$msg")
        echo -e "${GREEN}✓ Committed${ENDCOLOR} ${BLUE}${last_hash}${ENDCOLOR} ${msg}"
    done

    rm -f "$snapshot_file"
    trap - INT TERM

    # Clean up cached state — split flow handled the entire commit
    git config --unset gitbasher.cached-git-add 2>/dev/null
    git config --unset gitbasher.cached-commit-message 2>/dev/null

    echo
    if [ $commit_count -eq 0 ]; then
        echo -e "${YELLOW}No commits were created.${ENDCOLOR}"
        exit 0
    fi
    echo -e "${GREEN}✓ Created ${commit_count} atomic commit(s) on ${current_branch}:${ENDCOLOR}"
    for i in "${!commit_hashes[@]}"; do
        echo -e "  ${BLUE}${commit_hashes[$i]}${ENDCOLOR} ${commit_headers[$i]}"
    done

    if [ -n "${push}" ]; then
        echo
        push_script y
    fi

    exit 0
}

### Offer to split the staged changes into atomic per-scope commits.
# Skipped silently when:
#   - gitbasher.commit-auto-split = "never"
#   - fewer than 2 distinct scopes are detected (after optional AI refinement)
# Auto-accepts the y/N prompt when:
#   - gitbasher.commit-auto-split = "always"
#   - $1 is non-empty (split mode forced via CLI)
#   - $2 is non-empty (caller is fast/auto-accept and doesn't want to ask)
# When the user asks for an AI split (the llm flag, set by ai/aisplit/ff/etc) and
# a provider is available, AI feature-grouping is the PRIMARY path: it reads the
# real diff and groups files by feature (which may span folders). The folder
# heuristic is the FALLBACK, used when AI is unavailable, errors, or returns
# unparseable output. Disable the AI path with gitbasher.commit-ai-grouping =
# "never" (folder heuristic only); "auto" (default) and "always" both attempt AI.
# The number of groups is capped at gitbasher.commit-max-split-groups (default
# 7) so a huge changeset stays a handful of reviewable commits instead of
# dozens of micro-commits — see consolidate_split_groups.
# The resulting commits are ordered so foundational scopes (those other scopes
# reference) commit first — see order_split_groups_by_dependency. Disable with
# gitbasher.commit-split-order = "alpha".
# Returns to the caller (no exit) when the user declines or the split isn't
# applicable; perform_commit_split exits the script directly on success.
# $1: "true" to force the split flow even when the config says "ask"/"never"
# $2: "true" to skip the y/N prompt and proceed straight to splitting
function try_offer_commit_split {
    local force_split="$1"
    local auto_yes="$2"

    local auto_split
    auto_split=$(get_config_value gitbasher.commit-auto-split "ask")
    if [ "$auto_split" = "never" ] && [ -z "$force_split" ]; then
        return 1
    fi

    # Always run the folder heuristic first — fast and free. It provides the
    # fallback grouping and the detected_scopes used as naming hints for the AI.
    build_split_groups_from_staged

    # Decide whether to attempt AI feature-grouping. It is the primary path
    # whenever the user asked for an AI split; the folder heuristic above stays
    # as the fallback if AI is off, unavailable, or fails.
    local ai_grouping
    ai_grouping=$(get_config_value gitbasher.commit-ai-grouping "auto")
    local should_use_ai="false"
    case "$ai_grouping" in
        never)  should_use_ai="false" ;;
        *)      should_use_ai="true" ;;   # auto + always: attempt AI
    esac

    # AI usage is gated on the user's explicit AI intent (llm flag set by
    # ai/aisplit/aif/ff/etc). Non-AI modes (regular commit, fast, split) never
    # call the model — they keep the folder heuristic grouping as-is.
    if [ -z "$llm" ]; then
        should_use_ai="false"
    fi

    if [ "$should_use_ai" = "true" ] && check_ai_available 2>/dev/null; then
        echo
        echo -e "${YELLOW}Grouping changes by feature with AI...${ENDCOLOR}"
        if ! group_files_by_feature_with_ai; then
            # AI failed; keep the folder heuristic groups (may be empty)
            echo -e "${YELLOW}AI feature grouping failed, falling back to folder-based grouping.${ENDCOLOR}"
        fi
        # Safety net: cap AI's grouping too (the heuristic path is already
        # capped inside build_split_groups_from_staged).
        consolidate_split_groups "$(get_max_split_groups)"
    fi

    # A single group means the AI judged everything to be one feature (or the
    # folder heuristic found one scope) — nothing to split.
    if [ ${#split_group_keys[@]} -lt 2 ]; then
        if [ -n "$force_split" ]; then
            echo -e "${YELLOW}Cannot split: all changes look like a single feature.${ENDCOLOR}"
        fi
        return 1
    fi

    # Commit foundational scopes (those other scopes reference) first, so the
    # split commits don't reference code that history hasn't introduced yet.
    order_split_groups_by_dependency

    echo
    print_split_groups_preview
    echo

    local choice
    if [ -n "$force_split" ] || [ -n "$auto_yes" ] || [ "$auto_split" = "always" ]; then
        choice="y"
    else
        read_key choice "Split into ${#split_group_keys[@]} atomic commits for a cleaner changelog? (y/N) "
        echo
    fi

    # The prompt defaults to No (y/N), so Enter/empty input must decline. is_yes
    # treats Enter as "yes" (for (Y/n) prompts), so guard against empty here.
    if [ -z "$choice" ] || ! is_yes "$choice"; then
        return 1
    fi

    # 2 = "split was attempted and failed" (vs 1 = declined/not applicable):
    # the forced-split caller must not treat a failed split as success, and
    # must not unstage the staging the failure path just restored.
    perform_commit_split || return 2
    return 0
}

### Function to handle AI commit message generation
# $1: step number to display
# $2: ai generation mode ("full", "subject", or "simple")
# $3: commit prefix (for subject mode)
function handle_ai_commit_generation {
    local step="$1"
    local ai_mode="$2"
    local commit_prefix="$3"

    echo
    if [ "$ai_mode" = "full" ]; then
        echo -e "${YELLOW}Step ${step}.${ENDCOLOR} Generating ${YELLOW}multiline commit message${ENDCOLOR} using AI..."
    elif [ "$ai_mode" = "subject" ]; then
        echo -e "${YELLOW}Step ${step}.${ENDCOLOR} Generating ${YELLOW}commit message subject${ENDCOLOR} using AI..."
    else
        echo -e "${YELLOW}Step ${step}.${ENDCOLOR} Generating ${YELLOW}commit message${ENDCOLOR} using AI..."
    fi

    # Check if AI is available
    if ! check_ai_available; then
        cleanup_on_exit "$git_add"
        exit 1
    fi

    # Detect scopes from staged files for AI context
    detect_scopes_from_staged_files

    # Generate / regenerate loop: user can press 'r' to ask the model again with rejected messages included.
    local ai_commit_message choice
    local rejected_ai_messages=""
    while true; do
        ai_commit_message=$(generate_ai_commit_message "$ai_mode" "$detected_scopes" "$scopes" "$commit_prefix" "$rejected_ai_messages")

        if [ $? -ne 0 ] || [ -z "$ai_commit_message" ]; then
            echo
            echo -e "${RED}✗ Cannot generate AI commit message.${ENDCOLOR}"
            echo
            # Benign fallback prompt: Enter counts as yes, EOF/closed stdin
            # declines so non-interactive runs keep today's abort behavior.
            read_key choice "Continue with a manual commit message? (Y/n) " || choice="n"
            echo
            if is_yes "$choice"; then
                if [ "$ai_mode" = "subject" ]; then
                    echo
                fi
                echo -e "${YELLOW}Falling back to manual commit message creation...${ENDCOLOR}"
                if [ "$ai_mode" = "subject" ]; then
                    echo
                fi
                # Staging is intentionally left intact for the manual flow.
                return
            fi
            cleanup_on_exit "$git_add"
            exit 1
        fi

        ai_commit_message=$(clean_ai_commit_message "$ai_commit_message")

        echo
        echo -e "${GREEN}AI generated commit message:${ENDCOLOR}"
        echo -e "${BOLD}$ai_commit_message${ENDCOLOR}"
        echo

        # Save AI commit message so it can be reused if user exits.
        # It will be cleared only after a successful commit.
        git config gitbasher.cached-commit-message "$ai_commit_message"

        # Auto-accept mode (ff): take the first AI message and skip the prompt
        if [ -n "$auto_accept" ]; then
            choice="y"
            normalized_key="y"
            break
        fi

        read_key choice "Use this commit message? (y/n/r to regenerate/e to edit/0 to exit) " || choice="0"
        echo
        if [ "$ai_mode" != "subject" ] && [ "$choice" != "0" ]; then
            echo
        fi

        normalize_key "$choice"
        if [ "$normalized_key" = "r" ]; then
            echo -e "${YELLOW}Regenerating...${ENDCOLOR}"
            if [ -n "$rejected_ai_messages" ]; then
                rejected_ai_messages="${rejected_ai_messages}
${ai_commit_message}"
            else
                rejected_ai_messages="$ai_commit_message"
            fi
            continue
        fi
        break
    done

    if [ "$normalized_key" = "y" ] || [ -z "$choice" ]; then
        commit="$ai_commit_message"
        # Skip to final commit step
        if [ "$ai_mode" = "subject" ]; then
            echo
        fi
        # Save commit message in case commit fails (e.g. pre-commit hook)
        git config gitbasher.cached-commit-message "$commit"
        result=$(git commit -m "$commit" 2>&1)
        check_code $? "$result" "commit"

        # Clean up cached git add and commit message on successful commit
        git config --unset gitbasher.cached-git-add 2>/dev/null
        git config --unset gitbasher.cached-commit-message 2>/dev/null

        after_commit

        if [ -n "${push}" ]; then
            echo
            push_script y
        fi
        exit

    elif [ "$normalized_key" = "e" ]; then
        if [ "$ai_mode" = "full" ]; then
            echo -e "${YELLOW}Edit the AI generated message:${ENDCOLOR}"
            # Create temp file with AI message
            commitmsg_file=$(mktemp "${TMPDIR:-/tmp}/commitmsg.XXXXXX")
            chmod 600 "$commitmsg_file" 2>/dev/null || true
            trap 'rm -f "$commitmsg_file"' EXIT INT TERM
            echo "$ai_commit_message" > $commitmsg_file

            while [ true ]; do
                $editor $commitmsg_file
                commit_message=$(cat $commitmsg_file | sed '/^#/d')

                if [ -n "$commit_message" ]; then
                    break
                fi
                echo
                echo -e "${YELLOW}⚠  Commit message cannot be empty.${ENDCOLOR}"
                echo
                read -n 1 -p "Try again? (Y/n) " -s -e choice || choice="n"
                if ! is_yes "$choice"; then
                    cleanup_on_exit "$git_add"
                    rm -f "$commitmsg_file"
                    exit
                fi
            done

            # Re-apply the comment filter: the loop above validated the
            # FILTERED content, so an unfiltered re-read would commit '#'
            # note lines (git commit -m does not strip comments).
            commit_message=$(cat "$commitmsg_file" | sed '/^#/d')
            rm -f "$commitmsg_file"
            echo
        else
            if [ "$ai_mode" = "subject" ]; then
                echo
            fi
            echo -e "${YELLOW}Edit the AI generated message:${ENDCOLOR}"
            read_editable_input commit_message "" "$ai_commit_message"
        fi
        
        if [ -z "$commit_message" ]; then
            cleanup_on_exit "$git_add"
            exit
        fi
        
        commit="$commit_message"
        # Skip to final commit step
        echo
        # Save commit message in case commit fails (e.g. pre-commit hook)
        git config gitbasher.cached-commit-message "$commit"
        result=$(git commit -m "$commit" 2>&1)
        check_code $? "$result" "commit"

        # Clean up cached git add and commit message on successful commit
        git config --unset gitbasher.cached-git-add 2>/dev/null
        git config --unset gitbasher.cached-commit-message 2>/dev/null

        after_commit

        if [ -n "${push}" ]; then
            echo
            push_script y
        fi
        exit
    
    elif [ "$choice" = "0" ]; then
        cleanup_on_exit "$git_add"
        exit
        
    else
        if [ "$ai_mode" = "subject" ]; then
            echo
        fi
        echo -e "${YELLOW}Falling back to manual commit message creation...${ENDCOLOR}"
        if [ "$ai_mode" = "subject" ]; then
            echo
        fi
        # Continue with manual flow
    fi
}

### Function prints information about the last commit, use it after `git commit`
# $1: name of operation, e.g. `amend`
# Using of global:
#     * current_branch
#     * commit - message
function after_commit {
    if [ -n "$1" ]; then
        echo -e "${GREEN}✓ Committed ($1)${ENDCOLOR}"
    else
        echo -e "${GREEN}✓ Committed${ENDCOLOR}"
    fi
    
    echo

    # Print commit hash and message
    commit_hash=$(git rev-parse HEAD)
    echo -e "${BLUE}[$current_branch ${commit_hash::7}]${ENDCOLOR}"
    if [ -z "${commit}" ]; then
        echo "$(git log -1 --pretty=%B)"
    else
        printf "%s\n" "$commit"
    fi

    echo

    # Print stat of last commit - updated files and lines
    print_changes_stat "$(git --no-pager show $commit_hash --stat --format="")"

    # Some info to help users
    if [ -z "${fast}" ] && [ -z "${push}" ]; then
        echo
        echo -e "Push your changes: ${YELLOW}gitb push${ENDCOLOR}"
        echo -e "Undo commit: ${YELLOW}gitb reset${ENDCOLOR}"
    fi
}


### Map a single multi-word token to its commit flag(s).
# Returns 1 for unknown tokens so the caller can surface a wrong_mode error.
# Used only when commit_script receives 2+ arguments (multi-word form like
# `gitb commit ai fast push`). Single-token compact forms (aifp, ffp, ...) are
# still handled by the case statement below.
function set_commit_flag_from_token {
    case "$1" in
        ai|llm|i)            llm="true";;
        fast|f)              fast="true";;
        push|pu|p)           push="true";;
        scope|s)             scope="true";;
        msg|m)               msg="true";;
        ticket|jira|j|t)     ticket="true";;
        staged|st)           staged="true";;
        ff)                  fast="true"; llm="true"; auto_accept="true";;
        sff|ffst)            staged="true"; llm="true"; auto_accept="true";;
        no-split|nosplit|nos|nsp|nsl) no_split="true";;
        fixup|fix|x)         fixup="true";;
        amend|am|a)          amend="true";;
        split|sp|sl)         split="true";;
        revert|rev)          revert="true";;
        last|l)              last="true";; # deprecated alias of `gitb edit`; kept for back-compat
        help|h)              help="true";;
        *) return 1;;
    esac
    return 0
}


### Reject combinations the help text already documents as invalid (line 1295-).
# Without this, dispatch silently picks one action and ignores the rest, e.g.
# `commit ai revert` runs revert and silently drops the AI step.
function validate_commit_flag_combo {
    local actions=() invalid=()

    [ -n "$revert" ] && actions+=("revert")
    [ -n "$fixup" ]  && actions+=("fixup")
    [ -n "$amend" ]  && actions+=("amend")
    [ -n "$split" ]  && actions+=("split")

    if [ ${#actions[@]} -gt 1 ]; then
        echo -e "${RED}✗ Cannot combine actions: ${actions[*]}${ENDCOLOR}"
        echo -e "Pick one of: revert, fixup, amend, split."
        exit 1
    fi

    if [ -n "$revert" ]; then
        [ -n "$llm" ]      && invalid+=("ai")
        [ -n "$fast" ]     && invalid+=("fast")
        [ -n "$scope" ]    && invalid+=("scope")
        [ -n "$msg" ]      && invalid+=("msg")
        [ -n "$ticket" ]   && invalid+=("ticket")
        [ -n "$staged" ]   && invalid+=("staged")
        [ -n "$no_split" ] && invalid+=("no-split")
        if [ ${#invalid[@]} -gt 0 ]; then
            echo -e "${RED}✗ 'revert' does not use: ${invalid[*]}${ENDCOLOR}"
            echo -e "Only push applies (the revert commit message is auto-generated)."
            exit 1
        fi
    fi

    if [ -n "$amend" ] || [ -n "$fixup" ]; then
        local action_name
        [ -n "$amend" ] && action_name="amend" || action_name="fixup"
        invalid=()
        [ -n "$llm" ]      && invalid+=("ai")
        [ -n "$msg" ]      && invalid+=("msg")
        [ -n "$ticket" ]   && invalid+=("ticket")
        [ -n "$scope" ]    && invalid+=("scope")
        [ -n "$no_split" ] && invalid+=("no-split")
        if [ ${#invalid[@]} -gt 0 ]; then
            echo -e "${RED}✗ '${action_name}' does not use: ${invalid[*]}${ENDCOLOR}"
            echo -e "Only fast, staged, push apply (the message is reused / autosquashed)."
            exit 1
        fi
    fi

    if [ -n "$fast" ] && [ -n "$staged" ]; then
        echo -e "${RED}✗ 'fast' and 'staged' are mutually exclusive${ENDCOLOR}"
        echo -e "fast stages everything; staged commits what's already in the index."
        exit 1
    fi

    if [ -n "$split" ]; then
        invalid=()
        [ -n "$msg" ]      && invalid+=("msg")
        [ -n "$ticket" ]   && invalid+=("ticket")
        [ -n "$no_split" ] && invalid+=("no-split")
        if [ ${#invalid[@]} -gt 0 ]; then
            # Without this the split gate silently skipped and a single
            # commit was created despite the SPLIT header and summary.
            echo -e "${RED}✗ 'split' does not use: ${invalid[*]}${ENDCOLOR}"
            echo -e "Split builds one message per group; only ai, fast, staged, push apply."
            exit 1
        fi
    fi

    if [ -n "$last" ]; then
        invalid=()
        [ -n "$push" ]   && invalid+=("push")
        [ -n "$llm" ]    && invalid+=("ai")
        [ -n "$fast" ]   && invalid+=("fast")
        [ -n "$staged" ] && invalid+=("staged")
        [ -n "$msg" ]    && invalid+=("msg")
        [ -n "$ticket" ] && invalid+=("ticket")
        [ -n "$scope" ]  && invalid+=("scope")
        if [ ${#invalid[@]} -gt 0 ]; then
            # 'last' routes straight to gitb edit; silently dropping the
            # other flags (e.g. push) surprised users.
            echo -e "${RED}✗ 'last' is a deprecated alias of ${GREEN}gitb edit${RED} and takes no modifiers: ${invalid[*]}${ENDCOLOR}"
            exit 1
        fi
    fi
}


### Print a one-line summary of how the parsed flags will be interpreted.
# Helps users catch typos like `amend fasts` (a typo of `fastfix`) where the
# parser accepts the input but the chosen action wouldn't match intent.
function summarize_commit_intent {
    local action="commit" mods=()

    if [ -n "$auto_accept" ]; then
        if [ -n "$staged" ]; then
            action="ultrafast commit (ai + staged + auto-accept)"
        else
            action="ultrafast commit (ai + fast + auto-accept)"
        fi
    elif [ -n "$revert" ]; then
        action="revert a commit"
    elif [ -n "$amend" ]; then
        action="amend last commit"
    elif [ -n "$fixup" ]; then
        action="fixup an earlier commit"
    elif [ -n "$split" ]; then
        action="split staged changes into atomic commits"
    fi

    [ -n "$llm" ] && [ -z "$auto_accept" ] && mods+=("ai message")
    [ -n "$fast" ]     && [ -z "$auto_accept" ] && mods+=("fast")
    [ -n "$staged" ]   && [ -z "$auto_accept" ] && mods+=("staged")
    [ -n "$scope" ]    && mods+=("scope")
    [ -n "$msg" ]      && mods+=("msg")
    [ -n "$ticket" ]   && mods+=("ticket")
    [ -n "$no_split" ] && mods+=("no-split")
    [ -n "$push" ]     && mods+=("push")

    local line="→ ${action}"
    if [ ${#mods[@]} -gt 0 ]; then
        line="${line} (modifiers: ${mods[*]})"
    fi
    echo -e "${YELLOW}${line}${ENDCOLOR}"
}


### Main function
# $1...: mode token(s)
    # <empty> - regular commit mode
    # Single token: compact form like aifp, ffp, llmsfp (see case below)
    # Multiple tokens: any combination of words/aliases in any order, e.g.
    #   `ai fast push`, `push fast ai`, `ai f p` all map to llm+fast+push
    # msg: use editor to write commit message
    # ticket: add ticket info to the end of message header
    # fast: fast commit with git add .
    # fasts: fast commit with scope
    # push: push changes after commit
    # fastp: fast commit with push
    # fastsp: fast commit with scope and push
    # fixup: fixup commit
    # fastfix: fixup commit with git add .
    # fastfixp: fast fixup commit with push
    # amend: add to the last without edit (add to last commit)
    # amendf: add all fiels to the last commit without edit
    # revert: revert commit
    # help: print help
function commit_script {
    if [ $# -ge 2 ]; then
        for tok in "$@"; do
            set_commit_flag_from_token "$tok" || wrong_mode "commit" "$tok"
        done
    else
    case "$1" in
        scope|s)            ;; # general commit with scope
        split|sp|sl)        split="true";; # force atomic-split flow (heuristic + manual messages)
        splitp|spp|slp)     split="true"; push="true";;
        aisplit|isplit|aispl|ispl)        split="true"; llm="true";; # AI feature grouping + AI messages
        aisplitp|isplitp|aisplp|isplp)    split="true"; llm="true"; push="true";;
        no-split|nosplit|nos|nsp|nsl) no_split="true";;
        msg|m)              msg="true";;
        ticket|jira|j|t)    ticket="true";;
        fast|f)             fast="true";;
        fasts|fs|sf)        fast="true"; scope="true";;
        ff)                 fast="true"; llm="true"; auto_accept="true";; # ultrafast: no prompts at all
        ffp|ffpush)         fast="true"; llm="true"; auto_accept="true"; push="true";;
        sff|ffst)           staged="true"; llm="true"; auto_accept="true";; # like ff but on already-staged files (no git add .)
        sffp|ffstp)         staged="true"; llm="true"; auto_accept="true"; push="true";;
        staged|st)          staged="true";;
        push|pu|p)          push="true";;
        fastp|fp|pf)        fast="true"; push="true";;
        fastsp|fsp|fps)     fast="true"; push="true"; scope="true";;
        fixup|fix|x)        fixup="true";;
        fixupp|fixp|xp|px)  fixup="true"; push="true";;
        fixupst|xst|stx)    fixup="true"; staged="true";;
        fastfix|fx|xf)      fixup="true"; fast="true";;
        fastfixp|fxp|xfp)   fixup="true"; fast="true"; push="true";;
        amend|am|a)         amend="true";;
        amendst|ast|sta)    amend="true"; staged="true";;
        amendf|amf|af|fa)   amend="true"; fast="true";;
        last|l)             last="true";; # deprecated alias of `gitb edit`; kept for back-compat
        revert|rev)         revert="true";;
        revertp|revp|rp)    revert="true"; push="true";;
        llm|ai|i)           llm="true";;
        llmf|aif|if)        llm="true"; fast="true";;
        llmp|aip|ip)        llm="true"; push="true";;
        llmst|aist|ist)     llm="true"; staged="true";;
        llmfp|aifp|ifp|ipf) llm="true"; fast="true"; push="true";;
        llms|ais|is)        llm="true"; scope="true";;
        llmsf|aisf|isf)     llm="true"; scope="true"; fast="true";;
        llmsfp|aisfp|isfp)  llm="true"; scope="true"; fast="true"; push="true";;
        llmm|aim|im)        llm="true"; msg="true";;
        llmmf|aimf|imf)     llm="true"; msg="true"; fast="true";;
        llmmfp|aimfp|imfp)  llm="true"; msg="true"; fast="true"; push="true";;
        help|h)             help="true";;
        *)
            wrong_mode "commit" $1
    esac
    fi

    ### Deprecated alias: `gitb commit last` -> `gitb edit`.
    # Kept for backwards compatibility; not surfaced in help, completions, or
    # summaries. Routes silently so users with the old habit still get the
    # same `git commit --amend` editor flow.
    # Validate BEFORE routing so `commit last push` is rejected instead of
    # silently dropping the extra flags.
    validate_commit_flag_combo

    if [ -n "$last" ]; then
        edit_script ""
        exit
    fi


    ### Print header
    header_msg="GIT COMMIT"
    if [ -n "${llm}" ]; then
        header_msg="$header_msg AI"
    fi

    if [ -n "${auto_accept}" ]; then
        if [ -n "${push}" ]; then
            header_msg="$header_msg ULTRAFAST & PUSH"
        else
            header_msg="$header_msg ULTRAFAST"
        fi
    elif [ -n "${split}" ]; then
        if [ -n "${push}" ]; then
            header_msg="$header_msg SPLIT & PUSH"
        else
            header_msg="$header_msg SPLIT"
        fi
    elif [ -n "${staged}" ]; then
        header_msg="$header_msg STAGED"
    elif [ -n "${fast}" ]; then
        if [ -n "${push}" ]; then
            if [ -n "${fixup}" ]; then
                header_msg="$header_msg FAST FIXUP & PUSH"
            else
                header_msg="$header_msg FAST & PUSH"
            fi
        elif [ -n "${fixup}" ]; then
            header_msg="$header_msg FAST FIXUP"
        else
            header_msg="$header_msg FAST"
        fi
    elif [ -n "${fixup}" ]; then
        if [ -n "${push}" ]; then
            header_msg="$header_msg FIXUP & PUSH"
        else
            header_msg="$header_msg FIXUP"
        fi
    elif [ -n "${push}" ]; then
        header_msg="$header_msg & PUSH"
    elif [ -n "${msg}" ]; then
        header_msg="$header_msg MSG"
    elif [ -n "${ticket}" ]; then
        header_msg="$header_msg TICKET"
    elif [ -n "${amend}" ]; then
        header_msg="$header_msg AMEND LAST"
    elif [ -n "${revert}" ]; then
        header_msg="$header_msg REVERT"
    fi

    echo -e "${YELLOW}${header_msg}${ENDCOLOR}"
    echo

    if [ -n "$help" ]; then
        echo -e "usage: ${YELLOW}gitb commit [<flag> ...]${ENDCOLOR}     ${BLUE}# space-separated, any order${ENDCOLOR}"
        echo -e "       ${YELLOW}gitb commit <combined>${ENDCOLOR}        ${BLUE}# compact form: ff, aifp, fastsp, ...${ENDCOLOR}"
        echo
        echo -e "A commit invocation is one ${BOLD}action${NORMAL} plus zero or more ${BOLD}modifiers${NORMAL}."
        echo -e "Words can be combined freely (${GREEN}ai fast push${ENDCOLOR}) or written as a single"
        echo -e "compact token (${GREEN}aifp${ENDCOLOR}). Aliases are interchangeable."
        echo
        echo -e "${YELLOW}Actions${ENDCOLOR} ${BLUE}(pick one; default is a regular commit)${ENDCOLOR}"
        local PAD=22
        print_help_header $PAD
        print_help_row $PAD "<empty>" ""               "Interactive commit: choose files, type, scope, and summary"
        print_help_row $PAD "split"   "sp, sl"         "Split staged changes into one commit per detected scope"
        print_help_row $PAD "fixup"   "x, fix"         "Create a ${GREEN}--fixup${ENDCOLOR} commit against an older commit"
        print_help_row $PAD "amend"   "a, am"          "Add changes into the last commit (no message edit)"
        print_help_row $PAD "revert"  "rev"            "Revert a commit (${GREEN}git revert --no-edit${ENDCOLOR})"
        print_help_row $PAD "ff"      ""               "Ultrafast: ${BOLD}ai + split + fast${NORMAL} with no prompts (use ${BOLD}ffp${NORMAL} to also push)"
        print_help_row $PAD "sff"     "ffst"           "Like ${BOLD}ff${NORMAL} but on already-staged files (no ${GREEN}git add .${ENDCOLOR}); use ${BOLD}sffp${NORMAL} to also push"
        print_help_row $PAD "help"    "h, --help, -h"  "Show this help"
        echo
        echo -e "${YELLOW}Modifiers${ENDCOLOR} ${BLUE}(stack with an action, any order)${ENDCOLOR}"
        local FPAD=20
        printf "  ${YELLOW}%-*s${ENDCOLOR}  ${BLUE}%s${ENDCOLOR}\n" "$FPAD" "Flag" "Description"
        print_help_row $FPAD "fast"     "f"           "Stage all changes (${GREEN}git add .${ENDCOLOR}) before committing"
        print_help_row $FPAD "staged"   "st"          "Use already-staged files (skip the add step)"
        print_help_row $FPAD "push"     "p, pu"       "Push after the commit succeeds"
        print_help_row $FPAD "scope"    "s"           "Force a scope: 'type(scope): message' (useful with fast mode)"
        print_help_row $FPAD "no-split" "nos, nsp, nsl" "Disable automatic split detection for this commit"
        print_help_row $FPAD "ai"       "i, llm"      "Generate the commit message with AI"
        print_help_row $FPAD "msg"      "m"           "Open \$EDITOR for a multiline message body"
        print_help_row $FPAD "ticket"   "t, j, jira"  "Append ticket info to the header"
        echo
        echo -e "${YELLOW}Examples${ENDCOLOR}"
        echo -e "  ${GREEN}gitb commit${ENDCOLOR}                  Interactive commit"
        echo -e "  ${GREEN}gitb commit fast${ENDCOLOR}             ${BLUE}git add .${ENDCOLOR} then enter a message"
        echo -e "  ${GREEN}gitb commit ai fast push${ENDCOLOR}     AI message + add all + commit + push"
        echo -e "  ${GREEN}gitb commit aifp${ENDCOLOR}             Same as above (compact form)"
        echo -e "  ${GREEN}gitb commit ai split push${ENDCOLOR}    AI groups staged files into commits, then push"
        echo -e "  ${GREEN}gitb commit fixup push${ENDCOLOR}       Pick an older commit, fixup it, then push"
        echo -e "  ${GREEN}gitb commit amend fast${ENDCOLOR}       Add all current changes into the last commit"
        echo -e "  ${GREEN}gitb commit ff${ENDCOLOR}               Full auto: AI splits and writes everything"
        echo
        echo -e "${YELLOW}How modes combine${ENDCOLOR}"
        echo -e "  ${BLUE}•${ENDCOLOR} Word order doesn't matter: ${GREEN}ai fast push${ENDCOLOR} == ${GREEN}push fast ai${ENDCOLOR} == ${GREEN}aifp${ENDCOLOR}"
        echo -e "  ${BLUE}•${ENDCOLOR} Modifiers stack on actions: ${GREEN}ai+fixup${ENDCOLOR}, ${GREEN}fast+amend${ENDCOLOR}, ${GREEN}split+push${ENDCOLOR}, ${GREEN}ai+staged${ENDCOLOR}, ..."
        echo -e "  ${BLUE}•${ENDCOLOR} ${BOLD}fast${NORMAL} and ${BOLD}staged${NORMAL} are mutually exclusive (one stages all, the other uses what's staged)"
        echo -e "  ${BLUE}•${ENDCOLOR} ${BOLD}revert${NORMAL} and ${BOLD}ff${NORMAL} only accept ${BOLD}push${NORMAL} (as ${BOLD}revp${NORMAL}/${BOLD}ffp${NORMAL}); to rewrite the last message use ${GREEN}gitb edit${ENDCOLOR}"
        # Clean up cached git add on help exit
        git config --unset gitbasher.cached-git-add 2>/dev/null || true
        exit 0
    fi


    ### Print a one-line summary of how flags were interpreted so users can
    ### catch typos before any work runs.
    summarize_commit_intent
    echo


    ### Refuse to silently create unreachable commits in detached-HEAD state
    warn_if_detached_head "commit"


    ### Check if there are unstaged files
    # --porcelain output is locale-stable; empty == clean working tree.
    is_clean=$(LC_ALL=C git status --porcelain)
    if [ -z "$is_clean" ]; then
        if [ -z "${revert}" ]; then
            # Clean up cached git add when working tree is clean
            git config --unset gitbasher.cached-git-add 2>/dev/null
            echo -e "${GREEN}✓ Nothing to commit — working tree clean${ENDCOLOR}"

            # If in push mode, check for unpushed commits and delegate to
            # push_script — it owns the full push UX (header, list, prompt,
            # pull-on-conflict, success links). Don't duplicate any of that here.
            if [ -n "${push}" ]; then
                get_push_list ${current_branch} ${main_branch} ${origin_name}

                if [ -n "$push_list" ]; then
                    echo
                    echo -e "${YELLOW}But there are unpushed commits.${ENDCOLOR}"
                    echo
                    if [ -n "${auto_accept}" ]; then
                        push_script y
                    else
                        push_script
                    fi
                fi
            fi
            exit
        fi
    elif [ -n "${revert}" ]; then
        echo -e "${RED}✗ Cannot revert — there are uncommitted changes.${ENDCOLOR}"
        exit
    fi


    ### Check for staged files when using staged mode
    if [ -n "${staged}" ]; then
        staged_files_check=$(git -c core.quotePath=false diff --no-renames --name-only --cached)
        if [ -z "$staged_files_check" ]; then
            echo -e "${RED}✗ No staged files found.${ENDCOLOR}"
            exit 1
        fi
        echo -e "${YELLOW}Using already staged files:${ENDCOLOR}"
        print_staged_files
    fi


    ### Run revert logic
    if [ -n "${revert}" ]; then
        echo -e "${YELLOW}Step 1.${ENDCOLOR} Select a commit to ${YELLOW}revert${ENDCOLOR} it:"
        
        choose_commit 20

        result=$(git revert --no-edit ${commit_hash} 2>&1)
        check_code $? "$result" "revert"

        after_commit "revert"

        if [ -n "${push}" ]; then
            echo
            push_script y
        fi
        exit
    fi


    ### Print status (don't need to print in fast or staged mode)
    if [ -z "${fast}" ] && [ -z "${staged}" ]; then 
        echo -e "${YELLOW}Changed files${ENDCOLOR}"
        git_status
    fi


    ### Check for previously saved git add arguments
    saved_git_add=""
    if [ -z "${fast}" ] && [ -z "${staged}" ]; then
        saved_git_add=$(git config --get gitbasher.cached-git-add 2>/dev/null)
        if [ -n "$saved_git_add" ]; then
            echo
            echo -e "${YELLOW}Found previous git add arguments:${ENDCOLOR} ${BOLD}$saved_git_add${ENDCOLOR}"
            read_key choice "Use them? (Y/n) " || choice="n"
            echo
            if is_yes "$choice"; then
                git add $saved_git_add
                if [ $? -eq 0 ]; then
                    git_add="$saved_git_add"
                    use_saved_git_add="true"
                else
                    echo
                    echo -e "${YELLOW}⚠  Could not reuse saved git add arguments — continuing without them.${ENDCOLOR}"
                    git config --unset gitbasher.cached-git-add 2>/dev/null
                fi
                echo
            else
                git config --unset gitbasher.cached-git-add 2>/dev/null
            fi
        fi
    fi


    ### Commit Step 1: add files to commit
    if [ -n "${staged}" ]; then
        # Files are already staged, skip git add step
        git_add=""
        # Clean up any existing cached git add since we're using staged files
        git config --unset gitbasher.cached-git-add 2>/dev/null
    elif [ -n "${fast}" ]; then
        if ! stage_fast_changes; then
            exit 1
        fi
        git_add="."
        # Clean up any existing cached git add since we're using fast mode
        git config --unset gitbasher.cached-git-add 2>/dev/null
    elif [ -n "${use_saved_git_add}" ]; then
        # Files are already staged using saved git add arguments
        echo -e "${YELLOW}Step 1.${ENDCOLOR} Using saved git add arguments: ${BOLD}$git_add${ENDCOLOR}"
        echo
    else
        echo
        printf "${YELLOW}Step 1.${ENDCOLOR} List files for "
        if [ -n "${fixup}" ]; then
            printf "${YELLOW}--fixup${ENDCOLOR} "
        elif [ -n "${squash}" ]; then
            printf "${YELLOW}--squash${ENDCOLOR} "
        elif [ -n "${amend}" ]; then
            printf "${YELLOW}--amend${ENDCOLOR} "
        fi
        if [ -n "${amend}" ]; then
            printf "to the last commit in the ${YELLOW}${current_branch}${ENDCOLOR} branch\n"
        else
            printf "commit to the ${YELLOW}${current_branch}${ENDCOLOR} branch\n"
        fi
        echo "Press Enter if you want to exit"

        while [ true ]; do
            read_editable_input git_add "$(echo -n -e "${BOLD}git add${ENDCOLOR} ")"

            # Sanitize file path input
            if [ "$git_add" == "" ]; then
                exit
            fi
            
            if ! sanitize_file_path "$git_add"; then
                show_sanitization_error "file path" "Invalid file path or pattern. Avoid dangerous characters and sequences."
                continue
            fi
            git_add="$sanitized_file_path"

            result=$(git add $git_add 2>&1)
            code=$?
            staged_files_list="$(git -c core.quotePath=false diff --no-renames --name-only --cached)"
            if [ $code -eq 0 ] && [ -n "$staged_files_list" ]; then
                # Save git add arguments for potential retry
                git config gitbasher.cached-git-add "$git_add"
                break
            else
                # Check if error is about "did not match any files" and try with * appended
                if [[ "$git_add" != *"*" ]]; then
                    echo

                    git_add_with_star="${git_add}*"
                    echo -e "${YELLOW}No files were staged! Trying with wildcard:${ENDCOLOR} ${BOLD}git add $git_add_with_star${ENDCOLOR}"
                   
                    result_star=$(git add $git_add_with_star 2>&1)
                    code_star=$?
                    staged_files_list_star="$(git -c core.quotePath=false diff --no-renames --name-only --cached)"
                    if [ $code_star -eq 0 ] && [ -n "$staged_files_list_star" ]; then
                        # Save the successful git add arguments for potential retry
                        git config gitbasher.cached-git-add "$git_add_with_star"
                        git_add="$git_add_with_star"
                        break
                    else
                        echo -e "${RED}✗ Cannot add files with wildcard:${ENDCOLOR} ${BOLD}$result_star${ENDCOLOR}"
                        echo
                    fi
                else
                    echo "$result"
                fi
            fi
        done

        echo
    fi

    ### Print staged files that we add at step 1
    if [ -z "${staged}" ]; then
        echo -e "${YELLOW}Staged files:${ENDCOLOR}"
        staged_files_list="$(sed 's/^/\t/' <<< "$(git -c core.quotePath=false diff --no-renames --name-only --cached)")"
        print_staged_files
    else
        # Still need to set the staged files list for later use (editor template)
        staged_files_list="$(sed 's/^/\t/' <<< "$(git -c core.quotePath=false diff --no-renames --name-only --cached)")"
    fi


    ### Offer atomic-split when staged changes span multiple scopes.
    # Split runs the entire commit flow itself (one commit per scope) and exits
    # the script on success. Skipped for modes where it doesn't make sense
    # (amend, fixup, multi-line msg, ticket) or when forced off via config.
    # Fast/auto-accept modes skip the y/N prompt — split silently when applicable.
    if [ -z "${amend}" ] && [ -z "${fixup}" ] && [ -z "${msg}" ] && [ -z "${ticket}" ] && [ -z "${no_split}" ]; then
        _split_auto_yes=""
        if [ -n "$fast" ] || [ -n "$auto_accept" ]; then
            _split_auto_yes="true"
        fi
        try_offer_commit_split "$split" "$_split_auto_yes"
        _split_rc=$?
        # If the user explicitly asked for split mode but it wasn't applicable,
        # don't silently fall through to the single-commit flow.
        if [ -n "$split" ]; then
            if [ "$_split_rc" -ge 2 ]; then
                # The split ran and failed; its snapshot restore already put
                # the staging back — don't unstage it again, and report the
                # failure instead of exit 0.
                exit 1
            fi
            cleanup_on_exit "$git_add"
            exit 0
        fi
    fi


    ### Check for previously saved commit message (from a failed commit)
    saved_commit_message=$(git config --get gitbasher.cached-commit-message 2>/dev/null)
    if [ -n "$saved_commit_message" ] && [ -z "${fixup}" ] && [ -z "${amend}" ]; then
        echo
        echo -e "${YELLOW}Found previous commit message:${ENDCOLOR} ${BOLD}$saved_commit_message${ENDCOLOR}"
        echo
        read_key choice "Use it? (y/e to edit/n) " || choice="n"
        echo
        normalize_key "$choice"
        if [ "$normalized_key" = "y" ] || [ -z "$choice" ]; then
            commit="$saved_commit_message"
            echo
            result=$(git commit -m "$commit" 2>&1)
            check_code $? "$result" "commit"

            # Clean up cached git add and commit message on successful commit
            git config --unset gitbasher.cached-git-add 2>/dev/null
            git config --unset gitbasher.cached-commit-message 2>/dev/null

            after_commit

            if [ -n "${push}" ]; then
                echo
                push_script y
            fi
            exit
        elif [ "$normalized_key" = "e" ]; then
            echo
            echo -e "${YELLOW}Edit the saved commit message:${ENDCOLOR}"
            read_editable_input edited_commit_message "" "$saved_commit_message"
            if [ -n "$edited_commit_message" ]; then
                commit="$edited_commit_message"
                echo
                # Save edited message in case this commit also fails
                git config gitbasher.cached-commit-message "$commit"
                result=$(git commit -m "$commit" 2>&1)
                check_code $? "$result" "commit"

                # Clean up cached git add and commit message on successful commit
                git config --unset gitbasher.cached-git-add 2>/dev/null
                git config --unset gitbasher.cached-commit-message 2>/dev/null

                after_commit

                if [ -n "${push}" ]; then
                    echo
                    push_script y
                fi
                exit
            else
                git config --unset gitbasher.cached-commit-message 2>/dev/null
            fi
        else
            git config --unset gitbasher.cached-commit-message 2>/dev/null
        fi
    fi


    ### AI Logic: Generate commit message using AI (before manual steps)
    if [ -n "${llm}" ] && [ -z "${scope}" ]; then
        if [ -n "${fast}" ] || [ -n "${staged}" ]; then
            step="1"
        else
            step="2"
        fi
        type="simple"
        if [ -n "${msg}" ]; then
            type="full"
        fi
        
        handle_ai_commit_generation "$step" "$type" ""
    fi


    ### Run fixup logic
    if [ -n "${fixup}" ]; then
        echo
        step="2"
        if [ -n "${fast}" ] || [ -n "${staged}" ]; then
            step="1"
        fi
        echo -e "${YELLOW}Step ${step}.${ENDCOLOR} Select a commit to ${YELLOW}--fixup${ENDCOLOR}:"

        if [ -n "${fast}" ] || [ -n "${staged}" ]; then
            choose_commit 9
        else
            choose_commit 19
        fi
        
        result=$(git commit --fixup $commit_hash 2>&1)
        check_code $? "$result" "create fixup commit"
        
        # Clean up cached git add and commit message on successful fixup
        git config --unset gitbasher.cached-git-add 2>/dev/null
        git config --unset gitbasher.cached-commit-message 2>/dev/null

        after_commit "fixup"

        if [ -n "${push}" ]; then
            echo
            push_script y
        fi

        exit
    fi


    ### Run amend logic - add staged files to the last commit
    if [ -n "${amend}" ]; then
        result=$(git commit --amend --no-edit 2>&1)
        check_code $? "$result" "amend"

        # Clean up cached git add and commit message on successful amend
        git config --unset gitbasher.cached-git-add 2>/dev/null
        git config --unset gitbasher.cached-commit-message 2>/dev/null

        echo
        after_commit "amend"

        if [ -n "${push}" ]; then
            echo
            push_script y
        fi
        exit
    fi


    ### Commit Step 2: Select commit type
    echo
    step="2"
    if [ -n "${fast}" ] || [ -n "${staged}" ]; then
        step="1"
    fi
    local _ai_available_for_menu="false"
    if check_ai_available 2>/dev/null; then
        _ai_available_for_menu="true"
    fi
    print_commit_type_menu "$step" "$_ai_available_for_menu"

    # Index 0 is an unused placeholder so the menu numbers (1-8) map directly
    # to array indices; a plain indexed array keeps this bash 3.2 compatible.
    local -a types=("" "feat" "fix" "refactor" "test" "build" "ci" "chore" "docs")

    while [ true ]; do
        read -n 1 -s choice || choice="0"

        if [ "$choice" == "0" ]; then
            cleanup_on_exit "$git_add"
            echo
            echo -e "${YELLOW}Aborted.${ENDCOLOR}"
            exit
        fi

        normalize_key "$choice"
        if [ "$normalized_key" == "g" ]; then
            if [ "$_ai_available_for_menu" != "true" ]; then
                continue
            fi
            local _ai_mode="simple"
            if [ -n "${msg}" ]; then
                _ai_mode="full"
            fi
            handle_ai_commit_generation "$step" "$_ai_mode" ""
            # AI fell back to manual — re-show the type menu and keep reading.
            echo
            print_commit_type_menu "$step" "$_ai_available_for_menu"
            continue
        fi

        re='^[0-9]+$'
        if ! [[ $choice =~ $re ]]; then
            continue
        fi

        if [ "$choice" == "9" ]; then
            is_empty="true"
            break
        fi

        commit_type="${types[$choice]}"
        if [ -n "$commit_type" ]; then
            break
        fi
    done

    commit=""
    if [ -z "$is_empty" ]; then
        commit="$commit_type"
    fi


    ### Commit Step 3: enter a commit scope
    if [ -z "$is_empty" ] && ([ -z "$fast" ] || [ -n "$scope" ]); then
        step="3"
        if [ -n "${fast}" ] || [ -n "${staged}" ]; then
            step="2"
        fi
        echo
        echo -e "${YELLOW}Step ${step}.${ENDCOLOR} Enter a ${YELLOW}scope${ENDCOLOR} for additional context"
        echo -e "Final message will be ${BLUE}${commit_type}${ENDCOLOR}(${YELLOW}<scope>${ENDCOLOR}): ${BLUE}<summary>${ENDCOLOR}"
        echo -e "Press Enter to skip the scope, or 0 to exit without changes"
        
        # Detect possible scopes from staged files
        detect_scopes_from_staged_files
        
        # Use predefined scopes or detected scopes
        all_scopes=""
        if [ -n "$scopes" ]; then
            all_scopes="$scopes"
        elif [ -n "$detected_scopes" ]; then
            all_scopes="$detected_scopes"
        fi
        
        if [ -n "$all_scopes" ]; then
           IFS=' ' read -r -a scopes_array <<< "$all_scopes"

           res=""
           for i in "${!scopes_array[@]}"; do
                scope_display="${scopes_array[$i]}"
                res="$res$((i+1)). ${BOLD}${scope_display}${ENDCOLOR}|"
           done
           echo -e "You can select one of the ${YELLOW}detected scopes${ENDCOLOR}: $(echo $res | column -ts'|')"            
        fi

        while [ true ]; do
            read_editable_input commit_scope "<scope>: "

            if [ "$commit_scope" == "0" ]; then
                cleanup_on_exit "$git_add"
                exit
            fi

            # Check if input is empty - continue without scope
            if [ -z "$commit_scope" ]; then
                commit="$commit: "
                break
            fi

            # Check if input is a number (index selection from scopes_array)
            re_number='^[1-9][0-9]*$'
            if [[ $commit_scope =~ $re_number ]] && [ -n "$all_scopes" ]; then
                # Try to find matching scope by index
                IFS=' ' read -r -a scopes_array <<< "$all_scopes"
                index=$((commit_scope - 1))
                if [ $index -ge 0 ] && [ $index -lt ${#scopes_array[@]} ]; then
                    selected_scope="${scopes_array[$index]}"
                    # Remove the asterisk marker if present
                    commit_scope="${selected_scope#*}"
                    if is_redundant_scope "$commit_type" "$commit_scope"; then
                        commit_scope=""
                        commit="$commit: "
                    else
                        commit="$commit($commit_scope): "
                    fi
                    break
                else
                    echo -e "${RED}✗ Invalid scope index. Please choose 1-${#scopes_array[@]} or enter a custom scope.${ENDCOLOR}"
                    continue
                fi
            else
                # Sanitize custom scope input
                if ! sanitize_git_name "$commit_scope"; then
                    show_sanitization_error "scope" "Use only letters, numbers, hyphens, underscores, dots, and slashes."
                    continue
                fi
                commit_scope="$sanitized_git_name"
                if is_redundant_scope "$commit_type" "$commit_scope"; then
                    commit_scope=""
                    commit="$commit: "
                else
                    commit="$commit($commit_scope): "
                fi
                break
            fi
        done

    fi

    if [ -z "$is_empty" ] && ([ -n "$fast" ]) && [ -z "$scope" ]; then
        commit="$commit: "
    fi


    ### Commit Step 4: enter commit message, use editor in msg mode
    if [ -n "${fast}" ]; then
        if [ -n "$scope" ]; then
            step="3"
        else
            step="2"
        fi
    elif [ -n "$is_empty" ] || [ -n "${staged}" ]; then
        step="3"
    else
        step="4"
    fi
    
    if [ -n "${llm}" ] && [ -n "${scope}" ]; then
        handle_ai_commit_generation "$step" "subject" "$commit"
    else
        echo
    fi

    echo -e "${YELLOW}Step ${step}.${ENDCOLOR} Write a ${YELLOW}summary${ENDCOLOR} about your changes"
    if [ -n "$is_empty" ]; then
        echo -e "Final message will be ${YELLOW}<summary>${ENDCOLOR}"
    elif [ "$commit_scope" == "" ]; then
        echo -e "Final message will be ${BLUE}${commit_type}${ENDCOLOR}: ${YELLOW}<summary>${ENDCOLOR}"
    else
        echo -e "Final message will be ${BLUE}${commit_type}${ENDCOLOR}(${BLUE}${commit_scope}${ENDCOLOR}): ${YELLOW}<summary>${ENDCOLOR}"
    fi
    echo -e "Press Enter if you want to exit"
    # Use an editor and commitmsg file
    if [ -n "$msg" ]; then
        commitmsg_file=$(mktemp "${TMPDIR:-/tmp}/commitmsg.XXXXXX")
        chmod 600 "$commitmsg_file" 2>/dev/null || true
        # shellcheck disable=SC2064  # bake the path now: the var may be out of scope at fire time
        trap "rm -f '$commitmsg_file'" EXIT INT TERM
        staged_with_tab="$(sed 's/^/####\t/' <<< "${staged_files_list}")"

        echo """
####
#### Step ${step}. Write only <summary> about your changes without type and scope. 
#### It will be appended to '${commit}'. 
#### Lines starting with '#' will be ignored. 
#### 
#### On branch ${current_branch}
#### Changes to be commited:
${staged_with_tab}
####
#### Here is expected format:
#### ${commit}<summary>
#### <BLANK LINE>
#### <optional body>
#### <BLANK LINE>
#### <optional footer>
####
#### Summary should provide a succinct description of the change:
####     use the imperative, present tense: 'change' not 'changed' nor 'changes'
####     no dot (.) at the end
####     don't capitalize the first letter
####
#### The body is optional and should explain why you are making the change. 
####
#### The footer is optional and should contain any information about 'Breaking Changes'.
#### Breaking Change section should start with the phrase 'BREAKING CHANGE: ' followed by a summary of the breaking change.
####
#### Similarly, a Deprecation section should start with 'DEPRECATED: ' followed by a short description of what is deprecated.
""" >> $commitmsg_file

        while [ true ]; do
            $editor $commitmsg_file
            commit_message=$(cat $commitmsg_file | sed '/^#/d')

            if [ -n "$commit_message" ]; then
                break
            fi
            echo
            echo -e "${YELLOW}⚠  Commit message cannot be empty.${ENDCOLOR}"
            echo
            read -n 1 -p "Try again? (Y/n) " -s -e choice || choice="n"
            if ! is_yes "$choice"; then
                cleanup_on_exit "$git_add"
                rm -f "$commitmsg_file"
                exit
            fi
        done

        rm -f "$commitmsg_file"

    # Use read from console
    else
        read_editable_input commit_message "$(echo -n -e "${commit}")"
        if [ -z "$commit_message" ]; then
            cleanup_on_exit "$git_add"
            exit
        fi
        
        # Sanitize commit message
        if ! sanitize_commit_message "$commit_message"; then
            show_sanitization_error "commit message" "Use printable characters only, 1-2000 characters."
            cleanup_on_exit "$git_add"
            exit 1
        fi
        commit_message="$sanitized_commit_message"
    fi


    ### Commit Step 5: enter tracker ticket
    if [ -n "${ticket}" ]; then
        echo
        echo -e "${YELLOW}Step 5.${ENDCOLOR} Enter the number of a resolved issue (e.g. JIRA or YouTrack)"
        echo -e "It will be appended to the summary header"
        echo -e "Press Enter to skip, or 0 to exit without changes"

        if [ -n "$ticket_name" ]; then
            read_editable_input commit_ticket "${ticket_name}${sep}"
        else 
            read_editable_input commit_ticket "<ticket>: "
        fi
        if [ "$commit_ticket" == "0" ]; then
            cleanup_on_exit "$git_add"
            exit
        fi

        if [ "$commit_ticket" != "" ]; then
            # Sanitize ticket input
            if ! sanitize_text_input "$commit_ticket" 50; then
                show_sanitization_error "ticket" "Use printable characters only, max 50 characters."
                cleanup_on_exit "$git_add"
                exit 1
            fi
            commit_ticket="$sanitized_text"

            summary=$(echo "$commit_message" | head -n 1)
            remaining_message=""
            if [ "$summary" != "$commit_message" ]; then
                remaining_message=$(echo "$commit_message" | tail -n +2)
                remaining_message="""
    $remaining_message"
            fi
            if [ -n "$ticket_name" ]; then
                commit_ticket="${ticket_name}${sep}${commit_ticket}"
            fi
            commit_message="$summary ($commit_ticket)$remaining_message"
        fi
    fi

    commit="${commit}${commit_message}"


    ### Finally
    echo

    # Save commit message in case commit fails (e.g. pre-commit hook)
    git config gitbasher.cached-commit-message "$commit"
    result=$(git commit -m "$commit" 2>&1)
    check_code $? "$result" "commit"

    # Clean up cached git add and commit message on successful commit
    git config --unset gitbasher.cached-git-add 2>/dev/null
    git config --unset gitbasher.cached-commit-message 2>/dev/null

    after_commit

    if [ -n "${push}" ]; then
        echo
        push_script y
    fi
}
