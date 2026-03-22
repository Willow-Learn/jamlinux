#!/bin/bash
set -e

echo "Configuring British English locale defaults..."

if ! grep -qx 'en_GB.UTF-8 UTF-8' /etc/locale.gen; then
    echo 'en_GB.UTF-8 UTF-8' >> /etc/locale.gen
fi

locale-gen en_GB.UTF-8
update-locale \
    LANG=en_GB.UTF-8 \
    LANGUAGE=en_GB:en \
    LC_ADDRESS=en_GB.UTF-8 \
    LC_MESSAGES=en_GB.UTF-8 \
    LC_NUMERIC=en_GB.UTF-8 \
    LC_TELEPHONE=en_GB.UTF-8 \
    LC_TIME=en_GB.UTF-8 \
    LC_MONETARY=en_GB.UTF-8 \
    LC_PAPER=en_GB.UTF-8 \
    LC_MEASUREMENT=en_GB.UTF-8

cat > /etc/default/keyboard <<'EOF'
XKBMODEL="pc105"
XKBLAYOUT="gb"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
EOF

echo 'Europe/London' > /etc/timezone
ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime

echo "Locale defaults configured."
