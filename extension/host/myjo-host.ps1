# MyJo Native Messaging Host
# Reads a Chrome native messaging request from stdin, calls myjo, and replies.

$ErrorActionPreference = "Stop"

# Chrome native messaging protocol: 4-byte LE length prefix + JSON
$stdin = [System.Console]::OpenStandardInput()

# Read 4-byte message length
$lengthBytes = New-Object byte[] 4
$bytesRead = $stdin.Read($lengthBytes, 0, 4)
if ($bytesRead -ne 4) {
    exit 1
}
$messageLength = [System.BitConverter]::ToUInt32($lengthBytes, 0)

# Read the JSON message
$messageBytes = New-Object byte[] $messageLength
$totalRead = 0
while ($totalRead -lt $messageLength) {
    $read = $stdin.Read($messageBytes, $totalRead, $messageLength - $totalRead)
    if ($read -eq 0) { break }
    $totalRead += $read
}

$json = [System.Text.Encoding]::UTF8.GetString($messageBytes)
$message = $json | ConvertFrom-Json

$notebook = $message.notebook
$text = $message.text

# Call myjo
$myjoScript = Join-Path (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))) "Journal.ps1"

try {
    # Read current active notebook so we can restore it after
    $configFile = "$env:USERPROFILE\.myjo\config.txt"
    $previousActive = $null
    if (Test-Path $configFile) {
        foreach ($line in (Get-Content $configFile)) {
            if ($line -match '^active=(.+)$') {
                $previousActive = $Matches[1]
                break
            }
        }
    }

    # Switch notebook, add entry, then restore original active notebook
    & powershell -ExecutionPolicy Bypass -NoProfile -File $myjoScript -Notebook $notebook 2>&1 | Out-Null
    & powershell -ExecutionPolicy Bypass -NoProfile -File $myjoScript $text 2>&1 | Out-Null

    # Restore the previously active notebook if it was different
    if ($previousActive -and $previousActive -ne $notebook) {
        & powershell -ExecutionPolicy Bypass -NoProfile -File $myjoScript -Notebook $previousActive 2>&1 | Out-Null
    }

    $response = '{"success":true}'
} catch {
    $errMsg = $_.Exception.Message -replace '"', '\"'
    $response = "{`"success`":false,`"error`":`"$errMsg`"}"
}

# Write response with 4-byte LE length prefix
$stdout = [System.Console]::OpenStandardOutput()
$responseBytes = [System.Text.Encoding]::UTF8.GetBytes($response)
$responseLengthBytes = [System.BitConverter]::GetBytes([uint32]$responseBytes.Length)
$stdout.Write($responseLengthBytes, 0, 4)
$stdout.Write($responseBytes, 0, $responseBytes.Length)
$stdout.Flush()
