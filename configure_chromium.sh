#!/bin/bash
set -e

echo "Configuring Chromium defaults and managed policies..."

install -d -m 755 /etc/chromium/policies/managed

cat > /etc/chromium/policies/managed/10-jamlinux.json <<'EOF'
{
  "ExtensionSettings": {
    "*": {
      "toolbar_pin": "force_unpinned"
    },
    "ddkjiahejlhfcafbddmgiahcphecmpfh": {
      "installation_mode": "force_installed",
      "update_url": "https://clients2.google.com/service/update2/crx"
    },
    "pkehgijcmpdhfbdbbnkijodmdjhbjlgp": {
      "installation_mode": "force_installed",
      "update_url": "https://clients2.google.com/service/update2/crx"
    },
    "ldpochfccmkkmhdbclfhpagapcfdljkj": {
      "installation_mode": "force_installed",
      "update_url": "https://clients2.google.com/service/update2/crx"
    },
    "kceglpglilklghkgofolieongaolnaob": {
      "installation_mode": "force_installed",
      "update_url": "https://clients2.google.com/service/update2/crx"
    },
    "noogafoofpebimajpfpamcfhoaifemoa": {
      "installation_mode": "force_installed",
      "update_url": "https://clients2.google.com/service/update2/crx"
    },
    "mnjggcdmjocbbbhaepdhchncahnbgone": {
      "installation_mode": "force_installed",
      "update_url": "https://clients2.google.com/service/update2/crx"
    },
    "edacconmaakjimmfgnblocblbcdcpbko": {
      "installation_mode": "force_installed",
      "update_url": "https://clients2.google.com/service/update2/crx",
      "toolbar_pin": "force_pinned"
    },
    "gppongmhjkpfnbhagpmjfkannfbllamg": {
      "installation_mode": "force_installed",
      "update_url": "https://clients2.google.com/service/update2/crx"
    }
  },
  "RestoreOnStartup": 1,
  "HomepageIsNewTabPage": true,
  "ShowHomeButton": true
}
EOF

chmod 644 /etc/chromium/policies/managed/10-jamlinux.json

if [ -f /etc/chromium/master_preferences ]; then
    python3 - <<'PY'
import json
from pathlib import Path

path = Path("/etc/chromium/master_preferences")
data = json.loads(path.read_text())

distribution = data.setdefault("distribution", {})
distribution["import_bookmarks"] = True

browser = data.setdefault("browser", {})
browser["show_home_button"] = True

toolbar = data.setdefault("toolbar", {})
pinned_actions = toolbar.get("pinned_actions")
if not isinstance(pinned_actions, list):
    pinned_actions = []

reading_mode_action = "kActionSidePanelShowReadAnything"
if reading_mode_action not in pinned_actions:
    pinned_actions.append(reading_mode_action)
toolbar["pinned_actions"] = pinned_actions

data["homepage"] = "chrome://newtab/"
data["homepage_is_newtabpage"] = True

path.write_text(json.dumps(data, indent=2) + "\n")
PY
fi

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

echo "Chromium defaults and policies configured."
