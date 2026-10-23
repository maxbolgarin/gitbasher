#!/usr/bin/env bash

### Script for unlocking passphrase-protected SSH keys during network commands
# Read README.md to get more information how to use it
# Use this script only with gitbasher


### ===== SSH KEY UNLOCKING =====
### A key locked with a passphrase and not loaded in an agent makes ssh ask
### for the passphrase on the terminal. Under the progress spinner that prompt
### was wiped every frame, so "Fetching" spun forever. Network commands to
### OpenSSH remotes therefore run with BatchMode=yes first: ssh fails fast
### instead of prompting, which keeps the spinner safe. When the failure is a
### locked key, gitbasher asks for the passphrase and retries; ssh-add reads
### it from the terminal itself, so it never passes through gitbasher.
###
### gitbasher.ssh-unlock picks where an unlocked key is kept:
###   agent    your ssh-agent for gitbasher.ssh-unlock-ttl (default) — git,
###            ssh and other tools can use it until it expires
###   gitb     a gitbasher-only ssh-agent for gitbasher.ssh-unlock-ttl
###   command  a throwaway ssh-agent that exits with the current gitb command
###   off      never unlock: ssh asks itself, and the spinner stays off


### How gitbasher unlocks passphrase-protected SSH keys (see above)
function get_ssh_unlock_mode {
    local v
    v=$(get_config_value gitbasher.ssh-unlock "agent")
    case "$v" in
        agent|gitb|command|off) echo "$v" ;;
        *) echo "agent" ;;
    esac
}
function set_ssh_unlock_mode {
    set_config_value gitbasher.ssh-unlock "$1"
}


### How long an unlocked key stays in an agent (modes agent and gitb), in
### ssh's time format: 30m, 1h, 1h30m, 1d, plain seconds; 0 = no time limit.
function get_ssh_unlock_ttl {
    local v
    v=$(get_config_value gitbasher.ssh-unlock-ttl "1h")
    if is_valid_ssh_ttl "$v"; then echo "$v"; else echo "1h"; fi
}
function set_ssh_unlock_ttl {
    set_config_value gitbasher.ssh-unlock-ttl "$1"
}


### Whether $1 is a lifetime `ssh-add -t` accepts (ssh's TIME FORMATS)
function is_valid_ssh_ttl {
    local re='^([0-9]+[sSmMhHdDwW]?)+$'
    [ ${#1} -le 16 ] && [[ "$1" =~ $re ]]
}

### Whether a lifetime means "no time limit" (0, 0s, 00m, ...)
function ssh_ttl_unlimited {
    local re='^(0+[sSmMhHdDwW]?)+$'
    [[ "$1" =~ $re ]]
}

### "for 1h" / "with no time limit"
function ssh_ttl_phrase {
    if ssh_ttl_unlimited "$1"; then
        echo "with no time limit"
    else
        echo "for $1"
    fi
}


### One-line description of a mode, for gitb cfg ssh
# $1: mode, $2: lifetime
function ssh_unlock_summary {
    case "$1" in
        agent)   echo "agent — unlocked keys stay in ssh-agent $(ssh_ttl_phrase "$2")" ;;
        gitb)    echo "gitb — unlocked keys stay in a gitbasher-only agent $(ssh_ttl_phrase "$2")" ;;
        command) echo "command — a key is unlocked for one gitb command, then forgotten" ;;
        off)     echo "off — ssh asks for the passphrase on every connection" ;;
    esac
}

### Short form for the configuration table: "agent, 1h", "gitb, no limit", "off"
# $1: mode, $2: lifetime
function ssh_unlock_short {
    case "$1" in
        agent|gitb)
            if ssh_ttl_unlimited "$2"; then echo "$1, no limit"; else echo "$1, $2"; fi ;;
        *) echo "$1" ;;
    esac
}


### A key path for messages, with $HOME shortened to ~
function ssh_key_label {
    # shellcheck disable=SC2088  # a literal ~ for display
    case "$1" in
        "$HOME"/*) printf '~/%s\n' "${1#"$HOME"/}" ;;
        *) printf '%s\n' "$1" ;;
    esac
}


### Remote URLs a network git command will contact, one per line
# $@: the command and its args ("git fetch ...", "git push ...", ...)
# Returns: 1 when the command does not talk to a remote
function git_network_urls {
    [ "$1" = "git" ] || return 1
    local sub="$2" arg target="" all="" push=""
    shift 2
    case "$sub" in
        fetch|pull|ls-remote) ;;
        push) push="--push" ;;
        remote)
            case "$1" in
                update) all="true" ;;
                prune) ;;
                *) return 1 ;;
            esac
            shift ;;
        clone)
            for arg in "$@"; do
                case "$arg" in
                    -*) ;;
                    *) printf '%s\n' "$arg"; return 0 ;;
                esac
            done
            return 1 ;;
        *) return 1 ;;
    esac
    for arg in "$@"; do
        case "$arg" in
            --all) all="true" ;;
            -*) ;;
            *) [ -z "$target" ] && target="$arg" ;;
        esac
    done
    if [ -n "$all" ]; then
        local remote
        while IFS= read -r remote; do
            [ -n "$remote" ] && git remote get-url ${push:+"$push"} "$remote" 2>/dev/null
        done < <(git remote 2>/dev/null)
        return 0
    fi
    target="${target:-${origin_name:-origin}}"
    # Not a configured remote: the argument is the URL itself
    git remote get-url ${push:+"$push"} "$target" 2>/dev/null || printf '%s\n' "$target"
}


### ssh's destination and port for an SSH remote URL, as "<[user@]host>\t<port>"
### (port may be empty). Follows git's rules: ssh://, git+ssh://, ssh+git://,
### or scp-like [user@]host:path where no slash comes before the colon.
# $1: remote URL
# Returns: 1 when the URL is not SSH (https, file, local path, ...)
function ssh_url_target {
    local url="$1" authority user="" hostport host port=""
    local bracketed='^(([^@/]*)@)?\[([^]/]+)\]:'
    case "$url" in
        ssh://*|git+ssh://*|ssh+git://*)
            authority="${url#*://}"
            authority="${authority%%/*}"
            if [[ "$authority" == *@* ]]; then
                user="${authority%@*}"
                hostport="${authority##*@}"
            else
                hostport="$authority"
            fi
            case "$hostport" in
                \[*\]:*) host="${hostport%%]*}"; host="${host#[}"; port="${hostport##*]:}" ;;
                \[*\]) host="${hostport#[}"; host="${host%]}" ;;
                *:*) host="${hostport%%:*}"; port="${hostport#*:}" ;;
                *) host="$hostport" ;;
            esac
            ;;
        *://*)
            return 1 ;;
        *)
            if [[ "$url" =~ $bracketed ]]; then
                user="${BASH_REMATCH[2]}"
                host="${BASH_REMATCH[3]}"
            else
                case "$url" in
                    *:*) ;;
                    *) return 1 ;;
                esac
                hostport="${url%%:*}"
                case "$hostport" in
                    */*|"") return 1 ;;
                esac
                if [[ "$hostport" == *@* ]]; then
                    user="${hostport%@*}"
                    host="${hostport##*@}"
                else
                    host="$hostport"
                fi
            fi
            ;;
    esac
    [ -n "$host" ] || return 1
    printf '%s%s\t%s\n' "${user:+$user@}" "$host" "$port"
}


### The ssh command line git runs for remotes (GIT_SSH_COMMAND, then
### core.sshCommand, then GIT_SSH, then plain ssh). Printed only when it is
### OpenSSH, whose -G and -o BatchMode gitbasher relies on.
# Returns: 1 for another SSH client (plink, wrappers, ...)
function ssh_git_command {
    local cmd prog
    if [ -n "${GIT_SSH_COMMAND:-}" ]; then
        cmd="$GIT_SSH_COMMAND"
    else
        cmd=$(git config --get core.sshCommand 2>/dev/null)
    fi
    if [ -n "$cmd" ]; then
        prog="${cmd%%[[:space:]]*}"
    elif [ -n "${GIT_SSH:-}" ]; then
        # GIT_SSH is a program path, not a command line: quote it for sh -c
        prog="$GIT_SSH"
        cmd="'${GIT_SSH//\'/\'\\\'\'}'"
    else
        prog="ssh"
        cmd="ssh"
    fi
    case "${prog##*/}" in
        ssh|ssh.exe) printf '%s\n' "$cmd" ;;
        *) return 1 ;;
    esac
}


### Effective ssh settings for a destination (`ssh -G`, no connection made)
# $1: ssh command line, $2: destination, $3: port (optional)
function _ssh_config_dump {
    if [ -n "$3" ]; then
        sh -c "$1 -G -p \"\$1\" \"\$2\"" sh "$3" "$2" </dev/null 2>/dev/null
    else
        sh -c "$1 -G \"\$1\"" sh "$2" </dev/null 2>/dev/null
    fi
}


### Normalize ssh's IdentityAgent value: "env" (SSH_AUTH_SOCK), "none", or
### "path:<socket>"
function _ssh_agent_spec {
    local v="$1" name
    local ident='^[A-Za-z_][A-Za-z0-9_]*$'
    case "$v" in
        ""|SSH_AUTH_SOCK|'$SSH_AUTH_SOCK'|'${SSH_AUTH_SOCK}') echo "env" ;;
        none) echo "none" ;;
        '$'*)
            name="${v#\$}"; name="${name#\{}"; name="${name%\}}"
            if [[ "$name" =~ $ident ]]; then
                echo "path:${!name}"
            else
                echo "path:$v"
            fi ;;
        *) echo "path:$v" ;;
    esac
}


### The agent socket ssh uses for an agent spec ("" when there is none)
function ssh_host_agent_socket {
    case "$1" in
        env) printf '%s\n' "${SSH_AUTH_SOCK:-}" ;;
        path:*) printf '%s\n' "${1#path:}" ;;
    esac
}


### Expand the ~ and %-tokens ssh allows in IdentityFile (`ssh -G` prints
### them raw). Unsupported tokens stay as-is, so such a file never exists.
# $1: path, $2: remote host, $3: remote user, $4: port, $5: host as given
function _ssh_expand_identity_path {
    local p="$1" out=""
    # shellcheck disable=SC2088  # matching a literal ~ prefix
    case "$p" in
        "~") p="$HOME" ;;
        "~/"*) p="$HOME/${p#\~/}" ;;
    esac
    while [ -n "$p" ]; do
        if [ "${p:0:1}" = "%" ] && [ ${#p} -ge 2 ]; then
            case "${p:1:1}" in
                %) out+="%" ;;
                d) out+="$HOME" ;;
                u) out+="${USER:-$(id -un 2>/dev/null)}" ;;
                i) out+="$(id -u 2>/dev/null)" ;;
                h) out+="$2" ;;
                r) out+="$3" ;;
                p) out+="$4" ;;
                n) out+="$5" ;;
                *) out+="${p:0:2}" ;;
            esac
            p="${p:2}"
        else
            out+="${p:0:1}"
            p="${p:1}"
        fi
    done
    printf '%s\n' "$out"
}


### Inspect how ssh authenticates to the hosts behind remote URLs
# $1: variable to receive the agent spec of the first host ("env", "none",
#     "path:<socket>")
# $2: variable to receive the identity files that exist, one per line, in
#     the order ssh tries them
# $3: variable to receive the first host, for messages ("git@github.com")
# $4: remote URLs, one per line (non-SSH ones are skipped)
# $5: optional variable to receive "true" when a host is reached through
#     ProxyJump / ProxyCommand
# Returns: 0 inspected, 1 no SSH URL, 2 ssh settings unreadable (not
#          OpenSSH, or a config ssh itself rejects)
function ssh_inspect_urls {
    local _si_agent_var="$1" _si_keys_var="$2" _si_host_var="$3" _si_urls="$4" _si_proxy_var="${5:-}"
    # Locals are prefixed: printf -v into a caller variable named like one of
    # them would set the local instead (e.g. callers pass "keys" and "host")
    local _si_cmd _si_url _si_target _si_dest _si_port _si_dump _si_name _si_val _si_ids _si_path
    local _si_agent="" _si_keys="" _si_host="" _si_hname _si_ruser _si_rport _si_host_agent _si_proxy=""
    _si_cmd=$(ssh_git_command) || return 2
    while IFS= read -r _si_url; do
        [ -n "$_si_url" ] || continue
        _si_target=$(ssh_url_target "$_si_url") || continue
        _si_dest="${_si_target%%$'\t'*}"
        _si_port="${_si_target#*$'\t'}"
        _si_dump=$(_ssh_config_dump "$_si_cmd" "$_si_dest" "$_si_port") || return 2
        _si_ids=""; _si_hname=""; _si_ruser=""; _si_rport=""; _si_host_agent=""
        while read -r _si_name _si_val; do
            case "$_si_name" in
                hostname) _si_hname="$_si_val" ;;
                user) _si_ruser="$_si_val" ;;
                port) _si_rport="$_si_val" ;;
                identityagent) _si_host_agent="$_si_val" ;;
                identityfile) _si_ids+="$_si_val"$'\n' ;;
                proxyjump|proxycommand) [ "$_si_val" != "none" ] && _si_proxy="true" ;;
            esac
        done <<< "$_si_dump"
        if [ -z "$_si_host" ]; then
            _si_host="$_si_dest"
            _si_agent=$(_ssh_agent_spec "$_si_host_agent")
        fi
        while IFS= read -r _si_val; do
            [ -n "$_si_val" ] || continue
            _si_path=$(_ssh_expand_identity_path "$_si_val" "$_si_hname" "$_si_ruser" "$_si_rport" "${_si_dest#*@}")
            [ -f "$_si_path" ] || continue
            case $'\n'"$_si_keys" in
                *$'\n'"$_si_path"$'\n'*) continue ;;
            esac
            _si_keys+="$_si_path"$'\n'
        done <<< "$_si_ids"
    done <<< "$_si_urls"
    [ -n "$_si_host" ] || return 1
    printf -v "$_si_agent_var" '%s' "$_si_agent"
    printf -v "$_si_keys_var" '%s' "$_si_keys"
    printf -v "$_si_host_var" '%s' "$_si_host"
    if [ -n "$_si_proxy_var" ]; then
        printf -v "$_si_proxy_var" '%s' "$_si_proxy"
    fi
}


### Whether an agent answers on a socket, with or without keys
function ssh_agent_alive {
    [ -n "$1" ] || return 1
    local code=0
    SSH_AUTH_SOCK="$1" ssh-add -l >/dev/null 2>&1 || code=$?
    [ "$code" -eq 0 ] || [ "$code" -eq 1 ]
}


### Fingerprints of the keys an agent holds, one per line
# $1: agent socket
# Returns: 1 when no agent answers there
function ssh_agent_fingerprints {
    [ -n "$1" ] || return 1
    local out code=0
    out=$(SSH_AUTH_SOCK="$1" ssh-add -l -E sha256 2>/dev/null) || code=$?
    case "$code" in
        0) printf '%s\n' "$out" | awk '{ print $2 }' ;;
        1) ;;
        *) return 1 ;;
    esac
}


### SHA256 fingerprint of a key file (reads only its public part)
function _ssh_key_fingerprint {
    ssh-keygen -l -E sha256 -f "$1" 2>/dev/null | awk '{ print $2; exit }'
}


### How a key file can be used right now
# $1: key file
# $2: fingerprints of keys loaded in the agent(s) ssh can use
# Prints: "agent" (loaded), "open" (no passphrase), "locked" (needs its
#         passphrase) or "unusable" (unreadable, bad permissions, not a key)
function ssh_key_state {
    local fp out
    if [ -n "$2" ]; then
        fp=$(_ssh_key_fingerprint "$1")
        if [ -n "$fp" ] && printf '%s\n' "$2" | grep -qxF -- "$fp"; then
            echo "agent"
            return
        fi
    fi
    # -P '' only tries an empty passphrase, so this never prompts
    if out=$(ssh-keygen -y -P '' -f "$1" 2>&1 >/dev/null); then
        echo "open"
    elif [[ "$out" == *passphrase* ]]; then
        echo "locked"
    else
        echo "unusable"
    fi
}


### Key files that would make ssh ask for a passphrase, in ssh's order
# $1: key files, one per line
# $2..: agent sockets whose keys count as unlocked (empty ones are skipped)
function ssh_locked_keys {
    local keys="$1" fps="" sock key
    shift
    for sock in "$@"; do
        [ -n "$sock" ] || continue
        fps+="$(ssh_agent_fingerprints "$sock")"$'\n'
    done
    while IFS= read -r key; do
        [ -n "$key" ] || continue
        if [ "$(ssh_key_state "$key" "$fps")" = "locked" ]; then
            printf '%s\n' "$key"
        fi
    done <<< "$keys"
}


### Socket of the gitbasher-only agent (mode gitb, and mode agent when no
### ssh-agent is running). It lives in a private per-user directory so the
### agent is found again by later gitb runs.
function ssh_gitb_agent_socket {
    local dir
    if [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -d "$XDG_RUNTIME_DIR" ] && [ -O "$XDG_RUNTIME_DIR" ]; then
        dir="${XDG_RUNTIME_DIR%/}/gitbasher"
    else
        dir="${TMPDIR:-/tmp}"
        dir="${dir%/}/gitbasher-$(id -u)"
    fi
    # Unix socket paths are capped at ~104 bytes (macOS)
    if [ ${#dir} -gt 90 ]; then
        dir="/tmp/gitbasher-$(id -u)"
    fi
    printf '%s/agent.sock\n' "$dir"
}


### Create (or verify) a directory only we can use: ours, not a symlink, 0700
function _ssh_private_dir {
    if [ ! -e "$1" ]; then
        mkdir -m 700 "$1" 2>/dev/null || return 1
    fi
    [ -d "$1" ] && [ ! -L "$1" ] && [ -O "$1" ] || return 1
    chmod 700 "$1" 2>/dev/null
}


### Start the gitbasher-only agent unless it is already running
# Prints: its socket
function ssh_start_gitb_agent {
    local sock
    sock=$(ssh_gitb_agent_socket)
    if ssh_agent_alive "$sock"; then
        printf '%s\n' "$sock"
        return 0
    fi
    command -v ssh-agent >/dev/null 2>&1 || return 1
    _ssh_private_dir "${sock%/*}" || return 1
    # A socket left behind by an agent that is gone (reboot, kill)
    rm -f "$sock"
    ssh-agent -s -a "$sock" >/dev/null 2>&1 || return 1
    ssh_agent_alive "$sock" || return 1
    printf '%s\n' "$sock"
}


### Start the throwaway agent of mode command (once per gitb run). A
### watchdog kills it as soon as this gitb process exits — not an EXIT trap,
### because commands install their own EXIT traps and would replace it.
# Sets: gitb_ssh_command_agent (its socket)
function ssh_start_command_agent {
    if [ -n "${gitb_ssh_command_agent:-}" ] && ssh_agent_alive "$gitb_ssh_command_agent"; then
        return 0
    fi
    command -v ssh-agent >/dev/null 2>&1 || return 1
    local out sock pid
    # -t: keys expire after an hour even if the watchdog never gets to run
    out=$(ssh-agent -s -t 3600 2>/dev/null) || return 1
    sock=$(printf '%s\n' "$out" | sed -n 's/^SSH_AUTH_SOCK=\([^;]*\);.*/\1/p')
    pid=$(printf '%s\n' "$out" | sed -n 's/^SSH_AGENT_PID=\([0-9]*\);.*/\1/p')
    if [ -z "$sock" ] || [ -z "$pid" ]; then
        return 1
    fi
    (
        trap '' INT HUP TERM
        while kill -0 "$$" 2>/dev/null; do sleep 1; done
        kill "$pid" 2>/dev/null
    ) </dev/null >/dev/null 2>&1 &
    gitb_ssh_command_agent="$sock"
}


### The gitbasher-managed agent holding one of the keys, for hosts that use
### SSH_AUTH_SOCK: the socket to run the command with, or nothing when ssh's
### own agent is the one to use
# $1: agent spec, $2: key files
function ssh_private_route {
    [ "$1" = "env" ] && [ -n "$2" ] || return 0
    local sock fps key fp
    for sock in "${gitb_ssh_command_agent:-}" "$(ssh_gitb_agent_socket)"; do
        [ -n "$sock" ] && [ -S "$sock" ] || continue
        fps=$(ssh_agent_fingerprints "$sock") || continue
        [ -n "$fps" ] || continue
        while IFS= read -r key; do
            [ -n "$key" ] || continue
            fp=$(_ssh_key_fingerprint "$key")
            if [ -n "$fp" ] && printf '%s\n' "$fps" | grep -qxF -- "$fp"; then
                printf '%s\n' "$sock"
                return 0
            fi
        done <<< "$2"
    done
}


### Ask for a key's passphrase and keep the key unlocked as the mode says.
### ssh-add prompts on the terminal itself; an empty passphrase skips the key.
# $1: key file, $2: mode, $3: agent spec of the host
# Returns: 0 unlocked, 1 skipped, 2 the key cannot be unlocked here (no
#          agent ssh would consult, or no ssh-add / ssh-agent)
function ssh_unlock_key {
    local key="$1" mode="$2" spec="$3"
    local ttl target="" where="" note="" sock out code label
    command -v ssh-add >/dev/null 2>&1 || return 2
    ttl=$(get_ssh_unlock_ttl)
    sock=$(ssh_host_agent_socket "$spec")
    case "$mode" in
        agent)
            if [ "$spec" != "none" ] && ssh_agent_alive "$sock"; then
                target="$sock"
                where="in ssh-agent $(ssh_ttl_phrase "$ttl")"
            elif [ "$spec" = "env" ] && target=$(ssh_start_gitb_agent); then
                where="for gitbasher $(ssh_ttl_phrase "$ttl")"
                note="No ssh-agent is running, so gitbasher keeps the key in its own agent"
            fi ;;
        gitb)
            if [ "$spec" = "env" ] && target=$(ssh_start_gitb_agent); then
                where="for gitbasher only, $(ssh_ttl_phrase "$ttl")"
            fi ;;
        command)
            if [ "$spec" = "env" ] && ssh_start_command_agent; then
                target="$gitb_ssh_command_agent"
                where="until this command finishes"
                ttl="0"
            fi ;;
    esac
    [ -n "$target" ] || return 2

    label=$(ssh_key_label "$key")
    echo -e "${YELLOW}🔒 SSH key ${BOLD}${label}${NORMAL}${YELLOW} is locked${ENDCOLOR}"
    if [ -n "$note" ]; then
        echo -e "${GRAY}${note}${ENDCOLOR}"
    fi
    echo -e "${GRAY}Unlocking it ${where} · empty passphrase skips · ${ENDCOLOR}${GREEN}gitb cfg ssh${ENDCOLOR}${GRAY} to change${ENDCOLOR}"

    while true; do
        code=0
        if ssh_ttl_unlimited "$ttl"; then
            out=$(SSH_AUTH_SOCK="$target" ssh-add "$key" 2>&1) || code=$?
        else
            out=$(SSH_AUTH_SOCK="$target" ssh-add -t "$ttl" "$key" 2>&1) || code=$?
        fi
        if [ "$code" -eq 0 ]; then
            echo -e "${GREEN}✓ Unlocked ${where}${ENDCOLOR}"
            echo
            return 0
        fi
        if [ "$code" -eq 2 ]; then
            # The agent went away between the check and the add
            echo
            return 2
        fi
        # Some agents refuse new keys, or keys with a lifetime (gnome-keyring,
        # 1Password). Keep it in gitbasher's agent instead: same lifetime.
        if [[ "$out" == *"refused"* ]] && [ "$mode" = "agent" ] && [ "$spec" = "env" ] \
            && [ "$target" = "$sock" ] && target=$(ssh_start_gitb_agent); then
            where="for gitbasher $(ssh_ttl_phrase "$ttl")"
            echo -e "${YELLOW}⚠  Your ssh-agent refused the key — keeping it unlocked ${where} instead${ENDCOLOR}"
            continue
        fi
        break
    done
    echo -e "${YELLOW}Skipped — ${label} stays locked${ENDCOLOR}"
    echo
    return 1
}


### Whether ssh refused only because the host key is not known yet, so an
### interactive run can let the user trust it. A changed key or
### StrictHostKeyChecking=yes fails the same way interactively.
function ssh_hostkey_unknown {
    [[ "$1" == *"Host key verification failed"* ]] && [[ "$1" != *"requested strict checking"* ]]
}

### Whether ssh failed to authenticate (a key, password, or PIN it would
### have asked for under BatchMode, or simply no access)
function ssh_auth_failed {
    [[ "$1" == *"Permission denied ("* ]] \
        || [[ "$1" == *"Too many authentication failures"* ]] \
        || [[ "$1" == *"sign_and_send_pubkey"* ]]
}


### Print the lines of stdin that are not in a list
# $1: lines to drop, one per line
function _ssh_drop_lines {
    local line
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        case $'\n'"$1" in
            *$'\n'"$line"$'\n'*) ;;
            *) printf '%s\n' "$line" ;;
        esac
    done
}


### stream_or_capture_git's runner for network commands to OpenSSH remotes.
### Runs with BatchMode=yes so ssh cannot prompt under the spinner. On
### failure: a locked key is unlocked (see ssh_unlock_key) and the command
### retried; an unknown host key, or a failure gitbasher cannot fix (a
### password, a PIN), is retried as a plain run without the spinner so ssh
### can ask the user itself.
# $@: the command and its args
# Writes the caller's __output, __code and __shown (dynamic scope).
# Returns: 0 when it ran the command, 1 when it does not apply (not an SSH
#          network command, mode off, not OpenSSH) or nothing could run
# shellcheck disable=SC2154  # __output/__code belong to stream_or_capture_git
function ssh_stream_git {
    local urls mode sshcmd spec="" keys="" host="" proxied="" label=""
    urls=$(git_network_urls "$@") || return 1
    mode=$(get_ssh_unlock_mode)
    [ "$mode" = "off" ] && return 1
    sshcmd=$(ssh_git_command) || return 1
    ssh_inspect_urls spec keys host "$urls" proxied || return 1
    # BatchMode does not reach a ProxyJump / ProxyCommand hop, which may still
    # prompt on the terminal: no spinner then, so that prompt stays visible
    if [ -z "$proxied" ]; then
        label=$(_progress_label "$@")
    fi

    local route unrouted="" skipped="" unlocked="" key attempt=0 rc run="true"
    while [ "$attempt" -lt 8 ]; do
        if [ -n "$run" ]; then
            attempt=$((attempt + 1))
            route=""
            if [ -z "$unrouted" ]; then
                route=$(ssh_private_route "$spec" "$keys")
            fi
            _stream_git_once "$label" "$route" "$sshcmd -o BatchMode=yes" "$@" || return 1
            [ "$__code" = "0" ] && return 0

            if ssh_hostkey_unknown "$__output"; then
                _stream_git_once "" "$route" "" "$@" || return 1
                return 0
            fi
            ssh_auth_failed "$__output" || return 0

            if [ -n "$route" ]; then
                # The host may want a key from ssh's own agent instead
                unrouted="true"
                continue
            fi
        fi
        run="true"

        key=$(ssh_locked_keys "$keys" "$(ssh_host_agent_socket "$spec")" \
                "${gitb_ssh_command_agent:-}" "$(ssh_gitb_agent_socket)" \
            | _ssh_drop_lines "${skipped}${unlocked}" | sed -n '1p')
        if [ -z "$key" ]; then
            # The user chose to keep a key locked: report the failure as is
            [ -n "$skipped" ] && return 0
            _stream_git_once "" "$(ssh_private_route "$spec" "$keys")" "" "$@" || return 1
            return 0
        fi

        rc=0
        ssh_unlock_key "$key" "$mode" "$spec" || rc=$?
        case "$rc" in
            0) unlocked+="$key"$'\n'; unrouted="" ;;
            # Nothing changed: offer the next locked key without a new attempt
            1) skipped+="$key"$'\n'; run="" ;;
            *)
                # No agent to keep it in: let ssh ask for the passphrase itself
                _stream_git_once "" "" "" "$@" || return 1
                return 0 ;;
        esac
    done
    return 0
}


### Show how each SSH key a remote uses can be used right now
# $1: remote name
function print_ssh_key_status {
    local remote="$1" urls spec keys host rc=0 m_sock p_sock m_fps p_fps key fp state label
    urls=$(git_network_urls git fetch "$remote")
    ssh_inspect_urls spec keys host "$urls" || rc=$?
    if [ "$rc" -eq 1 ]; then
        echo -e "Remote ${YELLOW}${remote}${ENDCOLOR} does not use SSH — there is no key to unlock"
        return
    fi
    if [ "$rc" -ne 0 ]; then
        echo -e "${YELLOW}⚠  Cannot read the ssh settings for ${remote} (not OpenSSH, or ssh rejects its config)${ENDCOLOR}"
        return
    fi
    echo -e "SSH keys for ${YELLOW}${host}${ENDCOLOR} (${remote}):"
    if [ -z "$keys" ]; then
        echo -e "\t${GRAY}no key files — ssh uses its agent or other credentials${ENDCOLOR}"
        return
    fi
    m_sock=$(ssh_host_agent_socket "$spec")
    p_sock=$(ssh_gitb_agent_socket)
    m_fps=$(ssh_agent_fingerprints "$m_sock")
    p_fps=""
    if [ "$spec" = "env" ] && [ -S "$p_sock" ]; then
        p_fps=$(ssh_agent_fingerprints "$p_sock")
    fi
    while IFS= read -r key; do
        [ -n "$key" ] || continue
        label=$(ssh_key_label "$key")
        fp=$(_ssh_key_fingerprint "$key")
        if [ -n "$fp" ] && [ -n "$m_fps" ] && printf '%s\n' "$m_fps" | grep -qxF -- "$fp"; then
            echo -e "\t${label}\t${GREEN}unlocked in ssh-agent${ENDCOLOR}"
            continue
        fi
        if [ -n "$fp" ] && [ -n "$p_fps" ] && printf '%s\n' "$p_fps" | grep -qxF -- "$fp"; then
            echo -e "\t${label}\t${GREEN}unlocked for gitbasher${ENDCOLOR}"
            continue
        fi
        state=$(ssh_key_state "$key" "")
        case "$state" in
            open)   echo -e "\t${label}\t${GREEN}no passphrase${ENDCOLOR}" ;;
            locked) echo -e "\t${label}\t${YELLOW}locked${ENDCOLOR}" ;;
            *)      echo -e "\t${label}\t${GRAY}not a usable private key${ENDCOLOR}" ;;
        esac
    done <<< "$keys"
}


### Unlock a remote's locked keys ahead of time, as the mode says
# $1: remote name
function ssh_unlock_remote_keys {
    local remote="$1" mode urls spec keys host locked key found="" rc
    mode=$(get_ssh_unlock_mode)
    case "$mode" in
        off)
            echo -e "${YELLOW}Mode 'off' never unlocks keys — ssh asks on every connection.${ENDCOLOR}"
            return ;;
        command)
            echo -e "${YELLOW}Mode 'command' forgets a key when the command ends — it is unlocked on demand.${ENDCOLOR}"
            return ;;
    esac
    urls=$(git_network_urls git fetch "$remote")
    if ! ssh_inspect_urls spec keys host "$urls"; then
        echo -e "${YELLOW}Remote ${remote} has no SSH keys gitbasher can unlock.${ENDCOLOR}"
        return
    fi
    locked=$(ssh_locked_keys "$keys" "$(ssh_host_agent_socket "$spec")" "$(ssh_gitb_agent_socket)")
    # Read the list on fd 3: ssh-add must get the terminal on stdin
    while IFS= read -r key <&3; do
        [ -n "$key" ] || continue
        found="true"
        rc=0
        ssh_unlock_key "$key" "$mode" "$spec" || rc=$?
        if [ "$rc" -eq 2 ]; then
            echo -e "${YELLOW}⚠  No ssh-agent available to keep $(ssh_key_label "$key") unlocked.${ENDCOLOR}"
        fi
    done 3<<< "$locked"
    if [ -z "$found" ]; then
        echo -e "${GREEN}✓ Nothing to unlock — every key for ${host} is already usable${ENDCOLOR}"
    fi
}


### Forget a remote's unlocked keys: remove them from ssh-agent and from
### gitbasher's agent
# $1: remote name
function ssh_lock_remote_keys {
    local remote="$1" urls spec keys host key sock removed=""
    urls=$(git_network_urls git fetch "$remote")
    if ! ssh_inspect_urls spec keys host "$urls"; then
        echo -e "${YELLOW}Remote ${remote} has no SSH keys gitbasher manages.${ENDCOLOR}"
        return
    fi
    while IFS= read -r key; do
        [ -n "$key" ] || continue
        for sock in "$(ssh_host_agent_socket "$spec")" "$(ssh_gitb_agent_socket)"; do
            [ -n "$sock" ] && [ -S "$sock" ] || continue
            if SSH_AUTH_SOCK="$sock" ssh-add -d "$key" >/dev/null 2>&1; then
                removed="true"
                echo -e "${GREEN}✓ Locked $(ssh_key_label "$key")${ENDCOLOR}"
            fi
        done
    done <<< "$keys"
    if [ -z "$removed" ]; then
        echo -e "${GREEN}✓ No unlocked keys for ${host}${ENDCOLOR}"
    fi
}

### ===== END SSH KEY UNLOCKING =====
