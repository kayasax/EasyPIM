function Invoke-ResourceAssignments {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ResourceType,
        
        [Parameter(Mandatory = $true)]
        [array]$Assignments,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$CommandMap
    )
    
    Write-Output "Processing $ResourceType assignments..."
    Write-Output "Found $($Assignments.Count) $ResourceType assignments in config"
    
    $counter = 0
    $createCounter = 0
    $skipCounter = 0
    $errorCounter = 0
    
    # Get existing assignments
    $getParams = $CommandMap.GetParams.Clone()
    $existingAssignments = & $CommandMap.GetCmd @getParams
    
    if ($CommandMap.DirectFilter) {
        $existingAssignments = $existingAssignments | Where-Object { $_.memberType -eq "Direct" }
    }
    
    Write-Output "Found $($existingAssignments.Count) existing assignments"
    
    # Group assignments by principal for batch processing
    $principalGroups = $Assignments | Group-Object -Property PrincipalId
    foreach ($principalGroup in $principalGroups) {
        $principalId = $principalGroup.Name
        
        # Check principal once per batch
        if (-not (Test-PrincipalExists -PrincipalId $principalId)) {
            Write-Warning "⚠️ Principal $principalId does not exist, skipping all assignments"
            $errorCounter += $principalGroup.Group.Count
            continue
        }
        
        # Process all assignments for this principal
        foreach ($assignment in $principalGroup.Group) {
            $counter++
            $assignmentDesc = "$ResourceType : PrincipalId=$($assignment.PrincipalId), Role=$($assignment.Rolename)"
            if ($assignment.Scope) { $assignmentDesc += ", Scope=$($assignment.Scope)" }
            if ($assignment.GroupId) { $assignmentDesc += ", GroupId=$($assignment.GroupId)" }
            
            Write-Output "[$counter/$($Assignments.Count)] Processing $assignmentDesc"
            
            # Check if assignment already exists
            $found = 0
            foreach ($existing in $existingAssignments) {
                $isMatch = $true
                
                # Check principal ID match
                if ($existing.PrincipalId -ne $assignment.PrincipalId) {
                    $isMatch = $false
                    continue
                }
                
                # Check role name match
                if ($existing.RoleName -ne $assignment.Rolename) {
                    $isMatch = $false
                    continue
                }
                
                # Check scope match if applicable
                if ($assignment.Scope -and ($existing.ScopeId -ne $assignment.Scope)) {
                    $isMatch = $false
                    continue
                }
                
                # Check group ID match if applicable
                if ($assignment.GroupId -and ($existing.GroupId -ne $assignment.GroupId)) {
                    $isMatch = $false
                    continue
                }
                
                if ($isMatch) {
                    $found = 1
                    break
                }
            }
            
            if ($found -eq 0) {
                $actionDescription = "Create new $assignmentDesc"
                
                if ($PSCmdlet.ShouldProcess($actionDescription)) {
                    Write-Output "⚙️ $actionDescription"
                    
                    # Clone the params to avoid modifying the original
                    $createParams = $CommandMap.CreateParams.Clone()
                    
                    # Add common parameters
                    $createParams['principalId'] = $assignment.PrincipalId
                    $createParams['roleName'] = $assignment.Rolename
                    $createParams['justification'] = $justification
                    
                    # Add resource-specific parameters
                    if ($assignment.Scope) {
                        $createParams['scope'] = $assignment.Scope
                    }
                    
                    if ($assignment.GroupId) {
                        $createParams['groupId'] = $assignment.GroupId
                    }
                    
                    if ($assignment.Duration) {
                        $createParams['duration'] = $assignment.Duration
                    }
                    
                    # Call the create command
                    try {
                        & $CommandMap.CreateCmd @createParams
                        $createCounter++
                    }
                    catch {
                        Write-Error "Failed to create assignment: $_"
                        $errorCounter++
                    }
                }
            }
            else {
                Write-Output "✓ $assignmentDesc already exists"
                $skipCounter++
            }
        }
    }
    
    Write-Output "$ResourceType assignments: $createCounter created, $skipCounter skipped (already exist), $errorCounter failed/skipped (error)"
}