#!/usr/bin/env bash

# Bash 3.2 compatibility checks.
#
# Two things are verified here:
#   1. Every shell script parses (`bash -n`) — the real guard against an
#      accidental bash 4-only construct sneaking back in.
#   2. The portable map/set shim and case-folding helpers in scripts/common.sh
#      behave correctly.
#
# Designed to run under bash 3.2 in CI (the official `bash:3.2` Docker image),
# but it also runs fine under any newer bash for a quick local check:
#   tests/bash32_compat_check.sh
# or under real 3.2 locally:
#   docker run --rm -v "$PWD:/work" -w /work bash:3.2 bash tests/bash32_compat_check.sh

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "bash: $BASH_VERSION"

fail=0

# 1. Syntax-check every shell file we ship.
for f in "$here"/scripts/*.sh "$here"/install.sh "$here"/dist/build.sh; do
    if ! bash -n "$f"; then
        echo "SYNTAX FAIL: $f"
        fail=1
    fi
done
# The bundle only exists after a build; check it when present.
if [ -f "$here/dist/gitb" ]; then
    if ! bash -n "$here/dist/gitb"; then
        echo "SYNTAX FAIL: dist/gitb"
        fail=1
    fi
fi

# 1b. Guard against non-ASCII bytes in @test descriptions. bats mangles them
# into broken function names under bash 3.2 and silently drops those tests
# ("executed N instead of expected M"). Keep descriptions ASCII; put any
# non-ASCII fixtures in the test body instead.
nonascii=$(LC_ALL=C grep -n '^@test .*[^ -~]' "$here"/tests/*.bats 2>/dev/null || true)
if [ -n "$nonascii" ]; then
    echo "NON-ASCII @test descriptions (break bats under bash 3.2):"
    printf '%s\n' "$nonascii"
    fail=1
fi

# 2. Load the helpers and exercise them.
# shellcheck disable=SC1091
source "$here/scripts/common.sh"

_t() {
    if [ "$2" = "$3" ]; then
        echo "ok  - $1"
    else
        echo "NOT - $1 : got [$2] want [$3]"
        fail=1
    fi
}

# Map with awkward keys (slashes, dots) and an awkward value (embedded newline).
gmap_clear m
gmap_set m "services/auth" $'a\nb'
gmap_set m ".github" "x"
_t "map: slash key, newline value" "$(gmap_get m 'services/auth')" $'a\nb'
_t "map: dot key" "$(gmap_get m '.github')" "x"
gmap_has m ".github"; _t "map: has present" "$?" "0"
gmap_has m "absent"; _t "map: has absent" "$?" "1"
_t "map: get absent is empty" "$(gmap_get m 'absent')" ""
_t "map: size" "$(gmap_size m)" "2"

# A value containing shell metacharacters must be stored inert, never executed.
gmap_clear inj
gmap_set inj "k" 'x $(touch /tmp/gitb_pwn) `id` ;rm'
_t "map: value injection is inert" "$(gmap_get inj 'k')" 'x $(touch /tmp/gitb_pwn) `id` ;rm'
[ -e /tmp/gitb_pwn ] && { echo "NOT - injection executed!"; fail=1; }

# Counters.
gmap_clear c
gmap_inc c "foo.bar"; gmap_inc c "foo.bar"; gmap_inc c "foo.bar"
_t "map: inc 3x" "$(gmap_get c 'foo.bar')" "3"

# Clear really clears, including emptying size.
gmap_clear m
_t "map: cleared size" "$(gmap_size m)" "0"
_t "map: cleared get" "$(gmap_get m 'services/auth')" ""

# Insertion-order key iteration.
gmap_clear k
gmap_set k "b" 1; gmap_set k "a" 1; gmap_set k "c" 1
_t "map: keys in insertion order" "$(gmap_keys k)" $'b\na\nc'

# Map names that are prefixes of one another must not collide.
gmap_clear staged
gmap_clear staged_status
gmap_set staged "x" "1"
gmap_set staged_status "x" "2"
_t "map: no name-prefix collision A" "$(gmap_get staged 'x')" "1"
_t "map: no name-prefix collision B" "$(gmap_get staged_status 'x')" "2"

# Set helpers.
gmap_clear s
gset_add s "x/y"
gset_has s "x/y"; _t "set: member" "$?" "0"
gset_has s "z"; _t "set: non-member" "$?" "1"

# Case folding.
_t "to_lower" "$(to_lower 'AbC/DeF')" "abc/def"
_t "to_upper" "$(to_upper 'AbC/DeF')" "ABC/DEF"

if [ "$fail" -ne 0 ]; then
    echo "FAILED bash 3.2 compatibility checks"
    exit 1
fi
echo "All bash 3.2 compatibility checks passed."
