@{
    RootModule        = 'EasyPIM.Orchestrator.psm1'
    ModuleVersion = '1.4.10'
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
EasyPIM.Orchestrator v1.4.10 - Graph Scope Optimization

Improved
- Optimized Microsoft Graph authentication requirements: Graph scopes are now only required when operations include EntraRoles, GroupRoles, or All. Azure-only operations (AzureRoles) no longer require RoleManagement.ReadWrite.Directory permissions, reducing permission footprint for Azure RBAC-focused deployments.
- Enhanced authentication flow with clearer messaging about required scopes based on operation type.

Contributors
- @AzureStackNerd - Graph scope optimization (PR #225)

Previous releases:
v1.4.9 - Automation override token for protected roles in CI/CD
'@
    } }
}
