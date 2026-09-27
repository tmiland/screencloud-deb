#!/usr/bin/env bash
# Repackage the upstream ScreenCloud AppImage into a .deb.
# Usage: build-deb.sh <version> <appimage-path> <output-dir> [arch]
set -euo pipefail

VERSION="${1:?version}"
APPIMAGE="${2:?appimage}"
OUTDIR="${3:?outdir}"
ARCH="${4:-amd64}"

DEB_ARCH="$ARCH"
case "$ARCH" in
  x86_64|amd64) DEB_ARCH=amd64 ;;
  aarch64|arm64) DEB_ARCH=arm64 ;;
esac

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
PKG="$WORK/pkg"
PREFIX="/opt/screencloud"

# 1. Extract the AppImage
install -m 0755 "$APPIMAGE" "$WORK/app.AppImage"
( cd "$WORK" && "$WORK/app.AppImage" --appimage-extract >/dev/null )
APPDIR="$WORK/squashfs-root"

# 2. Lay out the package tree
mkdir -p "$PKG$PREFIX" "$PKG/usr/bin" "$PKG/usr/share/applications" \
         "$PKG/usr/share/metainfo" "$PKG/DEBIAN"
cp -a "$APPDIR/." "$PKG$PREFIX/"

# launcher on PATH
ln -s "$PREFIX/AppRun" "$PKG/usr/bin/screencloud"

# desktop entry (strip the AppImage shebang, ensure PATH-independent launch)
sed -e '/^#!/d' "$APPDIR/net.screencloud.screencloudapp.desktop" \
  | sed -e 's|^Exec=.*|Exec=screencloud|' -e 's|^Icon=.*|Icon=screencloud|' \
        -e '/^OnlyShowIn=/d' \
  > "$PKG/usr/share/applications/net.screencloud.screencloudapp.desktop"

# icons + appstream metainfo
if [ -d "$APPDIR/usr/local/share/icons/hicolor" ]; then
  mkdir -p "$PKG/usr/share/icons/hicolor"
  cp -a "$APPDIR/usr/local/share/icons/hicolor/." "$PKG/usr/share/icons/hicolor/"
fi
if [ -f "$APPDIR/usr/local/share/metainfo/net.screencloud.screencloudapp.appdata.xml" ]; then
  cp -a "$APPDIR/usr/local/share/metainfo/net.screencloud.screencloudapp.appdata.xml" \
        "$PKG/usr/share/metainfo/"
fi

# 3. control
SIZE=$(du -sk "$PKG" | awk '{print $1}')
cat > "$PKG/DEBIAN/control" <<EOF
Package: screencloud
Version: $VERSION
Architecture: $DEB_ARCH
Maintainer: Tommy Miland <tmiland@tmiland.com>
Installed-Size: $SIZE
Section: graphics
Priority: optional
Homepage: https://screencloud.net/
Depends: libc6 (>= 2.34), libgcc-s1, libstdc++6, zlib1g, libcom-err2, libdrm2, libegl1, libfontconfig1, libfreetype6, libgbm1, libgl1, libglx0, libgmp10, libgpg-error0, libopengl0, libssh2-1, libuuid1, libwayland-client0, libx11-6, libx11-xcb1, libxcb1
Description: Easy to use screenshot sharing tool
 ScreenCloud is a cross-platform screenshot sharing application. It lets you
 take screenshots, annotate them, and upload them to several online services
 (Imgur, Dropbox, your own FTP, etc.) via plugins.
 .
 This package repackages the upstream AppImage build.
EOF

cat > "$PKG/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if [ -x "$(command -v update-desktop-database)" ]; then
  update-desktop-database -q /usr/share/applications || true
fi
if [ -x "$(command -v gtk-update-icon-cache)" ]; then
  gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
fi
exit 0
EOF

cat > "$PKG/DEBIAN/postrm" <<'EOF'
#!/bin/sh
set -e
if [ -x "$(command -v update-desktop-database)" ]; then
  update-desktop-database -q /usr/share/applications || true
fi
if [ -x "$(command -v gtk-update-icon-cache)" ]; then
  gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
fi
exit 0
EOF

chmod 755 "$PKG/DEBIAN/postinst" "$PKG/DEBIAN/postrm"
find "$PKG" -type d -exec chmod 755 {} +
find "$PKG$PREFIX" -type f -exec chmod 644 {} + 2>/dev/null || true
chmod 755 "$PKG$PREFIX/AppRun" 2>/dev/null || true
find "$PKG$PREFIX" -type f \( -name '*.so*' -o -name 'screencloud*' \) -exec chmod 755 {} + 2>/dev/null || true
find "$PKG$PREFIX/usr/local/bin" -type f -exec chmod 755 {} + 2>/dev/null || true

# 4. build
mkdir -p "$OUTDIR"
DEB="$OUTDIR/screencloud_${VERSION}_${DEB_ARCH}.deb"
dpkg-deb --root-owner-group -Zzstd -b "$PKG" "$DEB"
echo "built: $DEB"
