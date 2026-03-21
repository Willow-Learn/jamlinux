# JamLinux
Debian Testing remix designed to look beautiful and work with the latest x64_86 hardware (in particular, ThinkPad T14s AMD).

## Build Scripts
- build_scripts/copy-reference-system/run.sh - gathers local config of machine into reference/
- build_scripts/build.sh - builds the ISO

## Run in QEMU
qemu-system-x86_64 -m 4096 -cdrom dist/jamlinux* -boot d

## TODO:
- code 
- nautilus open in terminal
- ulauncher
- steam
- python, ruby, rust, java, etc?
- triple a?
- tor?
- vivaldi?
- more firmware/drivers?