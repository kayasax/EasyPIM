# Define shared helper functions for cleanup operations
# Used by both Invoke-DeltaCleanup and Invoke-InitialCleanup

# Define protected roles that should never be removed automatically at script level
$script:protectedRoles = @(
    "User Access Administrator",
    "Global Administrator",
    "Privileged Role Administrator",
    "Security Administrator"
)

function Test-IsProtectedAssignment {
    [CmdletBinding()]
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
    param (
        [Parameter(Mandatory = $true)]
        [string]$RoleName
    )
    
    return $script:protectedRoles -contains $RoleName
}

function Test-AssignmentInConfig {
    [CmdletBinding()]
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
                # For Entra roles, we only need to match principal and role
                $typeMatches = $true
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

function Test-IsJustificationFromOrchestrator {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [object]$Assignment,
        
        [Parameter(Mandatory = $false)]
        [string]$JustificationFilter = "Invoke-EasyPIMOrchestrator"
    )
    
    # Check various properties where justification might be stored
    foreach ($propName in @("Justification", "justification", "Reason", "reason")) {
        if ($Assignment.PSObject.Properties.Name -contains $propName -and 
            $Assignment.$propName -and 
            $Assignment.$propName -like "*$JustificationFilter*") {
            return $true
        }
    }
    
    return $false
}

function Get-FormattedCleanupSummary {
    [CmdletBinding()]
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
│ $ResourceType Cleanup Summary                      
├────────────────────────────────────────────────────┤
│ ✅ Kept:    $KeptCount
│ 🗑️ Removed: $RemovedCount
│ ⏭️ Skipped: $SkippedCount
"@

    if ($ProtectedCount -gt 0) {
        $output += "`n│ 🛡️ Protected: $ProtectedCount"
    }
    
    $output += "`n└────────────────────────────────────────────────────┘"
    
    return $output
}

function Get-AssignmentProperties {
    [CmdletBinding()]
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
    if ($Assignment.PSObject.Properties.Name -contains "principal" -and 
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