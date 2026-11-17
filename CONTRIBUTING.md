# Contributing to tethercam

Thank you for your help. This guide tells you how to make a change.

## Before you start

- For a small fix, open a pull request.
- For a large change, open an issue first. Then we can agree on the plan.
- Issues with the `good first issue` label are a good start.

## Project parts

| Folder | What it is | Language |
|---|---|---|
| `pc/tethercam.py` | The main program. It finds the phone and sends the picture to the virtual webcam. | Python |
| `pc/iphone_source.py` | The iPhone link (Apple usbmux, JPEG frames). | Python |
| `pc/android_source.py` | The Android link (adb, scrcpy server, H.264). | Python |
| `ios/` | The iPhone app. It reads the camera and sends JPEG frames. | Swift |
| `install.ps1`, `install.sh` | The Windows and Linux installers. | PowerShell, Bash |
| `tests/` | Tests for `pc/`. They use a fake iPhone and a fake adb, so you do not need a real phone. | Python |

## Set up and test the PC part

```
python -m pip install -r pc/requirements.txt
python -m unittest discover -s tests -v
```

All tests must pass before you send a pull request.

## Build the iPhone app

You do not need a Mac. Push your branch to your fork. GitHub Actions builds `Tethercam.ipa` for you.
Download it from the **Actions** tab. Then install it with Sideloadly.

If you have a Mac: install [XcodeGen](https://github.com/yonaskolb/XcodeGen), run `xcodegen generate` in `ios/`, and open `Tethercam.xcodeproj`.

## Rules

- Keep changes small. Do one thing in each pull request.
- Write simple English in the docs. Use short sentences. Use one instruction in each step.
- Do not add analytics, tracking or network calls to the internet.
- The iPhone app must accept connections only from the USB cable (loopback). Do not change this.
- Do not put secrets, API keys or personal data in the code or in issues.
- If you change the scrcpy version, update `SCRCPY_VERSION` and `SERVER_SHA256` together in `pc/android_source.py`.
- Test on Windows and Linux when you can. Say in the pull request what you tested.

## Release (for maintainers)

1. Add the changes to `CHANGELOG.md` under a new version.
2. Change `MARKETING_VERSION` in `ios/project.yml`.
3. Go to **Actions › Build iPhone app › Run workflow** and type the tag (for example `v1.1.0`). Or publish a release on the Releases page.
4. GitHub Actions builds the app and attaches the files to the release.
