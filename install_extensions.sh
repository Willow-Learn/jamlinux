#!/bin/bash
set -e

echo "Finalizing staged GNOME Shell extensions..."

# Create system extensions directory
mkdir -p /usr/share/gnome-shell/extensions

installed_count=0
for extension_dir in /usr/share/gnome-shell/extensions/*; do
    if [ -d "$extension_dir" ]; then
        installed_count=$((installed_count + 1))
        echo "  Found $(basename "$extension_dir")"
    fi
done

if [ "$installed_count" -eq 0 ]; then
    echo "  No staged GNOME Shell extensions found."
fi

# Fix permissions
chmod -R 755 /usr/share/gnome-shell/extensions/
chown -R root:root /usr/share/gnome-shell/extensions/

# Compile schemas for extensions
for schema in /usr/share/gnome-shell/extensions/*/schemas/*.gschema.xml; do
    if [ -f "$schema" ]; then
        dir=$(dirname "$schema")
        glib-compile-schemas "$dir" 2>/dev/null || true
    fi
done

echo "Extensions ready."