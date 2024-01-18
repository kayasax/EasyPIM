<# 
      .Synopsis
       Update policy with new rules
      .Description
       Patch $policyID with the rules $rules
      .Parameter PolicyID 
       
      .Parameter rules
                   
      .Example
        Update-Policy -policyID $id -rules $rules
      .Link
     
      .Notes
#>
function Update-Policy  {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        $policyID, 
        $rules
    )
    Log "Updating Policy $policyID"
    #write-verbose "rules: $rules"
    $scope = "subscriptions/$script:subscriptionID"
    $ARMhost = "https://management.azure.com"
    #$ARMendpoint = "$ARMhost/$scope/providers/Microsoft.Authorization"

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
    
    $restUri = "$ARMhost/$PolicyId/?api-version=2020-10-01"
   <# write-verbose "`n>> PATCH body: $body"
    
    write-verbose "Patch URI : $restURI"
    $response = Invoke-RestMethod -Uri $restUri -Method PATCH -Headers $authHeader -Body $body -verbose:$false
    #>
    $response = invoke-ARM -restURI $restUri -Method "PATCH" -Body $body
    #
    return $response
}
