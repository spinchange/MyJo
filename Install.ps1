# Install.ps1
# MyJo Journal installer - sets up the myjo command on your system.

param(
    [string]$InstallPath
)

Write-Host ""
Write-Host "===== MyJo Journal Installer =====" -ForegroundColor Cyan
Write-Host ""

# Determine script location
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$journalScript = Join-Path $scriptDir "Journal.ps1"

if (-not (Test-Path $journalScript)) {
    Write-Host "Error: Journal.ps1 not found in $scriptDir" -ForegroundColor Red
    exit 1
}

# Choose install location
if (-not $InstallPath) {
    Write-Host "Where should MyJo be installed?" -ForegroundColor White
    Write-Host "  1. Keep it here ($scriptDir)" -ForegroundColor Gray
    Write-Host "  2. Copy to a custom location" -ForegroundColor Gray
    Write-Host ""
    $choice = Read-Host "Choose (1 or 2)"

    if ($choice -eq "2") {
        $InstallPath = Read-Host "Enter install path"
        if ([string]::IsNullOrWhiteSpace($InstallPath)) {
            Write-Host "No path entered. Using current location." -ForegroundColor Yellow
            $InstallPath = $scriptDir
        }
    } else {
        $InstallPath = $scriptDir
    }
}

# Copy if needed
if ($InstallPath -ne $scriptDir) {
    if (-not (Test-Path $InstallPath)) {
        New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    }
    Copy-Item $journalScript -Destination $InstallPath -Force
    Write-Host "Copied Journal.ps1 to $InstallPath" -ForegroundColor Green
}

$targetScript = Join-Path $InstallPath "Journal.ps1"

# Set execution policy if needed
try {
    $policy = Get-ExecutionPolicy -Scope CurrentUser
    if ($policy -eq "Restricted" -or $policy -eq "AllSigned") {
        Write-Host ""
        Write-Host "PowerShell execution policy is '$policy'." -ForegroundColor Yellow
        Write-Host "MyJo needs at least 'RemoteSigned' to run." -ForegroundColor Yellow
        $setPolicy = Read-Host "Set execution policy to RemoteSigned for current user? (Y/N)"
        if ($setPolicy -eq "Y") {
            Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
            Write-Host "Execution policy updated." -ForegroundColor Green
        } else {
            Write-Host "Skipped. You may need to set this manually." -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "Could not check execution policy. You may need to set it manually." -ForegroundColor Yellow
}

# Add to profile
$profilePath = $PROFILE.CurrentUserCurrentHost
$functionDef = @"

# MyJo Journal
function myjo { & '$targetScript' @args }
"@

$addToProfile = $true
if (Test-Path $profilePath) {
    $profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
    if ($profileContent -and $profileContent -match "function myjo") {
        Write-Host ""
        Write-Host "A 'myjo' function already exists in your profile." -ForegroundColor Yellow
        $overwrite = Read-Host "Update it? (Y/N)"
        if ($overwrite -ne "Y") {
            $addToProfile = $false
        } else {
            # Remove old definition
            $profileContent = $profileContent -replace "(?m)# MyJo Journal\r?\nfunction myjo \{[^\}]+\}\r?\n?", ""
            $profileContent | Out-File -FilePath $profilePath -Encoding UTF8
        }
    }
}

if ($addToProfile) {
    if (-not (Test-Path $profilePath)) {
        New-Item -ItemType File -Path $profilePath -Force | Out-Null
    }
    $functionDef | Out-File -FilePath $profilePath -Append -Encoding UTF8
    Write-Host ""
    Write-Host "Added 'myjo' command to your PowerShell profile." -ForegroundColor Green
    Write-Host "Profile: $profilePath" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "To start using MyJo:" -ForegroundColor White
Write-Host "  1. Restart PowerShell (or run: . `$PROFILE)" -ForegroundColor Gray
Write-Host "  2. Type: myjo" -ForegroundColor Gray
Write-Host "  3. Follow the first-time setup wizard" -ForegroundColor Gray
Write-Host ""

# Offer to run setup now
$runSetup = Read-Host "Run first-time setup now? (Y/N)"
if ($runSetup -eq "Y") {
    & $targetScript -Setup
}
