#!/bin/bash
# Runs INSIDE the chroot. Remove Snap entirely and block it from returning.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "==> [00-desnap] Removing snaps and snapd"

# 1) Remove installed snaps. On the ISO the snaps are *pre-seeded* rather than
#    fully installed, so `snap remove` may not apply; the authoritative fix is
#    clearing the seed (step 3) + purging snapd. We still try snap remove in
#    case the live rootfs has them mounted.
if command -v snap >/dev/null 2>&1; then
  # Apps first, then base snaps last (dependency order).
  for s in firefox thunderbird snap-store firmware-updater \
           snapd-desktop-integration gtk-common-themes bare; do
    snap remove --purge "$s" 2>/dev/null || true
  done
  # Remaining (gnome-* base, core*) — remove whatever is left.
  snap list 2>/dev/null | awk 'NR>1{print $1}' | while read -r s; do
    snap remove --purge "$s" 2>/dev/null || true
  done
fi

# 2) Purge the snapd daemon + the transitional snap-wrapper debs. In 26.04's
#    minimal.squashfs the `firefox` deb is a stub that depends on snapd; remove it
#    so Mozilla's real deb (installed in 20-replace-apps.sh) takes the name.
apt-get purge -y firefox snapd || true
apt-get autoremove --purge -y || true

# 3) Wipe pre-seeded snaps and snapd state so first boot does NOT reinstall them.
#    Removing the whole tree also drops /var/lib/snapd/seed and its seed.yaml,
#    so first-boot seeding finds nothing to install.
rm -rf /snap /var/snap /var/lib/snapd /var/cache/snapd /root/snap 2>/dev/null || true

# 4) Permanent block. The pin file is delivered via overlay/ (see
#    overlay/etc/apt/preferences.d/no-snap.pref) and is already in place by the
#    time this runs, but assert it here too for a standalone-safe script.
install -d /etc/apt/preferences.d
cat > /etc/apt/preferences.d/no-snap.pref <<'EOF'
# Flubuntu: never install snapd, even as a dependency.
Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF

# 5) Sanity: report anything that still Depends (hard) on snapd — these must be
#    handled in 20-replace-apps.sh, otherwise apt would pull snapd back in.
echo "==> [00-desnap] Reverse-depends still referencing snapd (review!):"
apt-cache rdepends --installed snapd 2>/dev/null | sed 's/^/    /' || true

echo "==> [00-desnap] done"
