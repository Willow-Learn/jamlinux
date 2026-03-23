#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Applying JamLinux live host fixes..."

install -Dm0644 "$ROOT_DIR/gnome/gdm" /etc/dconf/db/gdm.d/00-login-screen
if [ -f "$ROOT_DIR/backgrounds/login-lock-bg.jpg" ]; then
    install -Dm0644 "$ROOT_DIR/backgrounds/login-lock-bg.jpg" /usr/share/backgrounds/gdm/login-lock-bg.jpg
fi
dconf update

bash "$ROOT_DIR/install_theme.sh"

install -Dm0644 "$ROOT_DIR/plymouth/jamlinux/jamlinux.plymouth" /usr/share/plymouth/themes/jamlinux/jamlinux.plymouth
install -Dm0644 "$ROOT_DIR/plymouth/jamlinux/jamlinux.script" /usr/share/plymouth/themes/jamlinux/jamlinux.script
install -Dm0644 "$ROOT_DIR/branding/logo.png" /usr/share/plymouth/themes/jamlinux/logo.png
install -Dm0644 "$ROOT_DIR/plymouth/jamlinux/password_dot.png" /usr/share/plymouth/themes/jamlinux/password_dot.png
install -Dm0644 "$ROOT_DIR/plymouth/jamlinux/password_field.png" /usr/share/plymouth/themes/jamlinux/password_field.png

cat >/etc/plymouth/plymouthd.conf <<'EOF'
# Administrator customizations go in this file
[Daemon]
Theme=jamlinux
EOF

update-initramfs -u -k "$(uname -r)"

echo
echo "Verifying active GNOME Shell override..."
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
gresource extract /usr/share/gnome-shell/gnome-shell-theme.gresource /org/gnome/shell/theme/gnome-shell-dark.css > "$tmpdir/dark.css"
tail -n 40 "$tmpdir/dark.css"

echo
echo "Verifying initramfs contains JamLinux Plymouth assets..."
lsinitramfs /boot/initrd.img-"$(uname -r)" | grep -E 'usr/share/plymouth/themes/jamlinux/(jamlinux\.script|password_dot\.png|password_field\.png)$'

echo
echo "Done. Restart GDM to test lock screen:"
echo "  systemctl restart gdm"
echo "Then reboot to test the real LUKS prompt."
