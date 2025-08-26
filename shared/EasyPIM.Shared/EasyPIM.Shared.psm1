# Load internal shared helpers
foreach ($file in Get-ChildItem -Path (Join-Path $PSScriptRoot 'internal') -Filter *.ps1 -Recurse) {
    . $file.FullName
}

# Export shared helpers used by parent modules
Export-ModuleMember -Function @(
    'Write-SectionHeader',
    'Initialize-EasyPIMPolicies',
    'invoke-graph',
    'Test-PrincipalExists',
    'Test-GroupEligibleForPIM',
    'Invoke-ARM',
    'Get-PIMAzureEnvironmentEndpoint'
)
