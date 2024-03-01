<#
      .Synopsis
       definne the eligible assignment setting : max duration and if permanent eligibility is allowed
      .Description
       correspond to rule 5 here: https://learn.microsoft.com/en-us/graph/identity-governance-pim-rules-overview#assignment-rules
      .Parameter MaximumEligibilityDuration
       maximum duration of an eligibility
      .Parameter AllowPermanentEligibility
       Do we allow permanent eligibility
       .PARAMETER entraRole
        set to true if configuration is for an entra role
      .EXAMPLE
        PS> Set-EligibilityAssignment -MaximumEligibilityDuration "P30D" -AllowPermanentEligibility $false

        define a maximum eligibility duration of 30 days
      .Link
     
      .Notes
#>
function Set-EligibilityAssignmentFromCSV($MaximumEligibilityDuration, $AllowPermanentEligibility, [switch]$entraRole) {
    write-verbose "Set-EligibilityAssignmentFromCSV: $MaximumEligibilityDuration $AllowPermanentEligibility"
    $max = $MaximumEligibilityDuration
     
    if ( "true" -eq $AllowPermanentEligibility) {
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
    # update rule only if a change was requested
    return $rule
}
