# Define script-level counters at the top of the file (outside any function)
$script:keptCounter = 0
$script:removeCounter = 0
$script:skipCounter = 0
$script:protectedCounter = 0

# Define protected roles at script level
$script:protectedRoles = @(
    "User Access Administrator",
    "Global Administrator",
    "Privileged Role Administrator",
    "Security Administrator"
)

function Invoke-Cleanup {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([System.Collections.Hashtable])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    param (
        [string]$ResourceType,
        [array]$ConfigAssignments,
        [hashtable]$ApiInfo,
        [array]$ProtectedUsers,
        [Parameter(Mandatory = $false)]
        [ValidateSet('Initial', 'Delta')]
        [string]$Mode = 'Delta',
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
    $script:protectedCounter = 0

    #region Prevent duplicate calls
    if (-not $script:ProcessedCleanups) { $script:ProcessedCleanups = @{} }

    $uniqueKey = "$ResourceType-$Mode"
    if ($ApiInfo.GroupId) { $uniqueKey += "-$($ApiInfo.GroupId)" }

    if ($script:ProcessedCleanups.ContainsKey($uniqueKey)) {
        Write-Host "`n⚠️ Cleanup for '$ResourceType' ($Mode mode) already processed - skipping duplicate call`n" -ForegroundColor Yellow
        return @{
            ResourceType = $ResourceType;
            KeptCount = 0;
            RemovedCount = 0;
            SkippedCount = 0;
            ProtectedCount = 0
        }
    }

    $script:ProcessedCleanups[$uniqueKey] = (Get-Date)

    Write-Host "`n┌────────────────────────────────────────────────────┐" -ForegroundColor Cyan
    Write-Host "│ Processing $ResourceType $Mode Cleanup" -ForegroundColor Cyan
    Write-Host "└────────────────────────────────────────────────────┘`n" -ForegroundColor Cyan

    # Display initial warning for Initial mode
    if ($Mode -eq 'Initial') {
        Write-Host "`n┌────────────────────────────────────────────────────┐" -ForegroundColor Yellow
        Write-Host "│ ⚠️ CAUTION: POTENTIALLY DESTRUCTIVE OPERATION" -ForegroundColor Yellow
        Write-Host "└────────────────────────────────────────────────────┘`n" -ForegroundColor Yellow
        Write-Host "This will remove ALL PIM assignments not defined in your configuration." -ForegroundColor Yellow
        Write-Host "If your protected users list is incomplete, you may lose access to critical resources!" -ForegroundColor Yellow
        Write-Host "Protected users count: $($ProtectedUsers.Count)" -ForegroundColor Yellow
        Write-Host "`n---" -ForegroundColor Yellow
        Write-Host "USAGE GUIDANCE:" -ForegroundColor Yellow
        Write-Host "• To preview changes without making them: Use -WhatIf" -ForegroundColor Yellow
        Write-Host "• To skip confirmation prompts: Use -Confirm:`$false" -ForegroundColor Yellow
        Write-Host "---`n" -ForegroundColor Yellow

        # Global confirmation for Initial mode
        $operationDescription = "Initial cleanup mode - remove ALL assignments not in configuration"
        $operationTarget = "PIM assignments across Azure, Entra ID, and Groups"

        if (-not $PSCmdlet.ShouldProcess($operationTarget, $operationDescription)) {
            Write-Output "Operation cancelled by user."
            return
        }
    }

    # Define resource type specific settings
    $config = switch ($ResourceType) {
        "Azure Role eligible" {
            @{
                ApiEndpoint = "/providers/Microsoft.Authorization/roleEligibilityScheduleRequests";
                ApiVersion = "2020-10-01";
                RemoveCmd = "Remove-PIMAzureResourceEligibleAssignment";
                Filter = "status eq 'Provisioned'"
            }
        }
        "Azure Role active" {
            @{
                ApiEndpoint = "/providers/Microsoft.Authorization/roleAssignmentScheduleRequests";
                ApiVersion = "2020-10-01";
                RemoveCmd = "Remove-PIMAzureResourceActiveAssignment";
                Filter = "status eq 'Provisioned'"
            }
        }
        "Entra Role eligible" {
            @{
                ApiEndpoint = "https://graph.microsoft.com/beta/roleManagement/directory/roleEligibilityScheduleInstances"
                ApiVersion = "beta"
                RemoveCmd = "Remove-PIMEntraRoleEligibleAssignment"
                GraphBased = $true
            }
        }
        "Entra Role active" {
            @{
                ApiEndpoint = "https://graph.microsoft.com/beta/roleManagement/directory/roleAssignmentScheduleInstances"
                ApiVersion = "beta"
                RemoveCmd = "Remove-PIMEntraRoleActiveAssignment"
                GraphBased = $true
            }
        }
        "Group eligible" {
            @{
                ApiEndpoint = "https://graph.microsoft.com/beta/roleManagement/directory/roleEligibilityScheduleInstances"
                ApiVersion = "beta"
                RemoveCmd = "Remove-PIMGroupEligibleAssignment"
                GraphBased = $true
                GroupBased = $true
            }
        }
        "Group active" {
            @{
                ApiEndpoint = "https://graph.microsoft.com/beta/roleManagement/directory/roleAssignmentScheduleInstances"
                ApiVersion = "beta"
                RemoveCmd = "Remove-PIMGroupActiveAssignment"
                GraphBased = $true
                GroupBased = $true
            }
        }
        default {
            throw "Unknown resource type: $ResourceType"
        }
    }

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
        $cfgScope = if ($null -ne $cfg.Scope) { $cfg.Scope } else { "NO_SCOPE" }
        Write-Verbose "Config Assignment: Principal=$cfgId, Role=$cfgRole, Scope=$cfgScope"
    }
    Write-Verbose "========== END CONFIG DUMP ==========="


    try {
        # Get current assignments directly using scopes from config
        Write-Host "`n=== Processing Scopes ===" -ForegroundColor Cyan
        $allAssignments = @()

        if ($config.GraphBased) {
            if ($config.GroupBased) {
                # For group assignments, need to get assignments for each group
                Write-Host "  🔍 Checking group assignments" -ForegroundColor White
                try {
                    $getCmd = if ($ResourceType -eq "Group eligible") {
                        "Get-PIMGroupEligibleAssignment"
                    } else {
                        "Get-PIMGroupActiveAssignment"
                    }

                    foreach ($groupId in $ApiInfo.GroupIds) {
                        Write-Host "    ├─ Processing group: $groupId" -ForegroundColor White
                        $groupAssignments = & $getCmd -TenantId $ApiInfo.TenantId -groupId $groupId
                        if ($null -ne $groupAssignments) {
                            $allAssignments += $groupAssignments
                            Write-Host "    │  └─ Found $($groupAssignments.Count) assignments" -ForegroundColor Gray
                        }
                    }
                }
                catch {
                    Write-Error "Failed to get group assignments: $_"
                }
            }
            else {
                # For Entra roles, get assignments using our module's commands
                Write-Host "  🔍 Checking tenant-wide Entra Role assignments" -ForegroundColor White
                try {
                    $getCmd = if ($ResourceType -eq "Entra Role eligible") {
                        "Get-PIMEntraRoleEligibleAssignment"
                    } else {
                        "Get-PIMEntraRoleActiveAssignment"
                    }

                    $allAssignments = & $getCmd -TenantId $ApiInfo.TenantId
                    Write-Host "    ├─ Found $($allAssignments.Count) assignments" -ForegroundColor Gray
                }
                catch {
                    Write-Error "Failed to get Entra role assignments: $_"
                }
            }
        }
        else {
            # For Azure roles, use existing scope-based logic
            $getCmd = if ($ResourceType -eq "Azure Role eligible") {
                "Get-PIMAzureResourceEligibleAssignment"
            } else {
                "Get-PIMAzureResourceActiveAssignment"
            }

            # Track processed scopes to avoid duplicates
            $processedScopes = @{}

            foreach ($configAssignment in $ConfigAssignments) {
                if ($configAssignment.Scope) {
                    # Skip if we've already processed this scope
                    if ($processedScopes.ContainsKey($configAssignment.Scope)) {
                        Write-Verbose "Skipping already processed scope: $($configAssignment.Scope)"
                        continue
                    }

                    Write-Host "  🔍 Checking scope: $($configAssignment.Scope)" -ForegroundColor White
                    $params = @{
                        TenantId = $ApiInfo.TenantId
                        Scope = $configAssignment.Scope
                    }

                    $scopeAssignments = & $getCmd @params
                    if ($null -ne $scopeAssignments) {
                        $allAssignments += $scopeAssignments
                    }

                    Write-Host "    ├─ Found $($scopeAssignments.Count) assignments" -ForegroundColor Gray
                    $processedScopes[$configAssignment.Scope] = $true
                }
            }
        }

        Write-Host "`n=== Processing Assignments ===" -ForegroundColor Cyan
        Write-Host "  📊 Total assignments found: $($allAssignments.Count)" -ForegroundColor White

        # Create a tracking set for processed assignments to avoid duplicates
        $processedAssignments = @{}

        # Process assignments
        if ($allAssignments.Count -gt 0) {
            foreach ($assignment in $allAssignments) {
                # Extract assignment details with proper fallbacks for each property
                $principalId = if ($config.GraphBased) {
                    $assignment.principalid  # Our module's commands provide this consistently
                }
                elseif ($null -ne $assignment.PrincipalId) {
                    $assignment.PrincipalId
                }
                elseif ($null -ne $assignment.principalId) {
                    $assignment.principalId
                }
                else {
                    $null
                }

                # Handle role name/member type based on resource type
                $roleName = if ($config.GroupBased) {
                    $assignment.memberType  # For groups, use memberType (member/owner)
                }
                elseif ($config.GraphBased) {
                    $assignment.rolename  # For Entra roles, use rolename consistently
                }
                elseif ($null -ne $assignment.RoleName -and $assignment.RoleName -ne '') {
                    $assignment.RoleName
                }
                elseif ($null -ne $assignment.roleName -and $assignment.roleName -ne '') {
                    $assignment.roleName
                }
                elseif ($null -ne $assignment.RoleDefinitionDisplayName -and $assignment.RoleDefinitionDisplayName -ne '') {
                    $assignment.RoleDefinitionDisplayName
                }
                else {
                    $roleId = $assignment.RoleId
                    if ($roleId) {
                        try {
                            $roleDefinition = Get-AzRoleDefinition -Id ($roleId -split '/')[-1]
                            if ($roleDefinition) {
                                $roleDefinition.Name
                            }
                            else { $null }
                        }
                        catch {
                            Write-Verbose "Failed to get role name from role definition: $_"
                            $null
                        }
                    }
                    else { $null }
                }

                # Get scope - handle Azure roles properly
                $scope = if ($config.GraphBased) {
                    $null  # Entra roles don't use scope
                }
                else {  # For Azure roles, always use ScopeId
                    $assignment.ScopeId
                }

                # Get principal name - simplified since our module provides consistent output
                $principalName = if ($config.GraphBased) {
                    $assignment.principalname  # Our module's commands provide this consistently
                }
                elseif ($null -ne $assignment.PrincipalName) {
                    $assignment.PrincipalName
                }
                elseif ($null -ne $assignment.principalName) {
                    $assignment.principalName
                }
                else {
                    "Principal-$principalId"
                }

                Write-Host "`n  Processing: $principalName" -ForegroundColor White
                Write-Host "    ├─ Role: $roleName" -ForegroundColor Gray
                if ($scope) {
                    Write-Host "    ├─ Scope: $scope" -ForegroundColor Gray
                }

                # Skip invalid assignments
                if (-not $principalId -or -not $roleName) {
                    Write-Host "    └─ ⚠️ Invalid assignment data (missing principalId or roleName) - skipping" -ForegroundColor Yellow
                    $script:skipCounter++
                    continue
                }
                # For non-Graph based assignments (Azure roles), require scope
                if (-not $config.GraphBased -and -not $scope) {
                    Write-Host "    └─ ⚠️ Invalid assignment data (missing scope for Azure role) - skipping" -ForegroundColor Yellow
                    $script:skipCounter++
                    continue
                }

                # Create a unique key to track this assignment - for Graph-based assignments, don't include scope
                $assignmentKey = if ($config.GraphBased) {
                    "$principalId|$roleName"
                } else {
                    "$principalId|$roleName|$scope"
                }

                # Skip if we've already processed this assignment
                if ($processedAssignments.ContainsKey($assignmentKey)) {
                    Write-Host "    └─ ⏭️ Duplicate entry - skipping" -ForegroundColor DarkYellow
                    $script:skipCounter++
                    continue
                }

                # Mark as processed
                $processedAssignments[$assignmentKey] = $true

                # Check if assignment matches config
                $foundInConfig = $false
                foreach ($configAssignment in $ConfigAssignments) {
                    $matchesPrincipal = $configAssignment.PrincipalId -eq $principalId
                    $matchesRole = $configAssignment.RoleName -ieq $roleName

                    # For Graph-based assignments (Entra Roles), ignore scope comparison
                    $matchesScope = if ($config.GraphBased) {
                        $true
                    } else {
                        $configAssignment.Scope -eq $scope
                    }

                    if ($matchesPrincipal -and $matchesRole -and $matchesScope) {
                        $foundInConfig = $true
                        break
                    }
                }

                # Keep assignment if it's in config
                if ($foundInConfig) {
                    Write-Host "    └─ ✅ Matches config - keeping" -ForegroundColor Green
                    $script:keptCounter++
                    continue
                }

                # Check if protected user
                if ($ProtectedUsers -contains $principalId) {
                    Write-Host "    └─ 🛡️ Protected user - skipping" -ForegroundColor Yellow
                    $script:protectedCounter++
                    continue
                }

                # Check if protected role
                if ($script:protectedRoles -contains $roleName) {
                    Write-Host "    └─ ⚠️ Protected role - skipping" -ForegroundColor Yellow
                    $script:protectedCounter++
                    continue
                }

                # Check if assignment is inherited
                $isInherited = $false
                $inheritedReason = ""

                if ($assignment.PSObject.Properties.Name -contains "memberType" -and $assignment.memberType -eq "Inherited") {
                    $isInherited = $true
                    $inheritedReason = "memberType=Inherited"
                }
                elseif ($assignment.PSObject.Properties.Name -contains "ScopeType" -and $assignment.ScopeType -eq "managementgroup") {
                    $isInherited = $true
                    $inheritedReason = "ScopeType=managementgroup"
                }
                elseif ($assignment.PSObject.Properties.Name -contains "ScopeId" -and $assignment.ScopeId -like "*managementGroups*") {
                    $isInherited = $true
                    $inheritedReason = "ScopeId contains managementGroups"
                }

                if ($isInherited) {
                    Write-Host "    └─ ⏭️ Inherited assignment ($inheritedReason) - skipping" -ForegroundColor DarkYellow
                    $script:skipCounter++
                    continue
                }

                # Remove assignment
                Write-Host "    └─ 🗑️ Not in config - removing..." -ForegroundColor Magenta
                if ($PSCmdlet.ShouldProcess("Remove $ResourceType assignment for $principalName with role '$roleName'")) {
                    try {
                        if ($config.GroupBased) {
                            # For groups, we need to use groupId and memberType
                            & $config.RemoveCmd -TenantId $ApiInfo.TenantId -GroupId $assignment.id.Split('_')[0] -PrincipalId $principalId -type $roleName
                        }
                        else {
                            # For Azure and Entra roles, use RoleName
                            $params = @{
                                TenantId = $ApiInfo.TenantId
                                PrincipalId = $principalId
                                RoleName = $roleName
                            }
                            if ($scope) {
                                $params.Scope = $scope
                            }
                            & $config.RemoveCmd @params
                        }

                        $script:removeCounter++
                        Write-Host "       ✓ Removed successfully" -ForegroundColor Green
                    }
                    catch {
                        Write-Host "       ❌ Failed to remove: $_" -ForegroundColor Red
                    }
                }
                else {
                    $script:skipCounter++
                    Write-Host "       ⏭️ Removal skipped (WhatIf mode)" -ForegroundColor DarkYellow
                }
            }
        }
    }
    catch {
        Write-Error "An error occurred processing $ResourceType cleanup: $_"
    }

    Write-Host "`n┌────────────────────────────────────────────────────┐" -ForegroundColor Cyan
    Write-Host "│ $ResourceType Cleanup Summary" -ForegroundColor Cyan
    Write-Host "├────────────────────────────────────────────────────┤" -ForegroundColor Cyan
    Write-Host "│ ✅ Kept:      $script:keptCounter" -ForegroundColor White
    Write-Host "│ 🗑️ Removed:   $script:removeCounter" -ForegroundColor White
    Write-Host "│ ⏭️ Skipped:   $script:skipCounter" -ForegroundColor White
    Write-Host "│ 🛡️ Protected: $script:protectedCounter" -ForegroundColor White
    Write-Host "└────────────────────────────────────────────────────┘" -ForegroundColor Cyan

    if ($KeptCounter) { $KeptCounter.Value = $script:keptCounter }
    if ($RemoveCounter) { $RemoveCounter.Value = $script:removeCounter }
    if ($SkipCounter) { $SkipCounter.Value = $script:skipCounter }

    return @{
        ResourceType = $ResourceType;
        KeptCount = $script:keptCounter;
        RemovedCount = $script:removeCounter;
        SkippedCount = $script:skipCounter;
        ProtectedCount = $script:protectedCounter
    }
}
