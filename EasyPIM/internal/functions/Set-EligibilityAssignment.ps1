<# 
      .Synopsis
       definne the eligible assognment setting : max duration and if permanent eligibility is allowed
      .Description
       correspond to rule 5 here: https://learn.microsoft.com/en-us/graph/identity-governance-pim-rules-overview#assignment-rules
      .Parameter MaximumEligibilityDuration 
       maximum duration of an eligibility
      .Parameter AllowPermanentEligibility
       Do we allow permanent eligibility
      
      .Example
        Set-EligibilityAssignment -MaximumEligibilityDuration "P30D" -AllowPermanentEligibility $false
      .Link
     
      .Notes
#>
function Set-EligibilityAssignment($MaximumEligibilityDuration, $AllowPermanentEligibility) {
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
    # update rule only if a change was requested
    return $rule
}
