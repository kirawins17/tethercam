# Security

## Report a problem

Do not open a public issue for a security problem.
Use **[Report a vulnerability](https://github.com/kirawins17/tethercam/security/advisories/new)**. Only the maintainer can see the report.
We reply in 3 days or less.

## Security design

- The iPhone app listens only on loopback (`127.0.0.1`). Only the USB cable (Apple usbmux) can reach it. Other devices on Wi-Fi cannot.
- The app also refuses all connections that are not from loopback.
- The PC program connects only to the local Apple USB service (`127.0.0.1:27015`).
- The PC program refuses frames larger than 20 MB.
- Android: Tethercam uses the official scrcpy server. It checks the download against a fixed SHA-256 and refuses any other file.
  The server runs only while you stream and removes itself when it stops. The adb tunnel listens only on `127.0.0.1`.
- Tethercam sends no data to the internet. It has no accounts, analytics or tracking.
- The installer downloads only from `github.com/kirawins17/tethercam` and from the official sites of the tools it installs (on Windows: Python, OBS Studio, iTunes and adb with `winget`, Sideloadly from sideloadly.io; on Linux: your distribution's package manager). It shows the list and asks before it installs anything.
