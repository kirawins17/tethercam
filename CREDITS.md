# Credits

Tethercam uses or learns from these projects. Thank you to everyone who made them.

## Ideas and design

| Project | By | What we took |
|---|---|---|
| [scrcpy](https://github.com/Genymobile/scrcpy) | Genymobile, Romain Vimont and contributors | The design: a small server on the phone, a USB tunnel, and a video socket. |
| [Scrcpy-Camera](https://github.com/xeniumcode/Scrcpy-Camera) | xeniumcode | The idea to control a phone camera as a webcam from Python. |
| [scrcpy-camera](https://github.com/NanKillBro/scrcpy-camera) | NanKillBro | The idea to bring a phone camera into OBS with the scrcpy protocol. |
| [scrcpy + OpenCamera + v4l2loopback gist](https://gist.github.com/cadadr/64df554935c6fd50aa45428b4e5e4a11) | cadadr | An early guide to an Android phone as a Linux webcam. |

## Software that Tethercam uses

| Project | License | How Tethercam uses it |
|---|---|---|
| [scrcpy server](https://github.com/Genymobile/scrcpy) | Apache-2.0 | Streams the Android camera. Downloaded from the official scrcpy release and checked by SHA-256. Not included in this repo. |
| [pyvirtualcam](https://github.com/letmaik/pyvirtualcam) | GPL-2.0 | Sends the picture to the virtual webcam. Installed with pip. |
| [PyAV](https://github.com/PyAV-Org/PyAV) | BSD-3-Clause | Decodes the Android H.264 video. Installed with pip. |
| [OpenCV](https://github.com/opencv/opencv-python) | Apache-2.0 | Decodes iPhone JPEG frames, resizes and rotates. Installed with pip. |
| [NumPy](https://github.com/numpy/numpy) | BSD-3-Clause | Image buffers. Installed with pip. |
| [OBS Studio](https://github.com/obsproject/obs-studio) | GPL-2.0 | Provides "OBS Virtual Camera" on Windows. Installed separately. |
| [v4l2loopback](https://github.com/umlaeute/v4l2loopback) | GPL-2.0 | Provides the virtual webcam on Linux. Installed separately. |
| [libimobiledevice / usbmuxd](https://github.com/libimobiledevice) | LGPL-2.1 / GPL | The iPhone USB link on Linux, and the documentation of the usbmux protocol. Installed separately. |
| [Android platform-tools (adb)](https://developer.android.com/tools/releases/platform-tools) | Android SDK license terms | The Android USB link. Installed separately. |
| [XcodeGen](https://github.com/yonaskolb/XcodeGen) | MIT | Builds the iPhone app project in CI. |
| [Sideloadly](https://sideloadly.io/) and [Sideloader](https://github.com/Dadoum/Sideloader) | See their sites | Install the iPhone app without the App Store. Installed separately. |

## License notes

- Tethercam's own code is under the [MIT license](LICENSE). The projects above keep their own licenses.
- Tethercam does not include their code in this repository. The installers download them from their official sources.
- **pyvirtualcam is GPL-2.0.** Tethercam imports it at run time. If you share a package that bundles Tethercam together with pyvirtualcam (for example a single .exe), that combined package must follow the GPL-2.0. Using Tethercam, or sharing its source code, is not affected.
- **scrcpy server is Apache-2.0.** Tethercam does not redistribute it. Each PC downloads the official file from the scrcpy release page.

This page is information, not legal advice.

iPhone is a trademark of Apple Inc. Android is a trademark of Google LLC. Tethercam is not made by or connected with Apple or Google.
