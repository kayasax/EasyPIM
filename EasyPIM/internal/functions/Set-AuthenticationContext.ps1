<#
      .Synopsis
       Rule for authentication context
      .Description
       rule 3 in https://learn.microsoft.com/en-us/graph/identity-governance-pim-rules-overview#activation-rules
      .Parameter AuthenticationContext_Enabled
       $true or $false
       .PARAMETER AuthenticationContext_Value
       authentication context name ex "c1"
.PARAMETER entraRole
       $true or $false

      .EXAMPLE
        PS> Set-AuthenticationContext -authenticationContext_Enabled $true -authenticationContext_Value "c1"

        Authentication context c1 will be required to activate the role

      .Link

      .Notes

#>
function Set-AuthenticationContext($authenticationContext_Enabled, $authenticationContext_Value, [switch]$entraRole) {
    write-verbose "Set-AuthenticationContext : $($authenticationContext_Enabled), $($authenticationContext_Value)"



    if ($true -eq $authenticationContext_Enabled) {
        $enabled = "true"
        if ($authenticationContext_Value -eq "None" -or $authenticationContext_Value.length -eq 0) {
            Throw "AuthenticationContext_Value cannot be null or empty if AuthenticationContext_Enabled is true"
        }
        if ( ([regex]::match($authenticationContext_Value, "c[0-9]{1,2}$").success -eq $false)) {
            Throw "AuthenticationContext_Value must be in the format c1 - c99"
        }
    }
    else { $enabled = "false" }

    $properties = '{
	"id": "AuthenticationContext_EndUser_Assignment",
	"ruleType": "RoleManagementPolicyAuthenticationContextRule",
	"isEnabled": '+ $enabled + ',
	"claimValue": "'+ $authenticationContext_Value + '",
	"target": {
		"caller": "EndUser",
		"operations": [
			"All"
		],
		"level": "Assignment"
	}
}'

    if ($entraRole) {
        $properties = '
               {
            "@odata.type": "#microsoft.graph.unifiedRoleManagementPolicyAuthenticationContextRule",
            "id": "AuthenticationContext_EndUser_Assignment",
            "isEnabled": '+ $enabled + ',
            "claimValue": "'+ $authenticationContext_Value + '",
            "target": {
                "caller": "EndUser",
                "operations": [
                    "all"
                ],
                "level": "Assignment",
                "inheritableSettings": [],
                "enforcedSettings": []
            }


}'
    }
    return $properties
}
