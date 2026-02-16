# install-host.ps1 - Register the MyJo native messaging host for Chrome
#
# Usage:
#   .\install-host.ps1                          # uses placeholder extension ID
#   .\install-host.ps1 -ExtensionId "abcdef..." # sets the allowed origin

param(
    [string]$ExtensionId
)

$hostDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$manifestPath = Join-Path $hostDir "com.myjo.host.json"
$batPath = Join-Path $hostDir "myjo-host.bat"

# Update manifest with correct absolute path and extension ID
$manifest = @{
    name = "com.myjo.host"
    description = "MyJo Journal native messaging host"
    path = $batPath
    type = "stdio"
    allowed_origins = @()
}

if ($ExtensionId) {
    $manifest.allowed_origins = @("chrome-extension://$ExtensionId/")
} else {
    Write-Host 'No -ExtensionId provided. Using placeholder -- update later.' -ForegroundColor Yellow
    $manifest.allowed_origins = @("chrome-extension://EXTENSION_ID_HERE/")
}

$manifest | ConvertTo-Json -Depth 3 | Set-Content -Path $manifestPath -Encoding UTF8
Write-Host "Updated manifest: $manifestPath"

# Write registry key
$regPath = "HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.myjo.host"
if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}
Set-ItemProperty -Path $regPath -Name "(Default)" -Value $manifestPath
Write-Host "Registry key set: $regPath -> $manifestPath"

Write-Host ""
Write-Host 'Done! Next steps:' -ForegroundColor Green
Write-Host '  1. Load the extension in Chrome: chrome://extensions -> Load unpacked -> extension\chrome'
Write-Host '  2. Copy the extension ID from Chrome'
Write-Host '  3. Re-run: .\install-host.ps1 -ExtensionId <your-id>'
