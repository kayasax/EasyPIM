function Set-EligibilityAssignmentFromCSV($MaximumEligibilityDuration, $AllowPermanentEligibility) {
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
    # update rule only if a change was requested
    return $rule
}
