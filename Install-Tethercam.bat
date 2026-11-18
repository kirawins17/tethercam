@echo off
REM Tethercam installer. Unzip the whole folder first, then double-click this file.
REM It runs install.ps1, which sits in the same folder. You can open both files to read them.
set "TETHERCAM_TAG="
if not exist "%~dp0install.ps1" (
  echo install.ps1 is missing. Unzip the whole Tethercam-Setup-Windows.zip first, then run this file from that folder.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
if errorlevel 1 (
  echo.
  echo The installer stopped because of the error above.
  pause
)
