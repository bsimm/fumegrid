#!/bin/bash
# Install DOSBox-X DJGPP system to disk from live ISO

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  DOSBox-X DJGPP Development Environment Installer${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    echo "Run: sudo install-to-disk.sh"
    exit 1
fi

# Detect available disks
echo -e "${BLUE}Available disks:${NC}"
lsblk -d -o NAME,SIZE,TYPE,MODEL | grep disk
echo ""

# Get target device
read -p "Enter target device (e.g., /dev/sda or /dev/nvme0n1): " TARGET_DEVICE

if [ ! -b "$TARGET_DEVICE" ]; then
    echo -e "${RED}Error: $TARGET_DEVICE is not a valid block device${NC}"
    exit 1
fi

# Warning
echo ""
echo -e "${RED}WARNING: This will ERASE ALL DATA on $TARGET_DEVICE${NC}"
echo -e "${RED}Press Ctrl+C now to cancel, or wait 5 seconds to continue...${NC}"
sleep 5

# Get system configuration
echo ""
echo -e "${BLUE}System Configuration${NC}"
echo "-------------------"

read -p "Timezone [America/New_York]: " TIMEZONE
TIMEZONE=${TIMEZONE:-America/New_York}

read -p "Hostname [dosbox-dev]: " HOSTNAME
HOSTNAME=${HOSTNAME:-dosbox-dev}

read -p "Username [dosbox]: " USERNAME
USERNAME=${USERNAME:-dosbox}

read -sp "Password for $USERNAME: " PASSWORD
echo ""
read -sp "Confirm password: " PASSWORD_CONFIRM
echo ""

if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
    echo -e "${RED}Error: Passwords do not match${NC}"
    exit 1
fi

read -sp "Root password: " ROOT_PASSWORD
echo ""
read -sp "Confirm root password: " ROOT_PASSWORD_CONFIRM
echo ""

if [ "$ROOT_PASSWORD" != "$ROOT_PASSWORD_CONFIRM" ]; then
    echo -e "${RED}Error: Root passwords do not match${NC}"
    exit 1
fi

# Start installation
echo ""
echo -e "${GREEN}Starting installation...${NC}"
echo ""

# Partition the disk
echo -e "${BLUE}Partitioning disk...${NC}"
parted -s "$TARGET_DEVICE" mklabel gpt
parted -s "$TARGET_DEVICE" mkpart primary fat32 1MiB 512MiB
parted -s "$TARGET_DEVICE" set 1 esp on
parted -s "$TARGET_DEVICE" mkpart primary ext4 512MiB 100%

# Determine partition names
if [[ "$TARGET_DEVICE" == *"nvme"* ]] || [[ "$TARGET_DEVICE" == *"mmcblk"* ]]; then
    BOOT_PART="${TARGET_DEVICE}p1"
    ROOT_PART="${TARGET_DEVICE}p2"
else
    BOOT_PART="${TARGET_DEVICE}1"
    ROOT_PART="${TARGET_DEVICE}2"
fi

# Wait for partitions to be recognized
sleep 2

# Format partitions
echo -e "${BLUE}Formatting partitions...${NC}"
mkfs.fat -F32 "$BOOT_PART"
mkfs.ext4 -F "$ROOT_PART"

# Mount partitions
echo -e "${BLUE}Mounting partitions...${NC}"
mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot
mount "$BOOT_PART" /mnt/boot

# Install base system
echo -e "${BLUE}Installing base system...${NC}"
pacstrap /mnt base linux linux-firmware \
    grub efibootmgr \
    networkmanager \
    xorg-server xorg-xinit mesa \
    i3-wm i3status dmenu \
    alacritty \
    alsa-utils pulseaudio pulseaudio-alsa \
    base-devel git wget curl vim nano \
    gcc make bison flex texinfo unzip patch \
    htop tree man-db man-pages \
    ttf-dejavu ttf-liberation

# Generate fstab
echo -e "${BLUE}Generating fstab...${NC}"
genfstab -U /mnt >> /mnt/etc/fstab

# Configure system
echo -e "${BLUE}Configuring system...${NC}"
arch-chroot /mnt /bin/bash <<EOF
set -e

# Timezone
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Locale
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Hostname
echo "$HOSTNAME" > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
HOSTS

# Root password
echo "root:$ROOT_PASSWORD" | chpasswd

# Install GRUB
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Enable NetworkManager
systemctl enable NetworkManager

# Create user
useradd -m -G wheel,audio,video -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd

# Configure sudo
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers

# Install yay (AUR helper)
cd /tmp
sudo -u $USERNAME bash <<'YAYEOF'
cd /tmp
git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin
makepkg -si --noconfirm
YAYEOF

# Install DOSBox-X from AUR
sudo -u $USERNAME yay -S --noconfirm dosbox-x

# Download and install DJGPP
echo "Installing DJGPP toolchain..."
mkdir -p /opt/djgpp
cd /opt/djgpp
wget -c https://github.com/andrewwutw/build-djgpp/releases/download/v3.4/djgpp-linux64-gcc12.2.0.tar.bz2
tar xjf djgpp-linux64-gcc12.2.0.tar.bz2
rm djgpp-linux64-gcc12.2.0.tar.bz2

# Set up DJGPP environment
cat > /etc/profile.d/djgpp.sh <<'DJGPPEOF'
export DJGPP=/opt/djgpp
export PATH=\$DJGPP/bin:\$DJGPP/i586-pc-msdosdjgpp/bin:\$PATH
DJGPPEOF

chmod 755 /etc/profile.d/djgpp.sh

EOF

# Copy user configuration files
echo -e "${BLUE}Configuring user environment...${NC}"

# Create config directories
arch-chroot /mnt mkdir -p /home/$USERNAME/.config/i3
arch-chroot /mnt mkdir -p /home/$USERNAME/.config/alacritty
arch-chroot /mnt mkdir -p /home/$USERNAME/.config/dosbox-x

# Copy i3 config
cat > /mnt/home/$USERNAME/.config/i3/config <<'I3EOF'
# i3 config for DOSBox-X DJGPP Development
set $mod Mod4

font pango:DejaVu Sans Mono 10
floating_modifier $mod

# Key bindings
bindsym $mod+Return exec alacritty
bindsym $mod+Shift+q kill
bindsym $mod+d exec --no-startup-id dmenu_run

# Focus
bindsym $mod+h focus left
bindsym $mod+j focus down
bindsym $mod+k focus up
bindsym $mod+l focus right

# Move
bindsym $mod+Shift+h move left
bindsym $mod+Shift+j move down
bindsym $mod+Shift+k move up
bindsym $mod+Shift+l move right

# Split
bindsym $mod+b split h
bindsym $mod+v split v

# Fullscreen
bindsym $mod+f fullscreen toggle

# Floating
bindsym $mod+Shift+space floating toggle
bindsym $mod+space focus mode_toggle

# Workspaces
set $ws1 "1:DOS"
set $ws2 "2:Terminal"
set $ws3 "3:Dev"

bindsym $mod+1 workspace $ws1
bindsym $mod+2 workspace $ws2
bindsym $mod+3 workspace $ws3

bindsym $mod+Shift+1 move container to workspace $ws1
bindsym $mod+Shift+2 move container to workspace $ws2
bindsym $mod+Shift+3 move container to workspace $ws3

# Reload/restart
bindsym $mod+Shift+c reload
bindsym $mod+Shift+r restart
bindsym $mod+Shift+e exec "i3-msg exit"

# Resize mode
mode "resize" {
    bindsym h resize shrink width 10 px or 10 ppt
    bindsym j resize grow height 10 px or 10 ppt
    bindsym k resize shrink height 10 px or 10 ppt
    bindsym l resize grow width 10 px or 10 ppt
    bindsym Return mode "default"
    bindsym Escape mode "default"
}
bindsym $mod+r mode "resize"

bar {
    status_command i3status
    position top
}

# Auto-start
assign [class="dosbox-x"] $ws1
for_window [class="dosbox-x"] fullscreen enable
exec --no-startup-id dosbox-x
exec --no-startup-id alacritty
bindsym $mod+Shift+d exec dosbox-x
I3EOF

# .xinitrc
cat > /mnt/home/$USERNAME/.xinitrc <<'XINITRC'
#!/bin/sh
if [ -f $HOME/.Xresources ]; then
    xrdb -merge $HOME/.Xresources
fi
exec i3
XINITRC

# .bash_profile
cat > /mnt/home/$USERNAME/.bash_profile <<'BASHPROFILE'
[[ -f ~/.bashrc ]] && . ~/.bashrc

if [[ -z $DISPLAY && $XDG_VTNR -eq 1 ]]; then
    echo "Starting X session with i3 window manager..."
    exec startx
fi
BASHPROFILE

# .bashrc
cat > /mnt/home/$USERNAME/.bashrc <<'BASHRC'
[[ $- != *i* ]] && return

export DJGPP=/opt/djgpp
export PATH=$DJGPP/bin:$DJGPP/i586-pc-msdosdjgpp/bin:$PATH

alias ls='ls --color=auto'
alias ll='ls -lah'
alias grep='grep --color=auto'

PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

cat <<'EOF'
╔═══════════════════════════════════════════════════════════╗
║   DOSBox-X DJGPP Development Environment                  ║
╚═══════════════════════════════════════════════════════════╝

Quick Start:
  - startx          : Launch i3 with DOSBox-X
  - dosbox-x        : Run DOSBox-X
  - i586-pc-msdosdjgpp-gcc : DJGPP compiler

Window Manager: Super+Enter (terminal), Super+Shift+D (DOSBox-X)
EOF
BASHRC

# Alacritty config
cat > /mnt/home/$USERNAME/.config/alacritty/alacritty.toml <<'ALACRITTY'
[window]
padding.x = 10
padding.y = 10
opacity = 0.95

[font]
size = 11.0

[font.normal]
family = "DejaVu Sans Mono"

[colors.primary]
background = "#1e1e1e"
foreground = "#d4d4d4"

[scrolling]
history = 10000
ALACRITTY

# Fix permissions
arch-chroot /mnt chown -R $USERNAME:$USERNAME /home/$USERNAME

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Installation Complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Unmount: umount -R /mnt"
echo "  2. Reboot: reboot"
echo "  3. Remove installation media"
echo "  4. Login with username: $USERNAME"
echo "  5. Type 'startx' to launch i3 window manager"
echo ""
echo -e "${BLUE}DOSBox-X and DJGPP are ready to use!${NC}"
