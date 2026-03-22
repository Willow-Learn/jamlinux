#!/bin/bash
set -e

echo "Configuring default user avatar..."

SOURCE_FILE="/usr/share/images/jamlinux/pp.png"
LIVE_USERNAME="user"
ACCOUNTS_DIR="/var/lib/AccountsService"
ICON_DIR="$ACCOUNTS_DIR/icons"
USER_DIR="$ACCOUNTS_DIR/users"

if [ ! -f "$SOURCE_FILE" ]; then
    echo "Default avatar asset not found at $SOURCE_FILE; skipping avatar setup."
    exit 0
fi

mkdir -p "$ICON_DIR" "$USER_DIR" /etc/skel

install -m 0644 "$SOURCE_FILE" "$ICON_DIR/$LIVE_USERNAME"
install -m 0644 "$SOURCE_FILE" /etc/skel/.face

cat > "$USER_DIR/$LIVE_USERNAME" <<EOF
[User]
Icon=$ICON_DIR/$LIVE_USERNAME
SystemAccount=false
EOF

chmod 0644 "$USER_DIR/$LIVE_USERNAME"

echo "Default user avatar configured for $LIVE_USERNAME."