# JamLinux
Aiming to be a polished daily-driver desktop based on Debian Stable. Designed to look beautiful, be practical and work with the latest x64_86 hardware (in particular, AMD based ThinkPad T14s).  
   
The goal is to have strong out-the-box hardware support, all the applications you need, a full development stack, and be ready-to-go for gaming and multimedia.   
    
Running on Kernel version 6.19
     
Opinionated Gnome 3 desktop environment, optimised for British English. 
   
## Build ISO
```
sudo bash build_scripts/build.sh
```

## Resume Build
```
cd $BUILD_DIR
sudo lb build
```

## Gather reference config from local machine
```
bash build_scripts/copy-reference-system/run.sh
```

## Run in QEMU
```
qemu-system-x86_64 \
  -enable-kvm \
  -cpu host \
  -smp 4 \
  -m 8192 \
  -cdrom dist/jamlinux-*.iso \
  -boot d \
  -display gtk,gl=on \
  -device virtio-vga
```

# Road Map
- gnome top bar on all screens
- better wallpapers / slideshow?
- grub branding
- ulauncher extensions
- different browser instead of chrome?
- different shell instead of bash?
- update manager:
  - detect apt get updates and alert users (probably easy)
  - update to latest "JamLinux" version (harder)
- remove "via AWSM" from reboot/power menu
- ananicy-cpp
- nvidia drivers (needs older kernel or newer drivers)
- establish deidcated jamlinux debian mirror with external packages included so we can remove messy 3rd party installations

