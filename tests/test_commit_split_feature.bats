#!/usr/bin/env bats

# Tests for AI FEATURE-based commit splitting (group_files_by_feature_with_ai)
# and the AI-primary orchestration in try_offer_commit_split.
#
# Background: the split used to group staged files by FOLDER/scope, fragmenting a
# single logical feature that spanned several folders into one commit per folder.
# The AI now groups by feature (reading the real diff) as the primary path, with
# the folder heuristic kept only as a fallback. These tests lock that in:
#   - files in different folders that form one feature land in one group;
#   - the actual diff is sent to the model (not just file paths);
#   - a genuine AI failure falls back to the pre-computed folder groups;
#   - a single-feature verdict collapses to one group (caller then won't split);
#   - AI grouping runs even when the folder heuristic already looks "strong".

load setup_suite

setup() {
    setup_test_repo
    GITBASHER_SKIP_INIT_QUERIES=1 source "${GITBASHER_ROOT}/scripts/init.sh"
    source "${GITBASHER_ROOT}/scripts/common.sh"
    source "${GITBASHER_ROOT}/scripts/ai.sh"
    source "${GITBASHER_ROOT}/scripts/commit.sh"
    cd "$TEST_REPO"
}

teardown() {
    cleanup_test_repo
}

# Stage a file with given content (creating parent dirs as needed).
stage_file() {
    local path="$1" content="${2:-x}"
    mkdir -p "$(dirname "$path")"
    printf '%s\n' "$content" > "$path"
    git add "$path"
}

@test "feature grouping: cross-folder files sharing a feature land in one group" {
    stage_file "api/login.go"     "auth login"
    stage_file "web/session.js"   "auth session"
    stage_file "api/invoice.go"   "billing invoice"
    stage_file "web/checkout.js"  "billing checkout"

    # AI returns a FEATURE grouping: auth spans api+web, billing spans api+web —
    # i.e. grouped by purpose, not by folder.
    call_ai_api() {
        printf 'auth\tapi/login.go\nauth\tweb/session.js\nbilling\tapi/invoice.go\nbilling\tweb/checkout.js\n'
    }

    group_files_by_feature_with_ai
    local rc=$?
    [ "$rc" -eq 0 ]

    [ "${#split_group_keys[@]}" -eq 2 ]
    [[ " ${split_group_keys[*]} " == *" auth "* ]]
    [[ " ${split_group_keys[*]} " == *" billing "* ]]

    local auth_files billing_files
    auth_files=$(gmap_get split_groups "auth")
    billing_files=$(gmap_get split_groups "billing")

    # auth = api/login.go + web/session.js (two different folders, one feature)
    [[ "$auth_files" == *"api/login.go"* ]]
    [[ "$auth_files" == *"web/session.js"* ]]
    # billing = api/invoice.go + web/checkout.js
    [[ "$billing_files" == *"api/invoice.go"* ]]
    [[ "$billing_files" == *"web/checkout.js"* ]]
}

@test "feature grouping: the actual diff is sent to the model, not just file paths" {
    stage_file "api/login.go" "UNIQUE_DIFF_MARKER_12345"

    local captured="${BATS_TEST_TMPDIR:-/tmp}/captured_prompt.txt"
    # Capture the user prompt ($2) and return a valid single-file TSV so the
    # function still succeeds.
    call_ai_api() {
        printf '%s' "$2" > "$captured"
        printf 'auth\tapi/login.go\n'
    }

    group_files_by_feature_with_ai

    local prompt
    prompt=$(cat "$captured")
    [[ "$prompt" == *"<diff>"* ]]
    [[ "$prompt" == *"UNIQUE_DIFF_MARKER_12345"* ]]
    # A real unified diff has a hunk header — proof it's diff content, not a stat.
    [[ "$prompt" == *"@@"* ]]
}

@test "feature grouping: AI failure leaves the folder heuristic groups intact" {
    stage_file "api/a.go" "a"
    stage_file "web/b.js" "b"

    # Pretend the folder heuristic already produced these two groups.
    gmap_clear split_groups
    gmap_set split_groups "api" "api/a.go"
    gmap_set split_groups "web" "web/b.js"
    split_group_keys=(api web)

    call_ai_api() { return 1; }

    # An `if` guard so bats doesn't abort on the intentional non-zero return.
    local rc=0
    if ! group_files_by_feature_with_ai; then rc=1; fi
    [ "$rc" -ne 0 ]

    # Fallback groups untouched.
    [ "${#split_group_keys[@]}" -eq 2 ]
    [[ " ${split_group_keys[*]} " == *" api "* ]]
    [[ " ${split_group_keys[*]} " == *" web "* ]]
}

@test "feature grouping: full type(scope) prefixes are normalized to the bare scope" {
    stage_file "content/de.md" "de text"
    stage_file "content/en.md" "en text"
    stage_file "misc.txt"      "misc"

    # Some models (observed with gemini-3.5-flash) answer with the full
    # conventional-commit prefix instead of the bare scope when the repo's
    # recent commits all look like "docs(reflection): ..." — the parser must
    # extract the scope token rather than reject every line and fall back.
    call_ai_api() {
        printf 'docs(reflection)\tcontent/de.md\ndocs(reflection):\tcontent/en.md\nchore:\tmisc.txt\n'
    }

    group_files_by_feature_with_ai
    local rc=$?
    [ "$rc" -eq 0 ]

    [ "${#split_group_keys[@]}" -eq 2 ]
    [[ " ${split_group_keys[*]} " == *" reflection "* ]]
    [[ " ${split_group_keys[*]} " == *" chore "* ]]

    local reflection_files
    reflection_files=$(gmap_get split_groups "reflection")
    [[ "$reflection_files" == *"content/de.md"* ]]
    [[ "$reflection_files" == *"content/en.md"* ]]
    [[ "$(gmap_get split_groups "chore")" == "misc.txt" ]]
}

@test "feature grouping: single-feature verdict collapses to one group" {
    stage_file "a.go" "one"
    stage_file "b.go" "feature"
    stage_file "c.go" "together"

    # AI decides everything is one feature.
    call_ai_api() {
        printf 'refactor\ta.go\nrefactor\tb.go\nrefactor\tc.go\n'
    }

    group_files_by_feature_with_ai
    local rc=$?
    [ "$rc" -eq 0 ]

    # One group means the caller (try_offer_commit_split) declines to split.
    [ "${#split_group_keys[@]}" -eq 1 ]
    [[ " ${split_group_keys[*]} " == *" refactor "* ]]
}

@test "orchestration: AI grouping runs when 3+ folder scopes are involved" {
    # Three clearly-separated folders → the gate lets the AI regroup by feature.
    stage_file "api/a.go" "a"
    stage_file "web/b.js" "b"
    stage_file "cli/c.sh" "c"

    git config gitbasher.commit-auto-split "ask"
    git config gitbasher.commit-ai-grouping "auto"
    llm="true"
    current_branch="main"
    push=""

    check_ai_available() { return 0; }
    group_files_by_feature_with_ai() {
        echo "AI-GROUPING-CALLED"
        gmap_clear split_groups
        gmap_set split_groups "featA" "api/a.go"
        gmap_set split_groups "featB" "web/b.js"
        split_group_keys=(featA featB)
        return 0
    }
    perform_commit_split() {
        echo "split-performed"
        return 0
    }

    # force_split + auto_yes so no interactive prompt.
    run try_offer_commit_split "true" "true"

    assert_success
    [[ "$output" == *"AI-GROUPING-CALLED"* ]]
    [[ "$output" == *"split-performed"* ]]
}

@test "orchestration: only 2 folder scopes (auto) skip AI, use folder split" {
    # Two folders → an obvious folder split; the gate must NOT spend an AI call.
    stage_file "api/a.go" "a"
    stage_file "web/b.js" "b"

    git config gitbasher.commit-auto-split "ask"
    git config gitbasher.commit-ai-grouping "auto"
    llm="true"
    current_branch="main"
    push=""

    check_ai_available() { return 0; }
    group_files_by_feature_with_ai() {
        echo "AI-GROUPING-CALLED"
        return 0
    }
    perform_commit_split() {
        echo "split-performed"
        return 0
    }

    run try_offer_commit_split "true" "true"

    assert_success
    [[ "$output" != *"AI-GROUPING-CALLED"* ]]
    [[ "$output" == *"split-performed"* ]]
}

@test "orchestration: commit-ai-grouping=always forces AI even at 2 scopes" {
    stage_file "api/a.go" "a"
    stage_file "web/b.js" "b"

    git config gitbasher.commit-auto-split "ask"
    git config gitbasher.commit-ai-grouping "always"
    llm="true"
    current_branch="main"
    push=""

    check_ai_available() { return 0; }
    group_files_by_feature_with_ai() {
        echo "AI-GROUPING-CALLED"
        gmap_clear split_groups
        gmap_set split_groups "featA" "api/a.go"
        gmap_set split_groups "featB" "web/b.js"
        split_group_keys=(featA featB)
        return 0
    }
    perform_commit_split() {
        echo "split-performed"
        return 0
    }

    run try_offer_commit_split "true" "true"

    assert_success
    [[ "$output" == *"AI-GROUPING-CALLED"* ]]
}

@test "feature grouping: a few unassigned files are placed by folder, not discarded" {
    stage_file "api/login.go"    "auth"
    stage_file "web/session.js"  "auth"
    stage_file "api/invoice.go"  "billing"
    stage_file "web/checkout.js" "billing"
    stage_file "api/report.go"   "reporting"   # the model will "forget" this one

    # Populate the folder heuristic so leftovers have somewhere to land.
    build_split_groups_from_staged

    # Model returns only 4 of 5 files (drops api/report.go) — 20%, within budget.
    call_ai_api() {
        printf 'auth\tapi/login.go\nauth\tweb/session.js\nbilling\tapi/invoice.go\nbilling\tweb/checkout.js\n'
    }

    group_files_by_feature_with_ai
    local rc=$?
    [ "$rc" -eq 0 ]

    # The AI's feature groups survived...
    [[ " ${split_group_keys[*]} " == *" auth "* ]]
    [[ " ${split_group_keys[*]} " == *" billing "* ]]
    # ...and the dropped file is still assigned somewhere (folder-placed), not lost.
    local all_files k
    all_files=""
    for k in "${split_group_keys[@]}"; do
        all_files="${all_files}"$'\n'"$(gmap_get split_groups "$k")"
    done
    [[ "$all_files" == *"api/report.go"* ]]
}

@test "feature grouping: dropping many files falls back with a reason" {
    stage_file "a.go" "a"
    stage_file "b.go" "b"
    stage_file "c.go" "c"
    stage_file "d.go" "d"
    stage_file "e.go" "e"

    # Root files collapse to a single "misc" group (return 1); we only need the
    # side effects, so ignore the status.
    build_split_groups_from_staged || true

    # Model returns only 1 of 5 (drops 4 → 80% unmatched, over the 20% budget).
    call_ai_api() { printf 'x\ta.go\n'; }

    local ai_grouping_fail_reason=""
    local rc=0
    if ! group_files_by_feature_with_ai; then rc=1; fi
    [ "$rc" -eq 1 ]
    [[ "$ai_grouping_fail_reason" == *"of 5 files unassigned"* ]]
}

@test "feature grouping: API error falls back with an API-error reason" {
    stage_file "a.go" "a"
    call_ai_api() { return 1; }

    local ai_grouping_fail_reason=""
    local rc=0
    if ! group_files_by_feature_with_ai; then rc=1; fi
    [ "$rc" -eq 1 ]
    [[ "$ai_grouping_fail_reason" == *"API error"* ]]
}

@test "orchestration: non-AI split (no llm) never calls the AI grouping" {
    stage_file "api/a.go" "a"
    stage_file "web/b.js" "b"

    git config gitbasher.commit-auto-split "ask"
    git config gitbasher.commit-ai-grouping "auto"
    llm=""
    current_branch="main"
    push=""

    check_ai_available() { return 0; }
    group_files_by_feature_with_ai() {
        echo "AI-GROUPING-CALLED"
        return 0
    }
    perform_commit_split() {
        echo "split-performed"
        return 0
    }

    run try_offer_commit_split "true" "true"

    assert_success
    [[ "$output" != *"AI-GROUPING-CALLED"* ]]
    [[ "$output" == *"split-performed"* ]]
}
