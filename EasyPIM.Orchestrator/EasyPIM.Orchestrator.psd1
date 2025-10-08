@{
    RootModule        = 'EasyPIM.Orchestrator.psm1'
    ModuleVersion = '1.4.5'
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
🚀 EasyPIM.Orchestrator v1.4.5 - Policy Arrays + Drift Accuracy

### Added
- Array-based policy definitions now supported across Azure, Entra, and Group scopes with template override support.
- New documentation and sample JSON (`config/enhanced-sample-config-array.json`) demonstrating the array formats.

### Fixed
- `Test-PIMPolicyDrift` now compares template-based policies using the resolved payload produced by the orchestrator.
- Cleaned source files flagged by FileIntegrity tests (trailing whitespace) to keep CI validation green.

### Docs
- Added dedicated array policy guides under `EasyPIM/Documentation` for Azure, Entra, and Group scenarios.
'@
    } }
}
