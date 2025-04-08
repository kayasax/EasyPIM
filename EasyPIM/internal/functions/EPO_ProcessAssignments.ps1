function Process-PIMAssignments {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([System.Collections.Hashtable])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("Create", "Remove")]
        [string]$Operation,
        
        [Parameter(Mandatory = $true)]
        [string]$ResourceType,
        
        [Parameter(Mandatory = $true)]
        [array]$Assignments,
        
        [Parameter(Mandatory = $true)]
        [array]$ConfigAssignments,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$CommandMap,
        
        [Parameter(Mandatory = $false)]
        [array]$ProtectedUsers = @(),
        
        [Parameter(Mandatory = $false)]
        [string]$CleanupMode = "delta",
        
        [Parameter(Mandatory = $false)]
        [switch]$FilterByJustification,
        
        [Parameter(Mandatory = $false)]
        [string]$JustificationFilter = "Invoke-EasyPIMOrchestrator"
    )
    
    # Determine operation type
    $isCreationOperation = $Operation -eq "Create"
    $isRemovalOperation = $Operation -eq "Remove"
    
    # Initialize counters based on operation type
    if ($isCreationOperation) {
        $createCounter = 0
        $skipCounter = 0
        $errorCounter = 0
    } else {
        $keptCounter = 0
        $removeCounter = 0
        $skipCounter = 0
        $protectedCounter = 0
    }
    
    # Create a tracking map for processed assignments
    $processedAssignments = @{}
    
    # Get resource type category for matching logic
    $resourceTypeCategory = if ($ResourceType -like "Azure*") {
        "Azure"
    } elseif ($ResourceType -like "Entra*") {
        "Entra"
    } elseif ($ResourceType -like "Group*") {
        "Group"
    } else {
        "Unknown"
    }
    
    # Determine group ID if applicable
    # For GROUP resources in REMOVAL mode, we should use the GroupIDs from the CommandMap
    # For GROUP resources in CREATION mode, extract from the assignments
    $groupId = $null
    if ($resourceTypeCategory -eq "Group") {
        if ($isRemovalOperation) {
            # In removal mode, use the group ID(s) from the CommandMap
            if ($CommandMap.ContainsKey('GroupIds') -and $CommandMap.GroupIds.Count -gt 0) {
                $groupId = $CommandMap.GroupIds[0] # Use the first one for now
                Write-Verbose "Using group ID $groupId from CommandMap for removal operation"
            }
            elseif ($CommandMap.ContainsKey('groupId') -and -not [string]::IsNullOrEmpty($CommandMap.groupId)) {
                # Also check for the singular 'groupId' key which might be used instead
                $groupId = $CommandMap.groupId
                Write-Verbose "Using group ID $groupId from CommandMap (singular key) for removal operation"
            }
            elseif ($ResourceType -like "*active*" -and $CommandMap.ContainsKey('ActiveGroupId')) {
                # Try specific types for active assignments
                $groupId = $CommandMap.ActiveGroupId
                Write-Verbose "Using ActiveGroupId $groupId from CommandMap for removal operation"
            }
            elseif ($ResourceType -like "*eligible*" -and $CommandMap.ContainsKey('EligibleGroupId')) {
                # Try specific types for eligible assignments 
                $groupId = $CommandMap.EligibleGroupId
                Write-Verbose "Using EligibleGroupId $groupId from CommandMap for removal operation"
            }
            
            if (-not $groupId -and $Assignments.Count -gt 0) {
                # Last resort: try to find a groupId in one of the assignments themselves
                foreach ($assignment in $Assignments) {
                    if ($assignment.PSObject.Properties.Name -contains "groupId" -and $assignment.groupId) {
                        $groupId = $assignment.groupId
                        Write-Verbose "Found groupId $groupId in assignment data for removal operation"
                        break
                    }
                }
            }
        } 
        elseif ($isCreationOperation -and $Assignments.Count -gt 0) {
            # In creation mode, try to extract from assignments (as before)
            $firstAssignment = $Assignments[0]
            if ($firstAssignment.PSObject.Properties.Name -contains "GroupId") {
                $groupId = $firstAssignment.GroupId
                Write-Verbose "Using group ID $groupId from assignments for creation operation"
            }
        }
    }
    
    # Create header based on operation type
    $headerText = if ($isCreationOperation) {
        "Processing $ResourceType Assignments (Create)"
    } else {
        "Processing $ResourceType $CleanupMode Cleanup (Remove)"
    }
    
    # Display header
    Write-Host "`n┌────────────────────────────────────────────────────┐" -ForegroundColor Cyan
    Write-Host "│ $headerText" -ForegroundColor Cyan
    Write-Host "└────────────────────────────────────────────────────┘`n" -ForegroundColor Cyan
    
    # Get existing assignments
    $existingAssignments = @()
    try {
        if ($isCreationOperation) {
            $cmd = $CommandMap.GetCmd
            $params = $CommandMap.GetParams
        } else {
            $cmd = $CommandMap.GetCommand
            $params = @{
                tenantID = $CommandMap.TenantId
            }
            
            # Add subscription ID if applicable
            if ($resourceTypeCategory -eq "Azure" -and $CommandMap.Subscriptions -and $CommandMap.Subscriptions.Count -gt 0) {
                $params.subscriptionID = $CommandMap.Subscriptions[0]
            }
            
            # Add group ID if applicable
            if ($resourceTypeCategory -eq "Group" -and $groupId) {
                $params.groupId = $groupId
            }
        }
        
        # For Group resources, use a ScriptBlock approach to avoid parameter prompting
        if ($resourceTypeCategory -eq "Group") {
            if ($groupId) {
                # Build and execute command with all required parameters to avoid prompting
                $cmdExpression = "$cmd -tenantID '$($CommandMap.TenantId)' -groupID '$groupId'"
                $scriptBlock = [ScriptBlock]::Create($cmdExpression)
                $existingAssignments = Invoke-Command -ScriptBlock $scriptBlock -ErrorAction SilentlyContinue
            } else {
                # Skip execution if no group ID available
                Write-Warning "No group ID available for Group resource, skipping assignment retrieval"
                $existingAssignments = @()
            }
        } else {
            $existingAssignments = & $cmd @params
        }
        
        Write-Host "  🔍 Analyzing configuration" -ForegroundColor Cyan
        Write-Host "    ├─ Found $($Assignments.Count) assignments to process" -ForegroundColor White
        Write-Host "    └─ Found $($existingAssignments.Count) existing assignments" -ForegroundColor White
    }
    catch {
        Write-Host "    └─ ⚠️ Error fetching existing assignments: $_" -ForegroundColor Yellow
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
    
    # Process each assignment
    Write-Host "`n  📋 Processing assignments:" -ForegroundColor Cyan
    
    if ($Assignments.Count -eq 0) {
        Write-Host "    ├─ No assignments to process" -ForegroundColor White
        
        # Return appropriate result object based on operation type
        if ($isCreationOperation) {
            return @{
                Created = 0
                Skipped = 0
                Failed = 0
            }
        } else {
            return @{
                ResourceType = $ResourceType
                KeptCount = 0
                RemovedCount = 0
                SkippedCount = 0
                ProtectedCount = 0
            }
        }
    }
    
    foreach ($assignment in $Assignments) {
        # Extract assignment details using the helper function
        $props = Get-AssignmentProperties -Assignment $assignment
        $principalId = $props.PrincipalId
        $roleName = $props.RoleName
        $principalName = $props.PrincipalName
        $scope = $props.Scope
        
        # For group resources: 
        # In creation mode, get GroupId from the assignment directly
        # In removal mode, use the GroupId we already have from CommandMap
        $currentGroupId = $null
        if ($resourceTypeCategory -eq "Group") {
            if ($isCreationOperation) {
                # For creation, extract GroupId from the current assignment
                if ($assignment.PSObject.Properties.Name -contains "GroupId") {
                    $currentGroupId = $assignment.GroupId
                    Write-Verbose "Found GroupId $currentGroupId in assignment for creation"
                }
            } else {
                # For removal, use the GroupId from CommandMap that we stored earlier
                $currentGroupId = $groupId
                Write-Verbose "Using GroupId $currentGroupId from CommandMap for removal"
            }
        }
        
        # Skip if no principalId or roleName could be extracted
        if (-not $principalId -or -not $roleName) {
            Write-Host "    ├─ ⚠️ Invalid assignment data, skipping" -ForegroundColor Yellow
            Write-Verbose "DEBUG: Invalid assignment: $($assignment | ConvertTo-Json -Depth 2 -Compress)"
            $skipCounter++
            continue
        }
        
        # Create a unique key to track this assignment and avoid duplicates
        $assignmentKey = "$principalId|$roleName"
        if ($scope) { $assignmentKey += "|$scope" }
        if ($currentGroupId) { $assignmentKey += "|$currentGroupId" }
        
        # Skip if we've already processed this assignment
        if ($processedAssignments.ContainsKey($assignmentKey)) {
            Write-Host "    ├─ ⏭️ $principalName with role '$roleName' is a duplicate entry, skipping" -ForegroundColor DarkYellow
            $skipCounter++
            continue
        }
        
        # Mark as processed
        $processedAssignments[$assignmentKey] = $true
        
        # Check if principal exists
        if (-not (Test-PrincipalExists -PrincipalId $principalId)) {
            Write-Host "    ├─ ❌ $principalName does not exist, skipping assignment" -ForegroundColor Red
            if ($isCreationOperation) { $errorCounter++ } else { $skipCounter++ }
            continue
        }
        
        # Check if Group exists and is eligible for PIM (for Group assignments)
        if ($resourceTypeCategory -eq "Group") {
            if (-not $currentGroupId) {
                Write-Host "    ├─ ❌ Missing GroupId for assignment, skipping" -ForegroundColor Red
                if ($isCreationOperation) { $errorCounter++ } else { $skipCounter++ }
                continue
            }
            
            # Validate the group exists - but only for creation operations
            # For removal, we already validated in Invoke-PIMCleanup
            if ($isCreationOperation) {
                try {
                    $uri = "https://graph.microsoft.com/v1.0/directoryObjects/$currentGroupId"
                    Invoke-MgGraphRequest -Uri $uri -Method GET -ErrorAction Stop
                    Write-Verbose "Group $currentGroupId exists and is accessible"
                    
                    # Check if group is eligible for PIM (not synced from on-premises)
                    if (-not (Test-GroupEligibleForPIM -GroupId $currentGroupId)) {
                        Write-Host "    ├─ ⚠️ Group $currentGroupId is not eligible for PIM management (likely synced from on-premises), skipping" -ForegroundColor Yellow
                        $skipCounter++
                        continue
                    }
                }
                catch {
                    Write-Host "    ├─ ⚠️ Group $currentGroupId does not exist or cannot be accessed, skipping" -ForegroundColor Yellow
                    $skipCounter++
                    continue
                }
            }
        }
        
        # Format scope display for output
        $scopeDisplay = ""
        if ($resourceTypeCategory -eq "Azure" -and $scope) {
            $scopeDisplay = " on scope $scope"
        } elseif ($resourceTypeCategory -eq "Group" -and $currentGroupId) {
            $scopeDisplay = " in group $currentGroupId"
        }
        
        # Display assignment being processed
        Write-Host "    ├─ 🔍 $principalName with role '$roleName'$scopeDisplay" -ForegroundColor White
        
        # For Removal operation in delta mode with justification filter enabled
        if ($isRemovalOperation -and $CleanupMode -eq "delta" -and $FilterByJustification) {
            # Only consider assignments created by the orchestrator (based on justification)
            $isFromOrchestrator = Test-IsJustificationFromOrchestrator -Assignment $assignment -JustificationFilter $JustificationFilter
            
            # Skip if justification doesn't match
            if (-not $isFromOrchestrator) {
                Write-Host "    │  └─ ⏭️ Not created by orchestrator, skipping" -ForegroundColor DarkYellow
                $skipCounter++
                continue
            }
        }
        
        # Check if assignment is in config
        $foundInConfig = $false
        
        if ($isCreationOperation) {
            # For creation, current assignment is already in config
            $foundInConfig = $true
        } else {
            # For removal, check if current assignment is in config
            $foundInConfig = Test-AssignmentInConfig -PrincipalId $principalId -RoleName $roleName `
                -Scope $scope -GroupId $currentGroupId -ConfigAssignments $ConfigAssignments -ResourceType $resourceTypeCategory
        }
        
        # Check if assignment exists in current system
        $existingAssignment = $null
        $matchInfo = ""
        
        # Different comparison logic for different resource types
        foreach ($existing in $existingAssignments) {
            if ($resourceTypeCategory -eq "Entra") {
                # For Entra roles, check principal and role
                # Check for different property formats in Entra roles
                $principalMatched = $false
                $roleMatched = $false
                
                # Expanded object check
                if ($existing.PSObject.Properties.Name -contains 'principal') {
                    $principalMatched = $existing.principal.id -eq $principalId
                    $roleMatched = $existing.roleDefinition.displayName -ieq $roleName
                    if ($principalMatched && $roleMatched) {
                        $matchInfo = "principal.id='$($existing.principal.id)' and roleDefinition.displayName='$($existing.roleDefinition.displayName)'"
                    }
                } else {
                    # Standard properties
                    $principalMatched = $existing.PrincipalId -eq $principalId
                    $roleMatched = $existing.RoleName -ieq $roleName
                    if ($principalMatched && $roleMatched) {
                        $matchInfo = "PrincipalId='$($existing.PrincipalId)' and RoleName='$($existing.RoleName)'"
                    }
                }
                
                if ($principalMatched && $roleMatched) {
                    $existingAssignment = $existing
                    break
                }
            } 
            elseif ($resourceTypeCategory -eq "Group") {
                # For Group roles, check principal, role, and group
                $principalMatched = $false
                $roleMatched = $false
                
                # Check for principal match
                if ($existing.PrincipalId -eq $principalId || $existing.principalid -eq $principalId) {
                    $principalMatched = $true
                }
                
                # Check for role match with various property names
                if ($existing.RoleName -ieq $roleName || $existing.Type -ieq $roleName || $existing.memberType -ieq $roleName) {
                    $roleMatched = $true
                }
                
                if ($principalMatched && $roleMatched) {
                    $matchInfo = if ($null -ne $existing.memberType) {
                        "memberType='$($existing.memberType)'"
                    }
                    elseif ($null -ne $existing.Type) {
                        "type='$($existing.Type)'"
                    }
                    else {
                        "role matched"
                    }
                    $matchInfo = "principalId='$($existing.principalId)' and $matchInfo"
                    $existingAssignment = $existing
                    break
                }
            } 
            else {
                # For Azure roles and others, check principal, role, and scope
                if (($existing.PrincipalId -eq $principalId) && ($existing.RoleName -eq $roleName)) {
                    if ($scope) {
                        if ($existing.ScopeId -eq $scope) {
                            $matchInfo = "PrincipalId='$principalId', RoleName='$roleName', Scope='$scope'"
                            $existingAssignment = $existing
                            break
                        }
                    } else {
                        $matchInfo = "PrincipalId='$principalId', RoleName='$roleName'"
                        $existingAssignment = $existing
                        break
                    }
                }
            }
        }
        
        # Now decide what to do based on operation type and whether assignment exists
        if ($isCreationOperation) {
            # CREATION LOGIC
            if ($existingAssignment) {
                # Assignment already exists, skip creation
                Write-Host "    │  └─ ⏭️ Assignment already exists ($matchInfo), skipping" -ForegroundColor DarkYellow
                $skipCounter++
            } else {
                # Create the assignment - use the command map provided
                $params = @{}
                
                # Copy base parameters from command map
                if ($CommandMap.CreateParams) {
                    foreach ($key in $CommandMap.CreateParams.Keys) {
                        $params[$key] = $CommandMap.CreateParams[$key]
                    }
                }
                
                # Add standard justification
                if (-not $params.ContainsKey('justification')) {
                    $params['justification'] = "Created by EasyPIM Orchestrator on $(Get-Date -Format 'yyyy-MM-dd')"
                }
                
                # Add resource-specific parameters
                if ($resourceTypeCategory -eq "Azure") {
                    $params['principalId'] = $principalId
                    $params['roleName'] = $roleName
                    if ($assignment.PSObject.Properties.Name -contains "Scope") {
                        $params['scope'] = $assignment.Scope
                    }
                }
                elseif ($resourceTypeCategory -eq "Group") {
                    $params['principalID'] = $principalId
                    $params['groupID'] = $currentGroupId
                    $params['type'] = $roleName.ToLower()
                }
                else {
                    # For Entra roles and others
                    $params['principalId'] = $principalId
                    $params['roleName'] = $roleName
                }
                
                # Handle duration and permanent settings
                if ($assignment.PSObject.Properties.Name -contains "Permanent" && $assignment.Permanent -eq $true) {
                    $params['permanent'] = $true
                    Write-Host "    │  ├─ ⏱️ Setting as permanent assignment" -ForegroundColor Cyan
                }
                elseif ($assignment.PSObject.Properties.Name -contains "Duration" && $assignment.Duration) {
                    $params['duration'] = $assignment.Duration
                    Write-Host "    │  ├─ ⏱️ Setting duration: $($assignment.Duration)" -ForegroundColor Cyan
                }
                
                # Action description for ShouldProcess
                $actionDescription = "Create $ResourceType assignment for $principalName with role '$roleName'$scopeDisplay"
                
                # Create the assignment
                if ($PSCmdlet.ShouldProcess($actionDescription)) {
                    try {
                        $result = & $CommandMap.CreateCmd @params
                        
                        # Special verification for Group roles
                        if ($resourceTypeCategory -eq "Group") {
                            # Add verification that the assignment was created
                            $verifyParams = @{
                                tenantID = $params['tenantID']
                                groupID = $params['groupID']
                            }
                            
                            # Get verification command name based on assignment type
                            $verifyCmd = if ($ResourceType -like "*eligible*") {
                                "Get-PIMGroupEligibleAssignment"
                            } else {
                                "Get-PIMGroupActiveAssignment"
                            }
                            
                            # Get current assignments and check if our new assignment exists
                            $currentAssignments = & $verifyCmd @verifyParams
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
                        } else {
                            # For Azure and Entra roles
                            $createCounter++
                            Write-Host "    │  └─ ✅ Created successfully" -ForegroundColor Green
                        }
                    }
                    catch {
                        Write-Host "    │  └─ ❌ Failed to create: $_" -ForegroundColor Red
                        $errorCounter++
                    }
                } else {
                    Write-Host "    │  └─ ⏭️ Creation skipped (WhatIf mode)" -ForegroundColor DarkYellow
                    $skipCounter++
                }
            }
        } else {
            # REMOVAL LOGIC
            if ($foundInConfig) {
                # Assignment is in config, keep it
                Write-Host "    │  └─ ✅ Matches configuration, keeping" -ForegroundColor Green
                $keptCounter++
            } else {
                # Assignment is not in config, check if it should be removed
                
                # First check for protected assignments
                if ($ProtectedUsers -contains $principalId) {
                    Write-Host "    │  └─ 🛡️ Protected user, skipping removal" -ForegroundColor Yellow
                    $protectedCounter++
                    continue
                }
                
                # Check for protected roles
                if (Test-IsProtectedRole -RoleName $roleName) {
                    Write-Host "    │  └─ ⚠️ Protected role, skipping removal" -ForegroundColor Yellow
                    $protectedCounter++
                    continue
                }
                
                # Check if assignment is inherited
                $isInherited = $false
                $inheritedReason = ""
                
                # Check for inheritance indicators
                if ($existingAssignment) {
                    if ($existingAssignment.PSObject.Properties.Name -contains "memberType" -and $existingAssignment.memberType -eq "Inherited") {
                        $isInherited = $true
                        $inheritedReason = "memberType=Inherited"
                    }
                    elseif ($existingAssignment.PSObject.Properties.Name -contains "ScopeType" -and $existingAssignment.ScopeType -eq "managementgroup") {
                        $isInherited = $true
                        $inheritedReason = "ScopeType=managementgroup"
                    }
                    elseif ($existingAssignment.PSObject.Properties.Name -contains "ScopeId" -and $existingAssignment.ScopeId -like "*managementGroups*") {
                        $isInherited = $true
                        $inheritedReason = "ScopeId contains managementGroups"
                    }
                }
                
                if ($isInherited) {
                    Write-Host "    │  └─ ⏭️ Inherited assignment ($inheritedReason), skipping" -ForegroundColor DarkYellow
                    $skipCounter++
                    continue
                }
                
                # At this point, the assignment should be removed
                $removeParams = @{
                    tenantID = $CommandMap.TenantId
                    principalId = $principalId
                }
                
                # Add parameters specific to the resource type
                if ($resourceTypeCategory -eq "Azure") {
                    $removeParams.roleName = $roleName
                    # Add scope parameter if needed
                    if ($scope) {
                        $removeParams.scope = $scope
                    }
                }
                elseif ($resourceTypeCategory -eq "Group") {
                    # For Group assignments, use 'type' for the member type (owner/member)
                    $removeParams.type = $roleName
                    # Also set accessId to match the role type
                    $removeParams.accessId = $roleName
                    
                    # Add groupId parameter
                    if ($currentGroupId) {
                        $removeParams.groupId = $currentGroupId
                    }
                }
                else {
                    # For Entra roles and others, use roleName
                    $removeParams.roleName = $roleName
                }
                
                # Action description for removal
                $actionDescription = "Remove $ResourceType assignment for $principalName with role '$roleName'$scopeDisplay"
                
                # Execute removal
                if ($PSCmdlet.ShouldProcess($actionDescription)) {
                    try {
                        & $CommandMap.RemoveCmd @removeParams
                        $removeCounter++
                        Write-Host "    │  └─ 🗑️ Removed successfully" -ForegroundColor Green
                    }
                    catch {
                        if ($_.Exception.Message -match "InsufficientPermissions|inherited|cannot delete|does not belong") {
                            Write-Warning "    │  └─ ⚠️ Cannot remove: $($_.Exception.Message)"
                            $skipCounter++
                        }
                        else {
                            Write-Error "    │  └─ ❌ Failed to remove: $_"
                            $skipCounter++
                        }
                    }
                } else {
                    Write-Host "    │  └─ ⏭️ Removal skipped (WhatIf mode)" -ForegroundColor DarkYellow
                    $skipCounter++
                }
            }
        }
    }
    
    # Display summary based on operation type
    if ($isCreationOperation) {
        $summary = @"
┌────────────────────────────────────────────────────┐
│ $ResourceType Creation Summary                      
├────────────────────────────────────────────────────┤
│ ✅ Created: $createCounter
│ ⏭️ Skipped: $skipCounter
│ ❌ Failed:  $errorCounter
└────────────────────────────────────────────────────┘
"@
        Write-Host $summary -ForegroundColor Cyan
        
        return @{
            Created = [int]$createCounter
            Skipped = [int]$skipCounter
            Failed = [int]$errorCounter
        }
    } else {
        $summary = Get-FormattedCleanupSummary -ResourceType $ResourceType -KeptCount $keptCounter `
            -RemovedCount $removeCounter -SkippedCount $skipCounter -ProtectedCount $protectedCounter
        
        Write-Host $summary -ForegroundColor Cyan
        
        return @{
            ResourceType = $ResourceType
            KeptCount = [int]$keptCounter
            RemovedCount = [int]$removeCounter
            SkippedCount = [int]$skipCounter
            ProtectedCount = [int]$protectedCounter
        }
    }
}