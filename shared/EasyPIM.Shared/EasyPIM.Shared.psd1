@{
    RootModule        = 'EasyPIM.Shared.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '5c4e6f5d-2f65-4b15-9b19-f0c3c6dc8b1a'
    Author            = 'EasyPIM Team'
    CompanyName       = 'EasyPIM'
    Copyright         = '(c) EasyPIM. All rights reserved.'
    Description       = 'Private shared helpers used internally by EasyPIM modules.'
    PowerShellVersion = '5.1'
    # Export helpers consumed by EasyPIM Core and Orchestrator
    FunctionsToExport = @(
        'Write-SectionHeader',
        'Initialize-EasyPIMPolicies',
        'invoke-graph',
        'Test-PrincipalExists',
        'Test-GroupEligibleForPIM',
        'Invoke-ARM',
        'Get-PIMAzureEnvironmentEndpoint'
    )
    AliasesToExport   = @()
    CmdletsToExport   = @()
    PrivateData       = @{ PSData = @{ Tags = @('EasyPIM','Shared','Private') } }
}
