function Initialize-EasyPIMAssignments {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config
    )

    # Generate standard justification
    $justification = Get-EasyPIMJustification -IncludeTimestamp

    # Initialize the processed config
    $processedConfig = [PSCustomObject]@{
        AzureRoles = @()
        AzureRolesActive = @()
        EntraIDRoles = @()
        EntraIDRolesActive = @()
        GroupRoles = @()
        GroupRolesActive = @()
        ProtectedUsers = @()
        Justification = $justification  # Store for reference
    }

    # Process assignments - support both original format and new Assignments block format

    # Check for new Assignments block structure first
    if ($Config.PSObject.Properties['Assignments'] -and $Config.Assignments) {
        Write-Verbose "📋 Processing new Assignments block structure"

        # Process Assignments.AzureRoles (eligible assignments)
        if ($Config.Assignments.PSObject.Properties['AzureRoles'] -and $Config.Assignments.AzureRoles) {
            $expandedAzureRoles = @()
            $expandedAzureRolesActive = @()
            foreach ($roleAssignment in $Config.Assignments.AzureRoles) {
                foreach ($assignment in $roleAssignment.assignments) {
                    # Convert new format to old format for compatibility
                    $expandedAssignment = [PSCustomObject]@{
                        RoleName = $roleAssignment.roleName
                        Scope = $roleAssignment.scope
                        PrincipalId = if ($assignment.principalId) { $assignment.principalId } else { $assignment.principalName }
                        PrincipalName = $assignment.principalName  # Keep for backward compatibility
                        PrincipalType = $assignment.principalType
                        AssignmentType = $assignment.assignmentType
                        Duration = $assignment.duration
                        Permanent = $assignment.permanent
                        Justification = if ($assignment.justification) { $assignment.justification } else { $justification }
                    }

                    # Handle active vs eligible assignments
                    if ($assignment.assignmentType -eq "Active") {
                        $expandedAzureRolesActive += $expandedAssignment
                    } else {
                        $expandedAzureRoles += $expandedAssignment
                    }
                }
            }
            # For new Assignments structure, assignments are already individual - no need to expand with PrincipalIds
            $processedConfig.AzureRoles = $expandedAzureRoles
            if ($expandedAzureRolesActive.Count -gt 0) {
                $processedConfig.AzureRolesActive = $expandedAzureRolesActive
            }
            Write-Verbose "🔄 Expanded $($Config.Assignments.AzureRoles.Count) Azure role configs from Assignments block into $($processedConfig.AzureRoles.Count) eligible and $($processedConfig.AzureRolesActive.Count) active assignments"
        }

        # Process Assignments.EntraRoles (eligible assignments)
        if ($Config.Assignments.PSObject.Properties['EntraRoles'] -and $Config.Assignments.EntraRoles) {
            $expandedEntraRoles = @()
            $expandedEntraRolesActive = @()
            foreach ($roleAssignment in $Config.Assignments.EntraRoles) {
                foreach ($assignment in $roleAssignment.assignments) {
                    # Convert new format to old format for compatibility
                    $expandedAssignment = [PSCustomObject]@{
                        RoleName = $roleAssignment.roleName
                        PrincipalId = if ($assignment.principalId) { $assignment.principalId } else { $assignment.principalName }
                        PrincipalName = $assignment.principalName  # Keep for backward compatibility
                        PrincipalType = $assignment.principalType
                        AssignmentType = $assignment.assignmentType
                        Duration = $assignment.duration
                        Permanent = $assignment.permanent
                        Justification = if ($assignment.justification) { $assignment.justification } else { $justification }
                    }

                    # Handle active vs eligible assignments
                    if ($assignment.assignmentType -eq "Active") {
                        $expandedEntraRolesActive += $expandedAssignment
                    } else {
                        $expandedEntraRoles += $expandedAssignment
                    }
                }
            }
            # For new Assignments structure, assignments are already individual - no need to expand with PrincipalIds
            $processedConfig.EntraIDRoles = $expandedEntraRoles
            if ($expandedEntraRolesActive.Count -gt 0) {
                $processedConfig.EntraIDRolesActive = $expandedEntraRolesActive
            }
            Write-Verbose "🔄 Expanded $($Config.Assignments.EntraRoles.Count) Entra role configs from Assignments block into $($processedConfig.EntraIDRoles.Count) eligible and $($processedConfig.EntraIDRolesActive.Count) active assignments"
        }

        # Process Assignments.GroupRoles (preferred) OR Assignments.Groups (alias) if present
        $groupAssignmentsBlock = $null
        if ($Config.Assignments.PSObject.Properties['GroupRoles'] -and $Config.Assignments.GroupRoles) {
            $groupAssignmentsBlock = $Config.Assignments.GroupRoles
        } elseif ($Config.Assignments.PSObject.Properties['Groups'] -and $Config.Assignments.Groups) {
            Write-Verbose "⚙️ Using Assignments.Groups (alias) for group role assignments"
            $groupAssignmentsBlock = $Config.Assignments.Groups
        }

        if ($groupAssignmentsBlock) {
            $expandedGroupRoles = @()
            $expandedGroupRolesActive = @()
            foreach ($roleAssignment in $groupAssignmentsBlock) {
                foreach ($assignment in $roleAssignment.assignments) {
                    # Convert new format to old format for compatibility
                    $expandedAssignment = [PSCustomObject]@{
                        GroupId = $roleAssignment.groupId
                        GroupName = $roleAssignment.groupName
                        RoleName = $roleAssignment.roleName
                        PrincipalId = if ($assignment.principalId) { $assignment.principalId } else { $assignment.principalName }
                        PrincipalName = $assignment.principalName  # Keep for backward compatibility
                        PrincipalType = $assignment.principalType
                        AssignmentType = $assignment.assignmentType
                        Duration = $assignment.duration
                        Permanent = $assignment.permanent
                        Justification = if ($assignment.justification) { $assignment.justification } else { $justification }
                    }

                    # Handle active vs eligible assignments
                    if ($assignment.assignmentType -eq "Active") {
                        $expandedGroupRolesActive += $expandedAssignment
                    } else {
                        $expandedGroupRoles += $expandedAssignment
                    }
                }
            }
            # For new Assignments structure, assignments are already individual - no need to expand with PrincipalIds
            $processedConfig.GroupRoles = $expandedGroupRoles
            if ($expandedGroupRolesActive.Count -gt 0) {
                $processedConfig.GroupRolesActive = $expandedGroupRolesActive
            }
            $grpCount = $groupAssignmentsBlock.Count
            Write-Verbose "🔄 Expanded $grpCount group role configs from Assignments block into $($processedConfig.GroupRoles.Count) eligible and $($processedConfig.GroupRolesActive.Count) active assignments"
        }
    }

    # Fall back to original format if no Assignments block found
    else {
        Write-Verbose "📋 Processing original configuration format"

        # Expand all assignments with PrincipalIds arrays
        if ($Config.AzureRoles) {
            $processedConfig.AzureRoles = Expand-AssignmentWithPrincipalIds -Assignments $Config.AzureRoles
            Write-Verbose "Expanded $($Config.AzureRoles.Count) Azure role configs into $($processedConfig.AzureRoles.Count) individual assignments"
        }

        if ($Config.AzureRolesActive) {
            $processedConfig.AzureRolesActive = Expand-AssignmentWithPrincipalIds -Assignments $Config.AzureRolesActive

            # Ensure RoleName is consistent (some use Role instead)
            $processedConfig.AzureRolesActive = $processedConfig.AzureRolesActive | ForEach-Object {
                if (!$_.Rolename -and $_.Role) {
                    $_ | Add-Member -NotePropertyName "Rolename" -NotePropertyValue $_.Role -Force -PassThru
                } else {
                    $_
                }
            }
        }

        if ($Config.EntraIDRoles) {
            $processedConfig.EntraIDRoles = Expand-AssignmentWithPrincipalIds -Assignments $Config.EntraIDRoles
        }

        if ($Config.EntraIDRolesActive) {
            $processedConfig.EntraIDRolesActive = Expand-AssignmentWithPrincipalIds -Assignments $Config.EntraIDRolesActive
        }

        if ($Config.GroupRoles) {
            $processedConfig.GroupRoles = Expand-AssignmentWithPrincipalIds -Assignments $Config.GroupRoles
        }

        if ($Config.GroupRolesActive) {
            $processedConfig.GroupRolesActive = Expand-AssignmentWithPrincipalIds -Assignments $Config.GroupRolesActive
        }
    }

    # Copy protected users
    if ($Config.ProtectedUsers) {
        $processedConfig.ProtectedUsers = $Config.ProtectedUsers
    }

    return $processedConfig
}