@{

# CI trigger: 2025-08-23 to force GH rebuild via PR (no functional change)

# Script module or binary module file associated with this manifest.
RootModule = 'EasyPIM.psm1'

# Version number of this module.
ModuleVersion = '2.0.28'

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
    'Microsoft.Graph.Authentication'
)

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# Note: Shared module removed in favor of internal function duplication approach
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
    'Copy-PIMEntraRoleEligibleAssignment'
    # Note: Orchestration (EPO*) functions are owned by EasyPIM.Orchestrator
)

# NOTE: As of v1.10.0, orchestrator/test shims (Invoke-EasyPIMOrchestrator, Test-PIMEndpointDiscovery, Test-PIMPolicyDrift) have been removed from the core module. Please use the EasyPIM.Orchestrator module for orchestrator/test functionality. See release notes and migration guide for details.

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

        # Promoted to stable release - removing prerelease designation
        # Prerelease = 'beta1'

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
    🚀 EasyPIM v2.0.0 - Major Architectural Milestone (2025-08-28):

    BREAKING CHANGES:
    - Module separation: EasyPIM.Orchestrator now available as standalone module
    - Parameter standardization: 'assignee' renamed to 'principalId' (alias provided for compatibility)
    - ARM API compatibility improvements may affect existing scripts

    ✅ NEW FEATURES:
    - ARM API fixes: Resolved InvalidResourceType and NoRegisteredProviderFound errors
    - Enhanced policy validation with proactive error detection and clear user guidance
    - Auto-configuration of permanent assignment flags based on duration specifications
    - Parameter consistency across all Azure resource assignment functions
    - Improved module dependency management

    🔧 TECHNICAL IMPROVEMENTS:
    - Fixed query parameter formatting in ARM API calls (eliminated double question marks)
    - Updated API versions to 2020-10-01-preview for endpoint compatibility
    - Enhanced error handling with actionable guidance for policy conflicts
    - Microsoft Graph session preservation during module imports

    📋 MIGRATION GUIDE:
    - Update scripts using 'assignee' parameter to 'principalId' (alias available for compatibility)
    - Install both EasyPIM and EasyPIM.Orchestrator for complete functionality
    - Test workflows thoroughly before production deployment

    Contributors: Loïc MICHEL (original author), Chase Dafnis (multi-cloud support)
    Docs: https://github.com/kayasax/EasyPIM/wiki
'@

    # Appended in 2.0.2 and 2.0.3
    AdditionalReleaseNotes = @'
    2.0.3 (2025-08-29)
    - Stable release polish: removed prerelease references; validated end-to-end scenario passes
    - E2E test improvements: auto-connect to Graph/Az, comprehensive policy options exercise (Step 14)
    - Docs/readme alignment for stable installs

    2.0.2 (2025-08-29)
    - Centralized business rules (MFA vs. Authentication Context) via internal Test-PIMPolicyBusinessRules
    - Drift detection aligned with policy-setting logic; PSCustomObject normalization
    - Fixed parameter parsing for requirements and booleans; improved Approver handling
    - Added end-to-end tests; lint fixes (trailing spaces); minor robustness improvements
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

