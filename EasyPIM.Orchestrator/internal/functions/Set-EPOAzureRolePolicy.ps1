#Requires -Version 5.1

function Set-EPOAzureRolePolicy {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$PolicyDefinition,
        [Parameter(Mandatory = $true)]
        [string]$TenantId,
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,
        [Parameter(Mandatory = $true)]
        [string]$Mode,
        [Parameter(Mandatory = $false)]
        [switch]$AllowProtectedRoles
    )

    # Delegate to the Core internal builder via public Set-PIMAzureResourcePolicy when possible, preserving behavior
    Write-Verbose "[Orchestrator] Applying Azure role policy for $($PolicyDefinition.RoleName) at $($PolicyDefinition.Scope)"

    $protectedAzureRoles = @("Owner","User Access Administrator")
    if ($protectedAzureRoles -contains $PolicyDefinition.RoleName) {
        if (-not $AllowProtectedRoles) {
            Write-Warning "[WARNING] PROTECTED AZURE ROLE: '$($PolicyDefinition.RoleName)' is a critical role. Policy changes are blocked for security."
            Write-Host "[PROTECTED] Protected Azure role '$($PolicyDefinition.RoleName)' - policy change blocked (use -AllowProtectedRoles to override)" -ForegroundColor Yellow
            return @{ RoleName = $PolicyDefinition.RoleName; Scope = $PolicyDefinition.Scope; Status = "Protected (No Changes)"; Mode = $Mode; Details = "Azure role is protected from policy changes for security reasons. Use -AllowProtectedRoles to override." }
        } else {
            Write-Warning "[SECURITY] OVERRIDE: Allowing policy changes to protected Azure role '$($PolicyDefinition.RoleName)'. This action will be logged for audit purposes."
            Write-Host "[SECURITY] PROTECTED ROLE OVERRIDE: Proceeding with policy changes to '$($PolicyDefinition.RoleName)' as requested" -ForegroundColor Red

            # Enhanced audit logging for protected role modifications
            $auditInfo = @{
                Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffK"
                Action = "ProtectedRoleOverride"
                RoleType = "Azure"
                RoleName = $PolicyDefinition.RoleName
                Scope = $PolicyDefinition.Scope
                TenantId = $TenantId
                SubscriptionId = $SubscriptionId
                User = $env:USERNAME
                Context = $env:USERDOMAIN
                Mode = $Mode
                PolicyChanges = $PolicyDefinition | ConvertTo-Json -Depth 5 -Compress
            }
            Write-Verbose "[AUDIT] Protected role override: $($auditInfo | ConvertTo-Json -Depth 3 -Compress)"
            try {
                Write-EventLog -LogName "Application" -Source "EasyPIM" -EventId 4001 -EntryType Warning -Message "Protected Azure role policy override: $($PolicyDefinition.RoleName) by $($env:USERNAME)" -ErrorAction SilentlyContinue
            } catch {
                Write-Verbose "[AUDIT] Could not write to Windows Event Log: $($_.Exception.Message)"
            }
        }
    }

    # Build parameter map for Set-PIMAzureResourcePolicy (Core public API)
    $params = @{
        tenantID = $TenantId
        subscriptionID = $SubscriptionId
        rolename = @($PolicyDefinition.RoleName)
    }
    $resolved = $PolicyDefinition.ResolvedPolicy; if (-not $resolved) { $resolved = $PolicyDefinition }
    # Map fields that the public cmdlet supports
    if ($resolved.PSObject.Properties['ActivationDuration'] -and $resolved.ActivationDuration) { $params.ActivationDuration = $resolved.ActivationDuration }
    if ($resolved.PSObject.Properties['ActivationRequirement']) {
        $ar = $resolved.ActivationRequirement
        if ($ar -is [string]) { if ($ar -match ',') { $ar = ($ar -split ',') | ForEach-Object { $_.ToString().Trim() } } else { $ar = @($ar) } }
        elseif (-not ($ar -is [System.Collections.IEnumerable])) { $ar = @($ar) }
        $params.ActivationRequirement = $ar
    }
    if ($resolved.PSObject.Properties['ActiveAssignmentRequirement']) { $params.ActiveAssignationRequirement = $resolved.ActiveAssignmentRequirement }
    if ($resolved.PSObject.Properties['AuthenticationContext_Enabled']) { $params.AuthenticationContext_Enabled = $resolved.AuthenticationContext_Enabled }
    if ($resolved.PSObject.Properties['AuthenticationContext_Value']) { $params.AuthenticationContext_Value = $resolved.AuthenticationContext_Value }
    if ($resolved.PSObject.Properties['ApprovalRequired']) { $params.ApprovalRequired = $resolved.ApprovalRequired }
    if ($resolved.PSObject.Properties['Approvers']) { $params.Approvers = $resolved.Approvers }
    if ($resolved.PSObject.Properties['MaximumEligibilityDuration'] -and $resolved.MaximumEligibilityDuration) { $params.MaximumEligibilityDuration = $resolved.MaximumEligibilityDuration }
    if ($resolved.PSObject.Properties['AllowPermanentEligibility']) { $params.AllowPermanentEligibility = $resolved.AllowPermanentEligibility }
    # PT0S prevention: Only set MaximumActiveAssignmentDuration if it has a non-empty value to prevent PT0S conversion
    if ($resolved.PSObject.Properties['MaximumActiveAssignmentDuration'] -and $resolved.MaximumActiveAssignmentDuration) {
        # Additional validation to ensure value is not PT0S and meets minimum requirement
        $duration = [string]$resolved.MaximumActiveAssignmentDuration
        if ($duration -ne "PT0S" -and $duration -ne "PT0M" -and $duration -ne "PT0H" -and $duration -ne "P0D") {
            $params.MaximumActiveAssignmentDuration = $resolved.MaximumActiveAssignmentDuration
        } else {
            Write-Warning "[PT0S Prevention] Skipping MaximumActiveAssignmentDuration '$duration' for Azure role '$($PolicyDefinition.RoleName)' - zero duration values are not allowed"
        }
    }
    if ($resolved.PSObject.Properties['AllowPermanentActiveAssignment']) { $params.AllowPermanentActiveAssignment = $resolved.AllowPermanentActiveAssignment }
    foreach ($n in $resolved.PSObject.Properties | Where-Object { $_.Name -like 'Notification_*' }) { $params[$n.Name] = $n.Value }

    $status = 'Applied'
    if ($PSCmdlet.ShouldProcess("Azure role policy for $($PolicyDefinition.RoleName)", "Apply via Set-PIMAzureResourcePolicy")) {
        if (Get-Command -Name Set-PIMAzureResourcePolicy -ErrorAction SilentlyContinue) {
            try { Set-PIMAzureResourcePolicy @params -Verbose:$VerbosePreference | Out-Null }
            catch { Write-Warning "Set-PIMAzureResourcePolicy failed: $($_.Exception.Message)"; $status='Failed' }
        } else { Write-Warning 'Set-PIMAzureResourcePolicy cmdlet not found.'; $status='CmdletMissing' }
    } else { $status='Skipped' }

    return @{ RoleName=$PolicyDefinition.RoleName; Scope=$PolicyDefinition.Scope; Status=$status; Mode=$Mode }
}
