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
