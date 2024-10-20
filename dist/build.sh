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

contents=$(echo "#!/usr/bin/env bash" && build $1 | sed '/^[[:space:]]*#\{1,3\}[ !].*$/d' | sed '/^[[:space:]]*$/d')
echo "$contents" > $2
