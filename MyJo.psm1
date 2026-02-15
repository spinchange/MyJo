$scriptPath = Join-Path $PSScriptRoot "Journal.ps1"

function myjo {
    & $scriptPath @args
}

Export-ModuleMember -Function myjo
