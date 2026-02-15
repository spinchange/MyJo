@{
    RootModule        = 'MyJo.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'a3f7c8e1-2b4d-4f6a-9e1c-3d5b7a8f0e2c'
    Author            = 'MyJo Contributors'
    CompanyName       = 'MyJo'
    Copyright         = '(c) 2026 MyJo Contributors. MIT License.'
    Description       = 'A portable command-line journal with hashtags, machine signatures, multi-device sync, and AES-256 encryption.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('myjo')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('journal', 'diary', 'cli', 'productivity', 'encryption')
            LicenseUri = 'https://opensource.org/licenses/MIT'
        }
    }
}
