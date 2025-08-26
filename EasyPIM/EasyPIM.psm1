$__easypim_core_vp = $VerbosePreference
try {
    # Suppress verbose during module import; restore afterwards
    $VerbosePreference = 'SilentlyContinue'

# Ensure shared helpers are available for internal use (Invoke-ARM, invoke-graph, Initialize-EasyPIMPolicies, etc.)
# Try packaged relative path first (used after build), then repo-relative for local dev.
$sharedCandidates = @(
    (Join-Path $PSScriptRoot 'shared/EasyPIM.Shared/EasyPIM.Shared.psd1'),
    (Join-Path (Split-Path -Parent $PSScriptRoot) 'shared/EasyPIM.Shared/EasyPIM.Shared.psd1')
)
foreach ($cand in $sharedCandidates) {
    if (Test-Path $cand) {
        try {
            if (Get-Module -Name 'EasyPIM.Shared' -ErrorAction SilentlyContinue) { Remove-Module -Name 'EasyPIM.Shared' -Force -ErrorAction SilentlyContinue }
            Import-Module $cand -Force -ErrorAction Stop | Out-Null
        } catch {}
        break
    }
}

foreach ($file in Get-ChildItem -Path "$PSScriptRoot/internal/functions" -Filter *.ps1 -Recurse | Where-Object { $_.BaseName -notmatch '^(New-EPO|Set-EPO|Invoke-EPO|EPO_)' -and $_.BaseName -notin @('Test-PrincipalExists','Invoke-graph','Invoke-ARM','EPO_Test-GroupEligibleForPIM','New-EasyPIMAssignments','Initialize-EasyPIMPolicies','Shim-Test-PIMPolicyDrift') } ) {
    . $file.FullName
}

foreach ($file in Get-ChildItem -Path "$PSScriptRoot/functions" -Filter *.ps1 -Recurse) {
    . $file.FullName
}

foreach ($file in Get-ChildItem -Path "$PSScriptRoot/internal/scripts" -Filter *.ps1 -Recurse) {
    . $file.FullName
}

## Note: All internal helper functions (including Convert-IsoDuration, formerly Normalize-IsoDuration) are loaded from internal/functions/*.
## Orchestrator-owned EPO* policy functions (New-EPO*, Set-EPO*, Invoke-EPO*) are intentionally not loaded here.

# Explicit export gating: only export public API. Prevents accidental EPO* exports.
Export-ModuleMember -Function @(
    'Import-PIMAzureResourcePolicy',
    'Get-PIMAzureResourcePolicy',
    'Set-PIMAzureResourcePolicy',
    'Copy-PIMAzureResourcePolicy',
    'Export-PIMAzureResourcePolicy',
    'Backup-PIMAzureResourcePolicy',
    'Get-PIMAzureResourceActiveAssignment',
    'Get-PIMAzureResourceEligibleAssignment',
    'New-PIMAzureResourceActiveAssignment',
    'New-PIMAzureResourceEligibleAssignment',
    'Remove-PIMAzureResourceEligibleAssignment',
    'Remove-PIMAzureResourceActiveAssignment',
    'Get-PIMEntraRolePolicy',
    'Export-PIMEntraRolePolicy',
    'Import-PIMEntraRolePolicy',
    'Set-PIMEntraRolePolicy',
    'Backup-PIMEntraRolePolicy',
    'Copy-PIMEntraRolePolicy',
    'Get-PIMEntraRoleActiveAssignment',
    'Get-PIMEntraRoleEligibleAssignment',
    'New-PIMEntraRoleActiveAssignment',
    'New-PIMEntraRoleEligibleAssignment',
    'Remove-PIMEntraRoleActiveAssignment',
    'Remove-PIMEntraRoleEligibleAssignment',
    'Get-PIMGroupPolicy',
    'Set-PIMGroupPolicy',
    'Get-PIMGroupActiveAssignment',
    'Get-PIMGroupEligibleAssignment',
    'New-PIMGroupActiveAssignment',
    'New-PIMGroupEligibleAssignment',
    'Remove-PIMGroupActiveAssignment',
    'Remove-PIMGroupEligibleAssignment',
    'Show-PIMReport',
    'Get-PIMAzureResourcePendingApproval',
    'Approve-PIMAzureResourcePendingApproval',
    'Deny-PIMAzureResourcePendingApproval',
    'Get-PIMEntraRolePendingApproval',
    'Approve-PIMEntraRolePendingApproval',
    'Deny-PIMEntraRolePendingApproval',
    'Get-PIMGroupPendingApproval',
    'Approve-PIMGroupPendingApproval',
    'Deny-PIMGroupPendingApproval',
    'Copy-PIMAzureResourceEligibleAssignment',
    'Copy-PIMEntraRoleEligibleAssignment',
    'Get-EasyPIMConfiguration'
) -Alias @() -Variable @()

} finally {
    $VerbosePreference = $__easypim_core_vp
}
