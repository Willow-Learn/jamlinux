#!/bin/bash
set -eu

export DEBIAN_FRONTEND=noninteractive

MARKER_FILE="/var/lib/jamlinux/first-boot-complete"
FLATPAK_REMOTE_URL="https://dl.flathub.org/repo/flathub.flatpakrepo"
FLATPAK_APPS=(
    com.spotify.Client
    com.discordapp.Discord
    com.slack.Slack
    us.zoom.Zoom
)
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

main() {
    if [ -f "$MARKER_FILE" ]; then
        log "First-boot tasks are already complete."
        exit 0
    fi

    mkdir -p "$(dirname "$MARKER_FILE")"

    install_bundled_flatpaks

    touch "$MARKER_FILE"
    log "First-boot tasks completed."
}

main "$@"