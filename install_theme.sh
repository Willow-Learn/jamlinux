#!/bin/bash
set -e

echo "Setting up JamLinux visual identity (Yaru + patched GNOME Shell)..."

# Fonts and Yaru are provided by the image package lists.

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
'

append_shell_override() {
    local css_file="$1"

    [ -f "$css_file" ] || return 1
    grep -q "JamLinux shell overrides" "$css_file" && return 0

    printf '\n%s\n' "$jamlinux_shell_override" >> "$css_file"
    echo "  Patched $css_file"
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
for css_file in \
    /usr/share/gnome-shell/theme/gnome-shell.css \
    /usr/share/gnome-shell/theme/Yaru/gnome-shell.css \
    /usr/share/gnome-shell/theme/Yaru-dark/gnome-shell.css \
    /usr/share/themes/Yaru/gnome-shell/gnome-shell.css \
    /usr/share/themes/Yaru-dark/gnome-shell/gnome-shell.css
do
    if append_shell_override "$css_file"; then
        patched=1
    fi
done

if [ "$patched" -eq 0 ]; then
    echo "  Warning: no GNOME Shell CSS target found for Yaru patching."
fi

if [ -d /usr/share/gnome-shell/theme/Yaru ]; then
    rebuild_shell_resource /usr/share/gnome-shell/theme/Yaru
elif [ -d /usr/share/themes/Yaru/gnome-shell ]; then
    rebuild_shell_resource /usr/share/themes/Yaru/gnome-shell
else
    echo "  Warning: no Yaru GNOME Shell theme directory found for gresource rebuild."
fi

echo "JamLinux theme setup complete."
