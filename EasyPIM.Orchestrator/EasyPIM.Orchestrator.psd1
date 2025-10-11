@{
    RootModule        = 'EasyPIM.Orchestrator.psm1'
    ModuleVersion = '1.4.7'
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
EasyPIM.Orchestrator v1.4.7 - Assignment Scope Accuracy

Added
- `Test-PIMPolicyDrift` now uses the orchestrator policy normalization path when available, keeping drift checks aligned with live execution.

Fixed
- Azure assignment pre-checks ignore status-only strings and now require both scope and role name before skipping an entry.
- `Test-EasyPIMConfigurationValidity` strips AuthenticationContext-only activation requirements to prevent deployment conflicts.

Docs
- Validation sample configuration updated with Azure role policy coverage demonstrating the new normalization path.
'@
    } }
}
