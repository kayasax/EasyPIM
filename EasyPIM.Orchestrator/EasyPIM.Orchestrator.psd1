@{
    RootModule        = 'EasyPIM.Orchestrator.psm1'
    ModuleVersion = '1.5.0'
    GUID              = 'b6f9b3c9-bc6a-4d4b-8c51-7c45d42157cd'
    Author            = 'Loïc MICHEL'
    CompanyName       = 'EasyPIM'
    Copyright         = '(c) Loïc MICHEL. All rights reserved.'
    Description       = 'PIM-as-Code orchestration for EasyPIM. Deploy role policies and assignments from JSON configuration files with WhatIf validation, delta mode for incremental changes, and drift detection. Automate PIM governance across Azure Resources, Entra Roles, and PIM Groups with reusable templates, CI/CD integration, and comprehensive audit trails. Turn configuration files into enforceable PIM state.'
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
        Tags = @('EasyPIM','Orchestrator','PIM-as-Code','Infrastructure-as-Code','GitOps','Automation','Drift-Detection','Configuration-Management','Azure','EntraID','RBAC','Governance')
        ProjectUri = 'https://kayasax.github.io/EasyPIM/template-guide.html'
        LicenseUri = 'https://github.com/kayasax/EasyPIM/blob/main/LICENSE'
ReleaseNotes = @'
EasyPIM.Orchestrator v1.5.0 - Performance & Drift Detection Overhaul

Added
- **Rich Return Object**: `Invoke-EasyPIMOrchestrator` now returns a detailed `PSCustomObject` containing success status, policy results, assignment results, and cleanup analysis, enabling better programmatic integration.
- **Cleanup Analysis**: `initial` mode now performs and displays a full cleanup analysis (showing exactly what would be removed) even in `WhatIf` mode.
- **Performance**: Implemented batch pre-fetching for assignments, significantly reducing Graph/ARM API calls during validation (O(1) vs O(N)).

Changed
- **Drift Output**: `WhatIf` output now explicitly reports "⚠️ [DRIFT]" instead of "✅ [OK]" when policy drift is detected.
- **Assignment Logging**: "Planned" assignments (those that would be created) are now clearly distinguished from "Existing" ones in the summary.
- **Idempotency**: Improved logic to correctly identify existing assignments in `WhatIf` mode, preventing false "Creating..." logs.

Previous releases:
v1.4.12 - Fix Drift Detection
'@
    } }
}
