#!/usr/bin/env bats

# Tests for is_redundant_scope and strip_redundant_scope (commit.sh).
# Covers each Conventional Commit type with its singular/plural/synonym
# variants, plus subject formatting (breaking-change marker, multi-line
# body preservation, non-redundant scopes left alone).

load setup_suite

setup() {
    source_gitbasher_lite
    source "${GITBASHER_ROOT}/scripts/commit.sh"
}

# ===== is_redundant_scope: per-type matrix =====

@test "is_redundant_scope: feat matches feat/feats/feature/features" {
    is_redundant_scope feat feat
    is_redundant_scope feat feats
    is_redundant_scope feat feature
    is_redundant_scope feat features
}

@test "is_redundant_scope: fix matches fix/fixes/bugfix/bugfixes" {
    is_redundant_scope fix fix
    is_redundant_scope fix fixes
    is_redundant_scope fix bugfix
    is_redundant_scope fix bugfixes
}

@test "is_redundant_scope: refactor matches refactor/refactors/refactoring" {
    is_redundant_scope refactor refactor
    is_redundant_scope refactor refactors
    is_redundant_scope refactor refactoring
}

@test "is_redundant_scope: test matches test/tests/testing" {
    is_redundant_scope test test
    is_redundant_scope test tests
    is_redundant_scope test testing
}

@test "is_redundant_scope: docs matches doc/docs/documentation" {
    is_redundant_scope docs doc
    is_redundant_scope docs docs
    is_redundant_scope docs documentation
}

@test "is_redundant_scope: chore matches chore/chores" {
    is_redundant_scope chore chore
    is_redundant_scope chore chores
}

@test "is_redundant_scope: build matches build/builds/building" {
    is_redundant_scope build build
    is_redundant_scope build builds
    is_redundant_scope build building
}

@test "is_redundant_scope: ci matches ci/cicd/ci-cd" {
    is_redundant_scope ci ci
    is_redundant_scope ci cicd
    is_redundant_scope ci ci-cd
}

@test "is_redundant_scope: perf matches perf/performance/perfs" {
    is_redundant_scope perf perf
    is_redundant_scope perf performance
    is_redundant_scope perf perfs
}

@test "is_redundant_scope: style matches style/styles/styling" {
    is_redundant_scope style style
    is_redundant_scope style styles
    is_redundant_scope style styling
}

@test "is_redundant_scope: revert matches revert/reverts" {
    is_redundant_scope revert revert
    is_redundant_scope revert reverts
}

# ===== is_redundant_scope: case-insensitive =====

@test "is_redundant_scope: matches case-insensitively (Test/TESTS)" {
    is_redundant_scope Test Tests
    is_redundant_scope TEST TESTS
    is_redundant_scope test TESTING
}

# ===== is_redundant_scope: non-matches =====

@test "is_redundant_scope: empty scope is not redundant" {
    ! is_redundant_scope test ""
    ! is_redundant_scope feat ""
}

@test "is_redundant_scope: real scopes are kept" {
    ! is_redundant_scope feat auth
    ! is_redundant_scope fix api
    ! is_redundant_scope test commit
    ! is_redundant_scope docs readme
    ! is_redundant_scope refactor parser
    ! is_redundant_scope ci workflows
    ! is_redundant_scope build dist
    ! is_redundant_scope chore deps
    ! is_redundant_scope perf cache
    ! is_redundant_scope style formatting
    ! is_redundant_scope revert auth
}

@test "is_redundant_scope: cross-type tokens are not redundant" {
    # feat(test) is intentional — files in test/ for a new feature.
    ! is_redundant_scope feat tests
    ! is_redundant_scope fix docs
    ! is_redundant_scope test build
    ! is_redundant_scope refactor chore
}

@test "is_redundant_scope: unknown type with any scope is not redundant" {
    ! is_redundant_scope unknown unknown
    ! is_redundant_scope custom custom
}

# ===== strip_redundant_scope: subject rewriting =====

@test "strip_redundant_scope: drops redundant scope (test/tests)" {
    result=$(strip_redundant_scope "test(tests): add foo")
    [ "$result" = "test: add foo" ]
}

@test "strip_redundant_scope: drops redundant scope (docs/docs)" {
    result=$(strip_redundant_scope "docs(docs): clarify install instructions")
    [ "$result" = "docs: clarify install instructions" ]
}

@test "strip_redundant_scope: drops redundant scope for every type" {
    [ "$(strip_redundant_scope 'feat(features): foo')" = "feat: foo" ]
    [ "$(strip_redundant_scope 'fix(fixes): foo')" = "fix: foo" ]
    [ "$(strip_redundant_scope 'refactor(refactoring): foo')" = "refactor: foo" ]
    [ "$(strip_redundant_scope 'test(testing): foo')" = "test: foo" ]
    [ "$(strip_redundant_scope 'docs(documentation): foo')" = "docs: foo" ]
    [ "$(strip_redundant_scope 'chore(chores): foo')" = "chore: foo" ]
    [ "$(strip_redundant_scope 'build(building): foo')" = "build: foo" ]
    [ "$(strip_redundant_scope 'ci(cicd): foo')" = "ci: foo" ]
    [ "$(strip_redundant_scope 'perf(performance): foo')" = "perf: foo" ]
    [ "$(strip_redundant_scope 'style(styling): foo')" = "style: foo" ]
    [ "$(strip_redundant_scope 'revert(reverts): foo')" = "revert: foo" ]
}

@test "strip_redundant_scope: preserves breaking-change marker" {
    result=$(strip_redundant_scope "feat(features)!: add new API")
    [ "$result" = "feat!: add new API" ]
}

@test "strip_redundant_scope: leaves non-redundant scope alone" {
    result=$(strip_redundant_scope "feat(auth): add login")
    [ "$result" = "feat(auth): add login" ]
}

@test "strip_redundant_scope: leaves no-scope subject alone" {
    result=$(strip_redundant_scope "test: add coverage")
    [ "$result" = "test: add coverage" ]
}

@test "strip_redundant_scope: preserves multi-line body" {
    input=$'test(tests): add coverage\n\nbody explaining why\nmore body'
    expected=$'test: add coverage\n\nbody explaining why\nmore body'
    result=$(strip_redundant_scope "$input")
    [ "$result" = "$expected" ]
}

@test "strip_redundant_scope: leaves non-conventional subject alone" {
    result=$(strip_redundant_scope "WIP debugging stuff")
    [ "$result" = "WIP debugging stuff" ]
}

@test "strip_redundant_scope: leaves uppercase type subject alone" {
    # Strict Conventional Commits use lowercase types; uppercase implies
    # the user is opting out of the convention, so don't rewrite.
    result=$(strip_redundant_scope "Test(tests): add foo")
    [ "$result" = "Test(tests): add foo" ]
}

# ===== clean_ai_commit_message: integration =====

@test "clean_ai_commit_message: trims quotes/whitespace and strips redundant scope" {
    result=$(clean_ai_commit_message '"  test(tests): add foo  "')
    [ "$result" = "test: add foo" ]
}

@test "clean_ai_commit_message: leaves clean non-redundant message unchanged" {
    result=$(clean_ai_commit_message "feat(auth): add login")
    [ "$result" = "feat(auth): add login" ]
}
