<#
      .Synopsis
       Rule for maximum active assignment
      .Description
       rule 6 in https://learn.microsoft.com/en-us/graph/identity-governance-pim-rules-overview#assignment-rules
      .Parameter MaximumActiveAssignmentDuration
       Maximum active assignment duration.  Duration ref: https://en.wikipedia.org/wiki/ISO_8601#Durations
      .Parameter AllowPermanentActiveAssignment
        Allow permanent active assignement ?
      .EXAMPLE
        PS> Set-ActiveAssignment -MaximumActiveAssignmentDuration "P30D" -AllowPermanentActiveAssignment $false

        limit the active assignment duration to 30 days
      
      .Link
     
      .Notes
      	
#>
function Set-ActiveAssignment($MaximumActiveAssignmentDuration, $AllowPermanentActiveAssignment) {
    write-verbose "Set-ActiveAssignment($MaximumActiveAssignmentDuration, $AllowPermanentActiveAssignment)"
    if ( $true -eq 'AllowPermanentActiveAssignment') {
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
