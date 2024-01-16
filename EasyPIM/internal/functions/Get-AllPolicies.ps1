function Get-AllPolicies() {
    $restUri = "$ARMendpoint/roleDefinitions?`$select=roleName&api-version=2022-04-01"
    write-verbose "Getting All Policies at $restUri"
    $response = Invoke-RestMethod -Uri $restUri -Method Get -Headers $authHeader -verbose:$false
    $roles = $response | % { 
        $_.value.properties.roleName
    }
    return $roles
}
