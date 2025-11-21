#!/bin/bash
# This script runs on first boot to customize the live system

set -e

echo "Starting customization script..."

# Create a regular user for building AUR packages
useradd -m -G wheel -s /bin/bash builder
echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Install yay (AUR helper)
cd /tmp
sudo -u builder bash <<'EOF'
cd /tmp
git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin
makepkg -si --noconfirm
EOF

# Install DOSBox-X from AUR
sudo -u builder yay -S --noconfirm dosbox-x

# Download and set up DJGPP toolchain
echo "Setting up DJGPP toolchain..."
mkdir -p /opt/djgpp
cd /opt/djgpp

# Download DJGPP base (using djgpp.zip from delorie.com or mirrors)
# You can customize which components to include
DJGPP_VERSION="12.2.0"
DJGPP_BASE_URL="https://github.com/andrewwutw/build-djgpp/releases/download/v3.4"

sudo -u builder bash <<EOF
cd /opt/djgpp
# Download pre-built DJGPP toolchain
wget -c ${DJGPP_BASE_URL}/djgpp-linux64-gcc${DJGPP_VERSION}.tar.bz2
tar xjf djgpp-linux64-gcc${DJGPP_VERSION}.tar.bz2
rm djgpp-linux64-gcc${DJGPP_VERSION}.tar.bz2
EOF

# Set up environment
cat > /etc/profile.d/djgpp.sh <<'DJEOF'
export DJGPP=/opt/djgpp
export PATH=$DJGPP/bin:$DJGPP/i586-pc-msdosdjgpp/bin:$PATH
DJEOF

chmod 755 /etc/profile.d/djgpp.sh

# Create a default user 'dosbox' with password 'dosbox'
useradd -m -G wheel,audio,video -s /bin/bash dosbox
echo "dosbox:dosbox" | chpasswd

# Copy skeleton files to dosbox user
cp -r /etc/skel/. /home/dosbox/
chown -R dosbox:dosbox /home/dosbox

# Enable NetworkManager
systemctl enable NetworkManager

# Clean up builder user
userdel -r builder 2>/dev/null || true

echo "Customization complete!"
