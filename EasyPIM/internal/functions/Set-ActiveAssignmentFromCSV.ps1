<#
      .Synopsis
       Rule for maximum active assignment
      .Description
       rule 6 in https://learn.microsoft.com/en-us/graph/identity-governance-pim-rules-overview#assignment-rules
      .Parameter MaximumActiveAssignmentDuration
       Maximum active assignment duration.  Duration ref: https://en.wikipedia.org/wiki/ISO_8601#Durations
      .Parameter AllowPermanentActiveAssignment
        Allow permanent active assignement ?
        .PARAMETER EntraRole
         set to true if configuration is for an entra role
      .EXAMPLE
        PS> Set-ActiveAssignment -MaximumActiveAssignmentDuration "P30D" -AllowPermanentActiveAssignment $false

        limit the active assignment duration to 30 days

      .Link

      .Notes

#>
function Set-ActiveAssignmentFromCSV($MaximumActiveAssignmentDuration, $AllowPermanentActiveAssignment, [switch]$EntraRole) {
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

    if($EntraRole){
        $rule = '
            {
                "@odata.type": "#microsoft.graph.unifiedRoleManagementPolicyExpirationRule",
                "id": "Expiration_Admin_Assignment",
                "isExpirationRequired": '+ $expire2 + ',
                "maximumDuration": "'+ $MaximumActiveAssignmentDuration + '",
                "target": {
                    "caller": "Admin",
                    "operations": [
                        "All"
                    ],
                    "level": "Assignment",
                    "inheritableSettings": [],
                    "enforcedSettings": []
                }
            }'
     }
    return $rule

}
