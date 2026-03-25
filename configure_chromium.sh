#!/bin/bash
set -e

echo "Configuring Thorium browser defaults and managed policies..."

# Thorium uses the same Chromium policy format
install -d -m 755 /etc/thorium/policies/managed

cat > /etc/thorium/policies/managed/10-jamlinux.json <<'EOF'
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
    }
  },
  "RestoreOnStartup": 1,
  "HomepageIsNewTabPage": true,
  "ShowHomeButton": true,
  "DefaultSearchProviderEnabled": true,
  "DefaultSearchProviderName": "DuckDuckGo",
  "DefaultSearchProviderSearchURL": "https://duckduckgo.com/?q={searchTerms}",
  "DefaultSearchProviderKeyword": "@ddg",
  "DefaultSearchProviderIconURL": "https://duckduckgo.com/favicon.ico",
  "DefaultSearchProviderSuggestURL": "https://duckduckgo.com/ac/?q={searchTerms}&type=list",
  "ManagedSearchEngines": [
    {
      "name": "DuckDuckGo",
      "keyword": "@ddg",
      "search_url": "https://duckduckgo.com/?q={searchTerms}",
      "suggest_url": "https://duckduckgo.com/ac/?q={searchTerms}&type=list",
      "favicon_url": "https://duckduckgo.com/favicon.ico",
      "is_default": true
    },
    {
      "name": "Google",
      "keyword": "@g",
      "search_url": "https://www.google.com/search?q={searchTerms}",
      "suggest_url": "https://www.google.com/complete/search?output=chrome&q={searchTerms}",
      "favicon_url": "https://www.google.com/favicon.ico"
    }
  ]
}
EOF

chmod 644 /etc/thorium/policies/managed/10-jamlinux.json

# Thorium master_preferences
THORIUM_DIR="/opt/chromium.org/thorium"
if [ -d "$THORIUM_DIR" ]; then
    cat > "$THORIUM_DIR/master_preferences" <<'EOF'
{
  "distribution": {
    "import_bookmarks": true
  },
  "browser": {
    "show_home_button": true
  },
  "toolbar": {
    "pinned_actions": ["kActionSidePanelShowReadAnything", "kActionSplitTab"]
  },
  "homepage": "chrome://newtab/",
  "homepage_is_newtabpage": true
}
EOF
    chmod 644 "$THORIUM_DIR/master_preferences"
fi

# Initial bookmarks
install -d -m 755 /usr/share/thorium
cat > /usr/share/thorium/initial_bookmarks.html <<'EOF'
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

chmod 644 /usr/share/thorium/initial_bookmarks.html

echo "Thorium browser defaults and policies configured."
