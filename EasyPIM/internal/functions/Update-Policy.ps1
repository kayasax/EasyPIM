<#
      .Synopsis
       Update policy with new rules
      .Description
       Patch $policyID with the rules $rules
      .Parameter PolicyID
       policy ID
      .Parameter rules
        rules
      .Example
        PS> Update-Policy -policyID $id -rules $rules

        Update $policyID with rules $rules
      .Link

      .Notes
#>
function Update-Policy  {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        $policyID,
        $rules
    )
    Write-Verbose "Updating Policy $policyID"
    write-Verbose "script:scope = $script:scope"
    #write-verbose "rules: $rules"
    $scope = $script:scope
    $ARMhost = Get-PIMAzureEnvironmentEndpoint -EndpointType 'ARM' -Verbose:$false
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

    $restUri = "$($ARMhost.TrimEnd('/'))/$($PolicyId.TrimStart('/'))/?api-version=2020-10-01"
   <# write-verbose "`n>> PATCH body: $body"

    write-verbose "Patch URI : $restURI"
    $response = Invoke-RestMethod -Uri $restUri -Method PATCH -Headers $authHeader -Body $body -verbose:$false
    #>
  # Try to extract SubscriptionId from scope (if scope is at subscription level)
  $subId = $null
  try {
    $m = [regex]::Match($scope, '^/?subscriptions/([0-9a-fA-F\-]{36})')
    if ($m.Success) { $subId = $m.Groups[1].Value }
  } catch {
    Write-Verbose "Update-Policy: failed to extract SubscriptionId from scope '$scope': $($_.Exception.Message)"
  }

  if ($subId) {
    $response = invoke-ARM -restURI $restUri -Method "PATCH" -Body $body -SubscriptionId $subId -TenantId $script:tenantID
  } else {
    $response = invoke-ARM -restURI $restUri -Method "PATCH" -Body $body -TenantId $script:tenantID
  }
    #
    return $response
}
