#!/usr/bin/env bash

### Main script for running Gitbasher
# Copy this file to your project and use Makefile
# In file $SETTINGS_FILE is stored a path to a directory with a gitbasher repo
# Using: gitbasher.sh -r <script_name> -a "<script_args>"
# Example: gitbasher.sh -r commit -a "-f -b main"
# Supported scripts:
# - branch
# - commit
# - pull
# - push
# - tag
# - ver

SETTINGS_FILE=~/.gitbasher

### Options
# i: init application
# f: force init
# s: silent init
# r: script name to run
# a: args to script

while getopts 'ifsr:a:' flag; do
    case "${flag}" in
        i) to_init="true";;
        f) force="true";;
        s) silent="true";;
        r) to_run="$OPTARG";;
        a) args="$OPTARG";;
    esac
done

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
ENDCOLOR="\e[0m"
gitbasher_directory=$( cat ${SETTINGS_FILE} 2> /dev/null )


### Cannot use bash version less than 4 because of many features that was added to language in that version
if ((BASH_VERSINFO[0] < 4)); then 
    printf "Sorry, you need at least ${YELLOW}bash-4.0${ENDCOLOR} to run this script.\n
If your OS is debian-based, use:
    ${GREEN}apt-get install --only-upgrade bash${ENDCOLOR}\n
If your OS is mac, use:
    ${GREEN}brew install bash${ENDCOLOR}\n\n" 
    exit 1; 
fi


### Supported scripts
scripts_dir="scripts"
declare -A scripts=(
    ["branch"]="${scripts_dir}/branch.sh"
    ["commit"]="${scripts_dir}/commit.sh"
    ["pull"]="${scripts_dir}/pull.sh"
    ["push"]="${scripts_dir}/push.sh"
    ["tag"]="${scripts_dir}/tag.sh"
    ["ver"]="${scripts_dir}/ver.sh"
)


### Function for evaluating path with '~' symbol
# $1: path
function prepare_path {
    eval echo "$1"
}


### Function for creating .gitbasher file with path to gitbasher repo
# $1: flag for force init
function init {
    if [[ -z "${silent}" ]]; then
        printf "Welcome to ${YELLOW}gitbasher${ENDCOLOR} init application!\n"
    fi
    if [[ -n "${gitbasher_directory}" ]] && [[ -z "$1"  ]]; then
        if [[ -z "${silent}" ]]; then
            echo -e "Scripts are already inited to folder: ${YELLOW}${gitbasher_directory}${ENDCOLOR}"
            echo "If you want to change it, use '-f' flag."
        fi
        return
    fi
    touch ${SETTINGS_FILE}
    
    echo -e "To init gitbasher you should provide a path to gitbasher repo (it will be saved to ~/.gitbasher, default ${YELLOW}../gitbasher${ENDCOLOR})"
    echo -e "Enter ${YELLOW}pwd${ENDCOLOR} to use current directory (if you inside gitbasher repo now)"
    echo -e "Enter ${YELLOW}0${ENDCOLOR} to exit"
    while [ true ]; do
        read -p "Path: " -e gitbasher_directory

        if [ "${gitbasher_directory}" == "0" ]; then
            exit 1
        fi

        if [ "${gitbasher_directory}" == "pwd" ]; then
            gitbasher_directory=$(pwd)
        fi

        if [ -z "${gitbasher_directory}" ]; then
            gitbasher_directory="../gitbasher"
        fi

        gitbasher_directory=${gitbasher_directory##*( )}
        if [ -d $( prepare_path $gitbasher_directory ) ]; then
            echo ${gitbasher_directory} > $( prepare_path $SETTINGS_FILE )
            echo -e "Set path to ${YELLOW}${gitbasher_directory}${ENDCOLOR}"
            echo
            return
        else
            echo -e "${RED}Directory ${YELLOW}${gitbasher_directory} ${RED}doesn't exist${ENDCOLOR}"
        fi
    done
}

###
### Script logic here
###

### Run init if we want to init, provide -f if you want to force init
if [ -n "${to_init}" ]; then
    init $force
    exit
fi


#### Run init if we haven't been inited
if [ -z "${gitbasher_directory}" ]; then
    init 'true'
fi


### Run script
if [ -z "${to_run}" ]; then
    echo "You should provide script to run, use '-r' flag."
    exit
fi

script_name="${scripts[$to_run]}"
if [ -z "$script_name" ]; then
    echo -e "Unsupported script: ${YELLOW}${to_run}${ENDCOLOR}"
    exit
fi

utils=$( prepare_path "${gitbasher_directory}/${scripts_dir}/common.sh" )
script=$( prepare_path "${gitbasher_directory}/${script_name} ${args} -u ${utils}" )
$script
script_code=$?
exit $script_code
