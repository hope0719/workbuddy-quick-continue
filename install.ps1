# Quick Continue - Windows one-line installer
# Usage: irm https://raw.githubusercontent.com/hope0719/workbuddy-quick-continue/main/install.ps1 | iex
#   With floating button:  $button=$true; irm ... | iex

$ErrorActionPreference = "Stop"

# Check if button mode requested
$useButton = $false
if (Get-Variable button -Scope Global -ErrorAction SilentlyContinue) {
    $useButton = $Global:button
}

$Repo   = "hope0719/workbuddy-quick-continue"
$Branch = "main"
$Base   = "https://raw.githubusercontent.com/$Repo/$Branch"

$InstallDir  = Join-Path $env:LOCALAPPDATA "QuickContinue"
$ScriptFile  = Join-Path $InstallDir "quick_continue_win.py"
$LauncherFile = Join-Path $InstallDir "start.bat"
$SourceUrl   = "$Base/src/windows/quick_continue_win.py"
$StartupDir  = [Environment]::GetFolderPath("Startup")
$ShortcutPath = Join-Path $StartupDir "QuickContinue.lnk"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Quick Continue - Windows Installer" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1) Check Python
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
    $python = Get-Command python3 -ErrorAction SilentlyContinue
}
if (-not $python) {
    Write-Host "[X] Python not found." -ForegroundColor Red
    Write-Host "    Install from https://python.org" -ForegroundColor Yellow
    Write-Host "    Make sure to check 'Add Python to PATH'" -ForegroundColor Yellow
    exit 1
}
Write-Host "[OK] Python: $($python.Source)" -ForegroundColor Green

# 2) Create install directory
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}
Write-Host "[OK] Install dir: $InstallDir" -ForegroundColor Green

# 3) Download script
Write-Host "     Downloading..." -ForegroundColor Gray
try {
    Invoke-WebRequest -Uri $SourceUrl -OutFile $ScriptFile -UseBasicParsing
    Write-Host "[OK] Script downloaded." -ForegroundColor Green
} catch {
    Write-Host "[X] Download failed: $_" -ForegroundColor Red
    exit 1
}

# 4) Create launcher bat
$buttonArg = if ($useButton) { " --button" } else { "" }
$LauncherContent = @"
@echo off
start /min "" pythonw "$ScriptFile"$buttonArg
"@
Set-Content -Path $LauncherFile -Value $LauncherContent -Encoding ASCII
Write-Host "[OK] Launcher created." -ForegroundColor Green

# 5) Create startup shortcut
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath = $LauncherFile
$Shortcut.WindowStyle = 7  # Minimized
$Shortcut.Save()
Write-Host "[OK] Startup shortcut created." -ForegroundColor Green

# 6) Run now
Write-Host "     Starting service..." -ForegroundColor Gray
Start-Process -FilePath "python" -ArgumentList "pythonw `"$ScriptFile`"$buttonArg" -WindowStyle Hidden
Write-Host "[OK] Service started." -ForegroundColor Green

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  Installation complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Hotkey:  Alt+J"
if ($useButton) {
    Write-Host "  Button:  Floating button (bottom-right)" -ForegroundColor Yellow
}
Write-Host "  Action:  Type '继续' + Enter"
Write-Host ""
Write-Host "  The tool will start automatically on login."
Write-Host ""
Write-Host "  Commands:"
Write-Host "    Stop:      Task Manager > End 'python' task"
Write-Host "    Uninstall: irm $Base/uninstall.ps1 | iex"
Write-Host ""
if (-not $useButton) {
    Write-Host "  Tip: Add floating click button:" -ForegroundColor Gray
    Write-Host '    $button=$true; irm ... | iex' -ForegroundColor Gray
    Write-Host ""
}
