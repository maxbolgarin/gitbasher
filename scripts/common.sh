#!/usr/bin/env bash


### Consts for colors to use inside 'sed'. Emptied alongside the terminal
### colors in init.sh when NO_COLOR is set or stdout is not a terminal —
### they only ever appear on sed's replacement side, so empty is safe.
if [ -n "$NO_COLOR" ] || [ ! -t 1 ]; then
    RED_ES=""
    GREEN_ES=""
    YELLOW_ES=""
    BLUE_ES=""
    PURPLE_ES=""
    CYAN_ES=""
    GRAY_ES=""
    ENDCOLOR_ES=""
else
    RED_ES="\x1b[31m"
    GREEN_ES="\x1b[32m"
    YELLOW_ES="\x1b[33m"
    BLUE_ES="\x1b[34m"
    PURPLE_ES="\x1b[35m"
    CYAN_ES="\x1b[36m"
    GRAY_ES="\x1b[37m"
    ENDCOLOR_ES="\x1b[0m"
fi


### ===== PORTABLE ASSOCIATIVE-ARRAY SHIM (bash 3.2+) =====
### Bash 3.2 — the system bash on macOS — has no associative arrays, no
### ${var,,} case-folding, and no mapfile. These helpers emulate a string-keyed
### map/set on top of plain scalar variables so gitbasher runs everywhere
### without a bash 4 dependency.
###
### Keys may contain any bytes; they are hex-encoded into safe variable-name
### suffixes (_gmap_enc). Values are stored verbatim with `printf -v`, never
### through `eval`, so arbitrary value content — newlines, quotes, $(...) — is
### stored as inert data and never executed. Insertion order is preserved in a
### newline-delimited key list, so keys must not contain literal newlines (true
### at every call site, which reads keys with `read -r`).
###
### API:
###   gmap_clear NAME            reset map (call before first use to drop stale state)
###   gmap_set   NAME KEY VALUE  set / overwrite
###   gmap_get   NAME KEY        print value ("" when absent)
###   gmap_has   NAME KEY        return 0 when key present, 1 otherwise
###   gmap_inc   NAME KEY        value := (value or 0) + 1
###   gmap_keys  NAME            print keys, one per line, in insertion order
###   gmap_size  NAME            print number of keys
###   gset_add / gset_has        set wrappers (value is always 1)

### Hex-encode a string into [0-9a-f]* for use inside a variable name.
### Byte-exact and locale-independent: `local LC_ALL=C` forces byte semantics
### for the slice/length operators, and `& 0xff` masks any sign extension so
### every byte yields exactly two hex digits (self-delimiting, collision-free).
### Result is returned in _gmap_enc_out (no subshell, for speed in tight loops).
# $1: string to encode
function _gmap_enc {
    local LC_ALL=C
    local _s="$1" _out="" _i _n
    for (( _i = 0; _i < ${#_s}; _i++ )); do
        printf -v _n '%d' "'${_s:_i:1}"
        printf -v _n '%02x' "$(( _n & 0xff ))"
        _out="$_out$_n"
    done
    _gmap_enc_out="$_out"
}

### Remove every entry of a map and its key list (also used to initialize a
### map and drop any stale state left by an earlier call with the same name).
# $1: map name
function gmap_clear {
    local _hm _k _hk
    _gmap_enc "$1"; _hm="$_gmap_enc_out"
    while IFS= read -r _k; do
        [ -z "$_k" ] && continue
        _gmap_enc "$_k"; _hk="$_gmap_enc_out"
        unset "_gmapH_${_hm}_${_hk}"
    done < <(gmap_keys "$1")
    unset "_gmapKL_${_hm}"
}

### Set (or overwrite) the value for a key.
# $1: map name  $2: key  $3: value
function gmap_set {
    local _hm _hk _vn _kln _exists _cur
    _gmap_enc "$1"; _hm="$_gmap_enc_out"
    _gmap_enc "$2"; _hk="$_gmap_enc_out"
    _vn="_gmapH_${_hm}_${_hk}"
    _kln="_gmapKL_${_hm}"
    eval "_exists=\${${_vn}+x}"
    if [ -z "$_exists" ]; then
        eval "_cur=\${${_kln}-}"
        printf -v "$_kln" '%s%s\n' "$_cur" "$2"
    fi
    printf -v "$_vn" '%s' "$3"
}

### Print the value stored for a key, or nothing when the key is absent.
# $1: map name  $2: key
function gmap_get {
    local _hm _hk _vn
    _gmap_enc "$1"; _hm="$_gmap_enc_out"
    _gmap_enc "$2"; _hk="$_gmap_enc_out"
    _vn="_gmapH_${_hm}_${_hk}"
    eval "printf '%s' \"\${${_vn}-}\""
}

### Return 0 when the key exists in the map (even with an empty value).
# $1: map name  $2: key
function gmap_has {
    local _hm _hk _vn _exists
    _gmap_enc "$1"; _hm="$_gmap_enc_out"
    _gmap_enc "$2"; _hk="$_gmap_enc_out"
    _vn="_gmapH_${_hm}_${_hk}"
    eval "_exists=\${${_vn}+x}"
    [ -n "$_exists" ]
}

### Increment the integer value of a key (absent key counts as 0). Done without
### a subshell so it stays cheap inside per-file loops.
# $1: map name  $2: key
function gmap_inc {
    local _hm _hk _vn _kln _exists _cur
    _gmap_enc "$1"; _hm="$_gmap_enc_out"
    _gmap_enc "$2"; _hk="$_gmap_enc_out"
    _vn="_gmapH_${_hm}_${_hk}"
    _kln="_gmapKL_${_hm}"
    eval "_exists=\${${_vn}+x}"
    if [ -z "$_exists" ]; then
        eval "_cur=\${${_kln}-}"
        printf -v "$_kln" '%s%s\n' "$_cur" "$2"
        _cur=0
    else
        eval "_cur=\${${_vn}}"
    fi
    printf -v "$_vn" '%s' "$(( _cur + 1 ))"
}

### Print the map's keys, one per line, in insertion order.
# $1: map name
function gmap_keys {
    local _hm
    _gmap_enc "$1"; _hm="$_gmap_enc_out"
    eval "printf '%s' \"\${_gmapKL_${_hm}-}\""
}

### Print the number of keys in the map. Always exits 0 (grep -c returns 1 on
### an empty map, which would trip `set -e` at the call site).
# $1: map name
function gmap_size {
    local _n
    _n=$(gmap_keys "$1" | grep -c .)
    printf '%s' "$_n"
}

### Set membership helpers (a set is just a map whose values are all 1).
function gset_add { gmap_set "$1" "$2" 1; }
function gset_has { gmap_has "$1" "$2"; }


### ===== CASE-FOLDING HELPERS (bash 3.2+) =====
### Replacements for bash 4's ${var,,} / ${var^^} expansions.

### Print the argument lowercased.
# $1: string
function to_lower {
    printf '%s' "$1" | LC_ALL=C tr '[:upper:]' '[:lower:]'
}

### Print the argument uppercased.
# $1: string
function to_upper {
    printf '%s' "$1" | LC_ALL=C tr '[:lower:]' '[:upper:]'
}


### ===== UX STYLE GUIDE =====
### All user-facing text in gitbasher follows these rules. Reviewers and future
### contributors: please keep new strings consistent with this guide.
###
###   Errors    : ${RED}✗ Cannot <action>.${ENDCOLOR}              (period, no '!')
###   Success   : ${GREEN}✓ <Past-tense verb> <object>${ENDCOLOR}   (no 'Successfully')
###   Warnings  : ${YELLOW}⚠  <statement>.${ENDCOLOR}              (red ⚠ if destructive)
###   Tips      : ${CYAN}💡 <Tip text>${ENDCOLOR}
###   Steps     : ${YELLOW}Step N.${ENDCOLOR} <Imperative instruction>
###   Confirm   : routine "(y/n)?", destructive prefixed with red ⚠ line
###   Menu exit : "0. Exit" (or "00. Exit" when paginated/≥10 items)
###   Invalid   : ${RED}✗ Invalid choice.${ENDCOLOR}
###
### Free-text input uses `read -p`, single-key choices use `read -n 1 -s`.
### Color invariants: RED=error, GREEN=success/example, YELLOW=prompt/warning/key,
### BLUE=description/context, CYAN=tip, BOLD=mode/keyword.


### ===== INPUT SANITIZATION FRAMEWORK =====
### These functions provide security validation for all user inputs

### Function to sanitize git-safe names (branches, tags, etc.)
# $1: input string
# Returns: sanitized string safe for git operations
# Sets: sanitized_git_name global variable
function sanitize_git_name {
    local input="$1"
    sanitized_git_name=""
    
    if [ -z "$input" ]; then
        return 1
    fi
    
    # Remove dangerous characters, keep git-safe ones
    # Allow: letters, numbers, dash, underscore, dot, slash
    local cleaned=$(echo "$input" | sed 's/[^a-zA-Z0-9._/-]//g')
    
    # Remove leading/trailing dots and slashes (git restrictions)
    cleaned=$(echo "$cleaned" | sed 's/^[./]*//;s/[./]*$//')
    
    # Prevent git-unsafe patterns
    if [[ "$cleaned" =~ \.\. ]] || [[ "$cleaned" =~ ^- ]] || [[ "$cleaned" =~ -$ ]] || \
       [[ "$cleaned" =~ ^@ ]] || [[ "$cleaned" == "HEAD" ]] || [[ "$cleaned" =~ ^refs/ ]]; then
        return 1
    fi
    
    # Ensure minimum length
    if [ ${#cleaned} -lt 1 ] || [ ${#cleaned} -gt 255 ]; then
        return 1
    fi
    
    sanitized_git_name="$cleaned"
    return 0
}

### Function to sanitize file paths and patterns for git add
# $1: input string
# Returns: sanitized string safe for file operations
# Sets: sanitized_file_path global variable
function sanitize_file_path {
    local input="$1"
    sanitized_file_path=""
    
    if [ -z "$input" ]; then
        return 1
    fi
    
    # Remove null bytes and control characters (except tab and newline for multiline patterns)
    local cleaned=$(echo "$input" | tr -d '\000-\010\013\014\016-\037\177')
    
    # Remove dangerous sequences
    cleaned=$(echo "$cleaned" | sed 's/\.\.\///g')  # Remove ../
    cleaned=$(echo "$cleaned" | sed 's/;[[:space:]]*rm[[:space:]]*/; /g')  # Remove rm commands after semicolon
    cleaned=$(echo "$cleaned" | sed 's/&&[[:space:]]*rm[[:space:]]*/&& /g')  # Remove rm commands after &&
    cleaned=$(echo "$cleaned" | sed 's/|[[:space:]]*rm[[:space:]]*/| /g')  # Remove rm commands after pipe
    cleaned=$(echo "$cleaned" | sed 's/[[:space:]]rm[[:space:]]*/ /g')  # Remove rm commands with spaces around
    cleaned=$(echo "$cleaned" | sed 's/^rm[[:space:]]*//g')  # Remove rm at start
    cleaned=$(echo "$cleaned" | sed 's/[[:space:]]rm$//g')  # Remove rm at end
    
    # Limit length
    if [ ${#cleaned} -gt 1000 ]; then
        return 1
    fi
    
    sanitized_file_path="$cleaned"
    return 0
}

### Function to sanitize commit messages
# $1: input string
# Returns: sanitized commit message
# Sets: sanitized_commit_message global variable
function sanitize_commit_message {
    local input="$1"
    sanitized_commit_message=""
    
    if [ -z "$input" ]; then
        return 1
    fi
    
    # Remove null bytes and control characters except newlines and tabs
    local cleaned=$(echo "$input" | tr -d '\000-\010\013\014\016-\037\177')
    
    # Trim leading/trailing whitespace
    cleaned=$(echo "$cleaned" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    
    # Validate length (typical git limit is ~50-72 chars for subject, longer for body)
    if [ ${#cleaned} -lt 1 ] || [ ${#cleaned} -gt 2000 ]; then
        return 1
    fi
    
    sanitized_commit_message="$cleaned"
    return 0
}

### Function to sanitize command names (like editor)
# $1: input string
# Returns: sanitized command name
# Sets: sanitized_command global variable
function sanitize_command {
    local input="$1"
    sanitized_command=""
    
    if [ -z "$input" ]; then
        return 1
    fi
    
    # Check for dangerous patterns BEFORE cleaning (since cleaning removes them)
    if [[ "$input" =~ \.\. ]] || [[ "$input" == *";"* ]] || [[ "$input" == *"|"* ]] || \
       [[ "$input" == *"&"* ]] || [[ "$input" == *"\$"* ]] || [[ "$input" == *"\`"* ]]; then
        return 1
    fi
    
    # Only allow alphanumeric, dash, underscore, and slash for paths
    local cleaned=$(echo "$input" | sed 's/[^a-zA-Z0-9._/-]//g')
    
    # Validate length and format
    if [ ${#cleaned} -lt 1 ] || [ ${#cleaned} -gt 100 ] || [[ "$cleaned" =~ ^- ]]; then
        return 1
    fi
    
    sanitized_command="$cleaned"
    return 0
}

### Function to sanitize general text input
# $1: input string
# $2: max length (optional, default 500)
# Returns: sanitized text
# Sets: sanitized_text global variable
function sanitize_text_input {
    local input="$1"
    local max_length="${2:-500}"
    sanitized_text=""
    
    if [ -z "$input" ]; then
        return 1
    fi
    
    # Remove null bytes and most control characters, keep printable ones
    local cleaned=$(echo "$input" | tr -d '\000-\010\013\014\016-\037\177')
    
    # Trim whitespace
    cleaned=$(echo "$cleaned" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    
    # Validate length
    if [ ${#cleaned} -lt 1 ] || [ ${#cleaned} -gt "$max_length" ]; then
        return 1
    fi
    
    sanitized_text="$cleaned"
    return 0
}

### Function to validate numeric input
# $1: input string
# $2: min value (optional)
# $3: max value (optional)
# Returns: 0 if valid number, 1 if invalid
# Sets: validated_number global variable
function validate_numeric_input {
    local input="$1"
    local min_val="$2"
    local max_val="$3"
    validated_number=""
    
    if [ -z "$input" ]; then
        return 1
    fi
    
    # Check if it's a valid positive integer
    if ! [[ "$input" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    
    # Convert to number for range checking
    local num=$((input))
    
    # Check minimum value
    if [ -n "$min_val" ] && [ "$num" -lt "$min_val" ]; then
        return 1
    fi
    
    # Check maximum value
    if [ -n "$max_val" ] && [ "$num" -gt "$max_val" ]; then
        return 1
    fi
    
    validated_number="$num"
    return 0
}

### Function to validate email format
# $1: email string
# Returns: 0 if valid email format, 1 if invalid
# Sets: validated_email global variable
function validate_email {
    local input="$1"
    validated_email=""
    
    if [ -z "$input" ]; then
        return 1
    fi
    
    # Basic email regex validation
    if [[ "$input" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        # Additional length check
        if [ ${#input} -le 254 ]; then
            validated_email="$input"
            return 0
        fi
    fi
    
    return 1
}

### Function to validate scope list
# $1: scope list string
# Returns: 0 if valid, 1 if invalid
# Sets: validated_scopes global variable
function validate_scope_list {
    local input="$1"
    validated_scopes=""
    
    if [ -z "$input" ]; then
        return 1
    fi
    
    # Check format: letters and spaces only, max 9 scopes
    if [[ "$input" =~ ^([a-zA-Z]+ ){0,8}([a-zA-Z]+)$ ]]; then
        # Count words
        local word_count=$(echo "$input" | wc -w)
        if [ "$word_count" -le 9 ] && [ "$word_count" -ge 1 ]; then
            validated_scopes="$input"
            return 0
        fi
    fi
    
    return 1
}

### Function to sanitize choice input (y/n/numbers/etc.)
# $1: input string
# $2: allowed pattern (optional, default allows y/n/0-9/=)
# Returns: sanitized choice
# Sets: sanitized_choice global variable
function sanitize_choice_input {
    local input="$1"
    local pattern="${2:-^[yn0-9=]$}"
    sanitized_choice=""

    if [ -z "$input" ]; then
        return 1
    fi

    # Normalize key (handles uppercase and Russian keyboard layout)
    normalize_key "$input"
    local cleaned="$normalized_key"

    # Validate against pattern
    if [[ "$cleaned" =~ $pattern ]]; then
        sanitized_choice="$cleaned"
        return 0
    fi

    return 1
}

### Function to display sanitization error with helpful message
# $1: input type name
# $2: error message
function show_sanitization_error {
    local input_type="$1"
    local error_msg="$2"
    
    echo -e "${RED}✗ Invalid ${input_type} input.${ENDCOLOR}" >&2
    if [ -n "$error_msg" ]; then
        echo -e "${YELLOW}$error_msg${ENDCOLOR}" >&2
    fi
    echo -e "${YELLOW}Please try again with valid input.${ENDCOLOR}" >&2
}

### ===== END INPUT SANITIZATION FRAMEWORK =====


### ===== HELP TABLE FORMATTERS =====
### Used by every per-command help block (`gitb <cmd> help`) so the screen is
### visually consistent with the top-level `print_help` in base.sh: a fixed-
### width "mode (aliases)" column rendered via printf, then the description.
### Avoids depending on `column -t`, which would split rows on whatever
### separator we chose — that historically broke any description containing
### the separator character (e.g. `ORIG_HEAD` when `_` was the separator).

### Print the column header for a help table.
# $1: column width for the "mode (aliases)" column, in characters. The same
#     value must be passed to every print_help_row call so the columns line up.
function print_help_header {
    local pad="$1"
    printf "  ${YELLOW}%-*s${ENDCOLOR}  ${BLUE}%s${ENDCOLOR}\n" "$pad" "Mode" "Description"
}

### Print one row of a help table.
# $1: same column width passed to print_help_header (and every other row).
# $2: mode name (e.g. "annotated", literal "<empty>" for the no-arg case).
# $3: comma-separated alias list (e.g. "a, an"); empty string when the mode
#     has no aliases — in that case the parens are omitted entirely.
# $4: description text. May contain color escapes — uses %b so backslash
#     escapes (\e, \033) in the expanded ${BLUE}/${YELLOW}/etc. variables get
#     interpreted, matching the behavior of `echo -e` used elsewhere.
function print_help_row {
    local pad="$1"
    local mode="$2"
    local aliases="$3"
    local desc="$4"
    local label
    if [ -n "$aliases" ]; then
        label="${mode} (${aliases})"
    else
        label="${mode}"
    fi
    printf "  ${BOLD}%-*s${NORMAL}  %b\n" "$pad" "$label" "$desc"
}

### ===== END HELP TABLE FORMATTERS =====


### ===== KEYBOARD INPUT HELPERS =====
### Handle case-insensitive input and alternative keyboard layouts (e.g. Russian)

### bash 3.2's `read -t` rejects fractional timeouts (sub-second timeouts are
### bash 4+). Poll at 0.01s on bash 4+, and at 1s on bash 3.2 for the
### escape-sequence drain in read_key — that loop breaks as soon as the
### sequence terminator arrives, so only a lone Esc waits the full second.
if ((BASH_VERSINFO[0] >= 4)); then GITB_READ_POLL="0.01"; else GITB_READ_POLL="1"; fi

### Best-effort: discard any buffered terminal input without blocking. bash 3.2
### has no non-blocking sub-second read, so it skips draining there rather than
### stalling the UI for a full second after each keystroke.
function drain_pending_input {
    ((BASH_VERSINFO[0] < 4)) && return 0
    local _d
    while IFS= read -r -s -n 1 -t 0.01 _d 2>/dev/null; do :; done
}

### Map of Russian keyboard layout to Latin equivalents (same physical keys)
# Russian: й ц у к е н г ш щ з х ъ ф ы в а п р о л д ж э я ч с м и т ь б ю
# Latin:   q w e r t y u i o p [ ] a s d f g h j k l ; ' z x c v b n m , .

### Function to normalize a key press to its Latin lowercase equivalent
# Handles: uppercase (caps lock), Russian keyboard layout
# $1: the key pressed
# Returns: sets normalized_key global variable
function normalize_key {
    local key="$1"
    normalized_key="$key"

    # Handle empty input (Enter key)
    if [ -z "$key" ]; then
        normalized_key=""
        return
    fi

    # Convert ASCII uppercase to lowercase (tr only handles ASCII)
    normalized_key=$(echo "$key" | tr '[:upper:]' '[:lower:]')

    # Map Russian layout (both lowercase and uppercase) to Latin (same physical key positions)
    case "$normalized_key" in
        "й"|"Й") normalized_key="q" ;;
        "ц"|"Ц") normalized_key="w" ;;
        "у"|"У") normalized_key="e" ;;
        "к"|"К") normalized_key="r" ;;
        "е"|"Е") normalized_key="t" ;;
        "н"|"Н") normalized_key="y" ;;
        "г"|"Г") normalized_key="u" ;;
        "ш"|"Ш") normalized_key="i" ;;
        "щ"|"Щ") normalized_key="o" ;;
        "з"|"З") normalized_key="p" ;;
        "х"|"Х") normalized_key="[" ;;
        "ъ"|"Ъ") normalized_key="]" ;;
        "ф"|"Ф") normalized_key="a" ;;
        "ы"|"Ы") normalized_key="s" ;;
        "в"|"В") normalized_key="d" ;;
        "а"|"А") normalized_key="f" ;;
        "п"|"П") normalized_key="g" ;;
        "р"|"Р") normalized_key="h" ;;
        "о"|"О") normalized_key="j" ;;
        "л"|"Л") normalized_key="k" ;;
        "д"|"Д") normalized_key="l" ;;
        "я"|"Я") normalized_key="z" ;;
        "ч"|"Ч") normalized_key="x" ;;
        "с"|"С") normalized_key="c" ;;
        "м"|"М") normalized_key="v" ;;
        "и"|"И") normalized_key="b" ;;
        "т"|"Т") normalized_key="n" ;;
        "ь"|"Ь") normalized_key="m" ;;
    esac
}

### Check if the key press means "yes"
# Accepts: y, Y, Russian н/Н, Enter key
# $1: the key pressed
# Returns: 0 if yes, 1 if not
function is_yes {
    normalize_key "$1"
    if [ "$normalized_key" == "y" ] || [ -z "$1" ]; then
        return 0
    fi
    return 1
}

### Check if the key press means "no"
# Accepts: n, N, Russian т/Т
# $1: the key pressed
# Returns: 0 if no, 1 if not
function is_no {
    normalize_key "$1"
    if [ "$normalized_key" == "n" ]; then
        return 0
    fi
    return 1
}

### EOF guard for interactive read loops: closed/exhausted stdin means the
# prompt can never be answered — abort instead of spinning or auto-picking.
# Usage: read -n 1 -s choice || prompt_aborted
function prompt_aborted {
    echo
    echo -e "${YELLOW}Input closed — aborting.${ENDCOLOR}"
    exit 1
}

### Destructive-action confirmation: only an explicit "yes" key proceeds.
# Unlike is_yes-based prompts (where Enter means yes), Enter, Esc, EOF and
# any other key DECLINE — a destructive prompt must never auto-confirm on
# closed or exhausted stdin. Echoes the effective answer for transcripts.
# Returns: 0 on explicit yes, 1 on decline, 2 on EOF/closed stdin
function confirm_destructive {
    local _cd_key=""
    if ! read_key _cd_key; then
        printf "n\n"
        return 2
    fi
    normalize_key "$_cd_key"
    if [ -n "$_cd_key" ] && [ "$normalized_key" == "y" ]; then
        printf "y\n"
        return 0
    fi
    printf "n\n"
    return 1
}

### Returns 0 (true) when HEAD points at a branch; 1 (false) when detached.
function on_branch {
    git symbolic-ref --quiet HEAD >/dev/null 2>&1
}

### Warn the user when the working tree is in detached-HEAD state and prompt
### before proceeding. Defaults to NO (safer) on Enter.
# $1: short verb describing the operation (e.g. "commit", "push")
function warn_if_detached_head {
    on_branch && return 0
    local _action="${1:-this operation}"
    echo
    echo -e "${YELLOW}⚠  You are in detached HEAD state.${ENDCOLOR}"
    echo "Any new commits will not be on a branch and may be reclaimed by git's garbage collector."
    read -n 1 -p "Continue ${_action} anyway? (y/N) " _ans
    echo
    case "$_ans" in
        y|Y) return 0 ;;
        *) exit 1 ;;
    esac
}

### Read a single key press, properly handling multi-byte UTF-8 characters
# Works correctly in silent mode even with non-Latin keyboard layouts (e.g. Russian)
# In silent mode (-s), read -n 1 may return a single byte instead of a full character.
# This function detects UTF-8 leading bytes and reads the remaining bytes to get the complete character.
# $1: variable name to store the key (default: REPLY)
# $2: optional prompt text to display before reading
function read_key {
    local _var="${1:-REPLY}"
    local _prompt="$2"
    local _key=""
    local _rc=0

    if [ -n "$_prompt" ]; then
        printf '%s' "$_prompt"
    fi

    # A failed first read means EOF/closed stdin — callers that treat an
    # empty key as "accept" must check the return code (Enter also yields
    # an empty key, but with rc 0).
    IFS= read -r -s -n 1 _key || _rc=1

    if [ -n "$_key" ]; then
        if [ "$_key" = $'\e' ]; then
            local _esc_rest=""
            local _esc_part=""

            # Arrow keys and similar controls arrive as escape sequences. Drain the
            # remaining bytes now so they are not echoed as invalid input later.
            while IFS= read -r -s -n 1 -t "$GITB_READ_POLL" _esc_part; do
                _esc_rest="${_esc_rest}${_esc_part}"
                if [[ "$_esc_rest" =~ ^(\[|O).*[@-~]$ ]] || [ ${#_esc_rest} -ge 8 ]; then
                    break
                fi
            done
            _key="${_key}${_esc_rest}"
        fi

        # Check if read gave us a single byte (possible partial UTF-8)
        local _byte_len
        _byte_len=$(printf '%s' "$_key" | wc -c | tr -d ' ')

        if [ "$_byte_len" -eq 1 ]; then
            # Got a single byte - check if it's a UTF-8 leading byte that needs more bytes
            local _ord
            _ord=$(LC_CTYPE=C printf '%d' "'$_key" 2>/dev/null) || _ord=0
            # bash 3.2 prints high bytes as signed chars (0xD0 -> -48), so
            # the UTF-8 lead-byte ranges below never matched and multi-byte
            # keys (Russian layout) collapsed to their first byte.
            if [ "$_ord" -lt 0 ]; then
                _ord=$((_ord + 256))
            fi

            local _extra=0
            if (( _ord >= 192 && _ord < 224 )); then
                _extra=1  # 2-byte char (Cyrillic, Latin Extended, etc.)
            elif (( _ord >= 224 && _ord < 240 )); then
                _extra=2  # 3-byte char (CJK, etc.)
            elif (( _ord >= 240 )); then
                _extra=3  # 4-byte char (emoji, etc.)
            fi

            if (( _extra > 0 )); then
                local _rest
                IFS= read -r -s -n "$_extra" _rest
                _key="${_key}${_rest}"
            fi
        fi
    fi

    printf -v "$_var" '%s' "$_key"
    return $_rc
}

### Read editable text input, allowing Esc to cancel by submitting empty input.
# $1: variable name to store input (default: REPLY)
# $2: optional prompt text
# $3: optional initial value for readline
function read_editable_input {
    local _var="${1:-REPLY}"
    local _prompt="${2:-}"

    # Readline normally treats Esc as a prefix key. For GitBasher prompts, a
    # plain Esc should behave like "clear this prompt and submit empty".
    # `bind` is a no-op in non-interactive shells unless emacs mode is on.
    set -o emacs 2>/dev/null
    bind '"\e": "\C-a\C-k\C-m"' 2>/dev/null || true

    if [ $# -ge 3 ]; then
        if ((BASH_VERSINFO[0] >= 4)); then
            # bash 4+: preload the editable buffer so the user edits in place.
            if ! IFS= read -r -e -p "$_prompt" -i "$3" "$_var"; then
                printf -v "$_var" ''
                return 1
            fi
        else
            # bash 3.2 has no `read -i` to preload readline. Degrade gracefully:
            # show the current value and keep it when the user submits an empty
            # line (retype the line to change it). A FAILED read (EOF) must not
            # count as accepting the default — return empty instead.
            local _reply _hint=""
            [ -n "$3" ] && _hint="[$3] "
            if ! IFS= read -r -e -p "${_prompt}${_hint}" _reply; then
                printf -v "$_var" ''
                return 1
            fi
            if [ -z "$_reply" ]; then
                printf -v "$_var" '%s' "$3"
            else
                printf -v "$_var" '%s' "$_reply"
            fi
        fi
    else
        if ! IFS= read -r -e -p "$_prompt" "$_var"; then
            printf -v "$_var" ''
            return 1
        fi
    fi
}

### Read silent (no-echo) input, allowing Esc to cancel by submitting empty.
# Used for secret prompts (API keys) where readline (`read -e`) cannot be
# combined with silent mode. Backspace deletes the last typed byte.
# $1: variable name to store input (default: REPLY)
# $2: optional prompt text
function read_silent_input {
    local _var="${1:-REPLY}"
    local _prompt="${2:-}"
    local _input=""
    local _char

    if [ -n "$_prompt" ]; then
        printf '%s' "$_prompt"
    fi

    while IFS= read -r -s -n 1 _char; do
        # `read -n 1` returns empty when Enter is pressed
        if [ -z "$_char" ]; then
            break
        fi
        # ESC: drain any follow-on bytes (arrow keys etc.) and cancel
        if [ "$_char" = $'\e' ]; then
            _input=""
            drain_pending_input
            break
        fi
        # Backspace / DEL
        if [ "$_char" = $'\x7f' ] || [ "$_char" = $'\b' ]; then
            [ -n "$_input" ] && _input="${_input%?}"
            continue
        fi
        _input+="$_char"
    done
    echo

    printf -v "$_var" '%s' "$_input"
}

### ===== END KEYBOARD INPUT HELPERS =====


### Function should be used in default case in script mode selection
# $1: script name
# $2: entered mode
function wrong_mode {
    if [ -n "$2" ]; then
        echo -e "${RED}✗ Unknown mode ${YELLOW}$2${RED} for ${YELLOW}gitb $1${RED}.${ENDCOLOR}"
        echo -e "Run ${GREEN}gitb $1 help${ENDCOLOR} to see available modes."
        exit 1
    fi
}


### Detect transient network/connectivity failures in git output that are worth
### retrying (VPN flapping, DNS hiccups, SSH timeouts, dropped connections).
### Authentication, permission and "[rejected]" errors are NOT network errors and
### must never be retried here.
# $1: combined stdout+stderr of a failed git network command
# Returns: 0 (true) if the output looks like a transient network failure
function is_network_error {
    local output="$1"
    echo "$output" | grep -qiE \
        "Could not read from remote repository|Could not resolve host|Connection timed out|Operation timed out|connect to host|Connection refused|Connection reset|Network is unreachable|kex_exchange_identification|remote end hung up unexpectedly|unable to access|Failed to connect|early EOF|RPC failed|timed out|ssh: connect|Temporary failure in name resolution|[Bb]roken pipe|[Rr]ecv failure|[Ss]end failure|TLS connection|SSL connection|no route to host"
}


### Run a git (or any) command, streaming its native --progress output live to
### the terminal when interactive, while still capturing combined stdout+stderr
### and the exit code for downstream parsing. Falls back to silent capture when
### there is no TTY (tests/CI) or mktemp fails; in that fallback --progress is
### stripped from the args so it can't pollute the captured output (matches the
### fetch() helper's existing behavior).
# $1: name of the variable to receive captured output
# $2: name of the variable to receive the exit code
# $3: name of the variable to receive "true" when progress was streamed live
# $4..: the command and its args (pass --progress; honored only when streaming)
# Results are written to the CALLER-named vars; those names must not start with
# "__" (they would collide with this function's locals).
function stream_or_capture_git {
    local __out_var="$1" __code_var="$2" __shown_var="$3"; shift 3
    local __output="" __code=0 __shown=""
    if [ -t 1 ] && [ -t 2 ]; then
        local __tmp
        __tmp=$(mktemp 2>/dev/null)
        if [ -n "$__tmp" ]; then
            # `if pipeline` keeps errexit from aborting on a failed push/fetch,
            # while PIPESTATUS still reflects git's (not tee's) exit code.
            if "$@" 2>&1 | tee "$__tmp"; then __code=0; else __code=${PIPESTATUS[0]}; fi
            __output=$(cat "$__tmp")
            rm -f "$__tmp"
            __shown="true"
        fi
    fi
    if [ -z "$__shown" ]; then
        local __arg __args=()
        for __arg in "$@"; do
            [ "$__arg" = "--progress" ] || __args+=("$__arg")
        done
        # Capture without letting a non-zero exit trip errexit before we read it.
        if __output=$("${__args[@]}" 2>&1); then __code=0; else __code=$?; fi
    fi
    printf -v "$__out_var" '%s' "$__output"
    printf -v "$__code_var" '%s' "$__code"
    printf -v "$__shown_var" '%s' "$__shown"
}


### Function echoes (true return) url to current user's repo (remote)
# Return: url to repo
function get_repo {
    local remote_name=${origin_name:-origin}
    local repo
    repo=$(git config --get "remote.${remote_name}.url")
    if [ -z "$repo" ]; then
        echo ""
        return
    fi

    # Convert SSH-style URLs (git@host:user/repo) into https URLs by replacing
    # the first ':' after the host with '/'. This is more robust than
    # whitelisting specific TLDs and supports any host (github.com, gitlab.com,
    # self-hosted servers with .ai/.uk/.de/etc).
    if [[ "$repo" =~ ^git@([^:]+):(.*)$ ]]; then
        repo="https://${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    elif [[ "$repo" =~ ^ssh://git@([^/]+)/(.*)$ ]]; then
        repo="https://${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    fi

    # Strip .git suffix if present
    repo="${repo%.git}"
    echo "$repo"
}


### Function echoes (true return) name of current repo
function get_repo_name {
    repo=$(get_repo)
    echo "${repo##*/}"
}


### Detect remote host kind from a repo URL
# $1: repo URL (optional, defaults to current repo)
# Return: "github", "gitlab", "bitbucket" or empty string
function get_repo_host {
    local repo=${1:-$(get_repo)}
    if [[ "$repo" == *"github"* ]]; then
        echo "github"
    elif [[ "$repo" == *"gitlab"* ]]; then
        echo "gitlab"
    elif [[ "$repo" == *"bitbucket"* ]]; then
        echo "bitbucket"
    else
        echo ""
    fi
}


### URL to a branch in the remote repo
# $1: branch name, $2: repo URL (optional)
function get_branch_url {
    local branch=$1
    local repo=${2:-$(get_repo)}
    case "$(get_repo_host "$repo")" in
        github)    echo "${repo}/tree/${branch}";;
        gitlab)    echo "${repo}/-/tree/${branch}";;
        bitbucket) echo "${repo}/branch/${branch}";;
    esac
}


### URL to a commit in the remote repo
# $1: commit hash, $2: repo URL (optional)
function get_commit_url {
    local hash=$1
    local repo=${2:-$(get_repo)}
    case "$(get_repo_host "$repo")" in
        github)    echo "${repo}/commit/${hash}";;
        gitlab)    echo "${repo}/-/commit/${hash}";;
        bitbucket) echo "${repo}/commits/${hash}";;
    esac
}


### URL to open a new pull/merge request from a branch
# $1: base branch, $2: source branch, $3: repo URL (optional)
function get_new_pr_url {
    local base=$1
    local branch=$2
    local repo=${3:-$(get_repo)}
    case "$(get_repo_host "$repo")" in
        github)    echo "${repo}/compare/${base}...${branch}?expand=1";;
        gitlab)    echo "${repo}/-/merge_requests/new?merge_request%5Bsource_branch%5D=${branch}&merge_request%5Btarget_branch%5D=${base}";;
        bitbucket) echo "${repo}/pull-requests/new?source=${branch}&dest=${base}";;
    esac
}


### URL to the list of pull/merge requests
# $1: repo URL (optional)
function get_prs_url {
    local repo=${1:-$(get_repo)}
    case "$(get_repo_host "$repo")" in
        github)    echo "${repo}/pulls";;
        gitlab)    echo "${repo}/-/merge_requests";;
        bitbucket) echo "${repo}/pull-requests";;
    esac
}


### URL to CI runs filtered by branch (or all runs when branch is empty)
# $1: branch name (optional), $2: repo URL (optional)
function get_ci_url {
    local branch=$1
    local repo=${2:-$(get_repo)}
    case "$(get_repo_host "$repo")" in
        github)
            if [ -n "$branch" ]; then
                echo "${repo}/actions?query=branch%3A${branch}"
            else
                echo "${repo}/actions"
            fi;;
        gitlab)
            if [ -n "$branch" ]; then
                echo "${repo}/-/pipelines?ref=${branch}"
            else
                echo "${repo}/-/pipelines"
            fi;;
        bitbucket)
            echo "${repo}/pipelines";;
    esac
}


### Human-friendly label for the CI system
# $1: repo URL (optional)
function get_ci_label {
    case "$(get_repo_host "${1:-$(get_repo)}")" in
        github)    echo "Actions";;
        gitlab)    echo "Pipeline";;
        bitbucket) echo "Pipelines";;
        *)         echo "CI";;
    esac
}


### URL to a tag page in the remote repo
# $1: tag name, $2: repo URL (optional)
function get_tag_url {
    local tag=$1
    local repo=${2:-$(get_repo)}
    case "$(get_repo_host "$repo")" in
        github)    echo "${repo}/releases/tag/${tag}";;
        gitlab)    echo "${repo}/-/tags/${tag}";;
        bitbucket) echo "${repo}/src/${tag}";;
    esac
}


### URL to create a new release for a tag
# $1: tag name, $2: repo URL (optional)
function get_new_release_url {
    local tag=$1
    local repo=${2:-$(get_repo)}
    case "$(get_repo_host "$repo")" in
        github)    echo "${repo}/releases/new?tag=${tag}";;
        gitlab)    echo "${repo}/-/releases/new?tag_name=${tag}";;
    esac
}


### URL to all releases / downloads
# $1: repo URL (optional)
function get_releases_url {
    local repo=${1:-$(get_repo)}
    case "$(get_repo_host "$repo")" in
        github)    echo "${repo}/releases";;
        gitlab)    echo "${repo}/-/releases";;
        bitbucket) echo "${repo}/downloads/?tab=tags";;
    esac
}


### URL to the issues page
# $1: repo URL (optional)
function get_issues_url {
    local repo=${1:-$(get_repo)}
    case "$(get_repo_host "$repo")" in
        github)    echo "${repo}/issues";;
        gitlab)    echo "${repo}/-/issues";;
        bitbucket) echo "${repo}/issues";;
    esac
}


### URL to create a new issue
# $1: repo URL (optional)
function get_new_issue_url {
    local repo=${1:-$(get_repo)}
    case "$(get_repo_host "$repo")" in
        github)    echo "${repo}/issues/new";;
        gitlab)    echo "${repo}/-/issues/new";;
        bitbucket) echo "${repo}/issues/new";;
    esac
}


### URL to the branches list page
# $1: repo URL (optional)
function get_branches_url {
    local repo=${1:-$(get_repo)}
    case "$(get_repo_host "$repo")" in
        github)    echo "${repo}/branches";;
        gitlab)    echo "${repo}/-/branches";;
        bitbucket) echo "${repo}/branches";;
    esac
}


### URL to the tags list page
# $1: repo URL (optional)
function get_tags_url {
    local repo=${1:-$(get_repo)}
    case "$(get_repo_host "$repo")" in
        github)    echo "${repo}/tags";;
        gitlab)    echo "${repo}/-/tags";;
        bitbucket) echo "${repo}/branches/?tab=tags";;
    esac
}


### URL to the commit history page
# $1: repo URL (optional)
function get_commits_url {
    local repo=${1:-$(get_repo)}
    case "$(get_repo_host "$repo")" in
        github)    echo "${repo}/commits";;
        gitlab)    echo "${repo}/-/commits";;
        bitbucket) echo "${repo}/commits";;
    esac
}


### URL to the project wiki
# $1: repo URL (optional)
function get_wiki_url {
    local repo=${1:-$(get_repo)}
    case "$(get_repo_host "$repo")" in
        github)    echo "${repo}/wiki";;
        gitlab)    echo "${repo}/-/wikis/home";;
    esac
}


### URL to the project settings page
# $1: repo URL (optional)
function get_settings_url {
    local repo=${1:-$(get_repo)}
    case "$(get_repo_host "$repo")" in
        github)    echo "${repo}/settings";;
        gitlab)    echo "${repo}/edit";;
        bitbucket) echo "${repo}/admin";;
    esac
}


### URL to the project insights / activity page
# $1: repo URL (optional)
function get_insights_url {
    local repo=${1:-$(get_repo)}
    case "$(get_repo_host "$repo")" in
        github)    echo "${repo}/pulse";;
        gitlab)    echo "${repo}/activity";;
    esac
}


### URL to the contributors graph
# $1: repo URL (optional)
function get_contributors_url {
    local repo=${1:-$(get_repo)}
    case "$(get_repo_host "$repo")" in
        github)    echo "${repo}/graphs/contributors";;
        gitlab)    echo "${repo}/-/graphs/master";;
    esac
}


### URL to the forks/network page
# $1: repo URL (optional)
function get_forks_url {
    local repo=${1:-$(get_repo)}
    case "$(get_repo_host "$repo")" in
        github)    echo "${repo}/network/members";;
        gitlab)    echo "${repo}/-/forks";;
        bitbucket) echo "${repo}/forks";;
    esac
}


### Human-friendly label for pull/merge requests
# $1: repo URL (optional)
function get_pr_label {
    case "$(get_repo_host "${1:-$(get_repo)}")" in
        github)    echo "Pulls";;
        gitlab)    echo "MRs";;
        bitbucket) echo "Pulls";;
        *)         echo "PRs";;
    esac
}


### Print a "label: url" line with a fixed-width label so multiple lines align,
### regardless of the label length (color escapes don't affect padding).
# $1: label text (without trailing colon)
# $2: url
# $3: optional color (defaults to $YELLOW)
function print_link {
    local label="$1"
    local url="$2"
    local color="${3:-$YELLOW}"
    printf "%b%-10s%b %s\n" "$color" "${label}:" "$ENDCOLOR" "$url"
}


### URL to CI runs triggered by a tag
# $1: tag name, $2: repo URL (optional)
function get_tag_ci_url {
    local tag=$1
    local repo=${2:-$(get_repo)}
    case "$(get_repo_host "$repo")" in
        github)    echo "${repo}/actions?query=ref%3Arefs%2Ftags%2F${tag}";;
        gitlab)    echo "${repo}/-/pipelines?ref=${tag}";;
        bitbucket) echo "${repo}/pipelines";;
    esac
}


### Determine where a git config value originates.
# Used by print_configuration to label each row so users can tell whether a
# value comes from this repo, ~/.gitconfig, or gitbasher's built-in fallback.
# $1: full git config key (e.g. gitbasher.ai-provider)
# Returns: "local" | "global" | "default"
function config_source {
    if git config --local --get "$1" >/dev/null 2>&1; then
        echo "local"
    elif git config --global --get "$1" >/dev/null 2>&1; then
        echo "global"
    else
        echo "default"
    fi
}

### Render a colored "(project)" / "(global)" / "(default)" tag for a key.
# $1: full git config key
function config_source_tag {
    case "$(config_source "$1")" in
        local)   echo -e "${BLUE}(project)${ENDCOLOR}" ;;
        global)  echo -e "${PURPLE}(global)${ENDCOLOR}" ;;
        default) echo -e "${GRAY}(default)${ENDCOLOR}" ;;
    esac
}


### Function prints current config
function print_configuration {
    echo -e "${YELLOW}Current configuration:${ENDCOLOR}"

    local user_name=$(get_config_value user.name)
    if [ -n "$user_name" ]; then
        echo -e "\tuser.name:\t${YELLOW}$user_name${ENDCOLOR} $(config_source_tag user.name)"
    else
        echo -e "\tuser.name:\t${RED}not set${ENDCOLOR}"
    fi
    local user_email=$(get_config_value user.email)
    if [ -n "$user_email" ]; then
        echo -e "\tuser.email:\t${YELLOW}$user_email${ENDCOLOR} $(config_source_tag user.email)"
    else
        echo -e "\tuser.email:\t${RED}not set${ENDCOLOR}"
    fi
    echo -e "\tdefault:\t${YELLOW}$main_branch${ENDCOLOR} $(config_source_tag gitbasher.branch)"
    echo -e "\tseparator:\t${YELLOW}$sep${ENDCOLOR} $(config_source_tag gitbasher.sep)"
    echo -e "\teditor:\t\t${YELLOW}$editor${ENDCOLOR} $(config_source_tag core.editor)"
    if [ "$ticket_name" != "" ]; then
        echo -e "\tticket:\t\t${YELLOW}$ticket_name${ENDCOLOR} $(config_source_tag gitbasher.ticket)"
    fi
    if [ "$scopes" != "" ]; then
        echo -e "\tscopes:\t\t${YELLOW}$scopes${ENDCOLOR} $(config_source_tag gitbasher.scopes)"
    fi
    local ai_provider=$(get_ai_provider)
    echo -e "\tAI provider:\t${GREEN}$ai_provider${ENDCOLOR} $(config_source_tag gitbasher.ai-provider)"
    local ai_base_url=$(get_ai_base_url)
    if [ -n "$ai_base_url" ]; then
        echo -e "\tAI base URL:\t${GREEN}$ai_base_url${ENDCOLOR} $(config_source_tag gitbasher.ai-base-url)"
    fi
    local ai_key=$(get_ai_api_key)
    if [ -n "$ai_key" ]; then
        # Resolve where the active provider's key actually comes from. The
        # full resolution chain (per-provider env > per-provider config >
        # legacy env > legacy config) is encoded in get_ai_api_key_source.
        local ai_key_tag
        case "$(get_ai_api_key_source)" in
            env-provider)    ai_key_tag="${CYAN}(env: GITB_AI_API_KEY_$(to_upper "$ai_provider"))${ENDCOLOR}" ;;
            env-legacy)      ai_key_tag="${CYAN}(env: GITB_AI_API_KEY, legacy)${ENDCOLOR}" ;;
            local-provider)  ai_key_tag="${BLUE}(project)${ENDCOLOR}" ;;
            global-provider) ai_key_tag="${PURPLE}(global)${ENDCOLOR}" ;;
            local-legacy)    ai_key_tag="${YELLOW}(project, legacy slot)${ENDCOLOR}" ;;
            global-legacy)   ai_key_tag="${YELLOW}(global, legacy slot)${ENDCOLOR}" ;;
        esac
        ai_key=$(mask_api_key "$ai_key")
        echo -e "\tAI key:\t\t${GREEN}$ai_key${ENDCOLOR} ${GRAY}for ${ai_provider}${ENDCOLOR} $ai_key_tag"
    elif ai_provider_requires_api_key; then
        echo -e "\tAI key:\t\t${RED}not set for ${ai_provider}${ENDCOLOR} ${GRAY}— run ${GREEN}gitb cfg ai${ENDCOLOR}"
    else
        echo -e "\tAI key:\t\t${GRAY}not required for $ai_provider${ENDCOLOR}"
    fi
    # List other providers that have a key stored, so users can see at a
    # glance that switching providers won't lose their other keys.
    local other_keys=""
    while IFS= read -r prov; do
        [ -z "$prov" ] && continue
        [ "$prov" = "$ai_provider" ] && continue
        other_keys="${other_keys:+${other_keys}, }${prov}"
    done < <(list_providers_with_api_key)
    if [ -n "$other_keys" ]; then
        echo -e "\t\t\t${GRAY}also stored for: ${other_keys}${ENDCOLOR}"
    fi
    local ai_model=$(get_ai_model)
    if [ -n "$ai_model" ]; then
        echo -e "\tAI model:\t${GREEN}$ai_model${ENDCOLOR} ${GRAY}(all tasks)${ENDCOLOR} $(config_source_tag gitbasher.ai-model)"
    else
        echo -e "\tAI models:\t${GREEN}$(get_ai_model_for simple)${ENDCOLOR} ${GRAY}(simple/subject)${ENDCOLOR} $(config_source_tag gitbasher.ai-model-simple)"
        echo -e "\t\t\t${GREEN}$(get_ai_model_for full)${ENDCOLOR} ${GRAY}(full)${ENDCOLOR} $(config_source_tag gitbasher.ai-model-full)"
        echo -e "\t\t\t${GREEN}$(get_ai_model_for grouping)${ENDCOLOR} ${GRAY}(grouping)${ENDCOLOR} $(config_source_tag gitbasher.ai-model-grouping)"
    fi
    local ai_proxy=$(get_ai_proxy)
    if [ -n "$ai_proxy" ]; then
        echo -e "\tAI proxy:\t${GREEN}$ai_proxy${ENDCOLOR} $(config_source_tag gitbasher.ai-proxy)"
    else
        echo -e "\tAI proxy:\t${YELLOW}not set${ENDCOLOR}"
    fi
    local ai_history_limit=$(get_ai_commit_history_limit)
    echo -e "\tAI history:\t${GREEN}$ai_history_limit commits${ENDCOLOR} $(config_source_tag gitbasher.ai-commit-history-limit)"
    local ai_diff_lines=$(get_ai_diff_limit)
    local ai_diff_chars=$(get_ai_diff_max_chars)
    # Two keys share one row; pick the most-specific source so a single override
    # in either key is visible at a glance (local > global > default).
    local lines_src=$(config_source gitbasher.ai-diff-limit)
    local chars_src=$(config_source gitbasher.ai-diff-max-chars)
    local diff_src="default"
    if [ "$lines_src" = "local" ] || [ "$chars_src" = "local" ]; then
        diff_src="local"
    elif [ "$lines_src" = "global" ] || [ "$chars_src" = "global" ]; then
        diff_src="global"
    fi
    local diff_tag
    case "$diff_src" in
        local)   diff_tag="${BLUE}(project)${ENDCOLOR}" ;;
        global)  diff_tag="${PURPLE}(global)${ENDCOLOR}" ;;
        default) diff_tag="${GRAY}(default)${ENDCOLOR}" ;;
    esac
    echo -e "\tAI diff:\t${GREEN}${ai_diff_lines} lines / ${ai_diff_chars} chars max${ENDCOLOR} $diff_tag"

    local push_warn=$(get_push_warn_size)
    if [ "$push_warn" = "0" ]; then
        echo -e "\tPush warn:\t${YELLOW}disabled${ENDCOLOR} $(config_source_tag gitbasher.push-warn-size)"
    else
        echo -e "\tPush warn:\t${GREEN}${push_warn} MB${ENDCOLOR} $(config_source_tag gitbasher.push-warn-size)"
    fi

    echo
    echo -e "${GRAY}Source:${ENDCOLOR} ${BLUE}(project)${ENDCOLOR}${GRAY} this repo,${ENDCOLOR} ${PURPLE}(global)${ENDCOLOR}${GRAY} ~/.gitconfig,${ENDCOLOR} ${GRAY}(default) built-in fallback${ENDCOLOR}"
}



### Function to escape substring in string
# $1: string
# $2: substring to escape
# Returns: provided string with escaped substring
function escape {
    string="$1"
    sub="$2"
    escaped="\\$sub"
    echo "${string//${sub}/${escaped}}"
}


### Function checks code against 0 and show error
# $1: return code
# $2: command output (error message)
# $3: command name
# Using of global:
#     * git_add
function check_code {
    if [ "$1" != 0 ]; then
        echo
        echo
        echo -e "${RED}✗ Cannot $3.${ENDCOLOR}"
        echo -e "$2"
        if [ -n "$git_add" ]; then
            # Match `git add $git_add`: word-split intentionally (multiple
            # paths), glob-off, `--` so dash-leading paths aren't options.
            # A quoted "$git_add" treated the whole list as ONE pathspec and
            # failed loudly for multi-file input.
            ( set -f; git restore --staged -- $git_add 2>/dev/null )
        fi
        exit $1
    fi
}


### Function asks user to enter yes or no, it will exit if user answers 'no'
# $1: what to write in console on success
# $2: flag no echo
function yes_no_choice {
    while true; do
        if ! read -n 1 -s choice; then
            # EOF/closed stdin: never treat an unanswerable prompt as "yes".
            printf "n\n"
            echo -e "${YELLOW}Input closed — aborting.${ENDCOLOR}"
            exit 1
        fi
        if is_yes "$choice"; then
            if [ -n "$1" ]; then
                echo -e "${YELLOW}$1${ENDCOLOR}"
                if [ -z "$2" ]; then
                    echo
                fi
            fi
            return
        fi
        if is_no "$choice"; then
            exit
        fi
    done
}


### yes_no_choice's destructive twin: same output contract, but only an
# explicit "yes" key proceeds. A decline (n/Enter/other key) exits 0 —
# the user changed their mind, nothing happened. EOF exits 1 — the prompt
# could never be answered. Use for prompts that delete, force-push, or
# rewrite history.
# $1: text to print on confirm
# $2: pass anything to skip the trailing blank line
function yes_no_choice_strict {
    local _ync_rc
    confirm_destructive
    _ync_rc=$?
    if [ "$_ync_rc" -eq 2 ]; then
        echo -e "${YELLOW}Input closed — aborting.${ENDCOLOR}"
        exit 1
    fi
    if [ "$_ync_rc" -ne 0 ]; then
        exit 0
    fi
    if [ -n "$1" ]; then
        echo -e "${YELLOW}$1${ENDCOLOR}"
        if [ -z "$2" ]; then
            echo
        fi
    fi
}


### Undo the staging recorded in $git_add when a picker is aborted. Prefers
# cleanup_on_exit (commit.sh) when it is loaded: it word-splits multi-path
# input the same way `git add $git_add` did, and re-stages files the user
# had staged before a fast-mode `git add .` — a plain quoted restore
# treated the whole list as one pathspec and dropped pre-existing staging.
function _choose_restore_staged {
    if [ -z "$git_add" ]; then
        return
    fi
    if type cleanup_on_exit >/dev/null 2>&1; then
        cleanup_on_exit "$git_add"
    else
        ( set -f; git restore --staged -- $git_add 2>/dev/null )
    fi
}


### Function waits a number from user and returns result of choice from a provided list
# $1: list of values
# Returns: 
#     * choice_result
#     * pressed_alt
# Using of global:
#     * git_add
function choose {
    values=("$@")
    number_of_values=${#values[@]}

    while true; do
        local _choose_read_ok="true"
        if [ "$number_of_values" -gt 9 ]; then
            read -p "$read_prefix" -e -n 2 choice || _choose_read_ok=""
        else
            read -p "$read_prefix" -n 1 -s choice || _choose_read_ok=""
            # Drain trailing newline so users who press "1<Enter>" don't leak
            # the newline into the next read (e.g. worktree move's path prompt).
            drain_pending_input
        fi

        if [ -z "$_choose_read_ok" ]; then
            # EOF/closed stdin: abort without picking anything.
            _choose_restore_staged
            echo
            echo -e "${YELLOW}Input closed — aborting.${ENDCOLOR}"
            exit 1
        fi

        if [ "$choice" == "0" ] || [ "$choice" == "00" ]; then
            _choose_restore_staged
            if [ "$number_of_values" -le 9 ]; then
                printf "%s" "$choice"
            fi
            exit
        fi

        # Whole-token match only: mixed input like "5=" must not reach the
        # arithmetic below (bash would abort on "5=-1").
        re='^([0-9][0-9]?|=|==)$'
        if ! [[ $choice =~ $re ]]; then
            _choose_restore_staged
            exit
        fi

        if [ "$choice" == "=" ] || [ "$choice" == "==" ]; then
            pressed_alt="true"
            break
        fi

        # 10# so a leading zero ("09") is decimal, not an octal error
        index=$((10#$choice-1))
        choice_result=${values[index]}
        if [ -n "$choice_result" ]; then
            if [ "$number_of_values" -le 9 ]; then
                printf "%s" "$choice"
            fi
            break
        else
            if [ "$number_of_values" -gt 9 ]; then
                _choose_restore_staged
                exit
            fi
        fi
    done
}


### Function prints fiels from git status in a pretty way
function git_status {
    status_output=$(git status --short)
    status_output=$(echo "$status_output" | sed "s/^ D/${RED_ES}\tDeleted: ${ENDCOLOR_ES}/")
    status_output=$(echo "$status_output" | sed "s/^D /${GREEN_ES}Staged\t${RED_ES}Deleted: ${ENDCOLOR_ES}/")

    status_output=$(echo "$status_output" | sed "s/^ M/${YELLOW_ES}\tModified:${ENDCOLOR_ES}/")
    status_output=$(echo "$status_output" | sed "s/^MM/${GRAY_ES}Old\t${YELLOW_ES}Modified:${ENDCOLOR_ES}/")
    status_output=$(echo "$status_output" | sed "s/^AM/${GRAY_ES}Old\t${YELLOW_ES}Modified:${ENDCOLOR_ES}/")
    status_output=$(echo "$status_output" | sed "s/^M /${GREEN_ES}Staged\t${YELLOW_ES}Modified:${ENDCOLOR_ES}/")

    status_output=$(echo "$status_output" | sed "s/^A/${GREEN_ES}Staged\tAdded:   ${ENDCOLOR_ES}/")
    status_output=$(echo "$status_output" | sed "s/^??/${GREEN_ES}\tAdded:   ${ENDCOLOR_ES}/")
    echo -e "$status_output"
}


### Function prints staged files with color-coded status
# Added: green, Modified: yellow, Deleted: red
function print_staged_files {
    local staged_diff
    staged_diff=$(git -c core.quotePath=false diff --name-status --cached)
    if [ -z "$staged_diff" ]; then
        return
    fi
    while IFS=$'\t' read -r status file _; do
        [ -z "$file" ] && continue
        case "${status:0:1}" in
            A) echo -e "\t${GREEN}${file}${ENDCOLOR}" ;;
            M) echo -e "\t${YELLOW}${file}${ENDCOLOR}" ;;
            D) echo -e "\t${RED}${file}${ENDCOLOR}" ;;
            *) echo -e "\t${file}${ENDCOLOR}" ;;
        esac
    done <<< "$staged_diff"
}


### Function prints the list of commits
# $1: number of last commits to show
# $2: what to add before commit line
#     * <empty> - nothing
#     * tab
#     * number
# $3: from which place (commit, branch) show commits (empty for default)
# Returns: 
#     commits_info
#     commits_hash
function commit_list {
    ref=$3
    if [[ "$(git --no-pager log -n 1 2>&1)" == *"does not have any commits yet"* ]]; then
        if [[ "$3" == *"HEAD"* ]]; then
            ref="$(echo "$3" | sed 's/HEAD..//')"
        else
            return 
        fi
    fi

    IFS=$'\n' 
    read -rd '' -a commits_info <<<"$(git --no-pager log -n $1 --pretty="${YELLOW_ES}%h${ENDCOLOR_ES} | %s | ${BLUE_ES}%an${ENDCOLOR_ES} | ${GREEN_ES}%cr${ENDCOLOR_ES}" $ref | column -ts'|')" || true
    read -rd '' -a commits_hash <<<"$(git --no-pager log -n $1 --pretty="%h" $ref)" || true

    for index in "${!commits_info[@]}"
    do
        line=${commits_info[index]}
        if [ "$2" == "number" ]; then
            line="$(($index+1)). ${line}"
        elif [ "$2" == "tab" ]; then
            line="\t${line}"
        fi
        echo -e "$line"
    done
}


### Function prints the list of refs from reflog
# $1: number of last refs to show
# Returns: 
#     refs_info
#     refs_hash
function ref_list {
    IFS=$'\n' 
    read -rd '' -a refs_info <<<"$(git --no-pager reflog -n $1 --pretty="${YELLOW_ES}%h${ENDCOLOR_ES} | ${BLUE_ES}%gd${ENDCOLOR_ES} | %gs | ${GREEN_ES}%cr${ENDCOLOR_ES}" | column -ts'|')" || true
    read -rd '' -a refs_hash <<<"$(git --no-pager reflog -n $1 --pretty="%gd")" || true

    # Remove HEAD@{0}
    refs_info=("${refs_info[@]:1}")
    refs_hash=("${refs_hash[@]:1}")

    for index in "${!refs_info[@]}"
    do
        line="$(($index+1)). ${refs_info[index]}"
        echo -e "$line"
    done
}


### Function prints the list of commits and user should choose one
# $1: number of last commits to show
# Returns: 
#     commit_hash - hash of selected commit
# Using of global:
#     * git_add
function choose_commit {
    commit_list "$1" "number"
    if [ "$1" -gt 9 ]; then
        echo "00. Exit"
    else
        echo "0. Exit"
    fi

    echo -e "${BLUE}Tip: press = to show more commits${ENDCOLOR}"
    echo

    read_prefix="Enter commit number: "

    choose "${commits_hash[@]}"
    commit_hash=$choice_result

    if [ -n "$pressed_alt" ]; then
        commit_list 50 "number"
        echo "00. Exit"
        echo
        choose "${commits_hash[@]}"
        commit_hash=$choice_result
    fi

    echo
}


### Function prints provided stat in a nice format with colors
# $1: stats after pull or commit like 'README.md | 1 +\n1 file changed, 1 insertion(+)'
function print_changes_stat {
    IFS=$'\n' read -rd '' -a stats <<< "$1" || true
    result_stat=""
    bottom_line=""
    number_of_stats=${#stats[@]}
    for index in "${!stats[@]}"
    do
        s=$(echo ${stats[index]} | sed -e 's/^[[:space:]]*//')
        s=$(sed "s/+/${GREEN_ES}+${ENDCOLOR_ES}/g" <<< ${s})
        s=$(sed "s/-/${RED_ES}-${ENDCOLOR_ES}/g" <<< ${s})
        if [ $(($index+1)) == $number_of_stats ]; then
            #s=$(sed '1 s/,/|/' <<< ${s})
            bottom_line="${s}"
            break
        fi
        result_stat="${result_stat}\n${s}"
    done
    echo -e "$(echo -e "${result_stat}" | column -ts'|')"
    echo -e "$bottom_line"
}


### Render an AI summary for the terminal: strip the Markdown that models emit
### (headings, bold, bullets) and re-style it in gitbasher's colors. Defensive —
### the prompt asks for plain text, but models slip, so raw markup never leaks.
function print_ai_summary {
    local text="$1"
    local esc c_bold c_bullet c_head c_reset
    esc=$(printf '\033')
    c_bold="${esc}[1m"
    c_bullet="${esc}[36m"
    c_head="${esc}[33m"
    c_reset="${esc}[0m"

    local label_re='^[[:space:]]*[A-Za-z][A-Za-z0-9 &/_-]*:[[:space:]]*$'
    local backtick='`'
    local line
    while IFS= read -r line; do
        # Drop inline-code backticks the model emits despite the prompt.
        line=${line//$backtick/}
        # Markdown heading (#, ##, ###) -> plain colored header.
        if [[ "$line" =~ ^[[:space:]]*#+[[:space:]] ]]; then
            line=$(printf '%s' "$line" | sed -E 's/^[[:space:]]*#+[[:space:]]*//; s/[[:space:]]*#+[[:space:]]*$//')
            printf '%s%s%s\n' "$c_head" "$line" "$c_reset"
            continue
        fi
        # A standalone label line ("Risks & Concerns:") -> colored header.
        if [[ "$line" =~ $label_re ]]; then
            printf '%s%s%s\n' "$c_head" "$line" "$c_reset"
            continue
        fi
        # Leading bullet (*, +, -) -> colored bullet.
        line=$(printf '%s' "$line" | sed -E "s/^([[:space:]]*)[*+-][[:space:]]+/\\1${c_bullet}•${c_reset} /")
        # Inline bold -> terminal bold. Same-kind pairs only, anchored at
        # word boundaries: the old cross-kind pattern paired '**' across
        # spans (mangling '**a_b** and **c_d**') and ate math ('2**8') and
        # dunder names ('__init__.py').
        line=$(printf '%s' "$line" | sed -E "s/(^|[[:space:]])\\*\\*([^*]+)\\*\\*($|[[:space:]])/\\1${c_bold}\\2${c_reset}\\3/g")
        line=$(printf '%s' "$line" | sed -E "s/(^|[[:space:]])__([^_]+)__($|[[:space:]])/\\1${c_bold}\\2${c_reset}\\3/g")
        printf '%s\n' "$line"
    done <<< "$text"
}


### Threshold, in MB, above which a push warns about its total size or a single
### large blob. 0 disables the check entirely (also a performance opt-out).
function get_push_warn_size {
    get_config_value gitbasher.push-warn-size "50"
}
function set_push_warn_size {
    set_config_value gitbasher.push-warn-size "$1"
}


### Format an integer byte count as "N B" / "N.d KB|MB|GB" (base 1024, one
### decimal via integer math — no numfmt, bash-3.2 safe).
# $1: bytes
function human_size {
    local bytes="${1:-0}"
    case "$bytes" in ''|*[!0-9]*) bytes=0;; esac
    if [ "$bytes" -lt 1024 ]; then
        echo "${bytes} B"
        return
    fi
    local div=1024 label="KB"
    if [ "$bytes" -ge 1073741824 ]; then
        div=1073741824; label="GB"
    elif [ "$bytes" -ge 1048576 ]; then
        div=1048576; label="MB"
    fi
    echo "$((bytes / div)).$(( (bytes % div) * 10 / div )) ${label}"
}


### Report the size of the objects a push would transfer, and list oversized
### blobs. Sizes use %(objectsize) (uncompressed content size) — matches how
### users think about file size and safely over-estimates the wire transfer
### (git compresses objects on the wire).
# $1: blob-size threshold in BYTES (a blob strictly above this is reported)
# $2..: git rev-list selectors, e.g. "origin/br..HEAD" or "HEAD --not --remotes"
# Echoes: line 1 = total bytes (integer); then one "<bytes>\t<path>" line per
#         oversized blob (unsorted; caller sorts for display).
function get_push_size_report {
    local threshold="$1"; shift
    local revlist
    revlist=$(git rev-list --objects "$@" 2>/dev/null)
    if [ -z "$revlist" ]; then
        echo 0
        return
    fi
    awk -v th="$threshold" '
        NR==FNR { sha=$1; $1=""; sub(/^ +/,""); path[sha]=$0; next }
        { type=$1; size=$2+0; sha=$3; total+=size
          if (type=="blob" && size>th && path[sha]!="") blob[++n]=size "\t" path[sha] }
        END { print total+0; for (i=1;i<=n;i++) print blob[i] }
    ' <(printf '%s\n' "$revlist") \
      <(printf '%s\n' "$revlist" | awk '{print $1}' \
          | git cat-file --batch-check='%(objecttype) %(objectsize) %(objectname)' 2>/dev/null)
}


### Function sets to variables push_list and history_from actual push log information
# $1: current branch
# $2: main branch
# $3: origin name
# Returns: 
#     push_list - unpushed commits
#     history_from - branch or commit from which history was calculated
function get_push_list {
    # Handle case when origin_name is empty (e.g., in test mode or no remote)
    # Check both empty string and unset variable
    local origin="${3:-}"
    # Trim whitespace using parameter expansion
    origin="${origin#"${origin%%[![:space:]]*}"}"
    origin="${origin%"${origin##*[![:space:]]}"}"
    if [ -z "$origin" ]; then
        push_list=""
        history_from=""
        return
    fi
    
    push_list_check=$(git --no-pager log $origin/$1..HEAD 2>&1 || true)
    if [[ $push_list_check != *"unknown revision or path not in the working tree"* ]] && [[ $push_list_check != *"fatal:"* ]]; then
        push_list=$(commit_list 999 "tab" $origin/$1..HEAD)
        history_from="$origin/$1"
        return
    fi

    # Case with new repo without any branch
    if [[ $push_list_check == *"unknown revision or path not in the working tree"* ]] || [[ $push_list_check == *"fatal:"* ]]; then
        if [[ $1 == $2 ]]; then
            push_list=$(commit_list 999 "tab")
            history_from="HEAD"
            return
        fi
    fi
    
    base_commit=$(diff -u <(git rev-list --first-parent "$1" 2>/dev/null) <(git rev-list --first-parent "$2" 2>/dev/null) | sed -ne 's/^ //p' | head -1 || true)
    if [ -n "$base_commit" ]; then
        push_list=$(commit_list 999 "tab" "$base_commit..HEAD")
        history_from="${base_commit::7}"
    else
        # If no base commit found and origin_name is empty, use HEAD
        if [ -z "$origin" ]; then
            push_list=""
            history_from=""
        else
            push_list=$(commit_list 999 "tab" "$origin/$2..HEAD")
            history_from="$origin/$2"
        fi
    fi
}


### Function prints list of branches
# $1: possible values:
#     * no value prints all local branches
#     * 'remote' - all remote
#     * 'delete' - all local without main and current
#     * 'merge' - all local without current
# Using of global:
#     * current_branch
#     * main_branch
# Returns:
#     * number_of_branches
#     * branches_first_main
#     * to_exit
function list_branches {
    to_exit=""
    local branches_per_page=20
    args="--sort=-committerdate"
    if [[ "$1" == "remote" ]]; then
        args="--sort=-committerdate -r"
    fi
    branches_str=$(git --no-pager branch $args --format="%(refname:short)")
    branches_info_raw=$(git --no-pager branch $args --format="${BLUE_ES}%(refname:short)${ENDCOLOR_ES} | %(contents:subject) | ${YELLOW_ES}%(objectname:short)${ENDCOLOR_ES}  | ${GREEN_ES}%(committerdate:relative)${ENDCOLOR_ES}")
    # ctrl/torn: strip terminal-control bytes from subjects and repair a
    # trailing UTF-8 sequence cut mid-character (byte-based awk on macOS) —
    # one torn byte makes BSD column silently drop the row and all after it.
    branches_info_str=$(echo "$branches_info_raw" | LC_ALL=C awk -v max=60 \
        -v ctrl='[\001-\010\013-\037\177]' -v torn='[\300-\367][\200-\277]*$' -F'\\|' '{
        subject=$2
        gsub(ctrl,"",subject)
        gsub(/^[ \t]+|[ \t]+$/,"",subject)
        if (length(subject) > max) {
            subject=substr(subject,1,max-3)
            sub(torn,"",subject)
            subject=subject "..."
        }
        print $1 " | " subject " | " $3 " | " $4
    }' | column -ts'|' )

    local IFS=$'\n'
    read -rd '' -a branches <<< "$branches_str" || true
    read -rd '' -a branches_info <<< "$branches_info_str" || true

    number_of_branches=${#branches[@]}
    if [[ "$1" == "remote" ]]; then
        # There is origin/HEAD
        ((number_of_branches=number_of_branches-1))
    fi

    if [[ "$number_of_branches" == 0 ]]; then
        echo
        echo -e "${YELLOW}No branches found.${ENDCOLOR}"
        to_exit="true"
        return
    fi

    branch_to_check="${branches[0]}"
    if [[ "$1" == "remote" ]]; then
        # Remove 'origin/'
        branch_to_check="${branches[1]}"
        branch_to_check="$(sed "s/remotes\///g" <<< ${branch_to_check})"
        branch_to_check="$(sed "s/${origin_name}\///g" <<< ${branch_to_check})"
    fi

    if [[ "$number_of_branches" == 1 ]] && [[ "${branch_to_check}" == "${current_branch}" ]]; then
        echo
        echo -e "Only one branch exists: ${YELLOW}${current_branch}${ENDCOLOR}"
        to_exit="true"
        return
    fi

    if [[ "$1" == "delete" ]] && [[ "$number_of_branches" == 2 ]] && [[ "${current_branch}" != "${main_branch}" ]]; then
        echo
        echo -e "${YELLOW}No branches available to delete.${ENDCOLOR}"
        to_exit="true"
        return
    fi

    ### Main should be the first
    branches_first_main=(${main_branch})
    branches_info_first_main=("dummy")
    if [[ "$1" == "delete" ]]; then
        branches_first_main=()
        branches_info_first_main=()
    fi
    if [[ "$1" == "merge" ]] && [[ "$current_branch" == "$main_branch" ]]; then
        branches_first_main=()
        branches_info_first_main=()
    fi
    for index in "${!branches[@]}"
    do
        branch_to_check="${branches[index]}"
        if [[ "$1" == "delete" ]]; then
            if [[ "$branch_to_check" == "${current_branch}"* ]] || [[ "$branch_to_check" == "${main_branch}"* ]]; then
                continue    
            fi
        fi
        if [[ "$1" == "merge" ]]; then
            if [[ "$branch_to_check" == "${current_branch}"* ]]; then
                continue
            fi
        fi
        if [[ "$1" == "remote" ]]; then
            branch_to_check="$(sed "s/remotes\///g" <<< ${branch_to_check})"
            branch_to_check="$(sed "s/${origin_name}\///g" <<< ${branch_to_check})"
        fi

        if [[ "$branch_to_check" == "${main_branch}"* ]]; then
            branches_info_first_main[0]="${branches_info[index]}"
        elif [[ "$branch_to_check" != "HEAD->"* ]] && [[ "$branch_to_check" != "$origin_name" ]]; then 
            branches_first_main+=(${branches[index]})
            branches_info_first_main+=("${branches_info[index]}")
        fi
    done

    if [[ "${branches_info_first_main[0]}" == "dummy" ]]; then
        branches_info_first_main=("${branches_info_first_main[@]:1}")
        branches_first_main=("${branches_first_main[@]:1}")
    fi
    list_total_branches=${#branches_info_first_main[@]}
    list_total_pages=$(( (list_total_branches + branches_per_page - 1) / branches_per_page ))
    if [ -z "$2" ]; then
        list_current_page=1
        while [ $list_current_page -le $list_total_pages ]; do
            list_page_start=$(( (list_current_page - 1) * branches_per_page ))
            list_page_end=$(( list_page_start + branches_per_page - 1 ))
            if [ $list_page_end -ge $list_total_branches ]; then
                list_page_end=$(( list_total_branches - 1 ))
            fi
            for ((index=list_page_start; index<=list_page_end; index++)); do
                branch=$(escape "${branches_first_main[index]}" "/")
                if [[ "$1" == "remote" ]] && [[ "$branch" != "origin"* ]]; then
                    branch="$origin_name\/$branch"
                fi

                branch_line="${branches_info_first_main[index]}"
                if [ "${branches_first_main[index]}" == "$current_branch" ]; then
                    echo -e "$(($index+1)). * $branch_line"
                else
                    echo -e "$(($index+1)).   $branch_line"
                fi
            done
            if [ $list_total_pages -gt 1 ] && [ $list_current_page -lt $list_total_pages ]; then
                echo
                printf "Page %s/%s. Press Enter for next page, q to quit: " "$list_current_page" "$list_total_pages"
                read -r -n 1 page_choice
                echo
                normalize_key "$page_choice"
                if [ "$normalized_key" == "q" ]; then
                    break
                fi
            fi
            list_current_page=$((list_current_page + 1))
        done
    else
        list_current_page="$2"
        list_page_start=$(( (list_current_page - 1) * branches_per_page ))
        list_page_end=$(( list_page_start + branches_per_page - 1 ))
        if [ $list_page_end -ge $list_total_branches ]; then
            list_page_end=$(( list_total_branches - 1 ))
        fi
        for ((index=list_page_start; index<=list_page_end; index++)); do
            branch=$(escape "${branches_first_main[index]}" "/")
            if [[ "$1" == "remote" ]] && [[ "$branch" != "origin"* ]]; then
                branch="$origin_name\/$branch"
            fi

            branch_line="${branches_info_first_main[index]}"
            if [ "${branches_first_main[index]}" == "$current_branch" ]; then
                echo -e "$(($index+1)). * $branch_line"
            else
                echo -e "$(($index+1)).   $branch_line"
            fi
        done
    fi
}


### This function prints the list of branches and user should choose one
# $1: possible values:
#     * no value prints all local branches
#     * 'remote' - choose from all remote
#     * 'delete' - choose from all local without main and current
#     * 'merge' - all local without current
# Using of global:
#     * origin_name
#     * current_branch
#     * main_branch
# Returns:
#     * branch_name
function choose_branch {
    local page=1
    while true; do
        list_branches "$1" "$page"

        if [ -n "$to_exit" ]; then
            exit
        fi

        echo
        if [ "$list_total_pages" -gt 1 ]; then
            printf "Enter branch number (page %s/%s, n/p to navigate): " "$page" "$list_total_pages"
        else
            printf "Enter branch number: "
        fi

        local choice=""
        if [ ${#branches_first_main[@]} -gt 9 ]; then
            read -r -n 2 choice
        else
            read -r -n 1 -s choice
        fi
        echo

        normalize_key "$choice"
        if [ "$normalized_key" == "n" ]; then
            if [ $page -lt $list_total_pages ]; then
                page=$((page + 1))
            fi
            continue
        fi
        if [ "$normalized_key" == "p" ]; then
            if [ $page -gt 1 ]; then
                page=$((page - 1))
            fi
            continue
        fi
        if [ "$normalized_key" == "q" ] || [ "$choice" == "0" ] || [ "$choice" == "00" ]; then
            exit
        fi

        re='^[0-9=]+$'
        if ! [[ $choice =~ $re ]]; then
            exit
        fi
        index=$(($choice-1))
        branch_name=${branches_first_main[index]}
        if [ -n "$branch_name" ]; then
            break
        fi
        if [ ${#branches_first_main[@]} -gt 9 ]; then
            exit
        fi
    done

    # For remote, ensure branch_name is just the branch part (no origin/ prefix for local creation)
    if [[ "$1" == "remote" ]]; then
        branch_name=$(sed "s/remotes\///g" <<< ${branch_name})
        branch_name=$(sed "s/${origin_name}\///g" <<< ${branch_name})
    fi
}


### Function handles switch result
# $1: name of the branch to switch
# $2: pass it if you want to disable push log and moved changes
function switch {
    switch_output=$(git switch "$1" 2>&1)
    switch_code=$?

    ## Switch is OK
    if [ "$switch_code" == 0 ]; then
        if [ "$current_branch" == "$1" ]; then
            echo -e "${GREEN}✓ Already on '$1'${ENDCOLOR}"
        else
            echo -e "${GREEN}✓ Switched to '$1'${ENDCOLOR}"
            changes=$(git_status)
            if [ -n "$changes" ] && [ -z "$2" ]; then
                echo
                echo -e "${YELLOW}Moved changes:${ENDCOLOR}"
                echo -e "$changes"
            fi
        fi

        if [ -z "$2" ]; then
            # Only call get_push_list if origin_name is not empty
            # Trim whitespace using parameter expansion
            local check_origin="${origin_name:-}"
            check_origin="${check_origin#"${check_origin%%[![:space:]]*}"}"
            check_origin="${check_origin%"${check_origin##*[![:space:]]}"}"
            if [ -n "$check_origin" ]; then
                get_push_list "$1" "${main_branch}" "$check_origin"
                if [ -n "$push_list" ]; then
                    echo
                    count=$(echo -e "$push_list" | wc -l | sed 's/^ *//;s/ *$//')
                    echo -e "Your branch ${YELLOW}$1${ENDCOLOR} is ahead ${YELLOW}${history_from}${ENDCOLOR} by ${BOLD}$count${ENDCOLOR} commits"
                    echo -e "$push_list"
                fi
            fi
        fi
        return
    fi

    ## There are uncommited files with conflicts
    if [[ $switch_output == *"would be overwritten"* ]] || [[ $switch_output == *"overwritten by"* ]]; then
        # Platform-specific reverse command: tac (Linux) or tail -r (BSD/macOS)
        if which tac >/dev/null 2>&1; then
            conflicts="$(echo "$switch_output" | tac | tail -n +3 | tac | tail -n +2)"
        else
            conflicts="$(echo "$switch_output" | tail -r | tail -n +3 | tail -r | tail -n +2)"
        fi
        echo -e "${RED}✗ Cannot switch to '$1' — these files would be overwritten:${ENDCOLOR}"
        echo -e "${conflicts//[[:blank:]]/}"
        echo
        echo -e "${YELLOW}Commit or stash these files, then try again.${ENDCOLOR}"
        exit 1
    fi

    if [ $switch_code -ne 0 ]; then
        echo -e "${RED}✗ Cannot switch to '$1'.${ENDCOLOR}"
        echo -e "$switch_output"
        exit $switch_code
    fi
}
