cd $BASE_DIR

# List installed extensions
ls ~/.local/share/gnome-shell/extensions/ > extensions-list.txt 2>/dev/null || echo "No user extensions"

# Get GNOME Shell version (needed for extension compatibility)
gnome-shell --version > gnome-shell-version.txt

# Copy extensions metadata for version info
mkdir -p extensions-metadata
for ext in ~/.local/share/gnome-shell/extensions/*; do
    if [ -d "$ext" ]; then
        uuid=$(basename "$ext")
        cp "$ext/metadata.json" "extensions-metadata/${uuid}.json" 2>/dev/null || true
    fi
done

# Also check system extensions
ls /usr/share/gnome-shell/extensions/ > extensions-system-list.txt 2>/dev/null || true