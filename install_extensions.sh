#!/bin/bash
set -e

echo "Finalizing staged GNOME Shell extensions..."

EXTENSIONS_DIR=/usr/share/gnome-shell/extensions

# Create system extensions directory
mkdir -p "$EXTENSIONS_DIR"

extract_extension_archive() {
    local archive tmp_dir metadata uuid source_dir target_dir

    archive="$1"
    tmp_dir=$(mktemp -d)

    unzip -q "$archive" -d "$tmp_dir"

    metadata=$(find "$tmp_dir" -maxdepth 2 -name metadata.json -print | head -n 1)
    if [ -z "$metadata" ]; then
        echo "  Skipping $(basename "$archive"): metadata.json not found"
        rm -rf "$tmp_dir"
        return
    fi

    uuid=$(sed -n 's/.*"uuid"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$metadata" | head -n 1)
    if [ -z "$uuid" ]; then
        echo "  Skipping $(basename "$archive"): uuid missing from metadata.json"
        rm -rf "$tmp_dir"
        return
    fi

    source_dir=$(dirname "$metadata")
    target_dir="$EXTENSIONS_DIR/$uuid"

    rm -rf "$target_dir"
    mkdir -p "$target_dir"
    cp -a "$source_dir"/. "$target_dir"/
    rm -f "$archive"
    rm -rf "$tmp_dir"

    echo "  Unpacked $(basename "$archive") -> $uuid"
}

for archive in "$EXTENSIONS_DIR"/*.zip; do
    [ -f "$archive" ] || continue
    extract_extension_archive "$archive"
done

installed_count=0
for extension_dir in "$EXTENSIONS_DIR"/*; do
    if [ -d "$extension_dir" ]; then
        installed_count=$((installed_count + 1))
        echo "  Found $(basename "$extension_dir")"
    fi
done

if [ "$installed_count" -eq 0 ]; then
    echo "  No staged GNOME Shell extensions found."
fi

# Fix permissions
chmod -R 755 "$EXTENSIONS_DIR"
chown -R root:root "$EXTENSIONS_DIR" 2>/dev/null || true

# Compile schemas for extensions
for schema in "$EXTENSIONS_DIR"/*/schemas/*.gschema.xml; do
    if [ -f "$schema" ]; then
        dir=$(dirname "$schema")
        glib-compile-schemas "$dir" 2>/dev/null || true
    fi
done

echo "Extensions ready."
