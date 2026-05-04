#!/usr/bin/env bats

# Unit tests for dist/build.sh — the bundler that produces dist/gitb.
#
# What we verify:
#   - The `source <file>` lines in the entry script are inlined.
#   - The output bundle has no remaining `source` lines.
#   - Single-line comments are stripped (build.sh's `sed '/^[[:space:]]*#\{1,3\}[ !].*$/d'`).
#   - Blank lines are stripped.
#   - The shebang is preserved at line 1.
#   - GITBASHER_VERSION="dev" is rewritten to the requested version.
#   - The script fails fast under set -euo pipefail when given a bad input
#     (we ship a corrupt input and expect a non-zero exit, not a half-written file).

load setup_suite

setup() {
    BUILD_TEST_DIR=$(mktemp -d)
    export BUILD_TEST_DIR
    cp "${GITBASHER_ROOT}/dist/build.sh" "${BUILD_TEST_DIR}/build.sh"
}

teardown() {
    [ -n "$BUILD_TEST_DIR" ] && [ -d "$BUILD_TEST_DIR" ] && rm -rf "$BUILD_TEST_DIR"
}

# Build a tiny fixture script tree under BUILD_TEST_DIR/scripts and run the
# bundler against it. Returns the path of the produced bundle.
_run_build() {
    local entry="$1" out="$2" version="${3-}"
    cd "$BUILD_TEST_DIR"
    if [ -n "$version" ]; then
        bash ./build.sh "$entry" "$out" "$version"
    else
        bash ./build.sh "$entry" "$out"
    fi
}

@test "build.sh: bundles a single source line" {
    mkdir -p "${BUILD_TEST_DIR}/scripts"
    cat > "${BUILD_TEST_DIR}/scripts/lib.sh" <<'EOF'
function lib_fn { echo "from lib"; }
EOF
    cat > "${BUILD_TEST_DIR}/scripts/main.sh" <<'EOF'
#!/usr/bin/env bash
GITBASHER_VERSION="dev"
source scripts/lib.sh
lib_fn
EOF

    _run_build "scripts/main.sh" "out.sh" ""

    [ -f "${BUILD_TEST_DIR}/out.sh" ]
    # No source line should remain in the bundle.
    ! grep -q "^source " "${BUILD_TEST_DIR}/out.sh"
    # The library function must have been inlined.
    grep -q "function lib_fn" "${BUILD_TEST_DIR}/out.sh"
}

@test "build.sh: shebang stays at line 1" {
    mkdir -p "${BUILD_TEST_DIR}/scripts"
    cat > "${BUILD_TEST_DIR}/scripts/main.sh" <<'EOF'
#!/usr/bin/env bash
GITBASHER_VERSION="dev"
echo "hi"
EOF

    _run_build "scripts/main.sh" "out.sh"
    [ "$(head -1 "${BUILD_TEST_DIR}/out.sh")" = "#!/usr/bin/env bash" ]
}

@test "build.sh: strips single-line comments" {
    mkdir -p "${BUILD_TEST_DIR}/scripts"
    cat > "${BUILD_TEST_DIR}/scripts/main.sh" <<'EOF'
#!/usr/bin/env bash
GITBASHER_VERSION="dev"
# this comment must be stripped
echo "kept"
## also stripped
echo "also kept"
EOF

    _run_build "scripts/main.sh" "out.sh"
    ! grep -q "this comment must be stripped" "${BUILD_TEST_DIR}/out.sh"
    grep -q '^echo "kept"$' "${BUILD_TEST_DIR}/out.sh"
    grep -q '^echo "also kept"$' "${BUILD_TEST_DIR}/out.sh"
}

@test "build.sh: strips blank lines" {
    mkdir -p "${BUILD_TEST_DIR}/scripts"
    cat > "${BUILD_TEST_DIR}/scripts/main.sh" <<'EOF'
#!/usr/bin/env bash
GITBASHER_VERSION="dev"

echo "no_blanks_above_or_below"

EOF

    _run_build "scripts/main.sh" "out.sh"
    # Blank lines collapsed.
    ! grep -q "^[[:space:]]*$" "${BUILD_TEST_DIR}/out.sh"
}

@test "build.sh: substitutes version when provided" {
    mkdir -p "${BUILD_TEST_DIR}/scripts"
    cat > "${BUILD_TEST_DIR}/scripts/main.sh" <<'EOF'
#!/usr/bin/env bash
GITBASHER_VERSION="dev"
echo "$GITBASHER_VERSION"
EOF

    _run_build "scripts/main.sh" "out.sh" "v4.0.0-test"
    grep -q 'GITBASHER_VERSION="v4.0.0-test"' "${BUILD_TEST_DIR}/out.sh"
    ! grep -q 'GITBASHER_VERSION="dev"' "${BUILD_TEST_DIR}/out.sh"
}

@test "build.sh: leaves version alone when third arg is empty" {
    mkdir -p "${BUILD_TEST_DIR}/scripts"
    cat > "${BUILD_TEST_DIR}/scripts/main.sh" <<'EOF'
#!/usr/bin/env bash
GITBASHER_VERSION="dev"
EOF

    _run_build "scripts/main.sh" "out.sh"
    grep -q 'GITBASHER_VERSION="dev"' "${BUILD_TEST_DIR}/out.sh"
}

@test "build.sh: bundle runs end-to-end" {
    mkdir -p "${BUILD_TEST_DIR}/scripts"
    cat > "${BUILD_TEST_DIR}/scripts/lib.sh" <<'EOF'
function greet { echo "hello $1"; }
EOF
    cat > "${BUILD_TEST_DIR}/scripts/main.sh" <<'EOF'
#!/usr/bin/env bash
GITBASHER_VERSION="dev"
source scripts/lib.sh
greet "world"
EOF

    _run_build "scripts/main.sh" "out.sh"
    output=$(bash "${BUILD_TEST_DIR}/out.sh")
    [ "$output" = "hello world" ]
}

@test "build.sh: fails when entry file does not exist" {
    cd "$BUILD_TEST_DIR"
    run bash ./build.sh /nonexistent/path/to/entry.sh out.sh
    [ "$status" -ne 0 ]
}

@test "build.sh: fails when sourced file does not exist" {
    mkdir -p "${BUILD_TEST_DIR}/scripts"
    cat > "${BUILD_TEST_DIR}/scripts/main.sh" <<'EOF'
#!/usr/bin/env bash
source scripts/missing.sh
EOF

    cd "$BUILD_TEST_DIR"
    run bash ./build.sh "scripts/main.sh" "out.sh"
    # set -euo pipefail in build.sh means a `cat` of a missing file aborts.
    [ "$status" -ne 0 ]
}

@test "build.sh: handles paths with spaces in the output filename" {
    mkdir -p "${BUILD_TEST_DIR}/scripts"
    cat > "${BUILD_TEST_DIR}/scripts/main.sh" <<'EOF'
#!/usr/bin/env bash
echo "ok"
EOF

    cd "$BUILD_TEST_DIR"
    bash ./build.sh "scripts/main.sh" "out file.sh"
    [ -f "${BUILD_TEST_DIR}/out file.sh" ]
    output=$(bash "${BUILD_TEST_DIR}/out file.sh")
    [ "$output" = "ok" ]
}
