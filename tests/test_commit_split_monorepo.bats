#!/usr/bin/env bats

# Regression tests for split-commit scope assignment in monorepo layouts.
#
# Repro from a real `gitb c ffp` run: 25 files spread across services/{bff,
# help, main-bot, vip-bot, vip, whale}/... were lumped into a single
# `services` scope, while two files at depth 4 (services/bff/internal/
# external/, services/bff/internal/handler/) became their own scopes. The
# user wanted the service name as the scope (bff, main-bot, vip-bot, ...).
#
# Two fixes land here:
#   1. detect_scopes_from_staged_files filters monorepo containers
#      (services, apps, packages, modules, components, cmd, internal) so
#      the *next* path component becomes the candidate scope.
#   2. build_split_groups_from_staged walks each file's path shallow → deep
#      and picks the SHALLOWEST matching scope, instead of priority-order
#      winner — so a deep-but-popular candidate like `rubrics` doesn't
#      steal files away from the per-service scopes (`main-bot`, `vip-bot`).

load setup_suite

setup() {
    setup_test_repo
    source "${GITBASHER_ROOT}/scripts/common.sh"
    source "${GITBASHER_ROOT}/scripts/commit.sh"
    cd "$TEST_REPO"
}

teardown() {
    cleanup_test_repo
}

stage() {
    local path="$1"
    mkdir -p "$(dirname "$path")"
    : > "$path"
    git add "$path"
}

@test "monorepo: 'services' is filtered; service name becomes the scope" {
    stage "services/bff/cmd/bff/main.go"
    stage "services/bff/internal/handler/webhook.go"
    stage "services/main-bot/config.py"
    stage "services/main-bot/prompts.py"

    detect_scopes_from_staged_files
    [[ "$detected_scopes" != *"services"* ]]
    [[ "$detected_scopes" == *"bff"* ]]
    [[ "$detected_scopes" == *"main-bot"* ]]
}

@test "monorepo: 'cmd' and 'internal' Go containers are filtered" {
    stage "services/bff/cmd/bff/main.go"
    stage "services/bff/internal/handler/webhook.go"
    stage "services/bff/internal/external/telegram/sender.go"

    detect_scopes_from_staged_files
    [[ "$detected_scopes" != *"cmd"* ]]
    [[ "$detected_scopes" != *"internal"* ]]
    [[ "$detected_scopes" == *"bff"* ]]
}

@test "monorepo: 'apps' and 'packages' containers are filtered" {
    stage "apps/web/src/index.ts"
    stage "apps/mobile/src/index.ts"
    stage "packages/shared/util.ts"

    detect_scopes_from_staged_files
    [[ "$detected_scopes" != *"apps"* ]]
    [[ "$detected_scopes" != *"packages"* ]]
}

@test "monorepo: shallowest matching scope wins per file (bff over handler)" {
    # Two files in services/bff/internal/handler/. With the old logic,
    # `handler` (depth 4) sometimes won as scope. With the new walk-shallow
    # rule, `bff` (depth 2) wins for every file under bff/.
    stage "services/bff/cmd/bff/main.go"
    stage "services/bff/internal/handler/webhook.go"
    stage "services/bff/internal/handler/poller.go"
    stage "services/bff/internal/external/telegram/sender.go"
    stage "services/main-bot/config.py"
    stage "services/main-bot/prompts.py"

    build_split_groups_from_staged
    # Every bff-prefixed file lands in the bff group (or a parent that takes
    # precedence — services is filtered, so bff is the next match).
    [ -n "${split_groups[bff]:-}" ]
    bff_files=$(printf '%s' "${split_groups[bff]}" | grep -c '^services/bff/')
    [ "$bff_files" -eq 4 ]
}

@test "monorepo: rubrics under different bots stay with their bot, not pooled" {
    # Rubrics dir appears under both main-bot and vip-bot. With the old
    # priority-order logic, `rubrics` (high count) could outrank the bot
    # name. The shallowest-match rule keeps each rubric file with its bot.
    stage "services/main-bot/rubrics/morning.py"
    stage "services/main-bot/rubrics/breaking_news.py"
    stage "services/main-bot/rubrics/whale_alert.py"
    stage "services/vip-bot/rubrics/lab_signal.py"
    stage "services/vip-bot/rubrics/vip_lab.py"
    stage "services/vip-bot/rubrics/vip_signal.py"

    build_split_groups_from_staged
    [ -n "${split_groups[main-bot]:-}" ]
    [ -n "${split_groups[vip-bot]:-}" ]
    main_count=$(printf '%s' "${split_groups[main-bot]}" | grep -c '^services/main-bot/')
    vip_count=$(printf '%s' "${split_groups[vip-bot]}" | grep -c '^services/vip-bot/')
    [ "$main_count" -eq 3 ]
    [ "$vip_count" -eq 3 ]
    # And no `rubrics` scope at all.
    [ -z "${split_groups[rubrics]:-}" ]
}

@test "monorepo: filename-shaped dirs at depth 4+ no longer beat top-level scopes" {
    # Mirrors the real repro: external/ and handler/ at depth 4 shouldn't
    # steal a top-level scope's files away. They CAN exist as scopes if
    # nothing shallower matches, but bff/main-bot/etc. take priority.
    stage "services/bff/internal/external/telegram/httpclient.go"
    stage "services/bff/internal/external/telegram/sender.go"
    stage "services/bff/internal/handler/webhook.go"
    stage "services/bff/cmd/bff/main.go"
    # Need a second scope for build_split_groups_from_staged to return 0.
    stage "services/main-bot/config.py"

    build_split_groups_from_staged
    # All four bff-prefixed files belong to bff, not external or handler.
    [ -n "${split_groups[bff]:-}" ]
    bff_files=$(printf '%s' "${split_groups[bff]}" | grep -c '^services/bff/')
    [ "$bff_files" -eq 4 ]
    # And no external/handler scope was created for files that have a
    # shallower match available.
    [ -z "${split_groups[external]:-}" ]
    [ -z "${split_groups[handler]:-}" ]
}

@test "monorepo: 'scripts' is filtered; sub-tool dir or filename stem wins" {
    # `scripts/` is a generic source container, so it gets peeled like
    # `lib/`. Files with a sub-dir (scripts/llm_comparison/...) land under
    # the sub-dir name. One-off scripts (scripts/build_release.sh) fall
    # back to the filename stem (build_release).
    stage "scripts/llm_comparison/multimodel.py"
    stage "scripts/llm_comparison/results.json"
    stage "scripts/build_release.sh"
    # Second scope required for the split to be considered "meaningful".
    stage "services/bff/main.go"

    build_split_groups_from_staged
    # `scripts` itself must not be a scope (it's filtered).
    [ -z "${split_groups[scripts]:-}" ]
    # llm_comparison takes the two sub-dir files.
    [ -n "${split_groups[llm_comparison]:-}" ]
    [ "$(printf '%s' "${split_groups[llm_comparison]}" | grep -c .)" -eq 2 ]
    # build_release.sh becomes scope `build_release` via stem fallback.
    [ -n "${split_groups[build_release]:-}" ]
}

@test "stem fallback: scripts/commit.sh produces 'commit' scope" {
    # Gitbasher's own repo case: a one-off file under scripts/ should map
    # to the filename stem, not to misc and not to a vanished `scripts`.
    stage "scripts/commit.sh"
    stage "tests/test_commit.bats"

    build_split_groups_from_staged
    [ -z "${split_groups[scripts]:-}" ]
    [ -n "${split_groups[commit]:-}" ]
    [ -n "${split_groups[tests]:-}" ]
}

@test "stem fallback: skipped dirs at depth 1 trigger filename stem" {
    # Generic source dirs (src, lib, scripts, bin) trigger the stem
    # fallback when nothing else matches.
    stage "lib/auth.ts"
    stage "src/router.go"
    stage "bin/serve.sh"
    # Secondary scope so the split is meaningful.
    stage "tests/test_a.py"

    build_split_groups_from_staged
    [ -z "${split_groups[lib]:-}" ]
    [ -z "${split_groups[src]:-}" ]
    [ -z "${split_groups[bin]:-}" ]
    [ -n "${split_groups[auth]:-}" ]
    [ -n "${split_groups[router]:-}" ]
    [ -n "${split_groups[serve]:-}" ]
}

@test "stem fallback: generic stems (main, index, init) still go to misc" {
    # The stem fallback skips uninformative names so they don't pollute
    # the scope list with `index`, `main`, `init`, etc.
    stage "scripts/main.sh"
    stage "src/index.ts"
    stage "lib/utils.ts"
    # Secondary scope so the split is meaningful.
    stage "tests/test_a.py"

    build_split_groups_from_staged
    # All three generic-stem files should land in misc, not as their own
    # scope (we don't want main/index/utils as commit scopes).
    [ -z "${split_groups[main]:-}" ]
    [ -z "${split_groups[index]:-}" ]
    [ -z "${split_groups[utils]:-}" ]
    [ -n "${split_groups[misc]:-}" ]
    misc_count=$(printf '%s' "${split_groups[misc]}" | grep -c .)
    [ "$misc_count" -ge 3 ]
}

@test "stem fallback: root-level files still go to misc, not their stem" {
    # Files with no directory (Makefile, README.md, package.json) should
    # not become their-own-stem scopes. They go to misc as before.
    stage "Makefile"
    stage "README.md"
    stage "package.json"
    # Secondary scope.
    stage "tests/test_a.py"

    build_split_groups_from_staged
    [ -z "${split_groups[makefile]:-}" ]
    [ -z "${split_groups[readme]:-}" ]
    [ -z "${split_groups[package]:-}" ]
    [ -n "${split_groups[misc]:-}" ]
}

@test "monorepo: lib/<package> still surfaces the package name as scope" {
    # `lib` was already filtered before this change. Verify the next-level
    # package name comes through as expected.
    stage "lib/crypto_shared/config_base.py"
    stage "lib/crypto_shared/telegram_client.py"
    stage "lib/crypto_shared/approval_workflow.py"

    detect_scopes_from_staged_files
    [[ "$detected_scopes" != *" lib "* && "$detected_scopes" != "lib "* && "$detected_scopes" != *" lib" && "$detected_scopes" != "lib" ]]
    [[ "$detected_scopes" == *"crypto_shared"* ]]
}

@test "monorepo: file with no matching scope falls back to misc" {
    stage "services/whale/agent.py"
    stage "services/help/help_bot.py"
    stage "deploy/envs/.env.example"
    stage "scripts/foo.sh"
    stage "scripts/bar.sh"

    build_split_groups_from_staged
    # whale and help only have 1 file each; if scopes_arr cuts them out,
    # they fall back to misc. Either way they must NOT land under
    # `services` (which is filtered).
    if [ -n "${split_groups[services]:-}" ]; then
        echo "services should not exist as a scope" >&2
        return 1
    fi
}
