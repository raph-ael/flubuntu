#!/bin/bash
# Runs INSIDE the chroot. Install deb/Flatpak replacements for the removed snaps.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "==> [20-replace-apps] Installing deb/Flatpak replacements"

apt-get update

# ---- Browser: native deb from Mozilla repo (pinned in 10-repos) ----------
# Mozilla's apt repo provides Firefox as a deb. It does NOT ship Thunderbird,
# so we deliberately install only Firefox here — installing `thunderbird` from
# Ubuntu's archive would pull the snap-transitional package (and snapd) back in.
apt-get install -y firefox

# ---- App store: GNOME Software (deb) as unified frontend -----------------
#   snap-store (App Center) -> gnome-software + flatpak plugin + packagekit (deb).
apt-get install -y --no-install-recommends \
  gnome-software gnome-software-plugin-flatpak packagekit || \
  apt-get install -y --no-install-recommends gnome-software gnome-software-plugin-flatpak

# ---- Firmware updates: fwupd (deb) replaces the firmware-updater snap ------
apt-get install -y --no-install-recommends fwupd

# ---- Mail: Thunderbird as a Flatpak (Mozilla has no thunderbird deb) ------
# Best-effort: a Flathub hiccup should not fail the whole build; Thunderbird
# stays installable from GNOME Software either way.
flatpak install --system --noninteractive --assumeyes flathub org.mozilla.Thunderbird || \
  echo "WARN: Thunderbird flatpak not pre-installed (still available via GNOME Software/Flathub)"

# ---- Guard: fail loudly if snapd got pulled back in ----------------------
if dpkg -s snapd >/dev/null 2>&1; then
  echo "!! snapd was reinstalled as a dependency — check reverse-depends and" >&2
  echo "!! add a --no-install-recommends replacement in this script." >&2
  exit 1
fi

echo "==> [20-replace-apps] done"
