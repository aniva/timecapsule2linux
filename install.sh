#!/bin/bash
# ==============================================================================
# install.sh - Apple Time Capsule Linux Client Installer
# ==============================================================================
# Automatically installs build dependencies, builds the patched afpfs-ng
# client, installs helper scripts, and registers the auto-mount service.
# Supports Debian/Ubuntu and Fedora/CentOS/RHEL.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_FILE="${SCRIPT_DIR}/patches/afpfs-ng-wronly-fix.patch"
BUILD_DIR="/tmp/afpfs-ng-build"

echo "=== Apple Time Capsule Linux Client Installer ==="

# 1. Detect OS and install dependencies
if [ -f /etc/debian_version ]; then
    echo "[-] Detected Debian-based system."
    echo "[-] Installing build dependencies via apt..."
    sudo apt-get update
    sudo apt-get install -y build-essential meson ninja-build \
        libgcrypt20-dev libgmp-dev libfuse3-dev libglib2.0-dev pkg-config git
elif [ -f /etc/fedora-release ] || [ -f /etc/redhat-release ]; then
    echo "[-] Detected RedHat/Fedora-based system."
    echo "[-] Installing build dependencies via dnf..."
    sudo dnf install -y gcc gcc-c++ meson ninja-build \
        libgcrypt-devel gmp-devel fuse3-devel glib2-devel pkgconf-pkg-config git
else
    echo "[!] Unsupported operating system. Please install build dependencies manually."
    echo "Required: gcc/g++, meson, ninja, libgcrypt, gmp, libfuse3, glib2, pkg-config, git"
    read -r -p "Proceed anyway? (y/N) " response
    if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        exit 1
    fi
fi

# 2. Clean up any previous build dir
rm -rf "$BUILD_DIR"

# 3. Clone, patch, build, and install afpfs-ng
echo "[-] Cloning rdmark/afpfs-ng repository..."
git clone https://github.com/rdmark/afpfs-ng.git "$BUILD_DIR"

echo "[-] Applying O_WRONLY write compatibility patch..."
cd "$BUILD_DIR"
if [ -f "$PATCH_FILE" ]; then
    git apply "$PATCH_FILE"
    echo "[+] Patch applied successfully."
else
    echo "[!] Patch file not found at $PATCH_FILE. Compiling unpatched version."
fi

echo "[-] Compiling with Meson and Ninja..."
meson setup build
ninja -C build

echo "[-] Installing binaries and libraries to /usr/local..."
sudo ninja -C build install
sudo ldconfig

# Add global symlinks for ease of access if they don't exist under /usr/bin
for bin in mount_afpfs afpfsd afpcmd afpgetstatus; do
    if [ ! -f "/usr/bin/$bin" ] && [ -f "/usr/local/bin/$bin" ]; then
        echo "[-] Creating symlink /usr/bin/$bin -> /usr/local/bin/$bin"
        sudo ln -sf "/usr/local/bin/$bin" "/usr/bin/$bin"
    fi
done

# 4. Install template scripts and services
echo "[-] Setting up local configuration..."
mkdir -p "$HOME/scripts"
mkdir -p "$HOME/.config/systemd/user"

# Copy scripts if they do not already exist
if [ ! -f "$HOME/scripts/mount-timecapsule.sh" ]; then
    cp "$SCRIPT_DIR/mount-timecapsule.sh.template" "$HOME/scripts/mount-timecapsule.sh"
    chmod +x "$HOME/scripts/mount-timecapsule.sh"
    echo "[+] Created script at ~/scripts/mount-timecapsule.sh"
else
    echo "[!] File ~/scripts/mount-timecapsule.sh already exists, skipping to preserve settings."
fi

if [ ! -f "$HOME/.config/systemd/user/timecapsule.service" ]; then
    cp "$SCRIPT_DIR/timecapsule.service.template" "$HOME/.config/systemd/user/timecapsule.service"
    echo "[+] Created systemd service at ~/.config/systemd/user/timecapsule.service"
else
    echo "[!] Service ~/.config/systemd/user/timecapsule.service already exists, skipping."
fi

echo "================================================="
echo "[+] Installation complete!"
echo "================================================="
echo "Next steps to complete configuration:"
echo "1. Edit ~/scripts/mount-timecapsule.sh to set your Time Capsule IP, credentials, and mount point."
echo "2. Test mounting manually:"
echo "   ~/scripts/mount-timecapsule.sh mount"
echo "3. Enable and start auto-mounting on login:"
echo "   systemctl --user daemon-reload"
echo "   systemctl --user enable timecapsule.service"
echo "   systemctl --user start timecapsule.service"
echo "================================================="
