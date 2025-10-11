@{
    RootModule        = 'EasyPIM.Orchestrator.psm1'
    ModuleVersion = '1.4.8'
    GUID              = 'b6f9b3c9-bc6a-4d4b-8c51-7c45d42157cd'
    Author            = 'Loïc MICHEL'
    CompanyName       = 'EasyPIM'
    Copyright         = '(c) Loïc MICHEL. All rights reserved.'
    Description       = 'Orchestrator for EasyPIM (Invoke-EasyPIMOrchestrator)'
    PowerShellVersion = '5.1'

    # Required modules including stable EasyPIM core dependency
    RequiredModules   = @(
        'EasyPIM',
        'Az.Accounts',
        'Microsoft.Graph.Authentication'
    )

    # No nested modules - using simple internal function duplication approach
    FunctionsToExport = @(
        'Invoke-EasyPIMOrchestrator',
        'Test-PIMPolicyDrift',
        'Test-PIMEndpointDiscovery',
        'Get-EasyPIMConfiguration',
        'Disable-EasyPIMTelemetry'
    )
    AliasesToExport   = @()
    CmdletsToExport   = @()
    PrivateData       = @{ PSData =@{
        Tags = @('EasyPIM','Orchestrator')
        ProjectUri = 'https://github.com/kayasax/EasyPIM'
        LicenseUri = 'https://github.com/kayasax/EasyPIM/blob/main/LICENSE'
ReleaseNotes = @'
EasyPIM.Orchestrator v1.4.8 - Protected Role Safeguards

Fixed
- `Set-EPOEntraRolePolicy` now hard-skips Global Administrator policy automation regardless of override flags and surfaces clearer safety messaging.

Improved
- `Invoke-EasyPIMOrchestrator` highlights Global Administrator entries during execution so operators know they are preserved as break-glass roles.
- Added dedicated Pester coverage to ensure protected-role overrides behave consistently across future changes.
'@
    } }
}
