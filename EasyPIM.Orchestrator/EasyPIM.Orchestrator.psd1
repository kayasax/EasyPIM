@{
    RootModule        = 'EasyPIM.Orchestrator.psm1'
    ModuleVersion = '1.4.12'
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
EasyPIM.Orchestrator v1.4.11 - Fix Drift Detection

Fixed
- Resolved Issue #242: Fixed false positive drift detection in Test-PIMPolicyDrift where boolean values were being compared incorrectly (e.g. JSON 'true' vs API 'True').

Contributors
- @leighmo - Issue report
- @kayasax - Fix implementation

Previous releases:
v1.4.10 - Graph Scope Optimization
'@
    } }
}
