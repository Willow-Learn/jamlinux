#! /bin/bash
set -e

export BASE_DIR="/home/jbm/JamLinux/"
export BUILD_DIR="/home/jbm/JamLinux/build/$(date +%Y%m%d)"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

cd $BUILD_DIR

# Initialize for Debian Testing (Forky)
sudo lb config \
    --distribution forky \
    --archive-areas "main contrib non-free non-free-firmware" \
    --debian-installer live \
    --debian-installer-gui true \
    --win32-loader false \
    --iso-volume "JAMLINUX" \
    --iso-application "JamLinux" \
    --iso-publisher "Jamie Munro" \
    --iso-preparer "live-build" \
    --linux-packages "linux-image linux-headers" \
    --debian-installer-distribution forky

# Create all necessary directories
mkdir -p config/{hooks/normal,hooks/binary,includes.chroot/etc/{skel/{.config,.local/share},dconf/db/{local.d,gdm.d},apt/{preferences.d,sources.list.d}},package-lists,bootloaders}
mkdir -p config/includes.chroot/usr/share/{gnome-shell/extensions,themes,icons,backgrounds/gdm,plymouth/themes}
mkdir -p config/includes.chroot/usr/local/bin
mkdir -p config/includes.chroot/etc/systemd/system

# Copy apt sources
cp "$BASE_DIR/sources/sources.list" "$BUILD_DIR/config/archives/forky.list.chroot"

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

#extension hook
cp "$BASE_DIR/install_extensions.sh" "$BUILD_DIR/config/hooks/normal/0500-extensions.hook.chroot"
chmod +x config/hooks/normal/0500-extensions.hook.chroot

#theme hook
cp "$BASE_DIR/install_theme.sh" "$BUILD_DIR/config/hooks/normal/0501-themes.hook.chroot"
chmod +x config/hooks/normal/0501-themes.hook.chroot

#dconf hook
cp "$BASE_DIR/update_dconf.sh" "$BUILD_DIR/config/hooks/normal/0502-dconf.hook.chroot"
chmod +x config/hooks/normal/0502-dconf.hook.chroot

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

#grub
mkdir -p "$BUILD_DIR/config/includes.chroot/etc/default/grub.d"
cp "$BASE_DIR/grub/grub_branding.cfg" "$BUILD_DIR/config/includes.chroot/etc/default/grub.d/99-custom.cfg"
cp "$BASE_DIR/grub/grub_theme_hook.sh" "$BUILD_DIR/config/hooks/normal/0503-grub-theme.hook.chroot"
chmod +x "$BUILD_DIR/config/hooks/normal/0503-grub-theme.hook.chroot"

#installer branding
cp "$BASE_DIR/installer_branding.sh" "$BUILD_DIR/config/hooks/normal/0504-installer-branding.hook.chroot"
chmod +x "$BUILD_DIR/config/hooks/normal/0504-installer-branding.hook.chroot"

#first boot script
cp "$BASE_DIR/first_boot.sh" "$BUILD_DIR/config/includes.chroot/usr/local/bin/jamlinux-firstboot"
mkdir -p "$BUILD_DIR/config/includes.chroot/etc/skel/.config/jamlinux"
echo "# Marker file - delete after first boot setup" >> "$BUILD_DIR/config/includes.chroot/etc/skel/.config/jamlinux/firstboot-needed"
cat >> "$BUILD_DIR/config/hooks/normal/0505-firstboot.hook.chroot" <<'EOF'
#!/bin/bash
chmod +x /usr/local/bin/jamlinux-firstboot
EOF
chmod +x "$BUILD_DIR/config/includes.chroot/usr/local/bin/jamlinux-firstboot"

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
# live-image-amd64.hybrid.iso (or similar name)