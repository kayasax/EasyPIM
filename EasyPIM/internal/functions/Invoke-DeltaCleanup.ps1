# Define script-level counters at the top of the file (outside any function)
$script:keptCounter = 0
$script:removeCounter = 0
$script:skipCounter = 0

# Define protected roles at script level
$script:protectedRoles = @(
    "User Access Administrator",
    "Global Administrator", 
    "Privileged Role Administrator",
    "Security Administrator"
)

function Invoke-DeltaCleanup {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [string]$ResourceType,
        [array]$ConfigAssignments,
        [hashtable]$ApiInfo,
        [array]$ProtectedUsers,
        # Keep these parameters for compatibility - they're optional now
        [Parameter(Mandatory = $false)]
        [ref]$KeptCounter,
        [Parameter(Mandatory = $false)]
        [ref]$RemoveCounter,
        [Parameter(Mandatory = $false)]
        [ref]$SkipCounter
    )
    
    # Reset script counters at beginning of function call
    $script:keptCounter = 0
    $script:removeCounter = 0
    $script:skipCounter = 0

    # At the end of the function (around line 560), add a tracking variable for protected users:
    $protectedCounter = 0

    #region Prevent duplicate calls
    # Simple solution: track using a hashtable of processed resource types
    if (-not $script:ProcessedCleanups) { $script:ProcessedCleanups = @{} }
    
    $uniqueKey = $ResourceType
    if ($ApiInfo.GroupId) { $uniqueKey += "-$($ApiInfo.GroupId)" }
    
    if ($script:ProcessedCleanups.ContainsKey($uniqueKey)) {
        Write-host "`n⚠️ Cleanup for '$ResourceType' already processed - skipping duplicate call`n"
        return
    }
    
    # Mark as processed
    $script:ProcessedCleanups[$uniqueKey] = (Get-Date)
    #endregion
    
    #region Setup
    # Display header section
    Write-Host "`n┌────────────────────────────────────────────────────┐" -ForegroundColor Cyan
    Write-Host "│ Processing $ResourceType Delta Cleanup" -ForegroundColor Cyan
    Write-Host "└────────────────────────────────────────────────────┘`n" -ForegroundColor Cyan

    if ($config.SubscriptionBased) {
        foreach ($subscription in $ApiInfo.Subscriptions) {
            Write-Host "  🔍 Checking subscription: $subscription" -ForegroundColor White
            
            # Get the assignments
            if ($subscription -and $config.SubscriptionBased) {
                Write-Verbose "Getting assignments for subscription: $subscription"
                $allAssignments = Get-PIMAzureResourceEligibleAssignment -SubscriptionId $subscription -TenantId $ApiInfo.TenantID
                Write-Host "    ├─ Found $($allAssignments.Count) total current assignments" -ForegroundColor White
            }
        }
    }

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
        $cfgRole = $null
        foreach ($propName in @("RoleName", "Rolename", "Role", "roleName", "rolename", "role")) {
            if ($cfg.PSObject.Properties.Name -contains $propName) {
                $cfgRole = $cfg.$propName
                break
            }
        }
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
                Write-Host "  🔍 Checking subscription: $subscription" -ForegroundColor White
                
                # Get current assignments 
                $getCmd = if ($ResourceType -eq "Azure Role eligible") {
                    "get-pimAzureResourceEligibleAssignment"
                } else {
                    "get-pimAzureResourceActiveAssignment"
                }
                
                # Get assignments and process
                $allAssignments = & $getCmd -SubscriptionId $subscription -TenantId $ApiInfo.TenantId
                Write-Host "    ├─ Found $($allAssignments.Count) total current assignments" -ForegroundColor White

                # Debug the first assignment to see its structure
                if ($allAssignments.Count -gt 0) {
                    $firstAssignment = $allAssignments[0]
                    Write-Verbose "DEBUG: First assignment properties: $($firstAssignment | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name)"
                    Write-Verbose "DEBUG: First assignment: $($firstAssignment | ConvertTo-Json -Depth 2 -Compress)"
                }

                
                Write-Host "`n  📋 Processing assignments for: $ResourceType" -ForegroundColor Cyan

                # Process each assignment
                if ($allAssignments.Count -gt 0) {
                    Write-Host "`n  📋 Analyzing assignments:" -ForegroundColor Cyan
                    
                    # Add a counter for processed assignments
                    $processedCount = 0
                    
                    foreach ($assignment in $allAssignments) {
                        $processedCount++
                        
                        # Extract assignment details - handle different property naming conventions
                        # Try different property names based on API version
                        $principalId = if ($null -ne $assignment.PrincipalId) { $assignment.PrincipalId } 
                                       elseif ($null -ne $assignment.SubjectId) { $assignment.SubjectId } 
                                       elseif ($null -ne $assignment.principalId) { $assignment.principalId } 
                                       else { $null }
                                       
                        $roleName = if ($null -ne $assignment.RoleDefinitionDisplayName) { $assignment.RoleDefinitionDisplayName }
                                   elseif ($null -ne $assignment.RoleName) { $assignment.RoleName }
                                   elseif ($null -ne $assignment.roleName) { $assignment.roleName }
                                   else { "Unknown" }
                                   
                        $principalName = if ($null -ne $assignment.PrincipalDisplayName) { $assignment.PrincipalDisplayName }
                                        elseif ($null -ne $assignment.SubjectName) { $assignment.SubjectName }
                                        elseif ($null -ne $assignment.displayName) { $assignment.displayName }
                                        else { "Principal-$principalId" }
                        
                        # Different ways scope might be exposed
                        $scope = if ($null -ne $assignment.ResourceId) { $assignment.ResourceId }
                                elseif ($null -ne $assignment.scope) { $assignment.scope } 
                                elseif ($null -ne $assignment.Scope) { $assignment.Scope }
                                elseif ($null -ne $assignment.directoryScopeId) { $assignment.directoryScopeId }
                                else { $null }
                        
                        # Create a unique key to track this assignment
                        $assignmentKey = "$principalId|$roleName|$scope"
                        
                        # Skip if we've already processed this assignment
                        if ($processedAssignments.ContainsKey($assignmentKey)) {
                            Write-Host "    ├─ ⏭️ $principalName with role '$roleName' is a duplicate entry, skipping" -ForegroundColor DarkYellow
                            $script:skipCounter++
                            Write-Verbose "Skipped duplicate assignment - counter now: $script:skipCounter"
                            continue;
                        }
                        
                        # Mark as processed
                        $processedAssignments[$assignmentKey] = $true
                        
                        # For debugging property access issues
                        if (-not $principalId -or -not $roleName) {
                            Write-Host "    ├─ ⚠️ Invalid assignment data, skipping" -ForegroundColor Yellow
                            Write-Verbose "DEBUG: Invalid assignment: $($assignment | ConvertTo-Json -Depth 2 -Compress)"
                            $script:skipCounter++
                            Write-Verbose "Skipped assignment - counter now: $script:skipCounter"
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
                            
                            # Check Principal ID match
                            $principalMatches = $false

                            # Direct PrincipalId match
                            if ($configPrincipalId -eq $principalId) {
                                $principalMatches = $true
                                Write-Verbose "Principal matched directly"
                            }
                            # Check in PrincipalIds array if present
                            elseif ($configAssignment.PSObject.Properties.Name -contains "PrincipalIds" -and 
                                    $configAssignment.PrincipalIds -is [array]) {
                                $principalMatches = $configAssignment.PrincipalIds -contains $principalId
                                Write-Verbose "Principal checked against PrincipalIds array: $principalMatches"
                            }
                            
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
                            Write-Host "    ├─ ✅ $principalName with role '$roleName' matches config, keeping" -ForegroundColor Green
                            $script:keptCounter++
                            Write-Verbose "Kept assignment - counter now: $script:keptCounter"
                            continue
                        }
                        
                        # Check if protected user
                        if ($ProtectedUsers -contains $assignment.PrincipalId) {
                            Write-Host "    ├─ 🛡️ $principalName with role '$roleName' is a protected user, skipping" -ForegroundColor Yellow
                            $protectedCounter++  # Only increment protected counter, not skip counter
                            continue
                        }

                        # Check if protected role
                        if ($script:protectedRoles -contains $roleName) {
                            Write-host "    ├─ ⚠️ $principalName with role '$roleName' is a protected role, skipping"
                            $protectedCounter++  # Only increment protected counter
                            continue
                        }

                        # Check if assignment is inherited - consolidate all checks
                        $isInherited = $false

                        # Create a tracking variable
                        $inheritedReason = ""

                        # Check for memberType property first
                        if ($assignment.PSObject.Properties.Name -contains "memberType" -and $assignment.memberType -eq "Inherited") {
                            $isInherited = $true
                            $inheritedReason = "memberType=Inherited"
                        }
                        # Check for ScopeType property indicating management group
                        elseif ($assignment.PSObject.Properties.Name -contains "ScopeType" -and $assignment.ScopeType -eq "managementgroup") {
                            $isInherited = $true
                            $inheritedReason = "ScopeType=managementgroup"
                        }
                        # Check for ScopeId indicating management group
                        elseif ($assignment.PSObject.Properties.Name -contains "ScopeId" -and $assignment.ScopeId -like "*managementGroups*") {
                            $isInherited = $true
                            $inheritedReason = "ScopeId contains managementGroups"
                        }

                        if ($isInherited) {
                            Write-Host "    ├─ ⏭️ $principalName with role '$roleName' is an inherited assignment ($inheritedReason), skipping" -ForegroundColor DarkYellow
                            $script:skipCounter++
                            Write-Verbose "Skipped assignment - counter now: $script:skipCounter"
                            continue
                        }
                        
                        # Remove assignment
                        Write-Host "    ├─ ❓ $principalName with role '$roleName' not in config, removing..." -ForegroundColor White

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
                            $script:skipCounter++
                            Write-Verbose "Skipped assignment - counter now: $script:skipCounter"
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
                                    $errorMessage = if ($result.error.PSObject.Properties.Name -contains 'message' -and $result.error.message) {
                                        $result.error.message
                                    } else {
                                        'Unknown error'
                                    }
                                    Write-Warning "    │  └─ ⚠️ Removal failed: $errorMessage"
                                }
                                
                                # Check for "SUCCESS" in the output string itself
                                $successMessage = $outputLines | Where-Object { $_ -match "SUCCESS" }
                                if ($successMessage -and -not $hasError) {
                                    # Verify removal actually worked (optional for safety)
                                    $script:removeCounter++
                                    Write-Verbose "Removed assignment - counter now: $script:removeCounter"
                                    Write-Host "    │  └─ 🗑️ Removed successfully" -ForegroundColor Green
                                }
                                else {
                                    $script:skipCounter++
                                    Write-Verbose "Skipped assignment - counter now: $script:skipCounter"
                                }
                            } 
                            catch {
                                # Check for inheritance-related errors
                                if ($_.Exception.Message -match "InsufficientPermissions|inherited|cannot delete|does not belong") {
                                    Write-Warning "    │  └─ ⚠️ Cannot remove: $($_.Exception.Message)"
                                    $script:skipCounter++
                                    Write-Verbose "Skipped assignment - counter now: $script:skipCounter"
                                }
                                else {
                                    Write-Error "    │  └─ ❌ Failed to remove: $_"
                                }
                            }
                        } 
                        else {
                            $script:skipCounter++
                            Write-Verbose "Skipped assignment - counter now: $script:skipCounter"
                            Write-Host "    │  └─ ⏭️ Removal skipped (WhatIf mode)" -ForegroundColor DarkYellow
                        }
                    }
                }
            }
        }
        # Entra ID roles
        elseif ($config.GraphBased -and -not $config.GroupBased) {
            Write-Host "  🔍 Checking Entra roles" -ForegroundColor White
            
            # Query MS Graph for assignments with simplified error handling
            try {
                # Get directory roles for name resolution
                $directoryRoles = (Invoke-Graph -endpoint "/directoryRoles" -Method Get).value
                $roleTemplates = (Invoke-Graph -endpoint "/directoryRoleTemplates" -Method Get).value
                
                # Get instances (current assignments)
                $instancesEndpoint = ($config.ApiEndpoint -replace "https://graph.microsoft.com/beta", "")
                $allInstances = (Invoke-Graph -endpoint $instancesEndpoint -Method Get).value
                
                Write-Host "    ├─ Found $($allInstances.Count) active instances (current assignments)" -ForegroundColor White
                
                Write-Host "`n  📋 Processing assignments for: $ResourceType" -ForegroundColor Cyan

                # Process each assignment
                if ($allInstances.Count -gt 0) {
                    Write-Host "`n  📋 Analyzing assignments:" -ForegroundColor Cyan
                    
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
                            Write-Host "    ├─ ✅ $principalName with role '$roleName' matches config, keeping" -ForegroundColor Green
                            $script:keptCounter++
                            Write-Verbose "Kept assignment - counter now: $script:keptCounter"
                            continue
                        }
                        
                        # Check if protected user
                        if ($ProtectedUsers -contains $principalId) {
                           Write-Host "    ├─ 🛡️ $principalName with role '$roleName' is a protected user, skipping" -ForegroundColor Yellow
                            $protectedCounter++  # Only increment protected counter, not skip counter
                            continue
                        }

                        # Check if protected role
                        if ($script:protectedRoles -contains $roleName) {
                            Write-Host "    ├─ ⚠️ $principalName with role '$roleName' is a protected role, skipping" -ForegroundColor Yellow
                            $protectedCounter++  # Only increment protected counter
                            continue
                        }
                        
                        # Remove assignment
                        Write-Host "    ├─ ❓ $principalName with role '$roleName' not in config, removing..." -ForegroundColor White
                        
                        # Prepare parameters for removal
                        $removeParams = @{ 
                            tenantID = $ApiInfo.TenantId
                            principalId = $principalId
                            roleName = $roleName
                        }
                        
                        # Skip sensitive roles
                        if ($roleName -eq "User Access Administrator") {
                            Write-Warning "    │  └─ ⚠️ Skipping removal of sensitive role: User Access Administrator"
                            $script:skipCounter++
                            Write-Verbose "Skipped assignment - counter now: $script:skipCounter"
                            continue
                        }
                        
                        # Remove the assignment
                        if ($PSCmdlet.ShouldProcess("Remove $ResourceType assignment for $principalName with role '$roleName'")) {
                            try {
                                $result = & $config.RemoveCmd @removeParams
                                $script:removeCounter++
                                Write-Verbose "Removed assignment - counter now: $script:removeCounter"
                                Write-Host "    │  └─ 🗑️ Removed successfully" -ForegroundColor Green
                            } 
                            catch {
                                # Check for inheritance or permission errors
                                if ($_.Exception.Message -match "InsufficientPermissions" -or 
                                    $_.Exception.Message -match "inherited" -or 
                                    $_.Exception.Message -match "cannot delete an assignment" -or
                                    $_.Exception.Message -match "does not belong") {
                                    Write-Warning "    │  └─ ⚠️ Cannot remove: Assignment appears to be inherited from a higher scope"
                                    $script:skipCounter++
                                    Write-Verbose "Skipped assignment - counter now: $script:skipCounter"
                                }
                                else {
                                    Write-Error "    │  └─ ❌ Failed to remove: $_"
                                }
                            }
                        } else {
                            $script:skipCounter++
                            Write-Verbose "Skipped assignment - counter now: $script:skipCounter"
                            Write-Host "    │  └─ ⏭️ Removal skipped (WhatIf mode)" -ForegroundColor DarkYellow
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
            Write-Host "  ⚠️ $ResourceType cleanup via Graph API - Not yet implemented" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Error "An error occurred processing $ResourceType cleanup: $_"
    }
    #endregion
    
    #region Summary
    # Use Write-Host instead of Write-Output for consistent display
    Write-Host "`n┌────────────────────────────────────────────────────┐" -ForegroundColor Cyan
    Write-Host "│ $ResourceType Cleanup Summary" -ForegroundColor Cyan 
    Write-Host "├────────────────────────────────────────────────────┤" -ForegroundColor Cyan
    Write-Host "│ ✅ Kept:    $script:keptCounter" -ForegroundColor White
    Write-Host "│ 🗑️ Removed: $script:removeCounter" -ForegroundColor White
    Write-Host "│ ⏭️ Skipped: $script:skipCounter" -ForegroundColor White
    if ($protectedCounter -gt 0) {
        Write-Host "│ 🛡️ Protected: $protectedCounter" -ForegroundColor White
    }
    Write-Host "└────────────────────────────────────────────────────┘" -ForegroundColor Cyan
    #endregion

    # Update reference parameters at the end
    if ($KeptCounter) { $KeptCounter.Value = $script:keptCounter }
    if ($RemoveCounter) { $RemoveCounter.Value = $script:removeCounter }
    if ($SkipCounter) { $SkipCounter.Value = $script:skipCounter }

    # Return details object
    return @{
        ResourceType = $ResourceType
        KeptCount = $script:keptCounter
        RemovedCount = $script:removeCounter
        SkippedCount = $script:skipCounter
        ProtectedCount = $protectedCounter
    }
}