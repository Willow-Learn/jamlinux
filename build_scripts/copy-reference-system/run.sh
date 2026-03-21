#! /bin/bash
export BASE_DIR="/home/jbm/JamLinux/reference/$(date +%Y%m%d)"
SCRIPTS_DIR="/home/jbm/JamLinux/build_scripts/copy-reference-system"

mkdir -p "$BASE_DIR"

sh "$SCRIPTS_DIR/packages.sh"
sh "$SCRIPTS_DIR/gnome_config.sh"
sh "$SCRIPTS_DIR/extensions.sh"
sh "$SCRIPTS_DIR/theme.sh"
sh "$SCRIPTS_DIR/keyboard_shortcuts.sh"

tar czf ${BASE_DIR}.tar.gz ${BASE_DIR}