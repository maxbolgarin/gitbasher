#!/usr/bin/env bats

# Tests for dependency-aware ordering of split commits.
#
# Git returns staged files alphabetically by path, so without reordering the
# split commits run in alphabetical order. When a shared/foundational scope
# (e.g. `network/`, which defines the types every other scope consumes) sorts
# last, the earlier commits reference code that history hasn't introduced yet.
#
# order_split_groups_by_dependency reorders split_group_keys so a scope that
# OTHER scopes reference by name commits first. Controlled by
# gitbasher.commit-split-order (auto = on, alpha = legacy order).

load setup_suite

setup() {
    setup_test_repo
    GITBASHER_SKIP_INIT_QUERIES=1 source "${GITBASHER_ROOT}/scripts/init.sh"
    source "${GITBASHER_ROOT}/scripts/common.sh"
    source "${GITBASHER_ROOT}/scripts/commit.sh"
    cd "$TEST_REPO"
}

teardown() {
    cleanup_test_repo
}

# Stage a file with real content so the staged diff carries added lines the
# heuristic can scan for cross-scope references.
stage_content() {
    local path="$1"; shift
    mkdir -p "$(dirname "$path")"
    printf '%s\n' "$@" > "$path"
    git add "$path"
}

# Build the foundational `network` scope plus three dependents that each
# reference it. `network` itself references no sibling.
stage_network_changeset() {
    stage_content "network/provider.go" \
        "package network" \
        "type GRPCOptions struct{}" \
        "type NetworkProvider struct{}"
    stage_content "grpcconn/options.go" \
        "package grpcconn" \
        'import "example.com/proj/network"' \
        "var _ = network.GRPCOptions{}"
    stage_content "grpcsrv/grpcsrv.go" \
        "package grpcsrv" \
        'import "example.com/proj/network"' \
        "var _ = network.NetworkProvider{}"
    stage_content "httpsrv/httpsrv.go" \
        "package httpsrv" \
        'import "example.com/proj/network"' \
        "var _ = network.GRPCOptions{}"
}

@test "split order: foundational scope (network) commits first" {
    stage_network_changeset

    build_split_groups_from_staged
    # Sanity: git hands these back alphabetically, so network starts last.
    [ "${split_group_keys[0]}" = "grpcconn" ]
    [ "${split_group_keys[3]}" = "network" ]

    order_split_groups_by_dependency
    # network is referenced by the three sibling scopes, so it leads now.
    [ "${split_group_keys[0]}" = "network" ]
}

@test "split order: dependents keep their alphabetical order after the dependency" {
    stage_network_changeset

    build_split_groups_from_staged
    order_split_groups_by_dependency

    [ "${split_group_keys[0]}" = "network" ]
    # The three count-0 dependents keep the original (alphabetical) order.
    [ "${split_group_keys[1]}" = "grpcconn" ]
    [ "${split_group_keys[2]}" = "grpcsrv" ]
    [ "${split_group_keys[3]}" = "httpsrv" ]
}

@test "split order: commit-split-order=alpha keeps git's alphabetical order" {
    git config gitbasher.commit-split-order alpha
    stage_network_changeset

    build_split_groups_from_staged
    order_split_groups_by_dependency

    # Legacy behaviour: untouched, so network stays last.
    [ "${split_group_keys[0]}" = "grpcconn" ]
    [ "${split_group_keys[3]}" = "network" ]
}

@test "split order: no cross-references leaves the order unchanged" {
    # Three unrelated scopes that don't mention each other.
    stage_content "alpha/a.go" "package alpha" "var A = 1"
    stage_content "beta/b.go"  "package beta"  "var B = 2"
    stage_content "gamma/c.go" "package gamma" "var C = 3"

    build_split_groups_from_staged
    order_split_groups_by_dependency

    # Stable: identical scores preserve the alphabetical input order.
    [ "${split_group_keys[0]}" = "alpha" ]
    [ "${split_group_keys[1]}" = "beta" ]
    [ "${split_group_keys[2]}" = "gamma" ]
}

@test "split order: whole-word match avoids false positives (net vs network)" {
    # `netutil` mentions the bare word `network` -> it depends on network.
    # `network` mentions `netutil` only as a substring inside `netutilizer`,
    # which must NOT count as a reference (whole-word matching).
    stage_content "network/provider.go" \
        "package network" \
        "type netutilizer struct{}"
    stage_content "netutil/util.go" \
        "package netutil" \
        "var _ = network.Provider{}"

    build_split_groups_from_staged
    order_split_groups_by_dependency

    # network is referenced as a whole word; netutil is not -> network leads.
    [ "${split_group_keys[0]}" = "network" ]
    [ "${split_group_keys[1]}" = "netutil" ]
}

@test "split order: misc grab-bag never leads" {
    # Root-level file with no scope -> misc. A real dependency scope should
    # still come first even though misc may sort earlier alphabetically.
    stage_content "README.md" "# docs" "see network for details"
    stage_content "network/provider.go" "package network" "type T struct{}"
    stage_content "client/client.go" \
        "package client" \
        "var _ = network.T{}"

    build_split_groups_from_staged
    order_split_groups_by_dependency

    # network leads (referenced by client); misc is forced last.
    [ "${split_group_keys[0]}" = "network" ]
    last_idx=$(( ${#split_group_keys[@]} - 1 ))
    [ "${split_group_keys[$last_idx]}" = "misc" ]
}
