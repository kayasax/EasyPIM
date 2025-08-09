#Requires -Version 5.1

# PSScriptAnalyzer suppressions for this internal policy orchestration file
# This module contains Write-Host calls for user interaction which are intentional
# The "Policies" plural naming is intentional as it manages multiple policies collectively

function New-EasyPIMPolicies {
    <#
    .SYNOPSIS
        Applies PIM policy configuration from the processed configuration.

    .DESCRIPTION
        This function applies policy configurations for Azure Resources, Entra Roles, and Groups
        using the existing Import-PIM*Policy functions.

    .PARAMETER Config
        The processed configuration object containing resolved policy definitions

    .PARAMETER TenantId
        The Azure AD tenant ID

    .PARAMETER SubscriptionId
        The Azure subscription ID (required for Azure role policies)

    .PARAMETER PolicyMode
        The policy application mode: validate, delta, or initial

    .EXAMPLE
        $results = New-EasyPIMPolicies -Config $processedConfig -TenantId $tenantId -SubscriptionId $subscriptionId

    .NOTES
        Author: Loic MICHEL
        Homepage: https://github.com/kayasax/EasyPIM
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config,

        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $false)]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $false)]
        [ValidateSet("validate", "delta", "initial")]
        [string]$PolicyMode = "validate"
    )

    Write-Verbose "Starting New-EasyPIMPolicies in $PolicyMode mode"

    $results = @{
        AzureRolePolicies = @()
        EntraRolePolicies = @()
        GroupPolicies = @()
        Errors = @()
        Summary = @{
            TotalProcessed = 0
            Successful = 0
            Failed = 0
            Skipped = 0
        }
    }

    try {
        # Process Azure Role Policies
        if ($Config.PSObject.Properties['AzureRolePolicies'] -and $Config.AzureRolePolicies -and $Config.AzureRolePolicies.Count -gt 0) {
            # Build detailed WhatIf message for Azure Role Policies
            $whatIfDetails = @()
            foreach ($policyDef in $Config.AzureRolePolicies) {
                # Use resolved policy values if available, otherwise fall back to top-level properties
                $resolvedPolicy = if ($policyDef.ResolvedPolicy) { $policyDef.ResolvedPolicy } else { $policyDef }

                $policyDetails = @(
                    "Role: '$($policyDef.RoleName)'"
                    "Scope: '$($policyDef.Scope)'"
                    "Activation Duration: $($resolvedPolicy.ActivationDuration)"
                    "MFA Required: $(if ($resolvedPolicy.ActivationRequirement -match 'MFA') { 'Yes' } else { 'No' })"
                    "Justification Required: $(if ($resolvedPolicy.ActivationRequirement -match 'Justification') { 'Yes' } else { 'No' })"
                    "Approval Required: $($resolvedPolicy.ApprovalRequired)"
                )

                if ($resolvedPolicy.ApprovalRequired -and $resolvedPolicy.PSObject.Properties['Approvers'] -and $resolvedPolicy.Approvers) {
                    $approverList = $resolvedPolicy.Approvers | ForEach-Object { "$($_.description) ($($_.id))" }
                    $policyDetails += "Approvers: $($approverList -join ', ')"
                }

                if ($resolvedPolicy.PSObject.Properties['AuthenticationContext_Enabled'] -and $resolvedPolicy.AuthenticationContext_Enabled) {
                    $policyDetails += "Authentication Context: $($resolvedPolicy.AuthenticationContext_Value)"
                }

                $policyDetails += "Max Eligibility: $($resolvedPolicy.MaximumEligibilityDuration)"
                $policyDetails += "Permanent Eligibility: $(if ($resolvedPolicy.AllowPermanentEligibility) { 'Allowed' } else { 'Not Allowed' })"

                $whatIfDetails += "    * $($policyDetails -join ' | ')"
            }

            $whatIfMessage = "Apply Azure Role Policy configurations:`n$($whatIfDetails -join "`n")"

            if ($PSCmdlet.ShouldProcess($whatIfMessage, "Azure Role Policies")) {
                Write-Host "[PROC] Processing Azure Role Policies..." -ForegroundColor Cyan

                if (-not $SubscriptionId) {
                    $errorMsg = "SubscriptionId is required for Azure Role Policies"
                    Write-Error $errorMsg
                    $results.Errors += $errorMsg
                }
                else {
                    foreach ($policyDef in $Config.AzureRolePolicies) {
                        $results.Summary.TotalProcessed++

                        try {
                            $policyResult = Set-AzureRolePolicy -PolicyDefinition $policyDef -TenantId $TenantId -SubscriptionId $SubscriptionId -Mode $PolicyMode
                            $results.AzureRolePolicies += $policyResult

                            # Check if role was protected
                            if ($policyResult.Status -like "*Protected*") {
                                $results.Summary.Skipped++
                                Write-Host "  [PROTECTED] Protected Azure role '$($policyDef.RoleName)' - policy change blocked for security" -ForegroundColor Yellow
                            } else {
                                $results.Summary.Successful++
                                if ($PolicyMode -eq "validate") {
                                    Write-Host "  [OK] Validated policy for role '$($policyDef.RoleName)' at scope '$($policyDef.Scope)' (no changes applied)" -ForegroundColor Green
                                } else {
                                    Write-Host "  [OK] Applied policy for role '$($policyDef.RoleName)' at scope '$($policyDef.Scope)'" -ForegroundColor Green
                                }
                            }
                        }
                        catch {
                            $errorMsg = "Failed to apply Azure role policy for '$($policyDef.RoleName)': $($_.Exception.Message)"
                            Write-Error $errorMsg
                            $results.Errors += $errorMsg
                            $results.Summary.Failed++
                        }
                    }
                }
            } else {
                Write-Host "[WARNING] Skipping Azure Role Policies processing due to WhatIf" -ForegroundColor Yellow
                Write-Host "   Would have applied the following policy configurations:" -ForegroundColor Yellow
                foreach ($line in $whatIfDetails) {
                    Write-Host "   $line" -ForegroundColor Yellow
                }
                $results.Summary.Skipped += $Config.AzureRolePolicies.Count
            }
        }

        # Process Entra Role Policies
        if ($Config.PSObject.Properties['EntraRolePolicies'] -and $Config.EntraRolePolicies -and $Config.EntraRolePolicies.Count -gt 0) {
            # Build detailed WhatIf message for Entra Role Policies
            $whatIfDetails = @()
            foreach ($policyDef in $Config.EntraRolePolicies) {
                # Access the resolved policy configuration
                $policy = $policyDef.ResolvedPolicy
                if (-not $policy) {
                    $policy = $policyDef
                }

                $policyDetails = @(
                    "Role: '$($policyDef.RoleName)'"
                )

                # Add activation duration
                if ($policy.PSObject.Properties['ActivationDuration'] -and $policy.ActivationDuration) {
                    $policyDetails += "Activation Duration: $($policy.ActivationDuration)"
                } else {
                    $policyDetails += "Activation Duration: Not specified"
                }

                # Check activation requirements

                $requirements = @()
                if ($policy.PSObject.Properties['ActivationRequirement'] -and $policy.ActivationRequirement) {
                    if ($policy.ActivationRequirement -match 'MultiFactorAuthentication' -or $policy.ActivationRequirement -match 'MFA') { $requirements += 'MultiFactorAuthentication' }
                    if ($policy.ActivationRequirement -match 'Justification') { $requirements += 'Justification' }
                }
                $policyDetails += "Requirements: $(if ($requirements) { $requirements -join ', ' } else { 'None' })"

                # Add approval requirement and warn if missing approvers
                if ($policy.PSObject.Properties['ApprovalRequired'] -and $null -ne $policy.ApprovalRequired) {
                    $policyDetails += "Approval Required: $($policy.ApprovalRequired)"

                    if ($policy.ApprovalRequired) {
                        if ($policy.PSObject.Properties['Approvers'] -and $policy.Approvers) {
                            $approverList = $policy.Approvers | ForEach-Object {
                                if ($_.PSObject.Properties['description'] -and $_.PSObject.Properties['id']) {
                                    "$($_.description) ($($_.id))"
                                } else {
                                    "$_"
                                }
                            }
                            $policyDetails += "Approvers: $($approverList -join ', ')"
                        } else {
                            $policyDetails += "[WARNING: ApprovalRequired is true but no Approvers specified!]"
                        }
                    }
                } else {
                    $policyDetails += "Approval Required: Not specified"
                }

                # Add authentication context
                if ($policy.PSObject.Properties['AuthenticationContext_Enabled'] -and $policy.AuthenticationContext_Enabled -and
                    $policy.PSObject.Properties['AuthenticationContext_Value'] -and $policy.AuthenticationContext_Value) {
                    $policyDetails += "Authentication Context: $($policy.AuthenticationContext_Value)"
                }

                # Add eligibility settings
                if ($policy.PSObject.Properties['MaximumEligibilityDuration'] -and $policy.MaximumEligibilityDuration) {
                    $policyDetails += "Max Eligibility: $($policy.MaximumEligibilityDuration)"
                }

                if ($policy.PSObject.Properties['AllowPermanentEligibility'] -and $null -ne $policy.AllowPermanentEligibility) {
                    $policyDetails += "Permanent Eligibility: $(if ($policy.AllowPermanentEligibility) { 'Allowed' } else { 'Not Allowed' })"
                }

                $whatIfDetails += "    * $($policyDetails -join ' | ')"
            }

            $whatIfMessage = "Apply Entra Role Policy configurations:`n$($whatIfDetails -join "`n")"

            if ($PSCmdlet.ShouldProcess($whatIfMessage, "Entra Role Policies")) {
                Write-Host "[PROC] Processing Entra Role Policies..." -ForegroundColor Cyan

                foreach ($policyDef in $Config.EntraRolePolicies) {
                    $results.Summary.TotalProcessed++

                    try {
                        $policyResult = Set-EntraRolePolicy -PolicyDefinition $policyDef -TenantId $TenantId -Mode $PolicyMode
                        $results.EntraRolePolicies += $policyResult

                        # Check if role was protected
                        if ($policyResult.Status -like "*Protected*") {
                            $results.Summary.Skipped++
                            Write-Host "  [PROTECTED] Protected role '$($policyDef.RoleName)' - policy change blocked for security" -ForegroundColor Yellow
                        } else {
                            $results.Summary.Successful++
                            if ($PolicyMode -eq "validate") {
                                Write-Host "  [OK] Validated policy for Entra role '$($policyDef.RoleName)' (no changes applied)" -ForegroundColor Green
                            } else {
                                Write-Host "  [OK] Applied policy for Entra role '$($policyDef.RoleName)'" -ForegroundColor Green
                            }
                        }
                    }
                    catch {
                        $errorMsg = "Failed to apply Entra role policy for '$($policyDef.RoleName)': $($_.Exception.Message)"
                        Write-Error $errorMsg
                        $results.Errors += $errorMsg
                        $results.Summary.Failed++
                    }
                }
            } else {
                Write-Host "[WARNING] Skipping Entra Role Policies processing due to WhatIf" -ForegroundColor Yellow
                Write-Host "   Would have applied the following policy configurations:" -ForegroundColor Yellow
                foreach ($line in $whatIfDetails) {
                    Write-Host "   $line" -ForegroundColor Yellow
                }
                $results.Summary.Skipped += $Config.EntraRolePolicies.Count
            }
        }

        # Process Group Policies
        if ($Config.PSObject.Properties['GroupPolicies'] -and $Config.GroupPolicies -and $Config.GroupPolicies.Count -gt 0) {
            # Build detailed WhatIf message for Group Policies
            $whatIfDetails = @()
            foreach ($policyDef in $Config.GroupPolicies) {
                # Use resolved policy values if available, otherwise fall back to top-level properties
                $resolvedPolicy = if ($policyDef.ResolvedPolicy) { $policyDef.ResolvedPolicy } else { $policyDef }

                $policyDetails = @(
                    "Group ID: '$($policyDef.GroupId)'"
                    "Role: '$($policyDef.RoleName)'"
                    "Activation Duration: $($resolvedPolicy.ActivationDuration)"
                    "MFA Required: $(if ($resolvedPolicy.ActivationRequirement -match 'MFA') { 'Yes' } else { 'No' })"
                    "Justification Required: $(if ($resolvedPolicy.ActivationRequirement -match 'Justification') { 'Yes' } else { 'No' })"
                    "Approval Required: $($resolvedPolicy.ApprovalRequired)"
                )

                if ($resolvedPolicy.ApprovalRequired -and $resolvedPolicy.PSObject.Properties['Approvers'] -and $resolvedPolicy.Approvers) {
                    $approverList = $resolvedPolicy.Approvers | ForEach-Object { "$($_.description) ($($_.id))" }
                    $policyDetails += "Approvers: $($approverList -join ', ')"
                }

                if ($resolvedPolicy.PSObject.Properties['AuthenticationContext_Enabled'] -and $resolvedPolicy.AuthenticationContext_Enabled) {
                    $policyDetails += "Authentication Context: $($resolvedPolicy.AuthenticationContext_Value)"
                }

                $policyDetails += "Max Eligibility: $($resolvedPolicy.MaximumEligibilityDuration)"
                $policyDetails += "Permanent Eligibility: $(if ($resolvedPolicy.AllowPermanentEligibility) { 'Allowed' } else { 'Not Allowed' })"

                $whatIfDetails += "    * $($policyDetails -join ' | ')"
            }

            $whatIfMessage = "Apply Group Policy configurations:`n$($whatIfDetails -join "`n")"

            if ($PSCmdlet.ShouldProcess($whatIfMessage, "Group Policies")) {
                Write-Host "[PROC] Processing Group Policies..." -ForegroundColor Cyan

                foreach ($policyDef in $Config.GroupPolicies) {
                    $results.Summary.TotalProcessed++

                    try {
                        $policyResult = Set-GroupPolicy -PolicyDefinition $policyDef -TenantId $TenantId -Mode $PolicyMode
                        $results.GroupPolicies += $policyResult

                        # Check if role was protected
                        if ($policyResult.Status -like "*Protected*") {
                            $results.Summary.Skipped++
                            Write-Host "  [PROTECTED] Protected Group '$($policyDef.GroupId)' role '$($policyDef.RoleName)' - policy change blocked for security" -ForegroundColor Yellow
                        } else {
                            $results.Summary.Successful++
                            if ($PolicyMode -eq "validate") {
                                Write-Host "  [OK] Validated policy for Group '$($policyDef.GroupId)' role '$($policyDef.RoleName)' (no changes applied)" -ForegroundColor Green
                            } else {
                                Write-Host "  [OK] Applied policy for Group '$($policyDef.GroupId)' role '$($policyDef.RoleName)'" -ForegroundColor Green
                            }
                        }
                    }
                    catch {
                        $errorMsg = "Failed to apply Group policy for '$($policyDef.GroupId)' role '$($policyDef.RoleName)': $($_.Exception.Message)"
                        Write-Error $errorMsg
                        $results.Errors += $errorMsg
                        $results.Summary.Failed++
                    }
                }
            } else {
                Write-Host "[WARNING] Skipping Group Policies processing due to WhatIf" -ForegroundColor Yellow
                Write-Host "   Would have applied the following policy configurations:" -ForegroundColor Yellow
                foreach ($line in $whatIfDetails) {
                    Write-Host "   $line" -ForegroundColor Yellow
                }
                $results.Summary.Skipped += $Config.GroupPolicies.Count
            }
        }

        Write-Verbose "New-EasyPIMPolicies completed. Processed: $($results.Summary.TotalProcessed), Successful: $($results.Summary.Successful), Failed: $($results.Summary.Failed)"
        return $results
    }
    catch {
        Write-Error "Failed to process PIM policies: $($_.Exception.Message)"
        throw
    }
}

function Set-AzureRolePolicy {
    <#
    .SYNOPSIS
        Applies a single Azure role policy.

    .DESCRIPTION
        This function applies an Azure role policy by converting the policy definition to CSV format
        and using the existing Import-PIMAzureResourcePolicy function.

    .PARAMETER PolicyDefinition
        The resolved policy definition

    .PARAMETER TenantId
        The Azure AD tenant ID

    .PARAMETER SubscriptionId
        The Azure subscription ID

    .PARAMETER Mode
        The application mode
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$PolicyDefinition,

        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $true)]
        [string]$Mode
    )

    Write-Verbose "Applying Azure role policy for $($PolicyDefinition.RoleName) at $($PolicyDefinition.Scope)"

    # Define critical Azure roles that should be protected
    $protectedAzureRoles = @(
        "Owner",
        "User Access Administrator"
    )

    # Check if this is a protected Azure role
    if ($protectedAzureRoles -contains $PolicyDefinition.RoleName) {
        $warningMsg = "[WARNING] PROTECTED AZURE ROLE: '$($PolicyDefinition.RoleName)' is a critical role. Policy changes are blocked for security."
        Write-Warning $warningMsg
        Write-Host "[PROTECTED] Protected Azure role '$($PolicyDefinition.RoleName)' - policy change blocked" -ForegroundColor Yellow

        return @{
            RoleName = $PolicyDefinition.RoleName
            Scope = $PolicyDefinition.Scope
            Status = "Protected (No Changes)"
            Mode = $Mode
            Details = "Azure role is protected from policy changes for security reasons"
        }
    }

    if ($Mode -eq "validate") {
        Write-Verbose "Validation mode: Policy would be applied for role '$($PolicyDefinition.RoleName)'"

        # Show policy details that would be applied
        $policy = $PolicyDefinition.ResolvedPolicy
        Write-Host "[INFO] Policy Changes for Azure Role '$($PolicyDefinition.RoleName)' at '$($PolicyDefinition.Scope)':" -ForegroundColor Cyan
        Write-Host "   [TIME] Activation Duration: $($policy.ActivationDuration)" -ForegroundColor Yellow
        Write-Host "   [LOCK] Activation Requirements: $($policy.ActivationRequirement)" -ForegroundColor Yellow
        if ($policy.ActiveAssignmentRequirement) {
            Write-Host "   [SECURE] Active Assignment Requirements: $($policy.ActiveAssignmentRequirement)" -ForegroundColor Yellow
        }
        Write-Host "   [OK] Approval Required: $($policy.ApprovalRequired)" -ForegroundColor Yellow
        if ($policy.Approvers -and $policy.ApprovalRequired -eq $true) {
            Write-Host "   [USERS] Approvers: $($policy.Approvers.Count) configured" -ForegroundColor Yellow
        }
        Write-Host "   [TARGET] Max Eligibility Duration: $($policy.MaximumEligibilityDuration)" -ForegroundColor Yellow
        Write-Host "   [FAST] Max Active Duration: $($policy.MaximumActiveAssignmentDuration)" -ForegroundColor Yellow

        # Count notification settings
        $notificationCount = 0
        $policy.PSObject.Properties | Where-Object { $_.Name -like "Notification_*" } | ForEach-Object { $notificationCount++ }
        if ($notificationCount -gt 0) {
            Write-Host "   [EMAIL] Notification Settings: $notificationCount configured" -ForegroundColor Yellow
        }

        Write-Host "   [WARNING]  NOTE: No changes applied in validation mode" -ForegroundColor Magenta

        return @{
            RoleName = $PolicyDefinition.RoleName
            Scope = $PolicyDefinition.Scope
            Status = "Validated (No Changes Applied)"
            Mode = $Mode
            Details = "Policy validation completed - changes would be applied in delta/initial mode"
        }
    }

    # Convert policy to CSV format and create temporary file
    $csvData = ConvertTo-PolicyCSV -Policy $PolicyDefinition.ResolvedPolicy -PolicyType "AzureRole" -RoleName $PolicyDefinition.RoleName -Scope $PolicyDefinition.Scope
    $tempCsvPath = [System.IO.Path]::GetTempFileName() + ".csv"

    try {
        $csvData | Export-Csv -Path $tempCsvPath -NoTypeInformation

        if ($PSCmdlet.ShouldProcess("Azure role policy for $($PolicyDefinition.RoleName)", "Apply policy")) {
            # Use existing Import-PIMAzureResourcePolicy function
            Import-PIMAzureResourcePolicy -tenantID $TenantId -path $tempCsvPath
        }

        return @{
            RoleName = $PolicyDefinition.RoleName
            Scope = $PolicyDefinition.Scope
            Status = "Applied"
            Mode = $Mode
        }
    }
    finally {
        # Clean up temporary file
        if (Test-Path $tempCsvPath) {
            Remove-Item $tempCsvPath -Force
        }
    }
}

function Set-EntraRolePolicy {
    <#
    .SYNOPSIS
        Applies a single Entra role policy.

    .DESCRIPTION
        This function applies an Entra role policy by converting the policy definition to CSV format
        and using the existing Import-PIMEntraRolePolicy function.

    .PARAMETER PolicyDefinition
        The resolved policy definition

    .PARAMETER TenantId
        The Azure AD tenant ID

    .PARAMETER Mode
        The application mode
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$PolicyDefinition,

        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $true)]
        [string]$Mode
    )

    Write-Verbose "Applying Entra role policy for $($PolicyDefinition.RoleName)"

    # Define critical roles that should be protected from policy changes
    $protectedRoles = @(
        "Global Administrator",
        "Privileged Role Administrator",
        "Security Administrator",
        "User Access Administrator"
    )

    # Check if this is a protected role
    if ($protectedRoles -contains $PolicyDefinition.RoleName) {
        $warningMsg = "[WARNING] PROTECTED ROLE: '$($PolicyDefinition.RoleName)' is a critical role. Policy changes are blocked for security."
        Write-Warning $warningMsg
        Write-Host "[PROTECTED] Protected role '$($PolicyDefinition.RoleName)' - policy change blocked" -ForegroundColor Yellow

        return @{
            RoleName = $PolicyDefinition.RoleName
            Status = "Protected (No Changes)"
            Mode = $Mode
            Details = "Role is protected from policy changes for security reasons"
        }
    }

    if ($Mode -eq "validate") {
        Write-Verbose "Validation mode: Policy would be applied for Entra role '$($PolicyDefinition.RoleName)'"

        # Show policy details that would be applied
        $policy = $PolicyDefinition.ResolvedPolicy
        Write-Host "[INFO] Policy Changes for Entra Role '$($PolicyDefinition.RoleName)':" -ForegroundColor Cyan
        Write-Host "   [TIME] Activation Duration: $($policy.ActivationDuration)" -ForegroundColor Yellow
        Write-Host "   [LOCK] Activation Requirements: $($policy.ActivationRequirement)" -ForegroundColor Yellow
        if ($policy.ActiveAssignmentRequirement) {
            Write-Host "   [SECURE] Active Assignment Requirements: $($policy.ActiveAssignmentRequirement)" -ForegroundColor Yellow
        }
        Write-Host "   [OK] Approval Required: $($policy.ApprovalRequired)" -ForegroundColor Yellow
        if ($policy.Approvers -and $policy.ApprovalRequired -eq $true) {
            Write-Host "   [USERS] Approvers: $($policy.Approvers.Count) configured" -ForegroundColor Yellow
        }
        Write-Host "   [TARGET] Max Eligibility Duration: $($policy.MaximumEligibilityDuration)" -ForegroundColor Yellow
        Write-Host "   [FAST] Max Active Duration: $($policy.MaximumActiveAssignmentDuration)" -ForegroundColor Yellow
        if ($policy.AuthenticationContext_Enabled -eq $true) {
            Write-Host "   [PROTECTED] Auth Context: $($policy.AuthenticationContext_Value)" -ForegroundColor Yellow
        }

        # Count notification settings
        $notificationCount = 0
        $policy.PSObject.Properties | Where-Object { $_.Name -like "Notification_*" } | ForEach-Object { $notificationCount++ }
        if ($notificationCount -gt 0) {
            Write-Host "   [EMAIL] Notification Settings: $notificationCount configured" -ForegroundColor Yellow
        }

        Write-Host "   [WARNING]  NOTE: No changes applied in validation mode" -ForegroundColor Magenta

        return @{
            RoleName = $PolicyDefinition.RoleName
            Status = "Validated (No Changes Applied)"
            Mode = $Mode
            Details = "Policy validation completed - changes would be applied in delta/initial mode"
        }
    }

    # Convert policy to CSV format and create temporary file
    $csvData = ConvertTo-PolicyCSV -Policy $PolicyDefinition.ResolvedPolicy -PolicyType "EntraRole" -RoleName $PolicyDefinition.RoleName
    $tempCsvPath = [System.IO.Path]::GetTempFileName() + ".csv"

    try {
        $csvData | Export-Csv -Path $tempCsvPath -NoTypeInformation

        if ($PSCmdlet.ShouldProcess("Entra role policy for $($PolicyDefinition.RoleName)", "Apply policy")) {
            # Use existing Import-PIMEntraRolePolicy function
            Import-PIMEntraRolePolicy -tenantID $TenantId -path $tempCsvPath
        }

        return @{
            RoleName = $PolicyDefinition.RoleName
            Status = "Applied"
            Mode = $Mode
        }
    }
    finally {
        # Clean up temporary file
        if (Test-Path $tempCsvPath) {
            Remove-Item $tempCsvPath -Force
        }
    }
}

function Set-GroupPolicy {
    <#
    .SYNOPSIS
        Applies a single Group policy.

    .DESCRIPTION
        This function applies a Group policy. Note: Group policy import functionality
        may need to be implemented if not available in existing functions.

    .PARAMETER PolicyDefinition
        The resolved policy definition

    .PARAMETER TenantId
        The Azure AD tenant ID

    .PARAMETER Mode
        The application mode
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$PolicyDefinition,

        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $true)]
        [string]$Mode
    )

    Write-Verbose "Applying Group policy for Group $($PolicyDefinition.GroupId) role $($PolicyDefinition.RoleName)"

    if ($Mode -eq "validate") {
        Write-Verbose "Validation mode: Policy would be applied for Group '$($PolicyDefinition.GroupId)' role '$($PolicyDefinition.RoleName)'"
        return @{
            GroupId = $PolicyDefinition.GroupId
            RoleName = $PolicyDefinition.RoleName
            Status = "Validated"
            Mode = $Mode
        }
    }

    # Note: Group policy import may need additional implementation
    # For now, we'll use Set-PIMGroupPolicy if available
    if ($PSCmdlet.ShouldProcess("Group policy for $($PolicyDefinition.GroupId) role $($PolicyDefinition.RoleName)", "Apply policy")) {
        Write-Warning "Group policy application is not yet fully implemented. Policy would be applied for Group '$($PolicyDefinition.GroupId)' role '$($PolicyDefinition.RoleName)'"
    }

    return @{
        GroupId = $PolicyDefinition.GroupId
        RoleName = $PolicyDefinition.RoleName
        Status = "Pending Implementation"
        Mode = $Mode
    }
}

function ConvertTo-PolicyCSV {
    <#
    .SYNOPSIS
        Converts a policy object to CSV format for use with existing Import-PIM*Policy functions.

    .DESCRIPTION
        This function converts an inline policy object to the CSV format expected by the existing
        Import-PIMAzureResourcePolicy and Import-PIMEntraRolePolicy functions.

    .PARAMETER Policy
        The policy object to convert

    .PARAMETER PolicyType
        The type of policy (AzureRole, EntraRole, Group)

    .PARAMETER RoleName
        The role name

    .PARAMETER Scope
        The scope (for Azure roles)

    .EXAMPLE
        $csvData = ConvertTo-PolicyCSV -Policy $policy -PolicyType "AzureRole" -RoleName "Owner" -Scope "/subscriptions/..."
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Policy,

        [Parameter(Mandatory = $true)]
        [ValidateSet("AzureRole", "EntraRole", "Group")]
        [string]$PolicyType,

        [Parameter(Mandatory = $true)]
        [string]$RoleName,

        [Parameter(Mandatory = $false)]
        [string]$Scope
    )

    Write-Verbose "Converting policy to CSV format for $PolicyType"

    # For Entra roles, we need to look up the role ID and policy ID
    # For Azure roles, the PolicyID should be the scope
    $roleID = ""
    $policyID = ""

    if ($PolicyType -eq "EntraRole") {
        try {
            # Look up role ID
            $endpoint = "roleManagement/directory/roleDefinitions?`$filter=displayname eq '$RoleName'"
            $response = invoke-graph -Endpoint $endpoint
            $roleID = $response.value.Id

            if ($roleID) {
                # Look up policy ID
                $endpoint = "policies/roleManagementPolicyAssignments?`$filter=scopeType eq 'DirectoryRole' and roleDefinitionId eq '$roleID' and scopeId eq '/' "
                $response = invoke-graph -Endpoint $endpoint
                $policyID = $response.value.policyID
            }
        }
        catch {
            Write-Warning "Failed to lookup role ID and policy ID for '$RoleName': $($_.Exception.Message)"
        }
    }
    elseif ($PolicyType -eq "AzureRole" -and $Scope) {
        # For Azure roles, the PolicyID is the scope
        $policyID = $Scope
    }

    # Create CSV row object with safe property access matching the expected format
    $csvRow = [PSCustomObject]@{
        RoleName = $RoleName
        roleID = $roleID
        PolicyID = $policyID
        ActivationDuration = if ($Policy.PSObject.Properties['ActivationDuration']) { $Policy.ActivationDuration } else { "PT8H" }
        EnablementRules = if ($Policy.PSObject.Properties['ActivationRequirement'] -and $Policy.ActivationRequirement) { $Policy.ActivationRequirement } else { "" }
        AuthenticationContext_Enabled = if ($Policy.PSObject.Properties['AuthenticationContext_Enabled'] -and $null -ne $Policy.AuthenticationContext_Enabled) { $Policy.AuthenticationContext_Enabled.ToString() } else { "False" }
        AuthenticationContext_Value = if ($Policy.PSObject.Properties['AuthenticationContext_Value']) { $Policy.AuthenticationContext_Value } else { "" }
        ApprovalRequired = if ($Policy.PSObject.Properties['ApprovalRequired'] -and $null -ne $Policy.ApprovalRequired) { $Policy.ApprovalRequired.ToString() } else { "False" }
        Approvers = if ($Policy.PSObject.Properties['Approvers'] -and $Policy.Approvers) {
            # Convert approvers to PowerShell hashtable syntax expected by the import function
            $approverStrings = @()
            foreach ($approver in $Policy.Approvers) {
                if ($approver.PSObject.Properties['id'] -or $approver.PSObject.Properties['Id']) {
                    $id = if ($approver.PSObject.Properties['id']) { $approver.id } else { $approver.Id }
                    $description = if ($approver.PSObject.Properties['description']) { $approver.description } elseif ($approver.PSObject.Properties['DisplayName']) { $approver.DisplayName } else { "Unknown" }
                    $userType = if ($approver.PSObject.Properties['userType']) { $approver.userType } else { "User" }
                    $approverStrings += "@{`"id`"=`"$id`";`"description`"=`"$description`";`"userType`"=`"$userType`"}"
                }
            }
            ($approverStrings -join ',') + ','
        } else { "" }
        AllowPermanentEligibleAssignment = if ($Policy.PSObject.Properties['AllowPermanentEligibility'] -and $null -ne $Policy.AllowPermanentEligibility) { $Policy.AllowPermanentEligibility.ToString() } else { "true" }
        MaximumEligibleAssignmentDuration = if ($Policy.PSObject.Properties['MaximumEligibilityDuration']) { $Policy.MaximumEligibilityDuration } else { "P365D" }
        AllowPermanentActiveAssignment = if ($Policy.PSObject.Properties['AllowPermanentActiveAssignment'] -and $null -ne $Policy.AllowPermanentActiveAssignment) { $Policy.AllowPermanentActiveAssignment.ToString() } else { "true" }
        MaximumActiveAssignmentDuration = if ($Policy.PSObject.Properties['MaximumActiveAssignmentDuration']) { $Policy.MaximumActiveAssignmentDuration } else { "P180D" }

        # Active assignment requirement field - conditional naming based on policy type
        ActiveAssignmentRules = if ($PolicyType -eq "AzureRole") {
            if ($Policy.PSObject.Properties['ActiveAssignmentRequirement']) { $Policy.ActiveAssignmentRequirement } else { "" }
        } else { "" }

        ActiveAssignmentRequirement = if ($PolicyType -eq "EntraRole") {
            if ($Policy.PSObject.Properties['ActiveAssignmentRequirement']) { $Policy.ActiveAssignmentRequirement } else { "" }
        } else { "" }

        # Notification settings with safe defaults
        Notification_Eligibility_Alert_isDefaultRecipientEnabled = if ($Policy.PSObject.Properties['Notification_EligibleAssignment_Alert'] -and $Policy.Notification_EligibleAssignment_Alert.PSObject.Properties['isDefaultRecipientEnabled']) { $Policy.Notification_EligibleAssignment_Alert.isDefaultRecipientEnabled } else { "True" }
        Notification_Eligibility_Alert_NotificationLevel = if ($Policy.PSObject.Properties['Notification_EligibleAssignment_Alert'] -and $Policy.Notification_EligibleAssignment_Alert.PSObject.Properties['notificationLevel']) { $Policy.Notification_EligibleAssignment_Alert.notificationLevel } else { "All" }
        Notification_Eligibility_Alert_Recipients = if ($Policy.PSObject.Properties['Notification_EligibleAssignment_Alert'] -and $Policy.Notification_EligibleAssignment_Alert.PSObject.Properties['Recipients']) { ($Policy.Notification_EligibleAssignment_Alert.Recipients -join ',') } else { "" }

        Notification_Eligibility_Assignee_isDefaultRecipientEnabled = if ($Policy.PSObject.Properties['Notification_EligibleAssignment_Assignee'] -and $Policy.Notification_EligibleAssignment_Assignee.PSObject.Properties['isDefaultRecipientEnabled']) { $Policy.Notification_EligibleAssignment_Assignee.isDefaultRecipientEnabled } else { "True" }
        Notification_Eligibility_Assignee_NotificationLevel = if ($Policy.PSObject.Properties['Notification_EligibleAssignment_Assignee'] -and $Policy.Notification_EligibleAssignment_Assignee.PSObject.Properties['notificationLevel']) { $Policy.Notification_EligibleAssignment_Assignee.notificationLevel } else { "All" }
        Notification_Eligibility_Assignee_Recipients = if ($Policy.PSObject.Properties['Notification_EligibleAssignment_Assignee'] -and $Policy.Notification_EligibleAssignment_Assignee.PSObject.Properties['Recipients']) { ($Policy.Notification_EligibleAssignment_Assignee.Recipients -join ',') } else { "" }

        Notification_Eligibility_Approvers_isDefaultRecipientEnabled = if ($Policy.PSObject.Properties['Notification_EligibleAssignment_Approver'] -and $Policy.Notification_EligibleAssignment_Approver.PSObject.Properties['isDefaultRecipientEnabled']) { $Policy.Notification_EligibleAssignment_Approver.isDefaultRecipientEnabled } else { "True" }
        Notification_Eligibility_Approvers_NotificationLevel = if ($Policy.PSObject.Properties['Notification_EligibleAssignment_Approver'] -and $Policy.Notification_EligibleAssignment_Approver.PSObject.Properties['notificationLevel']) { $Policy.Notification_EligibleAssignment_Approver.notificationLevel } else { "All" }
        Notification_Eligibility_Approvers_Recipients = if ($Policy.PSObject.Properties['Notification_EligibleAssignment_Approver'] -and $Policy.Notification_EligibleAssignment_Approver.PSObject.Properties['Recipients']) { ($Policy.Notification_EligibleAssignment_Approver.Recipients -join ',') } else { "" }

        Notification_Active_Alert_isDefaultRecipientEnabled = if ($Policy.PSObject.Properties['Notification_ActiveAssignment_Alert'] -and $Policy.Notification_ActiveAssignment_Alert.PSObject.Properties['isDefaultRecipientEnabled']) { $Policy.Notification_ActiveAssignment_Alert.isDefaultRecipientEnabled } else { "True" }
        Notification_Active_Alert_NotificationLevel = if ($Policy.PSObject.Properties['Notification_ActiveAssignment_Alert'] -and $Policy.Notification_ActiveAssignment_Alert.PSObject.Properties['notificationLevel']) { $Policy.Notification_ActiveAssignment_Alert.notificationLevel } else { "All" }
        Notification_Active_Alert_Recipients = if ($Policy.PSObject.Properties['Notification_ActiveAssignment_Alert'] -and $Policy.Notification_ActiveAssignment_Alert.PSObject.Properties['Recipients']) { ($Policy.Notification_ActiveAssignment_Alert.Recipients -join ',') } else { "" }

        Notification_Active_Assignee_isDefaultRecipientEnabled = if ($Policy.PSObject.Properties['Notification_ActiveAssignment_Assignee'] -and $Policy.Notification_ActiveAssignment_Assignee.PSObject.Properties['isDefaultRecipientEnabled']) { $Policy.Notification_ActiveAssignment_Assignee.isDefaultRecipientEnabled } else { "True" }
        Notification_Active_Assignee_NotificationLevel = if ($Policy.PSObject.Properties['Notification_ActiveAssignment_Assignee'] -and $Policy.Notification_ActiveAssignment_Assignee.PSObject.Properties['notificationLevel']) { $Policy.Notification_ActiveAssignment_Assignee.notificationLevel } else { "All" }
        Notification_Active_Assignee_Recipients = if ($Policy.PSObject.Properties['Notification_ActiveAssignment_Assignee'] -and $Policy.Notification_ActiveAssignment_Assignee.PSObject.Properties['Recipients']) { ($Policy.Notification_ActiveAssignment_Assignee.Recipients -join ',') } else { "" }

        Notification_Active_Approvers_isDefaultRecipientEnabled = if ($Policy.PSObject.Properties['Notification_ActiveAssignment_Approver'] -and $Policy.Notification_ActiveAssignment_Approver.PSObject.Properties['isDefaultRecipientEnabled']) { $Policy.Notification_ActiveAssignment_Approver.isDefaultRecipientEnabled } else { "True" }
        Notification_Active_Approvers_NotificationLevel = if ($Policy.PSObject.Properties['Notification_ActiveAssignment_Approver'] -and $Policy.Notification_ActiveAssignment_Approver.PSObject.Properties['notificationLevel']) { $Policy.Notification_ActiveAssignment_Approver.notificationLevel } else { "All" }
        Notification_Active_Approvers_Recipients = if ($Policy.PSObject.Properties['Notification_ActiveAssignment_Approver'] -and $Policy.Notification_ActiveAssignment_Approver.PSObject.Properties['Recipients']) { ($Policy.Notification_ActiveAssignment_Approver.Recipients -join ',') } else { "" }

        Notification_Activation_Alert_isDefaultRecipientEnabled = if ($Policy.PSObject.Properties['Notification_Activation_Alert'] -and $Policy.Notification_Activation_Alert.PSObject.Properties['isDefaultRecipientEnabled']) { $Policy.Notification_Activation_Alert.isDefaultRecipientEnabled } else { "True" }
        Notification_Activation_Alert_NotificationLevel = if ($Policy.PSObject.Properties['Notification_Activation_Alert'] -and $Policy.Notification_Activation_Alert.PSObject.Properties['notificationLevel']) { $Policy.Notification_Activation_Alert.notificationLevel } else { "All" }
        Notification_Activation_Alert_Recipients = if ($Policy.PSObject.Properties['Notification_Activation_Alert'] -and $Policy.Notification_Activation_Alert.PSObject.Properties['Recipients']) { ($Policy.Notification_Activation_Alert.Recipients -join ',') } else { "" }

        Notification_Activation_Assignee_isDefaultRecipientEnabled = if ($Policy.PSObject.Properties['Notification_Activation_Assignee'] -and $Policy.Notification_Activation_Assignee.PSObject.Properties['isDefaultRecipientEnabled']) { $Policy.Notification_Activation_Assignee.isDefaultRecipientEnabled } else { "True" }
        Notification_Activation_Assignee_NotificationLevel = if ($Policy.PSObject.Properties['Notification_Activation_Assignee'] -and $Policy.Notification_Activation_Assignee.PSObject.Properties['notificationLevel']) { $Policy.Notification_Activation_Assignee.notificationLevel } else { "All" }
        Notification_Activation_Assignee_Recipients = if ($Policy.PSObject.Properties['Notification_Activation_Assignee'] -and $Policy.Notification_Activation_Assignee.PSObject.Properties['Recipients']) { ($Policy.Notification_Activation_Assignee.Recipients -join ',') } else { "" }

        Notification_Activation_Approver_isDefaultRecipientEnabled = if ($Policy.PSObject.Properties['Notification_Activation_Approver'] -and $Policy.Notification_Activation_Approver.PSObject.Properties['isDefaultRecipientEnabled']) { $Policy.Notification_Activation_Approver.isDefaultRecipientEnabled } else { "True" }
        Notification_Activation_Approver_NotificationLevel = if ($Policy.PSObject.Properties['Notification_Activation_Approver'] -and $Policy.Notification_Activation_Approver.PSObject.Properties['notificationLevel']) { $Policy.Notification_Activation_Approver.notificationLevel } else { "All" }
        Notification_Activation_Approver_Recipients = if ($Policy.PSObject.Properties['Notification_Activation_Approver'] -and $Policy.Notification_Activation_Approver.PSObject.Properties['Recipients']) { ($Policy.Notification_Activation_Approver.Recipients -join ',') } else { "" }
    }

    # Add scope for Azure roles
    if ($PolicyType -eq "AzureRole" -and $Scope) {
        $csvRow | Add-Member -NotePropertyName "Scope" -NotePropertyValue $Scope
    }

    # Add notification settings if they exist
    if ($Policy.Notifications) {
        $notifications = $Policy.Notifications

        # Eligibility notifications
        if ($notifications.Eligibility) {
            $csvRow | Add-Member -NotePropertyName "Notification_Eligibility_Alert_isDefaultRecipientEnabled" -NotePropertyValue $notifications.Eligibility.Alert.isDefaultRecipientEnabled.ToString()
            $csvRow | Add-Member -NotePropertyName "Notification_Eligibility_Alert_NotificationLevel" -NotePropertyValue $notifications.Eligibility.Alert.NotificationLevel
            $csvRow | Add-Member -NotePropertyName "Notification_Eligibility_Alert_Recipients" -NotePropertyValue ($notifications.Eligibility.Alert.Recipients -join ',')

            $csvRow | Add-Member -NotePropertyName "Notification_Eligibility_Assignee_isDefaultRecipientEnabled" -NotePropertyValue $notifications.Eligibility.Assignee.isDefaultRecipientEnabled.ToString()
            $csvRow | Add-Member -NotePropertyName "Notification_Eligibility_Assignee_NotificationLevel" -NotePropertyValue $notifications.Eligibility.Assignee.NotificationLevel
            $csvRow | Add-Member -NotePropertyName "Notification_Eligibility_Assignee_Recipients" -NotePropertyValue ($notifications.Eligibility.Assignee.Recipients -join ',')

            $csvRow | Add-Member -NotePropertyName "Notification_Eligibility_Approvers_isDefaultRecipientEnabled" -NotePropertyValue $notifications.Eligibility.Approvers.isDefaultRecipientEnabled.ToString()
            $csvRow | Add-Member -NotePropertyName "Notification_Eligibility_Approvers_NotificationLevel" -NotePropertyValue $notifications.Eligibility.Approvers.NotificationLevel
            $csvRow | Add-Member -NotePropertyName "Notification_Eligibility_Approvers_Recipients" -NotePropertyValue ($notifications.Eligibility.Approvers.Recipients -join ',')
        }

        # Active notifications
        if ($notifications.Active) {
            $csvRow | Add-Member -NotePropertyName "Notification_Active_Alert_isDefaultRecipientEnabled" -NotePropertyValue $notifications.Active.Alert.isDefaultRecipientEnabled.ToString()
            $csvRow | Add-Member -NotePropertyName "Notification_Active_Alert_NotificationLevel" -NotePropertyValue $notifications.Active.Alert.NotificationLevel
            $csvRow | Add-Member -NotePropertyName "Notification_Active_Alert_Recipients" -NotePropertyValue ($notifications.Active.Alert.Recipients -join ',')

            $csvRow | Add-Member -NotePropertyName "Notification_Active_Assignee_isDefaultRecipientEnabled" -NotePropertyValue $notifications.Active.Assignee.isDefaultRecipientEnabled.ToString()
            $csvRow | Add-Member -NotePropertyName "Notification_Active_Assignee_NotificationLevel" -NotePropertyValue $notifications.Active.Assignee.NotificationLevel
            $csvRow | Add-Member -NotePropertyName "Notification_Active_Assignee_Recipients" -NotePropertyValue ($notifications.Active.Assignee.Recipients -join ',')

            $csvRow | Add-Member -NotePropertyName "Notification_Active_Approvers_isDefaultRecipientEnabled" -NotePropertyValue $notifications.Active.Approvers.isDefaultRecipientEnabled.ToString()
            $csvRow | Add-Member -NotePropertyName "Notification_Active_Approvers_NotificationLevel" -NotePropertyValue $notifications.Active.Approvers.NotificationLevel
            $csvRow | Add-Member -NotePropertyName "Notification_Active_Approvers_Recipients" -NotePropertyValue ($notifications.Active.Approvers.Recipients -join ',')
        }

        # Activation notifications
        if ($notifications.Activation) {
            $csvRow | Add-Member -NotePropertyName "Notification_Activation_Alert_isDefaultRecipientEnabled" -NotePropertyValue $notifications.Activation.Alert.isDefaultRecipientEnabled.ToString()
            $csvRow | Add-Member -NotePropertyName "Notification_Activation_Alert_NotificationLevel" -NotePropertyValue $notifications.Activation.Alert.NotificationLevel
            $csvRow | Add-Member -NotePropertyName "Notification_Activation_Alert_Recipients" -NotePropertyValue ($notifications.Activation.Alert.Recipients -join ',')

            $csvRow | Add-Member -NotePropertyName "Notification_Activation_Assignee_isDefaultRecipientEnabled" -NotePropertyValue $notifications.Activation.Assignee.isDefaultRecipientEnabled.ToString()
            $csvRow | Add-Member -NotePropertyName "Notification_Activation_Assignee_NotificationLevel" -NotePropertyValue $notifications.Activation.Assignee.NotificationLevel
            $csvRow | Add-Member -NotePropertyName "Notification_Activation_Assignee_Recipients" -NotePropertyValue ($notifications.Activation.Assignee.Recipients -join ',')

            $csvRow | Add-Member -NotePropertyName "Notification_Activation_Approvers_isDefaultRecipientEnabled" -NotePropertyValue $notifications.Activation.Approvers.isDefaultRecipientEnabled.ToString()
            $csvRow | Add-Member -NotePropertyName "Notification_Activation_Approvers_NotificationLevel" -NotePropertyValue $notifications.Activation.Approvers.NotificationLevel
            $csvRow | Add-Member -NotePropertyName "Notification_Activation_Approvers_Recipients" -NotePropertyValue ($notifications.Activation.Approvers.Recipients -join ',')
        }
    }

    Write-Verbose "Policy conversion to CSV completed"
    return @($csvRow)
}
