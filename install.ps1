# Tethercam installer for Windows.
#
# Easiest way: download "Install-Tethercam.bat" from the Releases page and double-click it.
# Or run this in PowerShell:
#   irm https://raw.githubusercontent.com/kirawins17/tethercam/main/install.ps1 | iex
#
# It asks which phone you have, shows what it will install, and asks before it starts.

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$repo = 'kirawins17/tethercam'
$dest = Join-Path $env:LOCALAPPDATA 'tethercam'

function Say($text, $color = 'White') { Write-Host $text -ForegroundColor $color }
function Step($text) { Say "`n==> $text" 'Cyan' }

function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
}

function Find-Python {
    # Returns the full path of a real python.exe (3.9+), or $null.
    # Skips the Microsoft Store "python" stub, and looks where python.org puts it.
    $probe = 'import sys; print(sys.executable) if sys.version_info >= (3, 9) else None'
    foreach ($cmd in 'py -3', 'python', 'python3') {
        $exe, $rest = $cmd -split ' '
        $pre = @($rest | Where-Object { $_ })
        if (-not (Get-Command $exe -ErrorAction SilentlyContinue)) { continue }
        try {
            $out = (& $exe @pre -c $probe 2>$null | Select-Object -First 1)
            if ($LASTEXITCODE -eq 0 -and $out -and (Test-Path $out.Trim())) { return $out.Trim() }
        } catch { }
    }
    $found = Get-ChildItem "$env:LOCALAPPDATA\Programs\Python\Python3*\python.exe", "$env:ProgramFiles\Python3*\python.exe" -ErrorAction SilentlyContinue |
             Sort-Object FullName -Descending | Select-Object -First 1
    if ($found) { return $found.FullName }
    return $null
}

function Has-Python { return [bool](Find-Python) }

function Has-Obs {
    return [bool](@("$env:ProgramFiles\obs-studio", "${env:ProgramFiles(x86)}\obs-studio") |
                  Where-Object { Test-Path $_ })
}

function Has-AppleUsb {
    return [bool](Get-Service -Name 'Apple Mobile Device Service' -ErrorAction SilentlyContinue)
}

function Has-Adb {
    if (Get-Command adb -ErrorAction SilentlyContinue) { return $true }
    return Test-Path "$env:LOCALAPPDATA\Microsoft\WinGet\Links\adb.exe"
}

function Find-Sideloadly {
    $paths = @("$env:ProgramFiles\Sideloadly\sideloadly.exe",
               "${env:ProgramFiles(x86)}\Sideloadly\sideloadly.exe",
               "$env:LOCALAPPDATA\Sideloadly\sideloadly.exe")
    return $paths | Where-Object { Test-Path $_ } | Select-Object -First 1
}

function Winget-Install($id, $name, $link) {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install -e --id $id --silent --accept-source-agreements --accept-package-agreements
        $code = $LASTEXITCODE
        Refresh-Path
        if ($code -eq 0) { Say "    $name installed." 'Green'; return }
    }
    Say "    Could not install $name automatically. Opening the download page..." 'Yellow'
    Start-Process $link
    Read-Host "    Install $name, then press Enter to continue"
    Refresh-Path
}

# ---------------------------------------------------------------------------
Clear-Host
Say 'Tethercam: use your phone as a webcam on this PC' 'Green'
Say ''
Say 'Which phone do you have?'
Say '  1 = iPhone'
Say '  2 = Android'
Say '  3 = both'
$pick = Read-Host 'Type 1, 2 or 3 and press Enter'
$wantIphone = $pick -match '^[13]'
$wantAndroid = $pick -match '^[23]'
if (-not ($wantIphone -or $wantAndroid)) { Say 'Please run the installer again and type 1, 2 or 3.'; return }

$items = @(
    @{ Name = 'Python';      Need = -not (Has-Python); Why = 'runs the Tethercam program' },
    @{ Name = 'OBS Studio';  Need = -not (Has-Obs);    Why = 'adds the "OBS Virtual Camera" that Discord and Zoom see' }
)
if ($wantIphone) {
    $items += @{ Name = 'iTunes';     Need = -not (Has-AppleUsb);    Why = 'lets the PC talk to an iPhone over the cable' }
    $items += @{ Name = 'Sideloadly'; Need = -not (Find-Sideloadly); Why = 'puts the Tethercam app on your iPhone (one time)' }
}
if ($wantAndroid) {
    $items += @{ Name = 'Android tools (adb)'; Need = -not (Has-Adb); Why = 'lets the PC talk to an Android phone over the cable' }
}
$items += @{ Name = 'Tethercam'; Need = $true; Why = 'the program and a desktop shortcut' }

Say ''
Say 'The installer gets these for you. It skips what you already have:'
Say ''
foreach ($i in $items) {
    $state = if ($i.Need) { 'will install' } else { 'already installed' }
    Say ("  {0,-20} {1,-18} {2}" -f $i.Name, "($state)", $i.Why)
}
Say ''
Say "Tethercam goes in $dest"
Say 'Using Tethercam sends nothing to the internet. (Android: it downloads the scrcpy server from GitHub one time.)'
Say ''
$answer = Read-Host 'Press Enter to start, or type N to cancel'
if ($answer -match '^[Nn]') { Say 'Cancelled. Nothing was installed.'; return }

# ---------------------------------------------------------------------------
Step 'Python'
if (Has-Python) { Say '    Already installed.' 'Green' }
else {
    Winget-Install 'Python.Python.3.12' 'Python' 'https://www.python.org/downloads/'
    if (-not (Has-Python)) { throw 'Python is still missing. Install it from python.org, then run this installer again.' }
}
$py = Find-Python
Say "    Using $py"


Step 'OBS Studio (virtual webcam)'
if (Has-Obs) { Say '    Already installed.' 'Green' }
else { Winget-Install 'OBSProject.OBSStudio' 'OBS Studio' 'https://obsproject.com/' }

if ($wantIphone) {
    Step 'iTunes (Apple USB drivers)'
    if (Has-AppleUsb) { Say '    Already installed.' 'Green' }
    else { Winget-Install 'Apple.iTunes' 'iTunes' 'https://www.apple.com/itunes/' }

    Step 'Sideloadly (installs the app on your iPhone)'
    if (Find-Sideloadly) { Say '    Already installed.' 'Green' }
    else {
        $setup = Join-Path $env:TEMP 'SideloadlySetup64.exe'
        try {
            Invoke-WebRequest -UseBasicParsing 'https://sideloadly.io/SideloadlySetup64.exe' -OutFile $setup
            $sig = Get-AuthenticodeSignature $setup
            $run = $true
            if ($sig.Status -eq 'Valid') {
                Say "    Signature OK: $($sig.SignerCertificate.Subject)" 'Green'
            } else {
                Say "    Warning: the Sideloadly installer is not signed in a way Windows can check ($($sig.Status))." 'Yellow'
                Say '    It was downloaded from https://sideloadly.io/ over HTTPS.' 'Yellow'
                $run = (Read-Host '    Run it anyway? Type Y to run, or press Enter to skip') -match '^[Yy]'
            }
            if ($run) {
                Say '    Opening the Sideloadly installer. Click through it, then come back here.'
                Start-Process $setup -Wait
            } else {
                Say '    Skipped. You can install Sideloadly later from https://sideloadly.io/' 'Yellow'
            }
            Remove-Item $setup -ErrorAction SilentlyContinue
        } catch {
            Say '    Could not download Sideloadly. Opening its website...' 'Yellow'
            Start-Process 'https://sideloadly.io/'
            Read-Host '    Install Sideloadly, then press Enter to continue'
        }
    }
}

if ($wantAndroid) {
    Step 'Android tools (adb)'
    if (Has-Adb) { Say '    Already installed.' 'Green' }
    else { Winget-Install 'Google.PlatformTools' 'Android platform-tools' 'https://developer.android.com/tools/releases/platform-tools' }
}

Step 'Tethercam'
# Install one release, so the PC part matches the iPhone app.
# The installer attached to a release sets TETHERCAM_TAG to that release.
$tag = $env:TETHERCAM_TAG
if (-not $tag) {
    try { $tag = (Invoke-RestMethod -UseBasicParsing "https://api.github.com/repos/$repo/releases/latest").tag_name } catch { }
}
if ($tag) {
    $zipUrl = "https://github.com/$repo/archive/refs/tags/$tag.zip"
    $ipaUrl = "https://github.com/$repo/releases/download/$tag/Tethercam.ipa"
    Say "    Version $tag"
} else {
    $zipUrl = "https://github.com/$repo/archive/refs/heads/main.zip"
    $ipaUrl = "https://github.com/$repo/releases/latest/download/Tethercam.ipa"
}
$tmp = Join-Path $env:TEMP ('tethercam-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp, $dest -Force | Out-Null
Invoke-WebRequest -UseBasicParsing $zipUrl -OutFile "$tmp\src.zip"
Expand-Archive "$tmp\src.zip" -DestinationPath $tmp -Force
$src = Get-ChildItem $tmp -Directory | Select-Object -First 1
Copy-Item "$($src.FullName)\pc\*" $dest -Recurse -Force
Remove-Item $tmp -Recurse -Force
& $py -m pip install -q --disable-pip-version-check -r "$dest\requirements.txt"
if ($LASTEXITCODE -ne 0) { throw 'Could not install the Python packages. Check your internet and run the installer again.' }
if ($wantIphone) {
    try {
        Invoke-WebRequest -UseBasicParsing $ipaUrl -OutFile "$dest\Tethercam.ipa"
    } catch {
        Say "    Could not download Tethercam.ipa. Get it from https://github.com/$repo/releases" 'Yellow'
    }
}
# Launcher that uses the exact Python found above.
Set-Content -Path "$dest\start-tethercam.bat" -Encoding ASCII -Value @(
    '@echo off',
    'REM Starts Tethercam. Made by the installer.',
    'cd /d "%~dp0"',
    "`"$py`" tethercam.py %*",
    'pause'
)
$shell = New-Object -ComObject WScript.Shell
$link = $shell.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) 'Tethercam.lnk'))
$link.TargetPath = "$dest\start-tethercam.bat"
$link.WorkingDirectory = $dest
$link.Description = 'Use your phone as a webcam'
$link.Save()
Say '    Done. "Tethercam" is on your desktop.' 'Green'

# ---------------------------------------------------------------------------
Say "`nThe PC part is finished." 'Green'
if ($wantIphone) {
    Say ''
    Say 'IPHONE: put the app on it (one time)' 'Cyan'
    Say '  1. Plug your iPhone into this PC. Unlock it. Tap Trust.'
    Say '  2. In Sideloadly (opening now), drag in Tethercam.ipa from the folder that opens.'
    Say '     Type your Apple ID and click Start.'
    Say '  3. On the iPhone: Settings > General > VPN & Device Management > your Apple ID > Trust.'
    Say '  4. On the iPhone: Settings > Privacy & Security > Developer Mode > On. It restarts.'
}
if ($wantAndroid) {
    Say ''
    Say 'ANDROID: turn on USB debugging (one time, no app needed)' 'Cyan'
    Say '  1. Settings > About phone > tap "Build number" 7 times.'
    Say '  2. Settings > System > Developer options > USB debugging > On.'
    Say '  3. Plug the phone into this PC and tap Allow.'
    Say '  Needs Android 12 or newer.'
}
Say ''
Say 'TO USE IT: plug in the phone (iPhone: open the Tethercam app), then double-click Tethercam on your desktop.'
Say 'In Discord: Settings > Voice & Video > Camera > OBS Virtual Camera.'
Say ''
if ($wantIphone) {
    Start-Process explorer.exe $dest
    $sl = Find-Sideloadly
    if ($sl) { Start-Process $sl }
}
Read-Host 'Press Enter to close'
