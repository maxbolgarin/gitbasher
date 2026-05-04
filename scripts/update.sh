#!/usr/bin/env bash

### Script for checking and applying gitbasher self-updates
# Talks to the GitHub Releases API for maxbolgarin/gitbasher, compares the
# running GITBASHER_VERSION against the latest tag, and replaces the installed
# `gitb` binary in place. Use this script only with gitbasher.


GITBASHER_REPO="maxbolgarin/gitbasher"
GITBASHER_RELEASES_URL="https://github.com/${GITBASHER_REPO}/releases"


### Strip a leading "v" from a version string so 3.10.2 and v3.10.2 compare equal.
# $1: raw version string
function _normalize_version {
    local v="${1#v}"
    v="${v#V}"
    echo "$v"
}


### Compare two semver-ish version strings.
# $1: version A
# $2: version B
# Returns: 0 if A == B, 1 if A > B, 2 if A < B
# Numeric components compare numerically; pre-release suffixes (anything after
# the first '-') are stripped so "3.10.2" and "3.10.2-rc.1" are treated equal.
function _compare_versions {
    local a="$(_normalize_version "$1")"
    local b="$(_normalize_version "$2")"
    a="${a%%-*}"
    b="${b%%-*}"

    local IFS=.
    local -a aa=($a) bb=($b)
    local i max=${#aa[@]}
    [ ${#bb[@]} -gt $max ] && max=${#bb[@]}

    for ((i = 0; i < max; i++)); do
        local na=${aa[i]:-0} nb=${bb[i]:-0}
        # Strip non-digits to keep the comparison purely numeric.
        na=${na//[^0-9]/}
        nb=${nb//[^0-9]/}
        : "${na:=0}"
        : "${nb:=0}"
        if (( 10#$na > 10#$nb )); then return 1; fi
        if (( 10#$na < 10#$nb )); then return 2; fi
    done
    return 0
}


### Fetch the latest release JSON payload from GitHub.
# Echoes the raw response (or empty on failure). Sets _gitb_update_fetch_err on
# failure so callers can show a useful message.
function _fetch_latest_release {
    _gitb_update_fetch_err=""
    local url="https://api.github.com/repos/${GITBASHER_REPO}/releases/latest"
    local body=""

    if command -v curl >/dev/null 2>&1; then
        body=$(curl -fsSL --proto '=https' --tlsv1.2 --max-time 10 -H "Accept: application/vnd.github+json" "$url" 2>&1)
        if [ $? -ne 0 ]; then
            _gitb_update_fetch_err="$body"
            echo ""
            return 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        body=$(wget -qO- --https-only --timeout=10 --header="Accept: application/vnd.github+json" "$url" 2>&1)
        if [ $? -ne 0 ]; then
            _gitb_update_fetch_err="$body"
            echo ""
            return 1
        fi
    else
        _gitb_update_fetch_err="Need curl or wget to check for updates."
        echo ""
        return 1
    fi

    echo "$body"
}


### Pull a top-level string field out of a GitHub release JSON blob.
# Prefers jq when available (handles escaped quotes, unicode, future field
# additions); falls back to a grep+sed pair that's good enough for GitHub's
# stable schema. Used by the more-specific helpers below.
# $1: JSON body
# $2: field name (e.g. "tag_name", "html_url", "published_at")
function _extract_release_field {
    local body="$1"
    local field="$2"
    if command -v jq >/dev/null 2>&1; then
        # `// empty` ensures a missing/null field returns "" rather than the
        # literal string "null", which the legacy regex form also avoided.
        printf '%s' "$body" | jq -r --arg f "$field" '.[$f] // empty' 2>/dev/null
        return
    fi
    printf '%s' "$body" | grep -o "\"${field}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
              | head -1 \
              | sed -E 's/.*"([^"]+)"$/\1/'
}


### Pull the tag_name field out of a GitHub release JSON blob.
# $1: JSON body
function _extract_tag_name {
    _extract_release_field "$1" "tag_name"
}


### Pull the html_url field out of a GitHub release JSON blob.
# $1: JSON body
function _extract_release_url {
    _extract_release_field "$1" "html_url"
}


### Pull the published_at date out of a GitHub release JSON blob.
# Returns just the date portion (YYYY-MM-DD) of the ISO-8601 timestamp.
# $1: JSON body
function _extract_release_date {
    _extract_release_field "$1" "published_at" | cut -dT -f1
}


### Resolve where the running gitb binary lives on disk.
# Echoes an absolute path or empty when gitb is not on PATH (dev runs from
# scripts/gitb.sh fall into this case).
function _gitb_install_path {
    local path
    path=$(command -v gitb 2>/dev/null) || return 1
    [ -z "$path" ] && return 1
    # Resolve symlinks where possible so we update the real file, not a shim.
    # `realpath` is the most portable (POSIX-2024, also macOS 10.13+, Linux);
    # `readlink -f` is GNU-only and silently does nothing on BSD (where the
    # `-f` flag means something different). Fall back to a manual one-step
    # resolution if neither is available.
    local resolved=""
    if command -v realpath >/dev/null 2>&1; then
        resolved=$(realpath "$path" 2>/dev/null) || resolved=""
    fi
    if [ -z "$resolved" ] && command -v readlink >/dev/null 2>&1; then
        resolved=$(readlink -f "$path" 2>/dev/null) || resolved=""
        if [ -z "$resolved" ] && [ -L "$path" ]; then
            resolved=$(readlink "$path" 2>/dev/null)
            case "$resolved" in
                /*) ;;
                *)  resolved="$(dirname "$path")/$resolved" ;;
            esac
        fi
    fi
    [ -n "$resolved" ] && path="$resolved"
    echo "$path"
}


### Detect whether the gitb binary was installed via npm so we can defer to the
### npm-managed update flow instead of overwriting the file under node_modules.
# $1: install path
# Returns: 0 if installed via npm, 1 otherwise
function _gitb_is_npm_install {
    local path="$1"
    [ -z "$path" ] && return 1
    case "$path" in
        */node_modules/*) return 0 ;;
    esac
    if command -v npm >/dev/null 2>&1; then
        local npm_root
        npm_root=$(npm root -g 2>/dev/null)
        if [ -n "$npm_root" ] && [[ "$path" == "$npm_root"/* ]]; then
            return 0
        fi
    fi
    return 1
}


### Verify the SHA-256 of a downloaded gitb binary against the .sha256 asset
### published alongside it. Mirrors install.sh: refuses on mismatch; warns and
### allows when the .sha256 asset can't be fetched (older or hand-rolled
### releases may lack it). Sets _gitb_update_download_err on hard mismatch and
### _gitb_update_sha_warning when verification was skipped.
# $1: path to the downloaded binary
# Returns: 0 on verified or warned-and-continued; 1 on mismatch.
function _verify_gitb_sha256 {
    local downloaded="$1"
    local sha_url="https://github.com/${GITBASHER_REPO}/releases/latest/download/gitb.sha256"

    local sha_cmd=""
    if command -v shasum >/dev/null 2>&1; then
        sha_cmd="shasum -a 256"
    elif command -v sha256sum >/dev/null 2>&1; then
        sha_cmd="sha256sum"
    else
        _gitb_update_sha_warning="Neither shasum nor sha256sum is available — proceeding without verification."
        return 0
    fi

    local tmp_sha
    tmp_sha=$(mktemp 2>/dev/null || mktemp -t gitb.sha256)
    if [ -z "$tmp_sha" ]; then
        _gitb_update_sha_warning="Could not create temp file for checksum — proceeding without verification."
        return 0
    fi

    local fetched=0
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --proto '=https' --tlsv1.2 --max-time 30 -o "$tmp_sha" "$sha_url" 2>/dev/null && fetched=1
    elif command -v wget >/dev/null 2>&1; then
        wget --https-only --timeout=30 -qO "$tmp_sha" "$sha_url" 2>/dev/null && fetched=1
    fi

    if [ "$fetched" != "1" ] || [ ! -s "$tmp_sha" ]; then
        rm -f "$tmp_sha"
        _gitb_update_sha_warning="Could not fetch ${sha_url} — proceeding without verification."
        return 0
    fi

    local expected actual
    expected=$(awk 'NR==1 {print $1}' "$tmp_sha")
    actual=$($sha_cmd "$downloaded" | awk '{print $1}')
    rm -f "$tmp_sha"

    if [ -z "$expected" ] || [ "$expected" != "$actual" ]; then
        _gitb_update_download_err="Checksum mismatch (expected ${expected:-<empty>}, got ${actual:-<empty>}). Refusing to install."
        return 1
    fi

    _gitb_update_sha_verified=1
    return 0
}


### Download the latest gitb binary into a temp file. Echoes the temp path on
### success; sets _gitb_update_download_err on failure. Verifies SHA-256
### against the .sha256 asset before returning.
function _download_latest_gitb {
    _gitb_update_download_err=""
    _gitb_update_sha_warning=""
    _gitb_update_sha_verified=0
    local url="https://github.com/${GITBASHER_REPO}/releases/latest/download/gitb"
    local tmp
    tmp=$(mktemp 2>/dev/null || mktemp -t gitb)
    if [ -z "$tmp" ]; then
        _gitb_update_download_err="Could not create a temp file for the download."
        return 1
    fi

    local err=""
    if command -v curl >/dev/null 2>&1; then
        err=$(curl -fSL --proto '=https' --tlsv1.2 --max-time 60 -o "$tmp" "$url" 2>&1)
    elif command -v wget >/dev/null 2>&1; then
        err=$(wget --https-only --timeout=60 -qO "$tmp" "$url" 2>&1)
    else
        rm -f "$tmp"
        _gitb_update_download_err="Need curl or wget to download the new release."
        return 1
    fi

    if [ $? -ne 0 ]; then
        rm -f "$tmp"
        _gitb_update_download_err="$err"
        return 1
    fi

    # Sanity-check the payload — a 404 from GitHub returns HTML, not bash.
    if ! head -c 64 "$tmp" | grep -q '^#!.*bash'; then
        rm -f "$tmp"
        _gitb_update_download_err="Downloaded file is not a bash script (got HTML or empty body)."
        return 1
    fi

    if ! _verify_gitb_sha256 "$tmp"; then
        rm -f "$tmp"
        return 1
    fi

    echo "$tmp"
    return 0
}


### Replace the installed gitb binary with the freshly-downloaded one. Tries a
### plain `install` first, then re-runs with sudo when the destination is not
### writable by the current user.
# $1: source path (downloaded binary)
# $2: destination path (installed gitb)
# Returns: 0 on success, non-zero on failure
function _install_gitb_binary {
    local src="$1" dst="$2"
    local install_err=""

    if install -m 0755 "$src" "$dst" >/dev/null 2>&1; then
        return 0
    fi

    # Fall back to sudo only when we genuinely can't write — and only if sudo
    # is available, so headless runs surface a clear error instead of hanging.
    local dst_dir
    dst_dir=$(dirname "$dst")
    if [ -w "$dst" ] || { [ ! -e "$dst" ] && [ -w "$dst_dir" ]; }; then
        # Writable but install still failed — re-run to capture the real error.
        install_err=$(install -m 0755 "$src" "$dst" 2>&1)
        echo "$install_err" >&2
        return 1
    fi

    if ! command -v sudo >/dev/null 2>&1; then
        echo -e "${RED}✗ Cannot write to ${dst} and sudo is not available.${ENDCOLOR}" >&2
        return 1
    fi

    echo -e "${YELLOW}Updating ${dst} requires sudo — you may be prompted for your password.${ENDCOLOR}"
    if sudo install -m 0755 "$src" "$dst"; then
        return 0
    fi
    return 1
}


### Main entry point for `gitb update`.
# $1: mode (empty | check | force | help)
function update_script {
    case "$1" in
        check|c|ch)        check_only="true";;
        force|f|fo)        force_update="true";;
        help|h)            help="true";;
        "")                ;;
        *)
            wrong_mode "update" $1
    esac

    local header="GITBASHER UPDATE"
    if [ -n "$check_only" ]; then
        header="$header CHECK"
    elif [ -n "$force_update" ]; then
        header="$header FORCE"
    fi

    echo -e "${YELLOW}${header}${ENDCOLOR}"
    echo

    if [ -n "$help" ]; then
        echo -e "usage: ${YELLOW}gitb update <mode>${ENDCOLOR}"
        echo
        local PAD=14
        print_help_header $PAD
        print_help_row $PAD "<empty>" ""      "Check for a new release and install it"
        print_help_row $PAD "check"   "c, ch" "Only check for a newer release; do not install"
        print_help_row $PAD "force"   "f, fo" "Reinstall the latest release even if already up to date"
        print_help_row $PAD "help"    "h"     "Show this help"
        echo
        echo -e "${YELLOW}Examples${ENDCOLOR}"
        echo -e "  ${GREEN}gitb update${ENDCOLOR}        Check and install if a newer version is published"
        echo -e "  ${GREEN}gitb update check${ENDCOLOR}  Just check, don't install"
        echo -e "  ${GREEN}gitb update force${ENDCOLOR}  Re-download the latest release over the current one"
        exit
    fi

    local current_version="$GITBASHER_VERSION"
    echo -e "Current version: ${YELLOW}${current_version}${ENDCOLOR}"

    echo -e "${BLUE}Fetching latest release info...${ENDCOLOR}"
    local body
    body=$(_fetch_latest_release)
    if [ -z "$body" ]; then
        echo
        echo -e "${RED}✗ Cannot reach GitHub Releases.${ENDCOLOR}"
        if [ -n "$_gitb_update_fetch_err" ]; then
            echo -e "${GRAY}${_gitb_update_fetch_err}${ENDCOLOR}"
        fi
        echo
        print_link "Releases" "$GITBASHER_RELEASES_URL"
        exit 1
    fi

    local latest_tag latest_url latest_date
    latest_tag=$(_extract_tag_name "$body")
    latest_url=$(_extract_release_url "$body")
    latest_date=$(_extract_release_date "$body")

    if [ -z "$latest_tag" ]; then
        echo
        echo -e "${RED}✗ Could not parse the latest release tag from GitHub's response.${ENDCOLOR}"
        echo
        print_link "Releases" "$GITBASHER_RELEASES_URL"
        exit 1
    fi

    local latest_version="$(_normalize_version "$latest_tag")"
    local printed_date=""
    [ -n "$latest_date" ] && printed_date=" ${GRAY}(${latest_date})${ENDCOLOR}"
    echo -e "Latest version:  ${GREEN}${latest_version}${ENDCOLOR}${printed_date}"
    echo

    # `dev` is the placeholder version used when running scripts/gitb.sh
    # directly — there's nothing meaningful to update in that case.
    if [ "$current_version" = "dev" ]; then
        echo -e "${YELLOW}⚠  Running an unbuilt development version (GITBASHER_VERSION=dev).${ENDCOLOR}"
        echo -e "${GRAY}Build with ${GREEN}make build${GRAY} or install a release with the install script.${ENDCOLOR}"
        if [ -n "$latest_url" ]; then
            echo
            print_link "Release" "$latest_url"
        fi
        exit
    fi

    _compare_versions "$current_version" "$latest_version"
    local cmp=$?

    if [ -n "$check_only" ]; then
        case $cmp in
            0) echo -e "${GREEN}✓ You're on the latest version.${ENDCOLOR}";;
            1) echo -e "${YELLOW}⚠  Your version is newer than the latest release.${ENDCOLOR}";;
            2) echo -e "${YELLOW}⚠  A newer version is available: ${GREEN}${latest_version}${ENDCOLOR}"
               echo -e "Run ${GREEN}gitb update${ENDCOLOR} to install it.";;
        esac
        if [ -n "$latest_url" ]; then
            echo
            print_link "Release" "$latest_url"
        fi
        exit
    fi

    if [ $cmp -eq 0 ] && [ -z "$force_update" ]; then
        echo -e "${GREEN}✓ Already on the latest version.${ENDCOLOR}"
        echo -e "${GRAY}Use ${GREEN}gitb update force${GRAY} to reinstall anyway.${ENDCOLOR}"
        exit
    fi

    if [ $cmp -eq 1 ] && [ -z "$force_update" ]; then
        echo -e "${YELLOW}⚠  Your version (${current_version}) is newer than the latest release (${latest_version}).${ENDCOLOR}"
        echo -e "${GRAY}Use ${GREEN}gitb update force${GRAY} to install the published release anyway.${ENDCOLOR}"
        exit
    fi

    local install_path
    install_path=$(_gitb_install_path)
    if [ -z "$install_path" ]; then
        echo -e "${RED}✗ Could not locate the installed gitb binary on PATH.${ENDCOLOR}"
        echo -e "Reinstall manually:"
        echo -e "  ${GREEN}curl -fsSL https://raw.githubusercontent.com/${GITBASHER_REPO}/main/install.sh | bash${ENDCOLOR}"
        exit 1
    fi

    if _gitb_is_npm_install "$install_path"; then
        echo -e "${YELLOW}⚠  gitb is installed via npm at ${install_path}.${ENDCOLOR}"
        echo -e "Update with npm so the package metadata stays in sync:"
        echo -e "  ${GREEN}npm update -g gitbasher${ENDCOLOR}"
        if [ -n "$latest_url" ]; then
            echo
            print_link "Release" "$latest_url"
        fi
        exit
    fi

    echo -e "Install location: ${BLUE}${install_path}${ENDCOLOR}"
    if [ $cmp -eq 2 ]; then
        echo -e "Update ${YELLOW}${current_version}${ENDCOLOR} → ${GREEN}${latest_version}${ENDCOLOR}? (y/n)"
    else
        echo -e "Reinstall ${GREEN}${latest_version}${ENDCOLOR} over the current binary? (y/n)"
    fi
    yes_no_choice "Updating..."

    local tmp_path
    tmp_path=$(_download_latest_gitb)
    if [ -z "$tmp_path" ]; then
        echo -e "${RED}✗ Download failed.${ENDCOLOR}"
        if [ -n "$_gitb_update_download_err" ]; then
            echo -e "${GRAY}${_gitb_update_download_err}${ENDCOLOR}"
        fi
        echo
        print_link "Releases" "$GITBASHER_RELEASES_URL"
        exit 1
    fi

    if [ "${_gitb_update_sha_verified:-0}" = "1" ]; then
        echo -e "${GREEN}✓ Verified SHA-256 checksum${ENDCOLOR}"
    elif [ -n "${_gitb_update_sha_warning:-}" ]; then
        echo -e "${YELLOW}⚠  ${_gitb_update_sha_warning}${ENDCOLOR}"
    fi

    if ! _install_gitb_binary "$tmp_path" "$install_path"; then
        rm -f "$tmp_path"
        echo -e "${RED}✗ Could not install the new binary at ${install_path}.${ENDCOLOR}"
        exit 1
    fi
    rm -f "$tmp_path"

    # Verify the freshly-installed binary actually runs and reports a sane
    # version. Any non-zero exit here means we just shipped a broken file.
    local installed_version
    installed_version=$("$install_path" --version 2>/dev/null | head -1 | awk '{print $NF}')
    installed_version=$(_normalize_version "$installed_version")

    if [ -z "$installed_version" ]; then
        echo -e "${RED}✗ Installed binary at ${install_path} did not report a version.${ENDCOLOR}"
        exit 1
    fi

    echo -e "${GREEN}✓ Updated gitbasher to ${installed_version}${ENDCOLOR}"
    if [ -n "$latest_url" ]; then
        echo
        print_link "Release" "$latest_url"
    fi
}
