cd $BASE_DIR

# All installed packages
dpkg --get-selections > packages.list

# Explicitly installed (not auto) - your "wanted" packages
apt-mark showmanual > packages-manual.list

# Auto-installed (dependencies)
apt-mark showauto > packages-auto.list

# Package sources
mkdir -p sources
cp /etc/apt/sources.list sources/
cp -r /etc/apt/sources.list.d/ sources/ 2>/dev/null || true

# APT preferences (pinning)
cp /etc/apt/preferences /etc/apt/preferences.d/ sources/ 2>/dev/null || true