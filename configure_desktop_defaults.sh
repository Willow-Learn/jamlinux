#!/bin/bash
set -e

echo "Configuring JamLinux desktop defaults..."

mkdir -p /etc/xdg /etc/skel/.config

cat > /etc/xdg/mimeapps.list <<'EOF'
[Default Applications]
application/xhtml+xml=chromium.desktop
text/html=chromium.desktop
x-scheme-handler/about=chromium.desktop
x-scheme-handler/http=chromium.desktop
x-scheme-handler/https=chromium.desktop
EOF

cp /etc/xdg/mimeapps.list /etc/skel/.config/mimeapps.list

if [ -x /usr/bin/chromium ]; then
    update-alternatives --set x-www-browser /usr/bin/chromium 2>/dev/null || true
    update-alternatives --set gnome-www-browser /usr/bin/chromium 2>/dev/null || true
fi

if [ -x /usr/bin/ptyxis ]; then
    update-alternatives --set x-terminal-emulator /usr/bin/ptyxis 2>/dev/null || true

    mkdir -p /usr/local/share/applications
    if [ -f /usr/share/applications/org.gnome.Ptyxis.desktop ]; then
        sed \
            -e 's/^Name=Ptyxis$/Name=Terminal/' \
            -e 's/^Icon=org\.gnome\.Ptyxis$/Icon=utilities-terminal/' \
            /usr/share/applications/org.gnome.Ptyxis.desktop \
            > /usr/local/share/applications/org.gnome.Ptyxis.desktop
    fi
fi

mkdir -p /etc/systemd/logind.conf.d

cat > /etc/systemd/logind.conf.d/10-jamlinux-lid-switch.conf <<'EOF'
[Login]
HandleLidSwitch=suspend
HandleLidSwitchExternalPower=suspend
HandleLidSwitchDocked=suspend
EOF

packages_to_purge=()
for package in firefox firefox-esr gnome-terminal gnome-terminal-data nautilus-extension-gnome-terminal; do
    if dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
        packages_to_purge+=("$package")
    fi
done

if [ "${#packages_to_purge[@]}" -gt 0 ]; then
    apt-get purge -y "${packages_to_purge[@]}"
fi

echo "Desktop defaults configured."
