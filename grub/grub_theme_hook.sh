#!/bin/bash
set -e

echo "Setting up GRUB branding..."

# Install Plymouth theme for boot splash
apt-get install -y plymouth plymouth-themes

# Set default Plymouth theme (or install custom)
# plymouth-set-default-theme -R your-theme 2>/dev/null || true

# Update GRUB with custom settings
update-grub 2>/dev/null || true