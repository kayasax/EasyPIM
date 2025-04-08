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
    $groupId = $null
    if ($resourceTypeCategory -eq "Group") {
        if ($isRemovalOperation) {
            if ($CommandMap.ContainsKey('GroupIds') -and $CommandMap.GroupIds.Count -gt 0) {
                $groupId = $CommandMap.GroupIds[0]
                Write-Verbose "Using group ID $groupId from CommandMap for removal operation"
            }
            elseif ($CommandMap.ContainsKey('groupId') -and -not [string]::IsNullOrEmpty($CommandMap.groupId)) {
                $groupId = $CommandMap.groupId
                Write-Verbose "Using group ID $groupId from CommandMap (singular key) for removal operation"
            }
            elseif ($ResourceType -like "*active*" -and $CommandMap.ContainsKey('ActiveGroupId')) {
                $groupId = $CommandMap.ActiveGroupId
                Write-Verbose "Using ActiveGroupId $groupId from CommandMap for removal operation"
            }
            elseif ($ResourceType -like "*eligible*" -and $CommandMap.ContainsKey('EligibleGroupId')) {
                $groupId = $CommandMap.EligibleGroupId
                Write-Verbose "Using EligibleGroupId $groupId from CommandMap for removal operation"
            }
            
            if (-not $groupId -and $Assignments.Count -gt 0) {
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
            
            if ($resourceTypeCategory -eq "Azure" -and $CommandMap.Subscriptions -and $CommandMap.Subscriptions.Count -gt 0) {
                $params.subscriptionID = $CommandMap.Subscriptions[0]
            }
            
            if ($resourceTypeCategory -eq "Group" -and $groupId) {
                $params.groupId = $groupId
            }
        }
        
        if ($resourceTypeCategory -eq "Group") {
            if ($groupId) {
                $cmdExpression = "$cmd -tenantID '$($CommandMap.TenantId)' -groupID '$groupId'"
                $scriptBlock = [ScriptBlock]::Create($cmdExpression)
                $existingAssignments = Invoke-Command -ScriptBlock $scriptBlock -ErrorAction SilentlyContinue
            } else {
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
    
    if ($null -eq $existingAssignments) {
        Write-Verbose "Command returned null result, initializing empty array"
        $existingAssignments = @()
    }
    elseif (-not ($existingAssignments -is [array])) {
        Write-Verbose "Command returned a single object, converting to array"
        $existingAssignments = @($existingAssignments)
    }
    
    Write-Host "`n  📋 Processing assignments:" -ForegroundColor Cyan
    
    if ($Assignments.Count -eq 0) {
        Write-Host "    ├─ No assignments to process" -ForegroundColor White
        
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
        $props = Get-AssignmentProperties -Assignment $assignment
        $principalId = $props.PrincipalId
        $roleName = $props.RoleName
        $principalName = $props.PrincipalName
        $scope = $props.Scope
        
        $currentGroupId = $null
        if ($resourceTypeCategory -eq "Group") {
            if ($isCreationOperation) {
                if ($assignment.PSObject.Properties.Name -contains "GroupId") {
                    $currentGroupId = $assignment.GroupId
                    Write-Verbose "Found GroupId $currentGroupId in assignment for creation"
                }
            } else {
                $currentGroupId = $groupId
                Write-Verbose "Using GroupId $currentGroupId from CommandMap for removal"
            }
        }
        
        if (-not $principalId -or -not $roleName) {
            Write-Host "    ├─ ⚠️ Invalid assignment data, skipping" -ForegroundColor Yellow
            Write-Verbose "DEBUG: Invalid assignment: $($assignment | ConvertTo-Json -Depth 2 -Compress)"
            $skipCounter++
            continue
        }
        
        $assignmentKey = "$principalId|$roleName"
        if ($scope) { $assignmentKey += "|$scope" }
        if ($currentGroupId) { $assignmentKey += "|$currentGroupId" }
        
        if ($processedAssignments.ContainsKey($assignmentKey)) {
            Write-Host "    ├─ ⏭️ $principalName with role '$roleName' is a duplicate entry, skipping" -ForegroundColor DarkYellow
            $skipCounter++
            continue
        }
        
        $processedAssignments[$assignmentKey] = $true
        
        if (-not (Test-PrincipalExists -PrincipalId $principalId)) {
            Write-Host "    │  ❌ Principal '$principalName' ($principalId) does not exist, skipping assignment" -ForegroundColor Red
            $errorCounter++
            continue
        }
        
        if ($resourceTypeCategory -eq "Group") {
            if (-not $currentGroupId) {
                Write-Host "    ├─ ❌ Missing GroupId for assignment, skipping" -ForegroundColor Red
                $errorCounter++
                continue
            }
            
            try {
                $uri = "https://graph.microsoft.com/v1.0/directoryObjects/$currentGroupId"
                Invoke-MgGraphRequest -Uri $uri -Method GET -ErrorAction Stop
                Write-Verbose "Group $currentGroupId exists and is accessible"
                
                if (-not (Test-GroupEligibleForPIM -GroupId $currentGroupId)) {
                    Write-Host "    │  ⚠️ Group $currentGroupId is not eligible for PIM management (likely synced from on-premises), skipping" -ForegroundColor Yellow
                    $skipCounter++
                    continue
                }
            }
            catch {
                Write-Host "    │  ⚠️ Group $currentGroupId does not exist or cannot be accessed, skipping" -ForegroundColor Yellow
                $skipCounter++
                continue
            }
        }
        
        $scopeDisplay = ""
        if ($resourceTypeCategory -eq "Azure" -and $scope) {
            $scopeDisplay = " on scope $scope"
        } elseif ($resourceTypeCategory -eq "Group" -and $currentGroupId) {
            $scopeDisplay = " in group $currentGroupId"
        }
        
        Write-Host "    ├─ 🔍 $principalName with role '$roleName'$scopeDisplay" -ForegroundColor White
        
        if ($isRemovalOperation -and $CleanupMode -eq "delta" -and $FilterByJustification) {
            $isFromOrchestrator = Test-IsJustificationFromOrchestrator -Assignment $assignment -JustificationFilter $JustificationFilter
            
            if (-not $isFromOrchestrator) {
                Write-Host "    │  └─ ⏭️ Not created by orchestrator, skipping" -ForegroundColor DarkYellow
                $skipCounter++
                continue
            }
        }
        
        $foundInConfig = $false
        
        if ($isCreationOperation) {
            $foundInConfig = $true
        } else {
            $foundInConfig = Test-AssignmentInConfig -PrincipalId $principalId -RoleName $roleName `
                -Scope $scope -GroupId $currentGroupId -ConfigAssignments $ConfigAssignments -ResourceType $resourceTypeCategory
        }
        
        $existingAssignment = $null
        $matchInfo = ""
        
        foreach ($existing in $existingAssignments) {
            if ($resourceTypeCategory -eq "Entra") {
                $principalMatched = $false
                $roleMatched = $false
                
                if ($existing.PSObject.Properties.Name -contains 'principal') {
                    $principalMatched = $existing.principal.id -eq $principalId
                    $roleMatched = $existing.roleDefinition.displayName -ieq $roleName
                    if ($principalMatched && $roleMatched) {
                        $matchInfo = "principal.id='$($existing.principal.id)' and roleDefinition.displayName='$($existing.roleDefinition.displayName)'"
                    }
                } else {
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
                $principalMatched = $false
                $roleMatched = $false
                
                if ($existing.PrincipalId -eq $principalId || $existing.principalid -eq $principalId) {
                    $principalMatched = $true
                }
                
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
        
        if ($isCreationOperation) {
            if ($existingAssignment) {
                Write-Host "    │  └─ ⏭️ Assignment already exists ($matchInfo), skipping" -ForegroundColor DarkYellow
                $skipCounter++
            } else {
                $params = @{}
                
                if ($CommandMap.CreateParams) {
                    foreach ($key in $CommandMap.CreateParams.Keys) {
                        $params[$key] = $CommandMap.CreateParams[$key]
                    }
                }
                
                if (-not $params.ContainsKey('justification')) {
                    $params['justification'] = "Created by EasyPIM Orchestrator on $(Get-Date -Format 'yyyy-MM-dd')"
                }
                
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
                    $params['principalId'] = $principalId
                    $params['roleName'] = $roleName
                }
                
                if ($assignment.PSObject.Properties.Name -contains "Permanent" && $assignment.Permanent -eq $true) {
                    $params['permanent'] = $true
                    Write-Host "    │  ├─ ⏱️ Setting as permanent assignment" -ForegroundColor Cyan
                }
                elseif ($assignment.PSObject.Properties.Name -contains "Duration" && $assignment.Duration) {
                    $params['duration'] = $assignment.Duration
                    Write-Host "    │  ├─ ⏱️ Setting duration: $($assignment.Duration)" -ForegroundColor Cyan
                }
                
                $actionDescription = "Create $ResourceType assignment for $principalName with role '$roleName'$scopeDisplay"
                
                if ($PSCmdlet.ShouldProcess($actionDescription)) {
                    try {
                        $result = & $CommandMap.CreateCmd @params
                        
                        if ($resourceTypeCategory -eq "Group") {
                            $verifyParams = @{
                                tenantID = $params['tenantID']
                                groupID = $params['groupID']
                            }
                            
                            $verifyCmd = if ($ResourceType -like "*eligible*") {
                                "Get-PIMGroupEligibleAssignment"
                            } else {
                                "Get-PIMGroupActiveAssignment"
                            }
                            
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
            if ($foundInConfig) {
                Write-Host "    │  └─ ✅ Matches configuration, keeping" -ForegroundColor Green
                $keptCounter++
            } else {
                if ($ProtectedUsers -contains $principalId) {
                    Write-Host "    │  └─ 🛡️ Protected user, skipping removal" -ForegroundColor Yellow
                    $protectedCounter++
                    continue
                }
                
                if (Test-IsProtectedRole -RoleName $roleName) {
                    Write-Host "    │  └─ ⚠️ Protected role, skipping removal" -ForegroundColor Yellow
                    $protectedCounter++
                    continue
                }
                
                $isInherited = $false
                $inheritedReason = ""
                
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
                
                $removeParams = @{
                    tenantID = $CommandMap.TenantId
                    principalId = $principalId
                }
                
                if ($resourceTypeCategory -eq "Azure") {
                    $removeParams.roleName = $roleName
                    if ($scope) {
                        $removeParams.scope = $scope
                    }
                }
                elseif ($resourceTypeCategory -eq "Group") {
                    $removeParams.type = $roleName
                    $removeParams.accessId = $roleName
                    
                    if ($currentGroupId) {
                        $removeParams.groupId = $currentGroupId
                    }
                }
                else {
                    $removeParams.roleName = $roleName
                }
                
                $actionDescription = "Remove $ResourceType assignment for $principalName with role '$roleName'$scopeDisplay"
                
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
    
    if ($isCreationOperation) {
        return @{
            Created = [int]$createCounter
            Skipped = [int]$skipCounter
            Failed = [int]$errorCounter
        }
    } else {
        return @{
            ResourceType = $ResourceType
            KeptCount = [int]$keptCounter
            RemovedCount = [int]$removeCounter
            SkippedCount = [int]$skipCounter
            ProtectedCount = [int]$protectedCounter
        }
    }
}