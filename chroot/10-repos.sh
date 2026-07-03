#!/bin/bash
# Runs INSIDE the chroot. Set up the Mozilla APT repo (Firefox/Thunderbird deb)
# and Flatpak + Flathub as the second app source.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "==> [10-repos] Configuring APT/Flatpak sources"

# The ISO rootfs ships a CD-ROM apt source (file:///cdrom) that is unreachable in
# the build chroot AND would break `apt update` on the installed system. Remove it.
rm -f /etc/apt/sources.list.d/cdrom.sources

apt-get update
apt-get install -y --no-install-recommends ca-certificates wget gnupg

# ---- Mozilla APT repository (native deb Firefox & Thunderbird) -----------
install -d -m 0755 /etc/apt/keyrings
wget -qO- https://packages.mozilla.org/apt/repo-signing-key.gpg \
  > /etc/apt/keyrings/packages.mozilla.org.asc

cat > /etc/apt/sources.list.d/mozilla.sources <<'EOF'
Types: deb
URIs: https://packages.mozilla.org/apt
Suites: mozilla
Components: main
Signed-By: /etc/apt/keyrings/packages.mozilla.org.asc
EOF

# Pin Mozilla origin ABOVE Ubuntu's transitional (snap-wrapper) firefox deb, so
# `apt install firefox` always resolves to the real Mozilla package.
cat > /etc/apt/preferences.d/mozilla.pref <<'EOF'
# Flubuntu: prefer Mozilla's native deb over Ubuntu's snap-transitional package.
Package: firefox*
Pin: origin packages.mozilla.org
Pin-Priority: 700

Package: thunderbird*
Pin: origin packages.mozilla.org
Pin-Priority: 700
EOF

# ---- Flatpak + Flathub ---------------------------------------------------
apt-get update
apt-get install -y --no-install-recommends flatpak
# System-wide Flathub remote (available to every user, shown in GNOME Software).
flatpak remote-add --system --if-not-exists \
  flathub https://dl.flathub.org/repo/flathub.flatpakrepo

echo "==> [10-repos] done"
