# JamLinux
Polished daily-driver desktop based on Debian Testing. Designed to look beautiful, be practical and work with the latest x64_86 hardware (in particular, AMD based ThinkPad T14s).  
   
It aims to have strong out-the-box hardware support, all the applications you need, a full development stack, and b ready-to-go for gaming and multimedia.   
   
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
qemu-system-x86_64 \
  -enable-kvm \
  -cpu host \
  -smp 4 \
  -m 8192 \
  -cdrom dist/jamlinux-*.iso \
  -boot d \
  -display gtk,gl=on \
  -device virtio-vga