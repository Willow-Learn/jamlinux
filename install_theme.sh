#!/bin/bash
set -e

echo "Setting up JamLinux visual identity (Yaru + Custom Shell)..."

# === FONTS ===
cd /tmp

# Install Inter
curl -L "https://github.com/rsms/inter/releases/download/v4.0/Inter-4.0.zip" -o inter.zip 2>/dev/null || true
if [ -f inter.zip ]; then
    mkdir -p /usr/share/fonts/inter
    unzip -q inter.zip -d /usr/share/fonts/inter/
fi

# Install JetBrains Mono
curl -L "https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip" \
    -o jbmono.zip 2>/dev/null || true
if [ -f jbmono.zip ]; then
    mkdir -p /usr/share/fonts/jetbrains-mono
    unzip -q jbmono.zip -d /usr/share/fonts/jetbrains-mono/
fi

fc-cache -f -v

# === YARU THEME (GTK + Icons + Cursor) ===
apt-get install -y yaru-theme-gtk yaru-theme-icon yaru-theme-sound

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

chmod -R 755 /usr/share/themes/JamLinux-Shell/

echo "JamLinux theme setup complete."