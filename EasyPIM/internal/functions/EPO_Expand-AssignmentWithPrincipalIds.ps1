function Expand-AssignmentWithPrincipalIds {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
    param (
        [array]$Assignments
    )

    $expandedAssignments = @()

    foreach ($assignment in $Assignments) {
        # If using PrincipalIds array, expand to individual assignments
        if ($assignment.PrincipalIds) {
            foreach ($principalId in $assignment.PrincipalIds) {
                $newAssignment = $assignment.PSObject.Copy()
                $newAssignment.PSObject.Properties.Remove('PrincipalIds')
                $newAssignment | Add-Member -MemberType NoteProperty -Name "PrincipalId" -Value $principalId
                $expandedAssignments += $newAssignment
            }
        }
        # If using regular PrincipalId, add as-is
        elseif ($assignment.PrincipalId) {
            $expandedAssignments += $assignment
        }
        # No principal defined - log error
        else {
            Write-Warning "Assignment missing both PrincipalId and PrincipalIds properties: $($assignment | ConvertTo-Json -Compress)"
        }
    }

    return $expandedAssignments
}
