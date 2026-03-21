cd $BASE_DIR

# Full dconf dump (binary, for reference)
dconf dump / > dconf-full.dump

# GNOME Shell settings
dconf dump /org/gnome/shell/ > dconf-shell.ini

# Desktop/interface settings
dconf dump /org/gnome/desktop/interface/ > dconf-interface.ini
dconf dump /org/gnome/desktop/background/ > dconf-background.ini
dconf dump /org/gnome/desktop/wm/ > dconf-wm.ini

# Extension settings
dconf dump /org/gnome/shell/extensions/ > dconf-extensions.ini

# GTK settings
dconf dump /org/gnome/desktop/interface/gtk-theme > gtk-theme.txt 2>/dev/null || echo "No GTK theme set"
dconf dump /org/gnome/desktop/interface/icon-theme > icon-theme.txt 2>/dev/null || echo "No icon theme set"

# Nautilus/Files settings
dconf dump /org/gnome/nautilus/ > dconf-nautilus.ini

# Gedit/Terminal/other apps
dconf dump /org/gnome/gedit/ > dconf-gedit.ini 2>/dev/null || true
dconf dump /org/gnome/terminal/ > dconf-terminal.ini 2>/dev/null || true