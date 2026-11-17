# Changelog

All important changes are in this file. The format follows [Keep a Changelog](https://keepachangelog.com/).

## [1.1.0] - 2026-11-17

### Added
- Android support (Android 12 or newer). No app is needed on the phone: Tethercam uses the scrcpy server, checked by SHA-256.
- Linux support: one-command installer (`install.sh`) for apt, dnf, pacman and zypper. The webcam is named "tethercam".
- The program finds the plugged-in phone by itself (`--phone auto`).
- `--camera front` for Android.
- The Windows installer asks which phone you have and installs only what that phone needs.
- CREDITS.md with all projects and licenses.

### Changed
- `--udid` is now `--device` and works for both phone types.

## [1.0.0] - 2026-11-17

### Added
- iPhone app that sends the camera over the USB cable.
- Windows program that makes the iPhone a webcam (OBS Virtual Camera).
- Works with Discord, Zoom, Teams, OBS and other webcam apps.
- Switch between the front and back camera in the app.
- Options: rotate, mirror, size, preview.
- One-file installer for Windows (`Install-Tethercam.bat`). It installs Python, OBS Studio, iTunes and Sideloadly, and adds a desktop shortcut.
- Automatic build of the iPhone app (`Tethercam.ipa`). No Mac is necessary.

### Security
- The iPhone app accepts connections only from the USB cable, not from Wi-Fi.
