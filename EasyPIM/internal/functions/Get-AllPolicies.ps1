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
    $request = @{
        Method = 'GET'
        Body = $null
        TenantId = $TenantId
        ErrorAction = 'Stop'
    }
    if ($subId) { $request.SubscriptionId = $subId }

    $origin = [uri]$ARMhost
    $visited = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $roles = [System.Collections.Generic.List[string]]::new()
    while ($restUri) {
        $pageUri = $null
        if (-not [uri]::TryCreate($restUri, [System.UriKind]::Absolute, [ref]$pageUri) -or
            $pageUri.Scheme -ne 'https' -or $pageUri.Authority -ne $origin.Authority -or
            $pageUri.UserInfo -or $pageUri.Fragment) {
            throw 'Get-AllPolicies: invalid continuation URL or ARM origin mismatch.'
        }
        if (-not $visited.Add($pageUri.AbsoluteUri)) {
            throw 'Get-AllPolicies: repeated ARM continuation URL.'
        }

        # Keep the service URL intact, including its API version and encoded continuation token.
        $response = Invoke-ARM -restURI $restUri @request
        Write-Verbose $response
        foreach ($role in $response.value) {
            if ($null -ne $role.properties.roleName) {
                $roles.Add($role.properties.roleName)
            }
        }
        $restUri = $response.nextLink
    }
    # Emit nothing until every page succeeds so backup cannot use a partial role list.
    return $roles
}
