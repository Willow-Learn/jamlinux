#!/bin/bash
# First boot configuration script
# Runs once when a new user first logs in

# Apply any remaining per-user settings
if [ -f ~/.config/jamlinux/firstboot-needed ]; then
    # Set up default folders, etc.
    
    # Mark as done
    rm ~/.config/jamlinux/firstboot-needed
fi