#Requires -Version 5.1

function Set-EPOEntraRolePolicy {
    <#
    .SYNOPSIS
    Build and apply an Entra role policy from a definition object (orchestrator-private).
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$PolicyDefinition,
        [Parameter(Mandatory = $true)]
        [string]$TenantId,
        [Parameter(Mandatory = $true)]
        [string]$Mode
    )

    Write-Verbose "[Orchestrator] Applying Entra role policy for $($PolicyDefinition.RoleName)"

    $protectedRoles = @("Global Administrator","Privileged Role Administrator","Security Administrator","User Access Administrator")
    if ($protectedRoles -contains $PolicyDefinition.RoleName) {
        Write-Warning "[WARNING] PROTECTED ROLE: '$($PolicyDefinition.RoleName)' is a critical role. Policy changes are blocked for security."
        Write-Host "[PROTECTED] Protected role '$($PolicyDefinition.RoleName)' - policy change blocked" -ForegroundColor Yellow
        return @{ RoleName = $PolicyDefinition.RoleName; Status = "Protected (No Changes)"; Mode = $Mode; Details = "Role is protected from policy changes for security reasons" }
    }

    # Validate approvers before calling public API to avoid InvalidPolicy
    $resolved = $PolicyDefinition.ResolvedPolicy; if (-not $resolved) { $resolved = $PolicyDefinition }
    try {
        if ($resolved.PSObject.Properties['Approvers'] -and $resolved.Approvers) {
            $missing = @()
            foreach ($ap in @($resolved.Approvers)) {
                $apId = $null
                if ($ap -is [string]) { $apId = $ap } else { $apId = $ap.Id; if (-not $apId) { $apId = $ap.id } }
                if ($apId -and -not (Test-PrincipalExists -PrincipalId $apId)) { $missing += $apId }
            }
            if ($missing.Count -gt 0) { throw "Approver principal(s) not found: $($missing -join ', ')" }
        }
    } catch { throw $_ }

    # Build param map for Set-PIMEntraRolePolicy
    $params = @{ tenantID = $TenantId; rolename = @($PolicyDefinition.RoleName) }
    if ($resolved.PSObject.Properties['ActivationDuration'] -and $resolved.ActivationDuration) { $params.ActivationDuration = $resolved.ActivationDuration }
    if ($resolved.PSObject.Properties['ActivationRequirement']) {
        $ar = $resolved.ActivationRequirement
        if ($ar -is [string]) { if ($ar -match ',') { $ar = ($ar -split ',') | ForEach-Object { $_.ToString().Trim() } } else { $ar = @($ar) } }
        elseif (-not ($ar -is [System.Collections.IEnumerable])) { $ar = @($ar) }
        $params.ActivationRequirement = $ar
    }
    if ($resolved.PSObject.Properties['ActiveAssignmentRequirement']) { $params.ActiveAssignmentRequirement = $resolved.ActiveAssignmentRequirement }
    if ($resolved.PSObject.Properties['AuthenticationContext_Enabled']) { $params.AuthenticationContext_Enabled = $resolved.AuthenticationContext_Enabled }
    if ($resolved.PSObject.Properties['AuthenticationContext_Value']) { $params.AuthenticationContext_Value = $resolved.AuthenticationContext_Value }
    if ($resolved.PSObject.Properties['ApprovalRequired']) { $params.ApprovalRequired = $resolved.ApprovalRequired }
    # Only pass Approvers if approval is actually required to avoid generating empty approval rules
    if ($resolved.PSObject.Properties['Approvers'] -and $resolved.ApprovalRequired -ne $false) { $params.Approvers = $resolved.Approvers }
    if ($resolved.PSObject.Properties['MaximumEligibilityDuration'] -and $resolved.MaximumEligibilityDuration) { $params.MaximumEligibilityDuration = $resolved.MaximumEligibilityDuration }
    if ($resolved.PSObject.Properties['AllowPermanentEligibility']) { $params.AllowPermanentEligibility = $resolved.AllowPermanentEligibility }
    # PT0S prevention: Only set MaximumActiveAssignmentDuration if it has a non-empty value to prevent PT0S conversion
    if ($resolved.PSObject.Properties['MaximumActiveAssignmentDuration'] -and $resolved.MaximumActiveAssignmentDuration) {
        # Additional validation to ensure value is not PT0S and meets minimum requirement
        $duration = [string]$resolved.MaximumActiveAssignmentDuration
        if ($duration -ne "PT0S" -and $duration -ne "PT0M" -and $duration -ne "PT0H" -and $duration -ne "P0D") {
            $params.MaximumActiveAssignmentDuration = $resolved.MaximumActiveAssignmentDuration
        } else {
            Write-Warning "[PT0S Prevention] Skipping MaximumActiveAssignmentDuration '$duration' for role '$($PolicyDefinition.RoleName)' - zero duration values are not allowed"
        }
    }
    if ($resolved.PSObject.Properties['AllowPermanentActiveAssignment']) { $params.AllowPermanentActiveAssignment = $resolved.AllowPermanentActiveAssignment }
    foreach ($n in $resolved.PSObject.Properties | Where-Object { $_.Name -like 'Notification_*' }) { $params[$n.Name] = $n.Value }

    $status = 'Applied'
    if ($PSCmdlet.ShouldProcess("Entra role policy for $($PolicyDefinition.RoleName)", "Apply via Set-PIMEntraRolePolicy")) {
        if (Get-Command -Name Set-PIMEntraRolePolicy -ErrorAction SilentlyContinue) {
            try { Set-PIMEntraRolePolicy @params -Verbose:$VerbosePreference | Out-Null }
            catch { Write-Warning "Set-PIMEntraRolePolicy failed: $($_.Exception.Message)"; $status='Failed' }
        } else { Write-Warning 'Set-PIMEntraRolePolicy cmdlet not found.'; $status='CmdletMissing' }
    } else { $status='Skipped' }

    return @{ RoleName=$PolicyDefinition.RoleName; Status=$status; Mode=$Mode }
}
