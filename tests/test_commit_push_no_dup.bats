#!/usr/bin/env bats

# Regression: `gitb c <push-mode>` against a clean tree with unpushed commits
# must not duplicate the unpushed-commit list, the GIT PUSH header, or the
# "Pushing..." banner. commit.sh used to half-render the push UI itself and
# then call push_script, producing two of everything.

load setup_suite

setup() {
    setup_test_repo
    source_gitbasher
    source "${GITBASHER_ROOT}/scripts/commit.sh"
    source "${GITBASHER_ROOT}/scripts/push.sh"
    setup_remote_repo

    # Land one commit locally that is ahead of origin/main.
    create_test_file "ahead.txt" "ahead of origin"
    git add ahead.txt
    git commit -m "feat: ahead of origin"

    # Re-resolve the globals init.sh seeded — setup_remote_repo added the
    # remote after source_gitbasher ran.
    current_branch="main"
    main_branch="main"
    origin_name="origin"
}

teardown() {
    cleanup_remote_repo
    cleanup_test_repo
}

# Count occurrences of a literal substring in $output.
count_substr() {
    local needle="$1"
    awk -v n="$needle" 'BEGIN{c=0} { s=$0; while ((i=index(s,n))>0){c++; s=substr(s,i+length(n))} } END{print c}' <<<"$output"
}

@test "ffp on clean tree with unpushed commits delegates to push without duplicating UI" {
    run commit_script ffp

    [ "$status" -eq 0 ]
    [[ "$output" == *"Nothing to commit"* ]]
    [[ "$output" == *"But there are unpushed commits."* ]]
    [[ "$output" == *"GIT PUSH FAST"* ]]
    [[ "$output" == *"Pushed to origin/main"* ]]

    # Each of these used to render twice.
    pushing=$(count_substr "Pushing...")
    header=$(count_substr "Your branch is ahead")
    [ "$pushing" -eq 1 ] || { echo "Pushing... appeared $pushing times; expected 1"; echo "$output"; return 1; }
    [ "$header" -eq 1 ]  || { echo "list header appeared $header times; expected 1"; echo "$output"; return 1; }
}

@test "non-auto-accept push mode on clean tree delegates to interactive push_script" {
    # `gitb c p` → push="true" without auto_accept; push_script (no arg) owns
    # the prompt. Feed 'y' to accept.
    run commit_script p <<< "y"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Nothing to commit"* ]]
    [[ "$output" == *"But there are unpushed commits."* ]]
    [[ "$output" == *"GIT PUSH"* ]]
    [[ "$output" == *"Do you want to push"* ]]
    [[ "$output" == *"Pushed to origin/main"* ]]

    pushing=$(count_substr "Pushing...")
    header=$(count_substr "Your branch is ahead")
    [ "$pushing" -eq 1 ] || { echo "Pushing... appeared $pushing times; expected 1"; echo "$output"; return 1; }
    [ "$header" -eq 1 ]  || { echo "list header appeared $header times; expected 1"; echo "$output"; return 1; }
}
