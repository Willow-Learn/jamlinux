#!/bin/bash
set -eu

export DEBIAN_FRONTEND=noninteractive

MARKER_FILE="/var/lib/jamlinux/first-boot-complete"
DEB_CACHE_DIR="/var/lib/jamlinux/external-debs"
FLATPAK_REMOTE_URL="https://dl.flathub.org/repo/flathub.flatpakrepo"
FLATPAK_APPS=(
    com.spotify.Client
    com.discordapp.Discord
    com.slack.Slack
    us.zoom.Zoom
    org.openshot.OpenShot
    com.ozmartians.VidCutter
    com.github.tchx84.Flatseal
    io.dbeaver.DBeaverCommunity
    com.github.johnfactotum.Foliate
    org.signal.Signal
)

# External .deb package sources
# To add a new package, add its name to EXTERNAL_PACKAGES and define a
# matching install_<name> function below.  The framework calls each one
# with retries and verifies installation afterwards.
ULAUNCHER_DEB_URL="https://github.com/Ulauncher/Ulauncher/releases/download/5.15.15/ulauncher_5.15.15_all.deb"
VSCODE_DEB_URL="https://update.code.visualstudio.com/latest/linux-deb-x64/stable"
JULIAN_REPO_URL="https://julianfairfax.codeberg.page/package-repo/debs"

EXTERNAL_PACKAGES=(ulauncher code adw-gtk3)

MAX_ATTEMPTS="${JAMLINUX_FIRST_BOOT_RETRY_ATTEMPTS:-4}"
INITIAL_RETRY_DELAY="${JAMLINUX_FIRST_BOOT_RETRY_DELAY:-15}"

log() {
    echo "[jamlinux first boot] $*"
}

run_with_retries() {
    local description="$1"
    shift

    local attempt=1
    local delay="$INITIAL_RETRY_DELAY"

    while [ "$attempt" -le "$MAX_ATTEMPTS" ]; do
        if "$@"; then
            if [ "$attempt" -gt 1 ]; then
                log "$description succeeded on attempt $attempt/$MAX_ATTEMPTS."
            fi
            return 0
        fi

        if [ "$attempt" -eq "$MAX_ATTEMPTS" ]; then
            log "$description failed after $attempt attempts."
            return 1
        fi

        log "$description failed on attempt $attempt/$MAX_ATTEMPTS; retrying in ${delay}s."
        sleep "$delay"

        attempt=$((attempt + 1))
        delay=$((delay * 2))
    done
}

package_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

find_cached_deb() {
    local pkg="$1"
    find "$DEB_CACHE_DIR" -maxdepth 1 \( -name "${pkg}_*.deb" -o -name "${pkg}.deb" \) \
        -type f 2>/dev/null | head -1
}

# ---------------------------------------------------------------------------
# Per-package install functions
# Each function tries the build-time cached .deb first, then falls back to
# downloading from the network.  Add new packages by writing a new function
# and appending the package name to EXTERNAL_PACKAGES above.
# ---------------------------------------------------------------------------

install_ulauncher() {
    local cached
    cached="$(find_cached_deb ulauncher)"

    if [ -n "$cached" ]; then
        log "Installing ulauncher from cache: $(basename "$cached")"
        if apt-get install -y --no-install-recommends "$cached"; then
            return 0
        fi
        log "Cache install failed for ulauncher; downloading."
    fi

    local tmp="/var/tmp/jamlinux-ulauncher.deb"
    curl -fsSL --retry 3 --retry-all-errors --output "$tmp" "$ULAUNCHER_DEB_URL"
    apt-get install -y --no-install-recommends "$tmp"
    local rc=$?
    rm -f "$tmp"
    return $rc
}

install_code() {
    local cached
    cached="$(find_cached_deb code)"

    if [ -n "$cached" ]; then
        log "Installing code from cache: $(basename "$cached")"
        if apt-get install -y --no-install-recommends "$cached"; then
            return 0
        fi
        log "Cache install failed for code; downloading."
    fi

    local tmp="/var/tmp/jamlinux-code.deb"
    curl -fsSL --retry 3 --retry-all-errors --output "$tmp" "$VSCODE_DEB_URL"
    apt-get install -y --no-install-recommends "$tmp"
    local rc=$?
    rm -f "$tmp"
    return $rc
}

install_adw-gtk3() {
    local cached
    cached="$(find_cached_deb adw-gtk3)"

    if [ -n "$cached" ]; then
        log "Installing adw-gtk3 from cache: $(basename "$cached")"
        if apt-get install -y --no-install-recommends "$cached"; then
            return 0
        fi
        log "Cache install failed for adw-gtk3; downloading from repo."
    fi

    local list_file="/etc/apt/sources.list.d/julianfairfax.list"
    echo "deb [trusted=yes] $JULIAN_REPO_URL packages main" > "$list_file"
    apt-get update \
        -o Dir::Etc::sourcelist="$list_file" \
        -o Dir::Etc::sourceparts="-" \
        -o APT::Get::List-Cleanup="0"
    apt-get install -y --no-install-recommends adw-gtk3
    local rc=$?
    rm -f "$list_file"
    return $rc
}

# ---------------------------------------------------------------------------

install_libdvd() {
    if package_installed libdvd-pkg; then
        log "libdvd-pkg is already installed."
        return 0
    fi

    apt-get install -y libdvd-pkg
    dpkg-reconfigure -f noninteractive libdvd-pkg
}

ensure_apt_sources() {
    local staged="/usr/local/src/jamlinux/sources.list"

    if [ ! -s /etc/apt/sources.list ] && [ -s "$staged" ]; then
        install -m 0644 "$staged" /etc/apt/sources.list
        log "Restored apt sources.list from staged copy."
    fi
}

install_external_packages() {
    local pkg failures=0

    ensure_apt_sources

    if ! run_with_retries "APT metadata refresh" apt-get update; then
        log "WARNING: Could not refresh APT metadata; cached installs may still work."
    fi

    for pkg in "${EXTERNAL_PACKAGES[@]}"; do
        if package_installed "$pkg"; then
            log "$pkg is already installed."
            continue
        fi

        if run_with_retries "$pkg install" "install_${pkg}"; then
            log "Installed $pkg."
        else
            log "Failed to install $pkg."
            failures=$((failures + 1))
        fi
    done

    rm -rf "$DEB_CACHE_DIR"

    for pkg in "${EXTERNAL_PACKAGES[@]}"; do
        if ! package_installed "$pkg"; then
            log "VERIFICATION FAILED: $pkg is not installed."
            failures=$((failures + 1))
        fi
    done

    if [ "$failures" -gt 0 ]; then
        log "$failures external package(s) failed."
        return 1
    fi

    log "All external packages installed and verified."
}

# ---------------------------------------------------------------------------
# Flatpak section
# ---------------------------------------------------------------------------

configure_flathub() {
    flatpak remote-add --if-not-exists --system flathub "$FLATPAK_REMOTE_URL"
}

flatpak_app_installed() {
    local app="$1"

    flatpak info --system "$app" >/dev/null 2>&1
}

install_flatpak_app() {
    local app="$1"

    if flatpak_app_installed "$app"; then
        log "$app is already installed."
        return 0
    fi

    flatpak install --noninteractive -y --system flathub "$app"
    flatpak_app_installed "$app"
}

install_bundled_flatpaks() {
    local app

    if ! command -v flatpak >/dev/null 2>&1; then
        log "Flatpak is not installed; bundled app install cannot complete."
        return 1
    fi

    run_with_retries "Flathub remote configuration" configure_flathub

    for app in "${FLATPAK_APPS[@]}"; do
        if run_with_retries "$app install" install_flatpak_app "$app"; then
            log "Installed $app."
        else
            return 1
        fi
    done

    for app in "${FLATPAK_APPS[@]}"; do
        if flatpak_app_installed "$app"; then
            log "Verified $app."
        else
            log "$app is still missing after installation attempts."
            return 1
        fi
    done
}

# ---------------------------------------------------------------------------

main() {
    if [ -f "$MARKER_FILE" ]; then
        log "First-boot tasks are already complete."
        exit 0
    fi

    mkdir -p "$(dirname "$MARKER_FILE")"

    local all_ok=true

    if install_external_packages; then
        log "External package installation complete."
    else
        log "External package installation incomplete — will retry on next boot."
        all_ok=false
    fi

    if install_libdvd; then
        log "libdvd-pkg installation complete."
    else
        log "libdvd-pkg installation failed — DVD playback may not work."
        all_ok=false
    fi

    if install_bundled_flatpaks; then
        log "Bundled Flatpak installation complete."
    else
        log "Bundled Flatpak installation incomplete — will retry on next boot."
        all_ok=false
    fi

    if [ "$all_ok" = false ]; then
        log "First-boot tasks incomplete; will retry on next boot."
        exit 1
    fi

    touch "$MARKER_FILE"
    log "First-boot tasks completed."
}

main "$@"
