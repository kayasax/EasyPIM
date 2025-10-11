# Shared business rule validation for PIM policies
# This function contains the unified logic for handling Authentication Context vs MFA conflicts
# and other business rules that apply to both policy setting and drift detection.

function Test-PIMPolicyBusinessRules {
    <#
    .SYNOPSIS
    Validates and adjusts PIM policy settings according to Microsoft Graph API business rules.

    .DESCRIPTION
    This function applies the same business rule logic used by Set-PIMEntraRolePolicy
    to ensure drift detection and policy setting use identical conflict resolution.

    .PARAMETER PolicySettings
    The policy settings object to validate/adjust

    .PARAMETER CurrentPolicy
    The current live policy (for checking existing Authentication Context)

    .PARAMETER ApplyAdjustments
    If true, automatically adjusts conflicting settings. If false, only reports conflicts.

    .OUTPUTS
    PSCustomObject with properties:
    - AdjustedSettings: The policy settings with conflicts resolved
    - Conflicts: Array of detected conflicts
    - HasChanges: Boolean indicating if adjustments were made
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$PolicySettings,

        [Parameter()]
        [object]$CurrentPolicy,

        [Parameter()]
        [switch]$ApplyAdjustments
    )

    $conflicts = @()
    $hasChanges = $false
    $adjustedSettings = $PolicySettings.PSObject.Copy()

    # Rule 1: Authentication Context vs MFA Conflict
    $authContextEnabled = $false

    # Check if Authentication Context is enabled in requested settings
    if ($PolicySettings.PSObject.Properties['AuthenticationContext_Enabled']) {
        $authContextEnabled = ($PolicySettings.AuthenticationContext_Enabled -eq $true)
    }
    # Check if Authentication Context is enabled in current policy
    elseif ($CurrentPolicy) {
        $authContextProps = @('AuthenticationContext_Enabled', 'authenticationContextClassReferences', 'authenticationContext', 'AuthenticationContextEnabled')
        foreach ($prop in $authContextProps) {
            if ($CurrentPolicy.PSObject.Properties[$prop] -and $CurrentPolicy.$prop) {
                $authContextEnabled = $true
                break
            }
        }
    }

    # Check ActivationRequirement for MFA conflicts
    if ($PolicySettings.PSObject.Properties['ActivationRequirement']) {
        $requirements = $PolicySettings.ActivationRequirement

        # Normalize to array if comma-separated string
        if ($requirements -is [string] -and $requirements -match ',') {
            $requirements = $requirements -split ',' | ForEach-Object { $_.Trim() }
        }

        if ($requirements -is [string]) {
            $requirements = @($requirements)
        } elseif ($requirements -isnot [System.Collections.IEnumerable]) {
            $requirements = @($requirements)
        }

        if ($authContextEnabled -and $requirements -and ($requirements -contains 'MultiFactorAuthentication')) {
            $conflicts += @{
                Field = 'ActivationRequirement'
                Type = 'AuthenticationContextMfaConflict'
                Message = 'Authentication Context is enabled. MultiFactorAuthentication requirement will be automatically removed to avoid MfaAndAcrsConflict.'
                OriginalValue = $requirements
                AdjustedValue = @($requirements | Where-Object { $_ -ne 'MultiFactorAuthentication' })
            }

            if ($ApplyAdjustments) {
                $adjustedSettings.ActivationRequirement = @($requirements | Where-Object { $_ -ne 'MultiFactorAuthentication' })
                $hasChanges = $true
            }
        }

        if ($requirements -and ($requirements -contains 'AuthenticationContext')) {
            $conflicts += @{
                Field = 'ActivationRequirement'
                Type = 'AuthenticationContextInvalidValue'
                Message = "ActivationRequirement contains 'AuthenticationContext', which is controlled by AuthenticationContext_Enabled/Value. The entry will be removed."
                OriginalValue = $requirements
                AdjustedValue = @($requirements | Where-Object { $_ -ne 'AuthenticationContext' })
            }

            if ($ApplyAdjustments) {
                $adjustedSettings.ActivationRequirement = @($requirements | Where-Object { $_ -ne 'AuthenticationContext' })
                $hasChanges = $true
            }
        }
    }

    # Check ActiveAssignmentRequirement for MFA conflicts
    if ($PolicySettings.PSObject.Properties['ActiveAssignmentRequirement']) {
        $requirements = $PolicySettings.ActiveAssignmentRequirement

        # Normalize to array if comma-separated string
        if ($requirements -is [string] -and $requirements -match ',') {
            $requirements = $requirements -split ',' | ForEach-Object { $_.Trim() }
        }

        if ($requirements -is [string]) {
            $requirements = @($requirements)
        } elseif ($requirements -isnot [System.Collections.IEnumerable]) {
            $requirements = @($requirements)
        }

        if ($authContextEnabled -and $requirements -and ($requirements -contains 'MultiFactorAuthentication')) {
            $conflicts += @{
                Field = 'ActiveAssignmentRequirement'
                Type = 'AuthenticationContextMfaConflict'
                Message = 'Authentication Context is enabled. MultiFactorAuthentication requirement will be automatically removed to avoid MfaAndAcrsConflict.'
                OriginalValue = $requirements
                AdjustedValue = @($requirements | Where-Object { $_ -ne 'MultiFactorAuthentication' })
            }

            if ($ApplyAdjustments) {
                $adjustedSettings.ActiveAssignmentRequirement = @($requirements | Where-Object { $_ -ne 'MultiFactorAuthentication' })
                $hasChanges = $true
            }
        }

        if ($requirements -and ($requirements -contains 'AuthenticationContext')) {
            $conflicts += @{
                Field = 'ActiveAssignmentRequirement'
                Type = 'AuthenticationContextInvalidValue'
                Message = "ActiveAssignmentRequirement contains 'AuthenticationContext', which is controlled by AuthenticationContext_Enabled/Value. The entry will be removed."
                OriginalValue = $requirements
                AdjustedValue = @($requirements | Where-Object { $_ -ne 'AuthenticationContext' })
            }

            if ($ApplyAdjustments) {
                $adjustedSettings.ActiveAssignmentRequirement = @($requirements | Where-Object { $_ -ne 'AuthenticationContext' })
                $hasChanges = $true
            }
        }
    }

    # Future: Add more business rules here as they are discovered
    # Rule 2: Other potential conflicts...

    return [PSCustomObject]@{
        AdjustedSettings = $adjustedSettings
        Conflicts = $conflicts
        HasChanges = $hasChanges
        AuthenticationContextEnabled = $authContextEnabled
    }
}
