function Test-PIMPolicyDrift {
<#+
.SYNOPSIS
Tests (verifies) PIM policy settings against an expected configuration file and reports drift.

.DESCRIPTION
Parses a policy configuration JSON (supports // and /* */ comments plus PolicyTemplates) and compares key fields of Azure Resource Role, Entra Role, and Group Role PIM policies with live values in the target tenant (and subscription for Azure roles).
Returns structured drift result objects and optionally fails (non-zero exit code when used in a script) if drift or retrieval errors are present. Designed for reuse by Verify-PIMPolicies.ps1 and test harness.

.PARAMETER TenantId
Entra tenant (Directory) ID to query.

.PARAMETER ConfigPath
Path to policy configuration JSON file. Comments allowed.

.PARAMETER SubscriptionId
Azure subscription Id. If omitted, Azure role policies in config are skipped with warning.

.PARAMETER FailOnDrift
When supplied, function throws terminating error if drift or errors found.

.PARAMETER PassThru
Return the list of result objects instead of (or in addition to) formatted table output. (Objects always returned; PassThru suppresses formatting.)

.OUTPUTS
PSCustomObject with properties: Type, Name, Target, Status (Match|Drift|Error|SkippedRoleNotFound), Differences.

.EXAMPLE
Test-PIMPolicyDrift -TenantId $tid -SubscriptionId $sub -ConfigPath .\policy.json -FailOnDrift -PassThru

.NOTES
Key compared fields: ActivationDuration, ActivationRequirement, ApprovalRequired, MaximumEligibilityDuration, AllowPermanentEligibility, MaximumActiveAssignmentDuration, AllowPermanentActiveAssignment.
Approver count drift is also flagged when ApprovalRequired=true.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$TenantId,
        [Parameter(Mandatory)][string]$ConfigPath,
        [string]$SubscriptionId,
        [switch]$FailOnDrift,
        [switch]$PassThru
    )

    Write-Verbose "Starting PIM policy drift test for config: $ConfigPath"

    try { $ConfigPath = (Resolve-Path -Path $ConfigPath -ErrorAction Stop).Path } catch { throw "Config file not found: $ConfigPath" }

    function Remove-JsonComments {
        param([string]$Content)
        $noBlock    = [regex]::Replace($Content,'(?s)/\*.*?\*/','')
        $noFullLine = [regex]::Replace($noBlock,'(?m)^[ \t]*//.*?$','')
        $sb = New-Object System.Text.StringBuilder
        foreach ($line in $noFullLine -split "`n") {
            $inString = $false; $escaped=$false; $out = New-Object System.Text.StringBuilder
            for ($i=0; $i -lt $line.Length; $i++) {
                $ch = $line[$i]
                if ($escaped) { [void]$out.Append($ch); $escaped=$false; continue }
                if ($ch -eq '\\') { $escaped=$true; [void]$out.Append($ch); continue }
                if ($ch -eq '"') { $inString = -not $inString; [void]$out.Append($ch); continue }
                if (-not $inString -and $ch -eq '/' -and $i+1 -lt $line.Length -and $line[$i+1] -eq '/') { break }
                [void]$out.Append($ch)
            }
            [void]$sb.AppendLine(($out.ToString()))
        }
        return $sb.ToString()
    }

    $configRaw = Get-Content -Raw -Path $ConfigPath
    try {
        $clean = Remove-JsonComments -Content $configRaw
        $json  = $clean | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Verbose "Raw first 200: $($configRaw.Substring(0,[Math]::Min(200,$configRaw.Length)))"
        throw "Failed to parse config: $($_.Exception.Message)"
    }
    if (-not $json) { throw "Parsed JSON object is null - invalid configuration." }

    function Get-ResolvedPolicyObject { param($p); if ($p.PSObject.Properties['ResolvedPolicy'] -and $p.ResolvedPolicy) { return $p.ResolvedPolicy }; return $p }

    $expectedAzure=@(); $expectedEntra=@(); $expectedGroup=@(); $templates=@{}
    if ($json.PSObject.Properties['PolicyTemplates']) {
        foreach ($t in ($json.PolicyTemplates | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name)) { $templates[$t] = $json.PolicyTemplates.$t }
    }
    function Resolve-Template { param($obj) if (-not $obj) { return $obj }; if ($obj.Template -and $templates.ContainsKey($obj.Template)) { $base = $templates[$obj.Template] | ConvertTo-Json -Depth 20 | ConvertFrom-Json; foreach ($p in $obj.PSObject.Properties) { $base | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value -Force }; return $base }; return $obj }

    if ($json.PSObject.Properties['AzureRolePolicies']) { $expectedAzure += $json.AzureRolePolicies }
    if ($json.PSObject.Properties['EntraRolePolicies']) { $expectedEntra += $json.EntraRolePolicies }
    if ($json.PSObject.Properties['GroupPolicies']) { $expectedGroup += $json.GroupPolicies }

    if ($json.PSObject.Properties['AzureRoles'] -and $json.AzureRoles.PSObject.Properties['Policies']) {
        foreach ($prop in $json.AzureRoles.Policies.PSObject.Properties) {
            $roleName=$prop.Name; $p=$prop.Value; if (-not $p) { continue }
            $obj=[pscustomobject]@{ RoleName=$roleName; Scope=$p.Scope }
            foreach ($pp in $p.PSObject.Properties) { if ($pp.Name -notin @('Scope')) { $obj | Add-Member -NotePropertyName $pp.Name -NotePropertyValue $pp.Value -Force } }
            $expectedAzure += $obj
        }
    }
    if ($json.PSObject.Properties['EntraRoles'] -and $json.EntraRoles.PSObject.Properties['Policies']) {
        foreach ($prop in $json.EntraRoles.Policies.PSObject.Properties) {
            $roleName=$prop.Name; $p=$prop.Value; if (-not $p) { continue }
            $obj=[pscustomobject]@{ RoleName=$roleName }
            foreach ($pp in $p.PSObject.Properties) { $obj | Add-Member -NotePropertyName $pp.Name -NotePropertyValue $pp.Value -Force }
            $expectedEntra += $obj
        }
    }
    if ($json.PSObject.Properties['GroupRoles'] -and $json.GroupRoles.PSObject.Properties['Policies']) {
        foreach ($gprop in $json.GroupRoles.Policies.PSObject.Properties) {
            $groupId=$gprop.Name; $roleBlock=$gprop.Value; if (-not $roleBlock) { continue }
            foreach ($rprop in $roleBlock.PSObject.Properties) {
                $roleName=$rprop.Name; $p=$rprop.Value; if (-not $p) { continue }
                $obj=[pscustomobject]@{ GroupId=$groupId; RoleName=$roleName }
                foreach ($pp in $p.PSObject.Properties) { $obj | Add-Member -NotePropertyName $pp.Name -NotePropertyValue $pp.Value -Force }
                $expectedGroup += $obj
            }
        }
    }

    $expectedAzure = $expectedAzure | ForEach-Object { $_ | Add-Member -NotePropertyName ResolvedPolicy -NotePropertyValue (Resolve-Template $_) -Force; $_ }
    $expectedEntra = $expectedEntra | ForEach-Object { $_ | Add-Member -NotePropertyName ResolvedPolicy -NotePropertyValue (Resolve-Template $_) -Force; $_ }
    $expectedGroup = $expectedGroup | ForEach-Object { $_ | Add-Member -NotePropertyName ResolvedPolicy -NotePropertyValue (Resolve-Template $_) -Force; $_ }

    $fields = @('ActivationDuration','ActivationRequirement','ApprovalRequired','MaximumEligibilityDuration','AllowPermanentEligibility','MaximumActiveAssignmentDuration','AllowPermanentActiveAssignment')
    $liveNameMap = @{ 'ActivationRequirement'='EnablementRules'; 'MaximumEligibilityDuration'='MaximumEligibleAssignmentDuration'; 'AllowPermanentEligibility'='AllowPermanentEligibleAssignment' }
    $script:results=@(); $script:driftCount=0

    function Convert-RequirementValue {
        param([string]$Value)
        if (-not $Value) { return '' }
        $v = $Value.Trim()
        if ($v -eq '') { return '' }
        if ($v -match '^(none|null|no(ne)?requirements?)$') { return '' }
        # Split on comma / semicolon
        $tokens = $v -split '[,;]+' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        $norm = foreach ($t in $tokens) {
            switch -Regex ($t) {
                '^(mfa|multifactorauthentication)$' { 'MFA'; break }
                '^(justification)$' { 'Justification'; break }
                default { $t }
            }
        }
        ($norm | Sort-Object -Unique) -join ','
    }

    function Compare-Policy {
        param([string]$Type,[string]$Name,[object]$Expected,[object]$Live,[string]$ExtraId=$null,[int]$ApproverCountExpected=$null)
        $differences=@()
        foreach ($f in $fields) {
            if ($Expected.PSObject.Properties[$f]) {
                $exp=$Expected.$f; $liveProp=$f; if ($liveNameMap.ContainsKey($f)) { $liveProp=$liveNameMap[$f] }
                $liveVal=$null; if ($Live -and $Live.PSObject -and $Live.PSObject.Properties[$liveProp]) { $liveVal=$Live.$liveProp }
                if ($exp -is [System.Collections.IEnumerable] -and -not ($exp -is [string])) { $exp = ($exp | ForEach-Object { "$_" }) -join ',' }
                if ($liveVal -is [System.Collections.IEnumerable] -and -not ($liveVal -is [string])) { $liveVal = ($liveVal | ForEach-Object { "$_" }) -join ',' }
                if ($f -eq 'ActivationRequirement' -or $f -eq 'ActiveAssignmentRequirement') {
                    $expNorm  = Convert-RequirementValue $exp
                    $liveNorm = Convert-RequirementValue $liveVal
                    if ($expNorm -ne $liveNorm) {
                        $displayExp  = if ($null -eq $exp -or $exp -eq '' -or $exp -eq 'None') { 'None' } else { $exp }
                        $displayLive = if ($null -eq $liveVal -or $liveVal -eq '' -or $liveVal -eq 'None') { 'None' } else { $liveVal }
                        $differences += ("{0}: expected='{1}' actual='{2}'" -f $f,$displayExp,$displayLive)
                    }
                }
                else {
                    if ("$exp" -ne "$liveVal") { $differences += ("{0}: expected='{1}' actual='{2}'" -f $f,$exp,$liveVal) }
                }
            }
        }
        if ($null -ne $ApproverCountExpected -and $Expected.PSObject.Properties['ApprovalRequired'] -and $Expected.ApprovalRequired) {
            $liveApproverCount=$null
            foreach ($aprop in 'Approvers','Approver','Approval','approval','ApproverCount') {
                if ($Live.PSObject -and $Live.PSObject.Properties[$aprop]) {
                    $val=$Live.$aprop
                    if ($val -is [System.Collections.IEnumerable] -and -not ($val -is [string])) { $liveApproverCount=@($val).Count }
                    elseif ($val -match '^[0-9]+$') { $liveApproverCount=[int]$val }
                    if ($null -ne $liveApproverCount) { break }
                }
            }
            if ($null -ne $liveApproverCount -and $liveApproverCount -ne $ApproverCountExpected) { $differences += "ApproversCount: expected=$ApproverCountExpected actual=$liveApproverCount" }
        }
        if ($differences.Count -gt 0) { $script:driftCount++; $status='Drift' } else { $status='Match' }
        $script:results += [pscustomobject]@{ Type=$Type; Name=$Name; Target=$ExtraId; Status=$status; Differences=($differences -join '; ') }
    }

    if ($expectedAzure.Count -gt 0 -and -not $SubscriptionId) {
        Write-Warning "Azure role policies present but no -SubscriptionId provided; skipping Azure role validation."
    } elseif ($expectedAzure.Count -gt 0) {
        foreach ($p in $expectedAzure) {
            $r = Get-ResolvedPolicyObject $p
            if (-not $p.Scope) { $script:results += [pscustomobject]@{ Type='AzureRole'; Name=$p.RoleName; Target='(missing scope)'; Status='Error'; Differences='Missing Scope' }; $script:driftCount++; continue }
            try {
                $live = Get-PIMAzureResourcePolicy -tenantID $TenantId -subscriptionID $SubscriptionId -rolename $p.RoleName -ErrorAction Stop
                if ($live -is [System.Collections.IEnumerable] -and -not ($live -is [string])) { $live = @($live)[0] }
                $approverCount = if ($r.Approvers) { $r.Approvers.Count } else { $null }
                Compare-Policy -Type 'AzureRole' -Name $p.RoleName -Expected $r -Live $live -ExtraId $p.Scope -ApproverCountExpected $approverCount
            } catch { $script:results += [pscustomobject]@{ Type='AzureRole'; Name=$p.RoleName; Target=$p.Scope; Status='Error'; Differences=$_.Exception.Message }; $script:driftCount++ }
        }
    }

    foreach ($p in $expectedEntra) {
        if ($p._RoleNotFound) { $script:results += [pscustomobject]@{ Type='EntraRole'; Name=$p.RoleName; Target='/'; Status='SkippedRoleNotFound'; Differences='' }; continue }
        $r = Get-ResolvedPolicyObject $p
        try {
            $live = Get-PIMEntraRolePolicy -tenantID $TenantId -rolename $p.RoleName -ErrorAction Stop
            if ($live -is [System.Collections.IEnumerable] -and -not ($live -is [string])) { $live = @($live)[0] }
            if (-not $live) { throw "Live policy returned null for role '$($p.RoleName)'" }
            $approverCount = if ($r.Approvers) { $r.Approvers.Count } else { $null }
            Compare-Policy -Type 'EntraRole' -Name $p.RoleName -Expected $r -Live $live -ApproverCountExpected $approverCount
        } catch { $script:results += [pscustomobject]@{ Type='EntraRole'; Name=$p.RoleName; Target='/'; Status='Error'; Differences=$_.Exception.Message }; $script:driftCount++ }
    }

    foreach ($p in $expectedGroup) {
        $r = Get-ResolvedPolicyObject $p
        if (-not $r.PSObject.Properties['ActivationRequirement'] -and $r.PSObject.Properties['EnablementRules'] -and $r.EnablementRules) { try { $r | Add-Member -NotePropertyName ActivationRequirement -NotePropertyValue $r.EnablementRules -Force } catch { $r.ActivationRequirement = $r.EnablementRules } }
        if (-not $r.PSObject.Properties['ActivationDuration'] -and $r.PSObject.Properties['Duration'] -and $r.Duration) { try { $r | Add-Member -NotePropertyName ActivationDuration -NotePropertyValue $r.Duration -Force } catch { $r.ActivationDuration = $r.Duration } }
        if (-not $p.GroupId -and $p.GroupName) {
            try {
                $endpoint = "groups?`$filter=displayName eq '$($p.GroupName.Replace("'","''"))'"
                $resp = invoke-graph -Endpoint $endpoint
                if ($resp.value -and $resp.value.Count -gt 0) { $p | Add-Member -NotePropertyName GroupId -NotePropertyValue $resp.value[0].id -Force }
            } catch { Write-Warning "Group resolution failed for '$($p.GroupName)': $($_.Exception.Message)" }
        }
        $gid = $p.GroupId
        if (-not $gid) {
            $targetGroupRef = if ($p.GroupName) { $p.GroupName } else { '(unknown)' }
            $script:results += [pscustomobject]@{ Type='Group'; Name=$p.RoleName; Target=$targetGroupRef; Status='Error'; Differences='Missing GroupId' }
            $script:driftCount++
            continue
        }
        try {
            $live = Get-PIMGroupPolicy -tenantID $TenantId -groupID $gid -type ($p.RoleName.ToLower()) -ErrorAction Stop
            if ($live -is [System.Collections.IEnumerable] -and -not ($live -is [string])) { $live = @($live)[0] }
            $approverCount = if ($r.Approvers) { $r.Approvers.Count } else { $null }
            Compare-Policy -Type 'Group' -Name $p.RoleName -Expected $r -Live $live -ExtraId $gid -ApproverCountExpected $approverCount
        } catch { $script:results += [pscustomobject]@{ Type='Group'; Name=$p.RoleName; Target=$gid; Status='Error'; Differences=$_.Exception.Message }; $script:driftCount++ }
    }

    if (-not $PassThru) {
        Write-Host "Policy Verification Results:" -ForegroundColor Cyan
        $script:results | Sort-Object Type, Name | Format-Table -AutoSize
        $summary = $script:results | Group-Object Status | Select-Object Name,Count
        Write-Host "`nSummary:" -ForegroundColor Cyan
        $summary | Format-Table -AutoSize
        if ($script:results.Count -eq 0) {
            Write-Host "No policies discovered in config (nothing compared)." -ForegroundColor Yellow
        } else {
            $script:driftCount = ($script:results | Where-Object { $_.Status -in 'Drift','Error' }).Count
            if ($script:driftCount -eq 0) { Write-Host "All compared policy fields match expected values." -ForegroundColor Green }
            else { Write-Host "Drift detected in $script:driftCount policy item(s)." -ForegroundColor Yellow }
        }
    }

    if ($FailOnDrift -and ($script:results | Where-Object { $_.Status -in 'Drift','Error' })) {
        throw "PIM policy drift detected."
    }

    return $script:results
}
