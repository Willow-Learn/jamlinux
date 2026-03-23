#!/bin/bash
set -eu

export DEBIAN_FRONTEND=noninteractive

log() {
    echo "[jamlinux installed-system] $*"
}

warn() {
    echo "[jamlinux installed-system] warning: $*" >&2
}

ensure_bookmark_line() {
    local target_file="$1"
    local bookmark_line="file:/// Computer"
    local tmp_file

    mkdir -p "$(dirname "$target_file")"

    if [ -f "$target_file" ] && grep -Fxq "$bookmark_line" "$target_file"; then
        return
    fi

    tmp_file="$(mktemp)"
    printf '%s\n' "$bookmark_line" > "$tmp_file"

    if [ -f "$target_file" ]; then
        cat "$target_file" >> "$tmp_file"
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

seed_files_bookmarks() {
    local home_dir bookmark_file

    ensure_bookmark_line /etc/skel/.config/gtk-3.0/bookmarks

    for home_dir in /home/*; do
        [ -d "$home_dir" ] || continue

        bookmark_file="$home_dir/.config/gtk-3.0/bookmarks"
        ensure_bookmark_line "$bookmark_file"
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
    enable_first_boot_service
    seed_files_bookmarks
    apply_dconf_databases
    apply_shell_theme
    apply_plymouth_theme
    apply_grub_theme
    log "Installed-system activation complete."
}

main "$@"
