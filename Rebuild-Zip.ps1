# Rebuild-Zip.ps1
# Rebuilds MyJo.zip from the current repo contents.
# Run this after any changes before committing the ZIP.

$src = $PSScriptRoot
$tmp = Join-Path $env:TEMP 'MyJo_zip_tmp'
$zip = Join-Path $src 'MyJo.zip'

$include = @(
    'Journal.ps1', 'Install.ps1', 'MyJo.psd1', 'MyJo.psm1',
    'README.md', 'LICENSE', 'CHANGELOG.md', '.gitignore',
    'QuickAdd.ps1', 'Install-QuickAdd.ps1', 'Rebuild-Zip.ps1', 'Generate-Dashboard.ps1',
    'extension\chrome\background.js', 'extension\chrome\manifest.json',
    'extension\chrome\popup.html', 'extension\chrome\popup.js',
    'extension\chrome\icons\icon48.png',
    'extension\host\install-host.ps1', 'extension\host\myjo-host.bat',
    'extension\host\myjo-host.ps1'
)

if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
New-Item -ItemType Directory -Path $tmp | Out-Null

foreach ($file in $include) {
    $srcFile = Join-Path $src $file
    $dstFile = Join-Path $tmp $file
    $dstDir = Split-Path $dstFile -Parent
    if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir | Out-Null }
    if (Test-Path $srcFile) {
        Copy-Item $srcFile $dstFile
        Write-Host "Copied: $file"
    } else {
        Write-Host "MISSING: $file" -ForegroundColor Red
    }
}

Remove-Item $zip -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $tmp '*') -DestinationPath $zip
Remove-Item $tmp -Recurse -Force

Write-Host ''
Write-Host "ZIP rebuilt: $zip" -ForegroundColor Green
