#!/bin/bash
set -eu

export DEBIAN_FRONTEND=noninteractive

log() {
    echo "[jamlinux installed-system] $*"
}

warn() {
    echo "[jamlinux installed-system] warning: $*" >&2
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
    apply_dconf_databases
    apply_shell_theme
    apply_plymouth_theme
    apply_grub_theme
    log "Installed-system activation complete."
}

main "$@"
