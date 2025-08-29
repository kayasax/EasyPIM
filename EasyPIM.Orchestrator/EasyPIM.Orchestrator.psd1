@{
    RootModule        = 'EasyPIM.Orchestrator.psm1'
    ModuleVersion     = '1.0.6'
    GUID              = 'b6f9b3c9-bc6a-4d4b-8c51-7c45d42157cd'
    Author            = 'Loïc MICHEL'
    CompanyName       = 'EasyPIM'
    Copyright         = '(c) Loïc MICHEL. All rights reserved.'
    Description       = 'Orchestrator for EasyPIM (Invoke-EasyPIMOrchestrator)'
    PowerShellVersion = '5.1'

    # Required modules including stable EasyPIM core dependency
    RequiredModules   = @(
    @{ModuleName='EasyPIM'; ModuleVersion='2.0.3'},
        'Az.Accounts',
        'Microsoft.Graph.Authentication',
        'Microsoft.Graph.Identity.Governance'
    )

    # No nested modules - using simple internal function duplication approach
    FunctionsToExport = @(
        'Invoke-EasyPIMOrchestrator',
        'Test-PIMPolicyDrift',
        'Test-PIMEndpointDiscovery'
    )
    AliasesToExport   = @()
    CmdletsToExport   = @()
    PrivateData       = @{ PSData =@{
        Tags = @('EasyPIM','Orchestrator')
        ProjectUri = 'https://github.com/kayasax/EasyPIM'
        LicenseUri = 'https://github.com/kayasax/EasyPIM/blob/main/LICENSE'
ReleaseNotes = @'
🚀 EasyPIM.Orchestrator v1.0.6 - Stable Release

MAJOR MILESTONE: Module separation and architectural improvements complete and validated end-to-end.

✅ NEW FEATURES:
- ARM API compatibility fixes (resolves InvalidResourceType/NoRegisteredProviderFound errors)
- Enhanced policy validation with proactive error detection and clear guidance
- Parameter standardization: 'principalId' (with 'assignee' alias for compatibility)
- Standalone orchestrator module with proper dependency management
- Auto-configuration of permanent assignment flags based on duration specifications
- Dependency resolution improvements: now depends on stable EasyPIM v2.0.0

Stabilization notes:
- Comprehensive tests passed locally (6k+), plus end-to-end remediation and drift checks.
- Compatible with EasyPIM >= 2.0.2.

📋 REQUIREMENTS:
- EasyPIM v2.0.2 (automatically installed)
- PowerShell 5.1+
- Az.Accounts, Microsoft.Graph modules
'@
    } }
}
