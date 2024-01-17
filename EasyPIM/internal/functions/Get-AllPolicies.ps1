function Get-AllPolicies($scope) {
    
    $ARMhost = "https://management.azure.com"
    $ARMendpoint = "$ARMhost/$scope/providers/Microsoft.Authorization"
    $restUri = "$ARMendpoint/roleDefinitions?`$select=roleName&api-version=2022-04-01"

    write-verbose "Getting All Policies at $restUri"
    #$response = Invoke-RestMethod -Uri $restUri -Method Get -Headers $authHeader -verbose:$false
    $response = Invoke-ARM -restURI $restUri -Method 'GET' -Body $null
    Write-Verbose $response
    $roles = $response | % { 
        $_.value.properties.roleName
    }
    return $roles
}
