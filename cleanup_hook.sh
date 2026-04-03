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

# Disable server services — installed for dev use, not to run at boot.
# Users can start them manually with: systemctl start <service>
#
# We manipulate symlinks directly because systemctl may not function
# correctly inside a live-build chroot (no running systemd).  This
# ensures services are disabled on the live CD and on the installed system.
SERVICES_TO_DISABLE="apache2 avahi-daemon containerd cups dictd docker libvirtd mariadb nginx postgresql redis-server ssh syncthing wsdd2"

for svc in $SERVICES_TO_DISABLE; do
    if [ -f "/lib/systemd/system/${svc}.service" ]; then
        rm -f "/etc/systemd/system/multi-user.target.wants/${svc}.service"
        rm -f "/etc/systemd/system/${svc}.service"
        echo "Disabled ${svc}.service"
    fi
done

# Handle version-dependent php-fpm service (e.g. php8.4-fpm)
for unit in /lib/systemd/system/php*-fpm.service; do
    [ -e "$unit" ] || continue
    svc="$(basename "$unit")"
    rm -f "/etc/systemd/system/multi-user.target.wants/${svc}"
    rm -f "/etc/systemd/system/${svc}"
    echo "Disabled ${svc}"
done

echo "Cleanup complete."
