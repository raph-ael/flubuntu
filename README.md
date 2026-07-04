# Flubuntu

A shareable, **snap-free** remaster of **Ubuntu 26.04 LTS** (vanilla GNOME).
`snapd` is removed and permanently blocked; every snap-shipped program is
replaced by a **deb** or **Flatpak**:

| Ubuntu ships as snap | Flubuntu ships as |
|---|---|
| Firefox | Firefox **deb** (Mozilla APT repo, pinned) |
| Thunderbird | Thunderbird **deb** (Mozilla APT repo) |
| App Center (`snap-store`) | **GNOME Software** (+ Flatpak & deb plugins) |
| Firmware Updater | **fwupd** deb |
| Installer (`ubuntu-desktop-bootstrap`) | **Calamares** deb |
| misc GNOME apps | **Flatpak** from Flathub |

It stays on Ubuntu's standard repositories for system updates — this is a
remaster, not a from-scratch distribution.

## How it works

`build.sh` is "Cubic as code": it unpacks the official ISO, runs the `chroot/*.sh`
steps inside the rootfs (desnap → repos → replace → **installer** → brand → dock →
clean), repacks, and rebuilds a bootable ISO with `xorriso`.

**Installer:** Ubuntu 26.04's desktop installer (`ubuntu-desktop-bootstrap`) ships
**only as a classic snap**, so removing `snapd` removes the installer too. Flubuntu
replaces it with **Calamares** (deb, `chroot/25-installer.sh`), fully configured and
branded under `overlay/etc/calamares/`. A live-session launcher ("Install Flubuntu"
desktop icon + app-grid entry) runs it via `pkexec` (a polkit rule under
`overlay/etc/polkit-1/` lets the passwordless live user launch it); an autostart
script removes the dead snap-installer icon. Calamares installs the snap-free
`minimal.squashfs`, installs a GRUB **EFI + BIOS** bootloader, regenerates the
initramfs, and removes itself from the target — verified end-to-end (erase-disk
install → reboot → boots to GDM; the installed system has no `snapd`). Key config
choices that were needed for 26.04's Calamares (3.3.14):
- `partition.conf` uses an explicit `partitionLayout` (the default auto-layout
  created only an ESP);
- `mount.conf` is required (the bare `calamares` deb ships no default configs) and
  its `options` must be an **array** (`options: [ bind ]`) so `/dev` etc. reach the
  chroot for `grub-install`;
- the built-in `initramfs` module is dropped (it passes an unsupported `-t` to
  `update-initramfs`); the initramfs is regenerated from the `shellprocess` module.

**Desktop:** Ubuntu's built-in dock (`ubuntu-dock`, a Dash to Dock fork) is
reconfigured by default (`chroot/35-dock.sh`) from a full-height left panel that
intellihides behind windows into a **visible, floating, bottom-centered dock** —
via a `90_flubuntu-dock.gschema.override` that overrides Ubuntu's defaults under
the `:ubuntu` gsettings profile. No extra extension is installed; users can still
tweak it in Settings.

Ubuntu 26.04 ships a **layered** squashfs set in `casper/`. All the snap machinery
(`snapd`, the Firefox snap + its transitional deb, `snap-store`, `firmware-updater`,
`snapd-desktop-integration`) lives in the **self-contained base layer
`minimal.squashfs`** — which is also the *default* installer source
(`ubuntu-desktop-minimal`). Flubuntu therefore modifies **only that layer** and
rewrites `casper/install-sources.yaml` down to a single clean source, so every
install path is snap-free without having to deal with overlay whiteouts in the
thin `minimal.standard` diff layer (which is where the Thunderbird snap lived).

```
build.sh              orchestrator (run as root)
config/flubuntu.conf  version, ISO URL + SHA256, labels
chroot/               steps run INSIDE the chroot, in numeric order
overlay/              files copied verbatim into the rootfs (snap block,
                        Calamares config under etc/calamares, live launcher)
branding/             wallpaper + Plymouth theme (add your own)
scripts/test-vm.sh    boot the result in QEMU (UEFI + BIOS)
```

## Build

```bash
# 1. Host dependencies (on Ubuntu/Debian):
sudo apt install xorriso squashfs-tools wget rsync qemu-system-x86 ovmf

# 2. Set the ISO checksum:
#    edit config/flubuntu.conf -> SOURCE_ISO_SHA256 (from the official SHA256SUMS)

# 3. Build (needs root for mount/chroot; ~10 GB free disk, ~5 GB download):
sudo ./build.sh
# -> out/flubuntu-26.04-amd64.iso
```

## Verify (do this every build — the pipeline is not "done" until it passes)

```bash
./scripts/test-vm.sh          # UEFI boot
./scripts/test-vm.sh --bios   # legacy BIOS boot
```

In the live session:

1. `which snap` → nothing; `apt-cache policy snapd` → Pin-Priority **-10**.
2. Firefox & Thunderbird launch and are **deb** (no `/snap/` path;
   `apt-cache policy firefox` shows origin `packages.mozilla.org`).
3. GNOME Software opens and lists both deb and Flathub apps; a test Flatpak
   install succeeds.
4. Install to a VM disk, reboot, run `sudo apt update && sudo apt full-upgrade`,
   then re-check step 1 — **snapd must not come back.**

## Known validation points

- **Target layer.** `TARGET_SQUASHFS=casper/minimal.squashfs` (the self-contained
  base). The build asserts it is chrootable before proceeding.
- **`install-sources.yaml` rewrite.** Reduced to one source so the snap-laden
  "full" (`minimal.standard`) and `enhanced-secureboot` options can't be chosen.
  If a future ISO changes this schema, adjust the heredoc in `build.sh`.
- **snapd removal cascade.** `00-desnap.sh` purges `snapd` + the transitional
  `firefox` deb and prints anything still reverse-depending on snapd;
  `20-replace-apps.sh` then **fails loudly** if snapd got pulled back in.
- **EFI boot rebuild.** `xorriso ... -boot_image any replay` reuses the source
  ISO's boot records; confirm both QEMU boots reach GNOME.

## Not included (by scope)

Own APT repo / maintained update stream, Secure Boot signing (shim is shipped so
UEFI installs boot, but nothing is signed with a custom key), swap (the installer
defaults to no swap — a root-only layout).
