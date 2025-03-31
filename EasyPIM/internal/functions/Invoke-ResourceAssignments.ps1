function Invoke-ResourceAssignments {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [string]$ResourceType,
        [array]$Assignments,
        [hashtable]$CommandMap
    )
    
    # Improved formatting for section headers
    Write-Host "`n┌────────────────────────────────────────────────────┐"
    Write-Host "│ Processing $ResourceType Assignments"
    Write-Host "└────────────────────────────────────────────────────┘`n"
    
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
    
    # Add debug output for assignments
    if ($Assignments.Count -gt 0) {
        Write-Output "`n  📋 Processing assignments:"
        Write-Output "    ├─ Found $($Assignments.Count) assignments to process"
        
        # Display details for ALL assignments
        foreach ($assignment in $Assignments) {
            $principalId = $assignment.PrincipalId
            $roleName = if ([string]::IsNullOrEmpty($assignment.Rolename)) { 
                $assignment.Role 
            }
            else { 
                $assignment.Rolename 
            }
            
            # Fix scope display - different formats for different resource types
            $scopeDisplay = ""
            if ($ResourceType -like "Azure Role*" -and $assignment.Scope) {
                $scopeDisplay = " on scope $($assignment.Scope)"
            }
            elseif ($ResourceType -like "Group*" -and $assignment.GroupId) {
                $scopeDisplay = " in group $($assignment.GroupId)"
            }
            # For Entra ID roles, no scope is needed
            
            try {
                $principalName = (Get-MgUser -UserId $principalId -ErrorAction SilentlyContinue).DisplayName
                if (-not $principalName) {
                    $principalName = "Principal-$principalId"
                }
            }
            catch {
                $principalName = "Principal-$principalId"
            }
            
            Write-Output "    ├─ Processing: $principalName with role '$roleName'$scopeDisplay"
        }
        
        Write-Verbose "Debug: Total assignments to process: $($Assignments.Count)"
        
        # Display first few assignments in verbose mode
        foreach ($a in $Assignments | Select-Object -First 3) {
            Write-Verbose "Debug: Assignment: $($a | ConvertTo-Json -Compress)"
        }
    }
    
    foreach ($assignment in $Assignments) {
        # Extract identifiable information for display
        $principalId = $assignment.PrincipalId
        if (-not $principalId) {
            Write-Warning "Assignment is missing PrincipalId: $($assignment | ConvertTo-Json -Compress)"
            $errorCounter++
            continue
        }

        $roleName = if ([string]::IsNullOrEmpty($assignment.Rolename)) { 
            $assignment.Role 
        }
        else { 
            $assignment.Rolename 
        }
        $principalName = "Principal-$principalId"
        
        # Try to get a better name for the principal if possible
        try {
            $principalObj = Get-AzADUser -ObjectId $principalId -ErrorAction SilentlyContinue
            if ($principalObj) {
                $principalName = $principalObj.DisplayName
            }
            else {
                $principalGroup = Get-AzADGroup -ObjectId $principalId -ErrorAction SilentlyContinue
                if ($principalGroup) {
                    $principalName = $principalGroup.DisplayName
                }
            }
        }
        catch {
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
        }
        elseif ($ResourceType -like "Group*" -and $assignment.GroupId) {
            " in group $($assignment.GroupId)"
        }
        else {
            ""
        }
        
        # Display assignment being processed
        Write-Host "    ├─ 🔍 $principalName with role '$roleName'$scopeInfo"
        
        # Check if assignment already exists
        $found = 0
        foreach ($existing in $existingAssignments) {
            # Add debug output to see what we're comparing
            Write-Verbose "Comparing with existing: $($existing | ConvertTo-Json -Depth 10 -ErrorAction SilentlyContinue)"
            
            # Different comparison for different resource types
            if ($ResourceType -like "Entra ID Role*") {
                # Debug: Show the first existing assignment structure to help us understand it
                if ($existingAssignments.Count -gt 0 -and $existing -eq $existingAssignments[0]) {
                    Write-Verbose "First Entra ID existing assignment structure:"
                    Write-Verbose ($existing | ConvertTo-Json -Depth 10 -ErrorAction SilentlyContinue)
                }
                
                # The issue is that Graph API properties might have different casing or structure
                # Try multiple property paths for more robust comparison
                
                # Check if we're dealing with an expanded object or a basic one
                if ($existing.PSObject.Properties.Name -contains 'principal') {
                    Write-Verbose "Comparing expanded Entra object: principal.id=$($existing.principal.id) to $($assignment.PrincipalId)"
                    Write-Verbose "Comparing expanded Entra object: roleDefinition.displayName=$($existing.roleDefinition.displayName) to $roleName"
                    
                    # Case-insensitive comparison for role names
                    if (($existing.principal.id -eq $assignment.PrincipalId) -and 
                        ($existing.roleDefinition.displayName -ieq $roleName)) {
                        $found = 1
                        Write-Verbose "Match found using Entra ID expanded object comparison"
                        break
                    }
                }
                else {
                    # Try standard properties with case-insensitive role name comparison
                    Write-Verbose "Comparing standard Entra object: PrincipalId=$($existing.PrincipalId) to $($assignment.PrincipalId)"
                    Write-Verbose "Comparing standard Entra object: RoleName=$($existing.RoleName) to $roleName"
                    
                    if (($existing.PrincipalId -eq $assignment.PrincipalId) -and 
                        ($existing.RoleName -ieq $roleName)) {
                        $found = 1
                        Write-Verbose "Match found using Entra ID standard comparison"
                        break
                    }
                }
            }
            elseif ($ResourceType -like "Group Role*") {
                # Debug the first group assignment structure
                if ($existingAssignments.Count -gt 0 -and $existing -eq $existingAssignments[0]) {
                    Write-Verbose "First Group Role existing assignment structure:"
                    Write-Verbose ($existing | ConvertTo-Json -Depth 10 -ErrorAction SilentlyContinue)
                }
                
                # For Group roles, we need to check PrincipalId/ID and Type/type
                $principalMatched = $false
                $roleMatched = $false

                # Simplified principal ID check - just check for the two common property names
                if ($existing.PrincipalId -eq $assignment.PrincipalId -or 
                    $existing.principalid -eq $assignment.PrincipalId) {
                    $principalMatched = $true
                    Write-Verbose "Principal ID matched in group assignment"
                }

                # Simplified role name/type check - check only the different property names
                if ($existing.RoleName -ieq $roleName -or
                    $existing.Type -ieq $roleName -or
                    $existing.memberType -ieq $roleName) {
                    $roleMatched = $true
                    Write-Verbose "Role/type matched in group assignment (property: $($existing.PSObject.Properties.Name -like '*type*' -or $existing.PSObject.Properties.Name -like '*role*'))"
                }
                
                # Match found if both principal and role matched
                if ($principalMatched -and $roleMatched) {
                    $found = 1
                    # Store information about why this matched for display later
                    $matchReason = if ($existing.memberType) {
                        "memberType='$($existing.memberType)'"
                    } elseif ($existing.Type) {
                        "type='$($existing.Type)'"
                    } else {
                        "role matched"
                    }
                    $matchInfo = "principalId='$($existing.principalId)' and $matchReason"
                    Write-Verbose "Match found for Group Role assignment: $matchInfo"
                    break
                }
            }
            else {
                # Standard comparison for Azure roles and others
                if (($existing.PrincipalId -eq $assignment.PrincipalId) -and 
                    ($existing.RoleName -eq $roleName)) {
                    $found = 1
                    break
                }
            }
        }
        
        if ($found -eq 0) {
            # Prepare parameters for the create command
            $params = $CommandMap.CreateParams.Clone()
            
            # For Group roles, match EXACTLY what works in the direct command
            if ($ResourceType -like "Group Role*") {
                # Use uppercase 'ID' suffix as shown in the working command
                $params['principalID'] = $assignment.PrincipalId  # Note the capital ID
                $params['groupID'] = $assignment.GroupId          # Note the capital ID
                $params['type'] = $roleName.ToLower()             # Lowercase type value
                
                Write-Verbose "Using exact parameter cases for Group command: principalID, groupID, type"
            }
            else {
                # Standard parameters for other resource types
                $params['principalId'] = $assignment.PrincipalId
                $params['roleName'] = $roleName
            }
            
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
                if ($ResourceType -like "Group Role*") {
                    $params['permanent'] = $true  # Lowercase for group roles
                } else {
                    $params['permanent'] = $true  
                }
                Write-Host "    │  ├─ ⏱️ Setting as permanent assignment" -ForegroundColor Cyan
            }
            elseif ($assignment.Duration) {
                if ($ResourceType -like "Group Role*") {
                    $params['duration'] = $assignment.Duration  # Lowercase for group roles
                } else {
                    $params['duration'] = $assignment.Duration
                }
                Write-Host "    │  ├─ ⏱️ Setting duration: $($assignment.Duration)" -ForegroundColor Cyan
            }
            else {
                Write-Host "    │  ├─ ⏱️ Using maximum allowed duration" -ForegroundColor Cyan
            }

            # Ensure justification has the right case for each resource type
            if ($ResourceType -like "Group Role*") {
                $params['justification'] = $justification  # Lowercase for group roles
            } else {
                $params['justification'] = $justification
            }
            
            Write-Host "    │  ├─ 📝 Justification: $justification" -ForegroundColor Cyan
            
            # Just before executing the command:
            if ($ResourceType -like "Group Role*") {
                Write-Verbose "Group Role command parameters:"
                Write-Verbose ($params | ConvertTo-Json -Compress)
                Write-Verbose "Command being executed: $($CommandMap.CreateCmd)"
                
                # Debug command parameters
                try {
                    $cmdInfo = Get-Command $CommandMap.CreateCmd
                    Write-Verbose "Command accepts these parameters: $($cmdInfo.Parameters.Keys -join ', ')"
                } catch {
                    Write-Warning "Could not get command info: $_"
                }
            }
            
            $actionDescription = if ($ResourceType -like "Azure Role*") {
                "Create $ResourceType assignment for $principalName with role '$roleName' on scope $($assignment.Scope)"
            }
            else {
                "Create $ResourceType assignment for $principalName with role '$roleName'"
            }
            
            if ($PSCmdlet.ShouldProcess($actionDescription)) {
                try {
                    # Add more debugging for the exact result
                    Write-Verbose "Executing command: $($CommandMap.CreateCmd)"
                    
                    # Capture the output of the command
                    $result = & $CommandMap.CreateCmd @params
                    
                    # Improved result inspection
                    Write-Verbose "Result type: $($result.GetType().FullName)"
                    if ($null -ne $result) {
                        Write-Verbose "Result structure: $($result | ConvertTo-Json -Compress -Depth 10 -ErrorAction SilentlyContinue)"
                    }
                    
                    # Check if the result contains an error
                    $hasError = $false

                    # Different error checking based on object type
                    if ($result -is [System.Collections.Hashtable]) {
                        # For hashtables, use ContainsKey
                        if ($result.ContainsKey('error')) {
                            $hasError = $true
                            # Replace null-coalescing operator with if-else for PS5 compatibility
                            $errorMessage = if ($null -ne $result.error.message) { 
                                $result.error.message 
                            } elseif ($null -ne $result.error.code) { 
                                $result.error.code 
                            } else { 
                                "Unknown error" 
                            }
                            Write-Host "    │  └─ ❌ API returned error: $errorMessage" -ForegroundColor Red
                            $errorCounter++
                        }
                    }
                    elseif ($result -is [PSCustomObject]) {
                        # For PSCustomObject, check Properties collection
                        if ($result.PSObject.Properties.Name -contains 'error') {
                            $hasError = $true
                            # Replace null-coalescing operator with if-else for PS5 compatibility
                            $errorMessage = if ($null -ne $result.error.message) { 
                                $result.error.message 
                            } elseif ($null -ne $result.error.code) { 
                                $result.error.code 
                            } else { 
                                "Unknown error" 
                            }
                            Write-Host "    │  └─ ❌ API returned error: $errorMessage" -ForegroundColor Red
                            $errorCounter++
                        }
                    }
                    
                    # Only proceed if no error was detected
                    if (-not $hasError) {
                        # Group Role assignments may return nothing or a response
                        if ($ResourceType -like "Group Role*") {
                            # For Group roles, success if no error was detected
                            $createCounter++
                            Write-Host "    │  └─ ✅ Created successfully" -ForegroundColor Green
                        } else {
                            # For other resource types, still check for non-null result
                            if ($null -ne $result) {
                                $createCounter++
                                Write-Host "    │  └─ ✅ Created successfully" -ForegroundColor Green
                            } else {
                                Write-Host "    │  └─ ❌ Command executed but returned null result" -ForegroundColor Red
                                $errorCounter++
                            }
                        }
                    }
                }
                catch {
                    Write-Host "    │  └─ ❌ Failed to create: $_" -ForegroundColor Red
                    $errorCounter++
                }
            }
        }
        else {
            # After the loop ends, update the else statement with more details:
            if ($ResourceType -like "Entra ID Role*") {
                Write-Host "    │  └─ ⏭️ Assignment already exists in Entra ID, skipping" -ForegroundColor DarkYellow
            }
            elseif ($ResourceType -like "Group Role*") {
                Write-Host "    │  └─ ⏭️ Assignment already exists as $matchInfo, skipping" -ForegroundColor DarkYellow
            }
            else {
                Write-Host "    │  └─ ⏭️ Assignment already exists, skipping" -ForegroundColor DarkYellow
            }
            $skipCounter++
        }
    }
    
    # Return the counters in a structured format
    $result = @{
        Created = $createCounter
        Skipped = $skipCounter
        Failed  = $errorCounter
    }

    # Output summary 
    Write-Output "`n┌────────────────────────────────────────────────────┐"
    Write-Output "│ $ResourceType Assignments Summary"
    Write-Output "├────────────────────────────────────────────────────┤"
    Write-Output "│ ✅ Created: $createCounter"
    Write-Output "│ ⏭️ Skipped: $skipCounter" 
    Write-Output "│ ❌ Failed:  $errorCounter"
    Write-Output "└────────────────────────────────────────────────────┘`n"

    # Return the result object
    return $result
}