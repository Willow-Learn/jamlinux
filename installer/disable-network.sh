#!/bin/sh
set -eu

PATH=/bin:/sbin:/usr/bin:/usr/sbin

log() {
    echo "[jamlinux installer] $*" >/dev/tty1 2>/dev/null || true
}

seed_debconf() {
    if command -v debconf-set >/dev/null 2>&1; then
        printf '%s\n' \
            'netcfg netcfg/enable boolean false' \
            'netcfg netcfg/disable_autoconfig boolean true' \
            'apt-setup apt-setup/use_mirror boolean false' \
            'hw-detect hw-detect/load_firmware boolean false' |
            debconf-set || true
    fi
}

disable_network_helpers() {
    for helper in \
        /lib/debian-installer.d/S40network \
        /lib/netcfg/menu-item \
        /sbin/netcfg \
        /bin/netcfg
    do
        [ -e "$helper" ] || continue
        chmod -x "$helper" 2>/dev/null || true
    done
}

stop_network_clients() {
    for client in \
        NetworkManager \
        wpa_supplicant \
        dhclient \
        dhcpcd \
        pump \
        udhcpc
    do
        killall "$client" 2>/dev/null || true
    done
}

bring_interfaces_down() {
    for device in /sys/class/net/*; do
        [ -e "$device" ] || continue
        name="$(basename "$device")"
        [ "$name" = "lo" ] && continue

        ip link set "$name" down 2>/dev/null || true
        ifconfig "$name" down 2>/dev/null || true
    done
}

main() {
    log "forcing offline install mode"
    seed_debconf
    disable_network_helpers
    stop_network_clients
    bring_interfaces_down
}

main "$@"
