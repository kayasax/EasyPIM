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
            RolesNotFound = 0
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

                # Note: Groups do not support Authentication Context; if provided in template, surface as ignored
                if ($resolvedPolicy.PSObject.Properties['AuthenticationContext_Enabled'] -and $resolvedPolicy.AuthenticationContext_Enabled) {
                    $policyDetails += "Authentication Context: NOT SUPPORTED for Groups (ignoring)"
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
                                $resolved = $policyDef.ResolvedPolicy
                                # Build compact summary of key settings
                                if ($resolved) {
                                    $act = $resolved.ActivationDuration
                                    $reqs = @()
                                    if ($resolved.ActivationRequirement -match 'MFA') { $reqs += 'MFA' }
                                    if ($resolved.ActivationRequirement -match 'Justification') { $reqs += 'Justification' }
                                    $reqsTxt = if ($reqs) { $reqs -join '+' } else { 'None' }
                                    $appr = if ($resolved.ApprovalRequired) { "Yes($($resolved.Approvers.Count) approvers)" } else { 'No' }
                                    $elig = $resolved.MaximumEligibilityDuration
                                    $permElig = if ($resolved.AllowPermanentEligibility) { 'Allowed' } else { 'No' }
                                    $actMax = $resolved.MaximumActiveAssignmentDuration
                                    $permAct = if ($resolved.AllowPermanentActiveAssignment) { 'Allowed' } else { 'No' }
                                    $notifCount = ($resolved.PSObject.Properties | Where-Object { $_.Name -like 'Notification_*' }).Count
                                    $summary = "Activation=$act Requirements=$reqsTxt Approval=$appr Elig=$elig PermElig=$permElig Active=$actMax PermActive=$permAct Notifications=$notifCount"
                                } else { $summary = '' }
                                if ($PolicyMode -eq "validate") {
                                    Write-Host "  [OK] Validated policy for role '$($policyDef.RoleName)' at scope '$($policyDef.Scope)' (no changes applied) $summary" -ForegroundColor Green
                                } else {
                                    Write-Host "  [OK] Applied policy for role '$($policyDef.RoleName)' at scope '$($policyDef.Scope)' $summary" -ForegroundColor Green
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
            # Pre-validate each Entra role exists so warnings surface even under -WhatIf / validation
            foreach ($policyDef in $Config.EntraRolePolicies) {
                try {
                    if (-not $policyDef.PSObject.Properties['RoleName'] -or [string]::IsNullOrWhiteSpace($policyDef.RoleName)) { continue }
                    $endpoint = "roleManagement/directory/roleDefinitions?`$filter=displayName eq '$($policyDef.RoleName)'"
                    $resp = invoke-graph -Endpoint $endpoint
                    $found = $false
                    if ($resp.value -and $resp.value.Count -gt 0) { $found = $true }
                    if (-not $found) {
                        Write-Warning "Entra role '$($policyDef.RoleName)' not found - policy will be skipped. Correct the name to apply this policy."
                        if (-not $policyDef.PSObject.Properties['_RoleNotFound']) { $policyDef | Add-Member -NotePropertyName _RoleNotFound -NotePropertyValue $true -Force } else { $policyDef._RoleNotFound = $true }
                        $results.Summary.RolesNotFound++
                    } else {
                        if (-not $policyDef.PSObject.Properties['_RoleNotFound']) { $policyDef | Add-Member -NotePropertyName _RoleNotFound -NotePropertyValue $false -Force } else { $policyDef._RoleNotFound = $false }
                    }
                } catch {
                    Write-Warning "Failed to validate Entra role '$($policyDef.RoleName)': $($_.Exception.Message)"
                }
            }
            # Build detailed WhatIf message for Entra Role Policies
            $whatIfDetails = @()
            foreach ($policyDef in $Config.EntraRolePolicies) {
                # Access the resolved policy configuration
                $policy = $policyDef.ResolvedPolicy
                if (-not $policy) {
                    $policy = $policyDef
                }

                $roleLabel = if ($policyDef.PSObject.Properties['_RoleNotFound'] -and $policyDef._RoleNotFound) { "Role: '$($policyDef.RoleName)' [NOT FOUND - SKIPPED]" } else { "Role: '$($policyDef.RoleName)'" }

                $policyDetails = @( $roleLabel )

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
                    if ($policyDef.PSObject.Properties['_RoleNotFound'] -and $policyDef._RoleNotFound) {
                        # Record skipped not found entry
                        $results.EntraRolePolicies += [PSCustomObject]@{ RoleName = $policyDef.RoleName; Status = 'SkippedRoleNotFound'; Mode = $PolicyMode; Details = 'Role displayName not found during pre-validation' }
                        $results.Summary.Skipped++
                        continue
                    }
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
                            $resolved = $policyDef.ResolvedPolicy
                            if ($resolved) {
                                $act = $resolved.ActivationDuration
                                $reqs = @()
                                if ($resolved.ActivationRequirement -match 'MFA') { $reqs += 'MFA' }
                                if ($resolved.ActivationRequirement -match 'Justification') { $reqs += 'Justification' }
                                $reqsTxt = if ($reqs) { $reqs -join '+' } else { 'None' }
                                $appr = if ($resolved.ApprovalRequired) { "Yes($($resolved.Approvers.Count) approvers)" } else { 'No' }
                                $elig = $resolved.MaximumEligibilityDuration
                                $permElig = if ($resolved.AllowPermanentEligibility) { 'Allowed' } else { 'No' }
                                $actMax = $resolved.MaximumActiveAssignmentDuration
                                $permAct = if ($resolved.AllowPermanentActiveAssignment) { 'Allowed' } else { 'No' }
                                $notifCount = ($resolved.PSObject.Properties | Where-Object { $_.Name -like 'Notification_*' }).Count
                                $summary = "Activation=$act Requirements=$reqsTxt Approval=$appr Elig=$elig PermElig=$permElig Active=$actMax PermActive=$permAct Notifications=$notifCount"
                            } else { $summary = '' }
                            if ($PolicyMode -eq "validate") {
                                Write-Host "  [OK] Validated policy for Entra role '$($policyDef.RoleName)' (no changes applied) $summary" -ForegroundColor Green
                            } else {
                                Write-Host "  [OK] Applied policy for Entra role '$($policyDef.RoleName)' $summary" -ForegroundColor Green
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
                # Count all as skipped due to WhatIf, but they may also include not found roles already counted in RolesNotFound
                $results.Summary.Skipped += $Config.EntraRolePolicies.Count
                # Add explicit entries for not found roles so caller can see statuses programmatically
                foreach ($policyDef in $Config.EntraRolePolicies | Where-Object { $_.PSObject.Properties['_RoleNotFound'] -and $_._RoleNotFound }) {
                    $results.EntraRolePolicies += [PSCustomObject]@{ RoleName = $policyDef.RoleName; Status = 'SkippedRoleNotFound'; Mode = $PolicyMode; Details = 'Role displayName not found during pre-validation' }
                }
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

                        switch ($policyResult.Status) {
                            { $_ -like '*Protected*' } {
                                $results.Summary.Skipped++
                                Write-Host "  [PROTECTED] Protected Group '$($policyDef.GroupId)' role '$($policyDef.RoleName)' - policy change blocked for security" -ForegroundColor Yellow
                            }
                            'Applied' {
                                $results.Summary.Successful++
                                $resolved = $policyDef.ResolvedPolicy
                                if ($resolved) {
                                    $act = $resolved.ActivationDuration
                                    $reqs = @()
                                    if ($resolved.ActivationRequirement -match 'MFA') { $reqs += 'MFA' }
                                    if ($resolved.ActivationRequirement -match 'Justification') { $reqs += 'Justification' }
                                    $reqsTxt = if ($reqs) { $reqs -join '+' } else { 'None' }
                                    $appr = if ($resolved.ApprovalRequired) { "Yes($($resolved.Approvers.Count) approvers)" } else { 'No' }
                                    $elig = $resolved.MaximumEligibilityDuration
                                    $permElig = if ($resolved.AllowPermanentEligibility) { 'Allowed' } else { 'No' }
                                    $actMax = $resolved.MaximumActiveAssignmentDuration
                                    $permAct = if ($resolved.AllowPermanentActiveAssignment) { 'Allowed' } else { 'No' }
                                    $notifCount = ($resolved.PSObject.Properties | Where-Object { $_.Name -like 'Notification_*' }).Count
                                    $summary = "Activation=$act Requirements=$reqsTxt Approval=$appr Elig=$elig PermElig=$permElig Active=$actMax PermActive=$permAct Notifications=$notifCount"
                                } else { $summary = '' }
                                if ($PolicyMode -eq 'validate') {
                                    Write-Host "  [OK] Validated policy for Group '$($policyDef.GroupId)' role '$($policyDef.RoleName)' (no changes applied) $summary" -ForegroundColor Green
                                } else {
                                    Write-Host "  [OK] Applied policy for Group '$($policyDef.GroupId)' role '$($policyDef.RoleName)' $summary" -ForegroundColor Green
                                }
                            }
                            'DeferredNotEligible' {
                                $results.Summary.Skipped++
                                Write-Host "  [DEFERRED] Group '$($policyDef.GroupId)' role '$($policyDef.RoleName)' not PIM-eligible yet; will retry later" -ForegroundColor Yellow
                            }
                            'Skipped' {
                                $results.Summary.Skipped++
                                Write-Host "  [SKIPPED] Group '$($policyDef.GroupId)' role '$($policyDef.RoleName)'" -ForegroundColor Yellow
                            }
                            default {
                                $results.Summary.Failed++
                                Write-Host "  [ERR] Failed to apply policy for Group '$($policyDef.GroupId)' role '$($policyDef.RoleName)': Status=$($policyResult.Status)" -ForegroundColor Red
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
    # Direct apply always used (legacy CSV path removed)


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

    # Retrieve existing policy to capture correct PolicyID (roleManagementPolicies GUID) so PATCH hits the right resource
    try {
        $existing = Get-PIMAzureResourcePolicy -tenantID $TenantId -subscriptionID $SubscriptionId -rolename $PolicyDefinition.RoleName -ErrorAction Stop
        if ($existing -and $existing.PolicyID) {
            if (-not $PolicyDefinition.PSObject.Properties['PolicyID']) { $PolicyDefinition | Add-Member -NotePropertyName PolicyID -NotePropertyValue $existing.PolicyID -Force } else { $PolicyDefinition.PolicyID = $existing.PolicyID }
            if ($existing.roleID -and -not $PolicyDefinition.PSObject.Properties['roleID']) { $PolicyDefinition | Add-Member -NotePropertyName roleID -NotePropertyValue $existing.roleID -Force }
        } else {
            Write-Verbose "Existing Azure role policy ID not found for $($PolicyDefinition.RoleName); will fallback to scope path (may fail to PATCH)."
        }
    } catch { Write-Verbose "Failed to resolve existing Azure policy ID: $($_.Exception.Message)" }

    Write-Verbose "[Policy][Azure] Building rules in-memory for $($PolicyDefinition.RoleName)"
        $resolved = $PolicyDefinition.ResolvedPolicy
        if (-not $resolved) { $resolved = $PolicyDefinition }

        # Fallback: copy key properties from top-level definition if they didn't survive template resolution
        $propFallbacks = 'ActivationDuration','ActivationRequirement','ActiveAssignmentRequirement','AuthenticationContext_Enabled','AuthenticationContext_Value','ApprovalRequired','Approvers','MaximumEligibilityDuration','AllowPermanentEligibility','MaximumActiveAssignmentDuration','AllowPermanentActiveAssignment'
        foreach ($pn in $propFallbacks) {
            if (-not ($resolved.PSObject.Properties[$pn]) -and $PolicyDefinition.PSObject.Properties[$pn]) {
                try { $resolved | Add-Member -NotePropertyName $pn -NotePropertyValue $PolicyDefinition.$pn -Force } catch { $resolved.$pn = $PolicyDefinition.$pn }
                Write-Verbose "[DirectApply][Fallback] Injected missing property '$pn' from top-level definition for role $($PolicyDefinition.RoleName)"
            }
        }

        $rules = @()
        if ($resolved.PSObject.Properties['ActivationDuration'] -and $resolved.ActivationDuration) { $rules += Set-ActivationDuration $resolved.ActivationDuration }
        if ($resolved.PSObject.Properties['ActivationRequirement']) { $rules += Set-ActivationRequirement $resolved.ActivationRequirement }
        if ($resolved.PSObject.Properties['ActiveAssignmentRequirement']) { $rules += Set-ActiveAssignmentRequirement $resolved.ActiveAssignmentRequirement }
        if ($resolved.PSObject.Properties['AuthenticationContext_Enabled'] -and $resolved.AuthenticationContext_Enabled) { $rules += Set-AuthenticationContext $resolved.AuthenticationContext_Enabled $resolved.AuthenticationContext_Value }
        if ($resolved.PSObject.Properties['ApprovalRequired'] -or $resolved.PSObject.Properties['Approvers']) { $rules += Set-Approval $resolved.ApprovalRequired $resolved.Approvers }
        if ($resolved.PSObject.Properties['MaximumEligibilityDuration'] -or $resolved.PSObject.Properties['AllowPermanentEligibility']) { $rules += Set-EligibilityAssignment $resolved.MaximumEligibilityDuration $resolved.AllowPermanentEligibility }
        if ($resolved.PSObject.Properties['MaximumActiveAssignmentDuration'] -or $resolved.PSObject.Properties['AllowPermanentActiveAssignment']) { $rules += Set-ActiveAssignment $resolved.MaximumActiveAssignmentDuration $resolved.AllowPermanentActiveAssignment }
        # Notifications (only add if present to minimize churn)
        foreach ($n in $resolved.PSObject.Properties | Where-Object { $_.Name -like 'Notification_*' }) {
            switch ($n.Name) {
                'Notification_EligibleAssignment_Alert' { $rules += Set-Notification_EligibleAssignment_Alert $n.Value }
                'Notification_EligibleAssignment_Assignee' { $rules += Set-Notification_EligibleAssignment_Assignee $n.Value }
                'Notification_EligibleAssignment_Approver' { $rules += Set-Notification_EligibleAssignment_Approver $n.Value }
                'Notification_ActiveAssignment_Alert' { $rules += Set-Notification_ActiveAssignment_Alert $n.Value }
                'Notification_ActiveAssignment_Assignee' { $rules += Set-Notification_ActiveAssignment_Assignee $n.Value }
                'Notification_ActiveAssignment_Approver' { $rules += Set-Notification_ActiveAssignment_Approver $n.Value }
                'Notification_Activation_Alert' { $rules += Set-Notification_Activation_Alert $n.Value }
                'Notification_Activation_Assignee' { $rules += Set-Notification_Activation_Assignee $n.Value }
                'Notification_Activation_Approver' { $rules += Set-Notification_Activation_Approver $n.Value }
            }
        }
        $bodyRules = $rules -join ","
    Write-Verbose "[Policy][Azure] Rule objects count: $($rules.Count)"
        if ($PSCmdlet.ShouldProcess("Azure role policy for $($PolicyDefinition.RoleName)", "PATCH policy")) {
            if (-not $PolicyDefinition.PolicyID) { Write-Verbose '[Policy][Azure] Missing PolicyID - attempting re-fetch'; try { $existing = Get-PIMAzureResourcePolicy -tenantID $TenantId -subscriptionID $SubscriptionId -rolename $PolicyDefinition.RoleName -ErrorAction Stop; if ($existing.PolicyID){$PolicyDefinition.PolicyID=$existing.PolicyID} } catch { Write-Verbose "[Policy][Azure] Re-fetch failed: $($_.Exception.Message)" } }
            if ($PolicyDefinition.PolicyID) { Update-Policy $PolicyDefinition.PolicyID $bodyRules } else { throw "Azure apply failed: No PolicyID for role $($PolicyDefinition.RoleName)" }
        }
    return @{ RoleName=$PolicyDefinition.RoleName; Scope=$PolicyDefinition.Scope; Status='Applied'; Mode=$Mode }
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

    # Build and PATCH in-memory for Entra roles.
    $resolved = $PolicyDefinition.ResolvedPolicy
    if (-not $resolved) { $resolved = $PolicyDefinition }

    # Copy critical properties if missing
    $propFallbacks = 'ActivationDuration','ActivationRequirement','ActiveAssignmentRequirement','AuthenticationContext_Enabled','AuthenticationContext_Value','ApprovalRequired','Approvers','MaximumEligibilityDuration','AllowPermanentEligibility','MaximumActiveAssignmentDuration','AllowPermanentActiveAssignment'
    foreach ($pn in $propFallbacks) {
        if (-not ($resolved.PSObject.Properties[$pn]) -and $PolicyDefinition.PSObject.Properties[$pn]) {
            try { $resolved | Add-Member -NotePropertyName $pn -NotePropertyValue $PolicyDefinition.$pn -Force } catch { $resolved.$pn = $PolicyDefinition.$pn }
        }
    }

    $rules = @()
    if ($resolved.PSObject.Properties['ActivationDuration'] -and $resolved.ActivationDuration) { $rules += Set-ActivationDuration $resolved.ActivationDuration -EntraRole }
    if ($resolved.PSObject.Properties['ActivationRequirement']) { $rules += Set-ActivationRequirement $resolved.ActivationRequirement -EntraRole }
    if ($resolved.PSObject.Properties['ActiveAssignmentRequirement']) { $rules += Set-ActiveAssignmentRequirement $resolved.ActiveAssignmentRequirement -EntraRole }
    if ($resolved.PSObject.Properties['AuthenticationContext_Enabled'] -and $resolved.AuthenticationContext_Enabled) { $rules += Set-AuthenticationContext $resolved.AuthenticationContext_Enabled $resolved.AuthenticationContext_Value -EntraRole }
    if ($resolved.PSObject.Properties['ApprovalRequired'] -or $resolved.PSObject.Properties['Approvers']) { $rules += Set-Approval $resolved.ApprovalRequired $resolved.Approvers -EntraRole }
    if ($resolved.PSObject.Properties['MaximumEligibilityDuration'] -or $resolved.PSObject.Properties['AllowPermanentEligibility']) { $rules += Set-EligibilityAssignment $resolved.MaximumEligibilityDuration $resolved.AllowPermanentEligibility -EntraRole }
    if ($resolved.PSObject.Properties['MaximumActiveAssignmentDuration'] -or $resolved.PSObject.Properties['AllowPermanentActiveAssignment']) { $rules += Set-ActiveAssignment $resolved.MaximumActiveAssignmentDuration $resolved.AllowPermanentActiveAssignment -EntraRole }
    foreach ($n in $resolved.PSObject.Properties | Where-Object { $_.Name -like 'Notification_*' }) {
        switch ($n.Name) {
            'Notification_EligibleAssignment_Alert' { $rules += Set-Notification_EligibleAssignment_Alert $n.Value -EntraRole }
            'Notification_EligibleAssignment_Assignee' { $rules += Set-Notification_EligibleAssignment_Assignee $n.Value -EntraRole }
            'Notification_EligibleAssignment_Approver' { $rules += Set-Notification_EligibleAssignment_Approver $n.Value -EntraRole }
            'Notification_ActiveAssignment_Alert' { $rules += Set-Notification_ActiveAssignment_Alert $n.Value -EntraRole }
            'Notification_ActiveAssignment_Assignee' { $rules += Set-Notification_ActiveAssignment_Assignee $n.Value -EntraRole }
            'Notification_ActiveAssignment_Approver' { $rules += Set-Notification_ActiveAssignment_Approver $n.Value -EntraRole }
            'Notification_Activation_Alert' { $rules += Set-Notification_Activation_Alert $n.Value -EntraRole }
            'Notification_Activation_Assignee' { $rules += Set-Notification_Activation_Assignee $n.Value -EntraRole }
            'Notification_Activation_Approver' { $rules += Set-Notification_Activation_Approver $n.Value -EntraRole }
        }
    }
    $bodyRules = $rules -join ','
    Write-Verbose "[Policy][Entra] Rule objects count: $($rules.Count)"
    if ($PSCmdlet.ShouldProcess("Entra role policy for $($PolicyDefinition.RoleName)", "PATCH policy")) {
        # Need current PolicyID (roleManagementPolicies ID for the directoryRole)
        try {
            $existing = Get-PIMEntraRolePolicy -tenantID $TenantId -rolename $PolicyDefinition.RoleName -ErrorAction Stop
            if ($existing -and $existing.PolicyID) { $PolicyDefinition | Add-Member -NotePropertyName PolicyID -NotePropertyValue $existing.PolicyID -Force }
        } catch { Write-Verbose "[Policy][Entra] Failed to resolve PolicyID: $($_.Exception.Message)" }
        if ($PolicyDefinition.PSObject.Properties['PolicyID'] -and $PolicyDefinition.PolicyID) {
            Write-Verbose "[Policy][Entra] Using Graph updater for PolicyID $($PolicyDefinition.PolicyID)"
            Update-EntraRolePolicy $PolicyDefinition.PolicyID $bodyRules
        } else {
            throw "Entra apply failed: No PolicyID for role $($PolicyDefinition.RoleName)"
        }
    }
    return @{ RoleName=$PolicyDefinition.RoleName; Status='Applied'; Mode=$Mode }
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
        [string]$Mode,

        [Parameter(Mandatory = $false)]
        [switch]$SkipEligibilityCheck
    )

    # Resolve GroupId if only GroupName provided
    if (-not $PolicyDefinition.GroupId -and $PolicyDefinition.GroupName) {
        try {
            # Lookup group by displayName directly (URL encoding not required for simple equal filter)
            $endpoint = "groups?`$filter=displayName eq '$($PolicyDefinition.GroupName)'"
            $resp = invoke-graph -Endpoint $endpoint
            if ($resp.value -and $resp.value.Count -ge 1) {
                $PolicyDefinition | Add-Member -NotePropertyName GroupId -NotePropertyValue $resp.value[0].id -Force
            } else {
                throw "Unable to resolve GroupName '$($PolicyDefinition.GroupName)' to an Id"
            }
        } catch {
            Write-Warning "GroupName resolution failed: $($_.Exception.Message)"
        }
    }

    $groupRef = if ($PolicyDefinition.GroupId) { $PolicyDefinition.GroupId } else { $PolicyDefinition.GroupName }
    Write-Verbose "Applying Group policy for Group $groupRef role $($PolicyDefinition.RoleName)"

    # Eligibility pre-check (skip for validate mode or if explicitly bypassed)
    if ($Mode -ne 'validate' -and -not $SkipEligibilityCheck) {
        if (-not $PolicyDefinition.GroupId) {
            Write-Warning "Cannot check eligibility without GroupId for group name '$($PolicyDefinition.GroupName)'"
        } else {
            $eligible = $true
            try { $eligible = Test-GroupEligibleForPIM -GroupId $PolicyDefinition.GroupId } catch { Write-Verbose "Eligibility check failed: $($_.Exception.Message)" }
            if (-not $eligible) {
                if (-not $script:EasyPIM_DeferredGroupPolicies) { $script:EasyPIM_DeferredGroupPolicies = @() }
                # Store minimal data needed to retry later
                $script:EasyPIM_DeferredGroupPolicies += [PSCustomObject]@{
                    GroupId          = $PolicyDefinition.GroupId
                    GroupName        = $PolicyDefinition.GroupName
                    RoleName         = $PolicyDefinition.RoleName
                    ResolvedPolicy   = $PolicyDefinition.ResolvedPolicy
                    OriginalPolicy   = $PolicyDefinition
                }
                Write-Warning "Deferring Group policy for $($PolicyDefinition.GroupId) role $($PolicyDefinition.RoleName) - group not PIM-eligible yet"
                return @{ GroupId = $PolicyDefinition.GroupId; RoleName = $PolicyDefinition.RoleName; Status = 'DeferredNotEligible'; Mode = $Mode }
            }
        }
    }

    if ($Mode -eq "validate") {
    $groupRefValidate = if ($PolicyDefinition.GroupId) { $PolicyDefinition.GroupId } else { $PolicyDefinition.GroupName }
    Write-Verbose "Validation mode: Policy would be applied for Group '$groupRefValidate' role '$($PolicyDefinition.RoleName)'"
        return @{ GroupId = $PolicyDefinition.GroupId; RoleName = $PolicyDefinition.RoleName; Status = 'Validated'; Mode = $Mode }
    }

    # Build parameters for Set-PIMGroupPolicy from resolved policy
    $resolved = if ($PolicyDefinition.ResolvedPolicy) { $PolicyDefinition.ResolvedPolicy } else { $PolicyDefinition }

    # Normalize: map EnablementRules -> ActivationRequirement if needed
    if (-not ($resolved.PSObject.Properties['ActivationRequirement']) -and $resolved.PSObject.Properties['EnablementRules'] -and $resolved.EnablementRules) {
        try { $resolved | Add-Member -NotePropertyName ActivationRequirement -NotePropertyValue $resolved.EnablementRules -Force } catch { $resolved.ActivationRequirement = $resolved.EnablementRules }
        Write-Verbose "[GroupPolicy][Normalize] Added ActivationRequirement from EnablementRules for Group $($PolicyDefinition.GroupId) role $($PolicyDefinition.RoleName)"
    }
    # Normalize duration alias
    if (-not ($resolved.PSObject.Properties['ActivationDuration']) -and $resolved.PSObject.Properties['Duration'] -and $resolved.Duration) {
        try { $resolved | Add-Member -NotePropertyName ActivationDuration -NotePropertyValue $resolved.Duration -Force } catch { $resolved.ActivationDuration = $resolved.Duration }
        Write-Verbose "[GroupPolicy][Normalize] Added ActivationDuration from Duration for Group $($PolicyDefinition.GroupId) role $($PolicyDefinition.RoleName)"
    }

    $setParams = @{
        tenantID = $TenantId
        groupID  = @($PolicyDefinition.GroupId)
        type     = $PolicyDefinition.RoleName.ToLower()
    }
    $suppressedAuthCtx = $false
    foreach ($prop in $resolved.PSObject.Properties) {
        switch ($prop.Name) {
            'ActivationDuration' { if ($prop.Value) { $setParams.ActivationDuration = $prop.Value } }
            'ActivationRequirement' { if ($prop.Value) { $setParams.ActivationRequirement = $prop.Value } }
            'ActiveAssignmentRequirement' { if ($prop.Value) { $setParams.ActiveAssignmentRequirement = $prop.Value } }
        # Authentication Context not supported for Group policies; ignore if provided
        'AuthenticationContext_Enabled' { $suppressedAuthCtx = $true; continue }
        'AuthenticationContext_Value' { $suppressedAuthCtx = $true; continue }
            'ApprovalRequired' { $setParams.ApprovalRequired = $prop.Value }
            'Approvers' { $setParams.Approvers = $prop.Value }
            'MaximumEligibilityDuration' { $setParams.MaximumEligibilityDuration = $prop.Value }
            'AllowPermanentEligibility' { $setParams.AllowPermanentEligibility = $prop.Value }
            'MaximumActiveAssignmentDuration' { $setParams.MaximumActiveAssignmentDuration = $prop.Value }
            'AllowPermanentActiveAssignment' { $setParams.AllowPermanentActiveAssignment = $prop.Value }
            default { if ($prop.Name -like 'Notification_*') { $setParams[$prop.Name] = $prop.Value } }
        }
    }
    if ($suppressedAuthCtx) { Write-Verbose "[GroupPolicy][Normalize] AuthenticationContext_* provided but not supported for Groups; ignoring for Group $($PolicyDefinition.GroupId) role $($PolicyDefinition.RoleName)" }

    $status = 'Applied'
    if ($PSCmdlet.ShouldProcess("Group policy for $($PolicyDefinition.GroupId) role $($PolicyDefinition.RoleName)", "Apply policy")) {
        if (Get-Command -Name Set-PIMGroupPolicy -ErrorAction SilentlyContinue) {
            try {
                Write-Verbose ("[Policy][Group] Calling Set-PIMGroupPolicy with params: " + (($setParams.GetEnumerator() | ForEach-Object { $_.Key + '=' + ($_.Value -join ',') }) -join ' '))
                Set-PIMGroupPolicy @setParams -Verbose:$VerbosePreference | Out-Null
            } catch {
                Write-Warning "Set-PIMGroupPolicy failed: $($_.Exception.Message)"; $status='Failed'
            }
        } else { Write-Warning 'Set-PIMGroupPolicy cmdlet not found.'; $status='CmdletMissing' }
    } else { $status='Skipped' }

    return @{
        GroupId = $PolicyDefinition.GroupId
        RoleName = $PolicyDefinition.RoleName
        Status = $status
        Mode = $Mode
    }
}

    function Invoke-DeferredGroupPolicies {
        <#
        .SYNOPSIS
            Attempts to apply any group policies previously deferred due to group not being PIM-eligible.
        .DESCRIPTION
            Re-tests eligibility and applies policies. Summarizes outcomes.
        #>
        [CmdletBinding(SupportsShouldProcess = $true)]
        param(
            [Parameter(Mandatory=$true)][string]$TenantId,
            [Parameter(Mandatory=$false)][string]$Mode = 'delta'
        )
        if (-not $script:EasyPIM_DeferredGroupPolicies -or $script:EasyPIM_DeferredGroupPolicies.Count -eq 0) { return $null }

        Write-Host "🔁 Retrying deferred Group policies (count: $($script:EasyPIM_DeferredGroupPolicies.Count))" -ForegroundColor Cyan
        $applied=0;$stillDeferred=0;$failed=0
        $results=@()
        foreach ($p in $script:EasyPIM_DeferredGroupPolicies) {
            $eligible=$false
            try { $eligible = Test-GroupEligibleForPIM -GroupId $p.GroupId } catch { Write-Verbose "Retry eligibility check failed: $($_.Exception.Message)" }
            if (-not $eligible) {
                Write-Host "  ⏳ Still not eligible: $($p.GroupId) ($($p.RoleName))" -ForegroundColor Yellow
                $stillDeferred++
                $results += [PSCustomObject]@{ GroupId=$p.GroupId; RoleName=$p.RoleName; Status='StillNotEligible' }
                continue
            }
            $policyDef = [PSCustomObject]@{
                GroupId = $p.GroupId
                GroupName = $p.GroupName
                RoleName = $p.RoleName
                ResolvedPolicy = $p.ResolvedPolicy
            }
            try {
                $res = Set-GroupPolicy -PolicyDefinition $policyDef -TenantId $TenantId -Mode $Mode -SkipEligibilityCheck -WhatIf:$WhatIfPreference
                $results += [PSCustomObject]@{ GroupId=$p.GroupId; RoleName=$p.RoleName; Status=$res.Status }
                if ($res.Status -eq 'Applied') { $applied++ } else { $failed++ }
            } catch {
                Write-Warning "Deferred apply failed for $($p.GroupId): $($_.Exception.Message)"
                $failed++
                $results += [PSCustomObject]@{ GroupId=$p.GroupId; RoleName=$p.RoleName; Status='FailedRetry' }
            }
        }
        Write-Host "🔁 Deferred Group Policy Summary: Applied=$applied, StillNotEligible=$stillDeferred, Failed=$failed" -ForegroundColor Cyan
        # Clear collection to avoid duplicate attempts next run
        $script:EasyPIM_DeferredGroupPolicies = @()
        return [PSCustomObject]@{ Applied=$applied; StillNotEligible=$stillDeferred; Failed=$failed; Details=$results }
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
            else {
                Write-Warning "Entra role '$RoleName' not found (skipping policy). No Graph enumeration performed to preserve performance. Correct the name to apply a policy.";
                return [PSCustomObject]@{ RoleName=$RoleName; Status='SkippedRoleNotFound'; Reason='Role displayName not found'; Mode='lookup' }
            }
        }
        catch {
            Write-Warning "Failed to lookup role ID and policy ID for '$RoleName': $($_.Exception.Message)"
        }
    }
    elseif ($PolicyType -eq "AzureRole" -and $Scope) {
        if ($Policy.PSObject.Properties['PolicyID'] -and $Policy.PolicyID) {
            $policyID = $Policy.PolicyID
        } elseif ($Policy.PSObject.Properties['policyID'] -and $Policy.policyID) {
            $policyID = $Policy.policyID
        } else {
            # Fallback - legacy behavior (may not be valid for PATCH)
            $policyID = $Scope
        }
    }

    # Create CSV row object with safe property access matching the expected format
    $csvRow = [PSCustomObject]@{
        RoleName = $RoleName
        roleID = $roleID
        PolicyID = $policyID
        ActivationDuration = if ($Policy.PSObject.Properties['ActivationDuration']) { $Policy.ActivationDuration } else { "PT8H" }
        EnablementRules = if ($Policy.PSObject.Properties['ActivationRequirement'] -and $Policy.ActivationRequirement) {
            if ($Policy.ActivationRequirement -is [System.Collections.IEnumerable] -and -not ($Policy.ActivationRequirement -is [string])) { ($Policy.ActivationRequirement | ForEach-Object { "$_" }) -join ',' } else { $Policy.ActivationRequirement }
        } else { "" }
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
            # Helper to set or add property
            function SetOrAddProp { param([Parameter(Mandatory)][object]$Object,[Parameter(Mandatory)][string]$Name,[Parameter(Mandatory)][object]$Value) if(-not ($Object.PSObject.Properties.Match($Name))){ $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value } else { $Object.$Name = $Value } }
            SetOrAddProp -Object $csvRow -Name 'Notification_Eligibility_Alert_isDefaultRecipientEnabled' -Value ($notifications.Eligibility.Alert.isDefaultRecipientEnabled.ToString())
            SetOrAddProp -Object $csvRow -Name 'Notification_Eligibility_Alert_NotificationLevel' -Value ($notifications.Eligibility.Alert.NotificationLevel)
            SetOrAddProp -Object $csvRow -Name 'Notification_Eligibility_Alert_Recipients' -Value (($notifications.Eligibility.Alert.Recipients -join ','))
            SetOrAddProp -Object $csvRow -Name 'Notification_Eligibility_Assignee_isDefaultRecipientEnabled' -Value ($notifications.Eligibility.Assignee.isDefaultRecipientEnabled.ToString())
            SetOrAddProp -Object $csvRow -Name 'Notification_Eligibility_Assignee_NotificationLevel' -Value ($notifications.Eligibility.Assignee.NotificationLevel)
            SetOrAddProp -Object $csvRow -Name 'Notification_Eligibility_Assignee_Recipients' -Value (($notifications.Eligibility.Assignee.Recipients -join ','))
            SetOrAddProp -Object $csvRow -Name 'Notification_Eligibility_Approvers_isDefaultRecipientEnabled' -Value ($notifications.Eligibility.Approvers.isDefaultRecipientEnabled.ToString())
            SetOrAddProp -Object $csvRow -Name 'Notification_Eligibility_Approvers_NotificationLevel' -Value ($notifications.Eligibility.Approvers.NotificationLevel)
            SetOrAddProp -Object $csvRow -Name 'Notification_Eligibility_Approvers_Recipients' -Value (($notifications.Eligibility.Approvers.Recipients -join ','))
        }

        # Active notifications
        if ($notifications.Active) {
            function SetOrAddProp2 { param([Parameter(Mandatory)][object]$Object,[Parameter(Mandatory)][string]$Name,[Parameter(Mandatory)][object]$Value) if(-not ($Object.PSObject.Properties.Match($Name))){ $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value } else { $Object.$Name = $Value } }
            SetOrAddProp2 -Object $csvRow -Name 'Notification_Active_Alert_isDefaultRecipientEnabled' -Value ($notifications.Active.Alert.isDefaultRecipientEnabled.ToString())
            SetOrAddProp2 -Object $csvRow -Name 'Notification_Active_Alert_NotificationLevel' -Value ($notifications.Active.Alert.NotificationLevel)
            SetOrAddProp2 -Object $csvRow -Name 'Notification_Active_Alert_Recipients' -Value (($notifications.Active.Alert.Recipients -join ','))
            SetOrAddProp2 -Object $csvRow -Name 'Notification_Active_Assignee_isDefaultRecipientEnabled' -Value ($notifications.Active.Assignee.isDefaultRecipientEnabled.ToString())
            SetOrAddProp2 -Object $csvRow -Name 'Notification_Active_Assignee_NotificationLevel' -Value ($notifications.Active.Assignee.NotificationLevel)
            SetOrAddProp2 -Object $csvRow -Name 'Notification_Active_Assignee_Recipients' -Value (($notifications.Active.Assignee.Recipients -join ','))
            SetOrAddProp2 -Object $csvRow -Name 'Notification_Active_Approvers_isDefaultRecipientEnabled' -Value ($notifications.Active.Approvers.isDefaultRecipientEnabled.ToString())
            SetOrAddProp2 -Object $csvRow -Name 'Notification_Active_Approvers_NotificationLevel' -Value ($notifications.Active.Approvers.NotificationLevel)
            SetOrAddProp2 -Object $csvRow -Name 'Notification_Active_Approvers_Recipients' -Value (($notifications.Active.Approvers.Recipients -join ','))
        }

        # Activation notifications
        if ($notifications.Activation) {
            function SetOrAddProp3 { param([Parameter(Mandatory)][object]$Object,[Parameter(Mandatory)][string]$Name,[Parameter(Mandatory)][object]$Value) if(-not ($Object.PSObject.Properties.Match($Name))){ $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value } else { $Object.$Name = $Value } }
            SetOrAddProp3 -Object $csvRow -Name 'Notification_Activation_Alert_isDefaultRecipientEnabled' -Value ($notifications.Activation.Alert.isDefaultRecipientEnabled.ToString())
            SetOrAddProp3 -Object $csvRow -Name 'Notification_Activation_Alert_NotificationLevel' -Value ($notifications.Activation.Alert.NotificationLevel)
            SetOrAddProp3 -Object $csvRow -Name 'Notification_Activation_Alert_Recipients' -Value (($notifications.Activation.Alert.Recipients -join ','))
            SetOrAddProp3 -Object $csvRow -Name 'Notification_Activation_Assignee_isDefaultRecipientEnabled' -Value ($notifications.Activation.Assignee.isDefaultRecipientEnabled.ToString())
            SetOrAddProp3 -Object $csvRow -Name 'Notification_Activation_Assignee_NotificationLevel' -Value ($notifications.Activation.Assignee.NotificationLevel)
            SetOrAddProp3 -Object $csvRow -Name 'Notification_Activation_Assignee_Recipients' -Value (($notifications.Activation.Assignee.Recipients -join ','))
            SetOrAddProp3 -Object $csvRow -Name 'Notification_Activation_Approver_isDefaultRecipientEnabled' -Value ($notifications.Activation.Approvers.isDefaultRecipientEnabled.ToString())
            SetOrAddProp3 -Object $csvRow -Name 'Notification_Activation_Approver_NotificationLevel' -Value ($notifications.Activation.Approvers.NotificationLevel)
            SetOrAddProp3 -Object $csvRow -Name 'Notification_Activation_Approver_Recipients' -Value (($notifications.Activation.Approvers.Recipients -join ','))
        }
    }

    Write-Verbose "Policy conversion to CSV completed"
    return @($csvRow)
}
