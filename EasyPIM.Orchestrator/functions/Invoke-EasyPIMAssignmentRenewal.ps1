<#
.SYNOPSIS
Extends Azure resource role PIM assignments (eligible and active) that are declared in an EasyPIM orchestrator
configuration and are expiring within a threshold (default 14 days).
.DESCRIPTION
Loads an EasyPIM orchestrator configuration (file or Key Vault), lists the live eligible and active Azure resource
role assignments per configured scope, keeps those that are both declared in the configuration AND expiring within
-ThresholdDays, then submits an ARM AdminExtend request for each (via Update-PIMAzureResource*Assignment). Admin
extension requires no approval, so this is safe to schedule unattended (pipeline/runbook).

The new end date is set to now + the role policy maximum assignment duration (clamped to the policy). If a role
policy allows permanent assignment but defines no maximum duration, the assignment is skipped with a note
recommending a permanent assignment instead. Assignments that exist in Azure but are not declared in the
configuration are never touched.

v1 supports Azure resource roles only. Entra directory roles and PIM-for-Groups are not yet supported.
.PARAMETER ConfigFilePath
Path to the JSON/JSONC orchestrator configuration file.
.PARAMETER KeyVaultName
Key Vault holding the configuration secret (alternative to -ConfigFilePath).
.PARAMETER SecretName
Key Vault secret name that stores the configuration.
.PARAMETER TenantId
Target tenant GUID. Falls back to $env:tenantid.
.PARAMETER SubscriptionId
Target subscription GUID. Falls back to $env:subscriptionid.
.PARAMETER ThresholdDays
Extend assignments expiring within this many days. Default 14 (matching PIM's own notification window).
.EXAMPLE
Invoke-EasyPIMAssignmentRenewal -ConfigFilePath .\pim-config-azure.jsonc -TenantId $t -SubscriptionId $s -WhatIf
Preview which declared, expiring Azure assignments would be extended.
.EXAMPLE
Invoke-EasyPIMAssignmentRenewal -ConfigFilePath .\pim-config-azure.jsonc -TenantId $t -SubscriptionId $s
Extend all declared Azure assignments expiring within 14 days.
.LINK
https://github.com/kayasax/EasyPIM
#>
function Invoke-EasyPIMAssignmentRenewal {
    [CmdletBinding(DefaultParameterSetName = 'FilePath', SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'FilePath')]
        [string]$ConfigFilePath,
        [Parameter(Mandatory = $true, ParameterSetName = 'KeyVault')]
        [string]$KeyVaultName,
        [Parameter(Mandatory = $true, ParameterSetName = 'KeyVault')]
        [string]$SecretName,
        [Parameter()][string]$TenantId,
        [Parameter()][string]$SubscriptionId,
        [Parameter()][ValidateRange(1, 365)][int]$ThresholdDays = 14
    )

    Write-SectionHeader -Message "EasyPIM Assignment Renewal (threshold: $ThresholdDays days)"

    if (-not $TenantId) { $TenantId = $env:tenantid }
    if (-not $SubscriptionId) { $SubscriptionId = $env:subscriptionid }

    $summary = [pscustomobject]@{
        FoundExpiring = 0
        Extended      = 0
        Skipped       = 0
        Details       = @()
    }

    # 1. Load + normalize config
    $config = if ($PSCmdlet.ParameterSetName -eq 'KeyVault') {
        Get-EasyPIMConfiguration -KeyVaultName $KeyVaultName -SecretName $SecretName
    } else {
        Get-EasyPIMConfiguration -ConfigFilePath $ConfigFilePath
    }
    $processed = Initialize-EasyPIMAssignments -Config $config

    # Consume the normalized flat arrays produced by Initialize-EasyPIMAssignments:
    #   $processed.AzureRoles       -> eligible Azure resource role assignments
    #   $processed.AzureRolesActive -> active Azure resource role assignments
    # Each item is a clean object exposing .RoleName, .Scope, .PrincipalId, .AssignmentType.
    $eligibleItems = @($processed.AzureRoles)
    $activeItems   = @($processed.AzureRolesActive)

    if ($eligibleItems.Count -eq 0 -and $activeItems.Count -eq 0) {
        Write-Host "No Azure role assignments declared in configuration; nothing to renew." -ForegroundColor Yellow
        return $summary
    }

    $now = (Get-Date).ToUniversalTime()
    $cutoff = $now.AddDays($ThresholdDays)

    # Per-scope live-assignment caches (avoid N+1 fetches) and per-scope|role policy cache.
    $eligibleCache = @{}
    $activeCache   = @{}
    $policyCache   = @{}

    # Iterate eligible then active items from the normalized arrays.
    $work = @()
    foreach ($item in $eligibleItems) { $work += [pscustomobject]@{ Item = $item; IsActive = $false } }
    foreach ($item in $activeItems)   { $work += [pscustomobject]@{ Item = $item; IsActive = $true  } }

    foreach ($entry in $work) {
        $item     = $entry.Item
        $isActive = $entry.IsActive

        $roleName    = $item.RoleName
        $scope       = $item.Scope
        $principalId = $item.PrincipalId
        if (-not $roleName -or -not $scope -or -not $principalId) { continue }

        # Live assignments cached once per scope (per kind)
        if ($isActive) {
            if (-not $activeCache.ContainsKey($scope)) {
                $activeCache[$scope] = @()
                try { $activeCache[$scope] = @(Get-PIMAzureResourceActiveAssignment -tenantID $TenantId -subscriptionID $SubscriptionId -scope $scope -ErrorAction SilentlyContinue) } catch { Write-Verbose "[Renewal] active fetch failed for ${scope}: $($_.Exception.Message)" }
            }
            $liveSet = $activeCache[$scope]
        } else {
            if (-not $eligibleCache.ContainsKey($scope)) {
                $eligibleCache[$scope] = @()
                try { $eligibleCache[$scope] = @(Get-PIMAzureResourceEligibleAssignment -tenantID $TenantId -subscriptionID $SubscriptionId -scope $scope -ErrorAction SilentlyContinue) } catch { Write-Verbose "[Renewal] eligible fetch failed for ${scope}: $($_.Exception.Message)" }
            }
            $liveSet = $eligibleCache[$scope]
        }

        # Policy cached once per scope|role
        $policyKey = "$scope|$roleName"
        if (-not $policyCache.ContainsKey($policyKey)) {
            $policyCache[$policyKey] = $null
            try { $policyCache[$policyKey] = Get-PIMAzureResourcePolicy -tenantID $TenantId -scope $scope -rolename $roleName } catch { Write-Verbose "[Renewal] policy fetch failed for $roleName@${scope}: $($_.Exception.Message)" }
        }
        $policy = $policyCache[$policyKey]

        # Match against live assignments of the same kind
        $match = $liveSet | Where-Object {
            $_.PrincipalId -eq $principalId -and $_.RoleName -eq $roleName -and $_.ScopeId -eq $scope
        } | Select-Object -First 1
        if (-not $match) { continue }  # declared but not currently live -> New-EasyPIMAssignments handles creation, not us

        # Skip permanent / not-expiring. The getter returns endDateTime as a [datetime]
        # (ConvertFrom-Json coerces the ISO value) for time-bound assignments, or the
        # literal string 'permanent'. Use the [datetime] directly; only string-parse as a
        # fallback, and then with InvariantCulture so a non-US session culture cannot
        # mis-read or silently drop the value.
        $edt = $match.endDateTime
        if ($null -eq $edt) { continue }
        $end = $null
        if ($edt -is [datetime]) {
            $end = ([datetime]$edt).ToUniversalTime()
        } else {
            $edtStr = [string]$edt
            if ($edtStr -eq 'permanent' -or [string]::IsNullOrWhiteSpace($edtStr)) { continue }
            $parsedEnd = [datetime]::MinValue
            if (-not [datetime]::TryParse($edtStr, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$parsedEnd)) { continue }
            $end = $parsedEnd.ToUniversalTime()
        }
        if ($end -gt $cutoff) { continue }

        $summary.FoundExpiring++
        $kind = if ($isActive) { 'Active' } else { 'Eligible' }
        $ctx = "Azure/$roleName $principalId @ $scope [$kind]"

        # Compute new end date from policy max
        $maxDurationIso = if ($isActive) { $policy.MaximumActiveAssignmentDuration } else { $policy.MaximumEligibleAssignmentDuration }
        $allowPermanent = if ($isActive) { $policy.AllowPermanentActiveAssignment } else { $policy.AllowPermanentEligibleAssignment }

        if ([string]::IsNullOrWhiteSpace($maxDurationIso)) {
            $reason = if ("$allowPermanent" -eq 'true') { "policy allows permanent (no max duration) - consider a permanent assignment to remove the need to extend" } else { "no maximum duration in policy" }
            Write-Host "  SKIP  $ctx : $reason" -ForegroundColor Yellow
            $summary.Skipped++
            $summary.Details += [pscustomobject]@{ Context = $ctx; Action = 'Skipped'; Reason = $reason }
            continue
        }

        $maxTs = $null
        try { $maxTs = [System.Xml.XmlConvert]::ToTimeSpan($maxDurationIso) } catch { }
        if ($null -eq $maxTs) {
            Write-Host "  SKIP  $ctx : could not parse policy max duration '$maxDurationIso'" -ForegroundColor Yellow
            $summary.Skipped++
            $summary.Details += [pscustomobject]@{ Context = $ctx; Action = 'Skipped'; Reason = "unparsable max duration '$maxDurationIso'" }
            continue
        }
        $newEnd = ($now.Add($maxTs)).ToString("yyyy-MM-ddTHH:mm:ssZ")
        if ("$allowPermanent" -eq 'true') {
            Write-Host "  NOTE  $ctx : policy allows permanent; extending to policy max ($maxDurationIso). A permanent assignment would remove the need to extend." -ForegroundColor DarkCyan
        }

        if ($WhatIfPreference) {
            Write-Host "  What if: Extend $ctx to $newEnd" -ForegroundColor Cyan
            $summary.Details += [pscustomobject]@{ Context = $ctx; Action = 'PlannedExtend'; NewEnd = $newEnd }
            continue
        }

        $params = @{
            tenantID       = $TenantId
            subscriptionID = $SubscriptionId
            scope          = $scope
            rolename       = $roleName
            principalID    = $principalId
            newEndDateTime = $newEnd
        }
        try {
            if ($isActive) { Update-PIMAzureResourceActiveAssignment @params }
            else           { Update-PIMAzureResourceEligibleAssignment @params }
            Write-Host "  EXTENDED  $ctx -> $newEnd" -ForegroundColor Green
            $summary.Extended++
            $summary.Details += [pscustomobject]@{ Context = $ctx; Action = 'Extended'; NewEnd = $newEnd }
        } catch {
            Write-Host "  FAILED  $ctx : $($_.Exception.Message)" -ForegroundColor Red
            $summary.Skipped++
            $summary.Details += [pscustomobject]@{ Context = $ctx; Action = 'Failed'; Reason = $_.Exception.Message }
        }
    }

    Write-Host ""
    Write-Host "Renewal summary: FoundExpiring=$($summary.FoundExpiring) Extended=$($summary.Extended) Skipped=$($summary.Skipped)" -ForegroundColor Cyan
    return $summary
}
