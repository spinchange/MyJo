# Install-QuickAdd.ps1
# Creates Desktop shortcuts for MyJo quick access.
#
#   Ctrl+Alt+A  →  Quick Add popup (type an entry from anywhere)
#   Ctrl+Alt+M  →  MyJo interactive menu (opens in PowerShell)

$wsh = New-Object -ComObject WScript.Shell
$desktop = [Environment]::GetFolderPath("Desktop")

# Quick Add popup (Ctrl+Alt+A)
$quickAddScript = Join-Path $PSScriptRoot "QuickAdd.ps1"
$shortcut = $wsh.CreateShortcut((Join-Path $desktop "MyJo Quick Add.lnk"))
$shortcut.TargetPath = "powershell.exe"
$shortcut.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -NonInteractive -File `"$quickAddScript`""
$shortcut.WorkingDirectory = $PSScriptRoot
$shortcut.WindowStyle = 1
$shortcut.Hotkey = "Ctrl+Alt+A"
$shortcut.Description = "MyJo Quick Add"
$shortcut.Save()
Write-Host "Shortcut created: MyJo Quick Add  (Ctrl+Alt+A)" -ForegroundColor Green

# Interactive menu (Ctrl+Alt+M)
$journalScript = Join-Path $PSScriptRoot "Journal.ps1"
$shortcut = $wsh.CreateShortcut((Join-Path $desktop "MyJo Menu.lnk"))
$shortcut.TargetPath = "powershell.exe"
$shortcut.Arguments = "-ExecutionPolicy Bypass -NoProfile -File `"$journalScript`""
$shortcut.WorkingDirectory = $PSScriptRoot
$shortcut.WindowStyle = 1
$shortcut.Hotkey = "Ctrl+Alt+M"
$shortcut.Description = "MyJo Menu"
$shortcut.Save()
Write-Host "Shortcut created: MyJo Menu        (Ctrl+Alt+M)" -ForegroundColor Green

Write-Host ""
Write-Host "Note: Shortcuts must remain on the Desktop for hotkeys to work." -ForegroundColor Yellow
