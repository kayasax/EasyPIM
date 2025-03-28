function Invoke-ResourceAssignments {
    param (
        [string]$ResourceType,
        [array]$Assignments,
        [hashtable]$CommandMap
    )
    
    # Improved formatting for section headers
    Write-Output "`n┌────────────────────────────────────────────────────┐"
    Write-Output "│ Processing $ResourceType Assignments"
    Write-Output "└────────────────────────────────────────────────────┘`n"
    
    Write-Output "  🔍 Analyzing configuration"
    Write-Output "    ├─ Found $($Assignments.Count) assignments in config"
    
    $createCounter = 0
    $skipCounter = 0
    $errorCounter = 0
    
    # Get existing assignments
    try {
        $cmd = $CommandMap.GetCmd
        $params = $CommandMap.GetParams
        $existingAssignments = & $cmd @params
        Write-Output "    └─ Found $($existingAssignments.Count) existing assignments"
    }
    catch {
        Write-Output "    └─ ⚠️ Error fetching existing assignments: $_"
        $existingAssignments = @()
    }
    
    if ($Assignments.Count -gt 0) {
        Write-Output "`n  📋 Processing assignments:"
    }
    
    foreach ($assignment in $Assignments) {
        # Extract identifiable information for display
        $principalId = $assignment.PrincipalId
        $roleName = $assignment.Rolename
        $principalName = "Principal-$principalId"
        
        # Try to get a better name for the principal if possible
        try {
            $principalObj = Get-AzADUser -ObjectId $principalId -ErrorAction SilentlyContinue
            if ($principalObj) {
                $principalName = $principalObj.DisplayName
            } else {
                $principalGroup = Get-AzADGroup -ObjectId $principalId -ErrorAction SilentlyContinue
                if ($principalGroup) {
                    $principalName = $principalGroup.DisplayName
                }
            }
        } catch {
            # Silently continue with the default name
        }
        
        # Check if principal exists (if not already done in the command map)
        if (-not $CommandMap.DirectFilter) {
            if (-not (Test-PrincipalExists -PrincipalId $assignment.PrincipalId)) {
                Write-Output "    ├─ ❌ $principalName does not exist, skipping assignment"
                $errorCounter++ 
                continue
            }
        }
        
        # Scope information for display
        $scopeInfo = if ($ResourceType -like "Azure Role*" -and $assignment.Scope) {
            " on scope $($assignment.Scope)"
        } elseif ($ResourceType -like "Group*" -and $assignment.GroupId) {
            " in group $($assignment.GroupId)"
        } else {
            ""
        }
        
        # Display assignment being processed
        Write-Output "    ├─ 🔍 $principalName with role '$roleName'$scopeInfo"
        
        # Check if assignment already exists
        $found = 0
        foreach ($existing in $existingAssignments) {
            if (($existing.PrincipalId -eq $assignment.PrincipalId) -and 
                ($existing.RoleName -eq $assignment.Rolename)) {
                $found = 1
                break
            }
        }
        
        if ($found -eq 0) {
            # Prepare parameters for the create command
            $params = $CommandMap.CreateParams.Clone()
            $params['principalId'] = $assignment.PrincipalId
            $params['roleName'] = $assignment.Rolename
            
            # Add scope parameter for Azure role assignments
            if ($ResourceType -like "Azure Role*") {
                $params['scope'] = $assignment.Scope
            }
            
            # Add group ID parameter for Group role assignments
            if ($ResourceType -like "Group Role*") {
                $params['groupId'] = $assignment.GroupId
            }
            
            # Handle Permanent flag and Duration for all assignment types
            if ($assignment.Permanent -eq $true) {
                $params['permanent'] = $true
                Write-Output "    │  ├─ ⏱️ Setting as permanent assignment"
            }
            elseif ($assignment.Duration) {
                $params['duration'] = $assignment.Duration
                Write-Output "    │  ├─ ⏱️ Setting duration: $($assignment.Duration)"
            } else {
                Write-Output "    │  ├─ ⏱️ Using maximum allowed duration"
            }
            
            $params['justification'] = $justification
            Write-Output "    │  ├─ 📝 Justification: $justification"
            
            $actionDescription = if ($ResourceType -like "Azure Role*") {
                "Create $ResourceType assignment for $principalName with role '$roleName' on scope $($assignment.Scope)"
            } else {
                "Create $ResourceType assignment for $principalName with role '$roleName'"
            }
            
            if ($PSCmdlet.ShouldProcess($actionDescription)) {
                try {
                    # Use the command
                    & $CommandMap.CreateCmd @params
                    $createCounter++ 
                    Write-Output "    │  └─ ✅ Created successfully"
                }
                catch {
                    Write-Output "    │  └─ ❌ Failed to create: $_"
                    $errorCounter++ 
                }
            }
        }
        else {
            Write-Output "    │  └─ ⏭️ Assignment already exists, skipping"
            $skipCounter++
        }
    }
    
    # Final summary with visual formatting
    Write-Output "`n┌────────────────────────────────────────────────────┐"
    Write-Output "│ $ResourceType Assignments Summary"
    Write-Output "├────────────────────────────────────────────────────┤"
    Write-Output "│ ✅ Created: $createCounter"
    Write-Output "│ ⏭️ Skipped: $skipCounter" 
    Write-Output "│ ❌ Failed:  $errorCounter"
    Write-Output "└────────────────────────────────────────────────────┘`n"
        
}