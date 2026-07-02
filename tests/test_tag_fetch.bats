#!/usr/bin/env bats

# `gitb t r` (tag remote) runs `git fetch --tags`, which exits non-zero when a
# local tag points at a different object than the same-named remote tag: git
# refuses to move the immutable local tag ("would clobber existing tag"). That
# is a recoverable warning — git DID reach the remote — so the tag list must
# still print. A genuine failure (fatal: ...) must still abort.
#
# These tests exercise the pure classification/parsing helpers; the main flow
# wiring is glue over them.

load setup_suite

setup() {
    source_gitbasher_lite
    source "${GITBASHER_ROOT}/scripts/tag.sh"
}

@test "tag: clobber-only fetch output is classified as recoverable" {
    local fetch_output="From gitlab.example.net:sb/processing/releaser
 ! [rejected]        6.0.0      -> 6.0.0  (would clobber existing tag)
 ! [rejected]        6.2.0      -> 6.2.0  (would clobber existing tag)"

    run is_tag_clobber_only "$fetch_output"
    [ "$status" -eq 0 ]
}

@test "tag: fetch output mixing new tags and clobber is still recoverable" {
    local fetch_output="From gitlab.example.net:sb/processing/releaser
 * [new tag]         7.0.0      -> 7.0.0
 ! [rejected]        6.0.0      -> 6.0.0  (would clobber existing tag)"

    run is_tag_clobber_only "$fetch_output"
    [ "$status" -eq 0 ]
}

@test "tag: genuine fetch failure is not treated as clobber" {
    local fetch_output="ssh: Could not resolve hostname gitlab.example.net
fatal: Could not read from remote repository."

    run is_tag_clobber_only "$fetch_output"
    [ "$status" -ne 0 ]
}

@test "tag: missing-repo fetch failure is not treated as clobber" {
    local fetch_output="fatal: 'origin' does not appear to be a git repository"

    run is_tag_clobber_only "$fetch_output"
    [ "$status" -ne 0 ]
}

@test "tag: clobbered tag names are extracted from fetch output" {
    local fetch_output="From gitlab.example.net:sb/processing/releaser
 ! [rejected]        6.0.0      -> 6.0.0  (would clobber existing tag)
 ! [rejected]        6.2.0      -> 6.2.0  (would clobber existing tag)"

    run clobbered_tag_names "$fetch_output"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "6.0.0" ]
    [ "${lines[1]}" = "6.2.0" ]
}

@test "tag: no clobbered tag names when nothing was rejected" {
    local fetch_output="From gitlab.example.net:sb/processing/releaser
 * [new tag]         7.0.0      -> 7.0.0"

    run clobbered_tag_names "$fetch_output"
    [ -z "$output" ]
}
