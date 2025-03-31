function invoke-EntraRoleCleanup {
    param (
        [string]$ResourceType,
        [array]$ConfigAssignments,
        [hashtable]$ApiInfo,
        [hashtable]$Config,
        [array]$ProtectedUsers,
        [ref]$KeptCounter,
        [ref]$RemoveCounter,
        [ref]$SkipCounter
    )

    Write-Output "  🔍 Checking Entra roles"

    # Query MS Graph for assignments with simplified error handling
    try {
        # Get directory roles for name resolution
        $directoryRoles = (Invoke-Graph -endpoint "/directoryRoles" -Method Get).value
        $roleTemplates = (Invoke-Graph -endpoint "/directoryRoleTemplates" -Method Get).value

        # Get instances (current assignments)
        $instancesEndpoint = ($config.ApiEndpoint -replace "https://graph.microsoft.com/beta", "")
        $allInstances = (Invoke-Graph -endpoint $instancesEndpoint -Method Get).value

        Write-Output "    ├─ Found $($allInstances.Count) active instances (current assignments)"

        # Process each assignment
        if ($allInstances.Count -gt 0) {
            Write-Output "`n  📋 Analyzing assignments:"

            foreach ($assignment in $allInstances) {
                $principalId = $assignment.principalId
                $roleDefinitionId = $assignment.roleDefinitionId

                # Lookup role name from directory roles
                $roleName = "Unknown Role"
                $role = $directoryRoles | Where-Object { $_.id -eq $roleDefinitionId } | Select-Object -First 1
                if ($role) {
                    $roleName = $role.displayName
                } else {
                    $template = $roleTemplates | Where-Object { $_.id -eq $roleDefinitionId } | Select-Object -First 1
                    if ($template) { $roleName = $template.displayName }
                }

                # Get principal name
                $principalName = "Principal-$principalId"
                try {
                    $principalObj = Invoke-Graph -endpoint "/directoryObjects/$principalId" -Method Get -ErrorAction SilentlyContinue
                    if ($principalObj.displayName) { $principalName = $principalObj.displayName }
                } catch {}

                # Check if assignment matches config
                $foundInConfig = $false
                foreach ($configAssignment in $ConfigAssignments) {
                    $matchesPrincipal = $configAssignment.PrincipalId -eq $principalId
                    $matchesRole = $configAssignment.Rolename -ieq $roleName

                    if ($matchesPrincipal -and $matchesRole) {
                        $foundInConfig = $true
                        break
                    }
                }

                # Keep assignment if it's in config
                if ($foundInConfig) {
                    Write-Output "    ├─ ✅ $principalName with role '$roleName' matches config, keeping"
                    $KeptCounter.Value++
                    continue
                }

                # Check if protected user
                if ($ProtectedUsers -contains $principalId) {
                    Write-Output "    │  └─ 🛡️ Protected user! Skipping removal"
                    $SkipCounter.Value++
                    continue
                }

                # Remove assignment
                Write-Output "    ├─ ❓ $principalName with role '$roleName' not in config, removing..."

                # Prepare parameters for removal
                $removeParams = @{
                    tenantID = $ApiInfo.TenantId
                    principalId = $principalId
                    roleName = $roleName
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
                        & $Config.RemoveCmd @removeParams
                        $RemoveCounter.Value++
                        Write-Output "    │  └─ 🗑️ Removed successfully"
                    } catch {
                        Write-Error "    │  └─ ❌ Failed to remove: $_"
                    }
                } else {
                    $SkipCounter.Value++
                    Write-Output "    │  └─ ⏭️ Removal skipped (WhatIf mode)"
                }
            }
        }
    }
    catch {
        if ($_.Exception.Message -match "Permission") {
            Write-Warning "⚠️ Insufficient permissions to manage Entra role assignments."
            Write-Warning "Required permissions: RoleEligibilitySchedule.ReadWrite.Directory, RoleManagement.ReadWrite.Directory"
        }
        else {
            Write-Error "Failed to query Entra role assignments: $_"
        }
    }
}
