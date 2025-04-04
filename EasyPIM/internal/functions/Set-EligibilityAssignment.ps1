﻿<#
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
  $rule='{
    "@odata.type": "#microsoft.graph.unifiedRoleManagementPolicyExpirationRule",
    "id": "Expiration_Admin_Eligibility",
    "isExpirationRequired": '+ $expire + ',
    "maximumDuration": "'+ $max + '",
    "target": {
        "caller": "Admin",
        "operations": [
            "all"
        ],
        "level": "Eligibility",
        "inheritableSettings": [],
        "enforcedSettings": []
    }
  }'
}

    return $rule
}
