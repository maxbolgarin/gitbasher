#!/usr/bin/env bash

### Script for initializing gitbasher
# Run it before using gitbasher

### Consts for colors
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
PURPLE="\e[35m"
CYAN="\e[36m"
GRAY="\e[37m"
ENDCOLOR="\e[0m"
BOLD="\033[1m"
NORMAL="\033[0m"


### Function tries to get config from local, then from global, then returns default
# $1: config name
# $2: default value
# Returns: config value
function get_config_value {
    value=$(git config --local --get $1)
    if [ "$value" == "" ]; then
        value=$(git config --global --get $1)
        if [ "$value" == "" ]; then
            value=$2
        fi
    fi
    echo -e "$value"
}


### Branches
current_branch=$(git branch --show-current)

main_branch=$(get_config_value gitbasher.branch "main")
if [[ "$( git branch | grep "^[\s\*]*\s*main\s*$" )" == "" ]] && [[ "$( git branch | grep "^[\s\*]*\s*master\s*$" )" != "" ]]; then
    main_branch="master"
elif [[ "$(git branch | cat)" == "" ]]; then
    main_branch=$current_branch
fi

if [ "$(get_config_value gitbasher.branch "")" == "" ]; then
    git config --local gitbasher.branch "$main_branch"
fi


### Remote
origin_name=$(git remote -v | head -n 1 | sed 's/\t.*//')
if [ "$origin_name" == "" ]; then 
    echo -e "${YELLOW}There is no configured remote in this repo!${ENDCOLOR}"
    echo
    echo -e "Use ${BLUE}git remote add origin <url>${ENDCOLOR} to add it manually"
    echo -e "Press '${BOLD}y${ENDCOLOR}' to add it now or an any key to exit"

    read -n 1 -s choice
    if [ "$choice" != "y" ]; then
        exit
    fi

    echo
    
    read -p "Remote repo URL: " -e remote_url

    if [ "$remote_url" == "" ]; then
        exit
    fi

    remote_check=$(git ls-remote "$remote_url" 2>&1)
    if [[ "$remote_check" == *"does not appear to be a git"* ]]; then
        echo
        echo -e "${RED}'$remote_url' is not a git repository!${ENDCOLOR}"
        echo "Please make sure you have the correct access rights and the repository exists."
        exit
    fi

    git remote add origin "$remote_url"
    echo -e "${GREEN}Remote successfully added!${ENDCOLOR}"
    if [ "$remote_check" == "" ]; then
        echo -e "${YELLOW}Repository '$remote_url' is probably empty${ENDCOLOR}"
    fi
    echo
    
    origin_name=$(git remote -v | head -n 1 | sed 's/\t.*//')
fi


### Get configuration from git config
sep=$(get_config_value gitbasher.sep "-")
editor=$(get_config_value core.editor "vi")
ticket_name=$(get_config_value gitbasher.ticket "")
scopes=$(get_config_value gitbasher.scopes "")


### Is this is a first run of gitbasher in this project?
is_first=$(get_config_value gitbasher.isfirst "true")
git config --local gitbasher.isfirst "false"

