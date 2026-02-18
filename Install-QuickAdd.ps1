# Install-QuickAdd.ps1
# Creates a Desktop shortcut for the MyJo Quick Add popup (Ctrl+Alt+A).

$scriptPath = Join-Path $PSScriptRoot "QuickAdd.ps1"
$shortcutPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "MyJo Quick Add.lnk"

$wsh = New-Object -ComObject WScript.Shell
$shortcut = $wsh.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "powershell.exe"
$shortcut.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -NonInteractive -File `"$scriptPath`""
$shortcut.WorkingDirectory = $PSScriptRoot
$shortcut.WindowStyle = 1
$shortcut.Hotkey = "Ctrl+Alt+A"
$shortcut.Description = "MyJo Quick Add"
$shortcut.Save()

Write-Host "Shortcut created: $shortcutPath" -ForegroundColor Green
Write-Host "Hotkey: Ctrl+Alt+A" -ForegroundColor Green
Write-Host ""
Write-Host "Note: The shortcut must remain on the Desktop for the hotkey to work." -ForegroundColor Yellow
