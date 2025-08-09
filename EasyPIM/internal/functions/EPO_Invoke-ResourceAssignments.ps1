function Invoke-ResourceAssignment {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([System.Collections.Hashtable])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")] # Suppress false positive (all counters and params used)
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
    # Track planned creations when running in WhatIf (simulation) mode
    $plannedCreateCounter = 0

    # Cache for principalId -> display name to avoid repeated lookups
    $principalNameCache = @{}

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

    # Build fast lookup index for Entra ID role assignments to avoid O(N^2) comparisons
    $entraIndex = $null
    if ($ResourceType -like "Entra ID Role*") {
        $entraIndex = @{}
        foreach ($ex in $existingAssignments) {
            # Extract principalId from multiple possible shapes
            $exPrincipal = $null
            foreach ($p in 'principal.id','PrincipalId','principalId','principalid') {
                if ($p -eq 'principal.id' -and $ex.PSObject.Properties.Name -contains 'principal' -and $ex.principal -and $ex.principal.id) { $exPrincipal = $ex.principal.id; break }
                elseif ($ex.PSObject.Properties.Name -contains $p -and $ex.$p) { $exPrincipal = $ex.$p; break }
            }
            if (-not $exPrincipal) { continue }

            # Extract role name from expanded or flat shapes
            $exRoleName = $null
            if ($ex.PSObject.Properties.Name -contains 'roleDefinition' -and $ex.roleDefinition -and $ex.roleDefinition.displayName) {
                $exRoleName = $ex.roleDefinition.displayName
            } elseif ($ex.PSObject.Properties.Name -contains 'RoleName' -and $ex.RoleName) {
                $exRoleName = $ex.RoleName
            } elseif ($ex.PSObject.Properties.Name -contains 'rolename' -and $ex.rolename) {
                $exRoleName = $ex.rolename
            }
            if (-not $exRoleName) { continue }

            $key = ($exPrincipal + '|' + ($exRoleName.ToLower()))
            if (-not $entraIndex.ContainsKey($key)) { $entraIndex[$key] = $ex }
        }
        Write-Verbose "Built Entra assignment index with $($entraIndex.Count) entries"
    }

    # Add debug output for assignments
    if ($Assignments.Count -gt 0) {
        write-host "`n  📋 Processing assignments:"
        write-host "    ├─ Found $($Assignments.Count) assignments to process"

        # Display details for ALL assignments
        foreach ($assignment in $Assignments) {
            $principalId = $assignment.PrincipalId
            # Robust role name extraction supporting multiple property variants
            $roleName = $null
            foreach ($prop in 'RoleName','Rolename','Role','roleName','rolename','role','type','Type') {
                if ($assignment.PSObject.Properties.Name -contains $prop -and $assignment.$prop) { $roleName = $assignment.$prop; break }
            }
            if (-not $roleName) { $roleName = '<UnknownRole>' }

            # Fix scope display - different formats for different resource types
            $scopeDisplay = ""
            if ($ResourceType -like "Azure Role*" -and $assignment.Scope) {
                $scopeDisplay = " on scope $($assignment.Scope)"
            }
            elseif ($ResourceType -like "Group*" -and $assignment.GroupId) {
                $scopeDisplay = " in group $($assignment.GroupId)"
            }
            # For Entra ID roles, no scope is needed

            # Resolve friendly name (user / group / service principal)
            $principalName = $null
            if ($principalNameCache.ContainsKey($principalId)) {
                $principalName = $principalNameCache[$principalId]
            } else {
                try {
                    $u = Get-MgUser -UserId $principalId -ErrorAction SilentlyContinue
                    if ($u -and $u.DisplayName) { $principalName = $u.DisplayName }
                } catch {
                    Write-Verbose ("Lookup user failed for {0}: {1}" -f $principalId, $_.Exception.Message)
                }
                if (-not $principalName) {
                    try { $g = Get-MgGroup -GroupId $principalId -ErrorAction SilentlyContinue; if ($g -and $g.DisplayName) { $principalName = $g.DisplayName } } catch { Write-Verbose ("Lookup group failed for {0}: {1}" -f $principalId, $_.Exception.Message) }
                }
                if (-not $principalName) {
                    try { $sp = Get-MgServicePrincipal -ServicePrincipalId $principalId -ErrorAction SilentlyContinue; if ($sp -and $sp.DisplayName) { $principalName = $sp.DisplayName } } catch { Write-Verbose ("Lookup service principal failed for {0}: {1}" -f $principalId, $_.Exception.Message) }
                }
                if (-not $principalName) { $principalName = "Principal-$principalId" }
                $principalNameCache[$principalId] = $principalName
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

        # Robust role name extraction supporting RoleName/Rolename/Role and group role types
        $roleName = $null
        foreach ($prop in @('RoleName','Rolename','Role','roleName','rolename','role','type','Type','memberType')) {
            if ($assignment.PSObject.Properties.Name -contains $prop -and $assignment.$prop) { $roleName = $assignment.$prop; break }
        }

        if (-not $roleName) {
            Write-Warning "Assignment is missing Role/Rolename: $($assignment | ConvertTo-Json -Compress)"
            $errorCounter++
            continue
        }

        # Get a friendly name for the principal (single directoryObjects lookup to avoid noisy 404s)
        # Try cache first
        if ($principalNameCache.ContainsKey($principalId)) {
            $principalName = $principalNameCache[$principalId]
        } else {
            $principalName = "Principal-$principalId"
            try {
                $dirObj = Invoke-Graph -Endpoint "directoryObjects/$principalId" -Method GET -ErrorAction Stop
                if ($dirObj) {
                    if ($dirObj.PSObject.Properties.Name -contains 'displayName' -and $dirObj.displayName) {
                        $principalName = $dirObj.displayName
                    }
                }
            } catch {
                Write-Verbose ("DirectoryObjects lookup failed for {0}: {1}" -f $principalId, $_.Exception.Message)
            }
            if ($principalName -eq "Principal-$principalId") {
                # Fallback to specific entity queries
                try { $u = Get-MgUser -UserId $principalId -ErrorAction SilentlyContinue; if ($u.DisplayName) { $principalName = $u.DisplayName } } catch { Write-Verbose ("Fallback user lookup failed for {0}: {1}" -f $principalId, $_.Exception.Message) }
                if ($principalName -eq "Principal-$principalId") { try { $g = Get-MgGroup -GroupId $principalId -ErrorAction SilentlyContinue; if ($g.DisplayName) { $principalName = $g.DisplayName } } catch { Write-Verbose ("Fallback group lookup failed for {0}: {1}" -f $principalId, $_.Exception.Message) } }
                if ($principalName -eq "Principal-$principalId") { try { $sp = Get-MgServicePrincipal -ServicePrincipalId $principalId -ErrorAction SilentlyContinue; if ($sp.DisplayName) { $principalName = $sp.DisplayName } } catch { Write-Verbose ("Fallback service principal lookup failed for {0}: {1}" -f $principalId, $_.Exception.Message) } }
            }
            $principalNameCache[$principalId] = $principalName
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
                Write-Host "    ├─ ⚠️ Group $groupId does not exist or is inaccessible, skipping" -ForegroundColor Yellow
                $skipCounter++
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
        if ($ResourceType -like "Entra ID Role*") {
            if ($entraIndex) {
                $lookupKey = ($assignment.PrincipalId + '|' + ($roleName.ToLower()))
                if ($entraIndex.ContainsKey($lookupKey)) {
                    $found = 1
                    Write-Verbose "Match found in Entra index for key $lookupKey"
                } else {
                    Write-Verbose "No match in Entra index for key $lookupKey"
                }
            }
        } else {
            foreach ($existing in $existingAssignments) {
                Write-Verbose "Comparing with existing: $($existing | ConvertTo-Json -Depth 4 -ErrorAction SilentlyContinue)"

                if ($ResourceType -like "Group Role*") {
                    if ($existingAssignments.Count -gt 0 -and $existing -eq $existingAssignments[0]) {
                        Write-Verbose "First Group Role existing assignment structure:"
                        Write-Verbose ($existing | ConvertTo-Json -Depth 10 -ErrorAction SilentlyContinue)
                    }

                    $principalMatched = ($existing.PrincipalId -eq $assignment.PrincipalId -or $existing.principalid -eq $assignment.PrincipalId)
                    if ($principalMatched) { Write-Verbose "Principal ID matched in group assignment" }

                    $roleMatched = ($existing.RoleName -ieq $roleName -or $existing.Type -ieq $roleName -or $existing.memberType -ieq $roleName)
                    if ($roleMatched) { Write-Verbose "Role/type matched in group assignment" }

                    if ($principalMatched -and $roleMatched) {
                        $found = 1
                        $matchReason = if ($null -ne $existing.memberType) { "memberType='$($existing.memberType)'" } elseif ($null -ne $existing.Type) { "type='$($existing.Type)'" } else { "role matched" }
                        $matchInfo = "principalId='$($existing.principalId)' and $matchReason"
                        Write-Host "Match found for Group Role assignment: $matchInfo"
                        break
                    }
                }
                else {
                    if (($existing.PrincipalId -eq $assignment.PrincipalId) -and ($existing.RoleName -ieq $roleName)) {
                        if ($assignment.PSObject.Properties.Name -contains 'Scope' -or $assignment.PSObject.Properties.Name -contains 'scope') {
                            $targetScope = if ($assignment.PSObject.Properties.Name -contains 'Scope') { $assignment.Scope } else { $assignment.scope }
                            $existingScope = $null
                            foreach ($prop in @('ScopeId','scope','Scope')) {
                                if ($existing.PSObject.Properties.Name -contains $prop -and $existing.$prop) { $existingScope = $existing.$prop; break }
                            }
                            if ($existingScope -eq $targetScope) { $found = 1; break } else { continue }
                        } else { $found = 1; break }
                    }
                }
            }
        }

        if ($found -eq 0) {
            # Count as planned creation up-front (even if WhatIf prevents execution)
            $plannedCreateCounter++
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
                # For Azure roles, use lowercase property names
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

            # Action description for ShouldProcess with detailed information
            $assignmentDetails = @()
            # Show friendly display name inside parentheses when available; keep GUID as primary for traceability
            if ($principalName -and $principalName -ne "Principal-$principalId") {
                $assignmentDetails += "Principal: $principalId ($principalName)"
            } else {
                $assignmentDetails += "Principal: $principalName ($principalId)"
            }
            $assignmentDetails += "Role: '$roleName'"

            if ($ResourceType -like "Azure Role*") {
                $assignmentDetails += "Scope: $($assignment.Scope)"
            }
            elseif ($ResourceType -like "Group*") {
                $assignmentDetails += "Group: $($assignment.GroupId)"
            }

            $assignmentDetails += "Assignment Type: $(if ($ResourceType -like '*eligible*') { 'Eligible' } else { 'Active' })"

            if ($assignment.Duration) {
                $assignmentDetails += "Duration: $($assignment.Duration)"
            }

            if ($assignment.Justification) {
                $assignmentDetails += "Justification: $($assignment.Justification)"
            }

            $actionDescription = "Create $ResourceType assignment with details:`n    • $($assignmentDetails -join ' | ')"

            $shouldProcess = $PSCmdlet.ShouldProcess($actionDescription)
            if ($shouldProcess) {
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
                    # For Entra ID and Azure role assignments
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
            } else {
                Write-Verbose "Simulation only (WhatIf) - not executing create for $principalId / $roleName"
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

    # Add a closing section with summary
    Write-Host "`n  📊 Processing completed:"
    Write-Host "    ├─ Created: $createCounter"
    Write-Host "    ├─ Skipped: $skipCounter"
    Write-Host "    └─ Failed: $errorCounter"
    Write-Host "`n┌────────────────────────────────────────────────────┐"
    Write-Host "│ Completed $ResourceType Assignments"
    Write-Host "└────────────────────────────────────────────────────┘"

    # Return the counters in a structured format without writing the summary (it will be handled by EPO_New-Assignment.ps1)
    return @{
        Created = $createCounter
        Skipped = $skipCounter
    Failed  = $errorCounter
    PlannedCreated = $plannedCreateCounter
    }
}

# Create an alias for backward compatibility
Set-Alias -Name Invoke-ResourceAssignments -Value Invoke-ResourceAssignment
