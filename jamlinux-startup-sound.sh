#!/bin/bash
set -e

runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$UID}"
stamp_file="$runtime_dir/jamlinux-startup-sound.played"

if [ -e "$stamp_file" ]; then
    exit 0
fi

if command -v gsettings >/dev/null 2>&1; then
    event_sounds="$(gsettings get org.gnome.desktop.sound event-sounds 2>/dev/null || true)"
    if [ "$event_sounds" = "false" ]; then
        exit 0
    fi
fi

sound_file=""
for candidate in \
    /usr/share/sounds/jamlinux/jamlinux-login.oga \
    /usr/share/sounds/freedesktop/stereo/service-login.oga \
    /usr/share/sounds/freedesktop/stereo/complete.oga
do
    if [ -f "$candidate" ]; then
        sound_file="$candidate"
        break
    fi
done

if [ -z "$sound_file" ] || ! command -v pw-play >/dev/null 2>&1; then
    exit 0
fi

for _ in 1 2 3 4 5 6 7 8 9 10; do
    if pw-play --volume 0.35 "$sound_file" >/dev/null 2>&1; then
        : > "$stamp_file"
        exit 0
    fi

    sleep 1
done

exit 0
