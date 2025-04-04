function Invoke-EasyPIMCleanup {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([PSCustomObject])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet('initial', 'delta')]
        [string]$Mode,
        
        [Parameter(Mandatory = $true)]
        [string]$TenantId,
        
       [Parameter()]
       [string]$SubscriptionId
    )
    
    Write-SectionHeader "Processing Cleanup"
    
    $results = [PSCustomObject]@{
        Kept = 0
        Removed = 0
        Skipped = 0
        Protected = 0
    }
    
    if ($Mode -eq 'initial') {
        # Call the existing initial cleanup function
        $initialResult = Invoke-InitialCleanup -Config $Config `
            -TenantId $TenantId `
            -SubscriptionId $SubscriptionId `
            -AzureRoles $Config.AzureRoles `
            -AzureRolesActive $Config.AzureRolesActive `
            -EntraRoles $Config.EntraIDRoles `
            -EntraRolesActive $Config.EntraIDRolesActive `
            -GroupRoles $Config.GroupRoles `
            -GroupRolesActive $Config.GroupRolesActive
        
        $results.Kept = $initialResult.KeptCount
        $results.Removed = $initialResult.RemovedCount
        $results.Skipped = $initialResult.SkippedCount
        $results.Protected = $initialResult.ProtectedCount
    }
    else {
        # Delta mode cleanup
        Write-Host "=== Performing Delta Mode Cleanup ===" -ForegroundColor Yellow
        
        # Azure Role eligible delta cleanup
        if ($Config.AzureRoles) {
            Write-SubHeader "Azure Role Eligible Assignments Cleanup"
            $subscriptions = @($Config.AzureRoles.Scope | ForEach-Object { $_.Split("/")[2] } | Select-Object -Unique)
            
            $apiInfo = @{
                Subscriptions = $subscriptions
                TenantId      = $TenantId
                RemoveCmd     = "Remove-PIMAzureResourceEligibleAssignment"
            }
            
            $keptCounter = 0
            $removeCounter = 0
            $skipCounter = 0
            
            Invoke-DeltaCleanup -ResourceType "Azure Role eligible" -ConfigAssignments $Config.AzureRoles -ApiInfo $apiInfo -ProtectedUsers $Config.ProtectedUsers -KeptCounter ([ref]$keptCounter) -RemoveCounter ([ref]$removeCounter) -SkipCounter ([ref]$skipCounter)
            
            $results.Kept += $keptCounter
            $results.Removed += $removeCounter
            $results.Skipped += $skipCounter
        }
        
        # Azure Role active delta cleanup
        if ($Config.AzureRolesActive) {
            Write-SubHeader "Azure Role Active Assignments Cleanup"
            $subscriptions = @($Config.AzureRolesActive.Scope | ForEach-Object { $_.Split("/")[2] } | Select-Object -Unique)
            
            $apiInfo = @{
                Subscriptions    = $subscriptions
                ApiEndpoint      = "https://management.azure.com/subscriptions/$($subscriptions[0])/providers/Microsoft.Authorization/roleAssignmentScheduleRequests"
                TargetIdProperty = "targetRoleAssignmentScheduleId"
                RemoveCmd        = "Remove-PIMAzureResourceActiveAssignment"
                TenantId         = $TenantId
            }
            
            $keptCounter = 0
            $removeCounter = 0
            $skipCounter = 0
            
             Invoke-DeltaCleanup -ResourceType "Azure Role active" -ConfigAssignments $Config.AzureRolesActive -ApiInfo $apiInfo -ProtectedUsers $Config.ProtectedUsers -KeptCounter ([ref]$keptCounter) -RemoveCounter ([ref]$removeCounter) -SkipCounter ([ref]$skipCounter)
            
            $results.Kept += $keptCounter
            $results.Removed += $removeCounter
            $results.Skipped += $skipCounter
        }
        
        # Entra Role eligible delta cleanup
        if ($Config.EntraIDRoles) {
            Write-SubHeader "Entra Role Eligible Assignments Cleanup"
            
            $apiInfo = @{
                Subscriptions = @()  # Not needed for Entra roles
                RemoveCmd     = "Remove-PIMEntraRoleEligibleAssignment"
                TenantId      = $TenantId
            }
            
            $keptCounter = 0
            $removeCounter = 0
            $skipCounter = 0
            
            Invoke-DeltaCleanup -ResourceType "Entra Role eligible" -ConfigAssignments $Config.EntraIDRoles -ApiInfo $apiInfo -ProtectedUsers $Config.ProtectedUsers -KeptCounter ([ref]$keptCounter) -RemoveCounter ([ref]$removeCounter) -SkipCounter ([ref]$skipCounter)
            
            $results.Kept += $keptCounter
            $results.Removed += $removeCounter
            $results.Skipped += $skipCounter
        }
        
        # Entra Role active delta cleanup
        if ($Config.EntraIDRolesActive) {
            Write-SubHeader "Entra Role Active Assignments Cleanup"
            
            $apiInfo = @{
                Subscriptions = @()  # Not needed for Entra roles
                RemoveCmd     = "Remove-PIMEntraRoleActiveAssignment"
                TenantId      = $TenantId
            }
            
            $keptCounter = 0
            $removeCounter = 0
            $skipCounter = 0
            
            Invoke-DeltaCleanup -ResourceType "Entra Role active" -ConfigAssignments $Config.EntraIDRolesActive -ApiInfo $apiInfo -ProtectedUsers $Config.ProtectedUsers -KeptCounter ([ref]$keptCounter) -RemoveCounter ([ref]$removeCounter) -SkipCounter ([ref]$skipCounter)
            
            $results.Kept += $keptCounter
            $results.Removed += $removeCounter
            $results.Skipped += $skipCounter
        }
        
        # Group Role eligible cleanup
        if ($Config.GroupRoles -and $Config.GroupRoles.Count -gt 0) {
            Write-SubHeader "Group Role Eligible Assignments Cleanup"
            
            # Group by GroupId for processing
            $groupsByGroupId = $Config.GroupRoles | Group-Object -Property GroupId
            
            foreach ($group in $groupsByGroupId) {
                $groupId = $group.Name
                $groupAssignments = $group.Group
                
                # Validate group exists and is eligible for PIM
                try {
                    $uri = "https://graph.microsoft.com/v1.0/directoryObjects/$groupId"
                    Invoke-MgGraphRequest -Uri $uri -Method GET -ErrorAction Stop
                    Write-Verbose "Group $groupId exists and is accessible"
                    
                    # Check if group is eligible for PIM
                    if (-not (Test-GroupEligibleForPIM -GroupId $groupId)) {
                        Write-Warning "⚠️ Group $groupId is not eligible for PIM management (likely synced from on-premises), skipping cleanup"
                        $results.Skipped += $groupAssignments.Count
                        continue  # Skip this group entirely
                    }
                }
                catch {
                    Write-Warning "⚠️ Group $groupId does not exist, skipping cleanup for this group"
                    $results.Skipped += $groupAssignments.Count
                    continue
                }
                
                Write-Host "Processing group: $groupId with $($groupAssignments.Count) desired assignments"
                
                # Create API info with this specific group ID
                $apiInfo = @{
                    TenantId = $TenantId
                    GroupIds = @($groupId)
                    RemoveCmd = "Remove-PIMGroupEligibleAssignment"
                }
                
                # Call delta cleanup for this group
                $keptCounter = 0
                $removeCounter = 0
                $skipCounter = 0
                
                Invoke-DeltaCleanup -ResourceType "Group eligible" -ConfigAssignments $groupAssignments -ApiInfo $apiInfo -ProtectedUsers $Config.ProtectedUsers -KeptCounter ([ref]$keptCounter) -RemoveCounter ([ref]$removeCounter) -SkipCounter ([ref]$skipCounter)
                
                # Update results
                $results.Kept += $keptCounter
                $results.Removed += $removeCounter
                $results.Skipped += $skipCounter
            }
        }
        
        # Group Role active cleanup
        if ($Config.GroupRolesActive -and $Config.GroupRolesActive.Count -gt 0) {
            Write-SubHeader "Group Role Active Assignments Cleanup"
            
            # Group by GroupId for processing
            $groupsByGroupId = $Config.GroupRolesActive | Group-Object -Property GroupId
            
            foreach ($group in $groupsByGroupId) {
                $groupId = $group.Name
                $groupAssignments = $group.Group
                
                # Validate group exists and is eligible for PIM
                try {
                    $uri = "https://graph.microsoft.com/v1.0/directoryObjects/$groupId"
                    Invoke-MgGraphRequest -Uri $uri -Method GET -ErrorAction Stop
                    Write-Verbose "Group $groupId exists and is accessible"
                    
                    # Check if group is eligible for PIM
                    if (-not (Test-GroupEligibleForPIM -GroupId $groupId)) {
                        Write-Warning "⚠️ Group $groupId is not eligible for PIM management (likely synced from on-premises), skipping cleanup"
                        $results.Skipped += $groupAssignments.Count
                        continue  # Skip this group entirely
                    }
                }
                catch {
                    Write-Warning "⚠️ Group $groupId does not exist, skipping cleanup for this group"
                    $results.Skipped += $groupAssignments.Count
                    continue
                }
                
                Write-Host "Processing group: $groupId with $($groupAssignments.Count) desired assignments"
                
                # Create API info with this specific group ID
                $apiInfo = @{
                    TenantId = $TenantId
                    GroupIds = @($groupId)
                    RemoveCmd = "Remove-PIMGroupActiveAssignment"
                }
                
                # Call delta cleanup for this group
                $keptCounter = 0
                $removeCounter = 0
                $skipCounter = 0
                
                Invoke-DeltaCleanup -ResourceType "Group active" -ConfigAssignments $groupAssignments -ApiInfo $apiInfo -ProtectedUsers $Config.ProtectedUsers -KeptCounter ([ref]$keptCounter) -RemoveCounter ([ref]$removeCounter) -SkipCounter ([ref]$skipCounter)
                
                # Update results
                $results.Kept += $keptCounter
                $results.Removed += $removeCounter
                $results.Skipped += $skipCounter
            }
        }
    }
    
    Write-Verbose "Cleanup completed. Kept: $($results.Kept), Removed: $($results.Removed), Skipped: $($results.Skipped)"
    return $results
}