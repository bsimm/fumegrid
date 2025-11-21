#!/bin/sh
# .xinitrc - X initialization script

# Merge in defaults and keymaps
if [ -f $HOME/.Xresources ]; then
    xrdb -merge $HOME/.Xresources
fi

# Start i3 window manager
exec i3
