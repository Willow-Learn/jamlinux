#!/bin/bash
set -e

echo "Cleaning up build artifacts..."

# Clean apt cache
apt-get clean
rm -rf /var/lib/apt/lists/*

# Remove unnecessary files
rm -f /etc/resolv.conf
rm -rf /tmp/*
rm -rf /var/tmp/*

# Ensure proper permissions
chown root:root /usr/share/gnome-shell/extensions -R 2>/dev/null || true

# Disable services installed for desktop, development, or hardware support that
# should not run at boot by default.
# Users can start unmasked services manually with: systemctl start <unit>
#
# We manipulate symlinks directly because systemctl may not function
# correctly inside a live-build chroot (no running systemd).  This
# ensures services are disabled on the live CD and on the installed system.
SERVICES_TO_DISABLE="
apache2
avahi-daemon
containerd
cups
cups-browsed
dictd
docker
iscsid
ksmbd
libvirt-guests
libvirtd
mariadb
ModemManager
nginx
NetworkManager-wait-online
open-iscsi
openvpn
postgresql
redis-server
ssh
strongswan-starter
syncthing
tor
tor@default
virtlockd
virtlogd
wsdd2
"

SOCKETS_TO_DISABLE="
docker
iscsid
libvirtd
libvirtd-admin
libvirtd-ro
virtlockd
virtlockd-admin
virtlogd
virtlogd-admin
"

ALIASES_TO_DISABLE="
dbus-org.freedesktop.ModemManager1.service
iscsi.service
ipsec.service
"

UNITS_TO_MASK="
plymouth-quit-wait.service
"

disable_unit() {
    local unit="$1"
    local systemd_dir

    for systemd_dir in /etc/systemd/system /run/systemd/system /lib/systemd/system /usr/lib/systemd/system; do
        [ -d "$systemd_dir" ] || continue
        find "$systemd_dir" -type l \
            \( -path "*.wants/${unit}" -o -path "*.requires/${unit}" \) \
            -delete
    done

    rm -f "/etc/systemd/system/${unit}"
    echo "Disabled ${unit}"
}

mask_unit() {
    local unit="$1"

    disable_unit "$unit"
    ln -sf /dev/null "/etc/systemd/system/${unit}"
    echo "Masked ${unit}"
}

for svc in $SERVICES_TO_DISABLE; do
    disable_unit "${svc}.service"
done

for sock in $SOCKETS_TO_DISABLE; do
    disable_unit "${sock}.socket"
done

for alias in $ALIASES_TO_DISABLE; do
    disable_unit "$alias"
done

for unit in $UNITS_TO_MASK; do
    mask_unit "$unit"
done

# Handle version-dependent php-fpm service (e.g. php8.4-fpm)
for unit in /lib/systemd/system/php*-fpm.service; do
    [ -e "$unit" ] || continue
    svc="$(basename "$unit")"
    disable_unit "$svc"
done

echo "Cleanup complete."
