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

echo "JamLinux theme setup complete."
