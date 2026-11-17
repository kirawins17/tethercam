# Tethercam installer for Windows.
#
# Easiest way: download "Install-Tethercam.bat" from the Releases page and double-click it.
# Or run this in PowerShell:
#   irm https://raw.githubusercontent.com/kirawins17/tethercam/main/install.ps1 | iex
#
# It shows you what it will install and asks before it starts.

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$repo = 'kirawins17/tethercam'
$dest = Join-Path $env:LOCALAPPDATA 'tethercam'

function Say($text, $color = 'White') { Write-Host $text -ForegroundColor $color }
function Step($n, $text) { Say "`n[$n/6] $text" 'Cyan' }

function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
}

function Has-Python {
    try { & python --version *> $null; return $LASTEXITCODE -eq 0 } catch { return $false }
}

function Has-Obs {
    return [bool](@("$env:ProgramFiles\obs-studio", "${env:ProgramFiles(x86)}\obs-studio") |
                  Where-Object { Test-Path $_ })
}

function Has-AppleUsb {
    return [bool](Get-Service -Name 'Apple Mobile Device Service' -ErrorAction SilentlyContinue)
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
        Refresh-Path
        if ($LASTEXITCODE -eq 0) { Say "    $name installed." 'Green'; return }
    }
    Say "    Could not install $name automatically. Opening the download page..." 'Yellow'
    Start-Process $link
    Read-Host "    Install $name, then press Enter to continue"
    Refresh-Path
}

# ---------------------------------------------------------------------------
Clear-Host
Say 'Tethercam: use your iPhone as a webcam on this PC' 'Green'
Say ''
Say 'This installer gets everything for you. Each item and what it does:'
Say ''
$items = @(
    @{ Name = 'Python';     Need = -not (Has-Python);       Why = 'runs the Tethercam program' },
    @{ Name = 'OBS Studio'; Need = -not (Has-Obs);          Why = 'adds the "OBS Virtual Camera" that Discord and Zoom see' },
    @{ Name = 'iTunes';     Need = -not (Has-AppleUsb);     Why = 'lets the PC talk to your iPhone over the cable' },
    @{ Name = 'Sideloadly'; Need = -not (Find-Sideloadly);  Why = 'puts the Tethercam app on your iPhone (one time)' },
    @{ Name = 'Tethercam';  Need = $true;                   Why = 'the program + the iPhone app file, plus a desktop shortcut' }
)
foreach ($i in $items) {
    $state = if ($i.Need) { 'will install' } else { 'already installed' }
    Say ("  {0,-11} {1,-18} {2}" -f $i.Name, "($state)", $i.Why)
}
Say ''
Say "Everything goes in normal locations. Tethercam itself goes in $dest"
Say 'Nothing is sent to the internet when you use Tethercam.'
Say ''
$answer = Read-Host 'Press Enter to start, or type N to cancel'
if ($answer -match '^[Nn]') { Say 'Cancelled. Nothing was installed.'; return }

# ---------------------------------------------------------------------------
Step 1 'Python'
if (Has-Python) { Say '    Already installed.' 'Green' }
else {
    Winget-Install 'Python.Python.3.12' 'Python' 'https://www.python.org/downloads/'
    if (-not (Has-Python)) { throw 'Python is still missing. Install it, then run this installer again.' }
}

Step 2 'OBS Studio (virtual webcam)'
if (Has-Obs) { Say '    Already installed.' 'Green' }
else { Winget-Install 'OBSProject.OBSStudio' 'OBS Studio' 'https://obsproject.com/' }

Step 3 'iTunes (Apple USB drivers)'
if (Has-AppleUsb) { Say '    Already installed.' 'Green' }
else { Winget-Install 'Apple.iTunes' 'iTunes' 'https://www.apple.com/itunes/' }

Step 4 'Sideloadly (installs the app on your iPhone)'
if (Find-Sideloadly) { Say '    Already installed.' 'Green' }
else {
    $setup = Join-Path $env:TEMP 'SideloadlySetup64.exe'
    try {
        Invoke-WebRequest 'https://sideloadly.io/SideloadlySetup64.exe' -OutFile $setup
        Say '    Opening the Sideloadly installer. Click through it, then come back here.'
        Start-Process $setup -Wait
        Remove-Item $setup -ErrorAction SilentlyContinue
    } catch {
        Say '    Could not download Sideloadly. Opening its website...' 'Yellow'
        Start-Process 'https://sideloadly.io/'
        Read-Host '    Install Sideloadly, then press Enter to continue'
    }
}

Step 5 'Tethercam'
$tmp = Join-Path $env:TEMP ('tethercam-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp, $dest -Force | Out-Null
Invoke-WebRequest "https://github.com/$repo/archive/refs/heads/main.zip" -OutFile "$tmp\src.zip"
Expand-Archive "$tmp\src.zip" -DestinationPath $tmp -Force
Copy-Item "$tmp\tethercam-main\pc\*" $dest -Recurse -Force
Remove-Item $tmp -Recurse -Force
& python -m pip install -q --disable-pip-version-check -r "$dest\requirements.txt"
if ($LASTEXITCODE -ne 0) { throw 'Could not install the Python packages. Check your internet and run the installer again.' }
try {
    Invoke-WebRequest "https://github.com/$repo/releases/latest/download/Tethercam.ipa" -OutFile "$dest\Tethercam.ipa"
} catch {
    Say "    Could not download Tethercam.ipa. Get it from https://github.com/$repo/releases" 'Yellow'
}
Say '    Done.' 'Green'

Step 6 'Desktop shortcut'
$shell = New-Object -ComObject WScript.Shell
$link = $shell.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) 'Tethercam.lnk'))
$link.TargetPath = "$dest\start-tethercam.bat"
$link.WorkingDirectory = $dest
$link.Description = 'Use your iPhone as a webcam'
$link.Save()
Say '    "Tethercam" is on your desktop.' 'Green'

# ---------------------------------------------------------------------------
Say "`nThe PC part is finished." 'Green'
Say ''
Say 'LAST STEP: put the app on your iPhone (one time)' 'Cyan'
Say '  1. Plug your iPhone into this PC. Unlock it. Tap Trust.'
Say '  2. In Sideloadly (opening now), drag in Tethercam.ipa from the folder that opens.'
Say '     Type your Apple ID and click Start.'
Say '  3. On the iPhone: Settings > General > VPN & Device Management > tap your Apple ID > Trust.'
Say '  4. On the iPhone: Settings > Privacy & Security > Developer Mode > On. It restarts.'
Say ''
Say 'TO USE IT: open the Tethercam app on the iPhone, then double-click Tethercam on your desktop.'
Say 'In Discord: Settings > Voice & Video > Camera > OBS Virtual Camera.'
Say ''
Start-Process explorer.exe $dest
$sl = Find-Sideloadly
if ($sl) { Start-Process $sl }
Read-Host 'Press Enter to close'
