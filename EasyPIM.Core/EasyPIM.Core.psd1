@{
    RootModule        = 'EasyPIM.Core.psm1'
    ModuleVersion     = '0.0.1'
    GUID              = '11111111-1111-1111-1111-111111111111'
    Author            = 'EasyPIM Contributors'
    CompanyName       = 'EasyPIM'
    Copyright        = '(c) EasyPIM. All rights reserved.'
    Description       = 'Core APIs for EasyPIM: configuration, discovery, Get-* and diagnostics (scaffold).'
    PowerShellVersion = '5.1'
    RequiredModules   = @(
        @{ ModuleName = 'Az.Accounts'; ModuleVersion = '2.13.1' },
        @{ ModuleName = 'Microsoft.Graph.Authentication'; ModuleVersion = '2.29.0' }
    )
    FunctionsToExport = @()
    AliasesToExport   = @()
    CmdletsToExport   = @()
    PrivateData       = @{ PSData = @{ Tags = @('EasyPIM','Core','Scaffold'); ProjectUri = 'https://github.com/kayasax/EasyPIM' } }
}
