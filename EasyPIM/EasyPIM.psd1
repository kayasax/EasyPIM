@{

# CI trigger: 2025-08-23 to force GH rebuild via PR (no functional change)

# Script module or binary module file associated with this manifest.
RootModule = 'EasyPIM.psm1'

# Version number of this module.
ModuleVersion = '1.10.0'

# Supported PSEditions
# CompatiblePSEditions = @()

# ID used to uniquely identify this module
GUID = '634875e7-f904-423d-a6b1-69132684321c'

# Author of this module
Author = 'Loïc MICHEL'

# Company or vendor of this module
#CompanyName = 'MyCompany'

# Copyright statement for this module
Copyright = '(c) loicmichel. All rights reserved.'

# Description of the functionality provided by this module
Description = 'Manage PIM Azure Resource, PIM Entra role and PIM for Group settings and assignments with simplicity in mind'

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
# ScriptsToProcess intentionally left empty to simplify CI import path
# ScriptsToProcess = @('internal\\scripts\\Import-ModuleChecks.ps1')

# Modules that must be imported into the global environment prior to importing this module.
# Keep versions flexible; rely on gallery to resolve suitable versions.
RequiredModules = @(
    'Az.Accounts',
    'Microsoft.Graph.Authentication',
    'Microsoft.Graph.Identity.Governance'
)

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @()

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = @(
    "Import-PIMAzureResourcePolicy",
    "Get-PIMAzureResourcePolicy",
    "Set-PIMAzureResourcePolicy",
    "Copy-PIMAzureResourcePolicy",
    "Export-PIMAzureResourcePolicy",
    "Backup-PIMAzureResourcePolicy",
    "Get-PIMAzureResourceActiveAssignment",
    "Get-PIMAzureResourceEligibleAssignment",
    "New-PIMAzureResourceActiveAssignment",
    "New-PIMAzureResourceEligibleAssignment",
    "Remove-PIMAzureResourceEligibleAssignment",
    "Remove-PIMAzureResourceActiveAssignment",
    "Get-PIMEntraRolePolicy",
    "Export-PIMEntraRolePolicy",
    "Import-PIMEntraRolePolicy",
    "Set-PIMEntraRolePolicy",
    "Backup-PIMEntraRolePolicy",
    "Copy-PIMEntraRolePolicy",
    "Get-PIMEntraRoleActiveAssignment",
    "Get-PIMEntraRoleEligibleAssignment",
    "New-PIMEntraRoleActiveAssignment",
    "New-PIMEntraRoleEligibleAssignment",
    'Remove-PIMEntraRoleActiveAssignment',
    'Remove-PIMEntraRoleEligibleAssignment',
    "Get-PIMGroupPolicy",
    "Set-PIMGroupPolicy",
    "Get-PIMGroupActiveAssignment",
    "Get-PIMGroupEligibleAssignment",
    'New-PIMGroupActiveAssignment',
    'New-PIMGroupEligibleAssignment',
    'Remove-PIMGroupActiveAssignment',
    'Remove-PIMGroupEligibleAssignment',
    'Show-PIMReport',
    'Get-PIMAzureResourcePendingApproval',
    'Approve-PIMAzureResourcePendingApproval',
    'Deny-PIMAzureResourcePendingApproval',
    'Get-PIMEntraRolePendingApproval',
    'Approve-PIMEntraRolePendingApproval',
    'Deny-PIMEntraRolePendingApproval',
    'Get-PIMGroupPendingApproval',
    'Approve-PIMGroupPendingApproval',
    'Deny-PIMGroupPendingApproval',
    'Copy-PIMAzureResourceEligibleAssignment',
    'Copy-PIMEntraRoleEligibleAssignment',
    'Invoke-EasyPIMOrchestrator',
    'Get-EasyPIMConfiguration',
    'Test-PIMPolicyDrift',
    'Test-PIMEndpointDiscovery'
)

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
# CmdletsToExport = '*'

# Variables to export from this module
# VariablesToExport = '*'

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
# AliasesToExport = '*'

# DSC resources to export from this module
# DscResourcesToExport = @()

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
# FileList = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = @("Azure","PIM","EntraID","PrivilegedIdentityManagement")

        # A URL to the license for this module.
        LicenseUri = 'https://github.com/kayasax/EasyPIM/blob/main/LICENSE'

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/kayasax/EasyPIM/'

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
    ReleaseNotes = @'
    v1.10.0 Release Notes (2025-08-23):

    Multi-cloud Azure environment support (Chase Dafnis)
    - Enhanced Get-PIMAzureEnvironmentEndpoint for multi-cloud environments (Commercial, US Government, China, Germany)
    - Added comprehensive endpoint discovery and validation for all Azure cloud environments
    - Improved custom dependency management with Test-EasyPIMDependencies function.

    v1.9.4 Release Notes (2025-08-22):

    Group policy PATCH stability
    - Filter out null rule entries before PATCH to avoid Graph schema errors (rules: [ null ]).
    - Re-filter during per-rule isolation; isolation triggers only after a global PATCH failure.
    - Policy summary now increments Failed on apply errors (no false "Applied" on error paths).

    Diagnostics
    - Clearer isolation output (rule index, id, and type), retains body preview on failures.

    Notes: This is a patch-only release. No public API changes.

    v1.9.3 Release Notes (2025-08-21):

    Entra policy stability and correctness
    - Fixed unifiedRoleManagementPolicyApprovalRule payloads to use Graph subject sets (@odata.type + userId/groupId).
    - Normalized eligibility durations: convert PnY to day-based (PnD) and only include maximumDuration when expirationRequired=true.
    - Improved InvalidPolicy diagnostics with per-rule isolation and PATCH body previews.

    Authentication Context harmonization
    - When Authentication Context is enabled for a role, MFA is always stripped from EndUser enablement to avoid MfaAndAcrsConflict.
    - Still emit enablement rule to clear any prior MFA settings.

    Notifications
    - Flattened template properties and fixed boolean handling (.ToString().ToLower()) to prevent crashes.

    Contributors: Loïc MICHEL (original author), Chase Dafnis (multi-cloud / Azure environment support)
    Docs: https://github.com/kayasax/EasyPIM/wiki
'@

    # AdditionalReleaseNotes of this module
    # (Appended by fix/issue-121-followup)
    # AdditionalReleaseNotes removed; MFA is always removed when Authentication Context is enabled to avoid conflicts.

        # Prerelease string of this module
        # Prerelease = ''

        # Flag to indicate whether the module requires explicit user acceptance for install/update/save
        # RequireLicenseAcceptance = $false

        # External dependent modules of this module
        # ExternalModuleDependencies = @()

    } # End of PSData hashtable

} # End of PrivateData hashtable

# HelpInfo URI of this module
HelpInfoURI = 'https://github.com/kayasax/EasyPIM/wiki/Documentation'

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}

