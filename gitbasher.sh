#!/usr/bin/env bash

### Main script for running Gitbasher
# Copy this file to your project and use Makefile
# In file $SETTINGS_FILE is stored a path to a directory with a gitbasher repo
# Using: gitbasher.sh -r <script_name> -a "<script_args>"
# Example: gitbasher.sh -r commit -a "-f -b main"
# Supported scripts:
# - branch
# - commit
# - push
# - ver

### Options
# i: init application
# f: force init
# s: silent init
# r: script name to run
# a: args to script

SETTINGS_FILE=~/.gitbasher

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
ENDCOLOR="\e[0m"

if ((BASH_VERSINFO[0] < 4)); then 
    printf "Sorry, you need at least ${YELLOW}bash-4.0${ENDCOLOR} to run this script.\n
If your OS is debian-based, use:
    ${GREEN}apt-get install --only-upgrade bash${ENDCOLOR}\n
If your OS is mac, use:
    ${GREEN}brew install bash${ENDCOLOR}\n\n" 
    exit 1; 
fi

while getopts 'ifsr:a:' flag; do
    case "${flag}" in
        i) to_init="true";;
        f) force="true";;
        s) silent="true";;
        r) to_run="$OPTARG";;
        a) args="$OPTARG";;
    esac
done

SCRIPTS_DIR="scripts"
declare -A scripts=(
    ["branch"]="${SCRIPTS_DIR}/branch.sh"
    ["commit"]="${SCRIPTS_DIR}/commit.sh"
    ["push"]="${SCRIPTS_DIR}/push.sh"
    ["ver"]="${SCRIPTS_DIR}/ver.sh"
)

gitbasher_directory=$( cat ${SETTINGS_FILE} 2> /dev/null )

function prepare_path {
    eval echo "$1"
}

function init {
    if [[ -z "${silent}" ]]; then
        printf "Welcome to ${YELLOW}gitbasher${ENDCOLOR} init application!\n"
    fi
    if [[ -n "${gitbasher_directory}" ]] & [[ -z "$1"  ]]; then
        if [[ -z "${silent}" ]]; then
            echo -e "Scripts are already inited to folder: ${YELLOW}${gitbasher_directory}${ENDCOLOR}"
            echo "If you want to change it, use '-f' flag."
        fi
        return
    fi
    touch ${SETTINGS_FILE}
      
    while [ true ]; do
        read -p "Enter path to gitbasher repo (apply to all projects, default ../gitbasher): " -e gitbasher_directory

        if [ -z "${gitbasher_directory}" ]; then
            gitbasher_directory="../gitbasher"
        fi

        gitbasher_directory=${gitbasher_directory##*( )}
        if [ -d $( prepare_path $gitbasher_directory ) ]; then
            echo ${gitbasher_directory} > $( prepare_path $SETTINGS_FILE )
            echo -e "Set path to ${YELLOW}${gitbasher_directory}${ENDCOLOR}"
            return
        else
            echo -e "${RED}Directory ${YELLOW}${gitbasher_directory} ${RED}doesn't exist!${ENDCOLOR}"
        fi
    done
}

### Script logic here

# Run init if we want to init, provide -f if you want to force init
if [ -n "${to_init}" ]; then
    init $force
    exit
fi

# Run init if we haven't been inited
if [ -z "${gitbasher_directory}" ]; then
    init 'true'
fi

if [ -z "${to_run}" ]; then
    echo "You should provide script to run, use '-r' flag."
    exit
fi

script_name="${scripts[$to_run]}"
if [ -z "$script_name" ]; then
    echo -e "Unsupported script: ${YELLOW}${to_run}${ENDCOLOR}"
    exit
fi

utils=$( prepare_path "${gitbasher_directory}/${SCRIPTS_DIR}/utils.sh" )
script=$( prepare_path "${gitbasher_directory}/${script_name} ${args} -u ${utils}" )
$script
script_code=$?

if [ -f commitmsg ]; then 
    rm commitmsg
fi

exit $script_code