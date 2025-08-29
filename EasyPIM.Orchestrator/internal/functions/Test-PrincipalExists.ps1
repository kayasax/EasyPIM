# Minimal Test-PrincipalExists for orchestrator use
function Test-PrincipalExists {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$PrincipalId
    )

    try {
        $null = invoke-graph -Endpoint "directoryObjects/$PrincipalId" -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}
