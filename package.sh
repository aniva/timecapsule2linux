#!/bin/bash
# ==============================================================================
# package.sh - Build Debian (.deb) and RPM (.rpm) Packages
# ==============================================================================
# Automates the compilation and packaging of the patched FUSE client,
# helper scripts, and systemd configurations.
# ==============================================================================

set -euo pipefail

VERSION="1.0.0"
RELEASE="1"
ARCH="amd64"
PKG_NAME="timecapsule2linux"
BUILD_DIR="/tmp/afpfs-ng-build"
PKG_STAGE="/tmp/timecapsule2linux-pkg"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_FILE="${SCRIPT_DIR}/patches/afpfs-ng-wronly-fix.patch"

echo "=== Building timecapsule2linux packages (v${VERSION}) ==="

# 1. Compile patched afpfs-ng from source
echo "[-] Compiling patched afpfs-ng..."
rm -rf "$BUILD_DIR"
git clone https://github.com/rdmark/afpfs-ng.git "$BUILD_DIR"
cd "$BUILD_DIR"
if [ -f "$PATCH_FILE" ]; then
    git apply "$PATCH_FILE"
fi
meson setup build --prefix=/usr
ninja -C build
DESTDIR="$PKG_STAGE" ninja -C build install

# Clean up build docs and includes in the package stage to keep it lean
rm -rf "${PKG_STAGE}/usr/include"
rm -rf "${PKG_STAGE}/usr/share/man"
rm -rf "${PKG_STAGE}/usr/share/doc"
rm -rf "${PKG_STAGE}/usr/lib/x86_64-linux-gnu/pkgconfig"

# 2. Add local configuration files and scripts to package
echo "[-] Adding scripts and systemd templates..."
mkdir -p "${PKG_STAGE}/usr/share/timecapsule2linux"
cp "${SCRIPT_DIR}/mount-timecapsule.sh.template" "${PKG_STAGE}/usr/share/timecapsule2linux/mount-timecapsule.sh"
cp "${SCRIPT_DIR}/timecapsule.service.template" "${PKG_STAGE}/usr/share/timecapsule2linux/timecapsule.service"

# 3. Create Debian Package (.deb)
if command -v dpkg-deb >/dev/null 2>&1; then
    echo "[-] Building Debian (.deb) package..."
    DEB_DIR="${PKG_STAGE}-deb"
    rm -rf "$DEB_DIR"
    cp -r "$PKG_STAGE" "$DEB_DIR"
    
    mkdir -p "${DEB_DIR}/DEBIAN"
    cat > "${DEB_DIR}/DEBIAN/control" <<EOF
Package: ${PKG_NAME}
Version: ${VERSION}-${RELEASE}
Section: utils
Priority: optional
Architecture: ${ARCH}
Depends: libgcrypt20, libgmp10, libfuse3-3, libglib2.0-0, fuse3
Maintainer: ${user.name:-aniva} <${user.email:-ivanovan@gmail.com}>
Description: Apple Time Capsule AFP FUSE Mount Client
 Package includes a patched afpfs-ng client with FUSE3 support,
 a mount helper script, and a systemd user service template
 configured to bypass legacy SMBv1/NTLMv1 restrictions.
EOF

    # postinst script to run ldconfig
    cat > "${DEB_DIR}/DEBIAN/postinst" <<EOF
#!/bin/sh
set -e
ldconfig
echo "========================================================================="
echo "timecapsule2linux has been installed!"
echo "Configuration templates have been placed in:"
echo "  /usr/share/timecapsule2linux/"
echo ""
echo "To get started:"
echo "1. Copy mount-timecapsule.sh to your home directory:"
echo "   mkdir -p ~/scripts && cp /usr/share/timecapsule2linux/mount-timecapsule.sh ~/scripts/"
echo "2. Edit and configure ~/scripts/mount-timecapsule.sh"
echo "3. Copy and enable the systemd service:"
echo "   mkdir -p ~/.config/systemd/user && cp /usr/share/timecapsule2linux/timecapsule.service ~/.config/systemd/user/"
echo "   systemctl --user daemon-reload"
echo "   systemctl --user enable timecapsule.service"
echo "========================================================================="
EOF
    chmod +x "${DEB_DIR}/DEBIAN/postinst"

    dpkg-deb --build "$DEB_DIR" "${SCRIPT_DIR}/${PKG_NAME}_${VERSION}-${RELEASE}_${ARCH}.deb"
    echo "[+] Debian package created at: ${PKG_NAME}_${VERSION}-${RELEASE}_${ARCH}.deb"
    rm -rf "$DEB_DIR"
else
    echo "[!] dpkg-deb not found, skipping Debian packaging."
fi

# 4. Create RPM Package (.rpm) using fpm if available
if command -v fpm >/dev/null 2>&1; then
    echo "[-] Building RPM (.rpm) package via fpm..."
    # Convert libraries path structure if required for Fedora (lib64)
    # FPM can automatically generate an RPM from a directory
    fpm -s dir -t rpm \
        -n "$PKG_NAME" \
        -v "$VERSION" \
        --iteration "$RELEASE" \
        --architecture "x86_64" \
        --depends "libgcrypt" \
        --depends "gmp" \
        --depends "fuse3" \
        --depends "glib2" \
        --description "Apple Time Capsule AFP FUSE Mount Client" \
        -C "$PKG_STAGE" \
        -p "${SCRIPT_DIR}/${PKG_NAME}-${VERSION}-${RELEASE}.x86_64.rpm" \
        usr/
    echo "[+] RPM package created at: ${PKG_NAME}-${VERSION}-${RELEASE}.x86_64.rpm"
elif command -v rpmbuild >/dev/null 2>&1; then
    echo "[-] Building RPM (.rpm) package via rpmbuild..."
    # Simple SPEC-based rpmbuild can be triggered here
    # Since rpmbuild setups are verbose, GitHub Actions workflow is the preferred path.
    echo "[!] rpmbuild detected. Spec files are handled natively in GitHub Actions pipeline."
else
    echo "[!] FPM / rpmbuild not found, skipping RPM packaging."
fi

# Clean up build assets
rm -rf "$PKG_STAGE"
rm -rf "$BUILD_DIR"
echo "[+] Done!"
