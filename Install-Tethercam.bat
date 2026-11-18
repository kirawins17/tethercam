@echo off
REM Tethercam installer. Double-click this file.
REM The copy attached to a release installs exactly that release.
set "TETHERCAM_TAG="
set "TETHERCAM_PS1=https://raw.githubusercontent.com/kirawins17/tethercam/main/install.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm $env:TETHERCAM_PS1 | iex"
if errorlevel 1 (
  echo.
  echo The installer stopped because of the error above.
  pause
)
