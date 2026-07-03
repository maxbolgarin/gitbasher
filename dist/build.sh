#!/usr/bin/env bash
set -euo pipefail

### Function returns contents of the final gitb script
# $1: original gitb script
function build {
    while IFS= read -r line; do
        # Match only lines that begin with optional whitespace then 'source' or '.' followed by a filepath
        if [[ "$line" =~ ^[[:space:]]*(source|\.)[[:space:]]+([^[:space:]]+) ]]; then
            file="${BASH_REMATCH[2]}"
            cat "$file"
        else
            echo "$line"
        fi
    done < "$1"
}

# Strip 1-3-hash comments and blank lines — EXCEPT inside regions fenced by
# `#### bundler-keep-begin` / `#### bundler-keep-end`. Those fence multi-line
# strings whose bodies are EMITTED CONTENT (hook templates, AI prompts,
# completion scripts): stripping inside them made the released binary emit
# different artifacts than a dev run. The markers themselves never reach the
# bundle. Alternation instead of an interval so any POSIX awk matches.
contents=$(echo "#!/usr/bin/env bash" && build "$1" | awk '
    /^[[:space:]]*#### bundler-keep-end/   { keep=0; next }
    /^[[:space:]]*#### bundler-keep-begin/ { keep=1; next }
    keep                                   { print; next }
    /^[[:space:]]*(###|##|#)[ !]/          { next }
    /^[[:space:]]*$/                       { next }
    { print }
')
echo "$contents" > "$2"

if [ -n "${3:-}" ]; then
    # Escape sed-replacement specials: an "&" in the version would splice the
    # matched text back in silently ("4.1.0&x" -> "4.1.0GITBASHER_...x").
    v="${3//\\/\\\\}"
    v="${v//&/\\&}"
    v="${v//\//\\/}"
    # BSD/macOS sed requires a backup extension after -i (use '' for none); GNU sed does not.
    if sed --version >/dev/null 2>&1; then
        sed -i "s/GITBASHER_VERSION=\"dev\"/GITBASHER_VERSION=\"$v\"/" "$2"
    else
        sed -i '' "s/GITBASHER_VERSION=\"dev\"/GITBASHER_VERSION=\"$v\"/" "$2"
    fi
fi
