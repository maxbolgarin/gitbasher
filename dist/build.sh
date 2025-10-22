#!/usr/bin/env bash

### Function returns contents of the final gitb script
# $1: original gitb script
function build {
    while IFS= read -r line; do
        # Match only lines that begin with optional whitespace then 'source' or '.' followed by a filepath
        if [[ "$line" =~ ^[[:space:]]*(source|\.)[[:space:]]+([^[:space:]]+) ]]; then
            file="${BASH_REMATCH[2]}"
            echo "$(cat "$file")"
        else
            echo "$line"
        fi
    done < "$1"
}

contents=$(echo "#!/usr/bin/env bash" && build $1 | sed '/^[[:space:]]*#\{1,3\}[ !].*$/d' | sed '/^[[:space:]]*$/d')
echo "$contents" > $2
