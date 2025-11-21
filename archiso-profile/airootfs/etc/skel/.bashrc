# .bashrc

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# DJGPP environment
export DJGPP=/opt/djgpp
export PATH=$DJGPP/bin:$DJGPP/i586-pc-msdosdjgpp/bin:$PATH

# Aliases
alias ls='ls --color=auto'
alias ll='ls -lah'
alias grep='grep --color=auto'

# Prompt
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

# Welcome message
cat <<'EOF'
╔═══════════════════════════════════════════════════════════╗
║   DOSBox-X DJGPP Development Environment                  ║
╚═══════════════════════════════════════════════════════════╝

Quick Start:
  - startx          : Launch i3 window manager with DOSBox-X
  - dosbox-x        : Run DOSBox-X from terminal
  - i586-pc-msdosdjgpp-gcc : DJGPP C compiler

Window Manager Shortcuts (Super/Windows key):
  - Super+Enter     : Open terminal
  - Super+Shift+D   : Launch DOSBox-X
  - Super+D         : Application launcher (dmenu)
  - Super+1/2/3     : Switch workspaces
  - Super+Shift+Q   : Close window
  - Super+Shift+E   : Exit i3

DJGPP Compiler Ready:
  - i586-pc-msdosdjgpp-gcc --version

EOF
