@{
    RootModule        = 'EasyPIM.Orchestrator.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'b6f9b3c9-bc6a-4d4b-8c51-7c45d42157cd'
    Author            = 'Loïc MICHEL'
    CompanyName       = 'EasyPIM'
    Copyright         = '(c) Loïc MICHEL. All rights reserved.'
    Description       = 'Orchestrator for EasyPIM (Invoke-EasyPIMOrchestrator)'
    PowerShellVersion = '5.1'

    # Required modules to support EasyPIM core module dependencies
    RequiredModules   = @(
        @{ModuleName='EasyPIM'; ModuleVersion='2.0.0'},
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
    Prerelease = 'beta1'
ReleaseNotes = @'
🚀 EasyPIM.Orchestrator v1.0.0-beta1 - Production-Ready Beta Release

MAJOR MILESTONE: Module separation and architectural improvements complete!

✅ NEW FEATURES:
- ARM API compatibility fixes (resolves InvalidResourceType/NoRegisteredProviderFound errors)
- Enhanced policy validation with proactive error detection and clear guidance
- Parameter standardization: 'principalId' (with 'assignee' alias for compatibility)
- Standalone orchestrator module with proper dependency management
- Auto-configuration of permanent assignment flags based on duration specifications

⚠️ BETA TESTING:
- Comprehensive testing completed but real-world validation needed
- Compatible with EasyPIM v2.0.0-beta1
- Report issues: https://github.com/kayasax/EasyPIM/issues
- Production use not recommended until stable release

📋 REQUIREMENTS:
- EasyPIM v2.0.0-beta1 (automatically installed)
- PowerShell 5.1+
- Az.Accounts, Microsoft.Graph modules
'@
    } }
}
