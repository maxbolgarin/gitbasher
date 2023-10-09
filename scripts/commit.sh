#!/usr/bin/env bash

### Script for creating commits in angular style (conventional commits)
# Read README.md to get more information how to use it
# Use this script only with gitbasher


### Function prints information about the last commit, use it after `git commit`
# $1: name of operation, e.g. `amend`
# Using of global:
#     * current_branch
#     * commit - message
function after_commit {
    echo
    if [ -n "$1" ]; then
        echo -e "${GREEN}Successful commit $1!${ENDCOLOR}"
    else
        echo -e "${GREEN}Successful commit!${ENDCOLOR}"
    fi
    
    echo

    # Print commit hash and message
    commit_hash=$(git rev-parse HEAD)
    echo -e "${BLUE}[$current_branch ${commit_hash::7}]${ENDCOLOR}"
    if [ -z "${commit}" ]; then
        echo $(git log -1 --pretty=%B | cat)
    else
        printf "$commit\n"
    fi

    echo

    # Print stat of last commit - updated files and lines
    print_changes_stat "$(git --no-pager show $commit_hash --stat --format="")"

    # Some info to help users
    if [ -z "${fast}" ]; then
        echo
        echo -e "Push your changes: ${YELLOW}gitb push${ENDCOLOR}"
        echo -e "Undo commit: ${YELLOW}gitb undo-commit${ENDCOLOR}"
    fi
}


### Main function
# $1: mode
    # <empty> - regular commit mode
    # fast: fast commit with git add .
    # msg: use editor to write commit message
    # ticket: add ticket info to the end of message header
    # amend: amend without edit (add to last commit)
    # fixup: fixup commit
    # autosquash: autosquash fixup commits
    # revert: revert commit
function commit_script {
    case "$1" in
        fast|f)         fast="true";;
        msg|m)          msg="true";;
        ticket|t)       ticket="true";;
        amend|a)        amend="true";;
        fixup|x)        fixup="true";;
        autosquash|s)   autosquash="true";;
        revert|r)       revert="true";;
        help|h)         help="true";;
    esac

    if [ -n "$help" ]; then
        echo -e "usage: ${YELLOW}gitb commit <mode>${ENDCOLOR}"
        echo
        echo -e "${YELLOW}Available modes${ENDCOLOR}"
        echo -e "<empty>\t\tChoose files to commit and create conventional message in format: 'type(scope): message'"
        echo -e "fast|f\t\tAdd all files (git add .) and create commit message as in <empty>"
        echo -e "msg|m\t\tSame as in <empty>, but create multiline commit message using text editor"
        echo -e "ticket|t\tSame as previous, but add tracker's ticket info to the end of commit header"
        echo -e "amend|a\t\tChoose files and make --amend commit to the last one (git commit --amend --no-edit)"
        echo -e "fixup|x\t\tChoose files and select commit to --fixup (git commit --fixup <commit>) "
        echo -e "autosquash|s\tChoose commit from which to squash fixup commits and run git rebase -i --autosquash <commit>"
        echo -e "revert|r\tChoose commit to revert (git revert -no-edit <commit>)"
        echo -e "help|h\t\tShow this help"
        exit
    fi


    ### Print header
    header_msg="GIT COMMIT"
    if [ -n "${fast}" ]; then
        header_msg="$header_msg FAST"
    elif [ -n "${msg}" ]; then
        header_msg="$header_msg MSG"
    elif [ -n "${ticket}" ]; then
        header_msg="$header_msg TICKET"
    elif [ -n "${amend}" ]; then
        header_msg="$header_msg AMEND"
    elif [ -n "${fixup}" ]; then
        header_msg="$header_msg FIXUP"
    elif [ -n "${autosquash}" ]; then
        header_msg="$header_msg AUTOSQUASH"
    elif [ -n "${revert}" ]; then
        header_msg="$header_msg REVERT"
    fi

    echo -e "${YELLOW}${header_msg}${ENDCOLOR}"
    echo


    ### Check if there are unstaged files
    is_clean=$(git status | tail -n 1)
    if [ "$is_clean" = "nothing to commit, working tree clean" ]; then
        if [ -z "${autosquash}" ] && [ -z "${revert}" ]; then
            echo -e "${GREEN}Nothing to commit, working tree clean${ENDCOLOR}"
            exit
        fi
    elif [ -n "${autosquash}" ]; then
        echo -e "${RED}Cannot autosquash: there is uncommited changes!${ENDCOLOR}"
        exit
    elif [ -n "${revert}" ]; then
        echo -e "${RED}Cannot revert: there is uncommited changes!${ENDCOLOR}"
        exit
    fi


    ### Run autosquash logic
    if [ -n "${autosquash}" ]; then
        echo -e "${YELLOW}Step 1.${ENDCOLOR} Choose commit from which to squash fixup commits (third one or older):"

        choose_commit 20

        git rebase -i --autosquash ${commit_hash}
        check_code $? "" "autosquash"
        exit
    fi


    ### Run revert logic
    if [ -n "${revert}" ]; then
        echo -e "${YELLOW}Step 1.${ENDCOLOR} Choose commit to revert:"
        
        choose_commit 20

        result=$(git revert --no-edit ${commit_hash} 2>&1)
        check_code $? "$result" "revert"

        after_commit "revert"
        exit
    fi

    ### TODO: better

    ### Print status (don't need to print in fast mode because we add everything)
    if [ -z "${fast}" ]; then 
        #echo -e "On branch ${YELLOW}${current_branch}${ENDCOLOR}"
        #echo
        echo -e "${YELLOW}Changed fiels${ENDCOLOR}"
        git status -s
    fi


    ### Commit Step 1: add files to commit
    if [ -n "${fast}" ]; then
        git add .
        git_add="."
    else
        echo
        echo -e "${YELLOW}Step 1.${ENDCOLOR} List the files that need to be commited on ${YELLOW}${current_branch}${ENDCOLOR}"
        echo "You can specify entire folders or use a '.' if you want to add everything, tab also works here"
        echo "Leave it blank if you want to exit"

        while [ true ]; do
            read -p "$(echo -n -e "${TODO}git add${ENDCOLOR} ")" -e git_add

            # Trim spaces
            git_add=$(echo "$git_add" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            if [ "$git_add" == "" ]; then
                exit
            fi

            git add $git_add
            if [ $? -eq 0 ]; then
                break
            fi
        done
    fi


    ### Run amend logic - add staged files to last commit
    if [ -n "${amend}" ]; then
        result=$(git commit --amend --no-edit 2>&1)
        check_code $? "$result" "amend"

        after_commit "amend"
        exit
    fi

    if [ -z "${fast}" ]; then
        echo
    fi


    ### Print staged files that we add at step 1
    echo -e "${YELLOW}Staged files:${ENDCOLOR}"
    staged="$(sed 's/^/\t/' <<< "$(git diff --name-only --cached)")"
    echo -e "${GREEN}${staged}${ENDCOLOR}"


    ### Run fixup logic
    if [ -n "${fixup}" ]; then
        echo
        echo -e "${YELLOW}Step 2.${ENDCOLOR} Choose commit to fixup:"

        choose_commit 9
        
        result=$(git commit --fixup $commit_hash 2>&1)
        check_code $? "$result" "fixup"

        after_commit "fixup"
        exit
    fi


    ### Commit Step 2: choose commit type
    echo
    step="2"
    if [ -n "${fast}" ]; then
        step="1"
    fi
    echo -e "${YELLOW}Step ${step}.${ENDCOLOR} What type of change do you want to commit?"
    echo "1. feat:      new feature or logic changes"
    echo "2. fix:       small changes, eg. bug fix"
    echo "3. refactor:  code change that neither fixes a bug nor adds a feature, style changes"
    echo "4. test:      adding missing tests or correcting existing tests"
    echo "5. perf:      code change that improves performance"
    echo "6. build:     changes that affect the build system or external dependencies"
    echo "7. ci:        changes to CI configuration files and scripts"
    echo "8. chore:     maintanance and housekeeping"
    echo "9. docs:      documentation only changes"
    echo "0. Exit without changes"

    declare -A types=(
        [1]="feat"
        [2]="fix"
        [3]="refactor"
        [4]="test"
        [5]="perf"
        [6]="build"
        [7]="ci"
        [8]="chore"
        [9]="docs"
    )

    while [ true ]; do
        read -n 1 -s choice

        if [ "$choice" == "0" ]; then
            git restore --staged $git_add
            exit
        fi

        re='^[0-9]+$'
        if ! [[ $choice =~ $re ]]; then
            continue
        fi

        commit_type="${types[$choice]}"
        if [ -n "$commit_type" ]; then
            break
        fi
    done

    commit="$commit_type"


    ### Commit Step 3: enter commit scope
    echo
    step="3"
    if [ -n "${fast}" ]; then
        step="2"
    fi
    echo -e "${YELLOW}Step ${step}.${ENDCOLOR} Enter a scope of your changes to provide additional context"
    echo -e "Final meesage will be ${YELLOW}${commit_type}(<scope>): <summary>${ENDCOLOR}"
    echo -e "Leave it blank if you don't want to enter a scope or 0 to exit"

    read -p "$(echo -n -e "${TODO}<scope>:${ENDCOLOR} ")" -e commit_scope

    if [ "$commit_scope" == "0" ]; then
        git restore --staged $git_add
        exit
    fi

    commit_scope=$(echo "$commit_scope" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    if [ "$commit_scope" != "" ]; then
        commit="$commit($commit_scope):"
    else
        commit="$commit:"
    fi


    ### Commit Step 4: enter commit message, use editor in msg mode
    step="4"
    if [ -n "${fast}" ]; then
        step="3"
    fi
    echo
    echo -e "${YELLOW}Step ${step}.${ENDCOLOR} Write a <summary> about your changes"
    echo -e "Final meesage will be ${YELLOW}${commit} <summary>${ENDCOLOR}"

    # Use editor and commitmsg file
    if [ -n "$msg" ]; then
        commitmsg_file=".commitmsg__"
        touch $commitmsg_file

        staged_with_tab="$(sed 's/^/###\t/' <<< "${staged}")"

        echo """
###
### Step ${step}. Write a <summary> about your changes. Lines starting with '#' will be ignored. 
### 
### On branch ${current_branch}
### Changes to be commited:
${staged_with_tab}
###
### Here is expected format:
### ${commit} <summary>
### <BLANK LINE>
### <optional body>
### <BLANK LINE>
### <optional footer>
###
### Summary should provide a succinct description of the change:
###     use the imperative, present tense: 'change' not 'changed' nor 'changes'
###     no dot (.) at the end
###     don't capitalize the first letter
###
### The body is optional. should explain why you are making the change. 
### You can include a comparison of the previous behavior with the new behavior in order to illustrate the impact of the change.
###
### The footer is optional and should contain any information about 'Breaking Changes'.
### Breaking Change section should start with the phrase 'BREAKING CHANGE: ' followed by a summary of the breaking change, 
### a blank line, and a detailed description of the breaking change that also includes migration instructions.
###
### Similarly, a Deprecation section should start with 'DEPRECATED: ' followed by a short description of what is deprecated,
### a blank line, and a detailed description of the deprecation that also mentions the recommended update path.
""" >> $commitmsg_file

        while [ true ]; do
            $editor $commitmsg_file
            commit_message=$(cat $commitmsg_file | sed '/^#/d')

            if [ -n "$commit_message" ]; then
                break
            fi
            echo
            echo -e "${YELLOW}Commit message cannot be empty${ENDCOLOR}"
            echo
            read -n 1 -p "Try for one more time? (y/n) " -s -e choice
            if [ "$choice" != "y" ]; then
                git restore --staged $git_add
                find . -name "$commitmsg_file*" -delete
                exit
            fi    
        done

        find . -name "$commitmsg_file*" -delete

    # Use read from console
    else
        echo -e "Leave it blank if you want to exit"
        read -p "$(echo -n -e "${TODO}${commit}${ENDCOLOR} ")" -e commit_message
        if [ -z "$commit_message" ]; then
            git restore --staged $git_add
            exit
        fi
    fi


    ### Commit Step 5: enter tracker ticket
    if [ -n "${ticket}" ]; then
        echo
        echo -e "${YELLOW}Step 5.${ENDCOLOR} Enter the number of issue in your tracking system (e.g. JIRA or Youtrack)"
        echo -e "It will be added to the end of summary"
        echo -e "Leave it blank if you don't want to enter a ticket or 0 to exit"

        read -p "<ticket>: " -e commit_ticket

        if [ "$commit_ticket" == "0" ]; then
            git restore --staged $git_add
            exit
        fi

        if [ "$commit_ticket" != "" ]; then
            commit_ticket=$(echo "$commit_ticket" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

            summary=$(echo "$commit_message" | head -n 1)
            remaining_message=""
            if [ "$summary" != "$commit_message" ]; then
                remaining_message=$(echo "$commit_message" | tail -n +2)
                remaining_message="""
    $remaining_message"
            fi
            commit_message="$summary ($commit_ticket)$remaining_message"
        fi
    fi

    commit="$commit $commit_message"


    ### Finally
    result=$(git commit -m """$commit""" 2>&1)
    check_code $? "$result" "commit"

    after_commit

}