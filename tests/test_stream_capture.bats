#!/usr/bin/env bats

# stream_or_capture_git runs a command, capturing combined stdout+stderr and
# the exit code for downstream parsing. Interactive runs reveal the captured
# stream live only when the transfer outlives a quiet window, so quick pushes
# and fetches stay noise-free. Under BATS there is no TTY, so the
# stream_or_capture_git tests exercise the silent-capture fallback path; the
# quiet-window logic itself lives in _stream_transfer_after_delay, which is
# TTY-independent and tested directly below.

load setup_suite

setup() {
    source_gitbasher_lite
}

@test "stream_or_capture_git: fallback captures output and zero exit, shown empty" {
    stream_or_capture_git out code shown printf 'hello world'
    [ "$out" = "hello world" ]
    [ "$code" = "0" ]
    [ -z "$shown" ]
}

@test "stream_or_capture_git: strips --progress in the capture fallback" {
    stream_or_capture_git out code shown printf '%s|' a --progress b
    [ "$out" = "a|b|" ]
    [ "$code" = "0" ]
}

@test "stream_or_capture_git: propagates a non-zero exit code" {
    stream_or_capture_git out code shown sh -c 'echo boom; exit 3'
    [ "$out" = "boom" ]
    [ "$code" = "3" ]
}

@test "stream_or_capture_git: captures stderr merged with stdout" {
    stream_or_capture_git out code shown sh -c 'echo err 1>&2'
    [ "$out" = "err" ]
    [ "$code" = "0" ]
}

# ===== the quiet window (_stream_transfer_after_delay) =====

@test "quiet window: fast transfer prints nothing" {
    capture="$BATS_TEST_TMPDIR/capture"
    shown_out="$BATS_TEST_TMPDIR/shown"
    bash -c 'printf "Enumerating objects: 15, done.\nWriting objects: 100%%\n"' >"$capture" 2>&1 &
    revealed=""
    _stream_transfer_after_delay $! "$capture" 8 revealed > "$shown_out"
    [ -z "$revealed" ]
    [ ! -s "$shown_out" ]
}

@test "quiet window: slow transfer reveals output live and keeps the exit code" {
    capture="$BATS_TEST_TMPDIR/capture"
    shown_out="$BATS_TEST_TMPDIR/shown"
    bash -c 'echo phase1; sleep 1; echo phase2; exit 3' >"$capture" 2>&1 &
    revealed=""
    code=0
    _stream_transfer_after_delay $! "$capture" 1 revealed > "$shown_out" || code=$?
    [ "$code" -eq 3 ]
    [ "$revealed" = "true" ]
    grep -q "phase1" "$shown_out"
    grep -q "phase2" "$shown_out"
}

@test "quiet window: output written after the last poll is still revealed" {
    capture="$BATS_TEST_TMPDIR/capture"
    shown_out="$BATS_TEST_TMPDIR/shown"
    # Sleep first so the reveal starts, then write and exit immediately —
    # the final flush after wait() must pick up the tail bytes.
    bash -c 'echo early; sleep 1; printf "late-final"' >"$capture" 2>&1 &
    revealed=""
    _stream_transfer_after_delay $! "$capture" 1 revealed > "$shown_out"
    [ "$revealed" = "true" ]
    grep -q "late-final" "$shown_out"
}

@test "quiet window: fast failure stays silent so the caller prints the error" {
    capture="$BATS_TEST_TMPDIR/capture"
    shown_out="$BATS_TEST_TMPDIR/shown"
    bash -c 'echo "fatal: does not appear to be a git repository" >&2; exit 128' >"$capture" 2>&1 &
    revealed=""
    code=0
    _stream_transfer_after_delay $! "$capture" 8 revealed > "$shown_out" || code=$?
    [ "$code" -eq 128 ]
    [ -z "$revealed" ]
    [ ! -s "$shown_out" ]
    grep -q "fatal" "$capture"
}

# ===== spinner / progress helpers =====

@test "strip_git_progress: drops \\r-updated progress meters, keeps messages" {
    local cr=$'\r'
    out=$(strip_git_progress "remote: Counting objects:  50% (1/2)${cr}remote: Counting objects: 100% (2/2), done.
Receiving objects: 100% (2/2), done.
From /tmp/remote
 * branch            main       -> FETCH_HEAD
Updating files: 100% (3/3), done.")
    [ "$out" = "From /tmp/remote
 * branch            main       -> FETCH_HEAD" ]
}

@test "strip_git_progress: keeps errors and remote messages" {
    out=$(strip_git_progress "remote: Create a pull request for 'feat':
error: failed to push some refs")
    [[ "$out" == *"Create a pull request"* ]]
    [[ "$out" == *"failed to push some refs"* ]]
}

@test "_progress_label: maps git commands to readable labels" {
    [ "$(_progress_label git fetch --progress origin)" = "Fetching" ]
    [ "$(_progress_label git push --progress)" = "Pushing" ]
    [ "$(_progress_label git switch --progress main)" = "Checking out files" ]
    [ "$(_progress_label git stash pop)" = "Applying stash" ]
    [ "$(_progress_label git stash push -m x)" = "Stashing" ]
    [ "$(_progress_label git gc)" = "Running git gc" ]
}

@test "run_with_spinner: without a TTY passes stdout and exit code through" {
    slow_fn() { echo "result"; return 4; }
    code=0
    out=$(run_with_spinner "Waiting" slow_fn) || code=$?
    [ "$out" = "result" ]
    [ "$code" = "4" ]
}

@test "quiet window: label without a TTY draws no spinner" {
    capture="$BATS_TEST_TMPDIR/capture"
    err_out="$BATS_TEST_TMPDIR/err"
    bash -c 'sleep 1.2; echo done' >"$capture" 2>&1 &
    revealed=""
    _stream_transfer_after_delay $! "$capture" 100 revealed "Fetching" 2> "$err_out" >/dev/null
    [ -z "$revealed" ]
    [ ! -s "$err_out" ]
}

@test "_git_may_prompt_for_credentials: https remote without a helper may prompt" {
    repo="$BATS_TEST_TMPDIR/repo"
    git init -q "$repo"
    cd "$repo"
    git remote add origin https://example.com/x/y.git
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
    unset GIT_ASKPASS GIT_TERMINAL_PROMPT
    origin_name=origin
    _git_may_prompt_for_credentials git fetch --progress origin
    ! GIT_TERMINAL_PROMPT=0 _git_may_prompt_for_credentials git fetch origin
    ! _git_may_prompt_for_credentials git switch main
    git config credential.helper store
    ! _git_may_prompt_for_credentials git push --progress origin main
}
