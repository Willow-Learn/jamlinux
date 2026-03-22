#!/bin/bash
set -e

echo "Setting up JamLinux visual identity (Yaru + JamLinux Shell)..."

# Fonts and Yaru are provided by the image package lists.

# === CUSTOM SHELL THEME: JamLinux-Shell ===
mkdir -p /usr/share/themes/JamLinux-Shell/gnome-shell

cat > /usr/share/themes/JamLinux-Shell/gnome-shell/gnome-shell.css << 'CSS'
/* JamLinux Shell Theme - Inter + Noto */
stage {
    font-family: "Inter", "Noto Sans", sans-serif;
    font-size: 11pt;
    font-weight: 500;
}

#panel {
    font-family: "Inter", "Noto Sans", sans-serif;
    font-size: 11pt;
    font-weight: 500;
    height: 28px;
}

#panel .panel-button {
    font-family: "Inter", "Noto Sans", sans-serif;
    font-weight: 500;
}

.calendar,
.message-list,
.notification {
    font-family: "Inter", "Noto Sans", sans-serif;
    font-size: 10.5pt;
}

.search-entry {
    font-family: "Inter", "Noto Sans", sans-serif;
    font-size: 14pt;
}

.osd-window,
.modal-dialog {
    font-family: "Inter", "Noto Sans", sans-serif;
}
CSS

chmod -R a+rX /usr/share/themes/JamLinux-Shell/

echo "JamLinux theme setup complete."
