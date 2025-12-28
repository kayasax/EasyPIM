<#
      .Synopsis
       Retrieve all role policies
      .Description
       Get all roles then for each get the policy
      .Parameter scope
       Scope to look at
      .Example
        PS> Get-AllPolicies -scope "subscriptions/$subscriptionID"

        Get all roles then for each get the policy
      .Link

      .Notes
#>
function Get-AllPolicies {
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
  [CmdletBinding()]
  param (
      [Parameter()]
      [string]
      $scope,

      [Parameter()]
      [string]
      $TenantId
  )

    $ARMhost = Get-PIMAzureEnvironmentEndpoint -EndpointType 'ARM' -Verbose:$false
    $ARMendpoint = "$($ARMhost.TrimEnd('/'))/$($scope.TrimStart('/'))/providers/Microsoft.Authorization"
    $restUri = "$ARMendpoint/roleDefinitions?`$select=roleName&api-version=2022-04-01"

    # Try to extract SubscriptionId from scope
    $subId = $null
    try { $m = [regex]::Match($scope, '^/?subscriptions/([0-9a-fA-F\-]{36})'); if ($m.Success) { $subId = $m.Groups[1].Value } }
    catch { Write-Verbose "Get-AllPolicies: failed to extract SubscriptionId from scope '$scope'" }

    write-verbose "Getting All Policies at $restUri"
    if ($subId) {
        $response = Invoke-ARM -restURI $restUri -Method 'GET' -Body $null -SubscriptionId $subId -TenantId $TenantId
    } else {
        $response = Invoke-ARM -restURI $restUri -Method 'GET' -Body $null -TenantId $TenantId
    }
    Write-Verbose $response
    $roles = $response | ForEach-Object {
        $_.value.properties.roleName
    }
    return $roles
}
