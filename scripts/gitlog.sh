#!/usr/bin/env bash

### Script for providing some info from git log and movind HEAD
# Read README.md to get more information how to use it
# Use this script only with gitbasher


function gitlog_script {
    case "$1" in
        main|master)  main="true";;
        sep)          sep="true";;
        editor)       editor="true";;
    esac
}