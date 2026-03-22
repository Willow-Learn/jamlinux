#!/bin/bash
set -e

echo "Setting up installer..."

# Note: The installer slideshow is complex to customize
# This sets basic branding strings

# Update distributor name for installer
echo "JamLinux" > /etc/distributor-name

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