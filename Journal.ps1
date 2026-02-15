# Journal.ps1
# A portable command-line journal with hashtag support, machine signatures, and encryption.
# Stores config in ~/.myjo so the script itself can live anywhere (USB, sync folder, etc.)
#
# Usage:
#   myjo                                    - Opens interactive menu
#   myjo "Fixed the printer #work"          - Quick-add with tags
#   myjo -search "keyword"                  - Quick search entries
#   myjo -tag "work"                        - View all entries tagged #work
#   myjo -tags                              - List all tags with counts
#   myjo -machine "LUNA"                    - View entries from machine LUNA
#   myjo -machines                          - List all machines with entry counts
#   myjo -edit                              - Compose entry in external editor
#   myjo -edit -plain                       - Editor entry, strip markdown
#   myjo -editor "code --wait"              - Set preferred editor
#   myjo -lock                              - Encrypt all journal files
#   myjo -unlock                            - Decrypt all journal files
#   myjo -notebook work                     - Switch to notebook "work"
#   myjo -notebook work "G:\Work Journal"   - Create notebook with path
#   myjo -notebooks                         - List all notebooks
#   myjo -setup                             - Re-run first-time setup

param(
    [Parameter(Position = 0, ValueFromRemainingArguments)]
    [string[]]$QuickEntry,
    [Alias("s")]
    [string]$Search,
    [string]$Tag,
    [switch]$Tags,
    [string]$Machine,
    [switch]$Machines,
    [switch]$Lock,
    [switch]$Unlock,
    [switch]$Setup,
    [switch]$Edit,
    [switch]$Plain,
    [string]$Editor,
    [string]$Notebook,
    [switch]$Notebooks
)

# --- Configuration ---
$configDir = "$env:USERPROFILE\.myjo"
$configFile = "$configDir\config.txt"
$machineName = $env:COMPUTERNAME

# --- Encryption helpers ---
function Get-DerivedKey {
    param([string]$Password, [byte[]]$Salt)
    $derive = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($Password, $Salt, 100000, [System.Security.Cryptography.HashAlgorithmName]::SHA256)
    $key = $derive.GetBytes(32)
    $iv = $derive.GetBytes(16)
    $derive.Dispose()
    return @{ Key = $key; IV = $iv }
}

function Protect-File {
    param([string]$FilePath, [string]$Password)
    $salt = New-Object byte[] 16
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($salt)
    $rng.Dispose()

    $derived = Get-DerivedKey -Password $Password -Salt $salt
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = $derived.Key
    $aes.IV = $derived.IV
    $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7

    $plainBytes = [System.IO.File]::ReadAllBytes($FilePath)
    $encryptor = $aes.CreateEncryptor()
    $cipherBytes = $encryptor.TransformFinalBlock($plainBytes, 0, $plainBytes.Length)
    $encryptor.Dispose()
    $aes.Dispose()

    # Write: salt (16 bytes) + ciphertext
    $outPath = "$FilePath.enc"
    $outBytes = New-Object byte[] ($salt.Length + $cipherBytes.Length)
    [Array]::Copy($salt, 0, $outBytes, 0, $salt.Length)
    [Array]::Copy($cipherBytes, 0, $outBytes, $salt.Length, $cipherBytes.Length)
    [System.IO.File]::WriteAllBytes($outPath, $outBytes)

    Remove-Item $FilePath -Force
}

function Unprotect-File {
    param([string]$EncPath, [string]$Password)
    $allBytes = [System.IO.File]::ReadAllBytes($EncPath)
    $salt = $allBytes[0..15]
    $cipherBytes = $allBytes[16..($allBytes.Length - 1)]

    $derived = Get-DerivedKey -Password $Password -Salt ([byte[]]$salt)
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = $derived.Key
    $aes.IV = $derived.IV
    $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7

    try {
        $decryptor = $aes.CreateDecryptor()
        $plainBytes = $decryptor.TransformFinalBlock([byte[]]$cipherBytes, 0, $cipherBytes.Length)
        $decryptor.Dispose()
        $aes.Dispose()
    } catch {
        $aes.Dispose()
        return $null
    }

    $outPath = $EncPath -replace '\.enc$', ''
    [System.IO.File]::WriteAllBytes($outPath, $plainBytes)
    Remove-Item $EncPath -Force
    return $outPath
}

function Unprotect-FileToMemory {
    param([string]$EncPath, [string]$Password)
    $allBytes = [System.IO.File]::ReadAllBytes($EncPath)
    $salt = $allBytes[0..15]
    $cipherBytes = $allBytes[16..($allBytes.Length - 1)]

    $derived = Get-DerivedKey -Password $Password -Salt ([byte[]]$salt)
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = $derived.Key
    $aes.IV = $derived.IV
    $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7

    try {
        $decryptor = $aes.CreateDecryptor()
        $plainBytes = $decryptor.TransformFinalBlock([byte[]]$cipherBytes, 0, $cipherBytes.Length)
        $decryptor.Dispose()
        $aes.Dispose()
        return [System.Text.Encoding]::UTF8.GetString($plainBytes)
    } catch {
        $aes.Dispose()
        return $null
    }
}

function Protect-Content {
    param([string]$Content, [string]$Password)
    $salt = New-Object byte[] 16
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($salt)
    $rng.Dispose()

    $derived = Get-DerivedKey -Password $Password -Salt $salt
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = $derived.Key
    $aes.IV = $derived.IV
    $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7

    $plainBytes = [System.Text.Encoding]::UTF8.GetBytes($Content)
    $encryptor = $aes.CreateEncryptor()
    $cipherBytes = $encryptor.TransformFinalBlock($plainBytes, 0, $plainBytes.Length)
    $encryptor.Dispose()
    $aes.Dispose()

    $outBytes = New-Object byte[] ($salt.Length + $cipherBytes.Length)
    [Array]::Copy($salt, 0, $outBytes, 0, $salt.Length)
    [Array]::Copy($cipherBytes, 0, $outBytes, $salt.Length, $cipherBytes.Length)
    return $outBytes
}

function Test-JournalLocked {
    param([string]$Dir)
    return Test-Path (Join-Path $Dir ".myjo-locked")
}

function Get-EncryptionPassword {
    param([string]$Prompt = "Enter journal password")
    $secure = Read-Host -Prompt $Prompt -AsSecureString
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    $plain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    return $plain
}

function Lock-Journal {
    param([string]$Dir)
    if (Test-JournalLocked $Dir) {
        Write-Host "Journal is already locked." -ForegroundColor Yellow
        return
    }

    $txtFiles = Get-ChildItem $Dir -Filter "Journal_*.txt" -ErrorAction SilentlyContinue
    if ($txtFiles.Count -eq 0) {
        Write-Host "No journal files to encrypt." -ForegroundColor Yellow
        return
    }

    $password = Get-EncryptionPassword "Enter a password to lock the journal"
    if ([string]::IsNullOrWhiteSpace($password)) {
        Write-Host "Password cannot be empty. Cancelled." -ForegroundColor Red
        return
    }
    $confirm = Get-EncryptionPassword "Confirm password"
    if ($password -ne $confirm) {
        Write-Host "Passwords do not match. Cancelled." -ForegroundColor Red
        return
    }

    $count = 0
    foreach ($file in $txtFiles) {
        Protect-File -FilePath $file.FullName -Password $password
        $count++
    }

    # Create marker file
    "locked" | Out-File -FilePath (Join-Path $Dir ".myjo-locked") -Encoding UTF8
    Write-Host "Journal locked. $count file(s) encrypted." -ForegroundColor Green
}

function Unlock-Journal {
    param([string]$Dir)
    if (-not (Test-JournalLocked $Dir)) {
        Write-Host "Journal is not locked." -ForegroundColor Yellow
        return
    }

    $encFiles = Get-ChildItem $Dir -Filter "Journal_*.txt.enc" -ErrorAction SilentlyContinue
    if ($encFiles.Count -eq 0) {
        # Remove stale marker
        Remove-Item (Join-Path $Dir ".myjo-locked") -Force -ErrorAction SilentlyContinue
        Write-Host "No encrypted files found. Lock marker removed." -ForegroundColor Yellow
        return
    }

    $password = Get-EncryptionPassword "Enter password to unlock the journal"
    if ([string]::IsNullOrWhiteSpace($password)) {
        Write-Host "Password cannot be empty. Cancelled." -ForegroundColor Red
        return
    }

    # Test with first file
    $testContent = Unprotect-FileToMemory -EncPath $encFiles[0].FullName -Password $password
    if ($null -eq $testContent) {
        Write-Host "Wrong password. Journal remains locked." -ForegroundColor Red
        return
    }

    # Decrypt all files
    $count = 0
    foreach ($file in $encFiles) {
        $result = Unprotect-File -EncPath $file.FullName -Password $password
        if ($null -ne $result) { $count++ }
    }

    Remove-Item (Join-Path $Dir ".myjo-locked") -Force -ErrorAction SilentlyContinue
    Write-Host "Journal unlocked. $count file(s) decrypted." -ForegroundColor Green
}

# Read journal content respecting encryption state.
# Returns hashtable of filename => content lines (as arrays).
function Get-JournalContent {
    param([string]$Dir, [string]$Password = $null)

    $result = @{}
    $locked = Test-JournalLocked $Dir

    if ($locked) {
        $encFiles = Get-ChildItem $Dir -Filter "Journal_*.txt.enc" -ErrorAction SilentlyContinue
        if ($encFiles.Count -eq 0) { return $result }

        if (-not $Password) {
            $Password = Get-EncryptionPassword "Enter password to read journal"
            if ([string]::IsNullOrWhiteSpace($Password)) {
                Write-Host "Password required." -ForegroundColor Red
                return $result
            }
            # Validate password against first file
            $test = Unprotect-FileToMemory -EncPath $encFiles[0].FullName -Password $Password
            if ($null -eq $test) {
                Write-Host "Wrong password." -ForegroundColor Red
                return $result
            }
            $script:cachedPassword = $Password
        }

        foreach ($file in $encFiles) {
            $content = Unprotect-FileToMemory -EncPath $file.FullName -Password $Password
            if ($null -ne $content) {
                $baseName = $file.Name -replace '\.enc$', ''
                $result[$baseName] = $content -split "`r?`n"
            }
        }
    } else {
        $txtFiles = Get-ChildItem $Dir -Filter "Journal_*.txt" -ErrorAction SilentlyContinue
        foreach ($file in $txtFiles) {
            $result[$file.Name] = Get-Content $file.FullName
        }
    }
    return $result
}

# Read a single journal file by date, respecting encryption.
function Get-JournalFile {
    param([string]$Dir, [string]$FileName, [string]$Password = $null)

    $locked = Test-JournalLocked $Dir
    if ($locked) {
        $encPath = Join-Path $Dir "$FileName.enc"
        if (-not (Test-Path $encPath)) { return $null }
        if (-not $Password) {
            $Password = Get-EncryptionPassword "Enter password to read journal"
            if ([string]::IsNullOrWhiteSpace($Password)) { return $null }
            $script:cachedPassword = $Password
        }
        $content = Unprotect-FileToMemory -EncPath $encPath -Password $Password
        if ($null -eq $content) {
            Write-Host "Wrong password." -ForegroundColor Red
            return $null
        }
        return $content -split "`r?`n"
    } else {
        $path = Join-Path $Dir $FileName
        if (Test-Path $path) { return Get-Content $path }
        return $null
    }
}

# Write content to a journal file, encrypting if journal is locked.
function Set-JournalFile {
    param([string]$Dir, [string]$FileName, [string[]]$Lines, [string]$Password = $null)

    $locked = Test-JournalLocked $Dir
    if ($locked) {
        if (-not $Password) {
            $Password = Get-EncryptionPassword "Enter password to write journal"
            if ([string]::IsNullOrWhiteSpace($Password)) {
                Write-Host "Password required." -ForegroundColor Red
                return
            }
            $script:cachedPassword = $Password
        }
        $content = $Lines -join "`r`n"
        $encBytes = Protect-Content -Content $content -Password $Password
        $encPath = Join-Path $Dir "$FileName.enc"
        [System.IO.File]::WriteAllBytes($encPath, $encBytes)
    } else {
        $path = Join-Path $Dir $FileName
        $Lines | Out-File -FilePath $path -Encoding UTF8
    }
}

# Ensure we have a cached password for locked journal operations.
function Ensure-Password {
    param([string]$Dir)
    if (-not (Test-JournalLocked $Dir)) { return $true }
    if ($script:cachedPassword) {
        # Validate cached password
        $encFiles = Get-ChildItem $Dir -Filter "Journal_*.txt.enc" -ErrorAction SilentlyContinue
        if ($encFiles.Count -eq 0) { return $true }
        $test = Unprotect-FileToMemory -EncPath $encFiles[0].FullName -Password $script:cachedPassword
        if ($null -ne $test) { return $true }
    }
    $password = Get-EncryptionPassword "Enter password to access journal"
    if ([string]::IsNullOrWhiteSpace($password)) {
        Write-Host "Password required." -ForegroundColor Red
        return $false
    }
    $encFiles = Get-ChildItem $Dir -Filter "Journal_*.txt.enc" -ErrorAction SilentlyContinue
    if ($encFiles.Count -gt 0) {
        $test = Unprotect-FileToMemory -EncPath $encFiles[0].FullName -Password $password
        if ($null -eq $test) {
            Write-Host "Wrong password." -ForegroundColor Red
            return $false
        }
    }
    $script:cachedPassword = $password
    return $true
}

function Initialize-Config {
    if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir -Force | Out-Null }

    Write-Host ""
    Write-Host "===== MYJO FIRST-TIME SETUP =====" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Where should journal entries be stored?" -ForegroundColor White
    Write-Host "Enter a path to a folder (local, network drive, cloud sync, USB, etc.)" -ForegroundColor Gray
    Write-Host "Example: C:\Users\user\OneDrive\Journal" -ForegroundColor Gray
    Write-Host "Example: D:\Sync\Journal" -ForegroundColor Gray
    Write-Host "Example: \\server\share\Journal" -ForegroundColor Gray
    Write-Host ""

    $path = Read-Host "Journal folder path"

    if ([string]::IsNullOrWhiteSpace($path)) {
        $path = "$env:USERPROFILE\Documents\Journal"
        Write-Host "Using default: $path" -ForegroundColor Yellow
    }

    if (-not (Test-Path $path)) {
        $create = Read-Host "Folder doesn't exist. Create it? (Y/N)"
        if ($create -eq "Y") {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
            Write-Host "Created: $path" -ForegroundColor Green
        } else {
            Write-Host "Setup cancelled." -ForegroundColor Red
            exit 1
        }
    }

    # Ask about encryption
    Write-Host ""
    Write-Host "Would you like to enable journal encryption?" -ForegroundColor White
    Write-Host "You can lock/unlock your journal anytime with 'myjo -lock' and 'myjo -unlock'." -ForegroundColor Gray
    $encChoice = Read-Host "Enable encryption? (Y/N)"

    # Ask about editor
    Write-Host ""
    Write-Host "Which editor should 'myjo -edit' open?" -ForegroundColor White
    Write-Host "Examples: notepad, emacs, code --wait, notepad++" -ForegroundColor Gray
    $editorChoice = Read-Host "Editor command (Enter for notepad.exe)"
    if ([string]::IsNullOrWhiteSpace($editorChoice)) { $editorChoice = "notepad.exe" }

    $configLines = @("notebook:default=$path", "active=default")
    if ($encChoice -eq "Y") {
        $configLines += "encryption=enabled"
        Write-Host "Encryption enabled. Use 'myjo -lock' to encrypt your journal." -ForegroundColor Green
    } else {
        $configLines += "encryption=disabled"
    }
    $configLines += "editor=$editorChoice"

    $configLines | Out-File -FilePath $configFile -Encoding UTF8
    Write-Host ""
    Write-Host "Config saved. Journal will be stored at: $path" -ForegroundColor Green
    Write-Host "Editor: $editorChoice" -ForegroundColor Green
    Write-Host "Machine signature: $machineName" -ForegroundColor Green
    Write-Host "Re-run setup anytime with: myjo -setup" -ForegroundColor Gray
    Write-Host ""
}

# Run setup if needed
if ($Setup -or -not (Test-Path $configFile)) {
    Initialize-Config
    if ($Setup) { exit 0 }
}

# --- Config parsing ---
function Get-ConfigValue {
    param([string]$Path)
    $cfg = @{ notebooks = @{}; settings = @{} }
    if (-not (Test-Path $Path)) { return $cfg }
    $lines = Get-Content $Path
    foreach ($line in $lines) {
        $l = $line.Trim()
        if ($l -match '^notebook:([^=]+)=(.+)$') {
            $cfg.notebooks[$Matches[1]] = $Matches[2]
        } elseif ($l -match '^([^=]+)=(.*)$') {
            $cfg.settings[$Matches[1]] = $Matches[2]
        }
    }
    return $cfg
}

function Write-Config {
    param([hashtable]$Config)
    $lines = @()
    foreach ($nb in ($Config.notebooks.GetEnumerator() | Sort-Object Name)) {
        $lines += "notebook:$($nb.Key)=$($nb.Value)"
    }
    foreach ($s in ($Config.settings.GetEnumerator() | Sort-Object Name)) {
        $lines += "$($s.Key)=$($s.Value)"
    }
    $lines | Out-File -FilePath $configFile -Encoding UTF8
}

# Auto-migrate old config format (bare path on line 1)
function Migrate-ConfigIfNeeded {
    if (-not (Test-Path $configFile)) { return }
    $firstLine = (Get-Content $configFile -First 1).Trim()
    if ($firstLine -notmatch '=' -and $firstLine -ne '') {
        # Old format: line 1 is a bare path
        $oldLines = Get-Content $configFile
        $newLines = @("notebook:default=$firstLine", "active=default")
        foreach ($line in ($oldLines | Select-Object -Skip 1)) {
            if ($line.Trim() -ne '') { $newLines += $line.Trim() }
        }
        $newLines | Out-File -FilePath $configFile -Encoding UTF8
    }
}

Migrate-ConfigIfNeeded
$script:config = Get-ConfigValue $configFile

# Determine active notebook
$activeNotebook = if ($script:config.settings.ContainsKey('active')) { $script:config.settings['active'] } else { 'default' }
if ($script:config.notebooks.Count -eq 0) {
    Write-Host "No notebooks configured. Run 'myjo -setup'." -ForegroundColor Red
    exit 1
}
if (-not $script:config.notebooks.ContainsKey($activeNotebook)) {
    Write-Host "Active notebook '$activeNotebook' not found. Run 'myjo -setup'." -ForegroundColor Red
    exit 1
}
$journalDir = $script:config.notebooks[$activeNotebook]

# Validate the journal path is accessible
if (-not (Test-Path $journalDir)) {
    Write-Host "Journal folder not accessible: $journalDir" -ForegroundColor Red
    Write-Host "The drive or network path may be disconnected." -ForegroundColor Yellow
    Write-Host "Run 'myjo -setup' to reconfigure." -ForegroundColor Yellow
    exit 1
}

# Cache password within a session so the user isn't prompted repeatedly
$script:cachedPassword = $null

# --- Notebook functions ---
function Switch-Notebook {
    param([string]$Name)
    $Name = $Name.ToLower()

    # Check if remaining args provide a path for creating a new notebook
    $nbPath = $null
    if ($QuickEntry -and $QuickEntry.Count -gt 0) {
        $nbPath = $QuickEntry -join " "
    }

    if ($nbPath) {
        # Create new notebook
        if (-not (Test-Path $nbPath)) {
            $create = Read-Host "Folder '$nbPath' doesn't exist. Create it? (Y/N)"
            if ($create -eq "Y") {
                New-Item -ItemType Directory -Path $nbPath -Force | Out-Null
                Write-Host "Created: $nbPath" -ForegroundColor Green
            } else {
                Write-Host "Cancelled." -ForegroundColor Yellow
                return
            }
        }
        $script:config.notebooks[$Name] = $nbPath
        $script:config.settings['active'] = $Name
        Write-Config $script:config
        Write-Host "Notebook '$Name' created and activated. Path: $nbPath" -ForegroundColor Green
    } else {
        # Switch to existing notebook
        if (-not $script:config.notebooks.ContainsKey($Name)) {
            Write-Host "Notebook '$Name' not found. Create it with: myjo -notebook $Name ""<path>""" -ForegroundColor Red
            Write-Host ""
            Write-Host "Available notebooks:" -ForegroundColor Cyan
            foreach ($nb in $script:config.notebooks.GetEnumerator()) {
                $marker = if ($nb.Key -eq $activeNotebook) { " *" } else { "" }
                Write-Host "  $($nb.Key)$marker  ->  $($nb.Value)" -ForegroundColor White
            }
            return
        }
        $script:config.settings['active'] = $Name
        Write-Config $script:config
        Write-Host "Switched to notebook '$Name'. Path: $($script:config.notebooks[$Name])" -ForegroundColor Green
    }
}

function Show-Notebooks {
    if ($script:config.notebooks.Count -eq 0) {
        Write-Host "No notebooks configured." -ForegroundColor Yellow
        return
    }
    Write-Host ""
    Write-Host "Notebooks:" -ForegroundColor Cyan
    foreach ($nb in ($script:config.notebooks.GetEnumerator() | Sort-Object Name)) {
        $marker = if ($nb.Key -eq $activeNotebook) { " *" } else { "" }
        Write-Host "  $($nb.Key)$marker  ->  $($nb.Value)" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "Active: $activeNotebook" -ForegroundColor Gray
    Write-Host ""
}

function Interactive-SwitchNotebook {
    Show-Notebooks
    $name = Read-Host "Notebook name to switch to (or 'new' to create)"
    if ([string]::IsNullOrWhiteSpace($name)) { return }
    if ($name -eq 'new') {
        $newName = Read-Host "New notebook name"
        if ([string]::IsNullOrWhiteSpace($newName)) { return }
        $newPath = Read-Host "Folder path for '$newName'"
        if ([string]::IsNullOrWhiteSpace($newPath)) { return }
        $newName = $newName.ToLower()
        if (-not (Test-Path $newPath)) {
            $create = Read-Host "Folder '$newPath' doesn't exist. Create it? (Y/N)"
            if ($create -eq "Y") {
                New-Item -ItemType Directory -Path $newPath -Force | Out-Null
                Write-Host "Created: $newPath" -ForegroundColor Green
            } else {
                Write-Host "Cancelled." -ForegroundColor Yellow
                return
            }
        }
        $script:config.notebooks[$newName] = $newPath
        $script:config.settings['active'] = $newName
        Write-Config $script:config
        $script:activeNotebook = $newName
        $script:journalDir = $newPath
        Write-Host "Notebook '$newName' created and activated." -ForegroundColor Green
    } else {
        $name = $name.ToLower()
        if (-not $script:config.notebooks.ContainsKey($name)) {
            Write-Host "Notebook '$name' not found." -ForegroundColor Red
            return
        }
        $script:config.settings['active'] = $name
        Write-Config $script:config
        $script:activeNotebook = $name
        $script:journalDir = $script:config.notebooks[$name]
        Write-Host "Switched to notebook '$name'." -ForegroundColor Green
    }
}

# --- Editor helpers ---
function Get-EditorCommand {
    if ($env:EDITOR) { return $env:EDITOR }
    $configLines = Get-Content $configFile
    foreach ($line in $configLines) {
        if ($line -match '^editor=(.+)$') { return $Matches[1] }
    }
    return "notepad.exe"
}

function ConvertFrom-MarkdownText {
    param([string]$Text)
    # Headers: ## Heading → Heading
    $Text = $Text -replace '(?m)^#{1,6}\s+', ''
    # Bold/italic combos: ***text*** or ___text___
    $Text = $Text -replace '\*{3}(.+?)\*{3}', '$1'
    $Text = $Text -replace '_{3}(.+?)_{3}', '$1'
    # Bold: **text** or __text__
    $Text = $Text -replace '\*{2}(.+?)\*{2}', '$1'
    $Text = $Text -replace '_{2}(.+?)_{2}', '$1'
    # Italic: *text* or _text_
    $Text = $Text -replace '(?<!\w)\*(.+?)\*(?!\w)', '$1'
    $Text = $Text -replace '(?<!\w)_(.+?)_(?!\w)', '$1'
    # Inline code: `text`
    $Text = $Text -replace '`(.+?)`', '$1'
    # Links: [text](url) → text (url)
    $Text = $Text -replace '\[(.+?)\]\((.+?)\)', '$1 ($2)'
    return $Text
}

function New-EditorEntry {
    param([switch]$StripMarkdown)
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $tempFile = Join-Path $env:TEMP "myjo_entry_$timestamp.md"
    $header = "<!-- Write your journal entry below. Lines starting with <!-- are ignored. Save and close to submit. -->"
    $header | Out-File -FilePath $tempFile -Encoding UTF8

    $editorCmd = Get-EditorCommand
    # Split command to handle args like "code --wait"
    $parts = $editorCmd -split '\s+', 2
    $exe = $parts[0]
    if ($parts.Length -gt 1) {
        $editorArgs = "$($parts[1]) `"$tempFile`""
    } else {
        $editorArgs = "`"$tempFile`""
    }

    $proc = Start-Process -FilePath $exe -ArgumentList $editorArgs -PassThru -Wait
    if (-not (Test-Path $tempFile)) {
        Write-Host "Temp file not found. Nothing saved." -ForegroundColor Yellow
        return
    }

    $lines = Get-Content $tempFile
    # Strip HTML comment lines
    $contentLines = $lines | Where-Object { $_ -notmatch '^\s*<!--.*-->\s*$' }
    $text = ($contentLines -join "`n").Trim()

    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue

    if ([string]::IsNullOrWhiteSpace($text)) {
        Write-Host "Empty entry, nothing saved." -ForegroundColor Yellow
        return
    }

    if ($StripMarkdown) {
        $text = ConvertFrom-MarkdownText $text
    }

    Add-Entry $text
}

# --- Core functions ---
function Get-TodayFileName {
    return "Journal_$(Get-Date -Format 'yyyy-MM-dd').txt"
}

function Get-TodayFile {
    return Join-Path $journalDir (Get-TodayFileName)
}

function Add-Entry {
    param([string]$Text)
    $fileName = Get-TodayFileName
    $timestamp = Get-Date -Format 'HH:mm:ss'
    $entry = "[$timestamp @$machineName] $Text"

    $locked = Test-JournalLocked $journalDir

    if ($locked) {
        if (-not (Ensure-Password $journalDir)) { return }
        $existingLines = Get-JournalFile -Dir $journalDir -FileName $fileName -Password $script:cachedPassword
        if ($null -eq $existingLines) {
            $header = "=== $(Get-Date -Format 'dddd, MMMM dd, yyyy') ==="
            $existingLines = @($header, "", $entry)
        } else {
            $existingLines = @($existingLines) + @("", $entry)
        }
        Set-JournalFile -Dir $journalDir -FileName $fileName -Lines $existingLines -Password $script:cachedPassword
    } else {
        $file = Get-TodayFile
        if (-not (Test-Path $file)) {
            $header = "=== $(Get-Date -Format 'dddd, MMMM dd, yyyy') ==="
            $header | Out-File -FilePath $file -Encoding UTF8
            "" | Out-File -FilePath $file -Append -Encoding UTF8
        }
        "" | Out-File -FilePath $file -Append -Encoding UTF8
        $entry | Out-File -FilePath $file -Append -Encoding UTF8
    }

    $detectedTags = [regex]::Matches($Text, '#(\w+)') | ForEach-Object { $_.Value }
    if ($detectedTags) {
        Write-Host "Entry added from $machineName. Tags: $($detectedTags -join ', ')" -ForegroundColor Green
    } else {
        Write-Host "Entry added from $machineName." -ForegroundColor Green
    }
}

function Show-Today {
    $fileName = Get-TodayFileName
    $lines = Get-JournalFile -Dir $journalDir -FileName $fileName -Password $script:cachedPassword
    if ($lines) {
        Write-Host ""
        $lines | ForEach-Object { Write-Host $_ }
        Write-Host ""
    } else {
        Write-Host "No entries for today yet." -ForegroundColor Yellow
    }
}

function Show-RecentEntries {
    param([int]$Days = 7)

    $locked = Test-JournalLocked $journalDir
    if ($locked) {
        if (-not (Ensure-Password $journalDir)) { return }
        $allContent = Get-JournalContent -Dir $journalDir -Password $script:cachedPassword
        if ($allContent.Count -eq 0) {
            Write-Host "No journal entries found." -ForegroundColor Yellow
            return
        }
        $sorted = $allContent.Keys | Sort-Object -Descending | Select-Object -First $Days
        foreach ($name in $sorted) {
            Write-Host ""
            $allContent[$name] | ForEach-Object { Write-Host $_ }
        }
        Write-Host ""
    } else {
        $files = Get-ChildItem $journalDir -Filter "Journal_*.txt" | Sort-Object Name -Descending | Select-Object -First $Days
        if ($files.Count -eq 0) {
            Write-Host "No journal entries found." -ForegroundColor Yellow
            return
        }
        foreach ($file in $files) {
            Write-Host ""
            Get-Content $file.FullName | ForEach-Object { Write-Host $_ }
        }
        Write-Host ""
    }
}

function Search-Entries {
    param([string]$Keyword)

    $locked = Test-JournalLocked $journalDir
    if ($locked) {
        if (-not (Ensure-Password $journalDir)) { return }
    }

    $allContent = Get-JournalContent -Dir $journalDir -Password $script:cachedPassword
    if ($allContent.Count -eq 0) {
        Write-Host "No journal entries found." -ForegroundColor Yellow
        return
    }

    $found = $false
    foreach ($name in ($allContent.Keys | Sort-Object)) {
        $matchLines = $allContent[$name] | Where-Object { $_ -like "*$Keyword*" }
        if ($matchLines) {
            if (-not $found) { Write-Host "" }
            $found = $true
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($name)
            Write-Host "--- $baseName ---" -ForegroundColor Cyan
            $matchLines | ForEach-Object { Write-Host "  $_" }
        }
    }

    if (-not $found) {
        Write-Host "No entries matching '$Keyword'." -ForegroundColor Yellow
    }
    Write-Host ""
}

function Filter-ByTag {
    param([string]$TagName)
    $TagName = $TagName -replace '^#', ''

    $locked = Test-JournalLocked $journalDir
    if ($locked) {
        if (-not (Ensure-Password $journalDir)) { return }
    }

    $allContent = Get-JournalContent -Dir $journalDir -Password $script:cachedPassword
    if ($allContent.Count -eq 0) {
        Write-Host "No journal entries found." -ForegroundColor Yellow
        return
    }

    $found = $false
    foreach ($name in ($allContent.Keys | Sort-Object)) {
        $matchLines = $allContent[$name] | Where-Object { $_ -match "#$TagName\b" }
        if ($matchLines) {
            if (-not $found) { Write-Host "" }
            $found = $true
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($name)
            Write-Host "--- $baseName ---" -ForegroundColor Cyan
            $matchLines | ForEach-Object { Write-Host "  $_" }
        }
    }

    if (-not $found) {
        Write-Host "No entries with tag #$TagName." -ForegroundColor Yellow
    }
    Write-Host ""
}

function Show-AllTags {
    $locked = Test-JournalLocked $journalDir
    if ($locked) {
        if (-not (Ensure-Password $journalDir)) { return }
    }

    $allContent = Get-JournalContent -Dir $journalDir -Password $script:cachedPassword
    if ($allContent.Count -eq 0) {
        Write-Host "No journal entries found." -ForegroundColor Yellow
        return
    }

    $tagCounts = @{}
    foreach ($name in $allContent.Keys) {
        $content = $allContent[$name] -join "`n"
        $matches = [regex]::Matches($content, '#(\w+)')
        foreach ($m in $matches) {
            $tag = $m.Groups[1].Value.ToLower()
            if ($tagCounts.ContainsKey($tag)) {
                $tagCounts[$tag]++
            } else {
                $tagCounts[$tag] = 1
            }
        }
    }

    if ($tagCounts.Count -eq 0) {
        Write-Host "No tags found in any entries." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "All tags:" -ForegroundColor Cyan
    $tagCounts.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
        Write-Host "  #$($_.Key)  ($($_.Value) entries)" -ForegroundColor White
    }
    Write-Host ""
}

function Filter-ByMachine {
    param([string]$MachineName)
    $MachineName = $MachineName.Trim().ToUpper()

    $locked = Test-JournalLocked $journalDir
    if ($locked) {
        if (-not (Ensure-Password $journalDir)) { return }
    }

    $allContent = Get-JournalContent -Dir $journalDir -Password $script:cachedPassword
    if ($allContent.Count -eq 0) {
        Write-Host "No journal entries found." -ForegroundColor Yellow
        return
    }

    $found = $false
    foreach ($name in ($allContent.Keys | Sort-Object)) {
        $matchLines = $allContent[$name] | Where-Object { $_ -match "\[@?\d{2}:\d{2}:\d{2}\s+@$MachineName\]" }
        if ($matchLines) {
            if (-not $found) { Write-Host "" }
            $found = $true
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($name)
            Write-Host "--- $baseName ---" -ForegroundColor Cyan
            $matchLines | ForEach-Object { Write-Host "  $_" }
        }
    }

    if (-not $found) {
        Write-Host "No entries from machine '$MachineName'." -ForegroundColor Yellow
    }
    Write-Host ""
}

function Show-AllMachines {
    $locked = Test-JournalLocked $journalDir
    if ($locked) {
        if (-not (Ensure-Password $journalDir)) { return }
    }

    $allContent = Get-JournalContent -Dir $journalDir -Password $script:cachedPassword
    if ($allContent.Count -eq 0) {
        Write-Host "No journal entries found." -ForegroundColor Yellow
        return
    }

    $machineCounts = @{}
    foreach ($name in $allContent.Keys) {
        foreach ($line in $allContent[$name]) {
            if ($line -match '\[\d{2}:\d{2}:\d{2}\s+@(\S+)\]') {
                $m = $Matches[1].ToUpper()
                if ($machineCounts.ContainsKey($m)) {
                    $machineCounts[$m]++
                } else {
                    $machineCounts[$m] = 1
                }
            }
        }
    }

    if ($machineCounts.Count -eq 0) {
        Write-Host "No machine signatures found." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "All machines:" -ForegroundColor Cyan
    $machineCounts.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
        $marker = if ($_.Key -eq $machineName) { " (this machine)" } else { "" }
        Write-Host "  @$($_.Key)  ($($_.Value) entries)$marker" -ForegroundColor White
    }
    Write-Host ""
}

function Show-Calendar {
    $locked = Test-JournalLocked $journalDir
    if ($locked) {
        if (-not (Ensure-Password $journalDir)) { return }
        $allContent = Get-JournalContent -Dir $journalDir -Password $script:cachedPassword
        if ($allContent.Count -eq 0) {
            Write-Host "No journal entries found." -ForegroundColor Yellow
            return
        }
        Write-Host ""
        Write-Host "Journal entries:" -ForegroundColor Cyan
        foreach ($name in ($allContent.Keys | Sort-Object -Descending)) {
            $date = [System.IO.Path]::GetFileNameWithoutExtension($name) -replace "Journal_", ""
            $lineCount = ($allContent[$name] | Where-Object { $_ -match "^\[" }).Count
            Write-Host "  $date  ($lineCount entries)" -ForegroundColor White
        }
        Write-Host ""
    } else {
        $files = Get-ChildItem $journalDir -Filter "Journal_*.txt" -ErrorAction SilentlyContinue
        if ($files.Count -eq 0) {
            Write-Host "No journal entries found." -ForegroundColor Yellow
            return
        }
        Write-Host ""
        Write-Host "Journal entries:" -ForegroundColor Cyan
        foreach ($file in ($files | Sort-Object Name -Descending)) {
            $date = $file.BaseName -replace "Journal_", ""
            $lineCount = (Get-Content $file.FullName | Where-Object { $_ -match "^\[" }).Count
            Write-Host "  $date  ($lineCount entries)" -ForegroundColor White
        }
        Write-Host ""
    }
}

function Read-DateEntries {
    Write-Host ""
    Show-Calendar
    $date = Read-Host "Enter a date (yyyy-MM-dd)"
    $fileName = "Journal_$date.txt"
    $lines = Get-JournalFile -Dir $journalDir -FileName $fileName -Password $script:cachedPassword
    if ($lines) {
        Write-Host ""
        $lines | ForEach-Object { Write-Host $_ }
        Write-Host ""
    } else {
        Write-Host "No entries for $date." -ForegroundColor Yellow
    }
}

function Get-Entries {
    param([string]$FileName)
    $lines = Get-JournalFile -Dir $journalDir -FileName $FileName -Password $script:cachedPassword
    if (-not $lines) { return @() }
    return @($lines | Where-Object { $_ -match "^\[" })
}

function Show-NumberedEntries {
    param([string]$FileName)
    $entries = Get-Entries $FileName
    if ($entries.Count -eq 0) {
        Write-Host "No entries found." -ForegroundColor Yellow
        return $entries
    }
    Write-Host ""
    for ($i = 0; $i -lt $entries.Count; $i++) {
        Write-Host "  $($i + 1). $($entries[$i])" -ForegroundColor White
    }
    Write-Host ""
    return $entries
}

function Edit-Entry {
    $fileName = Get-TodayFileName

    $locked = Test-JournalLocked $journalDir
    if ($locked) {
        if (-not (Ensure-Password $journalDir)) { return }
    }

    $entries = Show-NumberedEntries $fileName
    if ($entries.Count -eq 0) { return }

    $pick = Read-Host "Entry number to edit (or 0 to cancel)"
    if ($pick -eq "0" -or -not $pick) { return }

    $index = [int]$pick - 1
    if ($index -lt 0 -or $index -ge $entries.Count) {
        Write-Host "Invalid selection." -ForegroundColor Red
        return
    }

    Write-Host "Current: $($entries[$index])" -ForegroundColor Yellow
    $timestamp = if ($entries[$index] -match '^\[([^\]]+)\]') { $Matches[1] } else { "" }
    $newText = Read-Host "New text (timestamp will be kept)"

    if ([string]::IsNullOrWhiteSpace($newText)) {
        Write-Host "No changes made." -ForegroundColor Yellow
        return
    }

    $newEntry = "[$timestamp] $newText"
    $allLines = Get-JournalFile -Dir $journalDir -FileName $fileName -Password $script:cachedPassword
    $entryCount = 0
    for ($i = 0; $i -lt $allLines.Count; $i++) {
        if ($allLines[$i] -match "^\[") {
            if ($entryCount -eq $index) {
                $allLines[$i] = $newEntry
                break
            }
            $entryCount++
        }
    }
    Set-JournalFile -Dir $journalDir -FileName $fileName -Lines $allLines -Password $script:cachedPassword
    Write-Host "Entry updated." -ForegroundColor Green
}

function Remove-Entry {
    $fileName = Get-TodayFileName

    $locked = Test-JournalLocked $journalDir
    if ($locked) {
        if (-not (Ensure-Password $journalDir)) { return }
    }

    $entries = Show-NumberedEntries $fileName
    if ($entries.Count -eq 0) { return }

    $pick = Read-Host "Entry number to delete (or 0 to cancel)"
    if ($pick -eq "0" -or -not $pick) { return }

    $index = [int]$pick - 1
    if ($index -lt 0 -or $index -ge $entries.Count) {
        Write-Host "Invalid selection." -ForegroundColor Red
        return
    }

    Write-Host "Delete: $($entries[$index])" -ForegroundColor Yellow
    $confirm = Read-Host "Are you sure? (Y/N)"
    if ($confirm -ne "Y") {
        Write-Host "Cancelled." -ForegroundColor Yellow
        return
    }

    $allLines = @(Get-JournalFile -Dir $journalDir -FileName $fileName -Password $script:cachedPassword)
    $entryCount = 0
    $removeLine = -1
    for ($i = 0; $i -lt $allLines.Count; $i++) {
        if ($allLines[$i] -match "^\[") {
            if ($entryCount -eq $index) {
                $removeLine = $i
                break
            }
            $entryCount++
        }
    }

    if ($removeLine -ge 0) {
        $newLines = @()
        if ($removeLine -gt 0) { $newLines += $allLines[0..($removeLine - 1)] }
        if ($removeLine -lt $allLines.Count - 1) { $newLines += $allLines[($removeLine + 1)..($allLines.Count - 1)] }
        Set-JournalFile -Dir $journalDir -FileName $fileName -Lines $newLines -Password $script:cachedPassword
        Write-Host "Entry deleted." -ForegroundColor Green
    }
}

function Write-MultiLineEntry {
    Write-Host "Type your entry. Use #tags inline. (blank line to finish):" -ForegroundColor Cyan
    $lines = @()
    while ($true) {
        $line = Read-Host
        if ([string]::IsNullOrWhiteSpace($line)) { break }
        $lines += $line
    }
    if ($lines.Count -gt 0) {
        Add-Entry ($lines -join "`n")
    } else {
        Write-Host "Empty entry, nothing saved." -ForegroundColor Yellow
    }
}

# --- Quick modes ---
if ($Tags) {
    Show-AllTags
    exit 0
}

if ($Tag) {
    Filter-ByTag $Tag
    exit 0
}

if ($Search) {
    Search-Entries $Search
    exit 0
}

if ($Machine) {
    Filter-ByMachine $Machine
    exit 0
}

if ($Machines) {
    Show-AllMachines
    exit 0
}

if ($Lock) {
    Lock-Journal $journalDir
    exit 0
}

if ($Unlock) {
    Unlock-Journal $journalDir
    exit 0
}

if ($Editor) {
    $script:config.settings['editor'] = $Editor
    Write-Config $script:config
    Write-Host "Editor set to: $Editor" -ForegroundColor Green
    exit 0
}

if ($Edit) {
    New-EditorEntry -StripMarkdown:$Plain
    exit 0
}

if ($Notebooks) {
    Show-Notebooks
    exit 0
}

if ($Notebook) {
    Switch-Notebook $Notebook
    exit 0
}

if ($QuickEntry) {
    $text = $QuickEntry -join " "
    Add-Entry $text
    exit 0
}

# --- Interactive menu ---
while ($true) {
    $lockState = if (Test-JournalLocked $journalDir) { " [LOCKED]" } else { "" }
    $nbLabel = if ($activeNotebook -ne 'default') { " ($activeNotebook)" } else { "" }
    Write-Host ""
    Write-Host "===== JOURNAL [$machineName]$nbLabel$lockState =====" -ForegroundColor Cyan
    Write-Host "  1. New entry"
    Write-Host "  2. View today"
    Write-Host "  3. View recent (last 7 days)"
    Write-Host "  4. View by date"
    Write-Host "  5. Search entries"
    Write-Host "  6. Filter by tag"
    Write-Host "  7. List all tags"
    Write-Host "  8. Edit entry (today)"
    Write-Host "  9. Delete entry (today)"
    Write-Host "  E. New entry (editor)"
    Write-Host "  M. Filter by machine"
    Write-Host "  L. List all machines"
    if (Test-JournalLocked $journalDir) {
        Write-Host "  U. Unlock journal" -ForegroundColor Yellow
    } else {
        Write-Host "  K. Lock journal"
    }
    Write-Host "  N. Switch notebook"
    Write-Host "  Q. Exit"
    Write-Host ""

    $choice = Read-Host "Choose"

    switch ($choice.ToUpper()) {
        "1" { Write-MultiLineEntry }
        "2" { Show-Today }
        "3" { Show-RecentEntries }
        "4" { Read-DateEntries }
        "5" {
            $keyword = Read-Host "Search for"
            Search-Entries $keyword
        }
        "6" {
            $tagInput = Read-Host "Tag name (with or without #)"
            Filter-ByTag $tagInput
        }
        "7" { Show-AllTags }
        "8" { Edit-Entry }
        "9" { Remove-Entry }
        "E" { New-EditorEntry }
        "M" {
            $machineInput = Read-Host "Machine name"
            Filter-ByMachine $machineInput
        }
        "L" { Show-AllMachines }
        "K" { Lock-Journal $journalDir }
        "U" { Unlock-Journal $journalDir }
        "N" { Interactive-SwitchNotebook }
        "Q" { exit 0 }
        default { Write-Host "Invalid choice." -ForegroundColor Red }
    }
}
