#!/bin/bash
set -e

echo "Reapplying locale defaults after live-build generated hooks..."

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

cat > /etc/environment <<'EOF'
LANG=en_GB.UTF-8
EOF

echo "Locale defaults reapplied."