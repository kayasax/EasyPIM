function Set-ActiveAssignmentFromCSV($MaximumActiveAssignmentDuration, $AllowPermanentActiveAssignment) {
    write-verbose "Set-ActiveAssignmentFromCSV($MaximumActiveAssignmentDuration, $AllowPermanentActiveAssignment)"
    if ( "true" -eq $AllowPermanentActiveAssignment) {
        $expire2 = "false"
    }
    else {
        $expire2 = "true"
    }
            
    $rule = '
        {
        "isExpirationRequired": '+ $expire2 + ',
        "maximumDuration": "'+ $MaximumActiveAssignmentDuration + '",
        "id": "Expiration_Admin_Assignment",
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
    return $rule
        
}
