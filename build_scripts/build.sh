#! /bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
export BUILD_DIR="$BASE_DIR/build/$(date +%Y%m%d)"

install_payload_file() {
    local source="$1"
    local relative_path="$2"
    local destination="$PAYLOAD_DIR/$relative_path"

    mkdir -p "$(dirname "$destination")"
    cp "$source" "$destination"
}

cleanup_live_build_mounts() {
    local build_root mount_point
    build_root="${BASE_DIR%/}/build"

    mapfile -t mount_points < <(
        findmnt -rn -o TARGET | \
            grep -E "^${build_root}/[0-9]+/chroot(/.*)?$" | \
            awk '{ print length($0), $0 }' | \
            sort -rn | \
            cut -d' ' -f2-
    )

    if [[ ${#mount_points[@]} -eq 0 ]]; then
        return
    fi

    echo "Unmounting leftover live-build mounts..."
    for mount_point in "${mount_points[@]}"; do
        sudo umount "$mount_point" 2>/dev/null || sudo umount -l "$mount_point"
    done
}

cleanup_live_build_mounts

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

cd $BUILD_DIR

# Initialize for Debian Trixie
sudo lb config \
    --distribution trixie \
    --archive-areas "main contrib non-free non-free-firmware" \
    --bootappend-install "netcfg/enable=false netcfg/choose_interface=none netcfg/disable_autoconfig=true apt-setup/use_mirror=false hw-detect/load_firmware=false" \
    --debian-installer live \
    --debian-installer-gui true \
    --debian-installer-preseedfile /preseed.cfg \
    --win32-loader false \
    --firmware-binary false \
    --iso-volume "JAMLINUX" \
    --iso-application "JamLinux" \
    --iso-publisher "Jamie Munro" \
    --iso-preparer "live-build" \
    --linux-packages "linux-image linux-headers" \
    --debian-installer-distribution trixie

# Create all necessary directories
mkdir -p config/{hooks/normal,hooks/binary,debian-installer,preseed,includes.chroot/etc/{skel/{.config,.local/share},dconf/db/{local.d,gdm.d},apt/{preferences.d,sources.list.d}},includes.installer,package-lists,bootloaders}
mkdir -p config/archives
mkdir -p config/includes.binary/jamlinux-installer/rootfs
mkdir -p config/includes.chroot/etc/live/config.conf.d
mkdir -p config/includes.chroot/usr/share/{gnome-shell/extensions,themes,icons,backgrounds/gdm,plymouth/themes,grub/themes/jamlinux}
mkdir -p config/includes.chroot/usr/share/images/jamlinux
mkdir -p config/includes.chroot/usr/local/bin
mkdir -p config/includes.chroot/usr/local/src/jamlinux
mkdir -p config/includes.chroot/etc/systemd/system
mkdir -p config/includes.chroot/etc/systemd/system/multi-user.target.wants
mkdir -p config/includes.chroot/var/lib/jamlinux

mkdir -p "$BUILD_DIR/config/includes.chroot/usr/share/gnome-shell/extensions/"
# Stage GNOME Shell extensions from the repository into the live image.
if [[ -n "$(find "$BASE_DIR/extensions" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
    cp -a "$BASE_DIR/extensions/." "$BUILD_DIR/config/includes.chroot/usr/share/gnome-shell/extensions/"
else
    echo "No local GNOME Shell extensions found in $BASE_DIR/extensions"
fi

cp "$BASE_DIR/sources/sources.list" "$BUILD_DIR/config/includes.chroot/etc/apt/sources.list"
cp "$BASE_DIR/sources/sources.list" "$BUILD_DIR/config/includes.chroot/usr/local/src/jamlinux/sources.list"

#package lists
cp "$BASE_DIR/packages/base_system" "$BUILD_DIR/config/package-lists/base.list.chroot"
cp "$BASE_DIR/packages/gnome" "$BUILD_DIR/config/package-lists/gnome.list.chroot"
cp "$BASE_DIR/packages/custom_packages" "$BUILD_DIR/config/package-lists/custom.list.chroot"

# Installer preseed
cp "$BASE_DIR/installer/udeb_exclude" "$BUILD_DIR/config/debian-installer/udeb_exclude"
cp "$BASE_DIR/preseed/installer.preseed" "$BUILD_DIR/config/preseed/jamlinux.cfg.installer"
cp "$BASE_DIR/installer/disable-network.sh" "$BUILD_DIR/config/includes.installer/jamlinux-disable-installer-network.sh"
chmod +x "$BUILD_DIR/config/includes.installer/jamlinux-disable-installer-network.sh"

# live session defaults
cat > "$BUILD_DIR/config/includes.chroot/etc/live/config.conf.d/hostname.conf" <<'EOF'
LIVE_HOSTNAME="jamlinux"
EOF

#dconf
mkdir -p "$BUILD_DIR/config/includes.chroot/etc/dconf/profile"
cp "$BASE_DIR/dconf/profile/user" "$BUILD_DIR/config/includes.chroot/etc/dconf/profile/user"
cp "$BASE_DIR/dconf/profile/gdm" "$BUILD_DIR/config/includes.chroot/etc/dconf/profile/gdm"

#gnome config
cp "$BASE_DIR/gnome/core" "$BUILD_DIR/config/includes.chroot/etc/dconf/db/local.d/01-gnome-core"
cp "$BASE_DIR/gnome/extensions" "$BUILD_DIR/config/includes.chroot/etc/dconf/db/local.d/02-extensions"
cp "$BASE_DIR/gnome/key-bindings" "$BUILD_DIR/config/includes.chroot/etc/dconf/db/local.d/03-keybindings"
cp "$BASE_DIR/gnome/nautilus" "$BUILD_DIR/config/includes.chroot/etc/dconf/db/local.d/04-nautilus"
cp "$BASE_DIR/gnome/theme" "$BUILD_DIR/config/includes.chroot/etc/dconf/db/local.d/00-theme"
cp "$BASE_DIR/gnome/gdm" "$BUILD_DIR/config/includes.chroot/etc/dconf/db/gdm.d/00-login-screen"

#extension hook
cp "$BASE_DIR/install_extensions.sh" "$BUILD_DIR/config/hooks/normal/0500-extensions.hook.chroot"
chmod +x config/hooks/normal/0500-extensions.hook.chroot

#theme hook
cp "$BASE_DIR/install_theme.sh" "$BUILD_DIR/config/hooks/normal/0501-themes.hook.chroot"
chmod +x config/hooks/normal/0501-themes.hook.chroot
cp "$BASE_DIR/install_theme.sh" "$BUILD_DIR/config/includes.chroot/usr/local/bin/install_theme.sh"
chmod +x "$BUILD_DIR/config/includes.chroot/usr/local/bin/install_theme.sh"

#default avatar hook
cp "$BASE_DIR/install_default_avatar.sh" "$BUILD_DIR/config/hooks/normal/0501b-default-avatar.hook.chroot"
chmod +x "$BUILD_DIR/config/hooks/normal/0501b-default-avatar.hook.chroot"

#desktop defaults hook
cp "$BASE_DIR/configure_desktop_defaults.sh" "$BUILD_DIR/config/hooks/normal/0502-defaults.hook.chroot"
chmod +x config/hooks/normal/0502-defaults.hook.chroot

#chromium defaults and policy hook
cp "$BASE_DIR/configure_chromium.sh" "$BUILD_DIR/config/hooks/normal/0502b-chromium.hook.chroot"
chmod +x "$BUILD_DIR/config/hooks/normal/0502b-chromium.hook.chroot"

#nautilus ptyxis extension hook
cp "$BASE_DIR/nautilus-ptyxis.c" "$BUILD_DIR/config/includes.chroot/usr/local/src/jamlinux/nautilus-ptyxis.c"
cp "$BASE_DIR/install_nautilus_ptyxis.sh" "$BUILD_DIR/config/hooks/normal/0503-nautilus-ptyxis.hook.chroot"
chmod +x "$BUILD_DIR/config/hooks/normal/0503-nautilus-ptyxis.hook.chroot"

#locale hook
cp "$BASE_DIR/configure_locale.sh" "$BUILD_DIR/config/hooks/normal/0504-locale.hook.chroot"
chmod +x "$BUILD_DIR/config/hooks/normal/0504-locale.hook.chroot"
cp "$BASE_DIR/enforce_locale.sh" "$BUILD_DIR/config/hooks/normal/1030-locale-final.hook.chroot"
chmod +x "$BUILD_DIR/config/hooks/normal/1030-locale-final.hook.chroot"

#flatpak apps hook
cp "$BASE_DIR/install_flatpak_apps.sh" "$BUILD_DIR/config/hooks/normal/0505-flatpak-apps.hook.chroot"
chmod +x "$BUILD_DIR/config/hooks/normal/0505-flatpak-apps.hook.chroot"

#dconf hook
cp "$BASE_DIR/update_dconf.sh" "$BUILD_DIR/config/hooks/normal/0506-dconf.hook.chroot"
chmod +x config/hooks/normal/0506-dconf.hook.chroot
cp "$BASE_DIR/update_dconf.sh" "$BUILD_DIR/config/includes.chroot/usr/local/bin/update_dconf.sh"
chmod +x "$BUILD_DIR/config/includes.chroot/usr/local/bin/update_dconf.sh"

#identity
cp "$BASE_DIR/identity/os-release" "$BUILD_DIR/config/includes.chroot/etc/os-release"
cp "$BASE_DIR/identity/lsb-release" "$BUILD_DIR/config/includes.chroot/etc/lsb-release"
cp "$BASE_DIR/identity/issue" "$BUILD_DIR/config/includes.chroot/etc/issue"
cp "$BASE_DIR/identity/issue.net" "$BUILD_DIR/config/includes.chroot/etc/issue.net"

#backgrounds
mkdir -p config/includes.chroot/usr/share/backgrounds/jamlinux
cp "$BASE_DIR/backgrounds/default-bg.jpg" "$BUILD_DIR/config/includes.chroot/usr/share/backgrounds/jamlinux/default-bg.jpg"
cp "$BASE_DIR/backgrounds/default-bg-dark.jpg" "$BUILD_DIR/config/includes.chroot/usr/share/backgrounds/jamlinux/default-bg-dark.jpg"
cp "$BASE_DIR/backgrounds/login-bg.jpg" "$BUILD_DIR/config/includes.chroot/usr/share/backgrounds/gdm/login-bg.jpg"
cp "$BASE_DIR/backgrounds/login-lock-bg.jpg" "$BUILD_DIR/config/includes.chroot/usr/share/backgrounds/gdm/login-lock-bg.jpg"

#branding
cp "$BASE_DIR/branding/logo.png" "$BUILD_DIR/config/includes.chroot/usr/share/images/jamlinux/logo.png"
cp "$BASE_DIR/branding/pp.png" "$BUILD_DIR/config/includes.chroot/usr/share/images/jamlinux/pp.png"
cp "$BASE_DIR/branding/installer-banner.png" "$BUILD_DIR/config/includes.chroot/usr/share/images/jamlinux/installer-banner.png"

# Replace the Debian installer GTK banner with JamLinux branding.
# Files in config/includes.installer/ are injected into the installer initrd.
mkdir -p "$BUILD_DIR/config/includes.installer/usr/share/graphics"
cp "$BASE_DIR/branding/installer-banner.png" "$BUILD_DIR/config/includes.installer/usr/share/graphics/logo_debian.png"
mkdir -p "$BUILD_DIR/config/includes.chroot/usr/share/plymouth/themes/jamlinux"
cp "$BASE_DIR/branding/logo.png" "$BUILD_DIR/config/includes.chroot/usr/share/plymouth/themes/jamlinux/logo.png"
cp "$BASE_DIR/plymouth/jamlinux/jamlinux.plymouth" "$BUILD_DIR/config/includes.chroot/usr/share/plymouth/themes/jamlinux/jamlinux.plymouth"
cp "$BASE_DIR/plymouth/jamlinux/jamlinux.script" "$BUILD_DIR/config/includes.chroot/usr/share/plymouth/themes/jamlinux/jamlinux.script"
cp "$BASE_DIR/plymouth/jamlinux/password_dot.png" "$BUILD_DIR/config/includes.chroot/usr/share/plymouth/themes/jamlinux/password_dot.png"
cp "$BASE_DIR/plymouth/jamlinux/password_field.png" "$BUILD_DIR/config/includes.chroot/usr/share/plymouth/themes/jamlinux/password_field.png"
mkdir -p "$BUILD_DIR/config/includes.chroot/usr/share/sounds/jamlinux"
cp "$BASE_DIR/branding/jamlinux-login.oga" "$BUILD_DIR/config/includes.chroot/usr/share/sounds/jamlinux/jamlinux-login.oga"
mkdir -p "$BUILD_DIR/config/includes.chroot/etc/xdg/autostart"
cp "$BASE_DIR/autostart/ulauncher.desktop" "$BUILD_DIR/config/includes.chroot/etc/xdg/autostart/ulauncher.desktop"
mkdir -p "$BUILD_DIR/config/includes.chroot/usr/share/gdm/greeter/autostart"
cp "$BASE_DIR/autostart/jamlinux-startup-sound.desktop" "$BUILD_DIR/config/includes.chroot/usr/share/gdm/greeter/autostart/jamlinux-startup-sound.desktop"
mkdir -p "$BUILD_DIR/config/includes.chroot/etc/tmpfiles.d"
cp "$BASE_DIR/systemd/jamlinux-startup-sound.conf" "$BUILD_DIR/config/includes.chroot/etc/tmpfiles.d/jamlinux-startup-sound.conf"
cp "$BASE_DIR/jamlinux-startup-sound.sh" "$BUILD_DIR/config/includes.chroot/usr/local/bin/jamlinux-startup-sound"
chmod +x "$BUILD_DIR/config/includes.chroot/usr/local/bin/jamlinux-startup-sound"
cp "$BASE_DIR/configure_installed_system.sh" "$BUILD_DIR/config/includes.chroot/usr/local/bin/configure_installed_system.sh"
chmod +x "$BUILD_DIR/config/includes.chroot/usr/local/bin/configure_installed_system.sh"
cp "$BASE_DIR/configure_chromium.sh" "$BUILD_DIR/config/includes.chroot/usr/local/bin/configure_chromium.sh"
chmod +x "$BUILD_DIR/config/includes.chroot/usr/local/bin/configure_chromium.sh"
cp "$BASE_DIR/install_external_packages.sh" "$BUILD_DIR/config/includes.chroot/usr/local/bin/install_external_packages.sh"
chmod +x "$BUILD_DIR/config/includes.chroot/usr/local/bin/install_external_packages.sh"

# bootloader splash
mkdir -p "$BUILD_DIR/config/bootloaders/grub-pc/live-theme"
cat > "$BUILD_DIR/config/bootloaders/splash.svg" <<EOF
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg
   version="1.1"
   width="800"
   height="600"
   viewBox="0 0 800 600"
   xmlns="http://www.w3.org/2000/svg"
   xmlns:xlink="http://www.w3.org/1999/xlink">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#08111d" />
      <stop offset="55%" stop-color="#10253f" />
      <stop offset="100%" stop-color="#050b14" />
    </linearGradient>
    <radialGradient id="glow" cx="0.2" cy="0.18" r="0.85">
      <stop offset="0%" stop-color="#2bc0ff" stop-opacity="0.28" />
      <stop offset="45%" stop-color="#2bc0ff" stop-opacity="0.08" />
      <stop offset="100%" stop-color="#2bc0ff" stop-opacity="0" />
    </radialGradient>
    <filter id="shadow" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="10" stdDeviation="14" flood-color="#000000" flood-opacity="0.55" />
    </filter>
  </defs>

  <rect width="800" height="600" fill="url(#bg)" />
  <rect width="800" height="600" fill="url(#glow)" />
  <circle cx="675" cy="110" r="210" fill="#f59e0b" fill-opacity="0.08" />
  <circle cx="80" cy="540" r="180" fill="#38bdf8" fill-opacity="0.08" />

  <image
     x="34"
     y="82"
     width="170"
     height="170"
     preserveAspectRatio="xMidYMid meet"
     filter="url(#shadow)"
     xlink:href="data:image/png;base64,$(base64 -w 0 "$BASE_DIR/branding/pp.png")" />

    <text x="238" y="110" fill="#ffffff" font-family="DejaVu Sans" font-size="30" font-weight="700">JamLinux GNU/Linux @VERSION@ (@DISTRIBUTION@)</text>
    <text x="238" y="148" fill="#ffffff" font-family="DejaVu Sans" font-size="30" font-weight="700">@ARCHITECTURE@</text>

  <text x="238" y="208" fill="#f3f4f6" font-family="DejaVu Sans" font-size="18" font-weight="700">Built: @YEAR@-@MONTH@-@DAY@ @HOUR@:@MINUTE@:@SECOND@ @TIMEZONE@</text>
</svg>
EOF

SPLASH_SVG="$BUILD_DIR/config/bootloaders/splash.svg"
SPLASH_PNG="$BUILD_DIR/config/bootloaders/splash.png"

if command -v magick >/dev/null 2>&1; then
    magick "$SPLASH_SVG" PNG32:"$SPLASH_PNG"
elif command -v rsvg-convert >/dev/null 2>&1; then
    rsvg-convert -w 800 -h 600 "$SPLASH_SVG" -o "$SPLASH_PNG"
elif command -v convert >/dev/null 2>&1; then
    convert "$SPLASH_SVG" PNG32:"$SPLASH_PNG"
else
    echo "Missing image renderer (magick, rsvg-convert, or convert) needed to build the GRUB splash image" >&2
    exit 1
fi

cat > "$BUILD_DIR/config/bootloaders/grub-pc/live-theme/theme.txt" <<'EOF'
desktop-image: "../splash.png"
title-color: "#ffffff"
title-font: "Unifont Regular 16"
title-text: ""
message-font: "Unifont Regular 16"
terminal-font: "Unifont Regular 16"

+ label {
    top = 100%-50
    left = 0
    width = 100%
    height = 20
    text = "@KEYMAP_SHORT@"
    align = "center"
    color = "#ffffff"
	font = "Unifont Regular 16"
}

+ boot_menu {
    left = 10%
    width = 80%
    top = 52%
    height = 48%-80
    item_color = "#d6e4f1"
	item_font = "Unifont Regular 16"
    selected_item_color= "#f59e0b"
	selected_item_font = "Unifont Regular 16"
    item_height = 24
    item_padding = 0
    item_spacing = 6
	icon_width = 0
	icon_heigh = 0
	item_icon_space = 0
}

+ progress_bar {
    id = "__timeout__"
    left = 15%
    top = 100%-80
    height = 16
    width = 70%
    font = "Unifont Regular 16"
    text_color = "#08111d"
    fg_color = "#f59e0b"
    bg_color = "#274156"
    border_color = "#38bdf8"
    text = "@TIMEOUT_NOTIFICATION_LONG@"
}
EOF
cp "$BASE_DIR/grub/theme.txt" "$BUILD_DIR/config/includes.chroot/usr/share/grub/themes/jamlinux/theme.txt"
cp "$SPLASH_PNG" "$BUILD_DIR/config/includes.chroot/usr/share/grub/themes/jamlinux/splash.png"

#grub
mkdir -p "$BUILD_DIR/config/includes.chroot/etc/default/grub.d"
cp "$BASE_DIR/grub/grub_branding.cfg" "$BUILD_DIR/config/includes.chroot/etc/default/grub.d/99-custom.cfg"
cp "$BASE_DIR/grub/grub_theme_hook.sh" "$BUILD_DIR/config/hooks/normal/0507-grub-theme.hook.chroot"
chmod +x "$BUILD_DIR/config/hooks/normal/0507-grub-theme.hook.chroot"

#installer branding
cp "$BASE_DIR/installer_branding.sh" "$BUILD_DIR/config/hooks/normal/0508-installer-branding.hook.chroot"
chmod +x "$BUILD_DIR/config/hooks/normal/0508-installer-branding.hook.chroot"

#first boot script
cp "$BASE_DIR/first-boot.sh" "$BUILD_DIR/config/includes.chroot/usr/local/bin/first-boot.sh"
chmod +x "$BUILD_DIR/config/includes.chroot/usr/local/bin/first-boot.sh"
cp "$BASE_DIR/systemd/jamlinux-first-boot.service" "$BUILD_DIR/config/includes.chroot/etc/systemd/system/jamlinux-first-boot.service"
ln -sf ../jamlinux-first-boot.service "$BUILD_DIR/config/includes.chroot/etc/systemd/system/multi-user.target.wants/jamlinux-first-boot.service"

#external packages
cp "$BASE_DIR/install_external_packages.sh" "$BUILD_DIR/config/hooks/normal/0510-external-packages.hook.chroot"
chmod +x "$BUILD_DIR/config/hooks/normal/0510-external-packages.hook.chroot"

# Binary hook: stage cached external .deb files into the installer payload so
# they are available on the installed system (the installation is offline).
cat > "$BUILD_DIR/config/hooks/normal/0600-stage-external-debs.hook.binary" <<'HOOK'
#!/bin/bash
set -eu

src="chroot/var/lib/jamlinux/external-debs"
dst="binary/jamlinux-installer/rootfs/var/lib/jamlinux/external-debs"

if ! find "$src" -maxdepth 1 -name "*.deb" -type f 2>/dev/null | grep -q .; then
    echo "[jamlinux binary hook] No cached external .deb files to stage."
    exit 0
fi

mkdir -p "$dst"
cp -a "$src/." "$dst/"
echo "[jamlinux binary hook] Staged external .deb files for installed-system provisioning:"
ls -1 "$dst"
HOOK
chmod +x "$BUILD_DIR/config/hooks/normal/0600-stage-external-debs.hook.binary"

# installer target payload
PAYLOAD_DIR="$BUILD_DIR/config/includes.binary/jamlinux-installer/rootfs"
install_payload_file "$BASE_DIR/configure_installed_system.sh" "usr/local/bin/configure_installed_system.sh"
install_payload_file "$BASE_DIR/configure_chromium.sh" "usr/local/bin/configure_chromium.sh"
install_payload_file "$BASE_DIR/first-boot.sh" "usr/local/bin/first-boot.sh"
install_payload_file "$BASE_DIR/install_external_packages.sh" "usr/local/bin/install_external_packages.sh"
install_payload_file "$BASE_DIR/install_theme.sh" "usr/local/bin/install_theme.sh"
install_payload_file "$BASE_DIR/update_dconf.sh" "usr/local/bin/update_dconf.sh"
install_payload_file "$BASE_DIR/systemd/jamlinux-first-boot.service" "etc/systemd/system/jamlinux-first-boot.service"
install_payload_file "$BASE_DIR/sources/sources.list" "usr/local/src/jamlinux/sources.list"
install_payload_file "$BASE_DIR/grub/grub_branding.cfg" "etc/default/grub.d/99-custom.cfg"
install_payload_file "$BASE_DIR/grub/theme.txt" "usr/share/grub/themes/jamlinux/theme.txt"
install_payload_file "$SPLASH_PNG" "usr/share/grub/themes/jamlinux/splash.png"
install_payload_file "$BASE_DIR/plymouth/jamlinux/jamlinux.plymouth" "usr/share/plymouth/themes/jamlinux/jamlinux.plymouth"
install_payload_file "$BASE_DIR/plymouth/jamlinux/jamlinux.script" "usr/share/plymouth/themes/jamlinux/jamlinux.script"
install_payload_file "$BASE_DIR/branding/logo.png" "usr/share/plymouth/themes/jamlinux/logo.png"
install_payload_file "$BASE_DIR/plymouth/jamlinux/password_dot.png" "usr/share/plymouth/themes/jamlinux/password_dot.png"
install_payload_file "$BASE_DIR/plymouth/jamlinux/password_field.png" "usr/share/plymouth/themes/jamlinux/password_field.png"
install_payload_file "$BASE_DIR/branding/logo.png" "usr/share/images/jamlinux/logo.png"
install_payload_file "$BASE_DIR/branding/installer-banner.png" "usr/share/images/jamlinux/installer-banner.png"
install_payload_file "$BASE_DIR/backgrounds/login-bg.jpg" "usr/share/backgrounds/gdm/login-bg.jpg"
install_payload_file "$BASE_DIR/backgrounds/login-lock-bg.jpg" "usr/share/backgrounds/gdm/login-lock-bg.jpg"
install_payload_file "$BASE_DIR/dconf/profile/gdm" "etc/dconf/profile/gdm"
install_payload_file "$BASE_DIR/gnome/gdm" "etc/dconf/db/gdm.d/00-login-screen"
install_payload_file "$BASE_DIR/autostart/ulauncher.desktop" "etc/xdg/autostart/ulauncher.desktop"
install_payload_file "$BASE_DIR/branding/jamlinux-login.oga" "usr/share/sounds/jamlinux/jamlinux-login.oga"
install_payload_file "$BASE_DIR/autostart/jamlinux-startup-sound.desktop" "usr/share/gdm/greeter/autostart/jamlinux-startup-sound.desktop"
install_payload_file "$BASE_DIR/systemd/jamlinux-startup-sound.conf" "etc/tmpfiles.d/jamlinux-startup-sound.conf"
install_payload_file "$BASE_DIR/jamlinux-startup-sound.sh" "usr/local/bin/jamlinux-startup-sound"
chmod +x "$PAYLOAD_DIR/usr/local/bin/jamlinux-startup-sound"
chmod +x "$PAYLOAD_DIR/usr/local/bin/configure_chromium.sh"
mkdir -p "$PAYLOAD_DIR/etc/systemd/system/multi-user.target.wants"
ln -sf ../jamlinux-first-boot.service "$PAYLOAD_DIR/etc/systemd/system/multi-user.target.wants/jamlinux-first-boot.service"

# cleanup
cp "$BASE_DIR/cleanup_hook.sh" "$BUILD_DIR/config/hooks/normal/0900-cleanup.hook.chroot"
chmod +x "$BUILD_DIR/config/hooks/normal/0900-cleanup.hook.chroot"

#build the ISO
cd $BUILD_DIR

pwd
echo "Building JamLinux ISO - this may take a while..."

# Clean any previous builds
sudo lb clean

# Verify configuration
lb config

sudo lb build

#launch
mkdir -p $BASE_DIR/dist
cp *.iso $BASE_DIR/dist/jamlinux-v1.0-$(date +%Y%m%d).iso

sync
