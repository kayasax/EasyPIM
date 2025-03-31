function Invoke-InitialCleanup {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Config,
        
        [Parameter(Mandatory = $true)]
        [string]$TenantId,
        
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,
        
        [Parameter(Mandatory = $false)]
        [array]$AzureRoles,
        
        [Parameter(Mandatory = $false)]
        [array]$AzureRolesActive,
        
        [Parameter(Mandatory = $false)]
        [array]$EntraRoles,

        [Parameter(Mandatory = $false)]
        [array]$EntraRolesActive,

        [Parameter(Mandatory = $false)]
        [array]$GroupRoles,
        [Parameter(Mandatory = $false)]
        [array]$GroupRolesActive
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
    $script:totalRemoved = 0
    $script:totalSkipped = 0
    $script:totalProtected = 0
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
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
        $batchSize = [Math]::Min(20, $total)
        
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
        
        # Update global counters
        $script:totalRemoved += $removeCounter
        $script:totalSkipped += $skipCounter
        $script:totalProtected += $protectedCounter
    }
    
    function Invoke-CleanupEntraIDRoles {
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
        Write-Summary -Category "Entra ID Role $Type Cleanup" -Created 0 -Skipped $skipCounter -Failed $removeCounter
        Write-StatusInfo "Protected assignments skipped: $protectedCounter"
        
        # Update global counters
        $script:totalRemoved += $removeCounter
        $script:totalSkipped += $skipCounter
        $script:totalProtected += $protectedCounter
    }
    
    function Invoke-CleanupGroupRoles {
        param (
            [string]$Type,
            [array]$ConfigAssignments,
            [string]$GetCommand,
            [string]$RemoveCommand
        )
        
        Write-SubHeader "Group Role $Type Assignments Cleanup"
        $removeCounter = 0
        $skipCounter = 0
        $protectedCounter = 0
        $sectionWatch = [System.Diagnostics.Stopwatch]::StartNew()
        
        # First get all PIM-enabled groups
        Write-StatusInfo "Retrieving all PIM-enabled groups..."
        try {
            $allGroups = Get-PIMGroup -tenantID $TenantId -ErrorAction Stop
            Write-StatusInfo "Found $($allGroups.Count) PIM-enabled groups"
        }
        catch {
            Write-StatusWarning "Failed to retrieve PIM-enabled groups: $_"
            Write-StatusInfo "Falling back to groups in config"
            $allGroups = $ConfigAssignments | Select-Object -Property @{Name='Id';Expression={$_.GroupId}} -Unique
        }
        
        $groupCount = $allGroups.Count
        $groupProcessed = 0
        
        foreach ($group in $allGroups) {
            $groupProcessed++
            $groupId = $group.Id
            
            Write-Progress -Activity "Processing Group $Type Assignments" -Status "Group $groupProcessed of $groupCount" -PercentComplete (($groupProcessed / $groupCount) * 100)
            Write-StatusInfo "Processing group $groupId ($groupProcessed of $groupCount)..."
            
            # Get existing assignments for this group
            try {
                $existing = & $GetCommand -tenantID $TenantId -groupId $groupId -ErrorAction SilentlyContinue
                if (-not $existing -or $existing.Count -eq 0) { 
                    Write-StatusInfo "No $Type assignments found for group $groupId"
                    continue 
                }
                
                Write-StatusInfo "Found $($existing.Count) existing $Type assignments for group $groupId"
                
                # Get config assignments for this group (prefilter for performance)
                $configAssignmentsForGroup = $ConfigAssignments | Where-Object { $_.GroupId -eq $groupId }
                
                foreach ($assignment in $existing) {
                    $principalId = $assignment.PrincipalId
                    $roleName = $assignment.RoleName
                    
                    # Check if assignment is in config
                    $isInConfig = Test-GroupRoleAssignmentInConfig -PrincipalId $principalId -RoleName $roleName -GroupId $groupId -ConfigAssignments $configAssignmentsForGroup
                    
                    if (-not $isInConfig) {
                        # Check if role is protected
                        if ($protectedRoles -contains $roleName) {
                            Write-Output "    ├─ ⚠️ $principalId with role '$roleName' is a protected role, skipping"
                            continue
                        }
                        
                        # Check if principal is protected
                        if (Test-IsProtectedAssignment -PrincipalId $principalId) {
                            Write-StatusInfo "Skipping removal of protected user $principalId with role $roleName on group $groupId"
                            $protectedCounter++
                            continue
                        }
                        
                        # Not in config and not protected, so remove
                        $actionDescription = "Remove Group Role $Type assignment for $principalId with role $roleName on group $groupId"
                        
                        if ($PSCmdlet.ShouldProcess($actionDescription)) {
                            try {
                                Write-StatusProcessing "Removing $Type assignment..."
                                & $RemoveCommand -tenantID $TenantId -principalId $principalId -roleName $roleName -groupId $groupId
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
                        Write-Verbose "$Type assignment in config, keeping: $principalId, $roleName, $groupId"
                        $skipCounter++
                    }
                }
            }
            catch {
                Write-StatusWarning "Error processing group $groupId : $_"
                continue
            }
        }
        
        Write-Progress -Activity "Processing Group $Type Assignments" -Completed
        
        $elapsed = $sectionWatch.Elapsed.TotalSeconds
        Write-StatusInfo "Completed in $elapsed seconds"
        Write-Host "`n┌────────────────────────────────────────────────────┐" -ForegroundColor Cyan
        Write-Host "│ Group Role $Type Cleanup Summary" -ForegroundColor Cyan
        Write-Host "├────────────────────────────────────────────────────┤" -ForegroundColor Cyan
        Write-Host "│ ✅ Kept:    $keptCounter" -ForegroundColor White
        Write-Host "│ 🗑️ Removed: $removeCounter" -ForegroundColor White
        Write-Host "│ ⏭️ Skipped: $skipCounter" -ForegroundColor White
        if ($protectedCounter -gt 0) {
            Write-Host "│ 🛡️ Protected: $protectedCounter" -ForegroundColor White
        }
        Write-Host "└────────────────────────────────────────────────────┘" -ForegroundColor Cyan
        
        # Update global counters
        $script:totalRemoved += $removeCounter
        $script:totalSkipped += $skipCounter
        $script:totalProtected += $protectedCounter
    }
    
    # Execute cleanup operations
    if ($AzureRoles) {
        Invoke-CleanupAzureRoles -Type "Eligible" -ConfigAssignments $AzureRoles -GetCommand "Get-PIMAzureResourceEligibleAssignment" -RemoveCommand "Remove-PIMAzureResourceEligibleAssignment"
    }
    
    if ($AzureRolesActive) {
        Invoke-CleanupAzureRoles -Type "Active" -ConfigAssignments $AzureRolesActive -GetCommand "Get-PIMAzureResourceActiveAssignment" -RemoveCommand "Remove-PIMAzureResourceActiveAssignment"
    }
    
    if ($EntraRoles) {
        Invoke-CleanupEntraIDRoles -Type "Eligible" -ConfigAssignments $EntraRoles -GetCommand "Get-PIMEntraRoleEligibleAssignment" -RemoveCommand "Remove-PIMEntraRoleEligibleAssignment"
    }
    
    if ($Config.EntraIDRolesActive) {
        Invoke-CleanupEntraIDRoles -Type "Active" -ConfigAssignments $Config.EntraIDRolesActive -GetCommand "Get-PIMEntraRoleActiveAssignment" -RemoveCommand "Remove-PIMEntraRoleActiveAssignment"
    }
    
    # Group role cleanup functionality is currently disabled
    # There is no Get-PIMGroup cmdlet available to retrieve all PIM-enabled groups
    <#
    if ($Config.GroupRoles) {
        Invoke-CleanupGroupRoles -Type "Eligible" -ConfigAssignments $Config.GroupRoles -GetCommand "Get-PIMGroupEligibleAssignment" -RemoveCommand "Remove-PIMGroupEligibleAssignment"
    }

    if ($Config.GroupRolesActive) {
        Invoke-CleanupGroupRoles -Type "Active" -ConfigAssignments $Config.GroupRolesActive -GetCommand "Get-PIMGroupActiveAssignment" -RemoveCommand "Remove-PIMGroupActiveAssignment"
    }
    #>

    # Note: We're keeping the Invoke-CleanupGroupRoles function defined for future use
    # when an appropriate method becomes available to enumerate all PIM-enabled groups
    
    $totalTime = $stopwatch.Elapsed.TotalMinutes
    
    Write-SectionHeader "Initial Mode Cleanup Summary"
    Write-StatusInfo "Total assignments removed: $script:totalRemoved"
    Write-StatusInfo "Total assignments kept: $script:totalSkipped"
    Write-StatusInfo "Total protected assignments skipped: $script:totalProtected"
    Write-StatusInfo "Total execution time: $($totalTime.ToString("F2")) minutes"

       
    Write-StatusSuccess "Initial mode cleanup completed"

    # Update reference parameters with the final counter values
    if ($KeptCounter) { $KeptCounter.Value = $script:keptCounter }
    if ($RemoveCounter) { $RemoveCounter.Value = $script:removeCounter }
    if ($SkipCounter) { $SkipCounter.Value = $script:skipCounter }

    # Create and return a result object for better tracking
    return @{
        KeptCount = $script:totalSkipped  # Skipped in InitialCleanup = kept
        RemovedCount = $script:totalRemoved
        SkippedCount = $script:totalProtected
    }
}