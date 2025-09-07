@{
    RootModule        = 'EasyPIM.Orchestrator.psm1'
    ModuleVersion = '1.3.6'
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
🚀 EasyPIM.Orchestrator v1.1.0 - Enhanced Stability Release

RECENT IMPROVEMENTS: Dependency optimization and reliability enhancements.

✅ UPDATES IN v1.1.1:
- 🆕 Template + Inline Override Merging: Full implementation of Issue #136 for all policy types
- 🏗️ Code Architecture Refactoring: Extracted helper functions to internal modules for better maintainability
- 🔍 Enhanced Drift Detection: Test-PIMPolicyDrift now uses orchestrator logic for consistency
- 📚 Comprehensive Documentation: Updated step-by-step guide with template + override examples
- ✅ Quality Standards: PSScriptAnalyzer compliant across all functions
- 🔧 New Internal Functions: Remove-JsonComments, Get-ResolvedPolicyObject, Test-IsProtectedRole, Convert-RequirementValue, Compare-PIMPolicy, Resolve-PolicyTemplate

✅ UPDATES IN v1.1.0:
- Dependency optimization: Removed unnecessary Microsoft.Graph.Identity.Governance requirement
- Enhanced module architecture with cleaner dependencies
- Improved reliability with CI/CD gallery version checking
- Support for protected roles override functionality (Issue #137)
- Compatible with latest EasyPIM core v2.0.5

✅ CORE FEATURES:
- Complete PIM orchestration via Invoke-EasyPIMOrchestrator
- Policy drift detection with Test-PIMPolicyDrift
- Endpoint discovery with Test-PIMEndpointDiscovery
- ARM API compatibility fixes for Azure resource roles
- Parameter standardization: 'principalId' (with 'assignee' alias for compatibility)
- Auto-configuration of permanent assignment flags based on duration specifications

📋 REQUIREMENTS:
- EasyPIM (latest stable version, automatically installed)
- PowerShell 5.1+
- Az.Accounts, Microsoft.Graph.Authentication modules
'@
    } }
}
