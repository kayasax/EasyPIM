function Update-Policy ($policyID, $rules) {
    Log "Updating Policy $policyID"
    #write-verbose "rules: $rules"
    $body = '
        {
            "properties": {
            "scope": "'+ $scope + '",  
            "rules": [
        '+ $rules +
    '],
          "level": "Assignment"
            }
        }'
    write-verbose "`n>> PATCH body: $body"
    $restUri = "$ARMhost/$PolicyId/?api-version=2020-10-01"
    write-verbose "Patch URI : $restURI"
    $response = Invoke-RestMethod -Uri $restUri -Method PATCH -Headers $authHeader -Body $body -verbose:$false
}
