function Invoke-DeltaCleanup {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ResourceType,
        
        [Parameter(Mandatory = $true)]
        [array]$ConfigAssignments,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$ApiInfo,
        
        [Parameter(Mandatory = $false)]
        [array]$ProtectedUsers = @()
    )

    #region Prevent duplicate calls
    # Simple solution: track using a hashtable of processed resource types
    if (-not $script:ProcessedCleanups) { $script:ProcessedCleanups = @{} }
    
    $uniqueKey = $ResourceType
    if ($ApiInfo.GroupId) { $uniqueKey += "-$($ApiInfo.GroupId)" }
    
    if ($script:ProcessedCleanups.ContainsKey($uniqueKey)) {
        Write-Output "`n⚠️ Cleanup for '$ResourceType' already processed - skipping duplicate call`n"
        return
    }
    
    # Mark as processed
    $script:ProcessedCleanups[$uniqueKey] = (Get-Date)
    #endregion
    
    #region Setup
    # Display header
    Write-Output "`n┌────────────────────────────────────────────────────┐"
    Write-Output "│ Processing $ResourceType Delta Cleanup"
    Write-Output "└────────────────────────────────────────────────────┘`n"
    
    # Initialize counters
    $removeCounter = 0
    $skipCounter = 0
    $keptCounter = 0
    
    # Create a tracking set for processed assignments to avoid duplicates
    $processedAssignments = @{}

    # Define resource type specific settings directly
    $config = $null
    switch ($ResourceType) {
        "Azure Role eligible" {
            $config = @{
                ApiEndpoint = "/providers/Microsoft.Authorization/roleEligibilityScheduleRequests"
                ApiVersion = "2020-10-01"
                RemoveCmd = "Remove-PIMAzureResourceEligibleAssignment"
                SubscriptionBased = $true
                Filter = "status eq 'Provisioned'"
            }
        }
        "Azure Role active" {
            $config = @{
                ApiEndpoint = "/providers/Microsoft.Authorization/roleAssignmentScheduleRequests"
                ApiVersion = "2020-10-01"
                RemoveCmd = "Remove-PIMAzureResourceActiveAssignment"
                SubscriptionBased = $true
                Filter = "status eq 'Provisioned'"
            }
        }
        "Entra Role eligible" {
            $config = @{
                ApiEndpoint = "https://graph.microsoft.com/beta/roleManagement/directory/roleEligibilityScheduleInstances"
                ApiVersion = "beta"
                RemoveCmd = "Remove-PIMEntraRoleEligibleAssignment"
                SubscriptionBased = $false
                GraphBased = $true
            }
        }
        "Entra Role active" {
            $config = @{
                ApiEndpoint = "https://graph.microsoft.com/beta/roleManagement/directory/roleAssignmentScheduleInstances"
                ApiVersion = "beta"
                RemoveCmd = "Remove-PIMEntraRoleActiveAssignment"
                SubscriptionBased = $false
                GraphBased = $true
            }
        }
        "Group eligible" {
            $config = @{
                ApiEndpoint = "https://graph.microsoft.com/beta/roleManagement/directory/roleEligibilityScheduleInstances"
                ApiVersion = "beta"
                RemoveCmd = "Remove-PIMGroupEligibleAssignment"
                SubscriptionBased = $false
                GraphBased = $true
                GroupBased = $true
            }
        }
        "Group active" {
            $config = @{
                ApiEndpoint = "https://graph.microsoft.com/beta/roleManagement/directory/roleAssignmentScheduleInstances"
                ApiVersion = "beta"
                RemoveCmd = "Remove-PIMGroupActiveAssignment"
                SubscriptionBased = $false
                GraphBased = $true
                GroupBased = $true
            }
        }
        default {
            throw "Unknown resource type: $ResourceType"
        }
    }
    
    # Justification filter used for identifying our assignments
    $justificationFilter = "Invoke-EasyPIMOrchestrator"

    Write-Verbose "========== CONFIG ASSIGNMENTS DUMP ==========="
    foreach ($cfg in $ConfigAssignments) {
        $cfgId = $cfg.PrincipalId
        $cfgRole = $cfg.Role ?? $cfg.RoleName ?? "MISSING_ROLE"
        $cfgScope = $cfg.Scope ?? "NO_SCOPE"
        Write-Verbose "Config Assignment: Principal=$cfgId, Role=$cfgRole, Scope=$cfgScope"
    }
    Write-Verbose "========== END CONFIG DUMP ==========="
    #endregion
    
    #region Process by resource type
    try {
        # Azure Resource roles
        if ($config.SubscriptionBased) {
            # Process each subscription
            foreach ($subscription in $ApiInfo.Subscriptions) {
                Write-Output "  🔍 Checking subscription: $subscription"
                
                # Get current assignments 
                $getCmd = if ($ResourceType -eq "Azure Role eligible") {
                    "get-pimAzureResourceEligibleAssignment"
                } else {
                    "get-pimAzureResourceActiveAssignment"
                }
                
                # Get assignments and process
                $allAssignments = & $getCmd -SubscriptionId $subscription -TenantId $ApiInfo.TenantId
                Write-Output "    ├─ Found $($allAssignments.Count) total current assignments"

                # Debug the first assignment to see its structure
                if ($allAssignments.Count -gt 0) {
                    $firstAssignment = $allAssignments[0]
                    Write-Verbose "DEBUG: First assignment properties: $($firstAssignment | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name)"
                    Write-Verbose "DEBUG: First assignment: $($firstAssignment | ConvertTo-Json -Depth 2 -Compress)"
                }

                # Process each assignment
                if ($allAssignments.Count -gt 0) {
                    Write-Output "`n  📋 Analyzing assignments:"
                    
                    foreach ($assignment in $allAssignments) {
                        # Extract assignment details - handle different property naming conventions
                        # Try different property names based on API version
                        $principalId = $assignment.PrincipalId ?? $assignment.SubjectId ?? $assignment.principalId
                        $roleName = $assignment.RoleDefinitionDisplayName ?? $assignment.RoleName ?? $assignment.roleName
                        $principalName = $assignment.PrincipalDisplayName ?? $assignment.SubjectName ?? $assignment.displayName ?? "Principal-$principalId"
                        
                        # Different ways scope might be exposed
                        $scope = $assignment.ResourceId ?? $assignment.scope ?? $assignment.Scope ?? $assignment.directoryScopeId
                        
                        # Create a unique key to track this assignment
                        $assignmentKey = "$principalId|$roleName|$scope"
                        
                        # Skip if we've already processed this assignment
                        if ($processedAssignments.ContainsKey($assignmentKey)) {
                            Write-Verbose "Skipping duplicate processing of assignment: $principalName with role '$roleName'"
                            continue
                        }
                        
                        # Mark as processed
                        $processedAssignments[$assignmentKey] = $true
                        
                        # For debugging property access issues
                        if (-not $principalId -or -not $roleName) {
                            Write-Output "    ├─ ⚠️ Invalid assignment data, skipping"
                            Write-Verbose "DEBUG: Invalid assignment: $($assignment | ConvertTo-Json -Depth 2 -Compress)"
                            $skipCounter++
                            continue
                        }
                        
                        # Check if assignment matches config
                        $foundInConfig = $false
                
                        # Add detailed debug output
                        Write-Verbose "Checking if assignment is in config: PrincipalId=$principalId, RoleName=$roleName, Scope=$scope"
                
                        # Loop through each assignment in config
                        foreach ($configAssignment in $ConfigAssignments) {
                            # Get config role name with case-insensitive property lookup
                            $configRole = $null
                            foreach ($propName in @("RoleName", "Rolename", "Role", "roleName", "rolename", "role")) {
                                if ($configAssignment.PSObject.Properties.Name -contains $propName) {
                                    $configRole = $configAssignment.$propName
                                    break
                                }
                            }
                            
                            # Get the principal ID with similar case-insensitive approach
                            $configPrincipalId = $null
                            foreach ($propName in @("PrincipalId", "principalId", "PrincipalID", "principalID")) {
                                if ($configAssignment.PSObject.Properties.Name -contains $propName) {
                                    $configPrincipalId = $configAssignment.$propName
                                    break
                                }
                            }
                            
                            # Get the scope with case-insensitive approach
                            $configScope = $null
                            foreach ($propName in @("Scope", "scope")) {
                                if ($configAssignment.PSObject.Properties.Name -contains $propName) {
                                    $configScope = $configAssignment.$propName
                                    break
                                }
                            }
                            
                            # Debug output to help diagnose matching issues
                            Write-Verbose "Comparing assignment: Principal=$principalId, Role=$roleName, Scope=$scope"
                            Write-Verbose "With config: Principal=$configPrincipalId, Role=$configRole, Scope=$configScope"
                            
                            # Check Principal ID match - must match exactly
                            $principalMatches = $configPrincipalId -eq $principalId
                            
                            # Check role name match - case insensitive comparison
                            $roleMatches = $configRole -ieq $roleName
                            
                            # Check scope match directly
                            $scopeMatches = $false
                            if ($configScope) {
                                # Only do direct scope comparison - no subscription ID extraction
                                if ($configScope -eq $scope) {
                                    $scopeMatches = $true
                                    Write-Verbose "Scope exact match: $configScope"
                                }
                                # Handle empty scope by using subscription context
                                elseif ([string]::IsNullOrEmpty($scope) -and $subscription) {
                                    $inferredScope = "/subscriptions/$subscription"
                                    if ($configScope -eq $inferredScope) {
                                        $scopeMatches = $true
                                        $scope = $inferredScope  # Set for removal function
                                        Write-Verbose "Empty scope matched with inferred subscription scope: $inferredScope"
                                    }
                                }
                            }
                            else {
                                # If config has no scope, only match if assignment also has no scope
                                $scopeMatches = [string]::IsNullOrEmpty($scope)
                                Write-Verbose "Config has no scope, assignment scope is empty: $scopeMatches"
                            }
                            
                            Write-Verbose "Match results: Principal=$principalMatches, Role=$roleMatches, Scope=$scopeMatches"
                            
                            # Match found if all three components match
                            if ($principalMatches -and $roleMatches -and $scopeMatches) {
                                $foundInConfig = $true
                                Write-Verbose "✅ Match found in config!"
                                break
                            }
                        }
                        
                        # Keep assignment if it's in config
                        if ($foundInConfig) {
                            Write-Output "    ├─ ✅ $principalName with role '$roleName' matches config, keeping"
                            $keptCounter++
                            continue
                        }
                        
                        # Check if protected user
                        if ($ProtectedUsers -contains $principalId) {
                            Write-Output "    ├─ 🛡️ $principalName with role '$roleName' is a protected user, skipping"
                            $skipCounter++
                            continue
                        }

                        # Check if assignment is inherited
                        $isInherited = $false

                        # Check for memberType property first - this is what your debug output shows
                        if ($assignment.PSObject.Properties.Name -contains "memberType" -and $assignment.memberType -eq "Inherited") {
                            Write-Output "    ├─ ⏭️ $principalName with role '$roleName' is an inherited assignment (memberType=Inherited), skipping"
                            $isInherited = $true
                        }
                        # Check for ScopeType property indicating management group
                        elseif ($assignment.PSObject.Properties.Name -contains "ScopeType" -and $assignment.ScopeType -eq "managementgroup") {
                            Write-Output "    ├─ ⏭️ $principalName with role '$roleName' is a management group assignment (ScopeType=managementgroup), skipping"
                            $isInherited = $true
                        }
                        # Check for ScopeId indicating management group
                        elseif ($assignment.PSObject.Properties.Name -contains "ScopeId" -and $assignment.ScopeId -like "*managementGroups*") {
                            Write-Output "    ├─ ⏭️ $principalName with role '$roleName' is a management group assignment (ScopeId contains managementGroups), skipping"
                            $isInherited = $true
                        }
                        # Keep the existing checks as fallbacks
                        elseif ($assignment.PSObject.Properties.Name -contains "AssignmentType" -and $assignment.AssignmentType -eq "Inherited") {
                            $isInherited = $true
                        }
                        elseif ($assignment.PSObject.Properties.Name -contains "IsInherited" -and $assignment.IsInherited -eq $true) {
                            $isInherited = $true
                        }
                        elseif ($assignment.PSObject.Properties.Name -contains "Scope" -and 
                                $assignment.Scope -ne $scope -and 
                                $scope.StartsWith($assignment.Scope)) {
                            $isInherited = $true
                        }
                        elseif ($assignment.PSObject.Properties.Name -contains "InheritedFrom" -and 
                                -not [string]::IsNullOrEmpty($assignment.InheritedFrom)) {
                            $isInherited = $true
                        }

                        # Skip inherited assignments
                        if ($isInherited) {
                            Write-Output "    ├─ ⏭️ $principalName with role '$roleName' is an inherited assignment, cannot be removed at this scope"
                            $skipCounter++
                            continue
                        }
                        
                        # Remove assignment
                        Write-Output "    ├─ ❓ $principalName with role '$roleName' not in config, removing..."

                        # Prepare parameters for removal - use the exact scope value
                        $removeParams = @{ 
                            tenantID = $ApiInfo.TenantId
                            principalId = $principalId
                            roleName = $roleName
                        }

                        # Only add scope if it's not empty
                        if (-not [string]::IsNullOrEmpty($scope)) {
                            $removeParams.scope = $scope
                        }

                        # Skip sensitive roles
                        if ($roleName -eq "User Access Administrator") {
                            Write-Warning "    │  └─ ⚠️ Skipping removal of sensitive role: User Access Administrator"
                            $skipCounter++
                            continue
                        }

                        # Remove the assignment
                        if ($PSCmdlet.ShouldProcess("Remove $ResourceType assignment for $principalName with role '$roleName'")) {
                            try {
                                Write-Verbose "Attempting to remove $principalName with role '$roleName'"
                                
                                # The Remove-* command might output "SUCCESS : Assignment removed!" directly
                                # Capture both the output and the actual return value
                                $outputLines = New-Object System.Collections.ArrayList
                                $result = & $config.RemoveCmd @removeParams 2>&1 | ForEach-Object {
                                    $outputLines.Add($_) | Out-Null
                                    $_
                                }
                                
                                # Look for direct error objects in the result
                                $hasError = $false
                                if ($result -is [System.Management.Automation.ErrorRecord]) {
                                    $hasError = $true
                                    Write-Warning "    │  └─ ⚠️ Removal failed: $($result.Exception.Message)"
                                }
                                elseif ($result.PSObject.Properties.Name -contains "error" -and $result.error -ne $null) {
                                    $hasError = $true
                                    Write-Warning "    │  └─ ⚠️ Removal failed: $($result.error.message ?? 'Unknown error')"
                                }
                                
                                # Check for "SUCCESS" in the output string itself
                                $successMessage = $outputLines | Where-Object { $_ -match "SUCCESS" }
                                if ($successMessage -and -not $hasError) {
                                    # Verify removal actually worked (optional for safety)
                                    $removeCounter++
                                    Write-Output "    │  └─ 🗑️ Removed successfully"
                                }
                                else {
                                    $skipCounter++
                                }
                            } 
                            catch {
                                # Check for inheritance-related errors
                                if ($_.Exception.Message -match "InsufficientPermissions|inherited|cannot delete|does not belong") {
                                    Write-Warning "    │  └─ ⚠️ Cannot remove: $($_.Exception.Message)"
                                    $skipCounter++
                                }
                                else {
                                    Write-Error "    │  └─ ❌ Failed to remove: $_"
                                }
                            }
                        } 
                        else {
                            $skipCounter++
                            Write-Output "    │  └─ ⏭️ Removal skipped (WhatIf mode)"
                        }
                    }
                }
            }
        }
        # Entra ID roles
        elseif ($config.GraphBased -and -not $config.GroupBased) {
            Write-Output "  🔍 Checking Entra roles"
            
            # Query MS Graph for assignments with simplified error handling
            try {
                # Get directory roles for name resolution
                $directoryRoles = (Invoke-Graph -endpoint "/directoryRoles" -Method Get).value
                $roleTemplates = (Invoke-Graph -endpoint "/directoryRoleTemplates" -Method Get).value
                
                # Get instances (current assignments)
                $instancesEndpoint = ($config.ApiEndpoint -replace "https://graph.microsoft.com/beta", "")
                $allInstances = (Invoke-Graph -endpoint $instancesEndpoint -Method Get).value
                
                Write-Output "    ├─ Found $($allInstances.Count) active instances (current assignments)"
                
                # Process each assignment
                if ($allInstances.Count -gt 0) {
                    Write-Output "`n  📋 Analyzing assignments:"
                    
                    foreach ($assignment in $allInstances) {
                        $principalId = $assignment.principalId
                        $roleDefinitionId = $assignment.roleDefinitionId
                        
                        # Lookup role name from directory roles
                        $roleName = "Unknown Role"
                        $role = $directoryRoles | Where-Object { $_.id -eq $roleDefinitionId } | Select-Object -First 1
                        if ($role) {
                            $roleName = $role.displayName
                        } else {
                            $template = $roleTemplates | Where-Object { $_.id -eq $roleDefinitionId } | Select-Object -First 1
                            if ($template) { $roleName = $template.displayName }
                        }
                        
                        # Get principal name
                        $principalName = "Principal-$principalId"
                        try {
                            $principalObj = Invoke-Graph -endpoint "/directoryObjects/$principalId" -Method Get -ErrorAction SilentlyContinue
                            if ($principalObj.displayName) { $principalName = $principalObj.displayName }
                        } catch {}
                        
                        # Check if assignment matches config
                        $foundInConfig = $false
                        foreach ($configAssignment in $ConfigAssignments) {
                            $matchesPrincipal = $configAssignment.PrincipalId -eq $principalId
                            $matchesRole = $configAssignment.Rolename -ieq $roleName
                            
                            if ($matchesPrincipal -and $matchesRole) {
                                $foundInConfig = $true
                                break
                            }
                        }
                        
                        # Keep assignment if it's in config
                        if ($foundInConfig) {
                            Write-Output "    ├─ ✅ $principalName with role '$roleName' matches config, keeping"
                            $keptCounter++
                            continue
                        }
                        
                        # Check if protected user
                        if ($ProtectedUsers -contains $principalId) {
                            Write-Output "    │  └─ 🛡️ Protected user! Skipping removal"
                            $skipCounter++
                            continue
                        }
                        
                        # Remove assignment
                        Write-Output "    ├─ ❓ $principalName with role '$roleName' not in config, removing..."
                        
                        # Prepare parameters for removal
                        $removeParams = @{ 
                            tenantID = $ApiInfo.TenantId
                            principalId = $principalId
                            roleName = $roleName
                        }
                        
                        # Skip sensitive roles
                        if ($roleName -eq "User Access Administrator") {
                            Write-Warning "    │  └─ ⚠️ Skipping removal of sensitive role: User Access Administrator"
                            $skipCounter++
                            continue
                        }
                        
                        # Remove the assignment
                        if ($PSCmdlet.ShouldProcess("Remove $ResourceType assignment for $principalName with role '$roleName'")) {
                            try {
                                $result = & $config.RemoveCmd @removeParams
                                $removeCounter++
                                Write-Output "    │  └─ 🗑️ Removed successfully"
                            } 
                            catch {
                                # Check for inheritance or permission errors
                                if ($_.Exception.Message -match "InsufficientPermissions" -or 
                                    $_.Exception.Message -match "inherited" -or 
                                    $_.Exception.Message -match "cannot delete an assignment" -or
                                    $_.Exception.Message -match "does not belong") {
                                    Write-Warning "    │  └─ ⚠️ Cannot remove: Assignment appears to be inherited from a higher scope"
                                    $skipCounter++
                                }
                                else {
                                    Write-Error "    │  └─ ❌ Failed to remove: $_"
                                }
                            }
                        } else {
                            $skipCounter++
                            Write-Output "    │  └─ ⏭️ Removal skipped (WhatIf mode)"
                        }
                    }
                }
            }
            catch {
                if ($_.Exception.Message -match "Permission") {
                    Write-Warning "⚠️ Insufficient permissions to manage Entra role assignments."
                    Write-Warning "Required permissions: RoleEligibilitySchedule.ReadWrite.Directory, RoleManagement.ReadWrite.Directory"
                }
                else {
                    Write-Error "Failed to query Entra role assignments: $_"
                }
            }
        }
        # Group roles
        elseif ($config.GraphBased -and $config.GroupBased) {
            Write-Output "  ⚠️ $ResourceType cleanup via Graph API - Not yet implemented"
        }
    }
    catch {
        Write-Error "An error occurred processing $ResourceType cleanup: $_"
    }
    #endregion
    
    #region Summary
    Write-Output "`n┌────────────────────────────────────────────────────┐"
    Write-Output "│ $ResourceType Cleanup Summary"
    Write-Output "├────────────────────────────────────────────────────┤"
    Write-Output "│ ✅ Kept:    $keptCounter"
    Write-Output "│ 🗑️ Removed: $removeCounter" 
    Write-Output "│ ⏭️ Skipped: $skipCounter"
    Write-Output "└────────────────────────────────────────────────────┘`n"
    #endregion
}