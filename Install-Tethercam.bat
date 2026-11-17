@echo off
REM Tethercam installer. Double-click this file.
REM It downloads and runs install.ps1 from github.com/kirawins17/tethercam
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/kirawins17/tethercam/main/install.ps1 | iex"
