#!/bin/bash
# Runs INSIDE the chroot. Ship a visible, floating dock by default instead of
# Ubuntu's full-height left panel that intellihides behind windows.
#
# Ubuntu's built-in dock is `ubuntu-dock@ubuntu.com` (a Dash to Dock fork) using
# the org.gnome.shell.extensions.dash-to-dock schema. Ubuntu sets its defaults in
# 10_ubuntu-dock.gschema.override under the ":ubuntu" gsettings profile (the one
# the Ubuntu session activates): extend-height=true (full-height panel) and
# intellihide=true/ALL_WINDOWS (hides behind any window). We override those.
# The file sorts after 10_* so glib-compile-schemas lets our values win. We set
# both the :ubuntu profile (Ubuntu session) and the plain schema (vanilla GNOME).
set -euo pipefail

echo "==> [35-dock] Configuring a visible floating dock by default"

read -r -d '' DOCK_KEYS <<'EOF' || true
dock-position='BOTTOM'
extend-height=false
dock-fixed=true
autohide=false
intellihide=false
custom-theme-shrink=true
icon-size-fixed=true
dash-max-icon-size=48
transparency-mode='DYNAMIC'
running-indicator-style='DOTS'
show-apps-at-top=true
click-action='minimize-or-previews'
EOF

OVR=/usr/share/glib-2.0/schemas/90_flubuntu-dock.gschema.override
{
  echo "[org.gnome.shell.extensions.dash-to-dock:ubuntu]"
  echo "$DOCK_KEYS"
  echo
  echo "[org.gnome.shell.extensions.dash-to-dock]"
  echo "$DOCK_KEYS"
} > "$OVR"

# Recompile so the new defaults take effect. Fail loudly: an unknown key/value
# here would otherwise ship a broken schema cache.
glib-compile-schemas /usr/share/glib-2.0/schemas

echo "==> [35-dock] done"
