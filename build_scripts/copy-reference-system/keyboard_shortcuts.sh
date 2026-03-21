cd $BASE_DIR

# Custom keybindings
dconf dump /org/gnome/settings-daemon/plugins/media-keys/ > dconf-media-keys.ini
dconf dump /org/gnome/desktop/wm/keybindings/ > dconf-wm-keys.ini
dconf dump /org/gnome/shell/keybindings/ > dconf-shell-keys.ini

# Full gsettings readable output
gsettings list-recursively org.gnome.settings-daemon.plugins.media-keys > media-keys-full.txt
gsettings list-recursively org.gnome.desktop.wm.keybindings > wm-keys-full.txt