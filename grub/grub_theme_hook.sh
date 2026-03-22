#!/bin/bash
set -e

echo "Setting up GRUB branding..."

# Install Plymouth theme for boot splash
apt-get install -y plymouth plymouth-themes

# Activate the JamLinux Plymouth theme if it has been staged into the image.
if [ -f /usr/share/plymouth/themes/jamlinux/jamlinux.plymouth ]; then
    plymouth-set-default-theme -R jamlinux 2>/dev/null || true
fi

# Update GRUB with custom settings
update-grub 2>/dev/null || true
