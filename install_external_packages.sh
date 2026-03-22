#!/bin/bash
set -eu

export DEBIAN_FRONTEND=noninteractive

repo_dir="/usr/local/src/jamlinux/repositories"
ulauncher_deb_url="https://github.com/Ulauncher/Ulauncher/releases/download/5.15.15/ulauncher_5.15.15_all.deb"
max_attempts="${JAMLINUX_EXTERNAL_RETRY_ATTEMPTS:-4}"
initial_retry_delay="${JAMLINUX_EXTERNAL_RETRY_DELAY:-10}"
persist_repos="${JAMLINUX_PERSIST_REPOS:-0}"
strict_mode="${JAMLINUX_EXTERNAL_STRICT:-0}"

log() {
    echo "[jamlinux external packages] $*"
}

refresh_certificates() {
    if command -v update-ca-certificates >/dev/null 2>&1; then
        update-ca-certificates >/dev/null 2>&1 || true
    fi
}

package_installed() {
    local package_name="$1"

    dpkg-query -W -f='${Status}' "$package_name" 2>/dev/null | grep -q "install ok installed"
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

default_repo_update() {
    apt-get update
}

repo_install() {
    local package_name="$1"

    apt-get install -y --no-install-recommends "$package_name"
}

download_file() {
    local url="$1"
    local destination="$2"

    curl -fsSL --retry 3 --retry-all-errors --output "$destination" "$url"
}

install_local_deb() {
    local deb_path="$1"

    apt-get install -y --no-install-recommends "$deb_path"
}

cleanup_repo_registration() {
    local list_dest="$1"
    local key_dest="$2"

    rm -f "$list_dest" "$key_dest"
}

preserve_or_cleanup_repo_registration() {
    local list_dest="$1"
    local key_dest="$2"

    if [ "$persist_repos" -eq 1 ]; then
        log "Leaving repository metadata in place for a future retry."
        return
    fi

    cleanup_repo_registration "$list_dest" "$key_dest"
}

install_repo_package_with_dearmored_key() {
    local name="$1"
    local package_name="$2"
    local list_src="$repo_dir/$3"
    local key_src="$repo_dir/$4"
    local list_dest="/etc/apt/sources.list.d/$3"
    local key_dest="/usr/share/keyrings/$5"

    if [ ! -f "$list_src" ] || [ ! -f "$key_src" ]; then
        log "Skipping $name: missing repository metadata."
        return 0
    fi

    mkdir -p /usr/share/keyrings /etc/apt/sources.list.d
    gpg --batch --yes --dearmor --output "$key_dest" "$key_src"
    cp "$list_src" "$list_dest"
    chmod 0644 "$key_dest" "$list_dest"

    if package_installed "$package_name"; then
        if run_with_retries "$name APT metadata refresh" default_repo_update; then
            log "Configured the $name repository for $package_name."
        else
            log "Registered the $name repository, but metadata refresh failed."
        fi
        return 0
    fi

    if run_with_retries "$name APT metadata refresh" default_repo_update
    then
        if run_with_retries "$package_name install from $name" repo_install "$package_name"; then
            log "Installed $package_name from the $name repository."
        else
            log "Skipping $package_name: install failed after repository refresh."
            preserve_or_cleanup_repo_registration "$list_dest" "$key_dest"
            return 1
        fi
    else
        log "Skipping $package_name: repository refresh failed."
        preserve_or_cleanup_repo_registration "$list_dest" "$key_dest"
        return 1
    fi
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

    if package_installed "$package_name"; then
        if run_with_retries "$name APT metadata refresh" default_repo_update; then
            log "Configured the $name repository for $package_name."
        else
            log "Registered the $name repository, but metadata refresh failed."
        fi
        return 0
    fi

    if run_with_retries "$name APT metadata refresh" default_repo_update
    then
        if run_with_retries "$package_name install from $name" repo_install "$package_name"; then
            log "Installed $package_name from the $name repository."
        else
            log "Skipping $package_name: install failed after repository refresh."
            preserve_or_cleanup_repo_registration "$list_dest" "$key_dest"
            return 1
        fi
    else
        log "Skipping $package_name: repository refresh failed."
        preserve_or_cleanup_repo_registration "$list_dest" "$key_dest"
        return 1
    fi
}

install_ulauncher_release() {
    local download_dir="/var/tmp/jamlinux-external-packages"
    local deb_path="$download_dir/ulauncher_5.15.15_all.deb"

    if package_installed ulauncher; then
        log "ulauncher is already installed."
        return 0
    fi

    mkdir -p "$download_dir"

    if ! run_with_retries "APT metadata refresh for Ulauncher dependencies" default_repo_update; then
        log "Skipping ulauncher: failed to refresh APT metadata for dependencies."
        return 1
    fi

    if run_with_retries "Ulauncher release download" download_file "$ulauncher_deb_url" "$deb_path"
    then
        if run_with_retries "Ulauncher package install" install_local_deb "$deb_path"; then
            log "Installed ulauncher from the pinned GitHub release package."
            rm -f "$deb_path"
        else
            log "Skipping ulauncher: install from the pinned GitHub release failed."
            return 1
        fi
    else
        log "Skipping ulauncher: download from the pinned GitHub release failed."
        return 1
    fi
}

failures=0

install_repo_package "VS Code" "code" "vscode.list" "vscode.asc" || failures=1
install_repo_package_with_dearmored_key "Julian's package repo" "adw-gtk3" "julians-package-repo.list" "julians-package-repo.asc" "julians-package-repo.gpg" || failures=1
install_ulauncher_release || failures=1

if [ "$failures" -ne 0 ]; then
    log "One or more external packages could not be installed or refreshed."
    if [ "$strict_mode" -eq 1 ]; then
        exit 1
    fi
fi
