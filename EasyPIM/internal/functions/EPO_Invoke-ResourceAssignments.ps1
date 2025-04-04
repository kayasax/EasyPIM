function Invoke-ResourceAssignments {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([System.Collections.Hashtable])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
    param (
        [string]$ResourceType,
        [array]$Assignments,
        [hashtable]$CommandMap,
        [PSCustomObject]$Config
    )

    # Improved formatting for section headers
    Write-Host "`n┌────────────────────────────────────────────────────┐"
    Write-Host "│ Processing $ResourceType Assignments"
    Write-Host "└────────────────────────────────────────────────────┘`n"

    write-host "  🔍 Analyzing configuration"
    write-host "    ├─ Found $($Assignments.Count) assignments in config"

    $createCounter = 0
    $skipCounter = 0
    $errorCounter = 0

    # Get existing assignments
    try {
        $cmd = $CommandMap.GetCmd
        $params = $CommandMap.GetParams
        $existingAssignments = & $cmd @params
        write-host "    └─ Found $($existingAssignments.Count) existing assignments"
    }
    catch {
        write-host "    └─ ⚠️ Error fetching existing assignments: $_"
        $existingAssignments = @()
    }

    # Ensure existingAssignments is always an array
    if ($null -eq $existingAssignments) {
        Write-Verbose "Command returned null result, initializing empty array"
        $existingAssignments = @()
    }
    elseif (-not ($existingAssignments -is [array])) {
        Write-Verbose "Command returned a single object, converting to array"
        $existingAssignments = @($existingAssignments)
    }

    # Add debug output for assignments
    if ($Assignments.Count -gt 0) {
        write-host "`n  📋 Processing assignments:"
        write-host "    ├─ Found $($Assignments.Count) assignments to process"

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

            write-host "    ├─ Processing: $principalName with role '$roleName'$scopeDisplay"
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
            write-verbose "    ├─ ⚠️ Failed to resolve principal name for ID ${principalId}: $_"
            # Silently continue with the default name
        }

        # Check if principal exists (if not already done in the command map)
        if (-not $CommandMap.DirectFilter) {
            if (-not (Test-PrincipalExists -PrincipalId $assignment.PrincipalId)) {
                write-host "    ├─ ❌ $principalName does not exist, skipping assignment"
                $errorCounter++
                continue
            }
        }

        # Check if group exists for Group Role assignments
        if ($ResourceType -like "Group Role*") {
            $groupId = $assignment.GroupId
            if (-not $groupId) {
                Write-Host "    ├─ ❌ Missing GroupId for assignment, skipping" -ForegroundColor Red
                $errorCounter++
                continue
            }
            
            # Validate the group exists
            try {
                $uri = "https://graph.microsoft.com/v1.0/directoryObjects/$groupId"
                Invoke-MgGraphRequest -Uri $uri -Method GET -ErrorAction Stop
                Write-Verbose "Group $groupId exists and is accessible"
                
                # Check if group is eligible for PIM (not synced from on-premises)
                if (-not (Test-GroupEligibleForPIM -GroupId $groupId)) {
                    Write-Host "    ├─ ⚠️ Group $groupId is not eligible for PIM management (likely synced from on-premises), skipping" -ForegroundColor Yellow
                    $skipCounter++
                    continue
                }
            }
            catch {
                Write-StatusWarning "Group $groupId does not exist, skipping all assignments"
                $results.Skipped += $assignmentsForGroup.Count  # Skipped rather than Failed
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

        # Initialize matchInfo variable at the beginning of the foreach loop
        $matchInfo = "unknown reason" # Initialize with default value

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
                    $matchReason = if ($null -ne $existing.memberType) {
                        "memberType='$($existing.memberType)'"
                    }
                    elseif ($null -ne $existing.Type) {
                        "type='$($existing.Type)'"
                    }
                    else {
                        "role matched"
                    }
                    $matchInfo = "principalId='$($existing.principalId)' and $matchReason"
                    Write-host "Match found for Group Role assignment: $matchInfo"
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
            # Create a SINGLE parameters hashtable - this is critical
            $params = @{}
            
            # First, copy all base parameters from the command map
            if ($CommandMap.CreateParams) {
                foreach ($key in $CommandMap.CreateParams.Keys) {
                    $params[$key] = $CommandMap.CreateParams[$key]
                }
            }
            
            # Ensure justification exists from the beginning
            if (-not $params.ContainsKey('justification')) {
                # Try to get it from Config first
                if ($Config -and $Config.PSObject.Properties.Name -contains 'Justification' -and $Config.Justification) {
                    $params['justification'] = $Config.Justification
                    Write-Verbose "Using justification from Config: $($Config.Justification)"
                }
                # Otherwise generate a new one
                else {
                    $params['justification'] = "Created by EasyPIM Orchestrator on $(Get-Date -Format 'yyyy-MM-dd')"
                    Write-Verbose "Using default justification: $($params['justification'])"
                }
            }
            
            # Display justification
            Write-Verbose "    │  ├─ 📝 Justification: $($params['justification'])"
            
            # Resource-specific parameters
            if ($ResourceType -like "Azure Role*") {
                $params['principalId'] = $assignment.PrincipalId
                $params['roleName'] = $roleName
                $params['scope'] = $assignment.Scope
            }
            elseif ($ResourceType -like "Group Role*") {
                # For Group roles, use uppercase ID properties
                $params['principalID'] = $assignment.PrincipalId  # Capital ID
                $params['groupID'] = $assignment.GroupId          # Capital ID
                $params['type'] = $roleName.ToLower()             # Lowercase type
                
                # Double-check the parameters are set
                if (-not $params.ContainsKey('groupID') -or [string]::IsNullOrEmpty($params['groupID'])) {
                    Write-Error "Failed to set groupID parameter"
                    $errorCounter++
                    continue
                }
            }
            else {
                # For other resource types like Entra roles
                $params['principalId'] = $assignment.PrincipalId
                $params['roleName'] = $roleName
            }
            
            # Handle duration and permanent settings
            if ($assignment.Permanent -eq $true) {
                $params['permanent'] = $true
                Write-Host "    │  ├─ ⏱️ Setting as permanent assignment" -ForegroundColor Cyan
            }
            elseif ($assignment.Duration) {
                $params['duration'] = $assignment.Duration
                Write-Host "    │  ├─ ⏱️ Setting duration: $($assignment.Duration)" -ForegroundColor Cyan
            }
            else {
                Write-Host "    │  ├─ ⏱️ Using maximum allowed duration" -ForegroundColor Cyan
            }
            
            # Pre-execution debug
            Write-Verbose "Command accepts these parameters: $((Get-Command $CommandMap.CreateCmd -ErrorAction SilentlyContinue).Parameters.Keys -join ', ')"
            Write-Verbose "Final command parameters:"
            Write-Verbose ($params | ConvertTo-Json -Compress)
            
            # IMPORTANT: Do not create any new parameter hashtables after this point
            
            # Action description for ShouldProcess
            $actionDescription = if ($ResourceType -like "Azure Role*") {
                "Create $ResourceType assignment for $principalName with role '$roleName' on scope $($assignment.Scope)"
            }
            else {
                "Create $ResourceType assignment for $principalName with role '$roleName'"
            }
            
            if ($PSCmdlet.ShouldProcess($actionDescription)) {
                try {
                    # Execute the command
                    $result = & $CommandMap.CreateCmd @params
                    
                    # For Group role assignments, verify the operation succeeded
                    if ($ResourceType -like "Group Role*") {
                        # Add verification that the assignment was created
                        $verifyParams = @{
                            tenantID = $params['tenantID']
                            groupID = $params['groupID']
                            # Don't include principalID to get all assignments for the group
                        }
                        
                        # Get command name based on eligible vs active
                        $verifyCmd = if ($ResourceType -like "*eligible*") {
                            "Get-PIMGroupEligibleAssignment"
                        } else {
                            "Get-PIMGroupActiveAssignment"
                        }
                        
                        Write-Verbose "Verifying assignment creation with $verifyCmd"
                        
                        # Get current assignments and verify ours exists
                        $currentAssignments = & $verifyCmd @verifyParams
                        
                        # Check if our assignment now exists
                        $assignmentExists = $false
                        foreach ($existing in $currentAssignments) {
                            if (($existing.PrincipalId -eq $params['principalID']) -and
                                ($existing.Type -eq $params['type'] -or $existing.RoleName -eq $params['type'])) {
                                $assignmentExists = $true
                                break
                            }
                        }
                        
                        if ($assignmentExists) {
                            $createCounter++
                            Write-Host "    │  └─ ✅ Created and verified successfully" -ForegroundColor Green
                        } else {
                            Write-Host "    │  └─ ⚠️ Command completed but assignment not found in verification" -ForegroundColor Yellow
                            $errorCounter++
                        }
                    }
                    # For Azure roles, we rely on the existing check
                    elseif (($null -ne $result) -or ($ResourceType -like "Azure Role*" -and $? -eq $true)) {
                        $createCounter++
                        Write-Host "    │  └─ ✅ Created successfully" -ForegroundColor Green
                    }
                    else {
                        # For other resource types
                        Write-Host "    │  └─ ⚠️ Command completed but returned null" -ForegroundColor Yellow
                        $skipCounter++
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
    Write-CreationSummary -Category "$ResourceType Assignments" -Created $createCounter -Skipped $skipCounter -Failed $errorCounter

    # Return standardized result
    return @{
        Created = $createCounter
        Skipped = $skipCounter
        Failed  = $errorCounter
    }
}
