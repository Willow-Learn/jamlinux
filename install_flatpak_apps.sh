#!/bin/bash
set -e

echo "Configuring Flathub for bundled Flatpak applications..."

flatpak remote-add --if-not-exists --system flathub https://dl.flathub.org/repo/flathub.flatpakrepo

echo "Bundled Flatpak applications will be installed by first-boot.sh on the target system."
