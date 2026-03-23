#!/bin/bash
set -e

echo "Configuring Chromium defaults and managed policies..."

install -d -m 755 /etc/chromium/policies/managed

cat > /etc/chromium/policies/managed/10-jamlinux.json <<'EOF'
{
  "ExtensionInstallForcelist": [
    "ddkjiahejlhfcafbddmgiahcphecmpfh;https://clients2.google.com/service/update2/crx",
    "bkdgflcldnnnapblkhphbgpggdiikppg;https://clients2.google.com/service/update2/crx"
  ],
  "RestoreOnStartup": 1,
  "HomepageIsNewTabPage": true,
  "ShowHomeButton": true
}
EOF

chmod 644 /etc/chromium/policies/managed/10-jamlinux.json

if [ -f /etc/chromium/master_preferences ]; then
    sed -i 's/"import_bookmarks"[[:space:]]*:[[:space:]]*false/"import_bookmarks": true/' /etc/chromium/master_preferences
    sed -i 's|"homepage"[[:space:]]*:[[:space:]]*"[^"]*"|"homepage": "chrome://newtab/"|' /etc/chromium/master_preferences
    sed -i 's/"homepage_is_newtabpage"[[:space:]]*:[[:space:]]*false/"homepage_is_newtabpage": true/' /etc/chromium/master_preferences
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