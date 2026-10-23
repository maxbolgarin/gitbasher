#!/usr/bin/env bats

# SSH key unlocking (scripts/ssh.sh): a passphrase-protected key that is not
# loaded in an agent used to make ssh prompt under the progress spinner, which
# wiped the prompt every frame — "Fetching" then spun forever. Network
# commands to OpenSSH remotes now run with BatchMode=yes first and unlock a
# locked key on an authentication failure.
#
# The pure helpers (URL parsing, settings, classifiers) are tested directly.
# Tests that need OpenSSH (ssh -G, ssh-keygen, ssh-agent) skip without it.
# The retry loop (ssh_stream_git) is driven through stubbed runners, since
# BATS has no terminal for the real spinner path.

load setup_suite

setup() {
    export GIT_CONFIG_GLOBAL="$BATS_TEST_TMPDIR/gitconfig-global"
    : > "$GIT_CONFIG_GLOBAL"
    setup_test_repo
    source_gitbasher_lite
    cd "$TEST_REPO"
    origin_name="origin"
    # Keep the gitbasher agent of these tests away from the real one. A short
    # path: socket paths are capped near 104 bytes, and macOS's
    # $BATS_TEST_TMPDIR under /var/folders gets close to that.
    XDG_RUNTIME_DIR=$(mktemp -d /tmp/gitb-test.XXXXXX)
    export XDG_RUNTIME_DIR
    chmod 700 "$XDG_RUNTIME_DIR"
    unset GIT_SSH GIT_SSH_COMMAND
}

teardown() {
    local sock
    for sock in "$XDG_RUNTIME_DIR/gitbasher/agent.sock" "${TEST_AGENT_SOCK:-}"; do
        [ -n "$sock" ] && [ -S "$sock" ] && SSH_AUTH_SOCK="$sock" ssh-add -D >/dev/null 2>&1
    done
    if [ -n "${TEST_AGENT_PIDS:-}" ]; then
        kill $TEST_AGENT_PIDS 2>/dev/null || true
    fi
    pkill -f "ssh-agent -s -a $XDG_RUNTIME_DIR" 2>/dev/null || true
    rm -rf "$XDG_RUNTIME_DIR"
    cleanup_test_repo
}

need_openssh() {
    command -v ssh >/dev/null 2>&1 && command -v ssh-keygen >/dev/null 2>&1 \
        && command -v ssh-agent >/dev/null 2>&1 && command -v ssh-add >/dev/null 2>&1 \
        || skip "OpenSSH client tools not installed"
}

# Keys + an ssh config file under the test dir; ssh reads it via -F
make_ssh_fixture() {
    need_openssh
    FIX="$BATS_TEST_TMPDIR/ssh"
    mkdir -p "$FIX"
    chmod 700 "$FIX"
    ssh-keygen -q -t ed25519 -N 'secret pass' -C locked -f "$FIX/locked"
    ssh-keygen -q -t ed25519 -N '' -C open -f "$FIX/open"
    cat > "$FIX/config" <<EOF
Host locked-host
  HostName 127.0.0.1
  User git
  IdentityFile $FIX/locked
  IdentitiesOnly yes
Host open-host
  HostName 127.0.0.1
  IdentityFile $FIX/open
Host both-host
  IdentityFile $FIX/open
  IdentityFile $FIX/locked
  IdentityFile $FIX/missing
Host none-agent
  IdentityFile $FIX/locked
  IdentityAgent none
Host path-agent
  IdentityFile $FIX/locked
  IdentityAgent $FIX/other.sock
Host jumped
  IdentityFile $FIX/open
  ProxyJump bastion
EOF
    export GIT_SSH_COMMAND="ssh -F $FIX/config"
}

# Start a throwaway agent for the test; sets TEST_AGENT_SOCK
start_test_agent() {
    local out
    out=$(ssh-agent -s)
    TEST_AGENT_SOCK=$(printf '%s\n' "$out" | sed -n 's/^SSH_AUTH_SOCK=\([^;]*\);.*/\1/p')
    TEST_AGENT_PIDS="${TEST_AGENT_PIDS:-} $(printf '%s\n' "$out" | sed -n 's/^SSH_AGENT_PID=\([0-9]*\);.*/\1/p')"
}

# Add a key to an agent non-interactively: the passphrase goes through a pipe
# to a tiny askpass helper (ssh-add uses askpass when stdin is not a terminal)
add_key_to_agent() {
    local sock="$1" key="$2" helper="$BATS_TEST_TMPDIR/askpass"
    printf '#!/bin/sh\nIFS= read -r p || exit 1\nprintf "%%s\\n" "$p"\n' > "$helper"
    chmod 700 "$helper"
    printf '%s\n' 'secret pass' | SSH_AUTH_SOCK="$sock" DISPLAY=gitb \
        SSH_ASKPASS="$helper" SSH_ASKPASS_REQUIRE=force ssh-add "$key" >/dev/null 2>&1
}


# ===== URL parsing =====

@test "ssh_url_target: scp-like URLs with and without a user" {
    [ "$(ssh_url_target 'git@github.com:max/repo.git')" = "git@github.com	" ]
    [ "$(ssh_url_target 'github.com:max/repo')" = "github.com	" ]
}

@test "ssh_url_target: ssh:// URLs keep the port" {
    [ "$(ssh_url_target 'ssh://git@host.com:2222/x/y.git')" = "git@host.com	2222" ]
    [ "$(ssh_url_target 'ssh://host.com/x')" = "host.com	" ]
    [ "$(ssh_url_target 'git+ssh://u@h/x')" = "u@h	" ]
    [ "$(ssh_url_target 'ssh+git://h:22/x')" = "h	22" ]
}

@test "ssh_url_target: bracketed IPv6 hosts" {
    [ "$(ssh_url_target 'ssh://u@[::1]:22/x')" = "u@::1	22" ]
    [ "$(ssh_url_target 'u@[fe80::1]:repo.git')" = "u@fe80::1	" ]
}

@test "ssh_url_target: rejects https, file and local paths" {
    ! ssh_url_target 'https://github.com/x/y.git'
    ! ssh_url_target 'file:///srv/repo.git'
    ! ssh_url_target '/srv/repo.git'
    ! ssh_url_target './dir:with-colon'
    ! ssh_url_target 'repo'
}


# ===== which remotes a command contacts =====

@test "git_network_urls: fetch and push use the remote's fetch / push URL" {
    git remote add origin git@example.com:a/b.git
    git remote set-url --push origin git@push.example.com:a/b.git
    [ "$(git_network_urls git fetch --progress origin)" = "git@example.com:a/b.git" ]
    [ "$(git_network_urls git push --progress -u origin main)" = "git@push.example.com:a/b.git" ]
    [ "$(git_network_urls git ls-remote origin refs/heads/main)" = "git@example.com:a/b.git" ]
    [ "$(git_network_urls git remote prune origin)" = "git@example.com:a/b.git" ]
}

@test "git_network_urls: no remote argument falls back to origin_name" {
    git remote add upstream git@up.example.com:a/b.git
    origin_name="upstream"
    [ "$(git_network_urls git fetch --progress --prune)" = "git@up.example.com:a/b.git" ]
}

@test "git_network_urls: --all and remote update list every remote" {
    git remote add origin git@one.example.com:a/b.git
    git remote add other https://two.example.com/a/b.git
    out=$(git_network_urls git fetch --all --progress)
    [[ "$out" == *"git@one.example.com:a/b.git"* ]]
    [[ "$out" == *"https://two.example.com/a/b.git"* ]]
    [ "$(git_network_urls git remote update | wc -l | tr -d ' ')" = "2" ]
}

@test "git_network_urls: clone uses its URL, a URL argument is used as-is" {
    [ "$(git_network_urls git clone --progress git@h:x.git dest)" = "git@h:x.git" ]
    [ "$(git_network_urls git fetch git@h:x.git main)" = "git@h:x.git" ]
}

@test "git_network_urls: local commands do not contact a remote" {
    ! git_network_urls git merge --ff-only origin/main
    ! git_network_urls git switch main
    ! git_network_urls git remote -v
    ! git_network_urls sh -c true
}


# ===== the ssh command git runs =====

@test "ssh_git_command: plain ssh by default" {
    [ "$(ssh_git_command)" = "ssh" ]
}

@test "ssh_git_command: GIT_SSH_COMMAND beats core.sshCommand" {
    git config core.sshCommand "ssh -i /k1"
    [ "$(ssh_git_command)" = "ssh -i /k1" ]
    [ "$(GIT_SSH_COMMAND='/usr/bin/ssh -i /k2' ssh_git_command)" = "/usr/bin/ssh -i /k2" ]
}

@test "ssh_git_command: GIT_SSH is a program path and gets quoted" {
    [ "$(GIT_SSH=/usr/bin/ssh ssh_git_command)" = "'/usr/bin/ssh'" ]
}

@test "ssh_git_command: other SSH clients are not handled" {
    ! GIT_SSH=/usr/bin/plink ssh_git_command
    ! GIT_SSH_COMMAND='sshpass -p x ssh' ssh_git_command
}


# ===== settings =====

@test "ssh unlock settings: defaults are agent and 1h" {
    [ "$(get_ssh_unlock_mode)" = "agent" ]
    [ "$(get_ssh_unlock_ttl)" = "1h" ]
}

@test "ssh unlock settings: invalid stored values fall back to the defaults" {
    git config gitbasher.ssh-unlock bogus
    git config gitbasher.ssh-unlock-ttl 1x
    [ "$(get_ssh_unlock_mode)" = "agent" ]
    [ "$(get_ssh_unlock_ttl)" = "1h" ]
}

@test "ssh unlock settings: set values round-trip" {
    set_ssh_unlock_mode gitb >/dev/null
    set_ssh_unlock_ttl 8h >/dev/null
    [ "$(get_ssh_unlock_mode)" = "gitb" ]
    [ "$(get_ssh_unlock_ttl)" = "8h" ]
}

@test "is_valid_ssh_ttl: accepts ssh time formats only" {
    for t in 1h 30m 1h30m 90 0 1d 2w 45s 1H; do
        is_valid_ssh_ttl "$t"
    done
    for t in "" 1x abc "1 h" -1 1.5h 99999999999999999; do
        ! is_valid_ssh_ttl "$t"
    done
}

@test "ssh_ttl_unlimited and ssh_unlock_short describe zero as no limit" {
    ssh_ttl_unlimited 0
    ssh_ttl_unlimited 0s
    ! ssh_ttl_unlimited 1h
    [ "$(ssh_ttl_phrase 1h)" = "for 1h" ]
    [ "$(ssh_ttl_phrase 0)" = "with no time limit" ]
    [ "$(ssh_unlock_short agent 1h)" = "agent, 1h" ]
    [ "$(ssh_unlock_short gitb 0)" = "gitb, no limit" ]
    [ "$(ssh_unlock_short command 1h)" = "command" ]
}


# ===== ssh config helpers =====

@test "_ssh_expand_identity_path: expands ~ and the %-tokens ssh allows" {
    out=$(HOME=/home/me USER=me _ssh_expand_identity_path '~/.ssh/%h_%r_%p_%%_%u_%d_%n_%C' host.com git 2222 alias)
    [ "$out" = "/home/me/.ssh/host.com_git_2222_%_me_/home/me_alias_%C" ]
}

@test "_ssh_agent_spec: SSH_AUTH_SOCK, none, a path, an env var" {
    [ "$(_ssh_agent_spec '')" = "env" ]
    [ "$(_ssh_agent_spec 'SSH_AUTH_SOCK')" = "env" ]
    [ "$(_ssh_agent_spec 'none')" = "none" ]
    [ "$(_ssh_agent_spec '/run/agent.sock')" = "path:/run/agent.sock" ]
    [ "$(MY_AGENT=/x.sock _ssh_agent_spec '$MY_AGENT')" = "path:/x.sock" ]
}

@test "ssh_key_label: shortens the home directory" {
    [ "$(HOME=/home/me ssh_key_label /home/me/.ssh/id_ed25519)" = "~/.ssh/id_ed25519" ]
    [ "$(HOME=/home/me ssh_key_label /etc/key)" = "/etc/key" ]
}


# ===== failure classifiers =====

@test "ssh_auth_failed / ssh_hostkey_unknown: classify BatchMode failures" {
    ssh_auth_failed "git@github.com: Permission denied (publickey)."
    ssh_auth_failed "Received disconnect: Too many authentication failures"
    ! ssh_auth_failed "ssh: connect to host x port 22: Connection refused"
    ssh_hostkey_unknown "Host key verification failed."
    ! ssh_hostkey_unknown "Host key for x has changed and you have requested strict checking.
Host key verification failed."
}

@test "is_network_error: an ssh auth failure is not retried as a network error" {
    out="git@github.com: Permission denied (publickey).
fatal: Could not read from remote repository."
    is_auth_error "$out"
    ! is_network_error "$out"
    is_network_error "ssh: connect to host x port 22: Connection timed out
fatal: Could not read from remote repository."
}

@test "_progress_label: ls-remote and remote prune" {
    [ "$(_progress_label git ls-remote origin)" = "Checking remote" ]
    [ "$(_progress_label git remote prune origin)" = "Pruning remote branches" ]
    [ "$(_progress_label git remote update)" = "Updating remotes" ]
}

@test "_git_may_prompt_for_credentials: an ssh remote ssh_stream_git did not take may prompt" {
    git remote add origin git@example.com:a/b.git
    _git_may_prompt_for_credentials git fetch --progress origin
    git remote set-url origin "$BATS_TEST_TMPDIR/local.git"
    ! _git_may_prompt_for_credentials git fetch --progress origin
}


# ===== key state against real OpenSSH =====

@test "ssh_key_state: open, locked and unusable key files" {
    make_ssh_fixture
    [ "$(ssh_key_state "$FIX/open" "")" = "open" ]
    [ "$(ssh_key_state "$FIX/locked" "")" = "locked" ]
    echo "not a key" > "$FIX/junk"
    chmod 600 "$FIX/junk"
    [ "$(ssh_key_state "$FIX/junk" "")" = "unusable" ]
}

@test "ssh_inspect_urls: reads identity files and the agent from ssh -G" {
    make_ssh_fixture
    spec=""; keys=""; host=""
    ssh_inspect_urls spec keys host "locked-host:repo.git"
    [ "$spec" = "env" ]
    [ "$host" = "locked-host" ]
    [ "$keys" = "$FIX/locked"$'\n' ]
    # Missing files are dropped, the order is kept
    ssh_inspect_urls spec keys host "both-host:repo.git"
    [ "$keys" = "$FIX/open"$'\n'"$FIX/locked"$'\n' ]
    ssh_inspect_urls spec keys host "none-agent:repo.git"
    [ "$spec" = "none" ]
    ssh_inspect_urls spec keys host "path-agent:repo.git"
    [ "$spec" = "path:$FIX/other.sock" ]
}

@test "ssh_inspect_urls: flags hosts reached through ProxyJump" {
    make_ssh_fixture
    proxied=""
    ssh_inspect_urls spec keys host "jumped:repo.git" proxied
    [ "$proxied" = "true" ]
    ssh_inspect_urls spec keys host "open-host:repo.git" proxied
    [ -z "$proxied" ]
}

@test "ssh_inspect_urls: 1 without an SSH URL, 2 for another SSH client" {
    make_ssh_fixture
    run ssh_inspect_urls spec keys host "https://example.com/a/b.git"
    [ "$status" -eq 1 ]
    GIT_SSH_COMMAND="" GIT_SSH=/usr/bin/plink run ssh_inspect_urls spec keys host "locked-host:repo.git"
    [ "$status" -eq 2 ]
}

@test "ssh_locked_keys: a locked key stops counting once an agent holds it" {
    make_ssh_fixture
    keys="$FIX/open"$'\n'"$FIX/locked"$'\n'
    [ "$(ssh_locked_keys "$keys" "")" = "$FIX/locked" ]
    start_test_agent
    [ "$(ssh_locked_keys "$keys" "$TEST_AGENT_SOCK")" = "$FIX/locked" ]
    add_key_to_agent "$TEST_AGENT_SOCK" "$FIX/locked"
    [ -z "$(ssh_locked_keys "$keys" "$TEST_AGENT_SOCK")" ]
    # Any of several agents counts (ssh's own plus gitbasher's)
    [ -z "$(ssh_locked_keys "$keys" "" "/nonexistent.sock" "$TEST_AGENT_SOCK")" ]
}


# ===== gitbasher-managed agents =====

@test "ssh_start_gitb_agent: private 0700 directory, reused on the next call" {
    need_openssh
    sock=$(ssh_start_gitb_agent)
    [ "$sock" = "$XDG_RUNTIME_DIR/gitbasher/agent.sock" ]
    [ -S "$sock" ]
    [ "$(stat -c '%a' "${sock%/*}" 2>/dev/null || stat -f '%Lp' "${sock%/*}")" = "700" ]
    ssh_agent_alive "$sock"
    [ "$(ssh_start_gitb_agent)" = "$sock" ]
    [ "$(pgrep -f "ssh-agent -s -a $sock" | wc -l | tr -d ' ')" = "1" ]
}

@test "ssh_private_route: routes to the gitbasher agent only when it holds a key" {
    make_ssh_fixture
    keys="$FIX/locked"$'\n'
    sock=$(ssh_start_gitb_agent)
    [ -z "$(ssh_private_route env "$keys")" ]
    add_key_to_agent "$sock" "$FIX/locked"
    [ "$(ssh_private_route env "$keys")" = "$sock" ]
    # A host with its own IdentityAgent ignores SSH_AUTH_SOCK: no routing
    [ -z "$(ssh_private_route none "$keys")" ]
    [ -z "$(ssh_private_route "path:/x.sock" "$keys")" ]
}

@test "ssh_start_command_agent: the agent is killed once its gitb process exits" {
    need_openssh
    sock=$(bash -c "
        source '$GITBASHER_ROOT/scripts/common.sh'
        GITBASHER_SKIP_INIT_QUERIES=1 source '$GITBASHER_ROOT/scripts/init.sh'
        source '$GITBASHER_ROOT/scripts/ssh.sh'
        ssh_start_command_agent && printf '%s' \"\$gitb_ssh_command_agent\"
    ")
    [ -n "$sock" ]
    for _ in 1 2 3 4 5 6; do
        ssh_agent_alive "$sock" || break
        sleep 1
    done
    ! ssh_agent_alive "$sock"
}


# ===== the retry loop (ssh_stream_git) with stubbed runners =====
# RUNS records each run as "label|route|ssh command"; OUTCOMES feeds the
# results ("code|output" per line); UNLOCK_RC feeds ssh_unlock_key's answers.

stub_stream() {
    RUNS=""
    STUB_LOCKED="${STUB_LOCKED:-/k/locked}"
    ssh_inspect_urls() {
        printf -v "$1" '%s' "env"
        printf -v "$2" '%s' "/k/locked"$'\n'
        printf -v "$3" '%s' "git@example.com"
        if [ -n "${5:-}" ]; then printf -v "$5" '%s' "${STUB_PROXIED:-}"; fi
    }
    ssh_private_route() { printf '%s' "${STUB_ROUTE:-}"; STUB_ROUTE=""; }
    ssh_locked_keys() { printf '%s\n' "$STUB_LOCKED"; }
    ssh_unlock_key() {
        local rc="${UNLOCK_RC%% *}"
        UNLOCK_RC="${UNLOCK_RC#* }"
        UNLOCKED_KEYS+="$1 "
        return "$rc"
    }
    _stream_git_once() {
        RUNS+="$1|$2|$3"$'\n'
        local next="${OUTCOMES%%$'\n'*}"
        OUTCOMES="${OUTCOMES#*$'\n'}"
        __code="${next%%|*}"
        __output="${next#*|}"
        __shown=""
    }
    git remote add origin git@example.com:a/b.git
}

run_stream() {
    __output="" __code="" __shown=""
    ssh_stream_git git fetch --progress origin
}

@test "ssh_stream_git: success on the first BatchMode run" {
    stub_stream
    OUTCOMES=$'0|ok\n'
    run_stream
    [ "$__code" = "0" ]
    [ "$RUNS" = "Fetching||ssh -o BatchMode=yes"$'\n' ]
}

@test "ssh_stream_git: a locked key is unlocked, then the command retried" {
    stub_stream
    OUTCOMES=$'128|git@example.com: Permission denied (publickey).\n0|ok\n'
    UNLOCK_RC="0 "
    run_stream
    [ "$__code" = "0" ]
    [ "$UNLOCKED_KEYS" = "/k/locked " ]
    [ "$(printf '%s' "$RUNS" | grep -c 'BatchMode=yes')" = "2" ]
}

@test "ssh_stream_git: skipping the only key reports the failure without a plain run" {
    stub_stream
    OUTCOMES=$'128|git@example.com: Permission denied (publickey).\n'
    UNLOCK_RC="1 "
    run_stream
    [ "$__code" = "128" ]
    [[ "$__output" == *"Permission denied"* ]]
    [ "$(printf '%s' "$RUNS" | wc -l | tr -d ' ')" = "1" ]
}

@test "ssh_stream_git: skipping a key offers the next one without another run" {
    stub_stream
    STUB_LOCKED=$'/k/one\n/k/two'
    OUTCOMES=$'128|Permission denied (publickey).\n0|ok\n'
    UNLOCK_RC="1 0 "
    run_stream
    [ "$__code" = "0" ]
    [ "$UNLOCKED_KEYS" = "/k/one /k/two " ]
    [ "$(printf '%s' "$RUNS" | wc -l | tr -d ' ')" = "2" ]
}

@test "ssh_stream_git: an unknown host key is retried without spinner or BatchMode" {
    stub_stream
    OUTCOMES=$'128|Host key verification failed.\n0|ok\n'
    run_stream
    [ "$__code" = "0" ]
    [ "$(printf '%s' "$RUNS" | sed -n '2p')" = "||" ]
}

@test "ssh_stream_git: nothing to unlock means a plain run so ssh can ask" {
    stub_stream
    STUB_LOCKED=""
    OUTCOMES=$'128|Permission denied (password).\n0|ok\n'
    run_stream
    [ "$__code" = "0" ]
    [ "$(printf '%s' "$RUNS" | sed -n '2p')" = "||" ]
}

@test "ssh_stream_git: no agent to keep the key in means a plain run" {
    stub_stream
    OUTCOMES=$'128|Permission denied (publickey).\n0|ok\n'
    UNLOCK_RC="2 "
    run_stream
    [ "$__code" = "0" ]
    [ "$(printf '%s' "$RUNS" | sed -n '2p')" = "||" ]
}

@test "ssh_stream_git: a failed run through gitbasher's agent is retried with ssh's own" {
    stub_stream
    STUB_ROUTE="/run/gitb.sock"
    OUTCOMES=$'128|Permission denied (publickey).\n0|ok\n'
    run_stream
    [ "$__code" = "0" ]
    [ "$(printf '%s' "$RUNS" | sed -n '1p')" = "Fetching|/run/gitb.sock|ssh -o BatchMode=yes" ]
    [ "$(printf '%s' "$RUNS" | sed -n '2p')" = "Fetching||ssh -o BatchMode=yes" ]
}

@test "ssh_stream_git: no spinner through ProxyJump, where BatchMode does not reach" {
    stub_stream
    STUB_PROXIED="true"
    OUTCOMES=$'0|ok\n'
    run_stream
    [ "$RUNS" = "||ssh -o BatchMode=yes"$'\n' ]
}

@test "ssh_stream_git: a non-auth failure is returned as is" {
    stub_stream
    OUTCOMES=$'128|ssh: connect to host example.com port 22: Connection refused\n'
    run_stream
    [ "$__code" = "128" ]
    [ "$(printf '%s' "$RUNS" | wc -l | tr -d ' ')" = "1" ]
}

@test "ssh_stream_git: does not apply to mode off, https, or local commands" {
    stub_stream
    git config gitbasher.ssh-unlock off
    ! ssh_stream_git git fetch --progress origin
    git config --unset gitbasher.ssh-unlock
    git remote set-url origin https://example.com/a/b.git
    unset -f ssh_inspect_urls
    source "$GITBASHER_ROOT/scripts/ssh.sh"
    ! ssh_stream_git git fetch --progress origin
    ! ssh_stream_git git merge --ff-only origin/main
    [ -z "$RUNS" ]
}


# ===== remote_branch_commit =====

@test "remote_branch_commit: the branch's commit on the remote, exact name only" {
    setup_remote_repo
    remote_branch_commit sha main
    [ "$sha" = "$(git rev-parse HEAD)" ]
    remote_branch_commit sha missing
    [ -z "$sha" ]
    # `ls-remote --heads origin feature` would also match team/feature
    git push -q origin HEAD:refs/heads/team/feature
    remote_branch_commit sha feature
    [ -z "$sha" ]
    remote_branch_commit sha team/feature
    [ "$sha" = "$(git rev-parse HEAD)" ]
    cleanup_remote_repo
}


# ===== status for gitb cfg ssh =====

@test "print_ssh_key_status: https remote has no key to unlock" {
    git remote add origin https://example.com/a/b.git
    run print_ssh_key_status origin
    [[ "$output" == *"does not use SSH"* ]]
}

@test "print_ssh_key_status: shows locked, open and unlocked keys" {
    make_ssh_fixture
    git remote add origin both-host:repo.git
    unset SSH_AUTH_SOCK
    run print_ssh_key_status origin
    [[ "$output" == *"open"*"no passphrase"* ]]
    [[ "$output" == *"locked"*"locked"* ]]
    sock=$(ssh_start_gitb_agent)
    add_key_to_agent "$sock" "$FIX/locked"
    run print_ssh_key_status origin
    [[ "$output" == *"unlocked for gitbasher"* ]]
}
