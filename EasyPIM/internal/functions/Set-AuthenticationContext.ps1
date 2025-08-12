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
    Write-Verbose "Set-AuthenticationContext : Enabled=$authenticationContext_Enabled RawValue='$authenticationContext_Value'"

    # Normalize value (allow formats like 'c1' or 'c1:HighRiskOperations')
    $normalizedValue = $authenticationContext_Value
    if ($normalizedValue) { $normalizedValue = $normalizedValue.Trim() }
    if ($normalizedValue -and $normalizedValue.Contains(':')) { $normalizedValue = ($normalizedValue.Split(':')[0]).Trim() }

    if ($true -eq $authenticationContext_Enabled) {
        $enabled = "true"
        if (-not $normalizedValue -or $normalizedValue -eq 'None') { Throw "AuthenticationContext_Value cannot be null or empty if AuthenticationContext_Enabled is true" }
        if (-not [regex]::Match($normalizedValue,'^c([1-9]|[1-9][0-9])$').Success) { Throw "AuthenticationContext_Value must be 'c1' - 'c99' (optionally with ':Label' in config)" }
    } else { $enabled = "false" }

    $claimValue = if ($enabled -eq 'true') { $normalizedValue } else { '' }

    $properties = '{
    "id": "AuthenticationContext_EndUser_Assignment",
    "ruleType": "RoleManagementPolicyAuthenticationContextRule",
    "isEnabled": '+ $enabled + ',
    "claimValue": "'+ $claimValue + '",
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
            "claimValue": "'+ $claimValue + '",
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
