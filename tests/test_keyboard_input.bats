#!/usr/bin/env bats

# Tests for keyboard input helpers in common.sh:
# normalize_key, is_yes, is_no, sanitize_choice_input
# These handle case-insensitive input and alternative keyboard layouts (Russian).

load setup_suite

setup() {
    source_gitbasher
}

# ===== normalize_key tests =====

@test "normalize_key: passes through lowercase ASCII" {
    normalize_key "y"
    [ "$normalized_key" = "y" ]
    normalize_key "n"
    [ "$normalized_key" = "n" ]
    normalize_key "q"
    [ "$normalized_key" = "q" ]
}

@test "normalize_key: lowercases ASCII uppercase" {
    normalize_key "Y"
    [ "$normalized_key" = "y" ]
    normalize_key "N"
    [ "$normalized_key" = "n" ]
    normalize_key "Q"
    [ "$normalized_key" = "q" ]
}

@test "normalize_key: empty input returns empty" {
    normalize_key ""
    [ -z "$normalized_key" ]
}

@test "normalize_key: digits pass through" {
    normalize_key "0"
    [ "$normalized_key" = "0" ]
    normalize_key "9"
    [ "$normalized_key" = "9" ]
}

@test "normalize_key: maps Russian lowercase to Latin" {
    normalize_key "й"
    [ "$normalized_key" = "q" ]
    normalize_key "н"
    [ "$normalized_key" = "y" ]
    normalize_key "т"
    [ "$normalized_key" = "n" ]
    normalize_key "ф"
    [ "$normalized_key" = "a" ]
}

@test "normalize_key: maps Russian uppercase to Latin" {
    normalize_key "Й"
    [ "$normalized_key" = "q" ]
    normalize_key "Н"
    [ "$normalized_key" = "y" ]
    normalize_key "Т"
    [ "$normalized_key" = "n" ]
    normalize_key "Ф"
    [ "$normalized_key" = "a" ]
}

@test "normalize_key: maps all Russian alphabet keys" {
    # Spot-check a representative subset of mappings (lowercase)
    declare -A expected=(
        [ц]=w [у]=e [к]=r [е]=t [г]=u [ш]=i [щ]=o [з]=p
        [ы]=s [в]=d [а]=f [п]=g [р]=h [о]=j [л]=k [д]=l
        [я]=z [ч]=x [с]=c [м]=v [и]=b [ь]=m
    )
    for ru in "${!expected[@]}"; do
        normalize_key "$ru"
        [ "$normalized_key" = "${expected[$ru]}" ] || \
            { echo "Failed: '$ru' -> '$normalized_key', expected '${expected[$ru]}'"; return 1; }
    done
}

@test "normalize_key: special chars pass through" {
    normalize_key "="
    [ "$normalized_key" = "=" ]
    normalize_key "/"
    [ "$normalized_key" = "/" ]
}

# ===== is_yes tests =====

@test "is_yes: accepts lowercase y" {
    is_yes "y"
}

@test "is_yes: accepts uppercase Y" {
    is_yes "Y"
}

@test "is_yes: accepts empty (Enter key)" {
    is_yes ""
}

@test "is_yes: accepts Russian н (Y position lowercase)" {
    is_yes "н"
}

@test "is_yes: accepts Russian Н (Y position uppercase)" {
    is_yes "Н"
}

@test "is_yes: rejects n" {
    ! is_yes "n"
}

@test "is_yes: rejects arbitrary letter" {
    ! is_yes "x"
    ! is_yes "a"
}

@test "is_yes: rejects digit" {
    ! is_yes "1"
}

# ===== is_no tests =====

@test "is_no: accepts lowercase n" {
    is_no "n"
}

@test "is_no: accepts uppercase N" {
    is_no "N"
}

@test "is_no: accepts Russian т (N position lowercase)" {
    is_no "т"
}

@test "is_no: accepts Russian Т (N position uppercase)" {
    is_no "Т"
}

@test "is_no: rejects empty input" {
    ! is_no ""
}

@test "is_no: rejects y" {
    ! is_no "y"
}

@test "is_no: rejects arbitrary letter" {
    ! is_no "x"
}

# ===== sanitize_choice_input tests =====

@test "sanitize_choice_input: accepts y" {
    sanitize_choice_input "y"
    [ "$sanitized_choice" = "y" ]
}

@test "sanitize_choice_input: accepts Y (lowercased)" {
    sanitize_choice_input "Y"
    [ "$sanitized_choice" = "y" ]
}

@test "sanitize_choice_input: accepts n" {
    sanitize_choice_input "n"
    [ "$sanitized_choice" = "n" ]
}

@test "sanitize_choice_input: accepts digit" {
    sanitize_choice_input "5"
    [ "$sanitized_choice" = "5" ]
}

@test "sanitize_choice_input: accepts =" {
    sanitize_choice_input "="
    [ "$sanitized_choice" = "=" ]
}

@test "sanitize_choice_input: accepts Russian н as y" {
    sanitize_choice_input "н"
    [ "$sanitized_choice" = "y" ]
}

@test "sanitize_choice_input: rejects empty" {
    ! sanitize_choice_input ""
}

@test "sanitize_choice_input: rejects multi-character ASCII" {
    ! sanitize_choice_input "yes"
}

@test "sanitize_choice_input: rejects punctuation by default" {
    ! sanitize_choice_input ";"
    ! sanitize_choice_input "&"
}

@test "sanitize_choice_input: respects custom pattern" {
    sanitize_choice_input "a" "^[abc]$"
    [ "$sanitized_choice" = "a" ]
    ! sanitize_choice_input "z" "^[abc]$"
}

@test "sanitize_choice_input: rejects ANSI escape sequences" {
    ! sanitize_choice_input $'\e[D' "^[0-9s]$"
}

# ===== read_key tests =====

@test "read_key: consumes an ANSI sequence without swallowing the next key" {
    run bash -c 'source "$GITBASHER_ROOT/scripts/init.sh"; source "$GITBASHER_ROOT/scripts/common.sh"; { read_key first; read_key second; printf "%s\n%s" "$(printf "%s" "$first" | wc -c | tr -d " ")" "$second"; } < <(printf "\033[D1")'
    assert_success
    [ "${lines[0]}" = "3" ]
    [ "${lines[1]}" = "1" ]
}

@test "read_editable_input: Esc submits empty input" {
    run python3 - <<'PY'
import os
import pty
import select
import subprocess
import sys
import time

root = os.environ["GITBASHER_ROOT"]
script = f'''
set -e
source "{root}/scripts/init.sh"
source "{root}/scripts/common.sh"
read_editable_input value "Prompt: " "prefilled"
printf "\\n<%s>\\n" "$value"
'''

master, slave = pty.openpty()
proc = subprocess.Popen(
    ["bash", "-lc", script],
    stdin=slave,
    stdout=slave,
    stderr=slave,
    close_fds=True,
)
os.close(slave)

output = b""
sent_escape = False
deadline = time.time() + 5

while time.time() < deadline:
    ready, _, _ = select.select([master], [], [], 0.05)
    if ready:
        try:
            chunk = os.read(master, 1024)
        except OSError:
            break
        if not chunk:
            break
        output += chunk
        if b"Prompt:" in output and not sent_escape:
            os.write(master, b"\x1b")
            sent_escape = True

    if proc.poll() is not None:
        break

if proc.poll() is None:
    proc.kill()
    proc.wait()

sys.stdout.write(output.decode("utf-8", errors="replace"))
sys.exit(proc.returncode)
PY
    assert_success
    [[ "$output" == *"<>"* ]]
}
