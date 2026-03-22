#! /bin/bash
set -e

export BASE_DIR="/home/jbm/JamLinux/"
export BUILD_DIR="/home/jbm/JamLinux/build/$(date +%Y%m%d)"

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
    --debian-installer live \
    --debian-installer-gui true \
    --win32-loader false \
    --iso-volume "JAMLINUX" \
    --iso-application "JamLinux" \
    --iso-publisher "Jamie Munro" \
    --iso-preparer "live-build" \
    --linux-packages "linux-image linux-headers" \
    --debian-installer-distribution trixie

# Create all necessary directories
mkdir -p config/{hooks/normal,hooks/binary,includes.chroot/etc/{skel/{.config,.local/share},dconf/db/{local.d,gdm.d},apt/{preferences.d,sources.list.d}},package-lists,bootloaders}
mkdir -p config/archives
mkdir -p config/includes.chroot/usr/share/{gnome-shell/extensions,themes,icons,backgrounds/gdm,plymouth/themes}
mkdir -p config/includes.chroot/usr/share/images/jamlinux
mkdir -p config/includes.chroot/usr/local/bin
mkdir -p config/includes.chroot/usr/local/src/jamlinux
mkdir -p config/includes.chroot/usr/local/src/jamlinux/repositories
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

# Stage third-party repository metadata for a post-package install hook.
cp "$BASE_DIR/sources/vscode.list.chroot" "$BUILD_DIR/config/includes.chroot/usr/local/src/jamlinux/repositories/vscode.list"
cp "$BASE_DIR/sources/vscode.key.chroot" "$BUILD_DIR/config/includes.chroot/usr/local/src/jamlinux/repositories/vscode.asc"

#package lists
cp "$BASE_DIR/packages/base_system" "$BUILD_DIR/config/package-lists/base.list.chroot"
cp "$BASE_DIR/packages/gnome" "$BUILD_DIR/config/package-lists/gnome.list.chroot"
cp "$BASE_DIR/packages/custom_packages" "$BUILD_DIR/config/package-lists/custom.list.chroot"

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

#default avatar hook
cp "$BASE_DIR/install_default_avatar.sh" "$BUILD_DIR/config/hooks/normal/0501b-default-avatar.hook.chroot"
chmod +x "$BUILD_DIR/config/hooks/normal/0501b-default-avatar.hook.chroot"

#desktop defaults hook
cp "$BASE_DIR/configure_desktop_defaults.sh" "$BUILD_DIR/config/hooks/normal/0502-defaults.hook.chroot"
chmod +x config/hooks/normal/0502-defaults.hook.chroot

#nautilus ptyxis extension hook
cp "$BASE_DIR/nautilus-ptyxis.c" "$BUILD_DIR/config/includes.chroot/usr/local/src/jamlinux/nautilus-ptyxis.c"
cp "$BASE_DIR/install_nautilus_ptyxis.sh" "$BUILD_DIR/config/hooks/normal/0503-nautilus-ptyxis.hook.chroot"
chmod +x "$BUILD_DIR/config/hooks/normal/0503-nautilus-ptyxis.hook.chroot"

#locale hook
cp "$BASE_DIR/configure_locale.sh" "$BUILD_DIR/config/hooks/normal/0504-locale.hook.chroot"
chmod +x "$BUILD_DIR/config/hooks/normal/0504-locale.hook.chroot"

#flatpak apps hook
cp "$BASE_DIR/install_flatpak_apps.sh" "$BUILD_DIR/config/hooks/normal/0505-flatpak-apps.hook.chroot"
chmod +x "$BUILD_DIR/config/hooks/normal/0505-flatpak-apps.hook.chroot"

#dconf hook
cp "$BASE_DIR/update_dconf.sh" "$BUILD_DIR/config/hooks/normal/0506-dconf.hook.chroot"
chmod +x config/hooks/normal/0506-dconf.hook.chroot

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

#branding
cp "$BASE_DIR/branding/logo.png" "$BUILD_DIR/config/includes.chroot/usr/share/images/jamlinux/logo.png"
cp "$BASE_DIR/branding/pp.png" "$BUILD_DIR/config/includes.chroot/usr/share/images/jamlinux/pp.png"
mkdir -p "$BUILD_DIR/config/includes.chroot/usr/share/plymouth/themes/jamlinux"
cp "$BASE_DIR/branding/logo.png" "$BUILD_DIR/config/includes.chroot/usr/share/plymouth/themes/jamlinux/logo.png"
cp "$BASE_DIR/plymouth/jamlinux/jamlinux.plymouth" "$BUILD_DIR/config/includes.chroot/usr/share/plymouth/themes/jamlinux/jamlinux.plymouth"
cp "$BASE_DIR/plymouth/jamlinux/jamlinux.script" "$BUILD_DIR/config/includes.chroot/usr/share/plymouth/themes/jamlinux/jamlinux.script"
mkdir -p "$BUILD_DIR/config/includes.chroot/usr/share/sounds/jamlinux"
cp "$BASE_DIR/branding/jamlinux-login.oga" "$BUILD_DIR/config/includes.chroot/usr/share/sounds/jamlinux/jamlinux-login.oga"
mkdir -p "$BUILD_DIR/config/includes.chroot/etc/xdg/autostart"
cp "$BASE_DIR/autostart/jamlinux-startup-sound.desktop" "$BUILD_DIR/config/includes.chroot/etc/xdg/autostart/jamlinux-startup-sound.desktop"
cp "$BASE_DIR/jamlinux-startup-sound.sh" "$BUILD_DIR/config/includes.chroot/usr/local/bin/jamlinux-startup-sound"
chmod +x "$BUILD_DIR/config/includes.chroot/usr/local/bin/jamlinux-startup-sound"

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
cat > "$BUILD_DIR/config/includes.chroot/etc/systemd/system/jamlinux-first-boot.service" <<'EOF'
[Unit]
Description=Run JamLinux first-boot tasks
Wants=network-online.target
After=network-online.target
ConditionPathExists=!/var/lib/jamlinux/first-boot-complete

[Service]
Type=oneshot
ExecStart=/usr/local/bin/first-boot.sh

[Install]
WantedBy=multi-user.target
EOF
ln -sf ../jamlinux-first-boot.service "$BUILD_DIR/config/includes.chroot/etc/systemd/system/multi-user.target.wants/jamlinux-first-boot.service"

#external packages
cp "$BASE_DIR/install_external_packages.sh" "$BUILD_DIR/config/hooks/normal/0510-external-packages.hook.chroot"
chmod +x "$BUILD_DIR/config/hooks/normal/0510-external-packages.hook.chroot"

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
cp *.iso $BASE_DIR/dist/jamlinux-$(date +%Y%m%d).iso
