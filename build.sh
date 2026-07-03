#!/bin/bash
# Flubuntu build orchestrator: download -> unpack -> chroot -> repack -> ISO.
# Run as root on an Ubuntu/Debian host:  sudo ./build.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"
# shellcheck source=config/flubuntu.conf
source "$REPO_ROOT/config/flubuntu.conf"

ISO_DIR="$WORK_DIR/iso"          # extracted ISO tree
ROOTFS="$WORK_DIR/rootfs"        # extracted (target) squashfs -> chroot
MOUNTS=()                        # tracked for cleanup

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m!! %s\033[0m\n' "$*" >&2; }
die()  { err "$*"; exit 1; }

cleanup() {
  set +e
  # Unmount in reverse order.
  for ((i=${#MOUNTS[@]}-1; i>=0; i--)); do
    umount -lf "${MOUNTS[$i]}" 2>/dev/null
  done
  [ -n "${ISO_MNT:-}" ] && mountpoint -q "$ISO_MNT" && umount -lf "$ISO_MNT" 2>/dev/null
}
trap cleanup EXIT

# ---------------------------------------------------------------- preflight
[ "$(id -u)" -eq 0 ] || die "Must run as root (sudo ./build.sh)."
for bin in xorriso unsquashfs mksquashfs wget rsync; do
  command -v "$bin" >/dev/null || die "Missing '$bin'. Install: apt install xorriso squashfs-tools wget rsync"
done
mkdir -p cache out "$WORK_DIR"

# ---------------------------------------------------------------- 1. source ISO
log "Fetching source ISO"
if [ ! -f "$SOURCE_ISO" ]; then
  wget -c -O "$SOURCE_ISO" "$SOURCE_ISO_URL"
fi
if [ "$SOURCE_ISO_SHA256" = "REPLACE_WITH_OFFICIAL_SHA256" ]; then
  die "Set SOURCE_ISO_SHA256 in config/flubuntu.conf (from the official SHA256SUMS)."
fi
log "Verifying checksum"
echo "$SOURCE_ISO_SHA256  $SOURCE_ISO" | sha256sum -c - || die "Checksum mismatch — aborting."

# RESUME=1 reuses an existing work/ (extracted ISO + modified rootfs) and only
# re-runs the idempotent chroot steps + packing — avoids re-downloading packages.
RESUME="${RESUME:-}"

# ---------------------------------------------------------------- 2. unpack ISO
if [ -z "$RESUME" ]; then
  log "Extracting ISO tree to $ISO_DIR"
  rm -rf "$ISO_DIR"; mkdir -p "$ISO_DIR"
  ISO_MNT="$(mktemp -d)"
  mount -o loop,ro "$SOURCE_ISO" "$ISO_MNT"
  rsync -a "$ISO_MNT"/ "$ISO_DIR"/
  umount "$ISO_MNT"; rmdir "$ISO_MNT"; ISO_MNT=""
  chmod -R u+w "$ISO_DIR"
else
  log "RESUME: reusing existing $ISO_DIR"
  [ -d "$ISO_DIR/casper" ] || die "RESUME set but $ISO_DIR/casper missing."
fi

# Locate the squashfs layer to modify.
if [ -n "${TARGET_SQUASHFS:-}" ]; then
  SQUASH="$ISO_DIR/$TARGET_SQUASHFS"
else
  # Prefer the "standard"/full layer; fall back to the largest .squashfs.
  SQUASH="$(ls -S "$ISO_DIR"/casper/*.standard.squashfs "$ISO_DIR"/casper/*.squashfs 2>/dev/null | head -n1)"
fi
[ -f "$SQUASH" ] || die "No target squashfs found under casper/. Set TARGET_SQUASHFS."
log "Target squashfs: ${SQUASH#$ISO_DIR/}"

# ---------------------------------------------------------------- 3. unpack rootfs
if [ -z "$RESUME" ]; then
  log "Unsquashing rootfs to $ROOTFS"
  rm -rf "$ROOTFS"
  unsquashfs -d "$ROOTFS" "$SQUASH"
else
  log "RESUME: reusing existing $ROOTFS"
fi

# CRITICAL VALIDATION POINT (layered squashfs):
# Ubuntu 24.04+ uses layered squashfs. If the chosen layer is a thin overlay it
# will lack a full userland and the chroot will fail. Verify it is chrootable.
[ -x "$ROOTFS/bin/bash" ] || [ -x "$ROOTFS/usr/bin/bash" ] || die \
  "Rootfs has no bash — the chosen layer is a partial overlay. Set TARGET_SQUASHFS
   to the FULL layer (usually *.standard.squashfs) or merge layers first."

# ---------------------------------------------------------------- 4. modify
log "Applying overlay files"
rsync -a "$REPO_ROOT"/overlay/ "$ROOTFS"/

log "Staging branding assets"
[ -d "$REPO_ROOT/branding/backgrounds" ] && \
  rsync -a "$REPO_ROOT/branding/backgrounds/" "$ROOTFS/usr/share/backgrounds/"
[ -d "$REPO_ROOT/branding/plymouth" ] && \
  rsync -a "$REPO_ROOT/branding/plymouth/" "$ROOTFS/usr/share/plymouth/themes/flubuntu/"

# Bind-mount kernel filesystems for a working chroot.
for fs in dev dev/pts proc sys run; do
  mount --bind "/$fs" "$ROOTFS/$fs"; MOUNTS+=("$ROOTFS/$fs")
done
# Give the chroot working DNS. The rootfs ships /etc/resolv.conf as a symlink to
# systemd-resolved's stub (127.0.0.53), which does not resolve inside a chroot,
# so replace it with a real file using public resolvers for the build.
rm -f "$ROOTFS/etc/resolv.conf"
printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > "$ROOTFS/etc/resolv.conf"

# Copy chroot scripts in and run them in order. A per-script .done marker lets
# RESUME skip already-completed steps (avoids re-purging/re-downloading).
mkdir -p "$ROOTFS/tmp/flubuntu" "$ROOTFS/var/lib/flubuntu"
rsync -a "$REPO_ROOT"/chroot/ "$ROOTFS/tmp/flubuntu/"
chmod +x "$ROOTFS"/tmp/flubuntu/*.sh
for script in "$ROOTFS"/tmp/flubuntu/[0-9]*.sh; do
  name="$(basename "$script")"
  if [ -n "$RESUME" ] && [ -e "$ROOTFS/var/lib/flubuntu/$name.done" ]; then
    log "chroot: skip $name (already done)"; continue
  fi
  log "chroot: running $name"
  chroot "$ROOTFS" env \
    DISTRO_NAME="$DISTRO_NAME" DISTRO_VERSION="$DISTRO_VERSION" \
    DISTRO_CODENAME="$DISTRO_CODENAME" \
    /tmp/flubuntu/"$name"
  touch "$ROOTFS/var/lib/flubuntu/$name.done"
done
rm -rf "$ROOTFS/tmp/flubuntu" "$ROOTFS/var/lib/flubuntu"
# Restore the systemd-resolved symlink so the installed system uses it again.
rm -f "$ROOTFS/etc/resolv.conf"
ln -sf ../run/systemd/resolve/stub-resolv.conf "$ROOTFS/etc/resolv.conf"

# Unmount chroot filesystems before repacking.
for ((i=${#MOUNTS[@]}-1; i>=0; i--)); do umount -lf "${MOUNTS[$i]}"; done
MOUNTS=()

# ---------------------------------------------------------------- 5. repack
log "Repacking squashfs (${SQUASHFS_COMP})"
rm -f "$SQUASH"
mksquashfs "$ROOTFS" "$SQUASH" -comp "$SQUASHFS_COMP" $SQUASHFS_COMP_ARGS -noappend
ROOTFS_BYTES="$(du -sx --block-size=1 "$ROOTFS" | cut -f1)"
# Update the layer size hint the installer reads.
if [ -f "${SQUASH%.squashfs}.size" ]; then
  printf '%s' "$ROOTFS_BYTES" > "${SQUASH%.squashfs}.size"
fi

# ---- Rewrite install-sources.yaml: one clean, self-contained source -------
# 26.04 offers a snap-laden layered "full" source and secureboot variations we
# did not desnap. Collapse to a single source that installs our modified
# minimal.squashfs, so EVERY install path is snap-free.
ISRC="$ISO_DIR/casper/install-sources.yaml"
if [ -f "$ISRC" ]; then
  log "Rewriting install-sources.yaml -> single clean source"
  cat > "$ISRC" <<EOF
kernel:
  default: linux-generic-hwe-24.04
sources:
- default: true
  description:
    en: A snap-free Ubuntu Desktop (deb + Flatpak).
  id: ubuntu-desktop-minimal
  locale_support: langpack
  name:
    en: $DISTRO_NAME Desktop
  path: minimal.squashfs
  preinstalled_langs:
  - de
  - en
  - ''
  size: $ROOTFS_BYTES
  type: fsimage-layered
  variant: desktop
  variations:
    minimal:
      path: minimal.squashfs
      size: $ROOTFS_BYTES
version: 2
EOF
fi

log "Regenerating md5sum.txt"
( cd "$ISO_DIR" && rm -f md5sum.txt && \
  find . -type f ! -name md5sum.txt -exec md5sum {} + | sort -k2 > md5sum.txt )

# ---------------------------------------------------------------- 6. build ISO
log "Building $OUTPUT_ISO"
mkdir -p "$(dirname "$OUTPUT_ISO")"
# Load the source ISO for its exact boot records, replay them, and overwrite the
# tree with our modified files. This preserves UEFI + BIOS boot without having
# to reconstruct El-Torito/GRUB by hand.
xorriso -indev "$SOURCE_ISO" \
        -outdev "$OUTPUT_ISO" \
        -boot_image any replay \
        -volid "$ISO_VOLID" \
        -overwrite on \
        -map "$ISO_DIR" / \
        -commit

log "Done: $OUTPUT_ISO"
log "Next: boot-test in QEMU (see README) under BOTH UEFI and BIOS."
