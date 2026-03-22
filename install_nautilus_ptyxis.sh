#!/bin/bash
set -e

echo "Building JamLinux Nautilus Ptyxis extension..."

SOURCE_FILE="/usr/local/src/jamlinux/nautilus-ptyxis.c"
BUILD_DIR="/tmp/jamlinux-nautilus-ptyxis"
OUTPUT_FILE="$BUILD_DIR/libnautilus-ptyxis.so"

if [[ ! -f "$SOURCE_FILE" ]]; then
    echo "Missing source file: $SOURCE_FILE" >&2
    exit 1
fi

if ! command -v nautilus >/dev/null 2>&1; then
    echo "Nautilus is not installed; skipping Nautilus Ptyxis extension build."
    exit 0
fi

mkdir -p "$BUILD_DIR"

gcc -fPIC -shared "$SOURCE_FILE" -o "$OUTPUT_FILE" \
    $(pkg-config --cflags --libs gio-2.0 glib-2.0 gobject-2.0 libnautilus-extension-4)

extension_dir=""
if command -v dpkg-architecture >/dev/null 2>&1; then
    multiarch="$(dpkg-architecture -qDEB_HOST_MULTIARCH)"
    extension_dir="/usr/lib/${multiarch}/nautilus/extensions-4"
fi

if [[ -z "$extension_dir" || ! -d "$extension_dir" ]]; then
    extension_dir="/usr/lib/nautilus/extensions-4"
fi

mkdir -p "$extension_dir"
cp -v "$OUTPUT_FILE" "$extension_dir/"

rm -rf "$BUILD_DIR"

echo "JamLinux Nautilus Ptyxis extension installed to $extension_dir"