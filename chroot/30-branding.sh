#!/bin/bash
# Runs INSIDE the chroot. Apply Flubuntu identity. Values passed via env by
# build.sh: DISTRO_NAME, DISTRO_VERSION, DISTRO_CODENAME.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

NAME="${DISTRO_NAME:-Flubuntu}"
VER="${DISTRO_VERSION:-26.04}"
CODENAME="${DISTRO_CODENAME:-flubuntu}"

echo "==> [30-branding] Branding as $NAME $VER"

# ---- os-release / lsb-release -------------------------------------------
cat > /etc/os-release <<EOF
PRETTY_NAME="$NAME $VER"
NAME="$NAME"
VERSION_ID="$VER"
VERSION="$VER ($CODENAME)"
VERSION_CODENAME=$CODENAME
ID=flubuntu
ID_LIKE="ubuntu debian"
HOME_URL="https://example.org/flubuntu"
SUPPORT_URL="https://example.org/flubuntu/support"
BUG_REPORT_URL="https://example.org/flubuntu/issues"
EOF
# Note: /etc/os-release is already a symlink to ../usr/lib/os-release, so the
# write above updates the canonical file; no extra symlinking needed.

cat > /etc/lsb-release <<EOF
DISTRIB_ID=$NAME
DISTRIB_RELEASE=$VER
DISTRIB_CODENAME=$CODENAME
DISTRIB_DESCRIPTION="$NAME $VER"
EOF

echo "$NAME $VER \\n \\l" > /etc/issue
echo "$NAME $VER" > /etc/issue.net

# ---- Wallpaper / logos (delivered via overlay/ into /usr/share) ----------
#   Place assets under branding/ ; build.sh copies overlay/. Here we set the
#   GNOME default background + favourites (no snap apps) via a gschema override.
if [ -d /usr/share/glib-2.0/schemas ]; then
  cat > /usr/share/glib-2.0/schemas/90_flubuntu.gschema.override <<'EOF'
[org.gnome.desktop.background]
picture-uri='file:///usr/share/backgrounds/flubuntu.png'
picture-uri-dark='file:///usr/share/backgrounds/flubuntu.png'

[org.gnome.shell]
favorite-apps=['firefox.desktop', 'thunderbird.desktop', 'org.gnome.Nautilus.desktop', 'org.gnome.Software.desktop', 'org.gnome.Console.desktop']
EOF
  glib-compile-schemas /usr/share/glib-2.0/schemas || true
fi

# ---- Plymouth boot theme (if a flubuntu theme was staged via overlay) ----
if [ -d /usr/share/plymouth/themes/flubuntu ]; then
  update-alternatives --install /usr/share/plymouth/themes/default.plymouth \
    default.plymouth /usr/share/plymouth/themes/flubuntu/flubuntu.plymouth 200 || true
  update-alternatives --set default.plymouth \
    /usr/share/plymouth/themes/flubuntu/flubuntu.plymouth || true
  update-initramfs -u || true
fi

echo "==> [30-branding] done"
