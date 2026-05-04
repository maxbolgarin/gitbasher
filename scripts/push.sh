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
function push {
    push_output=$(git push "$@" "${origin_name}" "${current_branch}" 2>&1)
    push_code=$?

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

    if [[ $push_output != *"[rejected]"* ]]; then
        echo -e "${RED}✗ Cannot push.${ENDCOLOR}"
        echo "$push_output"
        exit $push_code
    fi
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
    # kcov-skip-start


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
        # kcov-skip-start
        echo -e "usage: ${YELLOW}gitb push <mode>${ENDCOLOR}"
        echo
        local PAD=16
        print_help_header $PAD
        print_help_row $PAD "<empty>"  ""       "Show unpushed commits and push the current branch (pulls first if needed)"
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
        # kcov-skip-end
    fi


    ### Detached HEAD has no current_branch — push would fail with a confusing error
    warn_if_detached_head "push"


    ### Check if there are commits to push
    get_push_list ${current_branch} ${main_branch} ${origin_name}

    if [ -z "$push_list" ]; then
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
        pull $current_branch $origin_name $editor "rebase"
    else
        echo -e "Do you want to pull ${YELLOW}${origin_name}/${current_branch}${ENDCOLOR} (y/n)?"
        yes_no_choice "Pulling..."
        pull $current_branch $origin_name $editor
    fi


    ### Push after pull
    echo
    echo -e "${YELLOW}Pushing...${ENDCOLOR}"
    echo
    push "${force_args[@]}"
    # kcov-skip-end
}
