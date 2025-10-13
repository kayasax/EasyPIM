@{
    RootModule        = 'EasyPIM.Orchestrator.psm1'
    ModuleVersion = '1.4.9'
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
EasyPIM.Orchestrator v1.4.9 - Automation Override Token

Added
- `Invoke-EasyPIMOrchestrator` now accepts `-ProtectedRoleOverrideToken` so CI and scheduled automation can authorize protected-role policy updates without interactive prompts.

Improved
- Telemetry captures whether the override token was supplied to provide audit trails for protected role changes.
- Added Pester coverage verifying the override token bypasses prompts only when the confirmation value matches, preventing regression.
'@
    } }
}
