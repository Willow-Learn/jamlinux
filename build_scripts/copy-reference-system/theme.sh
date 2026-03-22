cd $BASE_DIR

# Active themes
gsettings get org.gnome.desktop.interface gtk-theme > active-gtk-theme.txt
gsettings get org.gnome.desktop.interface icon-theme > active-icon-theme.txt
gsettings get org.gnome.desktop.interface cursor-theme > active-cursor-theme.txt

# Copy theme directories
mkdir -p themes icons
cp -r ~/.themes/* themes/ 2>/dev/null || true
cp -r ~/.icons/* icons/ 2>/dev/null || true
cp -r /usr/share/themes/* themes/ 2>/dev/null || true
cp -r /usr/share/icons/* icons/ 2>/dev/null || true

# Find which themes are actually used (filter the list)
echo "User themes:" > themes-inventory.txt
ls -la ~/.themes/ >> themes-inventory.txt 2>/dev/null || true
echo -e "\nSystem themes:" >> themes-inventory.txt
ls /usr/share/themes/ >> themes-inventory.txt 2>/dev/null || true
echo -e "\nUser icons:" >> themes-inventory.txt
ls ~/.icons/ >> themes-inventory.txt 2>/dev/null || true
echo -e "\nSystem icons:" >> themes-inventory.txt
ls /usr/share/icons/ >> themes-inventory.txt 2>/dev/null || true