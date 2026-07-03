#!/bin/bash
# Runs INSIDE the chroot. Shrink and sanitise the rootfs before repacking.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "==> [40-cleanup] Cleaning rootfs"

apt-get autoremove --purge -y || true
apt-get clean
rm -rf /var/lib/apt/lists/*
rm -rf /tmp/* /var/tmp/*

# Truncate logs.
find /var/log -type f -exec truncate -s 0 {} + 2>/dev/null || true

# Reset machine-id so every installed system gets a fresh one.
: > /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id 2>/dev/null || true

# Drop any downloaded keyring/apt working state noise.
rm -rf /root/.cache /root/.wget-hsts 2>/dev/null || true

echo "==> [40-cleanup] done"
