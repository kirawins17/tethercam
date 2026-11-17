@echo off
REM Double-click to start tethercam. The first run installs the Python packages.
cd /d "%~dp0"
python -m pip install -q --disable-pip-version-check -r requirements.txt
python tethercam.py %*
pause
