#!/usr/bin/env bash

### Main script for running Gitbasher other scripts
# In file $SETTINGS_FILE is stored a path to a directory with gitbasher repo
# Using: s.sh -r <script_name> -a "<script_args>"
# Example: s.sh -r commit -a "-f -b main"
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

GITBASHER_DIR=$( cat ${SETTINGS_FILE} 2>/dev/null )

function prepare_path {
    eval echo "$1"
}

function init {
    if [[ -z "${silent}" ]]; then
        printf "Welcome to ${YELLOW}gitbasher${ENDCOLOR} init application!\n"
    fi
    if [[ -n "${GITBASHER_DIR}" ]] & [[ -z "$1"  ]]; then
        if [[ -z "${silent}" ]]; then
            echo -e "Scripts are already inited to folder: ${YELLOW}${GITBASHER_DIR}${ENDCOLOR}"
            echo "If you want to change it, use '-f' flag."
        fi
        return
    fi
    touch ${SETTINGS_FILE}
      
    while [ true ]; do
        read -p "Enter path to gitbasher repo (apply to all projects, default ../gitbasher): " -e GITBASHER_DIR

        if [ -z "${GITBASHER_DIR}" ]; then
            GITBASHER_DIR="../gitbasher"
        fi

        GITBASHER_DIR=${GITBASHER_DIR##*( )}
        if [ -d $( prepare_path $GITBASHER_DIR ) ]; then
            echo ${GITBASHER_DIR} > $( prepare_path $SETTINGS_FILE )
            echo -e "Set path to ${YELLOW}${GITBASHER_DIR}${ENDCOLOR}"
            return
        else
            echo -e "${RED}Directory ${YELLOW}${GITBASHER_DIR} ${RED}doesn't exist!${ENDCOLOR}"
        fi
    done
}

### Function logic here

# Run init if we want to init, provide -f if ypu want to force init
if [[ -n "${to_init}" ]]; then
    init $force
    exit
fi

# Run init if we haven't inited
if [[ -z "${GITBASHER_DIR}" ]]; then
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

utils=$( prepare_path "${GITBASHER_DIR}/${SCRIPTS_DIR}/utils.sh" )
scr=$( prepare_path "${GITBASHER_DIR}/${script_name} ${args} -u ${utils}" )
$scr
scr_code=$?

if [ -f commitmsg ]; then 
    rm commitmsg
fi

exit $scr_code
