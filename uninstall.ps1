# Quick Continue - Windows uninstaller
# Usage: irm https://raw.githubusercontent.com/hope0719/quick-continue/main/uninstall.ps1 | iex

$InstallDir   = Join-Path $env:LOCALAPPDATA "QuickContinue"
$StartupDir   = [Environment]::GetFolderPath("Startup")
$ShortcutPath = Join-Path $StartupDir "QuickContinue.lnk"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Quick Continue - Uninstaller" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1) Stop running process
$procs = Get-Process -Name python, pythonw -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowTitle -eq "" }
if ($procs) {
    $procs | Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Host "[OK] Service stopped." -ForegroundColor Green
} else {
    Write-Host "[--] Service not running." -ForegroundColor Yellow
}

# 2) Remove startup shortcut
if (Test-Path $ShortcutPath) {
    Remove-Item $ShortcutPath -Force
    Write-Host "[OK] Startup shortcut removed." -ForegroundColor Green
}

# 3) Remove install directory
if (Test-Path $InstallDir) {
    Remove-Item $InstallDir -Recurse -Force
    Write-Host "[OK] Application removed." -ForegroundColor Green
}

Write-Host ""
Write-Host "  Uninstalled successfully." -ForegroundColor Green
Write-Host ""
