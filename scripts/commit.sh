#!/bin/bash
# This script helps devs to create nice commits and version handling.
# Reference: https://www.conventionalcommits.org/en/v1.0.0/
# One more: https://github.com/angular/angular/blob/22b96b9/CONTRIBUTING.md#-commit-message-guidelines

GREEN="\e[32m"
YELLOW="\e[33m"
ENDCOLOR="\e[0m"

echo "********************************"
echo "COMMIT MANAGER v1.0"
echo
git status

# Step 1: add fields to commit

echo
echo -e "${YELLOW}Step 1.${ENDCOLOR} List the files that need to be added."
echo "You can specify entire folders, or use a '.' if you want to add everything."
echo "Leave it blank if you want to exit."

while [ true ]; do
    read -e -p "git add " git_add

    if [ -z $git_add ]; then
        exit
    fi

    git_add=${git_add##*( )}
    git add $git_add
    if [ $? -eq 0 ]; then
        break
    fi
done

echo "Staged files:"
staged=$(git diff --name-only --cached)
echo -e "${GREEN}${staged}${ENDCOLOR}"

# Step 2: choose commit type

declare -A types=(
    [1]="[FIX]"
    [2]="[FEAT]"
    [3]="[REFACT]"
    [4]="[PERF]"
    [5]="[TEST]"
    [6]="[DEPLOY]"
    [7]="[DOCS]"
    [8]="[OTHER]"
    [9]="[HUGE]"
)

echo
echo -e "${YELLOW}Step 2.${ENDCOLOR} What type of change do you want to commit?"
echo "1. [FIX]:       bug fix"
echo "2. [FEAT]:      new feature"
echo "3. [REFACT]:    code change that neither fixes a bug nor adds a feature"
echo "4. [PERF]:      code change that improves performance"
echo "5. [TEST]:      adding missing tests or correcting existing tests"
echo "6. [DEPLOY]:    changes in CI, dockerfiles, kubernetes manifests, etc..."
echo "7. [DOCS]:      documentation only changes"
echo "8. [OTHER]:     there is no option for this type of change (wtf?)"
echo "9. [HUGE]:      unrecommened type of commit when there are many changes"
echo "0. EXIT without changes"

commit_type=""

while [ true ]; do
    read -n 1 -s choice

    if [ "$choice" == "0" ]; then
        git restore --staged $git_add
        exit
    fi

    commit_type="${types[$choice]}"
    if [ -n "$commit_type" ]; then
        break
    fi
done

commit="$commit_type"

# Step 3: enter commit message

touch commitmsg
echo """
### Step 3. Write about your changes.
###
### General commit message template:
### [<type>][<JIRA>] <subject>
### <BLANK LINE>
### <body>
###
### Subject contains a succinct description of the change:
###     use the imperative, present tense: 'change' not 'changed' nor 'changes'
###     no dot (.) at the end
###
### Body: just as in the subject, use the imperative, present tense.
### The body should include the motivation for the change and contrast this with previous behavior.
""" >> commitmsg
nano commitmsg
commit_message=$(cat commitmsg | sed '/^#/d')
rm commitmsg

if [ -z "$commit_message" ]; then
    echo "Commit message cannot be empty!"
    git restore --staged $git_add
    exit
fi

# Finally

commit="$commit $commit_message"

echo

git commit -m """$commit"""

echo
echo -e "${YELLOW}Successfull commit!${ENDCOLOR}"

echo "Use 'git push origin $(git branch --show-current)' to push your changes."
echo "Use 'git reset HEAD^' to undo commit."
echo "Add some files to prev commit (ONLY LOCAL): 'git add <files> && git commit --amend --no-edit'"
echo "Change last commit message (ONLY LOCAL): 'git commit --amend'"
