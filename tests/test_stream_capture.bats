#!/usr/bin/env bats

# stream_or_capture_git runs a command, streaming its --progress output to the
# terminal when interactive while still capturing combined stdout+stderr and the
# exit code for downstream parsing. Under BATS there is no TTY, so these tests
# exercise the silent-capture fallback path: output/code/shown are set via the
# caller-named variables, and --progress is stripped so it can't pollute the
# captured text. Live streaming needs a real TTY and is verified end-to-end.

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
