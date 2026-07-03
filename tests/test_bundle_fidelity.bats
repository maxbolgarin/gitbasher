#!/usr/bin/env bats

# Dev-vs-release fidelity: the bundler strips comments and blank lines, and
# used to strip INSIDE multi-line strings too — so the released binary
# emitted different hook files and completion scripts than a dev run. These
# tests generate the emitted artifacts both ways and require byte equality.

load setup_suite

setup() {
    setup_test_repo
    cd "$TEST_REPO"
    BUNDLE="$BATS_TEST_TMPDIR/gitb-fidelity"
    (cd "$GITBASHER_ROOT" && bash dist/build.sh ./scripts/gitb.sh "$BUNDLE" dev)
    chmod +x "$BUNDLE"
}

teardown() {
    cleanup_test_repo
}

@test "bundle fidelity: created hook files are byte-identical to dev" {
    mkdir -p dev-repo bundle-repo
    (cd dev-repo && git init -q && git config user.email t@t && git config user.name t)
    (cd bundle-repo && git init -q && git config user.email t@t && git config user.name t)

    # Dev mode sources CWD-relative, so source from the repo root and cd
    # into the sandbox before creating the hook
    bash -c "
        cd '$GITBASHER_ROOT'
        source scripts/common.sh 2>/dev/null
        GITBASHER_SKIP_INIT_QUERIES=1 source scripts/init.sh 2>/dev/null
        source scripts/hooks.sh
        cd '$TEST_REPO/dev-repo'
        create_hook pre-commit pre-commit-lint
    " < /dev/null > /dev/null 2>&1 || true
    (cd bundle-repo && bash "$BUNDLE" hook create pre-commit pre-commit-lint < /dev/null > /dev/null 2>&1) || true

    dev_hook="dev-repo/.git/hooks/pre-commit"
    bundle_hook="bundle-repo/.git/hooks/pre-commit"
    [ -f "$dev_hook" ]
    [ -f "$bundle_hook" ]
    if ! diff -u "$dev_hook" "$bundle_hook"; then
        echo "released bundle generates different hook content than dev" >&2
        return 1
    fi
    # The template's explanatory comments must survive into the hook
    /usr/bin/grep -q "Add your custom logic here" "$bundle_hook" || \
        /usr/bin/grep -q "pre-commit checks" "$bundle_hook"
}

@test "bundle fidelity: bash completion output matches dev byte-for-byte" {
    git config --global gitbasher.completion.prompted "true" 2>/dev/null || true
    dev_out=$(bash -c "
        cd '$GITBASHER_ROOT'
        source scripts/common.sh 2>/dev/null
        GITBASHER_SKIP_INIT_QUERIES=1 source scripts/init.sh 2>/dev/null
        source scripts/completion.sh
        _gitb_bash_completion_content
    " 2>/dev/null < /dev/null)
    bundle_out=$(cd "$TEST_REPO" && bash "$BUNDLE" cfg auto print bash 2>/dev/null < /dev/null)
    [ -n "$dev_out" ]
    if [ "$dev_out" != "$bundle_out" ]; then
        diff <(printf '%s\n' "$dev_out") <(printf '%s\n' "$bundle_out") | /usr/bin/head -10 >&2
        return 1
    fi
}

@test "bundle fidelity: AI prompt paragraphs keep their blank-line separators" {
    # The grouping system prompt has blank lines between paragraphs; the
    # bundler used to delete them, silently changing what the model reads.
    /usr/bin/grep -q "A feature is defined by WHAT the change accomplishes" "$BUNDLE"
    /usr/bin/grep -B1 "A feature is defined by WHAT the change accomplishes" "$BUNDLE" | /usr/bin/head -1 | /usr/bin/grep -q '^$'
}

@test "bundle: version injection survives special characters" {
    SPECIAL="$BATS_TEST_TMPDIR/gitb-special"
    (cd "$GITBASHER_ROOT" && bash dist/build.sh ./scripts/gitb.sh "$SPECIAL" "1.0.0&x")
    /usr/bin/grep -q 'GITBASHER_VERSION="1.0.0&x"' "$SPECIAL"
}
