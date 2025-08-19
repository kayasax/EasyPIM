@{

# Script module or binary module file associated with this manifest.
RootModule = 'EasyPIM.psm1'

# Version number of this module.
ModuleVersion = '1.9.1'

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

# Minimum version of the PowerShell engine required by this module
# PowerShellVersion = ''

# Name of the PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# ClrVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
 RequiredModules = @("Az.Accounts","Az.KeyVault", "Az.Resources")

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
# ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()

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
    'Test-PIMPolicyDrift'
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
v1.9.1 Release Notes:

✨ Authentication Context parity and reliability
- Added Authentication Context rule support across Set-*, Export/Import, and copy flows for Entra roles
- Implemented guard to automatically remove MFA from EndUser enablement when Authentication Context is enabled to avoid Graph conflict (MfaAndAcrsConflict)

🧰 Better Microsoft Graph error surfacing
- invoke-graph now captures error.code and error.message reliably, probing with -SkipHttpErrorCheck when needed
- Clear, concise exceptions: "Graph error (Status): Code - Reason | method=... url=... [reqBody]"
- Optional full error body logging via $EasyPIM_FullGraphError

🧹 Analyzer hygiene & fixes
- Eliminated empty catch blocks, corrected try/catch structure in invoke-graph
- Minor robustness improvements in import/copy paths

For docs and examples, see: https://github.com/kayasax/EasyPIM/wiki
'@

    # AdditionalReleaseNotes of this module
    # (Appended by fix/issue-121-followup)
    AdditionalReleaseNotes = @'
Configurable MFA/Auth Context conflict handling
- New global toggle: $global:EasyPIM_AutoResolveMfaAcrConflict (default: $true).
- When enabled, EasyPIM auto-removes MultiFactorAuthentication from EndUser enablement when AuthenticationContext_Enabled is true to avoid Graph error MfaAndAcrsConflict.
- Set to $false to keep MFA (Graph may reject the patch).
'@

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

