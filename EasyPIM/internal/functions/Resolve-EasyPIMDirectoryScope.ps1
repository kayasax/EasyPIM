function Resolve-EasyPIMDirectoryScope {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]
        $Scope,

        [Parameter(Mandatory = $false)]
        [string]
        $DefaultScope = '/',

        [Parameter(Mandatory = $false)]
        [string]
        $ErrorContext = 'Resolve-EasyPIMDirectoryScope'
    )

    if ([string]::IsNullOrWhiteSpace($Scope)) {
        return $DefaultScope
    }

    $normalized = $Scope.Trim()

    if ($normalized -eq '/' -or $normalized -eq '\\' -or $normalized -eq 'tenant' -or $normalized -eq 'directory' -or $normalized -eq 'root') {
        return '/'
    }

    if ($normalized.StartsWith('/')) {
        return $normalized
    }

    if ($normalized -match '^[0-9a-fA-F-]{36}$') {
        return "/administrativeUnits/$normalized"
    }

    if ($normalized -match '^(administrativeUnits/|/administrativeUnits/)[0-9a-fA-F-]{36}$') {
        if ($normalized.StartsWith('/')) {
            return $normalized
        }

        return '/' + $normalized
    }

    $escapedName = $normalized.Replace("'", "''")
    try {
        $response = invoke-graph -Endpoint 'administrativeUnits' -Filter "displayName eq '$escapedName'" -Method 'GET'
    }
    catch {
        throw "$ErrorContext : Failed to query administrative units for scope '$Scope'. $($_.Exception.Message)"
    }

    $auMatches = @()
    if ($response) {
        if ($response.PSObject.Properties.Name -contains 'value') {
            $auMatches = @($response.value)
        }
        elseif ($response.PSObject.Properties.Name -contains 'id') {
            $auMatches = @($response)
        }
    }

    if (-not $auMatches -or $auMatches.Count -eq 0) {
        throw "$ErrorContext : No administrative unit found matching display name '$Scope'. Provide a GUID or supply the full '/administrativeUnits/<GUID>' scope."
    }

    if ($auMatches.Count -gt 1) {
        $displayNames = ($auMatches | ForEach-Object { $_.displayName }) -join ', '
        throw "$ErrorContext : Multiple administrative units matched '$Scope' ($displayNames). Provide a GUID or the full scope path to disambiguate."
    }

    if (-not $auMatches[0].PSObject.Properties.Name -contains 'id') {
        throw "$ErrorContext : Unable to determine administrative unit identifier for '$Scope'."
    }

    $resolvedId = $auMatches[0].id
    if (-not $resolvedId) {
        throw "$ErrorContext : Administrative unit '$Scope' did not include an 'id' property."
    }

    return "/administrativeUnits/$resolvedId"
}
