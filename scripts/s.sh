#!/bin/bash

GREEN="\e[32m"
YELLOW="\e[33m"
ENDCOLOR="\e[0m"
FOLDER="scripts"

USER_SETTINS_FILE="../.gitbasher"

declare -A scripts=(
    ["ver"]="${FOLDER}/ver.sh"
    ["changelog"]="${FOLDER}/changelog.sh"
    ["commit"]="${FOLDER}/commit.sh"
    ["ezcommit"]="${FOLDER}/commit_easy.sh"
    ["push"]="${FOLDER}/push.sh"
    ["release"]="${FOLDER}/release.sh"
)

### Get options
# i: init application
# f: force init
# r: script name to run
# a: args to script

GITBASHER=$( cat ${USER_SETTINS_FILE} )

function init {
    echo "********************************"
    echo -e "Welcome to ${YELLOW}gitbasher${ENDCOLOR} init application!"
    if [[ -n "${GITBASHER}" ]] & [[ -z "$1"  ]]; then
        echo -e "Scripts are already inited to folder: ${YELLOW}${GITBASHER}${ENDCOLOR}"
        echo "If you want to change it, use '-f' flag."
        return
    fi
    touch ${USER_SETTINS_FILE}
      
    while [ true ]; do
        read -e -p "Enter path to scripts repo (default ../gitbasher): " scripts_folder

        if [ -z $scripts_folder ]; then
            scripts_folder="../gitbasher"
        fi

        scripts_folder=${scripts_folder##*( )}
        if [ -d "$scripts_folder" ]; then
            export GITBASHER="${scripts_folder}"
            echo ${GITBASHER} > ${USER_SETTINS_FILE}
            echo -e "Set path to ${YELLOW}${GITBASHER}${ENDCOLOR}"
            return
        fi
    done
}

while getopts 'ifr:a:' flag; do
    case "${flag}" in
        f) force="true";;
        i) to_init="true";;
        r) to_run="$OPTARG";;
        a) args="$OPTARG";;
    esac
done

if [[ -n "${to_init}" ]]; then
    init $force
    exit
fi

if [[ "${GITBASHER}" = "" ]]; then
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

scr="${GITBASHER}/${script_name} ${args}"
$scr
