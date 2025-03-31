# Add caching for directory object lookups
$script:principalCache = @{}

function Test-PrincipalExists {
    param ([string]$PrincipalId)


    # Return from cache if available
    if ($script:principalCache.ContainsKey($PrincipalId)) {
        return $script:principalCache[$PrincipalId]
    }

    try {
        $response = Invoke-Graph -endpoint "directoryObjects/$PrincipalId" -ErrorAction SilentlyContinue
        if ($null -ne $response.error){
            Write-Verbose "Principal $PrincipalId does not exist: $($response.error.message)"
            $script:principalCache[$PrincipalId] = $false
            return $false
        }

        else{
            write-verbose "Principal $PrincipalId exists"
             $script:principalCache[$PrincipalId] = $true
        return $true
        }

    }
    catch {
        $script:principalCache[$PrincipalId] = $false
        return $false
    }
}
