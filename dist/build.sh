#!/usr/bin/env bash

### Function returns contents of the final gitb script
# $1: original gitb script
function build {
    while read line; do
    if [[ "$line" =~ (\.|source)\s+.+ ]]; then
        file="$(echo $line | cut -d' ' -f2)"
        echo "$(cat $file)"
    else
        echo "$line"
    fi
    done < "$1"
}

contents=$(build $1)
echo "$contents" > $2
