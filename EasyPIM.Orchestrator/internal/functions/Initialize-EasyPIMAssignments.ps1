function Initialize-EasyPIMAssignments {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [object]$Config
    )

    Write-Verbose "[Initialize-EasyPIMAssignments] Processing assignment configuration"

    # Start with a clean copy of the config
    $result = $Config | ConvertTo-Json -Depth 100 | ConvertFrom-Json

    # Initialize legacy assignment arrays with proper ArrayList objects to support Add() operations
    foreach ($name in 'AzureRoles','AzureRolesActive','EntraIDRoles','EntraIDRolesActive','GroupRoles','GroupRolesActive','ProtectedUsers') {
        if (-not $result.PSObject.Properties[$name]) {
            $result | Add-Member -MemberType NoteProperty -Name $name -Value ([System.Collections.ArrayList]@())
        } elseif ($null -eq $result.$name) {
            $result.$name = [System.Collections.ArrayList]@()
        } else {
            # Convert existing array to ArrayList if needed
            $result.$name = [System.Collections.ArrayList]@($result.$name)
        }
    }

    # Process Assignments section if it exists
    if ($result.PSObject.Properties['Assignments'] -and $result.Assignments) {

        # Process Entra Role Assignments
        if ($result.Assignments.PSObject.Properties['EntraRoles'] -and $result.Assignments.EntraRoles) {
            Write-Verbose "[Initialize-EasyPIMAssignments] Processing $($result.Assignments.EntraRoles.Count) Entra role assignment groups"
            foreach ($roleGroup in $result.Assignments.EntraRoles) {
                $roleName = $roleGroup.roleName
                if ($roleGroup.assignments) {
                    foreach ($assignment in $roleGroup.assignments) {
                        $assignmentObj = [PSCustomObject]@{
                            RoleName = $roleName
                            PrincipalId = $assignment.principalId
                            PrincipalType = if ($assignment.principalType) { $assignment.principalType } else { "User" }
                            AssignmentType = $assignment.assignmentType
                            Justification = $assignment.justification
                            Permanent = if ($assignment.PSObject.Properties['permanent']) { $assignment.permanent } else { $false }
                        }

                        # Add duration if specified
                        if ($assignment.PSObject.Properties['duration'] -and $assignment.duration) {
                            $assignmentObj | Add-Member -MemberType NoteProperty -Name 'Duration' -Value $assignment.duration
                        }

                        # Split by assignment type
                        if ($assignment.assignmentType -eq "Active") {
                            $null = $result.EntraIDRolesActive.Add($assignmentObj)
                        } else {
                            # Default to Eligible
                            $null = $result.EntraIDRoles.Add($assignmentObj)
                        }
                    }
                }
            }
        }

        # Process Azure Role Assignments
        if ($result.Assignments.PSObject.Properties['AzureRoles'] -and $result.Assignments.AzureRoles) {
            Write-Verbose "[Initialize-EasyPIMAssignments] Processing $($result.Assignments.AzureRoles.Count) Azure role assignment groups"
            foreach ($roleGroup in $result.Assignments.AzureRoles) {
                $roleName = $roleGroup.roleName
                $scope = $roleGroup.scope
                if ($roleGroup.assignments) {
                    foreach ($assignment in $roleGroup.assignments) {
                        $assignmentObj = [PSCustomObject]@{
                            RoleName = $roleName
                            Scope = $scope
                            PrincipalId = $assignment.principalId
                            PrincipalType = if ($assignment.principalType) { $assignment.principalType } else { "User" }
                            AssignmentType = $assignment.assignmentType
                            Justification = $assignment.justification
                            Permanent = if ($assignment.PSObject.Properties['permanent']) { $assignment.permanent } else { $false }
                        }

                        # Add duration if specified
                        if ($assignment.PSObject.Properties['duration'] -and $assignment.duration) {
                            $assignmentObj | Add-Member -MemberType NoteProperty -Name 'Duration' -Value $assignment.duration
                        }

                        # Split by assignment type
                        if ($assignment.assignmentType -eq "Active") {
                            $null = $result.AzureRolesActive.Add($assignmentObj)
                        } else {
                            # Default to Eligible
                            $null = $result.AzureRoles.Add($assignmentObj)
                        }
                    }
                }
            }
        }

        # Process Group Role Assignments
        if ($result.Assignments.PSObject.Properties['GroupRoles'] -and $result.Assignments.GroupRoles) {
            Write-Verbose "[Initialize-EasyPIMAssignments] Processing $($result.Assignments.GroupRoles.Count) Group role assignment groups"
            foreach ($roleGroup in $result.Assignments.GroupRoles) {
                $groupId = $roleGroup.groupId
                $roleName = if ($roleGroup.roleName) { $roleGroup.roleName } else { "Member" }
                if ($roleGroup.assignments) {
                    foreach ($assignment in $roleGroup.assignments) {
                        $assignmentObj = [PSCustomObject]@{
                            GroupId = $groupId
                            RoleName = $roleName
                            PrincipalId = $assignment.principalId
                            PrincipalType = if ($assignment.principalType) { $assignment.principalType } else { "User" }
                            AssignmentType = $assignment.assignmentType
                            Justification = $assignment.justification
                            Permanent = if ($assignment.PSObject.Properties['permanent']) { $assignment.permanent } else { $false }
                        }

                        # Add duration if specified
                        if ($assignment.PSObject.Properties['duration'] -and $assignment.duration) {
                            $assignmentObj | Add-Member -MemberType NoteProperty -Name 'Duration' -Value $assignment.duration
                        }

                        # Split by assignment type
                        if ($assignment.assignmentType -eq "Active") {
                            $null = $result.GroupRolesActive.Add($assignmentObj)
                        } else {
                            # Default to Eligible
                            $null = $result.GroupRoles.Add($assignmentObj)
                        }
                    }
                }
            }
        }
    }

    Write-Verbose "[Initialize-EasyPIMAssignments] Processed assignments -> Azure(E:$($result.AzureRoles.Count) A:$($result.AzureRolesActive.Count)) Entra(E:$($result.EntraIDRoles.Count) A:$($result.EntraIDRolesActive.Count)) Groups(E:$($result.GroupRoles.Count) A:$($result.GroupRolesActive.Count))"

    return $result
}
