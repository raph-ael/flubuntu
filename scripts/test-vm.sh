#!/bin/bash
# Boot the built ISO in QEMU. Defaults to UEFI; pass --bios for legacy BIOS.
# Usage: ./scripts/test-vm.sh [--bios] [path-to.iso]
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/config/flubuntu.conf"

MODE="uefi"
ISO="$REPO_ROOT/$OUTPUT_ISO"
for a in "$@"; do
  case "$a" in
    --bios) MODE="bios" ;;
    *.iso)  ISO="$a" ;;
  esac
done
[ -f "$ISO" ] || { echo "ISO not found: $ISO (run sudo ./build.sh first)"; exit 1; }
command -v qemu-system-x86_64 >/dev/null || { echo "Install qemu-system-x86 + ovmf"; exit 1; }

ARGS=(-m 4096 -smp 2 -cdrom "$ISO" -boot d -vga virtio)
# KVM if available.
[ -w /dev/kvm ] && ARGS+=(-enable-kvm -cpu host)

if [ "$MODE" = "uefi" ]; then
  OVMF="$(ls /usr/share/OVMF/OVMF_CODE*.fd 2>/dev/null | head -n1 || true)"
  [ -n "$OVMF" ] || { echo "OVMF firmware not found. Install: apt install ovmf"; exit 1; }
  ARGS+=(-drive "if=pflash,format=raw,readonly=on,file=$OVMF")
  echo "Booting UEFI..."
else
  echo "Booting legacy BIOS..."
fi
exec qemu-system-x86_64 "${ARGS[@]}"
