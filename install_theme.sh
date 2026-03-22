#!/bin/bash
set -e

echo "Setting up JamLinux visual identity (Adwaita-based GNOME Shell)..."

# Fonts and desktop theme packages are provided by the image package lists.

# Patch the system shell theme instead of relying on the User Themes extension.
jamlinux_shell_override='/* JamLinux shell overrides */
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
    font-weight: 500;
}

#lockDialogGroup {
    background: #08111d url("jamlinux-login-bg.jpg");
    background-repeat: no-repeat;
    background-position: center;
    background-size: cover;
}

.login-dialog-logo-bin {
    background-image: url("jamlinux-logo.png");
    background-position: center;
    background-repeat: no-repeat;
    background-size: contain;
}
'

append_shell_override() {
    local css_file="$1"

    [ -f "$css_file" ] || return 1
    grep -q "JamLinux shell overrides" "$css_file" && return 0

    printf '\n%s\n' "$jamlinux_shell_override" >> "$css_file"
    echo "  Patched $css_file"
}

copy_greeter_assets() {
    local theme_dir="$1"
    local login_bg="/usr/share/backgrounds/gdm/login-bg.jpg"
    local logo_png="/usr/share/images/jamlinux/logo.png"

    [ -d "$theme_dir" ] || return 1

    if [ -f "$login_bg" ]; then
        install -m 0644 "$login_bg" "$theme_dir/jamlinux-login-bg.jpg"
        echo "  Staged $theme_dir/jamlinux-login-bg.jpg"
    fi

    if [ -f "$logo_png" ]; then
        install -m 0644 "$logo_png" "$theme_dir/jamlinux-logo.png"
        echo "  Staged $theme_dir/jamlinux-logo.png"
    fi
}

rebuild_shell_resource() {
    local theme_dir="$1"
    local manifest
    local target_resource="$theme_dir/gnome-shell-theme.gresource"
    local system_resource="/usr/share/gnome-shell/gnome-shell-theme.gresource"

    [ -d "$theme_dir" ] || return 1

    manifest="$(mktemp)"
    {
        printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>'
        printf '%s\n' '<gresources>'
        printf '%s\n' '  <gresource prefix="/org/gnome/shell/theme">'
        find "$theme_dir" -maxdepth 1 -type f ! -name '*.gresource' -printf '    <file>%f</file>\n' | sort
        printf '%s\n' '  </gresource>'
        printf '%s\n' '</gresources>'
    } > "$manifest"

    glib-compile-resources --sourcedir="$theme_dir" --target="$target_resource" "$manifest"
    install -m 0644 "$target_resource" "$system_resource"
    rm -f "$manifest"

    echo "  Rebuilt $target_resource"
    echo "  Updated $system_resource"
}

patched=0
if append_shell_override /usr/share/gnome-shell/theme/gnome-shell.css; then
    patched=1
fi

if [ "$patched" -eq 0 ]; then
    echo "  Warning: no GNOME Shell CSS target found for default theme patching."
fi

if [ -d /usr/share/gnome-shell/theme ]; then
    copy_greeter_assets /usr/share/gnome-shell/theme || true
    rebuild_shell_resource /usr/share/gnome-shell/theme
else
    echo "  Warning: no GNOME Shell theme directory found for gresource rebuild."
fi

echo "JamLinux theme setup complete."
