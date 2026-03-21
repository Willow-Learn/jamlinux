#!/bin/bash
set -e

echo "Installing GNOME Shell extensions system-wide..."

# Get GNOME Shell version for compatibility
GNOME_VERSION=$(gnome-shell --version | grep -oP '\d+\.?\d*' | head -1)
GNOME_MAJOR=$(echo "$GNOME_VERSION" | cut -d. -f1)

echo "Detected GNOME Shell version: $GNOME_VERSION (major: $GNOME_MAJOR)"

# Create system extensions directory
mkdir -p /usr/share/gnome-shell/extensions

# Function to download extension
download_extension() {
    local uuid="$1"
    local name="$2"
    local version="$3"
    
    echo "Downloading $name ($uuid)..."
    
    # Try to download specific version, fallback to latest
    if [ -n "$version" ]; then
        curl -L "https://extensions.gnome.org/extension-data/${uuid}.v${version}.shell-extension.zip" \
            -o "/tmp/${uuid}.zip" 2>/dev/null || {
            echo "  Failed to download specific version, trying latest..."
            curl -L "https://extensions.gnome.org/extension-data/${uuid}.shell-extension.zip" \
                -o "/tmp/${uuid}.zip" 2>/dev/null
        }
    else
        curl -L "https://extensions.gnome.org/extension-data/${uuid}.shell-extension.zip" \
            -o "/tmp/${uuid}.zip" 2>/dev/null
    fi
    
    if [ -f "/tmp/${uuid}.zip" ]; then
        mkdir -p "/usr/share/gnome-shell/extensions/${uuid}"
        unzip -q -o "/tmp/${uuid}.zip" -d "/usr/share/gnome-shell/extensions/${uuid}"
        rm "/tmp/${uuid}.zip"
        echo "  Installed $name"
    else
        echo "  FAILED to download $name"
    fi
}

# Install requested extensions
download_extension "dash-to-dock@micxgx.gmail.com" "Dash to Dock" ""
download_extension "switcher@landau.fi" "Switcher" ""
download_extension "monitor@astraext.github.io" "System Monitor" ""
download_extension "caffeine@patapon.info" "Caffeine" ""
download_extension "simplebreakreminder@castillodel.com" "Simple Break Reminder" ""
download_extension "clipboard-indicator@tudmotu.com" "Clipboard Indicator" ""
download_extension "gsconnect@andyholmes.github.io" "GSConnect" ""
download_extension "user-theme@gnome-shell-extensions.gcampax.github.com" "User Themes" ""
download_extension "transparent-top-bar@ftpix.com" "Transparent Top Bar" ""
download_extension "blur-my-shell@aunetx" "Blur My Shell" ""

# Add more extensions from your extensions-list.txt
# Format: download_extension "UUID" "Friendly Name" "version"

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

echo "Extensions installed."