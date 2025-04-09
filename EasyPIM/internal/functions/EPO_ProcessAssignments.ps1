# This function is deprecated.
# The functionality has been consolidated into:
# - Invoke-DeltaCleanup (for cleanup operations)
# - Invoke-PIMAssignment (for creation operations)
# This function can be safely removed in a future version.
function Invoke-PIMAssignments {
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
    
    # Create simpler header text without box formatting
    Write-Host "`n=== Processing Assignments ===" -ForegroundColor Cyan
    Write-Host "  📊 Total assignments found: $($Assignments.Count)" -ForegroundColor White
    
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
        
        Write-Host "`n  Processing: $principalName" -ForegroundColor White
        Write-Host "    ├─ Role: $roleName" -ForegroundColor Gray
        if ($scope) {
            Write-Host "    ├─ Scope: $scope" -ForegroundColor Gray
        }
        
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
        
        # Check for inherited assignments
        if ($existingAssignment -and 
            (($existingAssignment.memberType -eq "Inherited") -or
             ($existingAssignment.ScopeType -eq "managementgroup") -or
             ($existingAssignment.ScopeId -like "*managementGroups*"))) {
            Write-Host "    └─ ⏭️ Inherited assignment (memberType=Inherited) - skipping" -ForegroundColor DarkYellow
            $skipCounter++
            continue
        }

        # Check if assignment matches configuration
        if ($foundInConfig) {
            Write-Host "    └─ ✅ Matches config - keeping" -ForegroundColor Green
            $keptCounter++
        } else {
            if ($ProtectedUsers -contains $principalId) {
                Write-Host "    └─ 🛡️ Protected user - skipping" -ForegroundColor Yellow
                $protectedCounter++
            } else {
                Write-Host "    └─ ❌ Not in config - removing" -ForegroundColor Red
                $removeCounter++
            }
        }
    }
    
    # End of processing assignments loop
    if ($isCreationOperation) {
        $summary = @{
            ResourceType = $ResourceType
            Created = [int]$createCounter
            Skipped = [int]$skipCounter
            Failed = [int]$errorCounter
        }
        
        if ($resourceTypeCategory -eq "Azure" -or $resourceTypeCategory -eq "Entra") {
            # For Azure and Entra roles, return summary without displaying it
            return $summary
        } else {
            # For other types (like Groups), write formatted summary and return
            $summaryOutput = Get-FormattedCleanupSummary -ResourceType "$ResourceType Assignments" `
                -KeptCount $summary.Created `
                -RemovedCount $summary.Failed `
                -SkippedCount $summary.Skipped
            Write-Host $summaryOutput
            return $summary
        }
    } else {
        $summary = @{
            ResourceType = $ResourceType
            KeptCount = [int]$keptCounter
            RemovedCount = [int]$removeCounter
            SkippedCount = [int]$skipCounter
            ProtectedCount = [int]$protectedCounter
        }
        
        if ($resourceTypeCategory -ne "Azure" -and $resourceTypeCategory -ne "Entra") {
            # For non-Azure/Entra types, write formatted summary
            $summaryOutput = Get-FormattedCleanupSummary -ResourceType "$ResourceType Cleanup" `
                -KeptCount $summary.KeptCount `
                -RemovedCount $summary.RemovedCount `
                -SkippedCount $summary.SkippedCount `
                -ProtectedCount $summary.ProtectedCount
            Write-Host $summaryOutput
        }
        return $summary
    }
}

# Process PIM assignments using the robust Invoke-ResourceAssignment function
function Invoke-PIMAssignment {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([System.Collections.Hashtable])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
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
    
    # When Operation is Create, use Invoke-ResourceAssignment
    if ($Operation -eq "Create") {
        # Create a simple config object for justification
        $Config = [PSCustomObject]@{
            Justification = "Created by EasyPIM Orchestrator on $(Get-Date -Format 'yyyy-MM-dd')"
            ProtectedUsers = $ProtectedUsers
        }
        
        return Invoke-ResourceAssignment -ResourceType $ResourceType -Assignments $Assignments -CommandMap $CommandMap -Config $Config
    }
    else {
        # For Remove operations, use existing functionality or Invoke-DeltaCleanup
        Write-Warning "Remove operation not implemented in this function. Please use Invoke-DeltaCleanup instead."
        return @{
            Created = 0
            Skipped = 0
            Failed = 0
        }
    }
}

# Create aliases for backward compatibility
Set-Alias -Name Process-PIMAssignments -Value Invoke-PIMAssignment
Set-Alias -Name Process-PIMAssignment -Value Invoke-PIMAssignment