#!/bin/bash
set -e

echo "Configuring Chromium defaults and managed policies..."

install -d -m 755 /etc/chromium/policies/managed

cat > /etc/chromium/policies/managed/10-jamlinux.json <<'EOF'
{
  "ExtensionSettings": {
    "ddkjiahejlhfcafbddmgiahcphecmpfh": {
      "installation_mode": "normal_installed",
      "update_url": "https://clients2.google.com/service/update2/crx"
    },
    "pkehgijcmpdhfbdbbnkijodmdjhbjlgp": {
      "installation_mode": "normal_installed",
      "update_url": "https://clients2.google.com/service/update2/crx"
    },
    "ldpochfccmkkmhdbclfhpagapcfdljkj": {
      "installation_mode": "normal_installed",
      "update_url": "https://clients2.google.com/service/update2/crx"
    },
    "noogafoofpebimajpfpamcfhoaifemoa": {
      "installation_mode": "normal_installed",
      "update_url": "https://clients2.google.com/service/update2/crx"
    },
    "mnjggcdmjocbbbhaepdhchncahnbgone": {
      "installation_mode": "normal_installed",
      "update_url": "https://clients2.google.com/service/update2/crx"
    },
    "edacconmaakjimmfgnblocblbcdcpbko": {
      "installation_mode": "normal_installed",
      "update_url": "https://clients2.google.com/service/update2/crx"
    }
  }
}
EOF

chmod 644 /etc/chromium/policies/managed/10-jamlinux.json

python3 - <<'PY'
import json
from pathlib import Path

path = Path("/etc/chromium/master_preferences")
data = json.loads(path.read_text()) if path.exists() else {}

distribution = data.setdefault("distribution", {})
distribution["import_bookmarks"] = True

browser = data.setdefault("browser", {})
browser["show_home_button"] = True

toolbar = data.setdefault("toolbar", {})
pinned_actions = toolbar.get("pinned_actions")
if not isinstance(pinned_actions, list):
    pinned_actions = []

for action in ["kActionSidePanelShowReadAnything", "kActionSplitTab"]:
    if action not in pinned_actions:
        pinned_actions.append(action)
toolbar["pinned_actions"] = pinned_actions

data["homepage"] = "chrome://newtab/"
data["homepage_is_newtabpage"] = True

session = data.setdefault("session", {})
session["restore_on_startup"] = 1

path.write_text(json.dumps(data, indent=2) + "\n")
PY

install -d -m 755 /usr/share/chromium
cat > /usr/share/chromium/initial_bookmarks.html <<'EOF'
<!DOCTYPE NETSCAPE-Bookmark-file-1>
<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
<TITLE>Bookmarks</TITLE>
<H1>Bookmarks</H1>
<DL><p>
    <DT><H3 PERSONAL_TOOLBAR_FOLDER="true">Bookmarks Bar</H3>
    <DL><p>
        <DT><A HREF="https://www.jamlinux.org/">JamLinux</A>
    </DL><p>
</DL><p>
EOF

chmod 644 /usr/share/chromium/initial_bookmarks.html

# Install Widevine CDM for DRM-protected streaming (Netflix, Disney+, etc.)
# Google's standalone Widevine endpoint is gone, so we extract it from Chrome.
install_widevine() {
    local widevine_dir="/usr/lib/chromium/WidevineCdm"
    local chrome_url="https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
    local tmp_dir

    if [ -f "$widevine_dir/_platform_specific/linux_x64/libwidevinecdm.so" ]; then
        echo "Widevine CDM is already installed."
        return 0
    fi

    echo "Downloading Google Chrome to extract Widevine CDM..."

    tmp_dir="$(mktemp -d)"
    local chrome_deb="$tmp_dir/chrome.deb"

    if ! curl -fsSL --retry 3 --retry-all-errors -o "$chrome_deb" "$chrome_url"; then
        echo "ERROR: Could not download Google Chrome .deb."
        rm -rf "$tmp_dir"
        return 1
    fi

    # Extract the .deb without installing it
    dpkg-deb -x "$chrome_deb" "$tmp_dir/chrome"

    local src_dir="$tmp_dir/chrome/opt/google/chrome/WidevineCdm"
    if [ ! -d "$src_dir" ]; then
        echo "ERROR: WidevineCdm directory not found in Chrome .deb."
        rm -rf "$tmp_dir"
        return 1
    fi

    install -d -m 755 "$widevine_dir/_platform_specific/linux_x64"
    install -m 644 "$src_dir/LICENSE" "$widevine_dir/" 2>/dev/null || true
    install -m 644 "$src_dir/manifest.json" "$widevine_dir/"
    install -m 644 "$src_dir/_platform_specific/linux_x64/libwidevinecdm.so" \
        "$widevine_dir/_platform_specific/linux_x64/"

    rm -rf "$tmp_dir"
    echo "Widevine CDM installed successfully (extracted from Chrome)."
}

install_widevine

echo "Chromium defaults and policies configured."
