# Branding assets

Drop your Flubuntu artwork here. `build.sh` stages these into the rootfs:

```
branding/
├── backgrounds/
│   └── flubuntu.png          -> /usr/share/backgrounds/flubuntu.png
└── plymouth/                 -> /usr/share/plymouth/themes/flubuntu/
    ├── flubuntu.plymouth
    └── ...theme files...
```

The GNOME background and favourites are wired to `flubuntu.png` in
`chroot/30-branding.sh`. If you rename the image, update that script too.

Placeholder — no assets committed yet. Until you add `backgrounds/flubuntu.png`
the desktop keeps Ubuntu's default wallpaper (harmless).
