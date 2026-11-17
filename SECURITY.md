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
- The only download while you use it: for Android, the scrcpy server from its official GitHub release, one time.
- The installer downloads only from `github.com/kirawins17/tethercam` and from the official sites of the tools it installs (on Windows: Python, OBS Studio, iTunes and adb with `winget`, Sideloadly from sideloadly.io; on Linux: your distribution's package manager). It shows the list and asks before it installs anything.

## Check a download

Every release has a `SHA256SUMS.txt` file. To check a file on Windows (PowerShell):

```powershell
Get-FileHash .\Tethercam.ipa -Algorithm SHA256
```

On Linux:

```sh
sha256sum -c SHA256SUMS.txt --ignore-missing
```

The result must be the same as the line in `SHA256SUMS.txt`.

Public releases also have signed build provenance. It proves that GitHub Actions built the file from this repository. With the [GitHub CLI](https://cli.github.com/):

```sh
gh attestation verify Tethercam.ipa --repo kirawins17/tethercam
```

## Supported versions

We fix security problems in the latest release only. Please update before you report a problem.

## How we protect the project

- All GitHub Actions are pinned to a full commit SHA. Workflow tokens are read-only by default.
- Dependabot checks the Actions and Python packages every month.
- CodeQL scans the code, and OpenSSF Scorecard checks the project setup.
