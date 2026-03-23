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
    background-color: #08111d;
    background-image: url("jamlinux-login-bg.jpg");
    background-repeat: no-repeat !important;
    background-position: center;
    background-size: cover;
}

.screen-shield-background,
.login-dialog,
.unlock-dialog {
    background-color: transparent;
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

extract_shell_resource() {
    local theme_dir="$1"
    local system_resource="/usr/share/gnome-shell/gnome-shell-theme.gresource"
    local resource
    local filename

    [ -f "$system_resource" ] || return 1

    while read -r resource; do
        [ -n "$resource" ] || continue
        filename="$(basename "$resource")"
        gresource extract "$system_resource" "$resource" > "$theme_dir/$filename"
    done <<EOF
$(gresource list "$system_resource" | grep '^/org/gnome/shell/theme/')
EOF
}

patch_shell_css() {
    local theme_dir="$1"
    local css_file
    local patched=0

    for css_file in \
        "$theme_dir/gnome-shell-dark.css" \
        "$theme_dir/gnome-shell-light.css" \
        "$theme_dir/gnome-shell-high-contrast.css"
    do
        if append_shell_override "$css_file"; then
            patched=1
        fi
    done

    [ "$patched" -eq 1 ]
}

rebuild_shell_resource() {
    local theme_dir="$1"
    local manifest="$theme_dir/jamlinux-shell-theme.gresource.xml"
    local target_resource="$theme_dir/gnome-shell-theme.gresource"
    local system_resource="/usr/share/gnome-shell/gnome-shell-theme.gresource"

    [ -d "$theme_dir" ] || return 1

    {
        printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>'
        printf '%s\n' '<gresources>'
        printf '%s\n' '  <gresource prefix="/org/gnome/shell/theme">'
        find "$theme_dir" -maxdepth 1 -type f \
            ! -name '*.gresource' \
            ! -name '*.xml' \
            -printf '    <file>%f</file>\n' | sort
        printf '%s\n' '  </gresource>'
        printf '%s\n' '</gresources>'
    } > "$manifest"

    glib-compile-resources --sourcedir="$theme_dir" --target="$target_resource" "$manifest"
    install -m 0644 "$target_resource" "$system_resource"

    echo "  Rebuilt $target_resource"
    echo "  Updated $system_resource"
}

theme_workspace="$(mktemp -d)"
cleanup() {
    rm -rf "$theme_workspace"
}
trap cleanup EXIT

extract_shell_resource "$theme_workspace" || true
copy_greeter_assets "$theme_workspace" || true

if patch_shell_css "$theme_workspace"; then
    rebuild_shell_resource "$theme_workspace"
else
    echo "  Warning: no GNOME Shell CSS target found for default theme patching."
fi

echo "JamLinux theme setup complete."
