#!/usr/bin/env bash

### Script for creating commits in angular style (conventional commits)
# Reference: https://github.com/angular/angular/blob/22b96b9/CONTRIBUTING.md#-commit-message-guidelines
# Use this script only with gitbasher.sh

### Options
# f: fast commit (not force!)
# t: add ticket info to the end of message header
# a: amend without edit (add to last commit)
# x: fixup commit
# s: squash fixup commits


while getopts ftaxsb:u: flag; do
    case "${flag}" in
        f) fast="true";;
        t) ticket="true";;
        a) amend="true";;
        x) fixup="true";;
        s) autosquash="true";;

        b) main_branch=${OPTARG};;
        u) utils=${OPTARG};;
    esac
done

if [ -z "$main_branch" ]; then
    main_branch="main"
fi

source $utils

### Script logic here
if [ -n "${amend}" ]; then
    echo -e "${YELLOW}COMMIT MANAGER${ENDCOLOR} AMEND MODE"
elif [ -n "${fast}" ]; then
    echo -e "${YELLOW}COMMIT MANAGER${ENDCOLOR} FAST MODE"
elif [ -n "${fixup}" ]; then
    echo -e "${YELLOW}COMMIT MANAGER${ENDCOLOR} FIXUP MODE"
elif [ -n "${squash}" ]; then
    echo -e "${YELLOW}COMMIT MANAGER${ENDCOLOR} AUTOSQUASH MODE"
else
    echo -e "${YELLOW}COMMIT MANAGER${ENDCOLOR}"
fi

echo

is_clean=$(git status | tail -n 1)
if [ "$is_clean" = "nothing to commit, working tree clean" ]; then
    echo -e "${GREEN}Nothing to commit, working tree clean${ENDCOLOR}"
    if [ -z "${squash}" ]; then
        exit
    fi
elif [ -n "${autosquash}" ]; then
    echo -e "${RED}Cannot autosquash: there is uncommited changes${ENDCOLOR}"
    exit
fi

if [ -n "${autosquash}" ]; then
    commit_list=$(git log --pretty="%h %s" -n 20 | cat 2>&1)

    IFS=$'\n' read -rd '' -a commits <<<"$commit_list"

    number_of_commits=${#commits[@]}

    echo
    echo -e "${YELLOW}Step q.${ENDCOLOR} Choose commit from which to sqash fixup commits:"
    for index in "${!commits[@]}"
    do
        echo -e "$(($index+1)). ${YELLOW}$(echo ${commits[index]} | awk '{print $1}')${ENDCOLOR}  $(echo ${commits[index]#* })" 
    done
    echo "0. Exit..."

    while [ true ]; do
         if [ $number_of_commits -gt 9 ]; then
            read -n 2 choice
        else
            read -n 1 -s choice
        fi

        if [ "$choice" == "0" ] || [ "$choice" == "00" ]; then
            git restore --staged $git_add
            exit
        fi

        re='^[0-9]+$'
        if ! [[ $choice =~ $re ]]; then
           continue
        fi

        index=$(($choice-1))
        commit_hash="$(echo ${commits[index]} | awk '{print $1}')"
        if [ -n "$commit_hash" ]; then
            break
        fi
    done

    git rebase -i --autosquash ${commit_hash}
    exit

fi

current_branch=$(git branch --show-current)

# Don't need to print status in fast mode because we add everything
if [ -z "${fast}" ]; then
    echo -e "On branch ${YELLOW}${current_branch}${ENDCOLOR}"
    echo
    echo -e "${BLUE}Changed fiels${ENDCOLOR}"
    git status -s
fi

function after_commit {
    echo -e "${GREEN}Successful commit $1${ENDCOLOR}"
    echo

    commit_hash=$(git rev-parse HEAD)
    echo -e "${BLUE}[$current_branch ${commit_hash::7}]${ENDCOLOR}"
    if [ -z "${commit}" ]; then
        echo $(git log -1 --pretty=%B | cat)
    else
        printf "$commit\n"
    fi

    echo

    stat=$(git show $commit_hash --stat --format="" | cat)
    IFS=$'\n' read -rd '' -a stats <<<"$stat"
    for index in "${!stats[@]}"
    do
        s=$(echo ${stats[index]} | xargs)
        s=$(sed 's/+/\\e[32m+\\e[0m/g' <<< ${s})
        s=$(sed 's/-/\\e[31m-\\e[0m/g' <<< ${s})
        echo -e "${s}"
    done

    if [ -z "${fast}" ]; then
        echo
        echo -e "Push your changes: ${YELLOW}make push${ENDCOLOR}"
        echo -e "Undo commit: ${YELLOW}make undo-commit${ENDCOLOR}"
    fi
}

# Step 1: add files to commit
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

        # trim spaces
        git_add=$(echo "$git_add" | xargs)
        git add $git_add
        if [ $? -eq 0 ]; then
            break
        fi
    done
    echo
fi

if [ -n "${amend}" ]; then
    amend_result=$(git commit --amend --no-edit)
    if [ $? != 0 ]; then
        echo -e "${RED}Error during commit${ENDCOLOR}"
        echo -e "$amend_result"
        exit $?
    fi
    after_commit "amend"
    exit
fi

echo -e "${YELLOW}Staged files:${ENDCOLOR}"
staged=$(git diff --name-only --cached)
echo -e "${GREEN}${staged}${ENDCOLOR}"

# Step 2 if fixup: choose commit to fixup

if [ -n "${fixup}" ]; then
    commit_list=$(git log --pretty="%h %s" -n 9 | cat 2>&1)

    IFS=$'\n' read -rd '' -a commits <<<"$commit_list"

    number_of_commits=${#commits[@]}

    echo
    echo -e "${YELLOW}Step 2.${ENDCOLOR} Choose commit to fixup:"
    for index in "${!commits[@]}"
    do
        echo -e "$(($index+1)). ${YELLOW}$(echo ${commits[index]} | awk '{print $1}')${ENDCOLOR}  $(echo ${commits[index]#* })" 
    done
    echo "0. Exit..."

    while [ true ]; do
         if [ $number_of_commits -gt 9 ]; then
            read -n 2 choice
        else
            read -n 1 -s choice
        fi

        if [ "$choice" == "0" ] || [ "$choice" == "00" ]; then
            git restore --staged $git_add
            exit
        fi

        re='^[0-9]+$'
        if ! [[ $choice =~ $re ]]; then
           continue
        fi

        index=$(($choice-1))
        commit_hash="$(echo ${commits[index]} | awk '{print $1}')"
        if [ -n "$commit_hash" ]; then
            break
        fi
    done
    
    commit_output=$(git commit --fixup $commit_hash)
    if [ $? != 0 ]; then
        echo -e "${RED}Error during commit${ENDCOLOR}"
        echo -e "$commit_output"
        exit $?
    fi
    echo
    after_commit "fixup"
    exit
fi

# Step 2: choose commit type

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

# Step 3: enter commit scope

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

# Step 4: enter commit message

touch commitmsg
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
""" >> commitmsg

while [ true ]; do
    nano commitmsg
    commit_message=$(cat commitmsg | sed '/^#/d')

    if [ -n "$commit_message" ]; then
        break
    fi
    echo
    echo -e "${YELLOW}Commit message cannot be empty!${ENDCOLOR}"
    echo
    read -n 1 -p "Try for one more time? (y/n) " -s -e choice
    if [ "$choice" != "y" ]; then
        git restore --staged $git_add
        exit
    fi    
done

rm commitmsg

# Step 5: enter tracker ticket
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

# Finally
commit_output=$(git commit -m """$commit""")
if [ $? != 0 ]; then
    echo -e "${RED}Error during commit${ENDCOLOR}"
    echo -e "$commit_output"
    exit $?
fi

echo
after_commit
