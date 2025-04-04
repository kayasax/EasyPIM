function New-EasyPIMAssignments {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config,
        
        [Parameter(Mandatory = $true)]
        [string]$TenantId,
        
        [Parameter()]
        [string]$SubscriptionId
    )
    
    Write-SectionHeader "Processing Assignments"
    
    $results = [PSCustomObject]@{
        Created = 0
        Skipped = 0
        Failed = 0
    }
    
    # Process Azure Role eligible assignments
    if ($Config.AzureRoles -and $Config.AzureRoles.Count -gt 0) {
        Write-SubHeader "Processing Azure Role Eligible Assignments"
        
        $commandMap = New-CommandMap -ResourceType 'AzureRoleEligible' -TenantId $TenantId -SubscriptionId $SubscriptionId -FirstAssignment $Config.AzureRoles[0]
        
        $azureResult = Invoke-ResourceAssignments -ResourceType "Azure Role eligible" -Assignments $Config.AzureRoles -CommandMap $commandMap
        
        Write-Summary -Category "Azure Role Eligible Assignments" -Created $azureResult.Created -Skipped $azureResult.Skipped -Failed $azureResult.Failed
        
        $results.Created += $azureResult.Created
        $results.Skipped += $azureResult.Skipped
        $results.Failed += $azureResult.Failed
    }
    
    # Process Azure Role active assignments
    if ($Config.AzureRolesActive -and $Config.AzureRolesActive.Count -gt 0) {
        Write-SubHeader "Processing Azure Role Active Assignments"
        
        $commandMap = New-CommandMap -ResourceType 'AzureRoleActive' -TenantId $TenantId -SubscriptionId $SubscriptionId -FirstAssignment $Config.AzureRolesActive[0]
        
        $azureActiveResult = Invoke-ResourceAssignments -ResourceType "Azure Role active" -Assignments $Config.AzureRolesActive -CommandMap $commandMap
        
        Write-Summary -Category "Azure Role Active Assignments" -Created $azureActiveResult.Created -Skipped $azureActiveResult.Skipped -Failed $azureActiveResult.Failed
        
        $results.Created += $azureActiveResult.Created
        $results.Skipped += $azureActiveResult.Skipped
        $results.Failed += $azureActiveResult.Failed
    }
    
    # Process Entra ID Role eligible assignments
    if ($Config.EntraIDRoles -and $Config.EntraIDRoles.Count -gt 0) {
        Write-SubHeader "Processing Entra ID Role Eligible Assignments"
        
        $commandMap = New-CommandMap -ResourceType 'EntraRoleEligible' -TenantId $TenantId -FirstAssignment $Config.EntraIDRoles[0]
        
        $entraResult = Invoke-ResourceAssignments -ResourceType "Entra ID Role eligible" -Assignments $Config.EntraIDRoles -CommandMap $commandMap
        
        Write-Summary -Category "Entra ID Role Eligible Assignments" -Created $entraResult.Created -Skipped $entraResult.Skipped -Failed $entraResult.Failed
        
        $results.Created += $entraResult.Created
        $results.Skipped += $entraResult.Skipped
        $results.Failed += $entraResult.Failed
    }
    
    # Process Entra ID Role active assignments
    if ($Config.EntraIDRolesActive -and $Config.EntraIDRolesActive.Count -gt 0) {
        Write-SubHeader "Processing Entra ID Role Active Assignments"
        
        # Verify principals exist
        $validAssignments = $Config.EntraIDRolesActive | Where-Object {
            $exists = Test-PrincipalExists -PrincipalId $_.PrincipalId
            if (-not $exists) {
                Write-Warning "⚠️ Principal $($_.PrincipalId) does not exist, skipping assignment"
                $results.Failed++
                return $false
            }
            return $true
        }
        
        if ($validAssignments.Count -gt 0) {
            $commandMap = New-CommandMap -ResourceType 'EntraRoleActive' -TenantId $TenantId -FirstAssignment $validAssignments[0]
            
            $entraActiveResult = Invoke-ResourceAssignments -ResourceType "Entra ID Role active" -Assignments $validAssignments -CommandMap $commandMap
            
            Write-Summary -Category "Entra ID Role Active Assignments" -Created $entraActiveResult.Created -Skipped $entraActiveResult.Skipped -Failed $entraActiveResult.Failed
            
            $results.Created += $entraActiveResult.Created
            $results.Skipped += $entraActiveResult.Skipped
            $results.Failed += $entraActiveResult.Failed
        }
    }
    
    # Process Group Role assignments with special handling
    if ($Config.GroupRoles -and $Config.GroupRoles.Count -gt 0) {
        # Group roles in separate sections by GroupId
        $groupsByGroupId = $Config.GroupRoles | Group-Object -Property GroupId

        foreach ($group in $groupsByGroupId) {
            $groupId = $group.Name
            $groupAssignments = $group.Group
            
            # Validate group exists and is eligible for PIM
            try {
                $uri = "https://graph.microsoft.com/v1.0/directoryObjects/$groupId"
                $null = Invoke-MgGraphRequest -Uri $uri -Method GET -ErrorAction Stop
                Write-Verbose "Group $groupId exists and is accessible"
                
                # Check if group is eligible for PIM
                if (-not (Test-GroupEligibleForPIM -GroupId $groupId)) {
                    Write-Warning "⚠️ Group $groupId is not eligible for PIM management (likely synced from on-premises), skipping all assignments"
                    $results.Skipped += $groupAssignments.Count
                    continue  # Skip this group entirely
                }
            }
            catch {
                Write-Warning "⚠️ Group $groupId does not exist, skipping all assignments for this group"
                $results.Failed += $groupAssignments.Count
                continue  # Skip this group entirely
            }
            
            # Proceed with eligible group
            Write-SubHeader "Processing Group Role Eligible ($groupId) Assignments"
            
            # Pass groupId explicitly to New-CommandMap
            $commandMap = New-CommandMap -ResourceType 'GroupRoleEligible' -TenantId $TenantId -GroupId $groupId -FirstAssignment $groupAssignments[0]
            
            $groupResult = Invoke-ResourceAssignments -ResourceType "Group Role eligible ($groupId)" -Assignments $groupAssignments -CommandMap $commandMap
            
            # Add this summary call if it's missing
            Write-Summary -Category "Group Role Eligible Assignments ($groupId)" -Created $groupResult.Created -Skipped $groupResult.Skipped -Failed $groupResult.Failed
            
            # Update results
            $results.Created += $groupResult.Created
            $results.Skipped += $groupResult.Skipped
            $results.Failed += $groupResult.Failed
        }
    }
    
    # Process Group Role active assignments
    if ($Config.GroupRolesActive -and $Config.GroupRolesActive.Count -gt 0) {
        $groupRoleActiveResults = New-GroupRoleAssignments -Assignments $Config.GroupRolesActive -TenantId $TenantId -IsActive $true
        
        $results.Created += $groupRoleActiveResults.Created
        $results.Skipped += $groupRoleActiveResults.Skipped
        $results.Failed += $groupRoleActiveResults.Failed
    }
    
    return $results
}

function New-GroupRoleAssignments {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true)]
        [array]$Assignments,
        
        [Parameter(Mandatory = $true)]
        [string]$TenantId,
        
        [Parameter()]
        [bool]$IsActive = $false
    )
    
    $roleType = if ($IsActive) { "Active" } else { "Eligible" }
    Write-SectionHeader "Processing Group Role $roleType Assignments"
    
    $results = [PSCustomObject]@{
        Created = 0
        Skipped = 0
        Failed = 0
    }
    
    # Group roles by GroupId to minimize API calls
    $groupedAssignments = $Assignments | Group-Object -Property GroupId
    
    foreach ($groupSet in $groupedAssignments) {
        $groupId = $groupSet.Name
        $assignmentsForGroup = $groupSet.Group
        
        Write-GroupHeader "Processing group: $groupId with $($assignmentsForGroup.Count) assignments"
        
        # First check if group exists before trying to process assignments
        if (-not (Test-PrincipalExists -PrincipalId $groupId)) {
            Write-StatusWarning "Group $groupId does not exist, skipping all assignments"
            $results.Failed += $assignmentsForGroup.Count
            continue
        }
        
        # Create the command map for this group
        $resourceType = if ($IsActive) { 'GroupRoleActive' } else { 'GroupRoleEligible' }
        $commandMap = New-CommandMap -ResourceType $resourceType -TenantId $TenantId -FirstAssignment $assignmentsForGroup[0]
        
        # Process assignments for this group
        $groupResult = Invoke-ResourceAssignments -ResourceType "Group Role $roleType ($groupId)" -Assignments $assignmentsForGroup -CommandMap $commandMap
        
        $results.Created += $groupResult.Created
        $results.Skipped += $groupResult.Skipped
        $results.Failed += $groupResult.Failed
    }
    
    # Display summary for this type of group assignments
    Write-Summary -Category "Group Role $roleType Assignments (Total)" -Created $results.Created -Skipped $results.Skipped -Failed $results.Failed
    
    return $results
}