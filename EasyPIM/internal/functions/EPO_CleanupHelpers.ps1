# Define shared helper functions for cleanup operations
# Used by Invoke-Cleanup
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification="Module includes an alias with plural form for backward compatibility")]
param()

# Define protected roles that should never be removed automatically at script level
$script:protectedRoles = @(
    "User Access Administrator",
    "Global Administrator",
    "Privileged Role Administrator",
    "Security Administrator"
)

# Define script-level counters at the top of the file (outside any function)
$script:keptCounter = 0
$script:removeCounter = 0
$script:skipCounter = 0
$script:protectedCounter = 0

function Test-IsProtectedAssignment {
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$PrincipalId,

        [Parameter(Mandatory = $true)]
        [array]$ProtectedUsers
    )

    return $ProtectedUsers -contains $PrincipalId
}

function Test-IsProtectedRole {
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$RoleName
    )

    return $script:protectedRoles -contains $RoleName
}

function Test-AssignmentInConfig {
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$PrincipalId,

        [Parameter(Mandatory = $true)]
        [string]$RoleName,

        [Parameter(Mandatory = $false)]
        [string]$Scope,

        [Parameter(Mandatory = $false)]
        [string]$GroupId,

        [Parameter(Mandatory = $true)]
        [array]$ConfigAssignments,

        [Parameter(Mandatory = $false)]
        [string]$ResourceType = "Azure"
    )

    # Base matching logic for all resource types
    foreach ($config in $ConfigAssignments) {
        # Check role name match - handle various property possibilities
        $roleMatches = $false
        foreach ($propName in @("RoleName", "Rolename", "Role", "roleName", "rolename", "role")) {
            if ($config.PSObject.Properties.Name -contains $propName) {
                $roleMatches = $config.$propName -ieq $RoleName
                if ($roleMatches) { break }
            }
        }

        # Check principal ID match - direct match
        $principalMatches = $false
        foreach ($propName in @("PrincipalId", "principalId", "PrincipalID", "principalID")) {
            if ($config.PSObject.Properties.Name -contains $propName) {
                $principalMatches = $config.$propName -eq $PrincipalId
                if ($principalMatches) { break }
            }
        }

        # If not matched directly, check in PrincipalIds array if present
        if (-not $principalMatches -and $config.PSObject.Properties.Name -contains "PrincipalIds") {
            $principalMatches = $config.PrincipalIds -contains $PrincipalId
        }

        # Different matching logic based on resource type
        $typeMatches = $false

        switch ($ResourceType) {
            "Azure" {
                if (-not $Scope) {
                    $typeMatches = $true # No scope to check
                } else {
                    # Check scope match
                    $scopeMatches = $false
                    foreach ($propName in @("Scope", "scope")) {
                        if ($config.PSObject.Properties.Name -contains $propName) {
                            $scopeMatches = $config.$propName -eq $Scope
                            if ($scopeMatches) { break }
                        }
                    }
                    $typeMatches = $scopeMatches
                }
            }
            "Entra" {
                # For Entra roles, check for directoryScopeId if available
                if (-not $Scope) {
                    # If no scope provided, it's tenant-wide
                    $typeMatches = $true
                } else {
                    # If scope is provided and matches an Administrative Unit format, check for DirectoryScopeId property
                    # or assume it's tenant-wide if not specified in config
                    $scopeMatches = $false
                    foreach ($propName in @("DirectoryScopeId", "directoryScopeId")) {
                        if ($config.PSObject.Properties.Name -contains $propName) {
                            $scopeMatches = $config.$propName -eq $Scope
                            if ($scopeMatches) { break }
                        }
                    }
                    # If the config has no DirectoryScopeId, assume it's tenant-wide and doesn't match AU-scoped role
                    $typeMatches = $scopeMatches
                }
            }
            "Group" {
                if (-not $GroupId) {
                    $typeMatches = $false # Group ID is required
                } else {
                    # Check group ID match
                    $groupMatches = $false
                    foreach ($propName in @("GroupId", "groupId", "GroupID", "groupID")) {
                        if ($config.PSObject.Properties.Name -contains $propName) {
                            $groupMatches = $config.$propName -eq $GroupId
                            if ($groupMatches) { break }
                        }
                    }
                    $typeMatches = $groupMatches
                }
            }
            default {
                $typeMatches = $true # Default to true if resource type is not specified
            }
        }

        # Return true if all required components match
        if ($principalMatches -and $roleMatches -and $typeMatches) {
            return $true
        }
    }

    return $false
}

function Get-FormattedCleanupSummary {
    [CmdletBinding()]
    [OutputType([System.String])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ResourceType,

        [Parameter(Mandatory = $true)]
        [int]$KeptCount,

        [Parameter(Mandatory = $true)]
        [int]$RemovedCount,

        [Parameter(Mandatory = $true)]
        [int]$SkippedCount,

        [Parameter(Mandatory = $false)]
        [int]$ProtectedCount = 0
    )

    $output = @"
┌────────────────────────────────────────────────────┐
│ $ResourceType Cleanup Summary                      |
├────────────────────────────────────────────────────┤
│ ✅ Kept:      $KeptCount
│ 🗑️ Removed:   $RemovedCount
│ ⏭️ Skipped:   $SkippedCount
"@

    if ($ProtectedCount -gt 0) {
        $output += "`n│ 🛡️ Protected: $ProtectedCount"
    }

    $output += "`n└────────────────────────────────────────────────────┘"

    return $output
}

function Reset-CleanupCounter {
    [CmdletBinding()]
    [OutputType([System.Void])]
    param()

    $script:keptCounter = 0
    $script:removeCounter = 0
    $script:skipCounter = 0
    $script:protectedCounter = 0
}

# Create an alias for backward compatibility
Set-Alias -Name Reset-CleanupCounters -Value Reset-CleanupCounter -Scope Global

function Get-AssignmentProperties {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param (
        [Parameter(Mandatory = $true)]
        [object]$Assignment
    )

    # Extract principal ID
    $principalId = $null
    foreach ($propName in @("PrincipalId", "principalId", "SubjectId", "subjectId")) {
        if ($Assignment.PSObject.Properties.Name -contains $propName -and $Assignment.$propName) {
            $principalId = $Assignment.$propName
            Write-Verbose "Found principalId in property '$propName': $principalId"
            break
        }
    }

    # Extract role name/type - special handling for Group assignments
    $roleName = "Unknown"

    # First try to get accessId which is the authoritative source for Group PIM assignments
    if ($Assignment.PSObject.Properties.Name -contains 'accessId') {
        $roleName = $Assignment.accessId
        Write-Verbose "Found role in accessId: $roleName"
    }
    # Then try other Group-specific properties
    elseif ($Assignment.PSObject.Properties.Name -contains 'memberType') {
        $roleName = $Assignment.memberType
        Write-Verbose "Found role in memberType: $roleName"
    }
    else {
        foreach ($propName in @("memberType", "type", "Type", "MemberType")) {
            if ($Assignment.PSObject.Properties.Name -contains $propName -and $Assignment.$propName) {
                $roleName = $Assignment.$propName
                Write-Verbose "Found role in property '$propName': $roleName"
                break
            }
        }

        # If still no role found, try standard role properties
        if ($roleName -eq "Unknown") {
            foreach ($propName in @("RoleDefinitionDisplayName", "RoleName", "roleName", "displayName")) {
                if ($Assignment.PSObject.Properties.Name -contains $propName -and $Assignment.$propName) {
                    $roleName = $Assignment.$propName
                    Write-Verbose "Found role in property '$propName': $roleName"
                    break
                }
            }
        }
    }

    # Extract principal name
    $principalName = "Principal-$principalId"
    foreach ($propName in @("PrincipalDisplayName", "SubjectName", "displayName")) {
        if ($Assignment.PSObject.Properties.Name -contains $propName -and $Assignment.$propName) {
            $principalName = $Assignment.$propName
            Write-Verbose "Found principal name in property '$propName': $principalName"
            break
        }
    }

    # Try to get principal name from expanded principal object
    if ($Assignment.PSObject.Properties.Name -contains "principal" -and `
        $Assignment.principal.PSObject.Properties.Name -contains "displayName") {
        $principalName = $Assignment.principal.displayName
        Write-Verbose "Found principal name in expanded principal object: $principalName"
    }

    # Extract scope
    $scope = $null
    foreach ($propName in @("ResourceId", "scope", "Scope", "directoryScopeId", "ScopeId")) {
        if ($Assignment.PSObject.Properties.Name -contains $propName -and $Assignment.$propName) {
            $scope = $Assignment.$propName
            Write-Verbose "Found scope in property '$propName': $scope"
            break
        }
    }

    # Return properties as hashtable
    $result = @{
        PrincipalId = $principalId
        RoleName = $roleName.ToLower() # Normalize to lowercase for consistent comparison
        PrincipalName = $principalName
        Scope = $scope
    }

    Write-Verbose "Extracted properties: $($result | ConvertTo-Json -Compress)"
    return $result
}

function Test-IsJustificationFromOrchestrator {
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param (
        [Parameter(Mandatory = $true)]
        [object]$Assignment,

        [Parameter(Mandatory = $false)]
        [string]$JustificationFilter = "Invoke-EasyPIMOrchestrator"
    )

    # Check various properties where justification might be stored
    foreach ($propName in @("Justification", "justification", "Reason", "reason")) {
        if ($Assignment.PSObject.Properties.Name -contains $propName -and `
            $Assignment.$propName -and `
            $Assignment.$propName -like "*$JustificationFilter*") {

            # Log successful detection of orchestrator-created assignment
            Write-Verbose "Found orchestrator justification in property '$propName': $($Assignment.$propName)"
            return $true
        }
    }

    # Try to check additional properties that might contain justification in different API responses
    foreach ($propName in @("creationConditions", "scheduleInfo", "metadata")) {
        if ($Assignment.PSObject.Properties.Name -contains $propName -and $Assignment.$propName) {
            # Handle object properties that might contain justification
            if ($Assignment.$propName -is [System.Collections.IDictionary] -or `
                $Assignment.$propName.PSObject.Properties.Name -contains "justification") {

                $justification = if ($Assignment.$propName -is [System.Collections.IDictionary]) {
                    $Assignment.$propName["justification"]
                } else {
                    $Assignment.$propName.justification
                }

                if ($justification -and $justification -like "*$JustificationFilter*") {
                    Write-Verbose "Found orchestrator justification in nested property '$propName': $justification"
                    return $true
                }
            }
        }
    }

    return $false
}

function Test-AssignmentCreatedByOrchestrator {
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param (
        [Parameter(Mandatory = $true)]
        [object]$Assignment,

        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $true)]
        [string]$ResourceType,

        [Parameter(Mandatory = $false)]
        [string]$SubscriptionId = "",

        [Parameter(Mandatory = $false)]
        [string]$JustificationFilter = "Invoke-EasyPIMOrchestrator"
    )

    try {
        # Set the tenant ID for the helper functions to use
        $script:tenantID = $TenantId

        # Only set subscriptionID for Azure roles that require it
        if ($ResourceType -like "Azure Role*" -and -not [string]::IsNullOrEmpty($SubscriptionId)) {
            $script:subscriptionID = $SubscriptionId
        }

        # Extract necessary properties from the assignment
        $principalId = if ($Assignment.PSObject.Properties.Name -contains 'principalId') {
            $Assignment.principalId
        } elseif ($Assignment.PSObject.Properties.Name -contains 'PrincipalId') {
            $Assignment.PrincipalId
        } else { $null }

        if (-not $principalId) {
            Write-Verbose "No principalId found in assignment, cannot query schedule requests"
            return $false
        }

        # Check if the assignment itself contains justification information first
        if (Test-IsJustificationFromOrchestrator -Assignment $Assignment -JustificationFilter $JustificationFilter) {
            Write-Verbose "Found orchestrator justification directly in the assignment"
            return $true
        }

        # Handle Azure RBAC vs Entra ID vs Group roles differently
        if ($ResourceType -like "Azure Role*") {
            # For Azure roles, use Invoke-ARM with the proper API endpoint
            if ([string]::IsNullOrEmpty($SubscriptionId)) {
                Write-Verbose "No SubscriptionId provided for Azure role, cannot query ARM API"
                return $false
            }

            $scope = if ($Assignment.PSObject.Properties.Name -contains 'ScopeId') {
                $Assignment.ScopeId
            } elseif ($Assignment.PSObject.Properties.Name -contains 'scope') {
                $Assignment.scope
            } elseif ($Assignment.PSObject.Properties.Name -contains 'Scope') {
                $Assignment.Scope
            } else { $null }

            if (-not $scope) {
                Write-Verbose "No scope found in assignment, cannot query ARM API"
                return $false
            }

            # Extract role definition ID if available
            $roleDefinitionId = $null
            foreach ($propName in @("RoleDefinitionId", "roleDefinitionId")) {
                if ($Assignment.PSObject.Properties.Name -contains $propName -and $Assignment.$propName) {
                    $roleDefinitionId = $Assignment.$propName
                    break
                }
            }

            # Determine if we're checking eligible or active assignments
            $isEligible = $ResourceType -like "*eligible*"

            # For eligible assignments: Use roleEligibilityScheduleRequests
            # For active assignments: Use roleAssignmentScheduleRequests
            $requestType = if ($isEligible) {
                "roleEligibilityScheduleRequests"
            } else {
                "roleAssignmentScheduleRequests"
            }

            # Ensure the scope is properly formatted for the API URL
            # The API expects a scope like /subscriptions/{subscriptionId}
            if (-not $scope.StartsWith('/')) {
                $scope = "/$scope"
            }

            # Build the API URL as per documentation:
            # https://learn.microsoft.com/en-us/rest/api/authorization/role-assignment-schedule-requests/list-for-scope
            $apiUrl = "$scope/providers/Microsoft.Authorization/$requestType"
            $apiVersion = "2020-10-01"

            # Build the filter query parameter
            $filter = "principalId eq '$principalId'"

            # If we have a role definition ID, add it to the filter
            if ($roleDefinitionId) {
                $filter += " and roleDefinitionId eq '$roleDefinitionId'"
            }

            $apiUrl += "?api-version=$apiVersion&`$filter=$filter"

            Write-Verbose "Querying ARM API for schedule requests: $apiUrl"

            # Make the API call using the module's Invoke-ARM function
            $response = Invoke-ARM -restURI $apiUrl -method "GET"

            # Check if we received a valid response with results
            if ($response -and `
                $response.PSObject.Properties.Name -contains 'value' -and `
                $response.value -and `
                $response.value.Count -gt 0) {

                Write-Verbose "Found $($response.value.Count) schedule requests for principal $principalId"

                # Examine each request in the response
                foreach ($request in $response.value) {
                    # Look for the justification in the properties
                    if ($request.PSObject.Properties.Name -contains 'properties' -and `
                        $request.properties.PSObject.Properties.Name -contains 'justification') {

                        $justification = $request.properties.justification
                        Write-Verbose "Found justification in schedule request: $justification"

                        # Check if the justification matches our specific filter only
                        if ($justification -like "*$JustificationFilter*") {
                            Write-Verbose "Assignment was created by orchestrator based on justification: $justification"
                            return $true
                        }
                    }
                }

                Write-Verbose "No matching justification pattern found in any schedule requests"
            }
            else {
                Write-Verbose "No matching schedule requests found for principal $principalId at scope $scope"
            }
        }
        elseif ($ResourceType -like "Entra Role*" -or $ResourceType -like "Group*") {
            # For Entra ID roles or Group roles, use Invoke-Graph

            # Determine if it's an eligible or active role
            $requestType = if ($ResourceType -like "*eligible*") {
                "roleEligibilityScheduleRequests"
            } else {
                "roleAssignmentScheduleRequests"
            }

            # Determine if it's for directory (Entra) or groups
            $directoryType = "directory"  # Default for Entra roles
            $additionalFilter = ""

            # If it's a group role, extract the group ID and add to filter
            if ($ResourceType -like "Group*") {
                $groupId = $null

                # Extract group ID from assignment
                if ($Assignment.PSObject.Properties.Name -contains 'id' -and `
                    $Assignment.id -like "*_*") {
                    $groupId = $Assignment.id.Split('_')[0]
                } elseif ($Assignment.PSObject.Properties.Name -contains 'GroupId') {
                    $groupId = $Assignment.GroupId
                } elseif ($Assignment.PSObject.Properties.Name -contains 'groupId') {
                    $groupId = $Assignment.groupId
                }

                if (-not $groupId) {
                    Write-Verbose "No group ID found in group assignment, cannot query Graph API"
                    return $false
                }

                $additionalFilter = " and resourceId eq '$groupId'"
            }

            # Build the Graph API endpoint
            $graphEndpoint = "roleManagement/$directoryType/$requestType"
            $filter = "principalId eq '$principalId'$additionalFilter"
            $graphEndpoint += "?`$filter=$filter"

            Write-Verbose "Querying Microsoft Graph API using Invoke-Graph: $graphEndpoint"

            # Use the module's Invoke-Graph function with beta version
            $response = Invoke-Graph -Endpoint $graphEndpoint -Method "GET" -version "beta"

            # Check for orchestrator justification in the response
            if ($response -and $response.PSObject.Properties.Name -contains 'value' -and $response.value) {
                foreach ($request in $response.value) {
                    # Graph API returns justification directly at root level for Entra roles
                    if ($request.PSObject.Properties.Name -contains 'justification' -and `
                        ($request.justification -like "*$JustificationFilter*")) {

                        Write-Verbose "Found orchestrator justification in Graph API response: $($request.justification)"
                        return $true
                    }
                }
            }
        }

    }
    catch {
        Write-Verbose "Error in Test-AssignmentCreatedByOrchestrator: $_"
        Write-Verbose $_.Exception.Message
        Write-Verbose $_.ScriptStackTrace
    }

    # Default to false if no evidence found that the assignment was created by orchestrator
    return $false
}