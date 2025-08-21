<#
      .Synopsis
       definne the eligible assignment setting : max duration and if permanent eligibility is allowed
      .Description
       correspond to rule 5 here: https://learn.microsoft.com/en-us/graph/identity-governance-pim-rules-overview#assignment-rules
      .Parameter MaximumEligibilityDuration
       maximum duration of an eligibility
      .Parameter AllowPermanentEligibility
       Do we allow permanent eligibility
      .Parameter EntraRole
       Set to $true if configuring entra role
      .Example
       PS> Set-EligibilityAssignment -MaximumEligibilityDuration "P30D" -AllowPermanentEligibility $false

       set Max eligibility duration to 30 days
      .Link

      .Notes
#>
function Set-EligibilityAssignment($MaximumEligibilityDuration, $AllowPermanentEligibility, [switch]$entraRole) {
    write-verbose "Set-EligibilityAssignment: $MaximumEligibilityDuration $AllowPermanentEligibility"
    $max = $MaximumEligibilityDuration

    if ( ($true -eq $AllowPermanentEligibility) -or ("true" -eq $AllowPermanentEligibility) -and ("false" -ne $AllowPermanentEligibility)) {
        $expire = "false"
        write-verbose "1 setting expire to : $expire"
    }
    else {

        $expire = "true"
        write-verbose "2 setting expire to : $expire"
    }

    $rule = '
        {
        "isExpirationRequired": '+ $expire + ',
        "maximumDuration": "'+ $max + '",
        "id": "Expiration_Admin_Eligibility",
        "ruleType": "RoleManagementPolicyExpirationRule",
        "target": {
          "caller": "Admin",
          "operations": [
            "All"
          ],
          "level": "Eligibility",
          "targetObjects": null,
          "inheritableSettings": null,
          "enforcedSettings": null
        }
    }
    '
if($entraRole){
  $maxField = ''
  # Normalize duration for Entra: Graph may not accept P1Y; convert to P365D when needed
  $normMax = $max
  if ($null -ne $normMax -and $normMax -match '^P\d+Y$') {
    # Extract years and convert to days (approximate 365 days per year)
    $years = [int]($normMax.TrimStart('P').TrimEnd('Y'))
    if ($years -lt 0) { $years = 0 }
    $days = $years * 365
    $normMax = "P${days}D"
  }
  if ($expire -eq 'true') {
  $maxField = '"maximumDuration": "'+ $normMax + '",'
  }
  $normMaxDisplay = if ($null -ne $normMax -and $normMax -ne '') { $normMax } else { '<none>' }
  Write-Verbose ("[Policy][Entra][Eligibility] isExpirationRequired={0} maximumDuration={1}" -f $expire, $normMaxDisplay)
  $rule='{
    "@odata.type": "#microsoft.graph.unifiedRoleManagementPolicyExpirationRule",
    "id": "Expiration_Admin_Eligibility",
    "isExpirationRequired": '+ $expire + ',
    '+ $maxField + '
    "target": {
        "caller": "Admin",
        "operations": [
            "All"
        ],
        "level": "Eligibility",
        "inheritableSettings": [],
        "enforcedSettings": []
    }
  }'
}

    return $rule
}
