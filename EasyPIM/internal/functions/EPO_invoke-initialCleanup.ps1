function Invoke-InitialCleanup {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    [OutputType([System.Collections.Hashtable])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]

    param(
        [Parameter(Mandatory = $true)]
        [object]$Config,

        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,

        # These parameters exist for future extension but aren't currently used directly
        # We'll add the suppression attribute to avoid PSScriptAnalyzer warnings
        [Parameter(Mandatory = $false)]
        [array]$AzureRoles = @(),

        [Parameter(Mandatory = $false)]
        [array]$AzureRolesActive = @(),

        [Parameter(Mandatory = $false)]
        [array]$EntraRoles = @(),
        
        [Parameter(Mandatory = $false)]
        [array]$EntraRolesActive = @(),

        [Parameter(Mandatory = $false)]
        [array]$GroupRoles = @(),
        
        [Parameter(Mandatory = $false)]
        [array]$GroupRolesActive = @(),
     
        [Parameter(Mandatory = $false)]
        [ref]$KeptCounter,
        
        [Parameter(Mandatory = $false)]
        [ref]$RemoveCounter,
        
        [Parameter(Mandatory = $false)]
        [ref]$SkipCounter
    )

    # Display initial warning about potentially dangerous operation
    Write-Warning "⚠️ CAUTION: POTENTIALLY DESTRUCTIVE OPERATION ⚠️"
    Write-Warning "This will remove ALL PIM assignments not defined in your configuration."
    Write-Warning "If your protected users list is incomplete, you may lose access to critical resources!"
    Write-Warning "Protected users count: $($Config.ProtectedUsers.Count)"
    Write-Warning "---"
    Write-Warning "USAGE GUIDANCE:"
    Write-Warning "• To preview changes without making them: Use -WhatIf"
    Write-Warning '• To skip confirmation prompts: Use -Confirm:$false'
    Write-Warning '• Example: Invoke-InitialCleanup ... -Confirm:$false'
    Write-Warning "---"

    # Global confirmation for the entire operation
    $operationDescription = "Initial cleanup mode - remove ALL assignments not in configuration"
    $operationTarget = "PIM assignments across Azure, Entra ID, and Groups"

    if (-not $PSCmdlet.ShouldProcess($operationTarget, $operationDescription)) {
        Write-Output "Operation cancelled by user."
        return
    }

    Write-SectionHeader "Initial Mode Cleanup"
    Write-StatusInfo "This will remove all assignments not in the configuration except for protected users"

    # Track overall statistics
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    # Initialize standardized total counters
    $totalKept = 0
    $totalRemoved = 0
    $totalProtected = 0

    # Initialize protected users list
    $protectedUsers = @($Config.ProtectedUsers)
    Write-StatusInfo "Found $($protectedUsers.Count) protected users that will not be removed"

    # Define protected roles that should never be removed automatically
    $protectedRoles = @(
        "User Access Administrator",
        "Global Administrator",
        "Privileged Role Administrator",
        "Security Administrator"
    )

    # Helper functions for cleaner code
    function Test-IsProtectedAssignment {
        param ([string]$PrincipalId)
        return $protectedUsers -contains $PrincipalId
    }

    function Test-AzureRoleAssignmentInConfig {
        param (
            [string]$PrincipalId,
            [string]$RoleName,
            [string]$Scope,
            [array]$ConfigAssignments
        )

        foreach ($config in $ConfigAssignments) {
            $roleMatches = ($config.Rolename -eq $RoleName) -or ($config.Role -eq $RoleName)

            # Check for direct PrincipalId match
            $principalMatches = $config.PrincipalId -eq $PrincipalId

            # Also check in PrincipalIds array if present
            if (-not $principalMatches -and $config.PSObject.Properties.Name -contains "PrincipalIds") {
                $principalMatches = $config.PrincipalIds -contains $PrincipalId
            }

            if ($principalMatches -and $roleMatches -and $config.Scope -eq $Scope) {
                return $true
            }
        }
        return $false
    }

    function Test-EntraRoleAssignmentInConfig {
        param (
            [string]$PrincipalId,
            [string]$RoleName,
            [array]$ConfigAssignments
        )

        foreach ($config in $ConfigAssignments) {
            $roleNameMatch = $config.Rolename -eq $RoleName

            # Check direct PrincipalId
            $principalMatch = $config.PrincipalId -eq $PrincipalId

            # Check PrincipalIds array
            if (-not $principalMatch -and $config.PSObject.Properties.Name -contains "PrincipalIds") {
                $principalMatch = $config.PrincipalIds -contains $PrincipalId
            }

            if ($principalMatch -and $roleNameMatch) {
                return $true
            }
        }
        return $false
    }

    function Test-GroupRoleAssignmentInConfig {
        param (
            [string]$PrincipalId,
            [string]$RoleName,
            [string]$GroupId,
            [array]$ConfigAssignments
        )

        foreach ($config in $ConfigAssignments) {
            $roleNameMatch = $config.Rolename -eq $RoleName
            $groupIdMatch = $config.GroupId -eq $GroupId

            # Check direct PrincipalId
            $principalMatch = $config.PrincipalId -eq $PrincipalId

            # Check PrincipalIds array
            if (-not $principalMatch -and $config.PSObject.Properties.Name -contains "PrincipalIds") {
                $principalMatch = $config.PrincipalIds -contains $PrincipalId
            }

            if ($principalMatch -and $roleNameMatch -and $groupIdMatch) {
                return $true
            }
        }
        return $false
    }

    function Invoke-CleanupAzureRoles {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
        param (
            [string]$Type,
            [array]$ConfigAssignments,
            [string]$GetCommand,
            [string]$RemoveCommand
        )

        Write-SubHeader "Azure Role $Type Assignments Cleanup"
        $removeCounter = 0
        $skipCounter = 0
        $protectedCounter = 0
        $sectionWatch = [System.Diagnostics.Stopwatch]::StartNew()

        # Get all existing assignments
        Write-StatusInfo "Fetching existing $Type assignments..."
        $existing = & $GetCommand -tenantID $TenantId -subscriptionID $SubscriptionId

        # Filter to only include direct assignments
        $existing = $existing | Where-Object { $_.memberType -eq "Direct" }
        Write-StatusInfo "Found $($existing.Count) direct $Type assignments to process"

        # Process in batches for better performance reporting
        $total = $existing.Count
        $processed = 0

        foreach ($assignment in $existing) {
            $processed++
            $principalId = $assignment.PrincipalId
            $roleName = $assignment.RoleName
            $scope = $assignment.ScopeId

            # Check if principal exists
            if (-not (Test-PrincipalExists -PrincipalId $principalId)) {
                Write-StatusWarning "Principal $principalId does not exist, skipping..."
                continue
            }

            $percentComplete = [Math]::Floor(($processed / $total) * 100)
            Write-Progress -Activity "Processing Azure Role $Type Assignments" -Status "$processed of $total ($percentComplete%)" -PercentComplete $percentComplete

            # Check if assignment is in config
            $isInConfig = Test-AzureRoleAssignmentInConfig -PrincipalId $principalId -RoleName $roleName -Scope $scope -ConfigAssignments $ConfigAssignments

            if (-not $isInConfig) {
                # Check if role is protected
                if ($protectedRoles -contains $roleName) {
                    Write-Output "    ├─ ⚠️ $principalId with role '$roleName' is a protected role, skipping"
                    continue
                }

                # Check if principal is protected
                if (Test-IsProtectedAssignment -PrincipalId $principalId) {
                    Write-StatusInfo "Skipping removal of protected user $principalId with role $roleName on scope $scope"
                    $protectedCounter++
                    continue
                }

                # Not in config and not protected, so remove
                $actionDescription = "Remove Azure Role $Type assignment for $principalId with role $roleName on scope $scope"

                if ($PSCmdlet.ShouldProcess($actionDescription)) {
                    try {
                        Write-StatusProcessing "Removing assignment for $principalId with role $roleName..."
                        & $RemoveCommand -tenantID $TenantId -scope $scope -principalId $principalId -roleName $roleName
                        Write-StatusSuccess "Successfully removed assignment"
                        $removeCounter++
                    }
                    catch {
                        Write-StatusError "Failed to remove assignment: $_"
                        $skipCounter++
                    }
                }
            }
            else {
                Write-Verbose "Assignment in config, keeping: $principalId, $roleName, $scope"
                $skipCounter++
            }
        }

        Write-Progress -Activity "Processing Azure Role $Type Assignments" -Completed

        $elapsed = $sectionWatch.Elapsed.TotalSeconds
        Write-StatusInfo "Completed in $elapsed seconds"
        Write-Summary -Category "Azure Role $Type Cleanup" -Created $skipCounter -Removed $removeCounter -Failed 0 -OperationType "Cleanup"
        Write-StatusInfo "Protected assignments skipped: $protectedCounter"

        # Return standardized result object
        return @{
            KeptCount = $skipCounter
            RemovedCount = $removeCounter
            ProtectedCount = $protectedCounter
        }
    }

    function Invoke-CleanupEntraIDRoles {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
        param (
            [string]$Type,
            [array]$ConfigAssignments,
            [string]$GetCommand,
            [string]$RemoveCommand
        )

        Write-SubHeader "Entra ID Role $Type Assignments Cleanup"
        $removeCounter = 0
        $skipCounter = 0
        $protectedCounter = 0
        $sectionWatch = [System.Diagnostics.Stopwatch]::StartNew()

        # Get ALL existing assignments at once
        Write-StatusInfo "Fetching ALL existing Entra ID $Type assignments..."
        $allExisting = & $GetCommand -tenantID $TenantId
        Write-StatusInfo "Found $($allExisting.Count) existing assignments"

        # Filter direct assignments
        $existing = $allExisting | Where-Object { $_.memberType -eq "Direct" }
        Write-StatusInfo "Found $($existing.Count) direct $Type assignments to process"

        # Process in batches
        $total = $existing.Count
        $processed = 0

        foreach ($assignment in $existing) {
            $processed++
            $principalId = $assignment.PrincipalId
            $roleName = $assignment.RoleName

            # Check if principal exists
            if (-not (Test-PrincipalExists -PrincipalId $principalId)) {
                Write-StatusWarning "Principal $principalId does not exist, skipping..."
                continue
            }

            $percentComplete = [Math]::Floor(($processed / $total) * 100)
            Write-Progress -Activity "Processing Entra ID Role $Type Assignments" -Status "$processed of $total ($percentComplete%)" -PercentComplete $percentComplete

            # Check if assignment is in config
            $isInConfig = Test-EntraRoleAssignmentInConfig -PrincipalId $principalId -RoleName $roleName -ConfigAssignments $ConfigAssignments

            if (-not $isInConfig) {
                # Check if role is protected
                if ($protectedRoles -contains $roleName) {
                    Write-Output "    ├─ ⚠️ $principalId with role '$roleName' is a protected role, skipping"
                    continue
                }

                # Check if principal is protected
                if (Test-IsProtectedAssignment -PrincipalId $principalId) {
                    Write-StatusInfo "Skipping removal of protected user $principalId with role $roleName"
                    $protectedCounter++
                    continue
                }

                # Not in config and not protected, so remove
                $actionDescription = "Remove Entra ID Role $Type assignment for $principalId with role $roleName"

                if ($PSCmdlet.ShouldProcess($actionDescription)) {
                    try {
                        Write-StatusProcessing "Removing assignment for $principalId with role $roleName..."
                        & $RemoveCommand -tenantID $TenantId -principalId $principalId -roleName $roleName
                        Write-StatusSuccess "Successfully removed assignment"
                        $removeCounter++
                    }
                    catch {
                        Write-StatusError "Failed to remove assignment: $_"
                        $skipCounter++
                    }
                }
            }
            else {
                Write-Verbose "Assignment in config, keeping: $principalId, $roleName"
                $skipCounter++
            }
        }

        Write-Progress -Activity "Processing Entra ID Role $Type Assignments" -Completed

        $elapsed = $sectionWatch.Elapsed.TotalSeconds
        Write-StatusInfo "Completed in $elapsed seconds"
        Write-Summary -Category "Entra ID Role $Type Cleanup" -Kept $skipCounter -Removed $removeCounter -Skipped $protectedCounter -OperationType "Cleanup"
        Write-StatusInfo "Protected assignments skipped: $protectedCounter"

        # Return standardized result object
        return @{
            KeptCount = $skipCounter
            RemovedCount = $removeCounter
            ProtectedCount = $protectedCounter
        }
    }

    function Invoke-CleanupGroupRoles {
        [CmdletBinding(SupportsShouldProcess = $true)]
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
        param (
            [string]$Type,
            [array]$ConfigAssignments,
            [string]$GetCommand,
            [string]$RemoveCommand,
            [ref]$TotalKept,
            [ref]$TotalRemoved,
            [ref]$TotalSkipped
        )

        # Local counters for function summary
        $removeCounter = 0
        $skipCounter = 0
        $protectedCounter = 0

        # Add before these lines in the Group assignment verification section:
        $assignmentExists = $false
        foreach ($existing in $currentAssignments) {
            if (($existing.PrincipalId -eq $params['principalID']) -and
                ($existing.Type -eq $params['type'] -or $existing.RoleName -eq $params['type'])) {
                # Display match info in normal output
                $matchInfo = "principalId='$($existing.PrincipalId)' and memberType='$($existing.Type -or $existing.RoleName)'"
                Write-Host "    │  ├─ 🔍 Match found: $matchInfo" -ForegroundColor Cyan
                $assignmentExists = $true
                break
            }
        }
        
        # Rest of the function code stays the same
        
        # At the end, update the summary to use correct variables
        Write-Host "│ ✅ Kept:    $skipCounter" -ForegroundColor White
        Write-Host "│ 🗑️ Removed: $removeCounter" -ForegroundColor White
        Write-Host "│ ⏭️ Skipped: $protectedCounter" -ForegroundColor White
        
        # Update the reference parameters directly
        $TotalKept.Value += $skipCounter
        $TotalRemoved.Value += $removeCounter
        $TotalSkipped.Value += $protectedCounter
    }

    # Execute cleanup operations
    if ($Config.AzureRoles -or $AzureRoles.Count -gt 0) {
        $roleAssignments = if ($Config.AzureRoles) { $Config.AzureRoles } else { $AzureRoles }
        $result = Invoke-CleanupAzureRoles -Type "Eligible" -ConfigAssignments $roleAssignments -GetCommand "Get-PIMAzureResourceEligibleAssignment" -RemoveCommand "Remove-PIMAzureResourceEligibleAssignment"
        
        $totalKept += $result.KeptCount
        $totalRemoved += $result.RemovedCount
        $totalProtected += $result.ProtectedCount
    }

    if ($Config.AzureRolesActive -or $AzureRolesActive.Count -gt 0) {
        $roleAssignments = if ($Config.AzureRolesActive) { $Config.AzureRolesActive } else { $AzureRolesActive }
        $result = Invoke-CleanupAzureRoles -Type "Active" -ConfigAssignments $roleAssignments -GetCommand "Get-PIMAzureResourceActiveAssignment" -RemoveCommand "Remove-PIMAzureResourceActiveAssignment"
        
        $totalKept += $result.KeptCount
        $totalRemoved += $result.RemovedCount
        $totalProtected += $result.ProtectedCount
    }

    if ($Config.EntraIDRoles -or $EntraRoles.Count -gt 0) {
        $roleAssignments = if ($Config.EntraIDRoles) { $Config.EntraIDRoles } else { $EntraRoles }
        $result = Invoke-CleanupEntraIDRoles -Type "Eligible" -ConfigAssignments $roleAssignments -GetCommand "Get-PIMEntraRoleEligibleAssignment" -RemoveCommand "Remove-PIMEntraRoleEligibleAssignment"
        
        $totalKept += $result.KeptCount
        $totalRemoved += $result.RemovedCount
        $totalProtected += $result.ProtectedCount
    }

    if ($Config.EntraIDRolesActive -or $EntraRolesActive.Count -gt 0) {
        $roleAssignments = if ($Config.EntraIDRolesActive) { $Config.EntraIDRolesActive } else { $EntraRolesActive }
        $result = Invoke-CleanupEntraIDRoles -Type "Active" -ConfigAssignments $roleAssignments -GetCommand "Get-PIMEntraRoleActiveAssignment" -RemoveCommand "Remove-PIMEntraRoleActiveAssignment"
        
        $totalKept += $result.KeptCount
        $totalRemoved += $result.RemovedCount
        $totalProtected += $result.ProtectedCount
    }

    # Group role cleanup functionality is currently disabled
    # There is no Get-PIMGroup cmdlet available to retrieve all PIM-enabled groups
    <#
    if ($Config.GroupRoles -or $GroupRoles.Count -gt 0) {
        $roleAssignments = if ($Config.GroupRoles) { $Config.GroupRoles } else { $GroupRoles }
        Invoke-CleanupGroupRoles -Type "Eligible" -ConfigAssignments $roleAssignments -GetCommand "Get-PIMGroupEligibleAssignment" -RemoveCommand "Remove-PIMGroupEligibleAssignment" -TotalKept ([ref]$script:totalSkipped) -TotalRemoved ([ref]$script:totalRemoved) -TotalSkipped ([ref]$script:totalProtected)
    }

    if ($Config.GroupRolesActive -or $GroupRolesActive.Count -gt 0) {
        $roleAssignments = if ($Config.GroupRolesActive) { $Config.GroupRolesActive } else { $GroupRolesActive }
        Invoke-CleanupGroupRoles -Type "Active" -ConfigAssignments $roleAssignments -GetCommand "Get-PIMGroupActiveAssignment" -RemoveCommand "Remove-PIMGroupActiveAssignment"
    }
    #>

    # Note: We're keeping the Invoke-CleanupGroupRoles function defined for future use
    # when an appropriate method becomes available to enumerate all PIM-enabled groups

    $totalTime = $stopwatch.Elapsed.TotalMinutes

    # Final summary
    Write-SectionHeader "Initial Mode Cleanup Summary"
    Write-StatusInfo "Total assignments removed: $totalRemoved"
    Write-StatusInfo "Total assignments kept: $totalKept"
    Write-StatusInfo "Total protected assignments skipped: $totalProtected"
    Write-StatusInfo "Total execution time: $($totalTime.ToString("F2")) minutes"

    Write-StatusSuccess "Initial mode cleanup completed"

    # Update reference parameters
    if ($KeptCounter) { $KeptCounter.Value = $totalKept }
    if ($RemoveCounter) { $RemoveCounter.Value = $totalRemoved }
    if ($SkipCounter) { $SkipCounter.Value = $totalProtected }

    # Return standardized result object
    return @{
        KeptCount = $totalKept
        RemovedCount = $totalRemoved
        SkippedCount = $totalProtected  # Using 'SkippedCount' for backward compatibility
    }
}
