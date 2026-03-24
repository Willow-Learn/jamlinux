#!/bin/bash
set -eu

export DEBIAN_FRONTEND=noninteractive

log() {
    echo "[jamlinux installed-system] $*"
}

warn() {
    echo "[jamlinux installed-system] warning: $*" >&2
}

list_apt_source_files() {
    if [ -f /etc/apt/sources.list ]; then
        printf '%s\n' /etc/apt/sources.list
    fi

    find /etc/apt/sources.list.d -maxdepth 1 -type f \( -name '*.list' -o -name '*.sources' \) 2>/dev/null
}

find_repo_sources() {
    local repo_url="$1"
    local exclude_path="$2"
    local source_file
    local found=1

    while IFS= read -r source_file; do
        [ -n "$source_file" ] || continue
        [ "$source_file" = "$exclude_path" ] && continue

        if grep -Fqs "$repo_url" "$source_file"; then
            printf '%s\n' "$source_file"
            found=0
        fi
    done < <(list_apt_source_files)

    return "$found"
}

install_repo_registration_copy() {
    local name="$1"
    local list_src="$2"
    local key_src="$3"
    local list_dest="$4"
    local key_dest="$5"
    local repo_url="${6:-}"
    local existing_sources

    if [ ! -f "$list_src" ] || [ ! -f "$key_src" ]; then
        warn "Skipping $name repository registration: staged metadata is missing."
        return
    fi

    if [ -n "$repo_url" ]; then
        existing_sources="$(find_repo_sources "$repo_url" "$list_dest" || true)"
    else
        existing_sources=""
    fi

    if [ -n "$existing_sources" ]; then
        rm -f "$list_dest" "$key_dest"
        log "Keeping existing $name repository configuration from $(printf '%s' "$existing_sources" | tr '\n' ' ')."
        return
    fi

    mkdir -p "$(dirname "$list_dest")" "$(dirname "$key_dest")"
    install -m 0644 "$key_src" "$key_dest"
    install -m 0644 "$list_src" "$list_dest"
    log "Registered the $name repository for future updates."
}

install_repo_registration_dearmored() {
    local name="$1"
    local list_src="$2"
    local key_src="$3"
    local list_dest="$4"
    local key_dest="$5"
    local repo_url="${6:-}"
    local existing_sources

    if [ ! -f "$list_src" ] || [ ! -f "$key_src" ]; then
        warn "Skipping $name repository registration: staged metadata is missing."
        return
    fi

    if [ -n "$repo_url" ]; then
        existing_sources="$(find_repo_sources "$repo_url" "$list_dest" || true)"
    else
        existing_sources=""
    fi

    if [ -n "$existing_sources" ]; then
        rm -f "$list_dest"
        log "Keeping existing $name repository configuration from $(printf '%s' "$existing_sources" | tr '\n' ' ')."
        return
    fi

    mkdir -p "$(dirname "$list_dest")" "$(dirname "$key_dest")"
    install -m 0644 "$list_src" "$list_dest"

    if [ -f "$key_dest" ]; then
        log "Keeping existing $name repository keyring."
        return
    fi

    if ! command -v gpg >/dev/null 2>&1; then
        warn "gpg is unavailable; could not install the $name repository keyring."
        return
    fi

    gpg --batch --yes --dearmor --output "$key_dest" "$key_src"
    chmod 0644 "$key_dest"
    log "Registered the $name repository for future updates."
}

ensure_bookmark_lines() {
    local target_file="$1"
    local home_dir="$2"
    local tmp_file
    local line
    local computer_line="file:/// Computer"
    local default_lines=(
        "file://$home_dir/Documents Documents"
        "file://$home_dir/Music Music"
        "file://$home_dir/Pictures Pictures"
        "file://$home_dir/Videos Videos"
        "file://$home_dir/Downloads Downloads"
    )

    mkdir -p "$(dirname "$target_file")"

    tmp_file="$(mktemp)"
    printf '%s\n' "$computer_line" > "$tmp_file"

    for line in "${default_lines[@]}"; do
        printf '%s\n' "$line" >> "$tmp_file"
    done

    if [ -f "$target_file" ]; then
        while IFS= read -r line; do
            [ -n "$line" ] || continue
            grep -Fxq "$line" "$tmp_file" && continue
            printf '%s\n' "$line" >> "$tmp_file"
        done < "$target_file"
    fi

    mv "$tmp_file" "$target_file"
}

seed_primary_sources() {
    local source_file="/usr/local/src/jamlinux/sources.list"

    if [ ! -s "$source_file" ]; then
        warn "No staged Debian sources.list was found."
        return
    fi

    install -m 0644 "$source_file" /etc/apt/sources.list
    log "Installed Debian package sources."
}

seed_external_repositories() {
    install_repo_registration_dearmored \
        "VS Code" \
        "/usr/local/src/jamlinux/repositories/vscode.list" \
        "/usr/local/src/jamlinux/repositories/microsoft.asc" \
        "/etc/apt/sources.list.d/vscode.list" \
        "/usr/share/keyrings/microsoft.gpg" \
        "https://packages.microsoft.com/repos/code"

    install_repo_registration_dearmored \
        "Julian's package repo" \
        "/usr/local/src/jamlinux/repositories/julians-package-repo.list" \
        "/usr/local/src/jamlinux/repositories/julians-package-repo.asc" \
        "/etc/apt/sources.list.d/julians-package-repo.list" \
        "/usr/share/keyrings/julians-package-repo.gpg"
}

ensure_login_keyring_pam() {
    if ! command -v pam-auth-update >/dev/null 2>&1; then
        warn "pam-auth-update is unavailable; GNOME keyring PAM integration was not verified."
        return
    fi

    if [ ! -f /usr/share/pam-configs/gnome-keyring ]; then
        warn "gnome-keyring PAM profile is missing; login keyring auto-unlock may not work."
        return
    fi

    if pam-auth-update --package --enable gnome-keyring >/dev/null 2>&1; then
        log "Enabled PAM integration for GNOME keyring auto-unlock."
    else
        warn "Failed to enable GNOME keyring PAM integration."
    fi
}

enable_first_boot_service() {
    local service_file="/etc/systemd/system/jamlinux-first-boot.service"
    local wants_dir="/etc/systemd/system/multi-user.target.wants"

    if [ ! -f "$service_file" ]; then
        warn "First-boot service file is missing."
        return
    fi

    mkdir -p "$wants_dir"
    ln -sf ../jamlinux-first-boot.service "$wants_dir/jamlinux-first-boot.service"
    log "Enabled jamlinux-first-boot.service."
}

apply_dconf_databases() {
    if [ -x /usr/local/bin/update_dconf.sh ]; then
        /usr/local/bin/update_dconf.sh || warn "dconf database refresh failed."
        return
    fi

    if command -v dconf >/dev/null 2>&1; then
        dconf update || warn "dconf database refresh failed."
        return
    fi

    warn "dconf is not available."
}

apply_shell_theme() {
    if [ ! -x /usr/local/bin/install_theme.sh ]; then
        warn "Theme activation script is missing."
        return
    fi

    /usr/local/bin/install_theme.sh || warn "Theme activation failed."
}

apply_chromium_defaults() {
    if [ ! -x /usr/local/bin/configure_chromium.sh ]; then
        warn "Chromium configuration script is missing."
        return
    fi

    /usr/local/bin/configure_chromium.sh || warn "Chromium configuration failed."
}

seed_files_bookmarks() {
    local home_dir bookmark_file

    for home_dir in /home/*; do
        [ -d "$home_dir" ] || continue

        bookmark_file="$home_dir/.config/gtk-3.0/bookmarks"
        ensure_bookmark_lines "$bookmark_file" "$home_dir"
        chown "$(stat -c '%u:%g' "$home_dir")" "$bookmark_file" || warn "Failed to set ownership on $bookmark_file."
    done

    log "Seeded Files sidebar bookmarks."
}

apply_plymouth_theme() {
    if [ ! -f /usr/share/plymouth/themes/jamlinux/jamlinux.plymouth ]; then
        warn "JamLinux Plymouth theme files are missing."
        return
    fi

    if command -v plymouth-set-default-theme >/dev/null 2>&1; then
        plymouth-set-default-theme -R jamlinux || warn "Failed to set the default Plymouth theme."
    else
        warn "plymouth-set-default-theme is not available."
    fi

    if command -v update-initramfs >/dev/null 2>&1; then
        update-initramfs -u || warn "Failed to rebuild initramfs."
    fi
}

apply_grub_theme() {
    if [ ! -f /etc/default/grub.d/99-custom.cfg ] || [ ! -f /usr/share/grub/themes/jamlinux/theme.txt ]; then
        warn "JamLinux GRUB theme files are missing."
        return
    fi

    if command -v update-grub >/dev/null 2>&1; then
        update-grub || warn "Failed to rebuild GRUB configuration."
        return
    fi

    if command -v grub-mkconfig >/dev/null 2>&1 && [ -d /boot/grub ]; then
        grub-mkconfig -o /boot/grub/grub.cfg || warn "Failed to rebuild GRUB configuration."
        return
    fi

    warn "Neither update-grub nor grub-mkconfig is available."
}

main() {
    seed_primary_sources
    seed_external_repositories
    ensure_login_keyring_pam
    enable_first_boot_service
    apply_chromium_defaults
    seed_files_bookmarks
    apply_dconf_databases
    apply_shell_theme
    apply_plymouth_theme
    apply_grub_theme
    log "Installed-system activation complete."
}

main "$@"
