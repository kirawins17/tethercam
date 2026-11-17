#!/usr/bin/env bash
# Tethercam installer for Linux.
#   curl -fsSL https://raw.githubusercontent.com/kirawins17/tethercam/main/install.sh | bash
#
# It shows what it will install and asks before it starts.
# Supports apt (Ubuntu, Debian, Mint), dnf (Fedora), pacman (Arch) and zypper (openSUSE).
set -euo pipefail

REPO="kirawins17/tethercam"
DEST="${XDG_DATA_HOME:-$HOME/.local/share}/tethercam"

say()  { printf '%s\n' "$*"; }
step() { printf '\n\033[36m==> %s\033[0m\n' "$*"; }

if   command -v apt-get >/dev/null; then PM=apt
elif command -v dnf     >/dev/null; then PM=dnf
elif command -v pacman  >/dev/null; then PM=pacman
elif command -v zypper  >/dev/null; then PM=zypper
else say "Your package manager is not supported. See the README to install by hand."; exit 1
fi

case "$PM" in
  apt)    PKGS="python3 python3-venv python3-pip v4l2loopback-dkms usbmuxd libimobiledevice-utils adb libgl1 curl"
          INSTALL="sudo apt-get install -y" ;;
  dnf)    PKGS="python3 python3-pip v4l2loopback usbmuxd libimobiledevice-utils android-tools mesa-libGL curl"
          INSTALL="sudo dnf install -y" ;;
  pacman) PKGS="python python-pip v4l2loopback-dkms usbmuxd libimobiledevice android-tools mesa curl"
          INSTALL="sudo pacman -S --needed --noconfirm" ;;
  zypper) PKGS="python3 python3-pip v4l2loopback-kmp-default usbmuxd libimobiledevice-tools android-tools Mesa-libGL1 curl"
          INSTALL="sudo zypper install -y" ;;
esac

clear || true
say "Tethercam: use your phone as a webcam on this PC"
say ""
say "The installer will:"
say "  1. Install system packages with $PM (needs your password):"
say "       Python                 runs the Tethercam program"
say "       v4l2loopback           adds the virtual webcam that Discord and Zoom see"
say "       usbmuxd, libimobiledevice  lets the PC talk to an iPhone over the cable"
say "       adb                    lets the PC talk to an Android phone over the cable"
say "  2. Load the virtual webcam now and at every start-up (named \"tethercam\")."
say "  3. Put Tethercam in $DEST, with its own Python environment."
say "  4. Add Tethercam to your app menu."
say ""
say "Nothing is sent to the internet when you use Tethercam."
say ""
read -r -p "Press Enter to start, or type N to cancel: " ans </dev/tty || true
case "${ans:-}" in [Nn]*) say "Cancelled. Nothing was installed."; exit 0 ;; esac

step "System packages"
if [ "$PM" = apt ]; then sudo apt-get update -q; fi
# shellcheck disable=SC2086
if ! $INSTALL $PKGS; then
  say "Some packages could not be installed. On Fedora, v4l2loopback is in RPM Fusion."
  say "Install what is missing, then run this installer again."
  exit 1
fi

step "Virtual webcam (v4l2loopback)"
echo "v4l2loopback" | sudo tee /etc/modules-load.d/tethercam.conf >/dev/null
echo "options v4l2loopback devices=1 exclusive_caps=1 card_label=tethercam" \
  | sudo tee /etc/modprobe.d/tethercam.conf >/dev/null
sudo modprobe -r v4l2loopback 2>/dev/null || true
if sudo modprobe v4l2loopback devices=1 exclusive_caps=1 card_label=tethercam; then
  say "    Ready."
else
  say "    Could not load it now. Restart the PC once (with Secure Boot, you may need to enroll the module key)."
fi

step "Tethercam"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$DEST"
curl -fsSL "https://github.com/$REPO/archive/refs/heads/main.tar.gz" | tar xz -C "$TMP"
cp -r "$TMP/tethercam-main/pc/." "$DEST/"
chmod +x "$DEST/start-tethercam.sh"
python3 -m venv "$DEST/.venv"
"$DEST/.venv/bin/pip" install -q --disable-pip-version-check -r "$DEST/requirements.txt"
curl -fsSL -o "$DEST/Tethercam.ipa" "https://github.com/$REPO/releases/latest/download/Tethercam.ipa" \
  || say "    Could not download Tethercam.ipa. Get it from https://github.com/$REPO/releases"

mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/tethercam.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Tethercam
Comment=Use your phone as a webcam
Exec=$DEST/start-tethercam.sh
Terminal=true
Icon=camera-web
Categories=AudioVideo;Video;
DESKTOP
say "    Done. \"Tethercam\" is in your app menu."

say ""
say "The PC part is finished."
say ""
say "ANDROID (no app needed): Settings > About phone > tap Build number 7 times."
say "  Then Developer options > USB debugging > On. Plug in and tap Allow. Needs Android 12+."
say ""
say "IPHONE: the Tethercam app must be installed once. From Linux, use Sideloader"
say "  (https://github.com/Dadoum/Sideloader) with $DEST/Tethercam.ipa,"
say "  or use Sideloadly on any Windows PC or Mac. Then run: idevicepair pair"
say ""
say "TO USE IT: plug in the phone (iPhone: open the Tethercam app), then open Tethercam."
say "In Discord, Zoom or your browser, pick the camera named \"tethercam\"."
