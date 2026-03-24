#!/bin/bash
set -e

echo "Setting up installer branding..."

# Update distributor name for installer
echo "JamLinux" > /etc/distributor-name

# Replace the Debian installer banner/logo with JamLinux branding.
# The graphical installer (d-i GTK) displays /usr/share/graphics/logo_debian.png
# as the banner at the top of every screen.
if [ -f /usr/share/images/jamlinux/installer-banner.png ]; then
    mkdir -p /usr/share/graphics
    cp /usr/share/images/jamlinux/installer-banner.png /usr/share/graphics/logo_debian.png
    echo "Installer banner replaced with JamLinux branding"
fi

# Create a custom preseed file for unattended options if desired
mkdir -p /usr/share/live-installer
cat > /usr/share/live-installer/README << 'EOF'
JamLinux Installer
==================

Welcome to JamLinux, a customized Debian Testing (Forky) distribution.

This installer is based on Debian's live-installer with custom theming
and pre-installed packages.

For support, visit: https://github.com/yourusername/jamlinux
EOF