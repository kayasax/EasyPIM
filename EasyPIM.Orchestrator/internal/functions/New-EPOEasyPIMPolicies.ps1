#Requires -Version 5.1
function New-EPOEasyPIMPolicies {
    <#
    .SYNOPSIS
    Apply EasyPIM policies across Azure, Entra, and Groups.
    .DESCRIPTION
    Processes the provided configuration object, generating and applying policy rules for Azure Resource roles, Entra roles, and Group roles based on PolicyMode (delta/initial). Supports -WhatIf for preview and returns a summarized result object.
    .PARAMETER Config
    The PSCustomObject configuration previously loaded (e.g., via Get-EasyPIMConfiguration).
    .PARAMETER TenantId
    The target Entra tenant ID.
    .PARAMETER SubscriptionId
    The Azure subscription ID for Azure Resource role policies.
    .PARAMETER PolicyMode
    One of delta or initial to control application behavior.
    .EXAMPLE
    New-EPOEasyPIMPolicies -Config $cfg -TenantId $tid -SubscriptionId $sub -PolicyMode delta -WhatIf
    Previews configured policy changes without making modifications.
    .EXAMPLE
    New-EPOEasyPIMPolicies -Config $cfg -TenantId $tid -SubscriptionId $sub -PolicyMode delta
    Applies additive changes for roles and groups where needed.
    .NOTES
    Returns a summary object with per-domain results and counts.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Config,
        [Parameter(Mandatory=$true)]
        [string]$TenantId,
        [Parameter(Mandatory=$false)]
        [string]$SubscriptionId,
        [Parameter(Mandatory=$false)]
        [ValidateSet('delta','initial')]
        [string]$PolicyMode = 'delta',
        [Parameter(Mandatory=$false)]
        [switch]$AllowProtectedRoles
    )
    Write-Verbose "Starting New-EPOEasyPIMPolicies in $PolicyMode mode"
    
    # Detect WhatIf mode
    $isWhatIf = $PSCmdlet.ParameterSetName -eq 'WhatIf' -or $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('WhatIf') -or $WhatIfPreference.IsPresent

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
        # If the provided Config has no policy sections, nothing to do
        if (-not ($Config.PSObject.Properties['AzureRolePolicies'] -or $Config.PSObject.Properties['EntraRolePolicies'] -or $Config.PSObject.Properties['GroupPolicies'])) {
            Write-Verbose "No policy sections present in Config; skipping policy processing."
            return $results
        }
        # Azure Role Policies
        if ($Config.PSObject.Properties['AzureRolePolicies'] -and $Config.AzureRolePolicies -and $Config.AzureRolePolicies.Count -gt 0) {
            $whatIfDetails = @()
            
            # Pre-fetch live policies if in WhatIf mode to filter out matching ones
            $azureLivePolicies = @{}
            if ($isWhatIf) {
                Write-Verbose "WhatIf mode detected: Pre-fetching Azure policies to filter matching configurations..."
                try {
                    # Group by scope to optimize calls
                    $policiesByScope = $Config.AzureRolePolicies | Group-Object -Property { if ($_.Scope) { $_.Scope } else { "subscriptions/$SubscriptionId" } }
                    foreach ($scopeGroup in $policiesByScope) {
                        $scope = $scopeGroup.Name
                        $roles = $scopeGroup.Group.RoleName
                        if ($scope -and $roles) {
                            # Extract subscription ID from scope if possible, or use provided one
                            $subId = $SubscriptionId
                            if ($scope -match 'subscriptions/([^/]+)') { $subId = $matches[1] }
                            
                            try {
                                $live = Get-PIMAzureResourcePolicy -tenantID $TenantId -subscriptionID $subId -rolename $roles -ErrorAction SilentlyContinue
                                if ($live) {
                                    foreach ($l in $live) {
                                        # Note: Get-PIMAzureResourcePolicy returns policy objects but mapping them back to RoleName 
                                        # without additional API calls is complex. For now, we skip the optimization of pre-fetching 
                                        # and mapping for Azure policies and rely on individual fetching in the loop below.
                                        # This ensures accuracy at the cost of performance in WhatIf mode.
                                    }
                                }
                            } catch { Write-Verbose "Failed to fetch live Azure policy for scope $scope: $_" }
                        }
                    }
                } catch { Write-Verbose "Error pre-fetching Azure policies: $_" }
            }

            foreach ($policyDef in $Config.AzureRolePolicies) {
                $resolvedPolicy = if ($policyDef.ResolvedPolicy) { $policyDef.ResolvedPolicy } else { $policyDef }

                # Check if this is a protected Azure role and add warning to WhatIf display
                $protectedAzureRoles = @("Owner","User Access Administrator")
                $isProtected = $protectedAzureRoles -contains $policyDef.RoleName
                $protectedWarning = if ($isProtected) {
                    if (-not $AllowProtectedRoles) { " [⚠️ PROTECTED - BLOCKED]" }
                    else { " [⚠️ PROTECTED - OVERRIDE ENABLED]" }
                } else { "" }

                # WhatIf Logic: Check for drift if in WhatIf mode
                $isDrift = $true
                $driftReason = ""
                if ($isWhatIf) {
                    try {
                        # Determine scope
                        $scope = if ($policyDef.Scope) { $policyDef.Scope } else { "subscriptions/$SubscriptionId" }
                        $subId = $SubscriptionId
                        if ($scope -match 'subscriptions/([^/]+)') { $subId = $matches[1] }
                        
                        # Fetch single policy for comparison
                        $live = Get-PIMAzureResourcePolicy -tenantID $TenantId -subscriptionID $subId -rolename $policyDef.RoleName -ErrorAction SilentlyContinue
                        
                        if ($live) {
                            $tempResults = @()
                            $tempDrift = 0
                            # Use Compare-PIMPolicy to check for drift
                            Compare-PIMPolicy -Type 'AzureRole' -Name $policyDef.RoleName -Expected $resolvedPolicy -Live $live -Results ([ref]$tempResults) -DriftCount ([ref]$tempDrift)
                            
                            if ($tempDrift -eq 0) {
                                $isDrift = $false
                            } else {
                                $driftItems = $tempResults | Where-Object { $_.Status -eq 'Drift' }
                                $driftReason = " [DRIFT: $($driftItems.Differences -join ', ')]"
                            }
                        }
                    } catch {
                        Write-Verbose "Could not verify drift for $($policyDef.RoleName): $_"
                    }
                }

                if ($isDrift) {
                    $policyDetails = @(
                        "Role: '$($policyDef.RoleName)'$protectedWarning$driftReason",
                        "Scope: '$($policyDef.Scope)'",
                        "Activation Duration: $($resolvedPolicy.ActivationDuration)",
                        "MFA Required: $(if ($resolvedPolicy.ActivationRequirement -match 'MFA') { 'Yes' } else { 'No' })",
                        "Justification Required: $(if ($resolvedPolicy.ActivationRequirement -match 'Justification') { 'Yes' } else { 'No' })",
                        "Approval Required: $($resolvedPolicy.ApprovalRequired)"
                    )
                    if ($resolvedPolicy.ApprovalRequired -and $resolvedPolicy.PSObject.Properties['Approvers'] -and $resolvedPolicy.Approvers) {
                        $approverList = $resolvedPolicy.Approvers | ForEach-Object {
                            $desc = if ($_.description) { $_.description } else { $_.Name }
                            $idValue = if ($_.id) { $_.id } else { $_.Id }
                            "$desc ($idValue)"
                        }
                        $policyDetails += "Approvers: $($approverList -join ', ')"
                    }
                    if ($resolvedPolicy.PSObject.Properties['AuthenticationContext_Enabled'] -and $resolvedPolicy.AuthenticationContext_Enabled) {
                        $policyDetails += "Authentication Context: $($resolvedPolicy.AuthenticationContext_Value)"
                    }
                    $policyDetails += "Max Eligibility: $($resolvedPolicy.MaximumEligibilityDuration)"
                    $policyDetails += "Permanent Eligibility: $(if ($resolvedPolicy.AllowPermanentEligibility) { 'Allowed' } else { 'Not Allowed' })"
                    $whatIfDetails += "    * $($policyDetails -join ' | ')"
                }
            }
            
            if ($whatIfDetails.Count -eq 0 -and $Config.AzureRolePolicies.Count -gt 0) {
                $whatIfDetails += "    * [ALL MATCH] All $($Config.AzureRolePolicies.Count) Azure role policies match the current configuration."
            }

            $whatIfMessage = "Apply Azure Role Policy configurations:`n$($whatIfDetails -join "`n")"
            if ($PSCmdlet.ShouldProcess($whatIfMessage, "Azure Role Policies")) {
                Write-Host "[PROC] Processing Azure Role Policies..." -ForegroundColor Cyan
                if (-not $SubscriptionId -and -not ($Config.AzureRolePolicies | Where-Object { $_.Scope })) {
                    $errorMsg = "SubscriptionId is required for Azure Role Policies if no Scope is provided per policy"
                    Write-Error $errorMsg
                    $results.Errors += $errorMsg
                } else {
                    foreach ($policyDef in $Config.AzureRolePolicies) {
                        $results.Summary.TotalProcessed++
                        try {
                            $policyResult = Set-EPOAzureRolePolicy -PolicyDefinition $policyDef -TenantId $TenantId -SubscriptionId $SubscriptionId -Mode $PolicyMode -AllowProtectedRoles:$AllowProtectedRoles
                            $results.AzureRolePolicies += $policyResult
                            if ($policyResult.Status -like "*Protected*") {
                                $results.Summary.Skipped++
                                Write-Host "  [PROTECTED] Protected Azure role '$($policyDef.RoleName)' - policy change blocked for security" -ForegroundColor Yellow
                            }
                            elseif ($policyResult.Status -like "Failed*") {
                                $results.Summary.Failed++
                                Write-Host "  [FAIL] Azure role '$($policyDef.RoleName)' at scope '$($policyDef.Scope)' policy apply failed (Status=$($policyResult.Status))" -ForegroundColor Red
                            }
                            elseif ($policyResult.Status -like "Skipped*" -or $policyResult.Status -like "Deferred*") {
                                $results.Summary.Skipped++
                                Write-Host "  [SKIPPED] Azure role '$($policyDef.RoleName)' at scope '$($policyDef.Scope)' (Status=$($policyResult.Status))" -ForegroundColor Yellow
                            }
                            elseif ($policyResult.Status -like "CmdletMissing*") {
                                $results.Summary.Failed++
                                Write-Host "  [FAIL] Azure role '$($policyDef.RoleName)' at scope '$($policyDef.Scope)' required cmdlet missing" -ForegroundColor Red
                            }
                            else {
                                $results.Summary.Successful++
                                $resolved = $policyDef.ResolvedPolicy
                                if ($resolved) {
                                    $act = $resolved.ActivationDuration
                                    $reqs = @(); if ($resolved.ActivationRequirement -match 'MFA') { $reqs += 'MFA' }; if ($resolved.ActivationRequirement -match 'Justification') { $reqs += 'Justification' }
                                    $reqsTxt = if ($reqs) { $reqs -join '+' } else { 'None' }
                                    $appr = if ($resolved.ApprovalRequired) { "Yes($($resolved.Approvers.Count) approvers)" } else { 'No' }
                                    $elig = $resolved.MaximumEligibilityDuration
                                    $permElig = if ($resolved.AllowPermanentEligibility) { 'Allowed' } else { 'No' }
                                    $actMax = $resolved.MaximumActiveAssignmentDuration
                                    $permAct = if ($resolved.AllowPermanentActiveAssignment) { 'Allowed' } else { 'No' }
                                    $notifCount = ($resolved.PSObject.Properties | Where-Object { $_.Name -like 'Notification_*' }).Count
                                    $summary = "Activation=$act Requirements=$reqsTxt Approval=$appr Elig=$elig PermElig=$permElig Active=$actMax PermActive=$permAct Notifications=$notifCount"
                                } else { $summary = '' }
                                Write-Host "  [OK] Applied policy for role '$($policyDef.RoleName)' at scope '$($policyDef.Scope)' $summary" -ForegroundColor Green
                            }
                        } catch { $errorMsg = "Failed to apply Azure role policy for '$($policyDef.RoleName)': $($_.Exception.Message)"; Write-Error $errorMsg; $results.Errors += $errorMsg; $results.Summary.Failed++ }
                    }
                }
            } else {
                Write-Host "[WARNING] Skipping Azure Role Policies processing due to WhatIf" -ForegroundColor Yellow
                Write-Host "   Would have applied the following policy configurations:" -ForegroundColor Yellow
                foreach ($line in $whatIfDetails) { Write-Host "   $line" -ForegroundColor Yellow }
                $results.Summary.Skipped += $Config.AzureRolePolicies.Count
            }
        }
        # Entra Role Policies
        if ($Config.PSObject.Properties['EntraRolePolicies'] -and $Config.EntraRolePolicies -and $Config.EntraRolePolicies.Count -gt 0) {
            # Pre-fetch live policies if in WhatIf mode to filter out matching ones
            $entraLivePolicies = @{}
            if ($isWhatIf) {
                Write-Verbose "WhatIf mode detected: Pre-fetching Entra policies to filter matching configurations..."
                try {
                    $roleNames = $Config.EntraRolePolicies.RoleName | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                    if ($roleNames) {
                        $live = Get-PIMEntraRolePolicy -TenantId $TenantId -RoleName $roleNames -ErrorAction SilentlyContinue
                        if ($live) {
                            foreach ($l in $live) {
                                # Get-PIMEntraRolePolicy returns object with 'roleName' property which matches input
                                if ($l.PSObject.Properties['roleName']) {
                                    $entraLivePolicies[$l.roleName] = $l
                                }
                            }
                        }
                    }
                } catch { Write-Verbose "Error pre-fetching Entra policies: $_" }
            }

            foreach ($policyDef in $Config.EntraRolePolicies) {
                try {
                    if (-not $policyDef.PSObject.Properties['RoleName'] -or [string]::IsNullOrWhiteSpace($policyDef.RoleName)) { continue }
                    $endpoint = "roleManagement/directory/roleDefinitions?`$filter=displayName eq '$($policyDef.RoleName)'"
                    $resp = invoke-graph -Endpoint $endpoint
                    $found = $false; if ($resp.value -and $resp.value.Count -gt 0) { $found = $true }
                    if (-not $found) { Write-Warning "Entra role '$($policyDef.RoleName)' not found - policy will be skipped. Correct the name to apply this policy."; if (-not $policyDef.PSObject.Properties['_RoleNotFound']) { $policyDef | Add-Member -NotePropertyName _RoleNotFound -NotePropertyValue $true -Force } else { $policyDef._RoleNotFound = $true }; $results.Summary.RolesNotFound++ }
                    else { if (-not $policyDef.PSObject.Properties['_RoleNotFound']) { $policyDef | Add-Member -NotePropertyName _RoleNotFound -NotePropertyValue $false -Force } else { $policyDef._RoleNotFound = $false } }
                } catch { Write-Warning "Failed to resolve Entra role '$($policyDef.RoleName)': $($_.Exception.Message)" }
            }
            $whatIfDetails = @()
            foreach ($policyDef in $Config.EntraRolePolicies) {
                $policy = $policyDef.ResolvedPolicy; if (-not $policy) { $policy = $policyDef }

                # Check if this is a protected role and add warning to WhatIf display
                $protectedRoles = @("Global Administrator","Privileged Role Administrator","Security Administrator","User Access Administrator")
                $isProtected = $protectedRoles -contains $policyDef.RoleName
                $protectedWarning = if ($isProtected) {
                    if (-not $AllowProtectedRoles) { " [⚠️ PROTECTED - BLOCKED]" }
                    else { " [⚠️ PROTECTED - OVERRIDE ENABLED]" }
                } else { "" }

                # WhatIf Logic: Check for drift if in WhatIf mode
                $isDrift = $true
                $driftReason = ""
                if ($isWhatIf) {
                    try {
                        $live = $entraLivePolicies[$policyDef.RoleName]
                        if ($live) {
                            $tempResults = @()
                            $tempDrift = 0
                            Compare-PIMPolicy -Type 'EntraRole' -Name $policyDef.RoleName -Expected $policy -Live $live -Results ([ref]$tempResults) -DriftCount ([ref]$tempDrift)
                            
                            if ($tempDrift -eq 0) {
                                $isDrift = $false
                            } else {
                                $driftItems = $tempResults | Where-Object { $_.Status -eq 'Drift' }
                                $driftReason = " [DRIFT: $($driftItems.Differences -join ', ')]"
                            }
                        }
                    } catch { Write-Verbose "Could not verify drift for $($policyDef.RoleName): $_" }
                }

                if ($isDrift) {
                    $roleLabel = if ($policyDef.PSObject.Properties['_RoleNotFound'] -and $policyDef._RoleNotFound) { "Role: '$($policyDef.RoleName)' [NOT FOUND - SKIPPED]" } else { "Role: '$($policyDef.RoleName)'$protectedWarning$driftReason" }
                    $policyDetails = @( $roleLabel )
                    if ($policy.PSObject.Properties['ActivationDuration'] -and $policy.ActivationDuration) { $policyDetails += "Activation Duration: $($policy.ActivationDuration)" } else { $policyDetails += "Activation Duration: Not specified" }
                    $requirements = @(); if ($policy.PSObject.Properties['ActivationRequirement'] -and $policy.ActivationRequirement) { if ($policy.ActivationRequirement -match 'MultiFactorAuthentication' -or $policy.ActivationRequirement -match 'MFA') { $requirements += 'MultiFactorAuthentication' }; if ($policy.ActivationRequirement -match 'Justification') { $requirements += 'Justification' } }
                    $policyDetails += "Requirements: $(if ($requirements) { $requirements -join ', ' } else { 'None' })"
                    if ($policy.PSObject.Properties['ApprovalRequired'] -and $null -ne $policy.ApprovalRequired) {
                        $policyDetails += "Approval Required: $($policy.ApprovalRequired)"
                        if ($policy.ApprovalRequired) {
                            if ($policy.PSObject.Properties['Approvers'] -and $policy.Approvers) {
                                $approverList = $policy.Approvers | ForEach-Object {
                                    if ($_.PSObject.Properties['description'] -and $_.PSObject.Properties['id']) {
                                        $desc = if ($_.description) { $_.description } else { $_.Name }
                                        $idValue = if ($_.id) { $_.id } else { $_.Id }
                                        "$desc ($idValue)"
                                    } else {
                                        "$_"
                                    }
                                }
                                $policyDetails += "Approvers: $($approverList -join ', ')"
                            } else { $policyDetails += "[WARNING: ApprovalRequired is true but no Approvers specified!]" }
                        }
                    } else { $policyDetails += "Approval Required: Not specified" }
                    if ($policy.PSObject.Properties['AuthenticationContext_Enabled'] -and $policy.AuthenticationContext_Enabled -and $policy.PSObject.Properties['AuthenticationContext_Value'] -and $policy.AuthenticationContext_Value) { $policyDetails += "Authentication Context: $($policy.AuthenticationContext_Value)" }
                    if ($policy.PSObject.Properties['MaximumEligibilityDuration'] -and $policy.MaximumEligibilityDuration) { $policyDetails += "Max Eligibility: $($policy.MaximumEligibilityDuration)" }
                    if ($policy.PSObject.Properties['AllowPermanentEligibility'] -and $null -ne $policy.AllowPermanentEligibility) { $policyDetails += "Permanent Eligibility: $(if ($policy.AllowPermanentEligibility) { 'Allowed' } else { 'Not Allowed' })" }
                    $whatIfDetails += "    * $($policyDetails -join ' | ')"
                }
            }
            
            if ($whatIfDetails.Count -eq 0 -and $Config.EntraRolePolicies.Count -gt 0) {
                $whatIfDetails += "    * [ALL MATCH] All $($Config.EntraRolePolicies.Count) Entra role policies match the current configuration."
            }

            $whatIfMessage = "Apply Entra Role Policy configurations:`n$($whatIfDetails -join "`n")"
            if ($PSCmdlet.ShouldProcess($whatIfMessage, "Entra Role Policies")) {
                Write-Host "[PROC] Processing Entra Role Policies..." -ForegroundColor Cyan
                foreach ($policyDef in $Config.EntraRolePolicies) {
                    if ($policyDef.PSObject.Properties['_RoleNotFound'] -and $policyDef._RoleNotFound) { $results.EntraRolePolicies += [PSCustomObject]@{ RoleName = $policyDef.RoleName; Status = 'SkippedRoleNotFound'; Mode = $PolicyMode; Details = 'Role displayName not found during pre-validation' }; $results.Summary.Skipped++; continue }
                    $results.Summary.TotalProcessed++
                    try {
                        $policyResult = Set-EPOEntraRolePolicy -PolicyDefinition $policyDef -TenantId $TenantId -Mode $PolicyMode -AllowProtectedRoles:$AllowProtectedRoles
                        $results.EntraRolePolicies += $policyResult
                        if ($policyResult.Status -like "*Protected*") {
                            $results.Summary.Skipped++
                            Write-Host "  [PROTECTED] Protected role '$($policyDef.RoleName)' - policy change blocked for security" -ForegroundColor Yellow
                        }
                        elseif ($policyResult.Status -like "Failed*") {
                            $results.Summary.Failed++
                            Write-Host "  [FAIL] Entra role '$($policyDef.RoleName)' policy apply failed (Status=$($policyResult.Status))" -ForegroundColor Red
                        }
                        elseif ($policyResult.Status -like "Skipped*" -or $policyResult.Status -like "Deferred*") {
                            $results.Summary.Skipped++
                            Write-Host "  [SKIPPED] Entra role '$($policyDef.RoleName)' (Status=$($policyResult.Status))" -ForegroundColor Yellow
                        }
                        elseif ($policyResult.Status -like "CmdletMissing*") {
                            $results.Summary.Failed++
                            Write-Host "  [FAIL] Entra role '$($policyDef.RoleName)' required cmdlet missing" -ForegroundColor Red
                        }
                        else {
                            $results.Summary.Successful++
                            $resolved = $policyDef.ResolvedPolicy
                            if ($resolved) {
                                $act = $resolved.ActivationDuration
                                $reqs = @(); if ($resolved.ActivationRequirement -match 'MFA') { $reqs += 'MFA' }; if ($resolved.ActivationRequirement -match 'Justification') { $reqs += 'Justification' }
                                $reqsTxt = if ($reqs) { $reqs -join '+' } else { 'None' }
                                $appr = if ($resolved.ApprovalRequired) { "Yes($($resolved.Approvers.Count) approvers)" } else { 'No' }
                                $elig = $resolved.MaximumEligibilityDuration
                                $permElig = if ($resolved.AllowPermanentEligibility) { 'Allowed' } else { 'No' }
                                $actMax = $resolved.MaximumActiveAssignmentDuration
                                $permAct = if ($resolved.AllowPermanentActiveAssignment) { 'Allowed' } else { 'No' }
                                $notifCount = ($resolved.PSObject.Properties | Where-Object { $_.Name -like 'Notification_*' }).Count
                                $summary = "Activation=$act Requirements=$reqsTxt Approval=$appr Elig=$elig PermElig=$permElig Active=$actMax PermActive=$permAct Notifications=$notifCount"
                            } else { $summary = '' }
                            Write-Host "  [OK] Applied policy for Entra role '$($policyDef.RoleName)' $summary" -ForegroundColor Green
                        }
                    } catch { $errorMsg = "Failed to apply Entra role policy for '$($policyDef.RoleName)': $($_.Exception.Message)"; Write-Error $errorMsg; $results.Errors += $errorMsg; $results.Summary.Failed++ }
                }
            } else {
                Write-Host "[WARNING] Skipping Entra Role Policies processing due to WhatIf" -ForegroundColor Yellow
                Write-Host "   Would have applied the following policy configurations:" -ForegroundColor Yellow
                foreach ($line in $whatIfDetails) { Write-Host "   $line" -ForegroundColor Yellow }
                $results.Summary.Skipped += $Config.EntraRolePolicies.Count
                foreach ($policyDef in $Config.EntraRolePolicies | Where-Object { $_.PSObject.Properties['_RoleNotFound'] -and $_._RoleNotFound }) {
                    $results.EntraRolePolicies += [PSCustomObject]@{ RoleName = $policyDef.RoleName; Status = 'SkippedRoleNotFound'; Mode = $PolicyMode; Details = 'Role displayName not found during pre-validation' }
                }
            }
        }
        # Group Policies
        if ($Config.PSObject.Properties['GroupPolicies'] -and $Config.GroupPolicies -and $Config.GroupPolicies.Count -gt 0) {
            # Pre-fetch live policies if in WhatIf mode to filter out matching ones
            $groupLivePolicies = @{}
            if ($isWhatIf) {
                Write-Verbose "WhatIf mode detected: Pre-fetching Group policies to filter matching configurations..."
                try {
                    # Group by GroupId to optimize calls
                    $policiesByGroup = $Config.GroupPolicies | Group-Object -Property GroupId
                    foreach ($groupGroup in $policiesByGroup) {
                        $groupId = $groupGroup.Name
                        $roles = $groupGroup.Group.RoleName
                        if ($groupId -and $roles) {
                            try {
                                # Get-PIMGroupPolicy requires GroupID and Type (owner/member).
                                # It does not support filtering by an array of RoleNames directly.
                                # Therefore, we iterate through each unique role type (owner/member) present in the configuration
                                # to fetch the corresponding policies.
                                $types = $roles | Select-Object -Unique
                                foreach ($type in $types) {
                                    $live = Get-PIMGroupPolicy -tenantID $TenantId -groupID $groupId -type $type -ErrorAction SilentlyContinue
                                    if ($live) {
                                        # Key needs to be unique per group+role
                                        $key = "$groupId|$type"
                                        $groupLivePolicies[$key] = $live
                                    }
                                }
                            } catch { Write-Verbose "Failed to fetch live Group policy for group $groupId: $_" }
                        }
                    }
                } catch { Write-Verbose "Error pre-fetching Group policies: $_" }
            }

            $whatIfDetails = @()
            foreach ($policyDef in $Config.GroupPolicies) {
                $resolvedPolicy = if ($policyDef.ResolvedPolicy) { $policyDef.ResolvedPolicy } else { $policyDef }
                
                # WhatIf Logic: Check for drift if in WhatIf mode
                $isDrift = $true
                $driftReason = ""
                if ($isWhatIf) {
                    try {
                        $key = "$($policyDef.GroupId)|$($policyDef.RoleName)"
                        $live = $groupLivePolicies[$key]
                        
                        if ($live) {
                            $tempResults = @()
                            $tempDrift = 0
                            Compare-PIMPolicy -Type 'Group' -Name $policyDef.RoleName -Expected $resolvedPolicy -Live $live -ExtraId $policyDef.GroupId -Results ([ref]$tempResults) -DriftCount ([ref]$tempDrift)
                            
                            if ($tempDrift -eq 0) {
                                $isDrift = $false
                            } else {
                                $driftItems = $tempResults | Where-Object { $_.Status -eq 'Drift' }
                                $driftReason = " [DRIFT: $($driftItems.Differences -join ', ')]"
                            }
                        }
                    } catch { Write-Verbose "Could not verify drift for Group $($policyDef.GroupId) role $($policyDef.RoleName): $_" }
                }

                if ($isDrift) {
                    $policyDetails = @(
                        "Group ID: '$($policyDef.GroupId)'",
                        "Role: '$($policyDef.RoleName)'$driftReason",
                        "Activation Duration: $($resolvedPolicy.ActivationDuration)",
                        "MFA Required: $(if ($resolvedPolicy.ActivationRequirement -match 'MFA') { 'Yes' } else { 'No' })",
                        "Justification Required: $(if ($resolvedPolicy.ActivationRequirement -match 'Justification') { 'Yes' } else { 'No' })",
                        "Approval Required: $($resolvedPolicy.ApprovalRequired)"
                    )
                    if ($resolvedPolicy.ApprovalRequired -and $resolvedPolicy.PSObject.Properties['Approvers'] -and $resolvedPolicy.Approvers) {
                        $approverList = $resolvedPolicy.Approvers | ForEach-Object {
                            $desc = if ($_.description) { $_.description } else { $_.Name }
                            $idValue = if ($_.id) { $_.id } else { $_.Id }
                            "$desc ($idValue)"
                        }
                        $policyDetails += "Approvers: $($approverList -join ', ')"
                    }
                    if ($resolvedPolicy.PSObject.Properties['AuthenticationContext_Enabled'] -and $resolvedPolicy.AuthenticationContext_Enabled) { $policyDetails += "Authentication Context: $($resolvedPolicy.AuthenticationContext_Value)" }
                    $policyDetails += "Max Eligibility: $($resolvedPolicy.MaximumEligibilityDuration)"
                    $policyDetails += "Permanent Eligibility: $(if ($resolvedPolicy.AllowPermanentEligibility) { 'Allowed' } else { 'Not Allowed' })"
                    $whatIfDetails += "    * $($policyDetails -join ' | ')"
                }
            }
            
            if ($whatIfDetails.Count -eq 0 -and $Config.GroupPolicies.Count -gt 0) {
                $whatIfDetails += "    * [ALL MATCH] All $($Config.GroupPolicies.Count) Group policies match the current configuration."
            }

            $whatIfMessage = "Apply Group Policy configurations:`n$($whatIfDetails -join "`n")"
            if ($PSCmdlet.ShouldProcess($whatIfMessage, "Group Policies")) {
                Write-Host "[PROC] Processing Group Policies..." -ForegroundColor Cyan
                foreach ($policyDef in $Config.GroupPolicies) {
                    $results.Summary.TotalProcessed++
                    try {
                        $policyResult = Set-EPOGroupPolicy -PolicyDefinition $policyDef -TenantId $TenantId -Mode $PolicyMode
                        $results.GroupPolicies += $policyResult
                        if ($policyResult.Status -like "*Protected*") {
                            $results.Summary.Skipped++
                            Write-Host "  [PROTECTED] Protected Group '$($policyDef.GroupId)' role '$($policyDef.RoleName)' - policy change blocked for security" -ForegroundColor Yellow
                        }
                        elseif ($policyResult.Status -like "Failed*") {
                            $results.Summary.Failed++
                            Write-Host "  [FAIL] Group '$($policyDef.GroupId)' role '$($policyDef.RoleName)' policy apply failed (Status=$($policyResult.Status))" -ForegroundColor Red
                        }
                        elseif ($policyResult.Status -like "Skipped*" -or $policyResult.Status -like "Deferred*") {
                            $results.Summary.Skipped++
                            Write-Host "  [SKIPPED] Group '$($policyDef.GroupId)' role '$($policyDef.RoleName)' (Status=$($policyResult.Status))" -ForegroundColor Yellow
                        }
                        elseif ($policyResult.Status -like "CmdletMissing*") {
                            $results.Summary.Failed++
                            Write-Host "  [FAIL] Group '$($policyDef.GroupId)' role '$($policyDef.RoleName)' required cmdlet missing" -ForegroundColor Red
                        }
                        else {
                            $results.Summary.Successful++
                            $resolved = $policyDef.ResolvedPolicy
                            if ($resolved) {
                                $act = $resolved.ActivationDuration
                                $reqs = @(); if ($resolved.ActivationRequirement -match 'MFA') { $reqs += 'MFA' }; if ($resolved.ActivationRequirement -match 'Justification') { $reqs += 'Justification' }
                                $reqsTxt = if ($reqs) { $reqs -join '+' } else { 'None' }
                                $appr = if ($resolved.ApprovalRequired) { "Yes($($resolved.Approvers.Count) approvers)" } else { 'No' }
                                $elig = $resolved.MaximumEligibilityDuration
                                $permElig = if ($resolved.AllowPermanentEligibility) { 'Allowed' } else { 'No' }
                                $actMax = $resolved.MaximumActiveAssignmentDuration
                                $permAct = if ($resolved.AllowPermanentActiveAssignment) { 'Allowed' } else { 'No' }
                                $notifCount = ($resolved.PSObject.Properties | Where-Object { $_.Name -like 'Notification_*' }).Count
                                $summary = "Activation=$act Requirements=$reqsTxt Approval=$appr Elig=$elig PermElig=$permElig Active=$actMax PermActive=$permAct Notifications=$notifCount"
                            } else { $summary = '' }
                            Write-Host "  [OK] Applied policy for Group '$($policyDef.GroupId)' role '$($policyDef.RoleName)' $summary" -ForegroundColor Green
                        }
                    } catch { $errorMsg = "Failed to apply Group policy for '$($policyDef.GroupId)' role '$($policyDef.RoleName)': $($_.Exception.Message)"; Write-Error $errorMsg; $results.Errors += $errorMsg; $results.Summary.Failed++ }
                }
            } else {
                Write-Host "[WARNING] Skipping Group Policies processing due to WhatIf" -ForegroundColor Yellow
                Write-Host "   Would have applied the following policy configurations:" -ForegroundColor Yellow
                foreach ($line in $whatIfDetails) { Write-Host "   $line" -ForegroundColor Yellow }
                $results.Summary.Skipped += $Config.GroupPolicies.Count
            }
        }
        Write-Verbose "New-EPOEasyPIMPolicies completed. Processed: $($results.Summary.TotalProcessed), Successful: $($results.Summary.Successful), Failed: $($results.Summary.Failed)"
        return $results
    } catch { Write-Error "Failed to process PIM policies: $($_.Exception.Message)"; throw }
}
