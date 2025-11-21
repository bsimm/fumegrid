# .bash_profile

# Source .bashrc if it exists
[[ -f ~/.bashrc ]] && . ~/.bashrc

# Auto-start X on login to tty1
if [[ -z $DISPLAY && $XDG_VTNR -eq 1 ]]; then
    echo "Starting X session with i3 window manager..."
    echo "DOSBox-X and terminal will launch automatically"
    echo ""
    exec startx
fi
