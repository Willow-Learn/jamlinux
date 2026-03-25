#!/bin/bash
set -e

echo "Configuring Google Chrome defaults and managed policies..."

# Chrome reads managed policies from /etc/opt/chrome/policies/managed/
install -d -m 755 /etc/opt/chrome/policies/managed

cat > /etc/opt/chrome/policies/managed/10-jamlinux.json <<'EOF'
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

chmod 644 /etc/opt/chrome/policies/managed/10-jamlinux.json

# Chrome master_preferences
CHROME_DIR="/opt/google/chrome"
if [ -d "$CHROME_DIR" ]; then
    cat > "$CHROME_DIR/master_preferences" <<'EOF'
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
    chmod 644 "$CHROME_DIR/master_preferences"
fi

# Initial bookmarks
install -d -m 755 /usr/share/google-chrome
cat > /usr/share/google-chrome/initial_bookmarks.html <<'EOF'
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

chmod 644 /usr/share/google-chrome/initial_bookmarks.html

echo "Google Chrome defaults and policies configured."
