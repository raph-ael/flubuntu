#!/bin/bash
# Runs INSIDE the chroot. Install Calamares as Flubuntu's snap-free installer.
#
# Ubuntu 26.04's desktop installer (`ubuntu-desktop-bootstrap`) ships ONLY as a
# classic snap, so removing snapd in 00-desnap.sh also removed the installer.
# Calamares (deb, universe) replaces it. Its configuration + branding + the
# live-session launcher/polkit/autostart come in via overlay/ (already copied
# in before this script runs).
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "==> [25-installer] Installing Calamares + UEFI bootloader packages"
apt-get update

# Calamares itself. Keep recommends so its Qt/QML runtime + slideshow deps come
# along (the bare `calamares` deb is only the binary).
apt-get install -y calamares

# The base squashfs ships BIOS grub only (grub-pc). Add the UEFI bootloader
# stack so Calamares can install a working bootloader on EFI targets too. These
# coexist with grub-pc (the *-signed debs depend on grub-efi-amd64-bin, not the
# conflicting grub-efi-amd64 metapackage — verified with apt-get --dry-run).
apt-get install -y --no-install-recommends \
    grub-efi-amd64-bin grub-efi-amd64-signed shim-signed efibootmgr dosfstools

# Installer binary must exist, else the whole point is moot.
command -v calamares >/dev/null || { echo "!! [25-installer] calamares missing after install"; exit 1; }
[ -f /etc/calamares/settings.conf ]                         || { echo "!! [25-installer] settings.conf missing (overlay not applied?)"; exit 1; }
[ -f /etc/calamares/branding/flubuntu/branding.desc ]       || { echo "!! [25-installer] branding missing"; exit 1; }

# Ensure our helper scripts are executable (rsync should preserve, assert anyway).
chmod 0755 /usr/local/bin/install-flubuntu-launch \
           /usr/local/bin/flubuntu-live-setup \
           /usr/local/sbin/flubuntu-calamares

update-desktop-database -q 2>/dev/null || true

echo "==> [25-installer] Calamares ready: $(calamares --version 2>&1 | head -1)"
echo "==> [25-installer] done"
