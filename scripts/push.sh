#!/usr/bin/env bash

### Script for pushing commits to a remote git repository
# It will pull current branch if there are unpulled changes
# Read README.md to get more information how to use it
# Use this script only with gitbasher


### Use this function to push changes to origin
### It will exit if everyrhing is ok or there is a critical error, return if there is unpulled changes
# $@: extra args forwarded to `git push` (e.g. --force-with-lease). Pass as
#     individual array elements; this avoids word-splitting bugs and makes it
#     impossible for an empty/spaced arg to silently land as a phantom argument.
# Using of global:
#     * current_branch
#     * main_branch
#     * origin_name
# Returns:
#     * push_output
#     * push_code
#     * push_progress_shown - "true" when git's progress was streamed live
function push {
    # Transient connectivity failures (VPN flapping, DNS hiccups, SSH timeouts)
    # are retried with exponential backoff (2s, 4s, 8s, 16s) so a brief network
    # blip no longer forces the user to ctrl+c and re-run the whole command —
    # e.g. enabling a VPN mid-failure now recovers on the next attempt.
    local push_max_retries=4
    local push_retry_delay=2
    local push_attempt=0

    while true; do
        # Stream git's native progress to the terminal when interactive so large
        # pushes show live feedback, while still capturing output+code for the
        # link/rejection/network parsing below.
        stream_or_capture_git push_output push_code push_progress_shown \
            git push --progress "$@" "${origin_name}" "${current_branch}"

        if [ $push_code -eq 0 ] ; then
            echo -e "${GREEN}✓ Pushed to ${origin_name}/${current_branch}${ENDCOLOR}"

            repo=$(get_repo)
            host=$(get_repo_host "$repo")
            head_hash=$(git rev-parse HEAD 2>/dev/null)

            print_link "Repo" "$repo"

            # Direct link to the just-pushed commit
            if [ -n "$head_hash" ]; then
                commit_url=$(get_commit_url "$head_hash" "$repo")
                if [ -n "$commit_url" ]; then
                    print_link "Commit" "$commit_url"
                fi
            fi

            if [[ ${current_branch} != ${main_branch} ]]; then
                branch_url=$(get_branch_url "${current_branch}" "$repo")
                if [ -n "$branch_url" ]; then
                    print_link "Branch" "$branch_url"
                fi

                # Some hosts include a PR/MR link in the push output (first push, etc.)
                link=$(echo "$push_output" | grep -Eo "https?://[^[:space:]]+" | head -n 1 | sed 's|^remote:[[:space:]]*||')

                if [ "$host" = "github" ]; then
                    if [ -n "$link" ]; then
                        print_link "New PR" "$link"
                    else
                        new_pr_url=$(get_new_pr_url "${main_branch}" "${current_branch}" "$repo")
                        print_link "New PR" "$new_pr_url"
                    fi
                elif [ "$host" = "gitlab" ]; then
                    if [ -n "$link" ]; then
                        is_new=$(echo "$push_output" | grep -i "create a merge request")
                        if [ -n "$is_new" ]; then
                            print_link "New MR" "$link"
                        else
                            print_link "MR" "$link"
                        fi
                    else
                        new_mr_url=$(get_new_pr_url "${main_branch}" "${current_branch}" "$repo")
                        print_link "New MR" "$new_mr_url"
                    fi
                elif [ "$host" = "bitbucket" ]; then
                    if [ -n "$link" ]; then
                        print_link "New PR" "$link"
                    else
                        new_pr_url=$(get_new_pr_url "${main_branch}" "${current_branch}" "$repo")
                        print_link "New PR" "$new_pr_url"
                    fi
                fi
            fi

            # Link to CI runs for this branch
            ci_url=$(get_ci_url "${current_branch}" "$repo")
            if [ -n "$ci_url" ]; then
                print_link "$(get_ci_label "$repo")" "$ci_url"
            fi

            exit
        fi

        ### Unpulled remote changes — caller pulls then retries; not a network issue.
        if [[ $push_output == *"[rejected]"* ]]; then
            return
        fi

        ### Retry transient network failures with exponential backoff.
        if is_network_error "$push_output" && [ $push_attempt -lt $push_max_retries ]; then
            push_attempt=$((push_attempt + 1))
            echo -e "${YELLOW}⚠  Network error while pushing — retrying in ${push_retry_delay}s (attempt ${push_attempt}/${push_max_retries})...${ENDCOLOR}"
            if [ -z "$push_progress_shown" ]; then echo "$push_output" | head -n 2; fi
            echo
            sleep $push_retry_delay
            push_retry_delay=$((push_retry_delay * 2))
            continue
        fi

        ### Non-retryable error, or retries exhausted.
        echo -e "${RED}✗ Cannot push.${ENDCOLOR}"
        if [ -z "$push_progress_shown" ]; then echo "$push_output"; fi
        if [ $push_attempt -gt 0 ]; then
            echo
            echo -e "${YELLOW}⚠  Still failing after ${push_attempt} retries — check your network/VPN, then run ${GREEN}gitb push${YELLOW} again.${ENDCOLOR}"
        fi
        exit $push_code
    done
}


### Prints "<human size>  <path>" for each oversized blob, largest first.
# $1: newline-separated "<bytes>\t<path>" lines (from get_push_size_report)
function print_large_blob_lines {
    local blobs="$1"
    [ -z "$blobs" ] && return
    printf '%s\n' "$blobs" | sort -t"$(printf '\t')" -k1,1 -rn | while IFS="$(printf '\t')" read -r bytes path; do
        [ -z "$bytes" ] && continue
        echo -e "\t${YELLOW}$(human_size "$bytes")${ENDCOLOR}  ${path}"
    done
}


### Main function
# $1: mode
    # <empty> - regular commit mode
    # yes: fast push (answer 'yes')
    # force: force push
    # list: print list of commits to push and exit
function push_script {
    case "$1" in
        yes|y)      fast="true";;
        force|f)    force="true";;
        list|log|l) list="true";;
        help|h)     help="true";;
        *)
            wrong_mode "push" $1
    esac


    ### Print header
    header_msg="GIT PUSH"
    if [ -n "${fast}" ]; then
        header_msg="${YELLOW}$header_msg FAST${ENDCOLOR}"
    elif [ -n "${force}" ]; then
        header_msg="${RED}$header_msg FORCE${ENDCOLOR}"
    elif [ -n "${list}" ]; then
        header_msg="${YELLOW}$header_msg LIST${ENDCOLOR}"
    else
        header_msg="${YELLOW}$header_msg${ENDCOLOR}"
    fi

    echo -e "${header_msg}"
    echo


    if [ -n "$help" ]; then
        echo -e "usage: ${YELLOW}gitb push <mode>${ENDCOLOR}"
        echo
        local PAD=16
        print_help_header $PAD
        print_help_row $PAD "<empty>"  ""       "Show unpushed commits and push the current branch (pulls first if needed); offers to create the branch on the remote if it isn't there yet"
        print_help_row $PAD "yes"      "y"      "Push without confirmation"
        print_help_row $PAD "force"    "f"      "Push with ${RED}--force-with-lease${ENDCOLOR} (overwrites remote unless someone else has pushed first)"
        print_help_row $PAD "list"     "log, l" "Show unpushed commits without pushing"
        print_help_row $PAD "help"     "h"      "Show this help"
        echo
        echo -e "${YELLOW}Examples${ENDCOLOR}"
        echo -e "  ${GREEN}gitb push${ENDCOLOR}         Show unpushed commits, then ask before pushing"
        echo -e "  ${GREEN}gitb push y${ENDCOLOR}       Push current branch immediately, no prompt"
        echo -e "  ${GREEN}gitb push force${ENDCOLOR}   Force-push (use after a rebase that rewrites pushed history)"
        echo -e "  ${GREEN}gitb push list${ENDCOLOR}    Preview commits that would be pushed"
        exit
    fi


    ### Detached HEAD has no current_branch — push would fail with a confusing error
    warn_if_detached_head "push"


    ### Check if there are commits to push
    get_push_list ${current_branch} ${main_branch} ${origin_name}

    if [ -z "$push_list" ]; then
        ### A new branch with no commits ahead of its base still has nothing to
        # "push" in the commit sense, but it doesn't exist on the remote yet.
        # Offer to push it so the branch is created on ${origin_name}.
        branch_on_remote=$(git rev-parse --verify --quiet "${origin_name}/${current_branch}" 2>/dev/null)
        if [ -n "$origin_name" ] && [ -z "$branch_on_remote" ] && [ "${current_branch}" != "${main_branch}" ]; then
            echo -e "${BLUE}Branch ${YELLOW}${current_branch}${BLUE} does not exist on ${YELLOW}${origin_name}${BLUE} yet.${ENDCOLOR}"
            echo
            if [ -z "${fast}" ]; then
                echo -e "Do you want to push the new branch to ${YELLOW}${origin_name}/${current_branch}${ENDCOLOR} (y/n)?"
                yes_no_choice "Pushing..."
            else
                echo -e "${YELLOW}Pushing...${ENDCOLOR}"
                echo
            fi
            push -u
            exit
        fi

        echo -e "${GREEN}✓ Nothing to push${ENDCOLOR}"
        exit
    fi

    if [ "${history_from}" != "${origin_name}/${current_branch}" ]; then
        echo -e "${BLUE}Branch ${YELLOW}${current_branch}${BLUE} does not exist on ${YELLOW}${origin_name}${BLUE}; showing commits since the base commit.${ENDCOLOR}"
    fi

    ### Print list of unpushed commits
    count=$(echo -e "$push_list" | wc -l | sed 's/^ *//;s/ *$//')
    echo -e "Your branch is ahead ${YELLOW}${history_from}${ENDCOLOR} by ${BOLD}$count${ENDCOLOR} commits"
    echo -e "$push_list"


    ### Estimate how much this push will transfer and flag oversized blobs, so a
    ### stray non-code artifact ("did I commit a 500MB dump?") is caught before
    ### pushing. Disabled when the threshold is 0 or no remote is configured.
    local push_warn_mb push_warn_bytes push_range size_report push_total push_blobs
    push_warn_mb=$(get_push_warn_size)
    if [ "$push_warn_mb" != "0" ] && [ -n "$origin_name" ]; then
        if [ -n "$(git rev-parse --verify --quiet "${origin_name}/${current_branch}" 2>/dev/null)" ]; then
            push_range="${origin_name}/${current_branch}..HEAD"
        else
            push_range="HEAD --not --remotes"
        fi
        push_warn_bytes=$(( push_warn_mb * 1048576 ))
        # push_range may hold several rev-list selectors — intentional splitting.
        # shellcheck disable=SC2086
        size_report=$(get_push_size_report "$push_warn_bytes" $push_range)
        push_total=$(echo "$size_report" | head -1)
        push_blobs=$(echo "$size_report" | tail -n +2)

        if [ -n "$list" ]; then
            echo
            echo -e "Estimated push size: ${YELLOW}$(human_size "$push_total")${ENDCOLOR}"
            if [ -n "$push_blobs" ]; then
                echo -e "${YELLOW}⚠  Large files:${ENDCOLOR}"
                print_large_blob_lines "$push_blobs"
            fi
        elif [ "${push_total:-0}" -gt "$push_warn_bytes" ] || [ -n "$push_blobs" ]; then
            echo
            echo -e "${YELLOW}⚠  This push is large: ${BOLD}$(human_size "$push_total")${ENDCOLOR}${YELLOW} to ${origin_name}/${current_branch}.${ENDCOLOR}"
            if [ -n "$push_blobs" ]; then
                print_large_blob_lines "$push_blobs"
            fi
            echo -e "${GRAY}Did you mean to include these? Tune the limit with ${GREEN}gitb cfg push-size${ENDCOLOR}${GRAY} (0 disables).${ENDCOLOR}"
        fi
    fi


    ### List mode - print only unpushed commits
    if [ -n "$list" ]; then
        exit
    fi

    echo

    # `--force-with-lease` refuses to clobber commits that landed on the remote
    # since our last fetch — strictly safer than a bare `--force`. Users who
    # genuinely want to overwrite something newer can run `git push --force`
    # directly; we never expose the unconditional form here.
    force_args=()
    force_label=""
    if [ -n "${force}" ]; then
        force_args=(--force-with-lease)
        force_label=" --force-with-lease"
    fi

    ### If not in fast mode - ask if user wants to push
    if [ -z "${fast}" ]; then
        if [ -n "${force}" ]; then
            echo -e "${RED}⚠  Force-push will overwrite remote history on ${YELLOW}${origin_name}/${current_branch}${RED}.${ENDCOLOR}"
        fi
        if [ "${current_branch}" == "${main_branch}" ]; then
            echo -e "${RED}⚠  You are about to push directly to the default branch ${YELLOW}${main_branch}${RED}.${ENDCOLOR}"
        fi
        echo -e "Do you want to push${RED}${force_label}${ENDCOLOR} these commits to ${YELLOW}${origin_name}/${current_branch}${ENDCOLOR} (y/n)?"
        yes_no_choice "Pushing..."
    else
        echo -e "${YELLOW}Pushing...${ENDCOLOR}"
        echo
    fi


    ### Pushing
    push "${force_args[@]}"


    ### Get push error - there is unpulled changes
    echo -e "${RED}✗ Cannot push — there are unpulled changes in ${YELLOW}${origin_name}/${current_branch}${RED}.${ENDCOLOR}"
    echo
    if [ -n "${fast}" ]; then
        echo -e "${YELLOW}Pulling...${ENDCOLOR}"
        echo
        pull "$current_branch" "$origin_name" "$editor" "rebase"
    else
        echo -e "Do you want to pull ${YELLOW}${origin_name}/${current_branch}${ENDCOLOR} (y/n)?"
        yes_no_choice "Pulling..."
        pull "$current_branch" "$origin_name" "$editor"
    fi


    ### Push after pull
    echo
    echo -e "${YELLOW}Pushing...${ENDCOLOR}"
    echo
    push "${force_args[@]}"
}
