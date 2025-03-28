function Invoke-AzureRoleCleanup {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ResourceType,
        
        [Parameter(Mandatory = $true)]
        [array]$ConfigAssignments,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$ApiInfo,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,
        
        [Parameter(Mandatory = $false)]
        [array]$ProtectedUsers = @(),
        
        [Parameter(Mandatory = $true)]
        [ref]$KeptCounter,
        
        [Parameter(Mandatory = $true)]
        [ref]$RemoveCounter,
        
        [Parameter(Mandatory = $true)]
        [ref]$SkipCounter
    )
    
    # Process each subscription
    foreach ($subscription in $ApiInfo.Subscriptions) {
        Write-Output "  🔍 Checking subscription: $subscription"
        
        # Get current assignments 
        $getCmd = if ($ResourceType -eq "Azure Role eligible") {
            "Get-PIMAzureResourceEligibleAssignment"
        } else {
            "Get-PIMAzureResourceActiveAssignment"
        }
        
        # Get all assignments for this subscription
        $allAssignments = & $getCmd -SubscriptionId $subscription -TenantId $ApiInfo.TenantId
        Write-Output "    ├─ Found $($allAssignments.Count) total current assignments"
        
        # Debug invalid assignments
        $invalidAssignments = $allAssignments | Where-Object { 
            (-not $_.SubjectId) -or (-not $_.RoleName) 
        }
        
        if ($invalidAssignments.Count -gt 0) {
            Write-Output "    ├─ Found $($invalidAssignments.Count) system/orphaned assignments (normal)"
            Write-Verbose "Detailed invalid assignment properties:"
            foreach ($invalid in $invalidAssignments) {
                $invalidJson = $invalid | ConvertTo-Json -Depth 1 -Compress
                Write-Verbose "System assignment: $invalidJson"
            }
        }
        
        # Process valid assignments
        $validAssignments = $allAssignments | Where-Object { 
            $_.SubjectId -and $_.RoleName 
        }
        
        if ($validAssignments.Count -gt 0 -and $validAssignments[0]) {
            Write-Verbose "DEBUG: First assignment properties:"
            Write-Verbose ($validAssignments[0] | Format-List | Out-String)
        }
        
        if ($validAssignments.Count -gt 0) {
            Write-Output "`n  📋 Analyzing assignments:"
            
            foreach ($assignment in $validAssignments) {
                # Dump assignment properties at the beginning to understand what we're working with
                Write-Verbose "Full assignment properties:"
                foreach ($prop in $assignment.PSObject.Properties) {
                    Write-Verbose "  $($prop.Name): $($prop.Value)"
                }

                # Extract main properties - handle different property naming conventions
                $principalId = $assignment.PrincipalId ?? $assignment.SubjectId ?? $assignment.principalId
                $roleName = $assignment.RoleDefinitionDisplayName ?? $assignment.RoleName ?? $assignment.roleName
                $principalName = $assignment.PrincipalDisplayName ?? $assignment.SubjectName ?? $assignment.displayName ?? "Principal-$principalId"
                $scope = $assignment.ResourceId ?? $assignment.scope ?? $assignment.Scope ?? "/subscriptions/$subscription"
                
                #region Check if assignment is in config
                $foundInConfig = $false
                
                foreach ($configAssignment in $ConfigAssignments) {
                    # Make sure all the necessary properties exist before comparison
                    if (-not $configAssignment.PrincipalId -or -not ($configAssignment.RoleName -or $configAssignment.Role)) {
                        Write-Verbose "Skipping invalid config entry: $($configAssignment | ConvertTo-Json -Compress)"
                        continue
                    }
                    
                    # Check if principal, role and scope match
                    $matchesPrincipal = $configAssignment.PrincipalId -eq $principalId
                    $matchesRole = $configAssignment.RoleName -ieq $roleName -or $configAssignment.Role -ieq $roleName
                    
                    # Handle different scope formats
                    $configScope = $configAssignment.Scope
                    $matchesScope = $false
                    
                    if ($configScope) {
                        # Direct match
                        if ($configScope -eq $scope) {
                            $matchesScope = $true
                        }
                        # Handle subscription level scopes with different formats
                        elseif ($configScope -match "/subscriptions/([^/]+)" -and $scope -match "/subscriptions/([^/]+)") {
                            $configSubId = $matches[1]
                            $matchesScope = $scope -match $configSubId
                        }
                    }
                    
                    # Match found
                    if ($matchesPrincipal -and $matchesRole -and $matchesScope) {
                        $foundInConfig = $true
                        Write-Verbose "Match found in config for: $principalName with role '$roleName' at scope '$scope'"
                        break
                    }
                }
                #endregion
                
                # Keep assignment if it's in config
                if ($foundInConfig) {
                    Write-Output "    ├─ ✅ $principalName with role '$roleName' matches config, keeping"
                    $KeptCounter.Value++
                    continue
                }
                
                #region Check if protected user
                if ($ProtectedUsers -contains $principalId) {
                    Write-Output "    │  └─ 🛡️ Protected user! Skipping removal"
                    $SkipCounter.Value++
                    continue
                }
                #endregion
                
                #region Check if assignment is inherited
                # Dump the raw assignment object first for debugging
                Write-Host "DEBUG: Examining assignment with principal $principalId and role $roleName"

                # Multiple checks for inherited assignments
                $isInherited = $false

                # Add comprehensive logging for troubleshooting
                Write-Verbose "DEBUG: Checking inheritance status for $principalId"
                Write-Verbose "DEBUG: Assignment properties: $($assignment | ConvertTo-Json -Depth 1 -Compress)"
                Write-Verbose "DEBUG: memberType value: '$($assignment.memberType)'"
                Write-Verbose "DEBUG: ScopeType value: '$($assignment.ScopeType)'"
                Write-Verbose "DEBUG: ScopeId value: '$($assignment.ScopeId)'"

                # Force string comparison for memberType to avoid type issues
                if ($assignment.PSObject.Properties.Name -contains "memberType" -and "$($assignment.memberType)" -eq "Inherited") {
                    Write-Host "    ├─ ⏭️ $principalName with role '$roleName' is an inherited assignment (memberType), skipping"
                    $isInherited = $true
                }
                # Check #2: ScopeId property referencing management groups
                elseif ($assignment.PSObject.Properties.Name -contains "ScopeId" -and 
                        $assignment.ScopeId -like "*managementGroups*") {
                    Write-Host "    ├─ ⏭️ $principalName with role '$roleName' is a management group assignment, skipping"
                    $isInherited = $true
                }
                # Check #3: ScopeType property
                elseif ($assignment.PSObject.Properties.Name -contains "ScopeType" -and 
                        $assignment.ScopeType -eq "managementgroup") {
                    Write-Host "    ├─ ⏭️ $principalName with role '$roleName' is assigned at management group level, skipping"
                    $isInherited = $true
                }

                if ($isInherited) {
                    $SkipCounter.Value++
                    continue
                }
                #endregion
                
                #region Remove assignment if not in config, not protected, and not inherited
                # Remove assignment
                Write-Output "    ├─ ❓ $principalName with role '$roleName' not in config, removing..."
                
                # Prepare parameters for removal
                $removeParams = @{ 
                    tenantID = $ApiInfo.TenantId
                    principalId = $principalId
                    roleName = $roleName
                    scope = $scope
                }
                
                # Skip sensitive roles
                if ($roleName -eq "User Access Administrator") {
                    Write-Warning "    │  └─ ⚠️ Skipping removal of sensitive role: User Access Administrator"
                    $SkipCounter.Value++
                    continue
                }
                
                # Remove the assignment
                if ($PSCmdlet.ShouldProcess("Remove $ResourceType assignment for $principalName with role '$roleName'")) {
                    try {
                        $result = & $Config.RemoveCmd @removeParams
                        
                        # Check for error responses in various formats
                        if ($result -is [string] -and $result -match "InsufficientPermissions|inherited|cannot delete|does not belong") {
                            Write-Warning "    │  └─ ⚠️ Cannot remove: $result"
                            $SkipCounter.Value++
                        }
                        elseif ($result -is [PSObject] -and 
                                ($result.PSObject.Properties.Name -contains "code" -or 
                                 $result.PSObject.Properties.Name -contains "error")) {
                            $errorCode = $result.code ?? $result.error.code
                            $errorMsg = $result.message ?? $result.error.message
                            
                            if ($errorCode -match "InsufficientPermissions" -or 
                                $errorMsg -match "inherited|cannot delete|does not belong") {
                                Write-Warning "    │  └─ ⚠️ Cannot remove: $errorMsg"
                                $SkipCounter.Value++
                            }
                            else {
                                Write-Error "    │  └─ ❌ Error response: $errorMsg"
                            }
                        }
                        else {
                            $RemoveCounter.Value++
                            Write-Output "    │  └─ 🗑️ Removed successfully"
                        }
                    } 
                    catch {
                        # Check for inheritance-related errors
                        if ($_.Exception.Message -match "InsufficientPermissions|inherited|cannot delete|does not belong") {
                            Write-Warning "    │  └─ ⚠️ Cannot remove: Assignment appears to be inherited or protected"
                            $SkipCounter.Value++
                        }
                        else {
                            Write-Error "    │  └─ ❌ Failed to remove: $_"
                        }
                    }
                } 
                else {
                    $SkipCounter.Value++
                    Write-Output "    │  └─ ⏭️ Removal skipped (WhatIf mode)"
                }
                #endregion
            }
        }
    }
}