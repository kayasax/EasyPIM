function Invoke-EasyPIMCleanup {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([System.Collections.Hashtable])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    param (
        [Parameter(Mandatory = $true)]
        [object]$Config,

        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $false)]
        [ValidateSet("initial", "delta")]
        [string]$Mode = "delta",

        [Parameter(Mandatory = $false)]
        [string]$WouldRemoveExportPath
    )

    # Confirm the operation with the user
    $operationTarget = "PIM assignments across Azure, Entra ID, and Groups"
    $operationDescription = "$Mode mode cleanup - process assignments according to configuration"
    # ShouldProcess preview: we still want to execute enumeration when -WhatIf is used so that WouldRemove data is produced
    $shouldProceed = $PSCmdlet.ShouldProcess($operationTarget, $operationDescription)
    if (-not $shouldProceed -and -not $WhatIfPreference) {
        Write-Output "Operation cancelled by user."
        return @{
            KeptCount = 0
            RemovedCount = 0
            SkippedCount = 0
            ProtectedCount = 0
        }
    }

    $results = @()
    Write-Verbose "[Cleanup Debug] Entering Invoke-EasyPIMCleanup (Mode=$Mode WhatIf=$WhatIfPreference TenantId=$TenantId SubscriptionId=$SubscriptionId)"
    Write-Verbose "[Cleanup Debug] Post-ShouldProcess reached - beginning per-resource evaluation"
    try {
        Write-Verbose "[Cleanup Debug] Input arrays -> AzureRoles=$($Config.AzureRoles?.Count) AzureRolesActive=$($Config.AzureRolesActive?.Count) EntraIDRoles=$($Config.EntraIDRoles?.Count) EntraIDRolesActive=$($Config.EntraIDRolesActive?.Count) GroupRoles=$($Config.GroupRoles?.Count) GroupRolesActive=$($Config.GroupRolesActive?.Count)"
    } catch { Write-Verbose "[Cleanup Debug] Failed to enumerate input counts: $($_.Exception.Message)" }

    # Diagnostic: show counts of each assignment array prior to invoking per-resource cleanup
    try {
        $azEligCount = if ($Config.AzureRoles) { $Config.AzureRoles.Count } else { 0 }
        $azActCount  = if ($Config.AzureRolesActive) { $Config.AzureRolesActive.Count } else { 0 }
        $entraEligCount = if ($Config.EntraIDRoles) { $Config.EntraIDRoles.Count } else { 0 }
        $entraActCount  = if ($Config.EntraIDRolesActive) { $Config.EntraIDRolesActive.Count } else { 0 }
        $grpEligCount = if ($Config.GroupRoles) { $Config.GroupRoles.Count } else { 0 }
        $grpActCount  = if ($Config.GroupRolesActive) { $Config.GroupRolesActive.Count } else { 0 }
        Write-Verbose "[Cleanup Debug] Assignment set counts -> AzureEligible=$azEligCount AzureActive=$azActCount EntraEligible=$entraEligCount EntraActive=$entraActCount GroupEligible=$grpEligCount GroupActive=$grpActCount WhatIf=$WhatIfPreference Mode=$Mode"
    } catch { Write-Verbose "[Cleanup Debug] Failed to compute assignment counts: $($_.Exception.Message)" }

    # Process Azure Resource roles (eligible)
    if ($Config.AzureRoles -and $Config.AzureRoles.Count -gt 0) {
        $apiInfo = @{
            TenantId = $TenantId
            SubscriptionId = $SubscriptionId
        }
        # Pass through -WhatIf explicitly so nested cleanup honors preview semantics
        $results += Invoke-Cleanup -ResourceType "Azure Role eligible" -ConfigAssignments $Config.AzureRoles -ApiInfo $apiInfo -ProtectedUsers $Config.ProtectedUsers -Mode $Mode -WhatIf:$WhatIfPreference
    } else { Write-Verbose "[Cleanup Debug] Skipping Azure Role eligible cleanup (no assignments)" }

    # Process Azure Resource roles (active)
    if ($Config.AzureRolesActive -and $Config.AzureRolesActive.Count -gt 0) {
        $apiInfo = @{
            TenantId = $TenantId
            SubscriptionId = $SubscriptionId
        }
        $results += Invoke-Cleanup -ResourceType "Azure Role active" -ConfigAssignments $Config.AzureRolesActive -ApiInfo $apiInfo -ProtectedUsers $Config.ProtectedUsers -Mode $Mode -WhatIf:$WhatIfPreference
    } else { Write-Verbose "[Cleanup Debug] Skipping Azure Role active cleanup (no assignments)" }

    # Process Entra ID roles (eligible)
    if ($Config.EntraIDRoles -and $Config.EntraIDRoles.Count -gt 0) {
        $apiInfo = @{
            TenantId = $TenantId
        }
        $results += Invoke-Cleanup -ResourceType "Entra Role eligible" -ConfigAssignments $Config.EntraIDRoles -ApiInfo $apiInfo -ProtectedUsers $Config.ProtectedUsers -Mode $Mode -WhatIf:$WhatIfPreference
    } else { Write-Verbose "[Cleanup Debug] Skipping Entra Role eligible cleanup (no assignments)" }

    # Process Entra ID roles (active)
    if ($Config.EntraIDRolesActive -and $Config.EntraIDRolesActive.Count -gt 0) {
        $apiInfo = @{
            TenantId = $TenantId
        }
        $results += Invoke-Cleanup -ResourceType "Entra Role active" -ConfigAssignments $Config.EntraIDRolesActive -ApiInfo $apiInfo -ProtectedUsers $Config.ProtectedUsers -Mode $Mode -WhatIf:$WhatIfPreference
    } else { Write-Verbose "[Cleanup Debug] Skipping Entra Role active cleanup (no assignments)" }

    # Process Group roles (eligible)
    if ($Config.GroupRoles -and $Config.GroupRoles.Count -gt 0) {
        foreach ($groupConfig in $Config.GroupRoles) {
            if ($groupConfig.GroupId) {
                $apiInfo = @{
                    TenantId = $TenantId
                    GroupIds = @($groupConfig.GroupId)
                }
                $results += Invoke-Cleanup -ResourceType "Group eligible" -ConfigAssignments $Config.GroupRoles -ApiInfo $apiInfo -ProtectedUsers $Config.ProtectedUsers -Mode $Mode -WhatIf:$WhatIfPreference
            }
        }
    } else { Write-Verbose "[Cleanup Debug] Skipping Group eligible cleanup (no assignments)" }

    # Process Group roles (active)
    if ($Config.GroupRolesActive -and $Config.GroupRolesActive.Count -gt 0) {
        foreach ($groupConfig in $Config.GroupRolesActive) {
            if ($groupConfig.GroupId) {
                $apiInfo = @{
                    TenantId = $TenantId
                    GroupIds = @($groupConfig.GroupId)
                }
                $results += Invoke-Cleanup -ResourceType "Group active" -ConfigAssignments $Config.GroupRolesActive -ApiInfo $apiInfo -ProtectedUsers $Config.ProtectedUsers -Mode $Mode -WhatIf:$WhatIfPreference
            }
        }
    } else { Write-Verbose "[Cleanup Debug] Skipping Group active cleanup (no assignments)" }

    # Aggregate results
    $totalKept = ($results | Measure-Object -Property KeptCount -Sum).Sum
    $totalRemoved = ($results | Measure-Object -Property RemovedCount -Sum).Sum
    $totalSkipped = ($results | Measure-Object -Property SkippedCount -Sum).Sum
    $totalProtected = ($results | Measure-Object -Property ProtectedCount -Sum).Sum
    # Robust summation for WouldRemove counts (some result objects may be hashtables)
    $totalWouldRemove = 0
    foreach($r in $results){
        if ($null -eq $r) { continue }
        $val = $null
        if ($r -is [hashtable]) {
            if ($r.ContainsKey('WouldRemoveCount')) { $val = $r['WouldRemoveCount'] }
        } else {
            if ($r.PSObject.Properties.Name -contains 'WouldRemoveCount') { $val = $r.WouldRemoveCount }
        }
        if ($val -and ($val -as [int]) -ge 0) { $totalWouldRemove += [int]$val }
    }
    $allWouldRemoveDetails = @()
    foreach($r in $results){ if ($r.PSObject.Properties.Name -contains 'WouldRemoveDetails' -and $r.WouldRemoveDetails){ $allWouldRemoveDetails += $r.WouldRemoveDetails } }

    # Diagnostic dump (first few results) for WouldRemove visibility (now verbose-only)
    $results | Select-Object -First 5 | ForEach-Object {
        $wr = $null
        if ($_ -is [hashtable]) { if ($_.ContainsKey('WouldRemoveCount')) { $wr = $_['WouldRemoveCount'] } }
        else { if ($_.PSObject.Properties.Name -contains 'WouldRemoveCount') { $wr = $_.WouldRemoveCount } }
        Write-Verbose "[Cleanup Debug] Result -> Type=$($_.ResourceType) Kept=$($_.KeptCount) Removed=$($_.RemovedCount) Skipped=$($_.SkippedCount) Protected=$($_.ProtectedCount) WouldRemove=$wr"
    }
    Write-Verbose "[Cleanup Debug] Aggregation complete -> resources processed=$($results.Count) Kept=$totalKept Removed=$totalRemoved Skipped=$totalSkipped Protected=$totalProtected WouldRemove=$totalWouldRemove"

    # Optional export of full WouldRemove details
    $resolvedExportPath = $null
    if ($WouldRemoveExportPath) {
        try {
            $candidate = $WouldRemoveExportPath
            # If directory supplied, build file name
            if (Test-Path -LiteralPath $candidate -PathType Container) {
                $candidate = Join-Path $candidate ("EasyPIM-WouldRemove-" + (Get-Date -Format 'yyyyMMddTHHmmss') + '.json')
            }
            $ext = [IO.Path]::GetExtension($candidate)
            if (-not $ext) { $candidate = $candidate + '.json'; $ext = '.json' }
            $ext = $ext.ToLowerInvariant()
            # Ensure parent directory exists
            $parent = Split-Path -Parent $candidate
            if (-not (Test-Path -LiteralPath $parent)) {
                New-Item -ItemType Directory -Path $parent -Force | Out-Null
            }
            # Always export, even when count is zero (write empty structure) so user has a tangible artifact
            if ($ext -eq '.csv') {
                $selection = $allWouldRemoveDetails | Select-Object PrincipalId,PrincipalName,RoleName,Scope,ResourceType,Mode
                # Export-Csv with no input still creates file with headers; if no items, fabricate blank object for headers
                if (-not $selection -or $selection.Count -eq 0) {
                    # Create an empty object so headers are persisted
                    [pscustomobject]@{PrincipalId=$null;PrincipalName=$null;RoleName=$null;Scope=$null;ResourceType=$null;Mode=$null} | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $candidate -WhatIf:$false
                } else {
                    $selection | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $candidate -WhatIf:$false
                }
            } else {
                if ($allWouldRemoveDetails.Count -gt 0) {
                    $json = $allWouldRemoveDetails | ConvertTo-Json -Depth 6
                } else {
                    $json = '[]'
                }
                Set-Content -LiteralPath $candidate -Value $json -Encoding UTF8 -WhatIf:$false
            }
            $resolvedExportPath = $candidate
            $countMsg = "$($allWouldRemoveDetails.Count) item(s)"
            Write-Host "📤 Exported WouldRemove list ($countMsg) to: $candidate" -ForegroundColor Cyan
        } catch {
            Write-Warning "Failed to export WouldRemove details: $($_.Exception.Message)"
        }
    }

    return [pscustomobject]@{
        KeptCount = $totalKept
        RemovedCount = $totalRemoved
        SkippedCount = $totalSkipped
        ProtectedCount = $totalProtected
        WouldRemoveCount = $totalWouldRemove
        WouldRemoveDetails = $allWouldRemoveDetails
        WouldRemoveExportPath = $resolvedExportPath
    }
}