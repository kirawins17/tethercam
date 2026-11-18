# Changelog

All important changes are in this file. The format follows [Keep a Changelog](https://keepachangelog.com/), and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Every new issue gets a welcome reply within a minute, with the most common fixes and what to include.

## [1.4.0] - 2026-11-18

The first release since the repository became public. Its files have signed build provenance.

### Added
- New images in the README: hero, setup steps, iPhone vs Android, and how it works. Each has a dark and a light version that follows your GitHub theme.
- New social preview card.
- The README says the iPhone app needs iOS 15 or newer.

### Changed
- GitHub Actions updated to the latest versions (checkout v7, setup-python v7, upload-artifact v7, download-artifact v8, action-gh-release v3). They passed a full release dry run.
- OpenCV 5 is now allowed (`opencv-python>=4.8,<6`).
- Dependabot only proposes Python updates when a new version is outside the allowed range.

### Removed
- The old animated demo GIF.

## [1.3.0] - 2026-11-18

### Fixed
- Ctrl+C now always stops Tethercam cleanly, also while it waits for a phone.
- iPhone app: if iOS closes the connection point in the background, the app opens it again. You do not need to restart the app.
- Android: when you unplug the phone, Tethercam reconnects at once (no 20-second wait).
- Linux: if the virtual webcam package is missing (for example on Fedora without RPM Fusion), the installer explains how to get it and installs the rest.

### Security
- `Install-Tethercam.bat` and `install.sh` attached to a release are pinned to that release, and `install.ps1` is now a checked release file too.
- The Windows installer checks the signature of the Sideloadly installer before it runs it.

### Changed
- Releases run as a dry run on pull requests, so a broken update is found before it is merged.
- The README says that the iPhone app sends 1280 × 720.

## [1.2.0] - 2026-11-17

### Added
- Each release has `SHA256SUMS.txt` and signed build provenance, so you can check the files.
- CodeQL code scanning, OpenSSF Scorecard and Dependabot.
- Code of Conduct, SUPPORT.md, FAQ and Roadmap in the README.
- Legal notes: trademarks, the pyvirtualcam GPL-2.0 note, and "ask before you record people".
- `--version` option.
- Uninstall steps in the README.

### Changed
- All GitHub Actions are pinned to a full commit SHA.
- `install.sh` is attached to each release.
- The installers install the code of the latest release, so the PC part always matches the iPhone app.
- iPhone app ID is now `io.github.kirawins17.tethercam`. If you installed an older build, delete the old app.

### Fixed
- Windows installer: the window stays open when there is an error.
- Windows installer: works on PCs without Internet Explorer, and finds Python in more places.
- Android: adb picks a free port, slow cameras get 15 seconds to start, and the server stops cleanly.
- Linux: the camera name shown is "tethercam".

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

[Unreleased]: https://github.com/kirawins17/tethercam/compare/v1.4.0...HEAD
[1.4.0]: https://github.com/kirawins17/tethercam/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/kirawins17/tethercam/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/kirawins17/tethercam/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/kirawins17/tethercam/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/kirawins17/tethercam/releases/tag/v1.0.0
