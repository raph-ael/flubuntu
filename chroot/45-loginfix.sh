#!/bin/bash
# Runs INSIDE the chroot. Wire up the /tmp/.X11-unix login fix so the installed
# system doesn't get stuck in a GDM login loop (see flubuntu-fix-x11-unix for the
# full explanation). The helper script itself is delivered via overlay/.
set -euo pipefail

echo "==> [45-loginfix] Installing GDM /tmp/.X11-unix ownership fix"

chmod 0755 /usr/local/bin/flubuntu-fix-x11-unix

# Append a pam_exec session hook to gdm-password (idempotent). GDM's legacy
# PostLogin/PreSession scripts are NOT honoured on Ubuntu, so PAM is the reliable
# place to run this right before the user session starts.
PAM=/etc/pam.d/gdm-password
LINE="session    optional    pam_exec.so /usr/local/bin/flubuntu-fix-x11-unix"
if [ -f "$PAM" ]; then
  if ! grep -q 'flubuntu-fix-x11-unix' "$PAM"; then
    printf '\n# Flubuntu: re-assert root ownership of /tmp/.X11-unix before the session.\n%s\n' "$LINE" >> "$PAM"
    echo "==> [45-loginfix] pam_exec hook added to $PAM"
  else
    echo "==> [45-loginfix] pam_exec hook already present"
  fi
else
  echo "!! [45-loginfix] $PAM missing — cannot install login fix" >&2
  exit 1
fi

echo "==> [45-loginfix] done"
