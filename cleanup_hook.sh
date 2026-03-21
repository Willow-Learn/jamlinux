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

echo "Cleanup complete."