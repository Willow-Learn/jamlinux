#!/bin/bash
set -eu

export DEBIAN_FRONTEND=noninteractive

repo_dir="/usr/local/src/jamlinux/repositories"
max_attempts="${JAMLINUX_EXTERNAL_RETRY_ATTEMPTS:-4}"
initial_retry_delay="${JAMLINUX_EXTERNAL_RETRY_DELAY:-10}"

log() {
    echo "[jamlinux external packages] $*"
}

refresh_certificates() {
    if command -v update-ca-certificates >/dev/null 2>&1; then
        update-ca-certificates >/dev/null 2>&1 || true
    fi
}

run_with_retries() {
    local description="$1"
    shift

    local attempt=1
    local delay="$initial_retry_delay"

    while [ "$attempt" -le "$max_attempts" ]; do
        refresh_certificates

        if "$@"; then
            if [ "$attempt" -gt 1 ]; then
                log "$description succeeded on attempt $attempt/$max_attempts."
            fi
            return 0
        fi

        if [ "$attempt" -eq "$max_attempts" ]; then
            log "$description failed after $attempt attempts."
            return 1
        fi

        log "$description failed on attempt $attempt/$max_attempts; retrying in ${delay}s."
        sleep "$delay"

        attempt=$((attempt + 1))
        delay=$((delay * 2))
    done
}

repo_update() {
    local list_dest="$1"

    apt-get update \
        -o Dir::Etc::sourcelist="$list_dest" \
        -o Dir::Etc::sourceparts="-" \
        -o APT::Get::List-Cleanup="0"
}

repo_install() {
    local package_name="$1"

    apt-get install -y --no-install-recommends "$package_name"
}

cleanup_repo_registration() {
    local list_dest="$1"
    local key_dest="$2"

    rm -f "$list_dest" "$key_dest"
}

install_repo_package() {
    local name="$1"
    local package_name="$2"
    local list_src="$repo_dir/$3"
    local key_src="$repo_dir/$4"
    local list_dest="/etc/apt/sources.list.d/$3"
    local key_dest="/etc/apt/keyrings/$4"

    if [ ! -f "$list_src" ] || [ ! -f "$key_src" ]; then
        log "Skipping $name: missing repository metadata."
        return 0
    fi

    mkdir -p /etc/apt/keyrings /etc/apt/sources.list.d
    cp "$key_src" "$key_dest"
    cp "$list_src" "$list_dest"
    chmod 0644 "$key_dest" "$list_dest"

    if run_with_retries "$name repository refresh" repo_update "$list_dest"
    then
        if run_with_retries "$package_name install from $name" repo_install "$package_name"; then
            log "Installed $package_name from the $name repository."
        else
            log "Skipping $package_name: install failed after repository refresh."
            cleanup_repo_registration "$list_dest" "$key_dest"
        fi
    else
        log "Skipping $package_name: repository refresh failed."
        cleanup_repo_registration "$list_dest" "$key_dest"
    fi
}

install_repo_package "VS Code" "code" "vscode.list" "vscode.asc"
install_repo_package "Ulauncher" "ulauncher" "ulauncher.list" "ulauncher.asc"
