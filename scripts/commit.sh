#!/usr/bin/env bash

### Script for creating commits in angular style (conventional commits)
# Reference: https://github.com/angular/angular/blob/22b96b9/CONTRIBUTING.md#-commit-message-guidelines
# Read README.md to get more information how to use it
# Use this script only with gitbasher.sh

### Options
# f: fast commit (not force!)
# t: add ticket info to the end of message header
# a: amend without edit (add to last commit)
# x: fixup commit
# s: autosquash fixup commits
# r: revert commit
# e: text editor to write commit message (default 'nano')
# u: path to utils.sh (mandatory, auto pass by gitbasher.sh)


while getopts ftaxsre:u: flag; do
    case "${flag}" in
        f) fast="true";;
        t) ticket="true";;
        a) amend="true";;
        x) fixup="true";;
        s) autosquash="true";;
        r) revert="true";;

        e) editor=${OPTARG};;
        u) utils=${OPTARG};;
    esac
done

if [ -z "$editor" ]; then
    editor="nano"
fi

source $utils


current_branch=$(git branch --show-current)

### This function prints information about last commit, use it after `git commit`
# $1: name of operation, e.g. `amend`
function after_commit {
    echo
    echo -e "${GREEN}Successful commit $1${ENDCOLOR}"
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
    stat=$(git show $commit_hash --stat --format="" | cat)
    IFS=$'\n' read -rd '' -a stats <<<"$stat"
    for index in "${!stats[@]}"
    do
        s=$(echo ${stats[index]} | xargs)
        s=$(sed 's/+/\\e[32m+\\e[0m/g' <<< ${s})
        s=$(sed 's/-/\\e[31m-\\e[0m/g' <<< ${s})
        echo -e "${s}"
    done

    # Some info to help users
    if [ -z "${fast}" ]; then
        echo
        echo -e "Push your changes: ${YELLOW}make push${ENDCOLOR}"
        echo -e "Undo commit: ${YELLOW}make undo-commit${ENDCOLOR}"
    fi
}

###
### Script logic here
###

### Print header
if [ -n "${amend}" ]; then
    echo -e "${YELLOW}COMMIT MANAGER${ENDCOLOR} AMEND"
elif [ -n "${fast}" ]; then
    echo -e "${YELLOW}COMMIT MANAGER${ENDCOLOR} FAST"
elif [ -n "${fixup}" ]; then
    echo -e "${YELLOW}COMMIT MANAGER${ENDCOLOR} FIXUP"
elif [ -n "${squash}" ]; then
    echo -e "${YELLOW}COMMIT MANAGER${ENDCOLOR} AUTOSQUASH"
elif [ -n "${revert}" ]; then
    echo -e "${YELLOW}COMMIT MANAGER${ENDCOLOR} REVERT"
else
    echo -e "${YELLOW}COMMIT MANAGER${ENDCOLOR}"
fi

echo


### Check if there are unstaged files
is_clean=$(git status | tail -n 1)
if [ "$is_clean" = "nothing to commit, working tree clean" ]; then
    if [ -z "${autosquash}" ] && [ -z "${revert}" ]; then
        echo -e "${GREEN}Nothing to commit, working tree clean${ENDCOLOR}"
        exit
    fi
elif [ -n "${autosquash}" ]; then
    echo -e "${RED}Cannot autosquash: there is uncommited changes${ENDCOLOR}"
    exit
elif [ -n "${revert}" ]; then
    echo -e "${RED}Cannot revert: there is uncommited changes${ENDCOLOR}"
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


### Print status (don't need to print in fast mode because we add everything)
if [ -z "${fast}" ]; then
    echo -e "On branch ${YELLOW}${current_branch}${ENDCOLOR}"
    echo
    echo -e "${YELLOW}Changed fiels${ENDCOLOR}"
    git status -s
fi


### Commit Step 1: add files to commit
if [ -n "${fast}" ]; then
    git add .
    git_add="."
else
    echo
    echo -e "${YELLOW}Step 1.${ENDCOLOR} List the files that need to be commited"
    echo "You can specify entire folders or use a '.' if you want to add everything, tab also works here"
    echo "Leave it blank if you want to exit"

    while [ true ]; do
        read -p "git add " -e git_add

        if [ -z $git_add ]; then
            exit
        fi

        # Trim spaces
        git_add=$(echo "$git_add" | xargs)
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

echo

### Print staged files that we add at step 1
echo -e "${YELLOW}Staged files:${ENDCOLOR}"
staged=$(git diff --name-only --cached)
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
echo "0. EXIT without changes"

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

commit_type=""
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

read -p "<scope>: " -e commit_scope

if [ "$commit_scope" == "0" ]; then
    git restore --staged $git_add
    exit
fi

commit_scope=$(echo "$commit_scope" | xargs)
if [ "$commit_scope" != "" ]; then
    commit="$commit($commit_scope):"
else
    commit="$commit:"
fi


### Commit Step 4: enter commit message
commitmsg_file=".commitmsg__"
touch $commitmsg_file
step="4"
if [ -n "${fast}" ]; then
    step="3"
fi
echo
echo -e "${YELLOW}Step ${step}.${ENDCOLOR} Write a <summary> about your changes"
echo """
###
### Step ${step}. Write a <summary> about your changes and press ^X, Y and Enter. Here is expected format:
###
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
        commit_ticket=$(echo "$commit_ticket" | xargs)

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
